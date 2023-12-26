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
            'info'      => Thruk::Agents::SNClient::make_info($inventory->{'cpu'}->[0]),
        };
    }
    if($inventory->{'cpu_utilization'}) {
        push @{$checks}, {
            'id'        => 'cpuutilization',
            'name'      => 'cpu utilization',
            'check'     => 'check_cpu_utilization',
            'parent'    => 'agent version',
            'info'      => Thruk::Agents::SNClient::make_info($inventory->{'cpu_utilization'}->[0]),
        };
    }

    return $checks;
}

##########################################################

1;
