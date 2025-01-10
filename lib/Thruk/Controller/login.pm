package Thruk::Controller::login;

use warnings;
use strict;
use Carp;
use Cpanel::JSON::XS ();

use Thruk::Utils ();
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
    my $cookie_domain = $c->get_cookie_domain();

    my $keywords = $c->req->uri->query;
    my $has_query = $c->req->uri->query ? 1 : 0;
    my $logoutref;
    if($keywords and $keywords =~ m/^logout(\/.*)/mx) {
        $keywords = 'logout';
        $logoutref = $1;
    }
    if($c->req->url =~ m/\/\Q$product_prefix\E\/cgi\-bin\/login\.cgi\?logout(\/.*)/mx) {
        $keywords = 'logout';
        $logoutref = $1;
    }
    # replace first & with ? (so we don't have to use encoded %3f which breaks apache rewrites)
    if($logoutref && $logoutref !~ m/\?/mx) {
        $logoutref =~ s|&|?|mx;
    }

    my $login   = $c->req->parameters->{'login'}    || '';
    my $pass    = $c->req->parameters->{'password'} || '';
    my $referer = $c->req->parameters->{'referer'}  || '';
    $referer    =~ s#^//#/#gmx;         # strip double slashes
    $referer    = $keywords || $c->stash->{'url_prefix'} unless $referer;
    # append slash for omd sites, IE and chrome wont send the login cookie otherwise
    if(($ENV{'OMD_SITE'} and $referer eq '/'.$ENV{'OMD_SITE'})
       or ($referer eq $c->stash->{'url_prefix'})) {
        $referer =~ s/\/*$//gmx;
        $referer = $referer.'/';
    }
    $referer = $c->req->unescape($referer);
    # add trailing slash if referer ends with the product prefix and nothing else
    if($referer =~ m|\Q/$product_prefix\E$|mx) {
        $referer = $referer.'/';
    }
    my $query = $keywords || $c->req->uri->query;

    # remove known keywords from referer
    $referer  =~ s/^(logout|expired|invalid|problem|locked|setsession|nocookie)(\&|$)//gmx;
    $keywords =~ s/^(logout|expired|invalid|problem|locked|setsession|nocookie)\&.*$/$1/gmx if $keywords;

    # replace first & with ? (so we don't have to use encoded %3f which breaks apache rewrites)
    if($referer && $referer !~ m/\?/mx) {
        $referer =~ s|&|?|mx;
    }

    $c->stash->{'referer'}       = $referer;
    $c->stash->{'clean_cookies'} = 0;

    if($keywords) {
        if($keywords eq 'nocookie') {
            # clean all cookies
            _invalidate_current_session($c, $cookie_path, "login page clears all cookies");
            $c->stash->{'clean_cookies'} = 1; # make html page clear all cookies
        }
        if($keywords eq 'logout') {
            _invalidate_current_session($c, $cookie_path, "user logout");
            Thruk::Utils::set_message( $c, 'success_message', 'logout successful' );
            return $c->redirect_to($logoutref) if $logoutref;
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi");
        }
        elsif($keywords eq 'expired') {
            _invalidate_current_session($c, $cookie_path, "session expired");
            # try again, kerberos sites would login automatically
            if($has_query && $referer && $referer =~ m%/thruk/%mx) {
                sleep(3); # delay a bit
                $referer = '/'.$referer if $referer !~ m|^/|mx;
                return $c->redirect_to($referer);
            }
            Thruk::Utils::set_message( $c, 'fail_message', 'session has expired' );
        }
        elsif($keywords eq 'invalid') {
            _invalidate_current_session($c, $cookie_path, "session invalid");
            Thruk::Utils::set_message( $c, 'fail_message', 'session is not valid (anymore)' );
        }
        elsif($keywords eq 'problem') {
            # don't remove all sessions when there is a (temporary) technical problem
            #_invalidate_current_session($c, $cookie_path, "technical issue");
            Thruk::Utils::set_message( $c, 'fail_message', 'technical problem during login, please have a look at the logfiles.' );
        }
        elsif($keywords eq 'locked') {
            _invalidate_current_session($c, $cookie_path, "user locked");
            Thruk::Utils::set_message($c, { 'style' => 'fail_message', 'msg' => $c->config->{'locked_message'}, 'escape'  => 0 });
        }
        elsif($keywords eq 'setsession') {
            $c->authenticate();
            return $c->redirect_to($referer) if $referer;
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi");
        }
    }

    # simply redirect if already authenticated, but only if it looks like a valid url
    if($has_query && $referer && $referer =~ m%/thruk/%mx && $c->cookies('thruk_auth') && $c->authenticate()) {
        $referer = '/'.$referer if $referer !~ m|^/|mx;
        return $c->redirect_to($referer);
    }

    if($c->req->parameters->{'state'} || (defined $c->req->parameters->{'oauth'} && $c->req->parameters->{'oauth'} ne "")) {
        require Thruk::Utils::OAuth;
        return(Thruk::Utils::OAuth::handle_oauth_login($c, $referer, $cookie_path, $cookie_domain));
    }

    if(defined $c->req->parameters->{'login'} && $login eq '') {
        Thruk::Utils::set_message( $c, 'fail_message', 'Missing credentials' );
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi");
    }

    if($login ne '') {
        return(_handle_basic_login($c, $login, $pass, $referer, $cookie_path, $cookie_domain));
    }

    Thruk::Utils::ssi_include($c, 'login');

    if($c->config->{'cookie_auth_domain'} && $cookie_domain ne $c->config->{'cookie_auth_domain'}) {
        Thruk::Utils::set_message( $c, 'warn_message', 'using '.$cookie_domain.' instead of the configured cookie_auth_domain '.$c->config->{'cookie_auth_domain'});
    }
    $c->stash->{'cookie_domain'} = $cookie_domain;

    $c->stats->profile(end => "login::index");

    $c->res->code(401);

    if(($query && $query =~ m|/thruk/r/|mx) || $c->want_json_response()) {
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
            Thruk::Utils::IO::cmd($c->config->{'cookie_auth_login_hook'}.' >/dev/null 2>&1');
        }
        return(login_successful($c, $login, $session, $referer, $cookie_domain, "password"));
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

        Thruk::Utils::store_user_data($c, $userdata, $login);
        _clean_failed_logins($c);

        if($userdata->{'login'}->{'locked'}) {
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi?locked&".$referer);
        }
    }
    return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi?".$referer);
}

##########################################################

=head2 login_successful

    login_successful($c, $login, $session, $referer, $cookie_domain)

redirects to $referer and sets sessions cookie

=cut
sub login_successful {
    my($c, $login, $session, $referer, $cookie_domain, $type) = @_;

    $c->stash->{'remote_user'} = $login;
    confess("no session") unless $session;
    $c->{'session'} = $session;
    $c->cookie('thruk_auth', $session->{'private_key'}, { domain => $cookie_domain, httponly => 1 });

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
        delete $userdata->{'login'}->{'failed'};
        delete $userdata->{'login'}->{'last_failed'};
    }
    $userdata->{'login'}->{'last_success'} = { time => time(), ip => $c->req->address, forwarded_for => $c->env->{'HTTP_X_FORWARDED_FOR'} };
    Thruk::Utils::store_user_data($c, $userdata, $login);

    _audit_log("login", "user login, session started (".$type.")");

    # add missing leading /
    if($referer !~ m|^/|gmx) {
        $referer = '/'.$referer;
    }

    return $c->redirect_to($referer);
}

##########################################################
sub _invalidate_current_session {
    my($c, $cookie_path, $hint) = @_;
    $hint = "session invalidated" unless $hint;
    my $cookie = $c->cookies('thruk_auth');
    if($cookie) {
        my $session_data = Thruk::Utils::CookieAuth::retrieve_session(config => $c->config, id => $cookie);

        my $sessionid = $session_data->{'hashed_key'};
        $sessionid = (Thruk::Utils::CookieAuth::private2hashed($cookie))[0] unless $sessionid; # try to reconstruct the session id for already removed session files
        _audit_log("logout", "session ended, ".$hint, $session_data->{'username'}, $sessionid);

        if($session_data && $session_data->{'file'}) {
            unlink($session_data->{'file'});
        }
    }

    $c->cookie('thruk_auth', '', { expires  => 0, httponly => 1 });

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
        my $cookie = sprintf("thruk_auth=; path=%s;expires=Thu, 01 Jan 1970 00:00:01 GMT; HttpOnly; samesite=lax;", $path);
        push @{$c->stash->{'extra_headers'}}, "Set-Cookie", $cookie;

        # for all sub domains
        for my $domain (@{$domains}) {
            my $cookie = sprintf("thruk_auth=; path=%s;domain=%s;expires=Thu, 01 Jan 1970 00:00:01 GMT; HttpOnly; samesite=lax;", $path, $domain);
            push @{$c->stash->{'extra_headers'}}, "Set-Cookie", $cookie;
        }
    }

    return;
}

##########################################################
sub _clean_failed_logins {
    my($c) = @_;

    my $dir = $c->config->{'var_path'}.'/users';
    my $cookie_auth_session_timeout = $c->config->{'cookie_auth_session_timeout'};
    if($cookie_auth_session_timeout <= 0) {
        # clean old unused sessions after one year, even if they don't expire
        $cookie_auth_session_timeout = 365 * 86400;
    }
    my $timeout = time() - (30 * 86400);
    Thruk::Utils::IO::mkdir($dir);
# TODO: ...
    opendir( my $dh, $dir) or die "can't opendir '$dir': $!";
    for my $entry (readdir($dh)) {
        next if $entry eq '.' or $entry eq '..';
        my $file = $dir.'/'.$entry;
        my($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size, $atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
        next unless $mtime;
        next if $mtime > $timeout;

        # only remove if this user file only contains the failed login and noting else
        my $data = Thruk::Utils::IO::json_lock_retrieve($file);
        next if !$data;
        next if scalar keys %{$data} != 1; # contains a single item: login
        next if !$data->{'login'};
        next if scalar keys %{$data->{'login'}} != 2; # contains failed and last_failed
        next if !$data->{'login'}->{'failed'};

        unlink($file);
    }

    return;
}

##########################################################

1;
