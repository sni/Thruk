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

    # put some filter into the stash
    $c->stash->{'hoststatustypes'}    = $c->{'request'}->{'parameters'}->{'hoststatustypes'};
    $c->stash->{'hostprops'}          = $c->{'request'}->{'parameters'}->{'hostprops'};
    $c->stash->{'servicestatustypes'} = $c->{'request'}->{'parameters'}->{'servicestatustypes'};
    $c->stash->{'serviceprops'}       = $c->{'request'}->{'parameters'}->{'serviceprops'};

    $style = 'detail' unless defined $allowed_subpages->{$style};

    # did we get a search request?
    if(defined $c->{'request'}->{'parameters'}->{'navbarsearch'} and $c->{'request'}->{'parameters'}->{'navbarsearch'} eq '1') {
        $style = $self->_process_search_request($c);
    }

    # raw data request?
    $c->stash->{'output_format'} = $c->{'request'}->{'parameters'}->{'format'} || 'html';
    if($c->stash->{'output_format'} ne 'html') {
        $self->_process_raw_request($c);
        return 1;
    }
    # normal pages
    elsif($style eq 'detail') {
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

    Thruk::Utils::ssi_include($c);

    if(exists $c->{'request'}->{'parameters'}->{'title'}) {
        my $custom_title = $c->{'request'}->{'parameters'}->{'title'};
        $custom_title =~ s/\+/\ /gmx;
        $c->stash->{custom_title}   = $custom_title;
    }

    my $hidetop = $c->{'request'}->{'parameters'}->{'hidetop'};
    $c->stash->{hidetop}    = $hidetop;

    my $hidesearch = $c->{'request'}->{'parameters'}->{'hidesearch'};
    $c->stash->{hidesearch} = $hidesearch;


    return 1;
}


##########################################################
# check for search results
sub _process_raw_request {
    my ( $self, $c ) = @_;

    if($c->stash->{'output_format'} eq 'search') {
        my(@hostgroups,@servicegroups,@hosts,@services);
        if($c->config->{ajax_search_hostgroups}) {
            my $hostgroups    = $c->{'live'}->selectall_hashref("GET hostgroups\n".Thruk::Utils::Auth::get_auth_filter($c, 'hostgroups')."\nColumns: name", 'name');
            @hostgroups       = keys %{$hostgroups} if defined $hostgroups;
        }
        if($c->config->{ajax_search_servicegroups}) {
            my $servicegroups = $c->{'live'}->selectall_hashref("GET servicegroups\n".Thruk::Utils::Auth::get_auth_filter($c, 'servicegroups')."\nColumns: name", 'name');
            @servicegroups    = keys %{$servicegroups} if defined $servicegroups;
        }
        if($c->config->{ajax_search_hosts}) {
            my $hosts         = $c->{'live'}->selectall_hashref("GET hosts\n".Thruk::Utils::Auth::get_auth_filter($c, 'hosts')."\nColumns: name", 'name');
            @hosts            = keys %{$hosts} if defined $hosts;
        }
        if($c->config->{ajax_search_services}) {
            my $services      = $c->{'live'}->selectall_hashref("GET services\n".Thruk::Utils::Auth::get_auth_filter($c, 'services')."\nColumns: description", 'description');
            @services         = keys %{$services} if defined $services;
        }
        my $json = [
              { 'name' => 'hostgroups',    'data' => \@hostgroups    },
              { 'name' => 'servicegroups', 'data' => \@servicegroups },
              { 'name' => 'hosts',         'data' => \@hosts         },
              { 'name' => 'services',      'data' => \@services      },
        ];
        $c->stash->{'json'} = $json;
        $c->forward('Thruk::View::JSON');
        return;
    }

    # which host to display?
    my($hostfilter,$servicefilter, $groupfilter) = $self->_do_filter($c);
    return if defined $c->stash->{'has_error'};

    my($limit,$limitstr) = (undef,'');
    if(defined $c->{'request'}->{'parameters'}->{'limit'}) {
        $limitstr = "Limit: ".$c->{'request'}->{'parameters'}->{'limit'}."\n";
        $limit    = $c->{'request'}->{'parameters'}->{'limit'};
    }

    my @columns = qw/comments
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
    if(defined $c->{'request'}->{'parameters'}->{'column'}) {
        if(ref $c->{'request'}->{'parameters'}->{'column'} eq 'ARRAY') {
            @columns = @{$c->{'request'}->{'parameters'}->{'column'}};
        }
        else {
            @columns = ( $c->{'request'}->{'parameters'}->{'column'} );
        }
    }

    my $hosts = $c->{'live'}->selectall_arrayref("GET hosts\n".$limitstr.Thruk::Utils::Auth::get_auth_filter($c, 'hosts')."\n$hostfilter\nColumns: ".join(' ', @columns), { Slice => {} });
    if(defined $limit and scalar @{$hosts} > $limit) { @{$hosts} = @{$hosts}[0..$limit]; }
    $c->stash->{'json'} = $hosts;
    $c->forward('Thruk::View::JSON');

    return 1;
}


