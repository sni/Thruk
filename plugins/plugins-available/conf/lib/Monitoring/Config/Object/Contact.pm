package Monitoring::Config::Object::Contact;

use strict;
use warnings;
use parent 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Contact - Contact Object Configuration

=head1 DESCRIPTION

Defaults for contact objects

=cut

##########################################################

$Monitoring::Config::Object::Contact::Defaults = {
    'name'                          => { type => 'STRING', cat => 'Extended' },
    'use'                           => { type => 'LIST', link => 'contact', cat => 'Basic' },
    'register'                      => { type => 'BOOL', cat => 'Extended' },

    'contact_name'                  => { type => 'STRING', cat => 'Basic' },
    'alias'                         => { type => 'STRING', cat => 'Basic' },
    'contactgroups'                 => { type => 'LIST', 'link' => 'contactgroup', cat => 'Basic' },
    'host_notifications_enabled'    => { type => 'BOOL', cat => 'Notifications' },
    'service_notifications_enabled' => { type => 'BOOL', cat => 'Notifications' },
    'host_notification_period'      => { type => 'STRING', 'link' => 'timeperiod', cat => 'Notifications' },
    'service_notification_period'   => { type => 'STRING', 'link' => 'timeperiod', cat => 'Notifications' },
    'host_notification_options'     => { type => 'ENUM', values => ['d','u','r','f','s','n'], keys => [ 'Down', 'Unreachable', 'Recovery', 'Flapping', 'Downtime', 'None' ], cat => 'Notifications' },
    'service_notification_options'  => { type => 'ENUM', values => ['w','u','c','r','f','s','n'], keys => [ 'Warning', 'Unknown', 'Critical', 'Recovery', 'Flapping', 'Downtime', 'None' ], cat => 'Notifications' },
    'host_notification_commands'    => { type => 'LIST', 'link' => 'command', cat => 'Notifications' },
    'service_notification_commands' => { type => 'LIST', 'link' => 'command', cat => 'Notifications' },
    'email'                         => { type => 'STRING', cat => 'Basic' },
    'pager'                         => { type => 'STRING' },
    'address1'                      => { type => 'STRING', help => 'addressx' },
    'address2'                      => { type => 'STRING', help => 'addressx' },
    'address3'                      => { type => 'STRING', help => 'addressx' },
    'address4'                      => { type => 'STRING', help => 'addressx' },
    'address5'                      => { type => 'STRING', help => 'addressx' },
    'address6'                      => { type => 'STRING', help => 'addressx' },
    'can_submit_commands'           => { type => 'BOOL', cat => 'Basic' },
    'retain_status_information'     => { type => 'BOOL' },
    'retain_nonstatus_information'  => { type => 'BOOL' },
    'contact_groups'                => { type => 'ALIAS', 'name' => 'contactgroups', cat => 'Basic' },
};

# Only shinken has these...
$Monitoring::Config::Object::Contact::ShinkenSpecific = {
    'is_admin'              => { type => 'BOOL', cat => 'Extended' },
    'min_business_impact'   => { type => 'CHOOSE', values => [5,4,3,2,1,0], keys => [ 'Business Critical', 'Top Production', 'Production', 'Standard', 'Testing', 'Development' ], cat => 'Extended' },
};

##########################################################

=head1 METHODS

=head2 BUILD

return new object

=cut
sub BUILD {
    my $class = shift || __PACKAGE__;
    my $coretype = shift;
    if($coretype eq 'any' or $coretype eq 'shinken') {
        for my $key (keys %{$Monitoring::Config::Object::Contact::ShinkenSpecific}) {
            $Monitoring::Config::Object::Contact::Defaults->{$key} = $Monitoring::Config::Object::Contact::ShinkenSpecific->{$key};
        }
    } else {
        for my $key (keys %{$Monitoring::Config::Object::Contact::ShinkenSpecific}) {
            delete $Monitoring::Config::Object::Contact::Defaults->{$key};
        }
    }
    my $self = {
        'type'        => 'contact',
        'primary_key' => 'contact_name',
        'default'     => $Monitoring::Config::Object::Contact::Defaults,
        'standard'    => [ 'contact_name', 'use', 'alias', 'email', 'can_submit_commands' ],
    };
    bless $self, $class;
    return $self;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
