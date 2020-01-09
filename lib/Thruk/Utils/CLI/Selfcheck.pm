package Thruk::Utils::CLI::Selfcheck;

=head1 NAME

Thruk::Utils::CLI::Selfcheck - Selfcheck CLI module

=head1 DESCRIPTION

The selfcheck command runs a couple of selfchecks to identify typical issues when using Thruk.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] selfcheck <checktype>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<checktype>

    available check types are:

    - all                       runs all checks below
    - filesystem                runs filesystem checks
    - logfiles                  runs logfile checks
    - lmd                       runs lmd related checks
    - recurring_downtimes       runs recurring downtimes checks
    - reports                   runs reporting checks

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
    my($c, $action, $commandoptions, $data) = @_;
    $c->stats->profile(begin => "_cmd_selfcheck($action)");

    if(!$c->check_user_roles('authorized_for_admin')) {
        return("ERROR - authorized_for_admin role required", 1);
    }

    my $type = shift @{$commandoptions} || 'all';

    require Thruk::Utils::SelfCheck;
    my($rc, $msg, $details) = Thruk::Utils::SelfCheck->self_check($c, $type);
    $data->{'all_stdout'} = 1;

    $c->stats->profile(end => "_cmd_selfcheck($action)");
    return($msg."\n".$details."\n", $rc);
}

##############################################

=head1 EXAMPLES

Run all selfchecks

  %> thruk selfcheck all

=cut

##############################################

1;
