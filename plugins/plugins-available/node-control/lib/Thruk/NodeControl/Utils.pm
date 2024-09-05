package Thruk::NodeControl::Utils;

use warnings;
use strict;
use Carp;
use Cpanel::JSON::XS ();
use Time::HiRes qw/sleep/;

use Thruk::Base ();
use Thruk::Constants qw/:peer_states/;
use Thruk::Utils::External ();
use Thruk::Utils::IO ();
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
    for my $peer (@{$c->db->get_local_peers()}, @{$c->db->get_http_peers(1)}) {
        next if (defined $peer->{'disabled'} && $peer->{'disabled'} == HIDDEN_LMD_PARENT);
        push @peers, $peer;
    }
    return \@peers;
}

##########################################################

=head2 get_server

  get_server($c)

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
            return;
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
    my $server = {
        peer_key                => $peer->{'key'},
        section                 => $peer->{'section'},
        gathering               => $facts->{'gathering'} || 0,
        cleaning                => $facts->{'cleaning'} || 0,
        run_all                 => $facts->{'run_all'} || 0,
        installing              => $facts->{'installing'} || 0,
        updating                => $facts->{'updating'} || 0,
        os_updating             => $facts->{'os_updating'} || 0,
        os_sec_updating         => $facts->{'os_sec_updating'} || 0,
        host_name               => $facts->{'ansible_facts'}->{'ansible_fqdn'} // $peer->{'name'},
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
        facts                   => $facts || {},
    };

    # remove current default from cleanable
    if($server->{'omd_cleanable'}) {
        my $def = $config->{'omd_default_version'};
        @{$server->{'omd_cleanable'}} = grep(!/$def/mx, @{$server->{'omd_cleanable'}}) if $def;
    }

    return($server);
}

##########################################################

