package Thruk::Controller::summary;

use strict;
use warnings;
use utf8;
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

    Thruk::Utils::ssi_include($c);

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

    $c->stash->{hosts}         = $c->{'db'}->get_host_names(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts') ]);
    $c->stash->{hostgroups}    = $c->{'db'}->get_hostgroup_names_from_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );
    $c->stash->{servicegroups} = $c->{'db'}->get_servicegroup_names_from_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ] );
    $c->stash->{template}      = 'summary_step_1.tt';

    $c->stats->profile(end => "_show_step_1()");
    return 1;
}

##########################################################
sub _create_report {
    my ( $self, $c ) = @_;
    $c->stats->profile(begin => "_create_report()");

    my($timeperiod, $displaytype, $alerttypes, $hoststates, $servicestates);
    my $standardreport = $c->{'request'}->{'parameters'}->{'standardreport'};
    if(defined $standardreport) {
        # set options from standard report options
        $c->{'request'}->{'parameters'}->{'timeperiod'} = "last7days";
        $c->{'request'}->{'parameters'}->{'statetypes'} = 2;
        $c->{'request'}->{'parameters'}->{'limit'}      = 25;

        if($standardreport == SREPORT_RECENT_ALERTS) {
            $displaytype   = REPORT_RECENT_ALERTS;
            $alerttypes    = AE_HOST_ALERT + AE_SERVICE_ALERT;
            $hoststates    = AE_HOST_UP + AE_HOST_DOWN + AE_HOST_UNREACHABLE;
            $servicestates = AE_SERVICE_OK + AE_SERVICE_WARNING + AE_SERVICE_UNKNOWN + AE_SERVICE_CRITICAL;
        }
        elsif($standardreport == SREPORT_RECENT_HOST_ALERTS) {
            $displaytype   = REPORT_RECENT_ALERTS;
            $alerttypes    = AE_HOST_ALERT;
            $hoststates    = AE_HOST_UP + AE_HOST_DOWN + AE_HOST_UNREACHABLE;
        }
        elsif($standardreport == SREPORT_RECENT_SERVICE_ALERTS) {
            $displaytype   = REPORT_RECENT_ALERTS;
            $alerttypes    = AE_SERVICE_ALERT;
            $servicestates = AE_SERVICE_OK + AE_SERVICE_WARNING + AE_SERVICE_UNKNOWN + AE_SERVICE_CRITICAL;
        }
        elsif($standardreport == SREPORT_TOP_HOST_ALERTS) {
            $displaytype   = REPORT_TOP_ALERTS;
            $alerttypes    = AE_HOST_ALERT;
            $hoststates    = AE_HOST_UP + AE_HOST_DOWN + AE_HOST_UNREACHABLE;
        }
        elsif($standardreport == SREPORT_TOP_SERVICE_ALERTS) {
            $displaytype   = REPORT_TOP_ALERTS;
            $alerttypes    = AE_SERVICE_ALERT;
            $servicestates = AE_SERVICE_OK + AE_SERVICE_WARNING + AE_SERVICE_UNKNOWN + AE_SERVICE_CRITICAL;
        }
        else {
            return;
        }
        $c->{'request'}->{'parameters'}->{'alerttypes'}    = $alerttypes;
        $c->{'request'}->{'parameters'}->{'servicestates'} = $servicestates;
        $c->{'request'}->{'parameters'}->{'hoststates'}    = $hoststates;
    } else {
        # set options from parameters
        $displaytype    = $c->{'request'}->{'parameters'}->{'displaytype'};
    }

    # get start/end from timeperiod in params
    my($start,$end) = Thruk::Utils::get_start_end_for_timeperiod_from_param($c);
    return if (!defined $start or !defined $end);
    $c->stash->{start}      = $start;
    $c->stash->{end}        = $end;
    $c->stash->{timeperiod} = $c->{'request'}->{'parameters'}->{'timeperiod'};

    # get filter from parameters
    my($hostfilter, $servicefilter) = $self->_get_filter($c);

    unshift @{$hostfilter}, { time => { '<=' => $end }};
    unshift @{$hostfilter}, { time => { '>=' => $start }};

    unshift @{$servicefilter}, { time => { '<=' => $end }};
    unshift @{$servicefilter}, { time => { '>=' => $start }};

    my $alertlogs = $self->_get_alerts_from_log($c, $hostfilter, $servicefilter);

    if($displaytype == REPORT_RECENT_ALERTS) {
        $c->stash->{report_title}    = 'Most Recent Alerts';
        $c->stash->{report_template} = 'summary_report_recent_alerts.tt';
        $self->_display_recent_alerts($c, $alertlogs);
    }
    elsif($displaytype == REPORT_TOP_ALERTS) {
        $c->stash->{report_title}    = 'Top Alert Producers';
        $c->stash->{report_template} = 'summary_report_alert_producer.tt';
        $self->_display_top_alerts($c, $alertlogs);
    }
    elsif(   $displaytype == REPORT_ALERT_TOTALS
          or $displaytype == REPORT_HOSTGROUP_ALERT_TOTALS
          or $displaytype == REPORT_HOST_ALERT_TOTALS
          or $displaytype == REPORT_SERVICE_ALERT_TOTALS
          or $displaytype == REPORT_SERVICEGROUP_ALERT_TOTALS
         ) {
        $c->stash->{report_title}    = 'Alert Totals';
        $c->stash->{report_template} = 'summary_report_alert_totals.tt';
        $self->_display_alert_totals($c, $alertlogs, $displaytype);
    }
    else {
        return;
    }

    $c->stash->{template} = 'summary_report.tt';
    $c->stash->{limit}    = $c->{'request'}->{'parameters'}->{'limit'};

    $c->stats->profile(end => "_create_report()");
    return 1;
}

