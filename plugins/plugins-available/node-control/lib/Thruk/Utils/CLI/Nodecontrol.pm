package Thruk::Utils::CLI::Nodecontrol;

=head1 NAME

Thruk::Utils::CLI::Nodecontrol - NodeControl CLI module

=head1 DESCRIPTION

The nodecontrol command can start node control commands.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] nc <cmd> [options]

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<cmd>

    available commands are:

    - -l|list                                        list available backends.
    - facts   <backendid|all>  [-w|--worker=<nr>]    update facts for given backend.
    - runtime <backendid|all>  [-w|--worker=<nr>]    update runtime data for given backend.
    - setversion <version>                           set new default omd version
    - install <backendid|all>  [--version=<version]  install default omd version for given backend.
    - update  <backendid|all>  [--version=<version]  update default omd version for given backend.
    - cleanup <backendid|all>                        cleanup unused omd versions for given backend.

=back

=cut

use warnings;
use strict;
use Getopt::Long ();

use Thruk::Utils ();
use Thruk::Utils::CLI ();
use Thruk::Utils::External ();
use Thruk::Utils::Log qw/:all/;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions, $data, $src, $global_options) = @_;
    $data->{'all_stdout'} = 1;

    $c->stats->profile(begin => "_cmd_nc()");

    if(!$c->check_user_roles('authorized_for_admin')) {
        return("ERROR - authorized_for_admin role required", 1);
    }

    if(scalar @{$commandoptions} == 0) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    eval {
        require Thruk::NodeControl::Utils;
    };
    if($@) {
        _debug($@);
        return("node control plugin is not enabled.\n", 1);
    }

    my $config = Thruk::NodeControl::Utils::config($c);
    # parse options
    my $opt = {
      'worker'    => $config->{'parallel_tasks'} // 3,
      'version'   => $config->{'version'},
      'mode_list' => 0,
    };
    Getopt::Long::Configure('no_ignore_case');
    Getopt::Long::Configure('bundling');
    Getopt::Long::Configure('pass_through');
    Getopt::Long::GetOptionsFromArray($commandoptions,
       "w|worker=i"     => \$opt->{'worker'},
       "l|list"         => \$opt->{'mode_list'},
       "version=s"      => \$opt->{'version'},
    ) or do {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    };

    my $mode = shift @{$commandoptions};
    $mode = 'list' if $opt->{'mode_list'};
    Thruk::Base->config->{'no_external_job_forks'} = 0; # must be enabled, would break job control

    if($mode eq 'setversion') {
        return(_action_setversion($c, $commandoptions));
    }
    elsif($mode eq 'list') {
        return(_action_list($c, $config));
    }
    elsif($mode eq 'facts' || $mode eq 'runtime') {
        return(_action_facts($c, $mode, $opt, $commandoptions));
    }
    elsif($mode eq 'cleanup') {
        return(_action_cleanup($c, $opt, $commandoptions));
    }
    elsif($mode eq 'install') {
        return(_action_install($c, $opt, $commandoptions, $config));
    }
    elsif($mode eq 'update') {
        return(_action_update($c, $opt, $commandoptions, $config));
    }

    $c->stats->profile(end => "_cmd_nc()");
    return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
}

##############################################
sub _action_setversion {
    my($c, $commandoptions) = @_;
    my $version = shift @{$commandoptions};
    if(!$version) {
        return("ERROR - no version specified\n", 1);
    }
    my $omd_available_versions = Thruk::NodeControl::Utils::get_available_omd_versions($c);
    my @sel = grep { $_ =~ m/^$version/mx } @{$omd_available_versions};
    if(scalar @sel == 0) {
        return("ERROR - no such version available\navailable versions:\n - ".join("\n - ", @{$omd_available_versions})."\n", 1);
    }
    $version = $sel[0];
    Thruk::NodeControl::Utils::save_config($c, {
        'omd_default_version'   => $version,
    });
    return("default version successfully set to: $version\n", 0);
}

