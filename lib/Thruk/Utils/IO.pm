package Thruk::Utils::IO;

=head1 NAME

Thruk::Utils - IO Utilities Collection for Thruk

=head1 DESCRIPTION

IO Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Carp qw/confess longmess/;
use Fcntl qw/:DEFAULT :flock :mode SEEK_SET/;
use Cpanel::JSON::XS ();
use POSIX ":sys_wait_h";
use IPC::Open3 qw/open3/;
use File::Slurp qw/read_file/;
use File::Copy qw/move/;
use Time::HiRes qw/sleep/;
#use Thruk::Timer qw/timing_breakpoint/;

$Thruk::Utils::IO::config = undef;

##############################################
=head1 METHODS

=head2 close

  close($fh, $filename, $just_close)

close filehandle and ensure permissions and ownership

=cut
sub close {
    my($fh, $filename, $just_close) = @_;
    my $rc = CORE::close($fh);
    confess("cannot write to $filename: $!") unless $rc;
    ensure_permissions('file', $filename) unless $just_close;
    return $rc;
}

##############################################

=head2 mkdir

  mkdir($dirname)

create folder and ensure permissions and ownership

=cut

sub mkdir {
    for my $dirname (@_) {
        unless(-d $dirname) {
            CORE::mkdir($dirname) or confess("failed to create ".$dirname.": ".$!);
        }
        ensure_permissions('dir', $dirname);
    }
    return 1;
}

##############################################

=head2 mkdir_r

  mkdir_r($dirname)

create folder recursive

=cut

sub mkdir_r {
    for my $dirname (@_) {
        $dirname =~ s|\/\.?$||gmx;
        next if -d $dirname.'/.';
        my $path = '';
        for my $part (split/(\/)/mx, $dirname) {
            $path .= $part;
            next if $path eq '';
            Thruk::Utils::IO::mkdir($path) unless -d $path.'/.';
        }
    }
    return 1;
}

##############################################

=head2 read

  read($path)

read file and return content

=cut

sub read {
    my($path) = @_;
    my $content = read_file($path);
    return($content);
}

##############################################

=head2 write

  write($path, $content, [ $mtime ], [ $append ])

creates file and ensure permissions

=cut

sub write {
    my($path,$content,$mtime,$append) = @_;
    my $mode = $append ? '>>' : '>';
    open(my $fh, $mode, $path) or confess('cannot create file '.$path.': '.$!);
    print $fh $content;
    Thruk::Utils::IO::close($fh, $path) or confess("cannot close file ".$path.": ".$!);
    utime($mtime, $mtime, $path) if $mtime;
    return 1;
}

##############################################

=head2 ensure_permissions

  ensure_permissions($mode, $path)

ensure permissions and ownership

=cut

sub ensure_permissions {
    my($mode, $path) = @_;
    return if defined $ENV{'THRUK_NO_TOUCH_PERM'};

    confess("need a path") unless defined $path;
    return unless -e $path;

    my @stat = stat($path);
    my $cur  = sprintf "%04o", S_IMODE($stat[2]);

    if(!$Thruk::Utils::IO::config) {
        require Thruk::Backend::Pool;
        $Thruk::Utils::IO::config = Thruk::Config::get_config();
    }
    my $config = $Thruk::Utils::IO::config;
    # set modes
    if($mode eq 'file') {
        if($cur ne $config->{'mode_file'}) {
            chmod(oct($config->{'mode_file'}), $path)
                or warn("failed to ensure permissions (0660/$cur) with uid: ".$>." - ".$<." for ".$path.": ".$!."\n".`ls -dn '$path'`);
        }
    }
    elsif($mode eq 'dir') {
        if($cur ne $config->{'mode_dir'}) {
            chmod(oct($config->{'mode_dir'}), $path)
                or warn("failed to ensure permissions (0770/$cur) with uid: ".$>." - ".$<." for ".$path.": ".$!."\n".`ls -dn '$path'`);
        }
    }
    else {
        chmod($mode, $path)
            or warn("failed to ensure permissions (".$mode.") with uid: ".$>." - ".$<." for ".$path.": ".$!."\n".`ls -dn '$path'`);
    }

    # change owner too if we are root
    my $uid = -1;
    if($> == 0) {
        $uid = $ENV{'THRUK_USER_ID'} or confess('no user id!');
    }

    # change group
    chown($uid, $ENV{'THRUK_GROUP_ID'}, $path) if defined $ENV{'THRUK_GROUP_ID'};
    return;
}

