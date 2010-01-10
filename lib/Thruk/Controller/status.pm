package Thruk::Controller::status;

use strict;
use warnings;
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
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    # which style to display?
    my $allowed_subpages = {'detail' => 1, 'grid' => 1, 'hostdetail' => 1, 'overview' => 1, 'summary' => 1};
    my $style = $c->{'request'}->{'parameters'}->{'style'} || '';

    if($style eq '') {
        if(defined $c->{'request'}->{'parameters'}->{'hostgroup'} and $c->{'request'}->{'parameters'}->{'hostgroup'} ne '') {
            $style = 'overview';
        }
        if(defined $c->{'request'}->{'parameters'}->{'servicegroup'} and $c->{'request'}->{'parameters'}->{'servicegroup'} ne '') {
            $style = 'overview';
        }
    }

    $style = 'detail' unless defined $allowed_subpages->{$style};

    # did we get a search request?
    if(defined $c->{'request'}->{'parameters'}->{'navbarsearch'} and $c->{'request'}->{'parameters'}->{'navbarsearch'} eq '1') {
        $style = $self->_process_search_request($c);
    }

    # normal pages
    if($style eq 'detail') {
        $self->_process_details_page($c);
    }
    elsif($style eq 'hostdetail') {
        $self->_process_hostdetails_page($c);
    }
    elsif($style eq 'overview') {
        $self->_process_overview_page($c);
    }
    elsif($style eq 'grid') {
        $self->_process_grid_page($c);
    }
    elsif($style eq 'summary') {
        $self->_process_summary_page($c);
    }

    $c->stash->{title}          = 'Current Network Status';
    $c->stash->{infoBoxTitle}   = 'Current Network Status';
    $c->stash->{page}           = 'status';
    $c->stash->{template}       = 'status_'.$style.'.tt';
}

##########################################################
# check for search results
sub _process_search_request {
    my ( $self, $c ) = @_;

    # search pattern is in host param
    my $host = $c->{'request'}->{'parameters'}->{'host'};

    return('detail') unless defined $host;

    # is there a servicegroup with this name?
    my $servicegroups = $c->{'live'}->selectall_arrayref("GET servicegroups\n".Thruk::Helper::get_auth_filter($c, 'servicegroups')."\nColumns: name\nFilter: name = $host");
    if(scalar @{$servicegroups} > 0) {
        $c->{'request'}->{'parameters'}->{'servicegroup'} = $host;
        return('overview');
    }

    # is there a hostgroup with this name?
    my $hostgroups = $c->{'live'}->selectall_arrayref("GET hostgroups\n".Thruk::Helper::get_auth_filter($c, 'hostgroups')."\nColumns: name\nFilter: name = $host");
    if(scalar @{$hostgroups} > 0) {
        $c->{'request'}->{'parameters'}->{'hostgroup'} = $host;
        return('overview');
    }

    return('detail');
}

##########################################################
# create the status details page
sub _process_details_page {
    my ( $self, $c ) = @_;

    # which host to display?
    my $host          = $c->{'request'}->{'parameters'}->{'host'}         || '';
    my $hostgroup     = $c->{'request'}->{'parameters'}->{'hostgroup'}    || '';
    my $servicegroup  = $c->{'request'}->{'parameters'}->{'servicegroup'} || '';
    my $hostfilter    = "";
    my $servicefilter = "";

    if($host ne 'all' and $host ne '') {
        $hostfilter    = "Filter: name = $host\n";
        $servicefilter = "Filter: host_name = $host\n";

        # check for wildcards
        if(CORE::index($host, '*') >= 0) {
            # convert wildcards into real regexp
            my $searchhost = $host;
            $searchhost =~ s/\.\*/*/gmx;
            $searchhost =~ s/\*/.*/gmx;
            $hostfilter    = "Filter: name ~~ $searchhost\n";
            $servicefilter = "Filter: host_name ~~ $searchhost\n";
        }
    }
    elsif($hostgroup ne 'all' and $hostgroup ne '') {
        $hostfilter    = "Filter: groups >= $hostgroup\n";
        $servicefilter = "Filter: host_groups >= $hostgroup\n";
    }
    elsif($servicegroup ne 'all' and $servicegroup ne '') {
        $servicefilter = "Filter: groups >= $servicegroup\n";
    }

    # fill the host/service totals box
    $self->_fill_totals_box($c, $hostfilter, $servicefilter);

    # then add some more filter based on get parameter
    ($hostfilter,$servicefilter) = $self->_extend_filter($c,$hostfilter,$servicefilter);

    # get all services
    my $services = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Helper::get_auth_filter($c, 'services')."\n$servicefilter\nColumns: host_name host_state host_address host_acknowledged host_notifications_enabled host_active_checks_enabled host_is_flapping host_scheduled_downtime_depth host_is_executing host_notes_url host_action_url host_icon_image host_icon_image_alt host_comments has_been_checked state description acknowledged comments notifications_enabled active_checks_enabled accept_passive_checks is_flapping scheduled_downtime_depth is_executing notes_url action_url icon_image icon_image_alt last_check last_state_change current_attempt max_check_attempts next_check plugin_output", { Slice => {}, AddPeer => 1 });

    for my $service (@{$services}) {
        # ordering by duration needs this
        $service->{'last_state_change_plus'} = $c->stash->{pi}->{program_start};
        $service->{'last_state_change_plus'} = $service->{'last_state_change'} if $service->{'last_state_change'};
    }

    # do the sort
    my $sorttype   = $c->{'request'}->{'parameters'}->{'sorttype'}   || 1;
    my $sortoption = $c->{'request'}->{'parameters'}->{'sortoption'} || 1;
    my $order = "ASC";
    $order = "DESC" if $sorttype == 2;
    my $sortoptions = {
                '1' => [ ['host_name', 'description'],                              'host name'       ],
                '2' => [ ['description', 'host_name'],                              'service name'    ],
                '3' => [ ['has_been_checked', 'state', 'host_name', 'description'], 'service status'  ],
                '4' => [ ['last_check', 'host_name', 'description'],                'last check time' ],
                '5' => [ ['current_attempt', 'host_name', 'description'],           'attempt number'  ],
                '6' => [ ['last_state_change_plus', 'host_name', 'description'],    'state duration'  ],
    };
    $sortoption = 1 if !defined $sortoptions->{$sortoption};
    my $sortedservices = Thruk::Helper->sort($c, $services, $sortoptions->{$sortoption}->[0], $order);
    if($sortoption == 6) { @{$sortedservices} = reverse @{$sortedservices}; }

    $c->stash->{'orderby'}       = $sortoptions->{$sortoption}->[1];
    $c->stash->{'orderdir'}      = $order;
    $c->stash->{'host'}          = $host;
    $c->stash->{'hostgroup'}     = $hostgroup;
    $c->stash->{'servicegroup'}  = $servicegroup;
    $c->stash->{'services'}      = $sortedservices;
    $c->stash->{'style'}         = 'detail';
}

