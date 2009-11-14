package Catalyst::Authentication::Credential::Nagios;

use strict;
use warnings;
use Data::Dumper;
use Nagios::Web::Helper;

use base 'Class::Accessor::Fast';

BEGIN {
    __PACKAGE__->mk_accessors(
        qw/realm/);
}

sub new {
    my ( $class, $config, $app, $realm ) = @_;

    my $self = { };
    bless $self, $class;

	$self->realm($realm);
    return $self;
}

sub authenticate {
    my ( $self, $c, $realm, $authinfo ) = @_;
	my $username;

    #$c->log->debug("authenticate()");
    #$c->log->debug(Dumper($realm));
    #$c->log->debug(Dumper($authinfo));

	my $cgi_cfg = Nagios::Web::Helper->get_cgi_cfg($c);

    # authenticated by ssl
    if(defined $cgi_cfg->{'use_ssl_authentication'} and $cgi_cfg->{'use_ssl_authentication'} == 1) {
        if(defined $c->engine->env->{'SSL_CLIENT_S_DN_CN'}) {
			$username = $c->engine->env->{'SSL_CLIENT_S_DN_CN'};
		}
    }

    # basic authentication
    elsif(defined $cgi_cfg->{'use_authentication'} and $cgi_cfg->{'use_authentication'} == 1) {
        if(defined $c->engine->env->{'REMOTE_USER'}) {
			$username = $c->engine->env->{'REMOTE_USER'};
		}
    }

    # authenticated by default_user_name
    elsif(defined $cgi_cfg->{'default_user_name'} and $cgi_cfg->{'use_authentication'} == 0) {
        $username = $cgi_cfg->{'default_user_name'};
    }

	if(!defined $username or $username eq '') {
		$c->log->error('got no or empty username from env');
		return;
	}

    $authinfo->{ username } = $username;
    my $user_obj = $realm->find_user( $authinfo, $c );
	$c->{'user'} = $username;
    return ref($user_obj) ? $user_obj : undef;
}

1;

__END__

=pod

=head1 NAME

Catalyst::Authentication::Credential::Nagios - Authenticate a remote user configured by the cgi.cfg
authenticate Catalyst application users

=head1 SYNOPSIS

    # in your MyApp.pm
    __PACKAGE__->config(

        'Plugin::Authentication' => {
            default_realm => 'remoterealm',
            realms => {
                remoterealm => {
                    credential => {
                        class        => 'Nagios',
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
