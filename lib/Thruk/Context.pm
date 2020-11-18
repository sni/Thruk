package Thruk::Context;

use warnings;
use strict;
use Carp qw/confess/;
use Plack::Util::Accessor qw(app db req res stash config user stats obj_db env);
use Scalar::Util qw/weaken/;
use Time::HiRes qw/gettimeofday/;
use Module::Load qw/load/;
use URI::Escape qw/uri_escape uri_unescape/;
use File::Slurp qw/read_file/;

use Thruk::Authentication::User;
use Thruk::Controller::error;
use Thruk::Request;
use Thruk::Request::Cookie;
use Thruk::Stats;
use Thruk::Utils;
use Thruk::Utils::IO;
use Thruk::Utils::CookieAuth;
use Thruk::Utils::APIKeys;
use Thruk::Utils::Log qw/:all/;

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

    my $time_begin  = [gettimeofday()];
    my $config = $app->config || confess("uninitialized, no app config");
    my $memory_begin;
    if($ENV{'THRUK_PERFORMANCE_DEBUG'}) {
        $memory_begin = Thruk::Backend::Pool::get_memory_usage();
    }

    # translate paths, translate ex.: /naemon/cgi-bin to /thruk/cgi-bin/
    $env->{'REQUEST_URI_ORIG'} = $env->{'REQUEST_URI'} || $env->{'PATH_INFO'};
    my $path_info         = translate_request_path($env->{'REQUEST_URI'} || $env->{'PATH_INFO'}, $config, $env);
    $env->{'PATH_INFO'}   = $path_info;
    $env->{'REQUEST_URI'} = $path_info;

    # extract non-url encoded q= param from raw body parameters
    if($env->{'QUERY_STRING'} && $env->{'QUERY_STRING'} =~ m/(^|\&)q=(.{3})/mx) {
        my $separator = $2;
        if(substr($separator,0,1) eq substr($separator,1,1) && substr($separator,0,1) eq substr($separator,2,1)) {
            $env->{'QUERY_STRING'} =~ s/\Q$separator\E(.*?)\Q$separator\E/&_url_encode($1)/gemx;
        }
    }
    my $req = Thruk::Request->new($env);
    my $self = {
        app    => $app,
        env    => $env,
        config => $config,
        req    => $req,
        res    => $req->new_response(200),
        stats  => $Thruk::Request::c ? $Thruk::Request::c->stats : Thruk::Stats->new(),
        user   => undef,
        errors => [],
    };
    $self->{'stash'} = Thruk::Config::get_default_stash($self, {
            'time_begin'    => $time_begin,
            'memory_begin'  => $memory_begin,
    });
    bless($self, $class);
    weaken($self->{'app'}) unless Thruk->mode eq 'CLI';
    $self->stats->enable();

    # extract non-url encoded q= param from raw body parameters
    $self->req->parameters();
    my $raw_body = $self->req->raw_body;
    if($raw_body && $raw_body =~ m/(^|\?|\&)q=(.{3})/mx) {
        my $separator = $2;
        if(substr($separator,0,1) eq substr($separator,1,1) && substr($separator,0,1) eq substr($separator,2,1)) {
            if($raw_body =~ m/\Q$separator\E(.*?)\Q$separator\E/gmx) {
                $self->req->body_parameters->{'q'} = $1;
                $self->req->parameters->{'q'} = $1;
            }
        }
    }

    # parse json body parameters
    if(ref $raw_body eq '' && $raw_body =~ m/^\{.*\}$/mxs) {
        if($self->req->content_type && $self->req->content_type =~ m%^application/json%mx) {
            my $data;
            my $json = Cpanel::JSON::XS->new->utf8;
            $json->relaxed();
            eval {
                $data = $json->decode($raw_body);
            };
            if($@) {
                confess("failed to parse json data argument: ".$@);
            }
            for my $key (sort keys %{$data}) {
                $self->req->body_parameters->{$key} = $data->{$key};
                $self->req->parameters->{$key} = $data->{$key};
            }
        }
    }

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

=head2 cluster

return cluster object

=cut
sub cluster {
    return($_[0]->app->cluster);
}

=head2 metrics

return metrics object

=cut
sub metrics {
    return($_[0]->app->metrics());
}

=head2 detach

detach to other controller

