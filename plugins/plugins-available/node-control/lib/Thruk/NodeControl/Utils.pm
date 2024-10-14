package Thruk::NodeControl::Utils;

use warnings;
use strict;
use Carp;
use Cpanel::JSON::XS ();
use Cwd qw/abs_path/;

use Thruk::Constants qw/:peer_states/;
use Thruk::Utils ();
use Thruk::Utils::External ();
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::NodeControl::Utils - Helper for the node control addon

=head1 DESCRIPTION

Helper for the node control addon

=head1 METHODS

=cut

##########################################################

=head2 update_cron_file

  update_cron_file($c)

update controlled nodes cronjobs

=cut
sub update_cron_file {
    my($c) = @_;

    return 1;
}

##########################################################

=head2 get_peers

  get_peers($c)

return list of available peers

=cut
sub get_peers {
    my($c) = @_;
    my @peers;
    my $dups = {};
    for my $peer (@{$c->db->get_local_peers()}, @{$c->db->get_http_peers(1)}, @{$c->db->get_peers_by_tags('node-control')}) {
        next if (defined $peer->{'disabled'} && $peer->{'disabled'} == HIDDEN_LMD_PARENT);
        next if $dups->{$peer->{'key'}}; # backend can be in both lists
        $dups->{$peer->{'key'}} = 1;
        push @peers, $peer;
    }
    return \@peers;
}

##########################################################

=head2 get_server

  get_server($c, $peer, [$config])

return server details

