package Thruk::Utils::LMD;

=head1 NAME

Thruk::Utils::LMD - LMD Utilities Collection for Thruk

=head1 DESCRIPTION

LMD Utilities Collection for Thruk

=cut

use warnings;
use strict;
use Carp qw/confess/;
use File::Copy qw/copy move/;
use POSIX ();
use Time::HiRes ();

use Thruk::Utils ();
use Thruk::Utils::Log qw/:all/;

#use Thruk::Timer qw/timing_breakpoint/;

##########################################################
=head1 METHODS

=head2 check_proc

  check_proc($config, [$c], [$log_missing])

makes sure lmd process is running. Returns undef or the lmd pid.

=cut

sub check_proc {
    my($config, $c, $log_missing) = @_;

    return if $config->{'lmd_remote'};

    my $lmd_dir    = $config->{'tmp_path'}.'/lmd';
    my $logfile    = $lmd_dir.'/lmd.log';
    my $size       = -s $logfile;
    my $keep       = $config->{'lmd_rotate_keep_logs'} || 3;
    my $rotatesize = ($config->{'lmd_rotate_size'} || 20 ) *1024*1024; # rotate logfile if its more than 20mb
    my $pid;
    if($size && $size > $rotatesize) {
        if(-e $logfile.'.'.$keep) {
            unlink($logfile.'.'.$keep);
            _debug(sprintf("removed %s", $logfile.'.'.$keep));
        }
        while($keep > 1) {
            if(-e $logfile.'.'.($keep-1)) {
                move($logfile.'.'.($keep-1), $logfile.'.'.$keep);
                _debug(sprintf("moved %s to %s", $logfile.'.'.($keep-1), $logfile.'.'.$keep));
            }
            $keep--;
        }
        copy($logfile, $logfile.'.1');
        Thruk::Utils::IO::write($logfile, '');
        _debug(sprintf("moved %s to %s.1", $logfile, $logfile));
    }
    if(-e $lmd_dir.'/live.sock' && ($pid = check_pid($lmd_dir.'/pid'))) {
        return($pid);
    }

    # only start it once
    my $startlock = $lmd_dir.'/startup';
    my($fh, $lock);
    eval {
        ($fh, $lock) = Thruk::Utils::IO::file_lock($startlock);
    };
    if($@) {
        _error("failed to get lmd startup lock: ". $@);
        return;
    }

    eval {
        # now that we have the lock, check pid again, it might have been restarted meanwhile
        if(-e $lmd_dir.'/live.sock' && ($pid = check_pid($lmd_dir.'/pid'))) {
            return($pid);
        }

        write_lmd_config($c, $config);

        _info("lmd not running, starting up...") if $log_missing;
        my $cmd = ($config->{'lmd_core_bin'} || 'lmd')
                .' -pidfile '.$lmd_dir.'/pid'
                .' -config "'.$lmd_dir.'/lmd.ini"';
        for my $cfg (@{Thruk::Base::array_uniq(Thruk::Base::list($config->{'lmd_core_config'}))}) {
            for my $file (glob($cfg)) {
                $cmd .= ' -config "'.$file.'"';
            }
        }
        if($config->{'lmd_options'}) {
            $cmd .= ' '.$config->{'lmd_options'}.' ';
        }
        my $startlog = $lmd_dir.'/startup.log';
        $cmd .= ' >'.$startlog.' 2>&1 &';

        _debug("start cmd: ". $cmd);
        my($rc, $output) = Thruk::Utils::IO::cmd($c, $cmd, undef, undef, 1); # start detached
        if($rc != 0) {
            _error(sprintf('starting lmd failed with rc %d: %s', $rc, $output));
        } else {
            # wait up to 5 seconds for pid file
            my $retries = 0;
            while(!$pid) {
                $pid = check_pid($lmd_dir.'/pid');
                if($pid || $retries >= 50) {
                    last;
                }
                $retries++;
                Time::HiRes::sleep(0.1);
            }
            if($pid) {
                _debug(sprintf('lmd started with pid %d', $pid));
            } else {
                if(-s $startlog) {
                    my $starterr = Thruk::Utils::IO::read($startlog);
                    _warn($starterr);
                }
                _warn(sprintf('lmd failed to start, you may find details in the lmd.log or in '.$startlog));
            }
        }
    };
    my $err = $@;

    Thruk::Utils::IO::file_unlock($startlock, $fh, $lock) if $fh;
    unlink($startlock);

    confess($err) if $err;

    #&timing_breakpoint('check_proc');
    return($pid);
}

