package Thruk::Utils::CLI::Downtimetask;

=head1 NAME

Thruk::Utils::CLI::Downtimetask - Downtimetask CLI module

=head1 DESCRIPTION

The downtimetask command executes recurring downtimes tasks.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] downtimetask [options] <nr>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=item B<autoremove>

    cleanup none-existing hosts/services/groups and backends from recurring downtimes.

=item B<-t / --test>

    do not send commands but display what would be send

=back

=cut

use warnings;
use strict;
use Cpanel::JSON::XS ();
use Getopt::Long ();

use Thruk::Action::AddDefaults ();
use Thruk::Utils::CLI ();
use Thruk::Utils::Log qw/:all/;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions) = @_;

    if(!$c->check_user_roles('authorized_for_admin')) {
        return("ERROR - authorized_for_admin role required", 1);
    }

    if(!$commandoptions || scalar @{$commandoptions} == 0) {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    }

    # parse options
    my $opt = {};
    Getopt::Long::Configure('no_ignore_case');
    Getopt::Long::Configure('bundling');
    Getopt::Long::Configure('pass_through');
    Getopt::Long::GetOptionsFromArray($commandoptions,
       "t|test"         => \$opt->{'testmode'},
       "autoremove"     => \$opt->{'removemode'},
    ) or do {
        return(Thruk::Utils::CLI::get_submodule_help(__PACKAGE__));
    };

    if($opt->{'removemode'} || ($commandoptions->[0] && $commandoptions->[0] eq 'autoremove')) {
        return(_auto_fix_downtimes($c));
    }

    local $ENV{'THRUK_NO_COMMANDS'} = "" if $opt->{'testmode'};

    $c->stats->profile(begin => "_cmd_downtimetask($action)");
    require URI::Escape;
    require Thruk::Utils::RecurringDowntimes;

    # this function must be run on one cluster node only
    if(my $msg = $c->cluster->run_cluster("once", "cmd: $action ".join(" ",@{$commandoptions}))) {
        return($msg, 0);
    }

    my $files = [split(/\|/mx, shift @{$commandoptions})];

    my $total_retries = 12;
    my $retries;

    for($retries = 0; $retries < $total_retries; $retries++) {
        sleep(10) if $retries > 0;
        eval {
            Thruk::Action::AddDefaults::set_processinfo($c);
        };
        last unless $@;
    }

    my($output, $overall_rc) = ("", 0);
    for my $file (@{$files}) {
        my($out, $rc) = _handle_file($c, $file);
        $output .= $out;
        $overall_rc = $rc if $rc > $overall_rc;
    }

    $c->stats->profile(end => "_cmd_downtimetask($action)");
    return($output, $overall_rc);
}

##############################################
# handle downtimetask for a given file
sub _handle_file {
    my($c, $file) = @_;

    my $retries;
    my $total_retries = 5;
    my $retry_delay   = 10;

    my $nr = $file;
    $file  = $c->config->{'var_path'}.'/downtimes/'.$file.'.tsk';
    if(!-s $file) {
        _error("cannot read %s: %s", $file, $!);
        return("", 1);
    }
    my $downtime = Thruk::Utils::RecurringDowntimes::read_downtime($c, $file, undef, undef, undef, undef, undef, undef, undef, 0);
    if(!$downtime) {
        _error("cannot read %s", $file);
        return("", 1);
    }

    # do quick self check
    Thruk::Utils::RecurringDowntimes::check_downtime($c, $downtime, $file);

    my $start    = time();
    my $end      = $start + ($downtime->{'duration'}*60);
    my $hours    = 0;
    my $minutes  = 0;
    my $flexible = '';
    if($downtime->{'fixed'} == 0) {
        $flexible = ' flexible';
        $end      = $start + $downtime->{'flex_range'}*60;
        $hours    = int($downtime->{'duration'} / 60);
        $minutes  = $downtime->{'duration'}%60;
    }

    my $done = {hosts => {}, groups => {}};
    my($backends, $cmd_typ) = Thruk::Utils::RecurringDowntimes::get_downtime_backends($c, $downtime);
    my $errors = 0;
    for($retries = 0; $retries < $total_retries; $retries++) {
        sleep($retry_delay * $retries) if $retries > 0;
        if($downtime->{'target'} eq 'host') {
            my $hosts = $downtime->{'host'};
            for my $hst (@{$hosts}) {
                next if $done->{'hosts'}->{$hst};
                $downtime->{'host'} = $hst;
                $downtime->{'service'} = undef;
                my $rc;
                eval {
                    $rc = set_downtime($c, $downtime, $cmd_typ, $backends, $start, $end, $hours, $minutes);
                };
                if($rc && !$@) {
                    $errors-- if defined $done->{'hosts'}->{$hst};
                    $done->{'hosts'}->{$hst} = 1;
                } else {
                    _debug($@);
                    $errors++ unless defined $done->{'hosts'}->{$hst};
                    $done->{'hosts'}->{$hst} = 0;
                }
            }
            $downtime->{'host'} = $hosts;
        }
        elsif($downtime->{'target'} eq 'service') {
            my $hosts    = $downtime->{'host'};
            my $services = $downtime->{'service'};
            for my $hst (@{$hosts}) {
                for my $svc (@{$services}) {
                    next if $done->{'services'}->{$hst}->{$svc};
                    $downtime->{'host'}    = $hst;
                    $downtime->{'service'} = $svc;
                    my $rc;
                    eval {
                        $rc = set_downtime($c, $downtime, $cmd_typ, $backends, $start, $end, $hours, $minutes);
                    };
                    if($rc && !$@) {
                        $errors-- if defined $done->{'services'}->{$hst}->{$svc};
                        $done->{'services'}->{$hst}->{$svc} = 1;
                    } else {
                        _debug($@);
                        $errors++ unless defined $done->{'services'}->{$hst}->{$svc};
                        $done->{'services'}->{$hst}->{$svc} = 0;
                    }
                }
            }
            $downtime->{'service'} = $services;
            $downtime->{'host'}    = $hosts;
        }
        elsif($downtime->{'target'} eq 'hostgroup' or $downtime->{'target'} eq 'servicegroup') {
            my $grps = $downtime->{$downtime->{'target'}};
            for my $grp (@{$grps}) {
                next if $done->{'groups'}->{$grp};
                $downtime->{'host'}    = undef;
                $downtime->{'service'} = undef;
                $downtime->{$downtime->{'target'}} = $grp;
                my $rc;
                eval {
                    $rc = set_downtime($c, $downtime, $cmd_typ, $backends, $start, $end, $hours, $minutes);
                };
                if($rc && !$@) {
                    $errors-- if defined $done->{'groups'}->{$grp};
                    $done->{'groups'}->{$grp} = 1;
                } else {
                    _debug($@);
                    $errors++ unless defined $done->{'groups'}->{$grp};
                    $done->{'groups'}->{$grp} = 0;
                }
            }
            $downtime->{$downtime->{'target'}} = $grps;
        }
        last unless $errors;
    }

    return("recurring downtime ".$file." failed after $retries retries.\n", 1) if $errors; # error is already printed

    my $output = '';
    $output = '['.$nr.'.tsk]';
    if($downtime->{'service'} && scalar @{$downtime->{'service'}} > 0) {
        $output .= ' scheduled'.$flexible.' downtime for service \''.join(', ', @{$downtime->{'service'}}).'\' on host: \''.join(', ', @{$downtime->{'host'}}).'\'';
    } else {
        $output .= ' scheduled'.$flexible.' downtime for '.$downtime->{'target'}.': \''.join(', ', @{$downtime->{$downtime->{'target'}}}).'\'';
    }
    $output .= " (duration ".Thruk::Utils::Filter::duration($downtime->{'duration'}*60).")";
    $output .= " (after $retries retries)\n" if $retries;
    $output .= "\n";

    return($output, 0);
}

