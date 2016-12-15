package Thruk::Utils::LMD;

=head1 NAME

Thruk::Utils::LMD - LMD Utilities Collection for Thruk

=head1 DESCRIPTION

LMD Utilities Collection for Thruk

=cut

use strict;
use warnings;
use File::Slurp qw/read_file/;
use Time::HiRes qw/sleep/;
use File::Copy qw/copy/;
use Thruk::Utils::External;
#use Thruk::Timer qw/timing_breakpoint/;

##########################################################
=head1 METHODS

=head2 check_proc

  check_proc($config, [$c], [$log_missing])

makes sure lmd process is running

=cut

sub check_proc {
    my($config, $c, $log_missing) = @_;

    my $lmd_dir = $config->{'tmp_path'}.'/lmd';
    my $logfile = $lmd_dir.'/lmd.log';
    if(-s $logfile > 10*1024*1024) { # rotate logfile if its more than 10mb
        copy($logfile, $logfile.'.1');
        Thruk::Utils::IO::write($logfile, '');
    }
    if(-e $lmd_dir.'/live.sock' && check_pid($lmd_dir.'/pid')) {
        return;
    }

    _write_lmd_config($config);

    $c->log->error("lmd not running, starting up...") if $log_missing;
    local $SIG{CHLD} = 'DEFAULT';
    my $cmd = ($config->{'lmd_core_bin'} || 'lmd')
              .' -pidfile '.$lmd_dir.'/pid'
              .' -config '.$lmd_dir.'/lmd.ini';
    if($config->{'lmd_core_config'}) {
        $cmd .= ' -config '.$config->{'lmd_core_config'};
    }
    $cmd .= ' >/dev/null 2>&1 &';

    my($rc, $output) = Thruk::Utils::IO::cmd($c, $cmd);
    $c->log->error(sprintf('starting lmd failed with rc %d: %s', $rc, $output)) if $rc != 0;

    #&timing_breakpoint('check_proc');
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
    if(-s $pidfile) {
        my $pid = read_file($pidfile);
        kill(15, $pid);
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
    return if(!defined $ENV{'THRUK_SRC'} || ($ENV{'THRUK_SRC'} ne 'FastCGI' && $ENV{'THRUK_SRC'} ne 'DebugServer'));

    #&timing_breakpoint("lmd check_initial_start");

    if($background) {
        ## no critic
        $SIG{CHLD} = 'IGNORE';
        ## use critic
        my $pid = fork();
        if($pid) {
            $config->{'_lmd_started'} = 1;
        } else {
            Thruk::Utils::External::_do_child_stuff();
            ## no critic
            $SIG{CHLD} = 'DEFAULT';
            ## use critic
            check_proc($config, $c, 0, 1);
            _check_changed_lmd_config($config);
            exit;
        }
    } else {
        check_proc($config, $c, 0, 1);
        _check_changed_lmd_config($config);
    }

    #&timing_breakpoint("lmd check_initial_start done");

    return;
}


########################################

=head2 check_pid

  check_pid($file)

check if pidfile exists and contains a valid pid

=cut
sub check_pid {
    my($file) = @_;
    return 0 unless -s $file;
    my $pid = read_file($file);
    if($pid =~ m/^(\d+)\s*$/mx) {
        if(-d '/proc/'.$1) {
            my $cmd = read_file('/proc/'.$1.'/cmdline');
            if($cmd =~ m/lmd/mxi) {
                return 1;
            }
        }
    }
    return 0;
}

########################################

=head2 _check_changed_lmd_config

  _check_changed_lmd_config($config)

check if the backends have changed and send a sighup to lmd if so

=cut
sub _check_changed_lmd_config {
    my($config) = @_;
    # return if it has not changed
    return unless _write_lmd_config($config);

    my $lmd_dir = $config->{'tmp_path'}.'/lmd';
    my $pidfile = $lmd_dir.'/pid';
    if(-s $pidfile) {
        my $pid = read_file($pidfile);
        kill(1, $pid);
    }
    return;
}

##############################################

=head2 _write_lmd_config

  _write_lmd_config($config)

write lmd.ini, returns true if file has changed or false otherwise

=cut
sub _write_lmd_config {
    my($config) = @_;
    my $lmd_dir = $config->{'tmp_path'}.'/lmd';

    # gather configs
    my $site_config = "Listen = ['".$lmd_dir."/live.sock']\n\n";

    $site_config .= "LogFile = '".$lmd_dir."/lmd.log'\n\n";
    $site_config .= "LogLevel = 'Warn'\n\n";

    if(!$config->{'ssl_verify_hostnames'}) {
        $site_config .= "SkipSSLCheck = 1\n\n";
    }

    for my $key (@{$Thruk::Backend::Pool::peer_order}) {
        my $peer = $Thruk::Backend::Pool::peers->{$key};
        $site_config .= "[[Connections]]\n";
        $site_config .= "name   = '".$peer->peer_name()."'\n";
        $site_config .= "id     = '".$key."'\n";
        $site_config .= "source = ['".join("', '", @{$peer->peer_list()})."']\n";
        if($peer->{'type'} eq 'http') {
            $site_config .= "auth = '".$peer->{'config'}->{'options'}->{'auth'}."'\n";
            $site_config .= "remote_name = '".$peer->{'config'}->{'options'}->{'remote_name'}."'\n" if $peer->{'config'}->{'options'}->{'remote_name'};
        }
        $site_config .= "\n";
    }

    eval {
        Thruk::Utils::IO::mkdir_r($lmd_dir) ;
    };
    die("could not create lmd ".$lmd_dir.': '.$@) if $@;

    if(-s $lmd_dir.'/lmd.ini') {
        my $old = read_file($lmd_dir.'/lmd.ini');
        if($old eq $site_config) {
            return(0);
        }
    }

    Thruk::Utils::IO::write($lmd_dir.'/lmd.ini',$site_config);
    return(1);
}

1;

__END__

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
