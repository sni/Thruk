package Thruk::Controller::summary;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::summary - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

use constant {
    # standard report types
    SREPORT_RECENT_ALERTS               => 1,
    SREPORT_RECENT_HOST_ALERTS          => 2,
    SREPORT_RECENT_SERVICE_ALERTS       => 3,
    SREPORT_TOP_HOST_ALERTS             => 4,
    SREPORT_TOP_SERVICE_ALERTS          => 5,

    # custom report types
    REPORT_RECENT_ALERTS                => 1,
    REPORT_ALERT_TOTALS                 => 2,
    REPORT_TOP_ALERTS                   => 3,
    REPORT_HOSTGROUP_ALERT_TOTALS       => 4 ,
    REPORT_HOST_ALERT_TOTALS            => 5,
    REPORT_SERVICE_ALERT_TOTALS         => 6,
    REPORT_SERVICEGROUP_ALERT_TOTALS    => 7,

    # alert types
    AE_HOST_ALERT                       => 1,
    AE_SERVICE_ALERT                    => 2,

    # state types
    AE_HOST_DOWN                        => 1,
    AE_HOST_UNREACHABLE                 => 2,
    AE_HOST_UP                          => 4,
    AE_SERVICE_WARNING                  => 8,
    AE_SERVICE_UNKNOWN                  => 16,
    AE_SERVICE_CRITICAL                 => 32,
    AE_SERVICE_OK                       => 64,
};

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    # set defaults
    $c->stash->{title}            = 'Event Summary';
    $c->stash->{infoBoxTitle}     = 'Alert Summary Report';
    $c->stash->{page}             = 'summary';
    $c->stash->{'no_auto_reload'} = 1;

    if(exists $c->{'request'}->{'parameters'}->{'report'}
       and $self->_create_report($c)) {
        # report created
    }
    else {
        # Step 1 - select report type
        $self->_show_step_1($c);
    }

    return 1;
}


##########################################################
sub _show_step_1 {
    my ( $self, $c ) = @_;
    $c->stats->profile(begin => "_show_step_1()");

    my @hosts         = sort keys %{$c->{'live'}->selectall_hashref("GET hosts\nColumns: name\n".Thruk::Utils::get_auth_filter($c, 'hosts'), 'name')};
    my @hostgroups    = sort keys %{$c->{'live'}->selectall_hashref("GET hostgroups\nColumns: name\n".Thruk::Utils::get_auth_filter($c, 'hostgroups'), 'name')};
    my @servicegroups = sort keys %{$c->{'live'}->selectall_hashref("GET servicegroups\nColumns: name\n".Thruk::Utils::get_auth_filter($c, 'servicegroups'), 'name')};

    $c->stash->{hosts}         = \@hosts;
    $c->stash->{hostgroups}    = \@hostgroups;
    $c->stash->{servicegroups} = \@servicegroups;
    $c->stash->{template}      = 'summary_step_1.tt';

    $c->stats->profile(end => "_show_step_1()");
    return 1;
}