##########################################################
# Most Recent Alerts
sub _display_recent_alerts {
    my ( $self, $c, $alerts ) = @_;
    $c->stats->profile(begin => "_display_recent_alerts()");

    my $sortedtotals = Thruk::Backend::Manager::_sort($c, $alerts, { 'DESC' => 'time'});
    Thruk::Backend::Manager::_page_data(undef, $c, $sortedtotals, $c->{'request'}->{'parameters'}->{'limit'});

    $c->stats->profile(end => "_display_recent_alerts()");
    return 1;
}

##########################################################
# Top Alert Producers
sub _display_top_alerts {
    my ( $self, $c, $alerts ) = @_;
    $c->stats->profile(begin => "_display_top_alerts()");

    my $totals = {};
    for my $alert (@{$alerts}) {
        my $ident = $alert->{'host_name'}.";".$alert->{'service_description'};
        if(!defined $totals->{$ident}) {
            $totals->{$ident} = {
                        'host_name'           => $alert->{'host_name'},
                        'service_description' => $alert->{'service_description'},
                        'alerts'              => 1,
            };
        }
        else {
            $totals->{$ident}->{'alerts'}++;
        }
    }

    my @totals = values %{$totals};
    my $sortedtotals = Thruk::Backend::Manager::_sort($c, \@totals, { 'DESC' => 'alerts'});
    Thruk::Backend::Manager::_page_data(undef, $c, $sortedtotals, $c->{'request'}->{'parameters'}->{'limit'});

    $c->stats->profile(end => "_display_top_alerts()");
    return 1;
}

