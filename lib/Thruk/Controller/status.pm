package Thruk::Controller::status;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::status - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=head2 index

=cut

##########################################################
sub index {
    my($c) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_CACHED_DEFAULTS);

    # which style to display?
    my $allowed_subpages = {
                            'detail'     => 1, 'hostdetail'   => 1,
                            'grid'       => 1, 'hostgrid'     => 1, 'servicegrid'     => 1,
                            'overview'   => 1, 'hostoverview' => 1, 'serviceoverview' => 1,
                            'summary'    => 1, 'hostsummary'  => 1, 'servicesummary'  => 1,
                            'combined'   => 1, 'perfmap'      => 1,
                        };
    my $style = $c->req->parameters->{'style'} || '';

    if($style ne '' && !defined $allowed_subpages->{$style}) {
        return if Thruk::Utils::Status::redirect_view($c, $style);
    }

    if( $style eq '' ) {
        if( defined $c->req->parameters->{'hostgroup'} and $c->req->parameters->{'hostgroup'} ne '' ) {
            $style = 'overview';
        }
        if( defined $c->req->parameters->{'servicegroup'} and $c->req->parameters->{'servicegroup'} ne '' ) {
            $style = 'overview';
        }
    }

    if(defined $c->req->parameters->{'addb'} or defined $c->req->parameters->{'saveb'}) {
        return _process_bookmarks($c);
    }

    if(defined $c->req->parameters->{'verify'} and $c->req->parameters->{'verify'} eq 'time') {
        return _process_verify_time($c);
    }

    if($c->req->parameters->{'serveraction'}) {
        my($rc, $msg) = Thruk::Utils::Status::serveraction($c);
        my $json = { 'rc' => $rc, 'msg' => $msg };
        return $c->render(json => $json);
    }

    if($c->req->parameters->{'replacemacros'}) {
        my($rc, $data) = _replacemacros($c);
        my $json = { 'rc' => $rc, 'data' => $data };
        return $c->render(json => $json);
    }

    # set some defaults
    Thruk::Utils::Status::set_default_stash($c);

    $style = 'detail' unless defined $allowed_subpages->{$style};

    # did we get a search request?
    if( defined $c->req->parameters->{'navbarsearch'} and $c->req->parameters->{'navbarsearch'} eq '1' ) {
        $style = _process_search_request($c);
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
    $c->stash->{'output_format'} = $c->req->parameters->{'format'} || 'html';
    if( $c->stash->{'output_format'} ne 'html' ) {
        return unless _process_raw_request($c);
        return 1;
    }

    # normal pages
    elsif ( $style eq 'detail' ) {
        $c->stash->{substyle} = 'service';
        return unless _process_details_page($c);
    }
    elsif ( $style eq 'hostdetail' ) {
        return unless _process_hostdetails_page($c);
    }
    elsif ( $style =~ m/overview$/mx ) {
        $style = 'overview';
        _process_overview_page($c);
    }
    elsif ( $style =~ m/grid$/mx ) {
        $style = 'grid';
        _process_grid_page($c);
    }
    elsif ( $style =~ m/summary$/mx ) {
        $style = 'summary';
        _process_summary_page($c);
    }
    elsif ( $style eq 'combined' ) {
        _process_combined_page($c);
    }
    elsif ( $style eq 'perfmap' ) {
        $c->stash->{substyle} = 'service';
        _process_perfmap_page($c);
    }

    $c->stash->{template} = 'status_' . $style . '.tt';

    Thruk::Utils::ssi_include($c);

    return 1;
}

