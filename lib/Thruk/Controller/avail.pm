package Thruk::Controller::avail;

use strict;
use warnings;
use Data::Dumper;
use Monitoring::Availability;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::avail - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    # set defaults
    $c->stash->{title}            = 'Availability';
    $c->stash->{infoBoxTitle}     = 'Availability Report';
    $c->stash->{page}             = 'avail';
    $c->stash->{'no_auto_reload'} = 1;

    # lookup parameters
    my $report_type    = $c->{'request'}->{'parameters'}->{'report_type'}  || '';
    my $timeperiod     = $c->{'request'}->{'parameters'}->{'timeperiod'};
    my $host           = $c->{'request'}->{'parameters'}->{'host'}         || '';
    my $hostgroup      = $c->{'request'}->{'parameters'}->{'hostgroup'}    || '';
    my $service        = $c->{'request'}->{'parameters'}->{'service'}      || '';
    my $servicegroup   = $c->{'request'}->{'parameters'}->{'servicegroup'} || '';


    # set them for our template
    $c->stash->{report_type}  = $report_type;
    $c->stash->{host}         = $host;
    $c->stash->{hostgroup}    = $hostgroup;
    $c->stash->{service}      = $service;
    $c->stash->{servicegroup} = $servicegroup;

    # set infobox title
    if($report_type eq 'servicegroups'  or $servicegroup) {
        $c->stash->{infoBoxTitle} = 'Servicegroup Availability Report';
    }
    elsif($report_type eq 'services'    or $service) {
        $c->stash->{infoBoxTitle} = 'Service Availability Report';
    }
    elsif($report_type eq 'hosts'       or $host) {
        $c->stash->{infoBoxTitle} = 'Host Availability Report';
    }
    elsif($report_type eq 'hostgroups'  or $hostgroup) {
        $c->stash->{infoBoxTitle} = 'Hostgroup Availability Report';
    }



    # Step 2 - select specific host/service/group
    if($report_type and $self->_show_step_2($c, $report_type)) {
    }

    # Step 3 - select date parts
    elsif(exists $c->{'request'}->{'parameters'}->{'get_date_parts'} and $self->_show_step_3($c)) {
    }

    # Step 4 - create report
    elsif(!$report_type
       and ($host or $service or $servicegroup or $hostgroup)
       and $self->_create_report($c)) {
    }



    # Step 1 - select report type
    else {
        $self->_show_step_1($c);
    }

    return 1;
}

##########################################################
sub _show_step_1 {
    my ( $self, $c ) = @_;

    $c->stats->profile(begin => "_show_step_1()");
    $c->stash->{template} = 'avail_step_1.tt';
    $c->stats->profile(end => "_show_step_1()");

    return 1;
}


##########################################################
sub _show_step_2 {
    my ( $self, $c, $report_type ) = @_;

    $c->stats->profile(begin => "_show_step_2($report_type)");

    my $data;
    if($report_type eq 'hosts') {
        $data = $c->{'live'}->selectall_hashref("GET hosts\nColumns: name\n".Thruk::Utils::get_auth_filter($c, 'hosts'), 'name');
    }
    elsif($report_type eq 'hostgroups') {
        $data = $c->{'live'}->selectall_hashref("GET hostgroups\nColumns: name\n".Thruk::Utils::get_auth_filter($c, 'hostgroups'), 'name');
    }
    elsif($report_type eq 'servicegroups') {
        $data = $c->{'live'}->selectall_hashref("GET servicegroups\nColumns: name\n".Thruk::Utils::get_auth_filter($c, 'servicegroups'), 'name');
    }
    elsif($report_type eq 'services') {
        my $services = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Utils::get_auth_filter($c, 'services')."\nColumns: host_name description", { Slice => 1});
        for my $service (@{$services}) {
            $data->{$service->{'host_name'}.";".$service->{'description'}} = 1;
        }
    }
    else {
        return 0;
    }

    my @sorted = sort keys %{$data};
    $c->stash->{data}        = \@sorted;
    $c->stash->{template}    = 'avail_step_2.tt';

    $c->stats->profile(end => "_show_step_2($report_type)");

    return 1;
}

