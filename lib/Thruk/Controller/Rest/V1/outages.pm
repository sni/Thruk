package Thruk::Controller::Rest::V1::outages;

use warnings;
use strict;
use Cpanel::JSON::XS ();

use Thruk::Controller::rest_v1 ();
use Thruk::Utils ();
use Thruk::Utils::Log qw/:all/;
use Thruk::Utils::Status ();

=head1 NAME

Thruk::Controller::Rest::outages - Outages Rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=head2 index

=cut


##########################################################
# REST PATH: GET /hosts/outages
# list of outages for all hosts.
#
# Optional arguments:
#
#   * type              - both | hosts | services
#   * timeperiod        - last24hours | lastmonth | thismonth | ...
#   * start             - unix timestamp
#   * end               - unix timestamp
#   * withdowntimes     - 0/1 wheter downtimes should count as outages
#   * includesoftstates - 0/1 wheter soft states should be used as well
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/hosts?/outages$%mx, \&_rest_get_hosts_outages, undef, 1);
sub _rest_get_hosts_outages {
    my($c) = @_;
    if(!$c->req->parameters->{'type'}) {
        $c->req->parameters->{'type'} = "hosts";
    }
    $c->req->parameters->{'host'} = 'all' unless $c->req->parameters->{'host'};
    my $outages = _rest_outages($c);
    delete $c->req->parameters->{'host'};
    _rest_outages_clean_param($c);
    return($outages);
}

##########################################################
# REST PATH: GET /hosts/<name>/outages
# list of outages for this host.
#
# Optional arguments:
#
#   * type              - both | hosts | services
#   * timeperiod        - last24hours | lastmonth | thismonth | ...
#   * start             - unix timestamp
#   * end               - unix timestamp
#   * withdowntimes     - 0/1 wheter downtimes should count as outages
#   * includesoftstates - 0/1 wheter soft states should be used as well
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/hosts?/([^/]+)/outages$%mx, \&_rest_get_host_outages);
sub _rest_get_host_outages {
    my($c, undef, $host) = @_;
    if(!$c->req->parameters->{'type'}) {
        $c->req->parameters->{'type'} = "hosts";
    }
    $c->req->parameters->{'host'} = $host;
    my $outages = _rest_outages($c);
    delete $c->req->parameters->{'host'};
    _rest_outages_clean_param($c);
    return($outages);
}

##########################################################
# REST PATH: GET /hosts/<name>/availability
# list availability for this host.
#
# Optional arguments:
#
#   * timeperiod        - last24hours | lastmonth | thismonth | ...
#   * start             - unix timestamp
#   * end               - unix timestamp
#   * withdowntimes     - 0/1 wheter downtimes should count as outages
#   * includesoftstates - 0/1 wheter soft states should be used as well
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/hosts?/([^/]+)/availability$%mx, \&_rest_get_host_availability);
sub _rest_get_host_availability {
    my($c, undef, $host) = @_;
    $c->req->parameters->{'type'} = "hosts";
    $c->req->parameters->{'host'} = $host;
    my $avail = _rest_availability($c);
    delete $c->req->parameters->{'host'};
    _rest_outages_clean_param($c);
    return($avail->{'avail'}->{'hosts'}->{$host});
}


##########################################################
# REST PATH: GET /hostgroups/<name>/outages
# list of outages for this hostgroup.
#
# Optional arguments:
#
#   * type              - both | hosts | services
#   * timeperiod        - last24hours | lastmonth | thismonth | ...
#   * start             - unix timestamp
#   * end               - unix timestamp
#   * withdowntimes     - 0/1 wheter downtimes should count as outages
#   * includesoftstates - 0/1 wheter soft states should be used as well
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/hostgroups?/([^/]+)/outages$%mx, \&_rest_get_hostgroup_outages);
sub _rest_get_hostgroup_outages {
    my($c, undef, $group) = @_;
    $c->req->parameters->{'hostgroup'} = $group;
    my $outages = _rest_outages($c);
    delete $c->req->parameters->{'hostgroup'};
    _rest_outages_clean_param($c);
    return($outages);
}

