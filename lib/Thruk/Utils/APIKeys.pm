package Thruk::Utils::APIKeys;

=head1 NAME

Thruk::Utils::APIKeys - Handles api keys related things

=head1 DESCRIPTION

API keys for Thruk

=cut

use strict;
use warnings;
use Digest ();
use File::Copy qw/move/;
use Thruk::Utils::IO ();

use constant DIGEST => 'SHA-256';

##############################################

=head1 METHODS

=head2 get_keys

  get_keys($c, $username)

returns list of api keys

=cut
sub get_keys {
    my($c, $user) = @_;
    my $keys = [];
    my $folder = $c->config->{'var_path'}.'/api_keys';
    for my $file (glob($folder.'/*')) {
        my $data = _read_key($c, $file);
        push @{$keys}, $data if $data->{'user'} eq $user;
    }
    return($keys);
}

##############################################

=head2 get_key_by_private_key

  get_key_by_private_key($c, $privatekey)

returns key for given private key

=cut
sub get_key_by_private_key {
    my($c, $privatekey) = @_;
    if($privatekey !~ m/^[a-zA-Z0-9]+$/mx) {
        $c->error("wrong authentication key");
        return;
    }
    my $digest = Digest->new(DIGEST);
    $digest->add($privatekey);
    my $publickey = $digest->hexdigest();
    my $folder = $c->config->{'var_path'}.'/api_keys';
    my $file   = $folder.'/'.$publickey;
    my $data   = _read_key($c, $file);
    return($data);
}

##############################################

=head2 create_key

  create_key($c, $username, [$comment])

create new api key for user

returns private and public key

=cut
sub create_key {
    my($c, $username, $comment) = @_;

    my $digest = Digest->new(DIGEST);
    $digest->add($username);
    $digest->add($comment);
    $digest->add(rand(10000));
    $digest->add(time());
    my $privatekey = $digest->hexdigest();
    if(length($privatekey) < 64) { die("creating key failed.") }
    $digest->reset();
    $digest->add($privatekey);
    my $publickey = $digest->hexdigest();
    my $folder = $c->config->{'var_path'}.'/api_keys';
    my $file   = $folder.'/'.$publickey;
    Thruk::Utils::IO::mkdir_r($folder);
    my $data = {
        user    => $username,
        created => time(),
    };
    $data->{'comment'} = $comment if $comment;
    die("hash collision") if -e $file;
    Thruk::Utils::IO::json_lock_store($file, $data , 1);

    return($privatekey, $publickey);
}

##############################################

=head2 remove_key

  remove_key($c, $username, $key)

remove given key

=cut
sub remove_key {
    my($c, $username, $key) = @_;

    my $folder = $c->config->{'var_path'}.'/api_keys';
    my $keys = get_keys($c, $username);
    for my $k (@{$keys}) {
        if($k->{'public_key'} eq $key) {
            unlink($folder.'/'.$key);
        }
    }

    return;
}

##############################################
sub _read_key {
    my($c, $file) = @_;
    my $data = Thruk::Utils::IO::json_lock_retrieve($file);
    my $key = $file;
    $key =~ s%^.*/%%gmx;
    if(length($key) < 64) {
      # upgrade key
      my $digest = Digest->new(DIGEST);
      $digest->add($key);
      my $publickey = $digest->hexdigest();
      my $folder = $c->config->{'var_path'}.'/api_keys';
      move($folder.'/'.$key, $folder.'/'.$publickey);
      $key = $publickey;
    }
    $data->{'public_key'} = $key;
    $data->{'file'}       = $file;
    return($data);
}

##############################################

1;
