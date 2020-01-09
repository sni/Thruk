package Monitoring::Config::Object::Serviceescalation;

use strict;
use warnings;
use parent 'Monitoring::Config::Object::Parent';

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

    'host_name'              => { type => 'LIST', 'link' => 'host' },
    'hostgroup_name'         => { type => 'LIST', 'link' => 'hostgroup' },
    'service_description'    => { type => 'LIST', 'link' => 'service' },
    'servicegroup_name'      => { type => 'LIST', 'link' => 'servicegroup' },
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

$Monitoring::Config::Object::Serviceescalation::primary_keys = [ 'host_name', [ 'hostgroup_name' ] ];
$Monitoring::Config::Object::Serviceescalation::Defaults::standard_keys = [ 'host_name', 'service_description', 'contact_groups', 'first_notification', 'last_notification', 'escalation_period', 'escalation_options' ];

##########################################################

=head1 METHODS

=head2 BUILD

return new object

=cut
sub BUILD {
    my $class = shift || __PACKAGE__;
    my $self = {
        'type'              => 'serviceescalation',
        'primary_key'       => $Monitoring::Config::Object::Serviceescalation::primary_keys,
        'default'           => $Monitoring::Config::Object::Serviceescalation::Defaults,
        'standard'          => $Monitoring::Config::Object::Serviceescalation::Defaults::standard_keys,
        'can_have_no_name'  => 1,
        'primary_name_all_keys' => 1,
    };
    bless $self, $class;
    return $self;
}

##########################################################

1;
