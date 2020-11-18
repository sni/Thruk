package Thruk::Utils::CLI::Logcache;

=head1 NAME

Thruk::Utils::CLI::Logcache - Logcache CLI module

=head1 DESCRIPTION

The logcache command creates/updates the mysql/mariadb logfile cache.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] logcache <command> [--start=time]

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<command>

    Available commands are:

        - import                    Initially import all logfiles
                 [--blocksize=...]  sets the amount of logfiles fetched in one
                                    import block. Default: 1d
                 [--start=... ]     Set the relative start point to import from.
                                    No default, will import all available logfiles
                                    if not set. Ex.: --start=1y
        - update                    Delta update all logfiles since last import/update.
        - stats                     Display logcache statistics.
        - authupdate                Update authentication data.
        - optimize                  Run table optimize.
        - clean [duration]          Clean cache and keep everything within given duration (in days). Defaults to `logcache_clean_duration`
        - compact [duration]        Compact cache and remove unnecessary thins. Duration is given in in days). Defaults to `logcache_compact_duration`
        - removeunused              Remove unused tables for no longer existing backends.
        - drop                      Remove all tables and data.

=back

=cut

use warnings;
use strict;
use Thruk::Utils ();
use Thruk::Utils::Log qw/:all/;
use Time::HiRes qw/gettimeofday tv_interval/;
use Getopt::Long ();

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions, undef, $src, $global_options) = @_;
    $c->stats->profile(begin => "_cmd_import_logs($action)");

    if(!$c->check_user_roles('authorized_for_admin')) {
        return("ERROR - authorized_for_admin role required", 1);
    }

    my $mode = shift @{$commandoptions};

    if(!defined $c->config->{'logcache'}) {
        return("FAILED - logcache is not enabled\n", 1);
    }

    return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__)) unless $mode;

    ## no critic
    my $terminal_attached = -t 0 ? 1 : 0;
    ## use critic

    # parse options
    my $opt = {};
    Getopt::Long::Configure('no_ignore_case');
    Getopt::Long::Configure('bundling');
    Getopt::Long::Configure('pass_through');
    Getopt::Long::GetOptionsFromArray($commandoptions,
       "s|start=s"          => \$opt->{'start'},
       "blocksize=s"        => \$opt->{'blocksize'},
    ) or do {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    };

    my $blocksize;
    if($mode eq 'import') {
        if($opt->{'blocksize'}) {
            $blocksize = Thruk::Utils::expand_duration($opt->{'blocksize'});
        } else {
            if(defined $commandoptions->[0] && $commandoptions->[0] =~ m/^\d+$/mx) {
                $blocksize = Thruk::Utils::expand_duration(shift @{$commandoptions});
            }
        }
    } elsif($mode eq 'clean') {
        $blocksize = $opt->{'start'} || shift @{$commandoptions} || $c->config->{'logcache_clean_duration'};
        # blocksize is given in days unless specified
        if($blocksize !~ m/^\d+$/mx) {
            $blocksize = Thruk::Utils::expand_duration($blocksize) / 86400;
        }
    } elsif($mode eq 'compact') {
        $blocksize = $opt->{'start'} || shift @{$commandoptions} || $c->config->{'logcache_compact_duration'};
        # blocksize is given in days unless specified
        if($blocksize !~ m/^\d+$/mx) {
            $blocksize = Thruk::Utils::expand_duration($blocksize) / 86400;
        }
    }

    $opt->{'force'} = $global_options->{'force'};
    $opt->{'yes'}   = $global_options->{'yes'};
    $opt->{'files'} = \@{$commandoptions};

    if($src ne 'local' and $mode eq 'import') {
        return("ERROR - please run the initial import with --local\n", 1);
    }

    my $type = '';
    $type = 'mysql' if $c->config->{'logcache'} =~ m/^mysql/mxi;

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

    Thruk::Action::AddDefaults::set_possible_backends($c, {}) unless defined $c->stash->{'backends'};
    my $backends = $c->stash->{'backends'};

    if($mode eq 'import' && !$global_options->{'yes'}) {
        # check if tables already existing
        my $exist = 0;
        for my $peer_key (@{$backends}) {
            my($stats) = Thruk::Backend::Provider::Mysql->_log_stats($c, $peer_key);
            if($stats && $stats->{'items'} > 0) {
                printf("logcache does already exist for backend: %s.\n", $stats->{'name'});
                $exist = 1;
            }
        }

        if($exist) {
            local $|=1;
            print "Import removes current cache and imports new logfile data.\n";
            print "Use 'thruk logcache update' to delta update the cache.\nContinue? [n]: ";
            my $buf;
            sysread STDIN, $buf, 1;
            if($buf !~ m/^(y|j)/mxi) {
                return("canceled\n", 1);
            }
        }
    }

    if($mode eq 'drop' && !$global_options->{'yes'}) {
        local $|=1;
        print "Do you really want to drop all data and remove the logcache?\nContinue? [n]: ";
        my $buf;
        sysread STDIN, $buf, 1;
        if($buf !~ m/^(y|j)/mxi) {
            return("canceled\n", 1);
        }
    }

    if($mode eq 'clean' && !$global_options->{'yes'} && $terminal_attached) {
        local $|=1;
        my $start = time() - (($blocksize // 365) * 86400);
        printf("Do you really want to drop all data older than %s?\nContinue? [n]: ", scalar localtime($start));
        my $buf;
        sysread STDIN, $buf, 1;
        if($buf !~ m/^(y|j)/mxi) {
            return("canceled\n", 1);
        }
    }
    if($mode eq 'compact' && !$global_options->{'yes'} && $terminal_attached) {
        local $|=1;
        my $start = time() - (($blocksize // 365) * 86400);
        printf("Do you really want to compact data older than %s?\nContinue? [n]: ", scalar localtime($start));
        my $buf;
        sysread STDIN, $buf, 1;
        if($buf !~ m/^(y|j)/mxi) {
            return("canceled\n", 1);
        }
    }

    if($mode eq 'stats') {
        my $stats;
        $stats= Thruk::Backend::Provider::Mysql->_log_stats($c);
        $c->stats->profile(end => "_cmd_import_logs($action)");
        Thruk::Backend::Manager::close_logcache_connections($c);
        return($stats, 0);
    }
    elsif($mode eq 'removeunused') {
        my $stats= Thruk::Backend::Provider::Mysql->_log_removeunused($c);
        Thruk::Backend::Manager::close_logcache_connections($c);
        $c->stats->profile(end => "_cmd_import_logs($action)");
        return($stats."\n", 0);
    } else {
        my $t0 = [gettimeofday];
        my($backend_count, $log_count, $errors) = Thruk::Backend::Provider::Mysql->_import_logs($c, $mode, undef, $blocksize, $opt);
        my $elapsed = tv_interval($t0);
        $c->stats->profile(end => "_cmd_import_logs($action)");
        my $plugin_ref_count;
        if($mode eq 'clean' || $mode eq 'compact') {
            $plugin_ref_count = $log_count->[1];
            $log_count        = $log_count->[0];
        }
        my $action = "imported";
        $action    = "updated"   if $mode eq 'authupdate';
        $action    = "removed"   if $mode eq 'clean';
        $action    = "compacted" if $mode eq 'compact';
        Thruk::Backend::Manager::close_logcache_connections($c);
        return("\n", 1) if $log_count == -1;
        my($rc, $msg) = (0, 'OK');
        my $res = 'successfully';
        if(scalar @{$errors} > 0) {
            $res = 'with '.scalar @{$errors}.' errors';
            ($rc, $msg) = (1, 'ERROR');
        }

        my $details = scalar @{$errors} > 0 ? join("\n", @{$errors})."\n" : "";
        if($mode eq 'drop') {
            return(sprintf("%s - droped logcache for %i site%s in %.2fs\n%s",
                           $msg,
                           $backend_count,
                           ($backend_count == 1 ? '' : 's'),
                           ($elapsed),
                           $details,
                           ), $rc);
        }
        if($mode eq 'optimize') {
            return(sprintf("%s - optimized logcache for %i site%s in %.2fs\n%s",
                           $msg,
                           $backend_count,
                           ($backend_count == 1 ? '' : 's'),
                           ($elapsed),
                           $details,
                           ), $rc);
        }
        if($mode eq 'compact') {
        return(sprintf("%s - %s %i log items and removed %d%s from %i site%s %s in %.2fs (%i/s)\n%s",
                       $msg,
                       $action,
                       $log_count,
                       $plugin_ref_count,
                       $log_count > 0 ? " (".int(($plugin_ref_count / $log_count)*100)."%)" : '',
                       $backend_count,
                       ($backend_count == 1 ? '' : 's'),
                       $res,
                       ($elapsed),
                       (($elapsed > 0 && $log_count > 0) ? ($log_count / ($elapsed)) : $log_count),
                       $details,
                       ), $rc);
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

=head1 EXAMPLES

Initial import

  %> thruk logcache import --local

Initial import, but only import last 3 weeks and fetch 12 hours per import block

  %> thruk logcache import --local --start=3w --blocksize=12h

Run delta update with logfiles retrieved by livestatus

  %> thruk logcache update

Run update from given files. (Also possible for initial import)

  %> thruk logcache update /var/log/naemon/archive/2017-07-*.log

Prune logcache data older than 3 years

  %> thruk logcache clean 3y

Remove logcache data completly

  %> thruk logcache drop

=cut

##############################################

1;
