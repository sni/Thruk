package Thruk::Controller::status;

use strict;
use warnings;
use utf8;
use Carp;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::status - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

##########################################################
sub index : Path : Args(0) : MyAction('AddDefaults') {
    my( $self, $c ) = @_;

    # which style to display?
    my $allowed_subpages = { 'detail' => 1, 'grid' => 1, 'hostdetail' => 1, 'overview' => 1, 'summary' => 1, 'bothtypes' => 1, 'combined' => 1 };
    my $style = $c->{'request'}->{'parameters'}->{'style'} || '';

    if( $style eq '' ) {
        if( defined $c->{'request'}->{'parameters'}->{'hostgroup'} and $c->{'request'}->{'parameters'}->{'hostgroup'} ne '' ) {
            $style = 'overview';
        }
        if( defined $c->{'request'}->{'parameters'}->{'servicegroup'} and $c->{'request'}->{'parameters'}->{'servicegroup'} ne '' ) {
            $style = 'overview';
        }
    }

    # put some filter into the stash
    $c->stash->{'hoststatustypes'}    = $c->{'request'}->{'parameters'}->{'hoststatustypes'}    || '';
    $c->stash->{'hostprops'}          = $c->{'request'}->{'parameters'}->{'hostprops'}          || '';
    $c->stash->{'servicestatustypes'} = $c->{'request'}->{'parameters'}->{'servicestatustypes'} || '';
    $c->stash->{'serviceprops'}       = $c->{'request'}->{'parameters'}->{'serviceprops'}       || '';
    $c->stash->{'nav'}                = $c->{'request'}->{'parameters'}->{'nav'}                || '';
    $c->stash->{'entries'}            = $c->{'request'}->{'parameters'}->{'entries'}            || '';
    $c->stash->{'sortoption'}         = $c->{'request'}->{'parameters'}->{'sortoption'}         || '';
    $c->stash->{'hidesearch'}         = $c->{'request'}->{'parameters'}->{'hidesearch'}         || 0;
    $c->stash->{'hostgroup'}          = $c->{'request'}->{'parameters'}->{'hostgroup'}          || '';
    $c->stash->{'servicegroup'}       = $c->{'request'}->{'parameters'}->{'servicegroup'}       || '';
    $c->stash->{'host'}               = $c->{'request'}->{'parameters'}->{'host'}               || '';
    $c->stash->{'data'}               = "";
    $c->stash->{'style'}              = "";
    $c->stash->{'has_error'}          = 0;
    $c->stash->{'pager'}              = "";

    $style = 'detail' unless defined $allowed_subpages->{$style};

    # did we get a search request?
    if( defined $c->{'request'}->{'parameters'}->{'navbarsearch'} and $c->{'request'}->{'parameters'}->{'navbarsearch'} eq '1' ) {
        $style = $self->_process_search_request($c);
    }

    $c->stash->{title}        = 'Current Network Status';
    $c->stash->{infoBoxTitle} = 'Current Network Status';
    $c->stash->{page}         = 'status';
    $c->stash->{template}     = 'status_' . $style . '.tt';
    $c->stash->{style}        = $style;

    # raw data request?
    $c->stash->{'output_format'} = $c->{'request'}->{'parameters'}->{'format'} || 'html';
    if( $c->stash->{'output_format'} ne 'html' ) {
        $self->_process_raw_request($c);
        return 1;
    }

    # normal pages
    elsif ( $style eq 'detail' ) {
        $self->_process_details_page($c);
    }
    elsif ( $style eq 'hostdetail' ) {
        $self->_process_hostdetails_page($c);
    }
    elsif ( $style eq 'overview' ) {
        $self->_process_overview_page($c);
    }
    elsif ( $style eq 'grid' ) {
        $self->_process_grid_page($c);
    }
    elsif ( $style eq 'summary' ) {
        $self->_process_summary_page($c);
    }
    elsif ( $style eq 'bothtypes' ) {
        $self->_process_bothtypes_page($c);
    }
    elsif ( $style eq 'combined' ) {
        $self->_process_combined_page($c);
    }


    Thruk::Utils::ssi_include($c);

    $c->stash->{custom_title} = '';
    if( exists $c->{'request'}->{'parameters'}->{'title'} ) {
        my $custom_title = $c->{'request'}->{'parameters'}->{'title'};
        $custom_title =~ s/\+/\ /gmx;
        $c->stash->{custom_title} = $custom_title;
        $c->stash->{title} = $custom_title;
    }

    return 1;
}

##########################################################
# check for search results
sub _process_raw_request {
    my( $self, $c ) = @_;

    if( $c->stash->{'output_format'} eq 'search' ) {
        my( $hostgroups, $servicegroups, $hosts, $services );
        if( $c->config->{ajax_search_hostgroups} ) {
            $hostgroups = $c->{'db'}->get_hostgroup_names( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ) ] );
        }
        if( $c->config->{ajax_search_servicegroups} ) {
            $servicegroups = $c->{'db'}->get_servicegroup_names( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'servicegroups' ) ] );
        }
        if( $c->config->{ajax_search_hosts} ) {
            $hosts = $c->{'db'}->get_host_names( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );
        }
        if( $c->config->{ajax_search_services} ) {
            $services = $c->{'db'}->get_service_names( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ] );
        }
        my $json = [ { 'name' => 'hostgroups', 'data' => $hostgroups }, { 'name' => 'servicegroups', 'data' => $servicegroups }, { 'name' => 'hosts', 'data' => $hosts }, { 'name' => 'services', 'data' => $services }, ];
        $c->stash->{'json'} = $json;
        $c->forward('Thruk::View::JSON');
        return;
    }

    # which host to display?
    my( $hostfilter, $servicefilter, $groupfilter ) = $self->_do_filter($c);
    return if $c->stash->{'has_error'};

    my $limit = $c->{'request'}->{'parameters'}->{'limit'} || 0;

    my @columns = qw/
        comments
        has_been_checked
        state
        name
        address
        acknowledged
        notifications_enabled
        active_checks_enabled
        is_flapping
        scheduled_downtime_depth
        is_executing
        notes_url_expanded
        action_url_expanded
        icon_image_expanded
        icon_image_alt
        last_check
        last_state_change
        plugin_output
        next_check
        long_plugin_output/;

    if( defined $c->{'request'}->{'parameters'}->{'column'} ) {
        if( ref $c->{'request'}->{'parameters'}->{'column'} eq 'ARRAY' ) {
            @columns = @{ $c->{'request'}->{'parameters'}->{'column'} };
        }
        else {
            @columns = ( $c->{'request'}->{'parameters'}->{'column'} );
        }
    }

    my $hosts = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ], columns => \@columns, limit => $limit );
    $c->stash->{'json'} = $hosts;
    $c->forward('Thruk::View::JSON');

    return 1;
}

##########################################################
# check for search results
sub _process_search_request {
    my( $self, $c ) = @_;

    # search pattern is in host param
    my $host = $c->{'request'}->{'parameters'}->{'host'};
    $c->{'request'}->{'parameters'}->{'hidesearch'} = 2;    # force show search

    return ('detail') unless defined $host;

    # is there a servicegroup with this name?
    my $servicegroups = $c->{'db'}->get_servicegroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'servicegroups' ), 'name' => $host ] );
    if( scalar @{$servicegroups} > 0 ) {
        delete $c->{'request'}->{'parameters'}->{'host'};
        $c->{'request'}->{'parameters'}->{'servicegroup'} = $host;
        return ('overview');
    }

    # is there a hostgroup with this name?
    my $hostgroups = $c->{'db'}->get_hostgroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ), 'name' => $host ] );
    if( scalar @{$hostgroups} > 0 ) {
        delete $c->{'request'}->{'parameters'}->{'host'};
        $c->{'request'}->{'parameters'}->{'hostgroup'} = $host;
        return ('overview');
    }

    return ('detail');
}

##########################################################
# create the status details page
sub _process_details_page {
    my( $self, $c ) = @_;

    # which host to display?
    my( $hostfilter, $servicefilter, $groupfilter ) = $self->_do_filter($c);
    return if $c->stash->{'has_error'};

    # add comments and downtimes
    my $comments = $c->{'db'}->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ) ] );
    my $downtimes = $c->{'db'}->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ) ] );
    my $downtimes_by_host;
    my $downtimes_by_host_service;
    if($downtimes) {
        for my $downtime ( @{$downtimes} ) {
            if( defined $downtime->{'service_description'} and $downtime->{'service_description'} ne '' ) {
                push @{ $downtimes_by_host_service->{ $downtime->{'host_name'} }->{ $downtime->{'service_description'} } }, $downtime;
            }
            else {
                push @{ $downtimes_by_host->{ $downtime->{'host_name'} } }, $downtime;
            }
        }
    }
    $c->stash->{'downtimes_by_host'}         = $downtimes_by_host;
    $c->stash->{'downtimes_by_host_service'} = $downtimes_by_host_service;
    my $comments_by_host;
    my $comments_by_host_service;
    if($comments) {
        for my $comment ( @{$comments} ) {
            if( defined $comment->{'service_description'} and $comment->{'service_description'} ne '' ) {
                push @{ $comments_by_host_service->{ $comment->{'host_name'} }->{ $comment->{'service_description'} } }, $comment;
            }
            else {
                push @{ $comments_by_host->{ $comment->{'host_name'} } }, $comment;
            }
        }
    }
    $c->stash->{'comments_by_host'}         = $comments_by_host;
    $c->stash->{'comments_by_host_service'} = $comments_by_host_service;

    # do the sort
    my $sorttype   = $c->{'request'}->{'parameters'}->{'sorttype'}   || 1;
    my $sortoption = $c->{'request'}->{'parameters'}->{'sortoption'} || 1;
    my $order      = "ASC";
    $order = "DESC" if $sorttype == 2;
    my $sortoptions = {
        '1' => [ [ 'host_name',   'description' ], 'host name' ],
        '2' => [ [ 'description', 'host_name' ],   'service name' ],
        '3' => [ [ 'has_been_checked', 'state', 'host_name', 'description' ], 'service status' ],
        '4' => [ [ 'last_check',             'host_name', 'description' ], 'last check time' ],
        '5' => [ [ 'current_attempt',        'host_name', 'description' ], 'attempt number' ],
        '6' => [ [ 'last_state_change_plus', 'host_name', 'description' ], 'state duration' ],
    };
    $sortoption = 1 if !defined $sortoptions->{$sortoption};

    # get all services
    my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ], sort => { $order => $sortoptions->{$sortoption}->[0] }, pager => $c );
    if( $sortoption == 6 and defined $services ) { @{ $c->stash->{'data'} } = reverse @{ $c->stash->{'data'} }; }

    my $view_mode = $c->{'request'}->{'parameters'}->{'view_mode'} || 'html';
    if( defined $view_mode and $view_mode eq 'xls' ) {
        $self->_set_selected_columns($c);
        my $filename = 'status.xls';
        $c->res->header( 'Content-Disposition', qq[attachment; filename="] . $filename . q["] );
        $c->stash->{'data'}     = $services;
        $c->stash->{'template'} = 'excel/status_detail.tt';
        return $c->detach('View::Excel');
    }

    $c->stash->{'orderby'}  = $sortoptions->{$sortoption}->[1];
    $c->stash->{'orderdir'} = $order;

    return 1;
}

