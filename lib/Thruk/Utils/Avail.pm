package Thruk::Utils::Avail;

=head1 NAME

Thruk::Utils::Avail - Utilities Collection for Availability Calculation

=head1 DESCRIPTION

Utilities Collection for Availability Calculation

=cut

use strict;
use warnings;
use Carp;
use Data::Dumper;
use File::Temp qw/tempfile/;
use File::Slurp qw/read_file/;
use POSIX ();
use Monitoring::Availability;
use Thruk::Utils::Log qw/:all/;

##############################################

=head1 METHODS

=head2 calculate_availability

  calculate_availability($c)

calculates the availability

=cut
sub calculate_availability {
    my($c)         = @_;
    my $start_time = time();

    Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 6, 'preparing logs') if $ENV{'THRUK_JOB_DIR'};

    my $host           = $c->req->parameters->{'host'};
    my $hostgroup      = $c->req->parameters->{'hostgroup'};
    my $service        = $c->req->parameters->{'service'};
    my $servicegroup   = $c->req->parameters->{'servicegroup'};

    if(defined $service and CORE::index($service, ';') > 0) {
        ($host,$service) = split/;/mx, $service;
        $c->stash->{host}    = $host;
        $c->stash->{service} = $service;
    }

    if(defined $host and $host eq 'null') { undef $host; }

    my $view_mode = $c->req->parameters->{'view_mode'} || 'html';
    if($view_mode eq 'csv') {
        $c->req->parameters->{'csvoutput'} = 1;
    }

    my $csvoutput = 0;
    $csvoutput = 1 if exists $c->req->parameters->{'csvoutput'};

    if(defined $hostgroup and $hostgroup ne '') {
        if($csvoutput) {
            $c->stash->{template}   = 'avail_report_hosts_csv.tt';
        } else {
            $c->stash->{template}   = 'avail_report_hostgroup.tt';
        }
    }
    elsif(defined $service and $service ne 'all') {
        if($csvoutput) {
            $c->stash->{template} = 'avail_report_services_csv.tt';
        } else {
            $c->stash->{template}   = 'avail_report_service.tt';
        }
    }
    elsif((defined $service and $service eq 'all') || $c->req->parameters->{s_filter}) {
        if($csvoutput) {
            $c->stash->{template} = 'avail_report_services_csv.tt';
        } else {
            $c->stash->{template} = 'avail_report_services.tt';
        }
    }
    elsif(defined $servicegroup and $servicegroup ne '') {
        if($csvoutput) {
            $c->stash->{template} = 'avail_report_services_csv.tt';
        } else {
            $c->stash->{template}   = 'avail_report_servicegroup.tt';
        }
    }
    elsif(defined $host and $host ne 'all') {
        if($csvoutput) {
            $c->stash->{template}   = 'avail_report_hosts_csv.tt';
        } else {
            $c->stash->{template}   = 'avail_report_host.tt';
        }
    }
    elsif((defined $host and $host eq 'all') || $c->req->parameters->{h_filter}) {
        if($csvoutput) {
            $c->stash->{template}   = 'avail_report_hosts_csv.tt';
        } else {
            $c->stash->{template}   = 'avail_report_hosts.tt';
        }
    }
    else {
        _error("unknown report type");
        return;
    }

    if($csvoutput) {
        $c->stash->{'res_ctype'}  = 'text/csv';
        $c->stash->{'res_header'} = [ 'Content-Disposition', 'attachment; filename="availability.csv"' ];
        delete $c->req->parameters->{'show_log_entries'};
        delete $c->req->parameters->{'full_log_entries'};
    }

    # get start/end from timeperiod in params
    my($start,$end) = Thruk::Utils::get_start_end_for_timeperiod_from_param($c);
    return $c->detach('/error/index/19') if (!defined $start || !defined $end);

    $c->stash->{start}      = $start;
    $c->stash->{end}        = $end;
    $c->stash->{t1}         = $c->req->parameters->{'t1'} || $start;
    $c->stash->{t2}         = $c->req->parameters->{'t2'} || $end;
    if(defined $c->req->parameters->{'timeperiod'}) {
        $c->stash->{timeperiod} = $c->req->parameters->{'timeperiod'};
    } elsif(!defined $c->req->parameters->{'t1'} && !defined $c->req->parameters->{'t2'}) {
        $c->stash->{timeperiod} = 'last24hours';
    } else {
        $c->stash->{timeperiod} = '';
    }

    my $rpttimeperiod                = $c->req->parameters->{'rpttimeperiod'} || '';
    my $assumeinitialstates          = $c->req->parameters->{'assumeinitialstates'};
    my $assumestateretention         = $c->req->parameters->{'assumestateretention'};
    my $assumestatesduringnotrunning = $c->req->parameters->{'assumestatesduringnotrunning'};
    my $includesoftstates            = $c->req->parameters->{'includesoftstates'};
    my $initialassumedhoststate      = $c->req->parameters->{'initialassumedhoststate'};
    my $initialassumedservicestate   = $c->req->parameters->{'initialassumedservicestate'};
    my $backtrack                    = $c->req->parameters->{'backtrack'};
    my $show_log_entries             = $c->req->parameters->{'show_log_entries'};
    my $full_log_entries             = $c->req->parameters->{'full_log_entries'};
    my $zoom                         = $c->req->parameters->{'zoom'};
    my $breakdown                    = $c->req->parameters->{'breakdown'} || '';

    # calculate zoom
    $zoom = 4 unless defined $zoom;
    $zoom =~ s/^\+//gmx;

    # default zoom is 4
    if($zoom !~ m/^(\-|)\d+$/mx) {
        $zoom = 4;
    }
    $zoom = 1 if $zoom == 0;

    # show_log_entries is true if it exists
    $show_log_entries = 1 if exists $c->req->parameters->{'show_log_entries'};

    # full_log_entries is true if it exists
    $full_log_entries = 1 if exists $c->req->parameters->{'full_log_entries'};

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

    $c->stash->{rpttimeperiod}                = $rpttimeperiod || '';
    $c->stash->{assumeinitialstates}          = $assumeinitialstates;
    $c->stash->{assumestateretention}         = $assumestateretention;
    $c->stash->{assumestatesduringnotrunning} = $assumestatesduringnotrunning;
    $c->stash->{includesoftstates}            = $includesoftstates;
    $c->stash->{initialassumedhoststate}      = $initialassumedhoststate;
    $c->stash->{initialassumedservicestate}   = $initialassumedservicestate;
    $c->stash->{backtrack}                    = $backtrack;
    $c->stash->{show_log_entries}             = $show_log_entries || '';
    $c->stash->{full_log_entries}             = $full_log_entries || '';
    $c->stash->{showscheduleddowntime}        = '';
    $c->stash->{zoom}                         = $zoom;
    $c->stash->{breakdown}                    = $breakdown;
    $c->stash->{servicegroupname}             = '';
    $c->stash->{hostgroupname}                = '';

    # get groups / hosts /services
    my $groupfilter;
    my $hostfilter;
    my $servicefilter;
    my $logserviceheadfilter;
    my $loghostheadfilter;
    my $initial_states = { 'hosts' => {}, 'services' => {} };

    # for which services do we need availability data?
    my $hosts    = [];
    my $services = [];

    my $softlogfilter;
    if(!$includesoftstates || $includesoftstates eq 'no') {
        # Somehow nagios can change from a Hard Critical into a Soft Critical which then results in a soft ok.
        # Any ok state always resets the current problem, so no matter if a ok is soft or hard, we have
        # to count it in. Otherwise we could end up with a critical last entry in the logfile, even if
        # the current state is ok.
        $softlogfilter = { -or => [ state_type => 'HARD', state => 0 ]};
    }

    my $logs;
    my $logstart = $start - $backtrack * 86400;
    _debug("logstart: ".$logstart." - ".(scalar localtime($logstart)));
    my $logfilter = {
        -and => [
            time => { '>=' => $logstart },
            time => { '<=' => $end },
    ]};

    # services
    $c->stash->{'services'} = {};
    if(defined $service || $c->req->parameters->{s_filter}) {
        my $all_services;
        my @servicefilter;
        my @hostfilter;
        if($c->req->parameters->{s_filter}) {
            $servicefilter = $c->req->parameters->{s_filter};
            $service       = 1;
        }
        elsif($service ne 'all') {
            $host = '*' if $host =~ m/^\s*$/mx;
            for my $h (split(/\s*,\s*/mx, $host)) {
                if($h =~ m/\*/mx) {
                    $h   =~ s/\.\*/\*/gmx;
                    $h   =~ s/\*/.*/gmx;
                    push @hostfilter, { 'host_name' => { '~~' => $h }};
                } else {
                    push @hostfilter, { 'host_name' => $h };
                }
            }
            $service = '*' if $service =~ m/^\s*$/mx;
            for my $s (split(/\s*,\s*/mx, $service)) {
                if($s =~ m/\*/mx) {
                    $s   =~ s/\.\*/\*/gmx;
                    $s   =~ s/\*/.*/gmx;
                    push @servicefilter, { 'description' => { '~~' => $s }};
                } else {
                    push @servicefilter, { 'description' => $s };
                }
            }
            $servicefilter = Thruk::Utils::combine_filter('-and', [
                Thruk::Utils::combine_filter('-or', \@hostfilter),
                Thruk::Utils::combine_filter('-or', \@servicefilter),
            ]);
        }
        $all_services = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter ]);
        die('no such service: '.($service||'')."\n".Dumper([ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter ])) unless scalar @{$all_services} > 0;
        my $services_data;
        for my $service (@{$all_services}) {
            $services_data->{$service->{'host_name'}}->{$service->{'description'}} = $service;
            push @{$services}, { 'host' => $service->{'host_name'}, 'service' => $service->{'description'} };
            if($initialassumedservicestate == -1) {
                $initial_states->{'services'}->{$service->{'host_name'}}->{$service->{'description'}} = $service->{'state'};
            }
        }
        if(scalar keys %{$services_data} == 0) {
            return $c->detach('/error/index/15');
        }
        $c->stash->{'services'} = $services_data;
        if(scalar @hostfilter == 0) {
            my $tmphosts = $c->{'db'}->get_hosts_by_servicequery(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter ]);
            # make uniq
            my %tmp;
            for my $host (@{$tmphosts}) {
                $tmp{$host->{'host_name'}} = 1;
            }
            for my $host (keys %tmp) {
                push @hostfilter, { 'host_name' => $host };
            }
        }
        $loghostheadfilter = Thruk::Utils::combine_filter('-or', \@hostfilter);
    }

    # single/multiple hosts
    elsif((defined $host and $host ne 'all') || $c->req->parameters->{h_filter}) {
        my @servicefilter;
        my @hostfilter;
        if($c->req->parameters->{h_filter}) {
            $hostfilter = $c->req->parameters->{h_filter};
        }
        else {
            for my $h (split(/\s*,\s*/mx, $host)) {
                if($h =~ m/\*/mx) {
                    $h   =~ s/\.\*/\*/gmx;
                    $h   =~ s/\*/.*/gmx;
                    push @hostfilter,    { 'name'      => { '~~' => $h }};
                    push @servicefilter, { 'host_name' => { '~~' => $h }};
                } else {
                    push @hostfilter,    { 'name'      => $h };
                    push @servicefilter, { 'host_name' => $h };
                }
            }
            if($c->req->parameters->{'include_host_services'}) {
                # host availability page includes services too, so
                # calculate service availability for services on these hosts too
                my $service_data = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), Thruk::Utils::combine_filter('-or', \@servicefilter) ]);
                for my $service (@{$service_data}) {
                    $c->stash->{'services'}->{$service->{'host_name'}}->{$service->{'description'}} = $service;
                    push @{$services}, { 'host' => $service->{'host_name'}, 'service' => $service->{'description'} };
                }

                if($initialassumedservicestate == -1) {
                    for my $service (@{$service_data}) {
                        $initial_states->{'services'}->{$service->{'host_name'}}->{$service->{'description'}} = $service->{'state'};
                    }
                }
            }
            $hostfilter        = Thruk::Utils::combine_filter('-or', \@hostfilter);
            $loghostheadfilter = Thruk::Utils::combine_filter('-or', \@servicefilter); # use service filter here, because log table needs the host_name => ... filter
        }

        my $host_data = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ]);
        die('no such host: '.($host||'')."\n".Dumper([ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ])) unless scalar @{$host_data} > 0;
        if($initialassumedhoststate == -1) {
            for my $host (@{$host_data}) {
                $initial_states->{'hosts'}->{$host->{'name'}} = $host->{'state'};
            }
        }
        for my $host (@{$host_data}) {
            push @{$hosts}, $host->{'name'};
        }
        $c->stash->{'hosts'} = Thruk::Utils::array2hash($host_data, 'name');
    }

    # all hosts
    elsif(defined $host and $host eq 'all') {
        my $host_data = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts') ]);
        die('no hosts found for all') unless scalar @{$host_data} > 0;
        $host_data    = Thruk::Utils::array2hash($host_data, 'name');
        push @{$hosts}, keys %{$host_data};
        $logserviceheadfilter = { service_description => undef };
        $c->stash->{'hosts'} = $host_data;
        if($initialassumedhoststate == -1) {
            for my $host (keys %{$host_data}) {
                $initial_states->{'hosts'}->{$host} = $host_data->{$host}->{'state'};
            }
        }
        if(scalar keys %{$host_data} == 0) {
            return $c->detach('/error/index/15');
        }
    }

    # multiple or all hostgroups
    elsif(defined $hostgroup and $hostgroup ne '') {
        my @hostfilter;
        my @servicefilter;
        my @groupfilter;
        if($hostgroup ne '' and $hostgroup ne 'all') {
            for my $hg (split(/\s*,\s*/mx, $hostgroup)) {
                push @hostfilter,       { groups      => { '>=' => $hg }};
                push @servicefilter,    { host_groups => { '>=' => $hg }};
                push @groupfilter,      { name        => $hg };
            }
            $hostfilter = Thruk::Utils::combine_filter('-or', \@hostfilter);
        }

        my $host_data = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ]);
        die('no host found for hostgroup: '.$hostgroup) unless scalar @{$host_data} > 0;
        $host_data    = Thruk::Utils::array2hash($host_data, 'name');
        if($hostgroup ne '' and $hostgroup ne 'all') {
            $groupfilter       = Thruk::Utils::combine_filter('-or', \@groupfilter);
            my @hosts_from_groups = ();
            for my $hostname (keys %{$host_data}) {
                push @hosts_from_groups, { host_name => $hostname };
            }
            $loghostheadfilter = Thruk::Utils::combine_filter('-or', \@hosts_from_groups);
        }
        my $groups = $c->{'db'}->get_hostgroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hostgroups'), $groupfilter ]);

        # join our groups together
        my %joined_groups;
        for my $group (@{$groups}) {
            my $name = $group->{'name'};
            if(!defined $joined_groups{$name}) {
                $joined_groups{$name}->{'name'}  = $group->{'name'};
                $joined_groups{$name}->{'hosts'} = {};
            }

            for my $hostname (@{$group->{'members'}}) {
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
        $c->stash->{'hosts'}  = $host_data;

        push @{$hosts}, keys %{$host_data};

        if($initialassumedhoststate == -1) {
            for my $hostname (keys %{$host_data}) {
                $initial_states->{'hosts'}->{$hostname} = $host_data->{$hostname}->{'state'};
            }
        }

        if($c->req->parameters->{'include_host_services'}) {
            # some pages includes services too, so
            # calculate service availability for services on these hosts too
            my $service_data = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), Thruk::Utils::combine_filter('-or', \@servicefilter) ]);
            for my $service (@{$service_data}) {
                $c->stash->{'services'}->{$service->{'host_name'}}->{$service->{'description'}} = $service;
                push @{$services}, { 'host' => $service->{'host_name'}, 'service' => $service->{'description'} };
            }

            if($initialassumedservicestate == -1) {
                for my $service (@{$service_data}) {
                    $initial_states->{'services'}->{$service->{'host_name'}}->{$service->{'description'}} = $service->{'state'};
                }
            }
        } else {
            $logserviceheadfilter = { service_description => undef };
        }
    }


    # multiple or all servicegroups
    elsif(defined $servicegroup and $servicegroup ne '') {
        my @servicefilter;
        my @groupfilter;
        if($servicegroup ne '' and $servicegroup ne 'all') {
            for my $sg (split(/\s*,\s*/mx, $servicegroup)) {
                push @servicefilter,    { groups => { '>=' => $sg }};
                push @groupfilter,      { name   => $sg };
            }
        }
        $groupfilter          = Thruk::Utils::combine_filter('-or', \@groupfilter);
        $servicefilter        = Thruk::Utils::combine_filter('-or', \@servicefilter);

        my $all_services = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter ]);
        my $groups       = $c->{'db'}->get_servicegroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'servicegroups'), $groupfilter ]);

        die('no such host/service') unless scalar @{$all_services} > 0;

        my $service_data;
        for my $service (@{$all_services}) {
            $service_data->{$service->{'host_name'}}->{$service->{'description'}} = $service;
        }
        $c->stash->{'services'} = $service_data;

        # join our groups together
        my %joined_groups;
        for my $group (@{$groups}) {
            my $name = $group->{'name'};
            if(!defined $joined_groups{$name}) {
                $joined_groups{$name}->{'name'}     = $group->{'name'};
                $joined_groups{$name}->{'services'} = {};
            }

            for my $member (@{$group->{'members'}}) {
                my($hostname,$description) = @{$member};
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

        # which services?
        if($servicegroup ne '' and $servicegroup ne 'all') {
            my @services_from_groups = ();
            for my $data (@{$services}) {
                push @services_from_groups, { '-and' => [ { host_name => $data->{'host'}}, { service_description => $data->{'service'}} ] };
            }
            $logserviceheadfilter = Thruk::Utils::combine_filter('-or', \@services_from_groups);
        }
    } else {
        croak("unknown report type: ".Dumper($c->req->parameters));
    }


    ########################
    # fetch logs
    my(@loghostfilter,@logservicefilter);
    unless($service) {
        push @loghostfilter, [ { type => 'HOST ALERT' }, $softlogfilter ];
        push @loghostfilter, [ { type => 'INITIAL HOST STATE' } , $softlogfilter ];
        push @loghostfilter, [ { type => 'CURRENT HOST STATE' }, $softlogfilter ];
    }
    push @loghostfilter, { type => 'HOST DOWNTIME ALERT' };
    if($service or $servicegroup or $c->req->parameters->{'include_host_services'}) {
        push @logservicefilter, [ { type => 'SERVICE ALERT' }, $softlogfilter ];
        push @logservicefilter, [ { type => 'INITIAL SERVICE STATE' }, $softlogfilter ];
        push @logservicefilter, [ { type => 'CURRENT SERVICE STATE' }, $softlogfilter ];
        push @logservicefilter, { type => 'SERVICE DOWNTIME ALERT' };
    }
    my @typefilter;
    if(defined $loghostheadfilter) {
        push @typefilter, { -and => [ $loghostheadfilter, { -or => [@loghostfilter] }]};
    } else {
        push @typefilter, { -or => [ @loghostfilter ] };
    }
    if(scalar @logservicefilter > 0) {
        if(defined $logserviceheadfilter and defined $loghostheadfilter) {
            push @typefilter, { -and => [ $loghostheadfilter, $logserviceheadfilter, { -or => [ @logservicefilter ] } ] };
        }
        elsif(defined $logserviceheadfilter) {
            push @typefilter, { -and => [ $logserviceheadfilter, { -or => [ @logservicefilter ] } ] };
        }
        elsif(defined $loghostheadfilter) {
            push @typefilter, { -and => [ $loghostheadfilter, { -or => [ @logservicefilter ] } ] };
        }
        else {
            push @typefilter, { -or => [ @logservicefilter ] };
        }
    }
    if($c->config->{'report_include_class2'} != 0) { # 0 means force - off
        if($c->config->{'report_include_class2'} == 2 # 2 means force on
           || ($c->config->{'report_include_class2'} == 1 # 1 means default auto
               && ($full_log_entries || $assumestatesduringnotrunning eq 'no'))
        ) {
            push @typefilter, { class => 2 }; # programm messages
        }
    }
    if($rpttimeperiod) {
        push @typefilter, { '-or' => [
                                      { message => { '~~' => 'TIMEPERIOD TRANSITION: '.$rpttimeperiod }},                               # livestatus
                                      { -and => [ {'type' => 'TIMEPERIOD TRANSITION' }, { 'message' => { '~~' => $rpttimeperiod }} ] }, # logcache
                                    ],
                          };
    }

    # make hosts uniq
    $hosts = Thruk::Utils::array_uniq($hosts);

    # ensure reports won't wrack our server
    my $total_nr = 0;
    $total_nr += scalar @{$hosts}    if defined $hosts;
    $total_nr += scalar @{$services} if defined $services;
    return(scalar @{$hosts}, scalar @{$services}) if $c->req->parameters->{'get_total_numbers_only'};
    if($total_nr > $c->config->{'report_max_objects'}) {
        die("too many objects: ".$total_nr.", maximum ".$c->config->{'report_max_objects'}.", please use more specific filter or raise limit (report_max_objects)!");
    }

    my $filter = [ $logfilter, { -or => [ @typefilter ] } ];

    if ($c->config->{'report_update_logcache'} == 1) {
        $c->stats->profile(begin => "avail.pm updatecache");
        Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 7, 'updating cache') if $ENV{'THRUK_JOB_DIR'};
        $c->{'db'}->renew_logcache($c, 1);
        $c->stats->profile(end   => "avail.pm updatecache");
    }

    Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 10, 'fetching logs') if $ENV{'THRUK_JOB_DIR'};

    # use tempfiles for reports > 14 days
    my $file = 0;
    if($c->config->{'report_use_temp_files'} and ($end - $logstart) / 86400 > $c->config->{'report_use_temp_files'}) {
        $file = 1;
    }

    $c->stats->profile(begin => "avail.pm fetchlogs");
    $logs = $c->{'db'}->get_logs(filter => $filter, columns => [ qw/time type message/ ], file => $file);
    $c->stats->profile(end   => "avail.pm fetchlogs");

    $file = fix_and_sort_logs($c, $logs, $file, $rpttimeperiod);

    Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 35, 'reading logs') if $ENV{'THRUK_JOB_DIR'};

    $c->stats->profile(begin => "calculate availability");
    my $ma = Monitoring::Availability->new();
    if(Thruk->debug) {
        $ma->{'verbose'} = 1;
        $ma->{'logger'}  = $c->log;
    }
    my $ma_options = {
        'start'                        => $start,
        'end'                          => $end,
        'log_livestatus'               => $logs,
        'hosts'                        => $hosts,
        'services'                     => $services,
        'initial_states'               => $initial_states,
        'rpttimeperiod'                => $rpttimeperiod,
        'assumeinitialstates'          => $assumeinitialstates,
        'assumestateretention'         => $assumestateretention,
        'assumestatesduringnotrunning' => $assumestatesduringnotrunning,
        'includesoftstates'            => $includesoftstates,
        'initialassumedhoststate'      => _initialassumedhoststate_to_state($initialassumedhoststate),
        'initialassumedservicestate'   => _initialassumedservicestate_to_state($initialassumedservicestate),
        'backtrack'                    => $backtrack,
        'breakdown'                    => $breakdown,
    };
    if($file) {
        delete $ma_options->{'log_livestatus'};
        $ma_options->{'log_file'} = $file;
    }
    $c->stash->{avail_data} = $ma->calculate(%{$ma_options});
    $c->stats->profile(end => "calculate availability");

    Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 75, 'finished calculation') if $ENV{'THRUK_JOB_DIR'};
    if($c->req->parameters->{'debug'}) {
        $c->stash->{'debug_info'} .= "\$ma_options\n";
        $c->stash->{'debug_info'} .= Dumper($ma_options);
        if($ma_options->{'log_file'}) {
            $c->stash->{'debug_info'} .= $ma_options->{'log_file'}.":\n";
            if(-s $ma_options->{'log_file'} < (1024*1024*100)) { # append files smaller than 100MB
                $c->stash->{'debug_info'} .= read_file($ma_options->{'log_file'});
            } else {
                $c->stash->{'debug_info'} .= sprintf("file too large (%.2fMB)\n", (-s $ma_options->{'log_file'})/1024/1024);
            }
        }
    } else {
        unlink($file) if $file;
    }

    if($c->req->parameters->{'outages'}) {
        $c->stash->{'service'}       = $service // "";
        $c->stash->{'host'}          = $host;
        $c->stash->{'withdowntimes'} = $c->req->parameters->{'withdowntimes'} // 0;
        $c->stash->{'template'} = 'avail_outages.tt';
        my $only_host_services = undef;
        my $unavailable_states = {
            critical             => 1,
            down                 => 1,
            unreachable          => 1,
        };
        if($c->stash->{'withdowntimes'} == 0) {
            for my $key (keys %{$unavailable_states}) {
                $unavailable_states->{$key.'_downtime'} = 1;
            }
        }
        my $logs = $ma->get_full_logs() || [];
        my $outages = outages($logs, $unavailable_states, $start, $end, $host, $service, $only_host_services);
        $c->stash->{'outages'} = $outages;
        return;
    }

    $c->stats->profile(begin => "got logs");
    if($full_log_entries) {
        $c->stash->{'logs'} = $ma->get_full_logs() || [];
    }
    elsif($show_log_entries) {
        $c->stash->{'logs'} = $ma->get_condensed_logs() || [];
    }
    $c->stats->profile(end => "got logs");

    # csv output needs host list
    if($csvoutput or $view_mode eq 'xls') {
        if(!defined $c->stash->{'hosts'}) {
            $c->stash->{'hosts'} = $c->stash->{'avail_data'}->{'hosts'};
        }
        if(!defined $c->stash->{'services'} || scalar keys %{$c->stash->{'services'}} == 0) {
            $c->stash->{'services'} = $c->stash->{'avail_data'}->{'services'};
        }
    }

    # finished
    $c->stash->{time_token} = time() - $start_time;

    my $return = {
        'avail' => $c->stash->{'avail_data'},
        'logs'  => $c->stash->{'logs'},
        'start' => $c->stash->{'start'},
        'end'   => $c->stash->{'end'},
    };

    # json export
    if($view_mode eq 'json') {
        $c->stash->{'json'} = $return;
    }
    if( $view_mode eq 'xls' ) {
        $c->stash->{'file_name'}  = 'availability.xls';
        $c->stash->{'name'}       = 'Availability';
        $c->stash->{'template'}  = 'excel/availability.tt';
        if(defined $c->stash->{job_id}) {
            # store resulting xls in file, forked reports cannot handle detaches
            Thruk::Utils::savexls($c);
        } else {
            $c->res->headers->header('Content-Disposition', 'attachment; filename="'.$c->stash->{'file_name'}.'"');
            delete $c->stash->{'file_name'}; # iritates the finished job page
            return $c->render_excel();
        }
    }

    return $return;
}

