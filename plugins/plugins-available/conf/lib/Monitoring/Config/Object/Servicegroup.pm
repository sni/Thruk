package Monitoring::Config::Object::Servicegroup;

use strict;
use warnings;
use Moose;
extends 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Servicegroup - Servicegroup Object Configuration

=head1 DESCRIPTION

Defaults for servicegroup objects

=cut

##########################################################

$Monitoring::Config::Object::Servicegroup::Defaults = {
    'name'                  => { type => 'STRING', cat => 'Extended' },
    'use'                   => { type => 'LIST', link => 'servicegroup', cat => 'Basic' },
    'register'              => { type => 'BOOL', cat => 'Extended' },

    'servicegroup_name'     => { type => 'STRING', cat => 'Basic' },
    'alias'                 => { type => 'STRING', cat => 'Basic' },
    'members'               => { type => 'LIST', 'link' => 'service', cat => 'Basic' },
    'servicegroup_members'  => { type => 'LIST', 'link' => 'servicegroup', cat => 'Basic' },
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
        'type'        => 'servicegroup',
        'primary_key' => 'servicegroup_name',
        'default'     => $Monitoring::Config::Object::Servicegroup::Defaults,
        'standard'    => [ 'servicegroup_name', 'alias', 'members' ],
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
