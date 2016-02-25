package Monitoring::Config::Object::Discoveryrule;

use strict;
use warnings;
use Monitoring::Config::Object::Host;
use Monitoring::Config::Object::Service;
use parent 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Discoveryrule - Shinken discoveryrule Object Configuration

=head1 DESCRIPTION

Defaults for discoveryrule objects

=cut

##########################################################

$Monitoring::Config::Object::Discoveryrule::Defaults = {
    'name'                            => { type => 'STRING', cat => 'Extended' },
    'use'                             => { type => 'LIST', link => 'service', cat => 'Basic' },
    'register'                        => { type => 'BOOL', cat => 'Extended' },

    'discoveryrule_name'              => { type => 'STRING', cat => 'Basic' },
    'creation_type'                   => { type => 'CHOOSE', values => ['service','host'], keys => ['service','host'], cat => 'Basic' },
    'discoveryrule_order'             => { type => 'INT', cat => 'Basic' },

    # Matching rules
    'isup'                            => { type => 'BOOL', cat => 'Matching' },
    '!isup'                           => { type => 'BOOL', cat => 'Matching' },
    'os'                              => { type => 'STRING', cat => 'Matching' },
    '!os'                             => { type => 'STRING', cat => 'Matching' },
    'osversion'                       => { type => 'STRING', cat => 'Matching' },
    '!osversion'                      => { type => 'STRING', cat => 'Matching' },
    'macvendor'                       => { type => 'STRING', cat => 'Matching' },
    '!macvendor'                      => { type => 'STRING', cat => 'Matching' },
    'openports'                       => { type => 'STRING', cat => 'Matching' },
    '!openports'                      => { type => 'STRING', cat => 'Matching' },
    'parents'                         => { type => 'STRING', cat => 'Matching' },
    '!parents'                        => { type => 'STRING', cat => 'Matching' },
    'fqdn'                            => { type => 'STRING', cat => 'Matching' },
    '!fqdn'                           => { type => 'STRING', cat => 'Matching' },
    'ip'                              => { type => 'STRING', cat => 'Matching' },
    '!ip'                             => { type => 'STRING', cat => 'Matching' },
    'fs'                              => { type => 'STRING', cat => 'Matching' },
    '!fs'                             => { type => 'STRING', cat => 'Matching' },
};

##########################################################

=head1 METHODS

=head2 BUILD

return new object

=cut
sub BUILD {
    my $class    = shift || __PACKAGE__;
    my $coretype = shift;

    return unless($coretype eq 'any' or $coretype eq 'shinken');

    $Monitoring::Config::Object::Discoveryrule::Defaults->{'-use'} = $Monitoring::Config::Object::Discoveryrule::Defaults->{'use'};
    $Monitoring::Config::Object::Discoveryrule::Defaults->{'+use'} = $Monitoring::Config::Object::Discoveryrule::Defaults->{'use'};
    for my $key (keys %{$Monitoring::Config::Object::Host::Defaults}) {
        next if $Monitoring::Config::Object::Discoveryrule::Defaults->{$key};
        $Monitoring::Config::Object::Discoveryrule::Defaults->{    $key} = $Monitoring::Config::Object::Host::Defaults->{$key};
        $Monitoring::Config::Object::Discoveryrule::Defaults->{'-'.$key} = $Monitoring::Config::Object::Host::Defaults->{$key};
        $Monitoring::Config::Object::Discoveryrule::Defaults->{'+'.$key} = $Monitoring::Config::Object::Host::Defaults->{$key};
    }
    for my $key (keys %{$Monitoring::Config::Object::Host::ShinkenSpecific}) {
        next if $Monitoring::Config::Object::Discoveryrule::Defaults->{$key};
        $Monitoring::Config::Object::Discoveryrule::Defaults->{    $key} = $Monitoring::Config::Object::Host::ShinkenSpecific->{$key};
        $Monitoring::Config::Object::Discoveryrule::Defaults->{'-'.$key} = $Monitoring::Config::Object::Host::ShinkenSpecific->{$key};
        $Monitoring::Config::Object::Discoveryrule::Defaults->{'+'.$key} = $Monitoring::Config::Object::Host::ShinkenSpecific->{$key};
    }
    my $self = {
        'type'        => 'discoveryrule',
        'primary_key' => 'discoveryrule_name',
        'default'     => $Monitoring::Config::Object::Discoveryrule::Defaults,
        'standard'    => [ 'discoveryrule_name', 'creation_type', 'discoveryrule_order' ],
    };
    bless $self, $class;
    return $self;
}

##########################################################

=head1 AUTHOR

Mathieu Parent, 2013, <math.parent@gmail.com>
Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
