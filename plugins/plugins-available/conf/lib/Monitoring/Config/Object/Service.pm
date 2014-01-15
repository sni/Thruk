package Monitoring::Config::Object::Service;

use strict;
use warnings;
use parent 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Service - Service Object Configuration

=head1 DESCRIPTION

Defaults for service objects

=cut

##########################################################

$Monitoring::Config::Object::Service::Defaults = {
    'name'                              => { type => 'STRING', cat => 'Extended' },
    'use'                               => { type => 'LIST', link => 'service', cat => 'Basic' },
    'register'                          => { type => 'BOOL', cat => 'Extended' },

    'host_name'                         => { type => 'LIST', 'link' => 'host', cat => 'Basic' },
    'hostgroup_name'                    => { type => 'LIST', 'link' => 'hostgroup', cat => 'Basic' },
    'service_description'               => { type => 'STRING', cat => 'Basic' },
    'display_name'                      => { type => 'STRING', cat => 'Extended' },
    'servicegroups'                     => { type => 'LIST', 'link' => 'servicegroup', cat => 'Basic' },
    'is_volatile'                       => { type => 'BOOL', cat => 'Extended' },
    'check_command'                     => { type => 'COMMAND', 'link' => 'command', cat => 'Checks' },
    'initial_state'                     => { type => 'CHOOSE', values => ['o','w','u','c'], keys => [ 'Ok', 'Warning', 'Unknown', 'Critical' ], cat => 'Extended' },
    'max_check_attempts'                => { type => 'INT', cat => 'Checks' },
    'check_interval'                    => { type => 'INT', cat => 'Checks' },
    'retry_interval'                    => { type => 'INT', cat => 'Checks' },
    'active_checks_enabled'             => { type => 'BOOL', cat => 'Checks' },
    'passive_checks_enabled'            => { type => 'BOOL', cat => 'Checks' },
    'check_period'                      => { type => 'STRING', 'link' => 'timeperiod', cat => 'Checks' },
    'obsess_over_service'               => { type => 'BOOL' },
    'check_freshness'                   => { type => 'BOOL' },
    'freshness_threshold'               => { type => 'INT', cat => 'Flapping' },
    'event_handler'                     => { type => 'LIST', 'link' => 'command', cat => 'Eventhandler' },
    'event_handler_enabled'             => { type => 'BOOL', cat => 'Eventhandler' },
    'low_flap_threshold'                => { type => 'INT', cat => 'Flapping' },
    'high_flap_threshold'               => { type => 'INT', cat => 'Flapping' },
    'flap_detection_enabled'            => { type => 'BOOL', cat => 'Flapping' },
    'flap_detection_options'            => { type => 'ENUM', values => ['o','w','c','u'], keys => [ 'Ok', 'Warning', 'Critical','Unknown' ], cat => 'Flapping' },
    'process_perf_data'                 => { type => 'BOOL', cat => 'Extended' },
    'retain_status_information'         => { type => 'BOOL' },
    'retain_nonstatus_information'      => { type => 'BOOL' },
    'notification_interval'             => { type => 'INT', cat => 'Notifications' },
    'first_notification_delay'          => { type => 'INT', cat => 'Notifications' },
    'notification_period'               => { type => 'STRING', 'link' => 'timeperiod', cat => 'Notifications' },
    'notification_options'              => { type => 'ENUM', values => ['w','u','c','r','f','s','n'], keys => [ 'Warning','Unknown','Critical','Recovery','Flapping','Downtime','None' ], cat => 'Notifications' },
    'notifications_enabled'             => { type => 'BOOL', cat => 'Notifications' },
    'contacts'                          => { type => 'LIST', 'link' => 'contact', cat => 'Contacts' },
    'contact_groups'                    => { type => 'LIST', 'link' => 'contactgroup', cat => 'Contacts' },
    'stalking_options'                  => { type => 'ENUM', values => ['o','w','u','c'], keys => [ 'Ok','Warning','Unknown','Critical' ] },
    'notes'                             => { type => 'STRING', cat => 'Ext Info' },
    'notes_url'                         => { type => 'STRING', cat => 'Ext Info' },
    'action_url'                        => { type => 'STRING', cat => 'Ext Info' },
    'icon_image'                        => { type => 'STRING', link => 'icon', cat => 'Ext Info' },
    'icon_image_alt'                    => { type => 'STRING', cat => 'Ext Info' },

    # aliased attributes
    'normal_check_interval'             => { type => 'ALIAS', 'name' => 'check_interval' },
    'retry_check_interval'              => { type => 'ALIAS', 'name' => 'retry_interval' },
    'host'                              => { type => 'ALIAS', 'name' => 'host_name' },
    'hosts'                             => { type => 'ALIAS', 'name' => 'host_name' },
    'description'                       => { type => 'ALIAS', 'name' => 'service_description' },
    'hostgroup'                         => { type => 'ALIAS', 'name' => 'hostgroup_name' },
    'hostgroups'                        => { type => 'ALIAS', 'name' => 'hostgroup_name' },
    'service_groups'                    => { type => 'ALIAS', 'name' => 'servicegroups' },

    # deprecated attributes
    'parallelize_check'                 => { type => 'DEPRECATED' },
    'failure_prediction_enabled'        => { type => 'DEPRECATED' },
};

