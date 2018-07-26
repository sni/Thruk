package Thruk;

=head1 NAME

Thruk - Monitoring Web Interface

=head1 DESCRIPTION

Monitoring web interface for Naemon, Nagios, Icinga and Shinken.

=cut

use strict;
use warnings;
use Cwd qw/abs_path/;

use 5.008000;

our $VERSION = '2.22';

###################################################
# create connection pool
# has to be done before the binmode
# or even earlier to save memory
BEGIN {
    if(!$ENV{'THRUK_SRC'} || $ENV{'THRUK_SRC'} ne 'TEST') {
        require Thruk::Backend::Pool;
        Thruk::Backend::Pool::init_backend_thread_pool();
    }
}

###################################################
# load timing class
BEGIN {
    #use Thruk::Timer qw/timing_breakpoint/;
    #&timing_breakpoint('starting thruk');
}

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
use constant {
    # backend states
    ADD_DEFAULTS        => 0,
    ADD_SAFE_DEFAULTS   => 1,
    ADD_CACHED_DEFAULTS => 2,
};
use Carp qw/confess longmess/;
$Carp::MaxArgLen = 500;
use File::Slurp qw(read_file);
use Module::Load qw/load/;
use Data::Dumper qw/Dumper/;
use Plack::Util ();
use POSIX ();

