package Thruk::Utils::IO;

=head1 NAME

Thruk::Utils::IO - IO Utilities Collection for Thruk

=head1 DESCRIPTION

IO Utilities Collection for Thruk

=cut

use warnings;
use strict;
use Carp qw/confess longmess/;
use Cpanel::JSON::XS ();
use Cwd qw/abs_path/;
use Errno qw(EEXIST);
use Fcntl qw/:DEFAULT :flock :mode SEEK_SET/;
use File::Copy qw/move copy/;
use IO::Select ();
use IPC::Open3 qw/open3/;
use POSIX ":sys_wait_h";
use Scalar::Util 'blessed';
use Time::HiRes qw/sleep gettimeofday tv_interval/;

use Thruk::Base ();
use Thruk::Timer qw/timing_breakpoint/;
use Thruk::Utils::Log qw/:all/;

$Thruk::Utils::IO::MAX_LOCK_RETRIES = 20;

##############################################
eval {
    require Clone;
};
if($@) {
    require Storable;
}

##############################################
=head1 METHODS

=head2 close

  close($fh, $filename, $just_close)

close filehandle and ensure permissions and ownership

=cut
sub close {
    my($fh, $filename, $just_close) = @_;
    my $t1 = [gettimeofday];
    my $rc = CORE::close($fh);
    confess("cannot write to $filename: $!") unless $rc;
    ensure_permissions('file', $filename) unless $just_close;

    my $elapsed = tv_interval($t1);
    my $c = $Thruk::Globals::c || undef;
    $c->stash->{'total_io_time'} += $elapsed if $c;

    return $rc;
}

##############################################

=head2 mkdir

  mkdir($dirname)

create folder and ensure permissions and ownership

=cut

sub mkdir {
    my(@dirs) = @_;

    my $t1 = [gettimeofday];

    for my $dirname (@dirs) {
        if(!CORE::mkdir($dirname)) {
            my $err = $!;
            confess("failed to create ".$dirname.": ".$err) unless -d $dirname;
        }
        ensure_permissions('dir', $dirname);
    }

    my $elapsed = tv_interval($t1);
    my $c = $Thruk::Globals::c || undef;
    $c->stash->{'total_io_time'} += $elapsed if $c;
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
            &mkdir($path) unless -d $path.'/.';
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
    my $t1 = [gettimeofday];

    open(my $fh, '<', $path) || die "Can't open file ".$path.": ".$!;
    local $/ = undef;
    my $content = <$fh>;
    CORE::close($fh);

    my $elapsed = tv_interval($t1);
    my $c = $Thruk::Globals::c || undef;
    $c->stash->{'total_io_time'} += $elapsed if $c;
    return($content);
}

##############################################

=head2 read_decoded

  read_decoded($path)

read file and return decoded content

=cut

sub read_decoded {
    require Thruk::Utils::Encode;
    return Thruk::Utils::Encode::decode_any(&read(@_));
}

##############################################

=head2 saferead

  saferead($path)

read file and return content or undef in case it cannot be read

=cut

sub saferead {
    my($path) = @_;
    my $t1 = [gettimeofday];

    open(my $fh, '<', $path) || return;
    local $/ = undef;
    my $content = <$fh>;
    CORE::close($fh);

    my $elapsed = tv_interval($t1);
    my $c = $Thruk::Globals::c || undef;
    $c->stash->{'total_io_time'} += $elapsed if $c;

    return($content);
}

##############################################

=head2 read_as_list

  read_as_list($path)

read file and return content as array

=cut

sub read_as_list {
    my($path) = @_;
    my $t1 = [gettimeofday];

    my @res;
    open(my $fh, '<', $path) || die "Can't open file ".$path.": ".$!;
    chomp(@res = <$fh>);
    CORE::close($fh);

    my $elapsed = tv_interval($t1);
    my $c = $Thruk::Globals::c || undef;
    $c->stash->{'total_io_time'} += $elapsed if $c;

    return(@res);
}

##############################################

=head2 saferead_as_list

  saferead_as_list($path)

read file and return content as array, return empty list if open fails

=cut

sub saferead_as_list {
    my($path) = @_;
    my $t1 = [gettimeofday];

    my @res;
    open(my $fh, '<', $path) || return(@res);
    chomp(@res = <$fh>);
    CORE::close($fh);

    my $elapsed = tv_interval($t1);
    my $c = $Thruk::Globals::c || undef;
    $c->stash->{'total_io_time'} += $elapsed if $c;

    return(@res);
}

