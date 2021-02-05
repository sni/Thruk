package Thruk::Controller::login;

use strict;
use warnings;
use Carp;
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::Controller::login - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=head2 index

=cut
sub index {
    my ( $c ) = @_;

    $c->stats->profile(begin => "login::index");

    if(!$c->config->{'login_modules_loaded'}) {
        require Thruk::Utils::CookieAuth;
        $c->config->{'login_modules_loaded'} = 1;
    }

    $c->stash->{'navigation'}     = 'off'; # would be useless here, so set it non-empty, otherwise AddDefaults::end would read it again
    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{'theme'}          = $c->config->{'default_theme'} unless defined $c->stash->{'theme'};
    $c->stash->{'page'}           = 'splashpage';
    $c->stash->{'loginurl'}       = $c->stash->{'url_prefix'}."cgi-bin/login.cgi";
    $c->stash->{'template'}       = 'login.tt';
    $c->stash->{'title'}          = 'Login';
    my $product_prefix            = $c->config->{'product_prefix'};

    my $cookie_path   = $c->stash->{'cookie_path'};
    my $cookie_domain = _get_cookie_domain($c);

    my $keywords = $c->req->uri->query;
    my $logoutref;
    if($keywords and $keywords =~ m/^logout(\/.*)/mx) {
        $keywords = 'logout';
        $logoutref = $1;
    }
    if($c->req->url =~ m/\/\Q$product_prefix\E\/cgi\-bin\/login\.cgi\?logout(\/.*)/mx) {
        $keywords = 'logout';
        $logoutref = $1;
    }

    my $login   = $c->req->parameters->{'login'}    || '';
    my $pass    = $c->req->parameters->{'password'} || '';
    my $submit  = $c->req->parameters->{'submit'}   || '';
    my $referer = $c->req->parameters->{'referer'}  || '';
    $referer    =~ s#^//#/#gmx;         # strip double slashes
    $referer    =~ s#.*/nocookie$##gmx; # strip nocookie
    $referer    = $c->stash->{'url_prefix'} unless $referer;
    # append slash for omd sites, IE and chrome wont send the login cookie otherwise
    if(($ENV{'OMD_SITE'} and $referer eq '/'.$ENV{'OMD_SITE'})
       or ($referer eq $c->stash->{'url_prefix'})) {
        $referer =~ s/\/*$//gmx;
        $referer = $referer.'/';
    }
    $referer =~ s/%3f/?/mx;
    # add trailing slash if referer ends with the product prefix and nothing else
    if($referer =~ m|\Q/$product_prefix\E$|mx) {
        $referer = $referer.'/';
    }

    if(defined $keywords) {
        if($keywords eq 'logout') {
            _invalidate_current_session($c, $cookie_path, "user logout");
            Thruk::Utils::set_message( $c, 'success_message', 'logout successful' );
            return $c->redirect_to($logoutref) if $logoutref;
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi");
        }

        if($keywords eq 'nocookie') {
            my $hint = '';
            if($cookie_domain) {
                $hint = ' (cookie domain is set to: '.$cookie_domain.')';
            }
            Thruk::Utils::set_message( $c, 'fail_message', 'login not possible without accepting cookies'.$hint );
        }
        if($keywords =~ /^expired\&(.*)$/mx or $keywords eq 'expired') {
            _invalidate_current_session($c, $cookie_path, "session expired");
            Thruk::Utils::set_message( $c, 'fail_message', 'session has expired' );
        }
        if($keywords =~ /^invalid\&(.*)$/mx or $keywords eq 'invalid') {
            _invalidate_current_session($c, $cookie_path, "session invalid");
            Thruk::Utils::set_message( $c, 'fail_message', 'session is not valid (anymore)' );
        }
        if($keywords =~ /^problem\&(.*)$/mx or $keywords eq 'problem') {
            # don't remove all sessions when there is a (temporary) technical problem
            #_invalidate_current_session($c, $cookie_path, "technical issue");
            Thruk::Utils::set_message( $c, 'fail_message', 'technical problem during login, please have a look at the logfiles.' );
        }
        if($keywords =~ /^locked\&(.*)$/mx or $keywords eq 'locked') {
            _invalidate_current_session($c, $cookie_path, "user locked");
            Thruk::Utils::set_message( $c, 'fail_message', 'account is locked, please contact an administrator' );
        }
        if($keywords =~ /^setsession\&(.*)$/mx or $keywords eq 'setsession') {
            $c->authenticate();
            return $c->redirect_to($referer) if $referer;
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi");
        }
    }

    if($c->req->parameters->{'state'} || (defined $c->req->parameters->{'oauth'} && $c->req->parameters->{'oauth'} ne "")) {
        require Thruk::Utils::OAuth;
        return(Thruk::Utils::OAuth::handle_oauth_login($c, $referer, $cookie_path, $cookie_domain));
    }

    if($submit ne '' && $login eq '') {
        Thruk::Utils::set_message( $c, 'fail_message', 'missing parameter: username' );
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi");
    }

    if($login ne '') {
        return(_handle_basic_login($c, $login, $pass, $referer, $cookie_path, $cookie_domain));
    }

    Thruk::Utils::ssi_include($c, 'login');

    # set test cookie
    $c->cookie('thruk_test' => '****', {
        path    => $cookie_path,
        domain  => $cookie_domain,
    });
    if($c->config->{'cookie_auth_domain'} && $cookie_domain ne $c->config->{'cookie_auth_domain'}) {
        Thruk::Utils::set_message( $c, 'warn_message', 'using '.$cookie_domain.' instead of the configured cookie_auth_domain '.$c->config->{'cookie_auth_domain'});
    }
    $c->stash->{'cookie_domain'} = $cookie_domain;

    $c->stats->profile(end => "login::index");

    $c->res->code(401);

    if(($keywords && $keywords =~ m|/thruk/r/|mx) || $c->want_json_response()) {
        # respond with json error for the rest api
        my $details = $c->stash->{'thruk_message_details'} || "no or invalid credentials used.";
        $details =~ s/^.*~~//mx;
        return $c->render(json => {
            failed      => Cpanel::JSON::XS::true,
            message     => $c->stash->{'thruk_message'} || "login required",
            details     => $details,
            description => "no or invalid credentials used.",
            code        => 401,
        });
    }

    return 1;
}

##########################################################
sub _handle_basic_login {
    my($c, $login, $pass, $referer, $cookie_path, $cookie_domain) = @_;

    # make lowercase username
    $login = lc($login) if $c->config->{'make_auth_user_lowercase'};

    my $testcookie = $c->cookie('thruk_test');
    $c->cookie('thruk_test' => '', {
        expires => 0,
        path    => $cookie_path,
        domain  => $cookie_domain,
    });
    if(   (!defined $testcookie || !$testcookie->value)
        && (!defined $c->req->header('user-agent') || $c->req->header('user-agent') !~ m/wget/mix)) {
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi?nocookie");
    }

    my $userdata = Thruk::Utils::get_user_data($c, $login);
    if($userdata->{'login'}->{'locked'}) {
        _audit_log("login", sprintf("login attempt for locked account %s on %s from %s%s",
                                $login,
                                $referer,
                                $c->req->address,
                                ($c->env->{'HTTP_X_FORWARDED_FOR'} ? ' ('.$c->env->{'HTTP_X_FORWARDED_FOR'}.')' :''),
                        ), $login);
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi?locked&".$referer);
    }

    $c->stats->profile(begin => "login::external_authentication");
    my $session = Thruk::Utils::CookieAuth::external_authentication($c->config, $login, $pass, $c->req->address, $c->stats);
    $c->stats->profile(end => "login::external_authentication");
    if(ref $session eq '' && $session eq '-1') {
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi?problem&".$referer);
    }
    elsif($session) {
        # call a script hook after successful login?
        if($c->config->{'cookie_auth_login_hook'}) {
            Thruk::Utils::IO::cmd($c, $c->config->{'cookie_auth_login_hook'}.' >/dev/null 2>&1 &');
        }
        return(login_successful($c, $login, $session, $referer, $cookie_path, $cookie_domain, "password"));
    }

    _audit_log("login", sprintf("login failed for %s on %s from %s%s",
                            $login,
                            $referer,
                            $c->req->address,
                            ($c->env->{'HTTP_X_FORWARDED_FOR'} ? ' ('.$c->env->{'HTTP_X_FORWARDED_FOR'}.')' :''),
                    ), $login);
    Thruk::Utils::set_message( $c, 'fail_message', 'login failed' );
    if($c->config->{cookie_auth_disable_after_failed_logins}) {
        # increase failed login counter and disable account if it exceeds
        my $userdata = Thruk::Utils::get_user_data($c, $login);
        $userdata->{'login'}->{'failed'}++;
        $userdata->{'login'}->{'last_failed'} = { time => time(), ip => $c->req->address, forwarded_for => $c->env->{'HTTP_X_FORWARDED_FOR'} };
        if($userdata->{'login'}->{'failed'} >= $c->config->{cookie_auth_disable_after_failed_logins}) {
            _audit_log("login", sprintf("account %s locked after %d failed attempts on %s from %s%s",
                                    $login,
                                    $userdata->{'login'}->{'failed'},
                                    $referer,
                                    $c->req->address,
                                    ($c->env->{'HTTP_X_FORWARDED_FOR'} ? ' ('.$c->env->{'HTTP_X_FORWARDED_FOR'}.')' :''),
                            ), $login);
            $userdata->{'login'}->{'locked'} = 1;
        }

        # only update user data if already exist, otherwise we would end up with a new file for each failed login
        my $file = $c->config->{'var_path'}."/users/".$login;
        Thruk::Utils::store_user_data($c, $userdata, $login) if -s $file;

        if($userdata->{'login'}->{'locked'}) {
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi?locked&".$referer);
        }
    }
    return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi?".$referer);
}

##########################################################

=head2 login_successful

    login_successful($c, $login, $session, $referer, $cookie_path, $cookie_domain)

redirects to $referer and sets sessions cookie

=cut
sub login_successful {
    my($c, $login, $session, $referer, $cookie_path, $cookie_domain, $type) = @_;

    $c->stash->{'remote_user'} = $login;
    confess("no session") unless $session;
    $c->{'session'} = $session;
    $c->cookie('thruk_auth' => $session->{'private_key'}, {
        path     => $cookie_path,
        domain   => $cookie_domain,
        httponly => 1,
    });

    # clean failed logins
    my $userdata = Thruk::Utils::get_user_data($c, $login);
    if($userdata->{'login'}) {
        if($userdata->{'login'}->{'failed'}) {
            Thruk::Utils::set_message( $c, 'warn_message',
                sprintf("There had been %d failed login attempts. (Date: %s - IP: %s%s)",
                            $userdata->{'login'}->{'failed'},
                            Thruk::Utils::Filter::date_format($c, $userdata->{'login'}->{'last_failed'}->{'time'}),
                            $userdata->{'login'}->{'last_failed'}->{'ip'},
                            $userdata->{'login'}->{'last_failed'}->{'forwarded_for'} ? ' ('.$userdata->{'login'}->{'last_failed'}->{'forwarded_for'} : '',
            ));
        }
        delete $userdata->{'login'};
        Thruk::Utils::store_user_data($c, $userdata, $login);
    }

    _audit_log("login", "user login, session started (".$type.")");

    return $c->redirect_to($referer);
}

##########################################################
sub _invalidate_current_session {
    my($c, $cookie_path, $hint) = @_;
    $hint = "session invalidated" unless $hint;
    my $cookie = $c->cookie('thruk_auth');
    if(defined $cookie and defined $cookie->value) {
        my $session_data = Thruk::Utils::CookieAuth::retrieve_session(config => $c->config, id => $cookie->value);

        my $sessionid = $session_data->{'hashed_key'};
        $sessionid = (Thruk::Utils::CookieAuth::private2hashed($cookie->value))[0] unless $sessionid; # try to reconstruct the session id for already removed session files
        _audit_log("logout", "session ended, ".$hint, $session_data->{'username'}, $sessionid);

        if($session_data && $session_data->{'file'}) {
            unlink($session_data->{'file'});
        }
    }

    $c->cookie('thruk_auth' => '', {
        expires  => 0,
        path     => $cookie_path,
        domain   => _get_cookie_domain($c),
        httponly => 1,
    });

    # remove session cookie for all path and domain variations
    my $domains = [];
    my $domain;
    my $http_host = $c->req->env->{'HTTP_HOST'};
    $http_host =~ s/:\d+$//gmx;
    for my $part (reverse split/\./mx, $http_host) {
        if(!$domain) {
            $domain = $part;
        } else {
            $domain = $part.".".$domain;
        }
        push @{$domains}, $domain;
    }

    my $path_info = $c->req->env->{'REQUEST_URI_ORIG'};
    $path_info =~ s/\?.*$//gmx; # strip off get parameter
    $path_info =~ s/^\///gmx; # strip off leading slash
    $path_info =~ s/\/[^\/]+$/\//gmx; # strip off file part
    my $paths = ["/"];
    my $path  = "";
    for my $part (split/\//mx, $path_info) {
        $path = $path."/".$part;
        push @{$paths}, $path."/";
    }

    for my $path (@{$paths}) {
        # without domain
        my $cookie = sprintf("thruk_auth=; path=%s;expires=Thu, 01 Jan 1970 00:00:01 GMT; HttpOnly", $path);
        push @{$c->stash->{'extra_headers'}}, "Set-Cookie", $cookie;

        # for all sub domains
        for my $domain (@{$domains}) {
            my $cookie = sprintf("thruk_auth=; path=%s;domain=%s;expires=Thu, 01 Jan 1970 00:00:01 GMT; HttpOnly", $path, $domain);
            push @{$c->stash->{'extra_headers'}}, "Set-Cookie", $cookie;
        }
    }

    return;
}

##########################################################
sub _get_cookie_domain {
    my($c) = @_;
    my $domain = $c->config->{'cookie_auth_domain'};
    return "" unless $domain;
    my $http_host = $c->req->env->{'HTTP_HOST'};
    # remove port
    $http_host =~ s/:\d+$//gmx;
    $domain =~ s/\.$//gmx;
    if($http_host !~ m/\Q$domain\E$/mx) {
        return($http_host);
    }
    return $domain;
}

##########################################################

1;
