package Thruk::Controller::login;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';
use Thruk::Utils::CookieAuth;

use LWP::UserAgent;

=head1 NAME

Thruk::Controller::login - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 login_cgi

page: /thruk/cgi-bin/login.cgi

=cut

sub login_cgi : Regex('thruk\/cgi\-bin\/login\.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/login/index');
}

##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{'theme'}          = $c->config->{'default_theme'} unless defined $c->stash->{'theme'};
    $c->stash->{'page'}           = 'splashpage';
    $c->stash->{'loginurl'}       = $c->stash->{'url_prefix'}."thruk/cgi-bin/login.cgi";
    $c->stash->{'template'}       = 'login.tt';

    # auth cookie is not for thruk only
    my $cookie_path = $c->stash->{'cookie_path'};
    $cookie_path =~ s/\/thruk$//mx;

    my $sdir = $c->config->{'tmp_path'}.'/sessions';
    Thruk::Utils::IO::mkdir($sdir);

    if($c->req->query_keywords eq 'logout') {
        my $cookie = $c->request->cookie('thruk_auth');
        $c->res->cookies->{'thruk_auth'} = {
            value   => '',
            expires => '-1M',
            path    => $cookie_path,
        };
        if(defined $cookie and defined $cookie->value) {
            my $sessionid = $cookie->value;
            if($sessionid =~ m/^\w+$/mx and -f $sdir.'/'.$sessionid) {
                unlink($sdir.'/'.$sessionid);
            }
        }

        Thruk::Utils::set_message( $c, 'success_message', 'logout successful' );
        return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/login.cgi");
    }

    my $login          = $c->request->parameters->{'login'}    || '';
    my $pass           = $c->request->parameters->{'password'} || '';
    my $submit         = $c->request->parameters->{'submit'}   || '';
    my $referer        = $c->request->parameters->{'referer'}  || $c->stash->{'url_prefix'}.'thruk/';

    if($submit ne '') {
        my $success = Thruk::Utils::CookieAuth::external_authentication($c->config, $login, $pass, $c->req->{'address'});
        if($success) {
            $c->res->cookies->{'thruk_auth'} = {
                value => $success,
                path  => $cookie_path,
            };
            $referer =~ s#^//#/#gmx; # strip double slashes
            return $c->response->redirect($referer);
        } else {
            $referer =~ s#^//#/#gmx; # strip double slashes
            $c->log->info("login failed for $login on $referer");
            Thruk::Utils::set_message( $c, 'fail_message', 'login failed' );
            return $c->response->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/login.cgi?".$referer);
        }
    }
    else {
        Thruk::Utils::CookieAuth::clean_session_files($c->config);
    }

    Thruk::Utils::ssi_include($c, 'login');

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
