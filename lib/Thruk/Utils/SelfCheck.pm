package Thruk::Utils::SelfCheck;

=head1 NAME

Thruk::Utils::SelfCheck - Utilities Collection for Checking Thruks Integrity

=head1 DESCRIPTION

Utilities Collection for Checking Thruks Integrity

=cut

use warnings;
use strict;

use Thruk::Constants ':peer_states';
use Thruk::Utils ();
use Thruk::Utils::RecurringDowntimes ();

my $rc_codes = {
    '0'     => 'OK',
    '1'     => 'WARNING',
    '2'     => 'CRITICAL',
    '3'     => 'UNKNOWN',
};

my $available_checks = {
    'filesystem'          => \&_filesystem_checks,
    'logfiles'            => \&_logfile_checks,
    'reports'             => \&_report_checks,
    'recurring_downtimes' => \&_reccuring_downtime_checks,
    'lmd'                 => \&_lmd_checks,
    'logcache'            => \&_logcache_checks,
    'backends'            => \&_backends_checks,
};

##############################################

=head1 METHODS

=head2 self_check

    self_check($c)

perform all self checks

return:

    (rc, msg, details)

    rc:  0 - OK
         1 - WARNING
         2 - CRITICAL
         3 - UNKNOWN

    msg: short message with textual result

    details: detailed message

=cut
sub self_check {
    my($self, $c, $type) = @_;
    my($rc, $msg, $details);
    my $results = [];
    my($selected, $dont) = ({}, {});
    for my $t (@{Thruk::Base::comma_separated_list($type)}) {
        if($t =~ m/^\!(.*)$/mx) {
            $dont->{$1} = 1;
        } else {
            $selected->{$t} = 1;
        }
    }
    if(scalar keys %{$selected} == 0 || $selected->{'all'}) {
        for my $t (sort keys %{$available_checks}) {
            $selected->{$t} = 1;
        }
        $selected->{'all'} = 1;
    }
    for my $t (sort keys %{$dont}) {
        delete $selected->{$t};
    }

    # run checks
    for my $t (sort keys %{$selected}) {
        next if $t eq 'all';
        if(!defined $available_checks->{$t}) {
            push @{$results}, {
                sub     => $t,
                rc      => 3,
                msg     => 'UNKNOW - unknown subcheck type',
                details => "available subcheck types are: ".join(", ", (sort keys %{$available_checks})),
            };
            next;
        }
        $c->stats->profile(begin => "selfcheck: $t");
        push @{$results}, &{$available_checks->{$t}}($c);
        $c->stats->profile(end => "selfcheck: $t");
    }

    # aggregate results
    $details = "";
    if(scalar @{$results} == 0) {
        $rc  = 3;
        $msg = "UNKNOWN - unknown subcheck type";
    } else {
        # sort by rc
        @{$results} = sort { $b->{rc} <=> $a->{rc} || $a->{sub} cmp $b->{sub} } @{$results};
        $rc = $results->[0]->{rc};
        my($ok, $warning, $critical, $unknown) = ([],[],[],[]);
        for my $r (@{$results}) {
            $details .= $r->{'details'}."\n";
            push @{$ok},      $r->{sub} if $r->{rc} == 0;
            push @{$warning}, $r->{sub} if $r->{rc} == 1;
            push @{$critical},$r->{sub} if $r->{rc} == 2;
            push @{$unknown}, $r->{sub} if $r->{rc} == 3;
        }
        $msg = 'OK - '.      join(', ', @{$ok})       if $rc == 0;
        $msg = 'WARNING - '. join(', ', @{$warning})  if $rc == 1;
        $msg = 'CRITICAL - '.join(', ', @{$critical}) if $rc == 2;
        $msg = 'UNKNOWN - '. join(', ', @{$unknown})  if $rc == 3;
    }

    # append performance data from /thruk/metrics
    if($selected->{'all'}) {
        $c->stats->profile(begin => "selfcheck: metrics");
        require Thruk::Utils::CLI::Rest;
        my $res = Thruk::Utils::CLI::Rest::cmd($c, undef, ['-o', ' ', '/thruk/metrics']);
        if($res->{'rc'} == 0 && $res->{'output'}) {
            $details .= $res->{'output'};
        }
        $c->stats->profile(end => "selfcheck: metrics");
    }

    return($rc, $msg, $details);
}