##############################################

=head2 write

  write($path, $content, [ $mtime ], [ $append ])

creates file and ensure permissions

=cut

sub write {
    my($path,$content,$mtime,$append) = @_;
    my $t1 = [gettimeofday];

    my $mode = $append ? '>>' : '>';
    open(my $fh, $mode, $path) or confess('cannot create file '.$path.': '.$!);
    print $fh $content;
    &close($fh, $path) or confess("cannot close file ".$path.": ".$!);
    if(Time::HiRes->can('utime')) {
        Time::HiRes::utime($mtime, $mtime, $path) if $mtime;
    } else {
        utime($mtime, $mtime, $path) if $mtime;
    }

    my $elapsed = tv_interval($t1);
    my $c = $Thruk::Globals::c || undef;
    $c->stash->{'total_io_time'} += $elapsed if $c;

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

    require Thruk::Config;
    my $config = Thruk::Config::get_config();

    confess("need a path") unless defined $path;
    return unless -e $path;

    my @stat = stat(_);
    my $cur  = sprintf "%04o", S_IMODE($stat[2]);

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

=head2 file_rlock

  file_rlock($file)

locks given file in shared / readonly mode. Returns filehandle.

=cut
sub file_rlock {
    my($file) = @_;
    confess("no file") unless $file;
    my $t1 = [gettimeofday];

    alarm(10);
    local $SIG{'ALRM'} = sub { confess("timeout while trying to shared flock: ".$file."\n"._fuser($file)); };

    my $fh;
    my $retrys = 0;
    my $err;
    while($retrys < 3) {
        undef $fh;
        eval {
            alarm(10);
            sysopen($fh, $file, O_RDONLY) or confess("cannot open file ".$file.": ".$!);
            flock($fh, LOCK_SH) or confess 'Cannot lock_sh '.$file.': '.$!;
        };
        $err = $@;
        alarm(0);
        if(!$err && $fh) {
            last;
        }
        $retrys++;
        sleep(0.5);
    }
    alarm(0);

    if($err) {
        die("failed to shared flock $file: $err");
    }

    if($retrys > 0) {
        _warn("got lock for ".$file." after ".$retrys." retries") unless $ENV{'TEST_IO_NOWARNINGS'};
    }

    my $elapsed = tv_interval($t1);
    my $c = $Thruk::Globals::c || undef;
    $c->stash->{'total_io_lock'} += $elapsed if $c;

    return($fh);
}

##############################################

=head2 file_lock

  file_lock($file)

locks given file in read/write mode. Returns locked filehandle and lock file handle.

=cut

sub file_lock {
    my($file, $mode) = @_;
    confess("no file") unless $file;
    if($mode && $mode eq 'sh') { return file_rlock($file); }

    my $t1 = [gettimeofday];
    alarm(20);
    local $SIG{'ALRM'} = sub { confess("timeout while trying to excl. flock: ".$file."\n"._fuser($file)); };

    # we can only lock files in existing folders
    my $basename = $file;
    if($basename !~ m|^[\.\/]|mx) { $basename = './'.$basename; }
    $basename    =~ s%/[^/]*$%%gmx;
    if(!-d $basename.'/.') {
        require Thruk::Config;
        my $config = Thruk::Config::get_config();
        my $match = sprintf("^(\Q%s\E|\Q%s\E)", $config->{'var_path'}, $config->{'tmp_path'});
        if($basename =~ m/$match/mx) {
            mkdir_r($basename);
        } else {
            confess("cannot lock $file in non-existing folder: ".$!);
        }
    }

    my $lock_file = $file.'.lock';
    my $lock_fh;
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
        flock($lock_fh, LOCK_EX) || confess('Cannot lock_ex '.$lock_file.': '.$!."\n"._fuser($lock_file));
    }

    my $fh;
    $retrys = 0;
    my $err;
    while($retrys < 3) {
        alarm(10);
        undef $fh;
        eval {
            sysopen($fh, $file, O_RDWR|O_CREAT) || confess("cannot open file ".$file.": ".$!);
            flock($fh, LOCK_EX) || confess('Cannot lock_ex '.$file.': '.$!."\n"._fuser($file));
        };
        $err = $@;
        alarm(0);
        if(!$err && $fh) {
            last;
        }
        $retrys++;
        sleep(0.5);
    }
    alarm(0);

    if($err) {
        die("failed to lock $file: $err");
    }

    if($retrys > 0) {
        _warn("got lock for ".$file." after ".$retrys." retries") unless $ENV{'TEST_IO_NOWARNINGS'};
    }

    my $elapsed = tv_interval($t1);
    my $c = $Thruk::Globals::c || undef;
    $c->stash->{'total_io_lock'} += $elapsed if $c;

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
    pretty                  => 0/1,         # don't write json into a single line and use human readable intendation
    tmpfile                 => <filename>   # use this tmpfile while writing new contents
    changed_only            => 0/1,         # only write the file if it has changed
    compare_data            => "...",       # use this string to compare for changed content
    skip_ensure_permissions => 0/1          # skip running ensure_permissions after write
    skip_validate           => 0/1          # skip file validation (author only)
    skip_config             => 0/1          # skip all steps which reqire thruk config
}

