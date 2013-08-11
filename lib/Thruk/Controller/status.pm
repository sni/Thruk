package Thruk::Controller::status;

use strict;
use warnings;
use utf8;
use Carp;
use parent 'Catalyst::Controller';
use Thruk::Utils::Status;

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
    my $allowed_subpages = {
                            'detail'     => 1, 'hostdetail'   => 1,
                            'grid'       => 1, 'hostgrid'     => 1, 'servicegrid'     => 1,
                            'overview'   => 1, 'hostoverview' => 1, 'serviceoverview' => 1,
                            'summary'    => 1, 'hostsummary'  => 1, 'servicesummary'  => 1,
                            'combined'   => 1,
                        };
    my $style = $c->{'request'}->{'parameters'}->{'style'} || '';

    if($style ne '' and ! defined $allowed_subpages->{$style}) {
        return if Thruk::Utils::Status::redirect_view($c, $style);
    }

    if( $style eq '' ) {
        if( defined $c->{'request'}->{'parameters'}->{'hostgroup'} and $c->{'request'}->{'parameters'}->{'hostgroup'} ne '' ) {
            $style = 'overview';
        }
        if( defined $c->{'request'}->{'parameters'}->{'servicegroup'} and $c->{'request'}->{'parameters'}->{'servicegroup'} ne '' ) {
            $style = 'overview';
        }
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

    $style = 'detail' unless defined $allowed_subpages->{$style};

    # did we get a search request?
    if( defined $c->{'request'}->{'parameters'}->{'navbarsearch'} and $c->{'request'}->{'parameters'}->{'navbarsearch'} eq '1' ) {
        $style = $self->_process_search_request($c);
    }

    $c->stash->{title}         = 'Current Network Status';
    $c->stash->{infoBoxTitle}  = 'Current Network Status';
    $c->stash->{page}          = 'status';
    $c->stash->{show_top_pane} = 1;
    $c->stash->{style}         = $style;
    $c->stash->{'num_hosts'}   = 0;
    $c->stash->{'custom_vars'} = [];

    $c->stash->{substyle}     = undef;
    if($c->stash->{'hostgroup'}) {
        $c->stash->{substyle} = 'host';
    }
    elsif($c->stash->{'servicegroup'}) {
        $c->stash->{substyle} = 'service';
    }
    elsif( $style =~ m/^host/mx ) {
        $c->stash->{substyle} = 'host';
    }
    elsif( $style =~ m/^service/mx ) {
        $c->stash->{substyle} = 'service';
    }

    # raw data request?
    $c->stash->{'output_format'} = $c->{'request'}->{'parameters'}->{'format'} || 'html';
    if( $c->stash->{'output_format'} ne 'html' ) {
        $self->_process_raw_request($c);
        return 1;
    }

    # normal pages
    elsif ( $style eq 'detail' ) {
        $c->stash->{substyle} = 'service';
        $self->_process_details_page($c);
    }
    elsif ( $style eq 'hostdetail' ) {
        $self->_process_hostdetails_page($c);
    }
    elsif ( $style =~ m/overview$/mx ) {
        $style = 'overview';
        $self->_process_overview_page($c);
    }
    elsif ( $style =~ m/grid$/mx ) {
        $style = 'grid';
        $self->_process_grid_page($c);
    }
    elsif ( $style =~ m/summary$/mx ) {
        $style = 'summary';
        $self->_process_summary_page($c);
    }
    elsif ( $style eq 'combined' ) {
        $self->_process_combined_page($c);
    }

    $c->stash->{template} = 'status_' . $style . '.tt';

    Thruk::Utils::ssi_include($c);

    return 1;
}