##############################################

=head2 _filesystem_checks

    _filesystem_checks($c)

verify basic filesystem related things

=cut
sub _filesystem_checks  {
    my($c) = @_;
    my $rc      = 0;
    my $details = "Filesystem:\n";

    for my $fs (['var path', $c->config->{'var_path'}],
                ['tmp path', $c->config->{'tmp_path'}],
                ) {
# TODO: check...
        if(!-e $fs->[1]) {
            $details .= sprintf("  - %s %s does not exist: %s\n", $fs->[0], $fs->[1], $!);
            $rc = 2;
            next;
        }
        if(-w $fs->[1]) {
            $details .= sprintf("  - %s %s is writable\n", $fs->[0], $fs->[1]);
        } else {
            $details .= sprintf("  - %s %s is not writable: %s\n", $fs->[0], $fs->[1], $!);
            $rc = 2;
        }
    }
    my $msg = sprintf('Filesystem %s', $rc_codes->{$rc});
    return({sub => 'filesystem', rc => $rc, msg => $msg, details => $details});
}

##############################################

=head2 _logfile_checks

    _logfile_checks($c)

verify logfile errors

=cut
sub _logfile_checks  {
    my($c) = @_;
    my $details = "Logfiles:\n";

    my $rc = 0;
    for my $log ($c->config->{'var_path'}.'/cron.log',
                 $c->config->{'log4perl_logfile_in_use'},
                ) {
        next unless $log;    # may not be set
        next unless Thruk::Utils::IO::file_exists($log); # may not exist either
        # count errors
# TODO: won't work with DB
        my @out = split(/\n/mx, Thruk::Utils::IO::cmd("grep 'ERROR' $log"));
        $details .= sprintf("  - %s: ", $log);
        if(scalar @out == 0) {
            $details .= "no errors\n";
        } else {
            $details .= (scalar @out)." errors found\n";
            $rc       = 1;
        }
    }

    my $msg = sprintf('Logfiles %s', $rc_codes->{$rc});
    return({sub => 'logfiles', rc => $rc, msg => $msg, details => $details});
}


##############################################

=head2 _report_checks

    _report_checks($c)

verify errors in reports

=cut
sub _report_checks  {
    my($c) = @_;
    my $details = "Reports:\n";

    eval {
        require Thruk::Utils::Reports;
    };
    if($@) {
        return({sub => 'reports', rc => 0, msg => 'Reports OK', details => "reports plugin not enabled"});
    }

    my $rc      = 0;
    my $reports = Thruk::Utils::Reports::get_report_list($c, 1);
    my $errors  = 0;
    for my $r (@{$reports}) {
        if($r->{'failed'}) {
            $details .= sprintf(" report failed: #%d - %s\n", $r->{'nr'}, $r->{'name'});
            $errors++;
        }
        for my $cr (@{$r->{'schedule'}}) {
            my $time = Thruk::Utils::get_cron_time_entry($cr);
            if(!defined $time) {
                $details .= sprintf(" report cannot expand cron entry: #%d - %s\n", $r->{'nr'}, $r->{'name'});
                $errors++;
            }
        }
    }
    if($errors == 0) {
        $details .= "  - no errors in ".(scalar @{$reports})." reports\n";
    } else {
        $rc = 2;
    }

    my $msg = sprintf('Reports %s', $rc_codes->{$rc});
    return({sub => 'reports', rc => $rc, msg => $msg, details => $details});
}

##############################################

=head2 _reccuring_downtime_checks

    _reccuring_downtime_checks($c)

verify errors in recurring downtimes

=cut
sub _reccuring_downtime_checks  {
    my($c) = @_;
    my $details = "Recurring Downtimes:\n";
    my $rc      = 0;
    my $errors  = 0;

    my $downtimes = Thruk::Utils::RecurringDowntimes::get_downtimes_list($c, 0, 1);
    for my $d (@{$downtimes}) {
        my $file    = $c->config->{'var_path'}.'/downtimes/'.$d->{'file'}.'.tsk';
        my($err, $detail) = Thruk::Utils::RecurringDowntimes::check_downtime($c, $d, $file);
        $errors  += $err;
        $details .= $detail;
    }

    if($errors == 0) {
        $details .= "  - no errors in ".(scalar @{$downtimes})." downtimes\n";
    } else {
        $rc = 2;
    }

    my $msg = sprintf('Recurring Downtimes %s', $rc_codes->{$rc});
    return({sub => 'recurring_downtimes', rc => $rc, msg => $msg, details => $details});
}

##############################################

=head2 check_recurring_downtime

    check_recurring_downtime($c, $d, $file)

verify errors in specific recurring downtime

=cut
sub check_recurring_downtime {
    my($c, $downtime, $file) = @_;

    my $fixables = {};
    my $errors   = 0;
    my $details  = "";

    #my($backends, $cmd_typ)...
    my($backends, undef) = Thruk::Utils::RecurringDowntimes::get_downtime_backends($c, $downtime);
    my $cleaned_backends = [];
    for my $b (@{$backends}) {
        my $peer = $c->db->get_peer_by_key($b);
        if($peer) {
            push @{$cleaned_backends}, $b;
        } else {
            $details .= "  - ERROR: backend with id ".$b." does not exist in recurring downtime ".$file."\n";
            $errors++;
            push @{$fixables->{'backends'}}, $b;
        }
    }
    $backends = $cleaned_backends;

    if($downtime->{'target'} eq 'host') {
        my $data   = $c->db->get_hosts(filter => [{ 'name' => { '-or' => $downtime->{'host'}  }} ], columns => [qw/name/], backend => $backends );
        my $lookup = Thruk::Base::array2hash($data, "name");
        for my $hst (@{$downtime->{'host'}}) {
            if(!$lookup->{$hst}) {
                $details .= "  - ERROR: ".$downtime->{'target'}." ".$hst." not found in recurring downtime ".$file."\n";
                $errors++;
                push @{$fixables->{'host'}}, $hst;
            }
        }
    }
    elsif($downtime->{'target'} eq 'service') {
        # check if there are host which do not match a single service or do not exist at all
        my $data   = $c->db->get_hosts(filter => [{ 'name' => { '-or' => $downtime->{'host'}  }} ], columns => [qw/name services/], backend => $backends );
        my $lookup = Thruk::Base::array2hash($data, "name");
        for my $hst (@{$downtime->{'host'}}) {
            # does the host itself exist
            if(!$lookup->{$hst}) {
                $details .= "  - ERROR: host ".$hst." not found in recurring downtime ".$file."\n";
                $errors++;
                push @{$fixables->{'host'}}, $hst;
                next;
            }
            # does it match at least one service
            my $found = 0;
            for my $svc1 (@{$downtime->{'service'}}) {
                for my $svc2 (@{$lookup->{$hst}->{'services'}}) {
                    if($svc1 eq $svc2) {
                        $found = 1;
                        last;
                    }
                }
            }
            if(!$found) {
                $details .= "  - ERROR: host ".$hst." does not have any of the configured services in recurring downtime ".$file."\n";
                $errors++;
                push @{$fixables->{'host'}}, $hst;
                next;
            }
        }

        # check if each service matches at least one host
        my $svc_lookup = {};
        for my $hstdata (@{$data}) {
            for my $svc (@{$hstdata->{'services'}}) {
                $svc_lookup->{$svc} = 1;
            }
        }
        my $svcdata    = $c->db->get_services(filter => [{ 'description' => { '-or' => $downtime->{'service'}  }} ], columns => [qw/description/], backend => $backends );
        my $namelookup = Thruk::Base::array2hash($svcdata, "description");
        for my $svc (@{$downtime->{'service'}}) {
            if(!$namelookup->{$svc}) {
                $details .= "  - ERROR: service ".$svc." not found in recurring downtime ".$file."\n";
                $errors++;
                push @{$fixables->{'service'}}, $svc;
                next;
            }
            if(!$svc_lookup->{$svc}) {
                $details .= "  - ERROR: service ".$svc." does not match any of the configured hosts in recurring downtime ".$file."\n";
                $errors++;
                push @{$fixables->{'service'}}, $svc;
                next;
            }
        }
    }
    elsif($downtime->{'target'} eq 'hostgroup') {
        my $data   = $c->db->get_hostgroups(filter => [{ 'name' => { '-or' => $downtime->{'hostgroup'}  }} ], columns => [qw/name/], backend => $backends );
        my $lookup = Thruk::Base::array2hash($data, "name");
        for my $grp (@{$downtime->{'hostgroup'}}) {
            if(!$lookup->{$grp}) {
                $details .= "  - ERROR: hostgroup ".$grp." not found in recurring downtime ".$file."\n";
                $errors++;
                push @{$fixables->{'hostgroup'}}, $grp;
            }
        }
    }
    elsif($downtime->{'target'} eq 'servicegroup') {
        my $data   = $c->db->get_servicegroups(filter => [{ 'name' => { '-or' => $downtime->{'servicegroup'}  }} ], columns => [qw/name/], backend => $backends );
        my $lookup = Thruk::Base::array2hash($data, "name");
        for my $grp (@{$downtime->{$downtime->{'target'}}}) {
            if(!$lookup->{$grp}) {
                $details .= "  - ERROR: servicegroup ".$grp." not found in recurring downtime ".$file."\n";
                $errors++;
                push @{$fixables->{'servicegroup'}}, $grp;
            }
        }
    }

    for my $cr (@{$downtime->{'schedule'}}) {
        my $time = Thruk::Utils::get_cron_time_entry($cr);
        if(!defined $time) {
            $details .= "  - ERROR: cannot expand cron entry in recurring downtime ".$file."\n";
            $errors++;
        }
    }

    return($errors, $details, $fixables);
}

##############################################

=head2 _lmd_checks

    _lmd_checks($c)

verify errors in lmd

=cut
sub _lmd_checks  {
    my($c) = @_;
    return unless $c->config->{'use_lmd_core'};
    my $rc      = 0;
    my $details = "LMD:\n";

    if($c->config->{'lmd_core_bin'} && $c->config->{'lmd_core_bin'} ne 'lmd') {
        my($lmd_core_bin) = glob($c->config->{'lmd_core_bin'});
        if(!$lmd_core_bin || ! -x $lmd_core_bin) {
            chomp(my $err = $!);
            $details .= sprintf("  - lmd binary %s not executable: %s\n", $c->config->{'lmd_core_bin'}, $err);
            return({sub => 'lmd', rc => 2, msg => "LMD CRITICAL", details => $details });
        }
    }

    # try to run
    my $cmd = ($c->config->{'lmd_core_bin'} || 'lmd').' --version 2>&1';
    my(undef, $output) = Thruk::Utils::IO::cmd($cmd);
    if($output !~ m/\Qlmd - version \E/mx) {
        $details .= sprintf("  - cannot execute lmd: %s\n", $output);
        return({sub => 'lmd', rc => 2, msg => "LMD CRITICAL", details => $details });
    }

    require Thruk::Utils::LMD;
    my($status, undef) = Thruk::Utils::LMD::status($c->config);
    my $pid = $status->[0]->{'pid'};
    if(!$pid) {
        $details .= "  - lmd not running\n";
        $rc = 1 unless $rc > 1;
    } else {
        my $start_time = $status->[0]->{'start_time'};
        $details .= sprintf("  - lmd running with pid %s since %s\n", $pid, Thruk::Utils::Filter::date_format($c, $start_time));

        $c->db->reset_failed_backends();
        my($backends) = $c->db->select_backends();

        my $total = scalar @{$backends};
        my $stats = $c->db->lmd_stats($c);
        my $online = 0;
        for my $stat (@{$stats}) {
            $online++ if $stat->{'status'} == 0;
        }
        $details .= sprintf("  - %i/%i backends online\n", $online, $total);
        for my $peer ( @{ $c->db->get_peers() } ) {
            my $key  = $peer->{'key'};
            my $name = $peer->{'name'};
            next unless $c->stash->{'failed_backends'}->{$key};
            $details .= sprintf("    - %s: %s\n", $name, $c->stash->{'failed_backends'}->{$key});
        }
        if($online != $total) {
            $rc = 1 unless $rc > 1;
        }
    }

    for my $log ($c->config->{'tmp_path'}.'/lmd/lmd.log') {
        next unless Thruk::Utils::IO::file_exists($log); # may not exist either
        # count errors
# TODO: won't work with DB
        my @out = split(/\n/mx, Thruk::Utils::IO::cmd("grep 'Panic:' $log"));
        $details .= sprintf("  - %s: ", $log);
        if(scalar @out == 0) {
            $details .= "no errors\n";
        } else {
            $details .= (scalar @out)." errors found\n";
            my $x = 0;
            for my $last_err (reverse @out) {
                $last_err = substr($last_err, 0, 97)."..." if length($last_err) > 100;
                $details .= sprintf("    * %s\n", $last_err);
                $x++;
                last if $x >= 3;
            }
            $rc = 1 unless $rc > 1;
        }
    }

    my $msg = sprintf('LMD %s', $rc_codes->{$rc});
    return({sub => 'lmd', rc => $rc, msg => $msg, details => $details});
}

##############################################

=head2 _logcache_checks

    _logcache_checks($c)

verify errors in logcache

=cut
sub _logcache_checks  {
    my($c) = @_;
    my $details = "Logcache:\n";

    return unless defined $c->config->{'logcache'};

    require Thruk::Backend::Provider::Mysql;
    Thruk::Backend::Provider::Mysql->import;

    my $rc      = 0;
    my $errors  = 0;
    my @stats     = Thruk::Backend::Provider::Mysql->_log_stats($c);
    my $to_remove = Thruk::Backend::Provider::Mysql->_log_removeunused($c, 1);

    for my $s (@stats) {
        next unless $s->{'enabled'};
        if(($s->{'cache_version'}||0) != $Thruk::Backend::Provider::Mysql::cache_version) {
            $details .= sprintf("  - [logcache %s] wrong cache version: %s (expected %s, hint: recreate cache)\n", $s->{'name'}, ($s->{'cache_version'}//0), $Thruk::Backend::Provider::Mysql::cache_version);
            $errors++;
        }
        if($s->{'last_update'} && $s->{'last_update'} < time() - 1800) {
            $details .= sprintf("  - [logcache %s] last update too old: %s (hint: check logcache update cronjob)\n", $s->{'name'}, scalar localtime $s->{'last_update'});
            $errors++;
        }
        if($s->{'last_reorder'} eq '') {
            $details .= sprintf('  - [logcache %s] tables have never been optimized (hint: run `thruk logcache optimize` once a week)'."\n", $s->{'name'});
            $errors++;
        }
        elsif($s->{'last_reorder'} < time() - (31*86400)) {
            $details .= sprintf('  - [logcache %s] last optimize run too old: %s (hint: run `thruk logcache optimize` once a week)'."\n", $s->{'name'}, scalar localtime $s->{'last_reorder'});
            $errors++;
        }
    }

    if(scalar keys %{$to_remove} == 0) {
        $details .= sprintf("  - no old tables found in logcache\n");
    } else {
        for my $key (sort keys %{$to_remove}) {
            $details .= sprintf('  - old logcache table %s could be removed. (hint: run `thruk logcache removeunused`)'."\n", $key);
            $errors++;
        }
    }

    if($errors == 0) {
        $details .= "  - no errors in ".(scalar @stats)." logcaches\n";
    } else {
        $rc = 2;
    }

    my $msg = sprintf('Logcache %s', $rc_codes->{$rc});
    return({sub => 'logcache', rc => $rc, msg => $msg, details => $details});
}

##############################################

=head2 _backends_checks

    _backends_checks($c)

verify errors in backend connections

=cut
sub _backends_checks  {
    my($c) = @_;
    my $details = "Backends:\n";

    my $rc      = 0;
    my $errors  = 0;

    for my $pd (sort keys %{$c->stash->{'backend_detail'}}) {
        next if $c->stash->{'backend_detail'}->{$pd}->{'disabled'} == 2; # hide hidden backends
        my $err = ($c->stash->{'failed_backends'}->{$pd} || $c->stash->{'backend_detail'}->{$pd}->{'last_error'} || '');
        next unless $err;
        $details .= sprintf("  - %s: %s (%s)\n",
                                ($c->stash->{'backend_detail'}->{$pd}->{'name'} // $pd),
                                $err,
                                ($c->stash->{'backend_detail'}->{$pd}->{'addr'} || ''),
        );
        $errors++;
    }

    if($errors == 0) {
        $details .= "  - no errors in ".(scalar keys %{$c->stash->{'backend_detail'}})." backends\n";
    } else {
        $rc = 2;
    }

    my $msg = sprintf('Backends %s', $rc_codes->{$rc});
    return({sub => 'backends', rc => $rc, msg => $msg, details => $details});
}

##############################################

1;
