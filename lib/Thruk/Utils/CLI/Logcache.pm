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

        - import[=blocksize]    initially import all logfiles, optionally supply
                                duration (--start) to only import given range.
                                Importing blocksize at a time which defaults to 1d.
        - update                delta update all logfiles since last import/update
        - stats                 display logcache statistics
        - authupdate            update authentication data
        - optimize              run table optimize
        - clean[=duration]      clean cache and keep everything within given duration
        - removeunused          remove unused tables for no longer existing backends

=back

=cut

use warnings;
use strict;
use Thruk::Utils::Log qw/_error _info _debug _trace/;
use Time::HiRes qw/gettimeofday tv_interval/;
use Getopt::Long qw//;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions, undef, $src, $global_options) = @_;
    $c->stats->profile(begin => "_cmd_import_logs($action)");

    my $mode      = shift @{$commandoptions};

    if(!defined $c->config->{'logcache'}) {
        return("FAILED - logcache is not enabled\n", 1);
    }

    return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__)) unless $mode;

    # parse options
    my $opt = {};
    Getopt::Long::Configure('no_ignore_case');
    Getopt::Long::Configure('bundling');
    Getopt::Long::Configure('pass_through');
    Getopt::Long::GetOptionsFromArray($commandoptions,
       "s|start=s"          => \$opt->{'start'},
    ) or do {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    };

    my $blocksize;
    if($mode eq 'import' || $mode eq 'clean') {
        $blocksize = shift @{$commandoptions};
    }

    $opt->{'force'} = $global_options->{'force'};
    $opt->{'yes'}   = $global_options->{'yes'};
    $opt->{'files'} = @{$commandoptions};

    if($src ne 'local' and $mode eq 'import') {
        return("ERROR - please run the initial import with --local\n", 1);
    }
    if($mode eq 'import' && !$global_options->{'yes'}) {
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
        $c->stats->profile(end => "_cmd_import_logs($action)");
        Thruk::Backend::Manager::close_logcache_connections($c);
        return($stats."\n", 0);
    }
    elsif($mode eq 'removeunused') {
        if($type eq 'mysql') {
            my $stats= Thruk::Backend::Provider::Mysql->_log_removeunused($c);
            Thruk::Backend::Manager::close_logcache_connections($c);
            $c->stats->profile(end => "_cmd_import_logs($action)");
            return($stats."\n", 0);
        }
        Thruk::Backend::Manager::close_logcache_connections($c);
        $c->stats->profile(end => "_cmd_import_logs($action)");
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
        $c->stats->profile(end => "_cmd_import_logs($action)");
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

=head1 EXAMPLES

Initial import

  %> thruk logcache import --local

Initial import, but only import last 3 weeks

  %> thruk logcache import --local --start=3w

Run delta update with logfiles retrieved by livestatus

  %> thruk logcache update

Run update from given files

  %> thruk logcache update /var/log/naemon/archive/2017-07-*.log

Prune logcache data older than 3 years

  %> thruk logcache clean 3y

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
