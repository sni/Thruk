package Thruk::Context;

use warnings;
use strict;
use Carp qw/confess/;
use Cpanel::JSON::XS ();
use Plack::Util ();
use Scalar::Util qw/weaken/;
use Time::HiRes qw/tv_interval gettimeofday/;
use URI::Escape qw/uri_escape uri_unescape/;

use Thruk::Action::AddDefaults ();
use Thruk::Authentication::User ();
use Thruk::Config 'noautoload';
use Thruk::Controller::error ();
use Thruk::Request ();
use Thruk::Stats ();
use Thruk::Utils::APIKeys ();
use Thruk::Utils::CookieAuth ();
use Thruk::Utils::Log qw/:all/;
use Thruk::Views::JSONRenderer ();

use Plack::Util::Accessor qw(app req res stash config user stats obj_db env);

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
        $memory_begin = Thruk::Utils::IO::get_memory_usage();
    }

    # translate paths, translate ex.: /naemon/cgi-bin to /thruk/cgi-bin/
    $env->{'REQUEST_URI_ORIG'} = $env->{'REQUEST_URI'} || $env->{'PATH_INFO'};
    if($env->{'PATH_TRANSLATED'} && $env->{'PATH_TRANSLATED'} =~ m%(/[^/]+/cgi\-bin/error\.cgi)%mx) {
        $env->{'REQUEST_URI'} = $1;
    }
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
        stats  => $Thruk::Globals::c ? $Thruk::Globals::c->stats : Thruk::Stats->new(),
        user   => undef,
        errors => [],
    };
    $self->{'stash'} = Thruk::Config::get_default_stash($self, {
            'time_begin'    => $time_begin,
            'memory_begin'  => $memory_begin,
    });
    bless($self, $class);
    weaken($self->{'app'}) unless Thruk::Base->mode_cli();
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

=head2 db

return db manager

=cut
sub db {
    return($_[0]->{'db'} ||= $_[0]->app->db);
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
        die("prevent further page processing from detach() via ".$filename.":".$line);
    }
    confess("detach: ".$url." at ".$c->req->url);
}


=head2 detach_error

  detach_error($c, $data)

end current request with an error.

$data contains:
{
        msg                 short error message
        descr               long description of the error
        code                http return code, defaults to 500;
        log                 flag wether error should be logged. Error codes > 500 are automatically logged if `log` is undefined
        debug_information   more details which will be logged, (string / array)
        skip_escape         skip escaping html
}

=cut
sub detach_error {
    my($c, $data) = @_;
    $data->{'stacktrace'} .= Carp::longmess("detach_error()") if(!$data->{'stacktrace'} && $c->stash->{'thruk_author'});
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
        die("prevent further page processing from detach_eror() via ".$filename.":".$line);
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
        reverse @{$c->config->{'plugin_templates_paths'}},
        $c->config->{'base_templates_dir'},
    );
    return(Thruk::Base::array_uniq($list));
}

=head2 render

detach to other controller