=cut

sub json_store {
    my($file, $data, $options) = @_;

    if(defined $options && ref $options ne 'HASH') {
        confess("json_store options have been changed to hash.");
    }

    if($options->{'skip_config'}) {
        $options->{'skip_ensure_permissions'} = 1;
        $options->{'skip_validate'}           = 1;
    }

    my $json = Cpanel::JSON::XS->new->utf8;
    $json = $json->pretty if $options->{'pretty'};
    $json = $json->canonical; # keys will be randomly ordered otherwise
    $json = $json->convert_blessed;

    my $write_out;
    if($options->{'changed_only'}) {
        $write_out = $json->encode($data);
        if(defined $options->{'compare_data'}) {
            return 1 if $options->{'compare_data'} eq $write_out;
        }
        elsif(-f $file) {
            my $old = &read($file);
            return 1 if $old eq $write_out;
        }
    }

    my $t1 = [gettimeofday];

    my $tmpfile = $options->{'tmpfile'} // $file.'.new';
    open(my $fh, '>', $tmpfile) or confess('cannot write file '.$tmpfile.': '.$!);
    print $fh ($write_out || $json->encode($data)) or confess('cannot write file '.$tmpfile.': '.$!);
    if($options->{'skip_ensure_permissions'}) {
        CORE::close($fh) || confess("cannot close file ".$tmpfile.": ".$!);
    } else {
        &close($fh, $tmpfile) || confess("cannot close file ".$tmpfile.": ".$!);
    }

    if(!$options->{'skip_validate'}) {
        require Thruk::Config;
        my $config = Thruk::Config::get_config();
        if($config->{'thruk_author'}) {
            eval {
                my $test = $json->decode(&read($tmpfile));
            };
            confess("json_store failed to write a valid file $tmpfile: ".$@) if $@;
        }
    }


    move($tmpfile, $file) or confess("cannot replace $file with $tmpfile: $!");

    my $elapsed = tv_interval($t1);
    my $c = $Thruk::Globals::c || undef;
    $c->stash->{'total_io_time'} += $elapsed if $c;

    return 1;
}

##############################################

=head2 json_lock_store

  json_lock_store($file, $data, [$options])

stores data json encoded. options are passed to json_store.

=cut

sub json_lock_store {
    my($file, $data, $options) = @_;
    my($fh, $lock_fh);
    eval {
        ($fh, $lock_fh) = file_lock($file);
        json_store($file, $data, $options);
    };
    my $err = $@;
    file_unlock($file, $fh, $lock_fh) if($fh || $lock_fh);
    confess($err) if $err;
    return 1;
}

##############################################

=head2 json_retrieve

  json_retrieve($file, $fh, [$lock_fh])

retrieve json data

=cut