##########################################################
# check for search results
sub _process_search_request {
    my ( $self, $c ) = @_;

    # search pattern is in host param
    my $host = $c->{'request'}->{'parameters'}->{'host'};
    $c->{'request'}->{'parameters'}->{'hidesearch'} = 2; # force show search

    return('detail') unless defined $host;

    # is there a servicegroup with this name?
    my $servicegroups = $c->{'live'}->selectall_arrayref("GET servicegroups\n".Thruk::Utils::Auth::get_auth_filter($c, 'servicegroups')."\nColumns: name\nFilter: name = $host");
    if(scalar @{$servicegroups} > 0) {
        delete $c->{'request'}->{'parameters'}->{'host'};
        $c->{'request'}->{'parameters'}->{'servicegroup'} = $host;
        return('overview');
    }

    # is there a hostgroup with this name?
    my $hostgroups = $c->{'live'}->selectall_arrayref("GET hostgroups\n".Thruk::Utils::Auth::get_auth_filter($c, 'hostgroups')."\nColumns: name\nFilter: name = $host");
    if(scalar @{$hostgroups} > 0) {
        delete $c->{'request'}->{'parameters'}->{'host'};
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
    my($hostfilter,$servicefilter, $groupfilter) = $self->_do_filter($c);
    return if defined $c->stash->{'has_error'};

    # add comments and downtimes
    my $comments  = $c->{'live'}->selectall_arrayref("GET comments\n".Thruk::Utils::Auth::get_auth_filter($c, 'comments')."\nColumns: host_name service_description source type author comment entry_time entry_type expire_time", { Slice => {} });
    my $downtimes = $c->{'live'}->selectall_arrayref("GET downtimes\n".Thruk::Utils::Auth::get_auth_filter($c, 'downtimes')."\nColumns: service_description author comment end_time entry_time fixed host_name id start_time", { Slice => {} });
    my $downtimes_by_host;
    my $downtimes_by_host_service;
    if($downtimes) {
        for my $downtime (@{$downtimes}) {
            if(defined $downtime->{'service_description'} and $downtime->{'service_description'} ne '') {
                push @{$downtimes_by_host_service->{$downtime->{'host_name'}}->{$downtime->{'service_description'}}}, $downtime;
            } else {
                push @{$downtimes_by_host->{$downtime->{'host_name'}}}, $downtime;
            }
        }
    }
    $c->stash->{'downtimes_by_host'}         = $downtimes_by_host;
    $c->stash->{'downtimes_by_host_service'} = $downtimes_by_host_service;
    my $comments_by_host;
    my $comments_by_host_service;
    if($comments) {
        for my $comment (@{$comments}) {
            if(defined $comment->{'service_description'} and $comment->{'service_description'} ne '') {
                push @{$comments_by_host_service->{$comment->{'host_name'}}->{$comment->{'service_description'}}}, $comment;
            } else {
                push @{$comments_by_host->{$comment->{'host_name'}}}, $comment;
            }
        }
    }
    $c->stash->{'comments_by_host'}         = $comments_by_host;
    $c->stash->{'comments_by_host_service'} = $comments_by_host_service;

    # get all services
    my $services = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Utils::Auth::get_auth_filter($c, 'services')."\n$servicefilter\nColumns: host_name host_state host_address host_acknowledged host_notifications_enabled host_active_checks_enabled host_is_flapping host_scheduled_downtime_depth host_is_executing host_notes_url_expanded host_action_url_expanded host_icon_image_expanded host_icon_image_alt host_comments has_been_checked state description acknowledged comments notifications_enabled active_checks_enabled accept_passive_checks is_flapping scheduled_downtime_depth is_executing notes_url_expanded action_url_expanded icon_image_expanded icon_image_alt last_check last_state_change current_attempt max_check_attempts next_check plugin_output long_plugin_output", { Slice => {}, AddPeer => 1 });

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
    my $sortedservices = Thruk::Utils::sort($c, $services, $sortoptions->{$sortoption}->[0], $order);
    if($sortoption == 6 and defined $sortedservices) { @{$sortedservices} = reverse @{$sortedservices}; }

    my $view_mode = $c->{'request'}->{'parameters'}->{'view_mode'} || 'html';
    if(defined $view_mode and $view_mode eq 'xls') {
        my $filename = 'status.xls';
        $c->res->header('Content-Disposition', qq[attachment; filename="]. $filename .q["]);
        $c->stash->{'data'}     = $sortedservices;
        $c->stash->{'template'} = 'excel/status_detail.tt';
        $c->detach('View::Excel');
        return 1;
    }

    Thruk::Utils::page_data($c, $sortedservices);

    $c->stash->{'orderby'}       = $sortoptions->{$sortoption}->[1];
    $c->stash->{'orderdir'}      = $order;
    $c->stash->{'style'}         = 'detail';

    return 1;
}

##########################################################
# create the hostdetails page
sub _process_hostdetails_page {
    my ( $self, $c ) = @_;

    # which host to display?
    my($hostfilter,$servicefilter, $groupfilter) = $self->_do_filter($c);
    return if defined $c->stash->{'has_error'};

    # add comments and downtimes
    my $comments  = $c->{'backend'}->get_comments('columns' => [qw/host_name source type author comment entry_time entry_type expire_time/],
                                                  'filter'  => [ Thruk::Utils::Auth::get_auth_filter($c, 'comments'), { 'service_description' => undef } ]
                                                 );
    my $downtimes = $c->{'backend'}->get_downtimes('columns' => [qw/author comment end_time entry_time fixed host_name id start_time/],
                                                  'filter'  => [ Thruk::Utils::Auth::get_auth_filter($c, 'downtimes'), { 'service_description' => undef } ]
                                                 );
    my $downtimes_by_host;
    if($downtimes) {
        for my $downtime (@{$downtimes}) {
            push @{$downtimes_by_host->{$downtime->{'host_name'}}}, $downtime;
        }
    }
    $c->stash->{'downtimes_by_host'} = $downtimes_by_host;
    my $comments_by_host;
    if($comments) {
        for my $comment (@{$comments}) {
            push @{$comments_by_host->{$comment->{'host_name'}}}, $comment;
        }
    }
    $c->stash->{'comments_by_host'} = $comments_by_host;

    # add comments into hosts.comments and hosts.comment_count
    my $hosts = $c->{'live'}->selectall_arrayref("GET hosts\n".Thruk::Utils::Auth::get_auth_filter($c, 'hosts')."\n$hostfilter\nColumns: comments has_been_checked state name address acknowledged notifications_enabled active_checks_enabled is_flapping scheduled_downtime_depth is_executing notes_url_expanded action_url_expanded icon_image_expanded icon_image_alt last_check last_state_change plugin_output next_check long_plugin_output", { Slice => {}, AddPeer => 1 });
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
    my $sortedhosts = Thruk::Utils::sort($c, $hosts, $sortoptions->{$sortoption}->[0], $order);
    if($sortoption == 6 and defined $sortedhosts) { @{$sortedhosts} = reverse @{$sortedhosts}; }

    my $view_mode = $c->{'request'}->{'parameters'}->{'view_mode'} || 'html';
    if(defined $view_mode and $view_mode eq 'xls') {
        my $filename = 'status.xls';
        $c->res->header('Content-Disposition', qq[attachment; filename="]. $filename .q["]);
        $c->stash->{'data'}     = $sortedhosts;
        $c->stash->{'template'} = 'excel/status_hostdetail.tt';
        $c->detach('View::Excel');
        return 1;
    }

    Thruk::Utils::page_data($c, $sortedhosts);

    $c->stash->{'orderby'}  = $sortoptions->{$sortoption}->[1];
    $c->stash->{'orderdir'} = $order;
    $c->stash->{'style'}    = 'hostdetail';

    return 1;
}

