package Catalyst::Authentication::Credential::Nagios;

use strict;
use warnings;

use base 'Class::Accessor::Fast';

BEGIN {
    __PACKAGE__->mk_accessors(
        qw/allow_re deny_re cutname_re source realm username_field/);
}

sub new {
    my ( $class, $config, $app, $realm ) = @_;

    my $self = { };
    bless $self, $class;

    # we are gonna compile regular expresions defined in config parameters
    # and explicitly throw an exception saying what parameter was invalid
    if (defined($config->{allow_regexp}) && ($config->{allow_regexp} ne "")) {
        eval { $self->allow_re( qr/$config->{allow_regexp}/ ) };
        Catalyst::Exception->throw( "Invalid regular expression in ".
        "'allow_regexp' configuration parameter") if $@;
    }
    if (defined($config->{deny_regexp}) && ($config->{deny_regexp} ne "")) {
        eval { $self->deny_re( qr/$config->{deny_regexp}/ ) };
        Catalyst::Exception->throw( "Invalid regular expression in ".
             "'deny_regexp' configuration parameter") if $@;
    }
    if (defined($config->{cutname_regexp}) && ($config->{cutname_regexp} ne "")) {
        eval { $self->cutname_re( qr/$config->{cutname_regexp}/ ) };
        Catalyst::Exception->throw( "Invalid regular expression in ".
             "'cutname_regexp' configuration parameter") if $@;
    }
    $self->source($config->{source} || 'REMOTE_USER');
    $self->realm($realm);
    $self->username_field($config->{username_field} || 'username');
    return $self;
}

sub authenticate {
    my ( $self, $c, $realm, $authinfo ) = @_;

    my $remuser;
    if ($self->source eq "REMOTE_USER") {
        # compatibility hack:
        if (defined($c->engine->env)) {
            # BEWARE: $c->engine->env was broken prior 5.80005
            $remuser = $c->engine->env->{REMOTE_USER};
        }
        elsif ($c->req->can('remote_user')) {
            # $c->req->remote_users was introduced in 5.80005; if not evailable we are
            # gonna use $c->req->user that is deprecated but more or less works as well
            $remuser = $c->req->remote_user;
        }
        elsif ($c->req->can('user')) {
            # maybe show warning that we are gonna use DEPRECATED $req->user
            if (ref($c->req->user)) {
                # I do not know exactly when this happens but it happens
	        Catalyst::Exception->throw( "Cannot get remote user from ".
		"\$c->req->user as it seems to be a reference not a string" );
	    }
	    else {
	        $remuser = $c->req->user;
	    }
        }
    }
    elsif ($self->source =~ /^(SSL_CLIENT_.*|CERT_*|AUTH_USER)$/) {
        # if you are using 'exotic' webserver or if the user is
        # authenticated e.g via SSL certificate his name could be avaliable
        # in different variables
        # BEWARE: $c->engine->env was broken prior 5.80005
        my $nam=$self->source;
        if ($c->engine->can('env')) {
            $remuser = $c->engine->env->{$nam};
        }
        else {
            # this happens on Catalyst 5.80004 and before (when using FastCGI)
            Catalyst::Exception->throw( "Cannot handle parameter 'source=$nam'".
                " as runnig Catalyst engine has broken \$c->engine->env" );
        }
    }
    else {
        Catalyst::Exception->throw( "Invalid value of 'source' parameter");
    }
    return unless defined($remuser);
    return if ($remuser eq "");

    # $authinfo hash can contain item username (it is optional) - if it is so
    # this username has to be equal to remote_user
    my $authuser = $authinfo->{username};
    return if (defined($authuser) && ($authuser ne $remuser));

    # handle deny / allow checks
    return if (defined($self->deny_re)  && ($remuser =~ $self->deny_re));
    return if (defined($self->allow_re) && ($remuser !~ $self->allow_re));

    # if param cutname_regexp is specified we try to cut the final usename as a
    # substring from remote_user
    my $usr = $remuser;
    if (defined($self->cutname_re)) {
        if (($remuser =~ $self->cutname_re) && ($1 ne "")) {
            $usr = $1;
        }
    }

    $authinfo->{ $self->username_field } = $usr;
    my $user_obj = $realm->find_user( $authinfo, $c );
    return ref($user_obj) ? $user_obj : undef;
}

1;

__END__

=pod

=head1 NAME

Catalyst::Authentication::Credential::Remote - Let the webserver (e.g. Apache)
authenticate Catalyst application users