##########################################################
# create the hostdetails page
sub _process_hostdetails_page {
    my( $self, $c ) = @_;

    # which host to display?
    my( $hostfilter, $servicefilter, $groupfilter ) = $self->_do_filter($c);
    return if $c->stash->{'has_error'};

    # add comments and downtimes
    my $comments = $c->{'db'}->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'service_description' => undef } ] );
    my $downtimes = $c->{'db'}->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'service_description' => undef } ] );
    my $downtimes_by_host;
    if($downtimes) {
        for my $downtime ( @{$downtimes} ) {
            push @{ $downtimes_by_host->{ $downtime->{'host_name'} } }, $downtime;
        }
    }
    $c->stash->{'downtimes_by_host'} = $downtimes_by_host;
    my $comments_by_host;
    if($comments) {
        for my $comment ( @{$comments} ) {
            push @{ $comments_by_host->{ $comment->{'host_name'} } }, $comment;
        }
    }
    $c->stash->{'comments_by_host'} = $comments_by_host;

    # do the sort
    my $sorttype   = $c->{'request'}->{'parameters'}->{'sorttype'}   || 1;
    my $sortoption = $c->{'request'}->{'parameters'}->{'sortoption'} || 7;
    my $order      = "ASC";
    $order = "DESC" if $sorttype == 2;
    my $sortoptions = {
        '1' => [ 'name', 'host name' ],
        '4' => [ [ 'last_check',             'name' ], 'last check time' ],
        '6' => [ [ 'last_state_change_plus', 'name' ], 'state duration' ],
        '8' => [ [ 'has_been_checked', 'state', 'name' ], 'host status' ],
    };
    $sortoption = 1 if !defined $sortoptions->{$sortoption};

    # get hosts
    my $hosts = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ], sort => { $order => $sortoptions->{$sortoption}->[0] }, pager => $c );
    if( $sortoption == 6 and defined $hosts ) { @{ $c->stash->{'data'} } = reverse @{ $c->stash->{'data'} }; }

    my $view_mode = $c->{'request'}->{'parameters'}->{'view_mode'} || 'html';
    if( defined $view_mode and $view_mode eq 'xls' ) {
        $self->_set_selected_columns($c);
        my $filename = 'status.xls';
        $c->res->header( 'Content-Disposition', qq[attachment; filename="] . $filename . q["] );
        $c->stash->{'data'}     = $hosts;
        $c->stash->{'template'} = 'excel/status_hostdetail.tt';
        return $c->detach('View::Excel');
    }

    $c->stash->{'orderby'}  = $sortoptions->{$sortoption}->[1];
    $c->stash->{'orderdir'} = $order;

    return 1;
}

##########################################################
# create the status details page
sub _process_overview_page {
    my( $self, $c ) = @_;

    # which host to display?
    my( $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = $self->_do_filter($c);
    return if $c->stash->{'has_error'};

    # we need the hostname, address etc...
    my $host_data;
    my $services_data;
    my $tmp_host_data = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ], columns => [ qw /action_url_expanded notes_url_expanded icon_image_alt icon_image_expanded address has_been_checked name state num_services_pending num_services_ok num_services_warn num_services_unknown num_services_crit/ ] );
    if( defined $tmp_host_data ) {
        for my $host ( @{$tmp_host_data} ) {
            $host_data->{ $host->{'name'} } = $host;
        }
    }

    if( defined $servicegroupfilter or $c->stash->{'servicegroup'} ) {
        # we have to sort in all services and states
        my $tmp_services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ], columns => [ qw /description has_been_checked state host_name/ ] );
        if( defined $tmp_services ) {
            for my $service ( @{$tmp_services} ) {
                next if $service->{'description'} eq '';
                $services_data->{ $service->{'host_name'} }->{ $service->{'description'} } = $service;
            }
        }
    }

    # get all host/service groups
    my $groups;
    if( defined $hostgroupfilter or $c->stash->{'hostgroup'} ) {
        $groups = $c->{'db'}->get_hostgroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ), $hostgroupfilter ] );
    }
    elsif ( defined $servicegroupfilter or $c->stash->{'servicegroup'} ) {
        $groups = $c->{'db'}->get_servicegroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'servicegroups' ), $servicegroupfilter ] );
    }

    # join our groups together
    my %joined_groups;
    for my $group ( @{$groups} ) {

        next if scalar @{ $group->{'members'} } == 0;

        my $name = $group->{'name'};
        if( !defined $joined_groups{$name} ) {
            $joined_groups{$name}->{'name'}  = $group->{'name'};
            $joined_groups{$name}->{'alias'} = $group->{'alias'};
            $joined_groups{$name}->{'hosts'} = {};
        }

        my( $hostname, $servicename );
        if( defined $hostgroupfilter or $c->stash->{'hostgroup'} ) {
            for my $hostname ( @{ $group->{'members'} } ) {

                # show only hosts with proper authorization
                next unless defined $host_data->{$hostname};

                if( !defined $joined_groups{$name}->{'hosts'}->{$hostname} ) {

                    # clone hash data
                    for my $key ( keys %{ $host_data->{$hostname} } ) {
                        $joined_groups{$name}->{'hosts'}->{$hostname}->{$key} = $host_data->{$hostname}->{$key};
                    }
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'pending'}  = 0;
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'ok'}       = 0;
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'warning'}  = 0;
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'unknown'}  = 0;
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'critical'} = 0;
                }
                $joined_groups{$name}->{'hosts'}->{$hostname}->{'pending'}  += $host_data->{$hostname}->{'num_services_pending'};
                $joined_groups{$name}->{'hosts'}->{$hostname}->{'ok'}       += $host_data->{$hostname}->{'num_services_ok'};
                $joined_groups{$name}->{'hosts'}->{$hostname}->{'warning'}  += $host_data->{$hostname}->{'num_services_warn'};
                $joined_groups{$name}->{'hosts'}->{$hostname}->{'unknown'}  += $host_data->{$hostname}->{'num_services_unknown'};
                $joined_groups{$name}->{'hosts'}->{$hostname}->{'critical'} += $host_data->{$hostname}->{'num_services_crit'};
            }
        }
        elsif ( defined $servicegroupfilter or $c->stash->{'servicegroup'} ) {
            for my $member ( @{ $group->{'members'} } ) {
                my( $hostname, $servicename ) = @{$member};

                # show only hosts with proper authorization
                next unless defined $host_data->{$hostname};

                if( !defined $joined_groups{$name}->{'hosts'}->{$hostname} ) {

                    # clone hash data
                    for my $key ( keys %{ $host_data->{$hostname} } ) {
                        $joined_groups{$name}->{'hosts'}->{$hostname}->{$key} = $host_data->{$hostname}->{$key};
                    }
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'pending'}  = 0;
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'ok'}       = 0;
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'warning'}  = 0;
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'unknown'}  = 0;
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'critical'} = 0;
                }

                my $state            = $services_data->{$hostname}->{$servicename}->{'state'};
                my $has_been_checked = $services_data->{$hostname}->{$servicename}->{'has_been_checked'};
                if( !$has_been_checked ) {
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'pending'}++;
                }
                elsif ( $state == 0 ) {
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'ok'}++;
                }
                elsif ( $state == 1 ) {
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'warning'}++;
                }
                elsif ( $state == 2 ) {
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'critical'}++;
                }
                elsif ( $state == 3 ) {
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'unknown'}++;
                }
            }
        }

        # remove empty groups
        if( scalar keys %{ $joined_groups{$name}->{'hosts'} } == 0 ) {
            delete $joined_groups{$name};
        }
    }

    my $sortedgroups = Thruk::Backend::Manager::_sort($c, [(values %joined_groups)], { 'ASC' => 'name'});
    Thruk::Utils::set_paging_steps($c, Thruk->config->{'group_paging_overview'});
    Thruk::Backend::Manager::_page_data(undef, $c, $sortedgroups);

    return 1;
}

