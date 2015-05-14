package Thruk::Request;
use strict;
use warnings;
use parent qw/Plack::Request/;
use Encode ();
use Carp ();
use Hash::MultiValue;
use URI::Escape qw/uri_unescape/;

use constant KEY_BASE_NAME    => 'thruk.request';
use constant DEFAULT_ENCODING => 'utf-8';

sub encoding {
    my $env = $_[0]->env;
    my $k   = KEY_BASE_NAME.'.encoding';

    # In order to be able to specify the `undef` into $req->env->{plack.request.withencoding.encoding}
    return(exists $env->{$k} ? $env->{$k} : ($env->{$k} = DEFAULT_ENCODING));
}

sub body_parameters {
    my $self = shift;
    return($self->env->{KEY_BASE_NAME.'.body'} ||= $self->_decode_parameters($self->SUPER::body_parameters));
}

sub query_parameters {
    my $self = shift;
    return($self->env->{KEY_BASE_NAME.'.query'} ||= $self->_decode_parameters($self->SUPER::query_parameters));
}

sub parameters {
    my $self = shift;
    return($self->env->{KEY_BASE_NAME.'.merged'} ||= do {
        my $query = $self->query_parameters;
        my $body  = $self->body_parameters;
        Hash::MultiValue->new($query->flatten, $body->flatten);
    });
}

sub _decode_parameters {
    my ($self, $stuff) = @_;
    return $stuff unless $self->encoding; # return raw value if encoding method is `undef`

    my $encoding = Encode::find_encoding($self->encoding);
    unless ($encoding) {
        my $invalid_encoding = $self->encoding;
        Carp::croak("Unknown encoding '$invalid_encoding'.");
    }

    my @flatten = $stuff->flatten;
    my @decoded;
    while ( my ($k, $v) = splice @flatten, 0, 2 ) {
        push @decoded, $encoding->decode($k), $encoding->decode($v);
    }
    return Hash::MultiValue->new(@decoded);
}

sub url {
    my $self = shift;
    my $url = uri_unescape("".$self->uri);
    return unless $url;
    my $encoding = Encode::find_encoding($self->encoding);
    unless($encoding) {
        my $invalid_encoding = $self->encoding;
        Carp::croak("Unknown encoding '$invalid_encoding'.");
    }
    return($encoding->decode($url));
}

1;
__END__

=head1 NAME

Thruk::Request - Subclass of L<Plack::Request> which supports encoding.

=head1 DESCRIPTION

based on Plack::Request::WithEncoding.

=head1 WMETHODS

=head2 encoding

Returns a encoding method to use to decode parameters.

=head2 query_parameters

Returns a reference to a hash containing B<decoded> query string (GET)
parameters. This hash reference is L<Hash::MultiValue> object.

=head2 body_parameters

Returns a reference to a hash containing B<decoded> posted parameters in the
request body (POST). As with C<query_parameters>, the hash
reference is a L<Hash::MultiValue> object.

=head2 parameters

Returns a L<Hash::MultiValue> hash reference containing B<decoded> (and merged) GET
and POST parameters.

=head2 param

Returns B<decoded> GET and POST parameters.

=head2 url

Returns urldecoded utf8 uri as string.

=head1 SEE ALSO

L<Plack::Request>, L<Plack::Request::WithEncoding>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Sven Nierlein, E<lt>sven@nierlein.orgE<gt>
moznion E<lt>moznion@gmail.comE<gt>

=cut