##############################################

=head2 fix_and_sort_logs

  fix_and_sort_logs($c, $logs, $file, $rpttimeperiod, $sort)

fixes livestatus timeperiod change timestamps which can differ up to a minute
from the real date

=cut
sub fix_and_sort_logs {
    my($c, $logs, $file, $rpttimeperiod, $sort) = @_;

    Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 25, 'sorting logs') if $ENV{'THRUK_JOB_DIR'};

    $sort = 'asc' unless $sort;
    $sort = lc $sort;
    $sort = 'asc' unless $sort eq 'desc';

    # fix timestamps of timeperiod transitions
    if($logs and ref $logs eq 'ARRAY') {
        @{$logs} = reverse @{$logs} if $sort eq 'desc';
        return($file) unless $rpttimeperiod;
        $c->stats->profile(begin => "avail.pm fix timeperiod transitions timestamps");
        for my $l (@{$logs}) {
            if($l->{'type'} && $l->{'type'} eq 'TIMEPERIOD TRANSITION') {
                $l->{'time'} = POSIX::floor(($l->{'time'}+30)/120) * 120;
            }
        }
        $c->stats->profile(end => "avail.pm fix timeperiod transitions timestamps");
        return($file);
    }
    elsif($file and ref $logs eq 'HASH') {
        my($fh,$tempfile) = tempfile();
        my $sort_add = '';
        $sort_add = '-r' if $sort eq 'desc';
        if($rpttimeperiod) {
            Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 25, 'fixing logs') if $ENV{'THRUK_JOB_DIR'};
            $c->stats->profile(begin => "avail.pm sort fix logs");
            for my $fname (values %{$logs}) {
                open(my $fh2, '<', $fname) or die("cannot open file $fname: $!");
                while(my $line = <$fh2>) {
                    if($line =~ m/^\[(\d+)\]\ TIMEPERIOD\ TRANSITION:(.*)/mxo) {
                        my $t = POSIX::floor(($1+30)/120) * 120;
                        print $fh '['.$t.'] TIMEPERIOD TRANSITION:'.$2."\n";
                    } else {
                        print $fh $line;
                    }
                }
                CORE::close($fh2);
                unlink($fname);
            }
            CORE::close($fh);
            $c->stats->profile(end   => "avail.pm sort fix logs");

            $c->stats->profile(begin => "avail.pm sort logs");
            Thruk::Utils::External::update_status($ENV{'THRUK_JOB_DIR'}, 30, 'sorting logs') if $ENV{'THRUK_JOB_DIR'};
            my $cmd = 'sort -k 1,12 '.$sort_add.' -o '.$tempfile.'2 '.$tempfile;
            Thruk::Utils::IO::cmd($cmd);
            unlink($tempfile);
            $file = $tempfile.'2';
            $c->stats->profile(end   => "avail.pm sort logs");
        } else {
            # use short file handling if no timeperiods have to be altered
            $c->stats->profile(begin => "avail.pm sort logs");
            my $cmd = 'sort -k 1,12 '.$sort_add.' -o '.$tempfile.' '.join(' ', values %{$logs});
            Thruk::Utils::IO::cmd($cmd);
            unlink(values %{$logs});
            $file = $tempfile;
            $c->stats->profile(end   => "avail.pm sort logs");
        }
    }
    return($file);
}