##########################################################
# check for search results
sub _process_raw_request {
    my( $c ) = @_;

    if( $c->stash->{'output_format'} eq 'search' ) {
        if( exists $c->req->parameters->{'type'} && $c->req->parameters->{'type'} ne 'all' ) {
            my $filter;
            if($c->req->parameters->{'query'}) {
                $filter = $c->req->parameters->{'query'};
                $filter =~ s/\s+/\.\*/gmx;
            }
            my $type = $c->req->parameters->{'type'};
            my $data;
            if($type eq 'contact') {
                if(!$c->check_user_roles("authorized_for_configuration_information")) {
                    $data = ["you are not authorized for configuration information"];
                } else {
                    my $contacts = $c->{'db'}->get_contacts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'contact' ), name => { '~~' => $filter } ] );
                    if(ref($contacts) eq 'ARRAY') {
                        for my $contact (@{$contacts}) {
                            push @{$data}, $contact->{'name'} . ' - '.$contact->{'alias'};
                        }
                    }
                }
            }
            elsif($type eq 'host' or $type eq 'hosts') {
                $data = $c->{'db'}->get_host_names( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), name => { '~~' => $filter } ] );
            }
            elsif($type eq 'hostgroup' or $type eq 'hostgroups') {
                $data = $c->{'db'}->get_hostgroup_names_from_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );
                @{$data} = grep {/$filter/mx} @{$data} if $filter;
            }
            elsif($type eq 'servicegroup' or $type eq 'servicegroups') {
                $data = $c->{'db'}->get_servicegroup_names_from_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ] );
                @{$data} = grep {/$filter/mx} @{$data} if $filter;
            }
            elsif($type eq 'service' or $type eq 'services') {
                my $host = $c->req->parameters->{'host'};
                my $additional_filter;
                my @hostfilter;
                if(defined $host and $host ne '') {
                    for my $h (split(/\s*,\s*/mx, $host)) {
                        push @hostfilter, { 'host_name' => $h };
                    }
                    $additional_filter = Thruk::Utils::combine_filter('-or', \@hostfilter);
                }
                $data = $c->{'db'}->get_service_names( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $additional_filter, description => { '~~' => $filter } ] );
            }
            elsif($type eq 'timeperiod' or $type eq 'timeperiods') {
                $data = $c->{'db'}->get_timeperiod_names( filter => [ name => { '~~' => $filter } ] );
            }
            elsif($type eq 'command' or $type eq 'commands') {
                if(!$c->check_user_roles("authorized_for_configuration_information")) {
                    $data = ["you are not authorized for configuration information"];
                } else {
                    my $commands = $c->{'db'}->get_commands( filter => [ name => { '~~' => $filter } ], columns => ['name'] );
                    $data = [];
                    for my $d (@{$commands}) {
                        push @{$data}, $d->{'name'};
                    }
                }
            }
            elsif($type eq 'custom variable') {
                if(!$c->check_user_roles("authorized_for_configuration_information")) {
                    $data = ["you are not authorized for configuration information"];
                } else {
                    # get available custom variables
                    $data        = [];
                    my $vars     = {};
                    my $hosts    = $c->{'db'}->get_hosts(    filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ),    custom_variable_names => { '!=' => '' } ], columns => ['custom_variable_names'] );
                    my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), custom_variable_names => { '!=' => '' } ], columns => ['custom_variable_names'] );
                    for my $obj (@{$hosts}, @{$services}) {
                        for my $key (@{$obj->{custom_variable_names}}) {
                            $vars->{$key} = 1;
                        }
                    }
                    @{$data} = sort keys %{$vars};
                    @{$data} = grep(/$filter/mx, @{$data}) if $filter;
                }
            }
            elsif($type eq 'contactgroup') {
                $data = [];
                if($c->req->parameters->{'wildcards'}) {
                    push @{$data}, '*';
                }
                my $groups = $c->{'db'}->get_contactgroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'contactgroups'), name => { '~~' => $filter } ], columns => [qw/name/], remove_duplicates => 1, sort => {ASC=> 'name'});
                for my $g (@{$groups}) {
                    push @{$data}, $g->{'name'};
                }
            }
            elsif($type eq 'event handler') {
                if(!$c->check_user_roles("authorized_for_configuration_information")) {
                    $data = ["you are not authorized for configuration information"];
                } else {
                    $data = $c->{'db'}->get_services( filter => [ -or => [ { host_event_handler => { '~~' => $filter }},
                                                                           {      event_handler => { '~~' => $filter }},
                                                                         ]],
                                                      columns => [qw/host_event_handler event_handler/],
                                                    );
                    my $eventhandler = {};
                    for my $d (@{$data}) {
                        $eventhandler->{$d->{host_event_handler}} = 1 if $d->{host_event_handler};
                        $eventhandler->{$d->{event_handler}}      = 1 if $d->{event_handler};
                    }
                    $data = [sort keys %{$eventhandler}];
                }
            }
            elsif($type eq 'site') {
                $data = [];
                for my $key (@{$c->stash->{'backends'}}) {
                    my $b = $c->stash->{'backend_detail'}->{$key};
                    push @{$data}, $b->{'name'};
                }
                @{$data} = sort @{$data};
            } else {
                die("unknown type: " . $type);
            }
            my $json = [ { 'name' => $type."s", 'data' => $data } ];
            if($c->req->parameters->{'hash'}) {
                my $total = scalar @{$data};
                Thruk::Backend::Manager::_page_data(undef, $c, $data);
                my $list = [];
                for my $d (@{$c->stash->{'data'}}) { push @{$list}, { 'text' => $d } }
                $json = { 'data' => $list, 'total' => $total };
            }
            return $c->render(json => $json);
        }

        # search type all
        my( $hostgroups, $servicegroups, $hosts, $services, $timeperiods );
        my @json;
        if( $c->config->{ajax_search_hostgroups} ) {
            $hostgroups = $c->{'db'}->get_hostgroup_names_from_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );
            push @json, { 'name' => 'hostgroups', 'data' => $hostgroups };
        }
        if( $c->config->{ajax_search_servicegroups} ) {
            $servicegroups = $c->{'db'}->get_servicegroup_names_from_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ] );
            push @json, { 'name' => 'servicegroups', 'data' => $servicegroups };
        }
        if( $c->config->{ajax_search_hosts} ) {
            $hosts = $c->{'db'}->get_host_names( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );
            push @json, { 'name' => 'hosts', 'data'=> $hosts };
        }
        if( $c->config->{ajax_search_services} ) {
            my @servicefilter = (Thruk::Utils::Auth::get_auth_filter( $c, 'services' ));
            Thruk::Utils::Status::set_default_filter($c, \@servicefilter);
            $services = $c->{'db'}->get_service_names( filter => \@servicefilter );
            push @json, { 'name' => 'services', 'data' => $services };
        }
        if( $c->config->{ajax_search_timeperiods} ) {
            $timeperiods = $c->{'db'}->get_timeperiod_names( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'timeperiods' ) ] );
            push @json, { 'name' => 'timeperiods', 'data' => $timeperiods };
        }
        return $c->render(json => \@json);
    }

    # which host to display?
    #my( $hostfilter, $servicefilter, $groupfilter )...
    my( $hostfilter, undef, undef ) = Thruk::Utils::Status::do_filter($c);
    return 1 if $c->stash->{'has_error'};

    my $limit = $c->req->parameters->{'limit'} || 0;

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

    if( defined $c->req->parameters->{'column'} ) {
        if( ref $c->req->parameters->{'column'} eq 'ARRAY' ) {
            @columns = @{ $c->req->parameters->{'column'} };
        }
        else {
            @columns = ( $c->req->parameters->{'column'} );
        }
    }

    my $hosts = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ], columns => \@columns, limit => $limit );
    return $c->render(json => $hosts);
}