##########################################################
# create the hostdetails page
sub _process_hostdetails_page {
    my ( $self, $c ) = @_;

    # which hostgroup to display?
    my $hostgroup = $c->{'request'}->{'parameters'}->{'hostgroup'} || 'all';
    my $hostfilter    = "";
    my $servicefilter = "";
    if($hostgroup ne 'all') {
        $hostfilter    = "Filter: groups >= $hostgroup\n";
        $servicefilter = "Filter: host_groups >= $hostgroup\n";
    }

    # fill the host/service totals box
    $self->_fill_totals_box($c, $hostfilter, $servicefilter);

    # then add some more filter based on get parameter
    ($hostfilter,$servicefilter) = $self->_extend_filter($c,$hostfilter,$servicefilter);

    # add comments into hosts.comments and hosts.comment_count
    my $hosts = $c->{'live'}->selectall_arrayref("GET hosts\n".Thruk::Helper::get_auth_filter($c, 'hosts')."\n$hostfilter\nColumns: comments has_been_checked state name address acknowledged notifications_enabled active_checks_enabled is_flapping scheduled_downtime_depth is_executing notes_url action_url icon_image icon_image_alt last_check last_state_change plugin_output next_check", { Slice => {}, AddPeer => 1 });
    for my $host (@{$hosts}) {
        # ordering by duration needs this
        $host->{'last_state_change_plus'} = $c->stash->{pi}->{program_start};
        $host->{'last_state_change_plus'} = $host->{'last_state_change'} if $host->{'last_state_change'};
    }

    # do the sort
    my $sorttype   = $c->{'request'}->{'parameters'}->{'sorttype'}   || 1;
    my $sortoption = $c->{'request'}->{'parameters'}->{'sortoption'} || 7;
    my $order = "ASC";
    $order = "DESC" if $sorttype == 2;
    my $sortoptions = {
                '1' => [ 'name',                                 'host name'       ],
                '4' => [ ['last_check', 'name'],                 'last check time' ],
                '6' => [ ['last_state_change_plus', 'name'],     'state duration'  ],
                '8' => [ ['has_been_checked', 'state', 'name'],  'host status'     ],
    };
    $sortoption = 1 if !defined $sortoptions->{$sortoption};
    my $sortedhosts = Thruk::Helper->sort($c, $hosts, $sortoptions->{$sortoption}->[0], $order);
    if($sortoption == 6) { @{$sortedhosts} = reverse @{$sortedhosts}; }

    $c->stash->{'orderby'}       = $sortoptions->{$sortoption}->[1];
    $c->stash->{'orderdir'}      = $order;
    $c->stash->{'hostgroup'}     = $hostgroup;
    $c->stash->{'hosts'}         = $sortedhosts;
    $c->stash->{'style'}         = 'hostdetail';
}

##########################################################
# create the status details page
sub _process_overview_page {
    my ( $self, $c ) = @_;

    # which host to display?
    my $hostgroup     = $c->{'request'}->{'parameters'}->{'hostgroup'}    || '';
    my $servicegroup  = $c->{'request'}->{'parameters'}->{'servicegroup'} || '';

    my $hostfilter      = "";
    my $servicefilter   = "";
    my $groupfilter     = "";
    if($hostgroup ne '' and $hostgroup ne 'all') {
        $hostfilter      = "Filter: groups >= $hostgroup\n";
        $servicefilter   = "Filter: host_groups >= $hostgroup\n";
        $groupfilter     = "Filter: name = $hostgroup\n";
    }
    elsif($servicegroup ne '' and $servicegroup ne 'all') {
        $servicefilter   = "Filter: groups >= $servicegroup\n";
        $groupfilter     = "Filter: name = $servicegroup\n";
    }

    # fill the host/service totals box
    $self->_fill_totals_box($c, $hostfilter, $servicefilter);

    # then add some more filter based on get parameter
    ($hostfilter,$servicefilter) = $self->_extend_filter($c,$hostfilter,$servicefilter);

    # we need the hostname, address etc...
    my $host_data;
    my $services_data;
    if($hostgroup) {
        $host_data = $c->{'live'}->selectall_hashref("GET hosts\n".Thruk::Helper::get_auth_filter($c, 'hosts')."\nColumns: name address state has_been_checked notes_url action_url icon_image icon_image_alt num_services_ok as ok num_services_unknown as unknown num_services_warn as warning num_services_crit as critical num_services_pending as pending\n$hostfilter", 'name' );
    }
    elsif($servicegroup) {
        $host_data = $c->{'live'}->selectall_hashref("GET hosts\n".Thruk::Helper::get_auth_filter($c, 'hosts')."\nColumns: name address state has_been_checked notes_url action_url icon_image icon_image_alt\n$hostfilter", 'name' );

        # we have to sort in all services and states
        for my $service (@{$c->{'live'}->selectall_arrayref("GET services\n".Thruk::Helper::get_auth_filter($c, 'services')."\nColumns: has_been_checked state description host_name", { Slice => {} })}) {
            next if $service->{'description'} eq '';
            $services_data->{$service->{'host_name'}}->{$service->{'description'}} = $service;
        }
    }

    # get all host/service groups
    my $groups;
    if($hostgroup) {
        $groups = $c->{'live'}->selectall_arrayref("GET hostgroups\n".Thruk::Helper::get_auth_filter($c, 'hostgroups')."\n$groupfilter\nColumns: name alias members", { Slice => {} });
    }
    elsif($servicegroup) {
        $groups = $c->{'live'}->selectall_arrayref("GET servicegroups\n".Thruk::Helper::get_auth_filter($c, 'servicegroups')."\n$groupfilter\nColumns: name alias members", { Slice => {} });
    }

    # join our groups together
    my %joined_groups;
    for my $group (@{$groups}) {

        my $name = $group->{'name'};
        if(!defined $joined_groups{$name}) {
            $joined_groups{$name}->{'name'}  = $group->{'name'};
            $joined_groups{$name}->{'alias'} = $group->{'alias'};
            $joined_groups{$name}->{'hosts'} = {};
        }

        my($hostname,$servicename);
        if($hostgroup) {
            for my $hostname (split /,/, $group->{'members'}) {
                # show only hosts with proper authorization
                next unless defined $host_data->{$hostname};

                if(!defined $joined_groups{$name}->{'hosts'}->{$hostname}) {
                    # clone hash data
                    for my $key (keys %{$host_data->{$hostname}}) {
                        $joined_groups{$name}->{'hosts'}->{$hostname}->{$key} = $host_data->{$hostname}->{$key};
                    }
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'pending'}  = 0;
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'ok'}       = 0;
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'warning'}  = 0;
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'unknown'}  = 0;
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'critical'} = 0;
                }
                $joined_groups{$name}->{'hosts'}->{$hostname}->{'pending'}  += $host_data->{$hostname}->{'pending'};
                $joined_groups{$name}->{'hosts'}->{$hostname}->{'ok'}       += $host_data->{$hostname}->{'ok'};
                $joined_groups{$name}->{'hosts'}->{$hostname}->{'warning'}  += $host_data->{$hostname}->{'warning'};
                $joined_groups{$name}->{'hosts'}->{$hostname}->{'unknown'}  += $host_data->{$hostname}->{'unknown'};
                $joined_groups{$name}->{'hosts'}->{$hostname}->{'critical'} += $host_data->{$hostname}->{'critical'};
            }
        }
        elsif($servicegroup) {
            for my $member (split /,/, $group->{'members'}) {
                my($hostname,$servicename) = split/\|/, $member, 2;
                # show only hosts with proper authorization
                next unless defined $host_data->{$hostname};

                if(!defined $joined_groups{$name}->{'hosts'}->{$hostname}) {
                    # clone hash data
                    for my $key (keys %{$host_data->{$hostname}}) {
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
                if(!$has_been_checked) {
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'pending'}++;
                } elsif($state == 0) {
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'ok'}++;
                } elsif($state == 1) {
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'warning'}++;
                } elsif($state == 2) {
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'critical'}++;
                } elsif($state == 3) {
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{'unknown'}++;
                }
            }
        }

        # remove empty groups
        if(scalar keys %{$joined_groups{$name}->{'hosts'}} == 0) {
            delete $joined_groups{$name};
        }
    }
