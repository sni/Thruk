package Monitoring::Config::Object::Arbiter;

use strict;
use warnings;
use parent 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Arbiter - Shinken Arbiter Object Configuration

=head1 DESCRIPTION

Defaults for arbiter objects

=cut

##########################################################

$Monitoring::Config::Object::Arbiter::Defaults = {
    'name'                            => { type => 'STRING', cat => 'Extended' },
    'use'                             => { type => 'LIST', link => 'arbiter', cat => 'Basic' },
    'register'                        => { type => 'BOOL', cat => 'Extended' },

    # From SatelliteLink:
    'address'                         => { type => 'STRING', cat => 'Basic' },
    'timeout'                         => { type => 'INT', cat => 'Extended' },
    'data_timeout'                    => { type => 'INT', cat => 'Extended' },
    'check_interval'                  => { type => 'INT', cat => 'Extended' },
    'max_check_attempts'              => { type => 'INT', cat => 'Extended' },
    'spare'                           => { type => 'BOOL', cat => 'Extended' },
    #'manage_sub_realms'               => { type => 'BOOL', cat => 'Extended' },
    #'manage_arbiters'                 => { type => 'BOOL', cat => 'Extended' },
    'modules'                         => { type => 'STRING', cat => 'Basic' },
    #'polling_interval'                => { type => 'INT', cat => 'Extended' },
    'use_timezone'                    => { type => 'STRING', cat => 'Extended' },
    'realm'                           => { type => 'LIST', 'link' => 'realm', cat => 'Extended' },
    'satellitemap'                    => { type => 'STRING', cat => 'Extended' },
    'use_ssl'                         => { type => 'BOOL', cat => 'Extended' },

    # Specific
    'arbiter_name'                    => { type => 'STRING', cat => 'Basic' },
    'host_name'                       => { type => 'STRING', cat => 'Basic' },
    'port'                            => { type => 'INT', cat => 'Basic' },
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

    my $self = {
        'type'        => 'arbiter',
        'primary_key' => 'arbiter_name',
        'default'     => $Monitoring::Config::Object::Arbiter::Defaults,
        'standard'    => [ 'arbiter_name', 'address', 'port', 'modules' ],
    };
    bless $self, $class;
    return $self;
}

##########################################################

=head1 AUTHOR

Mathieu Parent, 2013, <math.parent@gmail.com>
Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
