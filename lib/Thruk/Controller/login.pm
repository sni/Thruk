package Thruk::Controller::login;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';
use Thruk::Utils::CookieAuth;

=head1 NAME

Thruk::Controller::login - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 login_cgi

page: /thruk/cgi-bin/login.cgi

=cut

sub login_cgi : Path('/thruk/cgi-bin/login.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/login/index');
}

##########################################################

=head2 index

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->stats->profile(begin => "login::index");

    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{'theme'}          = $c->config->{'default_theme'} unless defined $c->stash->{'theme'};
    $c->stash->{'page'}           = 'splashpage';
    $c->stash->{'loginurl'}       = $c->stash->{'url_prefix'}."cgi-bin/login.cgi";
    $c->stash->{'template'}       = 'login.tt';

    # auth cookie is not for thruk only
    my $cookie_path = $c->stash->{'cookie_path'};
    $cookie_path =~ s/\/thruk$//mx;

    my $sdir = $c->config->{'var_path'}.'/sessions';
    Thruk::Utils::IO::mkdir($sdir);

    my $keywords = $c->req->query_keywords;
    my $logoutref;
    if($keywords and $keywords =~ m/^logout(\/.*)/mx) {
        $keywords = 'logout';
        $logoutref = $1;
    }
    if($c->req->uri =~ m/\/thruk\/cgi\-bin\/login\.cgi\?logout(\/.*)/mx) {
        $keywords = 'logout';
        $logoutref = $1;
    }
    if(defined $keywords) {
        if($keywords eq 'logout') {
            my $cookie = $c->request->cookie('thruk_auth');
            $c->res->cookies->{'thruk_auth'} = {
                value   => '',
                expires => '-1M',
                path    => $cookie_path,
                domain  => ($c->config->{'cookie_auth_domain'} ? $c->config->{'cookie_auth_domain'} : ''),
            };
            if(defined $cookie and defined $cookie->value) {
                my $sessionid = $cookie->value;
                if($sessionid =~ m/^\w+$/mx and -f $sdir.'/'.$sessionid) {
                    unlink($sdir.'/'.$sessionid);
                }
            }

            Thruk::Utils::set_message( $c, 'success_message', 'logout successful' );
            return $c->response->redirect($logoutref) if $logoutref;
            return $c->response->redirect($c->stash->{'url_prefix'}."cgi-bin/login.cgi");
        }

        if($keywords eq 'nocookie') {
            Thruk::Utils::set_message( $c, 'fail_message', 'login not possible without accepting cookies' );
        }
        if($keywords =~ /^expired\&(.*)$/mx or $keywords eq 'expired') {
            Thruk::Utils::set_message( $c, 'fail_message', 'session has expired' );
        }
        if($keywords =~ /^invalid\&(.*)$/mx or $keywords eq 'invalid') {
            Thruk::Utils::set_message( $c, 'fail_message', 'session is not valid (anymore)' );
        }
        if($keywords =~ /^problem\&(.*)$/mx or $keywords eq 'problem') {
            Thruk::Utils::set_message( $c, 'fail_message', 'technical problem during login, please have a look at the logfiles.' );
        }
    }

    my $login   = $c->request->parameters->{'login'}    || '';
    my $pass    = $c->request->parameters->{'password'} || '';
    my $submit  = $c->request->parameters->{'submit'}   || '';
    my $referer = $c->request->parameters->{'referer'}  || '';
    $referer    =~ s#^//#/#gmx;         # strip double slashes
    $referer    =~ s#.*/nocookie$##gmx; # strip nocookie
    $referer    = $c->stash->{'url_prefix'} unless $referer;

    # make lowercase username
    $login      = lc($login) if $c->config->{'make_auth_user_lowercase'};

    if($submit ne '') {
        my $testcookie = $c->request->cookie('thruk_test');
        $c->res->cookies->{'thruk_test'} = {
            value   => '',
            expires => '-1M',
            path    => $cookie_path,
            domain  => ($c->config->{'cookie_auth_domain'} ? $c->config->{'cookie_auth_domain'} : ''),
        };
        if(!defined $testcookie or !$testcookie->value) {
            return $c->response->redirect($c->stash->{'url_prefix'}."cgi-bin/login.cgi?nocookie");
        } else {
            $c->stats->profile(begin => "login::external_authentication");
            my $success = Thruk::Utils::CookieAuth::external_authentication($c->config, $login, $pass, $c->req->{'address'});
            $c->stats->profile(end => "login::external_authentication");
            if($success eq '-1') {
                return $c->response->redirect($c->stash->{'url_prefix'}."cgi-bin/login.cgi?problem&".$referer);
            }
            elsif($success) {
                $c->res->cookies->{'thruk_auth'} = {
                    value   => $success,
                    path    => $cookie_path,
                    domain  => ($c->config->{'cookie_auth_domain'} ? $c->config->{'cookie_auth_domain'} : ''),
                };
                # call a script hook after successful login?
                if($c->config->{'cookie_auth_login_hook'}) {
                    my $cookie_hook = 'REMOTE_USER="'.$login.'" '.$c->config->{'cookie_auth_login_hook'}.' >/dev/null 2>&1 &';
                    `$cookie_hook`;
                }
                return $c->response->redirect($referer);
            } else {
                $c->log->info("login failed for $login on $referer");
                Thruk::Utils::set_message( $c, 'fail_message', 'login failed' );
                return $c->response->redirect($c->stash->{'url_prefix'}."cgi-bin/login.cgi?".$referer);
            }
        }
    }
    else {
        # clean up in background
        $c->run_after_request('Thruk::Utils::CookieAuth::clean_session_files($c->config)');
    }

    Thruk::Utils::ssi_include($c, 'login');

    # set test cookie
    $c->res->cookies->{'thruk_test'} = {
        value   => '****',
        path    => $cookie_path,
        domain  => ($c->config->{'cookie_auth_domain'} ? $c->config->{'cookie_auth_domain'} : ''),
    };

    $c->stats->profile(end => "login::index");

    return 1;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
