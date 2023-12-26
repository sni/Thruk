package Thruk::Agents::SNClient::Checks::Kernelstats;

use warnings;
use strict;

use Thruk::Utils::Agents ();

=head1 NAME

Thruk::Agents::SNClient::Checks::Kernelstats - returns kernelstats checks for snclient

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

    return unless $inventory->{'kernel_stats'};
    for my $k (@{$inventory->{'kernel_stats'}}) {
        push @{$checks}, {
            'id'        => 'kernelstats.'.Thruk::Utils::Agents::to_id($k->{'name'}),
            'name'      => 'kernel '.lc($k->{'label'}),
            'check'     => 'check_kernel_stats',
            'args'      => { "type" => $k->{'name'} },
            'parent'    => 'agent version',
            'info'      => Thruk::Agents::SNClient::make_info($k),
        };
    }

    return $checks;
}

##########################################################

1;
