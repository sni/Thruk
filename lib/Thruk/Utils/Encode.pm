package Thruk::Utils::Encode;

=head1 NAME

Thruk::Utils::Encode - Encoding Utilities Collection for Thruk

=head1 DESCRIPTION

Encoding Utilities Collection for Thruk

=cut

use warnings;
use strict;
use Encode qw/encode_utf8 decode is_utf8/;

##########################################################

=head1 METHODS

=head2 decode_any

read and decode string from either utf-8 or iso-8859-1

=cut
sub decode_any {
    eval { $_[0] = decode( "utf8", $_[0], Encode::FB_CROAK ) };
    if($@) { # input was not utf8
        return($_[0]) if $@ =~ m/\QCannot decode string with wide characters\E/mxo; # since Encode.pm 2.53 decode_utf8 no longer noops when utf8 is already on
        return($_[0]) if $@ =~ m/\QWide character at\E/mxo;                         # since Encode.pm ~2.90 message changed
        $_[0] = decode( "iso-8859-1", $_[0], Encode::FB_WARN );
    }
    return $_[0];
}

##########################################################

=head2 ensure_utf8

    ensure_utf8($str)

makes sure the given string is utf8

=cut
sub ensure_utf8 {
    $_[0] = decode_any($_[0]);
    return($_[0]) if is_utf8($_[0]); # since Encode.pm 2.53 decode_utf8 no longer noops when utf8 is already on
    return(encode_utf8($_[0]));
}

##########################################################

=head2 encode_utf8

    encode_utf8($str)

encode in utf8

=cut

##########################################################

1;
