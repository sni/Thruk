package Thruk::Agents::SNClient::Checks::Memory;

use warnings;
use strict;

use Thruk::Agents::SNClient ();

=head1 NAME

Thruk::Agents::SNClient::Checks::Memory - returns memory checks for snclient

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

    return unless $inventory->{'memory'};

    for my $mem (@{$inventory->{'memory'}}) {
        if($mem->{'type'} eq 'physical') {
            push @{$checks}, {
                'id'     => 'mem',
                'name'   => 'memory',
                'check'  => 'check_memory',
                'args'   => { "type" => "physical" },
                'parent' => 'agent version',
                'info'   => Thruk::Agents::SNClient::make_info($mem),
            };
        }
        if($mem->{'type'} eq 'committed') {
            push @{$checks}, {
                'id'     => 'mem.swap',
                'name'   => 'memory swap',
                'check'  => 'check_memory',
                'parent' => 'agent version',
                'args'   => { "type" => "committed" },
                'info'   => Thruk::Agents::SNClient::make_info($mem),
            };
        }
    }

    return $checks;
}

##########################################################

1;