##########################################################
# Alert Totals
sub _display_alert_totals {
    my ( $self, $c, $alerts, $displaytype ) = @_;
    $c->stats->profile(begin => "_display_alert_totals()");

    # set overall title
    my $box_title_data;
    if($displaytype == REPORT_ALERT_TOTALS) {
        $c->stash->{'box_title'} = 'Overall Totals';
    }
    elsif($displaytype == REPORT_HOSTGROUP_ALERT_TOTALS) {
        $c->stash->{'box_title'} = 'Totals By Hostgroup';
        my $tmp = $c->{'db'}->get_hostgroups();
        $box_title_data = Thruk::Utils::array2hash($tmp, 'name');
    }
    elsif($displaytype == REPORT_HOST_ALERT_TOTALS) {
        $c->stash->{'box_title'} = 'Totals By Host';
        my $tmp = $c->{'db'}->get_hosts(columns => [qw/name alias/]);
        $box_title_data = Thruk::Utils::array2hash($tmp, 'name');
    }
    elsif($displaytype == REPORT_SERVICE_ALERT_TOTALS) {
        $c->stash->{'box_title'} = 'Totals By Service';
    }
    elsif($displaytype == REPORT_SERVICEGROUP_ALERT_TOTALS) {
        $c->stash->{'box_title'} = 'Totals By Servicegroup';
        my $tmp = $c->{'db'}->get_servicegroups();
        $box_title_data = Thruk::Utils::array2hash($tmp, 'name');
    }

    my $totals = {};
    for my $alert (@{$alerts}) {

        # define by which type we group
        my @idents;
        if($displaytype == REPORT_ALERT_TOTALS) {
            $idents[0] = 'overall';
        }
        elsif($displaytype == REPORT_HOSTGROUP_ALERT_TOTALS) {
            next unless defined $alert->{'current_host_groups'};
            @idents = @{$alert->{'current_host_groups'}};
        }
        elsif($displaytype == REPORT_HOST_ALERT_TOTALS) {
            $idents[0] = $alert->{'host_name'};
        }
        elsif($displaytype == REPORT_SERVICE_ALERT_TOTALS) {
            next unless defined $alert->{'service_description'};
            $idents[0] = $alert->{'host_name'}.";".$alert->{'service_description'};
        }
        elsif($displaytype == REPORT_SERVICEGROUP_ALERT_TOTALS) {
            next unless defined $alert->{'current_service_groups'};
            @idents = @{$alert->{'current_service_groups'}};
        }

        for my $ident (@idents) {
            # set a empty default set of counters
            if(!defined $totals->{$ident}) {
                my $sub_title = '';
                if($displaytype == REPORT_HOSTGROUP_ALERT_TOTALS) {
                    $sub_title = "Hostgroup '".$ident."' (".$box_title_data->{$ident}->{'alias'}.")";
                }
                elsif($displaytype == REPORT_HOST_ALERT_TOTALS) {
                    $sub_title = "Host '".$ident."' (".$box_title_data->{$ident}->{'alias'}.")";
                }
                elsif($displaytype == REPORT_SERVICE_ALERT_TOTALS) {
                    my($host,$service) = split/;/mx, $ident;
                    $sub_title = "Service '".$service."' on Host '".$host."'";
                }
                elsif($displaytype == REPORT_SERVICEGROUP_ALERT_TOTALS) {
                    $sub_title = "Servicegroup '".$ident."' (".$box_title_data->{$ident}->{'alias'}.")";
                }
                $totals->{$ident} = {
                    'sub_title' => $sub_title,
                    'no_hosts'  => 0,
                    'host'      => {
                                    'HARD' => {
                                                'UP'          => 0,
                                                'DOWN'        => 0,
                                                'UNREACHABLE' => 0,
                                               },
                                    'SOFT' => {
                                                'UP'          => 0,
                                                'DOWN'        => 0,
                                                'UNREACHABLE' => 0,
                                               },
                                },
                    'service'   => {
                                    'HARD' => {
                                                'OK'       => 0,
                                                'WARNING'  => 0,
                                                'UNKNOWN'  => 0,
                                                'CRITICAL' => 0,
                                               },
                                    'SOFT' => {
                                                'OK'       => 0,
                                                'WARNING'  => 0,
                                                'UNKNOWN'  => 0,
                                                'CRITICAL' => 0,
                                               },
                                },
                };
                if($displaytype == REPORT_SERVICE_ALERT_TOTALS) {
                    $totals->{$ident}->{'no_hosts'} = 1;
                }
            }

            # define path to counter
            my($host_or_service,$state);
            if(defined $alert->{'service_description'} and $alert->{'service_description'} ne '') {
                $host_or_service = 'service';
                if   ($alert->{'state'} == 0) { $state = 'OK';       }
                elsif($alert->{'state'} == 1) { $state = 'WARNING';  }
                elsif($alert->{'state'} == 2) { $state = 'CRITICAL'; }
                elsif($alert->{'state'} == 3) { $state = 'UNKNOWN';  }
            } else {
                $host_or_service = 'host';
                if   ($alert->{'state'} == 0) { $state = 'UP';          }
                elsif($alert->{'state'} == 1) { $state = 'DOWN';        }
                elsif($alert->{'state'} == 2) { $state = 'UNREACHABLE'; }
            }

            # increase counter
            $totals->{$ident}->{$host_or_service}->{$alert->{'state_type'}}->{$state}++;
        }
    }

    $c->stash->{'data'} = $totals;

    $c->stats->profile(end => "_display_alert_totals()");
    return 1;
}

##########################################################
sub _get_alerts_from_log {
    my ( $self, $c, $hostfilter, $servicefilter ) = @_;

    my($hostlogs, $servicelogs);

    $c->stats->profile(begin => "summary::updatecache");
    return if $c->{'db'}->renew_logcache($c);
    $c->stats->profile(end   => "summary::updatecache");

    if($c->stash->{alerttypefilter} ne "Service") {
        $c->stats->profile(begin => "summary.pm fetch host logs");
        $hostlogs = $c->{'db'}->get_logs(filter => [$hostfilter, Thruk::Utils::Auth::get_auth_filter($c, 'log')]);
        $c->stats->profile(end   => "summary.pm fetch host logs");
    }

    if($c->stash->{alerttypefilter} ne "Host") {
        $c->stats->profile(begin => "summary.pm fetch service logs");
        $servicelogs = $c->{'db'}->get_logs(filter => [$servicefilter, Thruk::Utils::Auth::get_auth_filter($c, 'log')]);
        $c->stats->profile(end   => "summary.pm fetch service logs");
    }

    $hostlogs    = [] unless defined $hostlogs;
    $servicelogs = [] unless defined $servicelogs;
    my $alertlogs = [ @{$hostlogs}, @{$servicelogs} ];

    return($alertlogs);
}