########################################

=head2 status

  status($config)

return lmd process status

=cut

sub status {
    my($config) = @_;

    my $status        = [];
    my $total_started = 0;
    my $started       = 0;
    my $start_time    = 0;
    my $pid;

    return($status, $total_started, $start_time) unless $config->{'use_lmd_core'};

    my $lmd_dir = $config->{'tmp_path'}.'/lmd';
    my $pidfile = $lmd_dir.'/pid';
    if(-e $lmd_dir.'/live.sock' && ($pid = check_pid($pidfile))) {
        $total_started++;
        $started = 1;
        $start_time = (stat($pidfile))[10];
    }
    push @{$status}, { status => $started, pid => $pid, start_time => $start_time };
    return($status, $total_started);
}

########################################

=head2 restart

  restart($c, $config)

restart lmd process

=cut

sub restart {
    my($c, $config) = @_;

    shutdown_procs($config);

    # wait till its stopped
    my($status, $started) = (1, 1);
    for(my $x = 0; $x <= 200; $x++) {
        eval {
            ($status, $started) = status($config);
        };
        last if $started == 0;
        Time::HiRes::sleep(0.1);
    }

    check_proc($config, $c, 0);

    return;
}

########################################

=head2 reload

  reload($c, $config)

send sighub tp lmd process

=cut

sub reload {
    my($config) = @_;

    my $lmd_dir = $config->{'tmp_path'}.'/lmd';
    if(-e $lmd_dir.'/live.sock' && check_pid($lmd_dir.'/pid')) {
        my $pid = Thruk::Utils::IO::read($lmd_dir.'/pid');
        chomp($pid);
        if(kill("SIGHUP", $pid)) {
            return(1);
        }
    }
    return;
}

########################################

=head2 shutdown_procs

  shutdown_procs($config)

stop all processes

=cut
sub shutdown_procs {
    my($config) = @_;
    return unless $config->{'use_lmd_core'};
    my $lmd_dir = $config->{'tmp_path'}.'/lmd';
    my $pidfile = $lmd_dir.'/pid';
    my $pid;
    if(-s $pidfile) {
        $pid = Thruk::Utils::IO::read($pidfile);
        kill(15, $pid);
    }
    delete $ENV{'THRUK_USE_LMD_FEDERATION_FAILED'};
    if($pid) {
        for (0..30) {
            last unless kill(0, $pid);
            Time::HiRes::sleep(0.1);
        }
    }
    return;
}

########################################

=head2 check_initial_start

  check_initial_start($c, $config)

do the initial start unless it has been started already or isn't used at all

=cut
sub check_initial_start {
    my($c, $config, $background) = @_;
    return if(!$config->{'use_lmd_core'});
    if(!$ENV{'THRUK_JOB_ID'}) {
        return if(Thruk::Base->mode ne 'FASTCGI' && Thruk::Base->mode ne 'DEVSERVER');
    }

    return if $config->{'lmd_remote'};

    #&timing_breakpoint("lmd check_initial_start");

    local $c->stash->{'remote_user'} = '(cli)' unless $c->stash->{'remote_user'};
    if($background) {
        require Thruk::Utils::External;
        Thruk::Utils::External::perl($c, { expr => 'Thruk::Utils::LMD::check_initial_start($c, $c->config, 0)', background => 1 });
        return;
    }

    check_proc($config, $c, 0);
    check_changed_lmd_config($c, $config);

    #&timing_breakpoint("lmd check_initial_start done");

    return;
}


########################################

