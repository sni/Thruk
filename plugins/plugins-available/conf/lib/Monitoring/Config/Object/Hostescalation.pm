package Monitoring::Config::Object::Hostescalation;

use strict;
use warnings;
use Moose;
extends 'Monitoring::Config::Object::Parent';

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

    'host_name'              => { type => 'STRING', 'link' => 'host' },
    'hostgroup_name'         => { type => 'LIST',   'link' => 'hostgroup' },
    'contacts'               => { type => 'LIST',   'link' => 'contact' },
    'contact_groups'         => { type => 'LIST',   'link' => 'contactgroup' },
    'first_notification'     => { type => 'INT' },
    'last_notification'      => { type => 'INT' },
    'notification_interval'  => { type => 'INT' },
    'escalation_period'      => { type => 'STRING', 'link' => 'timeperiod' },
    'escalation_options'     => { type => 'ENUM', values => ['w','u','c','r'], keys => [ 'Ok', 'Warning', 'Critical','Unknown' ] },

    # aliased attributes
    'host'                   => { type => 'ALIAS', 'name' => 'host_name' },
    'hostgroup'              => { type => 'ALIAS', 'name' => 'hostgroup_name' },
    'hostgroups'             => { type => 'ALIAS', 'name' => 'hostgroup_name' },
};

##########################################################

=head1 METHODS

=head2 new

return new object

=cut
sub new {
    my $class = shift || __PACKAGE__;
    my $self = {
        'type'        => 'hostescalation',
        'primary_key' => [ 'host_name', [ 'hostgroup_name' ] ],
        'default'     => $Monitoring::Config::Object::Hostescalation::Defaults,
    };
    bless $self, $class;
    return $self;
}


##########################################################

=head2 parse

parse the object config

=cut
sub parse {
    my $self = shift;
    return $self->SUPER::parse($self->{'default'});
}




=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