##########################################################
# check for search results
sub _process_search_request {
    my( $c ) = @_;

    # search pattern is in host param
    my $host = $c->req->parameters->{'host'};
    $c->req->parameters->{'hidesearch'} = 2;    # force show search

    return ('detail') unless defined $host;

    # is there a servicegroup with this name?
    my $servicegroups = $c->{'db'}->get_servicegroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'servicegroups' ), 'name' => $host ] );
    if( scalar @{$servicegroups} > 0 ) {
        delete $c->req->parameters->{'host'};
        $c->req->parameters->{'servicegroup'} = $host;
        return ('overview');
    }

    # is there a hostgroup with this name?
    my $hostgroups = $c->{'db'}->get_hostgroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ), 'name' => $host ] );
    if( scalar @{$hostgroups} > 0 ) {
        delete $c->req->parameters->{'host'};
        $c->req->parameters->{'hostgroup'} = $host;
        return ('overview');
    }

    return ('detail');
}

##########################################################
# create the status details page
sub _process_details_page {
    my( $c ) = @_;

    my $view_mode = $c->req->parameters->{'view_mode'} || 'html';
    $c->stash->{'minimal'} = 1 if $view_mode ne 'html';

    # which host to display?
    #my( $hostfilter, $servicefilter, $groupfilter )...
    my( $hostfilter, $servicefilter, undef) = Thruk::Utils::Status::do_filter($c);
    return 1 if $c->stash->{'has_error'};

    # do the sort
    my $sorttype   = $c->req->parameters->{'sorttype'}   || 1;
    my $sortoption = $c->req->parameters->{'sortoption'} || 1;
    my $order      = "ASC";
    $order = "DESC" if $sorttype == 2;
    my $sortoptions = {
        '1' => [ [ 'host_name',   'description' ], 'host name' ],
        '2' => [ [ 'description', 'host_name' ],   'service name' ],
        '3' => [ [ 'has_been_checked', 'state_order', 'host_name', 'description' ], 'service status' ],
        '4' => [ [ 'last_check',              'host_name', 'description' ], 'last check time' ],
        '5' => [ [ 'current_attempt',         'host_name', 'description' ], 'attempt number' ],
        '6' => [ [ 'last_state_change_order', 'host_name', 'description' ], 'state duration' ],
        '7' => [ [ 'peer_name', 'host_name', 'description' ], 'site' ],
        '9' => [ [ 'plugin_output', 'host_name', 'description' ], 'status information' ],
    };
    $sortoption = 1 if !defined $sortoptions->{$sortoption};

    # reverse order for duration
    my $backend_order = $order;
    if( $sortoption == 6 ) { $backend_order = $order eq 'ASC' ? 'DESC' : 'ASC'; }

    my($columns, $keep_peer_addr, $keep_peer_name, $keep_peer_key, $keep_last_state, $keep_state_order);
    if($view_mode eq 'json' and $c->req->parameters->{'columns'}) {
        @{$columns} = split(/\s*,\s*/mx, $c->req->parameters->{'columns'});
        my $col_hash = Thruk::Utils::array2hash($columns);
        $keep_peer_addr   = delete $col_hash->{'peer_addr'};
        $keep_peer_name   = delete $col_hash->{'peer_name'};
        $keep_peer_key    = delete $col_hash->{'peer_key'};
        $keep_last_state  = delete $col_hash->{'last_state_change_order'};
        $keep_state_order = delete $col_hash->{'state_order'};
        @{$columns} = keys %{$col_hash};
    }

    # get all services
    my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ], sort => { $backend_order => $sortoptions->{$sortoption}->[0] }, pager => 1, columns => $columns  );

    if(scalar @{$services} == 0 && !$c->stash->{'has_service_filter'}) {
        # try to find matching hosts, maybe we got some hosts without service
        my $host_stats = $c->{'db'}->get_host_stats( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ] );
        $c->stash->{'num_hosts'} = $host_stats->{'total'};

        # redirect to host details page if there are hosts but no service filter
        if($c->stash->{'num_hosts'} > 0) {
            my $url = $c->stash->{'url_prefix'}.'cgi-bin/'.Thruk::Utils::Filter::uri_with($c, {'style' => 'hostdetail'});
            $url =~ s/&amp;/&/gmx;
            Thruk::Utils::set_message( $c, 'info_message', 'No services found for this filter, redirecting to host view.' );
            return $c->redirect_to($url);
        }
    }

    if( $view_mode eq 'xls' ) {
        Thruk::Utils::Status::set_selected_columns($c);
        $c->res->headers->header( 'Content-Disposition', 'attachment; filename="status.xls"' );
        $c->stash->{'data'}     = $services;
        $c->stash->{'template'} = 'excel/status_detail.tt';
        return $c->render_excel();
    }
    if ( $view_mode eq 'json' ) {
        # remove unwanted colums
        if($columns) {
            for my $s (@{$services}) {
                delete $s->{'peer_addr'}               unless $keep_peer_addr;
                delete $s->{'peer_name'}               unless $keep_peer_name;
                delete $s->{'peer_key'}                unless $keep_peer_key;
                delete $s->{'last_state_change_order'} unless $keep_last_state;
                delete $s->{'state_order'}             unless $keep_state_order;
            }
        }
        if(!$c->check_user_roles("authorized_for_configuration_information")) {
            # remove custom macro colums which could contain confidential informations
            for my $s (@{$services}) {
                delete $s->{'host_custom_variable_names'};
                delete $s->{'host_custom_variable_values'};
                delete $s->{'custom_variable_names'};
                delete $s->{'custom_variable_values'};
            }
        }
        return $c->render(json => $services);
    }

    $c->stash->{'orderby'}  = $sortoptions->{$sortoption}->[1];
    $c->stash->{'orderdir'} = $order;

    if($c->config->{'show_custom_vars'}
       and defined $c->stash->{'host_stats'}
       and defined $c->stash->{'host_stats'}->{'up'}
       and $c->stash->{'host_stats'}->{'up'} + $c->stash->{'host_stats'}->{'down'} + $c->stash->{'host_stats'}->{'unreachable'} + $c->stash->{'host_stats'}->{'pending'} == 1) {
        # set allowed custom vars into stash
        Thruk::Utils::set_custom_vars($c, {'prefix' => 'host_', 'host' => $c->stash->{'data'}->[0], 'add_host' => 1 });
    }

    return 1;
}

