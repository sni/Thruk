package Thruk::Controller::dashboard;

use strict;
use warnings;
use Thruk::Utils::Status;
use Thruk::Backend::Provider::DashboardLivestatus;
use Thruk::Backend::Provider::DashboardHTTP;

=head1 NAME

Thruk::Controller::dashboard - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=cut

################################################################
#                     SIGMA Informatique
################################################################
#
# AUTEUR :    SIGMA INFORMATIQUE
#
# OBJET  :    Dashboard plugin
#
# DESC   :    Controller for dashboard plugin
#
#
################################################################
# Copyright © 2011 Sigma Informatique. All rights reserved.
# Copyright © 2010 Thruk Developer Team.
# Copyright © 2009 Nagios Core Development Team and Community Contributors.
# Copyright © 1999-2009 Ethan Galstad.
################################################################


##########################################################

=head2 add_routes

page: /thruk/cgi-bin/dashboard.cgi

=cut

sub add_routes {
    my($self, $app, $routes) = @_;

    $routes->{'/thruk/cgi-bin/dashboard.cgi'} = 'Thruk::Controller::dashboard::index';

    # add new view item
    Thruk::Utils::Status::add_view({'group' => 'Dashboard',
                                    'name'  => 'Dashboard',
                                    'value' => 'dashboard',
                                    'url'   => 'dashboard.cgi'
    });

    return;
}

=head1 METHODS

=head2 index

page: /thruk/cgi-bin/dashboard.cgi

=cut

sub index {
    my( $c ) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_DEFAULTS);

    my $style = $c->req->parameters->{'style'} || 'dashboard';
    if($style ne 'dashboard') {
        return if Thruk::Utils::Status::redirect_view($c, $style);
    }

    my $action = $c->req->parameters->{'action'} || '';
    if(defined $c->req->parameters->{'addb'} or defined $c->req->parameters->{'saveb'}) {
        return _process_bookmarks($c);
    }

    if(defined $c->req->parameters->{'verify'} and $c->req->parameters->{'verify'} eq 'time') {
        return _process_verify_time($c);
    }

    # set some defaults
    Thruk::Utils::Status::set_default_stash($c);

    $c->stash->{title}         = 'Current Network Status';
    $c->stash->{infoBoxTitle}  = 'Current Network Status';
    $c->stash->{page}          = 'status';
    $c->stash->{show_top_pane} = 1;
    $c->stash->{style}         = $style;

    $c->stash->{substyle}     = undef;

    if($c->stash->{'hostgroup'}) {
        $c->stash->{substyle} = 'host';
    }
    else {
        $c->stash->{substyle} = 'service';
    }

    _process_dashboard_page($c);

    Thruk::Utils::set_paging_steps($c, ['*16', 32, 48, 96]);

    $c->stash->{template} = 'status_dashboard.tt';

    Thruk::Utils::ssi_include($c);

    Thruk::Utils::Status::set_custom_title($c);

    return 1;
}