##########################################################
# check for search results
sub _process_raw_request {
    my( $self, $c ) = @_;

    if( $c->stash->{'output_format'} eq 'search' ) {
        if( exists $c->{'request'}->{'parameters'}->{'type'} ) {
            my $type = $c->{'request'}->{'parameters'}->{'type'};
            my $data;
            if($type eq 'contact') {
                my $contacts = $c->{'db'}->get_contacts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'contact' ) ] );
                if(ref($contacts) eq 'ARRAY') {
                    for my $contact (@{$contacts}) {
                        push @{$data}, $contact->{'name'} . ' - '.$contact->{'alias'};
                    }
                }
            }
            elsif($type eq 'host' or $type eq 'hosts') {
                $data = $c->{'db'}->get_host_names( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );
            }
            elsif($type eq 'hostgroup' or $type eq 'hostgroups') {
                $data = $c->{'db'}->get_hostgroup_names_from_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );
            }
            elsif($type eq 'servicegroup' or $type eq 'servicegroups') {
                $data = $c->{'db'}->get_servicegroup_names_from_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ] );
            }
            elsif($type eq 'service' or $type eq 'services') {
                my $host = $c->{'request'}->{'parameters'}->{'host'};
                my $additional_filter;
                my @hostfilter;
                if(defined $host and $host ne '') {
                    for my $h (split(/\s*,\s*/mx, $host)) {
                        push @hostfilter, { 'host_name' => $h };
                    }
                    $additional_filter = Thruk::Utils::combine_filter('-or', \@hostfilter);
                }
                $data = $c->{'db'}->get_service_names( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $additional_filter ] );
            }
            elsif($type eq 'timeperiod' or $type eq 'timeperiods') {
                $data = $c->{'db'}->get_timeperiod_names( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'timeperiods' ) ] );
            }
            elsif($type eq 'custom variable') {
                $data = [];
            } else {
                die("unknown type: " . $type);
            }
            my $json = [ { 'name' => $type."s", 'data' => $data } ];
            $c->stash->{'json'} = $json;
            $c->forward('Thruk::View::JSON');
            return;
        }

        my( $hostgroups, $servicegroups, $hosts, $services, $timeperiods );
        if( $c->config->{ajax_search_hostgroups} ) {
            $hostgroups = $c->{'db'}->get_hostgroup_names_from_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );
        }
        if( $c->config->{ajax_search_servicegroups} ) {
            $servicegroups = $c->{'db'}->get_servicegroup_names_from_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ] );
        }
        if( $c->config->{ajax_search_hosts} ) {
            $hosts = $c->{'db'}->get_host_names( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );
        }
        if( $c->config->{ajax_search_services} ) {
            $services = $c->{'db'}->get_service_names( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ] );
        }
        if( $c->config->{ajax_search_timeperiods} ) {
            $timeperiods = $c->{'db'}->get_timeperiod_names( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'timeperiods' ) ] );
        }
        my $json = [ { 'name' => 'hostgroups', 'data' => $hostgroups }, { 'name' => 'servicegroups', 'data' => $servicegroups }, { 'name' => 'hosts', 'data' => $hosts }, { 'name' => 'services', 'data' => $services }, { 'name' => 'timeperiods', 'data' => $timeperiods } ];
        $c->stash->{'json'} = $json;
        $c->forward('Thruk::View::JSON');
        return;
    }

    # which host to display?
    my( $hostfilter, $servicefilter, $groupfilter ) = Thruk::Utils::Status::do_filter($c);
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

    my $view_mode = $c->{'request'}->{'parameters'}->{'view_mode'} || 'html';

    # which host to display?
    my( $hostfilter, $servicefilter, $groupfilter ) = Thruk::Utils::Status::do_filter($c);
    return if $c->stash->{'has_error'};

    # add comments and downtimes
    Thruk::Utils::Status::set_comments_and_downtimes($c);

    # do the sort
    my $sorttype   = $c->{'request'}->{'parameters'}->{'sorttype'}   || 1;
    my $sortoption = $c->{'request'}->{'parameters'}->{'sortoption'} || 1;
    my $order      = "ASC";
    $order = "DESC" if $sorttype == 2;
    my $sortoptions = {
        '1' => [ [ 'host_name',   'description' ], 'host name' ],
        '2' => [ [ 'description', 'host_name' ],   'service name' ],
        '3' => [ [ 'has_been_checked', 'state_order', 'host_name', 'description' ], 'service status' ],
        '4' => [ [ 'last_check',             'host_name', 'description' ], 'last check time' ],
        '5' => [ [ 'current_attempt',        'host_name', 'description' ], 'attempt number' ],
        '6' => [ [ 'last_state_change_plus', 'host_name', 'description' ], 'state duration' ],
        '7' => [ [ 'peer_name', 'host_name', 'description' ], 'site' ],
        '9' => [ [ 'plugin_output', 'host_name', 'description' ], 'status information' ],
    };
    $sortoption = 1 if !defined $sortoptions->{$sortoption};

    # reverse order for duration
    my $backend_order = $order;
    if( $sortoption == 6 ) { $backend_order = $order eq 'ASC' ? 'DESC' : 'ASC'; }

    my($columns, $keep_peer_addr, $keep_peer_name, $keep_peer_key, $keep_last_state, $keep_state_order);
    if($view_mode eq 'json' and $c->{'request'}->{'parameters'}->{'columns'}) {
        @{$columns} = split(/\s*,\s*/mx, $c->{'request'}->{'parameters'}->{'columns'});
        my $col_hash = Thruk::Utils::array2hash($columns);
        $keep_peer_addr   = delete $col_hash->{'peer_addr'};
        $keep_peer_name   = delete $col_hash->{'peer_name'};
        $keep_peer_key    = delete $col_hash->{'peer_key'};
        $keep_last_state  = delete $col_hash->{'last_state_change_plus'};
        $keep_state_order = delete $col_hash->{'state_order'};
        @{$columns} = keys %{$col_hash};
    }

    # get all services
    my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ], sort => { $backend_order => $sortoptions->{$sortoption}->[0] }, pager => 1, columns => $columns  );

    if(scalar @{$services} == 0) {
        # try to find matching hosts, maybe we got some hosts without service
        my $host_stats = $c->{'db'}->get_host_stats( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ] );
        $c->stash->{'num_hosts'} = $host_stats->{'total'};
    }

    if( $view_mode eq 'xls' ) {
        Thruk::Utils::Status::set_selected_columns($c);
        $c->res->header( 'Content-Disposition', 'attachment; filename="status.xls"' );
        $c->stash->{'data'}     = $services;
        $c->stash->{'template'} = 'excel/status_detail.tt';
        return $c->detach('View::Excel');
    }
    if ( $view_mode eq 'json' ) {
        # remove unwanted colums
        if($columns) {
            for my $s (@{$services}) {
                delete $s->{'peer_addr'}              unless $keep_peer_addr;
                delete $s->{'peer_name'}              unless $keep_peer_name;
                delete $s->{'peer_key'}               unless $keep_peer_key;
                delete $s->{'last_state_change_plus'} unless $keep_last_state;
                delete $s->{'state_order'}            unless $keep_state_order;
            }
        }
        $c->stash->{'json'} = $services;
        return $c->detach('View::JSON');
    }

    $c->stash->{'orderby'}  = $sortoptions->{$sortoption}->[1];
    $c->stash->{'orderdir'} = $order;

    if($c->config->{'show_custom_vars'}
       and defined $c->stash->{'host_stats'}
       and defined $c->stash->{'host_stats'}->{'up'}
       and $c->stash->{'host_stats'}->{'up'} + $c->stash->{'host_stats'}->{'down'} + $c->stash->{'host_stats'}->{'unreachable'} + $c->stash->{'host_stats'}->{'pending'} == 1) {
        # set allowed custom vars into stash
        Thruk::Utils::set_custom_vars($c, $c->{'stash'}->{'data'}->[0], 'host_');
    }

    return 1;
}