##########################################################
# create the hostdetails page
sub _process_hostdetails_page {
    my( $c ) = @_;

    my $view_mode = $c->req->parameters->{'view_mode'} || 'html';
    $c->stash->{'minimal'} = 1 if $view_mode ne 'html';

    # which host to display?
    #my( $hostfilter, $servicefilter, $groupfilter )...
    my( $hostfilter, undef, undef ) = Thruk::Utils::Status::do_filter($c);
    return 1 if $c->stash->{'has_error'};

    # do the sort
    my $sorttype   = $c->req->parameters->{'sorttype'}   || 1;
    my $sortoption = $c->req->parameters->{'sortoption'} || 1;
    my $order      = "ASC";
    $order = "DESC" if $sorttype == 2;
    my $sortoptions = {
        '1' => [ 'name', 'host name' ],
        '4' => [ [ 'last_check',              'name' ], 'last check time' ],
        '6' => [ [ 'last_state_change_order', 'name' ], 'state duration' ],
        '7' => [ [ 'peer_name', 'name' ], 'site' ],
        '8' => [ [ 'has_been_checked', 'state', 'name' ], 'host status' ],
        '9' => [ [ 'plugin_output', 'name' ], 'status information' ],
    };
    $sortoption = 1 if !defined $sortoptions->{$sortoption};

    # reverse order for duration
    my $backend_order = $order;
    if( $sortoption == 6 ) { $backend_order = $order eq 'ASC' ? 'DESC' : 'ASC'; }

    my($columns, $keep_peer_addr, $keep_peer_name, $keep_peer_key, $keep_last_state);
    if($view_mode eq 'json' and $c->req->parameters->{'columns'}) {
        @{$columns} = split(/\s*,\s*/mx, $c->req->parameters->{'columns'});
        my $col_hash = Thruk::Utils::array2hash($columns);
        $keep_peer_addr  = delete $col_hash->{'peer_addr'};
        $keep_peer_name  = delete $col_hash->{'peer_name'};
        $keep_peer_key   = delete $col_hash->{'peer_key'};
        $keep_last_state = delete $col_hash->{'last_state_change_order'};
        @{$columns} = keys %{$col_hash};
    }

    # get hosts
    my $hosts = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ], sort => { $backend_order => $sortoptions->{$sortoption}->[0] }, pager => 1, columns => $columns );

    if( $view_mode eq 'xls' ) {
        Thruk::Utils::Status::set_selected_columns($c);
        my $filename = 'status.xls';
        $c->res->headers->header( 'Content-Disposition', qq[attachment; filename="] . $filename . q["]);
        $c->stash->{'data'}     = $hosts;
        $c->stash->{'template'} = 'excel/status_hostdetail.tt';
        return $c->render_excel();
    }
    if ( $view_mode eq 'json' ) {
        # remove unwanted colums
        if($columns) {
            for my $h (@{$hosts}) {
                delete $h->{'peer_addr'}               unless $keep_peer_addr;
                delete $h->{'peer_name'}               unless $keep_peer_name;
                delete $h->{'peer_key'}                unless $keep_peer_key;
                delete $h->{'last_state_change_order'} unless $keep_last_state;
            }
        }
        if(!$c->check_user_roles("authorized_for_configuration_information")) {
            # remove custom macro colums which could contain confidential informations
            for my $h (@{$hosts}) {
                delete $h->{'custom_variable_names'};
                delete $h->{'custom_variable_values'};
            }
        }
        return $c->render(json => $hosts);
    }

    $c->stash->{'orderby'}            = $sortoptions->{$sortoption}->[1];
    $c->stash->{'orderdir'}           = $order;
    $c->stash->{'show_host_attempts'} = defined $c->config->{'show_host_attempts'} ? $c->config->{'show_host_attempts'} : 0;

    return 1;
}