=cut
sub detach {
    my($c, $url) = @_;
    my($package, $filename, $line) = caller;
    $c->stats->profile(comment => 'detached to '.$url.' from '.$package.':'.$line);
    _debug2("detach to ".$url);
    # errored flag is set in error controller to avoid recursion if error controller
    # itself throws an error, just bail out in that case
    if(!$c->{'errored'} && $url =~ m|/error/index/(\d+)$|mx) {
        Thruk::Controller::error::index($c, $1);
        $c->{'detached'} = 1;
        die("prevent further page processing");
    }
    confess("detach: ".$url." at ".$c->req->url);
}

=head2 detach_error

detach_error to other controller

=cut
sub detach_error {
    my($c, $data) = @_;
    $c->stash->{'error_data'} = $data;
    my($package, $filename, $line) = caller;
    $c->stats->profile(comment => 'detach_eror from '.$package.':'.$line);
    _debug2("detach_error:");
    _debug2($data);
    # errored flag is set in error controller to avoid recursion if error controller
    # itself throws an error, just bail out in that case
    if(!$c->{'errored'}) {
        Thruk::Controller::error::index($c, 99);
        $c->{'detached'} = 1;
        die("prevent further page processing");
    }
    confess("detach_error at ".$c->req->url);
}

=head2 get_tt_template_paths

return list of template include paths

=cut
sub get_tt_template_paths {
    my($c) = @_;
    my $list = [];
    if($c->config->{'user_template_path'}) {
        push @{$list}, $c->config->{'user_template_path'};
    }
    push(@{$list},
          $c->config->{'themes_path'}.'/themes-enabled/'.$c->stash->{'theme'}.'/templates',
        @{$c->config->{'plugin_templates_paths'}},
          $c->config->{'base_templates_dir'},
    );
    return(Thruk::Utils::array_uniq($list));
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
    require Thruk::Views::ExcelRenderer;
    return(Thruk::Views::ExcelRenderer::render_excel($c));
}

=head2 render_gd

detach to gd controller

=cut
sub render_gd {
    my($c) = @_;
    require Thruk::Views::GDRenderer;
    return(Thruk::Views::GDRenderer::render_gd($c));
}

=head2 authenticate

  $c->authenticate(%options)

authenticate current request user

options are: {
    username       => force this username
    skip_db_access => do not access the livestatus to fetch roles
    apikey         => use api key to authenticate
    superuser      => flag wether this user should be a superuser
    internal       => flag wether this user is an internal technical user
    roles          => limit roles to this set
}

=cut
sub authenticate {
    my($c, %options) = @_;
    _debug2("checking authenticaton");
    confess("authenticate called multiple times, use change_user instead.") if $c->user_exists;
    delete $c->stash->{'remote_user'};
    delete $c->{'user'};
    delete $c->{'session'};
    my $username  = $options{'username'};
    my $superuser = $options{'superuser'};
    my $internal  = $options{'internal'};
    my $auth_src  = $options{'auth_src'};
    my($original_username, $roles);
    my($sessionid, $sessiondata);
    if(defined $username) {
        confess("auth_src required") unless defined $auth_src;
        $original_username = $username;
        $roles = $options{'roles'};
    } else {
        if($c->app->{'TRANSFER_USER'}) {
            # internal request setting $c->app->{'TRANSFER_USER'} to $c->user
            my $user = delete $c->app->{'TRANSFER_USER'};
            _set_stash_user($c, $user, $auth_src);
            return($user);
        }
        ($username, $auth_src, $roles, $superuser,$internal, $sessionid, $sessiondata) = _request_username($c, $options{'apikey'});

        # transform username upper/lower case?
        $original_username = $username;
        $username = Thruk::Authentication::User::transform_username($c->config, $username, $c);
    }
    return unless $username;
    if($sessionid) {
        $sessiondata = undef if(!$sessiondata || $sessiondata->{'username'} ne $username);
        $sessiondata->{'private_key'} = $sessionid if $sessiondata;
    }
    my $user = Thruk::Authentication::User->new($c, $username, $sessiondata, $superuser, $internal);
    return unless $user;
    if(!$internal) {
        if($user->{'settings'}->{'login'} && $user->{'settings'}->{'login'}->{'locked'}) {
            _debug(sprintf("user account '%s' is locked", $user->{'username'})) if Thruk->verbose;
            $c->error("account is locked, please contact an administrator");
            return;
        }
    }
    _set_stash_user($c, $user, $auth_src);
    $c->{'user'}->{'original_username'} = $original_username;
    $user->set_dynamic_attributes($c, $options{'skip_db_access'},$roles);
    _debug(sprintf("authenticated as '%s' - auth src '%s'", $user->{'username'}, $auth_src)) if Thruk->verbose;

    # set session id for all requests
    if(!$sessiondata && !$internal) {
        if(Thruk->mode ne 'CLI') {
            ($sessionid,$sessiondata) = Thruk::Utils::get_fake_session($c, undef, $username, undef, $c->req->address);
            $c->res->cookies->{'thruk_auth'} = {value => $sessionid, path => $c->stash->{'cookie_path'}, httponly => 1 };
        }
    }
    if($sessiondata) {
        my $now = time();
        utime($now, $now, $sessiondata->{'file'});
        $c->{'session'} = $sessiondata;
    }

    # save current roles in session file so it can be used from external tools
    if(!$internal && $sessiondata && !$sessiondata->{'current_roles'}) {
        $sessiondata->{'current_roles'} = $c->{'user'}->{'roles'} || [];
        my $data = Thruk::Utils::IO::json_lock_patch($sessiondata->{'file'}, { current_roles => $sessiondata->{'current_roles'} });
    }
    return($user);
}

