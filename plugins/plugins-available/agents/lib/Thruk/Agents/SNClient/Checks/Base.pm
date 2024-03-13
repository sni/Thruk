package Thruk::Agents::SNClient::Checks::Base;

use warnings;
use strict;

use Thruk::Agents::SNClient ();
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
    push @{$checks}, {
        'id'        => 'inventory',
        'name'      => 'agent inventory',
        'check'     => 'inventory',
        'parent'    => 'agent version',
    };
    push @{$checks}, {
        'id'        => 'version',
        'name'      => 'agent version',
        'check'     => 'check_snclient_version',
        'nscweb'    => '-e CRITICAL',
    };

    if($inventory->{'uptime'}) {
        push @{$checks}, {
            'id'     => 'uptime',
            'name'   => 'uptime',
            'check'  => 'check_uptime',
            'parent' => 'agent version',
            'info'   => Thruk::Agents::SNClient::make_info($inventory->{'uptime'}->[0]),
        };
    }

    if($inventory->{'os_version'}) {
        push @{$checks}, {
            'id'     => 'os_version',
            'name'   => 'os version',
            'check'  => 'check_os_version',
            'parent' => 'agent version',
            'info'   => Thruk::Agents::SNClient::make_info($inventory->{'os_version'}->[0]),
        };
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

    if($inventory->{'eventlog'}) {
        push @{$checks}, {
            'id'     => 'eventlog',
            'name'   => 'eventlog',
            'check'  => 'check_eventlog',
            'args'   => { "scan-range" => "1h" },
            'parent' => 'agent version',
            'noperf' => 1,
        };
    }

    return $checks;
}

##########################################################

1;
