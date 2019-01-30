package Monitoring::Config::Object::Serviceextinfo;

use strict;
use warnings;
use parent 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Servieextinfo - Serviceextinfo Object Configuration

=head1 DESCRIPTION

Defaults for serviceextinfo objects

=cut

##########################################################

$Monitoring::Config::Object::Serviceextinfo::Defaults = {
    'name'                  => { type => 'STRING', cat => 'Extended' },
    'use'                   => { type => 'LIST', link => 'serviceextinfo', cat => 'Basic' },
    'register'              => { type => 'BOOL', cat => 'Extended' },

    'host_name'             => { type => 'DEPRECATED' },
    'service_description'   => { type => 'DEPRECATED' },
    'notes'                 => { type => 'DEPRECATED' },
    'notes_url'             => { type => 'DEPRECATED' },
    'action_url'            => { type => 'DEPRECATED' },
    'icon_image'            => { type => 'DEPRECATED' },
    'icon_image_alt'        => { type => 'DEPRECATED' },
    'hostgroup_name'        => { type => 'DEPRECATED' },
    'hostgroup'             => { type => 'ALIAS', 'name' => 'hostgroup_name' },
};

##########################################################

=head1 METHODS

=head2 BUILD

return new object

=cut
sub BUILD {
    my $class = shift || __PACKAGE__;
    my $self = {
        'type'        => 'serviceextinfo',
        'deprecated'  => 1,
        'primary_key' => [ 'service_description', [ 'host_name', 'hostgroup_name' ] ],
        'default'     => $Monitoring::Config::Object::Serviceextinfo::Defaults,
    };
    bless $self, $class;
    return $self;
}

##########################################################

1;