=head2 check_pid

  check_pid($file)

check if pidfile exists and contains a valid pid, returns zero or the actual pid

=cut
sub check_pid {
    my($file) = @_;
    return 0 unless -s $file;
    my $pid = Thruk::Utils::IO::read($file);
    if($pid =~ m/^(\d+)\s*$/mx) {
        $pid = $1;
        if(! -d '/proc/.') {
            # check pid with kill when no proc filesystem exists
            if(kill(0, $pid)) {
                return($pid);
            }
        }
        elsif(-r '/proc/'.$pid.'/cmdline') {
            my $cmd = Thruk::Utils::IO::read('/proc/'.$pid.'/cmdline');
            if($cmd && $cmd =~ m/lmd/mxi) {
                return $pid;
            }
        }
    }
    return 0;
}

########################################

=head2 create_thread_dump

  create_thread_dump()

send sigusr1 to lmd to create a thread dump

=cut
sub create_thread_dump {
    my($config) = @_;
    return if(!$config->{'use_lmd_core'});
    return if(Thruk::Base->mode ne 'FASTCGI' && Thruk::Base->mode ne 'DEVSERVER');
    my $lmd_dir  = $config->{'tmp_path'}.'/lmd';
    my $pid_file = $lmd_dir.'/pid';
    my $pid = check_pid($pid_file);
    if($pid) {
        kill('USR1', $pid);
    }
    return;
}

########################################

=head2 kill_if_not_responding

  kill_if_not_responding()

send test query and kill hard if it does not respond

=cut
sub kill_if_not_responding {
    my($c, $config) = @_;

    return if $config->{'lmd_remote'};

    my $lmd_timeout = $config->{'lmd_timeout'} // 15;
    return if $lmd_timeout <= 0;
    my $lmd_dir  = $config->{'tmp_path'}.'/lmd';
    my $pid_file = $lmd_dir.'/pid';
    my $lmd_pid  = check_pid($pid_file);
    return unless $lmd_pid;

    # do not restart too soon, check if pidfile is older than 2 minutes
    my $ctime = (stat($pid_file))[10];
    return if($ctime > time() - 120);

    my $data;
    my $pid = fork();
    if($pid == -1) { die("fork failed: $!"); }

    if(!$pid) {
        require Thruk::Utils::External;
        Thruk::Utils::External::do_child_stuff($c, 0, 0);
        alarm($lmd_timeout);
        eval {
            $data = $c->db->lmd_peer->_raw_query("GET sites\n");
        };
        my $err = $@;
        alarm(0);
        if($err) {
            _error("lmd not responding, killing with force: err - ".$err);
            _error($data);
            kill('USR1', $lmd_pid);
            sleep(1);
            kill(2, $lmd_pid);
            sleep(1);
            kill(9, $lmd_pid);
        }
        exit 0;
    }

    my $waited = 0;
    my $extra  = 5;
    my $rc = -1;
    while($waited++ <= ($lmd_timeout+$extra) && $rc != 0) {
        POSIX::waitpid($pid, POSIX::WNOHANG);
        $rc = $?;
        sleep(1);
    }
    if($rc != 0) {
        _error("lmd not responding, killing with force: rc - ".$rc." - ".($! || ""));
        kill('USR1', $lmd_pid);
        kill(2, $pid);
        sleep(1);
        kill(2, $lmd_pid);
        sleep(1);
        kill(9, $lmd_pid);
        kill(9, $pid);
        sleep(1);
        POSIX::waitpid(-1, POSIX::WNOHANG);
    }

    return;
}

########################################

=head2 check_changed_lmd_config

  check_changed_lmd_config($c, $config)

check if the backends have changed and send a sighup to lmd if so

=cut
sub check_changed_lmd_config {
    my($c, $config) = @_;
    # return if it has not changed
    return unless write_lmd_config($c, $config);
    return reload($config);
}

##############################################

=head2 write_lmd_config

  write_lmd_config($c, $config)

write lmd.ini, returns true if file has changed or false otherwise

