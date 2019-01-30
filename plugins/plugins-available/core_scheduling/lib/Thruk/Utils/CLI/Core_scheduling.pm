package Thruk::Utils::CLI::Core_scheduling;

=head1 NAME

Thruk::Utils::CLI::Core_scheduling - Core_scheduling CLI module

=head1 DESCRIPTION

The core_scheduling command smart reschedules hosts / services.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] core_scheduling [command] [<filter>]

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<command>

    Available commands are:

        - fix           fix scheduling of hosts / services

=back

=cut

use warnings;
use strict;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions, $data, $src, $global_options) = @_;

    if(!$c->config->{'use_feature_core_scheduling'}) {
        return("ERROR - core_scheduling addon is disabled\n", 1);
    }

    eval {
        require Thruk::Controller::core_scheduling;
    };
    if($@) {
        _debug($@);
        return("core_scheduling plugin is disabled.\n", 1);
    }

    $c->stats->profile(begin => "_cmd_fix_scheduling($action)");

    my $command = shift @{$commandoptions} || 'help';
    if($command eq 'fix') {
        my $filter = shift @{$commandoptions};
        my $hostfilter;
        my $servicefilter;
        if($filter) {
            if($filter =~ m/^hg:(.*)$/mx) {
                $hostfilter    = { 'groups'      => { '>=' => $1 } };
                $servicefilter = { 'host_groups' => { '>=' => $1 } };
            }
            elsif($filter =~ m/^sg:(.*)$/mx) {
                $servicefilter = { 'groups'      => { '>=' => $1 } };
            }
            else {
                return("filter must be either hg:<hostgroup> or sg:<servicegroup>\n", 1);
            }
        }
        Thruk::Utils::set_user($c, '(cron)') unless $c->user_exists;
        Thruk::Controller::core_scheduling::reschedule_everything($c, $hostfilter, $servicefilter);
    }
    else {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    $c->stats->profile(end => "_cmd_fix_scheduling($action)");
    return($c->stash->{message}."\n", 0);
}

##############################################

=head1 EXAMPLES

Reschedule all hosts and services

  %> thruk core_scheduling fix

Reschedule all hosts and services of the hostgroup linux

  %> thruk core_scheduling fix hg:linux

=cut

1;
