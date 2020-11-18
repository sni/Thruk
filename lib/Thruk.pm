package Thruk;

=head1 NAME

Thruk - Monitoring Web Interface

=head1 DESCRIPTION

Monitoring web interface for Naemon, Nagios, Icinga and Shinken.

=cut

use strict;
use warnings;
use Cwd qw/abs_path/;
use Time::HiRes;
use Carp qw/confess longmess/;  $Carp::MaxArgLen = 500;
use File::Slurp qw(read_file);
use Module::Load qw/load/;
use Data::Dumper qw/Dumper/;    $Data::Dumper::Sortkeys = 1;
use Plack::Util ();
use POSIX ();

use 5.008000;

our $VERSION = '2.38';

###################################################
# load timing class
#use Thruk::Timer qw/timing_breakpoint/;
#&timing_breakpoint('starting thruk');

###################################################
# clean up env
my $tt_profiling = 0;
BEGIN {
    ## no critic
    if($ENV{'THRUK_VERBOSE'} and $ENV{'THRUK_VERBOSE'} >= 3) {
        $ENV{'THRUK_PERFORMANCE_DEBUG'} = 3;
    }
    use Time::HiRes qw/gettimeofday tv_interval/;
    eval "use Thruk::Template::Context;" if $ENV{'THRUK_PERFORMANCE_DEBUG'};
    eval "use Thruk::Template::Exception;" if $ENV{'TEST_AUTHOR'};
    ## use critic
    $tt_profiling = 1 if $ENV{'THRUK_PERFORMANCE_DEBUG'};
}

use Thruk::Base qw/:all/;
use Thruk::Config ();
use Thruk::Constants ':add_defaults';
use Thruk::Utils::Log qw/:all/;
use Thruk::Utils::IO ();

###################################################
our $cluster;
our $COUNT = 0;
our $thruk;

###################################################

=head1 METHODS

=head2 startup

returns the psgi code ref

=cut
sub startup {
    my($class) = @_;

    if(mode() ne 'TEST') {
        require Thruk::Backend::Pool;
        Thruk::Backend::Pool::init_backend_thread_pool();
    }

    require Thruk::Context;
    require Thruk::Utils;
    require Thruk::Utils::Auth;
    require Thruk::Utils::External;
    require Thruk::Utils::LMD;
    require Thruk::Utils::Menu;
    require Thruk::Utils::Status;
    require Thruk::Action::AddDefaults;
    require Thruk::Backend::Manager;
    require Thruk::Views::ToolkitRenderer;
    require Thruk::Views::JSONRenderer;

    my $app = $class->_build_app();

    if(Thruk->mode eq 'DEVSERVER' || Thruk->mode eq 'TEST') {
        require  Plack::Middleware::Static;
        $app = Plack::Middleware::Static->wrap($app,
                    path         => sub {
                                          my $p = Thruk::Context::translate_request_path($_, config());
                                          return unless $p =~ m%^/thruk/plugins/%mx;
                                          return unless $p =~ /\.(css|png|js|gif|jpg|ico|html|wav|mp3|ogg|ttf|svg|woff|woff2|eot|map)$/mx;
                                          $_ =~ s%^/thruk/plugins/([^/]+)/%$1/root/%mx;
                                          return 1;
                                        },
                    root         => './plugins/plugins-enabled/',
                    pass_through => 1,
        );
        $app = Plack::Middleware::Static->wrap($app,
                    path         => sub {
                                          my $p = Thruk::Context::translate_request_path($_, config());
                                          return if $p =~ m%^/thruk/cgi\-bin/proxy\.cgi%mx;
                                          $p =~ /\.(css|png|js|gif|jpg|ico|html|wav|mp3|ogg|ttf|svg|woff|woff2|eot|map)$/mx;
                                        },
                    root         => './root/',
                    pass_through => 1,
        );

        _setup_development_signals();
    }

    return($app);
}

