package Thruk::Agents::SNClient::Checks::NTP;

use warnings;
use strict;

use Thruk::Agents::SNClient ();
use Thruk::Utils::Agents ();

=head1 NAME

Thruk::Agents::SNClient::Checks::NTP - returns ntp checks for snclient

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

    return unless $inventory->{'ntp_offset'};

    my $disabled_config = Thruk::Agents::SNClient::get_disabled_config($c, 'ntp', {});
    for my $ntp (@{$inventory->{'ntp_offset'}}) {
        push @{$checks}, {
            'id'        => 'ntp',
            'name'      => 'ntp',
            'check'     => 'check_ntp_offset',
            'parent'    => 'agent version',
            'info'     => Thruk::Agents::SNClient::make_info($ntp),
            'disabled' => Thruk::Utils::Agents::check_disable($ntp, $disabled_config, 'ntp'),
        };
    }

    return $checks;
}

##########################################################

1;
