package Thruk::Controller::login;

use strict;
use warnings;

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
    my $product_prefix            = $c->config->{'product_prefix'};

    my $cookie_path   = $c->stash->{'cookie_path'};
    my $cookie_domain = _get_cookie_domain($c);
    my $sdir          = $c->config->{'var_path'}.'/sessions';
    Thruk::Utils::IO::mkdir($sdir);

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
    if(defined $keywords) {
        if($keywords eq 'logout') {
            _invalidate_current_session($c, $cookie_path, $sdir);
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
            _invalidate_current_session($c, $cookie_path, $sdir);
            Thruk::Utils::set_message( $c, 'fail_message', 'session has expired' );
        }
        if($keywords =~ /^invalid\&(.*)$/mx or $keywords eq 'invalid') {
            _invalidate_current_session($c, $cookie_path, $sdir);
            Thruk::Utils::set_message( $c, 'fail_message', 'session is not valid (anymore)' );
        }
        if($keywords =~ /^problem\&(.*)$/mx or $keywords eq 'problem') {
            # don't remove all sessions when there is a (temporary) technical problem
            #_invalidate_current_session($c, $cookie_path, $sdir);
            Thruk::Utils::set_message( $c, 'fail_message', 'technical problem during login, please have a look at the logfiles.' );
        }
        if($keywords =~ /^locked\&(.*)$/mx or $keywords eq 'locked') {
            _invalidate_current_session($c, $cookie_path, $sdir);
            Thruk::Utils::set_message( $c, 'fail_message', 'account is locked, please contact an administrator' );
        }
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

    # make lowercase username
    $login      = lc($login) if $c->config->{'make_auth_user_lowercase'};

    if($submit ne '' || $login ne '') {
        my $testcookie = $c->cookie('thruk_test');
        $c->cookie('thruk_test' => '', {
            expires => 0,
            path    => $cookie_path,
            domain  => $cookie_domain,
        });
        if(   (!defined $testcookie || !$testcookie->value)
           && (!defined $c->req->header('user-agent') || $c->req->header('user-agent') !~ m/wget/mix)) {
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi?nocookie");
        } else {
            my $userdata = Thruk::Utils::get_user_data($c, $login);
            if($userdata->{'login'}->{'locked'}) {
                return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi?locked&".$referer);
            }

            $c->stats->profile(begin => "login::external_authentication");
            my $success = Thruk::Utils::CookieAuth::external_authentication($c->config, $login, $pass, $c->req->address, $c->stats);
            $c->stats->profile(end => "login::external_authentication");
            if($success eq '-1') {
                return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi?problem&".$referer);
            }
            elsif($success) {
                $c->stash->{'remote_user'} = $login;
                $c->cookie('thruk_auth' => $success, {
                    path    => $cookie_path,
                    domain  => $cookie_domain,
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

                # call a script hook after successful login?
                if($c->config->{'cookie_auth_login_hook'}) {
                    Thruk::Utils::IO::cmd($c, $c->config->{'cookie_auth_login_hook'}.' >/dev/null 2>&1 &');
                }
                return $c->redirect_to($referer);
            } else {
                $c->log->info(sprintf("login failed for %s on %s from %s%s",
                                        $login,
                                        $referer,
                                        $c->req->address,
                                       ($c->env->{'HTTP_X_FORWARDED_FOR'} ? ' ('.$c->env->{'HTTP_X_FORWARDED_FOR'}.')' :''),
                              ));
                Thruk::Utils::set_message( $c, 'fail_message', 'login failed' );
                if($c->config->{cookie_auth_disable_after_failed_logins}) {
                    # increase failed login counter and disable account if it exceeds
                    my $userdata = Thruk::Utils::get_user_data($c, $login);
                    $userdata->{'login'}->{'failed'}++;
                    $userdata->{'login'}->{'last_failed'} = { time => time(), ip => $c->req->address, forwarded_for => $c->env->{'HTTP_X_FORWARDED_FOR'} };
                    if($userdata->{'login'}->{'failed'} >= $c->config->{cookie_auth_disable_after_failed_logins}) {
                        $userdata->{'login'}->{'locked'} = 1;
                    }
                    Thruk::Utils::store_user_data($c, $userdata, $login);
                    if($userdata->{'login'}->{'locked'}) {
                        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi?locked&".$referer);
                    }
                }
                return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi?".$referer);
            }
        }
    }
    else {
        # clean up
        Thruk::Utils::CookieAuth::clean_session_files($c->config);
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

    return 1;
}

##########################################################
sub _invalidate_current_session {
    my($c, $cookie_path, $sdir) = @_;
    my $cookie = $c->cookie('thruk_auth');
    $c->cookie('thruk_auth' => '', {
        expires => 0,
        path    => $cookie_path,
        domain  => _get_cookie_domain($c),
    });
    if(defined $cookie and defined $cookie->value) {
        my $sessionid = $cookie->value;
        if($sessionid =~ m/^\w+$/mx and -f $sdir.'/'.$sessionid) {
            unlink($sdir.'/'.$sessionid);
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

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