=cut
sub get_server {
    my($c, $peer, $config) = @_;
    my $facts = ansible_get_facts($c, $peer, 0);
    $config = $config || config($c);

    # check if jobs are still running
    my $save_required    = 0;
    my $refresh_required = 0;
    if($facts->{'gathering'} && !kill(0, $facts->{'gathering'})) {
        $save_required = 1;
        $facts->{'gathering'} = 0;
    }

    my $job_checking = 0;
    for my $key (qw/run_all cleaning installing updating os_updating os_sec_updating/) {
        my $job = $facts->{$key};
        next unless $job;
        # starting right now
        if($job eq "1") {
            $job_checking = 1;
            if($facts->{'job_checking'}) {
                if($facts->{'job_checking'} < time() - 10) {
                    delete $facts->{'job_checking'};
                    $facts->{$key} = 0;
                    $save_required = 1;
                }
            } else {
                $facts->{'job_checking'} = time();
                $save_required = 1;
            }
            next;
        }
        my $data;
        eval {
            $data = $peer->job_data($c, $job);
        };
        if($@) {
            _warn($@);
            next;
        }
        if($data && !$data->{'is_running'}) {
            $facts->{$key} = 0;
            if($data->{'rc'} != 0) {
                $facts->{'last_error'} = $data->{'stdout'}.$data->{'stderr'};
            }
            $facts->{'last_job'} = $job;
            $save_required = 1;
            $refresh_required = 1;
        }
        if(!$data) {
            $facts->{$key} = 0;
            $save_required = 1;
        }
    }
    if($facts->{'job_checking'} && !$job_checking) {
        delete $facts->{'job_checking'};
        $save_required = 1;
    }
    if($save_required) {
        Thruk::Utils::IO::mkdir_r($c->config->{'var_path'}.'/node_control');
        my $file = $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'.json';
        Thruk::Utils::IO::json_lock_store($file, $facts, { pretty => 1 });
    }
    if($refresh_required) {
        Thruk::Utils::External::perl($c, {
            'expr'       => 'Thruk::NodeControl::Utils::ansible_get_facts($c, "'.$peer->{'key'}.'", 1);',
            'background' => 1,
        });
        $facts->{'gathering'} = 1;
    }

    for my $errKey (qw/last_error last_facts_error/) {
        $facts->{$errKey} =~ s/\s+at\s+.*HTTP\.pm\s+line\s+\d+\.//gmx if $facts->{$errKey};
    }

    # gather available logs
    my @logs = glob($c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'_*.log');
    @logs = map { my $l = $_; $l =~ s/^.*\///gmx; $l =~ s/\.log$//gmx; $l =~ s/^$peer->{'key'}_//gmx; $l; } @logs;
    my $logs = Thruk::Base::array2hash(\@logs);
    for my $l (sort keys %{$logs}) {
        my $prefix = "";
        $prefix = "updating"   if $l eq 'update';
        $prefix = "installing" if $l eq 'install';
        $prefix = "cleaning"   if $l eq 'cleanup';
        $logs->{$l} = {
            'failed' => $facts->{$prefix.'_failed'} // 0,
            'time'   => $facts->{$prefix.'_time'}   // "",
        };
    }

    my $server = {
        peer_key                => $peer->{'key'},
        peer_name               => $peer->{'name'},
        section                 => $peer->{'section'},
        gathering               => $facts->{'gathering'}       || 0, # job id of current gathering job or 0
        cleaning                => $facts->{'cleaning'}        || 0, # cleaning job id
        run_all                 => $facts->{'run_all'}         || 0, # job id when install/update/clean runs in one job
        installing              => $facts->{'installing'}      || 0, # install job id
        updating                => $facts->{'updating'}        || 0, # update job id
        os_updating             => $facts->{'os_updating'}     || 0, # os update id
        os_sec_updating         => $facts->{'os_sec_updating'} || 0, # sec update job id
        host_name               => undef,
        ansible_fqdn            => $facts->{'ansible_facts'}->{'ansible_fqdn'},
        omd_version             => $facts->{'omd_version'} // '',
        omd_versions            => $facts->{'omd_versions'} // [],
        omd_cleanable           => $facts->{'omd_cleanable'} // [],
        omd_site                => $facts->{'omd_site'} // '',
        omd_status              => $facts->{'omd_status'} // {},
        os_name                 => $facts->{'ansible_facts'}->{'ansible_distribution'} // '',
        os_version              => $facts->{'ansible_facts'}->{'ansible_distribution_version'} // '',
        os_updates              => $facts->{'os_updates'} // [],
        os_security             => $facts->{'os_security'} // [],
        machine_type            => _machine_type($facts) // '',
        cpu_cores               => $facts->{'ansible_facts'}->{'ansible_processor_vcpus'} // '',
        cpu_perc                => $facts->{'omd_cpu_perc'} // '',
        memtotal                => $facts->{'ansible_facts'}->{'ansible_memtotal_mb'} // '',
        memfree                 => $facts->{'ansible_facts'}->{'ansible_memory_mb'}->{'nocache'}->{'free'} // '',
        omd_disk_total          => $facts->{'omd_disk_total'} // '',
        omd_disk_free           => $facts->{'omd_disk_free'} // '',
        omd_available_versions  => $facts->{'omd_packages_available'} // [],
        last_error              => $facts->{'last_error'} // '',
        last_facts_error        => $facts->{'last_facts_error'} // '',
        last_job                => $facts->{'last_job'} // '',
        logs                    => $logs,
        facts                   => $facts || {},
    };

    # add fallback site name and address
    if(!$server->{'host_name'}) {
        my($host, undef) = Thruk::Utils::get_remote_thruk_hostname($c, $peer->{'key'});
        $server->{'host_name'} = $host if $host;
    }
    if(!$server->{'host_name'} && $peer->{'addr'} =~ m/^\//mx) {
        $server->{'host_name'} = Thruk::Config::hostname();
    }
    $server->{'host_name'} = $peer->{'name'} unless $server->{'host_name'};
    if(!$server->{'omd_site'}) {
        my $site = Thruk::Utils::get_remote_thruk_site_name($c, $peer->{'key'});
        $server->{'omd_site'}  = $site if $site;
    }

    # remove current default from cleanable
    if($server->{'omd_cleanable'}) {
        my $def = $config->{'omd_default_version'};
        @{$server->{'omd_cleanable'}} = grep(!/$def/mx, @{$server->{'omd_cleanable'}}) if $def;
    }

    return($server);
}

##########################################################

=head2 ansible_get_facts

  ansible_get_facts($c, $peer, [$refresh])

return ansible gather facts

=cut
sub ansible_get_facts {
    my($c, $peer, $refresh) = @_;
    if(!ref $peer) {
        $peer = $c->db->get_peer_by_key($peer);
    }
    Thruk::Utils::IO::mkdir_r($c->config->{'var_path'}.'/node_control');
    my $file = $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'.json';
    my $f;
    eval {
        $f = _ansible_get_facts($c, $peer, $refresh);
    };
    if($@) {
        $f = Thruk::Utils::IO::json_lock_patch($file, { 'gathering' => 0, 'last_facts_error' => $@ }, { pretty => 1, allow_empty => 1 });
    }
    return($f);
}

##########################################################

=head2 update_runtime_data

  update_runtime_data($c, $peer, [$skip_cpu])

update runtime data and return facts

=cut
sub update_runtime_data {
    my($c, $peer, $skip_cpu) = @_;

    my $f = ansible_get_facts($c, $peer, 0);
    return($f) unless defined $f->{'ansible_facts'}; # update only if we have at least fetched facts once

    Thruk::Utils::IO::mkdir_r($c->config->{'var_path'}.'/node_control');
    my $file = $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'.json';
    Thruk::Utils::IO::json_lock_patch($file, { 'gathering' => $$ }, { pretty => 1, allow_empty => 1 });
    my $runtime = {};
    eval {
        $runtime = _runtime_data($c, $peer, $skip_cpu);
    };
    my $err = $@;
    if($err) {
        $f = Thruk::Utils::IO::json_lock_patch($file, { 'gathering' => 0, 'last_error' => $err }, { pretty => 1, allow_empty => 1 });
    } else {
        $f = Thruk::Utils::IO::json_lock_patch($file, { 'gathering' => 0, 'last_error' => '', %{$runtime}  }, { pretty => 1, allow_empty => 1 });
    }
    return($f);
}

##########################################################
sub _ansible_get_facts {
    my($c, $peer, $refresh) = @_;
    my $file = $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'.json';
    if(!$refresh && -e $file) {
        return(Thruk::Utils::IO::json_lock_retrieve($file));
    }
    if(defined $refresh && !$refresh) {
        return;
    }

    my $prev = Thruk::Utils::IO::json_lock_patch($file, { 'gathering' => $$ }, { pretty => 1, allow_empty => 1 });
    $prev->{'gathering'}  = 0;
    $prev->{'last_facts_error'} = "";

    # available subsets are listed here:
    # https://docs.ansible.com/ansible/latest/collections/ansible/builtin/setup_module.html#parameter-gather_subset
    # however, older ansible release don't support all of them and bail out
    my $f       = _ansible_adhoc_cmd($c, $peer, "-m setup -a 'gather_subset=hardware,virtual' -a 'gather_timeout=30'");
    my $runtime = _runtime_data($c, $peer);
    my $pkgs    = _ansible_available_packages($c, $peer, $f);
    my $updates = _ansible_available_os_updates($c, $peer, $f);

    # merge hashes
    $f = { %{$prev//{}}, %{$f//{}}, %{$runtime//{}}, %{$pkgs//{}}, %{$updates//{}}};

    Thruk::Utils::IO::json_lock_store($file, $f, { pretty => 1 });
    return($f);
}

##########################################################
sub _runtime_data {
    my($c, $peer, $skip_cpu) = @_;
    my $runtime = {};

    my $script = abs_path(Thruk::Base::dirname(__FILE__)."/../../../scripts/runtime.sh");
    if($skip_cpu) {
        $script .= " 1";
    }
    my($rc, $out) = _remote_script($c, $peer, $script);
    if($rc != 0) {
        die("failed to gather runtime data: rc ".$rc." ".$out);
    }
    $out =~ s/\r\n/\n/gmx;
    my %blocks = $out =~ m/<<<([^>]+)>>>\s*(.*?)\s*<<<>>>/sgmx;

    $runtime->{'omd_version'} = $blocks{'OMD VERSION'};

    my %services = ($blocks{'OMD STATUS'} =~ m/^(\S+?)\s+(\d+)/gmx);
    $runtime->{'omd_status'} = \%services;

    $runtime->{'omd_site'} = $blocks{'ID'};

    my @inst = split/\n/mx, $blocks{'OMD VERSIONS'};
    my $default;
    for my $i (@inst) {
        if($i =~ m/\Q(default)\E/mx) {
            $i =~ s/\s*\Q(default)\E//gmx;
            $default = $i;
        }
    }
    @inst = reverse sort @inst;
    $runtime->{'omd_versions'} = \@inst;

    my %omd_sites;
    my %in_use;
    my $sites = $blocks{'OMD SITES'};
    my @sites = split/\n/mx, $sites;
    for my $s (@sites) {
        my($name, $version, $comment) = split/\s+/mx, $s;
        next if $version eq 'VERSION';
        $omd_sites{$name} = $version;
        $in_use{$version} = 1;
    }
    $in_use{$default} = 1 if $default;

    my @cleanable;
    for my $v (@inst) {
        next if $in_use{$v};
        push @cleanable, $v;
    }
    @inst = reverse sort @inst;
    $runtime->{'omd_cleanable'} = \@cleanable;
    $runtime->{'omd_sites'}     = \%omd_sites;

    if($blocks{'OMD DF'} =~ m/^.*\s+(\d+)\s+(\d+)\s+(\d+)\s+/gmx) {
        $runtime->{'omd_disk_total'} = $1;
        $runtime->{'omd_disk_free'}  = $3;
    }

    if($blocks{'HAS TMUX'} =~ m/tmux$/gmx) {
        $runtime->{'has_tmux'} = $blocks{'HAS TMUX'};
    }

    if($blocks{'CPUTOP'} && $blocks{'CPUTOP'} =~ m/Cpu/gmx) {
        my @val = split/\s+/mx, $blocks{'CPUTOP'};
        $runtime->{'omd_cpu_perc'}  = (100-$val[7])/100;
    }


    return($runtime);
}

##########################################################
sub _ansible_available_packages {
    my($c, $peer, $facts) = @_;

    if(!$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}) {
        die("no package manager");
    }

    my $pkgs;
    if($facts->{'ansible_facts'}->{'ansible_pkg_mgr'} eq 'yum') {
        (undef, $pkgs) = _remote_cmd($c, $peer, 'yum search omd- 2>/dev/null');
    } elsif($facts->{'ansible_facts'}->{'ansible_pkg_mgr'} eq 'dnf') {
        (undef, $pkgs) = _remote_cmd($c, $peer, 'dnf search omd- 2>/dev/null');
    } elsif($facts->{'ansible_facts'}->{'ansible_pkg_mgr'} eq 'apt') {
        (undef, $pkgs) = _remote_cmd($c, $peer, 'apt-cache search omd- 2>/dev/null');
    } else {
        die("unknown package manager: ".$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}//'none');
    }
    my @pkgs = ($pkgs =~ m/^(omd\-\S+?)(?:\s|\.x86_64)/gmx);
    @pkgs = grep(!/^(omd-labs-edition|omd-daily)/mx, @pkgs); # remove meta packages
    @pkgs = reverse sort @pkgs;
    @pkgs = map { my $pkg = $_; $pkg =~ s/^omd\-//gmx; $pkg; } @pkgs;

    return({ omd_packages_available => \@pkgs });
}

##########################################################
sub _ansible_available_os_updates {
    my($c, $peer, $facts) = @_;

    if(!$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}) {
        die("no package manager");
    }

    my $updates  = [];
    my $security = [];
    if($facts->{'ansible_facts'}->{'ansible_pkg_mgr'} eq 'apt') {
        my($rc, $out) = _remote_cmd($c, $peer, 'apt-get -y --dry-run upgrade');
        if($rc == 0) {
            my @updates = $out =~ m/^Inst\s+(\S+)\s+(.*)$/gmx;
            while(scalar @updates > 0) {
                my $pkg = shift @updates;
                my $src = shift @updates;
                if($src =~ m/(Debian\-Security:|Ubuntu:[^\/]*\/[^-]*-security)/mx) {
                    push @{$security}, $pkg;
                } else {
                    push @{$updates}, $pkg;
                }
            }
        }
    }

    if($facts->{'ansible_facts'}->{'ansible_pkg_mgr'} eq 'dnf') {
        my($rc, $out) = _remote_cmd($c, $peer, 'dnf check-update 2>/dev/null');
        $updates = _parse_yum_check_update($out);

        ($rc, $out) = _remote_cmd($c, $peer, 'dnf check-update --security 2>/dev/null');
        $security = _parse_yum_check_update($out);
    }

    if($facts->{'ansible_facts'}->{'ansible_pkg_mgr'} eq 'yum') {
        my($rc, $out) = _remote_cmd($c, $peer, 'yum check-update 2>/dev/null');
        $updates = _parse_yum_check_update($out);

        ($rc, $out) = _remote_cmd($c, $peer, 'yum check-update --security 2>/dev/null');
        $security = _parse_yum_check_update($out);
    }

    @{$updates}  = sort @{$updates};
    @{$security} = sort @{$security};

    return({ os_updates => $updates, os_security => $security });
}

##########################################################

=head2 omd_install

  omd_install($c, $peer, $version, $force)

installs given version on peer

=cut
sub omd_install {
    my($c, $peer, $version, $force) = @_;

    my $facts = _ansible_get_facts($c, $peer, 0);
    if(!$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}) {
        die("no package manager");
    }

    $version = "omd-".$version;

    return if $facts->{'installing'};
    return if($facts->{'run_all'} && !$force);

    # continue in background job
    _set_job_started($c, 'installing', $peer->{'key'});
    my $job = Thruk::Utils::External::perl($c, {
        expr        => 'Thruk::NodeControl::Utils::_omd_install_step2($c, "'.$peer->{'key'}.'", "'.$version.'")',
        message     => 'Installing OMD '.$version,
        background  => 1,
        log_archive => $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'_install.log',
    });
    return($job);
}

##########################################################
sub _omd_install_step2 {
    my($c, $peerkey, $version) = @_;

    my $peer   = $c->db->get_peer_by_key($peerkey);
    my $facts  = _ansible_get_facts($c, $peer, 0);
    my $config = config($c);
    my $file   = $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'.json';

    print "*** installing $version\n";
    _set_job_started($c, 'installing', $peer->{'key'});

    if(!$config->{'cmd_'.$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}.'_pkg_install'}) {
        return _set_job_errored($c, 'installing', $peer->{'key'}, "package manager ".$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}." not supported");
    }

    my $cmd = _cmd_line($config->{'cmd_'.$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}.'_pkg_install'}, { '%PKG' => $version });
    my($rc, $job);
    eval {
        ($rc, $job) = _remote_cmd($c, $peer, $cmd, {});
    };
    if($@) {
        return _set_job_errored($c, 'installing', $peer->{'key'}, $@);
    }

    # wait for 1800 sec
    my $jobdata = Thruk::Utils::External::wait_for_peer_job($c, $peer, $job, 2, 1800, 1);
    if(!$jobdata || $jobdata->{'rc'} ne "0") {
        return _set_job_errored($c, 'installing', $peer->{'key'}, "pkg installation failed");
    }

    _set_job_done($c, 'installing', $peer->{'key'});
    ansible_get_facts($c, $peer, 1);
    update_runtime_data($c, $peer, 1);
    return(1);
}