=head2 ansible_get_facts

  ansible_get_facts($c, $peer)

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
    my $f       = _ansible_adhoc_cmd($c, $peer, "-m setup -a 'gather_subset=hardware,virtual gather_timeout=30'");
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
    my(undef, $omd_version) = _remote_cmd($c, $peer, 'omd version -b');
    chomp($omd_version);
    $runtime->{'omd_version'} = $omd_version;

    my(undef, $omd_status) = _remote_cmd($c, $peer, 'omd status -b');
    my %services = ($omd_status =~ m/^(\S+?)\s+(\d+)/gmx);
    $runtime->{'omd_status'} = \%services;

    my(undef, $omd_site) = _remote_cmd($c, $peer, 'id -un');
    chomp($omd_site);
    $runtime->{'omd_site'} = $omd_site;

    my(undef, $omd_disk) = _remote_cmd($c, $peer, 'df -k version/.');
    if($omd_disk =~ m/^.*\s+(\d+)\s+(\d+)\s+(\d+)\s+/gmx) {
        $runtime->{'omd_disk_total'} = $1;
        $runtime->{'omd_disk_free'}  = $3;
    }

    my(undef, $has_tmux) = _remote_cmd($c, $peer, '/bin/sh -c "command -v tmux"');
    if($has_tmux =~ m/tmux$/gmx) {
        $runtime->{'has_tmux'} = $has_tmux;
    }

    if(!$skip_cpu) {
        my(undef, $omd_cpu) = _remote_cmd($c, $peer, 'top -bn2 | grep Cpu | tail -n 1');
        if($omd_cpu =~ m/Cpu/gmx) {
            my @val = split/\s+/mx, $omd_cpu;
            $runtime->{'omd_cpu_perc'}  = (100-$val[7])/100;
        }
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
        (undef, $pkgs) = _remote_cmd($c, $peer, 'yum search omd-');
    } elsif($facts->{'ansible_facts'}->{'ansible_pkg_mgr'} eq 'dnf') {
        (undef, $pkgs) = _remote_cmd($c, $peer, 'dnf search omd-');
    } elsif($facts->{'ansible_facts'}->{'ansible_pkg_mgr'} eq 'apt') {
        (undef, $pkgs) = _remote_cmd($c, $peer, 'apt-cache search omd-');
    } else {
        die("unknown package manager: ".$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}//'none');
    }
    my @pkgs = ($pkgs =~ m/^(omd\-\S+?)(?:\s|\.x86_64)/gmx);
    @pkgs = grep(!/^(omd-labs-edition|omd-daily)/mx, @pkgs); # remove meta packages
    @pkgs = reverse sort @pkgs;
    @pkgs = map { my $pkg = $_; $pkg =~ s/^omd\-//gmx; $pkg; } @pkgs;

    # get installed omd versions
    my $installed;
    (undef, $installed) = _remote_cmd($c, $peer, 'omd versions');
    my @inst = split/\n/mx, $installed;
    my $default;
    for my $i (@inst) {
        if($i =~ m/\Q(default)\E/mx) {
            $i =~ s/\s*\Q(default)\E//gmx;
            $default = $i;
        }
    }

    my %omd_sites;
    my %in_use;
    my $sites;
    (undef, $sites) = _remote_cmd($c, $peer, 'omd sites');
    my @sites = split/\n/mx, $sites;
    for my $s (@sites) {
        my($name, $version, $comment) = split/\s+/mx, $s;
        $omd_sites{$name} = $version;
        $in_use{$version} = 1;
    }
    $in_use{$default} = 1;

    my @cleanable;
    for my $v (@inst) {
        next if $in_use{$v};
        push @cleanable, $v;
    }

    return({ omd_packages_available => \@pkgs, omd_versions => \@inst, omd_cleanable => \@cleanable, omd_sites => \%omd_sites });
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

    my $config = config($c);
    if(!$config->{'cmd_'.$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}.'_pkg_install'}) {
        die("package manager ".$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}." not supported");
    }
    my $cmd = _cmd_line($config->{'cmd_'.$facts->{'ansible_facts'}->{'ansible_pkg_mgr'}.'_pkg_install'}, { '%PKG' => $version });

    my $file = $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'.json';
    my $f = Thruk::Utils::IO::json_lock_patch($file, { 'installing' => 1, 'last_error' => '' }, { pretty => 1, allow_empty => 1 });

    my($rc, $job);
    eval {
        ($rc, $job) = _remote_cmd($c, $peer, $cmd, { message => 'Installing OMD '.$version });
        die("starting job failed") unless $job;
    };
    if($@) {
        $f = Thruk::Utils::IO::json_lock_patch($file, { 'installing' => 0, 'last_error' => $@ }, { pretty => 1, allow_empty => 1 });
        return;
    }

    Thruk::Utils::IO::json_lock_patch($file, { 'installing' => $job, 'last_job' => $job, 'last_error' => "" }, { pretty => 1, allow_empty => 1 });
    return($job);
}

##########################################################

=head2 omd_update

  omd_update($c, $peer, $version)

update site to given version on peer

=cut
sub omd_update {
    my($c, $peer, $version, $force) = @_;

    my $facts = _ansible_get_facts($c, $peer, 0);
    return if $facts->{'updating'};
    return if ($facts->{'run_all'} && !$force);

    my $file   = $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'.json';
    my $f      = Thruk::Utils::IO::json_lock_patch($file, { 'updating' => 1, 'last_error' => '' }, { pretty => 1, allow_empty => 1 });
    my $config = config($c);

    if($config->{'hook_update_pre'}) {
        my($rc, $out) = _remote_cmd($c, $peer, $config->{'hook_update_pre'});
        if($rc != 0) {
            Thruk::Utils::IO::json_lock_patch($file, { 'updating' => 0, 'last_error' => "update canceled by pre hook: ".$out }, { pretty => 1, allow_empty => 1 });
            return;
        }
    }

    # continue in background job
    my $job = Thruk::Utils::External::perl($c, {
        expr       => 'Thruk::NodeControl::Utils::_omd_update_step2($c, "'.$peer->{'key'}.'", "'.$version.'")',
        background => 1,
    });
    return($job);
}

