package Thruk::Utils::CLI::Downtimetask;

=head1 NAME

Thruk::Utils::CLI::Downtimetask - Downtimetask CLI module

=head1 DESCRIPTION

The downtimetask command executes recurring downtimes tasks.

=head1 SYNOPSIS

  Usage: thruk [globaloptions] downtimetask <nr>

=head1 OPTIONS

=over 4

=item B<help>

    print help and exit

=back

=cut

use warnings;
use strict;

##############################################

=head1 METHODS

=head2 cmd

    cmd([ $options ])

=cut
sub cmd {
    my($c, $action, $commandoptions) = @_;

    $c->stats->profile(begin => "_cmd_downtimetask($action)");
    require URI::Escape;
    require Thruk::Utils::RecurringDowntimes;

    # this function must be run on one cluster node only
    return("command send to cluster\n", 0) if $c->cluster->run_cluster("once", "cmd: $action ".join(" ",@{$commandoptions}));

    my $files = [split(/\|/mx, shift @{$commandoptions})];

    my $total_retries = 5;
    my $retries;

    # do auth stuff
    for($retries = 0; $retries < $total_retries; $retries++) {
        sleep(10) if $retries > 0;
        eval {
            Thruk::Utils::set_user($c, '(cron)') unless $c->user_exists;
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

    $file          = $c->config->{'var_path'}.'/downtimes/'.$file.'.tsk';
    my $downtime   = Thruk::Utils::read_data_file($file);
    my $default_rd = Thruk::Utils::RecurringDowntimes::get_default_recurring_downtime($c);
    for my $key (keys %{$default_rd}) {
        $downtime->{$key} = $default_rd->{$key} unless defined $downtime->{$key};
    }

    my $output     = '';
    if(!$downtime->{'target'}) {
        $downtime->{'target'} = 'host';
        $downtime->{'target'} = 'service' if $downtime->{'service'};
    }

    $downtime->{'host'}         = [$downtime->{'host'}]         unless ref $downtime->{'host'}         eq 'ARRAY';
    $downtime->{'hostgroup'}    = [$downtime->{'hostgroup'}]    unless ref $downtime->{'hostgroup'}    eq 'ARRAY';
    $downtime->{'service'}      = [$downtime->{'service'}]      unless ref $downtime->{'service'}      eq 'ARRAY';
    $downtime->{'servicegroup'} = [$downtime->{'servicegroup'}] unless ref $downtime->{'servicegroup'} eq 'ARRAY';

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
        sleep(10) if $retries > 0;
        if($downtime->{'target'} eq 'host') {
            my $hosts = $downtime->{'host'};
            for my $hst (@{$hosts}) {
                next if $done->{'hosts'}->{$hst};
                $downtime->{'host'} = $hst;
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

    return("recurring downtime ".$file." failed after $retries retries, find details in the thruk.log file.\n", 1) if $errors; # error is already printed

    if($downtime->{'service'}) {
        $output = 'scheduled'.$flexible.' downtime for service \''.join(', ', @{$downtime->{'service'}}).'\' on host: \''.join(', ', @{$downtime->{'host'}}).'\'';
    } else {
        $output = 'scheduled'.$flexible.' downtime for '.$downtime->{'target'}.': \''.join(', ', @{$downtime->{$downtime->{'target'}}}).'\'';
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

    # convert to normal url request
    my $product = $c->config->{'product_prefix'} || 'thruk';
    my $url = sprintf('/'.$product.'/cgi-bin/cmd.cgi?cmd_mod=2&cmd_typ=%d&com_data=%s&com_author=%s&trigger=0&start_time=%s&end_time=%s&fixed=%s&hours=%s&minutes=%s&backend=%s%s%s%s%s%s',
                      $cmd_typ,
                      URI::Escape::uri_escape_utf8($downtime->{'comment'}),
                      URI::Escape::uri_escape_utf8(defined $downtime->{'author'} ? $downtime->{'author'} : '(cron)'),
                      URI::Escape::uri_escape_utf8(Thruk::Utils::format_date($start, '%Y-%m-%d %H:%M:%S')),
                      URI::Escape::uri_escape_utf8(Thruk::Utils::format_date($end, '%Y-%m-%d %H:%M:%S')),
                      $downtime->{'fixed'},
                      $hours,
                      $minutes,
                      join(',', @{$backends}),
                      defined $downtime->{'childoptions'} ? '&childoptions='.$downtime->{'childoptions'} : '',
                      $downtime->{'host'} ? '&host='.URI::Escape::uri_escape_utf8($downtime->{'host'}) : '',
                      $downtime->{'service'} ? '&service='.URI::Escape::uri_escape_utf8($downtime->{'service'}) : '',
                      (ref $downtime->{'hostgroup'} ne 'ARRAY' and $downtime->{'hostgroup'}) ? '&hostgroup='.URI::Escape::uri_escape_utf8($downtime->{'hostgroup'}) : '',
                      (ref $downtime->{'servicegroup'} ne 'ARRAY' and $downtime->{'servicegroup'}) ? '&servicegroup='.URI::Escape::uri_escape_utf8($downtime->{'servicegroup'}) : '',
                     );
    local $ENV{'THRUK_SRC'} = 'CLI';
    my $old = $c->config->{'cgi_cfg'}->{'lock_author_names'};
    $c->config->{'cgi_cfg'}->{'lock_author_names'} = 0;
    my @res = Thruk::Utils::CLI::request_url($c, $url);
    $c->config->{'cgi_cfg'}->{'lock_author_names'} = $old;
    return 0 if $res[0] != 200; # error is already printed
    return 1;
}

##############################################

=head1 EXAMPLES

Runs the downtime task for file '1'

  %> thruk command downtimetask 1

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

##############################################

1;