##########################################################

=head2 omd_update

  omd_update($c, $peer, $version)

update site to given version on peer in background, returns job id

=cut
sub omd_update {
    my($c, $peer, $version, $force) = @_;

    my $facts = _ansible_get_facts($c, $peer, 0);
    return if $facts->{'updating'};
    return if ($facts->{'run_all'} && !$force);

    # continue in background job
    _set_job_started($c, 'updating', $peer->{'key'});
    my $job = Thruk::Utils::External::perl($c, {
        expr        => 'Thruk::NodeControl::Utils::_omd_update_step2($c, "'.$peer->{'key'}.'", "'.$version.'")',
        message     => sprintf('updating %s on %s to omd %s', $facts->{'omd_site'}, $peer->{'name'}, $version),
        background  => 1,
        log_archive => $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'_update.log',
    });
    return($job);
}

##########################################################
sub _omd_update_step2 {
    my($c, $peerkey, $version) = @_;
    my $peer   = $c->db->get_peer_by_key($peerkey);
    my $file   = $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'.json';
    my $config = config($c);
    my $env    = _get_hook_env($c, $peer, $version);
    my $facts  = _ansible_get_facts($c, $peer, 0);

    printf("*** updating %s on %s\n", $facts->{'omd_site'}//'', $peer->{'name'}//'');
    printf("*** from: %s\n", $env->{'FROM_OMD_VERSION'} // 'unknown');
    printf("*** to:   %s\n", $version);

    _set_job_started($c, 'updating', $peer->{'key'});

    if($config->{'hook_update_pre_local'}) {
        print "*** hook_update_pre_local:\n";
        my($rc, $out) = _local_run_hook($c, $config->{'hook_update_pre_local'}, $env);
        print "*** hook_update_pre_local rc: $rc\n";
        if($rc != 0) {
            return _set_job_errored($c, 'updating', $peer->{'key'}, sprintf("update canceled by local pre hook (rc: %d)", $rc));
        }
    }

    if($config->{'hook_update_pre'}) {
        print "*** hook_update_pre:\n";
        eval {
            my $rc = _remote_run_hook($c, $peer, $config->{'hook_update_pre'}, $env);
            print "*** hook_update_pre rc: $rc\n";
            if($rc ne '0') {
                return _set_job_errored($c, 'updating', $peer->{'key'}, sprintf("update canceled by pre hook (rc: %d)", $rc));
            }
        };
        if($@) {
            return _set_job_errored($c, 'updating', $peer->{'key'}, $@);
        }
    }

    my($rc, $job);
    eval {
        my $script = Thruk::Utils::IO::read($config->{'omd_update_script'});
        $peer->rpc($c, 'Thruk::Utils::IO::write', 'var/tmp/omd_update.sh', $script);
        ($rc, $job) = _remote_cmd($c, $peer, 'OMD_UPDATE="'.$version.'" bash var/tmp/omd_update.sh', { env => $env }, undef, $env);
    };
    if($@) {
        return _set_job_errored($c, 'updating', $peer->{'key'}, $@);
    }

    # wait for 180 sec
    my $jobdata = Thruk::Utils::External::wait_for_peer_job($c, $peer, $job, 1, 180, 1);
    if(!$jobdata || $jobdata->{'rc'} ne "0") {
        return _set_job_errored($c, 'updating', $peer->{'key'}, "update failed");
    }

    my $post_hooks_failed = 0;
    if($config->{'hook_update_post'}) {
        print "*** hook_update_post:\n";
        my $rc = -1;
        eval {
            $rc = _remote_run_hook($c, $peer, $config->{'hook_update_post'}, $env);
            print "*** hook_update_post rc: $rc\n";
        };
        if($@) {
            _info("hook_update_post failed: ".$@);
        }
        $post_hooks_failed = 1 if $rc ne '0';
    }

    if($config->{'hook_update_post_local'}) {
        print "*** hook_update_post_local:\n";
        my($rc, $out);
        eval {
            ($rc, $out) = _local_run_hook($c, $config->{'hook_update_post_local'}, $env);
            print "*** hook_update_post_local rc: $rc\n";
        };
        if($@) {
            _info("hook_update_post_local failed: ".$@);
        }
        $post_hooks_failed = 1 if $rc ne '0';
    }

    printf("*** updating %s on %s to omd %s finished\n", $facts->{'omd_site'}, $peer->{'name'}, $version);
    _set_job_done($c, 'updating', $peer->{'key'});

    update_runtime_data($c, $peer, 1);

    if($post_hooks_failed) {
        return _set_job_errored($c, 'updating', $peer->{'key'}, "update successfull but post hook failed");
    }
    return(1);
}

##########################################################

=head2 omd_install_update_cleanup

  omd_install_update_cleanup($c, $peer, $version)

install and update site to given version on peer, then run cleanup

=cut
sub omd_install_update_cleanup {
    my($c, $peer, $version) = @_;

    my $facts = _ansible_get_facts($c, $peer, 0);
    return if $facts->{'installing'};
    return if $facts->{'updating'};
    return if $facts->{'cleaning'};
    return if $facts->{'run_all'};

    # continue in background job
    _set_job_started($c, 'run_all', $peer->{'key'});
    my $job = Thruk::Utils::External::perl($c, {
        expr        => 'Thruk::NodeControl::Utils::_omd_install_update_cleanup_step2($c, "'.$peer->{'key'}.'", "'.$version.'")',
        background  => 1,
    });
    return($job);
}

##########################################################
sub _omd_install_update_cleanup_step2 {
    my($c, $peerkey, $version) = @_;
    my $peer   = $c->db->get_peer_by_key($peerkey);
    my $config = config($c);
    my $file   = $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'.json';
    my $facts  = _ansible_get_facts($c, $peer, 0);

    _set_job_started($c, 'run_all', $peer->{'key'});

    # install omd pkg
    if($config->{'pkg_install'} && !grep(/$version/mx, @{$facts->{'omd_versions'} // []})) {
        my $job = omd_install($c, $peer, $version, 1);
        return _set_job_errored($c, 'run_all', $peer->{'key'}, "failed to start install") unless $job;
        my $jobdata = Thruk::Utils::External::wait_for_peer_job($c, $peer, $job, 3, 1800, 1);
        if(!$jobdata || $jobdata->{'rc'} ne '0') {
            return _set_job_errored($c, 'run_all', $peer->{'key'}, "failed to install");
        }
    }

    # update
    my $f = _ansible_get_facts($c, $peer, 0);
    if($f->{'omd_version'} ne $version) {
        my $job = omd_update($c, $peer, $version, 1);
        return _set_job_errored($c, 'run_all', $peer->{'key'}, "failed to start update") unless $job;
        my $jobdata = Thruk::Utils::External::wait_for_peer_job($c, $peer, $job, 1, 180, 1);
        if(!$jobdata || $jobdata->{'rc'} ne '0') {
            return _set_job_errored($c, 'run_all', $peer->{'key'}, "failed to update");
        }
    }

    # cleanup
    if($config->{'pkg_cleanup'}) {
        my $job = omd_cleanup($c, $peer, 1);
        return _set_job_errored($c, 'run_all', $peer->{'key'}, "failed to start cleanup") unless $job;
        my $jobdata = Thruk::Utils::External::wait_for_peer_job($c, $peer, $job, 3, 1800, 1);
        if(!$jobdata || $jobdata->{'rc'} ne '0') {
            return _set_job_errored($c, 'run_all', $peer->{'key'}, "failed to cleanup");
        }
    }

    _set_job_done($c, 'run_all', $peer->{'key'});

    return(1);
}

##########################################################

=head2 os_update

  os_update($c, $peer)

update os packages

=cut
sub os_update {
    my($c, $peer) = @_;

    my $facts = _ansible_get_facts($c, $peer, 0);
    return if $facts->{'os_updating'};

    if(!$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}) {
        die("no package manager");
    }

    my $file   = $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'.json';
    my $f      = Thruk::Utils::IO::json_lock_patch($file, { 'os_updating' => 1, 'last_error' => '' }, { pretty => 1, allow_empty => 1 });
    my $config = config($c);

    if(!$config->{'cmd_'.$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}.'_os_update'}) {
        die("package manager ".$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}." not supported");
    }
    my $cmd = _cmd_line($config->{'cmd_'.$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}.'_os_update'});

    my($rc, $job);
    eval {
        ($rc, $job) = _remote_cmd($c, $peer, $cmd, { message => 'Installing OS Updates' });
        die("starting job failed") unless $job;
    };
    if($@) {
        $f = Thruk::Utils::IO::json_lock_patch($file, { 'os_updating' => 0, 'last_error' => $@ }, { pretty => 1, allow_empty => 1 });
        return;
    }

    Thruk::Utils::IO::json_lock_patch($file, { 'os_updating' => $job, 'last_job' => $job, 'last_error' => "" }, { pretty => 1, allow_empty => 1 });
    return($job);
}

