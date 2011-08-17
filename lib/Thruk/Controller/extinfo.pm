package Thruk::Controller::extinfo;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';
use Data::Page;

=head1 NAME

Thruk::Controller::extinfo - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

##########################################################
sub index : Path : Args(0) : MyAction('AddDefaults') {
    my( $self, $c ) = @_;
    my $type = $c->{'request'}->{'parameters'}->{'type'} || 0;

    my $infoBoxTitle;
    if( $type == 0 ) {
        $infoBoxTitle = 'Process Information';
        return $c->detach('/error/index/1') unless $c->check_user_roles("authorized_for_system_information");
        $self->_process_process_info_page($c);
    }
    if( $type == 1 ) {
        $infoBoxTitle = 'Host Information';
        $self->_process_host_page($c);
    }
    if( $type == 2 ) {
        $infoBoxTitle = 'Service Information';
        $self->_process_service_page($c);
    }
    if( $type == 3 ) {
        $infoBoxTitle = 'All Host and Service Comments';
        $self->_process_comments_page($c);
    }
    if( $type == 4 ) {
        $infoBoxTitle = 'Performance Information';
        $self->_process_perf_info_page($c);
    }
    if( $type == 5 ) {
        $infoBoxTitle = 'Hostgroup Information';
        $self->_process_hostgroup_cmd_page($c);
    }
    if( $type == 6 ) {
        $infoBoxTitle = 'All Host and Service Scheduled Downtime';
        $self->_process_downtimes_page($c);
    }
    if( $type == 7 ) {
        $infoBoxTitle = 'Check Scheduling Queue';
        $self->_process_scheduling_page($c);
    }
    if( $type == 8 ) {
        $infoBoxTitle = 'Servicegroup Information';
        $self->_process_servicegroup_cmd_page($c);
    }

    $c->stash->{title}        = 'Extended Information';
    $c->stash->{infoBoxTitle} = $infoBoxTitle;
    $c->stash->{page}         = 'extinfo';
    $c->stash->{template}     = 'extinfo_type_' . $type . '.tt';

    Thruk::Utils::ssi_include($c);

    return 1;
}

##########################################################
# SUBS
##########################################################

##########################################################
# create the downtimes page
sub _process_comments_page {
    my( $self, $c ) = @_;
    $c->stash->{'hostcomments'}    = $c->{'db'}->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'service_description' => undef } ] );
    $c->stash->{'servicecomments'} = $c->{'db'}->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'service_description' => { '!=' => undef } } ] );
    return 1;
}

##########################################################
# create the downtimes page
sub _process_downtimes_page {
    my( $self, $c ) = @_;
    $c->stash->{'hostdowntimes'}    = $c->{'db'}->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'service_description' => undef } ], sort => 'host_name' );
    $c->stash->{'servicedowntimes'} = $c->{'db'}->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'service_description' => { '!=' => undef } } ], sort => ['host_name', 'service_description'] );
    return 1;
}