##########################################################
# create the status details page
sub _process_overview_page {
    my( $c ) = @_;

    $c->stash->{'columns'} = $c->req->parameters->{'columns'} || 3;

    # which host to display?
    my( $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = Thruk::Utils::Status::do_filter($c);
    return 1 if $c->stash->{'has_error'};

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
    my( $c ) = @_;

    die("no substyle!") unless defined $c->stash->{substyle};

    # which host to display?
    my( $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = Thruk::Utils::Status::do_filter($c);
    return 1 if $c->stash->{'has_error'};

    my($host_data, $services_data) = _fill_host_services_hashes($c,
                                            [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ],
                                            [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ],
                                            0, # only name/description columes
                                    );

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

            # add all services
            $joined_groups{$name}->{'hosts'}->{$hostname}->{'services'} = {} unless defined $joined_groups{$name}->{'hosts'}->{$hostname}->{'services'};
            if( $c->stash->{substyle} eq 'host' ) {
                for my $service ( sort keys %{ $services_data->{$hostname} } ) {
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'services'}->{$service} = 1;
                }
            }
            else {
                $joined_groups{$name}->{'hosts'}->{$hostname}->{'services'}->{$servicename} = 1;
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

    $host_data     = undef;
    $services_data = undef;
    my @hostfilter;
    my @servicefilter;
    if( $c->stash->{substyle} eq 'host' ) {
        for my $group (@{$c->stash->{'data'}}) {
            push @hostfilter,    {      groups => { '>=' => $group->{name} } };
            push @servicefilter, { host_groups => { '>=' => $group->{name} } };
        }
        $hostfilter    = [$hostfilter,    Thruk::Utils::combine_filter('-or', \@hostfilter)];
        $servicefilter = [$servicefilter, Thruk::Utils::combine_filter('-or', \@servicefilter)];
    } else {
        for my $group (@{$c->stash->{'data'}}) {
            push @servicefilter, { groups => { '>=' => $group->{name} } };
        }
        $servicefilter = [$servicefilter, Thruk::Utils::combine_filter('-or', \@servicefilter)];
    }
    ($host_data, $services_data) = _fill_host_services_hashes($c,
                                            [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ],
                                            [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ],
                                            1, # all columes
                                    );

    for my $group (@{$c->stash->{'data'}}) {
        for my $hostname (keys %{$group->{hosts}}) {
            # merge host data
            %{$group->{hosts}->{$hostname}} = (%{$group->{hosts}->{$hostname}}, %{$host_data->{$hostname}});
            for my $servicename (keys %{$group->{hosts}->{$hostname}->{'services'}}) {
                $group->{hosts}->{$hostname}->{'services'}->{$servicename} = $services_data->{$hostname}->{$servicename};
            }
        }
    }

    return 1;
}

##########################################################
# create the status summary page
sub _process_summary_page {
    my( $c ) = @_;

    die("no substyle!") unless defined $c->stash->{substyle};

    # which host to display?
    my( $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = Thruk::Utils::Status::do_filter($c);
    return 1 if $c->stash->{'has_error'};

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
        my $host_data = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ],
                                              columns => [ qw/action_url_expanded notes_url_expanded icon_image_alt icon_image_expanded address has_been_checked name
                                                              state display_name custom_variable_names custom_variable_values groups scheduled_downtime_depth acknowledged
                                                              checks_enabled check_type/ ],
                                             );
        for my $host ( @{$host_data} ) {
            for my $group ( @{ $host->{'groups'} } ) {
                next if !defined $all_groups->{$group};
                Thruk::Utils::Status::summary_add_host_stats( "", $all_groups->{$group}, $host );
            }
        }
    }
    # create a hash of all services
    my $services_data = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ],
                                                 columns => [ qw/description state host_name acknowledged has_been_checked
                                                                 host_state host_has_been_checked host_acknowledged host_scheduled_downtime_depth host_checks_enabled host_groups
                                                                 checks_enabled check_type scheduled_downtime_depth groups/ ],
                                                );

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
    my( $c ) = @_;

    $c->stash->{hidetop}    = 1 unless $c->stash->{hidetop} ne '';
    $c->stash->{hidesearch} = 1;

    # which host to display?
    my( $hostfilter)           = Thruk::Utils::Status::do_filter($c, 'hst_');
    my( undef, $servicefilter) = Thruk::Utils::Status::do_filter($c, 'svc_');
    return 1 if $c->stash->{'has_error'};

    my $view_mode = $c->req->parameters->{'view_mode'} || 'html';

    # services
    my $sorttype   = $c->req->parameters->{'sorttype_svc'}   || 1;
    my $sortoption = $c->req->parameters->{'sortoption_svc'} || 1;
    my $order      = "ASC";
    $order = "DESC" if $sorttype == 2;
    my $sortoptions = {
        '1' => [ [ 'host_name',   'description' ], 'host name' ],
        '2' => [ [ 'description', 'host_name' ],   'service name' ],
        '3' => [ [ 'has_been_checked', 'state', 'host_name', 'description' ], 'service status' ],
        '4' => [ [ 'last_check',              'host_name', 'description' ], 'last check time' ],
        '5' => [ [ 'current_attempt',         'host_name', 'description' ], 'attempt number' ],
        '6' => [ [ 'last_state_change_order', 'host_name', 'description' ], 'state duration' ],
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
    $sorttype   = $c->req->parameters->{'sorttype_hst'}   || 1;
    $sortoption = $c->req->parameters->{'sortoption_hst'} || 7;
    $order      = "ASC";
    $order = "DESC" if $sorttype == 2;
    $sortoptions = {
        '1' => [ 'name', 'host name' ],
        '4' => [ [ 'last_check',              'name' ], 'last check time' ],
        '5' => [ [ 'current_attempt',         'name' ], 'attempt number'  ],
        '6' => [ [ 'last_state_change_order', 'name' ], 'state duration'  ],
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

    if( $view_mode eq 'xls' ) {
        Thruk::Utils::Status::set_selected_columns($c);
        $c->res->headers->header( 'Content-Disposition', 'attachment; filename="status.xls"' );
        $c->stash->{'hosts'}     = $hosts;
        $c->stash->{'services'}  = $services;
        $c->stash->{'template'}  = 'excel/status_combined.tt';
        return $c->render_excel();
    }
    if ( $view_mode eq 'json' ) {
        if(!$c->check_user_roles("authorized_for_configuration_information")) {
            # remove custom macro colums which could contain confidential informations
            for my $h (@{$hosts}) {
                delete $h->{'custom_variable_names'};
                delete $h->{'custom_variable_values'};
            }
            for my $s (@{$services}) {
                delete $s->{'host_custom_variable_names'};
                delete $s->{'host_custom_variable_values'};
                delete $s->{'custom_variable_names'};
                delete $s->{'custom_variable_values'};
            }
        }
        my $json = {
            'hosts'    => $hosts,
            'services' => $services,
        };
        return $c->render(json => $json);
    }

    # set audio file to play
    Thruk::Utils::Status::set_audio_file($c);

    return 1;
}

##########################################################
# create the perfmap details page
sub _process_perfmap_page {
    my( $c ) = @_;

    my $view_mode = $c->req->parameters->{'view_mode'} || 'html';

    # which host to display?
    #my( $hostfilter, $servicefilter, $groupfilter )...
    my( undef, $servicefilter, undef ) = Thruk::Utils::Status::do_filter($c);
    return 1 if $c->stash->{'has_error'};

    # do the sort
    my $sorttype   = $c->req->parameters->{'sorttype'}   || 1;
    my $sortoption = $c->req->parameters->{'sortoption'} || 1;
    my $order      = "ASC";
    $order = "DESC" if $sorttype == 2;

    # get all services
    my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ]  );
    my $data = [];
    my $keys = {};
    for my $svc (@{$services}) {
        $svc->{'perf'} = {};
        my $perfdata = $svc->{'perf_data'};
        my @matches  = $perfdata =~ m/([^\s]+|'[^']+')=([^\s]*)/gmxoi;
        for(my $x = 0; $x < scalar @matches; $x=$x+2) {
            my $key = $matches[$x];
            my $val = $matches[$x+1];
            $key =~ s/^'//gmxo;
            $key =~ s/'$//gmxo;
            $val =~ s/;.*$//gmxo;
            $val =~ s/,/./gmxo;
            $val =~ m/^([\d\.\-]+)(.*?)$/mx;
            if(defined $1) {
                $svc->{'perf'}->{$key} = 1;
                $keys->{$key} = 1;
                $svc->{$key} = $1.$2;
                $svc->{$key.'_sort'} = $1;
            }
        }
        push @{$data}, $svc;
    }

    if( $view_mode eq 'xls' ) {
        Thruk::Utils::Status::set_selected_columns($c);
        $c->stash->{'last_col'} = chr(65+(scalar keys %{$keys})-1);
        my $filename = 'performancedata.xls';
        $c->res->headers->header( 'Content-Disposition', qq[attachment; filename="] . $filename . q["] );
        $c->stash->{'name'}      = 'Performance';
        $c->stash->{'data'}     = $data;
        $c->stash->{'col_sel'}   = $c->stash->{'columns'};
        $c->stash->{'col_tr'}    = { 'host_name' => 'Hostname', 'description' => 'Service', 'state' => 'Status' };
        $c->stash->{'columns'}   = ['host_name', 'description', 'state', sort keys %{$keys}];
        $c->stash->{'template'}  = 'excel/generic.tt';
        return $c->render_excel();
    }
    if ( $view_mode eq 'json' ) {
        # remove unwanted colums
        for my $d (@{$data}) {
            delete $d->{'peer_key'};
            delete $d->{'perf'};
            delete $d->{'has_been_checked'};
            for my $k (keys %{$keys}) {
                delete $d->{$k.'_sort'};
            }
        }
        return $c->render(json => $data);
    }

    # sort things?
    if(defined $keys->{$sortoption}) {
        $data = Thruk::Backend::Manager::_sort($c, $data, { $order => $sortoption.'_sort'});
    } elsif($sortoption eq "1") {
        $c->stash->{'sortoption'}  = '';
    } elsif($sortoption eq "2") {
        $data = Thruk::Backend::Manager::_sort($c, $data, { $order => ['description', 'host_name']});
        $c->stash->{'sortoption'}  = '';
    }

    $c->stash->{'perf_keys'} = $keys;
    Thruk::Backend::Manager::_page_data(undef, $c, $data);

    $c->stash->{'orderby'}  = $sortoption;
    $c->stash->{'orderdir'} = $order;

    return 1;
}

