package Thruk::Utils::IO;

=head1 NAME

Thruk::Utils - IO Utilities Collection for Thruk

=head1 DESCRIPTION

IO Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Carp qw/confess/;
use Fcntl qw/:mode :flock/;
use JSON::XS ();
use POSIX ":sys_wait_h";
use IPC::Open3 qw/open3/;
use File::Slurp qw/read_file/;
use File::Copy qw/move/;
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
    my $rc = CORE::close($fh) or confess("cannot write to $filename: $!");
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
        next if -d $dirname;
        my $path = '';
        for my $part (split/(\/)/mx, $dirname) {
            $path .= $part;
            next if $path eq '';
            Thruk::Utils::IO::mkdir($path) unless -d $path;
        }
    }
    return 1;
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

=head2 json_lock_store

  json_lock_store($file, $data, [$pretty], [$changed_only])

stores data json encoded

=cut

sub json_lock_store {
    my($file, $data, $pretty, $changed_only, $tmpfile) = @_;

    my $json = JSON::XS->new->utf8;
    $json = $json->pretty if $pretty;
    $json = $json->canonical; # keys will be randomly ordered otherwise

    my $write_out;
    if($changed_only && -f $file) {
        $write_out = $json->encode($data);
        my $old = read_file($file);
        return 1 if $old eq $write_out;
    }

    $tmpfile = $file.'.new' unless $tmpfile;
    open(my $fh, '>', $file) or confess('cannot write file '.$file.': '.$!);
    alarm(30);
    local $SIG{'ALRM'} = sub { confess("timeout while trying to lock_ex: ".$file); };
    flock($fh, LOCK_EX) or confess 'Cannot lock '.$file.': '.$!;
    open(my $fh2, '>', $tmpfile) or confess('cannot write file '.$tmpfile.': '.$!);
    print $fh2 ($write_out || $json->encode($data)) or confess('cannot write file '.$tmpfile.': '.$!);
    Thruk::Utils::IO::close($fh2, $tmpfile) or confess("cannot close file ".$tmpfile.": ".$!);
    move($tmpfile, $file) or confess("cannot replace $file with $tmpfile: $!");
    alarm(0);
    return 1;
}

##############################################

=head2 json_lock_retrieve

  json_lock_retrieve($file)

retrieve json data

=cut

sub json_lock_retrieve {
    my($file) = @_;

    my $json = JSON::XS->new->utf8;
    $json->relaxed();
    local $/=undef;

    open(my $fh, '<', $file) or die('cannot read file '.$file.': '.$!);
    alarm(30);
    local $SIG{'ALRM'} = sub { die("timeout while trying to lock_sh: ".$file); };
    flock($fh, LOCK_SH) or die 'Cannot lock '.$file.': '.$!;
    my $data;
    eval {
        $data = $json->decode(<$fh>);
    };
    my $err = $@;
    CORE::close($fh) or die("cannot close file ".$file.": ".$!);
    alarm(0);
    if($err && !$data) {
        die("error while reading $file: ".$@);
    }
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
    open($fh, '>', $filename) or die('open '.$filename.' failed: '.$!);
    for my $r (@{$data}) {
        print $fh Encode::encode_utf8($r->{'message'}),"\n";
    }
    &close($fh, $filename) or die("cannot close file ".$filename.": ".$!);
    return($filename);
}

##############################################

=head2 cmd

  cmd($c, $command [, $stdin])

run command and return exit code and output

$command can be either a string like '/bin/prog arg1 arg2' or an
array like ['/bin/prog', 'arg1', 'arg2']

=cut

sub cmd {
    my($c, $cmd, $stdin) = @_;

    local $SIG{CHLD} = '';
    local $SIG{PIPE} = 'DEFAULT';
    local $SIG{INT}  = 'DEFAULT';
    local $SIG{TERM} = 'DEFAULT';
    local $ENV{REMOTE_USER}=$c->stash->{'remote_user'} if $c;
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
            push @lines, <$rdr>;
        }
        $rc = $?;
        push @lines, <$rdr>;
        chomp($output = join('', @lines) || '');
        # restore original array
        unshift @{$cmd}, $prog;
    } else {
        confess("stdin not supported for string commands") if $stdin;
        #&timing_breakpoint('IO::cmd: '.$cmd);
        $c->log->debug( "running cmd: ". $cmd ) if $c;
        $output = `$cmd 2>&1`;
        $rc = $?;
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
    if($v =~ /\A(.*)\z/msx) { $v = $1; }
    return($v);
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
