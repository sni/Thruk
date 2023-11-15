package Thruk::Agents::SNClient::Checks::Base;

use warnings;
use strict;

use Thruk::Agents::SNClient ();
use Thruk::Base ();
use Thruk::Utils::Agents ();
use Thruk::Utils::Log qw/:all/;

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
    my($self, $c, $inventory, $hostname, $password, $section) = @_;
    my $checks = [];

    # agent check itself
    push @{$checks}, { 'id' => 'inventory', 'name' => 'agent inventory', check => 'inventory', parent => 'agent version'};
    push @{$checks}, { 'id' => 'version', 'name' => 'agent version', check => 'check_snclient_version', 'noperf' => 1};

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

    if($inventory->{'uptime'}) {
        push @{$checks}, {
            'id'     => 'uptime',
            'name'   => 'uptime',
            'check'  => 'check_uptime',
            'parent' => 'agent version',
        };
    }

    if($inventory->{'os_version'}) {
        push @{$checks}, {
            'id'     => 'os_version',
            'name'   => 'os version',
            'check'  => 'check_os_version',
            'parent' => 'agent version',
            'noperf' => 1,
        };
    }

    if($inventory->{'network'}) {
        for my $net (@{$inventory->{'network'}}) {
            push @{$checks}, {
                'id'       => 'net.'.Thruk::Utils::Agents::to_id($net->{'name'}),
                'name'     => 'net '.$net->{'name'},
                'check'    => 'check_network',
                'args'     => { "filter" => "name=\"".$net->{'name'}."\"" },
                'parent'   => 'agent version',
                'info'     => Thruk::Agents::SNClient::make_info($net),
                'disabled' => Thruk::Utils::Agents::check_disable($net, $c->config->{'Thruk::Agents'}->{'snclient'}->{'disable'}->{network}),
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
                'info'     => Thruk::Agents::SNClient::make_info($drive),
                'disabled' => Thruk::Utils::Agents::check_disable($drive, $c->config->{'Thruk::Agents'}->{'snclient'}->{'disable'}->{drivesize}),
            };
        }
    }

    if($inventory->{'service'}) {
        my $wanted = {};
        my $configs = Thruk::Base::list($c->config->{'Thruk::Agents'}->{'snclient'}->{'service'});
        for my $cfg (@{$configs}) {
            next unless Thruk::Agents::SNClient::check_host_match($cfg->{'host'});
            next unless Thruk::Utils::Agents::check_wildcard_match($section, $cfg->{'section'});
            next unless $cfg->{'service'};
            for my $n (@{Thruk::Base::list($cfg->{'service'})}) {
                $wanted->{$n} = $cfg;
            }
        }
        my $services = Thruk::Base::list($inventory->{'service'});
        for my $svc (@{$services}) {
            next unless $wanted->{$svc->{'name'}};
            my $cfg = $wanted->{$svc->{'name'}};
            push @{$checks}, {
                'id'       => 'svc.'.Thruk::Utils::Agents::to_id($svc->{'name'}),
                'name'     => Thruk::Agents::SNClient::make_name($cfg->{'name'} // 'service %s', { '%s' => $svc->{'name'} }),
                'check'    => 'check_service',
                'args'     => { "service" => $svc->{'name'} },
                'parent'   => 'agent version',
                'info'     => Thruk::Agents::SNClient::make_info($svc),
            };
        }
    }

    if($inventory->{'process'}) {
        my $already_checked = {};
        my $wanted = {};
        my $configs = Thruk::Base::list($c->config->{'Thruk::Agents'}->{'snclient'}->{'proc'});
        for my $cfg (@{$configs}) {
            next unless Thruk::Agents::SNClient::check_host_match($cfg->{'host'});
            next unless Thruk::Utils::Agents::check_wildcard_match($section, $cfg->{'section'});
            next unless $cfg->{'match'};
            for my $n (@{Thruk::Base::list($cfg->{'match'})}) {
                push @{$wanted->{$n}}, $cfg;
            }
        }
        my $procs = Thruk::Base::list($inventory->{'process'});
        for my $p (@{$procs}) {
            my($cfg, $match, $user);
            for my $m (sort keys %{$wanted}) {
                $match = $m;
                ## no critic
                next unless $p->{'command_line'} =~ m|$m|i;
                ## use critic

                for my $cf (@{$wanted->{$m}}) {
                    $user = Thruk::Utils::Agents::check_wildcard_match($p->{'username'}, $cf->{'user'});
                    next unless $user;
                    $cfg = $cf;
                    last;
                }
            }
            next unless $cfg;
            my $username = $user ne 'ANY' ? $p->{'username'} : "";
            my $id       = 'proc.'.Thruk::Utils::Agents::to_id($match.'_'.($username || 'ANY'));
            next if $already_checked->{$id};
            $already_checked->{$id} = 1;
            my $filter = [ "filter='command_line ~~ /".$match."/'" ];
            if($user ne 'ANY') {
                push @{$filter}, "filter='username ~~ /".$user."/'";
            }
            push @{$checks}, {
                'id'       => $id,
                'name'     => Thruk::Agents::SNClient::make_name($cfg->{'name'} // 'proc %e %u', { '%e' => $p->{'exe'}, '%u' => $username }),
                'check'    => 'check_process',
                'args'     => $filter,
                'parent'   => 'agent version',
                'info'     => Thruk::Agents::SNClient::make_info($p),
            };
        }
    }

    # external scripts
    if($inventory->{'scripts'}) {
        for my $script (@{$inventory->{'scripts'}}) {
            push @{$checks}, {
                'id'       => 'extscript.'.Thruk::Utils::Agents::to_id($script),
                'name'     => $script,
                'check'    => $script,
                'parent'   => 'agent version',
            };
        }
    }

    if($inventory->{'omd'}) {
        my $disabled_config = $c->config->{'Thruk::Agents'}->{'snclient'}->{'disable'}->{'omd'} // { 'autostart' => '!= 1'};
        for my $omd (@{$inventory->{'omd'}}) {
            push @{$checks}, {
                'id'       => 'omd.'.Thruk::Utils::Agents::to_id($omd->{'site'}),
                'name'     => 'omd site '.$omd->{'site'},
                'check'    => 'check_omd',
                'args'     => { "site" => $omd->{'site'} },
                'parent'   => 'agent version',
                'info'     => Thruk::Agents::SNClient::make_info($omd),
                'disabled' => Thruk::Utils::Agents::check_disable($omd, $disabled_config),
            };
        }
    }

    return $checks;
}

##########################################################

1;