##########################################################

=head2 os_sec_update

  os_sec_update($c, $peer)

update os security packages

=cut
sub os_sec_update {
    my($c, $peer) = @_;

    my $facts = _ansible_get_facts($c, $peer, 0);
    return if $facts->{'os_sec_updating'};

    if(!$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}) {
        die("no package manager");
    }

    my $file   = $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'.json';
    my $f      = Thruk::Utils::IO::json_lock_patch($file, { 'os_sec_updating' => 1, 'last_error' => '' }, { pretty => 1, allow_empty => 1 });
    my $config = config($c);

    if(!$config->{'cmd_'.$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}.'_os_sec_update'}) {
        die("package manager ".$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}." not supported");
    }
    my $cmd = _cmd_line($config->{'cmd_'.$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}.'_os_sec_update'});

    my($rc, $job);
    eval {
        ($rc, $job) = _remote_cmd($c, $peer, $cmd, { message => 'Installing OS security Updates' });
        die("starting job failed") unless $job;
    };
    if($@) {
        $f = Thruk::Utils::IO::json_lock_patch($file, { 'os_sec_updating' => 0, 'last_error' => $@ }, { pretty => 1, allow_empty => 1 });
        return;
    }

    Thruk::Utils::IO::json_lock_patch($file, { 'os_sec_updating' => $job, 'last_job' => $job, 'last_error' => "" }, { pretty => 1, allow_empty => 1 });
    return($job);
}