##############################################
sub _action_list {
    my($c, $config) = @_;
    my @data;
    for my $peer (@{Thruk::NodeControl::Utils::get_peers($c)}) {
        my $s = Thruk::NodeControl::Utils::get_server($c, $peer, $config);
        my $v = $s->{'omd_version'};
        $v =~ s/-labs-edition//gmx;
        push @data, {
            Section => $s->{'section'} eq 'Default' ? '' : $s->{'section'},
            Name    => $peer->{'name'},
            ID      => $peer->{'key'},
            Host    => $s->{'host_name'},
            Site    => $s->{'omd_site'},
            Version => $v,
            OS      => sprintf("%s %s", $s->{'os_name'}, $s->{'os_version'}),
            Status  => _omd_status($s->{'omd_status'}),
        };
    }
    my $output = Thruk::Utils::text_table(
        keys => ['Name', 'Section', 'ID', 'Host', 'Site', 'Version', 'OS', 'Status'],
        data => \@data,
    );
    return($output, 0);
}

##############################################
sub _action_facts {
    my($c, $mode, $opt, $commandoptions) = @_;

    my $peers = _get_selected_peers($c, $commandoptions);
    _scale_peers($c, $opt->{'worker'}, $peers, sub {
        my($peer_key) = @_;
        my $peer = $c->db->get_peer_by_key($peer_key);
        my $facts;
        _debug("%s start fetching %s data...\n", $peer->{'name'}, $mode);
        if($mode eq 'facts') {
            $facts = Thruk::NodeControl::Utils::ansible_get_facts($c, $peer, 1);
        }
        if($mode eq 'runtime') {
            $facts = Thruk::NodeControl::Utils::update_runtime_data($c, $peer);
            if(!$facts->{'ansible_facts'}) {
                $facts = Thruk::NodeControl::Utils::ansible_get_facts($c, $peer, 1);
            }
        }
        if(!$facts || $facts->{'last_error'}) {
            my $err = sprintf("%s updating %s failed: %s\n", $peer->{'name'}, $mode, ($facts->{'last_error'}//'unknown error'));
            if($ENV{'THRUK_CRON'}) {
                _warn($err); # don't fill the log with errors from cronjobs
            } else {
                _error($err);
            }
        } else {
            _info("%s updated %s sucessfully: OK\n", $peer->{'name'}, $mode);
        }
    });
    $c->stats->profile(end => "_cmd_nc()");
    return("", 0);
}

##############################################
sub _action_install {
    my($c, $opt, $commandoptions, $config) = @_;

    my $version = $opt->{'version'} || $config->{'omd_default_version'};
    my $errors = 0;
    my $peers = _get_selected_peers($c, $commandoptions);
    for my $peer_key (@{$peers}) {
        my $peer = $c->db->get_peer_by_key($peer_key);
        local $ENV{'THRUK_LOG_PREFIX'} = sprintf("[%s] ", $peer->{'name'});
        _debug("start installing...\n");
        my($job) = Thruk::NodeControl::Utils::omd_install($c, $peer, $version);
        if(!$job) {
            _error("failed to start install");
            $errors++;
            next;
        }
        my $jobdata = Thruk::Utils::External::wait_for_peer_job($c, $peer, $job, 3, 1800);
        if(!$jobdata) {
            _error("failed to install");
            $errors++;
            next;
        }
        if($jobdata->{'rc'} ne '0') {
            _error("failed to install\n");
            _error("%s\n", $jobdata->{'stdout'}) if $jobdata->{'stdout'};
            _error("%s\n", $jobdata->{'stderr'}) if $jobdata->{'stderr'};
            $errors++;
            next;
        }
        _info("%s\n", $jobdata->{'stdout'}) if $jobdata->{'stdout'};
        _info("%s\n", $jobdata->{'stderr'}) if $jobdata->{'stderr'};
        _info("%s install sucessfully: OK\n", $peer->{'name'});
    }
    $c->stats->profile(end => "_cmd_nc()");
    return("", $errors > 0 ? 1 : 0);
}

##############################################
sub _action_update {
    my($c, $opt, $commandoptions, $config) = @_;

    my $version = $opt->{'version'} || $config->{'omd_default_version'};
    my $errors = 0;
    my $peers = _get_selected_peers($c, $commandoptions);
    for my $peer_key (@{$peers}) {
        my $peer = $c->db->get_peer_by_key($peer_key);
        local $ENV{'THRUK_LOG_PREFIX'} = sprintf("[%s] ", $peer->{'name'});
        _debug("start update...\n");
        my($job) = Thruk::NodeControl::Utils::omd_update($c, $peer, $version);
        if(!$job) {
            _error("failed to start update");
            $errors++;
            next;
        }
        my $jobdata = Thruk::Utils::External::wait_for_peer_job($c, $peer, $job, 3, 1800);
        if(!$jobdata) {
            _error("failed to update");
            $errors++;
            next;
        }
        if($jobdata->{'rc'} ne '0') {
            _error("failed to update\n");
            _error("%s\n", $jobdata->{'stdout'}) if $jobdata->{'stdout'};
            _error("%s\n", $jobdata->{'stderr'}) if $jobdata->{'stderr'};
            $errors++;
            next;
        }
        _info("%s\n", $jobdata->{'stdout'}) if $jobdata->{'stdout'};
        _info("%s\n", $jobdata->{'stderr'}) if $jobdata->{'stderr'};
        _info("%s update sucessfully: OK\n", $peer->{'name'});
    }
    $c->stats->profile(end => "_cmd_nc()");
    return("", $errors > 0 ? 1 : 0);
}

##############################################
sub _action_cleanup {
    my($c, $opt, $commandoptions) = @_;

    my $errors = 0;
    my $peers = _get_selected_peers($c, $commandoptions);
    for my $peer_key (@{$peers}) {
        my $peer = $c->db->get_peer_by_key($peer_key);
        local $ENV{'THRUK_LOG_PREFIX'} = sprintf("[%s] ", $peer->{'name'});
        _debug("start cleaning up...\n");
        my($job) = Thruk::NodeControl::Utils::omd_cleanup($c, $peer);
        if(!$job) {
            _error("failed to start cleanup");
            $errors++;
            next;
        }
        my $jobdata = Thruk::Utils::External::wait_for_peer_job($c, $peer, $job, 3, 1800);
        if(!$jobdata) {
            _error("failed to cleanup");
            $errors++;
            next;
        }
        if($jobdata->{'rc'} ne '0') {
            _error("failed to cleanup\n");
            _error("%s\n", $jobdata->{'stdout'}) if $jobdata->{'stdout'};
            _error("%s\n", $jobdata->{'stderr'}) if $jobdata->{'stderr'};
            $errors++;
            next;
        }
        _info("%s\n", $jobdata->{'stdout'}) if $jobdata->{'stdout'};
        _info("%s\n", $jobdata->{'stderr'}) if $jobdata->{'stderr'};
        _info("%s cleanup sucessfully: OK\n", $peer->{'name'});
    }
    $c->stats->profile(end => "_cmd_nc()");
    return("", $errors > 0 ? 1 : 0);
}

##############################################
sub _get_selected_peers {
    my($c, $commandoptions) = @_;
    my $peers = [];
    my $backend = shift @{$commandoptions};
    if($backend && $backend ne 'all') {
        my $peer = $c->db->get_peer_by_key($backend);
        if(!$peer) {
            _fatal("no such peer: ".$backend);
        }
        push @{$peers}, $backend;
    } else {
        for my $peer (@{Thruk::NodeControl::Utils::get_peers($c)}) {
            push @{$peers}, $peer->{'key'};
        }
    }
    return($peers);
}

##############################################
sub _scale_peers {
    my($c, $workernum, $peers, $sub) = @_;
    Thruk::Utils::scale_out(
        scale  => $workernum,
        jobs   => $peers,
        worker => $sub,
        collect => sub {},
    );
    return;
}

##############################################
sub _omd_status {
    my($status) = @_;

    return "" unless defined $status->{'OVERALL'};
    return "OK" if $status->{'OVERALL'} == 0;

    my @failed;
    for my $key (keys %{$status}) {
        next if $key eq 'OVERALL';
        if($status->{$key} == 1) {
            push @failed, $key;
        }
    }
    return "failed: ".join(', ', @failed);
}

##############################################

=head1 EXAMPLES

Update facts for specific backend.

  %> thruk nc facts backendid

=cut

##############################################

1;