###################################################
sub _build_app {
    my($class) = @_;
    my $self = {};
    bless($self, $class);
    $thruk = $self unless $thruk;

    #&timing_breakpoint('startup()');

    $self->{'errors'} = [];

    for my $key (@Thruk::Action::AddDefaults::stash_config_keys) {
        confess("$key not defined in config,\n".Dumper(Thruk->config)) unless defined Thruk->config->{$key};
    }

    _init_cache();

    ###################################################
    # load and parse cgi.cfg into $c->config
    unless(Thruk::Config::read_cgi_cfg($self, Thruk->config)) {
        die("\n\n*****\nfailed to load cgi config: ".(Thruk->config->{'cgi.cfg'} // 'none')."\n*****\n\n");
    }
    $self->_add_additional_roles();
    #&timing_breakpoint('startup() cgi.cfg parsed');

    $self->set_timezone();
    &_set_ssi();
    &_setup_pidfile();
    &_setup_cluster();

    ###################################################
    # create backends
    $self->{'db'} = Thruk::Backend::Manager->new();
    if(Thruk->trace && $Thruk::Backend::Pool::peers) {
        for my $key (@{$Thruk::Backend::Pool::peer_order}) {
            next unless $Thruk::Backend::Pool::peers->{$key}->{'class'};
            next unless $Thruk::Backend::Pool::peers->{$key}->{'class'}->{'live'};
            next unless $Thruk::Backend::Pool::peers->{$key}->{'class'}->{'live'}->{'backend_obj'};
            my $peer_cls = $Thruk::Backend::Pool::peers->{$key}->{'class'}->{'live'}->{'backend_obj'};
            $peer_cls->{'logger'} = Thruk::Utils::Log->log();
            $peer_cls->verbose(1);
        }
    }
    #&timing_breakpoint('startup() backends created');

    $self->{'routes'} = {
        '/'                                => 'Thruk::Controller::Root::index',
        '/index.html'                      => 'Thruk::Controller::Root::index',
        '/thruk'                           => 'Thruk::Controller::Root::thruk_index',
        '/thruk/'                          => 'Thruk::Controller::Root::thruk_index',
        '/thruk/index.html'                => 'Thruk::Controller::Root::thruk_index_html',
        '/thruk/side.html'                 => 'Thruk::Controller::Root::thruk_side_html',
        '/thruk/frame.html'                => 'Thruk::Controller::Root::thruk_frame_html',
        '/thruk/main.html'                 => 'Thruk::Controller::Root::thruk_main_html',
        '/thruk/changes.html'              => 'Thruk::Controller::Root::thruk_changes_html',
        '/thruk/docs/'                     => 'Thruk::Controller::Root::thruk_docs',
        '/thruk/docs/index.html'           => 'Thruk::Controller::Root::thruk_docs',
        '/thruk/cgi-bin/parts.cgi'         => 'Thruk::Controller::Root::parts_cgi',
        '/thruk/cgi-bin/job.cgi'           => 'Thruk::Controller::Root::job_cgi',
        '/thruk/cgi-bin/avail.cgi'         => 'Thruk::Controller::avail::index',
        '/thruk/cgi-bin/cmd.cgi'           => 'Thruk::Controller::cmd::index',
        '/thruk/cgi-bin/config.cgi'        => 'Thruk::Controller::config::index',
        '/thruk/cgi-bin/extinfo.cgi'       => 'Thruk::Controller::extinfo::index',
        '/thruk/cgi-bin/history.cgi'       => 'Thruk::Controller::history::index',
        '/thruk/cgi-bin/login.cgi'         => 'Thruk::Controller::login::index',
        '/thruk/cgi-bin/broadcast.cgi'     => 'Thruk::Controller::broadcast::index',
        '/thruk/cgi-bin/user.cgi'          => 'Thruk::Controller::user::index',
        '/thruk/cgi-bin/notifications.cgi' => 'Thruk::Controller::notifications::index',
        '/thruk/cgi-bin/outages.cgi'       => 'Thruk::Controller::outages::index',
        '/thruk/cgi-bin/remote.cgi'        => 'Thruk::Controller::remote::index',
        '/thruk/cgi-bin/restricted.cgi'    => 'Thruk::Controller::restricted::index',
        '/thruk/cgi-bin/showlog.cgi'       => 'Thruk::Controller::showlog::index',
        '/thruk/cgi-bin/status.cgi'        => 'Thruk::Controller::status::index',
        '/thruk/cgi-bin/summary.cgi'       => 'Thruk::Controller::summary::index',
        '/thruk/cgi-bin/tac.cgi'           => 'Thruk::Controller::tac::index',
        '/thruk/cgi-bin/trends.cgi'        => 'Thruk::Controller::trends::index',
        '/thruk/cgi-bin/test.cgi'          => 'Thruk::Controller::test::index',
        '/thruk/cgi-bin/error.cgi'         => 'Thruk::Controller::error::index',
        '/thruk/cgi-bin/docs.cgi'          => 'Thruk::Controller::Root::thruk_docs',
    };
    $self->{'routes_code'} = {};

    $self->{'route_pattern'} = [
        [ '^/thruk/r/v1.*'                   ,'Thruk::Controller::rest_v1::index' ],
        [ '^/thruk/r/.*'                     ,'Thruk::Controller::rest_v1::index' ],
        [ '^/thruk/cgi-bin/proxy.cgi/.*'     ,'Thruk::Controller::proxy::index' ],
    ];

    ###################################################
    # load routes dynamically from plugins
    our $routes_already_loaded;
    $routes_already_loaded = {} unless defined $routes_already_loaded;
    for my $plugin_dir (glob(Thruk->config->{'plugin_path'}.'/plugins-enabled/*/lib/Thruk/Controller/*.pm')) {
        my $route_file = $plugin_dir;
        $route_file =~ s|/lib/Thruk/Controller/.*\.pm$|/routes|gmx;
        if(-f $route_file) {
            next if $routes_already_loaded->{$route_file};
            my $routes = $self->{'routes'};
            my $app    = $self;
            ## no critic
            eval("#line 1 $route_file\n".read_file($route_file));
            ## use critic
            if($@) {
                _error("error while loading routes from ".$route_file.": ".$@);
                confess($@);
            }
            $routes_already_loaded->{$route_file} = 1;
        }
        elsif($plugin_dir =~ m|^.*/plugins-enabled/[^/]+/lib/(.*)\.pm|gmx) {
            my $plugin_class = $1;
            $plugin_class =~ s|/|::|gmx;
            my $err;
            eval {
                $err = _load_plugin_class($self, $plugin_class);
                $plugin_class->add_routes($self, $self->{'routes'}) unless $err;
            };
            $err = $@ if $@;
            _error("disabled broken plugin $plugin_class: ".$err) if $err;
        } else {
            die("unknown plugin folder format: $plugin_dir");
        }

        # enable cron files, this only works for OMD right now.
        if($ENV{'OMD_ROOT'}) {
            $self->_check_plugin_cron_file($plugin_dir);
        }
    }
    if($ENV{'OMD_ROOT'}) {
        $self->_cleanup_plugin_cron_files();
    }
    #&timing_breakpoint('startup() plugins loaded');

    Thruk::Views::ToolkitRenderer::register($self, Thruk::Config::get_toolkit_config());

    ###################################################
    my $c = Thruk::Context->new($self, {'PATH_INFO' => '/dummy-internal'.__FILE__.':'.__LINE__});
    Thruk::Utils::LMD::check_initial_start($c, Thruk->config, 1);
    $self->cluster->register($c) if Thruk->config->{'cluster_enabled'};

    binmode(STDOUT, ":encoding(UTF-8)");
    binmode(STDERR, ":encoding(UTF-8)");

    #&timing_breakpoint('start done');

    return(\&{_dispatcher});
}

###################################################
sub _dispatcher {
    my($env) = @_;

    $Thruk::COUNT++;
    #&timing_breakpoint("_dispatcher: ".$env->{PATH_INFO}, "reset");
    # connection keep alive breaks IE in development server
    if(Thruk->mode eq 'DEVSERVER' || Thruk->mode eq 'TEST') {
        delete $env->{'HTTP_CONNECTION'};
    }
    my $c = Thruk::Context->new($thruk, $env);
    $c->{'stage'} = 'pre';
    my $enable_profiles = 0;
    if($c->req->cookies->{'thruk_profiling'}) {
        $enable_profiles = $c->req->cookies->{'thruk_profiling'};
        $c->stash->{'user_profiling'} = $enable_profiles;
    }
    local $ENV{'THRUK_PERFORMANCE_DEBUG'}  = 1 if $enable_profiles;
    local $ENV{'THRUK_PERFORMANCE_STACKS'} = 1 if $enable_profiles > 1;
    local $ENV{'THRUK_PERFORMANCE_COLLECT_ONLY'} = 1 if(!$ENV{'THRUK_PERFORMANCE_DEBUG'} && $c->config->{'slow_page_log_threshold'} > 0); # do not inject stats if we want to log only
    local $ENV{'THRUK_PERFORMANCE_DEBUG'}  = 1 if $c->config->{'slow_page_log_threshold'} > 0;
    my $url = $c->req->url;
    $c->stats->profile(begin => "_dispatcher: ".$url);
    $c->stats->profile(comment => sprintf('time: %s - host: %s - pid: %s - req: %s', (scalar localtime), $c->config->{'hostname'}, $$, $Thruk::COUNT));
    $c->cluster->refresh() if $c->config->{'cluster_enabled'};

    if(Thruk->verbose) {
        _debug(sprintf("_dispatcher: %s\n", $url));
        _debug(sprintf("params:      %s\n", Thruk::Utils::dump_params($c->req->parameters))) if($c->req->parameters and scalar keys %{$c->req->parameters} > 0);
    }

    ###############################################
    # prepare request
    $c->{'errored'} = 0;
    local $Thruk::Request::c = $c if $Thruk::Request::c;
          $Thruk::Request::c = $c;

    eval {
        Thruk::Action::AddDefaults::begin($c);
    };
    my $begin_err = $@;
    if($begin_err) {
        if(!$c->{'detached'}) {
            _error($begin_err);
        } else {
            _debug($begin_err);
        }
        $c->{'errored'} = 1;
    }
    #&timing_breakpoint("_dispatcher begin done");

    ###############################################
    # route cgi request
    $c->{'stage'} = 'main';
    my($route, $routename);
    my $path_info = $c->req->path_info;
    if(!$c->{'errored'} && !$c->{'rendered'} && !$c->{'detached'}) {
        eval {
            my $rc;
            if(($route, $routename) = $thruk->find_route_match($c, $path_info)) {
                $c->stats->profile(begin => $routename);
                $c->stash->{controller} = $routename;
                $rc = &{$route}($c, $path_info);
                $c->stats->profile(end => $routename);
            }
            else {
                $rc = Thruk::Controller::error::index($c, 25);
            }
            if($rc) {
                Thruk::Action::AddDefaults::end($c);

                ###################################
                # request post processing and rendering
                unless($c->{'rendered'}) {
                    Thruk::Views::ToolkitRenderer::render_tt($c);
                }
            }
        };
        my $err = $@;
        if($err && !$c->{'detached'}) { # prevent overriding previously detached errors
            _error("Error path_info: ".$path_info) unless $c->req->url;
            $c->error($err);
            Thruk::Controller::error::index($c, 13);
        }
    }
    $c->{'stage'} = 'post';
    unless($c->{'rendered'}) {
        eval {
            Thruk::Action::AddDefaults::end($c);
        };
        my $err = $@;
        if($err && !$c->{'detached'}) {
            _error("Error path_info: ".$path_info) unless $c->req->url;
            $c->error($err);
            Thruk::Controller::error::index($c, 13);
        }
        elsif(!$c->stash->{'template'}) {
            my $error = "ERROR - not rendered and no template\n";
            $error   .= Dumper(sprintf("detached: %s, errored: %s", $c->{'detached'} ? 'yes' : 'no', $c->{'errored'} ? 'yes' : 'no'));
            $error   .= Dumper(["begin err",  $begin_err]) if defined $begin_err;
            $error   .= Dumper(["request",    $c->req]);
            $error   .= Dumper(["stash text", $c->stash->{'text'}]) if defined $c->stash->{'text'};
            $error   .= Dumper(["route",      $route, $routename])  if defined $route;
            confess($error);
        }
        eval {
            Thruk::Views::ToolkitRenderer::render_tt($c);
        };
        $err = $@;
        if($err && !$c->{'detached'}) {
            _error("Error path_info: ".$path_info) unless $c->req->url;
            $c->error($err);
            Thruk::Controller::error::index($c, 13);
            Thruk::Views::ToolkitRenderer::render_tt($c);
        }
    }

    my $res = $c->res->finalize;
    $c->stats->profile(end => "_dispatcher: ".$url);

    finalize_request($c, $res);

    $Thruk::Request::c = undef unless $ENV{'THRUK_KEEP_CONTEXT'};
    return($res);
}

###################################################

=head2 find_route_match

    lookup code ref for route

returns code ref and name of the route entry

=cut
sub find_route_match {
    my($self, $c, $path_info) = @_;
    if($self->{'routes_code'}->{$path_info}) {
        return($self->{'routes_code'}->{$path_info}, $self->{'routes'}->{$path_info});
    }
    if($self->{'routes'}->{$path_info}) {
        my $route = $self->{'routes'}->{$path_info};
        if(ref $route eq '') {
            my($class) = $route =~ m|^(.*)::.*?$|mx;
            my $err = _load_plugin_class($self, $class);
            die("loading plugin for ".$path_info." failed: ".$err) if $err;
            $self->{'routes_code'}->{$path_info} = \&{$route};
        }
        return($self->{'routes_code'}->{$path_info}, $self->{'routes'}->{$path_info});
    }
    for my $r (@{$self->{'route_pattern'}}) {
        if($path_info =~ m/$r->[0]/mx) {
            my $function = $self->{'routes_code'}->{$r->[1]} || $r->[1];
            if(ref $function eq '') {
                my($class) = $function =~ m|^(.*)::.*?$|mx;
                my $err = _load_plugin_class($self, $class);
                die("loading plugin for ".$path_info." failed: ".$err) if $err;
                $self->{'routes_code'}->{$r->[1]} = \&{$function};
                $function = $self->{'routes_code'}->{$r->[1]};
            }
            return($function, $r->[1]);
        }
    }
    return;
}

###################################################

=head2 cluster

    make cluster accessible via Thruk->cluster

=cut
sub cluster {
    my($self) = @_;
    unless($cluster) {
        require Thruk::Utils::Cluster;
        $cluster = Thruk::Utils::Cluster->new($self);
    }
    return($cluster);
}

###################################################

=head2 metrics

return metrics object

=cut
sub metrics {
    return($_[0]->{'_metrics'}) if $_[0]->{'_metrics'};
    require Thruk::Metrics;
    $_[0]->{'_metrics'} = Thruk::Metrics->new(file => $_[0]->config->{'var_path'}.'/thruk.stats');
    return($_[0]->{'_metrics'});
}

###################################################

=head2 obj_db_model

return obj_db object model

=cut
sub obj_db_model {
    my($self) = @_;
    return($self->{'obj_db_model'}) if $self->{'obj_db_model'};
    require Monitoring::Config::Multi;
    $self->{'obj_db_model'} = Monitoring::Config::Multi->new();
    return($self->{'obj_db_model'});
}

###################################################
# init cache
sub _init_cache {
    load Thruk::Utils::Cache, qw/cache/;
    Thruk::Utils::IO::mkdir(Thruk->config->{'tmp_path'});
    return Thruk::Utils::Cache->cache(Thruk->config->{'tmp_path'}.'/thruk.cache');
}

###################################################
# mod_fcgid sends a SIGTERM on timeouts, so try to determine if this is a normal
# exit or not and print the stacktrace if not.
sub _check_exit_reason {
    my($sig) = @_;
    my $reason = longmess();
    my $now    = time();

    ## no critic
    if($reason =~ m|Thruk::Utils::CLI::from_local|mx && -t 0) {
    ## use critic
        # this means someone hit ctrl+c, no need for a stracktrace then
        print STDERR "\nbailing out\n";
        return;
    }

    if(!defined $Thruk::Request::c) {
        # not processing any request right now -> simply exit
        return;
    }

    my $request_runtime = $now - $Thruk::Request::c->stash->{'time_begin'}->[0];

    local $| = 1;
    my $c = $Thruk::Request::c;
    my $url = $c->req->url;

    # print stacktrace
    if($request_runtime >= 10 && $sig eq 'TERM') {
        _error("got signal %s while handling request, possible timeout in %s\n", $sig, $url);
    } else {
        _error("got signal %s while handling request in %s\n", $sig, $url);
    }
    _error("User:       %s\n", $c->stash->{'remote_user'}) if $c->stash->{'remote_user'};
    _error("Runtime:    %1.fs\n", $request_runtime);
    _error("Timeout:    %d set in %s:%s\n", $Thruk::last_alarm->{'value'}, $Thruk::last_alarm->{'caller'}->[1], $Thruk::last_alarm->{'caller'}->[2]) if ($sig eq 'ALRM' && $Thruk::last_alarm);
    _error("Address:    %s\n", $c->req->address) if $c->req->address;
    _error("Parameters: %s\n", Thruk::Utils::dump_params($c->req->parameters)) if($c->req->parameters and scalar keys %{$c->req->parameters} > 0);
    if($c->stash->{errorDetails}) {
        for my $row (split(/\n|<br>/mx, $c->stash->{errorDetails})) {
            _error("%s\n", $row);
        }
    }
    _error("Stacktrace: \n%s", $reason);

    # send sigusr1 to lmd to create a backtrace as well
    if($c->config->{'use_lmd_core'}) {
        Thruk::Utils::LMD::kill_if_not_responding($c, $c->config);
    }

    return;
}

###################################################
# save pid
my $pidfile;
sub _setup_pidfile {
    $pidfile  = Thruk->config->{'tmp_path'}.'/thruk.pid';
    if(Thruk->mode eq 'FASTCGI') {
        -s $pidfile || unlink(Thruk->config->{'tmp_path'}.'/thruk.cache');
        open(my $fh, '>>', $pidfile) || warn("cannot write $pidfile: $!");
        print $fh $$."\n";
        Thruk::Utils::IO::close($fh, $pidfile);
    }
    return;
}

###################################################
sub _remove_pid {
    return unless $pidfile;
    local $SIG{PIPE} = 'IGNORE';
    if(Thruk->mode eq 'FASTCGI') {
        my $remaining = [];
        if($pidfile && -f $pidfile) {
            my $pids = [split(/\s/mx, read_file($pidfile))];
            for my $pid (@{$pids}) {
                next unless($pid and $pid =~ m/^\d+$/mx);
                next if $pid == $$;
                next if kill(0, $pid) == 0;
                push @{$remaining}, $pid;
            }
            if(scalar @{$remaining} == 0) {
                unlink($pidfile);
            } else {
                open(my $fh, '>', $pidfile);
                print $fh join("\n", @{$remaining}),"\n";
                CORE::close($fh);
            }
            undef $pidfile;
        }
    }
    return;
}

## no critic
{
    no warnings qw(redefine prototype);
    *CORE::GLOBAL::alarm = sub {
        if($_[0] == 0) {
            $Thruk::last_alarm = undef;
        }
        elsif($_[0] != 0) {
            my @caller = caller;
            $Thruk::last_alarm = {
                caller => \@caller,
                time   => time(),
                value  => $_[0],
            };
        }
        CORE::alarm($_[0]);
    };
};
## use critic
set_signal_handler();
END {
    _remove_pid();
    $cluster->unregister() if $cluster;
}

###################################################

=head2 set_signal_handler

    watch a few signals and print extra information

=cut
sub set_signal_handler {
    ## no critic
    $SIG{INT}  = sub { _check_exit_reason("INT");  _clean_exit(); };
    $SIG{TERM} = sub { _check_exit_reason("TERM"); _clean_exit(); };
    $SIG{PIPE} = sub { _check_exit_reason("PIPE"); _clean_exit(); };
    $SIG{ALRM} = sub { _check_exit_reason("ALRM"); _clean_exit(); };
    ## use critic
    return;
}

###################################################

=head2 restore_signal_handler

    reset all changed signals

=cut
sub restore_signal_handler {
    ## no critic
    $SIG{INT}  = 'DEFAULT';
    $SIG{TERM} = 'DEFAULT';
    $SIG{PIPE} = 'DEFAULT';
    $SIG{ALRM} = 'DEFAULT';
    ## use critic
    return;
}

###################################################
# exit and remove pid file
sub _clean_exit {
    _remove_pid();
    $cluster->unregister() if $cluster;
    undef $cluster;
    undef $thruk;
    exit;
}

###################################################

=head2 set_timezone

    set servers timezone

=cut
sub set_timezone {
    my($self, $timezone) = @_;
    my $config = Thruk->config;
    $config->{'_server_timezone'} = &_detect_timezone() unless $config->{'_server_timezone'};

    if(!defined $timezone) {
        $timezone = $config->{'server_timezone'} || $config->{'use_timezone'} || $config->{'_server_timezone'};
    }

    ## no critic
    $ENV{'TZ'} = $timezone;
    ## use critic
    POSIX::tzset();

    return;
}

###################################################
# create cluster files
sub _setup_cluster {
    my $config = Thruk->config;
    require Thruk::Utils::Crypt;
    $Thruk::HOSTNAME      = $config->{'hostname'};
    $Thruk::NODE_ID_HUMAN = $config->{'hostname'}."-".$config->{'home'}."-".abs_path($ENV{'THRUK_CONFIG'} || '.');
    $Thruk::NODE_ID       = Thruk::Utils::Crypt::hexdigest($Thruk::NODE_ID_HUMAN);
    return;
}

###################################################
# set installed server side includes
sub _set_ssi {
    my $config  = Thruk->config;
    my $ssi_dir = $config->{'ssi_path'};
    my (%ssi, $dh);
    if(-e $ssi_dir) {
        opendir( $dh, $ssi_dir) or die "can't opendir '$ssi_dir': $!";
        for my $entry (readdir($dh)) {
            next if $entry eq '.' or $entry eq '..';
            next if $entry !~ /\.ssi$/mx;
            $ssi{$entry} = 1;
        }
        closedir $dh;
    }
    $config->{'ssi_includes'} = \%ssi;
    $config->{'ssi_path'}     = $ssi_dir;
    return;
}

###################################################

=head2 register_cron_entries

    register_cron_entries($function_name)

register callback to update cron jobs

=cut
sub register_cron_entries {
    my($self, $function) = @_;
    $self->{'_cron_callbacks'} = {} unless defined $self->{'_cron_callbacks'};
    $self->{'_cron_callbacks'}->{$function} = 1;
    return;
}

###################################################
sub _setup_development_signals {
    # SizeMe and other devel internals
    if($ENV{'SIZEME'}) {
        # add signal handler to print memory information
        # ps -efl | grep thruk_server.pl | awk '{print $4}' | xargs kill -USR1
        print STDERR "adding USR1 signal handler\n";
        ## no critic
        $SIG{'USR1'} = sub {
            printf(STDERR "mem:% 7s MB  before devel::sizeme\n", Thruk::Backend::Pool::get_memory_usage());
            eval {
                require Devel::SizeMe;
                Devel::SizeMe::perl_size();
            };
            print STDERR $@ if $@;
        };
        ## use critic
    }
    if($ENV{'MALLINFO'}) {
        # add signal handler to print memory information
        # ps -efl | grep thruk_server.pl | awk '{print $4}' | xargs kill -USR2
        ## no critic
        $SIG{'USR2'} = sub {
            print STDERR "adding USR2 signal handler\n";
            eval {
                require Devel::Mallinfo;
                my $info = Devel::Mallinfo::mallinfo();
                printf STDERR "%s\n", '*******************************************';
                printf STDERR "%-30s    %5.1f %2s\n", 'arena',                              Thruk::Utils::reduce_number($info->{'arena'}, 'B');
                printf STDERR "   %-30s %5.1f %2s\n", 'bytes in use, ordinary blocks',  Thruk::Utils::reduce_number($info->{'uordblks'}, 'B');
                printf STDERR "   %-30s %5.1f %2s\n", 'bytes in use, small blocks',     Thruk::Utils::reduce_number($info->{'usmblks'}, 'B');
                printf STDERR "   %-30s %5.1f %2s\n", 'free bytes, ordinary blocks',    Thruk::Utils::reduce_number($info->{'fordblks'}, 'B');
                printf STDERR "   %-30s %5.1f %2s\n", 'free bytes, small blocks',       Thruk::Utils::reduce_number($info->{'fsmblks'}, 'B');
                printf STDERR "%-30s\n", 'total';
                printf STDERR "   %-30s %5.1f %2s\n", 'taken from the system',    Thruk::Utils::reduce_number($info->{'arena'} + $info->{'hblkhd'}, 'B');
                printf STDERR "   %-30s %5.1f %2s\n", 'in use by program',        Thruk::Utils::reduce_number($info->{'uordblks'} + $info->{'usmblks'} + $info->{'hblkhd'}, 'B');
                printf STDERR "   %-30s %5.1f %2s\n", 'free within program',      Thruk::Utils::reduce_number($info->{'fordblks'} + $info->{'fsmblks'}, 'B');
            };
            print STDERR $@ if $@;
        };
        ## use critic
    }
    return;
}

###################################################
sub _check_plugin_cron_file {
    my($self, $plugin_dir) = @_;
    my $cron_file = $plugin_dir;
    $cron_file =~ s|/lib/Thruk/Controller/.*\.pm$|/cron|gmx;
    if(-e $cron_file && $cron_file =~ m/\/plugins\-enabled\/([^\/]+)\/cron/mx) {
        my $plugin_name = $1;
        # check existing cron files, to see if its already enabled
        my $found = 0;
        my @existing_cron_files = glob($ENV{'OMD_ROOT'}.'/etc/cron.d/*');
        for my $file (@existing_cron_files) {
            if(-l $file) {
                my $target = readlink($file);
                if($target =~ m/\/\Q$plugin_name\E\/cron$/mx) {
                    $found = 1;
                    last;
                }
            }
        }
        if(!$found) {
            symlink('../thruk/plugins-enabled/'.$plugin_name.'/cron', 'etc/cron.d/thruk-plugin-'.$plugin_name);
            Thruk::Utils::IO::cmd("omd status crontab >/dev/null 2>&1 && omd reload crontab > /dev/null");
            _info("enabled cronfile for plugin: ".$plugin_name);
        }
    }
    return;
}

###################################################
sub _cleanup_plugin_cron_files {
    my($self) = @_;
    my @existing_cron_files = glob($ENV{'OMD_ROOT'}.'/etc/cron.d/*');
    for my $file (@existing_cron_files) {
        if($file =~ m/\/thruk\-plugin\-/mx && -l $file && !-e $file) {
            _info("removed old plugin cronfile: ".$file);
            unlink($file);
        }
    }
    return;
}

###################################################
sub _set_content_length {
    my($res) = @_;

    my $content_length;
    my $h = Plack::Util::headers($res->[1]);
    if (!Plack::Util::status_with_no_entity_body($res->[0]) &&
        !$h->exists('Content-Length') &&
        !$h->exists('Transfer-Encoding') &&
        defined($content_length = Plack::Util::content_length($res->[2])))
    {
        $h->push('Content-Length' => $content_length);
    }
    $h->push('Cache-Control', 'no-store');
    $h->push('Expires', '0');
    return($content_length);
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
    $thruk->set_timezone($c->config->{'_server_timezone'});

    if($ENV{THRUK_LEAK_CHECK}) {
        eval {
            require Devel::Cycle;
            $Devel::Cycle::FORMATTING = "cooked";
        };
        print STDERR $@ if $@ && Thruk->debug;
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
    $c->stats->profile(comment => 'total time waited on backends:  '.sprintf('%.2fs', $c->stash->{'total_backend_waited'})) if $c->stash->{'total_backend_waited'};
    $c->stats->profile(comment => 'total time waited on rendering: '.sprintf('%.2fs', $c->stash->{'total_render_waited'}))  if $c->stash->{'total_render_waited'};
    $c->stash->{'time_total'} = $elapsed;

    my($url) = ($c->req->url =~ m#.*?/thruk/(.*)#mxo);
    if($ENV{'THRUK_PERFORMANCE_DEBUG'} && $c->stash->{'inject_stats'} && !$ENV{'THRUK_PERFORMANCE_COLLECT_ONLY'}) {
        # inject stats into html page
        unshift @{$c->stash->{'profile'}}, @{Thruk::Template::Context::get_profiles()} if $tt_profiling;
        unshift @{$c->stash->{'profile'}}, [$c->stats->report_html(), $c->stats->report()];
        my $stats = "";
        Thruk::Views::ToolkitRenderer::render($c, "_internal_stats.tt", $c->stash, \$stats);
        $res->[2]->[0] =~ s/<\/body>/$stats<\/body>/gmx if ref $res->[2] eq 'ARRAY';
        Thruk::Template::Context::reset_profiles() if $tt_profiling;
    }
    # slow pages log
    if($ENV{'THRUK_PERFORMANCE_DEBUG'} && $c->config->{'slow_page_log_threshold'} > 0 && $elapsed > $c->config->{'slow_page_log_threshold'}) {
        _warn("***************************");
        _warn(sprintf("slow_page_log_threshold (%ds) hit, page took %.1fs to load.", $c->config->{'slow_page_log_threshold'}, $elapsed));
        _warn(sprintf("page:    %s\n", $c->req->url)) if defined $c->req->url;
        _warn(sprintf("params:  %s\n", Thruk::Utils::dump_params($c->req->parameters))) if($c->req->parameters and scalar keys %{$c->req->parameters} > 0);
        _warn(sprintf("user:    %s\n", ($c->stash->{'remote_user'} // 'not logged in')));
        _warn(sprintf("address: %s%s\n", $c->req->address, ($c->env->{'HTTP_X_FORWARDED_FOR'} ? ' ('.$c->env->{'HTTP_X_FORWARDED_FOR'}.')' : '')));
        _warn($c->stats->report());
    }

    my $content_length = _set_content_length($res);

    # last possible time to report/save profile
    Thruk::Utils::External::save_profile($c, $ENV{'THRUK_JOB_DIR'}) if $ENV{'THRUK_JOB_DIR'};

    if($ENV{'THRUK_PERFORMANCE_DEBUG'} && $c->stash->{'memory_begin'} && !$ENV{'THRUK_PERFORMANCE_COLLECT_ONLY'}) {
        $c->stash->{'memory_end'} = Thruk::Backend::Pool::get_memory_usage();
        $url     = $c->req->url unless $url;
        $url     =~ s|^https?://[^/]+/|/|mxo;
        $url     =~ s/^cgi\-bin\///mxo;
        if(length($url) > 80) { $url = substr($url, 0, 80).'...' }
        if(!$url) { $url = $c->req->url; }
        my $waited = [];
        push @{$waited}, $c->stash->{'total_backend_waited'} ? sprintf("%.3fs", $c->stash->{'total_backend_waited'}) : '-';
        push @{$waited}, $c->stash->{'total_render_waited'} ? sprintf("%.3fs", $c->stash->{'total_render_waited'}) : '-';
        _info(sprintf("%5d Req: %03d   mem:%7s MB %6s MB   dur:%6ss %16s   size:% 12s   stat: %d   url: %s",
                                $$,
                                $Thruk::COUNT,
                                $c->stash->{'memory_end'},
                                sprintf("%.2f", ($c->stash->{'memory_end'}-$c->stash->{'memory_begin'})),
                                sprintf("%.3f", $elapsed),
                                '('.join('/', @{$waited}).')',
                                defined $content_length ? sprintf("%.3f kb", $content_length/1024) : '----',
                                $res->[0],
                                $url,
                    ));
    }
    _debug($c->stats->report()) if Thruk->debug;
    $c->stats->clear() unless $ENV{'THRUK_KEEP_CONTEXT'};

    # save metrics to disk
    $c->app->{_metrics}->store() if $c->app->{_metrics};

    # restore user specific settings
    Thruk::Config::finalize($c);

    # does this process need a restart?
    if(Thruk->mode eq 'FASTCGI') {
        if($c->config->{'max_process_memory'}) {
            Thruk::Utils::check_memory_usage($c);
        }
    }

    return;
}

###################################################
# try to detect current timezone
# Locations like Europe/Berlin are prefered over CEST
sub _detect_timezone {
    if($ENV{'TZ'}) {
        _debug(sprintf("server timezone: %s (from ENV)", $ENV{'TZ'})) if Thruk->verbose;
        return($ENV{'TZ'});
    }

    if(-r '/etc/timezone') {
        chomp(my $tz = read_file('/etc/timezone'));
        if($tz) {
            _debug(sprintf("server timezone: %s (from /etc/timezone)", $tz)) if Thruk->verbose;
            return $tz;
        }
    }

    if(-r '/etc/sysconfig/clock') {
        my $content = read_file('/etc/sysconfig/clock');
        if($content =~ m/^\s*ZONE="([^"]+)"/mx) {
            _debug(sprintf("server timezone: %s (from /etc/sysconfig/clock)", $1)) if Thruk->verbose;
            return $1;
        }
        if($content =~ m/^\s*TIMEZONE="([^"]+)"/mx) {
            _debug(sprintf("server timezone: %s (from /etc/sysconfig/clock)", $1)) if Thruk->verbose;
            return $1;
        }
    }

    my $out = Thruk::Utils::IO::cmd("timedatectl 2>/dev/null");
    if($out =~ m/^\s*Time\ zone:\s+(\S+)/mx) {
        _debug(sprintf("server timezone: %s (from timedatectl)", $1)) if Thruk->verbose;
        return($1);
    }

    # returns CEST instead of CET as well
    POSIX::tzset();
    my($std, $dst) = POSIX::tzname();
    if($std) {
        _debug(sprintf("server timezone: %s (from POSIX::tzname)", $std)) if Thruk->verbose;
        return($std);
    }

    # last ressort, date, fails for ex. to set CET instead of CEST
    my $tz = Thruk::Utils::IO::cmd("date +%Z");
    _debug(sprintf("server timezone: %s (from date +%%Z)", $tz)) if Thruk->verbose;
    return $tz;
}

###################################################
sub _load_plugin_class {
    my($self, $class, $no_recurse) = @_;
    eval {
        load($class);
    };
    if($@) {
        my $err = $@;
        # try again clean
        if($err =~ m/Attempt\s+to\s+reload.*aborted/mx && !$no_recurse) {
            for my $key (sort keys %INC) {
                delete $INC{$key} unless defined $INC{$key};
            }
            # suppress redefined warnings
            local $SIG{__WARN__} = sub { };
            return(_load_plugin_class($self, $class, 1));
        }
        _error($err);
        return($err);
    }
    return;
}

###################################################
sub _add_additional_roles {
    my($self) = @_;
    my $roles = $Thruk::Authentication::User::possible_roles;
    my $config = Thruk->config;
    for my $role (sort keys %{$config}) {
        next unless $role =~ m/authorized_(contactgroup_|)for_/mx;
        $role =~ s/authorized_contactgroup_for_/authorized_for_/mx;
        push @{$roles}, $role;
    }
    $roles = Thruk::Config::array_uniq($roles);
    # always put readonly role at the end
    @{$roles} = sort grep(!/^authorized_for_read_only$/mx, @{$roles});
    push @{$roles}, "authorized_for_read_only";
    $Thruk::Authentication::User::possible_roles = $roles;
    return;
}

###################################################

=head2 stop_all

    stop_all()

stop all thruk pids except ourselves

=cut
sub stop_all {
    my($self) = @_;
    $pidfile  = Thruk->config->{'tmp_path'}.'/thruk.pid';
    if(-f $pidfile) {
        my @pids = read_file($pidfile);
        for my $pid (@pids) {
            next if $pid == $$;
            kill(15, $pid);
        }
    }
    return 1;
}

###################################################

=head2 graceful_stop

    graceful_stop($c)

stop our process gracefully

=cut
sub graceful_stop {
    my($self, $c) = @_;
    if($c && $c->env->{'psgix.harakiri'}) {
        # if plack server does support harakiri mode, only supported if plack uses a procmanager
        $c->env->{'psgix.harakiri.commit'} = 1;
    }
    elsif($c && $c->env->{'psgix.cleanup'}) {
        # supported since plack 1.0046
        push @{$c->env->{'psgix.cleanup.handlers'}}, sub {
            kill(15, $$);
        };
    } else {
        # kill it the hard way
        kill(15, $$); # send SIGTERM to ourselves which should be used in the FCGI::ProcManager::pm_post_dispatch then
    }
    return 1;
}

###################################################

=head1 SEE ALSO

L<Thruk::Controller::Root>, L<Plack>

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

Thruk is Copyright (c) 2009-2019 by Sven Nierlein and others.
This is free software; you can redistribute it and/or modify it under the
same terms as the Perl5 programming language system
itself.

=cut

1;