=cut
sub render {
    my($c, %args) = @_;
    if(defined $args{'json'}) {
        return(Thruk::Views::JSONRenderer::render_json($c, $args{'json'}));
    }
    if(defined $args{'text'}) {
        $c->res->content_type('text/plain; charset=utf-8') unless $c->res->content_type();
        $c->res->body($args{'text'});
        $c->{'rendered'} = 1;
        return;
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
    keep_session   => do not update current session cookie
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
        ($username, $auth_src, $roles, $superuser, $internal, $sessionid, $sessiondata) = _request_username($c, $options{'apikey'});

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
            _debug(sprintf("user account '%s' is locked", $user->{'username'})) if Thruk::Base->verbose;
            $c->error($c->config->{'locked_message'});
            return;
        }
    }
    _set_stash_user($c, $user, $auth_src);
    $c->{'user'}->{'original_username'} = $original_username;
    $user->set_dynamic_attributes($c, $options{'skip_db_access'},$roles);
    _debug(sprintf("authenticated as '%s' - auth src '%s'", $user->{'username'}, $auth_src)) if Thruk::Base->verbose;

    # set session id for all requests
    if(!$sessiondata && !$internal) {
        if(!Thruk::Base->mode_cli()) {
            ($sessionid,$sessiondata) = Thruk::Utils::get_fake_session($c, undef, $username, undef, $c->req->address);
            if(!$options{'keep_session'}) {
                $c->cookie('thruk_auth', $sessionid, { httponly => 1 });
            }
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

returns $username, $auth_src, $roles, $superuser, $internal, $sessionid, $sessiondata

=cut
sub _request_username {
    my($c, $apikey) = @_;

    my($username, $auth_src, $superuser, $internal, $roles, $sessiondata);
    my $env       = $c->env;
    $apikey       = $c->req->header('X-Thruk-Auth-Key') unless defined $apikey;
    my $sessionid = $c->cookies('thruk_auth');
    $sessiondata  = Thruk::Utils::CookieAuth::retrieve_session(config => $c->config, id => $sessionid) if $sessionid;

    # authenticate by secret.key from http header
    if($apikey) {
        my $secret_key = Thruk::Config::secret_key();
        $apikey        = Thruk::Base::trim_whitespace($apikey);
        if($apikey !~ m/^[a-zA-Z0-9_]+$/mx) {
            return $c->detach_error({msg => "wrong authentication key", code => 403, log => 1});
        }
        elsif($secret_key && $apikey eq $secret_key) {
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
            Thruk::Utils::IO::json_lock_store($data->{'file'}.'.stats', { last_used => time(), last_from => $addr }, { pretty => 1 });
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
    # kerberos authentication
    elsif(($env->{'AUTH_TYPE'}//'') eq 'Negotiate' && ($env->{'GSS_NAME'}//'') ne '' ) {
        $username = $env->{'REMOTE_USER'} // $env->{'GSS_NAME'};
        $auth_src = "Negotiate";
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

    elsif(!defined $username && Thruk::Base->mode_cli()) {
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

returns cookie from current request.

sets a cookie for current response if value is defined.

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
        $options->{'path'}     = $c->stash->{'cookie_path'} unless $options->{'path'};
        $options->{'secure'}   = 1 if $c->config->{'cookie_secure_only'} || _is_ssl_request($c);
        $c->res->cookies->{$name} = { value => $value, %{$options}};
        return;
    }
    return($c->cookies($name));
}

=head2 cookies

$c->cookies($name)

returns cookie from current request.

=cut
sub cookies {
    my($c, $name) = @_;
    if(wantarray) {
        my $val  = $c->req->cookies->{$name};
        return unless $val;
        return(split/&/mx, $val);
    }
    return($c->req->cookies->{$name});
}

=head2 redirect_to

$c->redirect_to(<url>)

=cut
sub redirect_to {
    my($c, $url) = @_;

    # do not redirect json post requests, for ex.: from send_form_in_background_and_reload()
    if($c->req->method eq 'POST' && want_json_response($c)) {
        my $data = { 'ok' => 1 };
        $data->{'message'} = $c->stash->{'thruk_message_raw'} if $c->stash->{'thruk_message_raw'};
        return($c->render(json => $data));
    }

    $c->res->content_type('text/html; charset=utf-8');
    $c->res->body('This item has moved to '.Thruk::Utils::Filter::escape_html($url));
    $c->res->redirect($url);
    $c->{'rendered'} = 1;
    if($url =~ m/ARRAY\(/mx) {
        require Data::Dumper;
        confess("invalid redirect url: ".Dumper($url));
    }
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
    } else {
        my $url_prefix = $config->{'url_prefix'} // '/';
        if($url_prefix ne '/') {
            $path_info =~ s|^\Q$url_prefix\E|/thruk/|mx;
        }
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
    local $Thruk::Globals::c = $c unless $Thruk::Globals::c;

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
    _debug2("sub_request to ".$url);
    my $sub_c = Thruk::Context->new($c->app, $env);
    $sub_c->{'user'} = $c->user;
    $sub_c->stash->{'remote_user'} = $c->stash->{'remote_user'};

    $sub_c->req->parameters();
    if($postdata) {
        for my $key (sort keys %{$postdata}) {
            $sub_c->req->body_parameters->{$key} = $postdata->{$key};
            $sub_c->req->parameters->{$key}      = $postdata->{$key};
        }
    }

    Thruk::Action::AddDefaults::begin($sub_c);
    my $path_info = $sub_c->req->path_info;

    my($route, $routename) = $c->app->find_route_match($c, $path_info);
    confess("no route") unless $route;
    $sub_c->{'rendered'} = 1 unless $rendered; # prevent json encoding, we want the data reference
    $c->stats->profile(begin => $routename);
    my $rc = &{$route}($sub_c, $path_info);
    $c->stats->profile(end => $routename);
    Thruk::Action::AddDefaults::end($sub_c);

    local $Thruk::Globals::c = undef;
    if(!$sub_c->{'rendered'}) {
        require Thruk::Views::ToolkitRenderer;
        Thruk::Views::ToolkitRenderer::render_tt($sub_c);
    }
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
    if($c->env->{'REQUEST_URI_ORIG'} && $c->env->{'REQUEST_URI_ORIG'} =~ m%^(/[^/]+|)/thruk/r/%mx) {
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

=head2 log

$c->log->...

compat wrapper for accessing logger

=cut
sub log {
    return(Thruk::Utils::Log::log());
}

###################################################

=head2 get_cookie_domain

$c->get_cookie_domain

return domain used for cookies

=cut
sub get_cookie_domain {
    my($c) = @_;
    my $domain = $c->config->{'cookie_auth_domain'};
    return "" unless $domain;
    my $http_host = $c->req->env->{'HTTP_HOST'};
    # remove port
    $http_host =~ s/:\d+$//gmx;
    $domain =~ s/\.$//gmx;
    if($http_host !~ m/\Q$domain\E$/mx) {
        return($http_host);
    }
    return $domain;
}

###################################################

=head2 finalize_request

    register_cron_entries($c, $res)

finalize request data by adding profile and headers

=cut
sub finalize_request {
    my($c, $res) = @_;
    $c->stats->profile(begin => "finalize_request");

    if($c->stash->{'extra_headers'}) {
        push @{$res->[1]}, @{$c->stash->{'extra_headers'}};
    }

    # restore timezone setting
    Thruk::Utils::Timezone::set_timezone($c->config, $c->config->{'_server_timezone'});

    if($ENV{THRUK_LEAK_CHECK}) {
        eval {
            require Devel::Cycle;
            $Devel::Cycle::FORMATTING = "cooked";
        };
        print STDERR $@ if $@ && Thruk::Base->debug;
        unless($@) {
            my $counter = 0;
            $Devel::Cycle::already_warned{'GLOB'}++;
            Devel::Cycle::find_cycle($c, sub {
                my($path) = @_;
                $counter++;
                _error("found leaks:") if $counter == 1;
                _error("Cycle ($counter):");
                foreach (@{$path}) {
                    my($type,$index,$ref,$value,$is_weak) = @{$_};
                    _error(sprintf "\t%30s => %-30s\n",($is_weak ? 'w-> ' : '').Devel::Cycle::_format_reference($type,$index,$ref,0),Devel::Cycle::_format_reference(undef,undef,$value,1));
                }
            });
        }
    }

    my $elapsed = tv_interval($c->stash->{'time_begin'});
    $c->stats->profile(end => "finalize_request");
    $c->set_stats_common_totals();
    $c->stash->{'time_total'} = $elapsed;

    my $h = Plack::Util::headers($res->[1]);
    my($url) = ($c->req->url =~ m#.*?/thruk/(.*)#mxo);
    if($ENV{'THRUK_PERFORMANCE_DEBUG'} && $c->stash->{'inject_stats'} && !$ENV{'THRUK_PERFORMANCE_COLLECT_ONLY'}) {

        my $save_for_later = 0;
        my $inject         = 0;
        if($res->[0] == 302 && $c->{'session'} && $c->{'session'}->{'file'}) {
            $save_for_later = 1;
        }
        if(!$save_for_later && ref $res->[2] eq 'ARRAY' && $res->[2]->[0] =~ m/<\/body>/mx) {
            $inject = 1;
        }

        if($inject) {
            # add previously saved profiles
            if($c->{'session'} && $c->{'session'}->{'page_profiles'}) {
                $c->add_profile($c->{'session'}->{'page_profiles'});
                Thruk::Utils::IO::json_lock_patch($c->{'session'}->{'file'}, { page_profiles => undef });
            }
        }
        if($inject || $save_for_later) {
            # inject current page stats into html
            $c->add_profile({name => 'Req '.$Thruk::Globals::COUNT, html => $c->stats->report_html(), text => $c->stats->report()});
            if($Thruk::Globals::tt_profiling) {
                require Thruk::Template::Context;
                $c->add_profile(Thruk::Template::Context::get_profiles());
            }
        }

        if($inject) {
            my $stats = "";
            require Thruk::Views::ToolkitRenderer;
            Thruk::Views::ToolkitRenderer::render($c, "_internal_stats.tt", $c->stash, \$stats);
            Thruk::Template::Context::reset_profiles() if $Thruk::Globals::tt_profiling;
            $res->[2]->[0] =~ s/<\/body>/$stats<\/body>/gmx;
            $h->remove("Content-Length");
        } elsif($save_for_later) {
            # redirected page, save stats for next page to show
            $c->{'session'}->{'page_profiles'} = [] unless $c->{'session'}->{'page_profiles'};
            push @{$c->{'session'}->{'page_profiles'}}, @{$c->stash->{'page_profiles'}};
            Thruk::Utils::IO::json_lock_patch($c->{'session'}->{'file'}, { page_profiles => $c->{'session'}->{'page_profiles'} });
        }
    }
    # slow pages log
    if($ENV{'THRUK_PERFORMANCE_DEBUG'} && $c->config->{'slow_page_log_threshold'} > 0 && $elapsed > $c->config->{'slow_page_log_threshold'}) {
        _warn("***************************");
        _warn(sprintf("slow_page_log_threshold (%ds) hit, page took %.1fs to load.", $c->config->{'slow_page_log_threshold'}, $elapsed));
        _warn(sprintf("page:    %s\n", $c->req->url)) if defined $c->req->url;
        _warn(sprintf("params:  %s\n", Thruk::Utils::dump_params($c->req->parameters))) if($c->req->parameters and scalar keys %{$c->req->parameters} > 0);
        _warn(sprintf("user:    %s\n", ($c->stash->{'remote_user'} // 'not logged in')));
        _warn(sprintf("address: %s%s\n", $c->req->address, ($c->env->{'HTTP_X_FORWARDED_FOR'} ? ' ('.$c->env->{'HTTP_X_FORWARDED_FOR'}.')' : '')));
        _warn($c->stash->{errorDetails}) if $c->stash->{errorDetails}; # might contain hints about the current dashboard
        _warn($c->stats->report());
    }

    my $content_length;
    if (!Plack::Util::status_with_no_entity_body($res->[0]) &&
        !$h->exists('Content-Length') &&
        !$h->exists('Transfer-Encoding') &&
        defined($content_length = Plack::Util::content_length($res->[2])))
    {
        $h->push('Content-Length' => $content_length);
    }
    $h->push('Cache-Control', 'no-store');
    $h->push('Expires', '0');

    # last possible time to report/save profile
    if($ENV{'THRUK_JOB_DIR'}) {
        require Thruk::Utils::External;
        Thruk::Utils::External::save_profile($c, $ENV{'THRUK_JOB_DIR'});
    }

    if($ENV{'THRUK_PERFORMANCE_DEBUG'} && $c->stash->{'memory_begin'} && !$ENV{'THRUK_PERFORMANCE_COLLECT_ONLY'}) {
        $c->stash->{'memory_end'} = Thruk::Utils::IO::get_memory_usage();
        $url     = $c->req->url unless $url;
        $url     =~ s|^https?://[^/]+/|/|mxo;
        $url     =~ s/^cgi\-bin\///mxo;
        if(length($url) > 80) { $url = substr($url, 0, 80).'...' }
        if(!$url) { $url = $c->req->url; }
        my $waited = [];
        push @{$waited}, $c->stash->{'total_backend_waited'} ? sprintf("M:%.3fs", $c->stash->{'total_backend_waited'}) : '-';
        push @{$waited}, $c->stash->{'total_render_waited'} ? sprintf("V:%.3fs", $c->stash->{'total_render_waited'}) : '-';
        _info(sprintf("[%s] pid: %5d req: %03d   mem:%7s MB %6s MB   dur:%6ss %16s   size:% 12s   stat: %d   url: %s",
                                Thruk::Utils::format_date(Time::HiRes::time(), "%H:%M:%S.%MILLI"),
                                $$,
                                $Thruk::Globals::COUNT,
                                $c->stash->{'memory_end'},
                                sprintf("%.2f", ($c->stash->{'memory_end'}-$c->stash->{'memory_begin'})),
                                sprintf("%.3f", $elapsed),
                                '('.join('/', @{$waited}).')',
                                defined $content_length ? sprintf("%.3f kb", $content_length/1024) : '----',
                                $res->[0],
                                $url,
                    ));
    }
    _debug($c->stats->report()) if Thruk::Base->debug;
    $c->stats->clear() unless $ENV{'THRUK_KEEP_CONTEXT'};

    # save metrics to disk
    $c->app->{_metrics}->store() if $c->app->{_metrics};

    # show deprecations
    if($Thruk::Globals::deprecations_log) {
        if(Thruk::Base->mode() ne 'TEST' && Thruk::Base->mode() ne 'CLI') {
            for my $warning (@{$Thruk::Globals::deprecations_log}) {
                _info($warning);
            }
        }
        undef $Thruk::Globals::deprecations_log;
    }

    # does this process need a restart?
    if(Thruk::Base->mode() eq 'FASTCGI') {
        if($c->config->{'max_process_memory'}) {
            Thruk::Utils::check_memory_usage($c);
        }
    }

    return;
}

###################################################

=head2 set_stats_common_totals

$c->set_stats_common_totals

adds common statistics

=cut
sub set_stats_common_totals {
    my($c) = @_;
    $c->stats->totals(
        { '*total time waited on backends'  => $c->stash->{'total_backend_waited'} },
        { '*total time waited on rendering' => $c->stash->{'total_render_waited'}  },
    );
    return;
}

###################################################

=head2 add_profile

$c->add_profile({ name => ..., [ text => \@txtprofiles ], [ html => \@htmlprofiles ] })

add profile to stash

=cut
sub add_profile {
    my($c, $options) = @_;
    if(ref $options eq 'HASH') {
        confes("no name in profile") unless $options->{'name'};
        return if $options->{'name'} eq 'TT get_variable.tt';
        $options->{'time'} = Time::HiRes::time() unless $options->{'time'};
        push @{$c->stash->{'page_profiles'}}, $options;

        # clean up if more than 10
        while(scalar @{$c->stash->{'page_profiles'}} > 10) {
            shift @{$c->stash->{'page_profiles'}};
        }
        return;
    }
    if(ref $options eq 'ARRAY') {
        for my $p (@{$options}) {
            $c->add_profile($p);
        }
        return;
    }
    confess("either add arrays or hashes to profiles");
}

###################################################
# returns true if request is using ssl/tls
sub _is_ssl_request {
    my($c) = @_;

    # plack url scheme
    if($c->env->{'psgi.url_scheme'} && lc($c->env->{'psgi.url_scheme'}) eq 'https') {
        return(1);
    }

    if($c->env->{'HTTP_ORIGIN'} && $c->env->{'HTTP_ORIGIN'} =~ m/^https/mx) {
        return(1);
    }

    # X-Forwarded-Proto header
    my $forward_proto = $c->req->header('X-Forwarded-Proto');
    if($forward_proto && lc($forward_proto) eq 'https') {
        return(1);
    }

    return;
}

###################################################

1;