##########################################################
# create the hostdetails page
sub _process_hostdetails_page {
    my( $self, $c ) = @_;

    my $view_mode = $c->{'request'}->{'parameters'}->{'view_mode'} || 'html';

    # which host to display?
    my( $hostfilter, $servicefilter, $groupfilter ) = Thruk::Utils::Status::do_filter($c);
    return if $c->stash->{'has_error'};

    # add comments and downtimes
    Thruk::Utils::Status::set_comments_and_downtimes($c);

    # do the sort
    my $sorttype   = $c->{'request'}->{'parameters'}->{'sorttype'}   || 1;
    my $sortoption = $c->{'request'}->{'parameters'}->{'sortoption'} || 7;
    my $order      = "ASC";
    $order = "DESC" if $sorttype == 2;
    my $sortoptions = {
        '1' => [ 'name', 'host name' ],
        '4' => [ [ 'last_check',             'name' ], 'last check time' ],
        '6' => [ [ 'last_state_change_plus', 'name' ], 'state duration' ],
        '7' => [ [ 'peer_name', 'name' ], 'site' ],
        '8' => [ [ 'has_been_checked', 'state', 'name' ], 'host status' ],
        '9' => [ [ 'plugin_output', 'name' ], 'status information' ],
    };
    $sortoption = 1 if !defined $sortoptions->{$sortoption};

    # reverse order for duration
    my $backend_order = $order;
    if( $sortoption == 6 ) { $backend_order = $order eq 'ASC' ? 'DESC' : 'ASC'; }

    my($columns, $keep_peer_addr, $keep_peer_name, $keep_peer_key, $keep_last_state);
    if($view_mode eq 'json' and $c->{'request'}->{'parameters'}->{'columns'}) {
        @{$columns} = split(/\s*,\s*/mx, $c->{'request'}->{'parameters'}->{'columns'});
        my $col_hash = Thruk::Utils::array2hash($columns);
        $keep_peer_addr  = delete $col_hash->{'peer_addr'};
        $keep_peer_name  = delete $col_hash->{'peer_name'};
        $keep_peer_key   = delete $col_hash->{'peer_key'};
        $keep_last_state = delete $col_hash->{'last_state_change_plus'};
        @{$columns} = keys %{$col_hash};
    }

    # get hosts
    my $hosts = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ], sort => { $backend_order => $sortoptions->{$sortoption}->[0] }, pager => 1, columns => $columns );

    if( $view_mode eq 'xls' ) {
        Thruk::Utils::Status::set_selected_columns($c);
        my $filename = 'status.xls';
        $c->res->header( 'Content-Disposition', qq[attachment; filename="] . $filename . q["] );
        $c->stash->{'data'}     = $hosts;
        $c->stash->{'template'} = 'excel/status_hostdetail.tt';
        return $c->detach('View::Excel');
    }
    if ( $view_mode eq 'json' ) {
        # remove unwanted colums
        if($columns) {
            for my $h (@{$hosts}) {
                delete $h->{'peer_addr'}              unless $keep_peer_addr;
                delete $h->{'peer_name'}              unless $keep_peer_name;
                delete $h->{'peer_key'}               unless $keep_peer_key;
                delete $h->{'last_state_change_plus'} unless $keep_last_state;
            }
        }
        $c->stash->{'json'} = $hosts;
        return $c->detach('View::JSON');
    }

    $c->stash->{'orderby'}            = $sortoptions->{$sortoption}->[1];
    $c->stash->{'orderdir'}           = $order;
    $c->stash->{'show_host_attempts'} = defined $c->config->{'show_host_attempts'} ? $c->config->{'show_host_attempts'} : 0;

    return 1;
}

