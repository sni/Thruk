package Thruk::Agents::SNClient::Checks::Process;

use warnings;
use strict;

use Thruk::Agents::SNClient ();
use Thruk::Base ();
use Thruk::Utils::Agents ();

=head1 NAME

Thruk::Agents::SNClient::Checks::Process - returns process checks for snclient

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

    return unless $inventory->{'process'};

    my $already_checked = {};
    my $wanted = {};
    my $configs = Thruk::Base::list($c->config->{'Thruk::Agents'}->{'snclient'}->{'proc'});
    for my $cfg (@{$configs}) {
        next unless Thruk::Agents::SNClient::check_host_match($cfg->{'host'});
        next unless Thruk::Utils::Agents::check_wildcard_match($section, ($cfg->{'section'} // 'ANY'));
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

    return $checks;
}

##########################################################

1;
