package Thruk::Backend::Provider::Merlin;

use strict;
use warnings;
use Carp;
use parent 'Thruk::Backend::Provider::Base';

=head1 NAME

Thruk::Backend::Provider::Merlin - connection provider for merlin connections

=head1 DESCRIPTION

connection provider for merlin connections

=head1 METHODS

=head2 new

create new manager

=cut


##########################################################
sub new {
    my( $class, $c ) = @_;
    my $self = {};
    bless $self, $class;
    return $self;
}

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