##########################################################

=head2 omd_cleanup

  omd_cleanup($c, $peer)

runs omd cleanup on peer

=cut
sub omd_cleanup {
    my($c, $peer, $force) = @_;

    my $facts = _ansible_get_facts($c, $peer, 0);
    return if $facts->{'cleaning'};
    return if($facts->{'run_all'} && !$force);

    # continue in background job
    _set_job_started($c, 'cleaning', $peer->{'key'});
    my $job = Thruk::Utils::External::perl($c, {
        expr        => 'Thruk::NodeControl::Utils::_omd_cleanup_step2($c, "'.$peer->{'key'}.'")',
        message     => 'running OMD cleanup',
        background  => 1,
        log_archive => $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'_cleanup.log',
    });
    return($job);
}

##########################################################
sub _omd_cleanup_step2 {
    my($c, $peerkey) = @_;

    my $peer   = $c->db->get_peer_by_key($peerkey);
    my $file   = $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'.json';
    my $config = config($c);
    my $cmd    = _cmd_line($config->{'cmd_omd_cleanup'});

    print "*** running cleanup\n";
    _set_job_started($c, 'cleaning', $peer->{'key'});

    my($rc, $job);
    eval {
        ($rc, $job) = _remote_cmd($c, $peer, $cmd, { message => 'Running OMD cleanup' });
    };
    if($@) {
        return _set_job_errored($c, 'cleaning', $peer->{'key'}, $@);
    }

    # wait for 1800 sec
    my $jobdata = Thruk::Utils::External::wait_for_peer_job($c, $peer, $job, 2, 1800, 1);
    if(!$jobdata || $jobdata->{'rc'} ne "0") {
        return _set_job_errored($c, 'cleaning', $peer->{'key'}, 'cleanup failed');
    }

    _set_job_done($c, 'cleaning', $peer->{'key'});

    ansible_get_facts($c, $peer, 1);
    update_runtime_data($c, $peer, 1);
    return(1);
}

