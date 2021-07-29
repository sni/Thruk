package Thruk::Request;
use warnings;
use strict;
use Encode ();
use Hash::MultiValue;
use Plack 1.0046;
use URI::Escape qw/uri_unescape/;

use parent qw/Plack::Request/;

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
    my($self, $val) = @_;
    if(defined $val) {
        $self->env->{KEY_BASE_NAME.'.merged'} = $val;
        return($val);
    }
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
        # skip all request parameters with illegal characters in their name
        next if $k !~ m/^[a-zA-Z0-9\/\.:,;\+\-_\[\]\(\)\{\}]+$/mx;

        my $v_decoded;
        if (ref $v eq 'ARRAY') {
            foreach (@{$v}) {
                push @{$v_decoded}, $encoding->decode($_);
            }
        } else {
                $v_decoded = $encoding->decode($v);
        }
        push @decoded, $encoding->decode($k), $v_decoded;
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

# returns uri, but applies HTTP_X_FORWARDED_* environment if set
sub uri {
    my($self) = @_;
    my $uri = $self->SUPER::uri(@_);

    my $scheme = $self->{'env'}->{'HTTP_X_FORWARDED_PROTO'};  # from X-FORWARDED-PROTO http header
    $scheme =~ s/\s*,.*$//mx if $scheme; # use first in list
    if($scheme && $scheme =~ m/^https?$/mx) {
        $uri->scheme($scheme);
    }

    my $host = $self->{'env'}->{'HTTP_X_FORWARDED_HOST'}; # from X-FORWARDED-HOST http header
    $host =~ s/\s*,.*$//mx if $host; # use first in list
    if($host && _is_valid_hostname($host)) {
        $uri->host($host);
    }

    my $port = $self->{'env'}->{'HTTP_X_FORWARDED_PORT'}; # from X-FORWARDED-PORT http header
    $port =~ s/\s*,.*$//mx if $port; # use first in list
    if($port && $port != $uri->port && $port =~ m/^\d+$/mx) {
        $uri->port($port);
    }
    return($uri);
}

sub _is_valid_hostname {
    my($host) = @_;
    # from https://www.oreilly.com/library/view/regular-expressions-cookbook/9781449327453/ch08s10.html
    if($host =~ m/^
        ([a-z0-9\-._~%]+     # Named host
        |\[[a-f0-9:.]+\])    # IPv6 host
        $/mx) {
        return 1;
    }
    return;
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

=head2 uri

Returns L<Uri> object, but applies HTTP_X_FORWARDED_* environment if set.

=head1 SEE ALSO

L<Plack::Request>, L<Plack::Request::WithEncoding>

=cut
