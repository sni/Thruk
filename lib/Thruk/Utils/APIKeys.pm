package Thruk::Utils::APIKeys;

=head1 NAME

Thruk::Utils::APIKeys - Handles api keys related things

=head1 DESCRIPTION

API keys for Thruk

=cut

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

use Thruk::Utils::IO;

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
        my $data = Thruk::Utils::IO::json_lock_retrieve($file);
        if($data->{'user'} eq $user) {
            my $key = $file;
            $key =~ s%^.*/%%gmx;
            $data->{'key'} = $key;
            push @{$keys}, $data;
        }
    }
    return($keys);
}

##############################################

=head2 create_key

  create_key($c, $username, [$comment])

create new api key for user

=cut
sub create_key {
    my($c, $username, $comment) = @_;

    my $key    = md5_hex(rand(1000).time());
    my $folder = $c->config->{'var_path'}.'/api_keys';
    my $file   = $folder.'/'.$key;
    Thruk::Utils::IO::mkdir_r($folder);
    my $data = {
        user => $username,
    };
    $data->{'comment'} = $comment if $comment;
    Thruk::Utils::IO::json_lock_store($file, $data , 1);

    return;
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
        if($k->{'key'} eq $key) {
            unlink($folder.'/'.$key);
        }
    }

    return;
}

##############################################

1;
