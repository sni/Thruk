package Thruk::Utils;

=head1 NAME

Thruk::Utils - Utilities Collection for Thruk

=head1 DESCRIPTION

Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Config::General;
use Carp;
use Data::Dumper;
use Date::Calc qw/Localtime Mktime Monday_of_Week Week_of_Year Today Normalize_DHMS/;
use Date::Manip;
use File::Slurp;
use Encode qw/decode/;
use Template::Plugin::Date;
use File::Copy;


##############################################
=head1 METHODS

=head2 parse_date

  my $timestamp = parse_date($c, $string)

Format: 2010-03-02 00:00:00
parse given date and return timestamp

=cut
sub parse_date {
    my $c      = shift;
    my $string = shift;
    my $timestamp;
    eval {
        if($string =~ m/(\d{4})\-(\d{2})\-(\d{2})\ (\d{2}):(\d{2}):(\d{2})/mx) {
            $timestamp = Mktime($1,$2,$3, $4,$5,$6);
            $c->log->debug("parse_date: '".$string."' to -> '".(scalar localtime $timestamp)."'");
        }
        else {
            $timestamp = UnixDate($string, '%s');
            if(!defined $timestamp) {
                return $c->detach('/error/index/19');
            }
            $c->log->debug("parse_date: '".$string."' to -> '".(scalar localtime $timestamp)."'");
        }
    };
    if($@) {
        $c->log->error($@);
        return $c->detach('/error/index/19');
    }
    return $timestamp;
}


##############################################

=head2 format_date

  my $date_string = format_date($string, $format)

return date from timestamp in given format

=cut
sub format_date {
    my $timestamp = shift;
    my $format    = shift;
    my $tpd  = Template::Plugin::Date->new();
    my $date = $tpd->format($timestamp, $format);
    return decode("utf-8", $date);
}


######################################

=head2 read_cgi_cfg

  read_cgi_cfg($c);

parse the cgi.cfg and put it into $c->config

=cut
sub read_cgi_cfg {
    my $c      = shift;
    my $config = shift;
    if(defined $c) {
        $config = $c->config;
    }

    $c->stats->profile(begin => "Utils::read_cgi_cfg()") if defined $c;

    # read only if its changed
    my $file = $config->{'cgi.cfg'};
    if(!defined $file or $file eq '') {
        $config->{'cgi_cfg'} = 'undef';
        if(defined $c) {
            $c->log->error("cgi.cfg not set");
            $c->error("cgi.cfg not set");
            return $c->detach('/error/index/4');
        }
        print STDERR "cgi.cfg option must be set in thruk.conf or thruk_local.conf\n\n";
        return;
    }
    elsif( -r $file ) {
        # perfect, file exists and is readable
    }
    elsif(-r $config->{'project_root'}.'/'.$file) {
        $file = $config->{'project_root'}.'/'.$file;
    }
    else {
        if(defined $c) {
            $c->log->error("cgi.cfg not readable: ".$!);
            $c->error("cgi.cfg not readable: ".$!);
            return $c->detach('/error/index/4');
        }
        print STDERR "$file not readable: ".$!."\n\n";
        return;
    }

    # (dev,ino,mode,nlink,uid,gid,rdev,size,atime,mtime,ctime,blksize,blocks)
    my @cgi_cfg_stat = stat($file);

    my $last_stat = $config->{'cgi_cfg_stat'};
    if(!defined $last_stat
       or $last_stat->[1] != $cgi_cfg_stat[1] # inode changed
       or $last_stat->[9] != $cgi_cfg_stat[9] # modify time changed
      ) {
        $c->log->info("cgi.cfg has changed, updating...") if defined $last_stat;
        $c->log->debug("reading $file") if defined $c;
        $config->{'cgi_cfg_stat'} = \@cgi_cfg_stat;
        $config->{'cgi.cfg_effective'} = $file;
        my $conf = new Config::General($file);
        %{$config->{'cgi_cfg'}} = $conf->getall;
    }

    $c->stats->profile(end => "Utils::read_cgi_cfg()") if defined $c;

    return 1;
}


######################################

=head2 is_valid_regular_expression

  my $result = is_valid_regular_expression($expression)

return true if this is a valid regular expression

