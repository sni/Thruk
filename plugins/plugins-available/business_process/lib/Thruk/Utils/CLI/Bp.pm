package Thruk::Utils::CLI::Bp;

=head1 NAME

Thruk::Utils::CLI::Bp - Bp CLI module

=head1 DESCRIPTION

The bp command provides all business process related cli commands.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] bp all [-w|--worker=<nr>]
                                  <nr>
                                  commit [--no-reload-core] [--no-reload-cron]

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<commit>

    write out all host/services objects for all business processes and update
    related cronjobs.

=item B<--no-reload-core>

    skip reloading core after writing files

=item B<--no-reload-cron>

    skip reloading cron after writing files

=item B<all>

    recalculate/update all business processes

=item B<-w|--worker>

    use this number of worker processes to calculate all processes.

    Defaults to 'auto' which trys to find a suitable number automatically.

=item B<nr>

    recalculate/update specific business process

=back

=cut

use warnings;
use strict;
use Fcntl qw/:DEFAULT/;
use File::Temp ();
use Getopt::Long ();
use Time::HiRes qw/gettimeofday tv_interval/;

use Thruk::Utils ();
use Thruk::Utils::CLI ();
use Thruk::Utils::Log qw/:all/;
use Thruk::Utils::Pidfile ();

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions, $data, $src, $global_options) = @_;
    if(!$c->config->{'use_feature_bp'}) {
        return("ERROR - business process addon is disabled\n", 1);
    }

    if(!$c->check_user_roles('authorized_for_business_processes')) {
        return("ERROR - authorized_for_business_processes role required", 1);
    }

    $c->stats->profile(begin => "_cmd_bp($action)");
    # parse options
    my $opt = {
      'worker'         => 'auto',
      'no-reload-core' => undef,
      'no-reload-cron' => undef,
    };
    Getopt::Long::Configure('no_ignore_case');
    Getopt::Long::Configure('bundling');
    Getopt::Long::Configure('pass_through');
    Getopt::Long::GetOptionsFromArray($commandoptions,
       "w|worker=i"     => \$opt->{'worker'},
       "no-reload-core" => \$opt->{'no-reload-core'},
       "no-reload-cron" => \$opt->{'no-reload-cron'},
    ) or do {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    };

    if(!Thruk::Utils::CLI::load_module("Thruk::BP::Utils")) {
        return("business process plugin is disabled.\n", 1);
    }

    my $mode = shift @{$commandoptions} || '';

    # backwards compatibility for thruk -a bpd command
    my $id = $mode;
    if($mode eq 'd') {
        $id = 'all';
    }

    # this function must be run on one cluster node only
    if($id eq 'all') {
        if(my $msg = $c->cluster->run_cluster("once", "cmd: bp all")) {
            return($msg, 0);
        }
    }

    if($mode eq 'commit') {
        # this function must be run on all cluster nodes
        return if $c->cluster->run_cluster("all", "cmd: bp commit");

        my $bps = Thruk::BP::Utils::load_bp_data($c);
        my($rc,$msg) = Thruk::BP::Utils::save_bp_objects($c, $bps, ($opt->{'no-reload-core'} ? 1 : 0));
        if($rc != 0) {
            $c->stats->profile(end => "_cmd_bp($action)");
            return($msg, $rc);
        }
        if(!$opt->{'no-reload-cron'}) {
            Thruk::BP::Utils::update_cron_file($c); # check cronjob
        }
        $c->stats->profile(end => "_cmd_bp($action)");
        return('OK - wrote '.(scalar @{$bps})." business process(es)\n", 0);
    }

    if(!$id) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    # loading Clone makes BPs with filters lot faster
    eval {
        require Clone;
    };

    # calculate bps
    my $lockfile;
    if($ENV{'THRUK_CRON'} && $id eq 'all') {
        $lockfile = $c->config->{'tmp_path'}."/bp.lock";
        my $lock = Thruk::Utils::Pidfile::lock($c, $lockfile);
        _fatalf("Previous business process calculation still running (pid %s). Exiting...", $lock) if $lock;
    }

    # set backends to default list, bp result should be deterministic
    $c->db->enable_default_backends();

    my $t0     = [gettimeofday];
    my $ids    = [];
    if($id eq 'all') {
        $ids = Thruk::BP::Utils::get_bp_ids($c);
    } else {
        for my $id ($id, @{$commandoptions}) {
            my $local_ids = Thruk::BP::Utils::get_bp_ids($c, $id);
            push @{$ids}, @{$local_ids};
        }
        $ids = Thruk::Base::array_uniq($ids);
    }
    my $num_bp = scalar @{$ids};

    # update bp
    my $hosts = {};
    for my $hst (@{$c->db->get_hosts( filter => [ { 'custom_variable_names' => { '>=' => 'THRUK_BP_ID' } } ], columns => [qw/name custom_variable_names custom_variable_values/] )}) {
        my $vars = Thruk::Utils::get_custom_vars($c, $hst, '', undef, 0);
        $hosts->{$hst->{'name'}}->{$vars->{'THRUK_BP_ID'}} = $hst->{'peer_key'};
    }

    my $worker_num = int($c->config->{'Thruk::Plugin::BP'}->{'worker'} || 0);
    if($worker_num == 0) {
        # try to autmatically find a suitable number of workers
        $worker_num = 1;
        if($num_bp >  20) { $worker_num = 3; }
        if($num_bp > 100) { $worker_num = 5; }
        if($num_bp > 500) { $worker_num = 8; }
    }
    if($opt->{'worker'} ne 'auto') { $worker_num = $opt->{'worker'}; }
    if($worker_num <= 0)           { $worker_num = 1; }
    if($worker_num > $num_bp)      { $worker_num = $num_bp; }

    _debug("calculating business process with ".$worker_num." workers") if $worker_num > 1;

	# use a single spool file for each worker
    my $spoolfile;
    if(!$c->config->{'Thruk::Plugin::BP'}->{'result_backend'} && $c->config->{'Thruk::Plugin::BP'}->{'spool_dir'}) {
        my $spool = $c->config->{'Thruk::Plugin::BP'}->{'spool_dir'};
        die("spool folder does not exist ".$spool.": ".$!) unless -d $spool;
        my $fh = File::Temp->new(
            TEMPLATE => "cXXXXXX",
            DIR      => $spool,
        );
        $fh->unlink_on_destroy(0); # do not remove file
        $spoolfile = $fh->filename;
        print $fh "### Active Check Result File ###\n";
        print $fh sprintf("file_time=%d\n\n",time);
        Thruk::Utils::IO::close($fh, $fh->filename);
        chmod(0664, $fh->filename); # make sure the core can read it
    }
    local $ENV{"THRUK_BP_SPOOLFILE"} = $spoolfile;

    my $numsize = length("$num_bp");
    my $nr      = 0;
    my $rc      = 0;
    Thruk::Utils::scale_out(
        scale  => $worker_num,
        jobs   => $ids,
        worker => sub {
            my($id) = @_;
            my $t1 = [gettimeofday];
            my $bps = Thruk::BP::Utils::load_bp_data($c, { id => $id });
            my $bp;
            if($bps && $bps->[0]) { $bp = $bps->[0]; }
            return unless $bp;
            if($hosts->{$bp->{'name'}}->{$bp->{'id'}}) {
                $bp->{'bp_backend'} = $hosts->{$bp->{'name'}}->{$bp->{'id'}};
            }
            eval {
                $bp->update_status($c);
            };
            my $err = $@ || $bp->{'failed'};
            if($err) {
                _error("bp '".$bp->{'name'}."' failed: ".$err);
            }
            my $elapsed = tv_interval($t1);
            return($bp->{'id'}, $bp->{'name'}, $err, $elapsed);
        },
        collect => sub {
            my($item) = @_;
            my($id, $name, $err, $elapsed) = @{$item};
            _debug(sprintf("%0".$numsize."d/%d bp %s in %.3fs | % 4s.tbp | '%s'",
                ++$nr,
                $num_bp,
                $err ? 'update failed' : 'update OK',
                $elapsed,
                $id,
                $name,
            ));
        },
    );

    # merge spool files into one file
    if($spoolfile) {
        my @files = glob($spoolfile.".*");
        if(scalar @files > 0) {
            for my $file (@files) {
                my $cont = Thruk::Utils::IO::read($file);
                Thruk::Utils::IO::write($spoolfile, $cont, undef, 1);
            }
            unlink(@files);
        }
        my $file = $spoolfile.'.ok';
        sysopen(my $t,$file,O_WRONLY|O_CREAT|O_NONBLOCK|O_NOCTTY) || die("cannot create $file: $!");
        Thruk::Utils::IO::close($t, $file);
    }

    my $elapsed = tv_interval($t0);
    if($id eq 'all') {
        $c->metrics->set('business_process_duration_seconds', $elapsed, "business process calculation duration in seconds");
        $c->metrics->set('business_process_last_update', time(), "timestamp of last business process calculation");
        $c->metrics->set('business_process_total', $num_bp, "total number of business processes");
        $c->metrics->set('business_process_worker_total', $worker_num, "total number of worker processes used to calculate business processes");
    }

    # run post hook
    if($c->config->{'Thruk::Plugin::BP'}->{'post_refresh_cmd'}) {
        my($rc, $out) = Thruk::Utils::IO::cmd($c->config->{'Thruk::Plugin::BP'}->{'post_refresh_cmd'});
        if($rc != 0) {
            _error("bp post hook exited with rc: ".$rc.': '.$out);
        }
    }

    $c->stats->profile(end => "_cmd_bp($action)");

    if($lockfile) {
        Thruk::Utils::Pidfile::unlock($c, $lockfile);
    }

    if($rc == 0) {
        return(sprintf("OK - %d business processes updated in %.2fs (%.1f/s)\n", $num_bp, $elapsed, ($num_bp/$elapsed)), 0);
    }
    return(sprintf("FAILED - calculating business processes failed, please consult the log files or run manually with options '--worker=0', exit code: %d\n", $rc), $rc);
}

##############################################

=head1 EXAMPLES

Recalculate business process with number 1

  %> thruk bp 1

Recalculate all business processes

  %> thruk bp all

Write out host and service objects

  %> thruk bp commit

=cut

##############################################

1;