#use Data::Dumper;
#print Dumper(\%joined_groups);
    $c->stash->{'hostgroup'}    = $hostgroup;
    $c->stash->{'servicegroup'} = $servicegroup;
    $c->stash->{'groups'}       = \%joined_groups;
    $c->stash->{'style'}        = 'overview';
}


##########################################################
# create the status grid page
sub _process_grid_page {
    my ( $self, $c ) = @_;

    # which host to display?
    my $hostgroup     = $c->{'request'}->{'parameters'}->{'hostgroup'}    || '';
    my $servicegroup  = $c->{'request'}->{'parameters'}->{'servicegroup'} || '';

    my $hostfilter      = "";
    my $servicefilter   = "";
    my $groupfilter     = "";
    if($hostgroup ne '' and $hostgroup ne 'all') {
        $hostfilter      = "Filter: groups >= $hostgroup\n";
        $servicefilter   = "Filter: host_groups >= $hostgroup\n";
        $groupfilter     = "Filter: name = $hostgroup\n";
    }
    elsif($servicegroup ne '' and $servicegroup ne 'all') {
        $servicefilter   = "Filter: groups >= $servicegroup\n";
        $groupfilter     = "Filter: name = $servicegroup\n";
    }

    # fill the host/service totals box
    $self->_fill_totals_box($c, $hostfilter, $servicefilter);

    # then add some more filter based on get parameter
    ($hostfilter,$servicefilter) = $self->_extend_filter($c,$hostfilter,$servicefilter);

    # we need the hostname, address etc...
    my $host_data = $c->{'live'}->selectall_hashref("GET hosts\n".Thruk::Helper::get_auth_filter($c, 'hosts')."\nColumns: name address state has_been_checked notes_url action_url icon_image icon_image_alt\n$hostfilter", 'name' );

    # create a hash of all services
    my $services_data;
    for my $service (@{$c->{'live'}->selectall_arrayref("GET services\n".Thruk::Helper::get_auth_filter($c, 'services')."\nColumns: has_been_checked state description host_name\n$servicefilter", { Slice => {} })}) {
        $services_data->{$service->{'host_name'}}->{$service->{'description'}} = $service;
    }

    # get all host/service groups
    my $groups;
    if($hostgroup) {
        $groups = $c->{'live'}->selectall_arrayref("GET hostgroups\n".Thruk::Helper::get_auth_filter($c, 'hostgroups')."\n$groupfilter\nColumns: name alias members", { Slice => {} });
    }
    elsif($servicegroup) {
        $groups = $c->{'live'}->selectall_arrayref("GET servicegroups\n".Thruk::Helper::get_auth_filter($c, 'servicegroups')."\n$groupfilter\nColumns: name alias members", { Slice => {} });
    }

    # sort in hosts / services
    my %joined_groups;
    for my $group (@{$groups}) {
        my $name = $group->{'name'};
        if(!defined $joined_groups{$name}) {
            $joined_groups{$name}->{'name'}  = $group->{'name'};
            $joined_groups{$name}->{'alias'} = $group->{'alias'};
            $joined_groups{$name}->{'hosts'} = {};
        }

        for my $member (split /,/, $group->{'members'}) {
            my($hostname,$servicename);
            if($hostgroup) {
                $hostname = $member;
            }
            if($servicegroup) {
                ($hostname,$servicename) = split/\|/, $member, 2;
            }

            next unless defined $host_data->{$hostname};

            if(!defined $joined_groups{$name}->{'hosts'}->{$hostname}) {
                # clone host data
                for my $key (keys %{$host_data->{$hostname}}) {
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{$key} = $host_data->{$hostname}->{$key};
                }
            }

            # add all services
            if($hostgroup) {
                for my $service (sort keys %{$services_data->{$hostname}}) {
                     $joined_groups{$name}->{'hosts'}->{$hostname}->{'services'}->{$services_data->{$hostname}->{$service}->{'description'}} = $services_data->{$hostname}->{$service};
                }
            }
            elsif($servicegroup) {
                $joined_groups{$name}->{'hosts'}->{$hostname}->{'services'}->{$services_data->{$hostname}->{$servicename}->{'description'}} = $services_data->{$hostname}->{$servicename};
            }
        }

        # remove empty groups
        if(scalar keys %{$joined_groups{$name}->{'hosts'}} == 0) {
            delete $joined_groups{$name};
        }
    }

    $c->stash->{'hostgroup'}    = $hostgroup;
    $c->stash->{'servicegroup'} = $servicegroup;
    $c->stash->{'groups'}       = \%joined_groups;
    $c->stash->{'style'}        = 'grid';
}