##########################################################
# create the status grid page
sub _process_grid_page {
    my( $self, $c ) = @_;

    # which host to display?
    my( $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = $self->_do_filter($c);
    return if $c->stash->{'has_error'};

    # we need the hostname, address etc...
    my $host_data;
    my $tmp_host_data = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ] );
    if( defined $tmp_host_data ) {
        for my $host ( @{$tmp_host_data} ) {
            $host_data->{ $host->{'name'} } = $host;
        }
    }

    # create a hash of all services
    my $services_data;
    my $tmp_services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ] );
    if( defined $tmp_services ) {
        for my $service ( @{$tmp_services} ) {
            $services_data->{ $service->{'host_name'} }->{ $service->{'description'} } = $service;
        }
    }

    # get all host/service groups
    my $groups;
    if( defined $hostgroupfilter or $c->stash->{'hostgroup'} ) {
        $groups = $c->{'db'}->get_hostgroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ), $hostgroupfilter ] );
    }
    elsif ( defined $servicegroupfilter or $c->stash->{'servicegroup'} ) {
        $groups = $c->{'db'}->get_servicegroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'servicegroups' ), $servicegroupfilter ] );
    }

    # sort in hosts / services
    my %joined_groups;
    for my $group ( @{$groups} ) {

        # only need groups with members
        next unless scalar @{ $group->{'members'} } > 0;

        my $name = $group->{'name'};
        if( !defined $joined_groups{$name} ) {
            $joined_groups{$name}->{'name'}  = $group->{'name'};
            $joined_groups{$name}->{'alias'} = $group->{'alias'};
            $joined_groups{$name}->{'hosts'} = {};
        }

        for my $member ( @{ $group->{'members'} } ) {
            my( $hostname, $servicename );
            if( defined $hostgroupfilter or $c->stash->{'hostgroup'} ) {
                $hostname = $member;
            }
            if( defined $servicegroupfilter or $c->stash->{'servicegroup'} ) {
                ( $hostname, $servicename ) = @{$member};
            }

            next unless defined $host_data->{$hostname};

            if( !defined $joined_groups{$name}->{'hosts'}->{$hostname} ) {

                # clone host data
                for my $key ( keys %{ $host_data->{$hostname} } ) {
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{$key} = $host_data->{$hostname}->{$key};
                }
            }

            # add all services
            $joined_groups{$name}->{'hosts'}->{$hostname}->{'services'} = {} unless defined $joined_groups{$name}->{'hosts'}->{$hostname}->{'services'};
            if( defined $hostgroupfilter or $c->stash->{'hostgroup'} ) {
                for my $service ( sort keys %{ $services_data->{$hostname} } ) {
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'services'}->{ $services_data->{$hostname}->{$service}->{'description'} } = $services_data->{$hostname}->{$service};
                }
            }
            elsif ( defined $servicegroupfilter or $c->stash->{'servicegroup'} ) {
                $joined_groups{$name}->{'hosts'}->{$hostname}->{'services'}->{ $services_data->{$hostname}->{$servicename}->{'description'} } = $services_data->{$hostname}->{$servicename};
            }
        }

        # remove empty groups
        if( scalar keys %{ $joined_groups{$name}->{'hosts'} } == 0 ) {
            delete $joined_groups{$name};
        }
    }

    my $sortedgroups = Thruk::Backend::Manager::_sort($c, [(values %joined_groups)], { 'ASC' => 'name'});
    Thruk::Utils::set_paging_steps($c, Thruk->config->{'group_paging_grid'});
    Thruk::Backend::Manager::_page_data(undef, $c, $sortedgroups);

    return 1;
}

##########################################################
# create the status summary page
sub _process_summary_page {
    my( $self, $c ) = @_;

    # which host to display?
    my( $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = $self->_do_filter($c);
    return if $c->stash->{'has_error'};

    # get all host/service groups
    my $groups;
    if( defined $hostgroupfilter or $c->stash->{'hostgroup'} ) {
        $groups = $c->{'db'}->get_hostgroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ), $hostgroupfilter ] );
    }
    elsif ( defined $servicegroupfilter or $c->stash->{'servicegroup'} ) {
        $groups = $c->{'db'}->get_servicegroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'servicegroups' ), $servicegroupfilter ] );
    }

    # set defaults for all groups
    my $all_groups;
    for my $group ( @{$groups} ) {
        $group->{'hosts_pending'}                      = 0;
        $group->{'hosts_up'}                           = 0;
        $group->{'hosts_down'}                         = 0;
        $group->{'hosts_down_unhandled'}               = 0;
        $group->{'hosts_down_downtime'}                = 0;
        $group->{'hosts_down_ack'}                     = 0;
        $group->{'hosts_down_disabled_active'}         = 0;
        $group->{'hosts_down_disabled_passive'}        = 0;
        $group->{'hosts_unreachable'}                  = 0;
        $group->{'hosts_unreachable_unhandled'}        = 0;
        $group->{'hosts_unreachable_downtime'}         = 0;
        $group->{'hosts_unreachable_ack'}              = 0;
        $group->{'hosts_unreachable_disabled_active'}  = 0;
        $group->{'hosts_unreachable_disabled_passive'} = 0;

        $group->{'services_pending'}                   = 0;
        $group->{'services_ok'}                        = 0;
        $group->{'services_warning'}                   = 0;
        $group->{'services_warning_unhandled'}         = 0;
        $group->{'services_warning_downtime'}          = 0;
        $group->{'services_warning_prob_host'}         = 0;
        $group->{'services_warning_ack'}               = 0;
        $group->{'services_warning_disabled_active'}   = 0;
        $group->{'services_warning_disabled_passive'}  = 0;
        $group->{'services_unknown'}                   = 0;
        $group->{'services_unknown_unhandled'}         = 0;
        $group->{'services_unknown_downtime'}          = 0;
        $group->{'services_unknown_prob_host'}         = 0;
        $group->{'services_unknown_ack'}               = 0;
        $group->{'services_unknown_disabled_active'}   = 0;
        $group->{'services_unknown_disabled_passive'}  = 0;
        $group->{'services_critical'}                  = 0;
        $group->{'services_critical_unhandled'}        = 0;
        $group->{'services_critical_downtime'}         = 0;
        $group->{'services_critical_prob_host'}        = 0;
        $group->{'services_critical_ack'}              = 0;
        $group->{'services_critical_disabled_active'}  = 0;
        $group->{'services_critical_disabled_passive'} = 0;
        $all_groups->{ $group->{'name'} }              = $group;
    }

    my $services_data;
    my $groupsname = "host_groups";
    if( defined $hostgroupfilter or $c->stash->{'hostgroup'} ) {

        # we need the hosts data
        my $host_data = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ] );

        # create a hash of all services
        $services_data = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ] );

        for my $host ( @{$host_data} ) {
            for my $group ( @{ $host->{'groups'} } ) {
                next if !defined $all_groups->{$group};
                $self->_summary_add_host_stats( "", $all_groups->{$group}, $host );
            }
        }
    }

    if( defined $servicegroupfilter or $c->stash->{'servicegroup'} ) {

        # create a hash of all services
        $services_data = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ] );
        $groupsname = "groups";
    }

    my %host_already_added;
    for my $service ( @{$services_data} ) {
        for my $group ( @{ $service->{$groupsname} } ) {
            next if !defined $all_groups->{$group};

            if( defined $servicegroupfilter or $c->stash->{'servicegroup'} ) {
                if( !defined $host_already_added{$group}->{ $service->{'host_name'} } ) {
                    $self->_summary_add_host_stats( "host_", $all_groups->{$group}, $service );
                    $host_already_added{$group}->{ $service->{'host_name'} } = 1;
                }
            }

            $all_groups->{$group}->{'services_total'}++;

            if( $service->{'has_been_checked'} == 0 ) { $all_groups->{$group}->{'services_pending'}++; }
            elsif ( $service->{'state'} == 0 ) { $all_groups->{$group}->{'services_ok'}++; }
            elsif ( $service->{'state'} == 1 ) { $all_groups->{$group}->{'services_warning'}++; }
            elsif ( $service->{'state'} == 2 ) { $all_groups->{$group}->{'services_critical'}++; }
            elsif ( $service->{'state'} == 3 ) { $all_groups->{$group}->{'services_unknown'}++; }

            if( $service->{'state'} == 1 and $service->{'scheduled_downtime_depth'} > 0 ) { $all_groups->{$group}->{'services_warning_downtime'}++; }
            if( $service->{'state'} == 1 and $service->{'acknowledged'} == 1 )            { $all_groups->{$group}->{'services_warning_ack'}++; }
            if( $service->{'state'} == 1 and $service->{'checks_enabled'} == 0 and $service->{'check_type'} == 0 ) { $all_groups->{$group}->{'services_warning_disabled_active'}++; }
            if( $service->{'state'} == 1 and $service->{'checks_enabled'} == 0 and $service->{'check_type'} == 1 ) { $all_groups->{$group}->{'services_warning_disabled_passive'}++; }
            if( $service->{'state'} == 1 and $service->{'host_state'} > 0 )               { $all_groups->{$group}->{'services_warning_prob_host'}++; }
            elsif ( $service->{'state'} == 1 and $service->{'checks_enabled'} == 1 and $service->{'host_state'} == 0 and $service->{'acknowledged'} == 0 and $service->{'scheduled_downtime_depth'} == 0 ) { $all_groups->{$group}->{'services_warning_unhandled'}++; }

            if( $service->{'state'} == 2 and $service->{'scheduled_downtime_depth'} > 0 ) { $all_groups->{$group}->{'services_critical_downtime'}++; }
            if( $service->{'state'} == 2 and $service->{'acknowledged'} == 1 )            { $all_groups->{$group}->{'services_critical_ack'}++; }
            if( $service->{'state'} == 2 and $service->{'checks_enabled'} == 0 and $service->{'check_type'} == 0 ) { $all_groups->{$group}->{'services_critical_disabled_active'}++; }
            if( $service->{'state'} == 2 and $service->{'checks_enabled'} == 0 and $service->{'check_type'} == 1 ) { $all_groups->{$group}->{'services_critical_disabled_passive'}++; }
            if( $service->{'state'} == 2 and $service->{'host_state'} > 0 )               { $all_groups->{$group}->{'services_critical_prob_host'}++; }
            elsif ( $service->{'state'} == 2 and $service->{'checks_enabled'} == 1 and $service->{'host_state'} == 0 and $service->{'acknowledged'} == 0 and $service->{'scheduled_downtime_depth'} == 0 ) { $all_groups->{$group}->{'services_critical_unhandled'}++; }

            if( $service->{'state'} == 3 and $service->{'scheduled_downtime_depth'} > 0 ) { $all_groups->{$group}->{'services_unknown_downtime'}++; }
            if( $service->{'state'} == 3 and $service->{'acknowledged'} == 1 )            { $all_groups->{$group}->{'services_unknown_ack'}++; }
            if( $service->{'state'} == 3 and $service->{'checks_enabled'} == 0 and $service->{'check_type'} == 0 ) { $all_groups->{$group}->{'services_unknown_disabled_active'}++; }
            if( $service->{'state'} == 3 and $service->{'checks_enabled'} == 0 and $service->{'check_type'} == 1 ) { $all_groups->{$group}->{'services_unknown_disabled_passive'}++; }
            if( $service->{'state'} == 3 and $service->{'host_state'} > 0 )               { $all_groups->{$group}->{'services_unknown_prob_host'}++; }
            elsif ( $service->{'state'} == 3 and $service->{'checks_enabled'} == 1 and $service->{'host_state'} == 0 and $service->{'acknowledged'} == 0 and $service->{'scheduled_downtime_depth'} == 0 ) { $all_groups->{$group}->{'services_unknown_unhandled'}++; }
        }
    }

    for my $group ( values %{$all_groups} ) {

        # remove empty groups
        $group->{'services_total'} = 0 unless defined $group->{'services_total'};
        $group->{'hosts_total'}    = 0 unless defined $group->{'hosts_total'};
        if( $group->{'services_total'} + $group->{'hosts_total'} == 0 ) {
            delete $all_groups->{ $group->{'name'} };
        }
    }

    my $sortedgroups = Thruk::Backend::Manager::_sort($c, [(values %{$all_groups})], { 'ASC' => 'name'});
    Thruk::Utils::set_paging_steps($c, Thruk->config->{'group_paging_summary'});
    Thruk::Backend::Manager::_page_data(undef, $c, $sortedgroups);

    return 1;
}