##############################################

=head2 file_lock

  file_lock($file, $mode)

  $mode can be
    - 'ex' exclusive
    - 'sh' shared

locks given file. Returns locked filehandle.

=cut

sub file_lock {
    my($file, $mode) = @_;

    alarm(30);
    local $SIG{'ALRM'} = sub { confess("timeout while trying to flock(".$mode."): ".$file); };

    my $lock_file = $file.'.lock';
    my $lock_fh;
    if($mode eq 'ex') {
        my $locked = 0;
        while(1) {
            if(sysopen($lock_fh, $lock_file, O_RDWR|O_EXCL|O_CREAT, 0660)) {
                last;
            }
            my $err = $!;
            # check for orphaned locks
            if($err eq 'File exists') {
                my $old_inode = (stat($lock_file))[1];
                if(sysopen($lock_fh, $lock_file, O_RDWR, 0660) && flock($lock_fh, LOCK_EX|LOCK_NB)) {
                    sleep(3);
                    my $new_inode = (stat($lock_file))[1];
                    if($new_inode && $new_inode == $old_inode) {
                        # lock seems to be orphaned, continue normally
                        $locked = 1;
                        last;
                    }
                }
            }
            sleep(0.1);
        }
        if(!$locked) {
            flock($lock_fh, LOCK_EX) or confess 'Cannot lock_ex '.$lock_file.': '.$!;
        }
    }
    elsif($mode eq 'sh') {
        # nothing to do
    } else {
        confess("unknown mode: ".$mode);
    }

    sysopen(my $fh, $file, O_RDWR|O_CREAT) or die("cannot open file ".$file.": ".$!);
    if($mode eq 'ex') {
        flock($fh, LOCK_EX) or confess 'Cannot lock_ex '.$lock_file.': '.$!;
    }
    elsif($mode eq 'sh') {
        flock($fh, LOCK_SH) or confess 'Cannot lock_sh '.$file.': '.$!;
    }

    seek($fh, 0, SEEK_SET) or die "Cannot seek ".$file.": $!\n";
    sysseek($fh, 0, SEEK_SET) or die "Cannot sysseek ".$file.": $!\n";

    alarm(0);
    return($fh, $lock_fh);
}

##############################################

=head2 file_unlock

  file_unlock($file, $fh)

unlocks file lock previously with file_lock exclusivly. Returns nothing.

=cut

sub file_unlock {
    my($file, $fh, $lock_fh) = @_;
    flock($fh, LOCK_UN) if $fh;
    unlink($file.'.lock');
    flock($lock_fh, LOCK_UN);
    return;
}

##############################################

=head2 json_store

  json_store($file, $data, [$pretty], [$changed_only])

stores data json encoded

=cut

sub json_store {
    my($file, $data, $pretty, $changed_only, $tmpfile) = @_;

    my $json = Cpanel::JSON::XS->new->utf8;
    $json = $json->pretty if $pretty;
    $json = $json->canonical; # keys will be randomly ordered otherwise

    my $write_out;
    if($changed_only && -f $file) {
        $write_out = $json->encode($data);
        my $old = read_file($file);
        return 1 if $old eq $write_out;
    }

    $tmpfile = $file.'.new' unless $tmpfile;
    open(my $fh2, '>', $tmpfile) or confess('cannot write file '.$tmpfile.': '.$!);
    print $fh2 ($write_out || $json->encode($data)) or confess('cannot write file '.$tmpfile.': '.$!);
    Thruk::Utils::IO::close($fh2, $tmpfile) or confess("cannot close file ".$tmpfile.": ".$!);

    if($Thruk::Utils::IO::config && $Thruk::Utils::IO::config->{'thruk_author'}) {
        eval {
            my $test = $json->decode(scalar read_file($tmpfile));
        };
        confess("json_store failed to write a valid file: ".$@) if $@;
    }


    move($tmpfile, $file) or confess("cannot replace $file with $tmpfile: $!");

    return 1;
}