##########################################################
# create the host info page
sub _process_host_page {
    my( $self, $c ) = @_;
    my $host;

    my $backend = $c->{'request'}->{'parameters'}->{'backend'} || '';
    my $hostname = $c->{'request'}->{'parameters'}->{'host'};
    return $c->detach('/error/index/5') unless defined $hostname;
    my $hosts = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), { 'name' => $hostname } ] );

    return $c->detach('/error/index/5') unless defined $hosts;

    # we only got one host
    $host = $hosts->[0];

    # we have more and backend param is used
    if( scalar @{$hosts} == 1 and defined $backend ) {
        for my $h ( @{$hosts} ) {
            if( $h->{'peer_key'} eq $backend ) {
                $host = $h;
                last;
            }
        }
    }

    return $c->detach('/error/index/5') unless defined $host;

    my @backends;
    for my $h ( @{$hosts} ) {
        push @backends, $h->{'peer_key'};
    }
    $self->_set_backend_selector( $c, \@backends, $host->{'peer_key'} );

    $c->stash->{'host'} = $host;
    my $comments = $c->{'db'}->get_comments(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'host_name' => $hostname }, { 'service_description' => undef } ],
        sort => { 'DESC' => 'id' } );
    my $downtimes = $c->{'db'}->get_downtimes(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'host_name' => $hostname }, { 'service_description' => undef } ],
        sort => { 'DESC' => 'id' } );


    # shinken only
    $c->stash->{'show_impacts_link'}      = 0;
    $c->stash->{'show_rootproblems_link'} = 0;

    if($c->stash->{'enable_shinken_features'}) {
        # show the impacts link for problem hosts
        if($host->{'is_problem'}) {
            $c->stash->{'show_impacts_link'}      = 1;
        }
        # show the root problems of this impact
        if($host->{'is_impact'}) {
            $c->stash->{'show_rootproblems_link'} = 1;
        }
    }

    $c->stash->{'comments'}  = $comments;
    $c->stash->{'downtimes'} = $downtimes;

    # generate command line
    if($c->{'stash'}->{'show_full_commandline'} == 2 ||
       $c->{'stash'}->{'show_full_commandline'} == 1 && $c->check_user_roles( "authorized_for_configuration_information" ) ) {
        if(defined $host) {
            my $command            = $c->{'db'}->expand_command('host' => $host );
            $c->stash->{'command'} = $command;
        }
    }

    # pnp graph?
    $c->stash->{'pnp_url'} = '';
    if($c->config->{'shown_inline_pnp'} and defined $host->{'action_url_expanded'} and $host->{'action_url_expanded'} =~ m|(^.*?/pnp4nagios/)|mx) {
        $c->stash->{'pnp_url'} = $1.'index.php';
    }

    # set allowed custom vars into stash
    Thruk::Utils::set_custom_vars($c, $host);

    return 1;
}

##########################################################
# create the hostgroup cmd page
sub _process_hostgroup_cmd_page {
    my( $self, $c ) = @_;

    my $hostgroup = $c->{'request'}->{'parameters'}->{'hostgroup'};
    return $c->detach('/error/index/5') unless defined $hostgroup;

    my $groups = $c->{'db'}->get_hostgroups(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ) , 'name' => $hostgroup ], limit => 1 );
    return $c->detach('/error/index/5') unless defined $groups->[0];

    $c->stash->{'hostgroup'}       = $groups->[0]->{'name'};
    $c->stash->{'hostgroup_alias'} = $groups->[0]->{'alias'};
    return 1;
}

##########################################################
# create the service info page
sub _process_service_page {
    my( $self, $c ) = @_;
    my $service;
    my $backend = $c->{'request'}->{'parameters'}->{'backend'} || '';

    my $hostname = $c->{'request'}->{'parameters'}->{'host'};
    return $c->detach('/error/index/15') unless defined $hostname;

    my $servicename = $c->{'request'}->{'parameters'}->{'service'};
    return $c->detach('/error/index/15') unless defined $servicename;

    my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { 'host_name' => $hostname }, { 'description' => $servicename }, ] );

    return $c->detach('/error/index/15') unless defined $services;

    # we only got one service
    $service = $services->[0];

    # we have more and backend param is used
    if( scalar @{$services} == 1 and defined $services ) {
        for my $s ( @{$services} ) {
            if( $s->{'peer_key'} eq $backend ) {
                $service = $s;
                last;
            }
        }
    }

    return $c->detach('/error/index/15') unless defined $service;

    my @backends;
    for my $s ( @{$services} ) {
        push @backends, $s->{'peer_key'};
    }
    $self->_set_backend_selector( $c, \@backends, $service->{'peer_key'} );

    $c->stash->{'service'} = $service;

    my $comments = $c->{'db'}->get_comments(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ), { 'host_name' => $hostname }, { 'service_description' => $servicename } ],
        sort => { 'DESC' => 'id' } );
    my $downtimes = $c->{'db'}->get_downtimes(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'host_name' => $hostname }, { 'service_description' => $servicename } ],
        sort => { 'DESC' => 'id' } );
    $c->stash->{'comments'}  = $comments;
    $c->stash->{'downtimes'} = $downtimes;

    # shinken only
    $c->stash->{'show_impacts_link'}      = 0;
    $c->stash->{'show_rootproblems_link'} = 0;
    if($c->stash->{'enable_shinken_features'}) {
        # show the impacts link for problem hosts
        if($service->{'is_problem'}) {
            $c->stash->{'show_impacts_link'}      = 1;
        }
        # show the root problems of this impact
        if($service->{'is_impact'}) {
            $c->stash->{'show_rootproblems_link'} = 1;
        }
    }

    # generate command line
    if($c->{'stash'}->{'show_full_commandline'} == 2 ||
       $c->{'stash'}->{'show_full_commandline'} == 1 && $c->check_user_roles( "authorized_for_configuration_information" ) ) {
        my $hosts               = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), { 'name' => $hostname } ] );
        # we only got one host
        my $host = $hosts->[0];
        # we have more and backend param is used
        if( scalar @{$hosts} == 1 and defined $backend ) {
            for my $h ( @{$hosts} ) {
                if( $h->{'peer_key'} eq $backend ) {
                    $host = $h;
                    last;
                }
            }
        }
        $c->stash->{'command'}  = '';
        if(defined $host and defined $service) {
            my $command            = $c->{'db'}->expand_command('host' => $host, 'service' => $service );
            $c->stash->{'command'} = $command;
        }
    }

    # pnp graph?
    $c->stash->{'pnp_url'} = '';
    if($c->config->{'shown_inline_pnp'} and defined $service->{'action_url_expanded'} and $service->{'action_url_expanded'} =~ m|(^.*?/pnp4nagios/)|mx) {
        $c->stash->{'pnp_url'} = $1.'index.php';
    }

    # set allowed custom vars into stash
    Thruk::Utils::set_custom_vars($c, $service);

    return 1;
}

