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
                 [--blocksize=...]  sets the amount of logfiles fetched in one
                                    update block. Default: 1d
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
use Getopt::Long ();
use Time::HiRes qw/gettimeofday tv_interval/;

use Thruk::Backend::Manager ();
use Thruk::Utils ();
use Thruk::Utils::CLI ();
use Thruk::Utils::Log qw/:all/;

my $lock_created = 1;
END {
    unlink($lock_created) if $lock_created;
}

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
    if($mode eq 'update') {
        if($opt->{'blocksize'}) {
            $blocksize = Thruk::Utils::expand_duration($opt->{'blocksize'});
        }
    } elsif($mode eq 'import') {
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

    my($backends) = $c->db->select_backends('get_logs');
    if(scalar @{$backends} > 1 && scalar @{$opt->{'files'}} > 0) {
        _error("you must specify a backend (-b) when importing files.");
        return("", 1);
    }

    if($ENV{'THRUK_CRON'} && $mode eq 'update') {
        return("", 0) unless Thruk::Backend::Provider::Mysql::check_global_lock($c);
        $lock_created = $c->config->{'tmp_path'}."/logcache_import.lock";
        Thruk::Utils::IO::write($lock_created, $$);
    }

    if($mode eq 'import' && !$global_options->{'yes'}) {
        # check if tables already existing
        my $exist = 0;
        for my $peer_key (@{$backends}) {
            my($stats) = Thruk::Backend::Provider::Mysql->_log_stats($c, $peer_key);
            if($stats && $stats->{'cache_version'}) {
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
        my $found = 0;
        for my $peer_key (@{$backends}) {
            my($stats) = Thruk::Backend::Provider::Mysql->_log_stats($c, $peer_key);
            if($stats && $stats->{'cache_version'}) {
                _info("logcache will be removed for backend: %s.", $stats->{'name'});
                $found++;
            }
        }
        return("no logcache tables found.\n", 0) if $found == 0;
        _info("Do you really want to drop all data and remove the logcache for the %d listed backends?", $found);
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
        my $stats = Thruk::Backend::Provider::Mysql->_log_stats($c);
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
                if($num_sites >   1) { $worker_num = 2; }
                if($num_sites >  20) { $worker_num = 3; }
                if($num_sites > 100) { $worker_num = 5; }
                if($num_sites > 200) { $worker_num = 8; }
            }
            if($opt->{'worker'} ne 'auto') { $worker_num = $opt->{'worker'}; }
            if($worker_num <= 0)           { $worker_num = 1; }
            if($worker_num > $num_sites)   { $worker_num = $num_sites; }
        }

        _debug("running ".$mode." command with ".$worker_num." workers") if $worker_num > 1;
        my $t0      = [gettimeofday];
        my $numsize = length("$num_sites");

        my $nr = 0;
        my($log_count, $plugin_ref_count, $errors) = (0,0,[]);
        Thruk::Utils::scale_out(
            scale  => $worker_num,
            jobs   => $backends,
            worker => sub {
                my($backend) = @_;
                my $t1 = [gettimeofday];
                my($log_count, $plugin_ref_count, $err) = (0, 0);
                eval {
                    my(undef, $loc_log_count, $errors) = Thruk::Backend::Provider::Mysql->_import_logs($c, $mode, $backend, $blocksize, $opt);
                    $c->stats->profile(end => "_cmd_import_logs($action)");
                    if($mode eq 'clean' || $mode eq 'compact') {
                        $plugin_ref_count += $loc_log_count->[1];
                        $log_count        += $loc_log_count->[0];
                    } else {
                        $log_count        += $loc_log_count;
                    }
                    $err = join("\n", @{$errors}) if $errors;
                };
                $err = $@ if $@;
                if($err) {
                    my($short_err, undef) = Thruk::Utils::extract_connection_error($err);
                    if(defined $short_err) {
                        _debug($err);
                        $err = $short_err;
                    }
                    $err = sprintf("backend '%s' failed: %s", $backend, $err);
                    _error($err);
                }
                my $elapsed = tv_interval($t1);
                return($log_count, $plugin_ref_count, $err, $elapsed);
            },
            collect => sub {
                my($item) = @_;
                $log_count        += $item->[0];
                $plugin_ref_count += $item->[1];
                my $err            = $item->[2];
                my $elapsed        = $item->[3];
                push @{$errors}, $err if $err;
                _debug(sprintf("%0".$numsize."d/%d backend %s %s in %.3fs",
                    ++$nr,
                    $num_sites,
                    $mode,
                    $err ? 'FAILED' : 'OK',
                    $elapsed,
                ));
                return;
            },
        );

        my $elapsed = tv_interval($t0);

        my $action = "imported";
        $action    = "updated"   if $mode eq 'authupdate';
        $action    = "removed"   if $mode eq 'clean';
        $action    = "compacted" if $mode eq 'compact';
        Thruk::Backend::Manager::close_logcache_connections($c);
        return("\n", 1) if $log_count == -1;
        my $rc  = 0;
        my $msg = 'OK';
        my $res = 'successfully';
        if(scalar @{$errors} > 0) {
            $res = 'with '.scalar @{$errors}.' errors';
            ($rc, $msg) = (1, 'ERROR');
        }

        if($mode eq 'drop') {
            return(sprintf("%s - droped logcache for %i site%s in %.2fs\n",
                           $msg,
                           $num_sites,
                           ($num_sites == 1 ? '' : 's'),
                           ($elapsed),
                           ), $rc);
        }
        if($mode eq 'optimize') {
            return(sprintf("%s - optimized logcache for %i site%s in %.2fs\n",
                           $msg,
                           $num_sites,
                           ($num_sites == 1 ? '' : 's'),
                           ($elapsed),
                           ), $rc);
        }
        if($mode eq 'compact') {
        return(sprintf("%s - %s %i log items and removed %d%s from %i site%s %s in %.2fs (%i/s)\n",
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
                       ), $rc);
        }
        return(sprintf("%s - %s %i log items %sfrom %i site%s %s in %.2fs (%i/s)\n",
                       $msg,
                       $action,
                       $log_count,
                       $plugin_ref_count ? "(and ".$plugin_ref_count." plugin ouput references) " : '',
                       $num_sites,
                       ($num_sites == 1 ? '' : 's'),
                       $res,
                       ($elapsed),
                       (($elapsed > 0 && $log_count > 0) ? ($log_count / ($elapsed)) : $log_count),
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

  %> thruk logcache update /var/log/naemon/archive/2017-07-*.log

Run initial import from archive.

  %> thruk logcache import /var/log/naemon/archive/ /var/log/naemon/naemon.log

Prune logcache data older than 3 years

  %> thruk logcache clean 3y

Remove logcache data completly

  %> thruk logcache drop

=cut

##############################################

1;