=cut
sub is_valid_regular_expression {
    my $c          = shift;
    my $expression = shift;
    return 1 unless defined $expression;
    local $SIG{__DIE__} = '';
    eval { "test" =~ m/$expression/mx; };
    if($@) {
        my $error_message = "invalid regular expression: ".$@;
        $error_message =~ s/\s+at\s+.*$//gmx;
        $error_message =~ s/in\s+regex\;/in regex<br \/>/gmx;
        $error_message =~ s/HERE\s+in\s+m\//HERE in <br \/>/gmx;
        $error_message =~ s/\/$//gmx;
        set_message($c, 'fail_message', $error_message);
        return;
    }
    return 1;
}


########################################

=head2 calculate_overall_processinfo

  my $process_info = calculate_overall_processinfo($process_info)

computes a combined status for process infos

=cut
sub calculate_overall_processinfo {
    my $pi = shift;
    my $return = {};

    # if no backend is available
    return($return) if ref $pi ne 'HASH';

    for my $peer (keys %{$pi}) {
        for my $key (keys %{$pi->{$peer}}) {
            my $value = $pi->{$peer}->{$key};
            if($value eq "0" or $value eq "1") {
                if(!defined $return->{$key}) {
                    $return->{$key} = $value;
                }elsif($return->{$key} == -1) {
                    # do nothing, result already varies
                }elsif($return->{$key} == $value) {
                    # do nothing, result is the same
                }elsif($return->{$key} != $value) {
                    # set result to vary
                    $return->{$key} = -1;
                }
            }
        }
    }
    return($return);
}


########################################

=head2 get_start_end_for_timeperiod

  my($start, $end) = get_start_end_for_timeperiod($c,
                                                  $timeperiod,
                                                  $smon,
                                                  $sday,
                                                  $syear,
                                                  $shour,
                                                  $smin,
                                                  $ssec,
                                                  $emon,
                                                  $eday,
                                                  $eyear,
                                                  $ehour,
                                                  $emin,
                                                  $esec,
                                                  $t1,
                                                  $t2);

returns a start and end timestamp for a report date definition

=cut
sub get_start_end_for_timeperiod {
    my($c,$timeperiod,$smon,$sday,$syear,$shour,$smin,$ssec,$emon,$eday,$eyear,$ehour,$emin,$esec,$t1,$t2) = @_;

    my $start;
    my $end;
    $timeperiod = 'custom' unless defined $timeperiod;
    if($timeperiod eq 'today') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        $start = Mktime($year,$month,$day,  0,0,0);
        $end   = time();
    }
    elsif($timeperiod eq 'last24hours') {
        $end   = time();
        $start = $end - 86400;
    }
    elsif($timeperiod eq 'yesterday') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        $start = Mktime($year,$month,$day,  0,0,0) - 86400;
        $end   = $start + 86400;
    }
    elsif($timeperiod eq 'thisweek') {
        # start on last sunday 0:00 till now
        my @today  = Today();
        my @monday = Monday_of_Week(Week_of_Year(@today));
        $start     = Mktime(@monday,  0,0,0) - 86400;
        $end       = time();
    }
    elsif($timeperiod eq 'last7days') {
        $end   = time();
        $start = $end - 7 * 86400;
    }
    elsif($timeperiod eq 'lastweek') {
        # start on last weeks sunday 0:00 till last weeks saturday 24:00
        my @today  = Today();
        my @monday = Monday_of_Week(Week_of_Year(@today));
        $end       = Mktime(@monday,  0,0,0) - 86400;
        $start     = $end - 7*86400;
    }
    elsif($timeperiod eq 'thismonth') {
        # start on first till now
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        $start = Mktime($year,$month,1,  0,0,0);
        $end   = time();
    }
    elsif($timeperiod eq 'last31days') {
        $end   = time();
        $start = $end - 31 * 86400;
    }
    elsif($timeperiod eq 'lastmonth') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        $end   = Mktime($year,$month,1,  0,0,0);
        my $lastmonth = $month - 1;
        if($lastmonth <= 0) { $lastmonth = $lastmonth + 12; $year--;}
        $start = Mktime($year,$lastmonth,1,  0,0,0);
    }
    elsif($timeperiod eq 'thisyear') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        $start = Mktime($year,1,1,  0,0,0);
        $end   = time();
    }
    elsif($timeperiod eq 'lastyear') {
        my($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        $start = Mktime($year-1,1,1,  0,0,0);
        $end   = Mktime($year,1,1,  0,0,0);
    }
    else {
        if(defined $t1) {
            $start = $t1;
        } else {
            $start = normal_mktime($syear,$smon,$sday, $shour,$smin,$ssec);
        }

        if(defined $t2) {
            $end   = $t2;
        } else {
            $end   = normal_mktime($eyear,$emon,$eday, $ehour,$emin,$esec);
        }
    }

    if(!defined $start or !defined $end) {
        return(undef, undef);
    }

    $c->log->debug("start: ".$start." - ".(scalar localtime($start)));
    $c->log->debug("end  : ".$end." - ".(scalar localtime($end)));

    if($end >= $start) {
        return($start, $end);
    }
    return($end, $start);
}


