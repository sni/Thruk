package Catalyst::Authentication::Credential::Nagios;

use strict;
use warnings;
$DB::single=1;
use base 'Class::Accessor::Fast';

BEGIN {
#$DB::single=1;
    __PACKAGE__->mk_accessors(
        qw/realm/);
}

sub new {
#$DB::single=1;
    my ( $class, $config, $app, $realm ) = @_;

    my $self = { };
    bless $self, $class;
#print "###################################\n";
#print "do da auth\n";
#print $app."\n";
#print $realm."\n";
#die('test');
    $self->realm($realm);
    $self->username_field($config->{username_field} || 'username');
    return $self;
}

sub authenticate {
#$DB::single=1;
    my ( $self, $c, $realm, $authinfo ) = @_;

	$c->log->debug("authenticate()");

#print "###################################\n";
#print "do da auth2\n";
#print $app."\n";
#print $realm."\n";
#die('test2');

=head1
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
=cut
    return;
}

1;

__END__
