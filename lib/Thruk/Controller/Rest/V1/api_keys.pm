package Thruk::Controller::Rest::V1::api_keys;

use warnings;
use strict;

use Thruk::Controller::rest_v1 ();

=head1 NAME

Thruk::Controller::Rest::V1::api_keys - API Keys rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=cut


##########################################################
# REST PATH: GET /thruk/api_keys
# lists api keys
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/api_keys?$%mx, \&_rest_get_thruk_api_keys);
sub _rest_get_thruk_api_keys {
    my($c, undef, $hashed_key) = @_;
    require Thruk::Utils::APIKeys;

    my $keys = Thruk::Utils::APIKeys::get_keys($c, {
            hashed_key => $hashed_key,
            user       => $c->check_user_roles('admin') ? undef : $c->stash->{'remote_user'},
    });

    if(!defined $hashed_key) {
        return($keys);
    }

    if(!$keys->[0]) {
        return({ 'message' => 'no such api key', code => 404 });
    }

    my $method = $c->req->method();
    if($method eq 'DELETE') {
        if($c->check_user_roles("authorized_for_read_only")) {
            return({
                'message' => 'no permission to delete api keys',
                'code'    => 403,
            });
        }
        if(unlink($keys->[0]->{'file'})) {
            unlink($keys->[0]->{'file'}.'.stats');
            return({
                'message' => 'successfully removed 1 api key.',
            });
        }
        return({
            'message' => 'failed to removed api key',
            'code'    => 500,
        });
    }

    return($keys->[0]);
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
#   * superuser (flag to create superuser api key)
#   * username (requires admin privileges)
#   * roles (restrict roles to given list)
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/thruk/api_keys?$%mx, \&_rest_get_thruk_api_key_new);
sub _rest_get_thruk_api_key_new {
    my($c) = @_;
    if(!$c->config->{'api_keys_enabled'}) {
        return({
            'message' => 'api keys are disabled',
            'code'    => 400,
        });
    }
    if($c->config->{'max_api_keys_per_user'} <= 0 || $c->check_user_roles("authorized_for_read_only")) {
        return({
            'message' => 'no permission to create api keys',
            'code'    => 403,
        });
    }
    require Thruk::Utils::APIKeys;
    my $keys = Thruk::Utils::APIKeys::get_keys($c, { user => $c->stash->{'remote_user'}});
    if(scalar @{$keys} >= $c->config->{'max_api_keys_per_user'}) {
        return({
            'message' => 'maximum number of api keys ('.$c->config->{'max_api_keys_per_user'}.') reached, cannot create more.',
            'code'    => 403,
        });
    }
    my($private_key, $hashed_key, $filename) = Thruk::Utils::APIKeys::create_key_from_req_params($c);
    if($private_key) {
        return({
            'message'     => 'successfully created api key',
            'file'        => $filename,
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
