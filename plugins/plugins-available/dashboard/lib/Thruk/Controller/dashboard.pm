package Thruk::Controller::dashboard;

use strict;
use warnings;
use utf8;
use Carp;
use Thruk::Utils::Status;
use List::Compare;
use List::MoreUtils;
use Thruk::Backend::Provider::DashboardLivestatus;

=head1 NAME

Thruk::Controller::dashboard - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

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
# add new view item
Thruk::Utils::Status::add_view({'group' => 'Dashboard',
                                'name'  => 'Dashboard',
                                'value' => 'dashboard',
                                'url'   => 'dashboard.cgi'
                            });

##########################################################

=head1 METHODS

=head2 index

page: /thruk/cgi-bin/dashboard.cgi

=cut

sub index : Path : Args(0) : MyAction('AddDefaults') : Regex('thruk\/cgi\-bin\/dashboard\.cgi') {
my( $self, $c ) = @_;

    my $style = $c->{'request'}->{'parameters'}->{'style'} || 'dashboard';
    if($style ne 'dashboard') {
        return if Thruk::Utils::Status::redirect_view($c, $style);
    }

    my $action = $c->{'request'}->{'parameters'}->{'action'} || '';
    if(defined $c->{'request'}->{'parameters'}->{'addb'} or defined $c->{'request'}->{'parameters'}->{'saveb'}) {
        return $self->_process_bookmarks($c);
    }

    if(defined $c->{'request'}->{'parameters'}->{'verify'} and $c->{'request'}->{'parameters'}->{'verify'} eq 'time') {
        return $self->_process_verify_time($c);
    }

    # set some defaults
    Thruk::Utils::Status::set_default_stash($c);

    $c->stash->{title}        = 'Current Network Status';
    $c->stash->{infoBoxTitle} = 'Current Network Status';
    $c->stash->{page}         = 'status';
    $c->stash->{style}        = $style;

    $c->stash->{substyle}     = undef;

    if($c->stash->{'hostgroup'}) {
        $c->stash->{substyle} = 'host';
    }
    else {
        $c->stash->{substyle} = 'service';
    }

    $self->_process_dashboard_page($c);

    Thruk::Utils::set_paging_steps($c, ['*16', 32, 48, 96]);

    $c->stash->{template} = 'status_dashboard.tt';

    Thruk::Utils::ssi_include($c);

    Thruk::Utils::Status::set_custom_title($c);

    return 1;
}


##########################################################
# create the status details page
sub _process_dashboard_page {
    my( $self, $c ) = @_;

    # which host to display?
    my( $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = Thruk::Utils::Status::do_filter($c);
    return if $c->stash->{'has_error'};

    die("no substyle!") unless defined $c->stash->{substyle};

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
            $stats->{'hosts'} = $c->{'db'}->get_host_stats_dashboard(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), \%filter_host]);
            $stats->{'services'} = $c->{'db'}->get_service_stats_dashboard(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), \%filter_service]);
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

            @{$filter_host{'-or'}} = List::MoreUtils::uniq(@{$filter_host{'-or'}});


            my $stats;
            $stats->{'services'} = $c->{'db'}->get_service_stats_dashboard(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), \%filter_service]);
            $stats->{'hosts'} = $c->{'db'}->get_host_stats_dashboard(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), \%filter_host]);
            $stats->{'name'} = $name;
            push (@dashboard, $stats);

        }

    }


    my $sortedgroups = Thruk::Backend::Manager::_sort($c, \@dashboard, { 'ASC' => 'name'});

    Thruk::Utils::set_paging_steps($c, Thruk->config->{'group_paging_overview'});
    Thruk::Backend::Manager::_page_data(undef, $c, $sortedgroups, 16, scalar(@dashboard));

    $c->stash->{'dashboard'} = $sortedgroups;

    return 1;
}

=head1 AUTHOR

Sigma Informatique, 2011

=cut

1;
