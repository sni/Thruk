package Monitoring::Config::Object::Serviceescalation;

use strict;
use warnings;
use Moose;
extends 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Serviceescalation - Serviceescalation Object Configuration

=head1 DESCRIPTION

Defaults for serviceescalation objects

=cut

##########################################################

$Monitoring::Config::Object::Serviceescalation::Defaults = {
    'name'                   => { type => 'STRING', cat => 'Extended' },
    'use'                    => { type => 'LIST', link => 'serviceescalation', cat => 'Basic' },
    'register'               => { type => 'BOOL', cat => 'Extended' },

    'host_name'              => { type => 'STRING', 'link' => 'host' },
    'hostgroup_name'         => { type => 'LIST', 'link' => 'hostgroup' },
    'service_description'    => { type => 'STRING' },
    'contacts'               => { type => 'LIST', 'link' => 'contact' },
    'contact_groups'         => { type => 'LIST', 'link' => 'contactgroup' },
    'first_notification'     => { type => 'INT' },
    'last_notification'      => { type => 'INT' },
    'notification_interval'  => { type => 'INT' },
    'escalation_period'      => { type => 'STRING', 'link' => 'timeperiod' },
    'escalation_options'     => { type => 'ENUM', values => ['w','u','c','r'], keys => [ 'Ok', 'Warning', 'Critical','Unknown' ] },

    # aliased attributes
    'host'                   => { type => 'ALIAS', 'name' => 'host_name' },
    'description'            => { type => 'ALIAS', 'name' => 'service_description' },
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
        'type'        => 'serviceescalation',
        'primary_key' => [ 'service_description', [ 'host_name', 'hostgroup_name' ] ],
        'default'     => $Monitoring::Config::Object::Serviceescalation::Defaults,
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

__PACKAGE__->meta->make_immutable;

1;
