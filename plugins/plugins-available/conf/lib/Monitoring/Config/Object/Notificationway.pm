package Monitoring::Config::Object::Notificationway;

use warnings;
use strict;

use parent 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Notificationway - Shinken notificationway Object Configuration

=head1 DESCRIPTION

Defaults for notificationway objects

=cut

##########################################################

$Monitoring::Config::Object::Notificationway::Defaults = {
    'name'                            => { type => 'STRING', cat => 'Extended' },
    'use'                             => { type => 'LIST', link => 'notificationway', cat => 'Basic' },
    'register'                        => { type => 'BOOL', cat => 'Extended' },

    'notificationway_name'            => { type => 'STRING', cat => 'Basic' },
    'host_notifications_enabled'      => { type => 'BOOL', cat => 'Notifications' },
    'service_notifications_enabled'   => { type => 'BOOL', cat => 'Notifications' },
    'host_notification_period'        => { type => 'STRING', 'link' => 'timeperiod', cat => 'Notifications' },
    'service_notification_period'     => { type => 'STRING', 'link' => 'timeperiod', cat => 'Notifications' },
    'host_notification_options'       => { type => 'ENUM', values => ['d','u','r','f','s','n'], keys => [ 'Down', 'Unreachable', 'Recovery', 'Flapping', 'Downtime', 'None' ], cat => 'Notifications' },
    'service_notification_options'    => { type => 'ENUM', values => ['w','u','c','r','f','s','n'], keys => [ 'Warning', 'Unknown', 'Critical', 'Recovery', 'Flapping', 'Downtime', 'None' ], cat => 'Notifications' },
    'host_notification_commands'      => { type => 'LIST', 'link' => 'command', cat => 'Notifications' },
    'service_notification_commands'   => { type => 'LIST', 'link' => 'command', cat => 'Notifications' },
    'min_business_impact'             => { type => 'CHOOSE', values => [5,4,3,2,1,0], keys => Monitoring::Config::Object::Parent::business_impact_keys(), cat => 'Extended' },
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
        'type'        => 'notificationway',
        'primary_key' => 'notificationway_name',
        'default'     => $Monitoring::Config::Object::Notificationway::Defaults,
        'standard'    => [ 'notificationway_name', 'host_notification_period', 'service_notification_period', 'host_notification_options', 'service_notification_options', 'host_notification_commands' ],
    };
    bless $self, $class;
    return $self;
}

##########################################################

1;