##########################################################
# create the status details page
sub _process_combined_page {
    my( $self, $c ) = @_;

    $c->stash->{hidetop}    = 1 unless $c->stash->{hidetop} ne '';
    $c->stash->{hidesearch} = 1;

    # which host to display?
    my( $hostfilter)           = $self->_do_filter($c, 'hst_');
    my( undef, $servicefilter) = $self->_do_filter($c, 'svc_');
    return if $c->stash->{'has_error'};

    # add comments and downtimes
    my $comments = $c->{'db'}->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ) ] );
    my $downtimes = $c->{'db'}->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ) ] );
    my $downtimes_by_host;
    my $downtimes_by_host_service;
    if($downtimes) {
        for my $downtime ( @{$downtimes} ) {
            if( defined $downtime->{'service_description'} and $downtime->{'service_description'} ne '' ) {
                push @{ $downtimes_by_host_service->{ $downtime->{'host_name'} }->{ $downtime->{'service_description'} } }, $downtime;
            }
            else {
                push @{ $downtimes_by_host->{ $downtime->{'host_name'} } }, $downtime;
            }
        }
    }
    $c->stash->{'downtimes_by_host'}         = $downtimes_by_host;
    $c->stash->{'downtimes_by_host_service'} = $downtimes_by_host_service;
    my $comments_by_host;
    my $comments_by_host_service;
    if($comments) {
        for my $comment ( @{$comments} ) {
            if( defined $comment->{'service_description'} and $comment->{'service_description'} ne '' ) {
                push @{ $comments_by_host_service->{ $comment->{'host_name'} }->{ $comment->{'service_description'} } }, $comment;
            }
            else {
                push @{ $comments_by_host->{ $comment->{'host_name'} } }, $comment;
            }
        }
    }
    $c->stash->{'comments_by_host'}         = $comments_by_host;
    $c->stash->{'comments_by_host_service'} = $comments_by_host_service;

    my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ], pager => $c );
    my $hosts    = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ], pager => $c );

    $c->stash->{'services'} = $services;
    $c->stash->{'hosts'}    = $hosts;

    return 1;
}


##########################################################
# create the status details page
sub _process_bothtypes_page {
    my( $self, $c ) = @_;

    # which host to display?
    my( $hostfilter, $servicefilter, $groupfilter ) = $self->_do_filter($c);
    return if $c->stash->{'has_error'};

    # add comments and downtimes
    my $comments = $c->{'db'}->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ) ] );
    my $downtimes = $c->{'db'}->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ) ] );
    my $downtimes_by_host;
    my $downtimes_by_host_service;
    if($downtimes) {
        for my $downtime ( @{$downtimes} ) {
            if( defined $downtime->{'service_description'} and $downtime->{'service_description'} ne '' ) {
                push @{ $downtimes_by_host_service->{ $downtime->{'host_name'} }->{ $downtime->{'service_description'} } }, $downtime;
            }
            else {
                push @{ $downtimes_by_host->{ $downtime->{'host_name'} } }, $downtime;
            }
        }
    }
    $c->stash->{'downtimes_by_host'}         = $downtimes_by_host;
    $c->stash->{'downtimes_by_host_service'} = $downtimes_by_host_service;
    my $comments_by_host;
    my $comments_by_host_service;
    if($comments) {
        for my $comment ( @{$comments} ) {
            if( defined $comment->{'service_description'} and $comment->{'service_description'} ne '' ) {
                push @{ $comments_by_host_service->{ $comment->{'host_name'} }->{ $comment->{'service_description'} } }, $comment;
            }
            else {
                push @{ $comments_by_host->{ $comment->{'host_name'} } }, $comment;
            }
        }
    }
    $c->stash->{'comments_by_host'}         = $comments_by_host;
    $c->stash->{'comments_by_host_service'} = $comments_by_host_service;

    # do the sort
    my $sorttype   = $c->{'request'}->{'parameters'}->{'sorttype'}   || 1;
    my $sortoption = $c->{'request'}->{'parameters'}->{'sortoption'} || 1;
    my $order      = "ASC";
    $order = "DESC" if $sorttype == 2;
    my $sortoptions = {
        '1' => [ [ 'host_name',   'description' ], 'host name' ],
        '2' => [ [ 'description', 'host_name' ],   'service name' ],
        '3' => [ [ 'has_been_checked', 'state', 'host_name', 'description' ], 'service status' ],
        '4' => [ [ 'last_check',             'host_name', 'description' ], 'last check time' ],
        '5' => [ [ 'current_attempt',        'host_name', 'description' ], 'attempt number' ],
        '6' => [ [ 'last_state_change_plus', 'host_name', 'description' ], 'state duration' ],
    };
    $sortoption = 1 if !defined $sortoptions->{$sortoption};

    # get all services
    my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ], sort => { $order => $sortoptions->{$sortoption}->[0] }, pager => $c );
    my $hosts    = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ], sort => { $order => $sortoptions->{$sortoption}->[0] }, pager => $c );
    if( $sortoption == 6 and defined $services ) { @{ $c->stash->{'data'} } = reverse @{ $c->stash->{'data'} }; }

    my $view_mode = $c->{'request'}->{'parameters'}->{'view_mode'} || 'html';
    if( defined $view_mode and $view_mode eq 'xls' ) {
        $self->_set_selected_columns($c);
        my $filename = 'status.xls';
        $c->res->header( 'Content-Disposition', qq[attachment; filename="] . $filename . q["] );
        $c->stash->{'servicedata'}     = $services;
        $c->stash->{'hostdata'}     = $hosts;
        $c->stash->{'template'} = 'excel/status_detail.tt';
        return $c->detach('View::Excel');
    }

    $c->stash->{'servicedata'} = $services;
    $c->stash->{'hostdata'}    = $hosts;
    $c->stash->{'orderby'}     = $sortoptions->{$sortoption}->[1];
    $c->stash->{'orderdir'}    = $order;

    return 1;
}


##########################################################
sub _summary_add_host_stats {
    my $self   = shift;
    my $prefix = shift;
    my $group  = shift;
    my $host   = shift;

    $group->{'hosts_total'}++;

    if( $host->{ $prefix . 'has_been_checked' } == 0 ) { $group->{'hosts_pending'}++; }
    elsif ( $host->{ $prefix . 'state' } == 0 ) { $group->{'hosts_up'}++; }
    elsif ( $host->{ $prefix . 'state' } == 1 ) { $group->{'hosts_down'}++; }
    elsif ( $host->{ $prefix . 'state' } == 2 ) { $group->{'hosts_unreachable'}++; }

    if( $host->{ $prefix . 'state' } == 1 and $host->{ $prefix . 'scheduled_downtime_depth' } > 0 ) { $group->{'hosts_down_downtime'}++; }
    if( $host->{ $prefix . 'state' } == 1 and $host->{ $prefix . 'acknowledged' } == 1 )            { $group->{'hosts_down_ack'}++; }
    if( $host->{ $prefix . 'state' } == 1 and $host->{ $prefix . 'checks_enabled' } == 1 and $host->{ $prefix . 'acknowledged' } == 0 and $host->{ $prefix . 'scheduled_downtime_depth' } == 0 ) { $group->{'hosts_down_unhandled'}++; }

    if( $host->{ $prefix . 'state' } == 1 and $host->{ $prefix . 'checks_enabled' } == 0 and $host->{ $prefix . 'check_type' } == 0 ) { $group->{'hosts_down_disabled_active'}++; }
    if( $host->{ $prefix . 'state' } == 1 and $host->{ $prefix . 'checks_enabled' } == 0 and $host->{ $prefix . 'check_type' } == 1 ) { $group->{'hosts_down_disabled_passive'}++; }

    if( $host->{ $prefix . 'state' } == 2 and $host->{ $prefix . 'scheduled_downtime_depth' } > 0 ) { $group->{'hosts_unreachable_downtime'}++; }
    if( $host->{ $prefix . 'state' } == 2 and $host->{ $prefix . 'acknowledged' } == 1 )            { $group->{'hosts_unreachable_ack'}++; }
    if( $host->{ $prefix . 'state' } == 2 and $host->{ $prefix . 'checks_enabled' } == 0 and $host->{ $prefix . 'check_type' } == 0 ) { $group->{'hosts_unreachable_disabled_active'}++; }
    if( $host->{ $prefix . 'state' } == 2 and $host->{ $prefix . 'checks_enabled' } == 0 and $host->{ $prefix . 'check_type' } == 1 ) { $group->{'hosts_unreachable_disabled_passive'}++; }
    if( $host->{ $prefix . 'state' } == 2 and $host->{ $prefix . 'checks_enabled' } == 1 and $host->{ $prefix . 'acknowledged' } == 0 and $host->{ $prefix . 'scheduled_downtime_depth' } == 0 ) { $group->{'hosts_unreachable_unhandled'}++; }

    return 1;
}

##########################################################
sub _fill_totals_box {
    my( $self, $c, $hostfilter, $servicefilter ) = @_;

    # host status box
    my $host_stats = {};
    if(   $c->stash->{style} eq 'detail'
       or ( $c->stash->{'servicegroup'}
            and ( $c->stash->{style} eq 'overview' or $c->stash->{style} eq 'grid' or $c->stash->{style} eq 'summary' )
          )
      ) {
        # set host status from service query
        my $services = $c->{'db'}->get_hosts_by_servicequery( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ] );
        $host_stats = {
            'pending'     => 0,
            'up'          => 0,
            'down'        => 0,
            'unreachable' => 0,
        };
        my %hosts;
        for my $service (@{$services}) {
            next if defined $hosts{$service->{'host_name'}};
            $hosts{$service->{'host_name'}} = 1;

            if($service->{'host_has_been_checked'} == 0) {
                $host_stats->{'pending'}++;
            } else{
                $host_stats->{'up'}++          if $service->{'host_state'} == 0;
                $host_stats->{'down'}++        if $service->{'host_state'} == 1;
                $host_stats->{'unreachable'}++ if $service->{'host_state'} == 2;
            }
        }
    } else {
        $host_stats = $c->{'db'}->get_host_stats( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ] );
    }
    $c->stash->{'host_stats'} = $host_stats;

    # services status box
    my $service_stats = $c->{'db'}->get_service_stats( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ] );

    $c->stash->{'service_stats'} = $service_stats;

    return 1;
}

