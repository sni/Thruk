package Thruk::Utils::OAuth;

use warnings;
use strict;
use Cpanel::JSON::XS qw/decode_json/;
use Data::Dumper;
use Digest::SHA ();
use MIME::Base64 ();

use Thruk::Authentication::User ();
use Thruk::Controller::login ();
use Thruk::UserAgent ();
use Thruk::Utils ();
use Thruk::Utils::CookieAuth ();
use Thruk::Utils::Crypt ();
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::Utils::OAuth - Thruk OAuth Handler

=head1 DESCRIPTION

Utilities to handle oauth login

=head1 METHODS

=head2 handle_oauth_login

=cut
sub handle_oauth_login {
    my($c, $referer, $cookie_path, $cookie_domain) = @_;
    my $auth_folder = $c->config->{'var_path'}."/oauth/";
    my $loginpage_uri = $c->req->uri;
    $loginpage_uri->query_form([]);
    $loginpage_uri->query_keywords([]);
    $loginpage_uri = $loginpage_uri->as_string();

    return(_send_error($c, $c->req->parameters)) if $c->req->parameters->{'error'};

    my $code  = $c->req->parameters->{'code'};
    my $state = $c->req->parameters->{'state'};
    # oauth login flow, step 2
    if($code && $state) {
        _cleanup_oauth_files($auth_folder, 600);
        if(Thruk::Base::check_for_nasty_filename($state)) {
            return $c->detach_error({msg => "oauth state contains invalid characters.", code => 400});
        }
        _debug(sprintf("oauth login step2: code:%s state:%s", $code, $state)) if Thruk::Base->debug;
        my $data = Thruk::Utils::IO::json_lock_retrieve($auth_folder."/".$state.".json");
        if(!$data || !defined $data->{'oauth'}) {
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi?expired&".$referer);
        }
        # exchange code into token
        my $auth = $c->config->{'auth_oauth'}->{'provider'}->[$data->{'oauth'}];
        if(!$auth) {
            return $c->detach_error({msg => "oauth provider not found", code => 500, debug_information => { oauth => $data->{'oauth'} }});
        }
        my $ua = Thruk::UserAgent->new({}, $c->config);
        $ua->default_header(Accept => "application/json");
	if (defined $auth->{'https_proxy'}) {
            $ua->proxy('https', $auth->{'https_proxy'});
            _debug(sprintf("oauth login step2: fetching token from: %s (via proxy: %s)", $auth->{'token_url'}, $auth->{'https_proxy'})) if Thruk::Base->debug;
        } else {
            _debug(sprintf("oauth login step2: fetching token from: %s", $auth->{'token_url'})) if Thruk::Base->debug;
        };
        my $token_data = {
            client_id       => $auth->{'client_id'},
            client_secret   => $auth->{'client_secret'},
            code            => $code,
            redirect_uri    => $loginpage_uri,
            state           => $state,
            grant_type      => 'authorization_code',
        };
        if($auth->{'enable_pkce'}) {
            $token_data->{'code_verifier'} = $data->{'pkce_code'};
            delete $token_data->{'client_secret'}; # client secret is not required when using pkce
        }
        my $res = $ua->post($auth->{'token_url'}, $token_data);
        _debug_http_response($res) if Thruk::Base->trace;
        unlink($auth_folder."/".$state.".json");
        my $token = _get_json($c, $res);
        if(!$token || !$token->{"access_token"}) {
            return $c->detach_error({msg => "cannot exchange oauth token", code => 500, debug_information => { res => $res }});
        }

        # get userdata from token
        if($token->{"token_type"} && lc($token->{"token_type"}) eq 'bearer') {
            $ua->default_header(Authorization => "Bearer ".$token->{"access_token"});
        } else {
            $ua->default_header(Authorization => "token ".$token->{"access_token"});
        }
        my $login;
        if ($auth->{'api_url'}) {
            _debug(sprintf("oauth login step2: fetching user id from: %s", $auth->{'api_url'})) if Thruk::Base->debug;
            $res = $ua->get($auth->{'api_url'});
            _debug_http_response($res) if Thruk::Base->trace;
            my $userinfo = _get_json($c, $res);
            if(!$userinfo) {
                return $c->detach_error({msg => "cannot fetch oauth user details", code => 500, debug_information => { res => $res }});
            }
            $login = _extract_login($auth, $userinfo);
            if(!defined $login) {
                return $c->detach_error({msg => "cannot find oauth user name", code => 500, debug_information => { userinfo => $userinfo }});
            }
        } else {
            # AD FS puts the claims in the id_token rather than in userinfo
            eval {
                require Crypt::JWT;
                Crypt::JWT->import('decode_jwt');
            };
            if ($@) {
                die("Crypt::JWT is required when user id assertions not fetched from api_url");
            }
            _debug(sprintf("oauth login step2: api_url not set, looking for user id in id_token")) if Thruk::Base->debug;
            my $id_token;
            if ($auth->{'jwks_url'}) {
                _debug(sprintf("oauth login step2: get jwks from: %s", $auth->{'jwks_url'})) if Thruk::Base->debug;
                $res = $ua->get($auth->{'jwks_url'});
                _debug_http_response($res) if Thruk::Base->trace;
                my $jwks = _get_json($c, $res);
                $id_token = decode_jwt(token => $token->{'id_token'}, kid_keys => $jwks);
            } elsif ($auth->{'jwk_key'}) {
                $id_token = decode_jwt(token => $token->{'id_token'}, keys => $auth->{'jwk_key'});
            } else {
                _debug("oauth login step2: WARNING insecure JWT decode");
                $id_token = decode_jwt(token => $token->{'id_token'}, ignore_signature => 1);
            }
            $login = _extract_login($auth, $id_token);
            if(!defined $login) {
                return $c->detach_error({msg => "cannot find oauth user name", code => 500, debug_information => { token => $token, id_token => $id_token }});
            }
        }
        _debug(sprintf("oauth login step2: got user id: %s", $login)) if Thruk::Base->debug;
        $login = Thruk::Authentication::User::transform_username($c->config, $login);
        my $session = Thruk::Utils::CookieAuth::store_session($c->config, undef, {
                                                                    address    => $c->req->address,
                                                                    username   => $login,
        });
        if($c->config->{'cookie_auth_login_hook'}) {
            Thruk::Utils::IO::cmd($c->config->{'cookie_auth_login_hook'}.' >/dev/null 2>&1');
        }
        _debug(sprintf("oauth login step2: login succesful as user: %s", $login)) if Thruk::Base->verbose;
        return(Thruk::Controller::login::login_successful($c, $login, $session, ($data->{'referer'}//$referer), $cookie_domain, "oauth: ".($auth->{'id'}//$auth->{'login'}//$auth->{'name'})));
    }

    # oauth login flow, step 1
    my $id = $c->req->parameters->{'oauth'};
    if(!defined $id) {
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi?problem&".$referer);
    }
    my $auth = $c->config->{'auth_oauth'}->{'provider'}->[$id];
    if(!$auth) {
        return $c->detach_error({msg => "oauth provider not found", code => 400});
    }
    # redirect to auth url
    $state = Thruk::Utils::Crypt::random_uuid([time()]);

    my $state_data = {
        'time'    => time(),
        'oauth'   => $id,
        'referer' => $referer,
    };
    my $login_data = {
        client_id             => $auth->{'client_id'},
        scope                 => $auth->{'scopes'},
        state                 => $state,
        response_type         => 'code',
        redirect_uri          => $loginpage_uri,
    };

    # PKCE workflow as described in rfc7636
    if($auth->{'enable_pkce'}) {
        my $pkce_code           = substr(Thruk::Utils::Crypt::random_uuid([time()]), 0, 64);
        my $pkce_code_challenge = _base64_url_encode(Digest::SHA::sha256($pkce_code));
        $login_data->{'code_challenge'}        = $pkce_code_challenge;
        $login_data->{'code_challenge_method'} = 'S256';
        $state_data->{'pkce_code'}             = $pkce_code;
    }

    Thruk::Utils::IO::mkdir($auth_folder);
    Thruk::Utils::IO::json_lock_store($auth_folder."/".$state.".json", $state_data);
    _cleanup_oauth_files($auth_folder, 600);
    my $oauth_login_url = Thruk::Utils::Filter::uri_with($c, $login_data, 1, $auth->{'auth_url'}, 1);
    _debug("oauth login step1: redirecting to ".$oauth_login_url) if Thruk::Base->verbose;
    return $c->redirect_to($oauth_login_url);
}

##########################################################
sub _send_error {
    my($c, $data) = @_;
    my $descr = $data->{'error_description'} // "";
    if($data->{'error_uri'}) {
        $descr .= "<br>" if $descr;
        $descr .= sprintf('<a class="link" target="_blank" href="%s"><i class="uil uil-external-link-alt text-sm"></i>%s</a>', $data->{'error_uri'}, $data->{'error_uri'});
    }
    return $c->detach_error({msg => $data->{'error'}, descr => $descr, code => 500, skip_escape => 1});
}

##########################################################
sub _cleanup_oauth_files {
    my($folder, $timeout) = @_;
    $timeout = time() - $timeout;
    opendir( my $dh, $folder) or die "can't opendir '$folder': $!";
    for my $entry (readdir($dh)) {
        next if $entry eq '.' or $entry eq '..';
        my $file = $folder.'/'.$entry;
        my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
           $atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
        if(!$mtime || $mtime < $timeout) {
            unlink($file);
        }
    }
    return;
}

##########################################################
sub _get_json {
    my($c, $res) = @_;

    my $body = $res->decoded_content || $res->content;
    if($body && $body =~ m/^\s*\{/gmx) {
        my $data = decode_json($body);
        if($data && $data->{'error'}) {
            return(_send_error($c, $data));
        }
        return($data);
    }
    return $c->detach_error({msg => "cannot get oauth data", code => 500, debug_information => { res => $res }});
}

##########################################################
# get username from response hash
sub _extract_login {
    my($auth, $userinfo) = @_;

    if(Thruk::Base->debug) {
        _debug("oauth login step2: got user details:");
        _debug($userinfo);
    }

    if($auth->{'login_field'}) {
        return $userinfo->{$auth->{'login_field'}};
    }

    return $userinfo->{'login'} if $userinfo->{'login'};
    return $userinfo->{'email'} if $userinfo->{'email'};

    return;
}

##########################################################
sub _base64_url_encode {
    my($str) = @_;

    my $data = MIME::Base64::encode_base64($str, '');
    $data =~ tr|+/=|-_|d;

    return($data);
}

##########################################################

1;
