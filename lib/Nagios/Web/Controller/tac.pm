package Nagios::Web::Controller::tac;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Nagios::Web::Controller::tac - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    my $host_stats    = $c->{'live'}->selectrow_hashref("GET hosts
Stats: name !=  as total
Stats: check_type = 0 as total_active
Stats: check_type = 1 as total_passive

Stats: has_been_checked = 1
Stats: state = 0
StatsAnd: 2 as up

Stats: has_been_checked = 1
Stats: state = 1
StatsAnd: 2 as down

Stats: has_been_checked = 1
Stats: state = 2
StatsAnd: 2 as unreachable

Stats: has_been_checked = 0 as pending

Stats: has_been_checked = 0
Stats: active_checks_enabled = 0
StatsAnd: 2 as pending_and_disabled

Stats: has_been_checked = 0
Stats: scheduled_downtime_depth > 0
StatsAnd: 2 as pending_and_scheduled

Stats: state = 0
Stats: has_been_checked = 1
Stats: active_checks_enabled = 0
StatsAnd: 3 as up_and_disabled

Stats: state = 0
Stats: has_been_checked = 1
Stats: scheduled_downtime_depth > 0
StatsAnd: 3 as up_and_scheduled

Stats: state = 1
Stats: has_been_checked = 1
Stats: acknowledged = 1
StatsAnd: 3 as down_and_ack

Stats: state = 1
Stats: scheduled_downtime_depth > 0
Stats: has_been_checked = 1
StatsAnd: 3 as down_and_scheduled

Stats: state = 1
Stats: active_checks_enabled = 0
Stats: has_been_checked = 1
StatsAnd: 3 as down_and_disabled

Stats: state = 1
Stats: active_checks_enabled = 1
Stats: acknowledged = 0
Stats: scheduled_downtime_depth = 0
Stats: has_been_checked = 1
StatsAnd: 5 as down_and_unhandled

Stats: state = 2
Stats: acknowledged = 1
Stats: has_been_checked = 1
StatsAnd: 3 as unreachable_and_ack

Stats: state = 2
Stats: scheduled_downtime_depth > 0
Stats: has_been_checked = 1
StatsAnd: 3 as unreachable_and_scheduled

Stats: state = 2
Stats: active_checks_enabled = 0
StatsAnd: 2 as unreachable_and_disabled

Stats: state = 2
Stats: active_checks_enabled = 1
Stats: acknowledged = 0
Stats: scheduled_downtime_depth = 0
Stats: has_been_checked = 1
StatsAnd: 5 as unreachable_and_unhandled

Stats: is_flapping = 1 as flapping

Stats: flap_detection_enabled = 0 as flapping_disabled

Stats: notifications_enabled = 0 as notifications_disabled

Stats: event_handler_enabled = 0 as eventhandler_disabled

Stats: active_checks_enabled = 0 as active_checks_disabled

Stats: accept_passive_checks = 0 as passive_checks_disabled
",
    { Slice => {}});
    my $service_stats = $c->{'live'}->selectrow_hashref("GET services
Stats: description !=  as total
Stats: check_type = 0 as total_active
Stats: check_type = 1 as total_passive

Stats: has_been_checked = 1
Stats: state = 0
StatsAnd: 2 as ok

Stats: has_been_checked = 1
Stats: state = 1
StatsAnd: 2 as warning

Stats: has_been_checked = 1
Stats: state = 2
StatsAnd: 2 as critical

Stats: has_been_checked = 1
Stats: state = 3
StatsAnd: 2 as unknown

Stats: has_been_checked = 0 as pending


Stats: has_been_checked = 0
Stats: active_checks_enabled = 0
StatsAnd: 2 as pending_and_disabled

Stats: has_been_checked = 0
Stats: scheduled_downtime_depth > 0
StatsAnd: 2 as pending_and_scheduled

Stats: state = 0
Stats: has_been_checked = 1
Stats: active_checks_enabled = 0
StatsAnd: 3 as ok_and_disabled

Stats: state = 0
Stats: has_been_checked = 1
Stats: scheduled_downtime_depth > 0
StatsAnd: 3 as ok_and_scheduled


Stats: state = 0
Stats: active_checks_enabled = 0
Stats: has_been_checked = 1
StatsAnd: 3 as ok_and_disabled

Stats: state = 1
Stats: host_state = 0
Stats: active_checks_enabled = 1
Stats: acknowledged = 0
Stats: scheduled_downtime_depth = 0
Stats: has_been_checked = 1
StatsAnd: 6 as warning_and_unhandled

Stats: acknowledged = 1
Stats: state = 1
Stats: has_been_checked = 1
StatsAnd: 3 as warning_and_ack

Stats: state = 1
Stats: active_checks_enabled = 0
Stats: has_been_checked = 1
StatsAnd: 3 as warning_and_disabled

Stats: host_state != 0
Stats: state = 1
Stats: has_been_checked = 1
StatsAnd: 3 as warning_on_down_host

Stats: state = 1
Stats: scheduled_downtime_depth > 0
Stats: has_been_checked = 1
StatsAnd: 3 as warning_and_scheduled


Stats: state = 2
Stats: host_state = 0
Stats: active_checks_enabled = 1
Stats: acknowledged = 0
Stats: scheduled_downtime_depth = 0
Stats: has_been_checked = 1
StatsAnd: 6 as critical_and_unhandled

Stats: state = 2
Stats: scheduled_downtime_depth > 0
Stats: has_been_checked = 1
StatsAnd: 3 as critical_and_scheduled

Stats: host_state != 0
Stats: state = 2
Stats: has_been_checked = 1
StatsAnd: 3 as critical_on_down_host

Stats: state = 2
Stats: active_checks_enabled = 0
Stats: has_been_checked = 1
StatsAnd: 3 as critical_and_disabled

Stats: acknowledged = 1
Stats: state = 2
Stats: has_been_checked = 1
StatsAnd: 3 as critical_and_ack

Stats: state = 3
Stats: host_state = 0
Stats: active_checks_enabled = 1
Stats: acknowledged = 0
Stats: scheduled_downtime_depth = 0
Stats: has_been_checked = 1
StatsAnd: 6 as unknown_and_unhandled

Stats: host_state != 0
Stats: state = 3
Stats: has_been_checked = 1
StatsAnd: 3 as unknown_on_down_host

Stats: acknowledged = 1
Stats: state = 3
Stats: has_been_checked = 1
StatsAnd: 3 as unknown_and_ack

Stats: state = 3
Stats: scheduled_downtime_depth > 0
Stats: has_been_checked = 1
StatsAnd: 3 as unknown_and_scheduled

Stats: state = 3
Stats: active_checks_enabled = 0
Stats: has_been_checked = 1
StatsAnd: 3 as unknown_and_disabled

Stats: is_flapping = 1 as flapping

Stats: flap_detection_enabled = 0 as flapping_disabled

Stats: notifications_enabled = 0 as notifications_disabled

Stats: event_handler_enabled = 0 as eventhandler_disabled

Stats: active_checks_enabled = 0 as active_checks_disabled

Stats: accept_passive_checks = 0 as passive_checks_disabled
",
    { Slice => {} } );
    $c->stash->{host_stats}     = $host_stats;
    $c->stash->{service_stats}  = $service_stats;
    $c->stash->{title}          = 'Nagios Tactical Monitoring Overview';
    $c->stash->{infoBoxTitle}   = 'Tactical Monitoring Overview';
    $c->stash->{page}           = 'tac';
    $c->stash->{template}       = 'tac.tt';
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
