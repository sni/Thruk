package Thruk::Controller::core_scheduling;

use strict;
use warnings;
use Module::Load qw/load/;

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

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_CACHED_DEFAULTS);

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
    my( $hostfilter, $servicefilter, $groupfilter ) = Thruk::Utils::Status::do_filter($c);
    return if $c->stash->{'has_error'};

    reschedule_everything($c, $hostfilter, $servicefilter) if $c->req->parameters->{'reschedule'};

    my $now           = time();
    my $group_seconds = $c->req->parameters->{'group_seconds'} || 1;
    my $look_back     = defined $c->req->parameters->{'look_back'} ? $c->req->parameters->{'look_back'} : 60;
    my $look_ahead    = $c->req->parameters->{'look_ahead'}    || 300;

    my $grouped = {};
    $grouped->{($now-$look_back )*1000} = { hosts => 0, services => 0, hosts_running => 0, services_running => 0 };
    $grouped->{($now+$look_ahead)*1000} = { hosts => 0, services => 0, hosts_running => 0, services_running => 0 };

    my $data = $c->{'db'}->get_scheduling_queue($c, hostfilter => $hostfilter, servicefilter => $servicefilter);
    for my $d (@{$data}) {
        my $time = $d->{'next_check'};
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
    }

    my $queue = [
        { label => "",               color => "#E0AF1B", data => [], bars => { show => 1, barWidth => $group_seconds*1000 }, stack => 1 },
        { label => "host checks",    color => "#EDC240", data => [], bars => { show => 1, barWidth => $group_seconds*1000 }, stack => 1 },
        { label => "",               color => "#59B2F8", data => [], bars => { show => 1, barWidth => $group_seconds*1000 }, stack => 1 },
        { label => "service checks", color => "#AFD8F8", data => [], bars => { show => 1, barWidth => $group_seconds*1000 }, stack => 1 },
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

    my $perf_stats = $c->{'db'}->get_extra_perf_stats(  filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'status' ) ] );
    if($c->req->parameters->{'json'}) {
        my $json = {
            queue    => $queue,
            markings => $markings,
            rate     => sprintf("%.2f", $perf_stats->{'host_checks_rate'} + $perf_stats->{'service_checks_rate'}),
        };
        $json->{'message'} = $c->stash->{message} if $c->stash->{message};
        return $c->render(json => $json);
    }

    $c->stash->{'markings'}         = $markings;
    $c->stash->{'scheduling_queue'} = $queue;

    # sort checks by interval
    my $intervals = {};
    my $total     = 0;
    for my $d (@{$data}) {
        $intervals->{$d->{'check_interval'}}++;
        $total += 1/$d->{'check_interval'};
    }
    $c->stash->{intervals}  = $intervals;
    $c->stash->{average}    = $total / 60;
    $c->stash->{perf_stats} = $perf_stats;

    $c->stash->{group_seconds}  = $group_seconds;
    $c->stash->{look_back}      = $look_back;
    $c->stash->{look_ahead}     = $look_ahead;

    $c->stash->{style}    = 'core_scheduling';
    $c->stash->{substyle} = 'service';
    $c->stash->{title}    = 'Core Scheduling Overview';
    $c->stash->{template} = 'core_scheduling.tt';
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
    my($backends_list) = $c->{'db'}->select_backends('send_command');
    for my $backend (@{$backends_list}) {
        my $cmds = _reschedule_backend($c, $backend, $hostfilter, $servicefilter);
        $commands2send->{$backend} = $cmds;
    }
    $c->{'db'}->enable_backends($backends_list, 1);

    Thruk::Controller::cmd::bulk_send($c, $commands2send);


    $c->stash->{message} = $c->stash->{scheduled}.' hosts and services rescheduled successfully';

    return;
}
##########################################################
sub _reschedule_backend {
    my($c, $backend, $hostfilter, $servicefilter) = @_;
    my $cmds = [];

    $c->{'db'}->enable_backends([$backend], 1);
    my $data = $c->{'db'}->get_scheduling_queue($c, hostfilter => $hostfilter, servicefilter => $servicefilter);
    my $intervals = {};
    for my $d (@{$data}) {
        push @{$intervals->{$d->{'check_interval'}}}, $d;
    }
    for my $interval (keys %{$intervals}) {
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
        for my $ts (@{$slots}) {
            if(defined $sorted_by_ts->{$ts}) {
                my $next = shift @{$sorted_by_ts->{$ts}};
                delete $sorted_by_ts->{$ts} if scalar @{$sorted_by_ts->{$ts}} == 0;
            } else {
                push @{$slots_to_fill}, $ts;
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

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