##########################################################
sub _show_step_3 {
    my ( $self, $c ) = @_;

    $c->stats->profile(begin => "_show_step_3()");

    $c->stash->{timeperiods} = $c->{'live'}->selectall_arrayref("GET timeperiods\nColumns: name".Thruk::Utils::get_auth_filter($c, 'timeperiods'), { Slice => 1});
    $c->stash->{template}    = 'avail_step_3.tt';

    my($host,$service);
    $service = $c->{'request'}->{'parameters'}->{'service'};
    if($service and CORE::index($service, ';') > 0) {
        ($host,$service) = split/;/mx, $c->{'request'}->{'parameters'}->{'service'};
        $c->stash->{host}    = $host;
        $c->stash->{service} = $service;
    }

    $c->stats->profile(end => "_show_step_3()");

    return 1;
}

##########################################################
sub _create_report {
    my ( $self, $c ) = @_;
    my $start_time   = time();

    $c->stats->profile(begin => "_create_report()");

    my $host           = $c->{'request'}->{'parameters'}->{'host'};
    my $hostgroup      = $c->{'request'}->{'parameters'}->{'hostgroup'};
    my $service        = $c->{'request'}->{'parameters'}->{'service'};
    my $servicegroup   = $c->{'request'}->{'parameters'}->{'servicegroup'};

    if(defined $service and CORE::index($service, ';') > 0) {
        ($host,$service) = split/;/mx, $service;
        $c->stash->{host}    = $host;
        $c->stash->{service} = $service;
    }

    if(defined $host and $host eq 'null') { undef $host; }

    if(defined $hostgroup and $hostgroup ne '') {
        $c->stash->{template}   = 'avail_report_hostgroup.tt';
    }
    elsif(defined $service and $service ne 'all') {
        $c->stash->{template}   = 'avail_report_service.tt';
    }
    elsif(defined $service and $service eq 'all') {
        $c->stash->{template}   = 'avail_report_services.tt';
    }
    elsif(defined $servicegroup and $servicegroup ne '') {
        $c->stash->{template}   = 'avail_report_servicegroup.tt';
    }
    elsif(defined $host and $host ne 'all') {
        $c->stash->{template}   = 'avail_report_host.tt';
    }
    elsif(defined $host and $host eq 'all') {
        $c->stash->{template}   = 'avail_report_hosts.tt';
    }
    else {
        $c->log->debug("unknown report type");
        return;
    }

    # get timeperiod
    my $timeperiod   = $c->{'request'}->{'parameters'}->{'timeperiod'};
    my $smon         = $c->{'request'}->{'parameters'}->{'smon'};
    my $sday         = $c->{'request'}->{'parameters'}->{'sday'};
    my $syear        = $c->{'request'}->{'parameters'}->{'syear'};
    my $shour        = $c->{'request'}->{'parameters'}->{'shour'};
    my $smin         = $c->{'request'}->{'parameters'}->{'smin'};
    my $ssec         = $c->{'request'}->{'parameters'}->{'ssec'};
    my $emon         = $c->{'request'}->{'parameters'}->{'emon'};
    my $eday         = $c->{'request'}->{'parameters'}->{'eday'};
    my $eyear        = $c->{'request'}->{'parameters'}->{'eyear'};
    my $ehour        = $c->{'request'}->{'parameters'}->{'ehour'};
    my $emin         = $c->{'request'}->{'parameters'}->{'emin'};
    my $esec         = $c->{'request'}->{'parameters'}->{'esec'};
    my $t1           = $c->{'request'}->{'parameters'}->{'t1'};
    my $t2           = $c->{'request'}->{'parameters'}->{'t2'};

    $timeperiod = 'last24hours' if(!defined $timeperiod and !defined $t1 and !defined $t2);
    my($start,$end) = Thruk::Utils::get_start_end_for_timeperiod($timeperiod,$smon,$sday,$syear,$shour,$smin,$ssec,$emon,$eday,$eyear,$ehour,$emin,$esec,$t1,$t2);

    $c->log->debug("start: ".$start." - ".(scalar localtime($start)));
    $c->log->debug("end  : ".$end." - ".(scalar localtime($end)));
    return 0 if (!defined $start or !defined $end);

    $c->stash->{start}      = $start;
    $c->stash->{end}        = $end;
    $c->stash->{timeperiod} = $timeperiod;

    my $rpttimeperiod                = $c->{'request'}->{'parameters'}->{'rpttimeperiod'};
    my $assumeinitialstates          = $c->{'request'}->{'parameters'}->{'assumeinitialstates'};
    my $assumestateretention         = $c->{'request'}->{'parameters'}->{'assumestateretention'};
    my $assumestatesduringnotrunning = $c->{'request'}->{'parameters'}->{'assumestatesduringnotrunning'};
    my $includesoftstates            = $c->{'request'}->{'parameters'}->{'includesoftstates'};
    my $initialassumedhoststate      = $c->{'request'}->{'parameters'}->{'initialassumedhoststate'};
    my $initialassumedservicestate   = $c->{'request'}->{'parameters'}->{'initialassumedservicestate'};
    my $backtrack                    = $c->{'request'}->{'parameters'}->{'backtrack'};
    my $show_log_entries             = $c->{'request'}->{'parameters'}->{'show_log_entries'};
    my $full_log_entries             = $c->{'request'}->{'parameters'}->{'full_log_entries'};

    # show_log_entries is true if it exists
    $show_log_entries = 1 if exists $c->{'request'}->{'parameters'}->{'show_log_entries'};

    # full_log_entries is true if it exists
    $full_log_entries = 1 if exists $c->{'request'}->{'parameters'}->{'full_log_entries'};

    # default backtrack is 4 days
    $backtrack = 4 unless defined $backtrack;
    $backtrack = 4 if $backtrack < 0;

    $assumeinitialstates          = 'yes' unless defined $assumeinitialstates;
    $assumeinitialstates          = 'no'  unless $assumeinitialstates          eq 'yes';

    $assumestateretention         = 'yes' unless defined $assumestateretention;
    $assumestateretention         = 'no'  unless $assumestateretention         eq 'yes';

    $assumestatesduringnotrunning = 'yes' unless defined $assumestatesduringnotrunning;
    $assumestatesduringnotrunning = 'no'  unless $assumestatesduringnotrunning eq 'yes';

    $includesoftstates            = 'no'  unless defined $includesoftstates;
    $includesoftstates            = 'no'  unless $includesoftstates            eq 'yes';

    $initialassumedhoststate      = 0 unless defined $initialassumedhoststate;
    $initialassumedhoststate      = 0 unless $initialassumedhoststate ==  0  # Unspecified
                                          or $initialassumedhoststate == -1  # Current State
                                          or $initialassumedhoststate ==  3  # Host Up
                                          or $initialassumedhoststate ==  4  # Host Down
                                          or $initialassumedhoststate ==  5; # Host Unreachable

    $initialassumedservicestate   = 0 unless defined $initialassumedservicestate;
    $initialassumedservicestate   = 0 unless $initialassumedservicestate ==  0  # Unspecified
                                          or $initialassumedservicestate == -1  # Current State
                                          or $initialassumedservicestate ==  6  # Service Ok
                                          or $initialassumedservicestate ==  8  # Service Warning
                                          or $initialassumedservicestate ==  7  # Service Unknown
                                          or $initialassumedservicestate ==  9; # Service Critical

    $c->stash->{rpttimeperiod}                = $rpttimeperiod;
    $c->stash->{assumeinitialstates}          = $assumeinitialstates;
    $c->stash->{assumestateretention}         = $assumestateretention;
    $c->stash->{assumestatesduringnotrunning} = $assumestatesduringnotrunning;
    $c->stash->{includesoftstates}            = $includesoftstates;
    $c->stash->{initialassumedhoststate}      = $initialassumedhoststate;
    $c->stash->{initialassumedservicestate}   = $initialassumedservicestate;
    $c->stash->{backtrack}                    = $backtrack;
    $c->stash->{show_log_entries}             = $show_log_entries;
    $c->stash->{full_log_entries}             = $full_log_entries;

    # get groups / hosts /services
    my $groupfilter      = "";
    my $hostfilter       = "";
    my $servicefilter    = "";
    my $logserviceheadfilter;
    my $loghostheadfilter;
    my $initial_states = { 'hosts' => {}, 'services' => {} };

    # for which services do we need availability data?
    my $hosts = [];
    my $services = [];

    my $softlogs = "";
    if(!$includesoftstates or $includesoftstates eq 'no') {
        $softlogs = "Filter: options ~ ;HARD;\nAnd: 2\n"
    }

    my $logs;
    my $logfilter = "Filter: time >= ($start - $backtrack * 86400)\n";
    $logfilter   .= "Filter: time <= $end\n";
    $logfilter   .= "And: 2\n";

    # a single service
    if(defined $service and $service ne 'all') {
        unless($c->check_permissions('service', $service, $host)) {
            $c->detach('/error/index/15');
        }
        $logserviceheadfilter = "Filter: service_description = $service\n";
        $loghostheadfilter    = "Filter: host_name = $host\n";
        push @{$services}, { 'host' => $host, 'service' => $service };

        if($initialassumedservicestate == -1) {
            my $service_data = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Utils::get_auth_filter($c, 'services')."\nColumns: state\nLimit: 1", {Slice => 1});
            $initial_states->{'services'}->{$host}->{$service} = $service_data->[0]->{'state'};
        }
    }

    # all services
    elsif(defined $service and $service eq 'all') {
        my $all_services = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Utils::get_auth_filter($c, 'services')."\nColumns: host_name description state", { Slice => 1});
        my $services_data;
        for my $service (@{$all_services}) {
            $services_data->{$service->{'host_name'}}->{$service->{'description'}} = 1;
            push @{$services}, { 'host' => $service->{'host_name'}, 'service' => $service->{'description'} };
            if($initialassumedservicestate == -1) {
                $initial_states->{'services'}->{$service->{'host_name'}}->{$service->{'description'}} = $service->{'state'};
            }
        }
        $c->stash->{'services'} = $services_data;
    }

    # a single host
    elsif(defined $host and $host ne 'all') {
        unless($c->check_permissions('host', $host)) {
            $c->detach('/error/index/5');
        }
        my $service_data = $c->{'live'}->selectall_hashref("GET services\nFilter: host_name = ".$host."\n".Thruk::Utils::get_auth_filter($c, 'services')."\nColumns: description state", 'description' );
        $c->stash->{'services'} = { $host =>  $service_data };
        $loghostheadfilter = "Filter: host_name = $host\n";

        for my $description (keys %{$service_data}) {
            push @{$services}, { 'host' => $host, 'service' => $description };
        }
        if($initialassumedservicestate == -1) {
            for my $servicename (keys %{$service_data}) {
                $initial_states->{'services'}->{$host}->{$servicename} = $service_data->{$servicename}->{'state'};
            }
        }
        if($initialassumedhoststate == -1) {
            my $host_data = $c->{'live'}->selectall_arrayref("GET hosts\nFilter: name = $host\n".Thruk::Utils::get_auth_filter($c, 'hosts')."\nColumns: state\nLimit: 1", {Slice => 1});
            $initial_states->{'hosts'}->{$host} = $host_data->[0]->{'state'};
        }
        push @{$hosts}, $host;
    }

    # all hosts
    elsif(defined $host and $host eq 'all') {
        my $host_data = $c->{'live'}->selectall_hashref("GET hosts\n".Thruk::Utils::get_auth_filter($c, 'hosts')."\nColumns: name state", 'name' );
        $logserviceheadfilter = "Filter: service_description =\n";
        $c->stash->{'hosts'} = $host_data;
        push @{$hosts}, keys %{$host_data};
        if($initialassumedhoststate == -1) {
            for my $hostname (keys %{$host_data}) {
                $initial_states->{'hosts'}->{$hostname} = $host_data->{$hostname}->{'state'};
            }
        }
    }

    # one or all hostgroups
    elsif(defined $hostgroup and $hostgroup ne '') {
        if($hostgroup ne '' and $hostgroup ne 'all') {
            $groupfilter       = "Filter: name = $hostgroup\n";
            $hostfilter        = "Filter: groups >= $hostgroup\n";
            $loghostheadfilter = "Filter: current_host_groups >= $hostgroup\n";
        }
        my $host_data = $c->{'live'}->selectall_hashref("GET hosts\n".Thruk::Utils::get_auth_filter($c, 'hosts')."\nColumns: name state\n$hostfilter", 'name' );
        my $groups    = $c->{'live'}->selectall_arrayref("GET hostgroups\n".Thruk::Utils::get_auth_filter($c, 'hostgroups')."\n$groupfilter\nColumns: name members", { Slice => {} });

        # join our groups together
        my %joined_groups;
        for my $group (@{$groups}) {
            my $name = $group->{'name'};
            if(!defined $joined_groups{$name}) {
                $joined_groups{$name}->{'name'}  = $group->{'name'};
                $joined_groups{$name}->{'hosts'} = {};
            }

            for my $hostname (split /,/mx, $group->{'members'}) {
                # show only hosts with proper authorization
                next unless defined $host_data->{$hostname};

                if(!defined $joined_groups{$name}->{'hosts'}->{$hostname}) {
                    $joined_groups{$name}->{'hosts'}->{$hostname} = 1;
                }
            }
            # remove empty groups
            if(scalar keys %{$joined_groups{$name}->{'hosts'}} == 0) {
                delete $joined_groups{$name};
            }
        }
        $c->stash->{'groups'} = \%joined_groups;
        $logserviceheadfilter = "Filter: service_description =\n";

        push @{$hosts}, keys %{$host_data};

        if($initialassumedhoststate == -1) {
            for my $hostname (keys %{$host_data}) {
                $initial_states->{'hosts'}->{$hostname} = $host_data->{$hostname}->{'state'};
            }
        }
    }


    # one or all servicegroups
    elsif(defined $servicegroup and $servicegroup ne '') {
        if($servicegroup ne '' and $servicegroup ne 'all') {
            $groupfilter          = "Filter: name = $servicegroup\n";
            $servicefilter        = "Filter: groups >= $servicegroup\n";
            $logserviceheadfilter = "Filter: current_service_groups >= $servicegroup\n";
        }
        my $all_services = $c->{'live'}->selectall_arrayref("GET services\n".$servicefilter.Thruk::Utils::get_auth_filter($c, 'services')."\nColumns: host_name description state host_state", { Slice => 1});
        my $groups       = $c->{'live'}->selectall_arrayref("GET servicegroups\n".Thruk::Utils::get_auth_filter($c, 'servicegroups')."\n$groupfilter\nColumns: name members", { Slice => {} });

        my $service_data;
        for my $service (@{$all_services}) {
            $service_data->{$service->{'host_name'}}->{$service->{'description'}} = 1;
        }

        # join our groups together
        my %joined_groups;
        for my $group (@{$groups}) {
            my $name = $group->{'name'};
            if(!defined $joined_groups{$name}) {
                $joined_groups{$name}->{'name'}     = $group->{'name'};
                $joined_groups{$name}->{'services'} = {};
            }

            for my $member (split /,/mx, $group->{'members'}) {
                my($hostname,$description) = split/\|/mx, $member, 2;
                # show only services with proper authorization
                next unless defined $service_data->{$hostname}->{$description};

                if(!defined $joined_groups{$name}->{'services'}->{$hostname}->{$description}) {
                    $joined_groups{$name}->{'services'}->{$hostname}->{$description} = 1;
                }
            }
            # remove empty groups
            if(scalar keys %{$joined_groups{$name}->{'services'}} == 0) {
                delete $joined_groups{$name};
            }
        }
        $c->stash->{'groups'} = \%joined_groups;

        my %tmp_hosts;
        for my $service (@{$all_services}) {
            $tmp_hosts{$service->{host_name}} = 1;
            push @{$services}, { 'host' => $service->{host_name}, 'service' => $service->{'description'} };
        }
        push @{$hosts}, keys %tmp_hosts;
        if($initialassumedservicestate == -1) {
            for my $service (@{$all_services}) {
                $initial_states->{'services'}->{$service->{host_name}}->{$service->{'description'}} = $service->{'state'};
            }
        }
        if($initialassumedhoststate == -1) {
            for my $service (@{$all_services}) {
                next if defined $initial_states->{'hosts'}->{$service->{host_name}};
                $initial_states->{'hosts'}->{$service->{host_name}} = $service->{'host_state'};
            }
        }
    } else {
        croak("unknown report type: ".Dumper($c->{'request'}->{'parameters'}));
    }


    ########################
    # fetch logs
    my(@loghostfilter,@logservicefilter);
    unless($service) {
        push @loghostfilter, "Filter: type = HOST ALERT\n".$softlogs;
        push @loghostfilter, "Filter: type = INITIAL HOST STATE\n".$softlogs;
        push @loghostfilter, "Filter: type = CURRENT HOST STATE\n".$softlogs;
    }
    push @loghostfilter, "Filter: type = HOST DOWNTIME ALERT\n";
    if($service or $host or $servicegroup) {
        push @logservicefilter, "Filter: type = SERVICE ALERT\n".$softlogs;
        push @logservicefilter, "Filter: type = INITIAL SERVICE STATE\n".$softlogs;
        push @logservicefilter, "Filter: type = CURRENT SERVICE STATE\n".$softlogs;
        push @logservicefilter, "Filter: type = SERVICE DOWNTIME ALERT\n";
    }
    my @typefilter;
    if(defined $loghostheadfilter) {
        push @typefilter, $loghostheadfilter.join("\n", @loghostfilter)."\nOr: ".(scalar @loghostfilter)."\nAnd: 2";
    } else {
        push @typefilter, join("\n", @loghostfilter)."\nOr: ".(scalar @loghostfilter)."\n";
    }
    if(scalar @logservicefilter > 0) {
        if(defined $logserviceheadfilter and defined $loghostheadfilter) {
            push @typefilter, $loghostheadfilter.$logserviceheadfilter."\nAnd: 2\n".join("\n", @logservicefilter)."\nOr: ".(scalar @logservicefilter)."\nAnd: 2";
        }
        elsif(defined $logserviceheadfilter) {
            push @typefilter, $logserviceheadfilter."\n".join("\n", @logservicefilter)."\nOr: ".(scalar @logservicefilter)."\nAnd: 2";
        }
        elsif(defined $loghostheadfilter) {
            push @typefilter, $loghostheadfilter."\n".join("\n", @logservicefilter)."\nOr: ".(scalar @logservicefilter)."\nAnd: 2";
        }
        else {
            push @typefilter, join("\n", @logservicefilter)."\nOr: ".(scalar @logservicefilter)."\n";
        }
    }
    push @typefilter, "Filter: class = 2\n"; # programm messages
    $logfilter .= join("\n", @typefilter)."\nOr: ".(scalar @typefilter);

    my $log_query = "GET log\n".$logfilter.Thruk::Utils::get_auth_filter($c, 'log')."\nColumns: class time type options state host_name service_description plugin_output";
    $c->log->debug($log_query);
    $c->stats->profile(begin => "avail.pm fetchlogs");
    $logs = $c->{'live'}->selectall_arrayref($log_query, { Slice => 1} );
    $c->stats->profile(end   => "avail.pm fetchlogs");

    #$Data::Dumper::Indent = 1;
    #open(FH, '>', '/tmp/logs.txt') or die("cannot open logs.txt: $!");
    ##print FH Dumper($logs);
    #for my $line (@{$logs}) {
    #    print FH '['.$line->{'time'}.'] '.$line->{'type'};
    #    print FH ': '.$line->{'options'} if(defined $line->{'options'} and $line->{'options'} ne '');
    #    print FH "\n";
    #}
    #close(FH);

    $c->stats->profile(begin => "calculate availability");
    my $ma = Monitoring::Availability->new(
        'rpttimeperiod'                => $rpttimeperiod,
        'assumeinitialstates'          => $assumeinitialstates,
        'assumestateretention'         => $assumestateretention,
        'assumestatesduringnotrunning' => $assumestatesduringnotrunning,
        'includesoftstates'            => $includesoftstates,
        'initialassumedhoststate'      => $self->_initialassumedhoststate_to_state($initialassumedhoststate),
        'initialassumedservicestate'   => $self->_initialassumedservicestate_to_state($initialassumedservicestate),
        'backtrack'                    => $backtrack,
#        'verbose'                      => 1,
#        'logger'                       => $c->log,
    );
    $c->stash->{avail_data} = $ma->calculate(
        'start'                        => $start,
        'end'                          => $end,
        'log_livestatus'               => $logs,
        'hosts'                        => $hosts,
        'services'                     => $services,
        'initial_states'               => $initial_states,
    );
    #$c->log->info(Dumper($c->stash->{avail_data}));
    $c->stats->profile(end => "calculate availability");

    if($full_log_entries) {
        $c->stash->{'logs'} = $ma->get_full_logs();
        #$c->log->debug("got full logs: ".Dumper($c->stash->{'logs'}));
    }
    elsif($show_log_entries) {
        $c->stash->{'logs'} = $ma->get_condensed_logs();
        #$c->log->debug("got condensed logs: ".Dumper($c->stash->{'logs'}));
    }

    $c->stats->profile(end => "got logs");

    # finished
    $c->stash->{time_token} = time() - $start_time;
    $c->stats->profile(end => "_create_report()");

    return 1;
}

##########################################################
sub _initialassumedhoststate_to_state {
    my $self                    = shift;
    my $initialassumedhoststate = shift;

    return 'unspecified' if $initialassumedhoststate ==  0; # Unspecified
    return 'current'     if $initialassumedhoststate == -1; # Current State
    return 'up'          if $initialassumedhoststate ==  3; # Host Up
    return 'down'        if $initialassumedhoststate ==  4; # Host Down
    return 'unreachable' if $initialassumedhoststate ==  5; # Host Unreachable
    croak('unknown state: '.$initialassumedhoststate);
}

##########################################################
sub _initialassumedservicestate_to_state {
    my $self                       = shift;
    my $initialassumedservicestate = shift;

    return 'unspecified' if $initialassumedservicestate ==  0; # Unspecified
    return 'current'     if $initialassumedservicestate == -1; # Current State
    return 'ok'          if $initialassumedservicestate ==  6; # Service Ok
    return 'warning'     if $initialassumedservicestate ==  8; # Service Warning
    return 'unknown'     if $initialassumedservicestate ==  7; # Service Unknown
    return 'critical'    if $initialassumedservicestate ==  9; # Service Critical
    croak('unknown state: '.$initialassumedservicestate);
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