=cut
sub write_lmd_config {
    my($c, $config) = @_;
    my $lmd_dir = $config->{'tmp_path'}.'/lmd';

    # gather configs
    my $site_config = "Listen = ['".$lmd_dir."/live.sock']\n\n";

    $site_config .= "LogFile = '".$lmd_dir."/lmd.log'\n\n";
    $site_config .= "LogLevel = 'Warn'\n\n";

    if(!$config->{'ssl_verify_hostnames'}) {
        $site_config .= "SkipSSLCheck = 1\n\n";
    }

    confess("got no peers") if scalar @{$c->db->peer_order} == 0;

    for my $key (@{$c->db->peer_order}) {
        my $peer = $c->db->peers->{$key};
        next if $peer->{'federation'};
        $site_config .= "[[Connections]]\n";
        $site_config .= "name           = '".$peer->peer_name()."'\n";
        $site_config .= "id             = '".$key."'\n";
        $site_config .= "source         = ['".join("', '", @{$peer->peer_list()})."']\n";
        # section is supported starting with lmd 1.1.6
        if($peer->{'section'} && $peer->{'section'} ne 'Default') {
            $site_config .= "section = '".$peer->{'section'}."'\n";
        }
        $site_config .= "auth           = '".$peer->{'peer_config'}->{'options'}->{'auth'}."'\n"     if $peer->{'peer_config'}->{'options'}->{'auth'};
        $site_config .= "remote_name    = '".$peer->{'peer_config'}->{'options'}->{'remote_name'}."'\n" if $peer->{'peer_config'}->{'options'}->{'remote_name'};
        $site_config .= "tlsCertificate = '".$peer->{'peer_config'}->{'options'}->{'cert'}."'\n"     if $peer->{'peer_config'}->{'options'}->{'cert'};
        $site_config .= "tlsKey         = '".$peer->{'peer_config'}->{'options'}->{'key'}."'\n"      if $peer->{'peer_config'}->{'options'}->{'key'};
        $site_config .= "tlsCA          = '".$peer->{'peer_config'}->{'options'}->{'ca_file'}."'\n"  if $peer->{'peer_config'}->{'options'}->{'ca_file'};
        $site_config .= "tlsSkipVerify  = 1\n" if(defined $peer->{'peer_config'}->{'options'}->{'verify'} && $peer->{'peer_config'}->{'options'}->{'verify'} == 0);
        $site_config .= "proxy          = '".$peer->{'peer_config'}->{'options'}->{'proxy'}."'\n"    if $peer->{'peer_config'}->{'options'}->{'proxy'};
        if($peer->{'peer_config'}->{'lmd_options'}) {
            for my $key (sort keys %{$peer->{'peer_config'}->{'lmd_options'}}) {
                $site_config .= sprintf("%-14s = %s\n", $key, $peer->{'peer_config'}->{'lmd_options'}->{$key});
            }
        }
        $site_config .= "\n";
    }

    eval {
        Thruk::Utils::IO::mkdir_r($lmd_dir) ;
    };
    die("could not create lmd ".$lmd_dir.': '.$@) if $@;

    if(-s $lmd_dir.'/lmd.ini') {
        my $old = Thruk::Utils::IO::read($lmd_dir.'/lmd.ini');
        if($old eq $site_config) {
            return(0);
        }
    }

    Thruk::Utils::IO::write($lmd_dir.'/lmd.ini',$site_config);
    return(1);
}

##########################################################

=head2 get_lmd_version

  get_lmd_version($config)

returns lmd version

=cut
sub get_lmd_version {
    my($config) = @_;
    return($config->{'lmd_version'}) if $config->{'lmd_version'};
    my $cmd = ($config->{'lmd_core_bin'} || 'lmd')
              .' -version';

    my($rc, $output) = Thruk::Utils::IO::cmd(undef, $cmd);
    $config->{'lmd_version'} = $output;
    if($output && $output =~ m/version\s+([\S]+)\s+/mx) {
        return $1;
    }

    return;
}

##########################################################

1;
