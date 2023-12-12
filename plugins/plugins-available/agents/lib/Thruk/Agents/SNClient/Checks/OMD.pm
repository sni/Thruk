package Thruk::Agents::SNClient::Checks::OMD;

use warnings;
use strict;

use Thruk::Agents::SNClient ();
use Thruk::Utils::Agents ();

=head1 NAME

Thruk::Agents::SNClient::Checks::OMD - returns omd checks for snclient

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

    return unless $inventory->{'omd'};

    my $disabled_config = Thruk::Agents::SNClient::get_disabled_config($c, 'omd', { 'autostart' => '!= 1'});
    for my $omd (@{$inventory->{'omd'}}) {
        push @{$checks}, {
            'id'       => 'omd.'.Thruk::Utils::Agents::to_id($omd->{'site'}),
            'name'     => 'omd site '.$omd->{'site'},
            'check'    => 'check_omd',
            'args'     => { "site" => $omd->{'site'} },
            'parent'   => 'agent version',
            'info'     => Thruk::Agents::SNClient::make_info($omd),
            'disabled' => Thruk::Utils::Agents::check_disable($omd, $disabled_config, 'omd'),
        };
    }

    return $checks;
}

##########################################################

1;