##########################################################
sub _extend_filter {
    my( $self, $c, $hostfilter, $servicefilter, $hoststatustypes, $hostprops, $servicestatustypes, $serviceprops ) = @_;

    my @hostfilter;
    my @servicefilter;

    push @hostfilter,    $hostfilter    if defined $hostfilter;
    push @servicefilter, $servicefilter if defined $servicefilter;

    $c->stash->{'show_filter_table'} = 0;

    # host statustype filter (up,down,...)
    my( $host_statustype_filtername, $host_statustype_filter, $host_statustype_filter_service );
    ( $hoststatustypes, $host_statustype_filtername, $host_statustype_filter, $host_statustype_filter_service ) = $self->_get_host_statustype_filter($hoststatustypes);
    push @hostfilter,    $host_statustype_filter         if defined $host_statustype_filter;
    push @servicefilter, $host_statustype_filter_service if defined $host_statustype_filter_service;

    $c->stash->{'show_filter_table'} = 1 if defined $host_statustype_filter;

    # host props filter (downtime, acknowledged...)
    my( $host_prop_filtername, $host_prop_filter, $host_prop_filter_service );
    ( $hostprops, $host_prop_filtername, $host_prop_filter, $host_prop_filter_service ) = $self->_get_host_prop_filter($hostprops);
    push @hostfilter,    $host_prop_filter         if defined $host_prop_filter;
    push @servicefilter, $host_prop_filter_service if defined $host_prop_filter_service;

    $c->stash->{'show_filter_table'} = 1 if defined $host_prop_filter;

    # service statustype filter (ok,warning,...)
    my( $service_statustype_filtername, $service_statustype_filter_service );
    ( $servicestatustypes, $service_statustype_filtername, $service_statustype_filter_service ) = $self->_get_service_statustype_filter($servicestatustypes);
    push @servicefilter, $service_statustype_filter_service if defined $service_statustype_filter_service;

    $c->stash->{'show_filter_table'} = 1 if defined $service_statustype_filter_service;

    # service props filter (downtime, acknowledged...)
    my( $service_prop_filtername, $service_prop_filter_service );
    ( $serviceprops, $service_prop_filtername, $service_prop_filter_service ) = $self->_get_service_prop_filter($serviceprops);
    push @servicefilter, $service_prop_filter_service if defined $service_prop_filter_service;

    $c->stash->{'show_filter_table'} = 1 if defined $service_prop_filter_service;

    $hostfilter    = Thruk::Utils::combine_filter( '-and', \@hostfilter );
    $servicefilter = Thruk::Utils::combine_filter( '-and', \@servicefilter );

    return ( $hostfilter, $servicefilter, $host_statustype_filtername, $host_prop_filtername, $service_statustype_filtername, $service_prop_filtername, $hoststatustypes, $hostprops, $servicestatustypes, $serviceprops );
}

##########################################################
sub _get_host_statustype_filter {
    my( $self, $number ) = @_;
    my @hoststatusfilter;
    my @servicestatusfilter;

    $number = 15 if !defined $number or $number !~ m/^\d+$/mx or $number <= 0 or $number > 15;
    my $hoststatusfiltername = 'All';
    if( $number and $number != 15 ) {
        my @hoststatusfiltername;
        my @bits = reverse split( /\ */mx, unpack( "B*", pack( "n", int($number) ) ) );

        if( $bits[0] ) {    # 1 - pending
            push @hoststatusfilter,    { has_been_checked      => 0 };
            push @servicestatusfilter, { host_has_been_checked => 0 };
            push @hoststatusfiltername, 'Pending';
        }
        if( $bits[1] ) {    # 2 - up
            push @hoststatusfilter,    { -and => { has_been_checked      => 1, state      => 0 } };
            push @servicestatusfilter, { -and => { host_has_been_checked => 1, host_state => 0 } };
            push @hoststatusfiltername, 'Up';
        }
        if( $bits[2] ) {    # 4 - down
            push @hoststatusfilter,    { -and => { has_been_checked      => 1, state      => 1 } };
            push @servicestatusfilter, { -and => { host_has_been_checked => 1, host_state => 1 } };
            push @hoststatusfiltername, 'Down';
        }
        if( $bits[3] ) {    # 8 - unreachable
            push @hoststatusfilter,    { -and => { has_been_checked      => 1, state      => 2 } };
            push @servicestatusfilter, { -and => { host_has_been_checked => 1, host_state => 2 } };
            push @hoststatusfiltername, 'Unreachable';
        }
        $hoststatusfiltername = join( ' | ', @hoststatusfiltername );
        $hoststatusfiltername = 'All problems' if $number == 12;
    }

    my $hostfilter    = Thruk::Utils::combine_filter( '-or', \@hoststatusfilter );
    my $servicefilter = Thruk::Utils::combine_filter( '-or', \@servicestatusfilter );

    return ( $number, $hoststatusfiltername, $hostfilter, $servicefilter );
}

##########################################################
sub _get_host_prop_filter {
    my( $self, $number ) = @_;

    my @host_prop_filter;
    my @host_prop_filter_service;

    $number = 0 if !defined $number or $number !~ m/^\d+$/mx or $number <= 0 or $number > 1048575;
    my $host_prop_filtername = 'Any';
    if( $number > 0 ) {
        my @host_prop_filtername;
        my @bits = reverse split( /\ */mx, unpack( "B*", pack( "N", int($number) ) ) );

        if( $bits[0] ) {    # 1 - In Scheduled Downtime
            push @host_prop_filter,         { scheduled_downtime_depth      => { '>' => 0 } };
            push @host_prop_filter_service, { host_scheduled_downtime_depth => { '>' => 0 } };
            push @host_prop_filtername, 'In Scheduled Downtime';
        }
        if( $bits[1] ) {    # 2 - Not In Scheduled Downtime
            push @host_prop_filter,         { scheduled_downtime_depth      => 0 };
            push @host_prop_filter_service, { host_scheduled_downtime_depth => 0 };
            push @host_prop_filtername, 'Not In Scheduled Downtime';
        }
        if( $bits[2] ) {    # 4 - Has Been Acknowledged
            push @host_prop_filter,         { acknowledged      => 1 };
            push @host_prop_filter_service, { host_acknowledged => 1 };
            push @host_prop_filtername, 'Has Been Acknowledged';
        }
        if( $bits[3] ) {    # 8 - Has Not Been Acknowledged
            push @host_prop_filter,         { acknowledged      => 0 };
            push @host_prop_filter_service, { host_acknowledged => 0 };
            push @host_prop_filtername, 'Has Not Been Acknowledged';
        }
        if( $bits[4] ) {    # 16 - Checks Disabled
            push @host_prop_filter,         { checks_enabled      => 0 };
            push @host_prop_filter_service, { host_checks_enabled => 0 };
            push @host_prop_filtername, 'Checks Disabled';
        }
        if( $bits[5] ) {    # 32 - Checks Enabled
            push @host_prop_filter,         { checks_enabled      => 1 };
            push @host_prop_filter_service, { host_checks_enabled => 1 };
            push @host_prop_filtername, 'Checks Enabled';
        }
        if( $bits[6] ) {    # 64 - Event Handler Disabled
            push @host_prop_filter,         { event_handler_enabled      => 0 };
            push @host_prop_filter_service, { host_event_handler_enabled => 0 };
            push @host_prop_filtername, 'Event Handler Disabled';
        }
        if( $bits[7] ) {    # 128 - Event Handler Enabled
            push @host_prop_filter,         { event_handler_enabled      => 1 };
            push @host_prop_filter_service, { host_event_handler_enabled => 1 };
            push @host_prop_filtername, 'Event Handler Enabled';
        }
        if( $bits[8] ) {    # 256 - Flap Detection Disabled
            push @host_prop_filter,         { flap_detection_enabled      => 0 };
            push @host_prop_filter_service, { host_flap_detection_enabled => 0 };
            push @host_prop_filtername, 'Flap Detection Disabled';
        }
        if( $bits[9] ) {    # 512 - Flap Detection Enabled
            push @host_prop_filter,         { flap_detection_enabled      => 1 };
            push @host_prop_filter_service, { host_flap_detection_enabled => 1 };
            push @host_prop_filtername, 'Flap Detection Enabled';
        }
        if( $bits[10] ) {    # 1024 - Is Flapping
            push @host_prop_filter,         { is_flapping      => 1 };
            push @host_prop_filter_service, { host_is_flapping => 1 };
            push @host_prop_filtername, 'Is Flapping';
        }
        if( $bits[11] ) {    # 2048 - Is Not Flapping
            push @host_prop_filter,         { is_flapping      => 0 };
            push @host_prop_filter_service, { host_is_flapping => 0 };
            push @host_prop_filtername, 'Is Not Flapping';
        }
        if( $bits[12] ) {    # 4096 - Notifications Disabled
            push @host_prop_filter,         { notifications_enabled      => 0 };
            push @host_prop_filter_service, { host_notifications_enabled => 0 };
            push @host_prop_filtername, 'Notifications Disabled';
        }
        if( $bits[13] ) {    # 8192 - Notifications Enabled
            push @host_prop_filter,         { notifications_enabled      => 1 };
            push @host_prop_filter_service, { host_notifications_enabled => 1 };
            push @host_prop_filtername, 'Notifications Enabled';
        }
        if( $bits[14] ) {    # 16384 - Passive Checks Disabled
            push @host_prop_filter,         { accept_passive_checks      => 0 };
            push @host_prop_filter_service, { host_accept_passive_checks => 0 };
            push @host_prop_filtername, 'Passive Checks Disabled';
        }
        if( $bits[15] ) {    # 32768 - Passive Checks Enabled
            push @host_prop_filter,         { accept_passive_checks      => 1 };
            push @host_prop_filter_service, { host_accept_passive_checks => 1 };
            push @host_prop_filtername, 'Passive Checks Enabled';
        }
        if( $bits[16] ) {    # 65536 - Passive Checks
            push @host_prop_filter,         { check_type      => 1 };
            push @host_prop_filter_service, { host_check_type => 1 };
            push @host_prop_filtername, 'Passive Checks';
        }
        if( $bits[17] ) {    # 131072 - Active Checks
            push @host_prop_filter,         { check_type      => 0 };
            push @host_prop_filter_service, { host_check_type => 0 };
            push @host_prop_filtername, 'Active Checks';
        }
        if( $bits[18] ) {    # 262144 - In Hard State
            push @host_prop_filter,         { state_type      => 1 };
            push @host_prop_filter_service, { host_state_type => 1 };
            push @host_prop_filtername, 'In Hard State';
        }
        if( $bits[19] ) {    # 524288 - In Soft State
            push @host_prop_filter,         { state_type      => 0 };
            push @host_prop_filter_service, { host_state_type => 0 };
            push @host_prop_filtername, 'In Soft State';
        }

        $host_prop_filtername = join( ' &amp; ', @host_prop_filtername );
    }

    my $hostfilter    = Thruk::Utils::combine_filter( '-and', \@host_prop_filter );
    my $servicefilter = Thruk::Utils::combine_filter( '-and', \@host_prop_filter_service );

    return ( $number, $host_prop_filtername, $hostfilter, $servicefilter );
}