###################################################
$Data::Dumper::Sortkeys = 1;
our $config;
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

    require Thruk::Context;
    require Thruk::Utils;
    require Thruk::Utils::IO;
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

    if($ENV{'THRUK_SRC'} eq 'DebugServer' || $ENV{'THRUK_SRC'} eq 'TEST') {
        require  Plack::Middleware::Static;
        $app = Plack::Middleware::Static->wrap($app,
                    path         => sub {
                                          my $p = Thruk::Context::translate_request_path($_, $class->config);
                                          return unless $p =~ m%^/thruk/plugins/%mx;
                                          return unless $p =~ /\.(css|png|js|gif|jpg|ico|html|wav|ttf|svg|woff|woff2|eot|)$/mx;
                                          $_ =~ s%^/thruk/plugins/([^/]+)/%$1/root/%mx;
                                          return 1;
                                        },
                    root         => './plugins/plugins-enabled/',
                    pass_through => 1,
        );
        $app = Plack::Middleware::Static->wrap($app,
                    path         => sub { my $p = Thruk::Context::translate_request_path($_, $class->config);
                                          $p =~ /\.(css|png|js|gif|jpg|ico|html|wav|ttf|svg|woff|woff2|eot|)$/mx;
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

    #&timing_breakpoint('startup()');

    $self->{'errors'} = [];

    $config = $Thruk::Utils::IO::config;
    if(!$config) {
        require Thruk::Config;
        $config = Thruk::Config::get_config();
    }
    $self->{'config'} = $config;
    $Thruk::Utils::IO::config = $config;

    for my $key (@Thruk::Action::AddDefaults::stash_config_keys) {
        confess("$key not defined in config,\n".Dumper($config)) unless defined $config->{$key};
    }

    _init_cache($self->{'config'});

    ###################################################
    # load and parse cgi.cfg into $c->config
    unless(Thruk::Utils::read_cgi_cfg(undef, $self->{'config'})) {
        die("\n\n*****\nfailed to load cgi config: ".$self->{'config'}->{'cgi.cfg'}."\n*****\n\n");
    }
    #&timing_breakpoint('startup() cgi.cfg parsed');

    $self->_create_secret_file();
    $self->set_timezone();
    $self->_set_ssi();
    $self->_setup_pidfile();
    $self->_setup_cluster();

    ###################################################
    # create backends
    $self->{'db'} = Thruk::Backend::Manager->new();
    if(Thruk->trace && $Thruk::Backend::Pool::peers) {
        for my $key (@{$Thruk::Backend::Pool::peer_order}) {
            next unless $Thruk::Backend::Pool::peers->{$key}->{'class'};
            next unless $Thruk::Backend::Pool::peers->{$key}->{'class'}->{'live'};
            next unless $Thruk::Backend::Pool::peers->{$key}->{'class'}->{'live'}->{'backend_obj'};
            my $peer_cls = $Thruk::Backend::Pool::peers->{$key}->{'class'}->{'live'}->{'backend_obj'};
            $peer_cls->{'logger'} = $self->log;
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

    $self->{'route_pattern'} = [
        [ '^/thruk/r/v1.*'                   ,'Thruk::Controller::rest_v1::index' ],
        [ '^/thruk/r/.*'                     ,'Thruk::Controller::rest_v1::index' ],
    ];

    ###################################################
    # load routes dynamically from plugins
    our $routes_already_loaded;
    $routes_already_loaded = {} unless defined $routes_already_loaded;
    for my $plugin_dir (glob($self->{'config'}->{'plugin_path'}.'/plugins-enabled/*/lib/Thruk/Controller/*.pm')) {
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
                $self->log->error("error while loading routes from ".$route_file.": ".$@);
                confess($@);
            }
            $routes_already_loaded->{$route_file} = 1;
        }
        elsif($plugin_dir =~ m|^.*/plugins-enabled/[^/]+/lib/(.*)\.pm|gmx) {
            my $plugin_class = $1;
            $plugin_class =~ s|/|::|gmx;
            eval {
                load $plugin_class;
                $plugin_class->add_routes($self, $self->{'routes'});
            };
            my $err = $@;
            $self->log->error("disabled broken plugin $plugin_class: ".$err) if $err;
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

    Thruk::Views::ToolkitRenderer::register($self, {config => $self->{'config'}->{'View::TT'}});

    ###################################################
    my $c = Thruk::Context->new($self, {'PATH_INFO' => '/dummy-internal'.__FILE__.':'.__LINE__});
    Thruk::Utils::LMD::check_initial_start($c, $config, 1);
    $self->cluster->register($c);

    binmode(STDOUT, ":encoding(UTF-8)");
    binmode(STDERR, ":encoding(UTF-8)");

    #&timing_breakpoint('start done');

    $thruk = $self unless $thruk;
    return(\&{_dispatcher});
}

###################################################
sub _dispatcher {
    my($env) = @_;

    $Thruk::COUNT++;
    #&timing_breakpoint("_dispatcher: ".$env->{PATH_INFO}, "reset");
    # connection keep alive breaks IE in development server
    if($ENV{'THRUK_SRC'} eq 'DebugServer' || $ENV{'THRUK_SRC'} eq 'TEST') {
        delete $env->{'HTTP_CONNECTION'};
    }
    my $c = Thruk::Context->new($thruk, $env);
    $c->cluster->register($c);
    my $enable_profiles = 0;
    if($c->req->cookies->{'thruk_profiling'}) {
        $enable_profiles = 1;
        $c->stash->{'user_profiling'} = 1;
    }
    local $ENV{'THRUK_PERFORMANCE_DEBUG'} = 1 if $enable_profiles;
    my $url = $c->req->url;
    $c->stats->profile(begin => "_dispatcher: ".$url);
    $c->stats->profile(comment => sprintf('time: %s - host: %s - pid: %s - req: %s', (scalar localtime), $c->config->{'hostname'}, $$, $Thruk::COUNT));

    if(Thruk->verbose) {
        $c->log->debug($url);
        $c->log->debug(Dumper($c->req->parameters));
    }

    ###############################################
    # prepare request
    $c->{'errored'} = 0;
    local $Thruk::Request::c = $c if $Thruk::Request::c;
          $Thruk::Request::c = $c;

    Thruk::Action::AddDefaults::begin($c);
    #&timing_breakpoint("_dispatcher begin done");

    ###############################################
    # route cgi request
    unless($c->{'errored'}) {
        my $path_info = $c->req->path_info;
        eval {
            my $rc;
            if(my $route = $thruk->_find_route_match($path_info)) {
                if(ref $route eq '') {
                    my($class) = $route =~ m|^(.*)::.*?$|mx;
                    load $class;
                    $thruk->{'routes'}->{$path_info} = \&{$route};
                    $route = $thruk->{'routes'}->{$path_info};
                }
                #&timing_breakpoint("_dispatcher route");
                $rc = &{$route}($c, $path_info);
                #&timing_breakpoint("_dispatcher route done");
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
        if($@) {
            $c->error($@);
            $c->log->error("Error in: ".$path_info);
            $c->log->error(longmess($@));
            Thruk::Controller::error::index($c, 13);
        }
    }
    unless($c->{'rendered'}) {
        Thruk::Action::AddDefaults::end($c);
        if(!$c->stash->{'template'}) {
            confess(Dumper("not rendered and no template for: ", $c->req, $c->stash->{'text'}));
        }
        Thruk::Views::ToolkitRenderer::render_tt($c);
    }

    my $res = $c->res->finalize;
    $c->stats->profile(end => "_dispatcher: ".$url);

    # restore timezone setting
    $thruk->set_timezone($c->config->{'_server_timezone'});

    _after_dispatch($c, $res);
    $Thruk::Request::c = undef unless $ENV{'THRUK_KEEP_CONTEXT'};
    return($res);
}

###################################################
sub _find_route_match {
    my($self, $path_info) = @_;
    return $self->{'routes'}->{$path_info} if $self->{'routes'}->{$path_info};
    for my $r (@{$self->{'route_pattern'}}) {
        if($path_info =~ m/$r->[0]/mx) {
            return($r->[1]);
        }
    }
    return;
}

###################################################

=head2 config

    make config accessible via Thruk->config

=cut
sub config {
    unless($config) {
        require Thruk::Config;
        $config = Thruk::Config::get_config();
    }
    return($config);
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

=head2 log

    make log accessible via Thruk->log

=cut
sub log {
    if($_[0]->{'_log'} && $_[0]->{'_log'} eq 'screen') {
        $_[0]->init_logging(1);
    }
    return($_[0]->{'_log'} ||= $_[0]->init_logging());
}

###################################################

=head2 reset_logging

    reset logging system, for example after starting child processes

=cut
sub reset_logging {
    my($self) = @_;

    my $appenders = Log::Log4perl::appenders();
    for my $name (keys %{$appenders}) {
        my $appender = $appenders->{$name};
        if($appender->{'appender'} && $appender->{'appender'}->{'fh'}) {
            # enable closing logs for forked childs
            $appender->{'appender'}->{'close'} = 1;
            $appender->{'appender'}->{'close_after_write'} = 1;

            # makes Log::Log4perl::Appender::File reopen its filehandle
            $appender->{'appender'}->{'recreate'} = 1;

            # result in write on close fh otherwise
            CORE::close($appender->{'appender'}->{'fh'});
            undef $appender->{'appender'}->{'fh'};
        }
    }

    return;
}

###################################################

=head2 verbose

    make verbose accessible via Thruk->verbose

=cut
sub verbose {
    if($ENV{'THRUK_VERBOSE'}) {
        return(1);
    }
    return(0);
}

###################################################

=head2 debug

    make debug accessible via Thruk->debug

=cut
sub debug {
    if($ENV{'THRUK_VERBOSE'} && $ENV{'THRUK_VERBOSE'} >= 2) {
        return(1);
    }
    return(0);
}

###################################################

=head2 trace

    make trace accessible via Thruk->trace

=cut
sub trace {
    if($ENV{'THRUK_VERBOSE'} && $ENV{'THRUK_VERBOSE'} >= 4) {
        return(1);
    }
    return(0);
}

###################################################
# init cache
sub _init_cache {
    my($config) = @_;
    load Thruk::Utils::Cache, qw/cache/;
    Thruk::Utils::IO::mkdir($config->{'tmp_path'});
    return Thruk::Utils::Cache->cache($config->{'tmp_path'}.'/thruk.cache');
}

###################################################
# mod_fcgid sends a SIGTERM on timeouts, so try to determine if this is a normal
# exit or not and print the stacktrace if not.
sub _check_exit_reason {
    my($sig) = @_;
    my $reason = longmess();
    my $now    = time();
    ## no critic
    if($reason =~ m|Thruk::Utils::CLI::_from_local|mx && -t 0) {
    ## use critic
        # this means someone hit ctrl+c, no need for a stracktrace then
        print STDERR "\nbailing out\n";
        return;
    }
    # if we are in run_app, this means we are currently processing a request
    if((defined $Thruk::Request::c && $now - $Thruk::Request::c->stash->{'time_begin'}->[0] > 10)
       || $reason =~ m|Plack::Util::run_app|gmx) {
        local $| = 1;
        my $c = $Thruk::Request::c;
        my $url = $c->req->url;
        printf(STDERR "ERROR: got signal %s while handling request, possible timeout in %s\n", $sig, $url);
        printf(STDERR "ERROR: User: %s\n", $c->stash->{'remote_user'}) if $c->stash->{'remote_user'};
        printf(STDERR "ERROR: Address: %s\n", $c->req->address) if $c->req->address;
        if($c->stash->{errorDetails}) {
            for my $row (split(/\n|<br>/mx, $c->stash->{errorDetails})) {
                printf(STDERR "ERROR: %s\n", $row);
            }
        }
        printf(STDERR "ERROR: Stacktrace: \n%s\n", $reason);
        # send sigusr1 to lmd to create a backtrace
        if($c->config->{'use_lmd_core'}) {
            Thruk::Utils::LMD::kill_if_not_responding($c, $c->config);
        }
    }
    return;
}

###################################################
# save pid
my $pidfile;
sub _setup_pidfile {
    my($self) = @_;
    $pidfile  = $self->config->{'tmp_path'}.'/thruk.pid';
    if(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'FastCGI') {
        -s $pidfile || unlink($self->config->{'tmp_path'}.'/thruk.cache');
        open(my $fh, '>>', $pidfile) || warn("cannot write $pidfile: $!");
        print $fh $$."\n";
        Thruk::Utils::IO::close($fh, $pidfile);
    }
    return;
}

###################################################
sub _remove_pid {
    return unless $pidfile;
    ## no critic
    $SIG{PIPE} = 'IGNORE';
    ## use critic
    if(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'FastCGI') {
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
        }
    }
    return;
}

## no critic
$SIG{INT}  = sub { _check_exit_reason("INT");  _remove_pid(); exit; };
$SIG{TERM} = sub { _check_exit_reason("TERM"); _remove_pid(); exit; };
$SIG{PIPE} = sub { _check_exit_reason("PIPE"); _remove_pid(); exit; };
$SIG{ALRM} = sub { _check_exit_reason("ALRM"); _remove_pid(); exit; };
## use critic
END {
    _remove_pid();
    $cluster->unregister() if $cluster;
}

###################################################
# create secret file
sub _create_secret_file {
    my($self) = @_;
    if(!defined $ENV{'THRUK_SRC'} || $ENV{'THRUK_SRC'} ne 'SCRIPTS') {
        my $var_path   = $self->config->{'var_path'} or die("no var path!");
        my $secretfile = $var_path.'/secret.key';
        unless(-s $secretfile) {
            load Digest::MD5, qw(md5_hex);
            my $digest = md5_hex(rand(1000).time());
            chomp($digest);
            open(my $fh, '>', $secretfile) or warn("cannot write to $secretfile: $!");
            if(defined $fh) {
                print $fh $digest;
                Thruk::Utils::IO::close($fh, $secretfile);
                chmod(0640, $secretfile);
            }
            $self->config->{'secret_key'} = $digest;
        } else {
            my $secret_key = read_file($secretfile);
            chomp($secret_key);
            $self->config->{'secret_key'} = $secret_key;
        }
    }
    return;
}

###################################################

=head2 set_timezone

    set servers timezone

=cut
sub set_timezone {
    my($self, $timezone) = @_;
    $self->config->{'_server_timezone'} = $self->_detect_timezone() unless $self->config->{'_server_timezone'};

    if(!defined $timezone) {
        $timezone = $self->config->{'server_timezone'} || $self->config->{'use_timezone'} || $self->config->{'_server_timezone'};
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
    my($self) = @_;
    load Digest::MD5, qw(md5_hex);
    chomp(my $hostname = `hostname`);
    $self->config->{'hostname'} = $hostname unless $self->config->{'hostname'};
    $Thruk::HOSTNAME            = $self->config->{'hostname'};
    $Thruk::NODE_ID_HUMAN       = $self->config->{'hostname'}."-".$self->{'config'}->{'home'}."-".abs_path($ENV{'THRUK_CONFIG'} || '.');
    $Thruk::NODE_ID             = md5_hex($Thruk::NODE_ID_HUMAN);
    return;
}

###################################################
# set installed server side includes
sub _set_ssi {
    my($self) = @_;
    my $ssi_dir = $self->config->{'ssi_path'};
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
    $self->config->{'ssi_includes'} = \%ssi;
    $self->config->{'ssi_path'}     = $ssi_dir;
    return;
}

###################################################

=head2 init_logging

    initialize logging

returns logger object

=cut

sub init_logging {
    my($self, $screen) = @_;
    my($log4perl_conf, $logger);
    if(!defined $ENV{'THRUK_SRC'} || ($ENV{'THRUK_SRC'} ne 'CLI' && $ENV{'THRUK_SRC'} ne 'SCRIPTS')) {
        if(defined $self->config->{'log4perl_conf'} && ! -s $self->config->{'log4perl_conf'} ) {
            die("\n\n*****\nfailed to load log4perl config: ".$self->config->{'log4perl_conf'}.": ".$!."\n*****\n\n");
        }
        $log4perl_conf = $self->config->{'log4perl_conf'} || $self->config->{'home'}.'/log4perl.conf';
    }
    if(!$screen && defined $log4perl_conf && -s $log4perl_conf) {
        require Log::Log4perl;
        Log::Log4perl::init($log4perl_conf);
        $logger = Log::Log4perl::get_logger();
        $self->{'_log'} = $logger;
        $self->config->{'log4perl_conf_in_use'} = $log4perl_conf;
    }
    else {
        require Log::Log4perl;
        my $log_conf = q(
        log4perl.logger                    = DEBUG, Screen
        log4perl.appender.Screen           = Log::Log4perl::Appender::Screen
        log4perl.appender.Screen.Threshold = DEBUG
        log4perl.appender.Screen.layout    = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Screen.layout.ConversionPattern = [%d{ABSOLUTE}][%p][%c] %m%n
        );
        $log_conf =~ s/Threshold\s*=\s*\w+$/Threshold = ERROR/gmx if $ENV{'THRUK_QUIET'};
        Log::Log4perl::init(\$log_conf);
        $logger = Log::Log4perl->get_logger();
        $self->{'_log'} = $logger;
    }
    if(Thruk->verbose) {
        $logger->level('DEBUG');
        $logger->debug("logging initialized");
    }
    else {
        $logger->level('INFO');
    }
    $logger->level('ERROR') if $ENV{'THRUK_QUIET'};
    return($logger);
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
            `omd status crontab >/dev/null 2>&1 && omd reload crontab > /dev/null`;
            $self->log->info("enabled cronfile for plugin: ".$plugin_name);
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
            $self->log->info("removed old plugin cronfile: ".$file);
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
    $h->push('Cache-Control', 'no-store, must-revalidate');
    $h->push('Expires', '0');
    return($content_length);
}

###################################################
sub _after_dispatch {
    my($c, $res) = @_;
    $c->stats->profile(begin => "_after_dispatch");

    if($ENV{THRUK_LEAK_CHECK}) {
        eval {
            require Devel::Cycle;
            $Devel::Cycle::FORMATTING = "cooked";
        };
        print STDERR $@ if $@ && $c->config->{'thruk_debug'};
        unless($@) {
            my $counter = 0;
            $Devel::Cycle::already_warned{'GLOB'}++;
            Devel::Cycle::find_cycle($c, sub {
                my($path) = @_;
                $counter++;
                $c->log->error("found leaks:") if $counter == 1;
                $c->log->error("Cycle ($counter):");
                foreach (@{$path}) {
                    my($type,$index,$ref,$value,$is_weak) = @{$_};
                    $c->log->error(sprintf "\t%30s => %-30s\n",($is_weak ? 'w-> ' : '').Devel::Cycle::_format_reference($type,$index,$ref,0),Devel::Cycle::_format_reference(undef,undef,$value,1));
                }
            });
        }
    }

    my $elapsed = tv_interval($c->stash->{'time_begin'});
    $c->stats->profile(end => "_after_dispatch");
    $c->stats->profile(comment => 'total time waited on backends:  '.sprintf('%.2fs', $c->stash->{'total_backend_waited'})) if $c->stash->{'total_backend_waited'};
    $c->stats->profile(comment => 'total time waited on rendering: '.sprintf('%.2fs', $c->stash->{'total_render_waited'}))  if $c->stash->{'total_render_waited'};
    $c->stash->{'time_total'} = $elapsed;

    my($url) = ($c->req->url =~ m#.*?/thruk/(.*)#mxo);
    if($ENV{'THRUK_PERFORMANCE_DEBUG'} && $c->stash->{'inject_stats'}) {
        # inject stats into html page
        push @{$c->stash->{'profile'}}, $c->stats->report();
        push @{$c->stash->{'profile'}}, @{Thruk::Template::Context::get_profiles()} if $tt_profiling;
        my $stats = "";
        Thruk::Views::ToolkitRenderer::render($c, "_internal_stats.tt", $c->stash, \$stats);
        $res->[2]->[0] =~ s/<\/body>/$stats<\/body>/gmx if ref $res->[2] eq 'ARRAY';
        Thruk::Template::Context::reset_profiles() if $tt_profiling;
    }

    my $content_length = _set_content_length($res);

    # last possible time to report/save profile
    Thruk::Utils::External::save_profile($c, $ENV{'THRUK_JOB_DIR'}) if $ENV{'THRUK_JOB_DIR'};

    if($ENV{'THRUK_PERFORMANCE_DEBUG'} and $c->stash->{'memory_begin'}) {
        $c->stash->{'memory_end'} = Thruk::Backend::Pool::get_memory_usage();
        $url     = $c->req->url unless $url;
        $url     =~ s|^https?://[^/]+/|/|mxo;
        $url     =~ s/^cgi\-bin\///mxo;
        if(length($url) > 80) { $url = substr($url, 0, 80).'...' }
        if(!$url) { $url = $c->req->url; }
        my $waited = [];
        push @{$waited}, $c->stash->{'total_backend_waited'} ? sprintf("%.3fs", $c->stash->{'total_backend_waited'}) : '-';
        push @{$waited}, $c->stash->{'total_render_waited'} ? sprintf("%.3fs", $c->stash->{'total_render_waited'}) : '-';
        $c->log->info(sprintf("%5d Req: %03d   mem:%7s MB %6s MB   dur:%6ss %16s   size:% 12s   stat: %d   url: %s",
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
    $c->log->debug($c->stats->report()) if Thruk->debug;

    # restore user specific settings
    Thruk::Config::finalize($c);

    # does this process need a restart?
    if($ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'FastCGI') {
        if($c->config->{'max_process_memory'} && $Thruk::COUNT && $Thruk::COUNT%10 == 0) {
            Thruk::Utils::check_memory_usage($c);
        }
    }

    return;
}

###################################################
# try to detect current timezone
# Locations like Europe/Berlin are prefered over CEST
sub _detect_timezone {
    my($self) = @_;

    if($ENV{'TZ'}) {
        $self->log->debug(sprintf("server timezone: %s (from ENV)", $ENV{'TZ'})) if Thruk->verbose;
        return($ENV{'TZ'});
    }

    if(-r '/etc/timezone') {
        chomp(my $tz = read_file('/etc/timezone'));
        if($tz) {
            $self->log->debug(sprintf("server timezone: %s (from /etc/timezone)", $tz)) if Thruk->verbose;
            return $tz;
        }
    }

    if(-r '/etc/sysconfig/clock') {
        my $content = read_file('/etc/sysconfig/clock');
        if($content =~ m/^\s*ZONE="([^"]+)"/mx) {
            $self->log->debug(sprintf("server timezone: %s (from /etc/sysconfig/clock)", $1)) if Thruk->verbose;
            return $1;
        }
        if($content =~ m/^\s*TIMEZONE="([^"]+)"/mx) {
            $self->log->debug(sprintf("server timezone: %s (from /etc/sysconfig/clock)", $1)) if Thruk->verbose;
            return $1;
        }
    }

    my $out = `timedatectl 2>/dev/null`;
    if($out =~ m/^\s*Time\ zone:\s+(\S+)/mx) {
        $self->log->debug(sprintf("server timezone: %s (from timedatectl)", $1)) if Thruk->verbose;
        return($1);
    }

    # returns CEST instead of CET as well
    POSIX::tzset();
    my($std, $dst) = POSIX::tzname();
    if($std) {
        $self->log->debug(sprintf("server timezone: %s (from POSIX::tzname)", $std)) if Thruk->verbose;
        return($std);
    }

    # last ressort, date, fails for ex. to set CET instead of CEST
    chomp(my $tz = `date +%Z`);
    $self->log->debug(sprintf("server timezone: %s (from date +%%Z)", $tz)) if Thruk->verbose;
    return $tz;
}
###################################################

=head1 SEE ALSO

L<Thruk::Controller::Root>, L<Plack>

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