##########################################################
# create the status summary page
sub _process_summary_page {
    my ( $self, $c ) = @_;

    # which host to display?
    my $hostgroup     = $c->{'request'}->{'parameters'}->{'hostgroup'}    || '';
    my $servicegroup  = $c->{'request'}->{'parameters'}->{'servicegroup'} || '';

    my $hostfilter      = "";
    my $servicefilter   = "";
    my $groupfilter     = "";
    if($hostgroup ne '' and $hostgroup ne 'all') {
        $hostfilter      = "Filter: groups >= $hostgroup\n";
        $servicefilter   = "Filter: host_groups >= $hostgroup\n";
        $groupfilter     = "Filter: name = $hostgroup\n";
    }
    elsif($servicegroup ne '' and $servicegroup ne 'all') {
        $servicefilter   = "Filter: groups >= $servicegroup\n";
        $groupfilter     = "Filter: name = $servicegroup\n";
    }

    # fill the host/service totals box
    $self->_fill_totals_box($c, $hostfilter, $servicefilter);

    # then add some more filter based on get parameter
    ($hostfilter,$servicefilter) = $self->_extend_filter($c,$hostfilter,$servicefilter);

    # get all host/service groups
    my $groups;
    if($hostgroup) {
        $groups = $c->{'live'}->selectall_hashref("GET hostgroups\n".Thruk::Helper::get_auth_filter($c, 'hostgroups')."\n$groupfilter\nColumns: name alias members", 'name');
    }
    elsif($servicegroup) {
        $groups = $c->{'live'}->selectall_hashref("GET servicegroups\n".Thruk::Helper::get_auth_filter($c, 'servicegroups')."\n$groupfilter\nColumns: name alias members", 'name');
    }

    # set defaults for all groups
    for my $group (values %{$groups}) {
        $group->{'hosts_pending'}               = 0;
        $group->{'hosts_up'}                    = 0;
        $group->{'hosts_down'}                  = 0;
        $group->{'hosts_down_unhandled'}        = 0;
        $group->{'hosts_down_downtime'}         = 0;
        $group->{'hosts_down_ack'}              = 0;
        $group->{'hosts_down_disabled'}         = 0;
        $group->{'hosts_unreachable'}           = 0;
        $group->{'hosts_unreachable_unhandled'} = 0;
        $group->{'hosts_unreachable_downtime'}  = 0;
        $group->{'hosts_unreachable_ack'}       = 0;
        $group->{'hosts_unreachable_disabled'}  = 0;

        $group->{'services_pending'}            = 0;
        $group->{'services_ok'}                 = 0;
        $group->{'services_warning'}            = 0;
        $group->{'services_warning_unhandled'}  = 0;
        $group->{'services_warning_downtime'}   = 0;
        $group->{'services_warning_prob_host'}  = 0;
        $group->{'services_warning_ack'}        = 0;
        $group->{'services_warning_disabled'}   = 0;
        $group->{'services_unknown'}            = 0;
        $group->{'services_unknown_unhandled'}  = 0;
        $group->{'services_unknown_downtime'}   = 0;
        $group->{'services_unknown_prob_host'}  = 0;
        $group->{'services_unknown_ack'}        = 0;
        $group->{'services_unknown_disabled'}   = 0;
        $group->{'services_critical'}           = 0;
        $group->{'services_critical_unhandled'} = 0;
        $group->{'services_critical_downtime'}  = 0;
        $group->{'services_critical_prob_host'} = 0;
        $group->{'services_critical_ack'}       = 0;
        $group->{'services_critical_disabled'}  = 0;
    }

    my $services_data;
    my $groupsname = "host_groups";
    if($hostgroup) {
        # we need the hosts data
        my $host_data = $c->{'live'}->selectall_arrayref("GET hosts\n".Thruk::Helper::get_auth_filter($c, 'hosts')."\nColumns: name groups state checks_enabled acknowledged scheduled_downtime_depth has_been_checked\n$hostfilter", { Slice => 1 } );

        # create a hash of all services
        $services_data = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Helper::get_auth_filter($c, 'services')."\nColumns: has_been_checked state host_name host_state groups host_groups checks_enabled acknowledged scheduled_downtime_depth\n$servicefilter", { Slice => {} });

        for my $host (@{$host_data}) {
            for my $group (split/,/, $host->{'groups'}) {
                next if !defined $groups->{$group};
                $self->_summary_add_host_stats("", $groups->{$group}, $host);
            }
        }
    }

    if($servicegroup) {
        # create a hash of all services
        $services_data = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Helper::get_auth_filter($c, 'services')."\nColumns: has_been_checked state host_name host_state groups host_groups checks_enabled acknowledged scheduled_downtime_depth host_name host_state host_checks_enabled host_acknowledged host_scheduled_downtime_depth host_has_been_checked\n$servicefilter", { Slice => {} });

        $groupsname = "groups";
    }

    my %host_already_added;
    for my $service (@{$services_data}) {
        for my $group (split/,/, $service->{$groupsname}) {
            next if !defined $groups->{$group};

            if($servicegroup) {
                if(!defined $host_already_added{$group}->{$service->{'host_name'}}) {
                    $self->_summary_add_host_stats("host_", $groups->{$group}, $service);
                    $host_already_added{$group}->{$service->{'host_name'}} = 1;
                }
            }

            $groups->{$group}->{'services_total'}++;

            if($service->{'has_been_checked'} == 0) { $groups->{$group}->{'services_pending'}++; }
            elsif($service->{'state'} == 0)         { $groups->{$group}->{'services_ok'}++; }
            elsif($service->{'state'} == 1)         { $groups->{$group}->{'services_warning'}++; }
            elsif($service->{'state'} == 2)         { $groups->{$group}->{'services_critical'}++; }
            elsif($service->{'state'} == 3)         { $groups->{$group}->{'services_unknown'}++; }

            if($service->{'state'} == 1 and $service->{'scheduled_downtime_depth'} > 0) { $groups->{$group}->{'services_warning_downtime'}++; }
            if($service->{'state'} == 1 and $service->{'acknowledged'}            == 1) { $groups->{$group}->{'services_warning_ack'}++; }
            if($service->{'state'} == 1 and $service->{'checks_enabled'}          == 0) { $groups->{$group}->{'services_warning_disabled'}++; }
            if($service->{'state'} == 1 and $service->{'host_state'}               > 0) { $groups->{$group}->{'services_warning_prob_host'}++; }
            elsif($service->{'state'} == 1 and $service->{'checks_enabled'}       == 1 and $service->{'host_state'} == 0 and $service->{'acknowledged'} == 0 and $service->{'scheduled_downtime_depth'} == 0) { $groups->{$group}->{'services_warning_unhandled'}++; }

            if($service->{'state'} == 2 and $service->{'scheduled_downtime_depth'} > 0) { $groups->{$group}->{'services_critical_downtime'}++; }
            if($service->{'state'} == 2 and $service->{'acknowledged'}            == 1) { $groups->{$group}->{'services_critical_ack'}++; }
            if($service->{'state'} == 2 and $service->{'checks_enabled'}          == 0) { $groups->{$group}->{'services_critical_disabled'}++; }
            if($service->{'state'} == 2 and $service->{'host_state'}               > 0) { $groups->{$group}->{'services_critical_prob_host'}++; }
            elsif($service->{'state'} == 2 and $service->{'checks_enabled'}       == 1 and $service->{'host_state'} == 0 and $service->{'acknowledged'} == 0 and $service->{'scheduled_downtime_depth'} == 0) { $groups->{$group}->{'services_critical_unhandled'}++; }

            if($service->{'state'} == 3 and $service->{'scheduled_downtime_depth'} > 0) { $groups->{$group}->{'services_unknown_downtime'}++; }
            if($service->{'state'} == 3 and $service->{'acknowledged'}            == 1) { $groups->{$group}->{'services_unknown_ack'}++; }
            if($service->{'state'} == 3 and $service->{'checks_enabled'}          == 0) { $groups->{$group}->{'services_unknown_disabled'}++; }
            if($service->{'state'} == 3 and $service->{'host_state'}               > 0) { $groups->{$group}->{'services_unknown_prob_host'}++; }
            elsif($service->{'state'} == 3 and $service->{'checks_enabled'}       == 1 and $service->{'host_state'} == 0 and $service->{'acknowledged'} == 0 and $service->{'scheduled_downtime_depth'} == 0) { $groups->{$group}->{'services_unknown_unhandled'}++; }
        }
    }

    for my $group (values %{$groups}) {
        # remove empty groups
        $group->{'services_total'} = 0 unless defined $group->{'services_total'};
        $group->{'hosts_total'}    = 0 unless defined $group->{'hosts_total'};
        if($group->{'services_total'} + $group->{'hosts_total'} == 0) {
            delete $groups->{$group->{'name'}};
        }
    }

