package Thruk::Agents::SNClient::Checks::Temperature;

use warnings;
use strict;

use Thruk::Agents::SNClient ();
use Thruk::Utils::Agents ();

=head1 NAME

Thruk::Agents::SNClient::Checks::Temperature - returns temperature checks for snclient

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

    return unless $inventory->{'temperature'};

    my $disabled_config = Thruk::Agents::SNClient::get_disabled_config($c, 'temperature', {
        'name' => '!= coretemp',
    });
    my $names = {};
    for my $temp (@{$inventory->{'temperature'}}) {
        next if $names->{$temp->{'name'}};
        $names->{$temp->{'name'}} = 1;
        my $name = $temp->{'name'};
        $name =~ s/temp$//gmx;
        push @{$checks}, {
            'id'        => 'temperature.'.Thruk::Utils::Agents::to_id($temp->{'name'}),
            'name'      => 'temperature '.$name,
            'check'     => 'check_temperature',
            'args'      => { "sensor" => $temp->{'name'} },
            'parent'    => 'agent version',
            'info'      => Thruk::Agents::SNClient::make_info($temp),
            'disabled'  => Thruk::Utils::Agents::check_disable($temp, $disabled_config, 'temperature'),
        };
    }

    return $checks;
}

##########################################################

1;