sub json_retrieve {
    my($file, $fh, $lock_fh) = @_;
    confess("got no filehandle") unless defined $fh;

    our $jsonreader;
    if(!$jsonreader) {
        $jsonreader = Cpanel::JSON::XS->new->utf8;
        $jsonreader->relaxed();
    }

    my $t1 = [gettimeofday];

    seek($fh, 0, SEEK_SET) or die "Cannot seek ".$file.": $!\n";

    my $data;
    my $content;
    eval {
        local $/ = undef;
        $content = scalar <$fh>;
        $data    = $jsonreader->decode($content);
    };
    my $err = $@;
    if($err) {
        # try to unlock
        flock($fh, LOCK_UN);
        if($lock_fh) {
            eval {
                file_unlock($file, $fh, $lock_fh);
            };
        }
        confess("error while reading $file: ".$err);
    }

    my $elapsed = tv_interval($t1);
    my $c = $Thruk::Globals::c || undef;
    $c->stash->{'total_io_time'} += $elapsed if $c;

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
    my($data, $fh);
    eval {
        $fh   = file_rlock($file);
        $data = json_retrieve($file, $fh);
        CORE::close($fh) or die("cannot close file ".$file.": ".$!);
        undef $fh; # closing the file removes the lock
    };
    my $err = $@;
    flock($fh, LOCK_UN) if $fh;
    confess($err) if $err;
    return $data;
}

##############################################

=head2 json_lock_patch

  json_lock_patch($file, $patch_data, [$options])

update json data with locking. options are passed to json_store.

=cut

sub json_lock_patch {
    my($file, $patch_data, $options) = @_;
    my($fh, $lock_fh, $data);
    eval {
        ($fh, $lock_fh) = file_lock($file);
        $options->{'lock_fh'} = $lock_fh;
        $data = json_patch($file, $fh, $patch_data, $options);
    };
    my $err = $@;
    file_unlock($file, $fh, $lock_fh) if($fh || $lock_fh);
    confess($err) if $err;
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
        ($data, $content) = json_retrieve($file, $fh, $options->{'lock_fh'});
    } else {
        if(!$options->{'allow_empty'}) {
            confess("attempt to patch empty file without allow_empty option: $file");
        }
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

    my $t1 = [gettimeofday];

    my($fh, $filename) = File::Temp::tempfile();
    $filename = $filename.'_tmplogs';
    open($fh, '>', $filename) or die('open '.$filename.' failed: '.$!);
    for my $r (@{$data}) {
        print $fh Encode::encode_utf8($r->{'message'}),"\n";
    }
    &close($fh, $filename);

    my $elapsed = tv_interval($t1);
    my $c = $Thruk::Globals::c || undef;
    $c->stash->{'total_io_time'} += $elapsed if $c;

    return($filename);
}

##############################################

=head2 cmd

  cmd($command, [ $options ])

run command and return exit code and output

$command can be either a string like '/bin/prog arg1 arg2' or an
array like ['/bin/prog', 'arg1', 'arg2']

options are:

    - stdin                 text used as stdin for the command
    - print_prefix          print the result on the fly with given prefix.
    - output_prefix         add prefix to output (can be a callback)
    - detached              run the command detached in the background
    - no_decode             skip decoding
    - timeout               kill the command after the timeout (seconds)
    - no_touch_signals      do not change signal handler

=cut