##########################################################
sub _omd_update_step2 {
    my($c, $peerkey, $version) = @_;
    my $peer   = $c->db->get_peer_by_key($peerkey);
    my $file   = $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'.json';
    my $config = config($c);

    my($rc, $job);
    eval {
        my $root   = Thruk::Base::dirname(__FILE__);
        my $script = Thruk::Utils::IO::read($root."/../../../scripts/omd_update.sh");
        $peer->rpc($c, 'Thruk::Utils::IO::write', 'var/tmp/omd_update.sh', $script);

        if($config->{'hook_update_post'}) {
            $peer->rpc($c, 'Thruk::Utils::IO::write', 'var/tmp/omd_update_post.sh', $config->{'hook_update_post'});
        } else {
            $peer->rpc($c, 'Thruk::Utils::IO::write', 'var/tmp/omd_update_post.sh', "");
        }

        ($rc, $job) = _remote_cmd($c, $peer, 'OMD_UPDATE="'.$version.'" bash var/tmp/omd_update.sh', { message => 'Updating Site To '.$version });
    };
    if($@) {
        Thruk::Utils::IO::json_lock_patch($file, { 'updating' => 0, 'last_error' => $@ }, { pretty => 1, allow_empty => 1 });
        return;
    }

    Thruk::Utils::IO::json_lock_patch($file, { 'updating' => $job, 'last_job' => $job, 'last_error' => "" }, { pretty => 1, allow_empty => 1 });

    # wait for 180 sec
    my $jobdata = _wait_for_job($c, $peer, $job, 3, 180, 1);
    if($jobdata && $jobdata->{'rc'} ne "0") {
        update_runtime_data($c, $peer, 1);
        return;
    }

    update_runtime_data($c, $peer, 1);

    return($job);
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

    my $file   = $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'.json';
    my $config = config($c);

    # continue in background job
    my $job = Thruk::Utils::External::perl($c, {
        expr       => 'Thruk::NodeControl::Utils::_omd_install_update_cleanup_step2($c, "'.$peer->{'key'}.'", "'.$version.'")',
        background => 1,
    });
    Thruk::Utils::IO::json_lock_patch($file, { 'run_all' => $job, 'last_job' => $job }, { pretty => 1, allow_empty => 1 });
    return($job);
}

