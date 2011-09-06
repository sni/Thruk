package Thruk::Utils::Status;

=head1 NAME

Thruk::Utils::Status - Status Utilities Collection for Thruk

=head1 DESCRIPTION

Status Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Carp;
use utf8;

##############################################

=head1 METHODS

=head2 set_default_stash

  set_default_stash($c)

sets some default stash variables

=cut
sub set_default_stash {
    my( $c ) = @_;

    $c->stash->{'hoststatustypes'}      = $c->{'request'}->{'parameters'}->{'hoststatustypes'}    || '';
    $c->stash->{'hostprops'}            = $c->{'request'}->{'parameters'}->{'hostprops'}          || '';
    $c->stash->{'servicestatustypes'}   = $c->{'request'}->{'parameters'}->{'servicestatustypes'} || '';
    $c->stash->{'serviceprops'}         = $c->{'request'}->{'parameters'}->{'serviceprops'}       || '';
    $c->stash->{'nav'}                  = $c->{'request'}->{'parameters'}->{'nav'}                || '';
    $c->stash->{'entries'}              = $c->{'request'}->{'parameters'}->{'entries'}            || '';
    $c->stash->{'sortoption'}           = $c->{'request'}->{'parameters'}->{'sortoption'}         || '';
    $c->stash->{'sortoption_hst'}       = $c->{'request'}->{'parameters'}->{'sortoption_hst'}     || '';
    $c->stash->{'sortoption_svc'}       = $c->{'request'}->{'parameters'}->{'sortoption_svc'}     || '';
    $c->stash->{'hidesearch'}           = $c->{'request'}->{'parameters'}->{'hidesearch'}         || 0;
    $c->stash->{'hostgroup'}            = $c->{'request'}->{'parameters'}->{'hostgroup'}          || '';
    $c->stash->{'servicegroup'}         = $c->{'request'}->{'parameters'}->{'servicegroup'}       || '';
    $c->stash->{'host'}                 = $c->{'request'}->{'parameters'}->{'host'}               || '';
    $c->stash->{'service'}              = $c->{'request'}->{'parameters'}->{'service'}            || '';
    $c->stash->{'data'}                 = "";
    $c->stash->{'style'}                = "";
    $c->stash->{'has_error'}            = 0;
    $c->stash->{'pager'}                = "";
    $c->stash->{show_substyle_selector} = 1;
    $c->stash->{imgsize}                = 20;

    return;
}

##############################################

=head2 summary_add_host_stats

  summary_add_host_stats($prefix, $group, $host)

count host status for this host

