package Catalyst::Plugin::Unicode::Encoding;

use strict;
use base 'Class::Data::Inheritable';

use Carp ();
use Encode 2.21 ();

use MRO::Compat;
our $VERSION = '0.9';
our $CHECK   = Encode::FB_CROAK | Encode::LEAVE_SRC;

__PACKAGE__->mk_classdata('_encoding');

sub encoding {
    my $c = shift;
    my $encoding;

    if ( scalar @_ ) {
        # Let it be set to undef
        if (my $wanted = shift)  {
            $encoding = Encode::find_encoding($wanted)
              or Carp::croak( qq/Unknown encoding '$wanted'/ );
        }

        $encoding = ref $c 
                  ? $c->{encoding} = $encoding
                  : $c->_encoding($encoding);
    } else {
      $encoding = ref $c && exists $c->{encoding} 
                ? $c->{encoding} 
                : $c->_encoding;
    }

    return $encoding;
}

sub finalize {
    my $c = shift;

    my $body = $c->response->body;

    return $c->next::method(@_)
      unless defined($body);

    my $enc = $c->encoding;

    return $c->next::method(@_) 
      unless $enc;

    my ($ct, $ct_enc) = $c->response->content_type;

    # Only touch 'text-like' contents
    return $c->next::method(@_)
      unless $c->response->content_type =~ /^text|xml$|javascript$/mx;

    if ($ct_enc && $ct_enc =~ /charset=(.*?)$/mx) {
        if (uc($1) ne $enc->mime_name) {
            $c->log->debug("Unicode::Encoding is set to encode in '" .
                           $enc->mime_name .
                           "', content type is '$1', not encoding ");
            return $c->next::method(@_);
        }
    } else {
        $c->res->content_type($c->res->content_type . "; charset=" . $enc->mime_name);
    }

    # Encode expects plain scalars (IV, NV or PV) and segfaults on ref's
    $c->response->body( $c->encoding->encode( $body, $CHECK ) )
        if ref(\$body) eq 'SCALAR';

    return $c->next::method(@_);
}

# Note we have to hook here as uploads also add to the request parameters
sub prepare_uploads {
    my $c = shift;

    $c->next::method(@_);

    my $enc = $c->encoding;

    for my $key (qw/ parameters query_parameters body_parameters /) {
        for my $value ( values %{ $c->request->{$key} } ) {

            # TODO: Hash support from the Params::Nested
            if ( ref $value && ref $value ne 'ARRAY' ) {
                next;
            }
            for ( ref($value) ? @{$value} : $value ) {
                # N.B. Check if already a character string and if so do not try to double decode.
                #      http://www.mail-archive.com/catalyst@lists.scsys.co.uk/msg02350.html
                #      this avoids exception if we have already decoded content, and is _not_ the
                #      same as not encoding on output which is bad news (as it does the wrong thing
                #      for latin1 chars for example)..
                next unless defined $_;
                $_ = Encode::is_utf8( $_ ) ? $_ : $enc->decode( $_, $CHECK );
            }
        }
    }
    for my $value ( values %{ $c->request->uploads } ) {
        $_->{filename} = $enc->decode( $_->{filename}, $CHECK )
            for ( ref($value) eq 'ARRAY' ? @{$value} : $value );
    }
    return;
}

sub prepare_action {
    my $c = shift;

    my $ret = $c->next::method(@_);

    my $enc = $c->encoding;

    foreach (@{$c->req->arguments}) {
        $_ = Encode::is_utf8( $_ ) ? $_ : $enc->decode( $_, $CHECK );
    }

    return $ret;
}

sub setup {
    my $self = shift;

    my $conf = $self->config;

    # Allow an explict undef encoding to disable default of utf-8
    my $enc = exists $conf->{encoding} ? delete $conf->{encoding} : 'UTF-8';
    $self->encoding( $enc );

    return $self->next::method(@_);
}

1;

__END__

=head1 NAME

Catalyst::Plugin::Unicode::Encoding - Unicode aware Catalyst

=head1 SYNOPSIS

    use Catalyst qw[Unicode::Encoding];

    MyApp->config( encoding => 'UTF-8' ); # A valid Encode encoding


=head1 DESCRIPTION

On request, decodes all params from encoding into a sequence of
logical characters. On response, encodes body into encoding.

=head1 METHODS

=over 4

=item encoding

Returns an instance of an C<Encode> encoding

    print $c->encoding->name

=back

=head1 OVERLOADED METHODS

=over

=item finalize

Encodes body into encoding.

=item prepare_uploads

Decodes parameters, query_parameters, body_parameters and filenames
in file uploads into a sequence of logical characters.

=item prepare_action

Decodes request arguments (i.e. C<< $c->request->arguments >>).

=item setup

Setups C<< $c->encoding >> with encoding specified in C<< $c->config->{encoding} >>.

=back

=head1 SEE ALSO

L<Encode>, L<Encode::Encoding>, L<Catalyst::Plugin::Unicode>, L<Catalyst>.

=head1 AUTHORS

Christian Hansen, C<ch@ngmedia.com>

Masahiro Chiba

Tomas Doran, C<bobtfish@bobtfish.net>

=head1 LICENSE

This library is free software . You can redistribute it and/or modify
it under the same terms as perl itself.

=cut