#use Data::Dumper;
#$Data::Dumper::Sortkeys = 1;
#print Dumper($groups);
    $c->stash->{'hostgroup'}    = $hostgroup;
    $c->stash->{'servicegroup'} = $servicegroup;
    $c->stash->{'groups'}       = $groups;
    $c->stash->{'style'}        = 'summary';
}

##########################################################
sub _summary_add_host_stats {
    my $self   = shift;
    my $prefix = shift;
    my $group  = shift;
    my $host   = shift;

    $group->{'hosts_total'}++;

    if($host->{$prefix.'has_been_checked'} == 0) { $group->{'hosts_pending'}++; }
    elsif($host->{$prefix.'state'} == 0)         { $group->{'hosts_up'}++; }
    elsif($host->{$prefix.'state'} == 1)         { $group->{'hosts_down'}++; }
    elsif($host->{$prefix.'state'} == 2)         { $group->{'hosts_unreachable'}++; }

    if($host->{$prefix.'state'} == 1 and $host->{$prefix.'scheduled_downtime_depth'} > 0) { $group->{'hosts_down_downtime'}++; }
    if($host->{$prefix.'state'} == 1 and $host->{$prefix.'acknowledged'}            == 1) { $group->{'hosts_down_ack'}++; }
    if($host->{$prefix.'state'} == 1 and $host->{$prefix.'checks_enabled'}          == 0) { $group->{'hosts_down_disabled'}++; }
    if($host->{$prefix.'state'} == 1 and $host->{$prefix.'checks_enabled'}          == 1 and $host->{$prefix.'acknowledged'} == 0 and $host->{$prefix.'scheduled_downtime_depth'} == 0) { $group->{'hosts_down_unhandled'}++; }

    if($host->{$prefix.'state'} == 2 and $host->{$prefix.'scheduled_downtime_depth'} > 0) { $group->{'hosts_unreachable_downtime'}++; }
    if($host->{$prefix.'state'} == 2 and $host->{$prefix.'acknowledged'}            == 1) { $group->{'hosts_unreachable_ack'}++; }
    if($host->{$prefix.'state'} == 2 and $host->{$prefix.'checks_enabled'}          == 0) { $group->{'hosts_unreachable_disabled'}++; }
    if($host->{$prefix.'state'} == 2 and $host->{$prefix.'checks_enabled'}          == 1 and $host->{$prefix.'acknowledged'} == 0 and $host->{$prefix.'scheduled_downtime_depth'} == 0) { $group->{'hosts_unreachable_unhandled'}++; }

    return;
}

