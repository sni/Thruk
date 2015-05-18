package Monitoring::Config::Object::Hostescalation;

use strict;
use warnings;
use parent 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Hostescalation - Hostescalation Object Configuration

=head1 DESCRIPTION

Defaults for Hostescalation objects

=cut

##########################################################

$Monitoring::Config::Object::Hostescalation::Defaults = {
    'name'                  => { type => 'STRING', cat => 'Extended' },
    'use'                   => { type => 'LIST', link => 'hostescalation', cat => 'Basic' },
    'register'              => { type => 'BOOL', cat => 'Extended' },

    'host_name'              => { type => 'LIST',   'link' => 'host' },
    'hostgroup_name'         => { type => 'LIST',   'link' => 'hostgroup' },
    'contacts'               => { type => 'LIST',   'link' => 'contact' },
    'contact_groups'         => { type => 'LIST',   'link' => 'contactgroup' },
    'first_notification'     => { type => 'INT' },
    'last_notification'      => { type => 'INT' },
    'notification_interval'  => { type => 'INT' },
    'escalation_period'      => { type => 'STRING', 'link' => 'timeperiod' },
    'escalation_options'     => { type => 'ENUM', values => ['r','d','u'], keys => [ 'Up(recovery)', 'Down', 'Unreachable' ] },

    # aliased attributes
    'host'                   => { type => 'ALIAS', 'name' => 'host_name' },
    'hostgroup'              => { type => 'ALIAS', 'name' => 'hostgroup_name' },
    'hostgroups'             => { type => 'ALIAS', 'name' => 'hostgroup_name' },
};

##########################################################

=head1 METHODS

=head2 BUILD

return new object

=cut
sub BUILD {
    my $class = shift || __PACKAGE__;
    my $self = {
        'type'              => 'hostescalation',
        'primary_key'       => [ 'host_name', [ 'hostgroup_name' ] ],
        'default'           => $Monitoring::Config::Object::Hostescalation::Defaults,
        'can_have_no_name'  => 1,
    };
    bless $self, $class;
    return $self;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
