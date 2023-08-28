package Thruk;

=head1 NAME

Thruk - Monitoring Web Interface

=head1 DESCRIPTION

Monitoring web interface for Naemon, Nagios, Icinga and Shinken.

=cut

use warnings;
use strict;
use Carp qw/confess longmess/;  $Carp::MaxArgLen = 500;
use Cwd qw/abs_path/;
use Data::Dumper qw/Dumper/;    $Data::Dumper::Sortkeys = 1;
use Module::Load qw/load/;

###################################################
# load timing class
use Thruk::Timer qw/timing_breakpoint/;
&timing_breakpoint('starting thruk');

###################################################
# clean up env
$Thruk::Globals::tt_profiling = 0 unless defined $Thruk::Globals::tt_profiling;
BEGIN {
    ## no critic
    if($ENV{'THRUK_VERBOSE'} and $ENV{'THRUK_VERBOSE'} >= 3) {
        $ENV{'THRUK_PERFORMANCE_DEBUG'} = 3;
    }
    if($ENV{'THRUK_VERBOSE'} and $ENV{'THRUK_VERBOSE'} >= 4) {
        $ENV{'MONITORING_LIVESTATUS_CLASS_TRACE'} = 999;
    }
    use Time::HiRes qw/gettimeofday tv_interval/;
    eval "use Thruk::Template::Context;" if $ENV{'THRUK_PERFORMANCE_DEBUG'};
    eval "use Thruk::Template::Exception;" if $ENV{'TEST_AUTHOR'};
    ## use critic
    $Thruk::Globals::tt_profiling = 1 if $ENV{'THRUK_PERFORMANCE_DEBUG'};
}

