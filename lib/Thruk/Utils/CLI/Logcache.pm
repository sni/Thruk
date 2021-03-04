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
                 [-w|--worker=<nr>] Use this number of worker processes to update all sites.
                                    Defaults to 'auto' which trys to find a suitable number automatically.
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
    my $opt = {
        'worker'    => 'auto',
    };
    Getopt::Long::Configure('no_ignore_case');
    Getopt::Long::Configure('bundling');
    Getopt::Long::Configure('pass_through');
    Getopt::Long::GetOptionsFromArray($commandoptions,
       "s|start=s"      => \$opt->{'start'},
       "blocksize=s"    => \$opt->{'blocksize'},
       "w|worker=i"     => \$opt->{'worker'},
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
        return("ERROR - please run the initial import locally\n", 1);
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

    if($ENV{'THRUK_CRON'} && $mode eq 'update') {
        return("", 0) unless Thruk::Backend::Provider::Mysql::check_global_lock($c);
    }

    my($backends) = $c->{'db'}->select_backends('get_logs');

    if($mode eq 'import' && !$global_options->{'yes'}) {
        # check if tables already existing
        my $exist = 0;
        for my $peer_key (@{$backends}) {
            my($stats) = Thruk::Backend::Provider::Mysql->_log_stats($c, $peer_key);
            if($stats && $stats->{'items'} > 0) {
                _info("logcache does already exist for backend: %s.", $stats->{'name'});
                $exist = 1;
            }
        }

        if($exist) {
            _info("Import removes current cache and imports new logfile data.");
            _info("Use 'thruk logcache update' to delta update the cache.");
            return("canceled\n", 1) unless _user_confirm();
        }
    }

    if($mode eq 'drop' && !$global_options->{'yes'}) {
        _info("Do you really want to drop all data and remove the logcache?");
        return("canceled\n", 1) unless _user_confirm();
    }

    if($mode eq 'clean' && !$global_options->{'yes'} && $terminal_attached) {
        my $start = time() - (($blocksize // 365) * 86400);
        _info("Do you really want to drop all data older than %s?", scalar localtime($start));
        return("canceled\n", 1) unless _user_confirm();
    }
    if($mode eq 'compact' && !$global_options->{'yes'} && $terminal_attached) {
        my $start = time() - (($blocksize // 365) * 86400);
        _info("Do you really want to compact data older than %s?", scalar localtime($start));
        return("canceled\n", 1) unless _user_confirm();
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
        my $worker_num = 1;
        my $num_sites  = scalar @{$backends};
        if($mode eq 'update' || $mode eq 'compact') {
            $worker_num = int($c->config->{'logcache_worker'} || 0);
            if($worker_num == 0) {
                # try to autmatically find a suitable number of workers
                $worker_num = 1;
                if($num_sites > 10) {
                    $worker_num = 2;
                }
                if($num_sites > 20) {
                    $worker_num = 3;
                }
                if($num_sites > 100) {
                    $worker_num = 5;
                }
            }
            if($opt->{'worker'} ne 'auto') {
                $worker_num = $opt->{'worker'};
            }
            if($worker_num <= 0) {
                $worker_num = 1;
            }
            if($worker_num > $num_sites) {
                $worker_num = $num_sites;
            }
        }

        _debug("running ".$mode." command with ".$worker_num." workers") if $worker_num > 1;
        my @child_pids;
        my $chunks           = Thruk::Utils::array_chunk($backends, $worker_num);
        my $rc               = 0;
        my $plugin_ref_count = 0;
        my $log_count        = 0;
        my $errors           = [];
        my $t0               = [gettimeofday];
        for my $chunk (@{$chunks}) {
            my $child_pid;
            if($worker_num > 1) {
                $child_pid = fork();
                die("failed to fork: $!") if $child_pid == -1;
            }
            if(!$child_pid) {
                if($worker_num > 1) {
                    Thruk::Utils::External::do_child_stuff($c);
                }
                my $local_rc = 0;
                my $total = scalar @{$chunk};
                my $nr    = 0;
                my $numsize = length("$total");
                for my $backend (@{$chunk}) {
                    my $t1 = [gettimeofday];
                    $nr++;
                    eval {
                        my $t0 = [gettimeofday];
                        my(undef, $loc_log_count, $loc_errors) = Thruk::Backend::Provider::Mysql->_import_logs($c, $mode, $backend, $blocksize, $opt);
                        my $elapsed = tv_interval($t0);
                        $c->stats->profile(end => "_cmd_import_logs($action)");
                        if($mode eq 'clean' || $mode eq 'compact') {
                            $plugin_ref_count += $loc_log_count->[1];
                            $log_count        += $loc_log_count->[0];
                        } else {
                            $log_count        += $loc_log_count;
                        }
                        push @{$errors}, @{$loc_errors} if $loc_errors;
                    };
                    my $err = $@;
                    if($err) {
                        _error("[$$] backend '".$backend."' failed: ".$err);
                        $local_rc = 1;
                        $rc = 1;
                    }
                    my $elapsed = tv_interval($t1);
                    _debug(sprintf("[%d] %0".$numsize."d/%d backend %s %s in %.3fs",
                        $$,
                        $nr,
                        $total,
                        $mode,
                        $err ? 'FAILED' : 'OK',
                        $elapsed,
                    ));
                }
                exit($local_rc) if $worker_num > 1;
            } else {
                _debug("worker start with pid: ".$child_pid);
                push @child_pids, $child_pid;
            }
        }
        if($worker_num > 1) {
            _debug("waiting for workers to finish");
            while(1) {
                my $pid = wait();
                last if $pid == -1;
                if($? != 0) {
                    $rc = $?>>8;
                    _error("worker ".$pid." exited with rc: ".$rc);
                } else {
                    _debug("worker ".$pid." exited ok");
                }
                @child_pids = grep(!/^$pid$/mx, @child_pids);
                Time::HiRes::sleep(0.1);
            }
            _debug("all worker finished");
        }
        my $elapsed = tv_interval($t0);

        my $action = "imported";
        $action    = "updated"   if $mode eq 'authupdate';
        $action    = "removed"   if $mode eq 'clean';
        $action    = "compacted" if $mode eq 'compact';
        Thruk::Backend::Manager::close_logcache_connections($c);
        return("\n", 1) if $log_count == -1;
        my $msg = 'OK';
        my $res = 'successfully';
        if(scalar @{$errors} > 0) {
            $res = 'with '.scalar @{$errors}.' errors';
            ($rc, $msg) = (1, 'ERROR');
        }

        my $details = scalar @{$errors} > 0 ? join("\n", @{$errors})."\n" : "";
        if($mode eq 'drop') {
            return(sprintf("%s - droped logcache for %i site%s in %.2fs\n%s",
                           $msg,
                           $num_sites,
                           ($num_sites == 1 ? '' : 's'),
                           ($elapsed),
                           $details,
                           ), $rc);
        }
        if($mode eq 'optimize') {
            return(sprintf("%s - optimized logcache for %i site%s in %.2fs\n%s",
                           $msg,
                           $num_sites,
                           ($num_sites == 1 ? '' : 's'),
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
                       $num_sites,
                       ($num_sites == 1 ? '' : 's'),
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
                       $num_sites,
                       ($num_sites == 1 ? '' : 's'),
                       $res,
                       ($elapsed),
                       (($elapsed > 0 && $log_count > 0) ? ($log_count / ($elapsed)) : $log_count),
                       $details,
                       ), $rc);
    }
}

##############################################
sub _user_confirm {
    _infos("Continue? [n]: ");
    my $buf;
    sysread STDIN, $buf, 1;
    if($buf !~ m/^(y|j)/mxi) {
        return;
    }
    _info("");
    return(1);
}

##############################################

=head1 EXAMPLES

Initial import

  %> thruk logcache import

Initial import, but only import last 3 weeks and fetch 12 hours per import block

  %> thruk logcache import --start=3w --blocksize=12h

Run delta update with logfiles retrieved by livestatus

  %> thruk logcache update

Run update from given files.

  %> thruk logcache import /var/log/naemon/archive/2017-07-*.log

Run import from archive.

  %> thruk logcache import /var/log/naemon/archive/ /var/log/naemon/naemon.log

Prune logcache data older than 3 years

  %> thruk logcache clean 3y

Remove logcache data completly

  %> thruk logcache drop

=cut

##############################################

1;
