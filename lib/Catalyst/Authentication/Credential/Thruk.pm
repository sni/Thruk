package Catalyst::Authentication::Credential::Thruk;

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

use base 'Class::Accessor::Fast';

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

    my $cgi_cfg = $c->{'cgi_cfg'};

    # authenticated by ssl
    if(defined $cgi_cfg->{'use_ssl_authentication'} and $cgi_cfg->{'use_ssl_authentication'} >= 1) {
        if(defined $c->engine->env->{'SSL_CLIENT_S_DN_CN'}) {
            $username = $c->engine->env->{'SSL_CLIENT_S_DN_CN'};
        }
    }

    # basic authentication
    else {
        if(defined $c->engine->env->{'REMOTE_USER'}) {
            $username = $c->engine->env->{'REMOTE_USER'};
        }
    }

    # default_user_name?
    if(!defined $username and defined $cgi_cfg->{'default_user_name'}) {
        $username = $cgi_cfg->{'default_user_name'};
    }

    if(!defined $username or $username eq '') {
        return;
    }

    $authinfo->{ username } = $username;
    my $user_obj = $realm->find_user( $authinfo, $c );

    if ( ref $user_obj ) {
        return $user_obj;
    } else {
        $c->log->debug("authentication failed to load with find_user; bad user_class? Try 'Null.'") if $self->debug;
        return;
    }
}

1;
