package Catalyst::Authentication::Credential::Thruk;
use parent 'Class::Accessor::Fast';

=head1 NAME

Catalyst::Authentication::Credential::Thruk - Authenticate a remote user configured using a cgi.cfg

=head1 SYNOPSIS

    # in your MyApp.pm
    __PACKAGE__->config(

        'Plugin::Authentication' => {
            default_realm => 'remoterealm',
            realms => {
                remoterealm => {
                    credential => {
                        class        => 'Thruk',
                    },
                    store => {
                        class => 'Null',
                    }
                },
            },
        },

    );

    # in your Controller/Root.pm you can implement "auto-login" in this way
    sub begin : Private {
        my ( $self, $c ) = @_;
        unless ($c->user_exists) {
            # authenticate() for this module does not need any user info
            # as the username is taken from $c->req->remote_user and
            # password is not needed
            unless ($c->authenticate( {} )) {
              # return 403 forbidden or kick out the user in other way
            };
        }
    }

    # or you can implement in any controller an ordinary login action like this
    sub login : Global {
        my ( $self, $c ) = @_;
        $c->authenticate( {} );
    }

=head1 DESCRIPTION

This module allows you to authenticate the users of your Catalyst application
on underlaying webserver.

=cut

use strict;
use warnings;
use Data::Dumper;

BEGIN {
    __PACKAGE__->mk_accessors(
        qw/realm/);
}

=head1 METHODS

=head2 new

create a new C<Catalyst::Authentication::Credential::Thruk> object.

 Catalyst::Authentication::Credential::Thruk->new($config, $app, $realm);

=cut

sub new {
    my ( $class, $config, $app, $realm ) = @_;

    my $self = { };
    bless $self, $class;

    $self->realm($realm);
    return $self;
}

=head2 authenticate

authenticate a user

 authenticate($c, $realm, $authinfo)

=cut

sub authenticate {
    my ( $self, $c, $realm, $authinfo ) = @_;
    my $username;
    my $authenticated = 0;

    # authenticated by ssl
    if(defined $c->config->{'cgi_cfg'}->{'use_ssl_authentication'} and $c->config->{'cgi_cfg'}->{'use_ssl_authentication'} >= 1
        and defined $c->engine->env->{'SSL_CLIENT_S_DN_CN'}) {
            $username = $c->engine->env->{'SSL_CLIENT_S_DN_CN'};
    }
    # from cli
    elsif(defined $c->stash->{'remote_user'} and $c->stash->{'remote_user'} ne '?') {
        $username = $c->stash->{'remote_user'};
    }
    # basic authentication
    elsif(defined $c->engine->env->{'REMOTE_USER'}) {
        $username = $c->engine->env->{'REMOTE_USER'};
    }
    elsif(defined $ENV{'REMOTE_USER'}) {
        $username = $ENV{'REMOTE_USER'};
    }

    # default_user_name?
    elsif(defined $c->config->{'cgi_cfg'}->{'default_user_name'}) {
        $username = $c->config->{'cgi_cfg'}->{'default_user_name'};
    }

    elsif(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'CLI') {
        $username = $c->config->{'default_cli_user_name'};
    }

    if(!defined $username or $username eq '') {
        return;
    }

    # change case?
    $username = lc($username) if $c->config->{'make_auth_user_lowercase'};
    $username = uc($username) if $c->config->{'make_auth_user_uppercase'};

    $authinfo->{ username } = $username;
    my $user_obj = $realm->find_user( $authinfo, $c );

    if ( ref $user_obj ) {
        return $user_obj;
    }
    $c->log->debug("authentication failed to load with find_user; bad user_class? Try 'Null.'") if $self->debug;
    return;
}

1;
