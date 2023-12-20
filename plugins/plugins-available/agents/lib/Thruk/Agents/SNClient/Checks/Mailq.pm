package Thruk::Agents::SNClient::Checks::Mailq;

use warnings;
use strict;

use Thruk::Agents::SNClient ();
use Thruk::Utils::Agents ();

=head1 NAME

Thruk::Agents::SNClient::Checks::Mailq - returns mailq checks for snclient

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

    my $disabled_config = Thruk::Agents::SNClient::get_disabled_config($c, 'mailq', {});
    for my $mta (@{$inventory->{'mailq'}}) {
        push @{$checks}, {
            'id'        => 'mailq.'.Thruk::Utils::Agents::to_id($mta->{'mta'}),
            'name'      => $mta->{'mta'}.' queue',
            'check'     => 'check_mailq',
            'parent'    => 'agent version',
            'info'     => Thruk::Agents::SNClient::make_info($mta),
            'disabled' => Thruk::Utils::Agents::check_disable($mta, $disabled_config, 'mailq'),
        };
    }

    return $checks;
}

##########################################################

1;