##########################################################
# store bookmarks and redirect to last page
sub _process_bookmarks {
    my( $c ) = @_;

    my $referer    = $c->req->parameters->{'referer'} || 'status.cgi';
    my $bookmark   = $c->req->parameters->{'bookmark'};
    my $bookmarks  = $c->req->parameters->{'bookmarks'};
    my $bookmarksp = $c->req->parameters->{'bookmarksp'};
    my $section    = $c->req->parameters->{'section'};
    my $newname    = $c->req->parameters->{'newname'};
    my $button     = $c->req->parameters->{'addb'};
    my $save       = $c->req->parameters->{'saveb'};
    my $public     = $c->req->parameters->{'public'} || 0;

    # public only allowed for admins
    if($public) {
        if(!$c->check_user_roles('authorized_for_system_commands') || !$c->check_user_roles('authorized_for_configuration_information')) {
            $public = 0;
        }
    }

    my $data   = Thruk::Utils::get_user_data($c);
    my $global = Thruk::Utils::get_global_user_data($c);
    my $done   = 0;

    # add new bookmark
    my $keep  = {};
    my $keepp = {};
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
            $keepp->{$section}->{$newname} = 1;
        } else {
            $data->{'bookmarks'}->{$section} = [] unless defined $data->{'bookmarks'}->{$section};
            push @{$data->{'bookmarks'}->{$section}}, [ $newname, $bookmark ];
            if(Thruk::Utils::store_user_data($c, $data)) {
                Thruk::Utils::set_message( $c, 'success_message', 'Bookmark added' );
            }
            $keep->{$section}->{$newname} = 1;
        }
        $done++;
    }

    # remove existing bookmarks
    if(    ( defined $button and $button eq 'add bookmark' )
        or ( defined $save   and $save   eq 'save changes' )) {
        for my $bookmark (@{Thruk::Utils::list($bookmarks)}) {
            next unless defined $bookmark;
            my($section, $name) = split(/::/mx, $bookmark ,2);
            $keep->{$section}->{$name} = 1;
        }

        my $new  = {};
        my $dups = {};
        for my $section (keys %{$data->{'bookmarks'}}) {
            for my $link ( reverse @{$data->{'bookmarks'}->{$section}} ) {
                next unless exists $keep->{$section}->{$link->[0]};
                next if     exists $dups->{$section}->{$link->[0]};
                push @{$new->{$section}}, $link;
                $dups->{$section}->{$link->[0]} = 1;
            }
            @{$new->{$section}} = reverse @{$new->{$section}} if defined $new->{$section}; # ensures the last bookmark with same name superseeds
        }

        $data->{'bookmarks'} = $new;
        if(Thruk::Utils::store_user_data($c, $data)) {
            Thruk::Utils::set_message( $c, 'success_message', 'Bookmarks updated' );
        }
        $done++;

        if($c->check_user_roles('authorized_for_system_commands') && $c->check_user_roles('authorized_for_configuration_information')) {
            for my $bookmark (@{Thruk::Utils::list($bookmarksp)}) {
                next unless defined $bookmark;
                my($section, $name) = split(/::/mx, $bookmark ,2);
                $keepp->{$section}->{$name} = 1;
            }

            $new  = {};
            $dups = {};
            for my $section (keys %{$global->{'bookmarks'}}) {
                for my $link ( reverse @{$global->{'bookmarks'}->{$section}} ) {
                    next unless exists $keepp->{$section}->{$link->[0]};
                    next if     exists $dups->{$section}->{$link->[0]};
                    push @{$new->{$section}}, $link;
                    $dups->{$section}->{$link->[0]} = 1;
                }
                @{$new->{$section}} = reverse @{$new->{$section}} if defined $new->{$section}; # ensures the last bookmark with same name superseeds
            }

            $global->{'bookmarks'} = $new;
            Thruk::Utils::store_global_user_data($c, $global);
            $done++;
        }

    }

    unless($done) {
        Thruk::Utils::set_message( $c, 'fail_message', 'nothing to do!' );
    }

    return $c->redirect_to($referer."&reload_nav=1");
}


