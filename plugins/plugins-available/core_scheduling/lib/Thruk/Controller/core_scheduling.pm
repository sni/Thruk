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

    $c->stash->{'no_auto_reload'}      = 1;
    $c->stash->{title}                 = 'Core Scheduling Graph';
    $c->stash->{page}                  = 'status'; # otherwise we would have to create a core_scheduling.css for every theme

    Thruk::Utils::ssi_include($c);

    return core_scheduling_page($c);
}


##########################################################

=head2 core_scheduling_page

=cut
sub core_scheduling_page {
    my($c) = @_;

    my $now           = time();
    my $data          = $c->{'db'}->get_scheduling_queue($c);
    my $group_seconds = $c->req->parameters->{'group_seconds'} || 10;
    my $look_back     = $c->req->parameters->{'look_back'}     || 60;
    my $look_ahead    = $c->req->parameters->{'look_ahead'}    || 300;

    my $queue = [
        { label => "",               color => "#E0AF1B", data => [], bars => { show => 1, barWidth => $group_seconds*1000 }, stack => 1 },
        { label => "host checks",    color => "#EDC240", data => [], bars => { show => 1, barWidth => $group_seconds*1000 }, stack => 1 },
        { label => "",               color => "#59B2F8", data => [], bars => { show => 1, barWidth => $group_seconds*1000 }, stack => 1 },
        { label => "service checks", color => "#AFD8F8", data => [], bars => { show => 1, barWidth => $group_seconds*1000 }, stack => 1 },
    ];
    my $markings = [
        { color => '#990000', lineWidth => 1, xaxis => { from => $now*1000, to => $now*1000 } },
    ];

    my $grouped = {};
    $grouped->{($now-$look_back )*1000} = { hosts => 0, services => 0, hosts_running => 0, services_running => 0 };
    $grouped->{($now+$look_ahead)*1000} = { hosts => 0, services => 0, hosts_running => 0, services_running => 0 };

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
    for my $time (sort keys %{$grouped}) {
        push @{$queue->[0]->{'data'}}, [$time, $grouped->{$time}->{hosts_running}];
        push @{$queue->[1]->{'data'}}, [$time, $grouped->{$time}->{hosts}];
        push @{$queue->[2]->{'data'}}, [$time, $grouped->{$time}->{services_running}];
        push @{$queue->[3]->{'data'}}, [$time, $grouped->{$time}->{services}];
    }

    my $perf_stats = $c->{'db'}->get_extra_perf_stats(  filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'status' ) ] );
    if($c->req->parameters->{'json'}) {
        return $c->render(json => { queue => $queue, markings => $markings, rate => sprintf("%.2f", $perf_stats->{'host_checks_rate'} + $perf_stats->{'service_checks_rate'}) });
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

    $c->stash->{title}    = 'Core Scheduling Overview';
    $c->stash->{template} = 'core_scheduling.tt';
    return;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
