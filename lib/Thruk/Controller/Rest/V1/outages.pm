package Thruk::Controller::Rest::V1::outages;

use strict;
use warnings;
use Thruk::Controller::rest_v1;
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::Controller::Rest::outages - Outages Rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=head2 index

=cut

use Thruk::Utils::Avail ();

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
sub _rest_outages {
    my($c) = @_;
    if($c->req->parameters->{'timeperiod'} && ($c->req->parameters->{'start'} || $c->req->parameters->{'end'})) {
        return({
                'message'     => 'use either timeperiod or start/end, not both.',
                'code'        => 400,
                'failed'      => Cpanel::JSON::XS::true,
        });
    }

    my($hostfilter, $servicefilter) = Thruk::Utils::Status::do_filter($c);
    if($c->stash->{'has_error'}) {
        return({
                'message'     => 'error in filter',
                'code'        => 400,
                'failed'      => Cpanel::JSON::XS::true,
        });
    }

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
