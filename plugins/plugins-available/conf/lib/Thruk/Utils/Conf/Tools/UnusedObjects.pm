package Thruk::Utils::Conf::Tools::UnusedObjects;

use strict;
use warnings;
use Thruk::Utils::Conf;

=head1 NAME

Thruk::Utils::Conf::Tools::UnusedObjects.pm - Tool to find unused objects

=head1 DESCRIPTION

Tool to find ununsed objects

=head1 METHODS

=cut

##########################################################

=head2 new($c)

returns new instance of this tool

=cut
sub new {
    my($class) = @_;
    my $self = {
        category    => 'Cleanup',
        link        => 'Find Unused Objects',
        title       => 'Unused Objects',
        description => 'Find all objects not used anywhere',
        fixlink     => 'remove',
    };
    bless($self, $class);
    return($self);
}

##########################################################

=head2 get_list($c, $ignores)

returns list of potential objects to remove

=cut
sub get_list {
    my($self, $c, $ignores) = @_;
    my $result = $c->{'obj_db'}->_check_orphaned_objects();
    return(Thruk::Utils::Conf::clean_from_tool_ignores($result, $ignores));
}

##########################################################

=head2 cleanup

cleanup this object

=cut
sub cleanup {
    my($self, $c, $ident, $ignores) = @_;
    if($ident eq 'all') {
        my $list = $self->get_list($c, $ignores);
        for my $data (@{$list}) {
            next if $data->{'obj'}->{'file'}->{'readonly'};
            $self->cleanup($c, $data->{'obj'}->get_id());
        }
        return;
    }
    my $obj = $c->{'obj_db'}->get_object_by_id($ident);
    if($obj) {
        if($obj->{'file'}->{'readonly'}) {
            Thruk::Utils::set_message( $c, 'fail_message', 'this file is readonly' );
        } else {
            $c->{'obj_db'}->delete_object($obj);
        }
    } else {
        Thruk::Utils::set_message( $c, 'fail_message', 'no such object' );
    }
    return;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