##########################################################
sub _get_service_statustype_filter {
    my( $self, $number ) = @_;

    my @servicestatusfilter;
    my @servicestatusfiltername;

    $number = 31 if !defined $number or $number !~ m/^\d+$/mx or $number <= 0 or $number > 31;
    my $servicestatusfiltername = 'All';
    if( $number and $number != 31 ) {
        my @bits = reverse split( /\ */mx, unpack( "B*", pack( "n", int($number) ) ) );

        if( $bits[0] ) {    # 1 - pending
            push @servicestatusfilter, { has_been_checked => 0 };
            push @servicestatusfiltername, 'Pending';
        }
        if( $bits[1] ) {    # 2 - ok
            push @servicestatusfilter, { -and => { has_been_checked => 1, state => 0 } };
            push @servicestatusfiltername, 'Ok';
        }
        if( $bits[2] ) {    # 4 - warning
            push @servicestatusfilter, { -and => { has_been_checked => 1, state => 1 } };
            push @servicestatusfiltername, 'Warning';
        }
        if( $bits[3] ) {    # 8 - unknown
            push @servicestatusfilter, { -and => { has_been_checked => 1, state => 3 } };
            push @servicestatusfiltername, 'Unknown';
        }
        if( $bits[4] ) {    # 16 - critical
            push @servicestatusfilter, { -and => { has_been_checked => 1, state => 2 } };
            push @servicestatusfiltername, 'Critical';
        }
        $servicestatusfiltername = join( ' | ', @servicestatusfiltername );
        $servicestatusfiltername = 'All problems' if $number == 28;
    }

    my $servicefilter = Thruk::Utils::combine_filter( '-or', \@servicestatusfilter );

    return ( $number, $servicestatusfiltername, $servicefilter );
}

##########################################################
sub _get_service_prop_filter {
    my( $self, $number ) = @_;

    my @service_prop_filter;
    my @service_prop_filtername;

    $number = 0 if !defined $number or $number !~ m/^\d+$/mx or $number <= 0 or $number > 1048575;
    my $service_prop_filtername = 'Any';
    if( $number > 0 ) {
        my @bits = reverse split( /\ */mx, unpack( "B*", pack( "N", int($number) ) ) );

        if( $bits[0] ) {    # 1 - In Scheduled Downtime
            push @service_prop_filter, { scheduled_downtime_depth => { '>' => 0 } };
            push @service_prop_filtername, 'In Scheduled Downtime';
        }
        if( $bits[1] ) {    # 2 - Not In Scheduled Downtime
            push @service_prop_filter, { scheduled_downtime_depth => 0 };
            push @service_prop_filtername, 'Not In Scheduled Downtime';
        }
        if( $bits[2] ) {    # 4 - Has Been Acknowledged
            push @service_prop_filter, { acknowledged => 1 };
            push @service_prop_filtername, 'Has Been Acknowledged';
        }
        if( $bits[3] ) {    # 8 - Has Not Been Acknowledged
            push @service_prop_filter, { acknowledged => 0 };
            push @service_prop_filtername, 'Has Not Been Acknowledged';
        }
        if( $bits[4] ) {    # 16 - Checks Disabled
            push @service_prop_filter, { checks_enabled => 0 };
            push @service_prop_filtername, 'Active Checks Disabled';
        }
        if( $bits[5] ) {    # 32 - Checks Enabled
            push @service_prop_filter, { checks_enabled => 1 };
            push @service_prop_filtername, 'Active Checks Enabled';
        }
        if( $bits[6] ) {    # 64 - Event Handler Disabled
            push @service_prop_filter, { event_handler_enabled => 0 };
            push @service_prop_filtername, 'Event Handler Disabled';
        }
        if( $bits[7] ) {    # 128 - Event Handler Enabled
            push @service_prop_filter, { event_handler_enabled => 1 };
            push @service_prop_filtername, 'Event Handler Enabled';
        }
        if( $bits[8] ) {    # 256 - Flap Detection Enabled
            push @service_prop_filter, { flap_detection_enabled => 1 };
            push @service_prop_filtername, 'Flap Detection Enabled';
        }
        if( $bits[9] ) {    # 512 - Flap Detection Disabled
            push @service_prop_filter, { flap_detection_enabled => 0 };
            push @service_prop_filtername, 'Flap Detection Disabled';
        }
        if( $bits[10] ) {    # 1024 - Is Flapping
            push @service_prop_filter, { is_flapping => 1 };
            push @service_prop_filtername, 'Is Flapping';
        }
        if( $bits[11] ) {    # 2048 - Is Not Flapping
            push @service_prop_filter, { is_flapping => 0 };
            push @service_prop_filtername, 'Is Not Flapping';
        }
        if( $bits[12] ) {    # 4096 - Notifications Disabled
            push @service_prop_filter, { notifications_enabled => 0 };
            push @service_prop_filtername, 'Notifications Disabled';
        }
        if( $bits[13] ) {    # 8192 - Notifications Enabled
            push @service_prop_filter, { notifications_enabled => 1 };
            push @service_prop_filtername, 'Notifications Enabled';
        }
        if( $bits[14] ) {    # 16384 - Passive Checks Disabled
            push @service_prop_filter, { accept_passive_checks => 0 };
            push @service_prop_filtername, 'Passive Checks Disabled';
        }
        if( $bits[15] ) {    # 32768 - Passive Checks Enabled
            push @service_prop_filter, { accept_passive_checks => 1 };
            push @service_prop_filtername, 'Passive Checks Enabled';
        }
        if( $bits[16] ) {    # 65536 - Passive Checks
            push @service_prop_filter, { check_type => 1 };
            push @service_prop_filtername, 'Passive Checks';
        }
        if( $bits[17] ) {    # 131072 - Active Checks
            push @service_prop_filter, { check_type => 0 };
            push @service_prop_filtername, 'Active Checks';
        }
        if( $bits[18] ) {    # 262144 - In Hard State
            push @service_prop_filter, { state_type => 1 };
            push @service_prop_filtername, 'In Hard State';
        }
        if( $bits[19] ) {    # 524288 - In Soft State
            push @service_prop_filter, { state_type => 0 };
            push @service_prop_filtername, 'In Soft State';
        }

        $service_prop_filtername = join( ' &amp; ', @service_prop_filtername );
    }

    my $servicefilter = Thruk::Utils::combine_filter( '-and', \@service_prop_filter );

    return ( $number, $service_prop_filtername, $servicefilter );
}

