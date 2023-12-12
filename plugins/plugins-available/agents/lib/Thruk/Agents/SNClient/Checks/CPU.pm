package Thruk::Agents::SNClient::Checks::CPU;

use warnings;
use strict;

=head1 NAME

Thruk::Agents::SNClient::Checks::CPU - returns cpu checks for snclient

=head1 METHODS

=cut

##########################################################

=head2 get_checks

    get_checks()

returns snclient checks

=cut
sub get_checks {
    my($self, $c, $inventory, $hostname, $password, $section) = @_;
    my $checks = [];

    if($inventory->{'cpu'}) {
        push @{$checks}, {
            'id'        => 'cpu',
            'name'      => 'cpu',
            'check'     => 'check_cpu',
            'parent'    => 'agent version',
        };
        push @{$checks}, {
            'id'        => 'cpuutilization',
            'name'      => 'cpu utilization',
            'check'     => 'check_cpu_utilization',
            'parent'    => 'agent version',
        };
    }

    return $checks;
}

##########################################################

1;
