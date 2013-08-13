package Catalyst::Helper::Model::Thruk::Class;

use strict;
use warnings;
use Carp qw/ croak /;

=head1 NAME

Catalyst::Helper::Model::Thruk::Class - Helper Class for Catalyst::Model::Thruk::Class

=head1 SYNOPSIS

    ./script/thruk_create.pl model Thruk Thruk::Class

=head1 METHODS

=head2 mk_compclass

=cut

sub mk_compclass {
    my ( $self, $helper, $peer ) = @_;
    $helper->{peer} = $peer;
    return $helper->render_file( 'thruk_class', $helper->{file} );
}


=head1 AUTHOR

Sven Nierlein, C<< <nierlein at cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Sven Nierlein.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;