##########################################################
# create the status details page
sub _process_overview_page {
    my ( $self, $c ) = @_;

    # which host to display?
    my($hostfilter,$servicefilter, $hostgroupfilter, $servicegroupfilter) = $self->_do_filter($c);
    return if defined $c->stash->{'has_error'};

    # we need the hostname, address etc...
    my $host_data;
    my $services_data;
    if($hostgroupfilter ne '') {
        $host_data = $c->{'live'}->selectall_hashref("GET hosts\n".Thruk::Utils::Auth::get_auth_filter($c, 'hosts')."\nColumns: name address state has_been_checked notes_url_expanded action_url_expanded icon_image_expanded icon_image_alt num_services_ok as ok num_services_unknown as unknown num_services_warn as warning num_services_crit as critical num_services_pending as pending\n$hostfilter", 'name' );
    }
    elsif($servicegroupfilter ne '') {
        $host_data = $c->{'live'}->selectall_hashref("GET hosts\n".Thruk::Utils::Auth::get_auth_filter($c, 'hosts')."\nColumns: name address state has_been_checked notes_url_expanded action_url_expanded icon_image_expanded icon_image_alt\n$hostfilter", 'name' );

        # we have to sort in all services and states
        my $tmp_services = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Utils::Auth::get_auth_filter($c, 'services')."\nColumns: has_been_checked state description host_name", { Slice => {} });
        if(defined $tmp_services) {
            for my $service (@{$tmp_services}) {
                next if $service->{'description'} eq '';
                $services_data->{$service->{'host_name'}}->{$service->{'description'}} = $service;
            }
        }
    }

    # get all host/service groups
    my $groups;
    if($hostgroupfilter ne '') {
        $groups = $c->{'live'}->selectall_arrayref("GET hostgroups\n".Thruk::Utils::Auth::get_auth_filter($c, 'hostgroups')."\n$hostgroupfilter\nColumns: name alias members", { Slice => {} });
    }
    elsif($servicegroupfilter ne '') {
        $groups = $c->{'live'}->selectall_arrayref("GET servicegroups\n".Thruk::Utils::Auth::get_auth_filter($c, 'servicegroups')."\n$servicegroupfilter\nColumns: name alias members", { Slice => {} });
    }

    # join our groups together
    my %joined_groups;
    for my $group (@{$groups}) {

        next unless defined $group->{'members'};

        my $name = $group->{'name'};
        if(!defined $joined_groups{$name}) {
            $joined_groups{$name}->{'name'}  = $group->{'name'};
            $joined_groups{$name}->{'alias'} = $group->{'alias'};
            $joined_groups{$name}->{'hosts'} = {};
        }

        my($hostname,$servicename);
        if($hostgroupfilter ne '' and defined $group->{'members'}) {
            for my $hostname (split /,/mx, $group->{'members'}) {
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
        elsif($servicegroupfilter ne '') {
            for my $member (split /,/mx, $group->{'members'}) {
                my($hostname,$servicename) = split/\|/mx, $member, 2;
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

    $c->stash->{'groups'}       = \%joined_groups;
    $c->stash->{'style'}        = 'overview';

    return 1;
}


##########################################################
# create the status grid page
sub _process_grid_page {
    my ( $self, $c ) = @_;

    # which host to display?
    my($hostfilter,$servicefilter, $hostgroupfilter, $servicegroupfilter) = $self->_do_filter($c);
    return if defined $c->stash->{'has_error'};

    # we need the hostname, address etc...
    my $host_data = $c->{'live'}->selectall_hashref("GET hosts\n".Thruk::Utils::Auth::get_auth_filter($c, 'hosts')."\nColumns: name address state has_been_checked notes_url_expanded action_url_expanded icon_image_expanded icon_image_alt\n$hostfilter", 'name' );

    # create a hash of all services
    my $services_data;
    my $tmp_services = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Utils::Auth::get_auth_filter($c, 'services')."\nColumns: has_been_checked state description host_name\n$servicefilter", { Slice => {} });
    if(defined $tmp_services) {
        for my $service (@{$tmp_services}) {
            $services_data->{$service->{'host_name'}}->{$service->{'description'}} = $service;
        }
    }

    # get all host/service groups
    my $groups;
    if($hostgroupfilter ne '') {
        $groups = $c->{'live'}->selectall_arrayref("GET hostgroups\n".Thruk::Utils::Auth::get_auth_filter($c, 'hostgroups')."\n$hostgroupfilter\nColumns: name alias members", { Slice => {} });
    }
    elsif($servicegroupfilter ne '') {
        $groups = $c->{'live'}->selectall_arrayref("GET servicegroups\n".Thruk::Utils::Auth::get_auth_filter($c, 'servicegroups')."\n$servicegroupfilter\nColumns: name alias members", { Slice => {} });
    }

    # sort in hosts / services
    my %joined_groups;
    for my $group (@{$groups}) {

        # only need groups with members
        next unless $group->{'members'};

        my $name = $group->{'name'};
        if(!defined $joined_groups{$name}) {
            $joined_groups{$name}->{'name'}  = $group->{'name'};
            $joined_groups{$name}->{'alias'} = $group->{'alias'};
            $joined_groups{$name}->{'hosts'} = {};
        }

        for my $member (split /,/mx, $group->{'members'}) {
            my($hostname,$servicename);
            if($hostgroupfilter ne '') {
                $hostname = $member;
            }
            if($servicegroupfilter ne '') {
                ($hostname,$servicename) = split/\|/mx, $member, 2;
            }

            next unless defined $host_data->{$hostname};

            if(!defined $joined_groups{$name}->{'hosts'}->{$hostname}) {
                # clone host data
                for my $key (keys %{$host_data->{$hostname}}) {
                    $joined_groups{$name}->{'hosts'}->{$hostname}->{$key} = $host_data->{$hostname}->{$key};
                }
            }

            # add all services
            if($hostgroupfilter ne '') {
                for my $service (sort keys %{$services_data->{$hostname}}) {
                     $joined_groups{$name}->{'hosts'}->{$hostname}->{'services'}->{$services_data->{$hostname}->{$service}->{'description'}} = $services_data->{$hostname}->{$service};
                }
            }
            elsif($servicegroupfilter ne '') {
                $joined_groups{$name}->{'hosts'}->{$hostname}->{'services'}->{$services_data->{$hostname}->{$servicename}->{'description'}} = $services_data->{$hostname}->{$servicename};
            }
        }

        # remove empty groups
        if(scalar keys %{$joined_groups{$name}->{'hosts'}} == 0) {
            delete $joined_groups{$name};
        }
    }

    $c->stash->{'groups'}       = \%joined_groups;
    $c->stash->{'style'}        = 'grid';

    return 1;
}


##########################################################
# create the status summary page
sub _process_summary_page {
    my ( $self, $c ) = @_;

    # which host to display?
    my($hostfilter,$servicefilter, $hostgroupfilter, $servicegroupfilter) = $self->_do_filter($c);
    return if defined $c->stash->{'has_error'};

    # get all host/service groups
    my $groups;
    if($hostgroupfilter ne '') {
        $groups = $c->{'live'}->selectall_hashref("GET hostgroups\n".Thruk::Utils::Auth::get_auth_filter($c, 'hostgroups')."\n$hostgroupfilter\nColumns: name alias members", 'name');
    }
    elsif($servicegroupfilter ne '') {
        $groups = $c->{'live'}->selectall_hashref("GET servicegroups\n".Thruk::Utils::Auth::get_auth_filter($c, 'servicegroups')."\n$servicegroupfilter\nColumns: name alias members", 'name');
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
    if($hostgroupfilter ne '') {
        # we need the hosts data
        my $host_data = $c->{'live'}->selectall_arrayref("GET hosts\n".Thruk::Utils::Auth::get_auth_filter($c, 'hosts')."\nColumns: name groups state checks_enabled acknowledged scheduled_downtime_depth has_been_checked\n$hostfilter", { Slice => 1 } );

        # create a hash of all services
        $services_data = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Utils::Auth::get_auth_filter($c, 'services')."\nColumns: has_been_checked state host_name host_state groups host_groups checks_enabled acknowledged scheduled_downtime_depth\n$servicefilter", { Slice => {} });

        for my $host (@{$host_data}) {
            for my $group (split/,/mx, $host->{'groups'}) {
                next if !defined $groups->{$group};
                $self->_summary_add_host_stats("", $groups->{$group}, $host);
            }
        }
    }

    if($servicegroupfilter ne '') {
        # create a hash of all services
        $services_data = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Utils::Auth::get_auth_filter($c, 'services')."\nColumns: has_been_checked state host_name host_state groups host_groups checks_enabled acknowledged scheduled_downtime_depth host_name host_state host_checks_enabled host_acknowledged host_scheduled_downtime_depth host_has_been_checked\n$servicefilter", { Slice => {} });

        $groupsname = "groups";
    }

    my %host_already_added;
    for my $service (@{$services_data}) {
        for my $group (split/,/mx, $service->{$groupsname}) {
            next if !defined $groups->{$group};

            if($servicegroupfilter ne '') {
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

    $c->stash->{'groups'}       = $groups;
    $c->stash->{'style'}        = 'summary';

    return 1;
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

    return 1;
}

##########################################################
sub _fill_totals_box {
    my ( $self, $c, $hostfilter, $servicefilter ) = @_;
    # host status box
    my $host_stats = $c->{'live'}->selectrow_hashref("GET hosts\n".Thruk::Utils::Auth::get_auth_filter($c, 'hosts')."
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
    my $service_stats = $c->{'live'}->selectrow_hashref("GET services\n".Thruk::Utils::Auth::get_auth_filter($c, 'services')."
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

    return 1;
}

##########################################################
sub _extend_filter {
    my ( $self, $c, $hostfilter, $servicefilter, $hoststatustypes, $hostprops, $servicestatustypes, $serviceprops ) = @_;

    my @hostfilter;
    my @servicefilter;

    push @hostfilter,    $hostfilter    if defined $hostfilter and $hostfilter ne '';
    push @servicefilter, $servicefilter if defined $servicefilter and $servicefilter ne '';

    # host statustype filter (up,down,...)
    my($host_statustype_filtername,$host_statustype_filter,$host_statustype_filter_service);
    ($hoststatustypes,$host_statustype_filtername,$host_statustype_filter,$host_statustype_filter_service)
            = $self->_get_host_statustype_filter($hoststatustypes);
    push @hostfilter,    $host_statustype_filter         if defined $host_statustype_filter and $host_statustype_filter ne '';
    push @servicefilter, $host_statustype_filter_service if defined $host_statustype_filter_service and $host_statustype_filter_service ne '';

    $c->stash->{'show_filter_table'}          = 1 if $host_statustype_filter ne '';

    # host props filter (downtime, acknowledged...)
    my($host_prop_filtername,$host_prop_filter,$host_prop_filter_service);
    ($hostprops,$host_prop_filtername,$host_prop_filter,$host_prop_filter_service) = $self->_get_host_prop_filter($hostprops);
    push @hostfilter,    $host_prop_filter         if defined $host_prop_filter and $host_prop_filter ne '';
    push @servicefilter, $host_prop_filter_service if defined $host_prop_filter_service and $host_prop_filter_service ne '';

    $c->stash->{'show_filter_table'}    = 1 if $host_prop_filter ne '';


    # service statustype filter (ok,warning,...)
    my($service_statustype_filtername,$service_statustype_filter_service);
    ($servicestatustypes,$service_statustype_filtername,$service_statustype_filter_service)
            = $self->_get_service_statustype_filter($servicestatustypes);
    push @servicefilter, $service_statustype_filter_service if defined $service_statustype_filter_service and $service_statustype_filter_service ne '';

    $c->stash->{'show_filter_table'}             = 1 if $service_statustype_filter_service ne '';

    # service props filter (downtime, acknowledged...)
    my($service_prop_filtername,$service_prop_filter_service);
    ($serviceprops,$service_prop_filtername,$service_prop_filter_service) = $self->_get_service_prop_filter($serviceprops);
    push @servicefilter, $service_prop_filter_service if defined $service_prop_filter_service and $service_prop_filter_service ne '';

    $c->stash->{'show_filter_table'}       = 1 if $service_prop_filter_service ne '';

    $hostfilter    = Thruk::Utils::combine_filter(\@hostfilter,    'And');
    $servicefilter = Thruk::Utils::combine_filter(\@servicefilter, 'And');

    return($hostfilter,
           $servicefilter,
           $host_statustype_filtername,
           $host_prop_filtername,
           $service_statustype_filtername,
           $service_prop_filtername,
           $hoststatustypes,
           $hostprops,
           $servicestatustypes,
           $serviceprops
          );
}

##########################################################
sub _get_host_statustype_filter {
    my ( $self, $number ) = @_;

    $number = 15 if !defined $number or $number !~ m/^\d+$/mx or $number <= 0 or $number > 15;
    my $hoststatusfiltername = 'All';
    my $hostfilter           = '';
    my $servicefilter        = '';
    if($number and $number != 15) {
        my @hoststatusfilter;
        my @servicestatusfilter;
        my @hoststatusfiltername;
        my @bits = reverse split(/\ */mx, unpack("B*", pack("n", int($number))));

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
    return($number,$hoststatusfiltername,$hostfilter,$servicefilter);
}

##########################################################
sub _get_host_prop_filter {
    my ( $self, $number ) = @_;

    $number = 0 if !defined $number or $number !~ m/^\d+$/mx or $number <= 0 or $number > 1048575;
    my $host_prop_filtername = 'Any';
    my $hostfilter           = '';
    my $servicefilter        = '';
    if($number > 0) {
        my @host_prop_filter;
        my @host_prop_filter_service;
        my @host_prop_filtername;
        my @bits = reverse split(/\ */mx, unpack("B*", pack("N", int($number))));

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
            push @host_prop_filter,         "Filter: state_type = 1";
            push @host_prop_filter_service, "Filter: host_state_type = 1";
            push @host_prop_filtername,     'In Hard State';
        }
        if($bits[19]) {  # 524288 - In Soft State
            push @host_prop_filter,         "Filter: state_type = 0";
            push @host_prop_filter_service, "Filter: host_state_type = 0";
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
    return($number,$host_prop_filtername,$hostfilter,$servicefilter);
}

##########################################################
sub _get_service_statustype_filter {
    my ( $self, $number ) = @_;

    $number = 31 if !defined $number or $number !~ m/^\d+$/mx or $number <= 0 or $number > 31;
    my $servicestatusfiltername = 'All';
    my $servicefilter           = '';
    if($number and $number != 31) {
        my @servicestatusfilter;
        my @servicestatusfiltername;
        my @bits = reverse split(/\ */mx, unpack("B*", pack("n", int($number))));

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
    return($number,$servicestatusfiltername,$servicefilter);
}

##########################################################
sub _get_service_prop_filter {
    my ( $self, $number ) = @_;

    $number = 0 if !defined $number or $number !~ m/^\d+$/mx or $number <= 0 or $number > 1048575;
    my $service_prop_filtername = 'Any';
    my $servicefilter           = '';
    if($number > 0) {
        my @service_prop_filter;
        my @service_prop_filtername;
        my @bits = reverse split(/\ */mx, unpack("B*", pack("N", int($number))));

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
    return($number,$service_prop_filtername,$servicefilter);
}


##########################################################
sub _do_filter {
    my ( $self, $c ) = @_;

    my $hostfilter         = "";
    my $servicefilter      = "";
    my $hostgroupfilter;
    my $servicegroupfilter;
    my $searches           = [];

    unless(   exists $c->{'request'}->{'parameters'}->{'s0_hoststatustypes'}
           or exists $c->{'request'}->{'parameters'}->{'s0_type'}
           ) {
        # classic search
        my $search;
        ($search,
         $hostfilter,
         $servicefilter,
         $hostgroupfilter,
         $servicegroupfilter)
            = $self->_classic_filter($c);

        # convert that into a new search
        push @{$searches}, $search;
    } else {
        # complex filter search?
        push @{$searches}, $self->_get_search_from_param($c, 's0', 1);
        for(my $x = 1; $x <= 99; $x++) {
            my $search = $self->_get_search_from_param($c, 's'.$x);
            push @{$searches}, $search if defined $search;
        }
        ($searches,
         $hostfilter,
         $servicefilter,
         $hostgroupfilter,
         $servicegroupfilter)
            = $self->_do_search($c, $searches);
    }

    $c->stash->{'searches'} = $searches;

    #$c->log->debug("hostfilter: $hostfilter");
    #$c->log->debug("servicefilter: $servicefilter");
    #$c->log->debug("hostgroupfilter: $hostgroupfilter");
    #$c->log->debug("servicegroupfilter: $servicegroupfilter");

    return($hostfilter,$servicefilter,$hostgroupfilter,$servicegroupfilter);
}


##########################################################
sub _classic_filter {
    my ( $self, $c ) = @_;

    my $hostfilter         = [];
    my $servicefilter      = [];
    my $hostgroupfilter    = [];
    my $servicegroupfilter = [];
    my $errors             = 0;

    # classic search
    my $host          = $c->{'request'}->{'parameters'}->{'host'}         || '';
    my $hostgroup     = $c->{'request'}->{'parameters'}->{'hostgroup'}    || '';
    my $servicegroup  = $c->{'request'}->{'parameters'}->{'servicegroup'} || '';

    $c->stash->{'host'}          = $host;
    $c->stash->{'hostgroup'}     = $hostgroup;
    $c->stash->{'servicegroup'}  = $servicegroup;

    if($host ne 'all' and $host ne '') {
        $hostfilter    = [{ 'name'      => $host }];
        $servicefilter = [{ 'host_name' => $host }];

        # check for wildcards
        if(CORE::index($host, '*') >= 0) {
            # convert wildcards into real regexp
            my $searchhost = $host;
            $searchhost =~ s/\.\*/*/gmx;
            $searchhost =~ s/\*/.*/gmx;
            $errors++ unless Thruk::Utils::is_valid_regular_expression($c, $searchhost);
            $hostfilter    = [{ 'name'      => { '~~' => $searchhost }}];
            $servicefilter = [{ 'host_name' => { '~~' => $searchhost }}];
        }
    }
    elsif($hostgroup ne 'all' and $hostgroup ne '') {
        $hostfilter      = [{ 'groups'      => { '>=' => $hostgroup }}];
        $servicefilter   = [{ 'host_groups' => { '>=' => $hostgroup }}];
        $hostgroupfilter = [{ 'name'        => $hostgroup }];
    }
    elsif($hostgroup eq 'all') {
    }
    elsif($servicegroup ne 'all' and $servicegroup ne '') {
        $servicefilter      = [{ 'groups'   => { '>=' => $servicegroup }}];
        $servicegroupfilter = [{ 'name'     => $servicegroup }];
    }
    elsif($servicegroup eq 'all') {
    }

    # fill the host/service totals box
    $self->_fill_totals_box($c, $hostfilter, $servicefilter);

    # then add some more filter based on get parameter
    my $hoststatustypes    = $c->{'request'}->{'parameters'}->{'hoststatustypes'};
    my $hostprops          = $c->{'request'}->{'parameters'}->{'hostprops'};
    my $servicestatustypes = $c->{'request'}->{'parameters'}->{'servicestatustypes'};
    my $serviceprops       = $c->{'request'}->{'parameters'}->{'serviceprops'};

    my($host_statustype_filtername,$host_prop_filtername,$service_statustype_filtername,$service_prop_filtername);
    my($host_statustype_filtervalue,$host_prop_filtervalue,$service_statustype_filtervalue,$service_prop_filtervalue);
    ($hostfilter,
     $servicefilter,
     $host_statustype_filtername,
     $host_prop_filtername,
     $service_statustype_filtername,
     $service_prop_filtername,
     $host_statustype_filtervalue,
     $host_prop_filtervalue,
     $service_statustype_filtervalue,
     $service_prop_filtervalue
    )= $self->_extend_filter($c,
                                $hostfilter,
                                $servicefilter,
                                $hoststatustypes,
                                $hostprops,
                                $servicestatustypes,
                                $serviceprops);

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

    if($host ne '') {
        push @{$search->{'text_filter'}}, {
            'type'  => 'host',
            'value' => $host,
            'op'    => '=',
        };
    }
    elsif($hostgroup ne '') {
        push @{$search->{'text_filter'}}, {
            'type'  => 'hostgroup',
            'value' => $hostgroup,
            'op'    => '=',
        };
    }
    elsif($servicegroup ne '') {
        push @{$search->{'text_filter'}}, {
            'type'  => 'servicegroup',
            'value' => $servicegroup,
            'op'    => '=',
        };
    }

    if($errors) {
        $c->stash->{'has_error'} = 1;
    }

    return($search,$hostfilter,$servicefilter,$hostgroupfilter,$servicegroupfilter);
}

##########################################################
sub _get_search_from_param {
    my ( $self, $c, $prefix, $force ) = @_;

    unless($force || exists $c->{'request'}->{'parameters'}->{$prefix.'_hoststatustypes'}) {
        return;
    }

    # use the type or prop without prefix as global overide
    # ex.: hoststatustypes set from the totals link should override all filter
    my $search = {
        'hoststatustypes'    => $c->stash->{'hoststatustypes'}    || $c->{'request'}->{'parameters'}->{$prefix.'_hoststatustypes'},
        'hostprops'          => $c->stash->{'hostprops'}          || $c->{'request'}->{'parameters'}->{$prefix.'_hostprops'},
        'servicestatustypes' => $c->stash->{'servicestatustypes'} || $c->{'request'}->{'parameters'}->{$prefix.'_servicestatustypes'},
        'serviceprops'       => $c->stash->{'serviceprops'}       || $c->{'request'}->{'parameters'}->{$prefix.'_serviceprops'},
    };

    return $search unless defined $c->{'request'}->{'parameters'}->{$prefix.'_type'};

    if(ref $c->{'request'}->{'parameters'}->{$prefix.'_type'} eq 'ARRAY') {
        for(my $x = 0; $x < scalar @{$c->{'request'}->{'parameters'}->{$prefix.'_type'}}; $x++) {
            my $text_filter = {
                type  => $c->{'request'}->{'parameters'}->{$prefix.'_type'}->[$x],
                value => $c->{'request'}->{'parameters'}->{$prefix.'_value'}->[$x],
                op    => $c->{'request'}->{'parameters'}->{$prefix.'_op'}->[$x],
            };
            push @{$search->{'text_filter'}}, $text_filter;
        }
    }
    else {
        my $text_filter = {
            type  => $c->{'request'}->{'parameters'}->{$prefix.'_type'},
            value => $c->{'request'}->{'parameters'}->{$prefix.'_value'},
            op    => $c->{'request'}->{'parameters'}->{$prefix.'_op'},
        };
        push @{$search->{'text_filter'}}, $text_filter;
    }

    return $search;
}

##########################################################
sub _do_search {
    my ( $self, $c, $searches ) = @_;

    my(@hostfilter,@servicefilter,@hostgroupfilter,@servicegroupfilter,@hosttotalsfilter,@servicetotalsfilter);

    for my $search (@{$searches}) {
        my($tmp_hostfilter, $tmp_servicefilter,$tmp_hostgroupfilter,$tmp_servicegroupfilter, $tmp_hosttotalsfilter, $tmp_servicetotalsfilter)
            = $self->_single_search($c, $search);
        push @hostfilter,          $tmp_hostfilter;
        push @servicefilter,       $tmp_servicefilter;
        push @hostgroupfilter,     $tmp_hostgroupfilter;
        push @servicegroupfilter,  $tmp_servicegroupfilter;
        push @servicetotalsfilter, $tmp_servicetotalsfilter;
        push @hosttotalsfilter,    $tmp_hosttotalsfilter;
    }

    # combine the array of filters by OR
    my $hostfilter          = Thruk::Utils::combine_filter(\@hostfilter,          'Or');
    my $servicefilter       = Thruk::Utils::combine_filter(\@servicefilter,       'Or');
    my $hostgroupfilter     = Thruk::Utils::combine_filter(\@hostgroupfilter,     'Or');
    my $servicegroupfilter  = Thruk::Utils::combine_filter(\@servicegroupfilter,  'Or');
    my $hosttotalsfilter    = Thruk::Utils::combine_filter(\@hosttotalsfilter,    'Or');
    my $servicetotalsfilter = Thruk::Utils::combine_filter(\@servicetotalsfilter, 'Or');

    # fill the host/service totals box
    $self->_fill_totals_box($c, $hosttotalsfilter, $servicetotalsfilter);

    # if there is only one search with a single text filter
    # set stash to reflect a classic search
    if(    scalar @{$searches} == 1
       and scalar @{$searches->[0]->{'text_filter'}} == 1
       and $searches->[0]->{'text_filter'}->[0]->{'op'} eq '='
      ) {
        my $type  = $searches->[0]->{'text_filter'}->[0]->{'type'};
        my $value = $searches->[0]->{'text_filter'}->[0]->{'value'};
        if($type eq 'host') {
            $c->stash->{'host'}         = $value;
        }
        elsif($type eq 'hostgroup') {
            $c->stash->{'hostgroup'}    = $value;
        }
        elsif($type eq 'servicegroup') {
            $c->stash->{'servicegroup'} = $value;
        }
    }

    return($searches, $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter);
}

##########################################################
sub _single_search {
    my ( $self, $c, $search ) = @_;

    my $errors = 0;
    my(@hostfilter,@servicefilter,@hostgroupfilter,@servicegroupfilter,@hosttotalsfilter,@servicetotalsfilter);

    my($tmp_hostfilter,
       $tmp_servicefilter,
       $host_statustype_filtername,
       $host_prop_filtername,
       $service_statustype_filtername,
       $service_prop_filtername,
       $host_statustype_filtervalue,
       $host_prop_filtervalue,
       $service_statustype_filtervalue,
       $service_prop_filtervalue
      ) = $self->_extend_filter($c,
                                undef,
                                undef,
                                $search->{'hoststatustypes'},
                                $search->{'hostprops'},
                                $search->{'servicestatustypes'},
                                $search->{'serviceprops'});

    $search->{'host_statustype_filtername'}    = $host_statustype_filtername;
    $search->{'host_prop_filtername'}          = $host_prop_filtername;
    $search->{'service_statustype_filtername'} = $service_statustype_filtername;
    $search->{'service_prop_filtername'}       = $service_prop_filtername;

    $search->{'hoststatustypes'}               = $host_statustype_filtervalue;
    $search->{'hostprops'}                     = $host_prop_filtervalue;
    $search->{'servicestatustypes'}            = $service_statustype_filtervalue;
    $search->{'serviceprops'}                  = $service_prop_filtervalue;

    push @hostfilter,    $tmp_hostfilter    if $tmp_hostfilter    ne '';
    push @servicefilter, $tmp_servicefilter if $tmp_servicefilter ne '';

    # do the text filter
    foreach my $filter (@{$search->{'text_filter'}}) {
        my $value = $filter->{'value'};
        my $op     = '=';
        my $listop = '>=';
        my $dateop = '=';
        my $joinop = "Or";
        if($filter->{'op'} eq '!~') { $op = '!~~'; $joinop = "And"; $listop = '!>='; }
        if($filter->{'op'} eq '~')  { $op = '~~';  }
        if($filter->{'op'} eq '!=') { $op = '!=';  $joinop = "And"; $listop = '!>='; $dateop = '!='; }
        if($filter->{'op'} eq '>=') { $dateop = '>='; }
        if($filter->{'op'} eq '<=') { $dateop = '<='; }

        if($op eq '!~~' or $op eq '~~') {
            $errors++ unless Thruk::Utils::is_valid_regular_expression($c, $value);
        }

        if($op eq '=' and $value eq 'all') {
            # add a useless filter
            if($filter->{'type'} eq 'host') {
                push @hostfilter, "Filter: name !=\n";
            }
            elsif($filter->{'type'} eq 'hostgroup') {
                push @hostgroupfilter, "Filter: name !=";
            }
            elsif($filter->{'type'} ne 'servicegroup') {
                push @servicegroupfilter, "Filter: name !=";
            }
            else {
                next;
            }
        }
        elsif($filter->{'type'} eq 'search') {
            my $host_search_filter = [
                "Filter: name $op $value",
                "Filter: alias $op $value",
                "Filter: groups $listop $value",
                "Filter: plugin_output $op $value",
                "Filter: long_plugin_output $op $value"
            ];
            push @hostfilter,       Thruk::Utils::combine_filter($host_search_filter, $joinop);
            push @hosttotalsfilter, Thruk::Utils::combine_filter($host_search_filter, $joinop);

            # and some for services
            my $service_search_filter = [
                "Filter: description $op $value",
                "Filter: groups $listop $value",
                "Filter: plugin_output $op $value",
                "Filter: long_plugin_output $op $value",
                "Filter: host_name $op $value",
                "Filter: host_alias $op $value",
                "Filter: host_groups $listop $value",
            ];
            push @servicefilter,       Thruk::Utils::combine_filter($service_search_filter, $joinop);
            push @servicetotalsfilter, Thruk::Utils::combine_filter($service_search_filter, $joinop);
        }
        elsif($filter->{'type'} eq 'host') {
            # check for wildcards
            if(CORE::index($value, '*') >= 0 and $op eq '=') {
                # convert wildcards into real regexp
                my $searchhost = $value;
                $searchhost =~ s/\.\*/*/gmx;
                $searchhost =~ s/\*/.*/gmx;
                push @hostfilter,          "Filter: name ~~ $searchhost\nFilter: alias ~~ $searchhost\nOr: 2";
                push @hosttotalsfilter,    "Filter: name ~~ $searchhost\nFilter: alias ~~ $searchhost\nOr: 2";
                push @servicefilter,       "Filter: host_name ~~ $searchhost\nFilter: host_alias ~~ $searchhost\nOr: 2";
                push @servicetotalsfilter, "Filter: host_name ~~ $searchhost\nFilter: host_alias ~~ $searchhost\nOr: 2";
            } else {
                push @hostfilter,          "Filter: name $op $value\nFilter: alias $op $value\n$joinop: 2";
                push @hosttotalsfilter,    "Filter: name $op $value\nFilter: alias $op $value\n$joinop: 2";
                push @servicefilter,       "Filter: host_name $op $value\nFilter: host_alias $op $value\n$joinop: 2";
                push @servicetotalsfilter, "Filter: host_name $op $value\nFilter: host_alias $op $value\n$joinop: 2";
            }
        }
        elsif($filter->{'type'} eq 'service') {
            push @servicefilter,       "Filter: description $op $value";
            push @servicetotalsfilter, "Filter: description $op $value";
        }
        elsif($filter->{'type'} eq 'hostgroup') {
            push @hostfilter,          "Filter: groups $listop $value";
            push @hosttotalsfilter,    "Filter: groups $listop $value";
            push @servicefilter,       "Filter: host_groups $listop $value";
            push @servicetotalsfilter, "Filter: host_groups $listop $value";
            push @hostgroupfilter,     "Filter: name $op $value";
        }
        elsif($filter->{'type'} eq 'servicegroup') {
            push @servicefilter,       "Filter: groups $listop $value";
            push @servicetotalsfilter, "Filter: groups $listop $value";
            push @servicegroupfilter,  "Filter: name $op $value";
        }
        elsif($filter->{'type'} eq 'contact') {
            push @servicefilter,       "Filter: contacts $listop $value";
            push @hostfilter,          "Filter: contacts $listop $value";
            push @servicetotalsfilter, "Filter: contacts $listop $value";
        }
        elsif($filter->{'type'} eq 'next check') {
            my $date = Thruk::Utils::parse_date($c, $value);
            if($date) {
                push @hostfilter,      "Filter: next_check $dateop $date";
                push @servicefilter,   "Filter: next_check $dateop $date";
            }
        }
        elsif($filter->{'type'} eq 'last check') {
            my $date = Thruk::Utils::parse_date($c, $value);
            if($date) {
                push @hostfilter,      "Filter: last_check $dateop $date";
                push @servicefilter,   "Filter: last_check $dateop $date";
            }
        }
        elsif($filter->{'type'} eq 'parent') {
            push @hostfilter,          "Filter: parents $listop $value";
            push @hosttotalsfilter,    "Filter: parents $listop $value";
            push @servicefilter,       "Filter: host_parents $listop $value";
            push @servicetotalsfilter, "Filter: host_parents $listop $value";
        }
        else {
            confess("unknown filter: ".$filter->{'type'});
        }
    }

    # combine the array of filters by AND
    my $hostfilter          = Thruk::Utils::combine_filter(\@hostfilter,          'And');
    my $servicefilter       = Thruk::Utils::combine_filter(\@servicefilter,       'And');
    my $hostgroupfilter     = Thruk::Utils::combine_filter(\@hostgroupfilter,     'And');
    my $servicegroupfilter  = Thruk::Utils::combine_filter(\@servicegroupfilter,  'And');
    my $hosttotalsfilter    = Thruk::Utils::combine_filter(\@hosttotalsfilter,    'And');
    my $servicetotalsfilter = Thruk::Utils::combine_filter(\@servicetotalsfilter, 'And');

    # filter does not work when it is empty,
    # so add useless filter which matches everything
    ## no critic
    if($hostfilter         =~ m/^\s*$/) { $hostfilter         = "Filter: name !=";        }
    if($servicefilter      =~ m/^\s*$/) { $servicefilter      = "Filter: description !="; }
    if($hostgroupfilter    =~ m/^\s*$/) { $hostgroupfilter    = "Filter: name !=";        }
    if($servicegroupfilter =~ m/^\s*$/) { $servicegroupfilter = "Filter: name !=";        }
    ## use critic

    if($errors) {
        $c->stash->{'has_error'} = 1;
    }

    return($hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter, $hosttotalsfilter, $servicetotalsfilter);
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
