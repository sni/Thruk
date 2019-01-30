package Thruk::Controller::avail;

use strict;
use warnings;
use Module::Load qw/load/;

=head1 NAME

Thruk::Controller::avail - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index {
    my ( $c ) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_DEFAULTS);

    if(!$c->config->{'avail_modules_loaded'}) {
        load Monitoring::Availability;
        load Thruk::Utils::Avail;
        $c->config->{'avail_modules_loaded'} = 1;
    }

    # set defaults
    $c->stash->{title}            = 'Availability';
    $c->stash->{infoBoxTitle}     = 'Availability Report';
    $c->stash->{page}             = 'avail';
    $c->stash->{'no_auto_reload'} = 1;

    Thruk::Utils::ssi_include($c);

    # lookup parameters
    my $report_type    = $c->req->parameters->{'report_type'}  || '';
    my $host           = $c->req->parameters->{'host'}         || '';
    my $hostgroup      = $c->req->parameters->{'hostgroup'}    || '';
    my $service        = $c->req->parameters->{'service'}      || '';
    my $servicegroup   = $c->req->parameters->{'servicegroup'} || '';

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
    if($report_type and _show_step_2($c, $report_type)) {
    }

    # Step 3 - select date parts
    elsif(exists $c->req->parameters->{'get_date_parts'} and _show_step_3($c)) {
    }

    # Step 4 - create report
    elsif(!$report_type
       && ($host || $service || $servicegroup || $hostgroup)
       && _create_report($c)) {
    }



    # Step 1 - select report type
    else {
        _show_step_1($c);
    }

    return 1;
}

##########################################################
sub _show_step_1 {
    my ( $c ) = @_;

    $c->stats->profile(begin => "_show_step_1()");
    $c->stash->{template} = 'avail_step_1.tt';
    $c->stats->profile(end => "_show_step_1()");

    return 1;
}


##########################################################
sub _show_step_2 {
    my ( $c, $report_type ) = @_;

    $c->stats->profile(begin => "_show_step_2($report_type)");

    my $data;
    if($report_type eq 'hosts') {
        $data = $c->{'db'}->get_host_names(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts') ]);
    }
    elsif($report_type eq 'hostgroups') {
        $data = $c->{'db'}->get_hostgroup_names_from_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );
    }
    elsif($report_type eq 'servicegroups') {
        $data = $c->{'db'}->get_servicegroup_names_from_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ] );
    }
    elsif($report_type eq 'services') {
        my $services = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services')]);
        for my $service (@{$services}) {
            $data->{$service->{'host_name'}.";".$service->{'description'}} = 1;
        }
        my @sorted = sort keys %{$data};
        $data = \@sorted;
    }
    else {
        return 0;
    }

    $c->stash->{data}     = $data;
    $c->stash->{template} = 'avail_step_2.tt';

    $c->stats->profile(end => "_show_step_2($report_type)");

    return 1;
}

##########################################################
sub _show_step_3 {
    my ( $c ) = @_;

    $c->stats->profile(begin => "_show_step_3()");

    $c->stash->{timeperiods} = $c->{'db'}->get_timeperiods(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'timeperiods')], remove_duplicates => 1, sort => 'name');
    $c->stash->{template}    = 'avail_step_3.tt';

    my($host,$service);
    $service = $c->req->parameters->{'service'};

    if($service and CORE::index($service, ';') > 0) {
        ($host,$service) = split/;/mx, $service;
        $c->stash->{host}    = $host;
        $c->stash->{service} = $service;
    }

    $c->stats->profile(end => "_show_step_3()");

    return 1;
}

##########################################################
sub _create_report {
    my ( $c ) = @_;
    $c->req->parameters->{'include_host_services'} = 1;
    return Thruk::Utils::External::perl($c, { expr => 'Thruk::Utils::Avail::calculate_availability($c)', message => 'please stand by while your report is being generated...' });
}

1;