##########################################################
# check for search results
sub _process_verify_time {
    my( $c ) = @_;

    my $verified = 'false';
    my $error    = 'not a valid date';
    my $time = $c->req->parameters->{'time'};
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
    return $c->render(json => $json);
}


##########################################################
# replace macros in given string for a host/service
sub _replacemacros {
    my( $c ) = @_;

    return(1, 'invalid request') unless Thruk::Utils::check_csrf($c);

    my $host    = $c->req->parameters->{'host'};
    my $service = $c->req->parameters->{'service'};
    my $data    = $c->req->parameters->{'data'};

    # replace macros
    my $objs;
    if($service) {
        $objs = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { host_name => $host, description => $service } ] );
    } else {
        $objs = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), { name => $host } ] );
    }
    my $obj = $objs->[0];
    return(1, 'no such object') unless $obj;

    my($new, $rc) = $c->{'db'}->replace_macros($data, {host => $obj, service => $service ? $obj : undef, skip_user => 1});
    # replace_macros returns 1 on success, js expects 0 on success, so revert rc here
    return(!$rc, $new);
}

##########################################################
sub _fill_host_services_hashes {
    my($c, $hostfilter, $servicefilter, $all_columns) = @_;

    my $host_data;
    my $tmp_host_data = $c->{'db'}->get_hosts( filter => $hostfilter, columns => $all_columns ? [qw/name state alias display_name icon_image_expanded icon_image_alt notes_url_expanded action_url_expanded/] : [qw/name/] );
    if( defined $tmp_host_data ) {
        for my $host ( @{$tmp_host_data} ) {
            $host_data->{ $host->{'name'} } = $host;
        }
    }

    my $services_data;
    my $tmp_services = $c->{'db'}->get_services( filter => $servicefilter, columns => $all_columns ? undef : [qw/host_name description/] );
    if( defined $tmp_services ) {
        for my $service ( @{$tmp_services} ) {
            $services_data->{ $service->{'host_name'} }->{ $service->{'description'} } = $service;
        }
    }
    return($host_data, $services_data);
}


##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
