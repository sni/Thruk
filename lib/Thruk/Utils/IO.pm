package Thruk::Utils::IO;

=head1 NAME

Thruk::Utils - IO Utilities Collection for Thruk

=head1 DESCRIPTION

IO Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Carp qw/confess longmess/;
use Errno qw(EEXIST);
use Fcntl qw/:DEFAULT :flock :mode SEEK_SET/;
use Cpanel::JSON::XS ();
use POSIX ":sys_wait_h";
use IPC::Open3 qw/open3/;
use IO::Select ();
use File::Slurp qw/read_file/;
use File::Copy qw/move copy/;
use Cwd qw/abs_path/;
use Time::HiRes qw/sleep/;
use Thruk::Utils::Log qw/:all/;
#use Thruk::Timer qw/timing_breakpoint/;

$Thruk::Utils::IO::MAX_LOCK_RETRIES = 20;

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

    require Thruk;
    my $config = Thruk->config;
    # set modes
    if($mode eq 'file') {
        if($cur ne $config->{'mode_file'}) {
            chmod(oct($config->{'mode_file'}), $path) || _warn("failed to ensure permissions (0660/$cur) with uid: ".$>." - ".$<." for ".$path.": ".$!."\n".`ls -dn '$path'`);
        }
    }
    elsif($mode eq 'dir') {
        if($cur ne $config->{'mode_dir'}) {
            chmod(oct($config->{'mode_dir'}), $path) || _warn("failed to ensure permissions (0770/$cur) with uid: ".$>." - ".$<." for ".$path.": ".$!."\n".`ls -dn '$path'`);
        }
    }
    else {
        chmod($mode, $path) || _warn("failed to ensure permissions (".$mode.") with uid: ".$>." - ".$<." for ".$path.": ".$!."\n".`ls -dn '$path'`);
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
    confess("no file") unless $file;

    alarm(30);
    local $SIG{'ALRM'} = sub { confess("timeout while trying to flock(".$mode."): ".$file); };

    # we can only lock files in existing folders
    my $basename = $file;
    $basename    =~ s%/[^/]*$%%gmx;
    if(!-d $basename.'/.') {
        confess("cannot lock $file in non-existing folder: ".$!);
    }

    my $lock_file = $file.'.lock';
    my $lock_fh;
    if($mode eq 'ex') {
        my $locked    = 0;
        my $old_inode = (stat($lock_file))[1];
        my $retrys    = 0;
        while(1) {
            $old_inode = (stat($lock_file))[1] unless $old_inode;
            if(sysopen($lock_fh, $lock_file, O_RDWR|O_EXCL|O_CREAT, 0660)) {
                last;
            }
            # check for orphaned locks
            if($!{EEXIST} && $old_inode) {
                sleep(0.3);
                if(sysopen($lock_fh, $lock_file, O_RDWR, 0660) && flock($lock_fh, LOCK_EX|LOCK_NB)) {
                    my $new_inode = (stat($lock_fh))[1];
                    if($new_inode && $new_inode == $old_inode) {
                        $retrys++;
                        if($retrys > $Thruk::Utils::IO::MAX_LOCK_RETRIES) {
                            # lock seems to be orphaned, continue normally unless in test mode
                            confess("got orphaned lock") if $ENV{'TEST_RACE'};
                            $locked = 1;
                            _warn("recovered orphaned lock for ".$file) unless $ENV{'TEST_IO_NOWARNINGS'};
                            last;
                        }
                        next;
                    }
                    if($new_inode && $new_inode != $old_inode) {
                        $retrys = 0;
                        undef $old_inode;
                    }
                } else {
                    $retrys++;
                    if($retrys > $Thruk::Utils::IO::MAX_LOCK_RETRIES) {
                        unlink($lock_file);
                        # we have to move and copy the file itself, otherwise
                        # the orphaned process may overwrite the file
                        # and the later flock() might hang again
                        copy($file, $file.'.copy') or confess("cannot copy file $file: $!");
                        move($file, $file.'.orphaned') or confess("cannot move file $file to .orphaned: $!");
                        move($file.'.copy', $file) or confess("cannot move file ".$file.".copy: $!");
                        unlink($file.'.orphaned');
                        _warn("removed orphaned lock for ".$file) unless $ENV{'TEST_IO_NOWARNINGS'};
                        $retrys = 0; # start over...
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

    my $fh;
    my $retrys = 0;
    my $err;
    while($retrys < 5) {
        undef $fh;
        eval {
            sysopen($fh, $file, O_RDWR|O_CREAT) or confess("cannot open file ".$file.": ".$!);
            if($mode eq 'ex') {
                flock($fh, LOCK_EX) or confess 'Cannot lock_ex '.$lock_file.': '.$!;
            }
            elsif($mode eq 'sh') {
                flock($fh, LOCK_SH) or confess 'Cannot lock_sh '.$file.': '.$!;
            }
        };
        $err = $@;
        if(!$err && $fh) {
            last;
        }
        $retrys++;
        sleep(0.5);
    }

    if($err) {
        die("failed to lock $file: $err");
    }

    if($retrys > 0) {
        _warn("got lock for ".$file." after ".$retrys." retries") unless $ENV{'TEST_IO_NOWARNINGS'};
    }

    seek($fh, 0, SEEK_SET) or die "Cannot seek ".$file.": $!\n";
    sysseek($fh, 0, SEEK_SET) or die "Cannot sysseek ".$file.": $!\n";

    alarm(0);
    return($fh, $lock_fh);
}

##############################################

=head2 file_unlock

  file_unlock($file, $fh, $lock_fh)

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

  json_store($file, $data, $options)

stores data json encoded

$options can be {
    pretty       => 0/1,       # don't write json into a single line and use human readable intendation
    tmpfile      => <filename> # use this tmpfile while writing new contents
    changed_only => 0/1,       # only write the file if it has changed
    compare_data => "...",     # use this string to compare for changed content
}

=cut

sub json_store {
    my($file, $data, $options) = @_;

    if(defined $options && ref $options ne 'HASH') {
        confess("json_store options have been changed to hash.");
    }

    my $json = Cpanel::JSON::XS->new->utf8;
    $json = $json->pretty if $options->{'pretty'};
    $json = $json->canonical; # keys will be randomly ordered otherwise

    my $write_out;
    if($options->{'changed_only'}) {
        $write_out = $json->encode($data);
        if(defined $options->{'compare_data'}) {
            return 1 if $options->{'compare_data'} eq $write_out;
        }
        elsif(-f $file) {
            my $old = read_file($file);
            return 1 if $old eq $write_out;
        }
    }

    my $tmpfile = $options->{'tmpfile'} // $file.'.new';
    open(my $fh2, '>', $tmpfile) or confess('cannot write file '.$tmpfile.': '.$!);
    print $fh2 ($write_out || $json->encode($data)) or confess('cannot write file '.$tmpfile.': '.$!);
    Thruk::Utils::IO::close($fh2, $tmpfile) or confess("cannot close file ".$tmpfile.": ".$!);

    require Thruk;
    my $config = Thruk->config;
    if($config->{'thruk_author'}) {
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

  json_lock_store($file, $data, [$options])

stores data json encoded. options are passed to json_store.

=cut

sub json_lock_store {
    my($file, $data, $options) = @_;
    my($fh, $lock_fh) = file_lock($file, 'ex');
    json_store($file, $data, $options);
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

    seek($fh, 0, SEEK_SET) or die "Cannot seek ".$file.": $!\n";
    sysseek($fh, 0, SEEK_SET) or die "Cannot sysseek ".$file.": $!\n";

    my $data;
    my $content;
    eval {
        local $/ = undef;
        $content = scalar <$fh>;
        $data    = $json->decode($content);
    };
    my $err = $@;
    if($err) {
        confess("error while reading $file: ".$err);
    }
    return($data, $content) if wantarray;
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
    flock($fh, LOCK_UN);
    CORE::close($fh) or die("cannot close file ".$file.": ".$!);
    return $data;
}

##############################################

=head2 json_lock_patch

  json_lock_patch($file, $patch_data, [$options])

update json data with locking. options are passed to json_store.

=cut

sub json_lock_patch {
    my($file, $patch_data, $options) = @_;
    my($fh, $lock_fh) = file_lock($file, 'ex');
    my $data = json_patch($file, $fh, $patch_data, $options);
    file_unlock($file, $fh, $lock_fh);
    return $data;
}

##############################################

=head2 json_patch

  json_patch($file, $fh, $patch_data, [$options])

update json data. options are passed to json_store.

=cut

sub json_patch {
    my($file, $fh, $patch_data, $options) = @_;
    if(defined $options && ref $options ne 'HASH') {
        confess("json_store options have been changed to hash.");
    }
    confess("got no filehandle") unless defined $fh;
    my($data, $content);
    if(-s $file) {
        ($data, $content) = json_retrieve($file, $fh);
    } else {
        ($data, $content) = ({}, "");
    }
    $data = merge_deep($data, $patch_data);
    $options->{'changed_only'} = 1;
    $options->{'compare_data'} = $content;
    json_store($file, $data, $options);
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

  cmd($command)
  cmd($c, $command [, $stdin] [, $print_prefix] [, $detached])

run command and return exit code and output

$command can be either a string like '/bin/prog arg1 arg2' or an
array like ['/bin/prog', 'arg1', 'arg2']

optional print_prefix will print the result on the fly with given prefix.

optional detached will run the command detached in the background

=cut

sub cmd {
    my($c, $cmd, $stdin, $print_prefix, $detached, $no_decode) = @_;
    if(defined $c && !defined $cmd) {
        $cmd = $c;
        $c = undef;
    }

    local $SIG{INT}  = 'DEFAULT';
    local $SIG{TERM} = 'DEFAULT';
    local $SIG{PIPE} = 'DEFAULT';
    local $ENV{REMOTE_USER} = $c->stash->{'remote_user'} if $c;
    my $groups = [];
    if($c && $c->user_exists) {
        $groups = $c->user->{'groups'};
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

    require Thruk::Utils;

    my($rc, $output);
    if(ref $cmd eq 'ARRAY') {
        my $prog = shift @{$cmd};
        #&timing_breakpoint('IO::cmd: '.$prog.' <args...>');
        _debug('running cmd: '.join(' ', @{$cmd})) if $c;
        my($pid, $wtr, $rdr, @lines);
        $pid = open3($wtr, $rdr, $rdr, $prog, @{$cmd});
        my $sel = IO::Select->new;
        $sel->add($rdr);
        if($stdin) {
            print $wtr $stdin,"\n";
        }
        CORE::close($wtr);

        while(my @ready = $sel->can_read) {
            foreach my $fh (@ready) {
                my $line;
                my $len = sysread $fh, $line, 8192;
                if(!defined $len){
                    die "Error from child: $!\n";
                } elsif ($len == 0){
                    $sel->remove($fh);
                    next;
                } else {
                    push @lines, $line;
                    print $print_prefix, $line if defined $print_prefix;
                }
            }
        }
        # reap process
        POSIX::waitpid($pid, 0);
        $rc = $?;
        @lines = grep defined, @lines;
        $output = join('', @lines) // '';
        $output = Thruk::Utils::decode_any($output) unless $no_decode;
        # restore original array
        unshift @{$cmd}, $prog;
    } else {
        confess("stdin not supported for string commands") if $stdin;
        #&timing_breakpoint('IO::cmd: '.$cmd);
        _debug( "running cmd: ". $cmd ) if $c;
        local $SIG{CHLD} = 'IGNORE' if $cmd =~ m/&\s*$/mx; # let the system reap the childs, we don't care

        # background process?
        if($cmd =~ m/&\s*$/mx) {
            if($cmd !~ m|2>&1|mx) {
                _warn(longmess("cmd does not redirect output but wants to run in the background, add >/dev/null 2>&1 to: ".$cmd)) if $c;
            }
        }

        $output = `$cmd`;
        $output = Thruk::Utils::decode_any($output) unless $no_decode;
        $rc = $?;
        # rc will be -1 otherwise when ignoring SIGCHLD
        $rc = 0 if($rc == -1 && defined $SIG{CHLD} && $SIG{CHLD} eq 'IGNORE');
    }
    if($rc == -1) {
        $output .= "[".$!."]";
    } else {
        $rc = $rc>>8;
    }
    _debug( "rc:     ". $rc )     if $c;
    _debug( "output: ". $output ) if $c;
    #&timing_breakpoint('IO::cmd done');
    return($rc, $output) if wantarray;
    return($output);
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

########################################

=head2 realpath

  realpath($file)

return realpath of this file

=cut
sub realpath {
    my($file) = @_;
    return(abs_path($file));
}

########################################

=head2 touch

  touch($file)

create file if not exists and update timestamp

=cut
sub touch {
    my($file) = @_;
    &write($file, "", time(), 1);
    return;
}

##############################################

=head2 merge_deep

  merge_deep($var, $merge_var)

returns merged variables

merge will be as follows:

    - hash keys will be replaced with the last level of hash keys
    - arrays will will be replaced completly, unless $merge_var is a hash of
      the form: { array_index => replacement }
    - everything else will be replaced

=cut
sub merge_deep {
    my($var, $merge) = @_;
    if(_is_hash($var) && _is_hash($merge)) {
        for my $key (keys %{$merge}) {
            if(!defined $merge->{$key}) {
                delete $var->{$key};
            }
            elsif(!defined $var->{$key}) {
                # remove all undefined values from $merge
                if(_is_hash($merge->{$key})) {
                    $var->{$key} = {};
                    $var->{$key} = merge_deep($var->{$key}, $merge->{$key});
                } else {
                    $var->{$key} = $merge->{$key};
                }
            } else {
                $var->{$key} = merge_deep($var->{$key}, $merge->{$key});
            }
        }
        return($var);
    }
    if(ref $var eq 'ARRAY' && _is_hash($merge)) {
        for my $key (sort keys %{$merge}) {
            if(!defined $merge->{$key}) {
                $var->[$key] = undef;
            }
            elsif(!defined $var->[$key]) {
                $var->[$key] = $merge->{$key};
            } else {
                $var->[$key] = merge_deep($var->[$key], $merge->{$key});
            }
        }
        # remove undefs
        @{$var} = grep defined, @{$var};
        return($var);
    }
    if(ref $var eq 'ARRAY' && ref $merge eq 'ARRAY') {
        for my $x (0..(scalar @{$merge} -1)) {
            if(ref $merge->[$x] && ref $var->[$x]) {
                $var->[$x] = merge_deep($var->[$x], $merge->[$x]);
            }
            else {
                $var->[$x] = $merge->[$x];
            }
        }
        # remove undefs
        @{$var} = grep defined, @{$var};
        return($var);
    }
    return($merge);
}

##############################################
# returns true if $var is a hash
sub _is_hash {
    my($o) = @_;
    # normal hash ref
    return 1 if(ref $o eq 'HASH');
    # blessed objects
    return 1 if(UNIVERSAL::isa($o, 'HASH'));
    return 0;
}

##############################################

1;
