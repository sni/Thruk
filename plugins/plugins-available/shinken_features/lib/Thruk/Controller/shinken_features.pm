package Thruk::Controller::shinken_features;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';
use Thruk::Utils::Status;

=head1 NAME

Thruk::Controller::shinken_features - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 index

=cut

######################################

=head2 shinken_cgi

page: /thruk/cgi-bin/shinken.cgi

=cut
sub shinken_cgi : Regex('thruk\/cgi\-bin\/shinken_status\.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/shinken_features/shinken_status');
}


######################################

=head2 outagespbimp_cgi

page: /thruk/cgi-bin/outagespbimp.cgi

=cut
sub outagespbimp_cgi : Regex('thruk\/cgi\-bin\/outagespbimp\.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'cancled'};
    return $c->detach('/shinken_features/outages_pbimp_index');
}


##########################################################
sub outages_pbimp_index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    unless($c->stash->{'enable_shinken_features'}) {
        return $c->detach('/error/index/21');
    }

    $self->_process_outagespbimp($c);

    Thruk::Utils::ssi_include($c);

    return 1;
}


##########################################################
sub shinken_status :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    unless($c->stash->{'enable_shinken_features'}) {
        return $c->detach('/error/index/21');
    }

    $self->_process_bothtypes_page($c);

    Thruk::Utils::ssi_include($c);

    return 1;
}


##########################################################
sub _process_outagespbimp {
    my ( $self, $c ) = @_;

    # We want root problems only
    my $hst_pbs = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'),
                                                    is_problem => 1
                                                  ]);
    my $srv_pbs = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'),
                                                    is_problem => 1
                                                  ]);

    # Main data given for the criticities level, and know
    # if we have elements in it or not
    my @criticities = (
        {value => 5, text => 'Top production',  nb => 0},
        {value => 4, text => 'Production',      nb => 0},
        {value => 3, text => 'Standard',        nb => 0},
        {value => 2, text => 'Qualification',   nb => 0},
        {value => 1, text => 'Devel',           nb => 0},
        {value => 0, text => 'Nearly nothing',  nb => 0});

    # First for hosts
    if(defined $hst_pbs and scalar @{$hst_pbs} > 0) {
        my $hostcomments = {};
        my $tmp = $c->{'db'}->get_comments(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'comments'), service_description => undef ]);
        for my $com (@{$tmp}) {
            $hostcomments->{$com->{'host_name'}} = 0 unless defined $hostcomments->{$com->{'host_name'}};
            $hostcomments->{$com->{'host_name'}}++;

        }

        my $tmp2 = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts') ] );
        my $all_hosts = Thruk::Utils::array2hash($tmp2, 'name');
        for my $host (@{$hst_pbs}) {

            # get number of comments
            $host->{'comment_count'} = 0;
            $host->{'comment_count'} = $hostcomments->{$host->{'name'}} if defined $hostcomments->{$host->{'name'}};

            # count number of impacted hosts / services
            my($affected_hosts,$affected_services) = $self->_count_hosts_and_services_impacts($host);

            $host->{'affected_hosts'}    = $affected_hosts;
            $host->{'affected_services'} = $affected_services;

            # add a criticity to this crit level
            my $crit = $host->{'criticity'};
            #print STDERR "ADD crit $crit for\n";
            $criticities[5 - $crit]{"nb"}++;


        }
    }

    # Then for services
    if(defined $srv_pbs and scalar @{$srv_pbs} > 0) {
        my $srvcomments = {};
        for my $srv (@{$srv_pbs}) {

            # get number of comments
            $srv->{'comment_count'} = 0;

            # count number of impacted hosts / services
            my($affected_hosts,$affected_services) = $self->_count_hosts_and_services_impacts($srv);

            $srv->{'affected_hosts'}    = $affected_hosts;
            $srv->{'affected_services'} = $affected_services;

            # add a criticity to this crit level
            my $crit = $srv->{'criticity'};
            $criticities[5 - $crit]{"nb"}++;

        }
    }

    # add comments and downtimes
    Thruk::Utils::Status::set_comments_and_downtimes($c);

    # sort by criticity
    my $sortedhst_pbs = Thruk::Backend::Manager::_sort($c, $hst_pbs, { 'DESC' => 'criticity' });
    my $sortedsrv_pbs = Thruk::Backend::Manager::_sort($c, $srv_pbs, { 'DESC' => 'criticity' });

    $c->stash->{hst_pbs}        = $sortedhst_pbs;
    $c->stash->{srv_pbs}        = $sortedsrv_pbs;
    $c->stash->{criticities}    = \@criticities;
    $c->stash->{title}          = 'Problems and Impacts';
    $c->stash->{infoBoxTitle}   = 'Problems and Impacts';
    $c->stash->{page}           = 'status';
    $c->stash->{template}       = 'shinken_outagespbimp.tt';

    return 1;
}


##########################################################
# create the status details page
sub _process_bothtypes_page {
    my( $self, $c ) = @_;

    $c->stash->{title}        = 'Current Network Status';
    $c->stash->{infoBoxTitle} = 'Current Network Status';
    $c->stash->{page}         = 'status';
    $c->stash->{style}        = 'bothtypes';
    $c->stash->{template}     = 'shinken_status_bothtypes.tt';

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


    # count number of impacted hosts / services
    for my $host (@{$hosts}) {
        my($affected_hosts,$affected_services) = $self->_count_hosts_and_services_impacts($host);
        $host->{'affected_hosts'}    = $affected_hosts;
        $host->{'affected_services'} = $affected_services;
    }
    for my $srv (@{$services}) {
        my($affected_hosts,$affected_services) = $self->_count_hosts_and_services_impacts($srv);
        $srv->{'affected_hosts'}    = $affected_hosts;
        $srv->{'affected_services'} = $affected_services;
    }


    my $view_mode = $c->{'request'}->{'parameters'}->{'view_mode'} || 'html';
    if( defined $view_mode and $view_mode eq 'xls' ) {
        Thruk::Utils::Status::set_selected_columns($c);
        my $filename = 'status.xls';
        $c->res->header( 'Content-Disposition', qq[attachment; filename="] . $filename . q["] );
        $c->stash->{'servicedata'}  = $services;
        $c->stash->{'hostdata'}     = $hosts;
        $c->stash->{'template'}     = 'excel/status_detail.tt';
        return $c->detach('View::Excel');
    }

    $c->stash->{'servicedata'} = $services;
    $c->stash->{'hostdata'}    = $hosts;
    $c->stash->{'orderby'}     = $sortoptions->{$sortoption}->[1];
    $c->stash->{'orderdir'}    = $order;

    Thruk::Utils::Status::set_custom_title($c);

    return 1;
}


##########################################################
# Count the impacts for an host
sub _count_hosts_and_services_impacts {
    my($self, $host ) = @_;

    my $affected_hosts    = 0;
    my $affected_services = 0;

    return(0,0) if !defined $host;

    if(defined $host->{'impacts'} and $host->{'impacts'} ne '') {
        for my $child (@{$host->{'impacts'}}) {
            # Look at if we match an host or a service here
            # a service will have a /, not for hosts
            if($child =~ /\//mx){
                $affected_services += 1;
            }else{
                $affected_hosts += 1;
            }
        }
    }

    return($affected_hosts, $affected_services);
}

##########################################################

=head1 AUTHOR

Jean Gabès, 2010, <naparuba@gmail.com>
Sven Nierlein, 2011, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
