package Thruk::Utils::CLI::Bp;

=head1 NAME

Thruk::Utils::CLI::Bp - Bp CLI module

=head1 DESCRIPTION

The bp command provides all business process related cli commands.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] bp [commit|all|<nr>]

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<commit>

    write out all host/services objects for all business processes and update
    related cronjobs.

=item B<all>

    recalculate/update all business processes

=item B<nr>

    recalculate/update specific business process

=back

=cut

use warnings;
use strict;
use Time::HiRes qw/gettimeofday tv_interval sleep/;
use Thruk::Utils;
use Thruk::Utils::Log qw/_error _info _debug _trace/;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions, $data, $src, $global_options) = @_;
    $c->stats->profile(begin => "_cmd_bp($action)");

    if(!$c->config->{'use_feature_bp'}) {
        return("ERROR - business process addon is disabled\n", 1);
    }

    eval {
        require Thruk::BP::Utils;
    };
    if($@) {
        _debug($@) if $Thruk::Utils::CLI::verbose >= 1;
        return("business process plugin is disabled.\n", 1);
    }

    my $mode = shift @{$commandoptions} || '';

    # backwards compatibility for thruk -a bpd command
    my $id = $mode;
    if($mode eq 'd') {
        $id = 'all';
    }

    # this function must be run on one cluster node only
    if($id eq 'all') {
        return("command send to cluster\n", 0) if $c->cluster->run_cluster("once", "cmd: bp all");
    }

    if($mode eq 'commit') {
        # this function must be run on all cluster nodes
        return if $c->cluster->run_cluster("all", "cmd: bp commit");

        my $bps = Thruk::BP::Utils::load_bp_data($c);
        my($rc,$msg) = Thruk::BP::Utils::save_bp_objects($c, $bps);
        if($rc != 0) {
            $c->stats->profile(end => "_cmd_bp($action)");
            return($msg, $rc);
        }
        Thruk::BP::Utils::update_cron_file($c); # check cronjob
        $c->stats->profile(end => "_cmd_bp($action)");
        return('OK - wrote '.(scalar @{$bps})." business process(es)\n", 0);
    }

    if(!$id) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    # loading Clone makes BPs with filters lot faster
    eval {
        require Clone;
    };

    # calculate bps
    my $last_bp;
    my $rate = int($c->config->{'Thruk::Plugin::BP'}->{'refresh_interval'} || 1);
    if($rate < 1) { $rate = 1; }
    if($rate > 5) { $rate = 5; }
    my $timeout = ($rate*60) -5;
    local $SIG{ALRM} = sub { die("hit ".$timeout."s timeout on ".($last_bp ? $last_bp->{'name'} : 'unknown')) };
    alarm($timeout);

    # enable all backends for now till configuration is possible for each BP
    $c->{'db'}->enable_backends();

    undef $id if $id eq 'all';
    my $t0     = [gettimeofday];
    my $bps    = Thruk::BP::Utils::load_bp_data($c, $id);
    my $num_bp = scalar @{$bps};

    my $worker_num = int($c->config->{'Thruk::Plugin::BP'}->{'worker'} || 0);
    if($worker_num == 0) {
        # try to autmatically find a suitable number of workers
        $worker_num = 1;
        if($num_bp > 20) {
            $worker_num = 3;
        }
        if($num_bp > 100) {
            $worker_num = 5;
        }
    }
    my $chunks = Thruk::Utils::array_chunk($bps, $worker_num);

    my @pids;
    for my $chunk (@{$chunks}) {
        my $child_pid;
        if($worker_num > 1) {
            $child_pid = fork();
            die("failed to fork: $!") if $child_pid == -1;
        }
        if(!$child_pid) {
            if($worker_num > 1) {
                Thruk::Utils::External::_do_child_stuff();
            }
            for my $bp (@{$chunk}) {
                $last_bp = $bp;
                _debug("[$$] updating: ".$bp->{'name'}) if $Thruk::Utils::CLI::verbose >= 1;
                $bp->update_status($c);
                _debug("[$$] OK") if $Thruk::Utils::CLI::verbose >= 1;
            }
            exit if $worker_num > 1;
        } else {
            push @pids, $child_pid;
        }
    }
    if($worker_num > 1) {
        while(wait() != -1) {
            sleep(0.1);
        }
    }
    alarm(0);
    my $elapsed = tv_interval($t0);
    my $output = sprintf("OK - %d business processes updated in %.2fs\n", $num_bp, $elapsed);

    $c->stats->profile(end => "_cmd_bp($action)");
    return($output, 0);
}

##############################################

=head1 EXAMPLES

Recalculate business process with number 1

  %> thruk bp 1

Recalculate all business processes

  %> thruk bp all

Write out host and service objects

  %> thruk bp commit

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
