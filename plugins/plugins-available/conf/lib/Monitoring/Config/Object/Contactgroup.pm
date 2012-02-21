package Monitoring::Config::Object::Contactgroup;

use strict;
use warnings;
use Moose;
extends 'Monitoring::Config::Object::Parent';

=head1 NAME

Monitoring::Config::Object::Contactgroup - Contactgroup Object Configuration

=head1 DESCRIPTION

Defaults for contactgroup objects

=cut

##########################################################

$Monitoring::Config::Object::Contactgroup::Defaults = {
    'name'                 => { type => 'STRING', cat => 'Extended' },
    'use'                  => { type => 'LIST', link => 'contactgroup', cat => 'Basic' },
    'register'             => { type => 'BOOL', cat => 'Extended' },

    'contactgroup_name'    => { type => 'STRING', cat => 'Basic' },
    'alias'                => { type => 'STRING', cat => 'Basic' },
    'members'              => { type => 'LIST', 'link' => 'contact', cat => 'Basic' },
    'contactgroup_members' => { type => 'LIST', 'link' => 'contactgroup', cat => 'Basic' },
};

##########################################################

=head1 METHODS

=head2 BUILD

return new object

=cut
sub BUILD {
    my $class = shift || __PACKAGE__;
    my $self = {
        'type'        => 'contactgroup',
        'primary_key' => 'contactgroup_name',
        'default'     => $Monitoring::Config::Object::Contactgroup::Defaults,
        'standard'    => [ 'contactgroup_name', 'alias', 'members' ],
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