##########################################################
# create the status details page
sub _process_overview_page {
    my( $self, $c ) = @_;

    $c->stash->{'columns'} = $c->{'request'}->{'parameters'}->{'columns'} || 3;

    # which host to display?
    my( $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = Thruk::Utils::Status::do_filter($c);
    return if $c->stash->{'has_error'};

    die("no substyle!") unless defined $c->stash->{substyle};

    # we need the hostname, address etc...
    my $host_data;
    my $services_data;
    my $tmp_host_data = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ], columns => [ qw /action_url_expanded notes_url_expanded icon_image_alt icon_image_expanded address has_been_checked name state num_services_pending num_services_ok num_services_warn num_services_unknown num_services_crit display_name custom_variable_names custom_variable_values/ ] );
    if( defined $tmp_host_data ) {
        for my $host ( @{$tmp_host_data} ) {
            $host_data->{ $host->{'name'} } = $host;
        }
    }

    if( $c->stash->{substyle} eq 'service' ) {
        # we have to sort in all services and states
        my $tmp_services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ], columns => [ qw /description has_been_checked state host_name display_name custom_variable_names custom_variable_values/ ] );
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
        if( $c->stash->{substyle} eq 'host' ) {
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
        else {
            my $uniq = {};
            for my $member ( @{ $group->{'members'} } ) {
                my( $hostname, $servicename ) = @{$member};

                # filter duplicates
                next if exists $uniq->{$hostname}->{$servicename};
                $uniq->{$hostname}->{$servicename} = 1;

                # show only hosts with proper authorization
                next unless defined $host_data->{$hostname};
                next unless defined $services_data->{$hostname}->{$servicename};

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

    die("no substyle!") unless defined $c->stash->{substyle};

    # which host to display?
    my( $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = Thruk::Utils::Status::do_filter($c);
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
    if( $c->stash->{substyle} eq 'host' ) {
        $groups = $c->{'db'}->get_hostgroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ), $hostgroupfilter ] );
    }
    else {
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
            if( $c->stash->{substyle} eq 'host' ) {
                $hostname = $member;
            } else {
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
            if( $c->stash->{substyle} eq 'host' ) {
                for my $service ( sort keys %{ $services_data->{$hostname} } ) {
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'services'}->{ $services_data->{$hostname}->{$service}->{'description'} } = $services_data->{$hostname}->{$service};
                }
            }
            else {
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

    die("no substyle!") unless defined $c->stash->{substyle};

    # which host to display?
    my( $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = Thruk::Utils::Status::do_filter($c);
    return if $c->stash->{'has_error'};

    # get all host/service groups
    my $groups;
    if( $c->stash->{substyle} eq 'host' ) {
        $groups = $c->{'db'}->get_hostgroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ), $hostgroupfilter ] );
    }
    else {
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

    if( $c->stash->{substyle} eq 'host' ) {
        # we need the hosts data
        my $host_data = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ] );
        for my $host ( @{$host_data} ) {
            for my $group ( @{ $host->{'groups'} } ) {
                next if !defined $all_groups->{$group};
                Thruk::Utils::Status::summary_add_host_stats( "", $all_groups->{$group}, $host );
            }
        }
    }
    # create a hash of all services
    my $services_data = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ] );

    my $groupsname = "host_groups";
    if( $c->stash->{substyle} eq 'service' ) {
        $groupsname = "groups";
    }

    my %host_already_added;
    my $uniq_services;
    for my $service ( @{$services_data} ) {
        next if exists $uniq_services->{$service->{'host_name'}}->{$service->{'description'}};
        $uniq_services->{$service->{'host_name'}}->{$service->{'description'}} = 1;
        for my $group ( @{ $service->{$groupsname} } ) {
            next if !defined $all_groups->{$group};

            if( $c->stash->{substyle} eq 'service' ) {
                if( !defined $host_already_added{$group}->{ $service->{'host_name'} } ) {
                    Thruk::Utils::Status::summary_add_host_stats( "host_", $all_groups->{$group}, $service );
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
    my( $hostfilter)           = Thruk::Utils::Status::do_filter($c, 'hst_');
    my( undef, $servicefilter) = Thruk::Utils::Status::do_filter($c, 'svc_');
    return if $c->stash->{'has_error'};

    # add comments and downtimes
    Thruk::Utils::Status::set_comments_and_downtimes($c);

    # services
    my $sorttype   = $c->{'request'}->{'parameters'}->{'sorttype_svc'}   || 1;
    my $sortoption = $c->{'request'}->{'parameters'}->{'sortoption_svc'} || 1;
    my $order      = "ASC";
    $order = "DESC" if $sorttype == 2;
    my $sortoptions = {
        '1' => [ [ 'host_name',   'description' ], 'host name' ],
        '2' => [ [ 'description', 'host_name' ],   'service name' ],
        '3' => [ [ 'has_been_checked', 'state', 'host_name', 'description' ], 'service status' ],
        '4' => [ [ 'last_check',             'host_name', 'description' ], 'last check time' ],
        '5' => [ [ 'current_attempt',        'host_name', 'description' ], 'attempt number' ],
        '6' => [ [ 'last_state_change_plus', 'host_name', 'description' ], 'state duration' ],
        '7' => [ [ 'peer_name', 'host_name', 'description' ], 'site' ],
        '9' => [ [ 'plugin_output', 'host_name', 'description' ], 'status information' ],
    };
    $sortoption = 1 if !defined $sortoptions->{$sortoption};
    $c->stash->{'svc_orderby'}  = $sortoptions->{$sortoption}->[1];
    $c->stash->{'svc_orderdir'} = $order;

    my $services            = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ],
                                                        sort   => { $order => $sortoptions->{$sortoption}->[0] },
                                                      );
    $c->stash->{'services'} = $services;
    if( $sortoption == 6 and defined $services ) { @{ $c->stash->{'services'} } = reverse @{ $c->stash->{'services'} }; }


    # hosts
    $sorttype   = $c->{'request'}->{'parameters'}->{'sorttype_hst'}   || 1;
    $sortoption = $c->{'request'}->{'parameters'}->{'sortoption_hst'} || 7;
    $order      = "ASC";
    $order = "DESC" if $sorttype == 2;
    $sortoptions = {
        '1' => [ 'name', 'host name' ],
        '4' => [ [ 'last_check',             'name' ], 'last check time' ],
        '5' => [ [ 'current_attempt',        'name' ], 'attempt number'  ],
        '6' => [ [ 'last_state_change_plus', 'name' ], 'state duration'  ],
        '8' => [ [ 'has_been_checked', 'state', 'name' ], 'host status'  ],
        '9' => [ [ 'plugin_output', 'name' ], 'status information' ],
    };
    $sortoption = 1 if !defined $sortoptions->{$sortoption};
    $c->stash->{'hst_orderby'}  = $sortoptions->{$sortoption}->[1];
    $c->stash->{'hst_orderdir'} = $order;

    my $hosts            = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ],
                                                  sort   => { $order => $sortoptions->{$sortoption}->[0] },
                                                );
    $c->stash->{'hosts'} = $hosts;
    $c->stash->{'show_host_attempts'} = defined $c->config->{'show_host_attempts'} ? $c->config->{'show_host_attempts'} : 1;
    if( $sortoption == 6 and defined $hosts ) { @{ $c->stash->{'hosts'} } = reverse @{ $c->stash->{'hosts'} }; }

    my $view_mode = $c->{'request'}->{'parameters'}->{'view_mode'} || 'html';
    if( $view_mode eq 'xls' ) {
        Thruk::Utils::Status::set_selected_columns($c);
        $c->res->header( 'Content-Disposition', 'attachment; filename="status.xls"' );
        $c->stash->{'hosts'}    = $hosts;
        $c->stash->{'services'} = $services;
        $c->stash->{'template'} = 'excel/status_combined.tt';
        return $c->detach('View::Excel');
    }
    if ( $view_mode eq 'json' ) {
        $c->stash->{'json'} = {
            'hosts'    => $hosts,
            'services' => $services,
        };
        return $c->detach('View::JSON');
    }

    # set audio file to play
    Thruk::Utils::Status::set_audio_file($c);

    return 1;
}