## no critic
sub cmd {
## use critic
    my($cmd, $options) = @_;

    # REMOVE AFTER: 01.01.2027
    if(scalar @_ > 2 || ref $options ne 'HASH') {
       return(_cmd_old(@_));
    }
    # end REMOVE...
    # enable check again
    #confess("cmd options have been migrated to hash") if(scalar @_ > 2);

    $options = {} unless defined $options;
    Thruk::Base::validate_options($options, [qw/stdin print_prefix output_prefix detached no_decode timeout no_touch_signals/]);

    my $c = $Thruk::Globals::c || undef;
    my $t1 = [gettimeofday];

    if($options->{'timeout'}) {
        setpgrp();
        alarm($options->{'timeout'});
        delete $options->{'timeout'};
        local $SIG{'ALRM'} = sub { die("timeout"); };
        my @res;
        eval {
            @res = &cmd($cmd, $options);
        };
        my $err = $@;
        my $remain = alarm(0);
        if($err) {
            if($c) {
                if($remain <= 0 || $err =~ m/timeout/mx) {
                    _warn(longmess("command timed out after ".$options->{'timeout'}." seconds"));
                } else {
                    _warn(longmess("command errror: ".$err));
                }
            }
            local $SIG{INT} = 'IGNORE';
            kill("-INT", $$);
            return(-1, $err);
        }
        return(@res);
    }

    $c->stats->profile(begin => "IO::cmd") if $c;

    local $SIG{INT}  = 'DEFAULT' unless $options->{'no_touch_signals'};
    local $SIG{TERM} = 'DEFAULT' unless $options->{'no_touch_signals'};
    local $SIG{PIPE} = 'DEFAULT' unless $options->{'no_touch_signals'};
    local $ENV{REMOTE_USER} = $c->stash->{'remote_user'} if $c;
    my $groups = [];
    if($c && $c->user_exists) {
        $groups = $c->user->{'groups'};
    }
    local $ENV{REMOTE_USER_GROUPS} = join(';', @{$groups}) if $c;
    local $ENV{REMOTE_USER_EMAIL} = $c->user->{'email'} if $c && $c->user;
    local $ENV{REMOTE_USER_ALIAS} = $c->user->{'alias'} if $c && $c->user;
    local $ENV{THRUK_REQ_URL}     = "".$c->req->uri if $c;

    if($options->{'detached'}) {
        confess("stdin not supported for detached commands") if $options->{'stdin'};
        confess("array cmd not supported for detached commands") if ref $cmd eq 'ARRAY';
        require Thruk::Utils::External;
        Thruk::Utils::External::perl($c, { expr => '`'.$cmd.'`', background => 1 });
        $c->stats->profile(end => "IO::cmd") if $c;
        return(0, "cmd started in background");
    }

    require Thruk::Utils::Encode unless $options->{'no_decode'};

    my($rc, $output);
    if(ref $cmd eq 'ARRAY') {
        my $prog = shift @{$cmd};
        &timing_breakpoint('IO::cmd: '.$prog.' <args...>');
        _debug('running cmd: '.join(' ', @{$cmd})) if $c;
        my($pid, $wtr, $rdr, @lines);
        $pid = open3($wtr, $rdr, $rdr, $prog, @{$cmd});
        my $sel = IO::Select->new;
        $sel->add($rdr);
        if($options->{'stdin'}) {
            print $wtr $options->{'stdin'},"\n";
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
                    if($options->{'output_prefix'}) {
                        my $prefix = $options->{'output_prefix'};
                        if(ref $prefix eq 'CODE') {
                            $prefix = &{$prefix};
                        }
                        $line = $prefix.$line;
                    }
                    push @lines, $line;
                    print $options->{'print_prefix'}, $line if defined $options->{'print_prefix'};
                }
            }
        }
        # reap process
        POSIX::waitpid($pid, 0);
        $rc = $?;
        @lines = grep defined, @lines;
        $output = join('', @lines) // '';
        $output = Thruk::Utils::Encode::decode_any($output) unless $options->{'no_decode'};
        # restore original array
        unshift @{$cmd}, $prog;
    } else {
        confess("stdin not supported for string commands") if $options->{'stdin'};
        &timing_breakpoint('IO::cmd: '.$cmd);
        _debug( "running cmd: ". $cmd ) if $c;

        # background process?
        if($cmd =~ m/&\s*$/mx) {
            local $SIG{CHLD} = 'IGNORE'; # let the system reap the childs, we don't care
            if($cmd !~ m|2>&1|mx) {
                _warn(longmess("cmd does not redirect output but wants to run in the background, add >/dev/null 2>&1 to: ".$cmd)) if $c;
            }
            $output = `$cmd`;
            $rc = $?;
            # rc will be -1 otherwise when ignoring SIGCHLD
            $rc = 0 if $rc == -1;
        } else {
            $output = `$cmd`;
            $rc     = $?;
            $output = Thruk::Utils::Encode::decode_any($output) unless $options->{'no_decode'};
        }
    }

    if($rc == -1) {
        $output .= "[".$!."]";
    } else {
        $rc = $rc>>8;
    }
    _debug( "rc:     ". $rc )     if $c;
    _debug( "output: ". $output ) if $c;
    &timing_breakpoint('IO::cmd done');
    $c->stats->profile(end => "IO::cmd") if $c;

    my $elapsed = tv_interval($t1);
    $c = $c || $Thruk::Globals::c || undef;
    $c->stash->{'total_io_cmd'} += $elapsed if $c;

    return($rc, $output) if wantarray;
    return($output);
}

