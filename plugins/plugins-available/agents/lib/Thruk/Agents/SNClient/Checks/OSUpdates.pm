package Thruk::Agents::SNClient::Checks::OSUpdates;

use warnings;
use strict;

use Thruk::Agents::SNClient ();

=head1 NAME

Thruk::Agents::SNClient::Checks::OSUpdates - returns os_updates checks for snclient

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

    return unless defined $inventory->{'os_updates'};

    my $def_opts = Thruk::Agents::SNClient::default_opt($c, 'os_updates');
    push @{$checks}, {
        'id'       => 'os_updates',
        'name'     => 'os updates',
        'check'    => 'check_os_updates',
        'args'     => [ $def_opts ],
        'parent'   => 'agent version',
    };

    return $checks;
}

##########################################################

1;
