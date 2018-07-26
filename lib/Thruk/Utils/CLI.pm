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
use Thruk::UserAgent qw//;
use Cpanel::JSON::XS qw/encode_json decode_json/;
use File::Slurp qw/read_file/;
use Encode qw(encode_utf8);
use Time::HiRes qw/gettimeofday tv_interval/;
use Module::Load qw/load/;
use Thruk::Utils qw//;
use Thruk::Utils::IO qw//;
use Thruk::Utils::Log qw/_error _info _debug _trace/;

$Thruk::Utils::CLI::verbose = 0 unless defined $Thruk::Utils::CLI::verbose;

##############################################

=head1 METHODS

=head2 new

    new([ $options ])

 $options = {
    verbose         => 0-2,         # be more verbose
    credential      => 'secret',    # secret key when accessing remote instances
    remoteurl       => 'url',       # url where to access remote instances
    local           => 0|1,         # local requests only
 }

create CLI tool object

=cut
sub new {
    my($class, $options) = @_;
    $options->{'verbose'} = 1 unless defined $options->{'verbose'};
    $Thruk::Utils::CLI::verbose = $options->{'verbose'};
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
    $ENV{'THRUK_SRC'}        = 'CLI';
    $ENV{'NO_EXTERNAL_JOBS'} = 1;
    $ENV{'REMOTE_USER'}      = $options->{'auth'} if defined $options->{'auth'};
    $ENV{'THRUK_BACKENDS'}   = join(';', @{$options->{'backends'}}) if(defined $options->{'backends'} and scalar @{$options->{'backends'}} > 0);
    $ENV{'THRUK_VERBOSE'}    = $options->{'verbose'}-1 if $options->{'verbose'} >= 2;;
    $ENV{'THRUK_DEBUG'}      = $options->{'verbose'} if $options->{'verbose'} >= 3;
    $ENV{'THRUK_QUIET'}      = 1 if $options->{'quiet'};
    ## use critic
    $options->{'remoteurl_specified'} = 1;
    unless(defined $options->{'remoteurl'}) {
        $options->{'remoteurl_specified'} = 0;
        if(defined $ENV{'STARTURL'}) {
            $options->{'remoteurl'} = $ENV{'STARTURL'};
        }
        elsif(defined $ENV{'REMOTEURL'}) {
            $options->{'remoteurl'} = $ENV{'REMOTEURL'};
        }
        elsif(defined $ENV{'OMD_SITE'}) {
            $options->{'remoteurl'} = 'http://localhost/'.$ENV{'OMD_SITE'}.'/thruk/cgi-bin/remote.cgi';
        }
        else {
            $options->{'remoteurl'} = 'http://localhost/thruk/cgi-bin/remote.cgi';
        }
    }
    $options->{'remoteurl'} =~ s|/thruk/*$||mx;
    $options->{'remoteurl'} = $options->{'remoteurl'}.'/thruk/cgi-bin/remote.cgi' if $options->{'remoteurl'} !~ m/remote\.cgi$/mx;

    # try to read secret file
    $self->{'opt'}->{'credential'} = $self->_read_secret() unless defined $self->{'opt'}->{'credential'};

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
    #my($c, $failed)
    my($c, undef, undef) = $self->_dummy_c();
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

    request_url($c, $url, [$cookies], [$method], [$postdata])

returns requested url as string. In list context returns ($code, $result)

=cut
sub request_url {
    my($c, $url, $cookies, $method, $postdata) = @_;
    $method = 'GET' unless $method;

    # external url?
    if($url =~ m/^https?:/mx) {
        confess("only GET supported right now") if $method ne 'GET';
        my($response) = _external_request($url, $cookies);
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
        return($result->{'code'}, $result) if wantarray;
        return $result->{'result'};
    }

    local $ENV{'REMOTE_USER'}      = $c->stash->{'remote_user'} if(!$ENV{'REMOTE_USER'} && $c->stash->{'remote_user'});
    local $ENV{'NO_EXTERNAL_JOBS'} = 1;

    # fork setting may be overriden in child requests
    my $old_no_external_job_forks = $c->config->{'no_external_job_forks'};

    my(undef, undef, $res) = _dummy_c(undef, $url, $method, $postdata);

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
        while($result->{'code'} == 302 or $result->{'result'} =~ m/thruk:\ waiting\ for\ job\ $jobid/mx) {
            my $sleep = 0.1 * $x;
            $sleep = 1 if $x > 10;
            sleep($sleep);
            $url = $result->{'headers'}->{'location'} if defined $result->{'headers'}->{'location'};
            (undef, undef, $result) = _dummy_c(undef, $url);
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
        _debug(Dumper($result)) if $Thruk::Utils::CLI::verbose >= 2;
        return($result->{'code'}, $result, $txt) if wantarray;
        return $txt;
    }
    elsif($result->{'code'} != 200) {
        my $txt = 'request failed: '.$result->{'code'}." - ".$result->{'result'}."\n";
        _debug(Dumper($result)) if $Thruk::Utils::CLI::verbose >= 2;
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
        open(my $fh, '<', $file) or die("open file $file failed (id: ".`id -a`.", pwd: ".`pwd`."): ".$!);
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
    if(-e $secretfile) {
        _debug("reading secret file: ".$secretfile) if $Thruk::Utils::CLI::verbose >= 2;
        $secret = read_file($var_path.'/secret.key');
        chomp($secret);
    } else {
        # don't print error unless in debug mode.
        # will be printed in debians postinst installcron otherwise
        _debug("reading secret file ".$secretfile." failed: ".$!) if $Thruk::Utils::CLI::verbose >= 2;
    }
    return $secret;
}

##############################################
sub _run {
    my($self) = @_;

    ## no critic
    my $terminal_attached = -t 0 ? 1 : 0;
    ## use critic
    my $log_timestamps = 0;
    my $action = $self->{'opt'}->{'action'} || $self->{'opt'}->{'commandoptions'}->[0] || '';
    if($ENV{'THRUK_CRON'} || $action =~ m/^(logcache|bp|report|downtimetask)/mx) {
        $log_timestamps = 1;
    }

    # skip cluster if --local is given on command line
    local $ENV{'THRUK_SKIP_CLUSTER'} = 1 if($self->{'opt'}->{'local'} && !$ENV{'THRUK_CRON'});

    # force some commands to be local
    if($action =~ m/^(logcache|livecache|bpd|bp||report|plugin|lmd|find)/mx) {
        $self->{'opt'}->{'local'} = 1;
    }

    # force cronjobs to be local
    if($ENV{'THRUK_CRON'}) {
        $self->{'opt'}->{'local'} = 1;
    }

    my($result, $response);
    _debug("_run(): ".Dumper($self->{'opt'})) if $Thruk::Utils::CLI::verbose >= 2;
    unless($self->{'opt'}->{'local'}) {
        ($result,$response) = _request($self->{'opt'}->{'credential'}, $self->{'opt'}->{'remoteurl'}, $self->{'opt'});
        if(!defined $result && $self->{'opt'}->{'remoteurl_specified'}) {
            _error("requesting result from ".$self->{'opt'}->{'remoteurl'}." failed: "._format_response_error($response));
            _debug(" -> ".Dumper($response)) if $Thruk::Utils::CLI::verbose >= 2;
            return 1;
        }
    }

    my($c, $capture);
    unless(defined $result) {
        # initialize backend pool here to safe some memory
        require Thruk::Backend::Pool;
        if($action and $action =~ m/livecache/mx) {
            local $ENV{'THRUK_NO_CONNECTION_POOL'} = 1;
            Thruk::Backend::Pool::init_backend_thread_pool();
        } else {
            Thruk::Backend::Pool::init_backend_thread_pool();
        }

        $c = $self->get_c();
        if(!defined $c) {
            print STDERR "command failed";
            return 1;
        }

        if($terminal_attached) {
            # initialize screen logging
            $c->app->{'_log'} = 'screen';
        }

        # catch prints when not attached to a terminal and redirect them to our logger
        local $| = 1;
        if(!$terminal_attached && $log_timestamps) {
            my $tmp;
            ## no critic
            open($capture, '>', \$tmp) or die("cannot open stdout capture: $!");
            tie *$capture, 'Thruk::Utils::Log', (*STDOUT);
            select $capture;
            ## use critic
        }

        $result = $self->_from_local($c, $self->{'opt'});

        # remove print capture
        ## no critic
        select *STDOUT;
        ## use critic
    }

    # no output?
    if(!defined $result->{'output'}) {
        return $result->{'rc'};
    }

    # fix encoding
    if(!$result->{'content_type'} || $result->{'content_type'} =~ /^text/mx) {
        $result->{'output'} = encode_utf8(Thruk::Utils::decode_any($result->{'output'}));
    }

    # with output
    if($capture) {
        print $capture $result->{'output'};
    }
    elsif($result->{'rc'} == 0 or $result->{'all_stdout'}) {
        binmode STDOUT;
        print STDOUT $result->{'output'} unless $self->{'opt'}->{'quiet'};
    } else {
        binmode STDERR;
        print STDERR $result->{'output'};
    }
    _trace("".$c->stats->report) if defined $c and $Thruk::Utils::CLI::verbose >= 3;
    return $result->{'rc'};
}

##############################################
sub _request {
    my($credential, $url, $options) = @_;
    _debug("_request(".$url.")") if $Thruk::Utils::CLI::verbose >= 2;
    my $ua       = _get_user_agent();
    my $response = $ua->post($url, {
        data => encode_json({
            credential => $credential,
            options    => $options,
        }),
    });
    if($response->is_success) {
        _debug(" -> success") if $Thruk::Utils::CLI::verbose >= 2;
        my $data_str = $response->decoded_content || $response->content;
        my $data;
        eval {
            $data = decode_json($data_str);
        };
        if($@) {
            _error(" -> decode failed: ".Dumper($@, $data_str, $response));
            return(undef, $response);
        }
        _debug("   -> ".Dumper($response)) if $Thruk::Utils::CLI::verbose >= 2;
        _debug("   -> ".Dumper($data))     if $Thruk::Utils::CLI::verbose >= 2;
        return($data, $response);
    }

    _debug(" -> failed: ".Dumper($response)) if $Thruk::Utils::CLI::verbose >= 2;
    return(undef, $response);
}

##############################################
sub _external_request {
    my($url, $cookies) = @_;
    _debug("_external_request(".$url.")") if $Thruk::Utils::CLI::verbose >= 2;
    my $ua = _get_user_agent();
    if($cookies) {
        my $cookie_string = "";
        for my $key (keys %{$cookies}) {
            $cookie_string .= $key.'='.$cookies->{$key}.';';
        }
        $ua->default_header(Cookie => $cookie_string);
    }

    my $response = $ua->get($url);
    if($response->is_success) {
        _debug(" -> success") if $Thruk::Utils::CLI::verbose >= 2;
        return($response);
    }
    _debug(" -> failed: ".Dumper($response)) if $Thruk::Utils::CLI::verbose >= 2;
    return($response);
}

##############################################
sub _dummy_c {
    my($self, $url, $method, $postdata) = @_;
    $method = 'GET' unless $method;

    _debug("_dummy_c()") if $Thruk::Utils::CLI::verbose >= 2;
    delete local $ENV{'PLACK_TEST_EXTERNALSERVER_URI'} if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    $url = '/thruk/cgi-bin/remote.cgi' unless defined $url;
    our $app;
    if(!$app) {
        require Thruk;
        require HTTP::Request;
        require Plack::Test;
        $app = Plack::Test->create(Thruk->startup);
    }
    local $ENV{'THRUK_KEEP_CONTEXT'} = 1;
    my $res    = $app->request(HTTP::Request->new($method, $url, [], $postdata));
    my $c      = $Thruk::Request::c;
    my $failed = ( $res->code == 200 ? 0 : 1 );
    _debug("_dummy_c() done") if $Thruk::Utils::CLI::verbose >= 2;
    return($c, $failed, $res);
}

##############################################
sub _from_local {
    my($self, $c, $options) = @_;
    _debug("_from_local()") if $Thruk::Utils::CLI::verbose >= 2;
    ## no critic
    $ENV{'NO_EXTERNAL_JOBS'} = 1;
    ## use critic
    return _run_commands($c, $options, 'local');
}

##############################################
sub _from_fcgi {
    my($c, $data_str) = @_;
    confess('no data?') unless defined $data_str;
    $data_str = encode_utf8($data_str);
    my $data  = decode_json($data_str);
    confess('corrupt data?') unless ref $data eq 'HASH';
    $Thruk::Utils::CLI::verbose = $data->{'options'}->{'verbose'} if defined $data->{'options'}->{'verbose'};
    local $ENV{'THRUK_SRC'}          = 'CLI';
    local $ENV{'THRUK_SKIP_CLUSTER'} = 1;

    # ensure secret key is fresh
    my $secret_file = $c->config->{'var_path'}.'/secret.key';
    $c->config->{'secret_key'}  = read_file($secret_file) if -s $secret_file;
    chomp($c->config->{'secret_key'});

    # check credentials
    my $res = {};
    if(   !defined $c->config->{'secret_key'}
       || !defined $data->{'credential'}
       || $c->config->{'secret_key'} ne $data->{'credential'}) {
        my $msg = "authorization failed, ". $c->req->url." does not accept this key.\n";
        if(!defined $data->{'credential'} || $data->{'credential'} eq '') {
            $msg = "authorization failed, no auth key specified for ". $c->req->url."\n";
        }
        $res = {
            'output'  => $msg,
            'rc'      => 1,
        };
    } else {
        $res = _run_commands($c, $data->{'options'}, 'fcgi');
    }
    if(ref $res eq 'HASH') {
        $res->{'version'} = $c->config->{'version'} unless defined $res->{'version'};
        $res->{'branch'}  = $c->config->{'branch'}  unless defined $res->{'branch'};
    }
    my $res_json;
    eval {
        $res_json = encode_json($res);
    };
    if($@) {
        die("unable to encode to json: ".Dumper($res));
    }
    return $res_json;
}

##############################################
sub _run_commands {
    my($c, $opt, $src) = @_;

    if(defined $opt->{'auth'}) {
        Thruk::Utils::set_user($c, $opt->{'auth'});
    } elsif(defined $c->config->{'default_cli_user_name'}) {
        Thruk::Utils::set_user($c, $c->config->{'default_cli_user_name'});
    }

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
        die('no local raw requests!') if $src ne 'fcgi';
        ($data->{'output'}, $data->{'rc'}) = _cmd_raw($c, $opt, $src);
    }

    # precompile templates
    elsif($action eq 'compile') {
        $data->{'output'} = _cmd_precompile($c);
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
            _debug("trying to load module: ".$modname) if $Thruk::Utils::CLI::verbose >= 1;
            undef $err;
            eval {
                load $modname;
            };
            $err = $@;
            last unless $err;

            if($err =~ m|^Can't\ locate\ .*\ in\ \@INC|mx && $err !~ m/Compilation\ failed\ in\ require\ at/mx) {
                _debug($@) if $Thruk::Utils::CLI::verbose >= 1;
                $data->{'output'} = "FAILED - no such command: ".$action.".\n".
                                    "Enabled cli plugins: ".join(", ", @{Thruk::Utils::get_cli_modules()})."\n";
            } elsif($err) {
                _error($@);
                $data->{'output'} = "FAILED - to load command module: ".$action.".\n";
            }
        }
        if($err) {
            $data->{'rc'} = 1;
            return $data;
        }

        # print help only?
        if(scalar @{$opt->{'commandoptions'}} > 0 && $opt->{'commandoptions'}->[0] =~ /^(help|\-h|--help)$/mx) {
            return(get_submodule_help(ucfirst($action)));
        }

        my $skip_backends;
        {
            ## no critic
            no strict 'refs';
            ## use critic
            $skip_backends = ${"Thruk::Utils::CLI::".ucfirst($action)."::skip_backends"};
        }
        if(!defined $c->stash->{'defaults_added'} && !$skip_backends) {
            Thruk::Action::AddDefaults::add_defaults($c, 1);

            # set backends from options
            if(defined $opt->{'backends'} and scalar @{$opt->{'backends'}} > 0) {
                Thruk::Action::AddDefaults::_set_enabled_backends($c, $opt->{'backends'});
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
        `touch $ENV{'THRUK_JOB_DIR'}/stdout`;
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

##########################################################
sub _cmd_configtool {
    my($c, $peerkey, $opt) = @_;
    my $res        = undef;
    my $last_error = undef;

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
        return("failed to set objects model, got configtool section for wrong backend", 1);
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
                $c->log->info('pre save hook: '.$rc);
                $c->log->info('pre save hook: '.$out);
                return("Save canceled by pre save hook!\n".$out, 1);
            }
            $c->log->debug('pre save hook: '.$out);
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
                $c->log->info(sprintf("[config][%s][%s][ext] %s file '%s'",
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
                $c->log->info(sprintf("[config][%s][%s][ext] deleted file '%s'",
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
        # fake remote user unless we have one. renewing the logcache requires
        # a remote user for starting external job
        if(!defined $c->stash->{'remote_user'}) {
            $c->stash->{'remote_user'} = 'cli';
        }
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
        local $ENV{'THRUK_SKIP_CLUSTER'} = 1;
        my $action = $1;
        $opt->{'commandoptions'} = [split/\s+/mx, $2];
        my $res = _run_command_action($c, $opt, $src, $action);
        return([$res->{'output'}], $res->{'rc'});
    }

    # run code
    elsif($function =~ /::/mx) {
        local $ENV{'THRUK_SKIP_CLUSTER'} = 1;
        require Thruk::Utils::Cluster;
        if($opt->{'args'} && ref $opt->{'args'} eq 'ARRAY') {
            for(my $x = 0; $x <= scalar @{$opt->{'args'}}; $x++) {
                if(!ref $opt->{'args'}->[$x] && $opt->{'args'}->[$x]) {
                    if($opt->{'args'}->[$x] eq 'Thruk::Context') {
                        $opt->{'args'}->[$x] = $c;
                    }
                    if($opt->{'args'}->[$x] eq 'Thruk::Utils::Cluster') {
                        $opt->{'args'}->[$x] = $c->cluster;
                    }
                }
            }
        }
        my $pkg_name     = $function;
        $pkg_name        =~ s%::[^:]+$%%mx;
        my $function_ref = \&{$function};
        my @res;
        eval {
            if($pkg_name) {
                load $pkg_name;
            }
            @res = &{$function_ref}(@{$opt->{'args'}});
        };
        if($@) {
            return($@, 1);
        }
        return(\@res, 0);
    }

    local $ENV{'THRUK_USE_LMD'} = ""; # don't try to do LMD stuff since we directly access the real backend
    my @res = Thruk::Backend::Pool::do_on_peer($key, $function, $opt->{'args'});
    my $res = shift @res;

    # add proxy version to processinfo
    if($function eq 'get_processinfo' and defined $res and ref $res eq 'ARRAY' and defined $res->[2] and ref $res->[2] eq 'HASH') {
        $res->[2]->{$key}->{'data_source_version'} .= ' (via Thruk '.$c->config->{'version'}.($c->config->{'branch'}? '~'.$c->config->{'branch'} : '').')';

        # add config tool settings (will be read from Thruk::Backend::Manager::_do_on_peers)
        if($Thruk::Backend::Pool::peers->{$key}->{'config'}->{'configtool'}) {
            my $tmp = $Thruk::Backend::Pool::peers->{$key}->{'config'}->{'configtool'};
            $res->[2]->{$key}->{'configtool'} = {
                'core_type'      => $tmp->{'core_type'},
                'obj_readonly'   => $tmp->{'obj_readonly'},
                'obj_check_cmd'  => exists $tmp->{'obj_check_cmd'},
                'obj_reload_cmd' => exists $tmp->{'obj_reload_cmd'},
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
    if(Thruk::Utils::External::is_running($c, $jobid, 1)) {
        $res = "jobid:".$jobid.":0";
    }
    else {
        #my($out,$err,$time,$dir,$stash,$rc)
        my @res = Thruk::Utils::External::get_result($c, $jobid, 1);
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
    my $config = { 'use_curl' => $ENV{'THRUK_CURL'} };
    my $ua = Thruk::UserAgent->new($config);
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

=head1 EXAMPLES

there are some cli scripting examples in the examples subfolder of the source
package.

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