# Only shinken has these...
$Monitoring::Config::Object::Service::ShinkenSpecific = {
    'business_impact'              => { type => 'CHOOSE', values => [5,4,3,2,1,0], keys => [ 'Business Critical', 'Top Production', 'Production', 'Standard', 'Testing', 'Development' ], cat => 'Extended' },
    'criticity'                    => { type => 'ALIAS', 'name' => 'business_impact' },
    'maintenance_period'           => { type => 'STRING', 'link' => 'timeperiod', cat => 'Checks' },
    'poller_tag'                   => { type => 'STRING', cat => 'Extended' },
    'reactionner_tag'              => { type => 'STRING', cat => 'Extended' },
    'resultmodulations'            => { type => 'STRING', cat => 'Extended' },
    'business_impact_modulations'  => { type => 'STRING', cat => 'Extended' },
    'escalations'                  => { type => 'STRING', 'link' => 'escalation', cat => 'Extended' },
    'icon_set'                     => { type => 'STRING', cat => 'Extended' },
};

##########################################################

=head1 METHODS

=head2 BUILD

return new object

=cut
sub BUILD {
    my $class    = shift || __PACKAGE__;
    my $coretype = shift;
    if($coretype eq 'any' or $coretype eq 'shinken') {
        for my $key (keys %{$Monitoring::Config::Object::Service::ShinkenSpecific}) {
            $Monitoring::Config::Object::Service::Defaults->{$key} = $Monitoring::Config::Object::Service::ShinkenSpecific->{$key};
        }
    } else {
        for my $key (keys %{$Monitoring::Config::Object::Service::ShinkenSpecific}) {
            delete $Monitoring::Config::Object::Service::Defaults->{$key};
        }
    }
    my $self = {
        'type'        => 'service',
        'primary_key' => [ 'service_description', [ 'host_name', 'hostgroup_name' ] ],
        'default'     => $Monitoring::Config::Object::Service::Defaults,
        'standard'    => [ 'service_description', 'use', 'host_name', 'check_command', 'contact_groups' ],
    };
    bless $self, $class;
    return $self;
}

##########################################################

=head2 get_macros

return all macros for this service

=cut
sub get_macros {
    my $self    = shift;
    my $objects = shift;
    my $macros  = shift || {};
    my($svc_conf_keys, $svc_config) = $self->get_computed_config($objects);

    # normal service macros
    $macros->{'$SERVICEDESC$'}         = $svc_config->{'service_description'};
    $macros->{'$SERVICECHECKCOMMAND$'} = $svc_config->{'check_command'};
    $macros->{'$SERVICESTATE$'}        = 0;
    $macros->{'$SERVICEDURATIONSEC$'}  = 0;

    # service user macros
    for my $key (@{$svc_conf_keys}) {
        next unless substr($key,0,1) eq '_';
        $key = substr($key, 1);
        $macros->{'$_SERVICE'.$key.'$'}  = $svc_config->{'_'.$key};
    }

    return $macros;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