##############################################

=head2 reset_req_parameters

  reset_req_parameters($c)

removes all parameters used for availability calculation from c->request->parameters

=cut

sub reset_req_parameters {
    my($c) = @_;
    delete $c->req->parameters->{h_filter};
    delete $c->req->parameters->{s_filter};
    delete $c->req->parameters->{filter};
    delete $c->req->parameters->{host};
    delete $c->req->parameters->{hostgroup};
    delete $c->req->parameters->{service};
    delete $c->req->parameters->{servicegroup};

    delete $c->req->parameters->{view_mode};
    delete $c->req->parameters->{csvoutput};
    delete $c->req->parameters->{show_log_entries};
    delete $c->req->parameters->{full_log_entries};
    delete $c->req->parameters->{timeperiod};
    delete $c->req->parameters->{rpttimeperiod};
    delete $c->req->parameters->{assumeinitialstates};
    delete $c->req->parameters->{assumestateretention};
    delete $c->req->parameters->{assumestatesduringnotrunning};
    delete $c->req->parameters->{includesoftstates};
    delete $c->req->parameters->{initialassumedhoststate};
    delete $c->req->parameters->{initialassumedservicestate};
    delete $c->req->parameters->{backtrack};
    delete $c->req->parameters->{show_log_entries};
    delete $c->req->parameters->{full_log_entries};
    delete $c->req->parameters->{zoom};
    delete $c->req->parameters->{breakdown};
    delete $c->req->parameters->{include_host_services};
    delete $c->req->parameters->{get_total_numbers_only};

    return;
}