##########################################################
sub _fill_totals_box {
    my ( $self, $c, $hostfilter, $servicefilter ) = @_;
    # host status box
    my $host_stats = $c->{'live'}->selectrow_hashref("GET hosts\n".Thruk::Helper::get_auth_filter($c, 'hosts')."
$hostfilter
Stats: has_been_checked = 1
Stats: state = 0
StatsAnd: 2 as up

Stats: has_been_checked = 1
Stats: state = 1
StatsAnd: 2 as down

Stats: has_been_checked = 1
Stats: state = 2
StatsAnd: 2 as unreachable

Stats: has_been_checked = 0 as pending
");


    # services status box
    my $service_stats = $c->{'live'}->selectrow_hashref("GET services\n".Thruk::Helper::get_auth_filter($c, 'services')."
$servicefilter
Stats: has_been_checked = 1
Stats: state = 0
StatsAnd: 2 as ok

Stats: has_been_checked = 1
Stats: state = 1
StatsAnd: 2 as warning

Stats: has_been_checked = 1
Stats: state = 2
StatsAnd: 2 as critical

Stats: has_been_checked = 1
Stats: state = 3
StatsAnd: 2 as unknown

Stats: has_been_checked = 0 as pending
");

    $c->stash->{'host_stats'}    = $host_stats;
    $c->stash->{'service_stats'} = $service_stats;
}

##########################################################
sub _extend_filter {
    my ( $self, $c, $hostfilter, $servicefilter ) = @_;

    $hostfilter    = '' unless defined $hostfilter;
    $servicefilter = '' unless defined $servicefilter;

    # host statustype filter (up,down,...)
    my($host_statustype_filtername,$host_statustype_filter,$host_statustype_filter_service)
            = $self->_get_host_statustype_filter($c->{'request'}->{'parameters'}->{'hoststatustypes'});
    $hostfilter    .= $host_statustype_filter;
    $servicefilter .= $host_statustype_filter_service;

    $c->stash->{'show_filter_table'}          = 1 if $host_statustype_filter ne '';
    $c->stash->{'host_statustype_filtername'} = $host_statustype_filtername;

    # host props filter (downtime, acknowledged...)
    my($host_prop_filtername,$host_prop_filter,$host_prop_filter_service) = $self->_get_host_prop_filter($c->{'request'}->{'parameters'}->{'hostprops'});
    $hostfilter    .= $host_prop_filter;
    $servicefilter .= $host_prop_filter_service;

    $c->stash->{'show_filter_table'}    = 1 if $host_prop_filter ne '';
    $c->stash->{'host_prop_filtername'} = $host_prop_filtername;


    # service statustype filter (ok,warning,...)
    my($service_statustype_filtername,$service_statustype_filter_service)
            = $self->_get_service_statustype_filter($c->{'request'}->{'parameters'}->{'servicestatustypes'});
    $servicefilter .= $service_statustype_filter_service;

    $c->stash->{'show_filter_table'}             = 1 if $service_statustype_filter_service ne '';
    $c->stash->{'service_statustype_filtername'} = $service_statustype_filtername;

    # service props filter (downtime, acknowledged...)
    my($service_prop_filtername,$service_prop_filter_service) = $self->_get_service_prop_filter($c->{'request'}->{'parameters'}->{'serviceprops'});
    $servicefilter .= $service_prop_filter_service;

    $c->stash->{'show_filter_table'}       = 1 if $service_prop_filter_service ne '';
    $c->stash->{'service_prop_filtername'} = $service_prop_filtername;

    $c->stash->{'servicestatustypes'} = $c->{'request'}->{'parameters'}->{'servicestatustypes'};
    $c->stash->{'hoststatustypes'}    = $c->{'request'}->{'parameters'}->{'hoststatustypes'};

    return($hostfilter,$servicefilter);
}

##########################################################
sub _get_host_statustype_filter {
    my ( $self, $number ) = @_;

    $number = 15 if !defined $number or $number <= 0 or $number > 15;
    my $hoststatusfiltername = 'All';
    my $hostfilter           = '';
    my $servicefilter        = '';
    if($number and $number != 15) {
        my @hoststatusfilter;
        my @servicestatusfilter;
        my @hoststatusfiltername;
        my @bits = reverse split(/ */, unpack("B*", pack("n", int($number))));

        if($bits[0]) {  # 1 - pending
            push @hoststatusfilter,    "Filter: has_been_checked = 0";
            push @servicestatusfilter, "Filter: host_has_been_checked = 0";
            push @hoststatusfiltername, 'Pending';
        }
        if($bits[1]) {  # 2 - up
            push @hoststatusfilter,    "Filter: state = 0\nFilter: has_been_checked = 1\nAnd: 2";
            push @servicestatusfilter, "Filter: host_state = 0\nFilter: host_has_been_checked = 1\nAnd: 2";
            push @hoststatusfiltername, 'Up';
        }
        if($bits[2]) {  # 4 - down
            push @hoststatusfilter,    "Filter: state = 1\nFilter: has_been_checked = 1\nAnd: 2";
            push @servicestatusfilter, "Filter: host_state = 1\nFilter: host_has_been_checked = 1\nAnd: 2";
            push @hoststatusfiltername, 'Down';
        }
        if($bits[3]) {  # 8 - unreachable
            push @hoststatusfilter,    "Filter: state = 2\nFilter: has_been_checked = 1\nAnd: 2";
            push @servicestatusfilter, "Filter: host_state = 2\nFilter: host_has_been_checked = 1\nAnd: 2";
            push @hoststatusfiltername, 'Unreachable';
        }
        $hoststatusfiltername = join(' | ', @hoststatusfiltername);
        $hoststatusfiltername = 'All problems' if $number == 12;

        if(scalar @hoststatusfilter > 1) {
            $hostfilter    .= join("\n", @hoststatusfilter)."\nOr: ".(scalar @hoststatusfilter)."\n";
            $servicefilter .= join("\n", @servicestatusfilter)."\nOr: ".(scalar @servicestatusfilter)."\n";
        }
        elsif(scalar @hoststatusfilter == 1) {
            $hostfilter    .= $hoststatusfilter[0]."\n";
            $servicefilter .= $servicestatusfilter[0]."\n";
        }
    }
    return($hoststatusfiltername,$hostfilter,$servicefilter);
}

##########################################################
sub _get_host_prop_filter {
    my ( $self, $number ) = @_;

    $number = 0 if !defined $number or $number <= 0 or $number > 1048575;
    my $host_prop_filtername = 'Any';
    my $hostfilter           = '';
    my $servicefilter        = '';
    if($number > 0) {
        my @host_prop_filter;
        my @host_prop_filter_service;
        my @host_prop_filtername;
        my @bits = reverse split(/ */, unpack("B*", pack("N", int($number))));

        if($bits[0]) {  # 1 - In Scheduled Downtime
            push @host_prop_filter,         "Filter: scheduled_downtime_depth > 0";
            push @host_prop_filter_service, "Filter: host_scheduled_downtime_depth > 0";
            push @host_prop_filtername,     'In Scheduled Downtime';
        }
        if($bits[1]) {  # 2 - Not In Scheduled Downtime
            push @host_prop_filter,         "Filter: scheduled_downtime_depth = 0";
            push @host_prop_filter_service, "Filter: host_scheduled_downtime_depth = 0";
            push @host_prop_filtername,     'Not In Scheduled Downtime';
        }
        if($bits[2]) {  # 4 - Has Been Acknowledged
            push @host_prop_filter,         "Filter: acknowledged = 1";
            push @host_prop_filter_service, "Filter: host_acknowledged = 1";
            push @host_prop_filtername,     'Has Been Acknowledged';
        }
        if($bits[3]) {  # 8 - Has Not Been Acknowledged
            push @host_prop_filter,         "Filter: acknowledged = 0";
            push @host_prop_filter_service, "Filter: host_acknowledged = 0";
            push @host_prop_filtername,     'Has Not Been Acknowledged';
        }
        if($bits[4]) {  # 16 - Checks Disabled
            push @host_prop_filter,         "Filter: checks_enabled = 0";
            push @host_prop_filter_service, "Filter: host_checks_enabled = 0";
            push @host_prop_filtername,     'Checks Disabled';
        }
        if($bits[5]) {  # 32 - Checks Enabled
            push @host_prop_filter,         "Filter: checks_enabled = 1";
            push @host_prop_filter_service, "Filter: host_checks_enabled = 1";
            push @host_prop_filtername,     'Checks Enabled';
        }
        if($bits[6]) {  # 64 - Event Handler Disabled
            push @host_prop_filter,         "Filter: event_handler_enabled = 0";
            push @host_prop_filter_service, "Filter: host_event_handler_enabled = 0";
            push @host_prop_filtername,     'Event Handler Disabled';
        }
        if($bits[7]) {  # 128 - Event Handler Enabled
            push @host_prop_filter,         "Filter: event_handler_enabled = 1";
            push @host_prop_filter_service, "Filter: host_event_handler_enabled = 1";
            push @host_prop_filtername,     'Event Handler Enabled';
        }
        if($bits[8]) {  # 256 - Flap Detection Disabled
            push @host_prop_filter,         "Filter: flap_detection_enabled = 0";
            push @host_prop_filter_service, "Filter: host_flap_detection_enabled = 0";
            push @host_prop_filtername,     'Flap Detection Disabled';
        }
        if($bits[9]) {  # 512 - Flap Detection Enabled
            push @host_prop_filter,         "Filter: flap_detection_enabled = 1";
            push @host_prop_filter_service, "Filter: host_flap_detection_enabled = 1";
            push @host_prop_filtername,     'Flap Detection Enabled';
        }
        if($bits[10]) {  # 1024 - Is Flapping
            push @host_prop_filter,         "Filter: is_flapping = 1";
            push @host_prop_filter_service, "Filter: host_is_flapping = 1";
            push @host_prop_filtername,     'Is Flapping';
        }
        if($bits[11]) {  # 2048 - Is Not Flapping
            push @host_prop_filter,         "Filter: is_flapping = 0";
            push @host_prop_filter_service, "Filter: host_is_flapping = 0";
            push @host_prop_filtername,     'Is Not Flapping';
        }
        if($bits[12]) {  # 4096 - Notifications Disabled
            push @host_prop_filter,         "Filter: notifications_enabled = 0";
            push @host_prop_filter_service, "Filter: host_notifications_enabled = 0";
            push @host_prop_filtername,     'Notifications Disabled';
        }
        if($bits[13]) {  # 8192 - Notifications Enabled
            push @host_prop_filter,         "Filter: notifications_enabled = 1";
            push @host_prop_filter_service, "Filter: host_notifications_enabled = 1";
            push @host_prop_filtername,     'Notifications Enabled';
        }
        if($bits[14]) {  # 16384 - Passive Checks Disabled
            push @host_prop_filter,         "Filter: accept_passive_checks = 0";
            push @host_prop_filter_service, "Filter: host_accept_passive_checks = 0";
            push @host_prop_filtername,     'Passive Checks Disabled';
        }
        if($bits[15]) {  # 32768 - Passive Checks Enabled
            push @host_prop_filter,         "Filter: accept_passive_checks = 1";
            push @host_prop_filter_service, "Filter: host_accept_passive_checks = 1";
            push @host_prop_filtername,     'Passive Checks Enabled';
        }
        if($bits[16]) {  # 65536 - Passive Checks
            push @host_prop_filter,         "Filter: check_type = 1";
            push @host_prop_filter_service, "Filter: host_check_type = 1";
            push @host_prop_filtername,     'Passive Checks';
        }
        if($bits[17]) {  # 131072 - Active Checks
            push @host_prop_filter,         "Filter: check_type = 0";
            push @host_prop_filter_service, "Filter: host_check_type = 0";
            push @host_prop_filtername,     'Active Checks';
        }
        if($bits[18]) {  # 262144 - In Hard State
            push @host_prop_filter,         "Filter: hard_state = 0";
            push @host_prop_filter_service, "Filter: host_hard_state = 0";
            push @host_prop_filtername,     'In Hard State';
        }
        if($bits[19]) {  # 524288 - In Soft State
            push @host_prop_filter,         "Filter: hard_state = 1";
            push @host_prop_filter_service, "Filter: host_hard_state = 1";
            push @host_prop_filtername,     'In Soft State';
        }

        $host_prop_filtername = join(' &amp; ', @host_prop_filtername);

        if(scalar @host_prop_filter > 1) {
            $hostfilter    .= join("\n", @host_prop_filter)."\nAnd: ".(scalar @host_prop_filter)."\n";
            $servicefilter .= join("\n", @host_prop_filter_service)."\nAnd: ".(scalar @host_prop_filter_service)."\n";
        }
        elsif(scalar @host_prop_filter == 1) {
            $hostfilter    .= $host_prop_filter[0]."\n";
            $servicefilter .= $host_prop_filter_service[0]."\n";
        }
    }
    return($host_prop_filtername,$hostfilter,$servicefilter);
}

##########################################################
sub _get_service_statustype_filter {
    my ( $self, $number ) = @_;

    $number = 31 if !defined $number or $number <= 0 or $number > 31;
    my $servicestatusfiltername = 'All';
    my $servicefilter           = '';
    if($number and $number != 31) {
        my @servicestatusfilter;
        my @servicestatusfiltername;
        my @bits = reverse split(/ */, unpack("B*", pack("n", int($number))));

        if($bits[0]) {  # 1 - pending
            push @servicestatusfilter, "Filter: has_been_checked = 0";
            push @servicestatusfiltername, 'Pending';
        }
        if($bits[1]) {  # 2 - ok
            push @servicestatusfilter, "Filter: state = 0\nFilter: has_been_checked = 1\nAnd: 2";
            push @servicestatusfiltername, 'Ok';
        }
        if($bits[2]) {  # 4 - warning
            push @servicestatusfilter, "Filter: state = 1\nFilter: has_been_checked = 1\nAnd: 2";
            push @servicestatusfiltername, 'Warning';
        }
        if($bits[3]) {  # 8 - unknown
            push @servicestatusfilter, "Filter: state = 3\nFilter: has_been_checked = 1\nAnd: 2";
            push @servicestatusfiltername, 'Unknown';
        }
        if($bits[4]) {  # 16 - critical
            push @servicestatusfilter, "Filter: state = 2\nFilter: has_been_checked = 1\nAnd: 2";
            push @servicestatusfiltername, 'Critical';
        }
        $servicestatusfiltername = join(' | ', @servicestatusfiltername);
        $servicestatusfiltername = 'All problems' if $number == 28;

        if(scalar @servicestatusfilter > 1) {
            $servicefilter .= join("\n", @servicestatusfilter)."\nOr: ".(scalar @servicestatusfilter)."\n";
        }
        elsif(scalar @servicestatusfilter == 1) {
            $servicefilter .= $servicestatusfilter[0]."\n";
        }
    }
    return($servicestatusfiltername,$servicefilter);
}

##########################################################
sub _get_service_prop_filter {
    my ( $self, $number ) = @_;

    $number = 0 if !defined $number or $number <= 0 or $number > 1048575;
    my $service_prop_filtername = 'Any';
    my $servicefilter           = '';
    if($number > 0) {
        my @service_prop_filter;
        my @service_prop_filtername;
        my @bits = reverse split(/ */, unpack("B*", pack("N", int($number))));

        if($bits[0]) {  # 1 - In Scheduled Downtime
            push @service_prop_filter,         "Filter: scheduled_downtime_depth > 0";
            push @service_prop_filtername,     'In Scheduled Downtime';
        }
        if($bits[1]) {  # 2 - Not In Scheduled Downtime
            push @service_prop_filter,         "Filter: scheduled_downtime_depth = 0";
            push @service_prop_filtername,     'Not In Scheduled Downtime';
        }
        if($bits[2]) {  # 4 - Has Been Acknowledged
            push @service_prop_filter,         "Filter: acknowledged = 1";
            push @service_prop_filtername,     'Has Been Acknowledged';
        }
        if($bits[3]) {  # 8 - Has Not Been Acknowledged
            push @service_prop_filter,         "Filter: acknowledged = 0";
            push @service_prop_filtername,     'Has Not Been Acknowledged';
        }
        if($bits[4]) {  # 16 - Checks Disabled
            push @service_prop_filter,         "Filter: checks_enabled = 0";
            push @service_prop_filtername,     'Active Checks Disabled';
        }
        if($bits[5]) {  # 32 - Checks Enabled
            push @service_prop_filter,         "Filter: checks_enabled = 1";
            push @service_prop_filtername,     'Active Checks Enabled';
        }
        if($bits[6]) {  # 64 - Event Handler Disabled
            push @service_prop_filter,         "Filter: event_handler_enabled = 0";
            push @service_prop_filtername,     'Event Handler Disabled';
        }
        if($bits[7]) {  # 128 - Event Handler Enabled
            push @service_prop_filter,         "Filter: event_handler_enabled = 1";
            push @service_prop_filtername,     'Event Handler Enabled';
        }
        if($bits[8]) {  # 256 - Flap Detection Enabled
            push @service_prop_filter,         "Filter: flap_detection_enabled = 1";
            push @service_prop_filtername,     'Flap Detection Enabled';
        }
        if($bits[9]) {  # 512 - Flap Detection Disabled
            push @service_prop_filter,         "Filter: flap_detection_enabled = 0";
            push @service_prop_filtername,     'Flap Detection Disabled';
        }
        if($bits[10]) {  # 1024 - Is Flapping
            push @service_prop_filter,         "Filter: is_flapping = 1";
            push @service_prop_filtername,     'Is Flapping';
        }
        if($bits[11]) {  # 2048 - Is Not Flapping
            push @service_prop_filter,         "Filter: is_flapping = 0";
            push @service_prop_filtername,     'Is Not Flapping';
        }
        if($bits[12]) {  # 4096 - Notifications Disabled
            push @service_prop_filter,         "Filter: notifications_enabled = 0";
            push @service_prop_filtername,     'Notifications Disabled';
        }
        if($bits[13]) {  # 8192 - Notifications Enabled
            push @service_prop_filter,         "Filter: notifications_enabled = 1";
            push @service_prop_filtername,     'Notifications Enabled';
        }
        if($bits[14]) {  # 16384 - Passive Checks Disabled
            push @service_prop_filter,         "Filter: accept_passive_checks = 0";
            push @service_prop_filtername,     'Passive Checks Disabled';
        }
        if($bits[15]) {  # 32768 - Passive Checks Enabled
            push @service_prop_filter,         "Filter: accept_passive_checks = 1";
            push @service_prop_filtername,     'Passive Checks Enabled';
        }
        if($bits[16]) {  # 65536 - Passive Checks
            push @service_prop_filter,         "Filter: check_type = 1";
            push @service_prop_filtername,     'Passive Checks';
        }
        if($bits[17]) {  # 131072 - Active Checks
            push @service_prop_filter,         "Filter: check_type = 0";
            push @service_prop_filtername,     'Active Checks';
        }
        if($bits[18]) {  # 262144 - In Hard State
            push @service_prop_filter,         "Filter: state_type = 1";
            push @service_prop_filtername,     'In Hard State';
        }
        if($bits[19]) {  # 524288 - In Soft State
            push @service_prop_filter,         "Filter: state_type = 0";
            push @service_prop_filtername,     'In Soft State';
        }

        $service_prop_filtername = join(' &amp; ', @service_prop_filtername);

        if(scalar @service_prop_filter > 1) {
            $servicefilter .= join("\n", @service_prop_filter)."\nAnd: ".(scalar @service_prop_filter)."\n";
        }
        elsif(scalar @service_prop_filter == 1) {
            $servicefilter .= $service_prop_filter[0]."\n";
        }
    }
    return($service_prop_filtername,$servicefilter);
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
