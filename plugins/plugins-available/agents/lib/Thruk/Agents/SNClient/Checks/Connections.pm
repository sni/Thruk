package Thruk::Agents::SNClient::Checks::Connections;

use warnings;
use strict;

use Thruk::Agents::SNClient ();
use Thruk::Utils::Agents ();

=head1 NAME

Thruk::Agents::SNClient::Checks::Connections - returns tcp connection checks for snclient

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

    return unless $inventory->{'connections'};

    my $disabled_config = Thruk::Agents::SNClient::get_disabled_config($c, 'connections', { "inet" => "total"});
    for my $conn (@{$inventory->{'connections'}}) {
        push @{$checks}, {
            'id'        => 'tcp.'.$conn->{'inet'},
            'name'      => 'tcp connections '.$conn->{'inet'},
            'check'     => 'check_connections',
            'parent'    => 'agent version',
            'args'      => { "inet" => $conn->{'inet'} },
            'info'      => Thruk::Agents::SNClient::make_info($conn),
            'disabled'  => Thruk::Utils::Agents::check_disable($conn, $disabled_config, 'connections'),
        };
    }

    return $checks;
}

##########################################################

1;
