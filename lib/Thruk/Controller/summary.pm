package Thruk::Controller::summary;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::summary - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

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

    # state types
    AE_SOFT                             => 1,
    AE_HARD                             => 2,

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

=head1 METHODS

=head2 index

=cut

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

    my($timeperiod, $statetypes, $limit, $displaytype, $alert_types, $host_states, $service_states);
    my $standardreport = $c->{'request'}->{'parameters'}->{'standardreport'};
    if(defined $standardreport) {
        # set options from standard report options
        $c->{'request'}->{'parameters'}->{'timeperiod'} = "last7days";
        $statetypes = 2; # hard only
        $limit      = 25;

        if($standardreport == SREPORT_RECENT_ALERTS) {
            $displaytype    = REPORT_RECENT_ALERTS;
            $alert_types    = AE_HOST_ALERT + AE_SERVICE_ALERT;
            $host_states    = AE_HOST_UP + AE_HOST_DOWN + AE_HOST_UNREACHABLE;
            $service_states = AE_SERVICE_OK + AE_SERVICE_WARNING + AE_SERVICE_UNKNOWN + AE_SERVICE_CRITICAL;
        }
        elsif($standardreport == SREPORT_RECENT_HOST_ALERTS) {
            $displaytype    = REPORT_RECENT_ALERTS;
            $alert_types    = AE_HOST_ALERT;
            $host_states    = AE_HOST_UP + AE_HOST_DOWN + AE_HOST_UNREACHABLE;
        }
        elsif($standardreport == SREPORT_RECENT_SERVICE_ALERTS) {
            $displaytype    = REPORT_RECENT_ALERTS;
            $alert_types    = AE_SERVICE_ALERT;
            $service_states = AE_SERVICE_OK + AE_SERVICE_WARNING + AE_SERVICE_UNKNOWN + AE_SERVICE_CRITICAL;
        }
        elsif($standardreport == SREPORT_TOP_HOST_ALERTS) {
            $displaytype    = REPORT_TOP_ALERTS;
            $alert_types    = AE_HOST_ALERT;
            $host_states    = AE_HOST_UP + AE_HOST_DOWN + AE_HOST_UNREACHABLE;
        }
        elsif($standardreport == SREPORT_TOP_SERVICE_ALERTS) {
            $displaytype    = REPORT_TOP_ALERTS;
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
        $displaytype    = $c->{'request'}->{'parameters'}->{'displaytype'};
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

    # get filter from parameters
    my($hostfilter, $servicefilter) = $self->_get_filter($c);

    $hostfilter    .= "Filter: time >= $start\nFilter: time <= $end";
    $servicefilter .= "Filter: time >= $start\nFilter: time <= $end";

    my $alertlogs = $self->_get_alerts_from_log($c, $hostfilter, $servicefilter);

    if($displaytype == REPORT_RECENT_ALERTS) {
        $c->stash->{report_title}    = 'Most Recent Alerts';
        $c->stash->{report_template} = 'summary_report_recent_alerts.tt';
        $self->_display_recent_alerts($c, $alertlogs);
    }
    elsif($displaytype == REPORT_TOP_ALERTS) {
        $c->stash->{report_title}    = 'Top Alert Producers';
        $c->stash->{report_template} = 'summary_report_top_alerts.tt';
        $self->_display_top_alerts($c, $alertlogs);
    }
    elsif($displaytype == REPORT_ALERT_TOTALS) {
        $c->stash->{report_title}    = 'Alert Totals';
        $c->stash->{report_template} = 'summary_report_alert_totals.tt';
        $self->_display_alert_totals($c, $alertlogs);
    }
    elsif($displaytype == REPORT_HOSTGROUP_ALERT_TOTALS) {
        $c->stash->{report_title}    = 'Alert Totals';
        $c->stash->{report_template} = 'summary_report_alert_totals.tt';
        $self->_display_alert_totals($c, $alertlogs);
    }
    elsif($displaytype == REPORT_HOST_ALERT_TOTALS) {
        $c->stash->{report_title}    = 'Alert Totals';
        $c->stash->{report_template} = 'summary_report_alert_totals.tt';
        $self->_display_alert_totals($c, $alertlogs);
    }
    elsif($displaytype == REPORT_SERVICE_ALERT_TOTALS) {
        $c->stash->{report_title}    = 'Alert Totals';
        $c->stash->{report_template} = 'summary_report_alert_totals.tt';
        $self->_display_alert_totals($c, $alertlogs);
    }
    elsif($displaytype == REPORT_SERVICEGROUP_ALERT_TOTALS) {
        $c->stash->{report_title}    = 'Alert Totals';
        $c->stash->{report_template} = 'summary_report_alert_totals.tt';
        $self->_display_alert_totals($c, $alertlogs);
    }
    else {
        return;
    }

    $c->stash->{template} = 'summary_report.tt';

    $c->stats->profile(end => "_create_report()");
    return 1;
}

##########################################################
sub _display_top_alerts {
    my ( $self, $c, $alerts ) = @_;
    $c->stats->profile(begin => "_display_top_alerts()");


    $c->stats->profile(end => "_display_top_alerts()");
    return 1;
}

##########################################################
sub _get_alerts_from_log {
    my ( $self, $c, $hostfilter, $servicefilter ) = @_;

    my($hostlogs, $servicelogs);

    if($c->stash->{alerttypefilter} ne "Service") {
        my $host_log_query = "GET log\n".$hostfilter.Thruk::Utils::get_auth_filter($c, 'log')."\nColumns: time state host_name service_description current_host_groups current_service_groups";
        $c->log->debug($host_log_query);
        $c->stats->profile(begin => "summary.pm fetch host logs");
        $hostlogs = $c->{'live'}->selectall_arrayref($host_log_query, { Slice => 1} );
        $c->stats->profile(end   => "summary.pm fetch host logs");
    }

    if($c->stash->{alerttypefilter} ne "Host") {
        my $service_log_query = "GET log\n".$servicefilter.Thruk::Utils::get_auth_filter($c, 'log')."\nColumns: time state host_name service_description current_host_groups current_service_groups";
        $c->log->debug($service_log_query);
        $c->stats->profile(begin => "summary.pm fetch service logs");
        $servicelogs = $c->{'live'}->selectall_arrayref($service_log_query, { Slice => 1} );
        $c->stats->profile(end   => "summary.pm fetch service logs");
    }

    my @alertlogs = [ @{$hostlogs}, @{$servicelogs} ];

    return(\@alertlogs);
}

##########################################################
sub _get_filter {
    my( $self, $c ) = @_;

    my($hostfilter, $servicefilter) = ("", "");

    # host state filter
    my($hoststatusfiltername,$hoststatusfilter)
        = $self->_get_host_statustype_filter($c->{'request'}->{'parameters'}->{'hoststates'});
    $c->stash->{hoststatusfilter} = $hoststatusfiltername;
    $hostfilter .= $hoststatusfilter;

    # service state filter
    my($servicestatusfiltername,$servicestatusfilter)
        = $self->_get_service_statustype_filter($c->{'request'}->{'parameters'}->{'servicestates'});
    $c->stash->{servicestatusfilter} = $servicestatusfiltername;
    $servicefilter .= $servicestatusfilter;

    # hard or soft?
    my $statetypes = $c->{'request'}->{'parameters'}->{'statetypes'};
    if($statetypes == AE_SOFT) {
        $c->stash->{statetypefilter} = "Soft";
        $servicefilter .= "Filter: options ~ ;SOFT;\n";
        $hostfilter    .= "Filter: options ~ ;SOFT;\n";
    }
    elsif($statetypes == AE_HARD) {
        $c->stash->{statetypefilter} = "Hard";
        $servicefilter .= "Filter: options ~ ;HARD;\n";
        $hostfilter    .= "Filter: options ~ ;HARD;\n";
    }
    else {
        $c->stash->{statetypefilter} = "Hard &amp; Soft";
    }

    # only hosts or services?
    $hostfilter    .= "Filter: type = HOST ALERT\n";
    $servicefilter .= "Filter: type = SERVICE ALERT\n";
    my $alerttypes = $c->{'request'}->{'parameters'}->{'alerttypes'};
    if($alerttypes == AE_HOST_ALERT) {
        $c->stash->{alerttypefilter} = "Host";
    }
    elsif($alerttypes == AE_SERVICE_ALERT) {
        $c->stash->{alerttypefilter} = "Service";
    }
    else {
        $c->stash->{alerttypefilter} = "Host &amp; Service";
    }

    # hostgroups?
    my $hostgroup    = $c->{'request'}->{'parameters'}->{'hostgroup'};
    my $host         = $c->{'request'}->{'parameters'}->{'host'};
    my $servicegroup = $c->{'request'}->{'parameters'}->{'servicegroup'};
    if(defined $hostgroup and $hostgroup ne 'all') {
        $hostfilter    .= "Filter: current_host_groups >= $hostgroup\n";
        $servicefilter .= "Filter: current_host_groups >= $hostgroup\n";
    }
    elsif(defined $host and $host ne 'all') {
        $hostfilter    .= "Filter: host_name = $host\n";
        $servicefilter .= "Filter: host_name = $host\n";
    }
    elsif(defined $servicegroup and $servicegroup ne 'all') {
        $hostfilter    .= "Filter: current_service_groups >= $servicegroup\n";
        $servicefilter .= "Filter: current_service_groups >= $servicegroup\n";
    }

    return($hostfilter, $servicefilter);
}

##########################################################
sub _get_host_statustype_filter {
    my ( $self, $number ) = @_;

    $number = 7 if !defined $number or $number <= 0 or $number > 7;
    my $hoststatusfiltername = 'All';
    my $hostfilter           = '';
    if($number and $number != 7) {
        my @hoststatusfilter;
        my @hoststatusfiltername;
        my @bits = reverse split(/\ */mx, unpack("B*", pack("n", int($number))));

        if($bits[0]) {  # 1 - host down
            push @hoststatusfilter,    "Filter: state = 1";
            push @hoststatusfiltername, 'Down';
        }
        if($bits[1]) {  # 2 - host unreachable
            push @hoststatusfilter,    "Filter: state = 2";
            push @hoststatusfiltername, 'Unreachable';
        }
        if($bits[2]) {  # 4 - host up
            push @hoststatusfilter,    "Filter: state = 0";
            push @hoststatusfiltername, 'Up';
        }
        $hoststatusfiltername = join(', ', @hoststatusfiltername);

        if(scalar @hoststatusfilter > 1) {
            $hostfilter    .= join("\n", @hoststatusfilter)."\nOr: ".(scalar @hoststatusfilter)."\n";
        }
        elsif(scalar @hoststatusfilter == 1) {
            $hostfilter    .= $hoststatusfilter[0]."\n";
        }
    }
    return($hoststatusfiltername,$hostfilter);
}

##########################################################
sub _get_service_statustype_filter {
    my ( $self, $number ) = @_;

    $number = 120 if !defined $number or $number <= 0 or $number > 120;
    my $servicestatusfiltername = 'All';
    my $servicefilter           = '';
    if($number and $number != 120) {
        my @servicestatusfilter;
        my @servicestatusfiltername;
        my @bits = reverse split(/\ */mx, unpack("B*", pack("n", int($number))));

        if($bits[3]) {  # 8 - service warning
            push @servicestatusfilter,    "Filter: state = 1";
            push @servicestatusfiltername, 'Warning';
        }
        if($bits[4]) {  # 16 - service unknown
            push @servicestatusfilter,    "Filter: state = 3";
            push @servicestatusfiltername, 'Unknown';
        }
        if($bits[5]) {  # 32 - service critical
            push @servicestatusfilter,    "Filter: state = 2";
            push @servicestatusfiltername, 'Critical';
        }
        if($bits[6]) {  # 64 - service ok
            push @servicestatusfilter,    "Filter: state = 0";
            push @servicestatusfiltername, 'Ok';
        }
        $servicestatusfiltername = join(', ', @servicestatusfiltername);

        if(scalar @servicestatusfilter > 1) {
            $servicefilter    .= join("\n", @servicestatusfilter)."\nOr: ".(scalar @servicestatusfilter)."\n";
        }
        elsif(scalar @servicestatusfilter == 1) {
            $servicefilter    .= $servicestatusfilter[0]."\n";
        }
    }
    return($servicestatusfiltername,$servicefilter);
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
