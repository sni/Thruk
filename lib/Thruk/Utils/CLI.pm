package Thruk::Utils::CLI;

=head1 NAME

Thruk::Utils::CLI - Utilities Collection for CLI Tool

=head1 DESCRIPTION

Utilities Collection for CLI scripting with Thruk. Allows you to access internal
structures and change config information.

=cut

use warnings;
use strict;
use Carp;
use Data::Dumper qw/Dumper/;
use Cpanel::JSON::XS qw/encode_json decode_json/;
use File::Slurp qw/read_file/;
use Encode qw(encode_utf8);
use Time::HiRes qw/gettimeofday tv_interval/;
use HTTP::Request 6.12 ();
use Module::Load qw/load/;

use Thruk ();
use Thruk::Config ();
use Thruk::Utils ();
use Thruk::Utils::Log qw/:all/;
use Thruk::Utils::IO ();
use Thruk::UserAgent ();

##############################################

=head1 METHODS

=head2 new

    new([ $options ])

 $options = {
    verbose => 0-4, # be more verbose
 }

create CLI tool object

=cut
sub new {
    my($class, $options) = @_;
    my $self  = {
        'opt' => $options,
    };
    bless $self, $class;

    # cleanup options
    for my $key (keys %{$self->{'opt'}}) {
        delete $self->{'opt'}->{$key} unless defined $self->{'opt'}->{$key};
    }

    # backends can be comma separated
    if($options->{'backends'}) {
        my @backends;
        for my $b (@{$options->{'backends'}}) {
            push @backends, split(/\s*,\s*/mx, $b);
        }
        $options->{'backends'} = \@backends;
    }

    # set some env defaults
    ## no critic
    $ENV{'THRUK_MODE'}       = 'CLI';
    $ENV{'NO_EXTERNAL_JOBS'} = 1;
    $ENV{'REMOTE_USER'}      = $options->{'auth'} if defined $options->{'auth'};
    $ENV{'THRUK_BACKENDS'}   = join(';', @{$options->{'backends'}}) if(defined $options->{'backends'} and scalar @{$options->{'backends'}} > 0);
    $ENV{'THRUK_VERBOSE'}    = $ENV{'THRUK_VERBOSE'} // $options->{'verbose'} // 0;
    $ENV{'THRUK_QUIET'}      = 1 if $options->{'quiet'};
    $ENV{'THRUK_VERBOSE'}    = 0 if$ENV{'THRUK_QUIET'};
    ## use critic

    if($options->{'verbose'} && $options->{'quiet'}) {
        _fatal("The quiet and verbose options are mutually exclusive. Choose one of them.");
    }

    return $self;
}

##############################################

=head2 get_c

    get_c()

return L<Thruk::Context> context object

=cut
sub get_c {
    my($self) = @_;
    return $Thruk::Request::c if defined $Thruk::Request::c;
    my($c, undef, undef) = _dummy_c();
    confess("internal request failed") unless $c;
    $c->stats->enable(1);
    return $c;
}

##############################################

=head1 BACKEND CONNECTION POOL

The Backend Connection Pool can be uses for own querys against
all connected backends in Thruk.

=head2 get_db

    get_db()

Return connection pool as a L<Thruk::Backend::Manager|Thruk::Backend::Manager> object.

=cut
sub get_db {
    my($self) = @_;
    my $c = $self->get_c();
    return $c->{'db'};
}

##############################################

=head1 CONFIG TOOL - OBJECT CONFIGURATION

These methods will only be available if you have the config tool plugin enabled
and if you set core config items to access the core objects config.

=head2 get_object_db

    get_object_db()

Return config database as a L<Monitoring::Config|Monitoring::Config> object.

=cut
sub get_object_db {
    my($self) = @_;
    my $c = $self->get_c();
    die("Config tool not enabled!") unless $c->config->{'use_feature_configtool'} == 1;
    require Thruk::Utils::Conf;
    Thruk::Utils::Conf::set_object_model($c) or die("Failed to set objects model. Object configuration enabled?");
    return $c->{'obj_db'};
}

##############################################

=head2 store_objects

    store_objects()

Store changed objects. Changes will be stashed into Thruks internal object cache
and can then be saved, reviewed or discarded.

=cut
sub store_objects {
    my($self) = @_;
    my $c = $self->get_c();
    die("config tool not enabled") unless $c->config->{'use_feature_configtool'} == 1;
    $c->{'obj_db'}->{'needs_commit'} = 1;
    $c->{'obj_db'}->{'last_changed'} = time();
    require Thruk::Utils::Conf;
    Thruk::Utils::Conf::store_model_retention($c, $c->stash->{'param_backend'}) or die("failed to store objects model");
    return;
}

##############################################

=head2 request_url

    request_url($c, $url, [$cookies], [$method], [$postdata], [$headers], [$insecure])

returns requested url as string. In list context returns ($code, $result)

