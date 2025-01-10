package Thruk::Utils::IO;

=head1 NAME

Thruk::Utils::IO - IO Utilities Collection for Thruk

=head1 DESCRIPTION

IO Utilities Collection for Thruk

=cut

use warnings;
use strict;
use Carp qw/confess longmess/;
use IO::Select ();
use IPC::Open3 qw/open3/;
use POSIX ":sys_wait_h";
use Scalar::Util 'blessed';
use Time::HiRes qw/gettimeofday tv_interval/;

use Thruk::Base ();
use Thruk::Config 'noautoload';
use Thruk::Timer qw/timing_breakpoint/;
use Thruk::Utils::IO::LocalFS ();
use Thruk::Utils::Log qw/:all/;

$Thruk::Utils::IO::MAX_LOCK_RETRIES = 20;
$Thruk::Utils::IO::var_path = undef;
$Thruk::Utils::IO::var_db   = undef;

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
    my(undef, $filename) = @_;
    return(handle_io("close", 1, $filename, \@_));
}

##############################################

=head2 mkdir

  mkdir($dirname)

create folder and ensure permissions and ownership

=cut

sub mkdir {
    my(@dirs) = @_;

    for my $dirname (@dirs) {
        handle_io("mkdir", 0, $dirname, [$dirname]);
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
        handle_io("mkdir_r", 0, $dirname, [$dirname]);
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
    return(handle_io("read", 0, $path, \@_));
}

##############################################

=head2 read_decoded

  read_decoded($path)

read file and return decoded content

=cut

sub read_decoded {
    my($path) = @_;
    return(handle_io("read_decoded", 0, $path, \@_));
}

##############################################

=head2 saferead

  saferead($path)

read file and return content or undef in case it cannot be read

=cut

sub saferead {
    my($path) = @_;
    return(handle_io("saferead", 0, $path, \@_));
}

##############################################

=head2 saferead_decoded

  saferead_decoded($path)

safe read file and return decoded content

=cut

sub saferead_decoded {
    my($path) = @_;
    return(handle_io("saferead_decoded", 0, $path, \@_));
}

##############################################

=head2 read_as_list

  read_as_list($path)

read file and return content as array

=cut

sub read_as_list {
    my($path) = @_;
    return(handle_io("read_as_list", 0, $path, \@_));
}

##############################################

=head2 saferead_as_list

  saferead_as_list($path)

read file and return content as array, return empty list if open fails

=cut

sub saferead_as_list {
    my($path) = @_;
    return(handle_io("saferead_as_list", 0, $path, \@_));
}

##############################################

=head2 write

  write($path, $content, [ $mtime ], [ $append ])

creates file and ensure permissions

=cut

sub write {
    my($path) = @_;
    return(handle_io("write", 0, $path, \@_));
}

##############################################

=head2 unlink

  unlink($path)

remove file

=cut

sub unlink {
    my(@paths) = @_;
    for my $p (@paths) {
        handle_io("unlink", 0, $p, [$p]);
    }
    return;
}

##############################################

=head2 file_exists

  file_exists($path)

returns true if the file exists

=cut

sub file_exists {
    my($path) = @_;
    return(handle_io("file_exists", 0, $path, \@_));
}

##############################################

=head2 file_not_empty

  file_not_empty($path)

returns true if the file exists and is not empty

=cut

sub file_not_empty {
    my($path) = @_;
    return(handle_io("file_not_empty", 0, $path, \@_));
}

##############################################

=head2 stat

  stat($path)

returns stat of file

=cut

sub stat {
    my($path) = @_;
    return(handle_io("stat", 0, $path, \@_));
}

##############################################

=head2 rmdir

  rmdir($path)

remove empty folder

=cut

sub rmdir {
    my($path) = @_;
    return(handle_io("rmdir", 0, $path, \@_));
}

##############################################

=head2 ensure_permissions

  ensure_permissions($mode, $path)

ensure permissions and ownership

=cut

sub ensure_permissions {
    my(undef, $path) = @_;
    return if defined $ENV{'THRUK_NO_TOUCH_PERM'};
    return(handle_io("ensure_permissions", 1, $path, \@_));
}

##############################################

=head2 file_rlock

  file_rlock($file)

locks given file in shared / readonly mode. Returns filehandle.

=cut
sub file_rlock {
    my($file) = @_;
    return(handle_io("file_rlock", 0, $file, \@_));
}

##############################################

=head2 file_lock

  file_lock($file)

locks given file in read/write mode. Returns locked filehandle and lock file handle.

=cut

sub file_lock {
    my($file) = @_;
    return(handle_io("file_lock", 0, $file, \@_));
}

##############################################

=head2 file_unlock

  file_unlock($file, $fh, $lock_fh)

unlocks file lock previously with file_lock exclusivly. Returns nothing.

=cut

sub file_unlock {
    my($file) = @_;
    return(handle_io("file_unlock", 0, $file, \@_));
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
    my($file) = @_;
    return(handle_io("json_store", 0, $file, \@_));
}

##############################################

=head2 json_lock_store

  json_lock_store($file, $data, [$options])

stores data json encoded. options are passed to json_store.

=cut

sub json_lock_store {
    my($file) = @_;
    return(handle_io("json_lock_store", 0, $file, \@_));
}

##############################################

=head2 json_retrieve

  json_retrieve($file, $fh, [$lock_fh])

retrieve json data

=cut

sub json_retrieve {
    my($file) = @_;
    return(handle_io("json_retrieve", 0, $file, \@_));
}

##############################################

=head2 json_lock_retrieve

  json_lock_retrieve($file)

retrieve json data

=cut

sub json_lock_retrieve {
    my($file) = @_;
    return(handle_io("json_lock_retrieve", 0, $file, \@_));
}

##############################################

=head2 json_lock_patch

  json_lock_patch($file, $patch_data, [$options])

update json data with locking. options are passed to json_store.

=cut

sub json_lock_patch {
    my($file) = @_;
    return(handle_io("json_lock_patch", 0, $file, \@_));
}

##############################################

=head2 json_patch

  json_patch($file, $fh, $patch_data, [$options])

update json data. options are passed to json_store.

=cut

sub json_patch {
    my($file) = @_;
    return(handle_io("json_patch", 0, $file, \@_));
}

########################################

=head2 touch

  touch($file)

create file if not exists and update timestamp

=cut
sub touch {
    my($file) = @_;
    return(handle_io("touch", 0, $file, \@_));
}

###################################################

=head2 find_files

  find_files($folder, $pattern, $skip_symlinks)

return list of files for folder and pattern (symlinks will optionally be skipped)

=cut

sub find_files {
    my($dir) = @_;
    my $files = handle_io("find_files", 0, $dir, \@_);
    if($Thruk::Utils::IO::var_path) {
        my $var_path = $Thruk::Utils::IO::var_path;
        $files = [map { my $f = $_; $f =~ s=^VAR::=$var_path=mx; $f; } @{$files}];
    }
    return($files);
}

###################################################

=head2 remove_folder

  remove_folder($folder)

recursively remove folder and all files

=cut
sub remove_folder {
    my($dir) = @_;
    handle_io("remove_folder", 0, $dir, \@_);
    return;
}

###################################################

=head2 handle_io

  handle_io($method, $idx, $path, $args)

wrapper to io functions

=cut
sub handle_io {
    my($method, $idx, $path, $args) = @_;
    if($Thruk::Utils::IO::var_path && !$ENV{'THRUK_FORCE_LOCAL_VAR_PATH'}) {
        my $var_path = $Thruk::Utils::IO::var_path;
        if($path !~ m=/local/=mx && $path =~ s=^$var_path=VAR::=mx) {
            my $hdl = ($Thruk::Utils::IO::var_db //= _init_var_db());
                if($hdl && $hdl ne "-1") {
                my @arg_copy = @{$args}; # required to not override source references
                $arg_copy[$idx] = $path;
                return($hdl->$method(@arg_copy));
            }
        }
    }
    my $f = \&{"Thruk::Utils::IO::LocalFS::".$method};
    return(&{$f}(@{$args}));
}

########################################
sub _init_var_db {
    my $config = Thruk::Config::get_config();
    return unless $config;
    return -1 unless $config->{'var_path_db'};
    if(!defined $Thruk::Utils::IO::var_db) {
        if($config->{'var_path_db'} =~ m|^mysql://|mx) {
            require Thruk::Utils::IO::Mysql;
            $Thruk::Utils::IO::var_db = Thruk::Utils::IO::Mysql->new($config->{'var_path_db'});
        } else {
            die("unknown var_path_db type");
        }
    }
    return $Thruk::Utils::IO::var_db;
}

##############################################

=head2 sync_db_fs

  sync_db_fs($c, $from, $to, $opts)

sync files to database or back

=cut
sub sync_db_fs {
    my($c, $from, $to, $opts) = @_;

    if(!$from || !$to) {
        die("usage: filesystem sync <from> <to>");
    }

    my $action;
    $action = 'export' if $from eq 'db';
    $action = 'import' if $from eq 'fs';
    if(!$action) {
        die("usage: filesystem sync <from> <to>");
    }
    if($action eq 'import' && $to ne 'db') {
        die("usage: filesystem sync <from> <to>");
    }
    if($action eq 'export' && $to ne 'fs') {
        die("usage: filesystem sync <from> <to>");
    }

    local $ENV{'THRUK_FORCE_LOCAL_VAR_PATH'} = 1 if $from eq 'fs';
    my $files = Thruk::Utils::IO::find_files($c->config->{'var_path'});
    delete $ENV{'THRUK_FORCE_LOCAL_VAR_PATH'};

    for my $file (sort @{$files}) {
        _debugs("writing %s %s:", $to eq 'db' ? 'to db' : 'to local fs', $file);
        local $ENV{'THRUK_FORCE_LOCAL_VAR_PATH'} = 1 if $from eq 'fs';
        my @stat    = Thruk::Utils::IO::stat($file);
        my $content = Thruk::Utils::IO::saferead($file);
        delete $ENV{'THRUK_FORCE_LOCAL_VAR_PATH'};

        local $ENV{'THRUK_FORCE_LOCAL_VAR_PATH'} = 1 if $to eq 'fs';
        my $dir = Thruk::Base::dirname($file);
        Thruk::Utils::IO::mkdir_r($dir);
        Thruk::Utils::IO::write($file, $content, $stat[9]);
        _debug(" OK");
        delete $ENV{'THRUK_FORCE_LOCAL_VAR_PATH'};
    }

    # remove all files which do not exist on source
    if($opts->{'delete'}) {
        local $ENV{'THRUK_FORCE_LOCAL_VAR_PATH'} = 1 if $to eq 'fs';
        my $destfiles = Thruk::Utils::IO::find_files($c->config->{'var_path'});
        my $existing = Thruk::Base::array2hash($files);

        for my $file (sort @{$destfiles}) {
            _debug("removing %s:", $file);
            Thruk::Utils::IO::unlink($file) if !defined $existing->{$file};
        }
        delete $ENV{'THRUK_FORCE_LOCAL_VAR_PATH'};
    }

    return;
}

########################################

=head2 realpath

  realpath($file)

return realpath of this file

=cut
sub realpath {
    return(Thruk::Utils::IO::LocalFS::realpath(@_));
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
    - env                   environment variables

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
    Thruk::Base::validate_options($options, [qw/stdin print_prefix output_prefix detached no_decode timeout no_touch_signals env/]);

    my $c = $Thruk::Globals::c || undef;
    my $t1 = [gettimeofday];

    if($options->{'timeout'}) {
        my $timeout = $options->{'timeout'};
        setpgrp();
        alarm($timeout);
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
                    _warn(longmess("command timed out after ".$timeout." seconds"));
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

    # set additional environment variables but keep local env
    local %ENV = (%{$options->{'env'}}, %ENV) if $options->{'env'};

    if($options->{'detached'}) {
        confess("stdin not supported for detached commands") if $options->{'stdin'};
        confess("array cmd not supported for detached commands") if ref $cmd eq 'ARRAY';
        require Thruk::Utils::External;
        Thruk::Utils::External::perl($c, { expr => '`'.$cmd.'`', background => 1 });
        $c->stats->profile(end => "IO::cmd") if $c;
        return(0, "cmd started in background");
    }

    require Thruk::Utils::Encode unless $options->{'no_decode'};

    if(ref $cmd ne 'ARRAY' && $cmd !~ m/&\s*$/mx) {
        $cmd = ["/bin/sh", "-c", $cmd];
    }

    my($rc, $output);
    if(ref $cmd eq 'ARRAY') {
        my $prog = shift @{$cmd};
        &timing_breakpoint('IO::cmd: '.$prog.' <args...>');
        _debug('running cmd: '.$prog.' '.join(' ', @{$cmd})) if $c;
        my($pid, $wtr, $rdr, @lines);
        $pid = open3($wtr, $rdr, $rdr, $prog, @{$cmd});
        my $sel = IO::Select->new;
        $sel->add($rdr);
        if($options->{'stdin'}) {
            print $wtr $options->{'stdin'},"\n";
        }
        CORE::close($wtr);

        while(my @ready = $sel->can_read()) {
            for my $fh (@ready) {
                my $line;
                my $len = sysread $fh, $line, 65536;
                if(!defined $len){
                    die "Error from child: $!\n";
                } elsif ($len == 0) {
                    $sel->remove($fh);
                    next;
                } else {
                    if(defined $options->{'print_prefix'}) {
                        my $l = "$line";
                        my $prefix = $options->{'print_prefix'};
                        my $chomped = chomp($l);
                        $l =~ s|\n|\n$prefix|gmx;
                        $l = $prefix.$l.($chomped ? "\n" : "");
                        print $l;
                    }
                    if($options->{'output_prefix'}) {
                        my $prefix = $options->{'output_prefix'};
                        if(ref $prefix eq 'CODE') {
                            $prefix = &{$prefix}();
                        }
                        my $l = "$line";
                        my $chomped = chomp($l);
                        $l =~ s|\n|\n$prefix|gmx;
                        $l = $prefix.$l.($chomped ? "\n" : "");
                        push @lines, $l;
                    } else {
                        push @lines, $line;
                    }
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

        # background command
        local $SIG{CHLD} = 'IGNORE'; # let the system reap the childs, we don't care
        if($cmd !~ m|2>&1|mx) {
            _warn(longmess("cmd does not redirect output but wants to run in the background, add >/dev/null 2>&1 to: ".$cmd)) if $c;
        }
        $output = `$cmd`;
        $rc = $?;
        # rc will be -1 otherwise when ignoring SIGCHLD
        $rc = 0 if $rc == -1;
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

    # log full command line of slow commands
    $c->stats->profile(comment => join(" ", @{Thruk::Base::list($cmd)})) if($c && $elapsed > 1);

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
            my $content = &saferead($file) // '';

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
