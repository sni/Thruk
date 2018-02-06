package Thruk;

=head1 NAME

Thruk - Monitoring Web Interface

=head1 DESCRIPTION

Monitoring web interface for Naemon, Nagios, Icinga and Shinken.

=cut

use strict;
use warnings;

use 5.008000;

our $VERSION = '2.18';

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
BEGIN {
    ## no critic
    if($ENV{'THRUK_VERBOSE'} and $ENV{'THRUK_VERBOSE'} >= 3) {
        $ENV{'THRUK_PERFORMANCE_DEBUG'} = 3;
    }
    eval "use Time::HiRes qw/gettimeofday tv_interval/;" if ($ENV{'THRUK_PERFORMANCE_DEBUG'} and $ENV{'THRUK_PERFORMANCE_DEBUG'} >= 0);
    eval "use Thruk::Template::Context;"                 if ($ENV{'THRUK_PERFORMANCE_DEBUG'} and $ENV{'THRUK_PERFORMANCE_DEBUG'} >= 3);
    ## use critic
}
use constant {
    # backend states
    ADD_DEFAULTS        => 0,
    ADD_SAFE_DEFAULTS   => 1,
    ADD_CACHED_DEFAULTS => 2,
};
use Carp qw/confess longmess/;
use File::Slurp qw(read_file);
use Module::Load qw/load/;
use Data::Dumper qw/Dumper/;
use Plack::Util qw//;

