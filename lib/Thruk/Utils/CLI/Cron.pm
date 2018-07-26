package Thruk::Utils::CLI::Cron;

=head1 NAME

Thruk::Utils::CLI::Cron - Cron CLI module

=head1 DESCRIPTION

The cron command installs/uninstalls cronjobs

=head1 SYNOPSIS

  Usage: thruk [globaloptions] cron <cmd>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<cmd>

    available commands are:

    - install       install thruks cronjobs
    - uninstall     remove thruks cronjobs

=back

=cut

use warnings;
use strict;

##############################################
# no backends required for this command
our $skip_backends = 1;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions) = @_;
    $c->stats->profile(begin => "_cmd_cron($action)");

    my $output;
    my $type = shift @{$commandoptions} || 'help';
    if($type eq 'install') {
        $output = _install($c);
    }
    elsif($type eq 'uninstall') {
        $output = _uninstall($c);
    } else {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    $c->stats->profile(end => "_cmd_cron($action)");
    return($output, 0);
}

##############################################
sub _install {
    my($c) = @_;
    $c->stats->profile(begin => "_cmd_installcron()");
    Thruk::Utils::switch_realuser($c);

    $c->cluster->run_cluster("others", "cmd: cron install");
    local $ENV{'THRUK_SKIP_CLUSTER'} = 1; # skip further subsequent cluster calls

    require Thruk::Utils::RecurringDowntimes;
    Thruk::Utils::RecurringDowntimes::update_cron_file($c);
    if($c->config->{'use_feature_reports'}) {
        require Thruk::Utils::Reports;
        Thruk::Utils::Reports::update_cron_file($c);
    }
    if($c->config->{'use_feature_bp'}) {
        require Thruk::BP::Utils;
        Thruk::BP::Utils::update_cron_file($c);
    }
    $c->stats->profile(end => "_cmd_installcron()");
    return "updated cron entries\n";
}

##############################################
sub _uninstall {
    my($c) = @_;
    $c->stats->profile(begin => "_cmd_uninstallcron()");
    Thruk::Utils::switch_realuser($c);
    Thruk::Utils::update_cron_file($c);
    $c->stats->profile(end => "_cmd_uninstallcron()");
    return "cron entries removed\n";
}

##############################################

=head1 EXAMPLES

Install thruks internal cronjobs

  %> thruk cron install

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