use Thruk::Base qw/:all/;
use Thruk::Config;
use Thruk::Constants ':add_defaults';
use Thruk::Utils::Cache ();
use Thruk::Utils::IO ();
use Thruk::Utils::Log qw/:all/;
use Thruk::Utils::Timezone ();

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
    my($class, $pool) = @_;

    if(Thruk::Base->mode() ne 'TEST' && !$pool) {
        require Thruk::Backend::Pool;
        $pool = Thruk::Backend::Pool->new();
    }

    require Thruk::Context;
    require Thruk::Utils;
    require Thruk::Utils::Menu;   # required for reading routes file
    require Thruk::Utils::Status; # required for reading routes file
    require Thruk::Action::AddDefaults;

    my $app = $class->_build_app($pool);

    if(Thruk::Base->mode() eq 'DEVSERVER' || Thruk::Base->mode() eq 'TEST') {
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
    my($class, $pool) = @_;
    my $self = {
        pool => $pool,
    };
    bless($self, $class);
    $thruk = $self unless $thruk;
    my $config = Thruk->config;

    if(Thruk->trace) {
        $self->{'pool'}->set_logger(Thruk::Utils::Log->log(), 1);
    }

    &timing_breakpoint('startup()');

    $self->{'errors'} = [];

    for my $key (@Thruk::Action::AddDefaults::stash_config_keys) {
        confess("$key not defined in config,\n".Dumper($config)) unless defined $config->{$key};
    }

    $self->cache();

    ###################################################
    # load and parse cgi.cfg into $c->config
    unless(Thruk::Config::read_cgi_cfg($self, $config)) {
        die("\n\n*****\nfailed to load cgi config: ".($config->{'cgi.cfg'} // 'none')."\n*****\n\n");
    }
    $self->_add_additional_roles();
    &timing_breakpoint('startup() cgi.cfg parsed');

    Thruk::Utils::Timezone::set_timezone($config);
    &_create_secret_file();
    &_set_ssi();
    &_setup_pidfile();
    &setup_cluster();
    Thruk::Utils::Log->log() if Thruk::Base->mode() eq 'FASTCGI'; # create log file if it doesn't exist

    $self->{'routes'} = {
        '/'                                => 'Thruk::Controller::Root::index',
        '/index.html'                      => 'Thruk::Controller::Root::index',
        '/thruk'                           => 'Thruk::Controller::Root::thruk_index',
        '/thruk/'                          => 'Thruk::Controller::Root::thruk_index',
        '/thruk/index.html'                => 'Thruk::Controller::Root::thruk_index_html',
        '/thruk/main.html'                 => 'Thruk::Controller::Root::thruk_main_html',
        '/thruk/changes.html'              => 'Thruk::Controller::Root::thruk_changes_html',
        '/thruk/docs/'                     => 'Thruk::Controller::Root::thruk_docs',
        '/thruk/docs/index.html'           => 'Thruk::Controller::Root::thruk_docs',
        '/thruk/cgi-bin/parts.cgi'         => 'Thruk::Controller::Root::parts_cgi',
        '/thruk/cgi-bin/job.cgi'           => 'Thruk::Controller::Root::job_cgi',
        '/thruk/cgi-bin/themes.cgi'        => 'Thruk::Controller::Root::thruk_theme_preview',
        '/thruk/cgi-bin/void.cgi'          => 'Thruk::Controller::Root::empty_page',
        '/thruk/cgi-bin/avail.cgi'         => 'Thruk::Controller::avail::index',
        '/thruk/cgi-bin/cmd.cgi'           => 'Thruk::Controller::cmd::index',
        '/thruk/cgi-bin/config.cgi'        => 'Thruk::Controller::config::index',
        '/thruk/cgi-bin/extinfo.cgi'       => 'Thruk::Controller::extinfo::index',
        '/thruk/cgi-bin/history.cgi'       => 'Thruk::Controller::showlog::index',
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
        '/thruk/cgi-bin/main.cgi'          => 'Thruk::Controller::main::index',
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

    Thruk::Utils::Status::add_view({'group' => 'Main',
                                    'name'  => 'Main Dashboard',
                                    'value' => 'main',
                                    'url'   => 'main.cgi',
    });

    Thruk::Utils::Status::add_view({'group' => 'Tac',
                                    'name'  => 'Tactical Overview',
                                    'value' => 'tac',
                                    'url'   => 'tac.cgi',
    });

    ###################################################
    # load routes dynamically from plugins
    $config->{'routes_already_loaded'} = {} unless defined $config->{'routes_already_loaded'};
    for my $plugin_dir (glob($config->{'plugin_path'}.'/plugins-enabled/*/lib/Thruk/Controller/*.pm')) {
        my $route_file = $plugin_dir;
        $route_file =~ s|/lib/Thruk/Controller/.*\.pm$|/routes|gmx;
        if(-f $route_file) {
            next if $config->{'routes_already_loaded'}->{$route_file};
            my $routes = $self->{'routes'};
            my $app    = $self;
            ## no critic
            eval("#line 1 $route_file\n".Thruk::Utils::IO::read($route_file));
            ## use critic
            if($@) {
                _error("error while loading routes from ".$route_file.": ".$@);
                confess($@);
            }
            $config->{'routes_already_loaded'}->{$route_file} = 1;
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
    &timing_breakpoint('startup() plugins loaded');

    ###################################################
    my $c = Thruk::Context->new($self, {'PATH_INFO' => '/dummy-internal'.__FILE__.':'.__LINE__});
    if($c->config->{'use_lmd_core'}) {
        require Thruk::Utils::LMD;
        Thruk::Utils::LMD::check_initial_start($c, $config, 1);
    }
    $self->cluster->register($c) if $config->{'cluster_enabled'};

    binmode(STDOUT, ":encoding(UTF-8)");
    binmode(STDERR, ":encoding(UTF-8)");

    &timing_breakpoint('start done');

    return(\&{_dispatcher});
}

###################################################
sub _dispatcher {
    my($env) = @_;

    $Thruk::Globals::COUNT++;
    &timing_breakpoint("_dispatcher: ".$env->{PATH_INFO}, "reset");
    # connection keep alive breaks IE in development server
    if(Thruk::Base->mode() eq 'DEVSERVER' || Thruk::Base->mode() eq 'TEST') {
        delete $env->{'HTTP_CONNECTION'};
    }
    my $c = Thruk::Context->new($thruk, $env);
    $c->{'stage'} = 'pre';
    my $enable_profiles = 0;
    if($c->cookies('thruk_profiling')) {
        $enable_profiles = $c->cookies('thruk_profiling');
        $c->stash->{'user_profiling'} = $enable_profiles;
    }
    local $ENV{'THRUK_PERFORMANCE_DEBUG'}  = 1 if $enable_profiles;
    local $ENV{'THRUK_PERFORMANCE_STACKS'} = 1 if $enable_profiles > 1;
    local $ENV{'THRUK_PERFORMANCE_COLLECT_ONLY'} = 1 if(!$ENV{'THRUK_PERFORMANCE_DEBUG'} && $c->config->{'slow_page_log_threshold'} > 0); # do not inject stats if we want to log only
    local $ENV{'THRUK_PERFORMANCE_DEBUG'}  = 1 if $c->config->{'slow_page_log_threshold'} > 0;
    my $url = $c->req->url;
    $c->stats->profile(begin => "_dispatcher: ".$url);
    $c->stats->profile(comment => sprintf('time: %s - host: %s - pid: %s - req: %s', (scalar localtime), $c->config->{'hostname'}, $$, $Thruk::Globals::COUNT));
    $c->cluster->refresh() if $c->config->{'cluster_enabled'};

    if(Thruk->verbose) {
        _debug(sprintf("_dispatcher: %s\n", $url));
        _debug(sprintf("params:      %s\n", Thruk::Utils::dump_params($c->req->parameters))) if($c->req->parameters and scalar keys %{$c->req->parameters} > 0);
    }

    ###############################################
    # prepare request
    $c->{'errored'} = 0;
    local $Thruk::Globals::c = $c if $Thruk::Globals::c;
          $Thruk::Globals::c = $c;

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
    &timing_breakpoint("_dispatcher begin done");

    ###############################################
    # route cgi request
    $c->{'stage'} = 'main';
    my($route, $routename);
    my $path_info = $c->req->path_info;
    if(!$c->{'errored'} && !$c->{'rendered'} && !$c->{'detached'}) {
        require Thruk::Controller::error;
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
                    &render_tt($c);
                }
            }
        };
        my $err = $@;
        if($err && !$c->{'detached'}) { # prevent overriding previously detached errors
            _error("Error path_info: ".$path_info) unless $c->req->url;
            $c->error($err);
            if($c->stash->{'backend_error'}) {
                Thruk::Controller::error::index($c, 9);
            } else {
                Thruk::Controller::error::index($c, 13);
            }
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
            &render_tt($c);
        };
        $err = $@;
        if($err) {
            if(!$c->{'detached'}) {
                _error("Error path_info: ".$path_info) unless $c->req->url;
                $c->error($err);
                Thruk::Controller::error::index($c, 13);
                &render_tt($c);
            } else {
                _warn($err);
            }
        }
    }

    &timing_breakpoint("_dispatcher render done");

    my $res = $c->res->finalize;
    $c->stats->profile(end => "_dispatcher: ".$url);

    $c->finalize_request($res);

    &timing_breakpoint("_dispatcher finalize done");

    $Thruk::Globals::c = undef unless $ENV{'THRUK_KEEP_CONTEXT'};
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

=head2 db

    return db manager

=cut
sub db {
    my($self) = @_;
    return($self->{'db'}) if $self->{'db'};
    &timing_breakpoint('creating $c->db');
    require Thruk::Backend::Manager;
    $self->{'db'} = Thruk::Backend::Manager->new($self->pool);
    &timing_breakpoint('creating $c->db done');
    return($self->{'db'});
}

###################################################

=head2 pool

    return connection pool

=cut
sub pool {
    my($self, $backends) = @_;
    if(!$self->{'pool'} || $backends) {
        require Thruk::Backend::Pool;
        $self->{'pool'} = Thruk::Backend::Pool->new($backends);
        if(Thruk->trace) {
            $self->{'pool'}->set_logger(Thruk::Utils::Log->log(), 1);
        }
    }
    return($self->{'pool'});
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

=head2 cache

return global cache

=cut
sub cache {
    my($self) = @_;
    return $self->{'_cache'} if $self->{'_cache'};
    Thruk::Utils::IO::mkdir(Thruk->config->{'tmp_path'});
    $self->{'_cache'} = Thruk::Utils::Cache->new(Thruk->config->{'tmp_path'}.'/thruk.cache');
    return;
}

###################################################
# mod_fcgid sends a SIGTERM on timeouts, so try to determine if this is a normal
# exit or not and print the stacktrace if not.
sub _check_exit_reason {
    my($sig) = @_;

    if($sig eq 'TERM' || $sig eq 'INT') {
        # sometime we receive sigpipes, ex. in log4perl END
        # no need for duplicate stacks
        ## no critic
        $SIG{'PIPE'} = 'IGNORE';
        ## use critic
    }

    my $reason = longmess();
    my $now    = time();

    ## no critic
    if($reason =~ m|Thruk::Utils::CLI::from_local|mx && -t 0 && $sig eq 'INT') {
    ## use critic
        # this means someone hit ctrl+c, no need for a stracktrace then
        printf(STDERR "\nbailing out, got signal SIG%s\n", $sig);
        return;
    }

    if(!defined $Thruk::Globals::c) {
        # not processing any request right now -> simply exit
        return;
    }

    my $request_runtime = $now - $Thruk::Globals::c->stash->{'time_begin'}->[0];

    local $| = 1;
    my $c = $Thruk::Globals::c;
    my $url = $c->req->url;

    # print stacktrace
    my $log = \&_error;
    if($request_runtime >= 20 && $sig eq 'TERM') {
        _error("got signal %s while handling request, possible timeout in %s\n", $sig, $url);
    } else {
        _warn("got signal %s while handling request in %s\n", $sig, $url);
        $log = \&_warn;
    }
    &{$log}("User:       %s\n", $c->stash->{'remote_user'}) if $c->stash->{'remote_user'};
    &{$log}("Runtime:    %1.fs\n", $request_runtime);
    &{$log}("Timeout:    %d set in %s:%s\n", $Thruk::last_alarm->{'value'}, $Thruk::last_alarm->{'caller'}->[1], $Thruk::last_alarm->{'caller'}->[2]) if ($sig eq 'ALRM' && $Thruk::last_alarm);
    &{$log}("Address:    %s\n", $c->req->address) if $c->req->address;
    &{$log}("Parameters: %s\n", Thruk::Utils::dump_params($c->req->parameters)) if($c->req->parameters and scalar keys %{$c->req->parameters} > 0);
    if($c->stash->{errorDetails}) {
        for my $row (split(/\n|<br>/mx, $c->stash->{errorDetails})) {
            &{$log}("%s\n", $row);
        }
    }
    &{$log}("Stacktrace: \n%s", $reason);

    # send sigusr1 to lmd to create a backtrace as well
    if($c->config->{'use_lmd_core'}) {
        require Thruk::Utils::LMD;
        Thruk::Utils::LMD::kill_if_not_responding($c, $c->config);
    }

    return;
}

###################################################
# save pid
my $pidfile;
sub _setup_pidfile {
    $pidfile  = Thruk->config->{'tmp_path'}.'/thruk.pid';
    if(Thruk::Base->mode() eq 'FASTCGI') {
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
    if(Thruk::Base->mode() eq 'FASTCGI') {
        my $remaining = [];
        if($pidfile) {
            my $pids = [split(/\s/mx, Thruk::Utils::IO::saferead($pidfile)//'')];
            for my $pid (@{$pids}) {
                next unless($pid and $pid =~ m/^\d+$/mx);
                next if $pid == $$;
                next if kill(0, $pid) == 0;
                push @{$remaining}, $pid;
            }
            if(scalar @{$remaining} == 0) {
                unlink($pidfile);
            } else {
                Thruk::Utils::IO::write($pidfile, join("\n", @{$remaining})."\n");
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
# exit and remove pid file
sub _clean_exit {
    _remove_pid();
    $cluster->unregister() if $cluster;
    undef $cluster;
    undef $thruk;
    exit;
}

###################################################
# create secret file
sub _create_secret_file {
    my $config = Thruk->config;
    return unless (Thruk::Base->mode() eq 'FASTCGI' || Thruk::Base->mode() eq 'DEVSERVER');
    my $var_path   = $config->{'var_path'} || die("no var path!");
    my $secretfile = $var_path.'/secret.key';
    return if -s $secretfile;
    require Thruk::Utils::Crypt;
    my $digest = Thruk::Utils::Crypt::random_uuid([time()]);
    Thruk::Utils::IO::write($secretfile, $digest);
    chmod(0600, $secretfile);
    return;
}

###################################################

=head2 setup_cluster

    setup_cluster()

create cluster files

=cut

sub setup_cluster {
    my $config = Thruk->config;
    require Thruk::Utils::Crypt;
    $Thruk::Globals::HOSTNAME      = $config->{'hostname'};
    $Thruk::Globals::NODE_ID_HUMAN = $config->{'hostname'}."-".$config->{'home'}."-".abs_path($ENV{'THRUK_CONFIG'} || '.');
    $Thruk::Globals::NODE_ID       = Thruk::Utils::Crypt::hexdigest($Thruk::Globals::NODE_ID_HUMAN);
    return;
}

###################################################
# set installed server side includes
sub _set_ssi {
    my $config  = Thruk->config;
    my $ssi_dir = $config->{'ssi_path'};
    my %ssi;
    if(-e $ssi_dir) {
        for my $entry (@{Thruk::Utils::IO::find_files($ssi_dir, '\.ssi$')}) {
            $ssi{$entry} = 1;
        }
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
            printf(STDERR "mem:% 7s MB  before devel::sizeme\n", Thruk::Utils::IO::get_memory_usage());
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
    my $roles = $Thruk::Constants::possible_roles;
    my $config = Thruk->config;
    for my $role (sort keys %{$config}) {
        next unless $role =~ m/authorized_(contactgroup_|)for_/mx;
        $role =~ s/authorized_contactgroup_for_/authorized_for_/mx;
        push @{$roles}, $role;
    }
    $roles = Thruk::Base::array_uniq($roles);
    # always put readonly role at the end
    @{$roles} = sort grep(!/^authorized_for_read_only$/mx, @{$roles});
    push @{$roles}, "authorized_for_read_only";
    $Thruk::Constants::possible_roles = $roles;
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
        for my $pid (Thruk::Utils::IO::read_as_list($pidfile)) {
            next if $pid == $$;
            kill("TERM", $pid);
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
            kill("TERM", $$);
        };
    } else {
        # kill it the hard way
        kill("TERM", $$); # send SIGTERM to ourselves which should be used in the FCGI::ProcManager::pm_post_dispatch then
    }
    return 1;
}

###################################################

=head2 log

Thruk->log->...

compat wrapper for accessing logger

=cut
sub log {
    return(Thruk::Utils::Log::log());
}

###################################################

=head2 render_tt

    render_tt($c)

wrapper for ToolkitRenderer

=cut
sub render_tt {
    my($c) = @_;
    require Thruk::Views::ToolkitRenderer;
    return(Thruk::Views::ToolkitRenderer::render_tt($c));
}

###################################################

=head1 SEE ALSO

L<Thruk::Controller::Root>, L<Plack>

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

Thruk is Copyright (c) 2009-present by Sven Nierlein and others.
This is free software; you can redistribute it and/or modify it under the
same terms as the Perl5 programming language system
itself.

=cut

1;
