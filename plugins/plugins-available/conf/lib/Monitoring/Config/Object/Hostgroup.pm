package Monitoring::Config::Object::Hostgroup;

use strict;
use warnings;
use Moose;
extends 'Monitoring::Config::Object::Parent';

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

=head2 new

return new object

=cut
sub new {
    my $class = shift || __PACKAGE__;
    my $self = {
        'type'        => 'hostgroup',
        'primary_key' => 'hostgroup_name',
        'default'     => $Monitoring::Config::Object::Hostgroup::Defaults,
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