##########################################################
# run given command on remote peer
sub _remote_cmd {
    my($c, $peer, $cmd, $background_options, $env) = @_;
    my($rc, $out, $err);

    if(!$peer->{'ssh_ok'} && ($peer->is_local() || $peer->is_peer_machine_reachable_by_http())) {
        eval {
            ($rc, $out) = $peer->cmd($c, $cmd, $background_options, $env);
        };
        $err = $@;
        if(!$err) {
            return($rc, $out);
        }
    }

    # fallback to ssh if possible
    my $facts     = ansible_get_facts($c, $peer, 0);
    my $config    = config($c);
    if(!$config->{'ssh_fallback'}) {
        die("http(s) connection failed\n".$err) if $err;
        die("no http(s) control connection available\n");
    }

    my $server = get_server($c, $peer, $config);
    my $host_name = $server->{'host_name'};
    if(!$host_name) {
        die("http(s) connection failed\n".$err);
    }

    _debug("remote cmd failed, trying ssh fallback: %s", $err) if $err;
    my $env_vars = "";
    for my $key (sort keys %{$env}) {
        $env_vars .= " --extra-vars $key=\"".$env->{$key}."\"";
    }
    my $fullcmd = "ansible all -i ".$server->{'omd_site'}."\@$host_name, -m shell -a \"".$cmd."\"".$env_vars;
    ($rc, $out) = Thruk::Utils::IO::cmd($fullcmd, { env => { 'ANSIBLE_PYTHON_INTERPRETER' => 'auto_silent' }});
    if($out =~ m/^.*?\s+\|\s+UNREACHABLE.*?=>/mx) {
        die("http(s) and ssh connection failed\nhttp(s):\n".$err."\n\nssh:\n".$out) if $err;
        die("ssh connection failed\n".$out);
    }
    $out =~ s/^.*?\s+\|\s+.*?\s+\|\s+rc=\d\s+>>\s*//gmx;
    if($out =~ m/usage:\ ansible/mx) {
        confess("ansible command failed: cmd: ".$fullcmd."\n".$out);
    }
    $peer->{'ssh_ok'} = 1;
    return($rc, $out);
}