=cut
sub summary_add_host_stats {
    my( $prefix, $group, $host ) = @_;

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

##############################################

=head2 get_search_from_param

  get_search_from_param($c, $prefix, $force)

returns search parameter based on request parameters

=cut
sub get_search_from_param {
    my( $c, $prefix, $force ) = @_;

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

    # store global searches, these will be added to our search
    my $globals = {
        'host'         => $c->stash->{'host'},
        'hostgroup'    => $c->stash->{'hostgroup'},
        'servicegroup' => $c->stash->{'servicegroup'},
        'service'      => $c->stash->{'service'},
    };

    if( ref $c->{'request'}->{'parameters'}->{ $prefix . '_type' } eq 'ARRAY' ) {
        for ( my $x = 0; $x < scalar @{ $c->{'request'}->{'parameters'}->{ $prefix . '_type' } }; $x++ ) {
            my $text_filter = {
                type  => $c->{'request'}->{'parameters'}->{ $prefix . '_type' }->[$x],
                value => $c->{'request'}->{'parameters'}->{ $prefix . '_value' }->[$x],
                op    => $c->{'request'}->{'parameters'}->{ $prefix . '_op' }->[$x],
            };
            if($text_filter->{'type'} eq 'priority' and defined $c->{'request'}->{'parameters'}->{ $prefix . '_value_sel' }->[$x]) {
                $text_filter->{'value'} = $c->{'request'}->{'parameters'}->{ $prefix . '_value_sel' }->[$x];
            }
            push @{ $search->{'text_filter'} }, $text_filter;
            if(defined $globals->{$text_filter->{type}} and $text_filter->{op} eq '=' and $text_filter->{value} eq $globals->{$text_filter->{type}}) { delete $globals->{$text_filter->{type}}; }
        }
    }
    else {
        my $text_filter = {
            type  => $c->{'request'}->{'parameters'}->{ $prefix . '_type' },
            value => $c->{'request'}->{'parameters'}->{ $prefix . '_value' },
            op    => $c->{'request'}->{'parameters'}->{ $prefix . '_op' },
        };
        if(defined $c->{'request'}->{'parameters'}->{ $prefix . '_value_sel'} and $text_filter->{'type'} eq 'priority') {
            $text_filter->{'value'} = $c->{'request'}->{'parameters'}->{ $prefix . '_value_sel'};
        }
        push @{ $search->{'text_filter'} }, $text_filter;
        if(defined $globals->{$text_filter->{type}} and $text_filter->{op} eq '=' and $text_filter->{value} eq $globals->{$text_filter->{type}}) { delete $globals->{$text_filter->{type}}; }
    }

    for my $key (keys %{$globals}) {
        if(defined $globals->{$key} and $globals->{$key} ne '') {
            my $text_filter = {
                type  => $key,
                value => $globals->{$key},
                op    => '=',
            };
            push @{ $search->{'text_filter'} }, $text_filter;
        }
    }

    return $search;
}


##############################################

=head2 do_filter

  do_filter($c, $prefix)

returns filter from request parameter

=cut
sub do_filter {
    my( $c, $prefix ) = @_;

    my $hostfilter;
    my $servicefilter;
    my $hostgroupfilter;
    my $servicegroupfilter;
    my $searches;

    $prefix = 'dfl_' unless defined $prefix;

    unless ( exists $c->{'request'}->{'parameters'}->{$prefix.'s0_hoststatustypes'}
          or exists $c->{'request'}->{'parameters'}->{$prefix.'s0_type'}
          or exists $c->{'request'}->{'parameters'}->{'s0_hoststatustypes'}
          or exists $c->{'request'}->{'parameters'}->{'s0_type'} )
    {

        # classic search
        my $search;
        ( $search, $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = Thruk::Utils::Status::classic_filter($c);

        # convert that into a new search
        push @{$searches}, $search;
    }
    else {

        if(   exists $c->{'request'}->{'parameters'}->{'s0_hoststatustypes'}
           or exists $c->{'request'}->{'parameters'}->{'s0_type'} ) {
            $prefix = '';
        }

        # complex filter search?
        push @{$searches}, Thruk::Utils::Status::get_search_from_param( $c, $prefix.'s0', 1 );
        for ( my $x = 1; $x <= 99; $x++ ) {
            my $search = Thruk::Utils::Status::get_search_from_param( $c, $prefix.'s' . $x );
            push @{$searches}, $search if defined $search;
        }
        ( $searches, $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = Thruk::Utils::Status::do_search( $c, $searches, $prefix );
    }

    $prefix = 'dfl_' unless $prefix ne '';
    $c->stash->{'searches'}->{$prefix} = $searches;

    return ( $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter );
}


##############################################

=head2 classic_filter

  classic_filter($c)

returns filter for old style parameter

=cut
sub classic_filter {
    my( $c ) = @_;

    # classic search
    my $errors       = 0;
    my $host         = $c->{'request'}->{'parameters'}->{'host'}         || '';
    my $hostgroup    = $c->{'request'}->{'parameters'}->{'hostgroup'}    || '';
    my $servicegroup = $c->{'request'}->{'parameters'}->{'servicegroup'} || '';

    $c->stash->{'host'}         = $host;
    $c->stash->{'hostgroup'}    = $hostgroup;
    $c->stash->{'servicegroup'} = $servicegroup;

    my @hostfilter;
    my @hostgroupfilter;
    my @servicefilter;
    my @servicegroupfilter;
    if( $host ne 'all' and $host ne '' ) {
        # check for wildcards
        if( CORE::index( $host, '*' ) >= 0 ) {
            # convert wildcards into real regexp
            my $searchhost = $host;
            $searchhost =~ s/\.\*/*/gmx;
            $searchhost =~ s/\*/.*/gmx;
            $errors++ unless Thruk::Utils::is_valid_regular_expression( $c, $searchhost );
            push @hostfilter,    [ { 'name'      => { '~~' => $searchhost } } ];
            push @servicefilter, [ { 'host_name' => { '~~' => $searchhost } } ];
        } else {
            push @hostfilter,    [ { 'name'      => $host } ];
            push @servicefilter, [ { 'host_name' => $host } ];
        }
    }
    if ( $hostgroup ne 'all' and $hostgroup ne '' ) {
        push @hostfilter,       [ { 'groups'      => { '>=' => $hostgroup } } ];
        push @servicefilter,    [ { 'host_groups' => { '>=' => $hostgroup } } ];
        push @hostgroupfilter,  [ { 'name' => $hostgroup } ];
    }
    if ( $servicegroup ne 'all' and $servicegroup ne '' ) {
        push @servicefilter,       [ { 'groups' => { '>=' => $servicegroup } } ];
        push @servicegroupfilter,  [ { 'name' => $servicegroup } ];
    }

    my $hostfilter         = Thruk::Utils::combine_filter( '-and', \@hostfilter );
    my $hostgroupfilter    = Thruk::Utils::combine_filter( '-and', \@hostgroupfilter );
    my $servicefilter      = Thruk::Utils::combine_filter( '-and', \@servicefilter );
    my $servicegroupfilter = Thruk::Utils::combine_filter( '-and', \@servicegroupfilter );

    # fill the host/service totals box
    unless($errors) {
        Thruk::Utils::Status::fill_totals_box( $c, $hostfilter, $servicefilter );
    }

    # then add some more filter based on get parameter
    my $hoststatustypes    = $c->{'request'}->{'parameters'}->{'hoststatustypes'};
    my $hostprops          = $c->{'request'}->{'parameters'}->{'hostprops'};
    my $servicestatustypes = $c->{'request'}->{'parameters'}->{'servicestatustypes'};
    my $serviceprops       = $c->{'request'}->{'parameters'}->{'serviceprops'};

    my( $host_statustype_filtername,  $host_prop_filtername,  $service_statustype_filtername,  $service_prop_filtername );
    my( $host_statustype_filtervalue, $host_prop_filtervalue, $service_statustype_filtervalue, $service_prop_filtervalue );
    ( $hostfilter, $servicefilter, $host_statustype_filtername, $host_prop_filtername, $service_statustype_filtername, $service_prop_filtername, $host_statustype_filtervalue, $host_prop_filtervalue, $service_statustype_filtervalue, $service_prop_filtervalue )
        = Thruk::Utils::Status::extend_filter( $c, $hostfilter, $servicefilter, $hoststatustypes, $hostprops, $servicestatustypes, $serviceprops );

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
    if ( $hostgroup ne '' ) {
        push @{ $search->{'text_filter'} },
            {
            'type'  => 'hostgroup',
            'value' => $hostgroup,
            'op'    => '=',
            };
    }
    if ( $servicegroup ne '' ) {
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


##############################################

=head2 do_search

  do_search($c, $searches, $prefix)

returns combined filter

=cut
sub do_search {
    my( $c, $searches, $prefix ) = @_;

    my( @hostfilter, @servicefilter, @hostgroupfilter, @servicegroupfilter, @hosttotalsfilter, @servicetotalsfilter );

    for my $search ( @{$searches} ) {
        my( $tmp_hostfilter, $tmp_servicefilter, $tmp_hostgroupfilter, $tmp_servicegroupfilter, $tmp_hosttotalsfilter, $tmp_servicetotalsfilter ) = Thruk::Utils::Status::single_search( $c, $search );
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
    if(!$c->stash->{'has_error'} and ( $prefix eq 'dfl_' or $prefix eq '')) {
        Thruk::Utils::Status::fill_totals_box( $c, $hosttotalsfilter, $servicetotalsfilter );
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


##############################################

=head2 fill_totals_box

  fill_totals_box($c, $hostfilter, $servicefilter)

fill host and service totals box

=cut
sub fill_totals_box {
    my( $c, $hostfilter, $servicefilter ) = @_;

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


##############################################

=head2 extend_filter

  extend_filter($c, $hostfilter, $servicefilter, $hoststatustypes, $hostprops, $servicestatustypes, $serviceprops)

returns extended filter

=cut
sub extend_filter {
    my( $c, $hostfilter, $servicefilter, $hoststatustypes, $hostprops, $servicestatustypes, $serviceprops ) = @_;

    my @hostfilter;
    my @servicefilter;

    push @hostfilter,    $hostfilter    if defined $hostfilter;
    push @servicefilter, $servicefilter if defined $servicefilter;

    $c->stash->{'show_filter_table'} = 0;

    # host statustype filter (up,down,...)
    my( $host_statustype_filtername, $host_statustype_filter, $host_statustype_filter_service );
    ( $hoststatustypes, $host_statustype_filtername, $host_statustype_filter, $host_statustype_filter_service )
        = Thruk::Utils::Status::get_host_statustype_filter($hoststatustypes);
    push @hostfilter,    $host_statustype_filter         if defined $host_statustype_filter;
    push @servicefilter, $host_statustype_filter_service if defined $host_statustype_filter_service;

    $c->stash->{'show_filter_table'} = 1 if defined $host_statustype_filter;

    # host props filter (downtime, acknowledged...)
    my( $host_prop_filtername, $host_prop_filter, $host_prop_filter_service );
    ( $hostprops, $host_prop_filtername, $host_prop_filter, $host_prop_filter_service )
        = Thruk::Utils::Status::get_host_prop_filter($hostprops);
    push @hostfilter,    $host_prop_filter         if defined $host_prop_filter;
    push @servicefilter, $host_prop_filter_service if defined $host_prop_filter_service;

    $c->stash->{'show_filter_table'} = 1 if defined $host_prop_filter;

    # service statustype filter (ok,warning,...)
    my( $service_statustype_filtername, $service_statustype_filter_service );
    ( $servicestatustypes, $service_statustype_filtername, $service_statustype_filter_service )
        = Thruk::Utils::Status::get_service_statustype_filter($servicestatustypes);
    push @servicefilter, $service_statustype_filter_service if defined $service_statustype_filter_service;

    $c->stash->{'show_filter_table'} = 1 if defined $service_statustype_filter_service;

    # service props filter (downtime, acknowledged...)
    my( $service_prop_filtername, $service_prop_filter_service );
    ( $serviceprops, $service_prop_filtername, $service_prop_filter_service )
        = Thruk::Utils::Status::get_service_prop_filter($serviceprops);
    push @servicefilter, $service_prop_filter_service if defined $service_prop_filter_service;

    $c->stash->{'show_filter_table'} = 1 if defined $service_prop_filter_service;

    $hostfilter    = Thruk::Utils::combine_filter( '-and', \@hostfilter );
    $servicefilter = Thruk::Utils::combine_filter( '-and', \@servicefilter );

    return ( $hostfilter, $servicefilter, $host_statustype_filtername, $host_prop_filtername, $service_statustype_filtername, $service_prop_filtername, $hoststatustypes, $hostprops, $servicestatustypes, $serviceprops );
}


##############################################

=head2 single_search

  single_search($c, $search)

processes a single search box filter

=cut
sub single_search {
    my( $c, $search ) = @_;

    my $errors = 0;
    my( @hostfilter, @servicefilter, @hostgroupfilter, @servicegroupfilter, @hosttotalsfilter, @servicetotalsfilter );

    my( $tmp_hostfilter, $tmp_servicefilter, $host_statustype_filtername, $host_prop_filtername, $service_statustype_filtername, $service_prop_filtername, $host_statustype_filtervalue, $host_prop_filtervalue, $service_statustype_filtervalue, $service_prop_filtervalue )
        = Thruk::Utils::Status::extend_filter( $c, undef, undef, $search->{'hoststatustypes'}, $search->{'hostprops'}, $search->{'servicestatustypes'}, $search->{'serviceprops'} );

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

        # skip most empty filter
        if(    $value =~ m/^\s*$/mx
           and $filter->{'type'} ne 'next check'
           and $filter->{'type'} ne 'last check'
        ) {
            next;
        }

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
            my($hfilter, $sfilter) = Thruk::Utils::Status::get_comments_filter($c, $op, $value);

            my $host_search_filter = [ { name               => { $op     => $value } },
                                       { alias              => { $op     => $value } },
                                       { address            => { $op     => $value } },
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
                                          { host_address       => { $op     => $value } },
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
                push @hostfilter,          { -or => [ name      => { '~~' => $searchhost }, alias      => { '~~' => $searchhost }, address      => { '~~' => $searchhost } ] };
                push @hosttotalsfilter,    { -or => [ name      => { '~~' => $searchhost }, alias      => { '~~' => $searchhost }, address      => { '~~' => $searchhost } ] };
                push @servicefilter,       { -or => [ host_name => { '~~' => $searchhost }, host_alias => { '~~' => $searchhost }, host_address => { '~~' => $searchhost } ] };
                push @servicetotalsfilter, { -or => [ host_name => { '~~' => $searchhost }, host_alias => { '~~' => $searchhost }, host_address => { '~~' => $searchhost } ] };
            }
            else {
                push @hostfilter,          { $joinop => [ name      => { $op => $value }, alias      => { $op => $value }, address      => { $op => $value } ] };
                push @hosttotalsfilter,    { $joinop => [ name      => { $op => $value }, alias      => { $op => $value }, address      => { $op => $value } ] };
                push @servicefilter,       { $joinop => [ host_name => { $op => $value }, host_alias => { $op => $value }, host_address => { $op => $value } ] };
                push @servicetotalsfilter, { $joinop => [ host_name => { $op => $value }, host_alias => { $op => $value }, host_address => { $op => $value }] };
            }
        }
        elsif ( $filter->{'type'} eq 'service' ) {
            push @servicefilter,       { description => { $op => $value } };
            push @servicetotalsfilter, { description => { $op => $value } };
        }
        elsif ( $filter->{'type'} eq 'hostgroup' ) {
            if($op eq '~~' or $op eq '!~~~') {
                my($hfilter, $sfilter) = Thruk::Utils::Status::get_groups_filter($c, $op, $value, 'hostgroup');
                push @hostfilter,          $hfilter;
                push @hosttotalsfilter,    $hfilter;
                push @servicefilter,       $sfilter;
                push @servicetotalsfilter, $sfilter;
            } else {
                push @hostfilter,          { groups      => { $listop => $value } };
                push @hosttotalsfilter,    { groups      => { $listop => $value } };
                push @servicefilter,       { host_groups => { $listop => $value } };
                push @servicetotalsfilter, { host_groups => { $listop => $value } };
            }
            push @hostgroupfilter,     { name        => { $op     => $value } };
        }
        elsif ( $filter->{'type'} eq 'servicegroup' ) {
            if($op eq '~~' or $op eq '!~~~') {
                my($hfilter, $sfilter) = Thruk::Utils::Status::get_groups_filter($c, $op, $value, 'servicegroup');
                push @servicefilter,       $sfilter;
                push @servicetotalsfilter, $sfilter;
            } else {
                push @servicefilter,       { groups => { $listop => $value } };
                push @servicetotalsfilter, { groups => { $listop => $value } };
            }
            push @servicegroupfilter,  { name   => { $op     => $value } };
        }
        elsif ( $filter->{'type'} eq 'contact' ) {
            push @servicefilter,       { contacts => { $listop => $value } };
            push @hostfilter,          { contacts => { $listop => $value } };
            push @servicetotalsfilter, { contacts => { $listop => $value } };
        }
        elsif ( $filter->{'type'} eq 'next check' ) {
            my $date;
            if($value eq "N/A" or $value eq "") {
                $date = "";
            } else {
                $date = Thruk::Utils::parse_date( $c, $value );
            }
            if(defined $date) {
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
        elsif ( $filter->{'type'} eq '% state change' ) {
            push @hostfilter,    { percent_state_change => { $op => $value } };
            push @servicefilter, { percent_state_change => { $op => $value } };
        }
        elsif ( $filter->{'type'} eq 'last check' ) {
            my $date;
            if($value eq "N/A" or $value eq "") {
                $date = "";
            } else {
                $date = Thruk::Utils::parse_date( $c, $value );
            }
            if(defined $date) {
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
        # Impacts are only available in Shinken
        elsif ( $filter->{'type'} eq 'impact' && $c->stash->{'enable_shinken_features'}) {
            next unless $c->stash->{'enable_shinken_features'};
            push @hostfilter,          { source_problems      => { $listop => $value } };
            push @hosttotalsfilter,    { source_problems      => { $listop => $value } };
            push @servicefilter,       { source_problems      => { $listop => $value } };
            push @servicetotalsfilter, { source_problems      => { $listop => $value } };
        }
        # Root Problems are only available in Shinken
        elsif ( $filter->{'type'} eq 'rootproblem' && $c->stash->{'enable_shinken_features'}) {
            next unless $c->stash->{'enable_shinken_features'};
            push @hostfilter,          { impacts      => { $listop => $value } };
            push @hosttotalsfilter,    { impacts      => { $listop => $value } };
            push @servicefilter,       { impacts      => { $listop => $value } };
            push @servicetotalsfilter, { impacts      => { $listop => $value } };
        }
        # Priority (criticity) is only available in Shinken
        elsif ( $filter->{'type'} eq 'priority' ) {
            next unless $c->stash->{'enable_shinken_features'};
            push @hostfilter,    { criticity => { $op => $value } };
            push @servicefilter, { criticity => { $op => $value } };
        }
        elsif ( $filter->{'type'} eq 'comment' ) {
            my($hfilter, $sfilter) = Thruk::Utils::Status::get_comments_filter($c, $op, $value);
            push @hostfilter,          $hfilter;
            push @servicefilter,       $sfilter;
        }
        elsif ( $filter->{'type'} eq 'check period' ) {
            push @hostfilter,    { check_period => { $op => $value } };
            push @servicefilter, { check_period => { $op => $value } };
        }
        # Filter on the downtime duration
        elsif ( $filter->{'type'} eq 'downtime duration' ) {
            my($hfilter, $sfilter) = Thruk::Utils::Status::get_downtimes_filter($c, $op, $value);
            push @hostfilter,          $hfilter;
            push @servicefilter,       $sfilter;
        }
        elsif ( $filter->{'type'} eq 'notification period' ) {
            push @hostfilter,    { notification_period => { $op => $value } };
            push @servicefilter, { notification_period => { $op => $value } };
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


##############################################

=head2 get_host_statustype_filter

  get_host_statustype_filter($number)

returns filter for number

=cut
sub get_host_statustype_filter {
    my( $number ) = @_;
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


##############################################

=head2 get_host_prop_filter

  get_host_prop_filter($number)

returns filter for number

=cut
sub get_host_prop_filter {
    my( $number ) = @_;

    my @host_prop_filter;
    my @host_prop_filter_service;

    $number = 0 if !defined $number or $number !~ m/^\d+$/mx or $number <= 0 or $number > 67108863;
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
        if( $bits[20] ) {    # 1048576 - In Check Period
            push @host_prop_filter,         { in_check_period => 1 };
            push @host_prop_filter_service, { host_in_check_period => 1 };
            push @host_prop_filtername, 'In Check Period';
        }
        if( $bits[21] ) {    # 2097152 - Outside Check Period
            push @host_prop_filter,         { in_check_period => 0 };
            push @host_prop_filter_service, { host_in_check_period => 0 };
            push @host_prop_filtername, 'Outside Check Period';
        }
        if( $bits[22] ) {    # 4194304 - In Notification Period
            push @host_prop_filter,         { in_notification_period => 1 };
            push @host_prop_filter_service, { host_in_notification_period => 1 };
            push @host_prop_filtername, 'In Notification Period';
        }
        if( $bits[23] ) {    # 8388608 - Outside Notification Period
            push @host_prop_filter,         { in_notification_period => 0 };
            push @host_prop_filter_service, { host_in_notification_period => 0 };
            push @host_prop_filtername, 'Outside Notification Period';
        }
        if( $bits[24] ) {    # 16777216 - Has Modified Attributes
            push @host_prop_filter,         { modified_attributes      => { '>' => 0 } };
            push @host_prop_filter_service, { host_modified_attributes => { '>' => 0 } };
            push @host_prop_filtername, 'Has Modified Attributes';
        }
        if( $bits[25] ) {    # 33554432 - No Modified Attributes
            push @host_prop_filter,         { modified_attributes => 0 };
            push @host_prop_filter_service, { host_modified_attributes => 0 };
            push @host_prop_filtername, 'No Modified Attributes';
        }

        $host_prop_filtername = join( ' &amp; ', @host_prop_filtername );
    }

    my $hostfilter    = Thruk::Utils::combine_filter( '-and', \@host_prop_filter );
    my $servicefilter = Thruk::Utils::combine_filter( '-and', \@host_prop_filter_service );

    return ( $number, $host_prop_filtername, $hostfilter, $servicefilter );
}


##############################################

=head2 get_service_statustype_filter

  get_service_statustype_filter($number)

returns filter for number

=cut
sub get_service_statustype_filter {
    my( $number ) = @_;

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


##############################################

=head2 get_service_prop_filter

  get_service_prop_filter($number)

returns filter for number

=cut
sub get_service_prop_filter {
    my( $number ) = @_;

    my @service_prop_filter;
    my @service_prop_filtername;

    $number = 0 if !defined $number or $number !~ m/^\d+$/mx or $number <= 0 or $number > 67108863;
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
        if( $bits[20] ) {    # 1048576 - In Check Period
            push @service_prop_filter, { in_check_period => 1 };
            push @service_prop_filtername, 'In Check Period';
        }
        if( $bits[21] ) {    # 2097152 - Outside Check Period
            push @service_prop_filter, { in_check_period => 0 };
            push @service_prop_filtername, 'Outside Check Period';
        }
        if( $bits[22] ) {    # 4194304 - In Notification Period
            push @service_prop_filter, { in_notification_period => 1 };
            push @service_prop_filtername, 'In Notification Period';
        }
        if( $bits[23] ) {    # 8388608 - Outside Notification Period
            push @service_prop_filter, { in_notification_period => 0 };
            push @service_prop_filtername, 'Outside Notification Period';
        }
        if( $bits[24] ) {    # 16777216 - Has Modified Attributes
            push @service_prop_filter, { modified_attributes => { '>' => 0 } };
            push @service_prop_filtername, 'Has Modified Attributes';
        }
        if( $bits[25] ) {    # 33554432 - No Modified Attributes
            push @service_prop_filter, { modified_attributes => 0 };
            push @service_prop_filtername, 'No Modified Attributes';
        }

        $service_prop_filtername = join( ' &amp; ', @service_prop_filtername );
    }

    my $servicefilter = Thruk::Utils::combine_filter( '-and', \@service_prop_filter );

    return ( $number, $service_prop_filtername, $servicefilter );
}


##############################################

=head2 get_comments_filter

  get_comments_filter($c, $op, $value)

returns filter for comments

=cut
sub get_comments_filter {
    my($c, $op, $value) = @_;

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


##############################################

=head2 get_groups_filter

  get_groups_filter($c, $op, $value, $type)

returns filter for comments

=cut
sub get_groups_filter {
    my($c, $op, $value, $type) = @_;

    my(@hostfilter, @servicefilter);

    return(\@hostfilter, \@servicefilter) unless Thruk::Utils::is_valid_regular_expression( $c, $value );

    return(\@hostfilter, \@servicefilter) if $value eq '';

    my $groups;
    if($type eq 'hostgroup') {
        $groups = $c->{'db'}->get_hostgroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ), { name => { $op => $value }} ] );
    }
    elsif($type eq 'servicegroup') {
        $groups = $c->{'db'}->get_servicegroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'servicegroups' ), { name => { $op => $value }} ] );
    }
    my @names = sort keys %{ Thruk::Utils::array2hash([@{$groups}], 'name') };
    if(scalar @names == 0) { @names = (''); }

    my $group_op = '!>=';
    if($op eq '=' or $op eq '~~') {
        $group_op = '>=';
    }

    if($type eq 'hostgroup') {
        push @hostfilter,    { -or => { groups      => { $group_op => \@names } } };
        push @servicefilter, { -or => { host_groups => { $group_op => \@names } } };
    }
    elsif($type eq 'servicegroup') {
        push @servicefilter, { -or => { groups => { $group_op => \@names } } };
    }

    return(\@hostfilter, \@servicefilter);
}


##############################################

=head2 set_selected_columns

  set_selected_columns($c)

set selected columns for the excel export

=cut
sub set_selected_columns {
    my($c) = @_;
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


##############################################

=head2 set_custom_title

  set_custom_title($c)

set selected columns for the excel export

=cut
sub set_custom_title {
    my($c) = @_;
    $c->stash->{custom_title} = '';
    if( exists $c->{'request'}->{'parameters'}->{'title'} ) {
        my $custom_title          = $c->{'request'}->{'parameters'}->{'title'};
        $custom_title             =~ s/\+/\ /gmx;
        $c->stash->{custom_title} = $custom_title;
        $c->stash->{title}        = $custom_title;
    }
    return;
}


##############################################

=head2 set_comments_and_downtimes

  set_comments_and_downtimes($c)

set comments / downtimes by host

=cut
sub set_comments_and_downtimes {
    my($c) = @_;

    # add comments and downtimes
    my $comments  = $c->{'db'}->get_comments( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'comments' ) ] );
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

    return;
}

##############################################

=head2 add_view

  add_view($options)

add a new view to the display filter selection

=cut
sub add_view {
    my $options = shift;

    confess("options missing") unless defined $options;
    confess("group missing")   unless defined $options->{'group'};
    confess("name missing")    unless defined $options->{'name'};
    confess("value missing")   unless defined $options->{'value'};
    confess("url missing")     unless defined $options->{'url'};

    $Thruk::Utils::Status::additional_views = {} unless defined $Thruk::Utils::Status::additional_views;

    my $group = $Thruk::Utils::Status::additional_views->{$options->{'group'}};

    $group = {
        'name'    => $options->{'group'},
        'options' => {},
    } unless defined $group;

    $group->{'options'}->{$options->{'name'}} = $options;
    $Thruk::Utils::Status::additional_views->{$options->{'group'}} = $group;

    return;
}

##############################################

=head2 redirect_view

  redirect_view($c)

redirect to right url when switching displays

=cut
sub redirect_view {
    my $c     = shift;
    my $style = shift || 'detail';

    my $new = 'status.cgi';
    my $uri = $c->request->uri();
    $uri =~ m/\/cgi\-bin\/(.*?\.cgi)/mx;
    my $old = $1 || 'status.cgi';

    VIEW_SEARCH:
    for my $groupname (keys %{$c->stash->{'additional_views'}}) {
        for my $optname (keys %{$c->stash->{'additional_views'}->{$groupname}->{'options'}}) {
            if($c->stash->{'additional_views'}->{$groupname}->{'options'}->{$optname}->{'value'} eq $style) {
                $new = $c->stash->{'additional_views'}->{$groupname}->{'options'}->{$optname}->{'url'};
                last VIEW_SEARCH;
            }
        }
    }
    return if $old eq $new;

    $uri    =~ s/$old/$new/gmx;
    return $c->redirect($uri);
}


# It's the method "get_comments_filter" adaptated
=head2 get_downtimes_filter

  get_downtimes_filter($c, $op, $value)

returns filter for downtime duration

=cut

sub get_downtimes_filter {
    my($c, $op, $value) = @_;
    my(@hostfilter, @servicefilter);

    return(\@hostfilter, \@servicefilter) unless Thruk::Utils::is_valid_regular_expression( $c, $value );

    if($value eq '') {
        push @hostfilter,          { -or => [ downtimes => { $op => { '!=' => undef }} ]};
        push @servicefilter,       { -or => [ downtimes => { $op => { '!=' => undef }} ]};
    }
    else {
        # The value is on hours, convert to seconds
        $value = $value * 3600;

        # Get all the downtimes
        my $downtimes    = $c->{'db'}->get_downtimes( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ) ] );
        my @downtime_ids = sort keys %{ Thruk::Utils::array2hash([@{$downtimes}], 'id') };

        # If no downtimes returned
        if(scalar @downtime_ids == 0) {
            @downtime_ids = (-1);
        }
        else {
            # Filter on the downtime duration
            foreach my $downtime (@{$downtimes}) {
                my $downtime_duration = $downtime->{end_time} - $downtime->{start_time};

                if ( $op eq '=' ) {
                    if ( not $downtime_duration == $value) {
                    $downtime = undef;
                    }
                } elsif ( $op eq '>=' ) {
                    if ( not $downtime_duration >= $value) {
                        $downtime = undef;
                    }
                } elsif ( $op eq '<=' ) {
                    if ( not $downtime_duration <= $value ) {
                        $downtime = undef;
                    } 
                } elsif ( $op eq '!=' ) {
                    if ( not $downtime_duration != $value ) {
                        $downtime = undef;
                    }
                }
            }
            @downtime_ids = sort keys %{ Thruk::Utils::array2hash([@{$downtimes}], 'id') };
        }

        # Supress undef value if is present and not the only result, or replace undef by -1 if no results
        if (scalar(@downtime_ids) == 1 and $downtime_ids[0] == undef) {
            $downtime_ids[0] = -1;
        } elsif ($downtime_ids[0] == undef or scalar(@downtime_ids) == 0) {
            splice (@downtime_ids, 0, 1);
        }

        my $downtime_op = '>=';
        my $downtime_count = scalar(@downtime_ids);

        $c->stash->{downtime_filter_count} = $downtime_count;

        push @hostfilter,          { -or => [ downtimes => { $downtime_op => \@downtime_ids } ]};
        push @servicefilter,       { -or => [ host_downtimes => { $downtime_op => \@downtime_ids }, downtimes => { $downtime_op => \@downtime_ids } ]};
    }

    return(\@hostfilter, \@servicefilter);
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