##########################################################
sub _do_filter {
    my( $self, $c, $prefix ) = @_;

    my $hostfilter;
    my $servicefilter;
    my $hostgroupfilter;
    my $servicegroupfilter;
    my $searches;

    $prefix = 'dfl_' unless defined $prefix;

    unless ( exists $c->{'request'}->{'parameters'}->{$prefix.'s0_hoststatustypes'}
        or exists $c->{'request'}->{'parameters'}->{$prefix.'s0_type'} )
    {

        # classic search
        my $search;
        ( $search, $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = $self->_classic_filter($c);

        # convert that into a new search
        push @{$searches}, $search;
    }
    else {

        # complex filter search?
        push @{$searches}, $self->_get_search_from_param( $c, $prefix.'s0', 1 );
        for ( my $x = 1; $x <= 99; $x++ ) {
            my $search = $self->_get_search_from_param( $c, $prefix.'s' . $x );
            push @{$searches}, $search if defined $search;
        }
        ( $searches, $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = $self->_do_search( $c, $searches, $prefix );
    }

    $c->stash->{'searches'}->{$prefix} = $searches;

    return ( $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter );
}

##########################################################
sub _classic_filter {
    my( $self, $c ) = @_;

    my $hostfilter;
    my $servicefilter;
    my $hostgroupfilter;
    my $servicegroupfilter;
    my $errors = 0;

    # classic search
    my $host         = $c->{'request'}->{'parameters'}->{'host'}         || '';
    my $hostgroup    = $c->{'request'}->{'parameters'}->{'hostgroup'}    || '';
    my $servicegroup = $c->{'request'}->{'parameters'}->{'servicegroup'} || '';

    $c->stash->{'host'}         = $host;
    $c->stash->{'hostgroup'}    = $hostgroup;
    $c->stash->{'servicegroup'} = $servicegroup;

    if( $host ne 'all' and $host ne '' ) {
        $hostfilter    = [ { 'name'      => $host } ];
        $servicefilter = [ { 'host_name' => $host } ];

        # check for wildcards
        if( CORE::index( $host, '*' ) >= 0 ) {

            # convert wildcards into real regexp
            my $searchhost = $host;
            $searchhost =~ s/\.\*/*/gmx;
            $searchhost =~ s/\*/.*/gmx;
            $errors++ unless Thruk::Utils::is_valid_regular_expression( $c, $searchhost );
            $hostfilter    = [ { 'name'      => { '~~' => $searchhost } } ];
            $servicefilter = [ { 'host_name' => { '~~' => $searchhost } } ];
        }
    }
    elsif ( $hostgroup ne 'all' and $hostgroup ne '' ) {
        $hostfilter    = [ { 'groups'      => { '>=' => $hostgroup } } ];
        $servicefilter = [ { 'host_groups' => { '>=' => $hostgroup } } ];
        $hostgroupfilter = [ { 'name' => $hostgroup } ];
    }
    elsif ( $hostgroup eq 'all' ) {
    }
    elsif ( $servicegroup ne 'all' and $servicegroup ne '' ) {
        $servicefilter = [ { 'groups' => { '>=' => $servicegroup } } ];
        $servicegroupfilter = [ { 'name' => $servicegroup } ];
    }
    elsif ( $servicegroup eq 'all' ) {
    }

    # fill the host/service totals box
    unless($errors) {
        $self->_fill_totals_box( $c, $hostfilter, $servicefilter );
    }

    # then add some more filter based on get parameter
    my $hoststatustypes    = $c->{'request'}->{'parameters'}->{'hoststatustypes'};
    my $hostprops          = $c->{'request'}->{'parameters'}->{'hostprops'};
    my $servicestatustypes = $c->{'request'}->{'parameters'}->{'servicestatustypes'};
    my $serviceprops       = $c->{'request'}->{'parameters'}->{'serviceprops'};

    my( $host_statustype_filtername,  $host_prop_filtername,  $service_statustype_filtername,  $service_prop_filtername );
    my( $host_statustype_filtervalue, $host_prop_filtervalue, $service_statustype_filtervalue, $service_prop_filtervalue );
    ( $hostfilter, $servicefilter, $host_statustype_filtername, $host_prop_filtername, $service_statustype_filtername, $service_prop_filtername, $host_statustype_filtervalue, $host_prop_filtervalue, $service_statustype_filtervalue, $service_prop_filtervalue ) = $self->_extend_filter( $c, $hostfilter, $servicefilter, $hoststatustypes, $hostprops, $servicestatustypes, $serviceprops );

    # create a new style search hash
    my $search = {
        'hoststatustypes'               => $host_statustype_filtervalue,
        'hostprops'                     => $host_prop_filtervalue,
        'servicestatustypes'            => $service_statustype_filtervalue,
        'serviceprops'                  => $service_prop_filtervalue,
        'host_statustype_filtername'    => $host_statustype_filtername,
        'host_prop_filtername'          => $host_prop_filtername,
        'service_statustype_filtername' => $service_statustype_filtername,
        'service_prop_filtername'       => $service_prop_filtername,
        'text_filter'                   => [],
    };

    if( $host ne '' ) {
        push @{ $search->{'text_filter'} },
            {
            'type'  => 'host',
            'value' => $host,
            'op'    => '=',
            };
    }
    elsif ( $hostgroup ne '' ) {
        push @{ $search->{'text_filter'} },
            {
            'type'  => 'hostgroup',
            'value' => $hostgroup,
            'op'    => '=',
            };
    }
    elsif ( $servicegroup ne '' ) {
        push @{ $search->{'text_filter'} },
            {
            'type'  => 'servicegroup',
            'value' => $servicegroup,
            'op'    => '=',
            };
    }

    if($errors) {
        $c->stash->{'has_error'} = 1;
    }

    return ( $search, $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter );
}

##########################################################
sub _get_search_from_param {
    my( $self, $c, $prefix, $force ) = @_;

    unless ( $force || exists $c->{'request'}->{'parameters'}->{ $prefix . '_hoststatustypes' } ) {
        return;
    }

    # use the type or prop without prefix as global overide
    # ex.: hoststatustypes set from the totals link should override all filter
    my $search = {
        'hoststatustypes'    => $c->stash->{'hoststatustypes'}    || $c->{'request'}->{'parameters'}->{ $prefix . '_hoststatustypes' },
        'hostprops'          => $c->stash->{'hostprops'}          || $c->{'request'}->{'parameters'}->{ $prefix . '_hostprops' },
        'servicestatustypes' => $c->stash->{'servicestatustypes'} || $c->{'request'}->{'parameters'}->{ $prefix . '_servicestatustypes' },
        'serviceprops'       => $c->stash->{'serviceprops'}       || $c->{'request'}->{'parameters'}->{ $prefix . '_serviceprops' },
    };

    return $search unless defined $c->{'request'}->{'parameters'}->{ $prefix . '_type' };

    if( ref $c->{'request'}->{'parameters'}->{ $prefix . '_type' } eq 'ARRAY' ) {
        for ( my $x = 0; $x < scalar @{ $c->{'request'}->{'parameters'}->{ $prefix . '_type' } }; $x++ ) {
            my $text_filter = {
                type  => $c->{'request'}->{'parameters'}->{ $prefix . '_type' }->[$x],
                value => $c->{'request'}->{'parameters'}->{ $prefix . '_value' }->[$x],
                op    => $c->{'request'}->{'parameters'}->{ $prefix . '_op' }->[$x],
            };
            push @{ $search->{'text_filter'} }, $text_filter;
        }
    }
    else {
        my $text_filter = {
            type  => $c->{'request'}->{'parameters'}->{ $prefix . '_type' },
            value => $c->{'request'}->{'parameters'}->{ $prefix . '_value' },
            op    => $c->{'request'}->{'parameters'}->{ $prefix . '_op' },
        };
        push @{ $search->{'text_filter'} }, $text_filter;
    }

    return $search;
}

##########################################################
sub _do_search {
    my( $self, $c, $searches, $prefix ) = @_;

    my( @hostfilter, @servicefilter, @hostgroupfilter, @servicegroupfilter, @hosttotalsfilter, @servicetotalsfilter );

    for my $search ( @{$searches} ) {
        my( $tmp_hostfilter, $tmp_servicefilter, $tmp_hostgroupfilter, $tmp_servicegroupfilter, $tmp_hosttotalsfilter, $tmp_servicetotalsfilter ) = $self->_single_search( $c, $search );
        push @hostfilter,          $tmp_hostfilter          if defined $tmp_hostfilter;
        push @servicefilter,       $tmp_servicefilter       if defined $tmp_servicefilter;
        push @hostgroupfilter,     $tmp_hostgroupfilter     if defined $tmp_hostgroupfilter;
        push @servicegroupfilter,  $tmp_servicegroupfilter  if defined $tmp_servicegroupfilter ;
        push @servicetotalsfilter, $tmp_servicetotalsfilter if defined $tmp_servicetotalsfilter;
        push @hosttotalsfilter,    $tmp_hosttotalsfilter    if defined $tmp_hosttotalsfilter;
    }

    # combine the array of filters by OR
    my $hostfilter          = Thruk::Utils::combine_filter( '-or', \@hostfilter );
    my $servicefilter       = Thruk::Utils::combine_filter( '-or', \@servicefilter );
    my $hostgroupfilter     = Thruk::Utils::combine_filter( '-or', \@hostgroupfilter );
    my $servicegroupfilter  = Thruk::Utils::combine_filter( '-or', \@servicegroupfilter );
    my $hosttotalsfilter    = Thruk::Utils::combine_filter( '-or', \@hosttotalsfilter );
    my $servicetotalsfilter = Thruk::Utils::combine_filter( '-or', \@servicetotalsfilter );

    # fill the host/service totals box
    if(!$c->stash->{'has_error'} and $prefix ne 'dfl_') {
        $self->_fill_totals_box( $c, $hosttotalsfilter, $servicetotalsfilter );
    }

    # if there is only one search with a single text filter
    # set stash to reflect a classic search
    if(     scalar @{$searches} == 1
        and scalar @{ $searches->[0]->{'text_filter'} } == 1
        and $searches->[0]->{'text_filter'}->[0]->{'op'} eq '=' )
    {
        my $type  = $searches->[0]->{'text_filter'}->[0]->{'type'};
        my $value = $searches->[0]->{'text_filter'}->[0]->{'value'};
        if( $type eq 'host' ) {
            $c->stash->{'host'} = $value;
        }
        elsif ( $type eq 'hostgroup' ) {
            $c->stash->{'hostgroup'} = $value;
        }
        elsif ( $type eq 'servicegroup' ) {
            $c->stash->{'servicegroup'} = $value;
        }
    }

    return ( $searches, $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter );
}

##########################################################
sub _single_search {
    my( $self, $c, $search ) = @_;

    my $errors = 0;
    my( @hostfilter, @servicefilter, @hostgroupfilter, @servicegroupfilter, @hosttotalsfilter, @servicetotalsfilter );

    my( $tmp_hostfilter, $tmp_servicefilter, $host_statustype_filtername, $host_prop_filtername, $service_statustype_filtername, $service_prop_filtername, $host_statustype_filtervalue, $host_prop_filtervalue, $service_statustype_filtervalue, $service_prop_filtervalue ) = $self->_extend_filter( $c, undef, undef, $search->{'hoststatustypes'}, $search->{'hostprops'}, $search->{'servicestatustypes'}, $search->{'serviceprops'} );

    $search->{'host_statustype_filtername'}    = $host_statustype_filtername;
    $search->{'host_prop_filtername'}          = $host_prop_filtername;
    $search->{'service_statustype_filtername'} = $service_statustype_filtername;
    $search->{'service_prop_filtername'}       = $service_prop_filtername;

    $search->{'hoststatustypes'}    = $host_statustype_filtervalue;
    $search->{'hostprops'}          = $host_prop_filtervalue;
    $search->{'servicestatustypes'} = $service_statustype_filtervalue;
    $search->{'serviceprops'}       = $service_prop_filtervalue;

    push @hostfilter,    $tmp_hostfilter    if defined $tmp_hostfilter;
    push @servicefilter, $tmp_servicefilter if defined $tmp_servicefilter;

    # do the text filter
    foreach my $filter ( @{ $search->{'text_filter'} } ) {

        # resolve search prefix
        if($filter->{'type'} eq 'search' and $filter->{'value'} =~ m/^(ho|hg|se|sg):/mx) {
            if($1 eq 'ho') { $filter->{'type'} = 'host';         }
            if($1 eq 'hg') { $filter->{'type'} = 'hostgroup';    }
            if($1 eq 'se') { $filter->{'type'} = 'service';      }
            if($1 eq 'sg') { $filter->{'type'} = 'servicegroup'; }
            $filter->{'value'} = substr($filter->{'value'}, 3);
        }

        my $value  = $filter->{'value'};

        next if $value =~ m/^\s*$/mx;

        my $op     = '=';
        my $listop = '>=';
        my $dateop = '=';
        my $joinop = "-or";
        if( $filter->{'op'} eq '!~' ) { $op = '!~~'; $joinop = "-and"; $listop = '!>='; }
        if( $filter->{'op'} eq '~'  ) { $op = '~~'; }
        if( $filter->{'op'} eq '!=' ) { $op = '!='; $joinop = "-and"; $listop = '!>='; $dateop = '!='; }
        if( $filter->{'op'} eq '>=' ) { $op = '>='; $dateop = '>='; }
        if( $filter->{'op'} eq '<=' ) { $op = '<='; $dateop = '<='; }

        if( $op eq '!~~' or $op eq '~~' ) {
            $errors++ unless Thruk::Utils::is_valid_regular_expression( $c, $value );
        }

        if( $op eq '=' and $value eq 'all' ) {

            # add a useless filter
            if( $filter->{'type'} eq 'host' ) {
                push @hostfilter, { name => { '!=' => undef } };
            }
            elsif ( $filter->{'type'} eq 'hostgroup' ) {
                push @hostgroupfilter, { name => { '!=' => undef } };
            }
            elsif ( $filter->{'type'} ne 'servicegroup' ) {
                push @servicegroupfilter, { name => { '!=' => undef } };
            }
            else {
                next;
            }
        }
        elsif ( $filter->{'type'} eq 'search' ) {
            my($hfilter, $sfilter) = $self->_get_comments_filter($c, $op, $value);

            my $host_search_filter = [ { name               => { $op     => $value } },
                                       { alias              => { $op     => $value } },
                                       { groups             => { $listop => $value } },
                                       { plugin_output      => { $op     => $value } },
                                       { long_plugin_output => { $op     => $value } },
                                       $hfilter,
                                    ];
            push @hostfilter,       { $joinop => $host_search_filter };
            push @hosttotalsfilter, { $joinop => $host_search_filter };

            # and some for services
            my $service_search_filter = [ { description        => { $op     => $value } },
                                          { groups             => { $listop => $value } },
                                          { plugin_output      => { $op     => $value } },
                                          { long_plugin_output => { $op     => $value } },
                                          { host_name          => { $op     => $value } },
                                          { host_alias         => { $op     => $value } },
                                          { host_groups        => { $listop => $value } },
                                          $sfilter,
                                        ];
            push @servicefilter,       { $joinop => $service_search_filter };
            push @servicetotalsfilter, { $joinop => $service_search_filter };
        }
        elsif ( $filter->{'type'} eq 'host' ) {

            # check for wildcards
            if( CORE::index( $value, '*' ) >= 0 and $op eq '=' ) {

                # convert wildcards into real regexp
                my $searchhost = $value;
                $searchhost =~ s/\.\*/*/gmx;
                $searchhost =~ s/\*/.*/gmx;
                push @hostfilter,          { -or => [ name      => { '~~' => $searchhost }, alias      => { '~~' => $searchhost } ] };
                push @hosttotalsfilter,    { -or => [ name      => { '~~' => $searchhost }, alias      => { '~~' => $searchhost } ] };
                push @servicefilter,       { -or => [ host_name => { '~~' => $searchhost }, host_alias => { '~~' => $searchhost } ] };
                push @servicetotalsfilter, { -or => [ host_name => { '~~' => $searchhost }, host_alias => { '~~' => $searchhost } ] };
            }
            else {
                push @hostfilter,          { $joinop => [ name      => { $op => $value }, alias      => { $op => $value } ] };
                push @hosttotalsfilter,    { $joinop => [ name      => { $op => $value }, alias      => { $op => $value } ] };
                push @servicefilter,       { $joinop => [ host_name => { $op => $value }, host_alias => { $op => $value } ] };
                push @servicetotalsfilter, { $joinop => [ host_name => { $op => $value }, host_alias => { $op => $value } ] };
            }
        }
        elsif ( $filter->{'type'} eq 'service' ) {
            push @servicefilter,       { description => { $op => $value } };
            push @servicetotalsfilter, { description => { $op => $value } };
        }
        elsif ( $filter->{'type'} eq 'hostgroup' ) {
            push @hostfilter,          { groups      => { $listop => $value } };
            push @hosttotalsfilter,    { groups      => { $listop => $value } };
            push @servicefilter,       { host_groups => { $listop => $value } };
            push @servicetotalsfilter, { host_groups => { $listop => $value } };
            push @hostgroupfilter,     { name        => { $op     => $value } };
        }
        elsif ( $filter->{'type'} eq 'servicegroup' ) {
            push @servicefilter,       { groups => { $listop => $value } };
            push @servicetotalsfilter, { groups => { $listop => $value } };
            push @servicegroupfilter,  { name   => { $op     => $value } };
        }
        elsif ( $filter->{'type'} eq 'contact' ) {
            push @servicefilter,       { contacts => { $listop => $value } };
            push @hostfilter,          { contacts => { $listop => $value } };
            push @servicetotalsfilter, { contacts => { $listop => $value } };
        }
        elsif ( $filter->{'type'} eq 'next check' ) {
            my $date = Thruk::Utils::parse_date( $c, $value );
            if($date) {
                push @hostfilter,    { next_check => { $dateop => $date } };
                push @servicefilter, { next_check => { $dateop => $date } };
            }
        }
        elsif ( $filter->{'type'} eq 'latency' ) {
            push @hostfilter,    { latency => { $op => $value } };
            push @servicefilter, { latency => { $op => $value } };
        }
        elsif ( $filter->{'type'} eq 'execution time' ) {
            push @hostfilter,    { execution_time => { $op => $value } };
            push @servicefilter, { execution_time => { $op => $value } };
        }
        elsif ( $filter->{'type'} eq 'last check' ) {
            my $date = Thruk::Utils::parse_date( $c, $value );
            if($date) {
                push @hostfilter,    { last_check => { $dateop => $date } };
                push @servicefilter, { last_check => { $dateop => $date } };
            }
        }
        elsif ( $filter->{'type'} eq 'parent' ) {
            push @hostfilter,          { parents      => { $listop => $value } };
            push @hosttotalsfilter,    { parents      => { $listop => $value } };
            push @servicefilter,       { host_parents => { $listop => $value } };
            push @servicetotalsfilter, { host_parents => { $listop => $value } };
        }
        # Impact are only available in Shinken
        elsif ( $filter->{'type'} eq 'impact' && $c->config->{'enable_shinken_features'}) {
            push @hostfilter,          { source_problems      => { $listop => $value } };
            push @hosttotalsfilter,    { source_problems      => { $listop => $value } };
            push @servicefilter,       { source_problems      => { $listop => $value } };
            push @servicetotalsfilter, { source_problems      => { $listop => $value } };
        }
        # Root Problems are only available in Shinken
        elsif ( $filter->{'type'} eq 'rootproblem' && $c->config->{'enable_shinken_features'}) {
            push @hostfilter,          { impacts      => { $listop => $value } };
            push @hosttotalsfilter,    { impacts      => { $listop => $value } };
            push @servicefilter,       { impacts      => { $listop => $value } };
            push @servicetotalsfilter, { impacts      => { $listop => $value } };
        }
        elsif ( $filter->{'type'} eq 'comment' ) {
            my($hfilter, $sfilter) = $self->_get_comments_filter($c, $op, $value);
            push @hostfilter,          $hfilter;
            push @servicefilter,       $sfilter;
        }
        else {
            confess( "unknown filter: " . $filter->{'type'} );
        }
    }

    # combine the array of filters by AND
    my $hostfilter          = Thruk::Utils::combine_filter( '-and', \@hostfilter );
    my $servicefilter       = Thruk::Utils::combine_filter( '-and', \@servicefilter );
    my $hostgroupfilter     = Thruk::Utils::combine_filter( '-and', \@hostgroupfilter );
    my $servicegroupfilter  = Thruk::Utils::combine_filter( '-and', \@servicegroupfilter );
    my $hosttotalsfilter    = Thruk::Utils::combine_filter( '-and', \@hosttotalsfilter );
    my $servicetotalsfilter = Thruk::Utils::combine_filter( '-and', \@servicetotalsfilter );

    if($errors) {
        $c->stash->{'has_error'} = 1;
    }

    return ( $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter, $hosttotalsfilter, $servicetotalsfilter );
}

##########################################################
sub _get_comments_filter {
    my($self, $c, $op, $value) = @_;

    my(@hostfilter, @servicefilter);

    return(\@hostfilter, \@servicefilter) unless Thruk::Utils::is_valid_regular_expression( $c, $value );

    if($value eq '') {
        if($op eq '=' or $op eq '~~') {
            push @hostfilter,          { -or => [ comments => { $op => undef }, downtimes => { $op => undef } ]};
            push @servicefilter,       { -or => [ comments => { $op => undef }, downtimes => { $op => undef } ]};
        } else {
            push @hostfilter,          { -or => [ comments => { $op => { '!=' => undef }}, downtimes => { $op => { '!=' => undef }} ]};
            push @servicefilter,       { -or => [ comments => { $op => { '!=' => undef }}, downtimes => { $op => { '!=' => undef }} ]};
        }
    }
    else {
        my $comments     = $c->{'db'}->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { -or => [comment => { $op => $value }, author => { $op => $value }]} ] );
        my @comment_ids  = sort keys %{ Thruk::Utils::array2hash([@{$comments}], 'id') };
        if(scalar @comment_ids == 0) { @comment_ids = (-1); }

        my $downtimes    = $c->{'db'}->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { -or => [comment => { $op => $value }, author => { $op => $value }]} ] );
        my @downtime_ids = sort keys %{ Thruk::Utils::array2hash([@{$downtimes}], 'id') };
        if(scalar @downtime_ids == 0) { @downtime_ids = (-1); }

        my $comment_op = '!>=';
        if($op eq '=' or $op eq '~~') {
            $comment_op = '>=';
        }
        push @hostfilter,          { -or => [ comments => { $comment_op => \@comment_ids }, downtimes => { $comment_op => \@downtime_ids } ]};
        push @servicefilter,       { -or => [ host_comments => { $comment_op => \@comment_ids }, host_downtimes => { $comment_op => \@downtime_ids }, comments => { $comment_op => \@comment_ids }, downtimes => { $comment_op => \@downtime_ids } ]};
    }

    return(\@hostfilter, \@servicefilter);
}


##########################################################
# set selected columns for the excel export
sub _set_selected_columns {
    my($self, $c) = @_;
    my $columns = {};
    my $last_col = 30;
    for my $x (0..30) { $columns->{$x} = 1; }
    if(defined $c->{'request'}->{'parameters'}->{'columns'}) {
        $last_col = 0;
        for my $x (0..30) { $columns->{$x} = 0; }
        my $cols = $c->{'request'}->{'parameters'}->{'columns'};
        for my $nr (ref $cols eq 'ARRAY' ? @{$cols} : ($cols)) {
            $columns->{$nr} = 1;
            $last_col++;
        }
    }
    $c->stash->{'last_col'} = chr(65+$last_col-1);
    $c->stash->{'columns'}  = $columns;
    return;
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
