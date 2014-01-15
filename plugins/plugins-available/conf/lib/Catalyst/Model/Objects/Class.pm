package Catalyst::Model::Objects::Class;

use Moose;
use Monitoring::Config::Multi;

extends 'Catalyst::Model';

has obj => (
    is => 'rw',
    isa => 'Monitoring::Config::Multi'
);

sub BUILD {
    my ( $self, $args ) = @_;
    $self->{obj} = Monitoring::Config::Multi->new();
    return;
}

sub ACCEPT_CONTEXT {
    return shift->obj;
};

__PACKAGE__->meta->make_immutable;

1;
__END__
=head1 NAME

Catalyst::Model::Thruk::Class - Catalyst model for Thruk::Class

=head1 DESCRIPTION

This is a L<Catalyst> model for the L<Thruk::Class>

=head1 SYNOPSIS

    # Use the helper to add an Thruk::Class model to your application...
    ./script/thruk_create.pl model Thruk Thruk::Class

    # lib/MyApp/Model/Thruk.pm
    package Thruk::Model::Thruk;

    use strict;
    use warnings;

    use parent qw/ Catalyst::Model::Thruk::Class /;

=head1 INTERNAL METHODS

=over 4

=item BUILD

=item ACCEPT_CONTEXT

=back

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Sven Nierlein.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut
