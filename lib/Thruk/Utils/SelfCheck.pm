package Thruk::Utils::SelfCheck;

=head1 NAME

Thruk::Utils::SelfCheck - Utilities Collection for Checking Thruks Integrity

=head1 DESCRIPTION

Utilities Collection for Checking Thruks Integrity

=cut

use warnings;
use strict;
use Thruk::Utils::RecurringDowntimes;

my $rc_codes = {
    '0'     => 'OK',
    '1'     => 'WARNING',
    '2'     => 'CRITICAL',
    '3'     => 'UNKNOWN',
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

    # run checks
    if($type eq 'all' or $type eq 'filesystem') {
        push @{$results}, _filesystem_checks($c);
    }
    if($type eq 'all' or $type eq 'logfiles') {
        push @{$results}, _logfile_checks($c);
    }
    if($type eq 'all' or $type eq 'reports') {
        push @{$results}, _report_checks($c);
    }
    if($type eq 'all' or $type eq 'recurring_downtimes') {
        push @{$results}, _reccuring_downtime_checks($c);
    }
    if($type eq 'all' or $type eq 'lmd') {
        push @{$results}, _lmd_checks($c);
    }

    # aggregate results
    if(scalar @{$results} == 0) {
        $rc  = 3;
        $msg = "UNKNOWN - unknown subcheck type";
    } else {
        # sort by rc
        @{$results} = sort { $b->{rc} <=> $a->{rc} || $a->{sub} cmp $b->{sub} } @{$results};
        $rc = $results->[0]->{rc};
        $details = "";
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
    return($rc, $msg, ($details || ''));
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
                 $c->config->{'log4perl_conf_in_use'},
                ) {
        next unless $log;    # may not be set
        next unless -e $log; # may not exist either
        # count errors
        my @out = `grep 'ERROR' $log`;
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

    #my($backends, $cmd_typ)...
    my($backends, undef) = Thruk::Utils::RecurringDowntimes::get_downtime_backends($c, $downtime);

    my $errors  = 0;
    my $details = "";
    if($downtime->{'target'} eq 'host') {
        for my $hst (@{$downtime->{'host'}}) {
            my $data = $c->{'db'}->get_hosts(filter => [{ 'name' => $hst } ], columns => [qw/name/], backend => $backends );
            if(!$data || scalar @{$data} == 0) {
                $details .= "  - ERROR: ".$downtime->{'target'}." ".$hst." not found in recurring downtime ".$file."\n";
                $errors++;
            }
        }
    }
    elsif($downtime->{'target'} eq 'service') {
        for my $hst (@{$downtime->{'host'}}) {
            for my $svc (@{$downtime->{'service'}}) {
                my $data = $c->{'db'}->get_services(filter => [{ 'host_name' => $hst, description => $svc } ], columns => [qw/host_name/], backend => $backends );
                if(!$data || scalar @{$data} == 0) {
                    $details .= "  - ERROR: ".$downtime->{'target'}." ".$hst." - ".$svc." not found in recurring downtime ".$file."\n";
                    $errors++;
                }
            }
        }
    }
    elsif($downtime->{'target'} eq 'hostgroup') {
        for my $grp (@{$downtime->{$downtime->{'target'}}}) {
            my $data = $c->{'db'}->get_hostgroups(filter => [{ 'name' => $grp }], columns => [qw/name/], backend => $backends );
            if(!$data || scalar @{$data} == 0) {
                $details .= "  - ERROR: ".$downtime->{'target'}." ".$grp." not found in recurring downtime ".$file."\n";
                $errors++;
            }
        }
    }
    elsif($downtime->{'target'} eq 'servicegroup') {
        for my $grp (@{$downtime->{$downtime->{'target'}}}) {
            my $data = $c->{'db'}->get_servicegroups(filter => [{ 'name' => $grp }], columns => [qw/name/], backend => $backends );
            if(!$data || scalar @{$data} == 0) {
                $details .= "  - ERROR: ".$downtime->{'target'}." ".$grp." not found in recurring downtime ".$file."\n";
                $errors++;
            }
        }
    }
    return($errors, $details);
}

##############################################

=head2 _lmd_checks

    _lmd_checks($c)

verify errors in lmd

=cut
sub _lmd_checks  {
    my($c) = @_;
    return unless $c->config->{'use_lmd_core'};

    my $details = "LMD:\n";
    if($c->config->{'lmd_core_bin'} && $c->config->{'lmd_core_bin'} ne 'lmd') {
        if(! -x $c->config->{'lmd_core_bin'}) {
            chomp(my $err = $!);
            $details .= sprintf("  - lmd binary %s not executable: %s\n", $c->config->{'lmd_core_bin'}, $err);
            return({sub => 'lmd', rc => 2, msg => "LMD CRITICAL", details => $details });
        }
    }

    # try to run
    my $cmd = ($c->config->{'lmd_core_bin'} || 'lmd').' --help 2>&1';
    my($rc, $output) = Thruk::Utils::IO::cmd($c, $cmd);
    if($rc != 2 || $output !~ m/\QUsage of\E/mx) {
        $details .= sprintf("  - cannot execute lmd: %s\n", $output);
        return({sub => 'lmd', rc => 2, msg => "LMD WARNING", details => $details });
    }

    my($status, undef) = Thruk::Utils::LMD::status($c->config);
    my $pid = $status->[0]->{'pid'};
    if(!$pid) {
        $details .= "  - lmd not running\n";
        return({sub => 'lmd', rc => 1, msg => "LMD WARNING", details => $details });
    }

    my $start_time = $status->[0]->{'start_time'};
    $details .= sprintf("  - lmd running with pid %s since %s\n", $pid, Thruk::Utils::Filter::date_format($c, $start_time));

    my $total = scalar @{$c->{'db'}->peer_key()};
    my $stats = $c->{'db'}->lmd_stats($c);
    my $online = 0;
    for my $stat (@{$stats}) {
        $online++ if $stat->{'status'} == 0;
    }
    $details .= sprintf("  - %i/%i backends online\n", $online, $total);
    for my $peer ( @{ $c->{'db'}->get_peers() } ) {
        my $key  = $peer->{'key'};
        my $name = $peer->{'name'};
        next unless $c->stash->{'failed_backends'}->{$key};
        $details .= sprintf("    - %s: %s\n", $name, $c->stash->{'failed_backends'}->{$key});
    }

    return({sub => 'lmd', rc => 0, msg => "LMD OK", details => $details });
}

##############################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