##########################################################
# create the servicegroup cmd page
sub _process_servicegroup_cmd_page {
    my( $self, $c ) = @_;

    my $servicegroup = $c->{'request'}->{'parameters'}->{'servicegroup'};
    return $c->detach('/error/index/5') unless defined $servicegroup;

    my $groups = $c->{'db'}->get_servicegroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'servicegroups' ), name => $servicegroup ], limit => 1);

    return $c->detach('/error/index/5') unless defined $groups->[0];

    $c->stash->{'servicegroup'}       = $groups->[0]->{'name'};
    $c->stash->{'servicegroup_alias'} = $groups->[0]->{'alias'};

    return 1;
}

##########################################################
# create the scheduling page
sub _process_scheduling_page {
    my( $self, $c ) = @_;

    my $sorttype   = $c->{'request'}->{'parameters'}->{'sorttype'}   || 1;
    my $sortoption = $c->{'request'}->{'parameters'}->{'sortoption'} || 7;

    my $order = "ASC";
    $order = "DESC" if $sorttype == 2;

    my $sortoptions = {
        '1' => [ [ 'host_name', 'description' ], 'host name' ],
        '2' => [ 'description', 'service name' ],
        '4' => [ 'last_check',  'last check time' ],
        '7' => [ 'next_check',  'next check time' ],
    };
    $sortoption = 7 if !defined $sortoptions->{$sortoption};

    $c->{'db'}->get_scheduling_queue( sort => { $order => $sortoptions->{$sortoption}->[0] }, pager => $c, c => $c );

    $c->stash->{'order'}   = $order;
    $c->stash->{'sortkey'} = $sortoptions->{$sortoption}->[1];

    return 1;
}

##########################################################
# create the process info page
sub _process_process_info_page {
    my( $self, $c ) = @_;

    return $c->detach('/error/index/1') unless $c->check_user_roles("authorized_for_system_information");
    return 1;
}

##########################################################
# create the performance info page
sub _process_perf_info_page {
    my( $self, $c ) = @_;

    $c->stash->{'stats'}      = $c->{'db'}->get_performance_stats( services_filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ], hosts_filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );
    $c->stash->{'perf_stats'} = $c->{'db'}->get_extra_perf_stats(  filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'status' ) ] );

    return 1;
}

##########################################################
# show backend selector
sub _set_backend_selector {
    my( $self, $c, $backends, $selected ) = @_;
    my %backends = map { $_ => 1 } @{$backends};

    my @backends;
    my @possible_backends = $c->{'db'}->peer_key();
    for my $back (@possible_backends) {
        next if !defined $backends{$back};
        push @backends, $back;
    }

    $c->stash->{'matching_backends'} = \@backends;
    $c->stash->{'backend'}           = $selected;
    return 1;
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
