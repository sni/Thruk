package Thruk::Agents::SNClient::Checks::Pagefile;

use warnings;
use strict;

use Thruk::Agents::SNClient ();
use Thruk::Utils::Agents ();

=head1 NAME

Thruk::Agents::SNClient::Checks::Pagefile - returns pagefile checks for snclient

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

    return unless $inventory->{'pagefile'};

    my $disabled_config = Thruk::Agents::SNClient::get_disabled_config($c, 'pagefile', { 'name' => '!= total'});
    for my $page (@{$inventory->{'pagefile'}}) {
        push @{$checks}, {
            'id'       => 'pagefile.'.Thruk::Utils::Agents::to_id($page->{'name'}),
            'name'     => $page->{'name'} eq 'total' ? 'pagefile' : 'pagefile '.$page->{'name'},
            'check'    => 'check_pagefile',
            'args'     => { "filter" => "name='".$page->{'name'}."'" },
            'parent'   => 'agent version',
            'info'     => Thruk::Agents::SNClient::make_info($page),
            'disabled' => Thruk::Utils::Agents::check_disable($page, $disabled_config, 'pagefile'),
        };
    }

    return $checks;
}

##########################################################

1;
