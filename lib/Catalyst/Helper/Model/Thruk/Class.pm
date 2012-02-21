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

__PACKAGE__->meta->make_immutable;

1;
__DATA__
=begin pod_to_ignore

__thruk_class__
package [% class %];

use strict;
use warnings;

use base qw/ Catalyst::Model::Thruk::Class /;

=head1 NAME

[% class %]

=head1 SYNOPSIS

See L<[% app %]>.

=head1 DESCRIPTION

Thruk::Class Model Class.

=head1 AUTHOR

[% author %]

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

=cut

1;
