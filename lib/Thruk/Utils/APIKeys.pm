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

my $supported_digests = {
    "1"  => 'SHA-256',
};
my $default_digest        = 1;
my $hashed_key_file_regex = qr/^([a-zA-Z0-9]+)(\.[A-Z]+\-\d+|)$/mx;
my $private_key_regex     = qr/^([a-zA-Z0-9]+)(|_\d{1})$/mx;

##############################################

=head1 METHODS

=head2 get_keys

    get_keys($c, $username, [$filepattern])

returns list of api keys

=cut
sub get_keys {
    my($c, $user, $filepattern) = @_;
    my $keys = [];
    my $folder = $c->config->{'var_path'}.'/api_keys';
    for my $file (glob($folder.'/*')) {
        my $basename = Thruk::Utils::basename($file);
        if($basename !~ $hashed_key_file_regex) {
            next;
        }
        if($filepattern && $basename ne $filepattern) {
            next;
        }
        my $data = read_key($c->config, $file);
        push @{$keys}, $data if($data && $data->{'user'} eq $user);
    }
    return($keys);
}

##############################################

=head2 get_key_by_private_key

    get_key_by_private_key($config, $privatekey)

returns key for given private key

=cut
sub get_key_by_private_key {
    my($config, $privatekey) = @_;
    my $nr;
    if($privatekey =~ $private_key_regex) {
        $nr = substr($2, 1) if $2;
    } else {
        return;
    }
    if(!$nr) {
        # REMOVE AFTER: 01.01.2020
        if(length($privatekey) < 64) {
            _upgrade_key($config, $privatekey);
            $nr = $default_digest;
        }
        # /REMOVE AFTER
        else {
            return;
        }
    }
    my $type = $supported_digests->{$nr};
    return unless $type;
    my $digest = Digest->new($type);
    $digest->add($privatekey);
    my $hashed_key = $digest->hexdigest();
    my $folder = $config->{'var_path'}.'/api_keys';
    my $file   = $folder.'/'.$hashed_key.'.'.$type;
    return(read_key($config, $file));
}

##############################################

=head2 create_key

    create_key($c, $username, [$comment])

create new api key for user

returns private, hashed key and filename

=cut
sub create_key {
    my($c, $username, $comment) = @_;

    my $type = $supported_digests->{$default_digest};
    my $digest = Digest->new($type);
    $digest->add($username);
    $digest->add($comment);
    $digest->add(rand(10000));
    $digest->add(time());
    my $privatekey = $digest->hexdigest()."_".$default_digest;
    if(length($privatekey) != 66) { die("creating key failed.") }
    $digest->reset();
    $digest->add($privatekey);
    my $hashed_key = $digest->hexdigest();
    my $folder = $c->config->{'var_path'}.'/api_keys';
    my $file   = $folder.'/'.$hashed_key.'.'.$type;
    Thruk::Utils::IO::mkdir_r($folder);
    my $data = {
        user    => $username,
        created => time(),
    };
    $data->{'comment'} = $comment // '';
    die("hash collision") if -e $file;
    Thruk::Utils::IO::json_lock_store($file, $data , 1);

    return($privatekey, $hashed_key, $file);
}

##############################################

=head2 remove_key

    remove_key($c, $username, $file)

removes given key

=cut
sub remove_key {
    my($c, $username, $file) = @_;

    my $keys = get_keys($c, $username, $file);
    for my $k (@{$keys}) {
        if(Thruk::Utils::basename($k->{'file'}) eq $file) {
            unlink($k->{'file'});
        }
    }

    return;
}

##############################################

=head2 read_key

    read_key($c, $file)

return key for given file

=cut
sub read_key {
    my($config, $file) = @_;
    return unless -r $file;
    my $data       = Thruk::Utils::IO::json_lock_retrieve($file);
    my $hashed_key = Thruk::Utils::basename($file);
    my $type;
    if($hashed_key =~ m%\.([^\.]+)$%gmx) {
        $type = $1;
    }
    if(!$type && length($hashed_key) < 64) {
        my($newkey, $newfile) = _upgrade_key($config, $hashed_key);
        if($newkey) {
            $hashed_key = $newkey;
            $file       = $newfile;
            $type       = $supported_digests->{$default_digest};
        }
    }
    $hashed_key =~ s%\.([^\.]+)$%%gmx;
    $data->{'hashed_key'} = $hashed_key;
    $data->{'file'}       = $file;
    $data->{'digest'}     = $type;
    return($data);
}

##############################################
# migrate key from old md5hex to current format
# REMOVE AFTER: 01.01.2020
sub _upgrade_key {
    my($config, $key) = @_;
    my $folder = $config->{'var_path'}.'/api_keys';
    return unless -e $folder.'/'.$key;
    my $type   = $supported_digests->{$default_digest};
    my $digest = Digest->new($type);
    $digest->add($key);
    my $hashed_key = $digest->hexdigest();
    my $newfile = $folder.'/'.$hashed_key.'.'.$type;
    move($folder.'/'.$key, $newfile);
    return($hashed_key, $newfile);
}

##############################################

1;