##########################################################
sub _get_filter {
    my( $self, $c ) = @_;

    my(@hostfilter, @servicefilter);

    # host state filter
    my($hoststatusfiltername,$hoststatusfilter)
        = $self->_get_host_statustype_filter($c->{'request'}->{'parameters'}->{'hoststates'});
    $c->stash->{hoststatusfilter} = $hoststatusfiltername;
    push @hostfilter, $hoststatusfilter if $hoststatusfilter;

    # service state filter
    my($servicestatusfiltername,$servicestatusfilter)
        = $self->_get_service_statustype_filter($c->{'request'}->{'parameters'}->{'servicestates'});
    $c->stash->{servicestatusfilter} = $servicestatusfiltername;
    push @servicefilter, $servicestatusfilter if $servicestatusfilter;

    # hard or soft?
    my $statetypes = $c->{'request'}->{'parameters'}->{'statetypes'} || 3;
    if($statetypes == AE_SOFT) {
        $c->stash->{statetypefilter} = "Soft";
        push @servicefilter, { state_type => { '=' => 'SOFT' }};
        push @hostfilter,    { state_type => { '=' => 'SOFT' }};
    }
    elsif($statetypes == AE_HARD) {
        $c->stash->{statetypefilter} = "Hard";
        push @servicefilter, { state_type => { '=' => 'HARD' }};
        push @hostfilter,    { state_type => { '=' => 'HARD' }};
    }
    else {
        $c->stash->{statetypefilter} = "Hard &amp; Soft";
    }

    # only hosts or services?
    push @hostfilter,    { type => 'HOST ALERT'};
    push @servicefilter, { type => 'SERVICE ALERT'};
    my $alerttypes = $c->{'request'}->{'parameters'}->{'alerttypes'} || 3;
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
        push @hostfilter,    { current_host_groups => { '>=' => $hostgroup }};
        push @servicefilter, { current_host_groups => { '>=' => $hostgroup }};
    }
    if(defined $host and $host ne 'all') {
        push @hostfilter,    { host_name => $host };
        push @servicefilter, { host_name => $host };
    }
    if(defined $servicegroup and $servicegroup ne 'all') {
        push @hostfilter,    { current_service_groups => { '>=' => $servicegroup }};
        push @servicefilter, { current_service_groups => { '>=' => $servicegroup }};
    }

    return(\@hostfilter, \@servicefilter);
}

##########################################################
sub _get_host_statustype_filter {
    my ( $self, $number ) = @_;

    $number = 7 if !defined $number or $number <= 0 or $number > 7;
    my $hoststatusfiltername = 'All';
    my @hoststatusfilter;
    if($number and $number != 7) {
        my @hoststatusfiltername;
        my @bits = reverse split(/\ */mx, unpack("B*", pack("n", int($number))));

        if($bits[0]) {  # 1 - host down
            push @hoststatusfilter,    { state =>  1 };
            push @hoststatusfiltername, 'Down';
        }
        if($bits[1]) {  # 2 - host unreachable
            push @hoststatusfilter,    { state =>  2 };
            push @hoststatusfiltername, 'Unreachable';
        }
        if($bits[2]) {  # 4 - host up
            push @hoststatusfilter,    { state =>  0 };
            push @hoststatusfiltername, 'Up';
        }
        $hoststatusfiltername = join(', ', @hoststatusfiltername);
    }
    my $hostfilter = Thruk::Utils::combine_filter('-or', \@hoststatusfilter);
    return($hoststatusfiltername,$hostfilter);
}

##########################################################
sub _get_service_statustype_filter {
    my ( $self, $number ) = @_;

    $number = 120 if !defined $number or $number <= 0 or $number > 120;
    my $servicestatusfiltername = 'All';
    my @servicestatusfilter;
    if($number and $number != 120) {
        my @servicestatusfiltername;
        my @bits = reverse split(/\ */mx, unpack("B*", pack("n", int($number))));

        if($bits[3]) {  # 8 - service warning
            push @servicestatusfilter,    { state => 1 };
            push @servicestatusfiltername, 'Warning';
        }
        if($bits[4]) {  # 16 - service unknown
            push @servicestatusfilter,    { state => 3 };
            push @servicestatusfiltername, 'Unknown';
        }
        if($bits[5]) {  # 32 - service critical
            push @servicestatusfilter,    { state => 2 };
            push @servicestatusfiltername, 'Critical';
        }
        if($bits[6]) {  # 64 - service ok
            push @servicestatusfilter,    { state => 0 };
            push @servicestatusfiltername, 'Ok';
        }
        $servicestatusfiltername = join(', ', @servicestatusfiltername);
    }
    my $servicefilter = Thruk::Utils::combine_filter('-or', \@servicestatusfilter);
    return($servicestatusfiltername,$servicefilter);
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
