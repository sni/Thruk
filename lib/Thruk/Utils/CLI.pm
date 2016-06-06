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
use JSON::XS qw/encode_json decode_json/;
use File::Slurp qw/read_file/;
use Encode qw(encode_utf8);
use Time::HiRes qw/gettimeofday tv_interval/;
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
    $ENV{'THRUK_BACKENDS'}   = join(',', @{$options->{'backends'}}) if(defined $options->{'backends'} and scalar @{$options->{'backends'}} > 0);
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
    Thruk::Utils::Conf::store_model_retention($c) or die("failed to store objects model");
    return;
}

##############################################

=head2 request_url

    request_url($c, $url, $cookies)

returns requested url as string. In list context returns ($code, $result)

=cut
sub request_url {
    my($c, $url, $cookies) = @_;

    # external url?
    if($url =~ m/^https?:/mx) {
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

    my(undef, undef, $res) = _dummy_c(undef, $url);

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

    my $c;
    unless(defined $result) {
        # initialize backend pool here to safe some memory
        require Thruk::Backend::Pool;
        if($self->{'opt'}->{'action'} and $self->{'opt'}->{'action'} =~ m/livecache/mx) {
            local $ENV{'USE_SHADOW_NAEMON'}        = 1;
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
        if(!$ENV{'THRUK_JOB_ID'} && $self->{'opt'}->{'action'} && $self->{'opt'}->{'action'} =~ /^report(\w*)=(.*)$/mx) {
            # create fake job
            my($id,$dir) = Thruk::Utils::External::_init_external($c);
            ## no critic
            $SIG{CHLD} = 'DEFAULT';
            Thruk::Utils::External::_do_parent_stuff($c, $dir, $$, $id, { allow => 'all', background => 1});
            $ENV{'THRUK_JOB_ID'}       = $id;
            $ENV{'THRUK_JOB_DIR'}      = $dir;
            ## use critic
            Thruk::Utils::IO::write($dir.'/stdout', "fake job create\n");
        }
        $result = $self->_from_local($c, $self->{'opt'});
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
    if($result->{'rc'} == 0 or $result->{'all_stdout'}) {
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
    my($self, $url) = @_;
    _debug("_dummy_c()") if $Thruk::Utils::CLI::verbose >= 2;
    delete local $ENV{'PLACK_TEST_EXTERNALSERVER_URI'} if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    $url = '/thruk/cgi-bin/remote.cgi' unless defined $url;
    require Thruk;
    require HTTP::Request;
    require Plack::Test;
    my $app    = Plack::Test->create(Thruk->startup);
    local $ENV{'THRUK_KEEP_CONTEXT'} = 1;
    my $res    = $app->request(HTTP::Request->new(GET => $url));
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
    local $ENV{'THRUK_SRC'}     = 'CLI';

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

    unless(defined $c->stash->{'defaults_added'}) {
        Thruk::Action::AddDefaults::add_defaults($c, 1);
    }
    # set backends from options
    if(defined $opt->{'backends'} and scalar @{$opt->{'backends'}} > 0) {
        Thruk::Action::AddDefaults::_set_enabled_backends($c, $opt->{'backends'});
    }

    my $data = {
        'output'  => '',
        'rc'      => 0,
    };

    # which command to run?
    my @actions = split(/\s*,\s*/mx, ($opt->{'action'} || ''));

    if(scalar @actions == 0 and defined $opt->{'url'} and scalar @{$opt->{'url'}} > 0) {
        push @actions, 'url='.$opt->{'url'}->[0];
    }
    if(scalar @actions == 0 and defined $opt->{'listbackends'}) {
        push @actions, 'listbackends';
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
    $c->stats->profile(begin => "_run_command_action($action)");

    my $data = {
        'output'  => '',
        'rc'      => 0,
    };

    # raw query
    if($action eq 'raw') {
        die('no local raw requests!') if $src ne 'fcgi';
        ($data->{'output'}, $data->{'rc'}) = _cmd_raw($c, $opt);
    }

    # list backends
    elsif($action eq 'listbackends') {
        $data->{'output'} = _cmd_listbackends($c);
    }

    # list hosts
    elsif($action eq 'listhosts') {
        $data->{'output'} = _cmd_listhosts($c);
    }

    # list services
    elsif($action eq 'listservices') {
        $data->{'output'} = _cmd_listservices($c);
    }

    # list hostgroups
    elsif($action eq 'listhostgroups') {
        $data->{'output'} = _cmd_listhostgroups($c);
    }

    # request url
    elsif($action =~ /^url=(.*)$/mx) {
        $data = _cmd_url($c, $1, $opt);
    }

    # report or report mails
    elsif($action =~ /^report(\w*)=(.*)$/mx) {
        ($data->{'output'}, $data->{'rc'}) = _cmd_report($c, $1, $2);
    }

    # downtime?
    elsif($action =~ /^downtimetask=(.*)$/mx) {
        ($data->{'output'}, $data->{'rc'}) = _cmd_downtimetask($c, $1);
    }

    # install cron
    elsif($action eq 'installcron') {
        $data->{'output'} = _cmd_installcron($c);
    }

    # uninstall cron
    elsif($action eq 'uninstallcron') {
        $data->{'output'} = _cmd_uninstallcron($c);
    }

    # precompile templates
    elsif($action eq 'compile') {
        $data->{'output'} = _cmd_precompile($c);
    }

    # get commands
    elsif($action eq 'command') {
        $data->{'output'} = _cmd_command($c, $opt);
    }

    # business process daemon
    elsif($action eq 'bpd' or $action eq 'bp' or $action eq 'bpcommit') {
        ($data->{'output'}, $data->{'rc'}) = _cmd_bpd($c, $opt, $action);
    }

    # dashboard cleanup
    elsif($action eq 'clean_dashboards') {
        ($data->{'output'}, $data->{'rc'}) = _cmd_panorama($c, $action);
    }

    # cache actions
    elsif($action eq 'dumpcache') {
        $data->{'rc'} = 0;
        $data->{'output'} = Dumper($c->cache->dump);
    }
    elsif($action eq 'clearcache') {
        $data->{'rc'} = 0;
        unlink($c->config->{'tmp_path'}.'/thruk.cache');
        $data->{'output'} = "cache cleared";
    }

    # import mysql logs
    elsif($action =~ /logcacheimport($|=(\d+))/mx) {
        ($data->{'output'}, $data->{'rc'}) = _cmd_import_logs($c, 'import', $src, $2, $opt);
    }
    elsif($action eq 'logcacheupdate') {
        ($data->{'output'}, $data->{'rc'}) = _cmd_import_logs($c, 'update', $src, undef, $opt);
    }
    elsif($action eq 'logcachestats') {
        ($data->{'output'}, $data->{'rc'}) = _cmd_import_logs($c, 'stats', $src, undef, $opt);
    }
    elsif($action eq 'logcacheauthupdate') {
        ($data->{'output'}, $data->{'rc'}) = _cmd_import_logs($c, 'authupdate', $src, undef, $opt);
    }
    elsif($action eq 'logcacheoptimize') {
        ($data->{'output'}, $data->{'rc'}) = _cmd_import_logs($c, 'optimize', $src, undef, $opt);
    }
    elsif($action =~ /logcacheclean($|=(\d+))/mx) {
        ($data->{'output'}, $data->{'rc'}) = _cmd_import_logs($c, 'clean', $src, $2, $opt);
    }
    elsif($action =~ /logcacheremoveunused/mx) {
        ($data->{'output'}, $data->{'rc'}) = _cmd_import_logs($c, 'removeunused', $src, $2, $opt);
    }

    # livestatus proxy cache
    elsif($action =~ /livecache(start|stop|status|restart)/mx) {
        ($data->{'output'}, $data->{'rc'}) = _cmd_livecache($c, $1, $src);
    }

    # self check
    elsif($action eq 'selfcheck' or $action =~ /^selfcheck=(.*)$/mx) {
        ($data->{'output'}, $data->{'rc'}) = _cmd_selfcheck($c, $1);
        $data->{'all_stdout'} = 1;
    }

    # core reschedule?
    elsif($action =~ /^fix_scheduling=?(.*)$/mx) {
        ($data->{'output'}, $data->{'rc'}) = _cmd_fix_scheduling($c, $1);
    }

    # graph actions
    elsif($action eq 'graph') {
        ($data->{'output'}, $data->{'rc'}) = _cmd_graph($c, $opt);
    }

    # nothing matched...
    else {
        $data->{'output'} = "FAILED - no such command: ".$action.". Run with --help to see a list of commands.\n";
        $data->{'rc'}     = 1;
    }

    $c->stats->profile(end => "_run_command_action($action)");

    if($ENV{'THRUK_JOB_DIR'}) {
        Thruk::Utils::External::save_profile($c, $ENV{'THRUK_JOB_DIR'}) if $ENV{'THRUK_JOB_DIR'};
        `touch $ENV{'THRUK_JOB_DIR'}/stdout`;
    }

    return $data;
}

##############################################
sub _cmd_listhosts {
    my($c) = @_;
    my $output = '';
    for my $host (@{$c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' )], sort => {'ASC' => 'name'})}) {
        $output .= $host->{'name'}."\n";
    }

    return($output);
}

##############################################
sub _cmd_listservices {
    my($c) = @_;
    my $output = '';
    for my $svc (@{$c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' )], sort => {'ASC' => [ 'host_name', 'description' ] })}) {
        $output .= $svc->{'host_name'}.";".$svc->{'description'}."\n";
    }

    return($output);
}

##############################################
sub _cmd_listhostgroups {
    my($c) = @_;
    my $output = '';
    for my $group (@{$c->{'db'}->get_hostgroups(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' )], sort => {'ASC' => 'name'})}) {
        $output .= sprintf("%-30s %s\n", $group->{'name'}, join(',', @{$group->{'members'}}));
    }

    return($output);
}

##############################################
sub _cmd_listbackends {
    my($c) = @_;
    $c->{'db'}->enable_backends();
    eval {
        $c->{'db'}->get_processinfo();
    };
    _debug($@) if $@;
    Thruk::Action::AddDefaults::_set_possible_backends($c, {});
    my $output = '';
    $output .= sprintf("%-4s  %-7s  %-9s   %s\n", 'Def', 'Key', 'Name', 'Address');
    $output .= sprintf("-------------------------------------------------\n");
    for my $key (@{$c->stash->{'backends'}}) {
        my $peer = $c->{'db'}->get_peer_by_key($key);
        my $addr = $c->stash->{'backend_detail'}->{$key}->{'addr'};
        $addr    =~ s|/cgi-bin/remote.cgi$||mx;
        $output .= sprintf("%-4s %-8s %-10s %s",
                (!defined $peer->{'hidden'} || $peer->{'hidden'} == 0) ? ' * ' : '',
                $key,
                $c->stash->{'backend_detail'}->{$key}->{'name'},
                $addr,
        );
        my $error = defined $c->stash->{'backend_detail'}->{$key}->{'last_error'} ? $c->stash->{'backend_detail'}->{$key}->{'last_error'} : '';
        chomp($error);
        $output .= " (".$error.")" if $error;
        $output .= "\n";
    }
    $output .= sprintf("-------------------------------------------------\n");

    return $output;
}

##############################################
sub _cmd_installcron {
    my($c) = @_;
    $c->stats->profile(begin => "_cmd_installcron()");
    Thruk::Utils::switch_realuser($c);
    require Thruk::Utils::RecurringDowntimes;
    Thruk::Utils::RecurringDowntimes::update_cron_file($c);
    if($c->config->{'use_feature_reports'}) {
        require Thruk::Utils::Reports;
        Thruk::Utils::Reports::update_cron_file($c);
    }
    if($c->config->{'use_feature_bp'}) {
        require Thruk::BP::Utils;
        Thruk::BP::Utils::update_cron_file($c);
    }
    $c->stats->profile(end => "_cmd_installcron()");
    return "updated cron entries\n";
}

##############################################
sub _cmd_uninstallcron {
    my($c) = @_;
    $c->stats->profile(begin => "_cmd_uninstallcron()");
    Thruk::Utils::switch_realuser($c);
    Thruk::Utils::update_cron_file($c);
    $c->stats->profile(end => "_cmd_uninstallcron()");
    return "cron entries removed\n";
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
sub _cmd_command {
    my($c, $opt) = @_;
    $c->stats->profile(begin => "_cmd_command()");
    my $hostname    = $opt->{'url'}->[0];
    my $description = $opt->{'url'}->[1];

    my $backend = $opt->{'backends'}->[0] || '';
    my($host, $service);

    my $hosts = $c->{'db'}->get_hosts( filter => [ { 'name' => $hostname } ] );
    $host = $hosts->[0];
    # we have more and backend param is used
    if( scalar @{$hosts} == 1 and defined $backend ) {
        for my $h ( @{$hosts} ) {
            if( $h->{'peer_key'} eq $backend ) {
                $host = $h;
                last;
            }
        }
    }
    if(!$host) {
        return "no such host '".$hostname."'\n";
    }

    if($description) {
        my $services = $c->{'db'}->get_services( filter => [{ 'host_name' => $hostname }, { 'description' => $description }, ] );
        $service = $services->[0];
        # we have more and backend param is used
        if( scalar @{$services} == 1 and defined $services ) {
            for my $s ( @{$services} ) {
                if( $s->{'peer_key'} eq $backend ) {
                    $service = $s;
                    last;
                }
            }
        }
        if(!$service) {
            return "no such service '".$description."' on host '".$hostname."'\n";
        }
    }

    my $command = $c->{'db'}->expand_command('host' => $host, 'service' => $service, 'source' => $c->config->{'show_full_commandline_source'} );
    my $msg;
    $msg .= 'Note:            '.$command->{'note'}."\n" if $command->{'note'};
    $msg .= 'Check Command:   '.$command->{'line'}."\n";
    $msg .= 'Expaned Command: '.$command->{'line_expanded'}."\n";

    $c->stats->profile(end => "_cmd_command()");
    return $msg;
}

##############################################
sub _cmd_report {
    my($c, $mail, $nr) = @_;

    $c->stats->profile(begin => "_cmd_report()");

    my $output;
    eval {
        require Thruk::Utils::Reports;
    };
    if($@) {
        return("reports plugin is not enabled.\n", 1);
    }
    my $logfile = $c->config->{'var_path'}.'/reports/'.$nr.'.log';
    # set waiting flag for queued reports, so the show up nicely in the gui
    Thruk::Utils::Reports::process_queue_file($c);
    if($mail eq 'mail') {
        if(Thruk::Utils::Reports::queue_report_if_busy($c, $nr, 1)) {
            $output = "report queued successfully\n";
        }
        elsif(Thruk::Utils::Reports::report_send($c, $nr)) {
            $output = "mail send successfully\n";
        } else {
            return("cannot send mail\n", 1)
        }
    } else {
        if(Thruk::Utils::Reports::queue_report_if_busy($c, $nr)) {
            $output = "report queued successfully\n";
        } else {
            my $report_file = Thruk::Utils::Reports::generate_report($c, $nr);
            if(defined $report_file and -f $report_file) {
                $output = read_file($report_file);
            } else {
                my $errors = read_file($logfile);
                return("generating report failed:\n".$errors, 1);
            }
        }
    }

    $c->stats->profile(end => "_cmd_report()");
    return($output, 0);
}

##############################################
sub _cmd_bpd {
    my($c, $opt, $action) = @_;
    $c->stats->profile(begin => "_cmd_bpd($action)");

    if(!$c->config->{'use_feature_bp'}) {
        return("ERROR - business process addon is disabled\n", 1);
    }

    eval {
        require Thruk::BP::Utils;
    };
    if($@) {
        _debug($@) if $Thruk::Utils::CLI::verbose >= 1;
        return("business process plugin is disabled.\n", 1);
    }

    if($action eq 'bpcommit') {
        my $bps = Thruk::BP::Utils::load_bp_data($c);
        my($rc,$msg) = Thruk::BP::Utils::save_bp_objects($c, $bps);
        if($rc != 0) {
            $c->stats->profile(end => "_cmd_bpd($action)");
            return($msg, $rc);
        }
        Thruk::BP::Utils::update_cron_file($c); # check cronjob
        $c->stats->profile(end => "_cmd_bpd($action)");
        return('OK - wrote '.(scalar @{$bps})." business process(es)\n", 0);
    }

    # calculate bps
    my $id;
    if($opt->{'url'} and $opt->{'url'}->[0]) {
        $id = $opt->{'url'}->[0];
    }

    my $last_bp;
    my $rate = int($c->config->{'Thruk::Plugin::BP'}->{'refresh_interval'} || 1);
    if($rate <  1) { $rate =  1; }
    if($rate > 60) { $rate = 60; }
    my $timeout = ($rate*60) -5;
    local $SIG{ALRM} = sub { die("hit ".$timeout."s timeout on ".($last_bp ? $last_bp->{'name'} : 'unknown')) };
    alarm($timeout);

    # enable all backends for now till configuration is possible for each BP
    $c->{'db'}->enable_backends();

    my $t0 = [gettimeofday];
    my $bps = Thruk::BP::Utils::load_bp_data($c, $id);
    for my $bp (@{$bps}) {
        $last_bp = $bp;
        _debug("updating: ".$bp->{'name'}) if $Thruk::Utils::CLI::verbose >= 1;
        $bp->update_status($c);
        _debug("OK") if $Thruk::Utils::CLI::verbose >= 1;
    }
    alarm(0);
    my $nr = scalar @{$bps};
    my $elapsed = tv_interval($t0);
    my $output = sprintf("OK - %d business processes updated in %.2fs\n", $nr, $elapsed);

    $c->stats->profile(end => "_cmd_bpd($action)");
    return($output, 0);
}

##############################################
sub _cmd_panorama {
    my($c, $action) = @_;
    $c->stats->profile(begin => "_cmd_panorama($action)");

    if(!$c->config->{'use_feature_panorama'}) {
        return("ERROR - panorama dashboard addon is disabled\n", 1);
    }

    eval {
        require Thruk::Utils::Panorama;
    };
    if($@) {
        _debug($@) if $Thruk::Utils::CLI::verbose >= 1;
        return("panorama plugin is disabled.\n", 1);
    }

    if($action eq 'clean_dashboards') {
        $c->stash->{'is_admin'} = 1;
        $c->{'panorama_var'}    = $c->config->{'var_path'}.'/panorama';
        my $num = Thruk::Utils::Panorama::clean_old_dashboards($c);
        return("OK - cleaned up $num old dashboards\n", 0);
    }

    $c->stats->profile(end => "_cmd_panorama($action)");
    return("unknown panorma command", 1);
}

##############################################
sub _cmd_fix_scheduling {
    my($c, $filter) = @_;

    if(!$c->config->{'use_feature_core_scheduling'}) {
        return("ERROR - core_scheduling addon is disabled\n", 1);
    }

    eval {
        require Thruk::Controller::core_scheduling;
    };
    if($@) {
        _debug($@) if $Thruk::Utils::CLI::verbose >= 1;
        return("core_scheduling plugin is disabled.\n", 1);
    }

    $c->stats->profile(begin => "_cmd_fix_scheduling()");

    my $hostfilter;
    my $servicefilter;
    if($filter) {
        if($filter =~ m/^hg:(.*)$/mx) {
            $hostfilter    = { 'groups'      => { '>=' => $1 } };
            $servicefilter = { 'host_groups' => { '>=' => $1 } };
        }
        elsif($filter =~ m/^sg:(.*)$/mx) {
            $servicefilter = { 'groups'      => { '>=' => $1 } };
        }
        else {
            return("filter must be either hg:<hostgroup> or sg:<servicegroup>\n", 1);
        }
    }
    Thruk::Utils::set_user($c, '(cron)') unless $c->user_exists;
    Thruk::Controller::core_scheduling::reschedule_everything($c, $hostfilter, $servicefilter);

    $c->stats->profile(end => "_cmd_fix_scheduling()");
    return($c->stash->{message}."\n", 0);
}

##############################################
sub _cmd_downtimetask {
    my($c, $file) = @_;
    $c->stats->profile(begin => "_cmd_downtimetask()");
    require URI::Escape;
    require Thruk::Utils::RecurringDowntimes;

    my $total_retries = 5;
    my $retries;

    # do auth stuff
    for($retries = 0; $retries < $total_retries; $retries++) {
        sleep(10) if $retries > 0;
        eval {
            Thruk::Utils::set_user($c, '(cron)') unless $c->user_exists;
        };
        last unless $@;
    }

    $file          = $c->config->{'var_path'}.'/downtimes/'.$file.'.tsk';
    my $downtime   = Thruk::Utils::read_data_file($file);
    my $default_rd = Thruk::Utils::RecurringDowntimes::get_default_recurring_downtime($c);
    for my $key (keys %{$default_rd}) {
        $downtime->{$key} = $default_rd->{$key} unless defined $downtime->{$key};
    }

    # do quick self check
    Thruk::Utils::RecurringDowntimes::check_downtime($c, $downtime, $file);

    my $start    = time();
    my $end      = $start + ($downtime->{'duration'}*60);
    my $hours    = 0;
    my $minutes  = 0;
    my $flexible = '';
    if($downtime->{'fixed'} == 0) {
        $flexible = ' flexible';
        $end      = $start + $downtime->{'flex_range'}*60;
        $hours    = int($downtime->{'duration'} / 60);
        $minutes  = $downtime->{'duration'}%60;
    }

    my $output     = '';
    if(!$downtime->{'target'}) {
        $downtime->{'target'} = 'host';
        $downtime->{'target'} = 'service' if $downtime->{'service'};
    }

    $downtime->{'host'}         = [$downtime->{'host'}]         unless ref $downtime->{'host'}         eq 'ARRAY';
    $downtime->{'hostgroup'}    = [$downtime->{'hostgroup'}]    unless ref $downtime->{'hostgroup'}    eq 'ARRAY';
    $downtime->{'servicegroup'} = [$downtime->{'servicegroup'}] unless ref $downtime->{'servicegroup'} eq 'ARRAY';

    my $done = {hosts => {}, groups => {}};
    my($backends, $cmd_typ) = Thruk::Utils::RecurringDowntimes::get_downtime_backends($c, $downtime);
    my $errors = 0;
    for($retries = 0; $retries < $total_retries; $retries++) {
        sleep(10) if $retries > 0;
        if($downtime->{'target'} eq 'host' or $downtime->{'target'} eq 'service') {
            my $hosts = $downtime->{'host'};
            for my $hst (@{$hosts}) {
                next if $done->{'hosts'}->{$hst};
                $downtime->{'host'} = $hst;
                my $rc;
                eval {
                    $rc = set_downtime($c, $downtime, $cmd_typ, $backends, $start, $end, $hours, $minutes);
                };
                if($rc && !$@) {
                    $errors-- if defined $done->{'hosts'}->{$hst};
                    $done->{'hosts'}->{$hst} = 1;
                } else {
                    $errors++ unless defined $done->{'hosts'}->{$hst};
                    $done->{'hosts'}->{$hst} = 0;
                }
            }
            $downtime->{'host'} = $hosts;
        }
        elsif($downtime->{'target'} eq 'hostgroup' or $downtime->{'target'} eq 'servicegroup') {
            my $grps = $downtime->{$downtime->{'target'}};
            for my $grp (@{$grps}) {
                next if $done->{'groups'}->{$grp};
                $downtime->{$downtime->{'target'}} = $grp;
                my $rc;
                eval {
                    $rc = set_downtime($c, $downtime, $cmd_typ, $backends, $start, $end, $hours, $minutes);
                };
                if($rc && !$@) {
                    $errors-- if defined $done->{'groups'}->{$grp};
                    $done->{'groups'}->{$grp} = 1;
                } else {
                    $errors++ unless defined $done->{'groups'}->{$grp};
                    $done->{'groups'}->{$grp} = 0;
                }
            }
            $downtime->{$downtime->{'target'}} = $grps;
        }
        last unless $errors;
    }

    return("recurring downtime ".$file." failed after $retries retries, find details in the thruk.log file.\n", 1) if $errors; # error is already printed

    if($downtime->{'service'}) {
        $output = 'scheduled'.$flexible.' downtime for service \''.$downtime->{'service'}.'\' on host: \''.join(', ', @{$downtime->{'host'}}).'\'';
    } else {
        $output = 'scheduled'.$flexible.' downtime for '.$downtime->{'target'}.': \''.join(', ', @{$downtime->{$downtime->{'target'}}}).'\'';
    }
    $output .= " (duration ".Thruk::Utils::Filter::duration($downtime->{'duration'}*60).")";
    $output .= " (after $retries retries)\n" if $retries;
    $output .= "\n";

    $c->stats->profile(end => "_cmd_downtimetask()");
    return($output, 0);
}

##############################################

=head2 set_downtime

    set_downtime($c, $downtime, $cmd_typ, $backends, $start, $end, $hours, $minutes)

set downtime.

    downtime is a hash like this:
    {
        author  => 'downtime author'
        host    => 'host name'
        service => 'optional service name'
        comment => 'downtime comment'
        fixed   => 1
    }

    cmd_typ is:
         55 -> hosts
         56 -> services
         84 -> hostgroups
        122 -> servicegroups

=cut
sub set_downtime {
    my($c, $downtime, $cmd_typ, $backends, $start, $end, $hours, $minutes) = @_;

    # convert to normal url request
    my $product = $c->config->{'product_prefix'} || 'thruk';
    my $url = sprintf('/'.$product.'/cgi-bin/cmd.cgi?cmd_mod=2&cmd_typ=%d&com_data=%s&com_author=%s&trigger=0&start_time=%s&end_time=%s&fixed=%s&hours=%s&minutes=%s&backend=%s%s%s%s%s%s',
                      $cmd_typ,
                      URI::Escape::uri_escape_utf8($downtime->{'comment'}),
                      URI::Escape::uri_escape_utf8(defined $downtime->{'author'} ? $downtime->{'author'} : '(cron)'),
                      URI::Escape::uri_escape_utf8(Thruk::Utils::format_date($start, '%Y-%m-%d %H:%M:%S')),
                      URI::Escape::uri_escape_utf8(Thruk::Utils::format_date($end, '%Y-%m-%d %H:%M:%S')),
                      $downtime->{'fixed'},
                      $hours,
                      $minutes,
                      join(',', @{$backends}),
                      defined $downtime->{'childoptions'} ? '&childoptions='.$downtime->{'childoptions'} : '',
                      $downtime->{'host'} ? '&host='.URI::Escape::uri_escape_utf8($downtime->{'host'}) : '',
                      $downtime->{'service'} ? '&service='.URI::Escape::uri_escape_utf8($downtime->{'service'}) : '',
                      (ref $downtime->{'hostgroup'} ne 'ARRAY' and $downtime->{'hostgroup'}) ? '&hostgroup='.URI::Escape::uri_escape_utf8($downtime->{'hostgroup'}) : '',
                      (ref $downtime->{'servicegroup'} ne 'ARRAY' and $downtime->{'servicegroup'}) ? '&servicegroup='.URI::Escape::uri_escape_utf8($downtime->{'servicegroup'}) : '',
                     );
    local $ENV{'THRUK_SRC'} = 'CLI';
    my $old = $c->config->{'cgi_cfg'}->{'lock_author_names'};
    $c->config->{'cgi_cfg'}->{'lock_author_names'} = 0;
    my @res = request_url($c, $url);
    $c->config->{'cgi_cfg'}->{'lock_author_names'} = $old;
    return 0 if $res[0] != 200; # error is already printed
    return 1;
}

##############################################
sub _cmd_url {
    my($c, $url, $opt) = @_;
    $c->stats->profile(begin => "_cmd_url()");

    if($opt->{'all_inclusive'} && !$c->config->{'use_feature_reports'}) {
        return({output => "all-inclusive options requires the reports plugin to be enabled", rc => 1});
    }

    if($url =~ m|^\w+\.cgi|gmx) {
        my $product = $c->config->{'product_prefix'} || 'thruk';
        $url = '/'.$product.'/cgi-bin/'.$url;
    }
    my @res = request_url($c, $url);

    # All Inclusive?
    if($res[0] == 200 && $res[1]->{'result'} && $opt->{'all_inclusive'}) {
        require Thruk::Utils::Reports::Render;
        $res[1]->{'result'} = Thruk::Utils::Reports::Render::html_all_inclusive($c, $url, $res[1]->{'result'}, 1);
    }

    my $content_type;
    if($res[1] && $res[1]->{'headers'}) {
        $content_type = $res[1]->{'headers'}->{'content-type'};
    }

    $c->stats->profile(end => "_cmd_url()");
    my $rc = $res[0] >= 400 ? 1 : 0;
    return({output => $res[2], rc => $rc, 'content_type' => $content_type}) if $res[2];
    if($res[1]->{'result'} =~ m/\Q<div class='infoMessage'>Your command request was successfully submitted to the Backend for processing.\E/gmx) {
        return({output => "Command request successfully submitted to the Backend for processing\n", rc => $rc});
    }
    return({output => $res[1]->{'result'}, rc => $rc, 'content_type' => $content_type});
}

##############################################
sub _cmd_import_logs {
    my($c, $mode, $src, $blocksize, $opt) = @_;
    $c->stats->profile(begin => "_cmd_import_logs()");

    if(!defined $c->config->{'logcache'}) {
        return("FAILED - logcache is not enabled\n", 1);
    }

    if($src ne 'local' and $mode eq 'import') {
        return("ERROR - please run the initial import with --local\n", 1);
    }
    if($mode eq 'import' && !$opt->{'yes'}) {
        local $|=1;
        print "import removes current cache and imports new logfile data.\n";
        print "use logcacheupdate to update cache. Continue? [n]: ";
        my $buf;
        sysread STDIN, $buf, 1;
        if($buf !~ m/^(y|j)/mxi) {
            return("canceled\n", 1);
        }
    }

    my $type = '';
    $type = 'mysql' if $c->config->{'logcache'} =~ m/^mysql/mxi;

    my $verbose = 0;
    $verbose = 1 if $src eq 'local';

    eval {
        if($type eq 'mysql') {
            require Thruk::Backend::Provider::Mysql;
            Thruk::Backend::Provider::Mysql->import;
        } else {
            die("unknown logcache type: ".$type);
        }
    };
    if($@) {
        return("FAILED - failed to load ".$type." support: ".$@."\n", 1);
    }

    if($mode eq 'stats') {
        my $stats;
        if($type eq 'mysql') {
            $stats= Thruk::Backend::Provider::Mysql->_log_stats($c);
        } else {
            die("unknown logcache type: ".$type);
        }
        $c->stats->profile(end => "_cmd_import_logs()");
        Thruk::Backend::Manager::close_logcache_connections($c);
        return($stats."\n", 0);
    }
    elsif($mode eq 'removeunused') {
        if($type eq 'mysql') {
            my $stats= Thruk::Backend::Provider::Mysql->_log_removeunused($c);
            Thruk::Backend::Manager::close_logcache_connections($c);
            $c->stats->profile(end => "_cmd_import_logs()");
            return($stats."\n", 0);
        }
        Thruk::Backend::Manager::close_logcache_connections($c);
        $c->stats->profile(end => "_cmd_import_logs()");
        return($type." logcache does not support this operation\n", 1);
    } else {
        my $t0 = [gettimeofday];
        my($backend_count, $log_count, $errors);
        if($type eq 'mysql') {
            ($backend_count, $log_count, $errors) = Thruk::Backend::Provider::Mysql->_import_logs($c, $mode, $verbose, undef, $blocksize, $opt);
        } else {
            die("unknown logcache type: ".$type);
        }
        my $elapsed = tv_interval($t0);
        $c->stats->profile(end => "_cmd_import_logs()");
        my $plugin_ref_count;
        if($mode eq 'clean') {
            $plugin_ref_count = $log_count->[1];
            $log_count        = $log_count->[0];
        }
        my $action = "imported";
        $action    = "updated" if $mode eq 'authupdate';
        $action    = "removed" if $mode eq 'clean';
        Thruk::Backend::Manager::close_logcache_connections($c);
        return("\n", 1) if $log_count == -1;
        my($rc, $msg) = (0, 'OK');
        my $res = 'successfully';
        if(scalar @{$errors} > 0) {
            $res = 'with '.scalar @{$errors}.' errors';
            ($rc, $msg) = (1, 'ERROR');
        }
        my $details = '';
        if(!$verbose) {
            # already printed if verbose
            $details = join("\n", @{$errors})."\n";
        }
        return(sprintf("%s - %s %i log items %sfrom %i site%s %s in %.2fs (%i/s)\n%s",
                       $msg,
                       $action,
                       $log_count,
                       $plugin_ref_count ? "(and ".$plugin_ref_count." plugin ouput references) " : '',
                       $backend_count,
                       ($backend_count == 1 ? '' : 's'),
                       $res,
                       ($elapsed),
                       (($elapsed > 0 && $log_count > 0) ? ($log_count / ($elapsed)) : $log_count),
                       $details,
                       ), $rc);
    }
}

##############################################
sub _cmd_livecache {
    my($c, $mode, $src) = @_;
    $c->stats->profile(begin => "_cmd_livecache($mode)");

    if($src ne 'local' and $mode ne 'status') {
        return("ERROR - please run with --local only\n", 1);
    }

    Thruk::Backend::Pool::init_backend_thread_pool();

    if($mode eq 'start') {
        Thruk::Utils::Livecache::check_shadow_naemon_procs($c->config, $c, 0, 1);
        # wait for the startup
        my($status, $started);
        for(my $x = 0; $x <= 20; $x++) {
            eval {
                ($status, $started) = Thruk::Utils::Livecache::status_shadow_naemon_procs($c->config);
            };
            last if($status && scalar @{$status} == $started);
            sleep(1);
        }
        return("OK - livecache started\n", 0) if(defined $started and $started > 0);
        return("FAILED - starting livecache failed\n", 1);
    }
    elsif($mode eq 'stop') {
        Thruk::Utils::Livecache::shutdown_shadow_naemon_procs($c->config);
        # wait for the fully stopped
        my($status, $started, $total, $failed);
        for(my $x = 0; $x <= 20; $x++) {
            eval {
                ($status, $started) = Thruk::Utils::Livecache::status_shadow_naemon_procs($c->config);
                ($total, $failed) = _get_shadownaemon_totals($c, $status);
            };
            last if(defined $started && $started == 0 && defined $total && $total == $failed);
            sleep(1);
        }
    }
    elsif($mode eq 'restart') {
        Thruk::Utils::Livecache::restart_shadow_naemon_procs($c, $c->config);
        # wait for the startup
        my($status, $started);
        for(my $x = 0; $x <= 20; $x++) {
            eval {
                ($status, $started) = Thruk::Utils::Livecache::status_shadow_naemon_procs($c->config);
            };
            last if($status && scalar @{$status} == $started);
            sleep(1);
        }
    }

    my($status, $started) = Thruk::Utils::Livecache::status_shadow_naemon_procs($c->config);
    $c->stats->profile(end => "_cmd_livecache($mode)");
    if(scalar @{$status} == 0) {
        return("UNKNOWN - livecache not enabled for any backend\n", 3);
    }
    if(scalar @{$status} == $started) {
        my($total, $failed) = _get_shadownaemon_totals($c, $status);
        return("OK - $started/$started livecache running, ".($total-$failed)."/".$total." online\n", 0);
    }
    if($started == 0) {
        return("STOPPED - $started livecache running\n", $mode eq 'stop' ? 0 : 2);
    }
    return("WARNING - $started/".(scalar @{$status})." livecache running\n", 1);
}

##########################################################
sub _get_shadownaemon_totals {
    my($c, $status) = @_;
    # get number of online sites
    my $sites = [];
    for my $site (@{$status}) { push @{$sites}, $site->{'key'}; }
    $c->{'db'}->reset_failed_backends();
    $c->{'db'}->enable_backends($sites);
    my $total  = scalar @{$sites};
    my $failed = $total;
    eval {
        $c->{'db'}->get_processinfo(backend => $sites);
        $failed = scalar keys %{$c->stash->{'failed_backends'}};
    };
    return($total, $failed);
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
            local $ENV{REMOTE_USER} = $c->stash->{'remote_user'};
            local $SIG{CHLD}        = 'DEFAULT';
            my $cmd = $c->config->{'Thruk::Plugin::ConfigTool'}->{'pre_obj_save_cmd'}." pre '".$filesroot."' 2>&1";
            $c->log->debug('pre save hook: '.$cmd);
            my $out = `$cmd`;
            my $rc  = $?>>8;
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
            local $ENV{REMOTE_USER} = $c->stash->{'remote_user'};
            local $SIG{CHLD}        = 'DEFAULT';
            system($c->config->{'Thruk::Plugin::ConfigTool'}->{'post_obj_save_cmd'}, 'post', $filesroot);
        }
    } else {
        return("unknown configtool command", 1);
    }
    return([undef, 1, $res, $last_error], 0);
}

##############################################
sub _cmd_raw {
    my($c, $opt) = @_;
    my $function  = $opt->{'sub'};

    unless(defined $c->stash->{'defaults_added'}) {
        Thruk::Action::AddDefaults::add_defaults(1, undef, "Thruk::Controller::remote", $c);
    }
    my @keys = @{$Thruk::Backend::Pool::peer_order};
    my $key = $keys[0];
    # do we have a hint about remote peer?
    if($opt->{'remote_name'}) {
        my $peer = $c->{'db'}->get_peer_by_name($opt->{'remote_name'});
        die('no such backend: '.$opt->{'remote_name'}) unless defined $peer;
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
sub _cmd_selfcheck {
    my($c, $type) = @_;
    $c->stats->profile(begin => "_cmd_selfcheck()");
    $type = 'all' unless $type;

    require Thruk::Utils::SelfCheck;
    my($rc, $msg, $details) = Thruk::Utils::SelfCheck->self_check($c, $type);

    $c->stats->profile(end => "_cmd_selfcheck()");
    return($msg."\n".$details."\n", $rc);
}

##############################################
sub _cmd_graph {
    my($c, $opt) = @_;
    my $now = time();
    if(!defined $c->stash->{'remote_user'}) {
        $c->stash->{'remote_user'} = 'cli';
    }
    my $start  = ($opt->{'start'} || $now-86400);
    my $end    = ($opt->{'end'}   || $now);
    # if no start / end given, round to nearest 10 seconds which makes caching more effective
    if(!$opt->{'start'} && !$opt->{'end'}) {
        $start = $start - $start % 10;
        $end   = $end   - $end   % 10;
    }
    my $format = $opt->{'format'} || 'png';
    my $width  = $opt->{'width'}  || 800;
    my $height = $opt->{'height'} || 300;
    if($format ne 'png' && $format ne 'base64') {
        return("ERROR: please use either 'png' or 'base64' format.", 1);
    }
    # use cached version?
    Thruk::Utils::IO::mkdir($c->config->{'tmp_path'}.'/graphs/');
    my $cache_file = $opt->{'host'}.'_'.($opt->{'service'} || '_HOST_');
    $cache_file =~ s|[^\a-zA-A_-]|.|gmx;
    $cache_file = $cache_file.'-'.$start.'-'.$end.'-'.($opt->{'source'}||'').'-'.$width.'-'.$height.'.'.$format;
    $cache_file = $c->config->{'tmp_path'}.'/graphs/'.$cache_file;
    if(-e $cache_file) {
        _debug("cache hit from ".$cache_file) if $Thruk::Utils::CLI::verbose >= 2;
        return(scalar read_file($cache_file), 0);
    }

    # create new image
    my $img = Thruk::Utils::get_perf_image($c,
                                           $opt->{'host'},
                                           $opt->{'service'},
                                           $start,
                                           $end,
                                           $width,
                                           $height,
                                           $opt->{'source'},
                                        );
    return("", 1) unless $img;
    if($format eq 'base64') {
        require MIME::Base64;
        $img = MIME::Base64::encode_base64($img);
    }
    Thruk::Utils::IO::write($cache_file, $img);
    _debug("cached graph to ".$cache_file) if $Thruk::Utils::CLI::verbose >= 2;

    # clean old cached files, threshold is 5minutes, since we mainly
    # want to cache files used from many seriel notifications
    for my $file (glob($c->config->{'tmp_path'}.'/graphs/*')) {
        my $mtime = (stat($file))[9];
        if($mtime < $now - 300) {
            _debug("removed old cached file (mtime: ".scalar($mtime)."): ".$file) if $Thruk::Utils::CLI::verbose >= 2;
            unlink($file);
        }
    }
    return($img, 0);
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