########################################
sub _cmd_old {
    my($cmd, $stdin, $print_prefix, $detached, $no_decode, $timeout, $no_touch_signals) = @_;
    # REMOVE AFTER: 01.01.2027
    # backwards compatible options (remove blessed import when removing this...)
    if($cmd && ref $cmd && blessed($cmd) && $cmd->isa("Thruk::Context")) {
        shift @_;
        return(_cmd_old(@_));
    }
    my $options = {
        stdin                 => $stdin,
        print_prefix          => $print_prefix,
        detached              => $detached,
        no_decode             => $no_decode,
        timeout               => $timeout,
        no_touch_signals      => $no_touch_signals,
    };
    return(&cmd($cmd, $options));
    # end REMOVE...
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
    &write($file, "", Time::HiRes::time(), 1);
    return;
}

##############################################

=head2 merge_deep

  merge_deep($var, $merge_var)

returns merged variables

merge will be as follows:

    - hash keys will be replaced with the last level of hash keys
    - arrays will will be replaced completely, unless $merge_var is a hash of
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

########################################

=head2 get_memory_usage

  get_memory_usage([$pid])

return memory usage of pid or own process if no pid specified

=cut

sub get_memory_usage {
    my($pid) = @_;
    my $t1 = [gettimeofday];

    $pid = $$ unless defined $pid;
    my $page_size_in_kb = 4;
    if(sysopen(my $fh, "/proc/$pid/statm", 0)) {
        sysread($fh, my $line, 255) or die $!;
        CORE::close($fh);
        my(undef, $rss) = split(/\s+/mx, $line,  3);
        return(sprintf("%.2f", ($rss*$page_size_in_kb)/1024));
    }
    my $rsize;
    open(my $ph, '-|', "ps -p $pid -o rss") or die("ps failed: $!");
    while(my $line = <$ph>) {
        if($line =~ m/(\d+)/mx) {
            $rsize = sprintf("%.2f", $1/1024);
        }
    }
    CORE::close($ph);

    my $elapsed = tv_interval($t1);
    my $c = $Thruk::Globals::c || undef;
    $c->stash->{'total_io_time'} += $elapsed if $c;

    return($rsize);
}

###################################################

=head2 find_files

  find_files($folder, $pattern, $skip_symlinks)

return list of files for folder and pattern (symlinks will be skipped)

=cut

sub find_files {
    my($dir, $match, $skip_symlinks) = @_;
    my @files;
    $dir =~ s/\/$//gmxo;

    # symlinks
    if($skip_symlinks && -l $dir) {
        return([]);
    }
    # not a directory?
    if(!-d $dir."/.") {
        if(defined $match) {
            return([]) unless $dir =~ m/$match/mx;
        }
        return([$dir]);
    }

    my @tmpfiles;
    opendir(my $dh, $dir."/.") or confess("cannot open directory $dir: $!");
    while(my $file = readdir $dh) {
        next if $file eq '.';
        next if $file eq '..';
        push @tmpfiles, $file;
    }
    closedir $dh;

    for my $file (@tmpfiles) {
        # follow sub directories
        if(-d sprintf("%s/%s/.", $dir, $file)) {
            push @files, @{find_files($dir."/".$file, $match, $skip_symlinks)};
        } else {
            # if its a file, make sure it matches our pattern
            if(defined $match) {
                my $test = $dir."/".$file;
                next unless $test =~ m/$match/mx;
            }

            push @files, $dir."/".$file;
        }
    }

    return \@files;
}

##############################################

=head2 all_perl_files

  all_perl_files(@dirs)

return list of all perl files for given folders

=cut
sub all_perl_files {
    my(@dirs) = @_;
    my @files;
    for my $dir (@dirs) {
        my $files = find_files($dir);
        for my $file (@{$files}) {
            if($file =~ m/\.(pl|pm)$/mx) {
                push @files, $file;
                next;
            }
            my $content = &read($file);

            if($content =~ m%\#\!(/usr|)/bin/perl%mx || $content =~ m|\Qexec perl -x\E|mx) {
                push @files, $file;
                next;
            }
            if($file =~ m/\.t$/mx && $content =~ m|^\s*use\s+strict|mx) {
                push @files, $file;
                next;
            }
        }
    }
    return(@files);
}

##############################################
sub _fuser {
    my($file) = @_;
    my $out = cmd(['fuser', '-v', $file]);
    return($out);
}

##############################################

=head2 dclone

    dclone($obj)

deep clones any object

=cut
sub dclone {
    my($obj) = @_;
    return unless defined $obj;

    # use faster Clone module if available
    return(Clone::clone($obj)) if $INC{'Clone.pm'};

    # else use Storable
    return(Storable::dclone($obj));
}

##############################################

1;