##########################################################
sub _create_report {
    my ( $self, $c ) = @_;
    $c->stats->profile(begin => "_create_report()");

    my($timeperiod, $statetypes, $limit, $display_type, $alert_types, $host_states, $service_states);
    my $standardreport = $c->{'request'}->{'parameters'}->{'standardreport'};
    if(defined $standardreport) {
        # set options from standard report options
        $c->{'request'}->{'parameters'}->{'timeperiod'} = "last7days";
        $statetypes = 2; # hard only
        $limit      = 25;

        if($standardreport == SREPORT_RECENT_ALERTS) {
            $display_type   = REPORT_RECENT_ALERTS;
            $alert_types    = AE_HOST_ALERT + AE_SERVICE_ALERT;
            $host_states    = AE_HOST_UP + AE_HOST_DOWN + AE_HOST_UNREACHABLE;
            $service_states = AE_SERVICE_OK + AE_SERVICE_WARNING + AE_SERVICE_UNKNOWN + AE_SERVICE_CRITICAL;
        }
        elsif($standardreport == SREPORT_RECENT_HOST_ALERTS) {
            $display_type   = REPORT_RECENT_ALERTS;
            $alert_types    = AE_HOST_ALERT;
            $host_states    = AE_HOST_UP + AE_HOST_DOWN + AE_HOST_UNREACHABLE;
        }
        elsif($standardreport == SREPORT_RECENT_SERVICE_ALERTS) {
            $display_type   = REPORT_RECENT_ALERTS;
            $alert_types    = AE_SERVICE_ALERT;
            $service_states = AE_SERVICE_OK + AE_SERVICE_WARNING + AE_SERVICE_UNKNOWN + AE_SERVICE_CRITICAL;
        }
        elsif($standardreport == SREPORT_TOP_HOST_ALERTS) {
            $display_type   = REPORT_TOP_ALERTS;
            $alert_types    = AE_HOST_ALERT;
            $host_states    = AE_HOST_UP + AE_HOST_DOWN + AE_HOST_UNREACHABLE;
        }
        elsif($standardreport == SREPORT_TOP_SERVICE_ALERTS) {
            $display_type   = REPORT_TOP_ALERTS;
            $alert_types    = AE_SERVICE_ALERT;
            $service_states = AE_SERVICE_OK + AE_SERVICE_WARNING + AE_SERVICE_UNKNOWN + AE_SERVICE_CRITICAL;
        }
        else {
            return;
        }
    } else {
        # set options from parameters
        $statetypes     = $c->{'request'}->{'parameters'}->{'statetypes'};
        $limit          = $c->{'request'}->{'parameters'}->{'limit'};
        $display_type   = $c->{'request'}->{'parameters'}->{'display_type'};
        $alert_types    = $c->{'request'}->{'parameters'}->{'alert_types'};
        $host_states    = $c->{'request'}->{'parameters'}->{'host_states'};
        $service_states = $c->{'request'}->{'parameters'}->{'service_states'};
    }

    # get start/end from timeperiod in params
    my($start,$end) = Thruk::Utils::get_start_end_for_timeperiod_from_param($c);
    return if (!defined $start or !defined $end);
    $c->stash->{start}      = $start;
    $c->stash->{end}        = $end;
    $c->stash->{timeperiod} = $c->{'request'}->{'parameters'}->{'timeperiod'};

    if($display_type == REPORT_RECENT_ALERTS) {
        $c->stash->{report_title}    = 'Most Recent Alerts';
        $c->stash->{report_template} = 'summary_report_recent_alerts.tt';
    }
    elsif($display_type == REPORT_TOP_ALERTS) {
        $c->stash->{report_title}    = 'Top Alert Producers';
        $c->stash->{report_template} = 'summary_report_top_alerts.tt';
    }
    elsif($display_type == REPORT_ALERT_TOTALS) {
        $c->stash->{report_title}    = 'Alert Totals';
        $c->stash->{report_template} = 'summary_report_alert_totals.tt';
    }
    elsif($display_type == REPORT_HOSTGROUP_ALERT_TOTALS) {
        $c->stash->{report_title}    = 'Alert Totals';
        $c->stash->{report_template} = 'summary_report_alert_totals.tt';
    }
    elsif($display_type == REPORT_HOST_ALERT_TOTALS) {
        $c->stash->{report_title}    = 'Alert Totals';
        $c->stash->{report_template} = 'summary_report_alert_totals.tt';
    }
    elsif($display_type == REPORT_SERVICE_ALERT_TOTALS) {
        $c->stash->{report_title}    = 'Alert Totals';
        $c->stash->{report_template} = 'summary_report_alert_totals.tt';
    }
    elsif($display_type == REPORT_SERVICEGROUP_ALERT_TOTALS) {
        $c->stash->{report_title}    = 'Alert Totals';
        $c->stash->{report_template} = 'summary_report_alert_totals.tt';
    }
    else {
        return;
    }

    $c->stash->{template}        = 'summary_report.tt';

    $c->stats->profile(begin => "_create_report()");
    return 1;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