##########################################################
# create the status details page
sub _process_dashboard_page {
    my( $c ) = @_;

    # which host to display?
    my( $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = Thruk::Utils::Status::do_filter($c);
    return if $c->stash->{'has_error'};

    die("no substyle!") unless defined $c->stash->{substyle};

    my $eval = { code => 'require Thruk::Backend::Provider::DashboardLivestatus', inc => 'dashboard/lib' };

    # we need the hostname, address etc...
    my $host_data;
    my $services_data;

    my $tmp_host_data = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ], columns => [ qw /acknowledged downtimes name state num_services_pending num_services_ok has_been_checked num_services_warn num_services_unknown num_services_crit/ ] );

    if( defined $tmp_host_data ) {
        for my $host ( @{$tmp_host_data} ) {
            $host_data->{ $host->{'name'} } = $host;
        }
    }

    if( $c->stash->{substyle} eq 'service' ) {

        my $tmp_services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ], columns => [ qw /has_been_checked host_name host_downtimes host_acknowledged host_state acknowledged description downtimes state/ ] );

        if( defined $tmp_services ) {
            for my $service ( @{$tmp_services} ) {
                next if $service->{'description'} eq '';
                $services_data->{ $service->{'host_name'} }->{ $service->{'description'} } = $service;
            }
        }
    }

    # get all host/service groups
    my $groups;
    if( $c->stash->{substyle} eq 'host' ) {
        $groups = $c->{'db'}->get_hostgroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ), $hostgroupfilter ] );
    }
    else {
        $groups = $c->{'db'}->get_servicegroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'servicegroups' ), $servicegroupfilter ] );
    }

    my @dashboard;

    for my $group ( @{$groups} ) {

        next if scalar @{ $group->{'members'} } == 0;

        my $name = $group->{'name'};

        my( $hostname, $servicename );
        if( $c->stash->{substyle} eq 'host' ) {
            my %filter_host = ( -or => [] );
            my %filter_service = ( -or => [] );
            for my $hostname ( @{ $group->{'members'} } ) {

                # show only hosts with proper authorization
                next unless defined $host_data->{$hostname};

                push (@{$filter_host{'-or'}}, {name => $hostname});
                push (@{$filter_service{'-or'}}, {host_name => $hostname});
            }
            my $stats;
            delete $filter_host{'-or'}    if scalar @{$filter_host{'-or'}} == 0;
            delete $filter_service{'-or'} if scalar @{$filter_service{'-or'}} == 0;
            $stats->{'hosts'} = $c->{'db'}->get_host_stats_dashboard(      filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'),    \%filter_host],    'eval' => $eval);
            $stats->{'services'} = $c->{'db'}->get_service_stats_dashboard(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), \%filter_service], 'eval' => $eval);
            $stats->{'name'} = $name;
            push (@dashboard, $stats);
        }
        else {
            my $uniq = {};
            my %filter_service = ( -or => [] );
            my %filter_host = ( -or => [] );

            for my $member ( @{$group->{'members'} } ) {
                my( $hostname, $servicename ) = @{$member};

                my %element;

                # filter duplicates
                next if exists $uniq->{$hostname}->{$servicename};
                $uniq->{$hostname}->{$servicename} = 1;

                # show only hosts with proper authorization
                next unless defined $host_data->{$hostname};
                next unless defined $services_data->{$hostname}->{$servicename};

                %element = (
                            -and =>    {
                                        host_name => $hostname,
                                        description => $servicename,
                                    },
                            );

                push (@{$filter_service{'-or'}}, \%element);
                push (@{$filter_host{'-or'}}, {name => $hostname});

            }

            $filter_host{'-or'} = Thruk::Utils::array_uniq($filter_host{'-or'});


            my $stats;
            delete $filter_host{'-or'}    if scalar @{$filter_host{'-or'}}    == 0;
            delete $filter_service{'-or'} if scalar @{$filter_service{'-or'}} == 0;
            $stats->{'services'} = $c->{'db'}->get_service_stats_dashboard(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), \%filter_service], 'eval' => $eval);
            $stats->{'hosts'}    = $c->{'db'}->get_host_stats_dashboard(   filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'),    \%filter_host],    'eval' => $eval);
            $stats->{'name'}     = $name;
            push (@dashboard, $stats);

        }

    }


    my $sortedgroups = Thruk::Backend::Manager::_sort($c, \@dashboard, { 'ASC' => 'name'});

    Thruk::Utils::set_paging_steps($c, Thruk->config->{'group_paging_overview'});
    Thruk::Backend::Manager::page_data($c, $sortedgroups, 16, scalar(@dashboard));

    $c->stash->{'dashboard'} = $sortedgroups;

    return 1;
}

=head1 AUTHOR

Sigma Informatique, 2011
Sven Nierlein, 2009-present, <sven@nierlein.org>

=cut

1;