##########################################################

=head2 get_availability_percents

  get_availability_percents($avail_data, $unavailable_states, $host, $service)

return list of availability percent as json list

=cut
sub get_availability_percents {
    my($avail_data, $unavailable_states, $host, $service) = @_;
    confess("No host") unless defined $host;

    my $avail;
    if($service) {
        $avail = $avail_data->{'services'}->{$host}->{$service};
    } else {
        $avail = $avail_data->{'hosts'}->{$host};
    }
    return unless defined $avail;

    my $u = $unavailable_states;
    my $values = {};
    for my $name (sort keys %{$avail->{'breakdown'}}) {
        my $t = $avail->{'breakdown'}->{$name};

        #my($percent, $time)
        my($percent, undef) = _sum_availability($t, $u);
        confess('corrupt breakdowns: '.Dumper($name, $avail->{'breakdown'})) unless defined $t->{'timestamp'};
        $values->{$name} = [
            $t->{'timestamp'}*1000,
            $percent,
        ];
    }

    my $x = 1;
    my $json = {keys => [], values => [], tvalues => []};
    $json->{'total'}->{'breakdown'} = {};
    my $breakdown = {};
    for my $key (sort keys %{$values}) {
        push @{$json->{'keys'}},    [$x, $key];
        push @{$json->{'values'}},  [$x, $values->{$key}->[1]+=0 ];
        push @{$json->{'tvalues'}}, [$values->{$key}->[0], $values->{$key}->[1]+=0 ];
        $breakdown->{$key} = $values->{$key}->[1] += 0;
        $x++;
    }

    my($percent, $time) = _sum_availability($avail, $u);
    $json->{'total'} = {
        'percent'   => $percent,
        'time'      => $time,
        'breakdown' => $breakdown,
    };
    return $json;
}