=cut
sub request_url {
    my($c, $url, $cookies, $method, $postdata, $headers, $insecure) = @_;
    $method = 'GET' unless $method;

    # external url?
    if($url =~ m/^https?:/mx) {
        my($response) = _external_request($c, $url, $cookies, $method, $postdata, $headers, $insecure);
        my $result = {
            code    => $response->code(),
            result  => $response->decoded_content || $response->content,
            headers => {},
        };
        $result->{'result'} = Thruk::Utils::decode_any($result->{'result'});
        $result->{'result'} =~ s/^\x{FEFF}//mx; # remove BOM
        for my $field ($response->header_field_names()) {
            $result->{'headers'}->{$field} = $response->header($field);
        }
        return($result->{'code'}, $result, $response) if wantarray;
        return $result->{'result'};
    }

    local $ENV{'NO_EXTERNAL_JOBS'} = 1;

    # fork setting may be overriden in child requests
    my $old_no_external_job_forks = $c->config->{'no_external_job_forks'};

    my(undef, undef, $res) = _internal_request($url, $method, $postdata, $c->user);

    my $result = {
        code    => $res->code,
        result  => $res->decoded_content || $res->content,
        headers => $res->headers,
    };
    if($result->{'code'} == 302
       and defined $result->{'headers'}
       and defined $result->{'headers'}->{'location'}
       and $result->{'headers'}->{'location'} =~ m|/cgi\-bin/job\.cgi\?job=(.*)$|mx) {
        my $jobid = $1;
        my $x = 0;
        while($result->{'code'} == 302 || $result->{'result'} =~ m/thruk:\ waiting\ for\ job\ $jobid/mx) {
            my $sleep = 0.1 * $x;
            $sleep = 1 if $x > 10;
            sleep($sleep);
            $url = $result->{'headers'}->{'location'} if defined $result->{'headers'}->{'location'};
            (undef, undef, $res) = _internal_request($url, undef, undef, $c->user);
            $result = {
                code    => $res->code,
                result  => $res->decoded_content || $res->content,
                headers => $res->headers,
            };
            $x++;
        }
    }

    # restore fork setting
    $c->config->{'no_external_job_forks'} = $old_no_external_job_forks;

    if($result->{'code'} == 302
          and defined $result->{'headers'}->{'set-cookie'}
          and $result->{'headers'}->{'set-cookie'} =~ m/^thruk_message="?(.*)(%7E%7E|~~)(.*)"?;\ path=/mxo
    ) {
        require URI::Escape;
        my $txt = URI::Escape::uri_unescape($3);
        my $msg = '';
        if($1 eq 'success_message') {
            $msg = 'OK';
        } else {
            $msg = 'FAILED';
        }
        $txt    =~ s/"\s*$//gmx;
        $txt = $msg.' - '.$txt."\n";
        return($result->{'code'}, $result, $txt) if wantarray;
        return $txt;
    }
    elsif($result->{'code'} == 500) {
        my $txt = 'request failed: '.$result->{'code'}." - internal error, please consult your logfiles\n";
        _trace(Dumper($result));
        return($result->{'code'}, $result, $txt) if wantarray;
        return $txt;
    }
    elsif($result->{'code'} != 200) {
        my $txt = 'request failed: '.$result->{'code'}." - ".$result->{'result'}."\n";
        _trace(Dumper($result));
        return($result->{'code'}, $result, $txt) if defined wantarray;
        return $txt;
    }

    # clean error message if there is one
    if($result->{'result'} =~ m/<span\sclass="fail_message">(.*?)<\/span>/mxo) {
        my $txt = 'ERROR - '.$1."\n";
        return(500, $result, $txt) if wantarray;
        return $txt;
    }

    return($result->{'code'}, $result) if wantarray;
    return $result->{'result'};
}

##############################################

=head2 load_module

    load_module($module)

load given module and returns true on success

=cut
sub load_module {
    my($module) = @_;
    ## no critic
    eval "require $module";
    ## use critic
    my $err = $@;
    if($err) {
        if($err =~ m/\QCompilation failed in require\E/mx) {
            _error($err);
        } else {
            _debug2($err);
        }
        return;
    }
    return 1;
}

##############################################
# INTERNAL SUBS
##############################################
sub _read_secret {
    my($self) = @_;
    my $files = [];
    push @{$files}, 'thruk.conf';
    push @{$files}, $ENV{'THRUK_CONFIG'}.'/thruk.conf'       if defined $ENV{'THRUK_CONFIG'};
    push @{$files}, 'thruk_local.conf';
    push @{$files}, $ENV{'THRUK_CONFIG'}.'/thruk_local.conf' if defined $ENV{'THRUK_CONFIG'};
    my $var_path = './var';
    for my $file (@{$files}) {
        next unless -f $file;
        open(my $fh, '<', $file) or die("open file $file failed (id: ".Thruk::Utils::IO::cmd("id -a").", pwd: ".Thruk::Utils::IO::cmd("pwd")."): ".$!);
        while(my $line = <$fh>) {
            next if substr($line, 0, 1) eq '#';
            if($line =~ m/^\s*var_path\s*=\s*(.*?)\s*$/mxo) {
                $var_path = $1;
            }
        }
        CORE::close($fh) or die("cannot close file ".$file.": ".$!);
    }
    my $secret;
    my $secretfile = $var_path.'/secret.key';
    if(-r $secretfile) {
        _debug2("reading secret file: ".$secretfile);
        $secret = read_file($var_path.'/secret.key');
        chomp($secret);
    } else {
        # don't print error unless in debug mode.
        # will be printed in debians postinst installcron otherwise
        _debug2("reading secret file ".$secretfile." failed: ".$!);
    }
    return $secret;
}

##############################################
sub _run {
    my($self) = @_;

    my $action = $self->{'opt'}->{'action'} || $self->{'opt'}->{'commandoptions'}->[0] || '';
    if($action eq 'bash_complete') {
        require Thruk::Utils::Bash;
        return(Thruk::Utils::Bash::complete());
    }

    my $log_timestamps = 0;
    if($ENV{'THRUK_CRON'} || Thruk->verbose) {
        $log_timestamps = 1;
    }

    local $ENV{'THRUK_SKIP_CLUSTER'} = 1 if !$ENV{'THRUK_CRON'};

    my $c = $self->get_c();
    if(!defined $c) {
        _error("command failed, could not create context");
        return 1;
    }

    _debug2("_run(): building response");

    # catch prints when not attached to a terminal and redirect them to our logger
    local $| = 1;
    Thruk::Utils::Log::wrap_stdout2log() if $log_timestamps;

    my $result = $self->from_local($c, $self->{'opt'});

    # remove print wrapper
    Thruk::Utils::Log::wrap_stdout2log_stop();

    _debug("_run(): building local response done, exit code ".$result->{'rc'});
    my $response = $c->res;

    _debug("".$c->stats->report) if Thruk->verbose >= 3;

    # no output?
    if(!defined $result->{'output'}) {
        return $result->{'rc'};
    }

    # fix encoding
    my $content_type = $result->{'content_type'} || $response->content_type() || 'text/plain';
    if($content_type =~ /^text/mx) {
        $result->{'output'} = encode_utf8(Thruk::Utils::decode_any($result->{'output'}));
    }

    if($result->{'rc'} == 0 or $result->{'all_stdout'}) {
        binmode STDOUT;
        print STDOUT $result->{'output'} unless $self->{'opt'}->{'quiet'};
    } else {
        binmode STDERR;
        print STDERR $result->{'output'};
    }
    return $result->{'rc'};
}

