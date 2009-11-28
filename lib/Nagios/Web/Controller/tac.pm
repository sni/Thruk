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

Stats: state = 0 as up
Stats: state = 1 as down
Stats: state = 2 as unreachable
Stats: state = 3 as unknown
Stats: state = 4 as pending

Stats: state = 0
Stats: active_checks_enabled = 0
StatsAnd: 2 as up_and_disabled

Stats: state = 1
Stats: acknowledged = 1
StatsAnd: 2 as down_and_ack

Stats: state = 1
Stats: scheduled_downtime_depth > 0
StatsAnd: 2 as down_and_scheduled

Stats: state = 1
Stats: active_checks_enabled = 0
StatsAnd: 2 as down_and_disabled

Stats: state = 1
Stats: active_checks_enabled = 1
Stats: acknowledged = 0
Stats: scheduled_downtime_depth = 0
StatsAnd: 4 as down_and_unhandled
",
    { Slice => {}});
    my $service_stats = $c->{'live'}->selectrow_hashref("GET services
Stats: description !=  as total
Stats: check_type = 0 as total_active
Stats: check_type = 1 as total_passive

Stats: state = 0 as ok
Stats: state = 1 as warning
Stats: state = 2 as critical
Stats: state = 3 as unknown
Stats: state = 4 as pending

Stats: host_state != 0
Stats: state = 1
StatsAnd: 2 as warning_on_down_host

Stats: host_state != 0
Stats: state = 2
StatsAnd: 2 as critical_on_down_host

Stats: host_state != 0
Stats: state = 3 as unknown_on_down_host
StatsAnd: 2",
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