=head1 SYNOPSIS

    # in your MyApp.pm
    __PACKAGE__->config(

        'Plugin::Authentication' => {
            default_realm => 'remoterealm',
            realms => {
                remoterealm => {
                    credential => {
                        class        => 'Remote',
                        allow_regexp => '^(user.*|admin|guest)$',
                        deny_regexp  => 'test',
                    },
                    store => {
                        class => 'Null',
                        # if you want to have some additional user attributes
                        # like user roles, user full name etc. you can specify
                        # here the store where you keep this data
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
on underlaying webserver. The complete list of authentication method available
via this module depends just on what your webserver (e.g. Apache, IIS, Lighttpd)
is able to handle.

Besides the common methods like HTTP Basic and Digest authentication you can
also use sophisticated ones like so called "integrated authentication" via
NTLM or Kerberos (popular in corporate intranet applications running in Windows
Active Directory enviroment) or even the SSL authentication when users
authenticate themself using their client SSL certificates.

The main idea of this module is based on a fact that webserver passes the name
of authenticated user into Catalyst application as REMOTE_USER variable (or in
case of SSL client authentication in other variables like SSL_CLIENT_S_DN on
Apache + mod_ssl) - from this point referenced as WEBUSER.
This module simply takes this value - perfoms some optional checks (see
below) - and if everything is OK the WEBUSER is declared as authenticated on
Catalyst level. In fact this module does not perform any check for password or
other credential; it simply believes the webserver that user was properly
authenticated.

=head1 CONFIG

=head2 class

This config item is B<REQUIRED>.

B<class> is part of the core L<Catalyst::Plugin::Authentication> module, it
contains the class name of the store to be used.

The classname used for Credential. This is part of L<Catalyst::Plugin::Authentication>
and is the method by which Catalyst::Authentication::Credential::Remote is
loaded as the credential validator. For this module to be used, this must be set
to 'Remote'.

=head2 source

This config item is B<OPTIONAL> - default is REMOTE_USER.

B<source> contains a name of a variable passed from webserver that contains the
user identification.

Supported values: REMOTE_USER, SSL_CLIENT_*, CERT_*, AUTH_USER

B<BEWARE:> Support for using different variables than REMOTE_USER does not work
properly with Catalyst 5.8004 and before (if you want details see source code).

Note1: Apache + mod_ssl uses SSL_CLIENT_S_DN, SSL_CLIENT_S_DN_* etc. (has to be
enabled by 'SSLOption +StdEnvVars') or you can also let Apache make a copy of
this value into REMOTE_USER (Apache option 'SSLUserName SSL_CLIENT_S_DN').

Note2: Microsoft IIS uses CERT_SUBJECT, CERT_SERIALNUMBER etc. for storing info
about client authenticated via SSL certificate. AUTH_USER on IIS seems to have
the same value as REMOTE_USER (but there might be some differences I am not
aware of).

=head2 deny_regexp

This config item is B<OPTIONAL> - no default value.

B<deny_regexp> contains a regular expression used for check against WEBUSER
(see details below)

=head2 allow_regexp

This config item is B<OPTIONAL> - no default value.

B<deny_regexp> contains a regular expression used for check against WEBUSER.

Allow/deny checking of WEBUSER values goes in this way:

1) If B<deny_regexp> is defined and WEBUSER matches deny_regexp then
authentication FAILS otherwise continues with next step. If deny_regexp is not
defined or is an empty string we skip this step.

2) If B<allow_regexp> is defined and WEBUSER matches allow_regexp then
authentication PASSES otherwise FAILS. If allow_regexp is not
defined or is an empty string we skip this step.

The order deny-allow is fixed.

=head2 cutname_regexp

This config item is B<OPTIONAL> - no default value.

If param B<cutname_regexp> is specified we try to cut the final usename passed to
Catalyst application as a substring from WEBUSER. This is usefull for
example in case of SSL authentication when WEBUSER looks like this
'CN=john, OU=Unit Name, O=Company, C=CZ' - from this format we can simply cut
pure usename by cutname_regexp set to 'CN=(.*), OU=Unit Name, O=Company, C=CZ'.

Substring is always taken as '$1' regexp substring. If WEBUSER does not
match cutname_regexp at all or if '$1' regexp substring is empty we pass the
original WEBUSER value (without cutting) to Catalyst application.

=head2 username_field

This config item is B<OPTIONAL> - default is I<username>

The key name in the authinfo hash that the user's username is mapped into.
This is useful for using a store which requires a specific unusual field name
for the username.  The username is additionally mapped onto the I<id> key.

=head1 METHODS

=head2 new ( $config, $app, $realm )

Instantiate a new Catalyst::Authentication::Credential::Remote object using the
configuration hash provided in $config. In case of invalid value of any
configuration parameter (e.g. invalid regular expression) throws an exception.

=cut

=head2 authenticate ( $realm, $authinfo )

Takes the username form WEBUSER set by webserver, performs additional
checks using optional allow_regexp/deny_regexp configuration params, optionaly
takes substring from WEBUSER and the sets the resulting value as
a Catalyst username.

=cut

=head1 COMPATIBILITY

It is B<strongly recommended> to use this module with Catalyst 5.80005 and above
as previous versions have some bugs related to $c->engine->env and do not
support $c->req->remote_user.

This module tries some workarounds when it detects an older version and should
work as well.

=cut
