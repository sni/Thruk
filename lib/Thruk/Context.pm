package Thruk::Context;

use warnings;
use strict;
use Carp qw/confess/;
use Thruk::Request;
use Thruk::Authentication::User;
use Thruk::Request::Cookie;
use Thruk::Stats;
use Plack::Util::Accessor qw(app db req res stash config user stats obj_db);
use Scalar::Util qw/weaken/;
use Time::HiRes qw/gettimeofday/;

=head1 NAME

Thruk::Context - Main Context Object

=head1 SYNOPSIS

  use Thruk::Context;

=head1 DESCRIPTION

C<Thruk::Context> Main Context Object

=head1 METHODS

=head2 new

    new()

return new context object

=cut

sub new {
    my($class, $app, $env) = @_;

    my($time_begin, $memory_begin);
    if($ENV{'THRUK_PERFORMANCE_DEBUG'}) {
        $time_begin   = [gettimeofday()];
        $memory_begin = Thruk::Backend::Pool::get_memory_usage();
    }

    my $req = Thruk::Request->new($env);
    my $self = {
        app    => $app,
        env    => $env,
        config => $app->{'config'},
        stash  => {
            time_begin   => $time_begin,
            memory_begin => $memory_begin,
        },
        req    => $req,
        res    => $req->new_response(200),
        stats  => Thruk::Stats->new(),
        user   => undef,
        errors => [],
    };
    bless($self, $class);
    weaken($self->{'app'}) unless $ENV{'THRUK_SRC'} eq 'CLI';
    #if(Thruk->debug) { $self->stats->enable(); }
    $self->stats->enable();
    return($self);
}

=head2 request

return request object

=cut
sub request {
    return($_[0]->{'req'});
}

=head2 response

return response object

=cut
sub response {
    return($_[0]->{'res'});
}

=head2 log

return log object

=cut
sub log {
    return($_[0]->{'app'}->{'log'});
}

=head2 detach

detach to other controller

=cut
sub detach {
    if(!$_[0]->{'errored'} && $_[1] =~ m|/error/index/(\d+)$|mx) {
        use Thruk::Controller::error;
        return(Thruk::Controller::error::index($_[0], $1));
    }
    confess("detach: ".$_[1]." at ".$_[0]->req->url->path);
}

=head2 render

detach to other controller

=cut
sub render {
    my($c, %args) = @_;
    if($args{'json'}) {
        return(Thruk::Views::JSONRenderer::render_json($c, $args{'json'}));
    }
    confess("unknown renderer");
}

=head2 render_excel

detach to excel controller

=cut
sub render_excel {
    my($c) = @_;
    return(Thruk::Views::ExcelRenderer::render_excel($c));
}

=head2 render_gd

detach to gd controller

=cut
sub render_gd {
    my($c) = @_;
    return(Thruk::Views::GDRenderer::render_gd($c));
}

=head2 authenticate

authenticate a user

=cut
sub authenticate {
    $_[0]->{'user'} = Thruk::Authentication::User->new($_[0]);
    return($_[0]->{'user'});
}

=head2 user_exists

return if a user exists

=cut
sub user_exists {
    return(1) if $_[0]->{'user'};
    return(0);
}

=head2 error

return/set errors

=cut
sub error {
    my($c) = @_;
    return($c->{'errors'}) unless $_[1];
    push @{$c->{'errors'}}, $_[1];
    return;
}

=head2 clear_errors

clear all errors

=cut
sub clear_errors {
    my($c) = @_;
    $c->{'errors'} = [];
    return;
}

=head2 check_user_roles

$c->check_user_roles(<role>)

=cut
sub check_user_roles {
    return(defined $_[0]->{'user'} && $_[0]->{'user'}->check_user_roles($_[1]))
}

=head2 check_permissions

$c->check_permissions(<type>, ...)

=cut
sub check_permissions {
    return(defined $_[0]->{'user'} && $_[0]->{'user'}->check_permissions(@_))
}

=head2 check_cmd_permissions

$c->check_cmd_permissions(<type>, ...)

=cut
sub check_cmd_permissions {
    return(defined $_[0]->{'user'} && $_[0]->{'user'}->check_cmd_permissions(@_))
}

=head2 cache

$c->cache()

=cut
sub cache {
    my $c = shift; return($c->app->cache(@_))
}

=head2 cookie

$c->cookie()

=cut
sub cookie {
    my($c, $name, $value, $options) = @_;
    if($options && defined $options->{'expires'} && $options->{'expires'} <= 0) {
        $options->{'expires'} = "Thu, 01-01-1970 01:00:01 GMT";
    }
    if(defined $value) {
        $c->res->cookies->{$name} = { value => $value, %{$options}};
        return;
    }
    my $cookie = $c->req->cookies->{$name};
    return unless defined $cookie;
    return(Thruk::Request::Cookie->new($cookie));
};

=head2 cookies

$c->cookies()

=cut
sub cookies {
    my($c, $name) = @_;
    my $cookie = $c->req->cookies->{$name};
    return unless defined $cookie;
    my $vars = [split/&/mx, $cookie];
    return(Thruk::Request::Cookie->new($vars));
};

=head2 redirect_to

$c->redirect_to(<url>)

=cut
sub redirect_to {
    my($c, $url) = @_;
    $c->res->content_type('text/html; charset=utf-8');
    $c->res->body('This item has moved');
    $c->res->redirect($url);
    $c->{'rendered'} = 1;
    return($c);
}

=head2 url_with

$c->url_with(<data>)

=cut
sub url_with {
    my($c, $args) = @_;
    return(Thruk::Utils::Filter::uri_with($c, $args));
}

1;
__END__

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
