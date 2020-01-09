package Monitoring::Config::Object::Servicedependency;

use strict;
use warnings;
use parent 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Servicedependency - Servicedependency Object Configuration

=head1 DESCRIPTION

Defaults for servicedependency objects

=cut

##########################################################

$Monitoring::Config::Object::Servicedependency::Defaults = {
    'name'                          => { type => 'STRING', cat => 'Extended' },
    'use'                           => { type => 'LIST', link => 'servicedependency', cat => 'Basic' },
    'register'                      => { type => 'BOOL', cat => 'Extended' },

    'dependent_host_name'           => { type => 'LIST', 'link' => 'host' },
    'dependent_hostgroup_name'      => { type => 'LIST', 'link' => 'hostgroup' },
    'dependent_servicegroup_name'   => { type => 'LIST', 'link' => 'servicegroup' },
    'dependent_service_description' => { type => 'LIST', 'link' => 'service' },
    'host_name'                     => { type => 'LIST', 'link' => 'host' },
    'hostgroup_name'                => { type => 'LIST', 'link' => 'hostgroup' },
    'servicegroup_name'             => { type => 'LIST', 'link' => 'servicegroup' },
    'service_description'           => { type => 'STRING', 'link' => 'service' },
    'inherits_parent'               => { type => 'BOOL' },
    'execution_failure_criteria'    => { type => 'ENUM', values => ['o','w','u','c','p','n'], keys => [ 'Ok', 'Warning', 'Unknown', 'Critical', 'Pending', 'None' ] },
    'notification_failure_criteria' => { type => 'ENUM', values => ['o','w','u','c','p','n'], keys => [ 'Ok', 'Warning', 'Unknown', 'Critical', 'Pending', 'None' ] },
    'dependency_period'             => { type => 'STRING', link => 'timeperiod' },

    'hostgroup'                     => { type => 'ALIAS', 'name' => 'hostgroup_name' },
    'hostgroups'                    => { type => 'ALIAS', 'name' => 'hostgroup_name' },
    'host'                          => { type => 'ALIAS', 'name' => 'host_name' },
    'master_host'                   => { type => 'ALIAS', 'name' => 'host_name' },
    'master_host_name'              => { type => 'ALIAS', 'name' => 'host_name' },
    'description'                   => { type => 'ALIAS', 'name' => 'service_description' },
    'master_description'            => { type => 'ALIAS', 'name' => 'service_description' },
    'master_service_description'    => { type => 'ALIAS', 'name' => 'service_description' },
    'dependent_hostgroup'           => { type => 'ALIAS', 'name' => 'dependent_hostgroup_name' },
    'dependent_hostgroups'          => { type => 'ALIAS', 'name' => 'dependent_hostgroup_name' },
    'dependent_host'                => { type => 'ALIAS', 'name' => 'dependent_host_name' },
    'dependent_description'         => { type => 'ALIAS', 'name' => 'dependent_service_description' },
    'execution_failure_options'     => { type => 'ALIAS', 'name' => 'execution_failure_criteria' },
    'notification_failure_options'  => { type => 'ALIAS', 'name' => 'notification_failure_criteria' },
};

$Monitoring::Config::Object::Servicedependency::primary_keys = [ 'service_description', [ 'host_name', 'hostgroup_name' ] ];
$Monitoring::Config::Object::Servicedependency::Defaults::standard_keys = [ 'dependent_host_name', 'dependent_service_description', 'host_name', 'service_description', 'execution_failure_criteria', 'notification_failure_criteria' ];

##########################################################

=head1 METHODS

=head2 BUILD

return new object

=cut
sub BUILD {
    my $class = shift || __PACKAGE__;
    my $self = {
        'type'        => 'servicedependency',
        'primary_key' => $Monitoring::Config::Object::Servicedependency::primary_keys,
        'default'     => $Monitoring::Config::Object::Servicedependency::Defaults,
        'standard'    => $Monitoring::Config::Object::Servicedependency::Defaults::standard_keys,
        'primary_name_all_keys' => 1,
    };
    bless $self, $class;
    return $self;
}

##########################################################

1;