##########################################################
# upload and run a local script
sub _remote_script {
    my($c, $peer, $script, $background_options, $env) = @_;
    my($rc, $out, $err);

    my $args;
    ($script, $args) = split(/\s+/mx, $script, 2);
    if(!defined $args) { $args = ""; }
    if($args ne "") { $args = " ".$args; }

    if(!$peer->{'ssh_ok'} && ($peer->is_local() || $peer->is_peer_machine_reachable_by_http())) {
        my $script_data = Thruk::Utils::IO::read($script);
        my $remote_path = sprintf('var/tmp/%s', Thruk::Base::basename($script));

        eval {
            $peer->rpc($c, 'Thruk::Utils::IO::write', $remote_path, $script_data);
            ($rc, $out) = _remote_cmd($c, $peer, 'bash '.$remote_path.$args, $background_options, undef, $env);
        };
        $err = $@;
        if(!$err) {
            return($rc, $out);
        }
    }

    # fallback to ssh if possible
    my $facts     = ansible_get_facts($c, $peer, 0);
    my $config    = config($c);
    if(!$config->{'ssh_fallback'}) {
        die("http(s) connection failed\n".$err) if $err;
        die("no http(s) control connection available\n");
    }

    my $server = get_server($c, $peer, $config);
    my $host_name = $server->{'host_name'};
    if(!$host_name) {
        die("http(s) connection failed\n".$err);
    }

    _debug("remote cmd failed, trying ssh fallback: %s", $err) if $err;
    my $env_vars = "";
    for my $key (sort keys %{$env}) {
        $env_vars .= " --extra-vars $key=\"".$env->{$key}."\"";
    }
    my $fullcmd = "ansible all -i ".$server->{'omd_site'}."\@$host_name, -m script -a \"".$script.$args."\"".$env_vars;
    ($rc, $out) = Thruk::Utils::IO::cmd($fullcmd, { env => { 'ANSIBLE_PYTHON_INTERPRETER' => 'auto_silent' }});
    if($out =~ m/^.*?\s+\|\s+UNREACHABLE.*?=>/mx) {
        die("http(s) and ssh connection failed\nhttp(s):\n".$err."\n\nssh:\n".$out) if $err;
        die("ssh connection failed\n".$out);
    }
    $out =~ s/^.*?\s+\|\s+.*?\s+\|\s+rc=\d\s+>>\s*//gmx;
    if($out =~ m/usage:\ ansible/mx) {
        confess("ansible command failed: cmd: ".$fullcmd."\n".$out);
    }

    if($out !~ m/\Q | CHANGED =>\E/gmx) {
        die("ansible failed: rc $rc ".$out);
    }
    $out =~ s/\A.*?\Q | CHANGED =>\E//sgmx;
    my $jsonreader = Cpanel::JSON::XS->new->utf8;
       $jsonreader->relaxed();
    my $f;
    eval {
        $f = $jsonreader->decode($out);
    };
    if($@) {
        die("ansible failed to parse json: ".$@);
    }

    $peer->{'ssh_ok'} = 1;
    return($rc, $f->{'stdout'});
}

##########################################################
sub _local_run_hook {
    my($c, $hook, $env) = @_;

    # remove prefix for consistency
    if($hook =~ m/^script:(.*)$/mx) {
        $hook = $1;
    }

    my($rc, $out) = Thruk::Utils::IO::cmd($hook, { env => $env, print_prefix => "" });

    return($rc, $out);
}

##########################################################
sub _remote_run_hook {
    my($c, $peer, $hook, $env) = @_;

    my $uploaded;
    if($hook =~ m/^script:(.*)$/mx) {
        my $script = Thruk::Utils::IO::read($1);
        $peer->rpc($c, 'Thruk::Utils::IO::write', 'var/tmp/hook.sh', $script);
        $hook = 'bash var/tmp/hook.sh';
        $uploaded = 1;
    }

    my($rc, $job) = _remote_cmd($c, $peer, $hook, { env => $env }, $env);

    # wait for 300 sec
    my $jobdata = Thruk::Utils::External::wait_for_peer_job($c, $peer, $job, 1, 300, 1);

    _remote_cmd($c, $peer, 'rm -f var/tmp/hook.sh') if $uploaded;

    return("-1") unless $jobdata;
    return($jobdata->{'rc'});
}

##########################################################
sub _ansible_adhoc_cmd {
    my($c, $peer, $args) = @_;
    my $cmd = 'ansible all -i localhost, -c local '.$args." 2>/dev/null";
    my($rc, $data) = _remote_cmd($c, $peer, $cmd);
    if($rc != 0) {
        die("ansible failed: rc $rc ".$data);
    }
    if($data !~ m/\Qlocalhost | SUCCESS =>\E/gmx) {
        die("ansible failed: rc $rc ".$data);
    }
    $data =~ s/\A.*?\Qlocalhost | SUCCESS =>\E//sgmx;
    my $jsonreader = Cpanel::JSON::XS->new->utf8;
       $jsonreader->relaxed();
    my $f;
    eval {
        $f = $jsonreader->decode($data);
    };
    if($@) {
        die("ansible failed to parse json: ".$@);
    }
    return($f);
}

##########################################################

=head2 omd_service

  omd_service($c, $peer, $service, $cmd)

start/stop omd services

=cut
sub omd_service {
    my($c, $peer, $service, $cmd) = @_;
    my $job = Thruk::Utils::External::perl($c, {
        'expr'       => 'Thruk::NodeControl::Utils::_omd_service_cmd($c, "'.$peer->{'key'}.'", "'.$service.'", "'.$cmd.'");',
        'background' => 1,
        'clean'      => 1,
    });
    my $jobdata = Thruk::Utils::External::wait_for_peer_job($c, $peer, $job, 0.2, 90);
    delete $peer->{'ssh_ok'}; # http might work again now
    return $jobdata;
}

##########################################################
sub _omd_service_cmd {
    my($c, $peerkey, $service, $cmd) = @_;
    my $peer = $c->db->get_peer_by_key($peerkey);
    my($rc, $out);
    eval {
        ($rc, $out) = _remote_cmd($c, $peer, 'omd '.$cmd.' '.$service, $service eq 'apache' ? {} : undef);
    };
    if($@) {
        _warn("omd cmd failed: %s", $@);
        return;
    }
    if($rc != 0) {
        _warn("omd cmd failed: %s", $out);
        return;
    }
    update_runtime_data($c, $peer, 1);
    return 1;
}

##########################################################

=head2 config

  config($c)

return node control config