########################################

=head2 get_start_end_for_timeperiod_from_param

  my($start, $end) = get_start_end_for_timeperiod_from_param($c)

returns a start and end timestamp for a report date definition
will use cgi params for input

=cut
sub get_start_end_for_timeperiod_from_param {
    my $c = shift;

    confess("no c") unless defined($c);

    # get timeperiod
    my $timeperiod   = $c->{'request'}->{'parameters'}->{'timeperiod'};
    my $smon         = $c->{'request'}->{'parameters'}->{'smon'};
    my $sday         = $c->{'request'}->{'parameters'}->{'sday'};
    my $syear        = $c->{'request'}->{'parameters'}->{'syear'};
    my $shour        = $c->{'request'}->{'parameters'}->{'shour'}  || 0;
    my $smin         = $c->{'request'}->{'parameters'}->{'smin'}   || 0;
    my $ssec         = $c->{'request'}->{'parameters'}->{'ssec'}   || 0;
    my $emon         = $c->{'request'}->{'parameters'}->{'emon'};
    my $eday         = $c->{'request'}->{'parameters'}->{'eday'};
    my $eyear        = $c->{'request'}->{'parameters'}->{'eyear'};
    my $ehour        = $c->{'request'}->{'parameters'}->{'ehour'}  || 0;
    my $emin         = $c->{'request'}->{'parameters'}->{'emin'}   || 0;
    my $esec         = $c->{'request'}->{'parameters'}->{'esec'}   || 0;
    my $t1           = $c->{'request'}->{'parameters'}->{'t1'};
    my $t2           = $c->{'request'}->{'parameters'}->{'t2'};

    $timeperiod = 'last24hours' if(!defined $timeperiod and !defined $t1 and !defined $t2);
    return Thruk::Utils::get_start_end_for_timeperiod($c, $timeperiod,$smon,$sday,$syear,$shour,$smin,$ssec,$emon,$eday,$eyear,$ehour,$emin,$esec,$t1,$t2);
}

########################################

=head2 set_can_submit_commands

  set_can_submit_commands($c)

sets the is_authorized_for_read_only role

=cut
sub set_can_submit_commands {
    my $c = shift;

    $c->stats->profile(begin => "Thruk::Utils::set_can_submit_commands");
    my $username = $c->request->{'user'}->{'username'};

    # is the contact allowed to send commands?
    my($can_submit_commands,$alias,$data);
    my $cache = $c->cache;
    my $cached_data = $cache->get($username);
    if(defined $cached_data->{'can_submit_commands'}) {
        # got cached data
        $data = $cached_data->{'can_submit_commands'};
    }
    else {
        $data = $c->{'db'}->get_can_submit_commands($username);
        $cached_data->{'can_submit_commands'} = $data;
        $cache->set($username, $cached_data);
    }

    if(defined $data) {
        for my $dat (@{$data}) {
            $alias               = $dat->{'alias'}               if defined $dat->{'alias'};
            $can_submit_commands = $dat->{'can_submit_commands'} if defined $dat->{'can_submit_commands'};
        }
    }

    if(defined $alias) {
        $c->request->{'user'}->{'alias'} = $alias;
    }
    if(!defined $can_submit_commands) {
        $can_submit_commands = Thruk->config->{'can_submit_commands'} || 0;
    }

    # override can_submit_commands from cgi.cfg
    if(grep /authorized_for_all_host_commands/mx, @{$c->request->{'user'}->{'roles'}}) {
        $can_submit_commands = 1;
    }
    elsif(grep /authorized_for_all_service_commands/mx, @{$c->request->{'user'}->{'roles'}}) {
        $can_submit_commands = 1;
    }
    elsif(grep /authorized_for_system_commands/mx, @{$c->request->{'user'}->{'roles'}}) {
        $can_submit_commands = 1;
    }

    $c->log->debug("can_submit_commands: $can_submit_commands");
    if($can_submit_commands != 1) {
        push @{$c->request->{'user'}->{'roles'}}, 'is_authorized_for_read_only';
    }

    $c->stats->profile(end => "Thruk::Utils::set_can_submit_commands");
    return 1;
}


