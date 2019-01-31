package Thruk::Request;
use strict;
use warnings;
use Plack 1.0046;
use parent qw/Plack::Request/;
use Encode qw/find_encoding/;
use Hash::MultiValue;
use URI::Escape qw/uri_unescape/;

use constant KEY_BASE_NAME    => 'thruk.request';
use constant DEFAULT_ENCODING => 'utf-8';

sub encoding {
    return(Encode::find_encoding(DEFAULT_ENCODING));
}

sub body_parameters {
    my $self = shift;
    return($self->env->{KEY_BASE_NAME.'.body'} ||= $self->_decode_parameters($self->SUPER::body_parameters)->mixed);
}

sub query_parameters {
    my $self = shift;
    return($self->env->{KEY_BASE_NAME.'.query'} ||= $self->_decode_parameters($self->SUPER::query_parameters)->mixed);
}

sub parameters {
    my $self = shift;
    return($self->env->{KEY_BASE_NAME.'.merged'} ||= do {
        my $query = Hash::MultiValue->from_mixed($self->query_parameters);
        my $body  = Hash::MultiValue->from_mixed($self->body_parameters);
        Hash::MultiValue->new($query->flatten, $body->flatten)->mixed;
    });
}

sub _decode_parameters {
    my ($self, $stuff) = @_;
    my $encoding = $self->encoding;
    my @flatten  = $stuff->flatten;
    my @decoded;
    while(my($k, $v) = splice(@flatten, 0, 2)) {
        push @decoded, $encoding->decode($k), $encoding->decode($v);
    }
    return Hash::MultiValue->new(@decoded);
}

sub url {
    my($self) = @_;
    return($self->env->{KEY_BASE_NAME.'.url'} ||= $self->_url());
}

sub _url {
    my($self) = @_;
    my $url = uri_unescape("".$self->uri);
    return unless $url;
    return($self->encoding->decode($url));
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
parameters.

=head2 body_parameters

Returns a reference to a hash containing B<decoded> posted parameters in the
request body (POST). As with C<query_parameters>.

=head2 parameters

Returns a hash reference containing B<decoded> (and merged) GET
and POST parameters.

=head2 param

Returns B<decoded> GET and POST parameters.

=head2 url

Returns urldecoded utf8 uri as string.

=head1 SEE ALSO

L<Plack::Request>, L<Plack::Request::WithEncoding>

=cut