##############################################

=head2 json_lock_store

  json_lock_store($file, $data, [$pretty], [$changed_only])

stores data json encoded

=cut

sub json_lock_store {
    my($file, $data, $pretty, $changed_only, $tmpfile) = @_;
    my($fh, $lock_fh) = file_lock($file, 'ex');
    json_store($file, $data, $pretty, $changed_only, $tmpfile);
    file_unlock($file, $fh, $lock_fh);
    return 1;
}

##############################################

=head2 json_retrieve

  json_retrieve($file, $fh)

retrieve json data

=cut

sub json_retrieve {
    my($file, $fh) = @_;
    confess("got no filehandle") unless defined $fh;

    my $json = Cpanel::JSON::XS->new->utf8;
    $json->relaxed();

    local $/ = undef;
    my $data;

    seek($fh, 0, SEEK_SET) or die "Cannot seek ".$file.": $!\n";
    sysseek($fh, 0, SEEK_SET) or die "Cannot sysseek ".$file.": $!\n";

    eval {
        $data = $json->decode(scalar <$fh>);
    };
    my $err = $@;
    if($err && !$data) {
        confess("error while reading $file: ".$@);
    }
    return $data;
}

##############################################

=head2 json_lock_retrieve

  json_lock_retrieve($file)

retrieve json data

=cut

sub json_lock_retrieve {
    my($file) = @_;
    return unless -s $file;
    my($fh) = file_lock($file, 'sh');
    my $data = json_retrieve($file, $fh);
    CORE::close($fh) or die("cannot close file ".$file.": ".$!);
    return $data;
}

##############################################

=head2 json_lock_patch

  json_lock_patch($file, $patch_data, [$pretty], [$changed_only], [$tmpfile])

update json data

=cut

sub json_lock_patch {
    my($file, $patch_data, $pretty, $changed_only, $tmpfile) = @_;
    my($fh, $lock_fh) = file_lock($file, 'ex');
    my $data = json_patch($file, $fh, $patch_data, $pretty, $changed_only, $tmpfile);
    file_unlock($file, $fh, $lock_fh);
    return $data;
}

##############################################

=head2 json_patch

  json_patch($file, $fh, $patch_data, [$pretty], [$changed_only], [$tmpfile])

update json data

=cut

sub json_patch {
    my($file, $fh, $patch_data, $pretty, $changed_only, $tmpfile) = @_;
    confess("got no filehandle") unless defined $fh;
    my $data = -s $file ? json_retrieve($file, $fh) : {};
    $data = _merge_deep_hash($data, $patch_data);
    json_store($file, $data, $pretty, $changed_only, $tmpfile);
    return $data;
}

##############################################

=head2 save_logs_to_tempfile

  save_logs_to_tempfile($logs)

save logfiles to tempfile

=cut

sub save_logs_to_tempfile {
    my($data) = @_;
    require Encode;
    require File::Temp;
    my($fh, $filename) = File::Temp::tempfile();
    $filename = $filename.'_tmplogs';
    open($fh, '>', $filename) or die('open '.$filename.' failed: '.$!);
    for my $r (@{$data}) {
        print $fh Encode::encode_utf8($r->{'message'}),"\n";
    }
    &close($fh, $filename);
    return($filename);
}

##############################################

=head2 cmd

  cmd($c, $command [, $stdin] [, $print_prefix] [, $detached])

run command and return exit code and output

$command can be either a string like '/bin/prog arg1 arg2' or an
array like ['/bin/prog', 'arg1', 'arg2']

optional print_prefix will print the result on the fly with given prefix.

optional detached will run the command detached in the background

=cut