##########################################################

=head2 outages

  outages($c, $logs, $unavailable_states, $start, $end, $host, $service, $only_host_services)

return combined outages from log entries

=cut
sub outages {
    my($logs, $unavailable_states, $start, $end, $host, $service, $only_host_services) = @_;
    my $u = $unavailable_states;

    # combine outages
    my @reduced_logs;
    my($current, $last, $current_state);
    my $in_timeperiod  = 1;

    for my $l (@{$logs}) {
        if($only_host_services) {
            next if  $l->{'host'} ne $host;
            next if !$l->{'service'};
        } else {
            if($service) {
                next if(defined $l->{'service'} and $l->{'service'} ne $service);
                next if(defined $l->{'host'}    and $l->{'host'}    ne $host);
            } else {
                next if(defined $l->{'host'}    and $l->{'host'}    ne $host);
            }
        }

        if($l->{'type'} eq 'TIMEPERIOD START') {
            $in_timeperiod = 1;
        }
        elsif($l->{'type'} eq 'TIMEPERIOD STOP') {
            $in_timeperiod = 0;
            if($current) {
                $current->{'real_end'} = $l->{'start'};
                push @reduced_logs, $current if $in_timeperiod;
                undef $current;
            }
            next;
        }

        # set current state
        $l->{'class'} = lc $l->{'class'};
        if($current_state && $l->{'class'} eq 'indeterminate') {
            if($current_state->{'class'} ne 'indeterminate') {
                for my $key (qw/class host service plugin_output type/) {
                    $l->{$key} = $current_state->{$key};
                }
            }
        } else {
            $current_state = $l;
        }

        # are we currently in the middle of an outage
        my $in_outage = 0;
        if($in_timeperiod) {
            if($l->{'in_downtime'}) {
                if($u->{$l->{'class'}.'_downtime'}) {
                    $in_outage = 1;
                }
            } else {
                if($u->{$l->{'class'}}) {
                    $in_outage = 1;
                }
            }
        }

        # end of current outage
        if($current && !$in_outage) {
            $current->{'real_end'} = $l->{'start'};
            push @reduced_logs, $current if $in_timeperiod;
            undef $current;
            next;
        }

        # start of new outage
        if(!$current && $in_outage) {
            $last    = $l;
            $current = $l;
            next;
        }

        if($current && $l->{'class'} ne 'indeterminate') {
            $current->{'class'} = $l->{'class'};
        }
        $last = $l;
    }
    if($current && $last) {
        $current->{'real_end'} = $last->{'end'};
        push @reduced_logs, $current if $in_timeperiod;
    }

    my $outages = [];
    for my $l (reverse @reduced_logs) {
        next if $end   < $l->{'start'};
        next if $start > $l->{'real_end'};
        $l->{'start'}    = $start if $start > $l->{'start'};
        $l->{'real_end'} = $end   if $end   < $l->{'real_end'};
        $l->{'duration'} = $l->{'real_end'} - $l->{'start'};
        if($l->{'real_end'} > $l->{'end'} && $l->{'real_end'} > time()) {
            $l->{'end'} = ""; # not yet ended
        } else {
            $l->{'end'} = $l->{'real_end'};
        }
        delete $l->{'real_end'};
        if($l->{'duration'} > 0) {
            push @{$outages}, $l;
        }
    }

    return $outages;
}

