package Thruk::Controller::shinken_features;

use strict;
use warnings;
use parent 'Catalyst::Controller';

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
sub shinken_cgi : Path('/thruk/cgi-bin/shinken_status.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/shinken_features/shinken_status');
}


######################################

=head2 outagespbimp_cgi

page: /thruk/cgi-bin/outagespbimp.cgi

=cut
sub outagespbimp_cgi : Path('/thruk/cgi-bin/outagespbimp.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/shinken_features/outages_pbimp_index');
}

######################################

=head2 businessview_cgi

page: /thruk/cgi-bin/businessview.cgi

=cut
sub businessview_cgi : Path('/thruk/cgi-bin/businessview.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/shinken_features/businessview_index');
}



##########################################################

=head2 outages_pbimp_index

outages impacts index page

=cut
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

=head2 shinken_status

shinken status index page

=cut
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

    my $priorities = [];
    for my $crit (sort keys %{$c->config->{'priorities'}}) {
        push @{$priorities}, { value => $crit, text => $c->config->{'priorities'}->{$crit}, count => 0 },
    }

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
            $priorities->[$crit]->{'count'}++;


        }
    }

    # Then for services
    if(defined $srv_pbs and scalar @{$srv_pbs} > 0) {
        for my $srv (@{$srv_pbs}) {

            # get number of comments
            $srv->{'comment_count'} = 0;

            # count number of impacted hosts / services
            my($affected_hosts,$affected_services) = $self->_count_hosts_and_services_impacts($srv);

            $srv->{'affected_hosts'}    = $affected_hosts;
            $srv->{'affected_services'} = $affected_services;

            # add a criticity to this crit level
            my $crit = $srv->{'criticity'};
            $priorities->[$crit]->{'count'}++;

        }
    }

    # add comments and downtimes
    Thruk::Utils::Status::set_comments_and_downtimes($c);

    # sort by criticity
    my $sortedhst_pbs = Thruk::Backend::Manager::_sort($c, $hst_pbs, { 'DESC' => 'criticity' });
    my $sortedsrv_pbs = Thruk::Backend::Manager::_sort($c, $srv_pbs, { 'DESC' => 'criticity' });

    $c->stash->{hst_pbs}        = $sortedhst_pbs;
    $c->stash->{srv_pbs}        = $sortedsrv_pbs;
    $c->stash->{prios}          = $priorities;
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

    $c->stash->{title}         = 'Current Network Status';
    $c->stash->{infoBoxTitle}  = 'Current Network Status';
    $c->stash->{page}          = 'status';
    $c->stash->{show_top_pane} = 1;
    $c->stash->{style}         = 'bothtypes';
    $c->stash->{template}      = 'shinken_status_bothtypes.tt';

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
        '4' => [ [ 'last_check',              'host_name', 'description' ], 'last check time' ],
        '5' => [ [ 'current_attempt',         'host_name', 'description' ], 'attempt number' ],
        '6' => [ [ 'last_state_change_order', 'host_name', 'description' ], 'state duration' ],
    };
    $sortoption = 1 if !defined $sortoptions->{$sortoption};

    # get all services
    my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ], sort => { $order => $sortoptions->{$sortoption}->[0] }, pager => 1 );
    my $hosts    = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ], sort => { $order => $sortoptions->{$sortoption}->[0] }, pager => 1 );
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

=head2 businessview_index

businessview index page

=cut
sub businessview_index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    unless($c->stash->{'enable_shinken_features'}) {
        return $c->detach('/error/index/21');
    }

    my $priorities = [];
    for my $crit (sort keys %{$c->config->{'priorities'}}) {
        push @{$priorities}, { value => $crit, text => $c->config->{'priorities'}->{$crit}, count => 0 },
    }

    # We want root problems only
    my $hst_pbs = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'),
                                                    got_business_rule => 1
                                                  ]);
    my $srv_pbs = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'),
                                                    got_business_rule => 1
                                                  ]);

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
            $self->_link_parent_hosts_and_services($c, $host);

            # add a criticity to this crit level
            my $crit = $host->{'criticity'};
            $priorities->[$crit]->{'count'}++;

        }
    }

    # Then for services
    if(defined $srv_pbs and scalar @{$srv_pbs} > 0) {
        for my $srv (@{$srv_pbs}) {

            # get number of comments
            $srv->{'comment_count'} = 0;

            # count number of impacted hosts / services
            $self->_link_parent_hosts_and_services($c, $srv);

            # add a criticity to this crit level
            my $crit = $srv->{'criticity'};
            $priorities->[$crit]->{'count'}++;

        }
    }

    # sort by criticity
    my $sortedhst_pbs = Thruk::Backend::Manager::_sort($c, $hst_pbs, { 'DESC' => 'criticity' });
    my $sortedsrv_pbs = Thruk::Backend::Manager::_sort($c, $srv_pbs, { 'DESC' => 'criticity' });

    $c->stash->{hst_pbs}        = $sortedhst_pbs;
    $c->stash->{srv_pbs}        = $sortedsrv_pbs;
    $c->stash->{prios}          = $priorities;
    $c->stash->{title}          = 'Business Elements';
    $c->stash->{infoBoxTitle}   = 'Business Elements';
    $c->stash->{page}           = 'businessview';
    $c->stash->{template}       = 'shinken_businessview.tt';

    Thruk::Utils::ssi_include($c);

    return 1;
}


##########################################################
# Count the impacts for an host
sub _link_parent_hosts_and_services {
    my($self, $c,  $elt, $level ) = @_;

    $level                     = 0 unless defined $level;
    $elt->{'host_parents'}     = [];
    $elt->{'services_parents'} = [];

    return 0 if !defined $elt;

    # avoid deep recursion
    return -1 if $level > 10;

    if(defined $elt->{'parent_dependencies'} and $elt->{'parent_dependencies'} ne '') {
        for my $parent (@{$elt->{'parent_dependencies'}}) {
            # Look at if we match an elt or a service here
            # a service will have a /, not for elts
            if($parent =~ /\//mx){
                # We need to look for the service object
                my @elts = split '\/', $parent;
                # Why is it reversed here?
                my $hname = $elts[0];
                my $desc = $elts[1];
                my $servicefilter = [ { description        => { '='     => $desc } },
                                      { host_name          => { '='     => $hname } },
                                    ];

                my $tmp_services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ] );
                my $srv = $tmp_services->[0];
                push(@{$elt->{'services_parents'}}, $srv);
                # And call this on this parent too to build a tree
                return -1 if $self->_link_parent_hosts_and_services($c, $srv, ++$level) == -1;
            }else{
                my $host_search_filter = [ { name               => { '='     => $parent } },
                                         ];

                my $tmp_hosts = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $host_search_filter ] );
                # we only got one host
                my $hst = $tmp_hosts->[0];

                push(@{$elt->{'host_parents'}}, $hst);
                # And call this on this parent too to build a tree
                return -1 if $self->_link_parent_hosts_and_services($c, $hst, ++$level) == -1;
            }
        }
    }

    return 0;
}


##########################################################

=head1 AUTHOR

Jean Gabes, 2010, <naparuba@gmail.com>
Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