##############################################

=head2 set_downtime

    set_downtime($c, $downtime, $cmd_typ, $backends, $start, $end, $hours, $minutes)

set downtime.

    downtime is a hash like this:
    {
        author  => 'downtime author'
        host    => 'host name'
        service => 'optional service name'
        comment => 'downtime comment'
        fixed   => 1
    }

    cmd_typ is:
         55 -> hosts
         56 -> services
         84 -> hostgroups
        122 -> servicegroups

=cut
sub set_downtime {
    my($c, $downtime, $cmd_typ, $backends, $start, $end, $hours, $minutes) = @_;

    my $product = $c->config->{'product_prefix'} || 'thruk';
    local $c->config->{'lock_author_names'} = 0;
    my @res = Thruk::Utils::CLI::request_url($c, '/'.$product.'/cgi-bin/cmd.cgi', undef, 'POST', {
        cmd_mod         => 2,
        cmd_typ         => $cmd_typ,
        com_data        => $downtime->{'comment'},
        com_author      => defined $downtime->{'author'} ? $downtime->{'author'} : '(cron)',
        trigger         => 0,
        start_time      => $start,
        end_time        => $end,
        fixed           => $downtime->{'fixed'},
        hours           => $hours,
        minutes         => $minutes,
        backend         => join(',', @{$backends}),
        childoptions    => $downtime->{'childoptions'},
        host            => $downtime->{'host'},
        service         => $downtime->{'service'},
        hostgroup       => $downtime->{'hostgroup'},
        servicegroup    => $downtime->{'servicegroup'},
        json            => 1,
    });

    if(scalar @res >= 2 && ref $res[1] eq 'HASH' && defined $res[1]->{'result'}) {
        my $data;
        my $jsonreader = Cpanel::JSON::XS->new->utf8;
        $jsonreader->relaxed();
        eval {
            $data = $jsonreader->decode($res[1]->{'result'});
        };
        if($@) {
            die("failed to parse json: ".$@);
        }
        return 1 if $data->{'success'};
        _warn($data->{'error'});
        return 0;
    }
    return 1 if $res[0] == 200;
    # error is already printed?
    return 0;
}

##############################################
# fix all downtimes
sub _auto_fix_downtimes {
    my($c) = @_;

    $c->stats->profile(begin => "_auto_fix_downtimes");

    require Thruk::Utils::RecurringDowntimes;

    my $fixed = 0;
    my @files = glob($c->config->{'var_path'}.'/downtimes/*.tsk');
    for my $dfile (@files) {
        next unless -f $dfile;
        my $d = Thruk::Utils::RecurringDowntimes::read_downtime($c, $dfile);
        next unless $d;
        next unless $d->{'fixable'};
        Thruk::Utils::RecurringDowntimes::fix_downtime($c, $dfile);
        $fixed++;
    }

    $c->stats->profile(end => "_auto_fix_downtimes");

    if($fixed) {
        return(sprintf("%d downtimes cleaned up.\n", $fixed), 0);
    }
    return("all downtimes already cleaned up.\n", 0);
}

##############################################

=head1 EXAMPLES

Runs the downtime task for file '1'

  %> thruk downtimetask 1

Same but in test mode:

  %> thruk downtimetask 1 --test

=cut

##############################################

1;