##########################################################
# REST PATH: GET /services/outages
# list of outages for all services.
#
# Optional arguments:
#
#   * type              - both | hosts | services
#   * timeperiod        - last24hours | lastmonth | thismonth | ...
#   * start             - unix timestamp
#   * end               - unix timestamp
#   * withdowntimes     - 0/1 wheter downtimes should count as outages
#   * includesoftstates - 0/1 wheter soft states should be used as well
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/services?/outages$%mx, \&_rest_get_services_outages, undef, 1);
sub _rest_get_services_outages {
    my($c) = @_;
    if(!$c->req->parameters->{'type'}) {
        $c->req->parameters->{'type'} = "services";
    }
    $c->req->parameters->{'host'} = 'all' unless $c->req->parameters->{'host'};
    my $outages = _rest_outages($c);
    delete $c->req->parameters->{'host'};
    _rest_outages_clean_param($c);
    return($outages);
}

##########################################################
# REST PATH: GET /services/<host>/<service>/outages
# list of outages for this service.
#
# Optional arguments:
#
#   * type              - both | hosts | services
#   * timeperiod        - last24hours | lastmonth | thismonth | ...
#   * start             - unix timestamp
#   * end               - unix timestamp
#   * withdowntimes     - 0/1 wheter downtimes should count as outages
#   * includesoftstates - 0/1 wheter soft states should be used as well
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/services?/([^/]+)/([^/]+)/outages$%mx, \&_rest_get_service_outages);
sub _rest_get_service_outages {
    my($c, undef, $host, $service) = @_;
    if(!$c->req->parameters->{'type'}) {
        $c->req->parameters->{'type'} = "services";
    }
    $c->req->parameters->{'host'}    = $host;
    $c->req->parameters->{'service'} = $service;
    my $outages = _rest_outages($c);
    delete $c->req->parameters->{'host'};
    delete $c->req->parameters->{'service'};
    _rest_outages_clean_param($c);
    return($outages);
}

##########################################################
# REST PATH: GET /services/<host>/<service>/availability
# list of outages for this service.
#
# Optional arguments:
#
#   * type              - both | hosts | services
#   * timeperiod        - last24hours | lastmonth | thismonth | ...
#   * start             - unix timestamp
#   * end               - unix timestamp
#   * withdowntimes     - 0/1 wheter downtimes should count as outages
#   * includesoftstates - 0/1 wheter soft states should be used as well
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/services?/([^/]+)/([^/]+)/availability$%mx, \&_rest_get_service_availability);
sub _rest_get_service_availability {
    my($c, undef, $host, $service) = @_;
    $c->req->parameters->{'type'} = "services";
    $c->req->parameters->{'host'}    = $host;
    $c->req->parameters->{'service'} = $service;
    my $avail = _rest_availability($c);
    delete $c->req->parameters->{'host'};
    delete $c->req->parameters->{'service'};
    _rest_outages_clean_param($c);
    return($avail->{'avail'}->{'services'}->{$host}->{$service});
}

##########################################################
# REST PATH: GET /servicegroups/<name>/outages
# list of outages for this servicegroup.
#
# Optional arguments:
#
#   * type              - both | hosts | services
#   * timeperiod        - last24hours | lastmonth | thismonth | ...
#   * start             - unix timestamp
#   * end               - unix timestamp
#   * withdowntimes     - 0/1 wheter downtimes should count as outages
#   * includesoftstates - 0/1 wheter soft states should be used as well
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/servicegroups?/([^/]+)/outages$%mx, \&_rest_get_servicegroup_outages);
sub _rest_get_servicegroup_outages {
    my($c, undef, $group) = @_;
    $c->req->parameters->{'servicegroup'} = $group;
    my $outages = _rest_outages($c);
    delete $c->req->parameters->{'servicegroup'};
    _rest_outages_clean_param($c);
    return($outages);
}

##########################################################
sub _rest_availability_prep {
    my($c) = @_;
    # extract time / timeperiod filter from query
    if($c->req->parameters->{'q'}) {
        my($filter) = Thruk::Utils::Status::parse_lexical_filter($c->req->parameters->{'q'}, 1);
        for my $param (@{$filter}) {
            if(ref $param eq 'ARRAY' && scalar @{$param} == 1) {
                $param = $param->[0];
            }
            my $ok = _rest_replace_logs_timeperiod_filter($c, $param);
            if($ok) {
                undef $param;
                next;
            }
            $ok = _rest_replace_logs_time_filter($c, $param);
            if($ok) {
                undef $param;
                next;
            }
        }
        # combine remaining filter again
        $c->req->parameters->{'q'} = Thruk::Utils::Status::filter2text($c, undef, $filter);
    }

    if($c->req->parameters->{'timeperiod'} && ($c->req->parameters->{'start'} || $c->req->parameters->{'end'})) {
        return(undef, undef, {
                'message'     => 'use either timeperiod or start/end, not both.',
                'code'        => 400,
                'failed'      => Cpanel::JSON::XS::true,
        });
    }

    my($hostfilter, $servicefilter) = Thruk::Utils::Status::do_filter($c, undef, undef, 1);
    if($c->stash->{'has_error'}) {
        return(undef, undef, {
                'message'     => 'error in filter',
                'code'        => 400,
                'failed'      => Cpanel::JSON::XS::true,
        });
    }

    return($hostfilter, $servicefilter);
}

