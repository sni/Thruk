package Catalyst::Engine::Thrukembedded;

use strict;
use base 'Catalyst::Engine::CGI';

sub finalize_headers {
    my ( $self, $c ) = @_;
    $c->response->headers->clear() if $c->response->status == 200;
    $ENV{'HTTP_CODE'} = $c->response->status;
    return;
}

1;

__END__

=head1 NAME

Catalyst::Engine::Thrukembedded - use app embedded in scripts

=head1 DESCRIPTION

Use this engine to embed the application in a script. We
just use the CGI engine and remove the http header.

=head1 OVERLOADED METHODS

=over

=item finalize_headers

remove headers

=back

=head1 SEE ALSO

L<Catalyst>.

=head1 AUTHORS

Sven Nierlein, 2012, <nierlein@cpan.org>

=head1 LICENSE

This library is free software . You can redistribute it and/or modify
it under the same terms as perl itself.

=cut
