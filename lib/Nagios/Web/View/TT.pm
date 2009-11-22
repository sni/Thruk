package Nagios::Web::View::TT;

use strict;
use MRO::Compat;
use Digest::MD5 'md5_hex';
use base 'Catalyst::View::TT';

__PACKAGE__->config(
                    TEMPLATE_EXTENSION => '.tt',
                    ENCODING           => 'utf8',
                    INCLUDE_PATH       =>  'templates',
                    );

sub process {
    my $self = shift;
    my $c = $_[0];

    $self->next::method(@_) or return 0;

    my $method = $c->request->method;
    return 1 if $method ne 'GET' and $method ne 'HEAD' or $c->stash->{nocache};    # disable caching explicitely

    my $body = $c->response->body;
    if ($body) {
        utf8::encode($body) if utf8::is_utf8($body);
        $c->response->headers->etag(md5_hex($body));
    }

    return 1;
}


=head1 NAME

Nagios::Web::View::TT - TT View for Nagios::Web

=head1 DESCRIPTION

TT View for Nagios::Web.

=head1 AUTHOR

=head1 SEE ALSO

L<Nagios::Web>

sven,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
