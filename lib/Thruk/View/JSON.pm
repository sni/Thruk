package Thruk::View::JSON;

use strict;
use JSON::XS ();
use base 'Catalyst::View::JSON';

=head1 NAME

Thruk::View::JSON - JSON View for Thruk

=head1 DESCRIPTION

JSON View for Thruk.

=head1 METHODS

=head2 encode_json

encodes data into json object

=cut
sub encode_json {
    my($self, $c, $data) = @_;
    my $encoder = JSON::XS->new
                          ->ascii
                          ->pretty
                          ->allow_blessed
                          ->allow_nonref;
    return $encoder->encode($data);
}

=head1 AUTHOR

=head1 SEE ALSO

L<Thruk>

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
