package Thruk::Agents::SNClient::Checks::Base;

use warnings;
use strict;

=head1 NAME

Thruk::Agents::SNClient::Checks::Base - returns basic checks for snclient

=head1 METHODS

=cut

##########################################################

=head2 get_checks

    get_checks()

returns snclient checks

=cut
sub get_checks {
    my($self, $c, $inventory, $hostname, $password) = @_;
    my $checks = [];

    # agent check itself
    push @{$checks}, { 'id' => 'inventory', 'name' => 'agent inventory', check => 'inventory', parent => 'agent version'};
    push @{$checks}, { 'id' => 'version', 'name' => 'agent version', check => 'check_snclient_version'};

    if($inventory->{'cpu'}) {
        push @{$checks}, { 'id' => 'cpu', 'name' => 'cpu', check => 'check_cpu', parent => 'agent version' };
    }

    if($inventory->{'memory'}) {
        push @{$checks}, {
            'id'     => 'mem',
            'name'   => 'memory',
            'check'  => 'check_memory',
            'parent' => 'agent version',
        };
    }

    if($inventory->{'network'}) {
        for my $net (@{$inventory->{'network'}}) {
            push @{$checks}, {
                'id'       => 'net.'.Thruk::Utils::Agents::to_id($net->{'name'}),
                'name'     => 'net '.$net->{'name'},
                'check'    => 'check_network',
                'args'     => { "filter" => "name=".$net->{'name'} },
                'parent'   => 'agent version',
                'info'     => Thruk::Agents::SNClient::_make_info($net),
                'disabled' => Thruk::Agents::SNClient::_check_disable($net, $c->config->{'Thruk::Agents'}->{'snclient'}->{'disable'}->{network}),
            };
        }
    }

    if($inventory->{'drivesize'}) {
        for my $drive (@{$inventory->{'drivesize'}}) {
            push @{$checks}, {
                'id'       => 'df.'.Thruk::Utils::Agents::to_id($drive->{'drive'}),
                'name'     => 'disk '.$drive->{'drive'},
                'check'    => 'check_drivesize',
                'args'     => { "drive" => $drive->{'drive'} },
                'parent'   => 'agent version',
                'info'     => Thruk::Agents::SNClient::_make_info($drive),
                'disabled' => Thruk::Agents::SNClient::_check_disable($drive, $c->config->{'Thruk::Agents'}->{'snclient'}->{'disable'}->{drivesize}),
            };
        }
    }

    if($inventory->{'service'}) {
        my $wanted = {};
        my $configs = Thruk::Base::list($c->config->{'Thruk::Agents'}->{'snclient'}->{'service'});
        for my $cfg (@{$configs}) {
            next unless Thruk::Agents::SNClient::_check_host_match($cfg->{'host'});
            if($cfg->{'name'}) {
                for my $n (@{Thruk::Base::list($cfg->{'name'})}) {
                    $wanted->{$n} = $cfg;
                }
            }
        }
        my $services = Thruk::Base::list($inventory->{'service'});
        for my $svc (@{$services}) {
            next unless $wanted->{$svc->{'name'}};
            push @{$checks}, {
                'id'       => 'svc.'.Thruk::Utils::Agents::to_id($svc->{'name'}),
                'name'     => 'service '.$svc->{'name'},
                'check'    => 'check_service',
                'args'     => { "service" => $svc->{'name'} },
                'parent'   => 'agent version',
                'info'     => Thruk::Agents::SNClient::_make_info($svc),
            };
        }
    }

    # TODO: process

    return $checks;
}

##########################################################

1;
