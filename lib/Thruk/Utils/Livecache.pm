package Thruk::Utils::Livecache;

=head1 NAME

Thruk::Utils::Livecache - Livecache Utilities Collection for Thruk

=head1 DESCRIPTION

Livecache Utilities Collection for Thruk

=cut

use strict;
use warnings;
use utf8;
use File::Slurp qw/read_file/;
use Time::HiRes qw/sleep/;
#use Thruk::Timer qw/timing_breakpoint/;

##########################################################
=head1 METHODS

=head2 check_shadow_naemon_procs

  check_shadow_naemon_procs($config, [$c], [$log_missing], [$force])

makes sure all shadownaemon processes are running

=cut

sub check_shadow_naemon_procs {
    my($config, $c, $log_missing, $force) = @_;
    local $SIG{CHLD} = 'DEFAULT';
    for my $key (keys %{$Thruk::Backend::Pool::peers}) {
        my $peer    = $Thruk::Backend::Pool::peers->{$key};
        next unless $peer->{'cacheproxy'};
        # faster check if nothing failed
        next if(!$force and $c and !$c->stash->{'failed_backends'}->{$key});
        my $basedir = $config->{'shadow_naemon_dir'}.'/'.$key;
        my $pidfile = $basedir.'/tmp/shadownaemon.pid';
        my $started = 0;
        if(-s $pidfile) {
            my $pid = read_file($pidfile);
            if(kill(0, $pid)) {
                $started = 1;
            }
        }
        if(!$started) {
            _start_shadownaemon_for_peer($config, $peer, $key, $basedir, $c, $log_missing);
        }
    }
    #&timing_breakpoint('check_shadow_naemon_procs');
    return;
}

##########################################################

=head2 restart_shadow_naemon_procs

  restart_shadow_naemon_procs($config)

restart all shadownaemon processes sequentially

=cut

sub restart_shadow_naemon_procs {
    my($config) = @_;
    return unless $config->{'shadow_naemon_dir'};
    for my $key (keys %{$Thruk::Backend::Pool::peers}) {
        my $peer    = $Thruk::Backend::Pool::peers->{$key};
        next unless $peer->{'cacheproxy'};
        #&timing_breakpoint("restarting $key");
        my $basedir = $config->{'shadow_naemon_dir'}.'/'.$key;
        my $pidfile = $basedir.'/tmp/shadownaemon.pid';
        if(-s $pidfile) {
            my $pid = read_file($pidfile);
            #&timing_breakpoint("pidfile exists: $pid");
            kill(2, $pid);
            for(1..300) {
                last if kill(0, $pid) == 0;
                sleep(0.1);
            }
            #&timing_breakpoint("stopped");
        }
        _start_shadownaemon_for_peer($config, $peer, $key, $basedir);
        #&timing_breakpoint("started");
    }
    return;
}

##########################################################

=head2 status_shadow_naemon_procs

  status_shadow_naemon_procs($config)

get status of shadownaemon processes

=cut

sub status_shadow_naemon_procs {
    my($config)       = @_;
    my $status        = [];
    my $total_started = 0;
    for my $key (keys %{$Thruk::Backend::Pool::peers}) {
        my $peer    = $Thruk::Backend::Pool::peers->{$key};
        next unless $peer->{'cacheproxy'};
        my $basedir = $config->{'shadow_naemon_dir'}.'/'.$key;
        my $pidfile = $basedir.'/tmp/shadownaemon.pid';
        my $started = 0;
        my $pid;
        if(-s $pidfile) {
            $pid = read_file($pidfile);
            if(kill(0, $pid)) {
                $started = 1;
                $total_started++;
            }
        }
        push @{$status}, { key => $key, name => $peer->{'name'}, status => $started, pid => $pid, dir => $basedir };
    }
    return($status, $total_started);
}

########################################

=head2 shutdown_shadow_naemon_procs

  shutdown_shadow_naemon_procs($config)

stop all shadownaemon processes

=cut
sub shutdown_shadow_naemon_procs {
    my($config) = @_;
    return unless $config->{'shadow_naemon_dir'};
    for my $key (keys %{$Thruk::Backend::Pool::peers}) {
        my $pidfile = $config->{'shadow_naemon_dir'}.'/'.$key.'/tmp/shadownaemon.pid';
        if(-s $pidfile) {
            my $pid = read_file($pidfile);
            kill(15, $pid);
        }
    }
    return;
}

##############################################
sub _start_shadownaemon_for_peer {
    my($config, $peer, $key, $basedir, $c, $log_missing) = @_;
    Thruk::Utils::IO::mkdir_r($basedir.'/tmp');
    $c->log->error(sprintf("shadownaemon %s for peer %s (%s) crashed, restarting...", $peer->{'name'}, $key, ($peer->{'config'}->{'options'}->{'fallback_peer'} || $peer->{'config'}->{'options'}->{'peer'}))) if $log_missing;
    my $cmd = [
            ($config->{'shadow_naemon_bin'} || 'shadownaemon'),
            '-d',
            '-i', ($peer->{'config'}->{'options'}->{'fallback_peer'} || $peer->{'config'}->{'options'}->{'peer'}),
            '-o',  $config->{'shadow_naemon_dir'}.'/'.$key,
    ];
    if($config->{'shadow_naemon_ls'}) {
        push @{$cmd}, ('-l', $config->{'shadow_naemon_ls'});
    }
    push @{$cmd}, ('>>', $config->{'shadow_naemon_dir'}.'/'.$key.'/tmp/shadownaemon.log 2>&1');
    $c->log->error(join(' ', @{$cmd})) if $log_missing;
    # starting in background is not faster here since the daemon immediatly backgrounds
    my($rc, $output) = Thruk::Utils::IO::cmd($c, $cmd);
    $c->log->error(sprintf('starting shadownaemon failed with rc %d: %s', $rc, $output)) if $rc != 0;
    return;
}


##############################################

1;

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