##############################################
sub _external_request {
    my($c, $url, $cookies, $method, $postdata, $headers, $insecure) = @_;
    if(!defined $method) {
        $method = $postdata ? "POST" : "GET";
    }
    _debug(sprintf("_external_request(%s, %s)", $url, $method));
    my $ua = _get_user_agent($c->config);
    if($insecure) {
        Thruk::UserAgent::disable_verify_hostname($ua);
    } else {
        Thruk::UserAgent::disable_verify_hostname_by_url($ua, $url);
    }
    if($cookies) {
        my $cookie_string = "";
        for my $key (keys %{$cookies}) {
            $cookie_string .= $key.'='.$cookies->{$key}.';';
        }
        $ua->default_header(Cookie => $cookie_string);
    }

    my $request = HTTP::Request->new($method, $url);
    $request->method(uc($method));
    if($postdata) {
        $request->header('Content-Type' => 'application/json;charset=UTF-8');
        $request->content(Cpanel::JSON::XS->new->encode($postdata)); # using ->utf8 here would end in double encoding
        $request->header('Content-Length' => undef);
    }
    for my $head (@{$headers}) {
        if(!ref $head) {
            my($key, $val) = split(/:/mx, $head, 2);
            $request->header($key, $val // '');
        } else {
            $request->header($head);
        }
    }

    my $response = $ua->request($request);
    if($response->is_success) {
        _debug2(" -> success");
        return($response);
    }
    if(Thruk->verbose >= 2) {
        _debug(" -> external request failed:");
        _debug($response->request->as_string());
        _debug(" -> response:");
        _debug($response->as_string());
    }
    return($response);
}

##############################################
sub _dummy_c {
    _debug2("_dummy_c()");
    my($c) = _internal_request('/thruk/cgi-bin/remote.cgi');
    return($c);
}

##############################################
sub _internal_request {
    my($url, $method, $postdata, $user) = @_;
    $method = 'GET' unless $method;

    _debug(sprintf("_internal_request('%s', '%s')", $url, $method));
    delete local $ENV{'PLACK_TEST_EXTERNALSERVER_URI'} if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    our $app;
    if(!$app) {
        require Thruk;
        require Plack::Test;
        $app = Plack::Test->create(Thruk->startup);
    }
    local $ENV{'THRUK_KEEP_CONTEXT'} = 1;

    delete $Thruk::thruk->{'TRANSFER_USER'} if $app->{'thruk'};
    $Thruk::thruk->{'TRANSFER_USER'} = $user if defined $user;

    my $res    = $app->request(HTTP::Request->new($method, $url, [], $postdata));
    my $c      = $Thruk::Request::c;
    my $failed = ( $res->code == 200 ? 0 : 1 );
    _debug2("_internal_request() done");
    return($c, $failed, $res);
}

##############################################

=head2 from_local

    $self->from_local($c, $options)

main entry point for cli commands from the terminal

=cut
sub from_local {
    my($self, $c, $options) = @_;
    _debug2("from_local()");
    ## no critic
    $ENV{'NO_EXTERNAL_JOBS'} = 1;
    ## use critic
    local $ENV{'THRUK_CLI_SRC'} = 'CLI';

    # user can be set from command line
    if(defined $options->{'auth'}) {
        Thruk::Utils::set_user($c,
                username  => $options->{'auth'},
                auth_src  => "cli",
        );
    } elsif(defined $c->config->{'default_cli_user_name'}) {
        Thruk::Utils::set_user($c,
                username  => $c->config->{'default_cli_user_name'},
                auth_src  => "cli",
        );
    } else {
        Thruk::Utils::set_user($c,
                username  => $ENV{'THRUK_CRON'} ? '(cron)' : '(cli)',
                auth_src  => 'cli',
                internal  => 1,
                superuser => 1,
        );
    }

    return _run_commands($c, $options, 'local');
}

##############################################

=head2 from_fcgi

    from_fcgi($c, $string)

main entry point for cli commands over http(s).

=cut
sub from_fcgi {
    my($c, $data_str) = @_;
    confess('no data?') unless defined $data_str;
    $data_str = encode_utf8($data_str);
    my $data  = decode_json($data_str);
    confess('corrupt data?') unless ref $data eq 'HASH';
    local $ENV{'THRUK_VERBOSE'}      = $data->{'options'}->{'verbose'} if defined $data->{'options'}->{'verbose'};
    local $ENV{'THRUK_MODE'}         = 'CLI';
    local $ENV{'THRUK_CLI_SRC'}      = 'FCGI';
    local $ENV{'THRUK_SKIP_CLUSTER'} = 1;

    # check credentials
    if(!defined $data->{'credential'} || $data->{'credential'} eq '') {
        return({
            'output' => "authorization failed, no auth key specified for ". $c->req->url."\n",
            'rc'     => 1,
        });
    }

    if(!$c->authenticate(apikey => $data->{'credential'})) {
        return({
            'output' => "authorization failed, ". $c->req->url." does not accept this key.\n",
            'rc'     => 1,
        });
    }

    if(defined $data->{'options'}->{'auth'} && $c->user->{'superuser'}) {
        if($c->user->{'internal'} && $data->{'options'}->{'keep_su'}) {
            Thruk::Utils::set_user($c,
                username  => $data->{'options'}->{'auth'},
                auth_src  => 'api',
                internal  => 1,
                superuser => 1,
                roles     => $c->user->{'roles'},
            );
        } else {
            if(!Thruk::Utils::change_user($c, $data->{'options'}->{'auth'}, "fcgi")) {
                return({
                    'output' => "no permission to change the user\n",
                    'rc'     => 1,
                });
            }
        }
    }
    return(_run_commands($c, $data->{'options'}, 'fcgi'));
}

##############################################
sub _run_commands {
    my($c, $opt, $src) = @_;

    my $data = {
        'output'  => '',
        'rc'      => 0,
    };

    # which command to run?
    my @actions = split(/\s*,\s*/mx, ($opt->{'action'} || ''));

    # convert -l to expaned command
    if(defined $opt->{'listbackends'}) {
        unshift @{$opt->{'commandoptions'}}, 'backend', 'list';
    }

    # first unknown option is the command
    if(scalar @actions == 0 and scalar @{$opt->{'commandoptions'}} > 0) {
        my $newcommandoptions = [];
        for my $action (@{$opt->{'commandoptions'}}) {
            if(scalar @actions == 0 && $action !~ m/^\-/gmx) {
                push @actions, $action;
            } else {
                push @{$newcommandoptions}, $action;
            }
        }
        $opt->{'commandoptions'} = $newcommandoptions;
    }

    if(scalar @actions == 1) {
        return(_run_command_action($c, $opt, $src, $actions[0]));
    }

    for my $action (@actions) {
        my $res = _run_command_action($c, $opt, $src, $action);
        $data->{'rc'}     += $res->{'rc'};
        $data->{'output'} .= $res->{'output'};
    }
    return($data);
}

##############################################
sub _run_command_action {
    my($c, $opt, $src, $action) = @_;
    $c->stats->profile(begin => "_run_command_action()");

    my $data = {
        'output'  => '',
        'rc'      => 0,
    };

    # map compatibilty style commands
    if($action =~ /^(https?:\/\/.*|\w+\.cgi.*|\/thruk\/.*)$/mx) {
        $action = 'url';
        unshift @{$opt->{'commandoptions'}}, $1;
    }
    elsif($action =~ /^(list|install|uninstall|clear|clean|dump)
                       (cron|backend|host|service|hostgroup|servicegroup|cache)s?$/mx) {
        $action = $2;
        unshift @{$opt->{'commandoptions'}}, $1;
    }
    elsif($action =~ /^(cache)
                       (dump|clear|clean|drop)$/mx) {
        $action = $1;
        unshift @{$opt->{'commandoptions'}}, $2;
    }
    elsif($action eq 'clean_dashboards') {
        $action = 'panorama';
        unshift @{$opt->{'commandoptions'}}, 'clean';
    }
    elsif($action =~ /^fix_scheduling=?(.*)$/mx) {
        $action = 'core_scheduling';
        unshift @{$opt->{'commandoptions'}}, 'fix';
    }

    # raw query
    if($action eq 'raw') {
        ($data->{'output'}, $data->{'rc'}) = _cmd_raw($c, $opt, $src);
    }

    # precompile templates
    elsif($action eq 'compile') {
        $data->{'output'} = _cmd_precompile($c);
    }

    # restart process
    elsif($action eq 'restart' || $action eq 'stop') {
        $data->{'output'} = _cmd_stop($c, $action);
    }

    else {
        # generic sub commands

        # compatibility mode for old style commands
        if($action =~ m/^(selfcheck|report|livecache|downtimetask|bp|logcache|url)(\w*)
                         =?(.*)$/gmx) {
            my @m = ($1, $2, $3);
            $action = $m[0];
            unshift @{$opt->{'commandoptions'}}, $m[2] if $m[2];
            unshift @{$opt->{'commandoptions'}}, $m[1] if $m[1];
        }

        # load sub command module
        my($err);
        my @mods = ($action);
        if($action =~ m/s$/mx) { $action =~ s/s$//gmx; push @mods, $action; }
        for my $mod (@mods) {
            $action = $mod;
            my $modname = "Thruk::Utils::CLI::".ucfirst($mod);
            _debug2("trying to load module: ".$modname);
            undef $err;
            eval {
                load $modname;
            };
            $err = $@;
            last unless $err;

            if($err =~ m|^Can't\ locate\ .*\ in\ \@INC|mx && $err !~ m/Compilation\ failed\ in\ require\ at/mx) {
                _debug($@);
                $data->{'output'} = "FAILED - no such command: ".$action.".\n".
                                    "Enabled cli plugins: ".join(", ", @{Thruk::Utils::get_cli_modules()})."\n";
            } elsif($err) {
                _error($@);
                $data->{'output'} = "FAILED - to load command module: ".$action.".\n";
            }
        }
        if($err) {
            $data->{'rc'} = 1;
            $c->stats->profile(end => "_run_command_action()");
            return $data;
        }

        # print help only?
        if(scalar @{$opt->{'commandoptions'}} > 0 && $opt->{'commandoptions'}->[0] =~ /^(help|\-h|--help)$/mx) {
            $c->stats->profile(end => "_run_command_action()");
            return(get_submodule_help(ucfirst($action)));
        }

        my $skip_backends;
        {
            ## no critic
            no strict 'refs';
            ## use critic
            $skip_backends = ${"Thruk::Utils::CLI::".ucfirst($action)."::skip_backends"};
            if(ref $skip_backends eq 'CODE') {
                $skip_backends = &{$skip_backends}($c, $opt);
            }
        }
        if(!defined $c->stash->{'defaults_added'} && !$skip_backends) {
            Thruk::Action::AddDefaults::add_defaults($c, 2);

            # set backends from options
            if(defined $opt->{'backends'} and scalar @{$opt->{'backends'}} > 0) {
                Thruk::Action::AddDefaults::set_enabled_backends($c, $opt->{'backends'});
            }
        }

        # run command
        my $f = \&{"Thruk::Utils::CLI::".ucfirst($action)."::cmd"};
        my @res = &{$f}($c, $action, $opt->{'commandoptions'}, $data, $src, $opt);
        if(scalar @res == 1 && ref $res[0] eq 'HASH') {
            $data = $res[0];
        } else {
            ($data->{'output'}, $data->{'rc'}) = @res;
        }
    }

    $c->stats->profile(end => "_run_command_action()");

    if($ENV{'THRUK_JOB_DIR'}) {
        Thruk::Utils::External::save_profile($c, $ENV{'THRUK_JOB_DIR'}) if $ENV{'THRUK_JOB_DIR'};
        Thruk::Utils::IO::touch($ENV{'THRUK_JOB_DIR'}."/stdout");
    }

    return $data;
}

##############################################

=head2 get_submodule_help

    get_submodule_help($module, [$data])

returns help extracted from pod for given module

=cut
sub get_submodule_help {
    my($module, $data) = @_;

    $data = {} unless $data;
    require Pod::Usage;
    my $file = "Thruk::Utils::CLI::".$module.".pm";
    if($module =~ m/::/gmx) {
        $file = $module.'.pm';
    }
    $file =~ s/::/\//gmx;
    my $output = "";
    open my $fh, ">", \$output or die $!;
    Pod::Usage::pod2usage({
            -verbose    => 99,
            -sections   => "DESCRIPTION|SYNOPSIS|OPTIONS|EXAMPLES",
            -noperldoc  => 1,
            -input      => $INC{$file},
            -output     => $fh,
            -exitval    => 'NOEXIT',
        });
    CORE::close($fh);
    $data->{'output'} = $output;
    $data->{'rc'}     = 3;
    return $data;
}

##############################################
sub _cmd_precompile {
    my($c) = @_;
    $c->stats->profile(begin => "_cmd_precompile()");
    my $msg = Thruk::Utils::precompile_templates($c);
    $c->stats->profile(end => "_cmd_precompile()");
    return $msg;
}

##############################################
sub _cmd_stop {
    my($c, $action) = @_;
    $c->stats->profile(begin => "_cmd_stop()");
    $c->app->stop_all();
    $c->stats->profile(end => "_cmd_stop()");
    return(sprintf("OK - all processes %s\n", $action eq 'stop' ? "stopped" : "restarted"));
}

##########################################################
sub _cmd_configtool {
    my($c, $peerkey, $opt) = @_;
    my $res        = undef;
    my $last_error = undef;

    if(!$c->check_user_roles('authorized_for_admin')) {
        return("admin privileges required to access the config tool ", 1);
    }

    $c->stash->{'param_backend'}     = $peerkey;
    $c->req->parameters->{'backend'} = $peerkey;

    require Thruk::Utils::Conf;
    if(!Thruk::Utils::Conf::set_object_model($c)) {
        if($c->stash->{set_object_model_err}) {
            return("failed to set objects model: ".$c->stash->{set_object_model_err}, 1);
        }
        return("failed to set objects model", 1);
    }
    if($peerkey ne $c->stash->{'param_backend'}) {
        return(sprintf("failed to set objects model, got configtool section for wrong backend '%s' ne '%s'",$peerkey, $c->stash->{'param_backend'}), 1);
    }
    # outgoing file sync
    elsif($opt->{'args'}->{'sub'} eq 'syncfiles') {
        $c->{'obj_db'}->check_files_changed();
        my $transfer    = {};
        my $remotefiles = $opt->{'args'}->{'args'}->{'files'};
        for my $f (@{$c->{'obj_db'}->{'files'}}) {
            $f->get_meta_data() unless defined $f->{'mtime'};
            # use display instead of path to make cascaded http backends work
            $transfer->{$f->{'display'}} = { mtime => $f->{'mtime'} };
            if(   !defined $remotefiles->{$f->{'display'}}
               || !defined $remotefiles->{$f->{'display'}}->{'mtime'}
               || $f->{'mtime'} != $remotefiles->{$f->{'display'}}->{'mtime'}) {
                $transfer->{$f->{'display'}}->{'content'} = read_file($f->{'path'});
            }
        }
        $res = $transfer;
    }
    # some settings
    elsif($opt->{'args'}->{'sub'} eq 'configsettings') {
        $res = {
            'files_root' => $c->{'obj_db'}->get_files_root(),
        };
    }
    # plugins
    elsif($opt->{'args'}->{'sub'} eq 'configplugins') {
        $res = $c->{'obj_db'}->get_plugins($c);
    }
    # plugin help
    elsif($opt->{'args'}->{'sub'} eq 'configpluginhelp') {
        $res = $c->{'obj_db'}->get_plugin_help($c, $opt->{'args'}->{'args'});
    }
    # plugin preview
    elsif($opt->{'args'}->{'sub'} eq 'configpluginpreview') {
        $res = $c->{'obj_db'}->get_plugin_preview($c, @{$opt->{'args'}->{'args'}});
    }
    # run config check
    elsif($opt->{'args'}->{'sub'} eq 'configcheck') {
        my $jobid = Thruk::Utils::External::cmd($c, { cmd => $c->{'obj_db'}->{'config'}->{'obj_check_cmd'}." 2>&1", 'background' => 1 });
        die("starting configcheck failed, check your logfiles") unless $jobid;
        $res = 'jobid:'.$jobid;
    }
    # reload configuration
    elsif($opt->{'args'}->{'sub'} eq 'configreload') {
        my $jobid = Thruk::Utils::External::cmd($c, { cmd => $c->{'obj_db'}->{'config'}->{'obj_reload_cmd'}." 2>&1", 'background' => 1 });
        die("starting configreload failed, check your logfiles") unless $jobid;
        $res = 'jobid:'.$jobid;
    }
    # save incoming config changes
    elsif($opt->{'args'}->{'sub'} eq 'configsave') {
        my $filesroot = $c->{'obj_db'}->get_files_root();

        if($c->config->{'Thruk::Plugin::ConfigTool'}->{'pre_obj_save_cmd'}) {
            my $cmd = $c->config->{'Thruk::Plugin::ConfigTool'}->{'pre_obj_save_cmd'}." pre '".$filesroot."' 2>&1";
            my($rc, $out) = Thruk::Utils::IO::cmd($c, $cmd);
            if($rc != 0) {
                _info('pre save hook: '.$rc);
                _info('pre save hook: '.$out);
                return("Save canceled by pre save hook!\n".$out, 1);
            }
            _debug('pre save hook: '.$out);
        }

        my $changed = $opt->{'args'}->{'args'}->{'changed'};
        # changed and new files
        for my $f (@{$changed}) {
            my($path,$content, $mtime) = @{$f};
            $content = encode_utf8(Thruk::Utils::decode_any($content));
            next if $path =~ m|/\.\./|gmx; # no relative paths
            my $file = $c->{'obj_db'}->get_file_by_path($path);
            my $saved;
            if($file && !$file->readonly()) {
                # update file
                Thruk::Utils::IO::write($path, $content, $mtime);
                $saved = 'updated';
            } elsif(!$file) {
                # new file
                if($path =~ m/^\Q$filesroot\E/mx) {
                    $file = Monitoring::Config::File->new($path, $c->{'obj_db'}->{'config'}->{'obj_readonly'}, $c->{'obj_db'}->{'coretype'});
                    if(defined $file && !$file->readonly()) {
                        Thruk::Utils::IO::write($path, $content, $mtime);
                        $saved = 'created';
                    }
                }
            }
            # create log message
            if($saved && !$ENV{'THRUK_TEST_NO_STDOUT_LOG'}) {
                _info(sprintf("[config][%s][%s][ext] %s file '%s'",
                                            $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'name'},
                                            $c->stash->{'remote_user'},
                                            $saved,
                                            $path,
                ));
            }
        }
        # deleted files
        my $deleted = $opt->{'args'}->{'args'}->{'deleted'};
        for my $f (@{$deleted}) {
            my $file = $c->{'obj_db'}->get_file_by_path($f);
            if($file && !$file->readonly()) {
                unlink($f);

                # create log message
                _info(sprintf("[config][%s][%s][ext] deleted file '%s'",
                                            $c->{'db'}->get_peer_by_key($c->stash->{'param_backend'})->{'name'},
                                            $c->stash->{'remote_user'},
                                            $f,
                ));
            }
        }
        $res = "saved";

        # run post hook
        if($c->config->{'Thruk::Plugin::ConfigTool'}->{'post_obj_save_cmd'}) {
            Thruk::Utils::IO::cmd($c, [$c->config->{'Thruk::Plugin::ConfigTool'}->{'post_obj_save_cmd'}, 'post', $filesroot]);
        }
    } else {
        return("unknown configtool command", 1);
    }
    return([undef, 1, $res, $last_error], 0);
}

##############################################
sub _cmd_raw {
    my($c, $opt, $src) = @_;
    my $function  = $opt->{'sub'};

    unless(defined $c->stash->{'defaults_added'}) {
        Thruk::Action::AddDefaults::add_defaults($c, 1);
    }
    my @keys = @{$Thruk::Backend::Pool::peer_order};
    my $key = $keys[0];
    # do we have a hint about remote peer?
    if($opt->{'remote_name'}) {
        if(ref $opt->{'remote_name'} eq 'ARRAY') {
            if(scalar @{$opt->{'remote_name'}} != 1) {
                die('multiple remote_name not supported');
            }
            $opt->{'remote_name'} = $opt->{'remote_name'}->[0];
        }
        my $peer = $c->{'db'}->get_peer_by_name($opt->{'remote_name'});
        die('no such backend: '.$opt->{'remote_name'}) unless defined $peer;
        $key = $peer->peer_key();
    }
    elsif($opt->{'backends'}) {
        if(ref $opt->{'backends'} ne 'ARRAY' || scalar @{$opt->{'backends'}} != 1) {
            die('backends must be an array with a single value');
        }
        my $peer = $c->{'db'}->get_peer_by_name($opt->{'backends'}->[0]);
        die('no such backend: '.$opt->{'backends'}->[0]) unless defined $peer;
        $key = $peer->peer_key();
    } else {
        $key = $keys[0];
    }
    die("no backends...") unless $key;

    if($function eq 'get_logs' or $function eq '_get_logs_start_end') {
        $c->{'db'}->renew_logcache($c);
    }

    # config tool commands
    elsif($function eq 'configtool') {
        return _cmd_configtool($c, $key, $opt);
    }

    # result for external job
    elsif($function eq 'job') {
        return _cmd_ext_job($c, $opt);
    }

    elsif($function =~ /^cmd:\s+(\w+)\s*(.*)/mx) {
        if(!$c->check_user_roles('authorized_for_admin')) {
            return("admin privileges required to run ".$function, 1);
        }
        local $ENV{'THRUK_SKIP_CLUSTER'} = 1;
        my $action = $1;
        $opt->{'commandoptions'} = [split/\s+/mx, $2];
        my $res = _run_command_action($c, $opt, $src, $action);
        return([$res->{'output'}], $res->{'rc'});
    }

    # run code
    elsif($function =~ /::/mx) {
        if(!$c->check_user_roles('authorized_for_admin') && $function ne 'Thruk::Utils::get_fake_session') {
            return("admin privileges required to run ".$function, 1);
        }
        local $ENV{'THRUK_SKIP_CLUSTER'} = 1;
        require Thruk::Utils::Cluster;
        $opt->{'args'}   = Thruk::Utils::unencode_arg_refs($c, $opt->{'args'});
        my $pkg_name     = $function;
        $pkg_name        =~ s%::[^:]+$%%mx;
        my $function_ref = \&{$function};
        my @res;
        eval {
            if($pkg_name && $pkg_name !~ m/^CORE/mx) {
                load $pkg_name;
            }
            @res = &{$function_ref}(@{$opt->{'args'}});
        };
        if($@) {
            return($@, 1);
        }
        return(\@res, 0);
    }

    # check permissions
    my $err = _authorize_function($c, $function, $opt);
    if($err) {
        return($err, 1);
    }

    # passthrough livestatus results if possible (used by cascaded lmd setups)
    if($ENV{'THRUK_USE_LMD'} && $function eq '_raw_query' && $c->req->headers->{'accept'} && $c->req->headers->{'accept'} =~ m/application\/livestatus/mx) {
        my $peer = $Thruk::Backend::Pool::lmd_peer;
        my $query = $opt->{'args'}->[0];
        chomp($query);
        $query .= "\nBackends: ".$key."\n";
        $c->res->body($peer->_raw_query($query));
        $c->{'rendered'} = 1;
        return;
    }

    local $ENV{'THRUK_USE_LMD'} = ""; # don't try to do LMD stuff since we directly access the real backend
    my @res = Thruk::Backend::Pool::do_on_peer($key, $function, $opt->{'args'});
    my $res = shift @res;

    # add proxy version and config tool settings to processinfo
    if($function eq 'get_processinfo' and defined $res and ref $res eq 'ARRAY' and defined $res->[2] and ref $res->[2] eq 'HASH') {
        $res->[2]->{$key}->{'data_source_version'} .= ' (via Thruk '.$c->config->{'version'}.($c->config->{'branch'}? '~'.$c->config->{'branch'} : '').')';

        # add config tool settings (will be read from Thruk::Backend::Manager::_do_on_peers)
        my $tmp = $Thruk::Backend::Pool::peers->{$key}->{'peer_config'}->{'configtool'};
        if($c->check_user_roles('authorized_for_admin') && $tmp && ref $tmp eq 'HASH' && scalar keys %{$tmp} > 0) {
            $res->[2]->{$key}->{'configtool'} = {
                'core_type'      => $tmp->{'core_type'},
                'obj_readonly'   => $tmp->{'obj_readonly'},
                'obj_check_cmd'  => exists $tmp->{'obj_check_cmd'},
                'obj_reload_cmd' => exists $tmp->{'obj_reload_cmd'},
            };
        } else {
            $res->[2]->{$key}->{'configtool'} = {
                'disable'        => 1,
            };
        }
    }

    return($res, 0);
}

##############################################
sub _cmd_ext_job {
    my($c, $opt) = @_;
    my $jobid       = $opt->{'args'};
    my $res         = "";
    my $last_error  = "";
    if(Thruk::Utils::External::is_running($c, $jobid, $c->user->{'superuser'})) {
        $res = "jobid:".$jobid.":0";
    }
    else {
        #my($out,$err,$time,$dir,$stash,$rc)
        my @res = Thruk::Utils::External::get_result($c, $jobid, $c->user->{'superuser'});
        $res = {
            'out'   => $res[0],
            'err'   => $res[1],
            'time'  => $res[2],
            'dir'   => $res[3],
            'rc'    => $res[5],
        };
    }
    return([undef, 1, $res, $last_error], 0);
}

##############################################
sub _get_user_agent {
    my($config) = @_;
    my $ua = Thruk::UserAgent->new({}, $config);
    $ua->requests_redirectable(['GET', 'POST', 'HEAD']);
    $ua->agent("thruk_cli");
    return $ua;
}

##############################################
sub _format_response_error {
    my($response) = @_;
    if(defined $response) {
        return $response->code().': '.$response->message();
    } else {
        return Dumper($response);
    }
}

##############################################
sub _authorize_function {
    my($c, $function, $opt) = @_;

    if($c->check_user_roles('authorized_for_admin')) {
        # OK
        return;
    }
    my $standard_error = "permission denied - function $function requires admin permissions.";

    if($function eq 'send_command') {
        return _authorize_send_command($c, $opt);
    }
    elsif($function eq '_raw_query') {
        return _authorize_raw_query($c, $opt);
    }
    elsif($function eq 'get_sites'
       || $function eq 'get_processinfo'
       || $function eq 'get_can_submit_commands'
    ) {
        # OK
        return;
    }
    elsif($function eq 'get_contactgroups_by_contact') {
        if(!$c->user->{'superuser'}) {
            $opt->{'args'}->[0] = $c->user->{'username'};
        }
        # OK
        return;
    }
    elsif($function eq 'get_hosts' || $function =~ /^get_host_/mx) {
        _extend_filter($c, $opt, 'filter', 'hosts');
        return;
    }
    elsif($function eq 'get_services' || $function =~ /^get_service_/mx || $function eq 'get_hosts_by_servicequery') {
        _extend_filter($c, $opt, 'filter', 'services');
        return;
    }
    elsif($function eq 'get_performance_stats') {
        _extend_filter($c, $opt, 'hosts_filter', 'hosts');
        _extend_filter($c, $opt, 'services_filter', 'services');
        return;
    }
    elsif($function eq 'get_hostgroups')        { return _extend_filter($c, $opt, 'filter', 'hostgroups'); }
    elsif($function eq 'get_hostgroup_names')   { return _extend_filter($c, $opt, 'filter', 'hostgroups'); }
    elsif($function eq 'get_servicegroups')     { return _extend_filter($c, $opt, 'filter', 'servicegroups'); }
    elsif($function eq 'get_servicegroup_names'){ return _extend_filter($c, $opt, 'filter', 'servicegroups'); }
    elsif($function eq 'get_extra_perf_stats')  { return _extend_filter($c, $opt, 'filter', 'status'); }
    elsif($function eq 'get_comments')          { return _extend_filter($c, $opt, 'filter', 'comments'); }
    elsif($function eq 'get_downtimes')         { return _extend_filter($c, $opt, 'filter', 'downtimes'); }
    elsif($function eq 'get_commands')          { return _extend_filter($c, $opt, 'filter', 'commands'); }
    elsif($function eq 'get_logs' || $function eq 'get_logs_start_end') {
        return _extend_filter($c, $opt, 'filter', 'log');
    } elsif($function eq 'get_timeperiods' || $function eq 'get_timeperiod_names') {
        _extend_filter($c, $opt, 'filter', 'timeperiods');
        return;
    }

    return($standard_error);
}

##############################################
sub _extend_filter {
    my($c, $opt, $key, $authname) = @_;
    my %args = @{$opt->{'args'}};
    $args{'filter'} = [] unless defined $args{'filter'};
    push @{$args{'filter'}}, Thruk::Utils::Auth::get_auth_filter($c, $authname);
    @{$opt->{'args'}} = %args;
    return;
}

##############################################
sub _authorize_raw_query {
    my($c, $opt) = @_;

    my $queries = _extract_queries($opt->{'args'});

    for my $q (@{$queries}) {
        if($q =~ m/^GET\s+(.*)$/mx) {
            my $table = $1;
            if($c->check_user_roles(["authorized_for_all_hosts", "authorized_for_all_services"])) {
                # OK without changes
                next;
            }
            if(!$c->check_user_roles("authorized_for_all_hosts") && ($table eq 'services' || $table eq 'comments' || $table eq 'downtimes')) {
                # there can be hosts which are not directly assigned to this contact but may be visible because of service contacts
                # in case of raw queries (from lmd) we have to limit services to host contacts only, since we cannot fetch the corresponding host
                # and will get inconsistant state otherwise
                $q .= "Filter: host_contacts >= ".$c->user->{'username'}."\n";
                next;
            }
            my @filter = Thruk::Utils::Auth::get_auth_filter($c, $table);
            if(scalar @filter == 0) {
                # OK without changes
                next;
            }
            require Monitoring::Livestatus::Class::Lite;
            @filter = Monitoring::Livestatus::Class::Lite::filter_statement(undef, \@filter);
            $q .= join("\n", @filter)."\n";
            next;
        }
        elsif($q =~ m/^COMMAND/mx) {
            if($c->check_user_roles("authorized_for_read_only")) {
                _warn(sprintf("rejected query command for readonly user %s: %s", $c->user->{'username'}, $q));
                return("permission denied - sending commands requires admin permissions.");
            }
            if($c->check_user_roles(["authorized_for_all_service_commands", "authorized_for_all_host_commands", "authorized_for_system_commands"])) {
                # OK without changes
                next;
            }

            if($q =~ m/^COMMAND\s+\[\d+\]\s([A-Z_]+);?(.*)/mx) {
                my $cmd_name = lc($1);
                my $cmd_args = [split(/;/mx, $2)];
                next if _authorize_command($c, $cmd_name, $cmd_args);
            }

            _warn(sprintf("rejected query command for user %s: %s", $c->user->{'username'}, $q));
            return("permission denied - sending this command requires admin permissions.");
        }

        _warn(sprintf("rejected unknown query for user %s: %s", $c->user->{'username'}, $q));
        return("permission denied - unnown query.");
    }

    # OK
    $opt->{'args'} = [join("\n", @{$queries})];
    return;
}

##############################################
sub _authorize_send_command {
    my($c, $opt) = @_;
    my %args = @{$opt->{'args'}};
    my $queries = _extract_queries($args{'command'});
    for my $q (@{$queries}) {
        if($q =~ m/^COMMAND\s+\[\d+\]\s([A-Z_]+);?(.*)/mx) {
            my $cmd_name = lc($1);
            my $cmd_args = [split(/;/mx, $2)];
            next if _authorize_command($c, $cmd_name, $cmd_args);
        }
        return("permission denied - sending this command requires admin permissions.");
    }
    return;
}

##############################################
sub _extract_queries {
    my($raw_queries) = @_;
    my $queries = [];
    my $current = "";
    for my $raw (@{Thruk::Utils::list($raw_queries)}) {
        for my $line (split(/\n/mx, $raw)) {
            chomp($line);
            if($line eq '') {
                push @{$queries}, $current;
                $current = '';
            }
            else {
                $current .= $line."\n";
            }
        }
        if($current ne '') {
            push @{$queries}, $current;
        }
    }
    return($queries);
}

##############################################
sub _authorize_command {
    my($c, $cmd_name, $cmd_args) = @_;
    require Thruk::Controller::Rest::V1::cmd;
    my $available_commands = Thruk::Controller::Rest::V1::cmd::get_rest_external_command_data();
    my($cmd, $cat);
    for my $cat_name (sort keys %{$available_commands}) {
        if($available_commands->{$cat_name}->{$cmd_name}) {
            $cmd = $available_commands->{$cat_name}->{$cmd_name};
            $cat = $cat_name;
            last;
        }
    }
    $cat =~ s/s$//gmx;
    if($cat eq 'service') {
        if($c->user->check_cmd_permissions($c, $cat, $cmd_args->[1], $cmd_args->[0])) {
            # OK
            return 1;
        }
    } elsif($cat eq 'system') {
        if($c->user->check_cmd_permissions($c, $cat)) {
            # OK
            return 1;
        }
    } else {
        if($c->user->check_cmd_permissions($c, $cat, $cmd_args->[0])) {
            # OK
            return 1;
        }
    }
    return;
}

##############################################

=head1 EXAMPLES

there are some cli scripting examples in the examples subfolder of the source
package.

=cut

1;