##########################################################
# remove timeperiod filter from query and place start/end into request parameters
# handles query likes 'timeperiod = lastweek'
sub _rest_replace_logs_timeperiod_filter {
    my($c, $param) = @_;
    return if ref $param ne 'HASH';
    return if scalar keys %{$param} != 1;
    return if ! exists $param->{'timeperiod'};

    return if ref $param->{'timeperiod'} ne 'HASH';
    return if scalar keys %{$param->{'timeperiod'}} != 1;
    my $op = (keys %{$param->{'timeperiod'}})[0];

    my($start, $end) = Thruk::Utils::get_start_end_for_timeperiod($c, $param->{'timeperiod'}->{$op});
    $c->req->parameters->{'start'} = $start;
    $c->req->parameters->{'end'}   = $end;

    return 1;
}

##########################################################
# remove time filter from query and place start/end into request parameters
# handles query likes (time >= ... and time <= ...)
sub _rest_replace_logs_time_filter {
    my($c, $param) = @_;
    if(ref $param eq 'HASH' && scalar keys %{$param} == 1 && exists $param->{'time'}) {
        $param = { "-and" => [ $param ] };
    }

    return if ref $param ne 'HASH';
    return if scalar keys %{$param} != 1;
    return if ! exists $param->{'-and'};

    my($start, $end);
    return if ref $param->{'-and'} ne 'ARRAY';
    return if scalar @{$param->{'-and'}} < 1;
    for my $t (@{$param->{'-and'}}) {
        return if ref $t ne 'HASH';
        return if scalar keys %{$t} != 1;
        return if ! exists $t->{'time'};

        my $op = (keys %{$t->{'time'}})[0];

        if($op eq '>=' || $op eq '>') {
            $start = $t->{'time'}->{$op};
        }
        elsif($op eq '<=' || $op eq '<') {
            $end = $t->{'time'}->{$op};
        } else {
            return;
        }
    }

    if($start) {
        $c->req->parameters->{'start'} = $start;
        $c->req->parameters->{'end'}   = $end // time();
        return 1;
    }
}

##########################################################
sub _rest_availability {
    my($c) = @_;

    my($hostfilter, $servicefilter, $err) = _rest_availability_prep($c);
    return $err if $err;

    if($c->req->parameters->{'type'} eq "services") {
        $c->req->parameters->{'s_filter'} = $servicefilter;
    } else {
        $c->req->parameters->{'h_filter'} = $hostfilter;
    }

    $c->req->parameters->{'t1'} = $c->req->parameters->{'start'};
    $c->req->parameters->{'t2'} = $c->req->parameters->{'end'};

    require Thruk::Utils::Avail;
    my $avail = Thruk::Utils::Avail::calculate_availability($c);

    return($avail);
}

##########################################################
sub _rest_outages {
    my($c) = @_;

    my($hostfilter, $servicefilter, $err) = _rest_availability_prep($c);
    return $err if $err;

    if(!$c->req->parameters->{'type'}) {
        $c->req->parameters->{'type'} = "both";
    }
    $c->req->parameters->{'outages'}   = 1;

    if($c->req->parameters->{'type'} eq "both") {
        $c->req->parameters->{'include_host_services'} = 1;
    }
    if($c->req->parameters->{'type'} eq "services" || $c->req->parameters->{'type'} eq 'both') {
        $c->req->parameters->{'s_filter'} = $servicefilter;
    } else {
        $c->req->parameters->{'h_filter'} = $hostfilter;
    }

    $c->req->parameters->{'t1'} = $c->req->parameters->{'start'};
    $c->req->parameters->{'t2'} = $c->req->parameters->{'end'};

    require Thruk::Utils::Avail;
    Thruk::Utils::Avail::calculate_availability($c);

    return($c->stash->{'outages'});
}

##########################################################
sub _rest_outages_clean_param {
    my($c) = @_;
    # cleanup parameters, would affect post rendering
    for my $param (qw/outages type s_filter h_filter include_host_services
                      start end timeperiod t1 t2 withdowntimes includesoftstates/) {
        delete $c->req->parameters->{$param};
    }
    return;
}

##########################################################

1;