=cut
sub config {
    my($c) = @_;
    my $file = $c->config->{'var_path'}.'/node_control/_conf.json';
    my $var;
    if(-e $file) {
        $var = Thruk::Utils::IO::json_lock_retrieve($file);
    }

    # set defaults
    my $defaults = {
        'ssh_fallback'            => 1,
        'os_updates'              => 1,
        'pkg_install'             => 1,
        'pkg_cleanup'             => 1,
        'skip_confirms'           => 0,
        'parallel_tasks'          => 3,
        'omd_update_script'       => abs_path(Thruk::Base::dirname(__FILE__)."/../../../scripts/omd_update.sh"),
        'cmd_omd_cleanup'         => 'sudo -n omd cleanup',
        'cmd_yum_pkg_install'     => 'sudo -n yum install -y %PKG',
        'cmd_dnf_pkg_install'     => 'sudo -n dnf install -y %PKG',
        'cmd_apt_pkg_install'     => 'DEBIAN_FRONTEND=noninteractive sudo -En apt-get install -y %PKG',
        'cmd_yum_os_update'       => 'sudo -n yum upgrade -y',
        'cmd_dnf_os_update'       => 'sudo -n dnf upgrade -y',
        'cmd_apt_os_update'       => 'DEBIAN_FRONTEND=noninteractive sudo -En apt-get upgrade -y',
        'cmd_yum_os_sec_update'   => 'sudo -n yum upgrade -y --security',
        'cmd_dnf_os_sec_update'   => 'sudo -n dnf upgrade -y --security',
        'cmd_apt_os_sec_update'   => 'DEBIAN_FRONTEND=noninteractive sudo -En apt-get upgrade -y    ',
    };

    # merge var into config
    my $conf = {%{$defaults}, %{$c->config->{'Thruk::Plugin::NodeControl'}//{}}, %{$var//{}}};

    return($conf);
}

##########################################################

=head2 save_config

  save_config($c)

save config to disk

=cut
sub save_config {
    my($c, $newconf) = @_;
    my $conf = {%{config($c)}, %{$newconf//{}}};
    my $file = $c->config->{'var_path'}.'/node_control/_conf.json';

    my $allowed_keys = {
        'omd_default_version'   => 1,
    };

    for my $key (sort keys %{$newconf}) {
        confess('config option '.$key.' not storable in var/') unless $allowed_keys->{$key};
    }

    # remove all keys except those which store a override in var/
    for my $key (sort keys %{$conf}) {
        delete $conf->{$key} unless $allowed_keys->{$key};
    }

    Thruk::Utils::IO::json_lock_store($file, $conf);
    return;
}

##########################################################

sub _machine_type {
    my($facts) = @_;
    if($facts->{'ansible_facts'}->{'ansible_virtualization_role'} && $facts->{'ansible_facts'}->{'ansible_virtualization_role'} eq 'guest') {
        return($facts->{'ansible_facts'}->{'ansible_virtualization_type'});
    }
    return;
}

##########################################################
sub _parse_yum_check_update {
    my($out) = @_;
    $out =~ s/^\s*$//gmx;
    my @pkgs = $out =~ /^(\S+)\s+\S+\s+\w+$/gmx;
    @pkgs = map { my $p = $_; $p =~ s/(\.noarch|\.x86_64)$//gmx; $p; } @pkgs;
    return(\@pkgs);
}

##########################################################
sub _cmd_line {
    my($rawcmd, $macros) = @_;
    my $cmd = $rawcmd;
    if($macros) {
        for my $key (keys %{$macros}) {
            my $val = $macros->{$key};
            $cmd =~ s/$key/$val/gmx;
        }
    }
    return $cmd;
}

##########################################################
sub _set_job_started {
    my($c, $type, $peerkey) = @_;

    my $file = $c->config->{'var_path'}.'/node_control/'.$peerkey.'.json';
    my $data = { 'last_error' => '' };
    $data->{$type."_failed"} = "0";
    $data->{$type."_time"}   = time();
    $data->{$type."_user"}   = $c->stash->{'remote_user'} // '';
    if($ENV{'THRUK_JOB_ID'}) {
        $data->{$type}      = $ENV{'THRUK_JOB_ID'};
        $data->{'last_job'} = $ENV{'THRUK_JOB_ID'};
    } else {
        $data->{$type}      = 1;
    }
    Thruk::Utils::IO::json_lock_patch($file, $data, { pretty => 1, allow_empty => 1 });

    return;
}

##########################################################
sub _set_job_done {
    my($c, $type, $peerkey) = @_;

    my $file = $c->config->{'var_path'}.'/node_control/'.$peerkey.'.json';
    my $data = {
        'last_error' => '',
    };
    $data->{$type} = 0;
    Thruk::Utils::IO::json_lock_patch($file, $data, { pretty => 1, allow_empty => 1 });

    return;
}

##########################################################
sub _set_job_errored {
    my($c, $type, $peerkey, $err) = @_;

    chomp($err);
    print "*** [ERROR] $err\n";

    my $file = $c->config->{'var_path'}.'/node_control/'.$peerkey.'.json';
    my $cur  = Thruk::Utils::IO::json_lock_retrieve($file);
    if($cur->{'last_error'}) {
        # append error
        $err = $cur->{'last_error'}."\n".$err;
    }
    my $data = {
        'last_error' => $err,
    };
    $data->{$type} = 0;
    $data->{$type."_failed"} = "1";
    Thruk::Utils::IO::json_lock_patch($file, $data, { pretty => 1, allow_empty => 1 });

    return;
}

##########################################################
sub _get_hook_env {
    my($c, $peer, $version) = @_;
    my $server = get_server($c, $peer);
    my $env = {
        'PEER_NAME'        => $peer->{'name'}          // '',
        'PEER_KEY'         => $peer->{'key'}           // '',
        'OMD_HOST_NAME'    => $server->{'host_name'}   // '',
        'SITE_NAME'        => $server->{'omd_site'}    // '',
        'FROM_OMD_VERSION' => $server->{'omd_version'} // '',
        'OMD_UPDATE'       => $version                 // '',
    };
    return($env);
}

##########################################################

1;
