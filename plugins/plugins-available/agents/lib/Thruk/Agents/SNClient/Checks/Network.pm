package Thruk::Agents::SNClient::Checks::Network;

use warnings;
use strict;

use Thruk::Agents::SNClient ();
use Thruk::Utils::Agents ();

=head1 NAME

Thruk::Agents::SNClient::Checks::Network - returns network checks for snclient

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

    return unless $inventory->{'network'};

    for my $net (@{$inventory->{'network'}}) {
        push @{$checks}, {
            'id'       => 'net.'.Thruk::Utils::Agents::to_id($net->{'name'}),
            'name'     => 'net '.$net->{'name'},
            'check'    => 'check_network',
            'args'     => { "device" => $net->{'name'} },
            'parent'   => 'agent version',
            'info'     => Thruk::Agents::SNClient::make_info($net),
            'disabled' => Thruk::Utils::Agents::check_disable($net, $c->config->{'Thruk::Agents'}->{'snclient'}->{'disable'}, 'network'),
        };
    }

    return $checks;
}

##########################################################

1;