##########################################################
# store bookmarks and redirect to last page
sub _process_bookmarks {
    my( $self, $c ) = @_;

    my $referer    = $c->{'request'}->{'parameters'}->{'referer'} || 'status.cgi';
    my $bookmark   = $c->{'request'}->{'parameters'}->{'bookmark'};
    my $bookmarks  = $c->{'request'}->{'parameters'}->{'bookmarks'};
    my $bookmarksp = $c->{'request'}->{'parameters'}->{'bookmarksp'};
    my $section    = $c->{'request'}->{'parameters'}->{'section'};
    my $newname    = $c->{'request'}->{'parameters'}->{'newname'};
    my $button     = $c->{'request'}->{'parameters'}->{'addb'};
    my $save       = $c->{'request'}->{'parameters'}->{'saveb'};
    my $public     = $c->{'request'}->{'parameters'}->{'public'} || 0;

    # public only allowed for admins
    if($public) {
        if(!$c->check_user_roles('authorized_for_system_commands') || !$c->check_user_roles('authorized_for_configuration_information')) {
            $public = 0;
        }
    }

    my $data   = Thruk::Utils::get_user_data($c);
    my $global = Thruk::Utils::get_global_user_data($c);
    my $done   = 0;

    # remove existing bookmarks
    if(    ( defined $button and $button eq 'add bookmark' )
        or ( defined $save   and $save   eq 'save changes' )) {
        my $keep = {};
        for my $bookmark (@{Thruk::Utils::list($bookmarks)}) {
            next unless defined $bookmark;
            my($section, $name) = split(/::/mx, $bookmark ,2);
            $keep->{$section}->{$name} = 1;
        }

        my $new = {};
        for my $section (keys %{$data->{'bookmarks'}}) {
            for my $link ( @{$data->{'bookmarks'}->{$section}} ) {
                next unless exists $keep->{$section}->{$link->[0]};
                push @{$new->{$section}}, $link;
            }
        }

        $data->{'bookmarks'} = $new;
        if(Thruk::Utils::store_user_data($c, $data)) {
            Thruk::Utils::set_message( $c, 'success_message', 'Bookmarks updated' );
        }
        $done++;

        if($c->check_user_roles('authorized_for_system_commands') && $c->check_user_roles('authorized_for_configuration_information')) {
            $keep = {};
            for my $bookmark (@{Thruk::Utils::list($bookmarksp)}) {
                next unless defined $bookmark;
                my($section, $name) = split(/::/mx, $bookmark ,2);
                $keep->{$section}->{$name} = 1;
            }

            $new = {};
            for my $section (keys %{$global->{'bookmarks'}}) {
                for my $link ( @{$global->{'bookmarks'}->{$section}} ) {
                    next unless exists $keep->{$section}->{$link->[0]};
                    push @{$new->{$section}}, $link;
                }
            }

            $global->{'bookmarks'} = $new;
            Thruk::Utils::store_global_user_data($c, $global);
            $done++;
        }

    }

    # add new bookmark
    if(    defined $newname   and $newname  ne ''
       and defined $bookmark  and $bookmark ne ''
       and defined $section   and $section  ne ''
       and (    ( defined $button and $button eq 'add bookmark' )
             or ( defined $save   and $save   eq 'save changes' )
           )
    ) {
        if($public) {
            $global->{'bookmarks'}->{$section} = [] unless defined $global->{'bookmarks'}->{$section};
            push @{$global->{'bookmarks'}->{$section}}, [ $newname, $bookmark ];
            if(Thruk::Utils::store_global_user_data($c, $global)) {
                Thruk::Utils::set_message( $c, 'success_message', 'Bookmark added' );
            }
        } else {
            $data->{'bookmarks'}->{$section} = [] unless defined $data->{'bookmarks'}->{$section};
            push @{$data->{'bookmarks'}->{$section}}, [ $newname, $bookmark ];
            if(Thruk::Utils::store_user_data($c, $data)) {
                Thruk::Utils::set_message( $c, 'success_message', 'Bookmark added' );
            }
        }
        $done++;
    }

    unless($done) {
        Thruk::Utils::set_message( $c, 'fail_message', 'nothing to do!' );
    }

    return $c->response->redirect($referer."&reload_nav=1");
}


##########################################################
# check for search results
sub _process_verify_time {
    my( $self, $c ) = @_;

    my $verified = 'false';
    my $error    = 'not a valid date';
    my $time = $c->{'request'}->{'parameters'}->{'time'};
    if(defined $time) {
        eval {
            if(Thruk::Utils::_parse_date($c, $time)) {
                $verified = 'true';
            }
        };
        if($@) {
            $error = $@;
            chomp($error);
            $error =~ s/\ at .*?\.pm\ line\ \d+//gmx;
            $error =~ s/^Date::Calc::Mktime\(\):\ //gmx;
        }
    }

    my $json = { 'verified' => $verified, 'error' => $error };
    $c->stash->{'json'} = $json;
    $c->forward('Thruk::View::JSON');
    return;
}


##########################################################

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