###################################################
$Data::Dumper::Sortkeys = 1;
our $config;
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
    require Thruk::Utils::Livecache;
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
                    path         => sub { my $p = Thruk::Context::translate_request_path($_, $class->config);
                                          $p =~ /\.(css|png|js|gif|jpg|ico|html|wav|ttf|svg|woff|woff2)$/mx;
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
    $self->_set_timezone();
    $self->_set_ssi();
    $self->_setup_pidfile();

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
    # start shadownaemons in background
    Thruk::Utils::Livecache::check_initial_start(undef, $config, 1);
    my $c = Thruk::Context->new($self, {'PATH_INFO' => '/'});
    Thruk::Utils::LMD::check_initial_start($c, $config, 1);

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
    #&timing_breakpoint("_dispatcher: ".$env->{PATH_INFO});
    # connection keep alive breaks IE in development server
    if($ENV{'THRUK_SRC'} eq 'DebugServer' || $ENV{'THRUK_SRC'} eq 'TEST') {
        delete $env->{'HTTP_CONNECTION'};
    }
    my $c = Thruk::Context->new($thruk, $env);
    $c->stats->profile(begin => "_dispatcher: ".$c->req->url);

    if(Thruk->verbose) {
        $c->log->debug($c->req->url);
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
            if($thruk->{'routes'}->{$path_info}) {
                my $route = $thruk->{'routes'}->{$path_info};
                if(ref $route eq '') {
                    my($class) = $route =~ m|^(.*)::.*?$|mx;
                    load $class;
                    $thruk->{'routes'}->{$path_info} = \&{$route};
                    $route = $thruk->{'routes'}->{$path_info};
                }
                #&timing_breakpoint("_dispatcher route");
                $rc = &{$route}($c);
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

    #&timing_breakpoint("_dispatcher finalize");
    my $res = $c->res->finalize;
    $c->stats->profile(end => "_dispatcher: ".$c->req->url);
    #&timing_breakpoint("_dispatcher finalize done");

    _after_dispatch($c, $res);
    $Thruk::Request::c = undef unless $ENV{'THRUK_KEEP_CONTEXT'};
    #&timing_breakpoint("_dispatcher done");
    return($res);
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
    return($_[0]->{'_log'} ||= $_[0]->_init_logging());
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
    if((defined $Thruk::Request::c && $now - $Thruk::Request::c->stash->{'time_begin'} > 10)
       || $reason =~ m|Plack::Util::run_app|gmx) {
        local $| = 1;
        my $url = $Thruk::Request::c ? $Thruk::Request::c->req->url : 'unknown url';
        print STDERR "ERROR: got signal $sig while handling request, possible timeout in $url\n$reason\n";
        # send sigusr1 to lmd to create a backtrace
        if(defined $Thruk::Request::c && $Thruk::Request::c->config->{'use_lmd_core'}) {
            my $c = $Thruk::Request::c;
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
        if($pidfile && -f $pidfile) {
            my $pids = [split(/\s/mx, read_file($pidfile))];
            my $remaining = [];
            for my $pid (@{$pids}) {
                next unless($pid and $pid =~ m/^\d+$/mx);
                next if $pid == $$;
                next if kill(0, $pid) == 0;
                push @{$remaining}, $pid;
            }
            if(scalar @{$remaining} == 0) {
                unlink($pidfile);
                if(__PACKAGE__->config->{'use_shadow_naemon'} and __PACKAGE__->config->{'use_shadow_naemon'} ne 'start_only') {
                    Thruk::Utils::Livecache::shutdown_shadow_naemon_procs(__PACKAGE__->config);
                }
            } else {
                open(my $fh, '>', $pidfile);
                print $fh join("\n", @{$remaining}),"\n";
                CORE::close($fh);
            }
        }
    }
    if(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'DebugServer') {
        # debug server has no pid file, so just kill our shadows
        if(__PACKAGE__->config->{'use_shadow_naemon'} and __PACKAGE__->config->{'use_shadow_naemon'} ne 'start_only') {
            Thruk::Utils::Livecache::shutdown_shadow_naemon_procs(__PACKAGE__->config);
        }
    }
    return;
}

## no critic
$SIG{INT}  = sub { _check_exit_reason("INT");  _remove_pid(); exit; };
$SIG{TERM} = sub { _check_exit_reason("TERM"); _remove_pid(); exit; };
$SIG{PIPE} = sub { _check_exit_reason("TERM"); _remove_pid(); exit; };
## use critic
END {
    _remove_pid();
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
# set timezone
sub _set_timezone {
    my($self) = @_;
    my $timezone = $self->config->{'use_timezone'};
    if(defined $timezone) {
        ## no critic
        $ENV{'TZ'} = $timezone;
        ## use critic
        require POSIX;
        POSIX::tzset();
    }
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
# Logging
sub _init_logging {
    my($self) = @_;
    my($log4perl_conf, $logger);
    if(!defined $ENV{'THRUK_SRC'} || ($ENV{'THRUK_SRC'} ne 'CLI' && $ENV{'THRUK_SRC'} ne 'SCRIPTS')) {
        if(defined $self->config->{'log4perl_conf'} && ! -s $self->config->{'log4perl_conf'} ) {
            die("\n\n*****\nfailed to load log4perl config: ".$self->config->{'log4perl_conf'}.": ".$!."\n*****\n\n");
        }
        $log4perl_conf = $self->config->{'log4perl_conf'} || $self->config->{'home'}.'/log4perl.conf';
    }
    if(defined $log4perl_conf and -s $log4perl_conf) {
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
sub _after_dispatch {
    my($c, $res) = @_;
    $c->stats->profile(begin => "_after_dispatch");

    # set content length
    my $content_length;
    my $h = Plack::Util::headers($res->[1]);
    if (!Plack::Util::status_with_no_entity_body($res->[0]) &&
        !$h->exists('Content-Length') &&
        !$h->exists('Transfer-Encoding') &&
        defined($content_length = Plack::Util::content_length($res->[2])))
    {
        $h->push('Content-Length' => $content_length);
    }

    # check if our shadows are still up and running
    if($c->config->{'shadow_naemon_dir'} and $c->stash->{'failed_backends'} and scalar keys %{$c->stash->{'failed_backends'}} > 0) {
        Thruk::Utils::Livecache::check_shadow_naemon_procs($c->config, $c, 1);
    }

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
    $c->stats->profile(end => "_after_dispatch");
    $c->stats->profile(comment => 'total time waited on backends: '.sprintf('%.2fs', $c->stash->{'total_backend_waited'})) if defined $c->stash->{'total_backend_waited'};

    # restore user specific settings
    Thruk::Config::finalize($c);

    # last possible time to report/save profile
    Thruk::Utils::External::save_profile($c, $ENV{'THRUK_JOB_DIR'}) if $ENV{'THRUK_JOB_DIR'};

    if($ENV{'THRUK_PERFORMANCE_DEBUG'} and $c->stash->{'memory_begin'}) {
        my $elapsed = tv_interval($c->stash->{'time_begin'});
        $c->stash->{'memory_end'} = Thruk::Backend::Pool::get_memory_usage();
        my($url) = ($c->req->url =~ m#.*?/thruk/(.*)#mxo);
        $url     = $c->req->url unless $url;
        $url     =~ s|^https?://[^/]+/|/|mxo;
        $url     =~ s/^cgi\-bin\///mxo;
        if(length($url) > 80) { $url = substr($url, 0, 80).'...' }
        if(!$url) { $url = $c->req->url; }
        $c->log->info(sprintf("%5d Req: %03d   mem:%7s MB %6s MB   dur:%6ss %9s   size:% 12s   stat: %d   url: %s",
                                $$,
                                $Thruk::COUNT,
                                $c->stash->{'memory_end'},
                                sprintf("%.2f", ($c->stash->{'memory_end'}-$c->stash->{'memory_begin'})),
                                sprintf("%.3f", $elapsed),
                                defined $c->stash->{'total_backend_waited'} ? sprintf('(%.3fs)', $c->stash->{'total_backend_waited'}) : '----',
                                defined $content_length ? sprintf("%.3f kb", $content_length/1024) : '----',
                                $res->[0],
                                $url,
                    ));
    }
    $c->log->debug($c->stats->report()) if Thruk->debug;

    # does this process need a restart?
    if($ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'FastCGI') {
        if($c->config->{'max_process_memory'} && $Thruk::COUNT && $Thruk::COUNT%10 == 0) {
            Thruk::Utils::check_memory_usage($c);
        }
    }

    return;
}

=head1 SEE ALSO

L<Thruk::Controller::Root>, L<Plack>

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
