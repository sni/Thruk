package Thruk::Utils::Crypt;

=head1 NAME

Thruk::Utils::Crypt - Utilities Collection for Encryption, Decryption and Hashing.

=head1 DESCRIPTION

Crypt offers functions to encrypt and decrypt data as well as hashing.

=cut

use warnings;
use strict;
use Digest ();
use Crypt::Rijndael ();
use MIME::Base64 ();
use Encode qw/encode_utf8 decode/;

##############################################
my $supported_digests = {
    '1' => 'SHA-256',
};
my $default_digest = 1;

##############################################

=head1 METHODS

=head2 encrypt

  encrypt($key, $data)

return encrypted data

=cut
sub encrypt {
    my($key, $data) = @_;

    $key = encode_utf8($key);
    $key = substr(_null_padding($key,32,'e'),0,32);
    my $cipher = Crypt::Rijndael->new($key, Crypt::Rijndael::MODE_CBC);
    $data = encode_utf8($data);
    $data = _null_padding($data,32,'e');
    $data = "CBC,".MIME::Base64::encode_base64($cipher->encrypt($data));
    return($data);
}

##############################################

=head2 decrypt

  decrypt($key, $encrypted_data)

return decrypted data

=cut
sub decrypt {
    my($key, $crypted) = @_;
    my $data;
    if($crypted && $crypted =~ m/^CBC,(.*)$/smx) {
        $data = $1;
    } else {
        return;
    }
    $key = encode_utf8($key);
    $key = substr(_null_padding($key,32,'e'),0,32);
    my $cipher = Crypt::Rijndael->new($key, Crypt::Rijndael::MODE_CBC);
    $data = MIME::Base64::decode_base64($data);
    $data = _null_padding($cipher->decrypt($data), 32, 'd');
    $data = decode("UTF-8", $data);
    return $data;
}

##############################################

=head2 random_uuid

  random_uuid([$salt])

returns random unique id

=cut
sub random_uuid {
    my($salt) = @_;
    my $type = $supported_digests->{$default_digest};
    my $digest = Digest->new($type);
    $digest->add(time());
    $digest->add(rand(10000000));
    if($salt) {
        for my $s (@{$salt}) {
            $digest->add($s);
        }
    }
    my $uuid = $digest->hexdigest().'_'.$default_digest;
    if(length($uuid) != 66) { die("creating uuid failed.") }
    return($uuid);
}

##############################################

=head2 digest_name

  digest_name($nr)

converts number to digest name

=cut
sub digest_name {
    my($nr) = @_;
    my $name = $supported_digests->{$nr};
    return($name) if $name;
    for my $name (sort values %{$supported_digests}) {
        return $name if $name eq $nr;
    }
    return;
}

##############################################

=head2 hexdigest

  hexdigest($data, [$digest_nr|$digest_name])

returns hex digest hash for given data along with the number and the name of the digest

=cut
sub hexdigest {
    my($data, $nr) = @_;
    $nr = $default_digest unless $nr;
    my $digest_name = digest_name($nr);
    if(!$digest_name) {
        confess("unsupported digest type: ".$nr);
    }
    my $digest = Digest->new($digest_name);
    $digest->add($data);
    my $hash = $digest->hexdigest();
    if(length($hash) != 64) { die("creating hexdigest failed.") }
    return($hash, $nr, $digest_name) if wantarray;
    return($hash);
}

##############################################
sub _null_padding {
    my($block,$bs,$decrypt) = @_;
    $block = length $block ? $block : '';
    if($decrypt eq 'd') {
        $block=~ s/\0*$//mxs;
        return $block;
    }
    return $block . pack("C*", (0) x ($bs - length($block) % $bs));
}

##############################################

1;
