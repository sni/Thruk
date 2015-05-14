package Thruk;

=head1 NAME

Thruk - Monitoring Web Interface

=head1 DESCRIPTION

Monitoring web interface for Naemon, Nagios, Icinga and Shinken.

=cut

use strict;
use warnings;

use 5.008000;

our $VERSION = '1.88';

###################################################
# create connection pool
# has to be done before the binmode
# or even earlier to save memory
use Thruk::Backend::Pool;
BEGIN {
    Thruk::Backend::Pool::init_backend_thread_pool();
};

###################################################
# load timing class
BEGIN {
    #use Thruk::Timer qw/timing_breakpoint/;
    #&timing_breakpoint('starting thruk');
};

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
    ADD_DEFAULTS        => 0,
    ADD_SAFE_DEFAULTS   => 1,
    ADD_CACHED_DEFAULTS => 2,
};
use Carp qw/confess/;
use POSIX qw(tzset);
use Digest::MD5 qw(md5_hex);
use File::Slurp qw(read_file);
use Data::Dumper;
use Module::Load qw/load/;
use Thruk::Context;
use Thruk::Utils;
use Thruk::Utils::Auth;
use Thruk::Utils::External;
use Thruk::Utils::Livecache;
use Thruk::Utils::Menu;
use Thruk::Utils::Status;
use Thruk::Utils::Cache qw/cache/;
use Thruk::Action::AddDefaults;
use Thruk::Backend::Manager;
use Thruk::Views::ToolkitRenderer;
use Thruk::Views::ExcelRenderer;
use Thruk::Views::GDRenderer;
use Thruk::Views::JSONRenderer;

###################################################
$Data::Dumper::Sortkeys = 1;
our $config;
our $COUNT = 0;

###################################################

=head1 METHODS

=head2 startup

returns the psgi code ref

=cut
sub startup {
    my($class) = @_;
    my $app = $class->_build_app();

    # middleware is in reverse order because it wraps each other
    if($ENV{'THRUK_SRC'} eq 'DebugServer' || $ENV{'THRUK_SRC'} eq 'TEST') {
        require Plack::Middleware::Lint;
        $app = Plack::Middleware::Lint->wrap($app);
    }

    require Plack::Middleware::ContentLength;
    $app = Plack::Middleware::ContentLength->wrap($app);

    if($ENV{'THRUK_SRC'} eq 'DebugServer' || $ENV{'THRUK_SRC'} eq 'TEST') {
        require  Plack::Middleware::Static;
        $app = Plack::Middleware::Static->wrap($app, path => qr{\.(css|png|js|gif|jpg|ico|html|wav)$}mx, root => './root/', pass_through => 1);
    }

    return($app);
}

###################################################
sub _build_app {
    my($class) = @_;
    my $self = {};
    bless($self, $class);

    #&timing_breakpoint('startup()');

    #if(Thruk->debug) {
    #    $ENV{'THRUK_PERFORMANCE_DEBUG'} = 3 unless defined $ENV{'THRUK_PERFORMANCE_DEBUG'};
    #}
    #elsif(Thruk->verbose) {
    #    $ENV{'THRUK_PERFORMANCE_DEBUG'} = 1 unless defined $ENV{'THRUK_PERFORMANCE_DEBUG'};
    #}

    $self->{'errors'} = [];

    $config = $Thruk::Utils::IO::config;
    if(!$config) {
        require Thruk::Config;
        $config = Thruk::Config::get_config();
    }
    $self->{'config'} = $config;
    $self->_init_logging();

    _init_cache($self->{'config'});
    #&timing_breakpoint('startup() cache created');

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
    #&timing_breakpoint('startup() backends created');

    $self->{'routes'} = {
        '/thruk/cgi-bin/avail.cgi'         => 'Thruk::Controller::avail::index',
        '/thruk/cgi-bin/cmd.cgi'           => 'Thruk::Controller::cmd::index',
        '/thruk/cgi-bin/config.cgi'        => 'Thruk::Controller::config::index',
        '/thruk/cgi-bin/extinfo.cgi'       => 'Thruk::Controller::extinfo::index',
        '/thruk/cgi-bin/history.cgi'       => 'Thruk::Controller::history::index',
        '/thruk/cgi-bin/login.cgi'         => 'Thruk::Controller::login::index',
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
    };
    load 'Thruk::Controller::Root';
    $self->{'routes'} = {%{Thruk::Controller::Root::add_routes()}, %{$self->{'routes'}}};

    ###################################################
    # load routes dynamically from plugins
    for my $plugin_dir (glob($self->{'config'}->{'plugin_path'}.'/plugins-enabled/*/lib/Thruk/Controller/*.pm')) {
        $plugin_dir =~ s|^.*/plugins-enabled/[^/]+/lib/(.*)\.pm||gmx;
        my $plugin = $1;
        $plugin =~ s|/|::|gmx;
        load $plugin;
        $plugin->add_routes($self, $self->{'routes'});
    }
    #&timing_breakpoint('startup() plugins loaded');

    Thruk::Views::ToolkitRenderer::register($self, {config => $self->{'config'}->{'View::TT'}});

    ###################################################
    # start shadownaemons in background
    Thruk::Utils::Livecache::check_initial_start(undef, $config, 1);

    binmode(STDOUT, ":encoding(UTF-8)");
    binmode(STDERR, ":encoding(UTF-8)");

    #&timing_breakpoint('start done');

    return(sub { return($self->_dispatcher(@_)) });
}