sub _set_stash_user {
    my($c, $user, $auth_src) = @_;
    $c->{'user'} = $user;
    $c->{'user'}->{'auth_src'} = $auth_src;
    $c->stash->{'remote_user'} = $user->{'username'};
    $c->stash->{'user_data'}   = $user->{'settings'};
    return;
}

=head2 _request_username

get username from env

returns $username, $src, $original_username, $roles, $superuser, $internal

=cut
sub _request_username {
    my($c, $apikey) = @_;

    my($username, $auth_src, $superuser, $internal, $roles, $sessiondata);
    my $env       = $c->env;
    $apikey       = $c->req->header('X-Thruk-Auth-Key') unless defined $apikey;
    my $sessionid = $c->req->cookies->{'thruk_auth'};
    $sessiondata  = Thruk::Utils::CookieAuth::retrieve_session(config => $c->config, id => $sessionid) if $sessionid;

    # authenticate by secret.key from http header
    if($apikey) {
        # ensure secret key is fresh
        my $secret_file = $c->config->{'var_path'}.'/secret.key';
        $c->config->{'secret_key'} = read_file($secret_file) if -s $secret_file;
        chomp($c->config->{'secret_key'});
        $apikey =~ s/^\s+//mx;
        $apikey =~ s/\s+$//mx;
        if($apikey !~ m/^[a-zA-Z0-9_]+$/mx) {
            return $c->detach_error({msg => "wrong authentication key", code => 403, log => 1});
        }
        elsif($apikey eq $c->config->{'secret_key'} && $c->config->{'secret_key'} ne '') {
            $username = $c->req->header('X-Thruk-Auth-User') || $c->config->{'default_user_name'};
            if(!$username) {
                $username  = '(api)';
                $internal  = 1;
            }
            $auth_src  = "secret_key";
            $superuser = 1;
        }
        elsif($c->config->{'api_keys_enabled'}) {
            my $data = Thruk::Utils::APIKeys::get_key_by_private_key($c->config, $apikey);
            if(!$data) {
                return $c->detach_error({msg => "wrong authentication key", code => 403, log => 1});
            }
            my $addr = $c->req->address;
            $addr   .= " (".$c->env->{'HTTP_X_FORWARDED_FOR'}.")" if($c->env->{'HTTP_X_FORWARDED_FOR'} && $addr ne $c->env->{'HTTP_X_FORWARDED_FOR'});
            Thruk::Utils::IO::json_lock_patch($data->{'file'}, { last_used => time(), last_from => $addr }, { pretty => 1 });
            $username = $data->{'user'};
            if($data->{'superuser'}) {
                $superuser = 1;
                $username  = $c->req->header('X-Thruk-Auth-User') || $c->config->{'default_user_name'};
                if(!$username) {
                    $username  = '(api)';
                    $internal  = 1;
                }
            }
            $roles    = $data->{'roles'};
            $auth_src = "api_key";
        } else {
            return $c->detach_error({msg => "wrong authentication key", code => 403, log => 1});
        }
    }
    elsif($sessiondata) {
        $username = $sessiondata->{'username'};
        $auth_src = "cookie";
        $roles    = $sessiondata->{'roles'} if($sessiondata->{'roles'} && scalar @{$sessiondata->{'roles'}} > 0);
    }
    elsif(defined $c->config->{'use_ssl_authentication'} and $c->config->{'use_ssl_authentication'} >= 1 and defined $env->{'SSL_CLIENT_S_DN_CN'}) {
        $username = $env->{'SSL_CLIENT_S_DN_CN'};
        $auth_src = "ssl_authentication";
    }
    # basic authentication
    elsif(defined $env->{'REMOTE_USER'} && $env->{'REMOTE_USER'} ne '' ) {
        $username = $env->{'REMOTE_USER'};
        $auth_src = "basic auth";
    }
    elsif(defined $ENV{'REMOTE_USER'} && $ENV{'REMOTE_USER'} ne '' ) {
        $username = $ENV{'REMOTE_USER'};
        $auth_src = "basic auth";
    }

    # default_user_name?
    if(!defined $username && defined $c->config->{'default_user_name'}) {
        $username = $c->config->{'default_user_name'};
        $auth_src = "default_user_name";
    }

    elsif(!defined $username && Thruk->mode eq 'CLI') {
        $username = $c->config->{'default_cli_user_name'};
        $auth_src = "cli";
    }

    if(!defined $username || $username eq '') {
        return;
    }

    return($username, $auth_src, $roles, $superuser, $internal, $sessionid, $sessiondata);
}

