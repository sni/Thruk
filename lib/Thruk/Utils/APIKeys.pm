package Thruk::Utils::APIKeys;

=head1 NAME

Thruk::Utils::APIKeys - Handles api keys related things

=head1 DESCRIPTION

API keys for Thruk

=cut

use warnings;
use strict;
use Carp qw/confess/;

use Thruk::Utils ();
use Thruk::Utils::Crypt ();

my $hashed_key_file_regex = qr/^([a-zA-Z0-9]+)(\.[A-Z]+\-\d+|)$/mx;
my $private_key_regex     = qr/^([a-zA-Z0-9]+)(|_\d{1})$/mx;

##############################################

=head1 METHODS

=head2 get_keys

    get_keys($c, { [hashed_key => $hashed_key], [user => $username], [file => $filename], [superuser => 0/1])

returns list of api keys, filtered by user, file or superuser

=cut
sub get_keys {
    my($c, $filter) = @_;
    my $filename   = $filter->{'file'};
    my $superuser  = $filter->{'superuser'};
    my $user       = $filter->{'user'};
    my $hashed_key = $filter->{'hashed_key'};
    my $all        = (defined $user || defined $superuser) ? 0 : 1;

    my $keys   = [];
    my $folder = $c->config->{'var_path'}.'/api_keys';
    for my $file (glob($folder.'/*')) {
        my $basename = Thruk::Base::basename($file);
        next unless $basename =~ $hashed_key_file_regex;
        next if $basename =~ /\.stats$/mx;
        if($filename && $basename ne $filename) {
            next;
        }
        next if($hashed_key && $basename !~ m/^$hashed_key\..*$/mx);
        my $data = read_key($c->config, $file);
        next unless $data;
        if(  $all
          || ($superuser && $data->{'superuser'})
          || ($user && $data->{'user'} && $user eq $data->{'user'})) {
            push @{$keys}, $data;
        }
    }
    return($keys);
}

##############################################

=head2 get_superuser_keys

    get_superuser_keys($c, [$filename])

returns list of superuser api keys

=cut
sub get_superuser_keys {
    my($c, $filename) = @_;
    return(get_keys($c, {file => $filename, superuser => 1}));
}

##############################################

=head2 get_keyinfo_by_private_key

    get_keyinfo_by_private_key($config, $privatekey)

returns key for given private key

=cut
sub get_keyinfo_by_private_key {
    my($config, $privatekey) = @_;
    my $nr;
    if($privatekey =~ $private_key_regex) {
        $nr = 1;
        $nr = substr($2, 1) if $2;
    } else {
        return;
    }
    return unless $nr;
    my($hashed_key, $digest_nr, $digest_name) = Thruk::Utils::Crypt::hexdigest($privatekey, $nr);
    return($hashed_key, $digest_nr, $digest_name);
}

##############################################

=head2 get_key_by_private_key

    get_key_by_private_key($config, $privatekey)

returns key for given private key

=cut
sub get_key_by_private_key {
    my($config, $privatekey) = @_;

    my($hashed_key, $digest_nr, $digest_name) = get_keyinfo_by_private_key($config, $privatekey);
    return unless $hashed_key;

    my $folder = $config->{'var_path'}.'/api_keys';
    my $file   = $folder.'/'.$hashed_key.'.'.$digest_name;
    return(read_key($config, $file));
}

##############################################

=head2 create_key

    create_key($c, $username, [$comment], [$roles], [$superuser])

create new api key for user

returns private, hashed key and filename

=cut
sub create_key {
    my($c, $username, $comment, $roles, $superuser) = @_;

    my $privatekey = Thruk::Utils::Crypt::random_uuid([$username, $comment, time()]);
    my($hashed_key, $digest_nr, $digest_name) = Thruk::Utils::Crypt::hexdigest($privatekey);
    my $folder = $c->config->{'var_path'}.'/api_keys';
    my $file   = $folder.'/'.$hashed_key.'.'.$digest_name;
    Thruk::Utils::IO::mkdir_r($folder);
    my $data = {
        user    => $username,
        created => time(),
    };
    $data->{'comment'}  = $comment // '';
    if($superuser) {
        delete $data->{'user'};
        $data->{'superuser'} = 1;
    }
    if(defined $roles) {
        $data->{'roles'} = $roles;
    }
    die("hash collision") if -e $file;
    Thruk::Utils::IO::json_lock_store($file, $data, { pretty => 1 });

    return($privatekey, $hashed_key, $file);
}

##############################################

=head2 create_key_from_req_params

    create_key_from_req_params($c)

create new api key for user from request parameters

returns private, hashed key and filename on success or undef otherwise

=cut
sub create_key_from_req_params {
    my($c) = @_;
    my $username = $c->stash->{'remote_user'};
    if($c->check_user_roles('admin')) {
        if($c->req->parameters->{'username'}) {
            $username = $c->req->parameters->{'username'};
        } elsif($c->user->{'internal'}) {
            $c->req->parameters->{'superuser'} = 1;
        }
    } else {
        # only allowed for admins
        $c->req->parameters->{'superuser'} = 0;
    }

    # roles cannot exceed existing roles
    my $roles ;
    if($c->req->parameters->{'roles'} && (!$c->req->parameters->{'restrict_only'} || $c->req->parameters->{'restrict'})) {
        $roles = [];
        for my $role (@{Thruk::Base::list($c->req->parameters->{'roles'})}) {
            next unless $c->user->check_role_permissions($role);
            push @{$roles}, $role;
        }
    }

    my($private_key, $hashed_key, $filename)
        = create_key(
            $c,
            $username,
           ($c->req->parameters->{'comment'} // ''),
            $roles,
            $c->req->parameters->{'superuser'} ? 1 : 0,
    );
    return($private_key, $hashed_key, $filename);
}

##############################################

=head2 remove_key

    remove_key($c, $username, $file)

removes given key

=cut
sub remove_key {
    my($c, $username, $file) = @_;

    my $keys = get_keys($c, { user => $username, file => $file});
    for my $k (@{$keys}) {
        if(Thruk::Base::basename($k->{'file'}) eq $file) {
            unlink($k->{'file'});
            unlink($k->{'file'}.'.stats');
        }
    }
    if($c->check_user_roles('admin')) {
        my $keys = get_superuser_keys($c, $file);
        for my $k (@{$keys}) {
            if(Thruk::Base::basename($k->{'file'}) eq $file) {
                unlink($k->{'file'});
                unlink($k->{'file'}.'.stats');
            }
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
    confess("no file") unless $file;
    return unless -r $file;
    my $data       = Thruk::Utils::IO::json_lock_retrieve($file);
    my $hashed_key = Thruk::Base::basename($file);
    my $type;
    if($hashed_key =~ m%\.([^\.]+)$%gmx) {
        $type = $1;
    }
    $hashed_key =~ s%\.([^\.]+)$%%gmx;
    $data->{'hashed_key'} = $hashed_key;
    $data->{'file'}       = $file;
    $data->{'digest'}     = $type;
    $data->{'superuser'}  = 1 if delete $data->{'system'}; # migrate system keys
    if(-s $file.'.stats') {
        my $stats = Thruk::Utils::IO::json_lock_retrieve($file.'.stats');
        $data = { %{$stats}, %{$data} };
    }
    return($data);
}

##############################################

1;
