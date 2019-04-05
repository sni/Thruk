package Thruk::Controller::Rest::V1::api_keys;

use strict;
use warnings;
use Thruk::Controller::rest_v1;

=head1 NAME

Thruk::Controller::Rest::V1::api_keys - API Keys rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=cut


##########################################################
# REST PATH: GET /thruk/api_keys
# lists broadcasts
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/api_keys?$%mx, \&_rest_get_thruk_api_keys);
sub _rest_get_thruk_api_keys {
    my($c, undef, $key) = @_;
    require Thruk::Utils::APIKeys;

    my $is_admin = 0;
    if($c->check_user_roles('admin')) {
        $is_admin = 1;
    }
    my $user = $c->stash->{'remote_user'};
    my $keys = [];
    my $folder = $c->config->{'var_path'}.'/api_keys';
    for my $file (glob($folder.'/*')) {
        my $hashed_key = Thruk::Utils::basename($file);
        next if($key && $hashed_key ne $key);
        my $data = Thruk::Utils::APIKeys::read_key($c->config, $file);
        if($data && ($is_admin || $data->{'user'} eq $user)) {
            push @{$keys}, $data;
        }
    }

    if(!$key) {
        return($keys);
    }

    if(!$keys->[0]) {
        return({ 'message' => 'no such api key', code => 404 });
    }

    my $method = $c->req->method();
    if($method eq 'DELETE') {
        if(unlink($keys->[0]->{'file'})) {
            return({
                'message' => 'successfully removed 1 api key.',
            });
        }
        return({
            'message' => 'failed to removed api key',
            'code'    => 500,
        });
    }

    if($key) {
        return($keys->[0]);
    }
}

##########################################################
# REST PATH: GET /thruk/api_keys/<id>
# alias for /thruk/api_keys?hashed_key=<id>
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/api_keys?/([^/\.]+)$%mx, \&_rest_get_thruk_api_keys);

# REST PATH: DELETE /thruk/api_keys/<id>
# remove key for given id.
Thruk::Controller::rest_v1::register_rest_path_v1(['DELETE'], qr%^/thruk/api_keys?/([^/\.]+)$%mx, \&_rest_get_thruk_api_keys);

##########################################################
# REST PATH: POST /thruk/api_keys
# create new api key.
#
# Optional arguments:
#
#   * comment
#   * username (requires admin privileges)
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/thruk/api_keys?$%mx, \&_rest_get_thruk_api_key_new);
sub _rest_get_thruk_api_key_new {
    my($c) = @_;
    require Thruk::Utils::APIKeys;
    my $username = $c->stash->{'remote_user'};
    if($c->req->parameters->{'username'} && $c->check_user_roles('admin')) {
        $username = $c->req->parameters->{'username'};
    }
    my($private_key, $hashed_key) = Thruk::Utils::APIKeys::create_key($c, $username, ($c->req->parameters->{'comment'} // ''));
    if($private_key) {
        return({
            'message'     => 'successfully created api key',
            'hashed_key'  => $hashed_key,
            'private_key' => $private_key,
        });
    }
    return({
        'message' => 'failed to create api key',
        'code'    => 500,
    });
}

##########################################################

1;
