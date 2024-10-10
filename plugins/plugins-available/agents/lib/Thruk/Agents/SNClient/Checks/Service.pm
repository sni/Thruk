package Thruk::Agents::SNClient::Checks::Service;

use warnings;
use strict;

use Thruk::Agents::SNClient ();
use Thruk::Base ();
use Thruk::Utils::Agents ();

=head1 NAME

Thruk::Agents::SNClient::Checks::Service - returns service checks for snclient

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

    return unless $inventory->{'service'};

    my $services = Thruk::Base::list($inventory->{'service'});
    # generic services check
    if(scalar @{$services} > 0) {
        push @{$checks}, {
            'id'       => 'svc',
            'name'     => 'services',
            'check'    => 'check_service',
            'parent'   => 'agent version',
        };
    }

    # specifically configured service checks
    my $wanted = {};
    my $configs = Thruk::Base::list($c->config->{'Thruk::Agents'}->{'snclient'}->{'service'});
    for my $cfg (@{$configs}) {
        next unless Thruk::Utils::Agents::check_wildcard_match($hostname, ($cfg->{'host'} // 'ANY'));
        next unless Thruk::Utils::Agents::check_wildcard_match($section, ($cfg->{'section'} // 'ANY'));
        next unless $cfg->{'service'};
        for my $n (@{Thruk::Base::list($cfg->{'service'})}) {
            $wanted->{$n} = $cfg;
        }
    }
    for my $svc (@{$services}) {
        next if($svc->{'active'} && $svc->{'active'} eq 'inactive');
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

    return $checks;
}

##########################################################

1;
