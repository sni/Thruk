package Monitoring::Config::Object::Hostescalation;

use warnings;
use strict;

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

$Monitoring::Config::Object::Hostescalation::primary_keys = [ 'host_name', [ 'hostgroup_name', 'first_notification', 'last_notification' ] ];
$Monitoring::Config::Object::Hostescalation::Defaults::standard_keys = [ 'host_name', 'contact_groups', 'first_notification', 'last_notification', 'escalation_period', 'escalation_options' ];

##########################################################

=head1 METHODS

=head2 BUILD

return new object

=cut
sub BUILD {
    my $class = shift || __PACKAGE__;
    my $self = {
        'type'              => 'hostescalation',
        'primary_key'       => $Monitoring::Config::Object::Hostescalation::primary_keys,
        'default'           => $Monitoring::Config::Object::Hostescalation::Defaults,
        'standard'          => $Monitoring::Config::Object::Hostescalation::Defaults::standard_keys,
        'can_have_no_name'  => 1,
        'primary_name_all_keys' => 1,
    };
    bless $self, $class;
    return $self;
}

##########################################################

1;