########################################

=head2 calculate_availability

  calculate_availability($c)

calculates the availability

=cut
sub calculate_availability {
    my $c    = shift;

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

    my $csvoutput = 0;
    $csvoutput = 1 if exists $c->{'request'}->{'parameters'}->{'csvoutput'};

    if(defined $hostgroup and $hostgroup ne '') {
        $c->stash->{template}   = 'avail_report_hostgroup.tt';
    }
    elsif(defined $service and $service ne 'all') {
        $c->stash->{template}   = 'avail_report_service.tt';
    }
    elsif(defined $service and $service eq 'all') {
        if($csvoutput) {
            $c->stash->{template} = 'avail_report_services_csv.tt';
        } else {
            $c->stash->{template} = 'avail_report_services.tt';
        }
    }
    elsif(defined $servicegroup and $servicegroup ne '') {
        $c->stash->{template}   = 'avail_report_servicegroup.tt';
    }
    elsif(defined $host and $host ne 'all') {
        $c->stash->{template}   = 'avail_report_host.tt';
    }
    elsif(defined $host and $host eq 'all') {
        if($csvoutput) {
            $c->stash->{template}   = 'avail_report_hosts_csv.tt';
        } else {
            $c->stash->{template}   = 'avail_report_hosts.tt';
        }
    }
    else {
        $c->log->error("unknown report type");
        return;
    }

    if($csvoutput) {
        $c->response->header('Content-Type' => 'text/plain');
        delete $c->{'request'}->{'parameters'}->{'show_log_entries'};
        delete $c->{'request'}->{'parameters'}->{'full_log_entries'};
    }

    # get start/end from timeperiod in params
    my($start,$end) = Thruk::Utils::get_start_end_for_timeperiod_from_param($c);
    return $c->detach('/error/index/19') if (!defined $start or !defined $end);

    $c->stash->{start}      = $start;
    $c->stash->{end}        = $end;
    if(defined $c->{'request'}->{'parameters'}->{'timeperiod'}) {
        $c->stash->{timeperiod} = $c->{'request'}->{'parameters'}->{'timeperiod'};
    } elsif(!defined $c->{'request'}->{'parameters'}->{'t1'} and !defined $c->{'request'}->{'parameters'}->{'t2'}) {
        $c->stash->{timeperiod} = 'last24hours';
    } else {
        $c->stash->{timeperiod} = '';
    }

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
    my $zoom                         = $c->{'request'}->{'parameters'}->{'zoom'};

    # calculate zoom
    $zoom = 4 unless defined $zoom;
    $zoom =~ s/^\+//gmx;

    # default zoom is 4
    if($zoom !~ m/^(\-|)\d+$/mx) {
        $zoom = 4;
    }
    $zoom = 1 if $zoom == 0;

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
    my $hosts = [];
    my $services = [];

    my $softlogfilter;
    if(!$includesoftstates or $includesoftstates eq 'no') {
        $softlogfilter = { options => { '~' => ';HARD;' }};
    }

    my $logs;
    my $logstart = $start - $backtrack * 86400;
    $c->log->debug("logstart: ".$logstart." - ".(scalar localtime($logstart)));
    my $logfilter = {
        -and => [
            time => { '>=' => $logstart },
            time => { '<=' => $end },
    ]};

    # a single service
    if(defined $service and $service ne 'all') {
        unless($c->check_permissions('service', $service, $host)) {
            return $c->detach('/error/index/15');
        }
        $logserviceheadfilter = { service_description => $service };
        $loghostheadfilter    = { host_name => $host };
        push @{$services}, { 'host' => $host, 'service' => $service };

        if($initialassumedservicestate == -1) {
            my $service_data = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), description => $service, host_name => $host ], limit => 1);
            $initial_states->{'services'}->{$host}->{$service} = $service_data->[0]->{'state'};
        }
    }

    # all services
    elsif(defined $service and $service eq 'all') {
        my $all_services = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services') ]);
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
            return $c->detach('/error/index/5');
        }
        my $service_data = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), host_name => $host ]);
        $service_data = array2hash($service_data, 'description');
        $c->stash->{'services'}->{$host} = $service_data;
        $loghostheadfilter = { host_name => $host };

        for my $description (keys %{$service_data}) {
            push @{$services}, { 'host' => $host, 'service' => $description };
        }
        if($initialassumedservicestate == -1) {
            for my $servicename (keys %{$service_data}) {
                $initial_states->{'services'}->{$host}->{$servicename} = $service_data->{$servicename}->{'state'};
            }
        }
        if($initialassumedhoststate == -1) {
            my $host_data = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), name => $host ], limit => 1);
            $initial_states->{'hosts'}->{$host} = $host_data->[0]->{'state'};
        }
        push @{$hosts}, $host;
    }

    # all hosts
    elsif(defined $host and $host eq 'all') {
        my $host_data = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts') ]);
        $host_data    = array2hash($host_data, 'name');
        push @{$hosts}, keys %{$host_data};
        $logserviceheadfilter = { service_description => undef };
        $c->stash->{'hosts'} = $host_data;
        if($initialassumedhoststate == -1) {
            for my $host (keys %{$host_data}) {
                $initial_states->{'hosts'}->{$host} = $host_data->{$host}->{'state'};
            }
        }
    }

    # one or all hostgroups
    elsif(defined $hostgroup and $hostgroup ne '') {
        if($hostgroup ne '' and $hostgroup ne 'all') {
            $groupfilter       = { name => $hostgroup };
            $hostfilter        = { groups => { '>=' => $hostgroup }};
            $loghostheadfilter = { current_host_groups => { '>=' => $hostgroup }};
        }
        my $host_data = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ]);
        $host_data    = array2hash($host_data, 'name');
        my $groups    = $c->{'db'}->get_hostgroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hostgroups'), $groupfilter ]);

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
        $logserviceheadfilter = { service_description => undef };

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
            $groupfilter          = { name => $servicegroup };
            $servicefilter        = { groups => { '>=' => $servicegroup }};
            $logserviceheadfilter = { current_service_groups => { '>=' => $servicegroup }};
        }
        my $all_services = $c->{'db'}->get_services(filter => [ $servicefilter, Thruk::Utils::Auth::get_auth_filter($c, 'services') ]);
        my $groups       = $c->{'db'}->get_servicegroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'servicegroups'), $groupfilter ]);

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
    } else {
        croak("unknown report type: ".Dumper($c->{'request'}->{'parameters'}));
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
    if($service or $host or $servicegroup) {
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
    push @typefilter, { class => 2 }; # programm messages

    my $filter = [ $logfilter, { -or => [ @typefilter ] } ];

    $c->stats->profile(begin => "avail.pm fetchlogs");
    $logs = $c->{'db'}->get_logs(filter => $filter);
    $c->stats->profile(end   => "avail.pm fetchlogs");

    $c->stats->profile(begin => "calculate availability");
    my $ma = Monitoring::Availability->new(
        'rpttimeperiod'                => $rpttimeperiod,
        'assumeinitialstates'          => $assumeinitialstates,
        'assumestateretention'         => $assumestateretention,
        'assumestatesduringnotrunning' => $assumestatesduringnotrunning,
        'includesoftstates'            => $includesoftstates,
        'initialassumedhoststate'      => Thruk::Utils::_initialassumedhoststate_to_state($initialassumedhoststate),
        'initialassumedservicestate'   => Thruk::Utils::_initialassumedservicestate_to_state($initialassumedservicestate),
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
        $c->stash->{'logs'} = $ma->get_full_logs() || [];
        #$c->log->debug("got full logs: ".Dumper($c->stash->{'logs'}));
    }
    elsif($show_log_entries) {
        $c->stash->{'logs'} = $ma->get_condensed_logs() || [];
        #$c->log->debug("got condensed logs: ".Dumper($c->stash->{'logs'}));
    }

    $c->stats->profile(end => "got logs");
    return 1;
}

########################################

=head2 set_message

  set_message($c, $style, $text, [ $details ])

set a message in an cookie for later display

=cut
sub set_message {
    my $c       = shift;
    my $style   = shift;
    my $message = shift;
    my $details = shift;

    $c->res->cookies->{'thruk_message'} = {
        value => $style.'~~'.$message,
    };
    $c->stash->{'thruk_message'}         = $style.'~~'.$message;
    $c->stash->{'thruk_message_details'} = $details || [];

    return 1;
}


########################################

=head2 ssi_include

  ssi_include($c)

puts the ssi templates into the stash

=cut
sub ssi_include {
    my $c = shift;
    my $global_header_file = "common-header.ssi";
    my $header_file        = $c->stash->{'page'}."-header.ssi";
    my $global_footer_file = "common-footer.ssi";
    my $footer_file        = $c->stash->{'page'}."-footer.ssi";

    if ( defined $c->config->{ssi_includes}->{$global_header_file} ){
        $c->stash->{ssi_header} = Thruk::Utils::read_ssi($c, $global_header_file);
    }
    if ( defined $c->config->{ssi_includes}->{$header_file} ){
        $c->stash->{ssi_header} .= Thruk::Utils::read_ssi($c, $header_file);
    }
    # Footer
    if ( defined $c->config->{ssi_includes}->{$global_footer_file} ){
        $c->stash->{ssi_footer} = Thruk::Utils::read_ssi($c, $global_footer_file);
    }
    if ( defined $c->config->{ssi_includes}->{$footer_file} ){
        $c->stash->{ssi_footer} .= Thruk::Utils::read_ssi($c, $footer_file);
    }

    return 1;
}


########################################

=head2 read_ssi

  read_ssi($c, $file)

reads a ssi file or executes it if its executable

=cut
sub read_ssi {
    my $c    = shift;
    my $file = shift;
    # retun if file is execitabel
    if( -x $c->config->{'ssi_path'}.$file ){
       open(my $ph, '-|', $c->config->{'ssi_path'}.$file.' 2>&1') or carp("cannot execute ssi: $!");
       local $/=undef;
       my $output = <$ph>;
       close($ph);
       return $output;
    }
    elsif( -r $c->config->{'ssi_path'}.$file ){
        return read_file($c->config->{'ssi_path'}.$file) or carp("cannot open ssi: $!");
    }
    $c->log->warn($c->config->{'ssi_path'}.$file." is no longer accessible, please restart thruk to initialize ssi information");
    return "";
}


########################################

=head2 version_compare

  version_compare($version1, $version2)

compare too version strings

=cut
sub version_compare {
    my($v1,$v2) = @_;
    confess("version_compare() needs two params, got: ".Dumper(\@_)) unless defined $v2;

    my @v1 = split/\./mx,$v1;
    my @v2 = split/\./mx,$v2;

    for(my $x = 0; $x < scalar @v1; $x++) {
        next if !defined $v2[$x];
        my $cmp = 0;
        if($v2[$x] =~ m/^(\d+)/gmx) { $cmp = $1; }
        return 0 unless $v1[$x] <= $cmp;
    }
    return 1;
}


########################################

=head2 combine_filter

  combine_filter($operator, $filter)

combine filter by operator

=cut
sub combine_filter {
    my $operator = shift;
    my $filter   = shift;

    my $return;
    if(!defined $operator and $operator ne '-or' and $operator ne '-and') {
        confess("unknown operator: ".Dumper($operator));
    }

    return unless defined $filter;

    if(ref $filter ne 'ARRAY') {
        confess("expected arrayref, got: ".Dumper(ref $filter));
    }

    return if scalar @{$filter} == 0;

    if(scalar @{$filter} == 1) {
        return $filter->[0];
    }

    return { $operator => $filter };

    return $return;
}


########################################

=head2 array2hash

  array2hash($data, $key)

create a hash by key

=cut
sub array2hash {
    my $data = shift;
    my $key   = shift;

    return {} unless defined $data;
    confess("not an array") unless ref $data eq 'ARRAY';

    my %hash;
    if(defined $key) {
        %hash = map { $_->{$key} => $_ } @{$data};
    } else {
        %hash = map { $_ => $_ } @{$data};
    }

    return \%hash;
}


########################################

=head2 set_paging_steps

  set_paging_steps($c, $data)

sets the pagins stepts, needs string like:

  *100, 500, 1000, all

=cut
sub set_paging_steps {
    my $c    = shift;
    my $data = shift;

    $c->stash->{'paging_steps'}      = [ '100', '500', '1000', '5000', 'all' ];
    $c->stash->{'default_page_size'} = 100;

    return unless defined $data;

    # we need an array
    $data = ref $data eq 'ARRAY' ? $data : [split(/\s*,\s*/mx, $data)];

    $c->stash->{'paging_steps'}      = [];
    $c->stash->{'default_page_size'} = undef;

    for my $step (@{$data}) {
        if($step =~ m/^\*(.*)$/mx) {
            $step                            = $1;
            $c->stash->{'default_page_size'} = $step;
        }
        push @{$c->stash->{'paging_steps'}}, $step;
    }

    # no default yet?
    unless(defined $c->stash->{'default_page_size'}) {
        $c->stash->{'default_page_size'} = $c->stash->{'paging_steps'}->[0];
    }

    return;
}


########################################

=head2 normal_mktime

  normal_mktime($year,$mon,$day,$hour,$min,$sec)

returns normalized timestamp for given date

=cut

sub normal_mktime {
    my($year,$mon,$day,$hour,$min,$sec) = @_;

    # calculate borrow
    my $add_time = 0;
    if($hour == 24) {
        $add_time = 86400;
        $hour = 0;
    }

    ($day, $hour, $min, $sec) = Normalize_DHMS($day, $hour, $min, $sec);
    my $timestamp = Mktime($year,$mon,$day, $hour,$min,$sec);
    $timestamp += $add_time;
    return $timestamp;
}

########################################
sub _initialassumedhoststate_to_state {
    my $initialassumedhoststate = shift;

    return 'unspecified' if $initialassumedhoststate ==  0; # Unspecified
    return 'current'     if $initialassumedhoststate == -1; # Current State
    return 'up'          if $initialassumedhoststate ==  3; # Host Up
    return 'down'        if $initialassumedhoststate ==  4; # Host Down
    return 'unreachable' if $initialassumedhoststate ==  5; # Host Unreachable
    croak('unknown state: '.$initialassumedhoststate);
}


########################################

=head2 get_user_data

  get_user_data()

returns user data

=cut

sub get_user_data {
    my($c) = @_;

    return {} unless defined $c->stash->{'remote_user'};

    my $file = $c->config->{'var_path'}."/users/".$c->stash->{'remote_user'};
    return {} unless -f $file;

    my $dump = read_file($file) or carp("cannot open file $file: $!");
    my $VAR1 = {};

    ## no critic
    eval($dump);
    ## use critic

    carp("error in file $file: $@") if $@;

    return($VAR1);
}


########################################

=head2 store_user_data

  store_user_data($section, $data)

store user data for section

=cut

sub store_user_data {
    my($c, $data) = @_;

    for my $dir ($c->config->{'var_path'}, $c->config->{'var_path'}."/users") {
        if(! -d $dir) {
            mkdir($dir) or do {
                Thruk::Utils::set_message( $c, 'fail_message', 'Saving Bookmarks failed: mkdir '.$dir.': '.$! );
                return;
            };
        }
    }

    my $file = $c->config->{'var_path'}."/users/".$c->stash->{'remote_user'};
    open(my $fh, '>', $file.'.new') or do {
        Thruk::Utils::set_message( $c, 'fail_message', 'Saving Bookmarks failed: open '.$file.'.new : '.$! );
        return;
    };
    print $fh Dumper($data);
    close($fh);

    move($file.'.new', $file) or do {
        Thruk::Utils::set_message( $c, 'fail_message', 'Saving Bookmarks failed: move '.$file.'.new '.$file.': '.$! );
        return;
    };

    return 1;
}


########################################
sub _initialassumedservicestate_to_state {
    my $initialassumedservicestate = shift;

    return 'unspecified' if $initialassumedservicestate ==  0; # Unspecified
    return 'current'     if $initialassumedservicestate == -1; # Current State
    return 'ok'          if $initialassumedservicestate ==  6; # Service Ok
    return 'warning'     if $initialassumedservicestate ==  8; # Service Warning
    return 'unknown'     if $initialassumedservicestate ==  7; # Service Unknown
    return 'critical'    if $initialassumedservicestate ==  9; # Service Critical
    croak('unknown state: '.$initialassumedservicestate);
}


1;

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