###################################################
sub _dispatcher {
    my($self, $env) = @_;
    my $c = Thruk::Context->new($self, $env);
    $Thruk::COUNT++;

    $c->stats->profile(begin => "_dispatcher");

    ###############################################
    # prepare request
    $c->{'errored'} = 0;
    $Thruk::Request::c = $c;
    Thruk::Action::AddDefaults::begin($c);

    ###############################################
    # route cgi request
    unless($c->{'errored'}) {
        eval {
            my $path_info = $c->req->path_info;
            my $rc;
            if($self->{'routes'}->{$path_info}) {
                my $route = $self->{'routes'}->{$path_info};
                if(ref $route eq '') {
                    my($class) = $route =~ m|^(.*)::.*?$|mx;
                    load $class;
                    $self->{'routes'}->{$path_info} = \&{$route};
                    $route = $self->{'routes'}->{$path_info};
                }
                $rc = &{$route}($c);
            }
            else {
                return([404, ['Content-Type' => 'text/plain', 'Content-Length' => 9], ['not found']]);
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
            $c->log->error($@);
            Thruk::Controller::error::index($c, 13);
        }
    }
    unless($c->{'rendered'}) {
        Thruk::Action::AddDefaults::end($c);
        Thruk::Views::ToolkitRenderer::render_tt($c);
    }

    $c->stats->profile(end => "_dispatcher");

    $c->stats->profile(begin => "_res_finalize");
    my $res = $c->res->finalize;
    $c->stats->profile(end => "_res_finalize");

    _after_dispatch($c, $res);
    return($res);
}

###################################################

=head2 config

    make config accessible via Thruk->config

=cut
sub config {
    $config = Thruk::Config::get_config() unless $config;
    return($config);
}

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
    return($_[0]->{'log'});
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
# init cache
sub _init_cache {
    my($config) = @_;
    Thruk::Utils::IO::mkdir($config->{'tmp_path'});
    return __PACKAGE__->cache($config->{'tmp_path'}.'/thruk.cache');
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
sub _remove_pid {
    return unless $pidfile;
    $SIG{PIPE} = 'IGNORE';
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
$SIG{INT}  = sub { _remove_pid(); exit; };
$SIG{TERM} = sub { _remove_pid(); exit; };
END {
    _remove_pid();
};

###################################################
# create secret file
sub _create_secret_file {
    my($self) = @_;
    if(!defined $ENV{'THRUK_SRC'} or $ENV{'THRUK_SRC'} ne 'SCRIPTS') {
        my $var_path   = $self->config->{'var_path'} or die("no var path!");
        my $secretfile = $var_path.'/secret.key';
        unless(-s $secretfile) {
            my $digest = md5_hex(rand(1000).time());
            chomp($digest);
            open(my $fh, ">$secretfile") or warn("cannot write to $secretfile: $!");
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
        $ENV{'TZ'} = $timezone;
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
    if(!-e $ssi_dir) {
        warn("cannot access ssi_path $ssi_dir: $!");
    } else {
        opendir( $dh, $ssi_dir) or die "can't opendir '$ssi_dir': $!";
        for my $entry (readdir($dh)) {
            next if $entry eq '.' or $entry eq '..';
            next if $entry !~ /\.ssi$/mx;
            $ssi{$entry} = { name => $entry }
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
    my $log4perl_conf;
    if(!defined $ENV{'THRUK_SRC'} or ($ENV{'THRUK_SRC'} ne 'CLI' and $ENV{'THRUK_SRC'} ne 'SCRIPTS')) {
        if(defined $self->config->{'log4perl_conf'} and ! -s $self->config->{'log4perl_conf'} ) {
            die("\n\n*****\nfailed to load log4perl config: ".$self->config->{'log4perl_conf'}.": ".$!."\n*****\n\n");
        }
        $log4perl_conf = $self->config->{'log4perl_conf'} || $self->config->{'home'}.'/log4perl.conf';
    }
    if(defined $log4perl_conf and -s $log4perl_conf) {
        require Log::Log4perl;
        Log::Log4perl::init($log4perl_conf);
        my $logger = Log::Log4perl::get_logger();
        $self->{'log'} = $logger;
        $self->config->{'log4perl_conf_in_use'} = $log4perl_conf;
    }
    else {
        require Log::Log4perl;
        my $log_conf = q(
        log4perl.logger                    = DEBUG, Screen
        log4perl.appender.Screen           = Log::Log4perl::Appender::Screen
        log4perl.appender.Screen.Threshold = DEBUG
        log4perl.appender.Screen.layout    = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.Screen.layout.ConversionPattern = [%d][%p][%c] %m%n
        );
        Log::Log4perl::init(\$log_conf);
        my $logger = Log::Log4perl->get_logger();
        $self->{'log'} = $logger;
        if(Thruk->verbose) {
            $self->log->level('DEBUG');
        }
        else {
            $self->log->level('INFO');
        }
        $self->log->debug("logging initialized");
    }
    return;
}

###################################################
# SizeMe and other devel internals
if($ENV{'SIZEME'}) {
    # add signal handler to print memory information
    # ps -efl | grep perl | grep thruk_server.pl | awk '{print $4}' | xargs kill -USR1
    $SIG{'USR1'} = sub {
        printf(STDERR "mem:% 7s MB  before devel::sizeme\n", Thruk::Backend::Pool::get_memory_usage());
        eval {
            require Devel::SizeMe;
            Devel::SizeMe::perl_size();
        };
        print STDERR $@ if $@;
    }
}
if($ENV{'MALLINFO'}) {
    # add signal handler to print memory information
    # ps -efl | grep perl | grep thruk_server.pl | awk '{print $4}' | xargs kill -USR2
    $SIG{'USR2'} = sub {
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
    }
}

###################################################
sub _after_dispatch {
    my($c, $res) = @_;
    $c->stats->profile(begin => "_after_dispatch");

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
            Devel::Cycle::find_cycle($c, sub {
                my $path    = shift;
                $counter++;
                $c->log->error("found leaks:") if $counter == 1;
                $c->log->error("Cycle ($counter):");
                foreach (@$path) {
                    my ($type,$index,$ref,$value,$is_weak) = @$_;
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
        $url     =~ s/^cgi\-bin\///mxo;
        if(length($url) > 80) { $url = substr($url, 0, 80).'...' }
        if(!$url) { $url = $c->req->url; }
        $c->log->info(sprintf("Req: %03d  mem:% 7s MB  % 10.2f MB     %.2fs %8s   %d    %s",
                                $Thruk::COUNT,
                                $c->stash->{'memory_end'},
                                ($c->stash->{'memory_end'}-$c->stash->{'memory_begin'}),
                                $elapsed,
                                defined $c->stash->{'total_backend_waited'} ? sprintf('(%.2fs)', $c->stash->{'total_backend_waited'}) : '',
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

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
