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
use Time::HiRes qw/gettimeofday tv_interval/;
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

    if($mode eq 'commit') {
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

    # backwards compatibility for thruk -a bpd command
    my $id = $mode;
    if($mode eq 'd') {
        $id = 'all';
    }

    if(!$id) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

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

    my $t0 = [gettimeofday];
    my $bps = Thruk::BP::Utils::load_bp_data($c, $id);
    for my $bp (@{$bps}) {
        $last_bp = $bp;
        _debug("updating: ".$bp->{'name'}) if $Thruk::Utils::CLI::verbose >= 1;
        $bp->update_status($c);
        _debug("OK") if $Thruk::Utils::CLI::verbose >= 1;
    }
    alarm(0);
    my $nr = scalar @{$bps};
    my $elapsed = tv_interval($t0);
    my $output = sprintf("OK - %d business processes updated in %.2fs\n", $nr, $elapsed);

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