=head2 user_exists

return if a user exists

=cut
sub user_exists {
    my($c) = @_;
    return(1) if defined $c->{'user'};
    return(0);
}

=head2 error

return/set errors

=cut
sub error {
    my($c, $error) = @_;
    return($c->{'errors'}) unless $error;
    push @{$c->{'errors'}}, $error;
    _debug($error);
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
    return(defined $_[0]->{'user'} && $_[0]->{'user'}->check_user_roles($_[1]));
}

=head2 check_permissions

$c->check_permissions(<type>, ...)

=cut
sub check_permissions {
    return(defined $_[0]->{'user'} && $_[0]->{'user'}->check_permissions(@_));
}

=head2 check_cmd_permissions

$c->check_cmd_permissions(<type>, ...)

=cut
sub check_cmd_permissions {
    return(defined $_[0]->{'user'} && $_[0]->{'user'}->check_cmd_permissions(@_));
}

=head2 cache

$c->cache()

=cut
sub cache {
    my $c = shift; return($c->app->cache(@_));
}

=head2 cookie

$c->cookie($name, [$value], [$options])

retrieves a cookie_path

sets a cookie if value is defined

options are available as descrbed here: L<Plack::Response/cookies>

basically: domain, expires, path, httponly, secure, max-age

=cut
sub cookie {
    my($c, $name, $value, $options) = @_;
    if($options && defined $options->{'expires'} && $options->{'expires'} <= 0) {
        $options->{'expires'} = "Thu, 01-01-1970 01:00:01 GMT";
    }
    if(defined $value) {
        $options->{'samesite'} = 'lax' unless $options->{'samesite'};
        $c->res->cookies->{$name} = { value => $value, %{$options}};
        return;
    }
    my $cookie = $c->req->cookies->{$name};
    return unless defined $cookie;
    return(Thruk::Request::Cookie->new($cookie));
}

=head2 cookies

$c->cookies()

=cut
sub cookies {
    my($c, $name) = @_;
    my $cookie = $c->req->cookies->{$name};
    return unless defined $cookie;
    my $vars = [split/&/mx, $cookie];
    return(Thruk::Request::Cookie->new($vars));
}

=head2 redirect_to

$c->redirect_to(<url>)

=cut
sub redirect_to {
    my($c, $url) = @_;
    $c->res->content_type('text/html; charset=utf-8');
    $c->res->body('This item has moved to '.Thruk::Utils::Filter::escape_html($url));
    $c->res->redirect($url);
    $c->{'rendered'} = 1;
    $c->stash->{'last_redirect_to'} = $url;
    return(1);
}

=head2 redirect_to_detached

$c->redirect_to_detached(<url>)