##############################################
sub _sum_availability {
    my($t, $u) = @_;
    my $time = {
        'available'                             => 0,
        'unavailable'                           => 0,
        'time_indeterminate_notrunning'         => $t->{'time_indeterminate_notrunning'}         || 0,
        'time_indeterminate_nodata'             => $t->{'time_indeterminate_nodata'}             || 0,
        'time_indeterminate_outside_timeperiod' => $t->{'time_indeterminate_outside_timeperiod'} || 0,
    };

    for my $s ( keys %{$t} ) {
        for my $state (qw/ok warning critical unknown up down unreachable/) {
            if($s eq 'time_'.$state) {
                if(defined $u->{$state}) {
                    $time->{'unavailable'} += $t->{'time_'.$state} - $t->{'scheduled_time_'.$state};
                } else {
                    $time->{'available'}   += $t->{'time_'.$state} - $t->{'scheduled_time_'.$state};
                }
            }
            elsif($s eq 'scheduled_time_'.$state) {
                if(defined $u->{$state.'_downtime'}) {
                    $time->{'unavailable'} += $t->{'scheduled_time_'.$state};
                } else {
                    $time->{'available'}   += $t->{'scheduled_time_'.$state};
                }
            }
        }
    }

    my $percent = -1;
    if($time->{'available'} + $time->{'unavailable'} > 0) {
        $percent = $time->{'available'} / ($time->{'available'} + $time->{'unavailable'}) * 100;
    }
    return($percent, $time);
}

