package Thruk::Controller::core_scheduling;

use warnings;
use strict;
use Module::Load qw/load/;

use Thruk::Action::AddDefaults ();
use Thruk::Utils::Auth ();
use Thruk::Utils::Status ();

=head1 NAME

Thruk::Controller::core_scheduling - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

##########################################################

=head2 index

=cut
sub index {
    my ( $c ) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::Constants::ADD_CACHED_DEFAULTS);

    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{title}            = 'Core Scheduling Graph';
    $c->stash->{page}             = 'status'; # otherwise we would have to create a core_scheduling.css for every theme
    $c->stash->{has_jquery_ui}    = 1;

    Thruk::Utils::ssi_include($c);

    return core_scheduling_page($c);
}


##########################################################

=head2 core_scheduling_page

=cut
sub core_scheduling_page {
    my($c) = @_;

    # set some defaults
    Thruk::Utils::Status::set_default_stash($c);

    my $style = $c->req->parameters->{'style'} || 'core_scheduling';
    if($style ne 'core_scheduling') {
        return if Thruk::Utils::Status::redirect_view($c, $style);
    }

    # do the filtering
    my( $hostfilter, $servicefilter, $groupfilter ) = Thruk::Utils::Status::do_filter($c, undef, undef, 1);
    return if $c->stash->{'has_error'};

    reschedule_everything($c, $hostfilter, $servicefilter) if $c->req->parameters->{'reschedule'};

    my $now           = time();
    my $group_seconds = $c->req->parameters->{'group_seconds'} || 1;
    my $look_back     = defined $c->req->parameters->{'look_back'} ? $c->req->parameters->{'look_back'} : 60;
    my $look_ahead    = $c->req->parameters->{'look_ahead'}    || 300;

    my $grouped = {};
    $grouped->{($now-$look_back )*1000} = { hosts => 0, services => 0, hosts_running => 0, services_running => 0 };
    $grouped->{($now+$look_ahead)*1000} = { hosts => 0, services => 0, hosts_running => 0, services_running => 0 };

    my $count_all          = 0;
    my $count_in_check_per = 0;
    my $latency_sum        = 0;
    my $execution_time_sum = 0;
    my $intervals          = {};
    my $interval_sum       = 0;
    my $check_rate         = 0;
    my $concurrent_rate    = 0;
    my $interval_lengths   = {};

    my $data = $c->db->get_scheduling_queue($c, hostfilter => $hostfilter, servicefilter => $servicefilter);
    for my $d (@{$data}) {
        next unless $d->{'check_interval'};
        next unless $d->{'has_been_checked'};
        next unless $d->{'active_checks_enabled'};

        my $interval_length = $c->stash->{'pi_detail'}->{$d->{'peer_key'}}->{'interval_length'} // 60;
        my $check_interval  = $d->{'check_interval'} * $interval_length;
        my $check_interval_minutes = $check_interval/60;
        $interval_lengths->{$interval_length}->{$d->{'peer_key'}} = 1;

        $intervals->{$check_interval_minutes}++;
        $check_rate += 1/($check_interval_minutes);
        $interval_sum += $check_interval_minutes;
        $count_all++;

        $concurrent_rate += $d->{'execution_time'} / $check_interval;

        my $time = $d->{'next_check'};
        next unless $d->{'in_check_period'};
        next unless $time > $now - $look_back;
        next unless $time < $now + $look_ahead;
        $time = ($time - ($time % $group_seconds))*1000;
        if(!$grouped->{$time}) {
            $grouped->{$time} = { hosts => 0, services => 0, hosts_running => 0, services_running => 0 };
        }
        if($d->{'description'}) {
            if($d->{'is_executing'}) {
                $grouped->{$time}->{'services_running'}++;
            } else {
                $grouped->{$time}->{'services'}++;
            }
        } else {
            if($d->{'is_executing'}) {
                $grouped->{$time}->{'hosts_running'}++;
            } else {
                $grouped->{$time}->{'hosts'}++;
            }
        }
        $count_in_check_per++;
        $latency_sum        += $d->{'latency'};
        $execution_time_sum += $d->{'execution_time'};
    }

    my $queue = [
        { label => "hosts running",    color => "#D1A317", data => [], bars => { show => 1, barWidth => $group_seconds*1000 }, stack => 1 },
        { label => "hosts planned",    color => "#FCD666", data => [], bars => { show => 1, barWidth => $group_seconds*1000 }, stack => 1 },
        { label => "services running", color => "#33A7FF", data => [], bars => { show => 1, barWidth => $group_seconds*1000 }, stack => 1 },
        { label => "services planned", color => "#B6DDFC", data => [], bars => { show => 1, barWidth => $group_seconds*1000 }, stack => 1 },
        { label => "moving average",   color => "#990000", data => [], lines => { show => 1, lineWidth => 1 }, shadowSize => 0 },
    ];
    my $markings = [
        { color => '#990000', lineWidth => 1, xaxis => { from => $now*1000, to => $now*1000 } },
    ];

    for my $time (sort keys %{$grouped}) {
        push @{$queue->[0]->{'data'}}, [$time, $grouped->{$time}->{hosts_running}];
        push @{$queue->[1]->{'data'}}, [$time, $grouped->{$time}->{hosts}];
        push @{$queue->[2]->{'data'}}, [$time, $grouped->{$time}->{services_running}];
        push @{$queue->[3]->{'data'}}, [$time, $grouped->{$time}->{services}];
    }

    my $start = ($now - $look_back) * 1000;
    my $end   = ($now + $look_ahead) * 1000;
    my $time  = $start;
    my @keys = sort keys %{$grouped};
    my $smooth_nr = 9;
    while($time <= $end) {
        my $val = 0;
        for my $x ((-1*$smooth_nr)..($smooth_nr)) {
            my $t = $time + (($x * $group_seconds)*1000);
            $val += ($grouped->{$t}->{hosts_running}//0)
                 +  ($grouped->{$t}->{hosts}//0)
                 +  ($grouped->{$t}->{services_running}//0)
                 +  ($grouped->{$t}->{services}//0);
        }
        $val = $val / (($smooth_nr*2)+1);
        push @{$queue->[4]->{'data'}}, [$time, $val] if $time >= ($now*1000);
        $time += ($group_seconds * 1000);
    }


    my $latency_avg        = 0;
    my $execution_time_avg = 0;
    if($count_in_check_per > 0) {
        $latency_avg        = $latency_sum / $count_in_check_per;
        $execution_time_avg = $execution_time_sum / $count_in_check_per;
    }

    my $perf_stats = $c->db->get_extra_perf_stats(  filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'status' ) ] );
    if($c->req->parameters->{'json'}) {
        my $json = {
            queue              => $queue,
            markings           => $markings,
            rate               => sprintf("%.2f", $perf_stats->{'host_checks_rate'} + $perf_stats->{'service_checks_rate'}),
            latency_avg        => sprintf("%.2f", $latency_avg),
            execution_time_avg => sprintf("%.2f", $execution_time_avg),
        };
        $json->{'message'} = $c->stash->{message} if $c->stash->{message};
        return $c->render(json => $json);
    }

    $c->stash->{'markings'}           = $markings;
    $c->stash->{'scheduling_queue'}   = $queue;
    $c->stash->{'latency_avg'}        = $latency_avg;
    $c->stash->{'execution_time_avg'} = $execution_time_avg;
    $c->stash->{'count_in_check_per'} = $count_in_check_per;

    $c->stash->{'intervals'}          = $intervals;
    $c->stash->{'interval_lengths'}   = $interval_lengths;
    $c->stash->{'interval_avg'}       = $count_all > 0 ? $interval_sum / $count_all : 0;
    $c->stash->{'check_rate'}         = $check_rate / 60;
    $c->stash->{'concurrent_rate'}    = $concurrent_rate;
    $c->stash->{'count_all'}          = $count_all;
    $c->stash->{'perf_stats'}         = $perf_stats;

    $c->stash->{'group_seconds'}      = $group_seconds;
    $c->stash->{'look_back'}          = $look_back;
    $c->stash->{'look_ahead'}         = $look_ahead;

    $c->stash->{'style'}              = 'core_scheduling';
    $c->stash->{'substyle'}           = 'service';
    $c->stash->{'title'}              = 'Core Scheduling Overview';
    $c->stash->{'template'}           = 'core_scheduling.tt';
    return;
}

##########################################################

=head2 reschedule_everything

    reschedule_everything($c, [$hostfilter], [$servicefilter])

=cut
sub reschedule_everything {
    my($c, $hostfilter, $servicefilter) = @_;

    load Thruk::Controller::cmd;

    $c->stash->{scheduled} = 0;
    my $commands2send = {};
    my($backends_list) = $c->db->select_backends('send_command');
    for my $backend (@{$backends_list}) {
        my $cmds = _reschedule_backend($c, $backend, $hostfilter, $servicefilter);
        $commands2send->{$backend} = $cmds;
    }
    $c->db->enable_backends($backends_list, 1);

    Thruk::Controller::cmd::bulk_send($c, $commands2send);


    if($c->stash->{scheduled} == 0) {
        $c->stash->{message} = 'All hosts and services are perfectly rebalanced already.';
    } else {
        $c->stash->{message} = $c->stash->{scheduled}.' hosts and services rebalanced successfully';
    }

    return;
}
##########################################################
sub _reschedule_backend {
    my($c, $backend, $hostfilter, $servicefilter) = @_;
    my $cmds = [];

    $c->db->enable_backends([$backend], 1);
    my $data = $c->db->get_scheduling_queue($c, hostfilter => $hostfilter, servicefilter => $servicefilter);
    my $intervals = {};
    for my $d (@{$data}) {
        next unless $d->{'check_interval'};
        next unless $d->{'has_been_checked'};
        next unless $d->{'in_check_period'};
        next if $d->{'is_executing'};
        push @{$intervals->{$d->{'check_interval'}}}, $d;
    }
    for my $interval (keys %{$intervals}) {
        # rescheduling is only useful if there are at least 2 services/hosts
        next if scalar @{$intervals->{$interval}} <= 1;

        # generate time slots for our checks
        my $slots = Thruk::Controller::cmd::generate_spread_startdates($c, scalar @{$intervals->{$interval}}, time(), $interval*60);
        return unless $slots;

        # sort our hosts and services by next_check
        my $sorted_by_ts = {};
        for my $d (@{$intervals->{$interval}}) {
            push @{$sorted_by_ts->{$d->{'next_check'}}}, $d;
        }

        # remove some which are in the right place already
        my $slots_to_fill = [];
        for(my $x = 0; $x < scalar @{$slots}; $x++) {
            my $start = $slots->[$x];
            my $end   = $slots->[$x+1] || $start;
            my $found = 0;
            for my $ts ($start..$end) {
                if(defined $sorted_by_ts->{$ts}) {
                    shift @{$sorted_by_ts->{$ts}};
                    delete $sorted_by_ts->{$ts} if scalar @{$sorted_by_ts->{$ts}} == 0;
                    $found++;
                }
                last if $found;
            }

            if(!$found) {
                push @{$slots_to_fill}, $start;
            }
        }

        my $relocated = {};
        my @orig_ts = sort keys %{$sorted_by_ts};
        for my $ts (@{$slots_to_fill}) {
            my $old_ts = $orig_ts[0];
            my $next   = shift @{$sorted_by_ts->{$old_ts}};
            if(scalar @{$sorted_by_ts->{$old_ts}} == 0) {
                delete $sorted_by_ts->{$old_ts};
                shift @orig_ts;
            }
            push @{$relocated->{$ts}}, $next;
        }
        for my $ts (sort keys %{$relocated}) {
            for my $d (@{$relocated->{$ts}}) {
                my $cmd_line = 'COMMAND [' . time() . '] ';
                if($d->{'description'}) {
                    $cmd_line .= sprintf('SCHEDULE_FORCED_SVC_CHECK;%s;%s;%lu', $d->{'host_name'}, $d->{'description'}, $ts);
                } else {
                    $cmd_line .= sprintf('SCHEDULE_FORCED_HOST_CHECK;%s;%lu', $d->{'host_name'}, $ts);
                }
                $c->stash->{scheduled}++;
                push @{$cmds}, $cmd_line;
            }
        }
    }
    return($cmds);
}

##########################################################

1;