##########################################################
sub _omd_install_update_cleanup_step2 {
    my($c, $peerkey, $version) = @_;
    my $peer   = $c->db->get_peer_by_key($peerkey);
    my $config = config($c);
    my $file   = $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'.json';
    my $facts  = _ansible_get_facts($c, $peer, 0);

    my($job, $jobdata);
    # install omd pkg
    print "*** installing $version\n";
    if(!grep(/$version/mx, @{$facts->{'omd_versions'} // []})) {
        $job     = omd_install($c, $peer, $version, 1);
        die("failed to start install") unless $job;
        $jobdata = _wait_for_job($c, $peer, $job, 3, 1800);
        return unless $jobdata;
        print $jobdata->{'stdout'},"\n";
        print $jobdata->{'stderr'},"\n";
    } else {
        print "*** not required, already installed\n";
    }

    # update
    my $f = _ansible_get_facts($c, $peer, 0);
    print "*** updating to $version\n";
    if($f->{'omd_version'} ne $version) {
        $job  = omd_update($c, $peer, $version, 1);
        my $f = _ansible_get_facts($c, $peer, 0);
        if(!$job && ($f->{'last_error'}//$f->{'last_facts_error'})) {
            print ($f->{'last_error'}//$f->{'last_facts_error'});
            return;
        }
        die("failed to start update") unless $job;
        $jobdata = _wait_for_job($c, $peer, $job, 3, 180);
        return unless $jobdata;
        print $jobdata->{'stdout'},"\n";
        print $jobdata->{'stderr'},"\n";
    } else {
        print "*** not required, already current version\n";
    }

    # cleanup
    print "*** running cleanup\n";
    $job     = omd_cleanup($c, $peer, 1);
    die("failed to start cleanup") unless $job;
    $jobdata = _wait_for_job($c, $peer, $job, 3, 1800);
    print $jobdata->{'stdout'},"\n";
    print $jobdata->{'stderr'},"\n";

    Thruk::Utils::IO::json_lock_patch($file, { 'run_all' => 0, 'last_error' => '' }, { pretty => 1, allow_empty => 1 });

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

    my $file   = $c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'.json';
    my $f      = Thruk::Utils::IO::json_lock_patch($file, { 'cleaning' => 1, 'last_error' => '' }, { pretty => 1, allow_empty => 1 });
    my $config = config($c);
    my $cmd    = _cmd_line($config->{'cmd_omd_cleanup'});

    my($rc, $job);
    eval {
        ($rc, $job) = _remote_cmd($c, $peer, $cmd, { message => 'Running OMD cleanup' });
    };
    if($@) {
        $f = Thruk::Utils::IO::json_lock_patch($file, { 'cleaning' => 0, 'last_error' => $@ }, { pretty => 1, allow_empty => 1 });
        return;
    }

    Thruk::Utils::IO::json_lock_patch($file, { 'cleaning' => $job, 'last_job' => $job, 'last_error' => "" }, { pretty => 1, allow_empty => 1 });
    return($job);
}

##########################################################
sub _remote_cmd {
    my($c, $peer, $cmd, $background_options) = @_;
    my($rc, $out);
    eval {
        ($rc, $out) = $peer->cmd($c, $cmd, $background_options);
    };
    my $err = $@;
    if($err) {
        # fallback to ssh if possible
        my $facts     = ansible_get_facts($c, $peer, 0);
        my $host_name = $facts->{'ansible_facts'}->{'ansible_fqdn'};
        if($host_name && !$background_options) {
            _warn("remote cmd failed, trying ssh fallback: %s", $err);
            _debug("fallback to ssh");
            ($rc, $out) = Thruk::Utils::IO::cmd($c, "ansible all -i $host_name, -m shell -a \"".$cmd."\"");
            die($out) if $out =~ m/^.*?\s+\|\s+UNREACHABLE.*?=>/mx;
            $out =~ s/^.*?\s+\|\s+.*?\s+\|\s+rc=\d\s+>>//gmx;
            return($rc, $out);
        } else {
            die($err);
        }
    }
    return($rc, $out);
}

##########################################################
sub _ansible_adhoc_cmd {
    my($c, $peer, $args) = @_;
    my($rc, $data) = _remote_cmd($c, $peer, 'ansible all -i localhost, -c local '.$args);
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
    _wait_for_job($c, $peer, $job, 0.2, 90);
    return;
}

##########################################################
sub _omd_service_cmd {
    my($c, $peerkey, $service, $cmd) = @_;
    my $peer = $c->db->get_peer_by_key($peerkey);
    my($rc, $out);
    eval {
        ($rc, $out) = _remote_cmd($c, $peer, 'omd '.$cmd.' '.$service);
    };
    if($@) {
        _warn("omd cmd failed: %s", $@);
    }
    update_runtime_data($c, $peer, 1);
    return;
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
        'parallel_tasks'        => 1,
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
sub _wait_for_job {
    my($c, $peer, $job, $poll_interval, $max_wait, $print) = @_;
    $max_wait      = 60 unless $max_wait;
    $poll_interval =  3 unless $poll_interval;
    my $end = time() + $max_wait;
    my $jobdata;
    while(time() < $end) {
        eval {
            $jobdata = $peer->job_data($c, $job);
        };
        if($jobdata && !$jobdata->{'is_running'}) {
            last;
        }
        sleep($poll_interval);
    }
    if($jobdata && $print) {
        print $jobdata->{'stdout'},"\n" if $jobdata->{'stdout'};
        print $jobdata->{'stderr'},"\n" if $jobdata->{'stderr'};
    }
    return($jobdata);
}

##########################################################

1;