##############################################

=head2 _initialassumedhoststate_to_state

  _initialassumedhoststate_to_state($state)

translate initial assumed host state to text

=cut
sub _initialassumedhoststate_to_state {
    my($initialassumedhoststate) = @_;

    return 'unspecified' if $initialassumedhoststate ==  0; # Unspecified
    return 'current'     if $initialassumedhoststate == -1; # Current State
    return 'up'          if $initialassumedhoststate ==  3; # Host Up
    return 'down'        if $initialassumedhoststate ==  4; # Host Down
    return 'unreachable' if $initialassumedhoststate ==  5; # Host Unreachable
    croak('unknown state: '.$initialassumedhoststate);
}

##############################################

=head2 _initialassumedservicestate_to_state

  _initialassumedservicestate_to_state($state)

translate initial assumed service state to text

=cut
sub _initialassumedservicestate_to_state {
    my($initialassumedservicestate) = @_;

    return 'unspecified' if $initialassumedservicestate ==  0; # Unspecified
    return 'current'     if $initialassumedservicestate == -1; # Current State
    return 'ok'          if $initialassumedservicestate ==  6; # Service Ok
    return 'warning'     if $initialassumedservicestate ==  8; # Service Warning
    return 'unknown'     if $initialassumedservicestate ==  7; # Service Unknown
    return 'critical'    if $initialassumedservicestate ==  9; # Service Critical
    croak('unknown state: '.$initialassumedservicestate);
}

##############################################

1;