sub cmd {
    my($c, $cmd, $stdin, $print_prefix, $detached) = @_;

    local $SIG{CHLD} = '';
    local $SIG{PIPE} = 'DEFAULT';
    local $SIG{INT}  = 'DEFAULT';
    local $SIG{TERM} = 'DEFAULT';
    local $ENV{REMOTE_USER} = $c->stash->{'remote_user'} if $c;
    my $groups = [];
    if($c && $c->stash->{'remote_user'}) {
        my $cache = $c->cache->get->{'users'}->{$c->stash->{'remote_user'}};
        $groups = [sort keys %{$cache->{'contactgroups'}}] if($cache && $cache->{'contactgroups'});
    }
    local $ENV{REMOTE_USER_GROUPS} = join(';', @{$groups}) if $c;
    local $ENV{REMOTE_USER_EMAIL} = $c->user->{'email'} if $c && $c->user;
    local $ENV{REMOTE_USER_ALIAS} = $c->user->{'alias'} if $c && $c->user;

    if($detached) {
        confess("stdin not supported for detached commands") if $stdin;
        confess("array cmd not supported for detached commands") if ref $cmd eq 'ARRAY';
        require Thruk::Utils::External;
        Thruk::Utils::External::perl($c, { expr => '`'.$cmd.'`', background => 1 });
        return(0, "cmd started in background");
    }

    my($rc, $output);
    if(ref $cmd eq 'ARRAY') {
        my $prog = shift @{$cmd};
        #&timing_breakpoint('IO::cmd: '.$prog.' <args...>');
        $c->log->debug('running cmd: '.join(' ', @{$cmd})) if $c;
        my($pid, $wtr, $rdr, @lines);
        $pid = open3($wtr, $rdr, $rdr, $prog, @{$cmd});
        if($stdin) {
            print $wtr $stdin,"\n";
            CORE::close($wtr);
        }
        while(POSIX::waitpid($pid, WNOHANG) == 0) {
            my @line = <$rdr>;
            push @lines, @line;
            print $print_prefix.join($print_prefix, @line) if defined $print_prefix;
        }
        $rc = $?;
        my @line = <$rdr>;
        push @lines, @line;
        print $print_prefix.join($print_prefix, @line) if defined $print_prefix;
        chomp($output = join('', @lines) || '');
        # restore original array
        unshift @{$cmd}, $prog;
    } else {
        confess("stdin not supported for string commands") if $stdin;
        #&timing_breakpoint('IO::cmd: '.$cmd);
        $c->log->debug( "running cmd: ". $cmd ) if $c;
        local $SIG{CHLD} = 'IGNORE' if $cmd =~ m/&\s*$/mx;

        # background process?
        if($cmd =~ m/&\s*$/mx) {
            if($cmd !~ m|2>&1|mx) {
                $c->log->warn(longmess("cmd does not redirect output but wants to run in the background, add >/dev/null 2>&1 to: ".$cmd)) if $c;
            }
        }

        $output = `$cmd`;
        $rc = $?;
        # rc will be -1 otherwise when ignoring SIGCHLD
        $rc = 0 if($rc == -1 && $SIG{CHLD} eq 'IGNORE');
    }
    if($rc == -1) {
        $output .= "[".$!."]";
    } else {
        $rc = $rc>>8;
    }
    $c->log->debug( "rc:     ". $rc )     if $c;
    $c->log->debug( "output: ". $output ) if $c;
    #&timing_breakpoint('IO::cmd done');
    return($rc, $output);
}

########################################

=head2 untaint

  untaint($var)

return untainted variable

=cut

sub untaint {
    my($v) = @_;
    if($v && $v =~ /\A(.*)\z/msx) { $v = $1; }
    return($v);
}

##############################################
sub _merge_deep_hash {
    my($hash, $merge) = @_;
    for my $key (keys %{$merge}) {
        if(ref $merge->{$key} eq 'HASH') {
            if(!defined $hash->{$key}) {
                $hash->{$key} = {};
            }
            _merge_deep_hash($hash->{$key}, $merge->{$key});
        }
        elsif(!defined $merge->{$key}) {
            delete $hash->{$key};
        } else {
            $hash->{$key} = $merge->{$key};
        }
    }
    return($hash);
}
##############################################

1;

__END__

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
