package Monitoring::Config::Object::Hostgroup;

use strict;
use warnings;
use parent 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Hostgroup - Hostgroup Object Configuration

=head1 DESCRIPTION

Defaults for hostgroup objects

=cut

##########################################################

$Monitoring::Config::Object::Hostgroup::Defaults = {
    'name'                  => { type => 'STRING', cat => 'Extended' },
    'use'                   => { type => 'LIST', link => 'hostgroup', cat => 'Basic' },
    'register'              => { type => 'BOOL', cat => 'Extended' },

    'hostgroup_name'        => { type => 'STRING', cat => 'Basic' },
    'alias'                 => { type => 'STRING', cat => 'Basic' },
    'members'               => { type => 'LIST', 'link' => 'host', cat => 'Basic' },
    'hostgroup_members'     => { type => 'LIST', 'link' => 'hostgroup', cat => 'Basic' },
    'notes'                 => { type => 'STRING', cat => 'Ext Info' },
    'notes_url'             => { type => 'STRING', cat => 'Ext Info' },
    'action_url'            => { type => 'STRING', cat => 'Ext Info' },
};

##########################################################

=head1 METHODS

=head2 BUILD

return new object

=cut
sub BUILD {
    my $class = shift || __PACKAGE__;
    my $self = {
        'type'              => 'hostgroup',
        'primary_key'       => 'hostgroup_name',
        'default'           => $Monitoring::Config::Object::Hostgroup::Defaults,
        'standard'          => [ 'hostgroup_name', 'alias', 'members' ],
        'can_have_no_name'  => 1, # hostgroups with register 0 without names are possible
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