=cut
sub redirect_to_detached {
    my($c, @args) = @_;
    $c->redirect_to(@args);
    $c->{'detached'} = 1;
    die("prevent further page processing, redirecting to ".($args[0] // 'unknown'));
}

=head2 url_with

$c->url_with(<data>)

=cut
sub url_with {
    my($c, $args) = @_;
    return(Thruk::Utils::Filter::uri_with($c, $args));
}

=head2 translate_request_path

    translate_request_path(<path_info>, $config, $env)

translate paths, /naemon/cgi-bin to /thruk/cgi-bin/
or /<omd-site/thruk/cgi-bin/... to /thruk/cgi-bin/...
so later functions can use /thruk/... for everything,
regardless of the deployment path.

=cut
sub translate_request_path {
    my($path_info, $config, $env) = @_;

    # strip off get parameter
    $path_info =~ s/\?.*$//gmx;

    if($path_info =~ m%^/?$%mx && $env->{'SCRIPT_NAME'} && $env->{'SCRIPT_NAME'} =~ m%/thruk/cgi\-bin/remote\.cgi(/r/.*)$%mx) {
        $path_info = '/thruk'.$1;
    }
    my $product_prefix = $config->{'product_prefix'};
    if($ENV{'OMD_SITE'}) {
        $path_info =~ s|^/\Q$ENV{'OMD_SITE'}\E/|/|mx;
    }
    if($product_prefix ne 'thruk') {
        $path_info =~ s|^/\Q$product_prefix\E|/thruk|mx;
    }
    if($ENV{'OMD_SITE'} and $ENV{'OMD_SITE'} eq 'thruk') {
        $path_info =~ s|^\Q/cgi-bin/\E|/thruk/cgi-bin/|mx;
    }
    return($path_info);
}

=head2 has_route

$c->has_route(<url>)

=cut
sub has_route {
    my($c, $url) = @_;
    return(defined $c->app->{'routes'}->{$url});
}

=head2 sub_request

$c->sub_request(<url>, [<method>], [<postdata>], [<rendered>])

=cut
sub sub_request {
    my($c, $url, $method, $postdata, $rendered) = @_;
    $method = 'GET' unless $method;
    $method = uc($method);
    my $orig_url = $url;
    $c->stats->profile(begin => "sub_request: ".$method." ".$orig_url);
    local $Thruk::Request::c = $c unless $Thruk::Request::c;

    $url = '/thruk'.$url;
    my $query;
    ($url, $query) = split(/\?/mx, $url, 2);
    my $env = {
        'PATH_INFO'           => $url,
        'REQUEST_METHOD'      => $method,
        'REQUEST_URI'         => $url,
        'SCRIPT_NAME'         => '',
        'QUERY_STRING'        => $query,

        'REMOTE_ADDR'         => $c->env->{'REMOTE_ADDR'},
        'REMOTE_HOST'         => $c->env->{'REMOTE_HOST'},
        'SERVER_PROTOCOL'     => $c->env->{'SERVER_PROTOCOL'},
        'SERVER_PORT'         => $c->env->{'SERVER_PORT'},
        'REMOTE_USER'         => $c->env->{'REMOTE_USER'},
        'plack.cookie.parsed' => $c->env->{'plack.cookie.parsed'},
        'plack.cookie.string' => $c->env->{'plack.cookie.string'},
    };
    $env->{'plack.request.body_parameters'} = [%{$postdata}] if $postdata;
    _debug2("sub_request to ".$url);
    my $sub_c = Thruk::Context->new($c->app, $env);
    $sub_c->{'user'} = $c->user;
    $sub_c->stash->{'remote_user'} = $c->stash->{'remote_user'};

    Thruk::Action::AddDefaults::begin($sub_c);
    my $path_info = $sub_c->req->path_info;

    my($route, $routename) = $c->app->find_route_match($c, $path_info);
    confess("no route") unless $route;
    $sub_c->{'rendered'} = 1 unless $rendered; # prevent json encoding, we want the data reference
    $c->stats->profile(begin => $routename);
    my $rc = &{$route}($sub_c, $path_info);
    $c->stats->profile(end => $routename);
    Thruk::Action::AddDefaults::end($sub_c);

    local $Thruk::Request::c = undef;
    Thruk::Views::ToolkitRenderer::render_tt($sub_c) unless $sub_c->{'rendered'};
    $c->stats->profile(end => "sub_request: ".$method." ".$orig_url);
    return $sub_c if $rendered;
    return $rc;
}

sub _url_encode {
    my($str) = @_;
    return(uri_escape(uri_unescape($str)));
}


=head2 want_json_response

$c->want_json_response()

returns true if request indicates a json response.

=cut
sub want_json_response {
    my($c) = @_;
    if($c->req->header('accept') && $c->req->header('accept') =~ m/application\/json/mx) {
        return 1;
    }
    if($c->req->path_info =~ m%^/thruk/r/%mx) {
        return 1;
    }
    if($c->req->parameters->{'view_mode'} && $c->req->parameters->{'view_mode'} eq 'json') {
        return 1;
    }
    if($c->req->parameters->{'json'}) {
        return 1;
    }
    return;
}

=head2 clone_user_config

$c->clone_user_config()

replace $c->config with a deepcopy of it

=cut
sub clone_user_config {
    my($c) = @_;
    $c->{'config'} = Thruk::Utils::dclone($c->{'config'});
    $c->{'config'}->{'cloned'} = 1;
    return;
}

1;
