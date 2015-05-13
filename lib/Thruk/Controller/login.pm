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

    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{'theme'}          = $c->config->{'default_theme'} unless defined $c->stash->{'theme'};
    $c->stash->{'page'}           = 'splashpage';
    $c->stash->{'loginurl'}       = $c->stash->{'url_prefix'}."cgi-bin/login.cgi";
    $c->stash->{'template'}       = 'login.tt';
    my $product_prefix            = $c->config->{'product_prefix'};

    my $cookie_path = $c->stash->{'cookie_path'};
    my $sdir        = $c->config->{'var_path'}.'/sessions';
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
            Thruk::Utils::set_message( $c, 'fail_message', 'login not possible without accepting cookies' );
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
            _invalidate_current_session($c, $cookie_path, $sdir);
            Thruk::Utils::set_message( $c, 'fail_message', 'technical problem during login, please have a look at the logfiles.' );
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
            domain  => ($c->config->{'cookie_auth_domain'} ? $c->config->{'cookie_auth_domain'} : ''),
        });
        if(   (!defined $testcookie or !$testcookie->value)
           && (!defined $c->req->header('user-agent') or $c->req->header('user-agent') !~ m/wget/mix)) {
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi?nocookie");
        } else {
            $c->stats->profile(begin => "login::external_authentication");
            my $success = Thruk::Utils::CookieAuth::external_authentication($c->config, $login, $pass, $c->req->{'address'}, $c->stats);
            $c->stats->profile(end => "login::external_authentication");
            if($success eq '-1') {
                return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/login.cgi?problem&".$referer);
            }
            elsif($success) {
                $c->cookie('thruk_auth' => $success, {
                    path    => $cookie_path,
                    domain  => ($c->config->{'cookie_auth_domain'} ? $c->config->{'cookie_auth_domain'} : ''),
                });
                # call a script hook after successful login?
                if($c->config->{'cookie_auth_login_hook'}) {
                    my $cookie_hook = 'REMOTE_USER="'.$login.'" '.$c->config->{'cookie_auth_login_hook'}.' >/dev/null 2>&1 &';
                    `$cookie_hook`;
                }
                return $c->redirect_to($referer);
            } else {
                $c->log->info("login failed for $login on $referer");
                Thruk::Utils::set_message( $c, 'fail_message', 'login failed' );
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
        domain  => ($c->config->{'cookie_auth_domain'} ? $c->config->{'cookie_auth_domain'} : ''),
    });

    $c->stats->profile(end => "login::index");

    return 1;
}

##########################################################
sub _invalidate_current_session {
    my($c, $cookie_path, $sdir) = @_;
    my $cookie = $c->cookie('thruk_auth');
    $c->cookie('thruk_auth' => '', {
        expires => 0,
        path    => $cookie_path,
        domain  => ($c->config->{'cookie_auth_domain'} ? $c->config->{'cookie_auth_domain'} : ''),
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

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
