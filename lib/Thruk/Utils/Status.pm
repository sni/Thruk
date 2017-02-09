package Thruk::Utils::Status;

=head1 NAME

Thruk::Utils::Status - Status Utilities Collection for Thruk

=head1 DESCRIPTION

Status Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Carp qw/confess/;

##############################################

=head1 METHODS

=head2 set_default_stash

  set_default_stash($c)

sets some default stash variables

=cut
sub set_default_stash {
    my( $c ) = @_;

    $c->stash->{'hoststatustypes'}      = Thruk::Utils::Filter::escape_html($c->req->parameters->{'hoststatustypes'}    || '');
    $c->stash->{'hostprops'}            = Thruk::Utils::Filter::escape_html($c->req->parameters->{'hostprops'}          || '');
    $c->stash->{'servicestatustypes'}   = Thruk::Utils::Filter::escape_html($c->req->parameters->{'servicestatustypes'} || '');
    $c->stash->{'serviceprops'}         = Thruk::Utils::Filter::escape_html($c->req->parameters->{'serviceprops'}       || '');
    $c->stash->{'nav'}                  = Thruk::Utils::Filter::escape_html($c->req->parameters->{'nav'}                || '');
    $c->stash->{'entries'}              = Thruk::Utils::Filter::escape_html($c->req->parameters->{'entries'}            || '');
    $c->stash->{'sortoption'}           = Thruk::Utils::Filter::escape_html($c->req->parameters->{'sortoption'}         || '');
    $c->stash->{'sortoption_hst'}       = Thruk::Utils::Filter::escape_html($c->req->parameters->{'sortoption_hst'}     || '');
    $c->stash->{'sortoption_svc'}       = Thruk::Utils::Filter::escape_html($c->req->parameters->{'sortoption_svc'}     || '');
    $c->stash->{'hidesearch'}           = Thruk::Utils::Filter::escape_html($c->req->parameters->{'hidesearch'}         || 0);
    $c->stash->{'hostgroup'}            = Thruk::Utils::Filter::escape_html($c->req->parameters->{'hostgroup'}          || '');
    $c->stash->{'servicegroup'}         = Thruk::Utils::Filter::escape_html($c->req->parameters->{'servicegroup'}       || '');
    $c->stash->{'host'}                 = Thruk::Utils::Filter::escape_html($c->req->parameters->{'host'}               || '');
    $c->stash->{'service'}              = Thruk::Utils::Filter::escape_html($c->req->parameters->{'service'}            || '');
    $c->stash->{'data'}                = '';
    $c->stash->{'style'}                = '';
    $c->stash->{'has_error'}            = 0;
    $c->stash->{'pager'}                = '';
    $c->stash->{show_substyle_selector} = 1;
    $c->stash->{imgsize}                = 20;
    $c->stash->{'audiofile'}            = '';
    $c->stash->{'has_service_filter'}   = 0;

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

    unless ( $force || exists $c->req->parameters->{ $prefix . '_hoststatustypes' } ) {
        return;
    }

    # use the type or prop without prefix as global overide
    # ex.: hoststatustypes set from the totals link should override all filter
    my $search = {
        'hoststatustypes'    => $c->stash->{'hoststatustypes'}    || $c->req->parameters->{ $prefix . '_hoststatustypes' },
        'hostprops'          => $c->stash->{'hostprops'}          || $c->req->parameters->{ $prefix . '_hostprops' },
        'servicestatustypes' => $c->stash->{'servicestatustypes'} || $c->req->parameters->{ $prefix . '_servicestatustypes' },
        'serviceprops'       => $c->stash->{'serviceprops'}       || $c->req->parameters->{ $prefix . '_serviceprops' },
    };

    # store global searches, these will be added to our search
    my $globals = {
        'host'         => $c->stash->{'host'},
        'hostgroup'    => $c->stash->{'hostgroup'},
        'servicegroup' => $c->stash->{'servicegroup'},
        'service'      => $c->stash->{'service'},
    };

    if( defined $c->req->parameters->{ $prefix . '_type' } ) {
        if( ref $c->req->parameters->{ $prefix . '_type' } eq 'ARRAY' ) {
            for ( my $x = 0; $x < scalar @{ $c->req->parameters->{ $prefix . '_type' } }; $x++ ) {
                my $text_filter = {
                    val_pre => _is_defined($c->req->parameters->{ $prefix . '_val_pre' }->[$x], ''),
                    type    => _is_defined($c->req->parameters->{ $prefix . '_type' }->[$x],    ''),
                    value   => _is_defined($c->req->parameters->{ $prefix . '_value' }->[$x],   ''),
                    op      => _is_defined($c->req->parameters->{ $prefix . '_op' }->[$x],      ''),
                };
                if($text_filter->{'type'} eq 'business impact' and defined $c->req->parameters->{ $prefix . '_value_sel' }->[$x]) {
                    $text_filter->{'value'} = $c->req->parameters->{ $prefix . '_value_sel' }->[$x];
                }
                push @{ $search->{'text_filter'} }, $text_filter;
                if(defined $globals->{$text_filter->{type}} and $text_filter->{op} eq '=' and $text_filter->{value} eq $globals->{$text_filter->{type}}) { delete $globals->{$text_filter->{type}}; }
            }
        }
        else {
            my $text_filter = {
                val_pre => _is_defined($c->req->parameters->{ $prefix . '_val_pre' }, ''),
                type    => _is_defined($c->req->parameters->{ $prefix . '_type' },    ''),
                value   => _is_defined($c->req->parameters->{ $prefix . '_value' },   ''),
                op      => _is_defined($c->req->parameters->{ $prefix . '_op' },      ''),
            };
            if(defined $c->req->parameters->{ $prefix . '_value_sel'} and $text_filter->{'type'} eq 'business impact') {
                $text_filter->{'value'} = $c->req->parameters->{ $prefix . '_value_sel'};
            }
            push @{ $search->{'text_filter'} }, $text_filter;
            if(defined $globals->{$text_filter->{type}} and $text_filter->{op} eq '=' and $text_filter->{value} eq $globals->{$text_filter->{type}}) { delete $globals->{$text_filter->{type}}; }
        }
    }

    # add other filter
    for my $key (keys %{$globals}) {
        if(defined $globals->{$key} and $globals->{$key} ne '') {
            my $text_filter = {
                val_pre => '',
                type    => $key,
                value   => $globals->{$key},
                op      => '=',
            };
            push @{ $search->{'text_filter'} }, $text_filter;
        }
    }

    # put our default filter into the search box
    if($c->req->parameters->{'add_default_service_filter'}) {
        my $default_service_text_filter = set_default_filter($c);
        if($default_service_text_filter) {
            # not for service searches
            if(!defined $c->req->parameters->{'s0_value'} || $c->req->parameters->{'s0_value'} !~ m/^se:/mx) {
                unshift @{ $search->{'text_filter'} }, $default_service_text_filter;
            }
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

    # flag whether there are service only filters or not
    $c->stash->{'has_service_filter'} = 0;

    $prefix = 'dfl_' unless defined $prefix;

    unless ( exists $c->req->parameters->{$prefix.'s0_hoststatustypes'}
          or exists $c->req->parameters->{$prefix.'s0_type'}
          or exists $c->req->parameters->{'s0_hoststatustypes'}
          or exists $c->req->parameters->{'s0_type'}
          or exists $c->req->parameters->{'complex'} )
    {

        # classic search
        my $search;
        ( $search, $hostfilter, $servicefilter, $hostgroupfilter, $servicegroupfilter ) = Thruk::Utils::Status::classic_filter($c);

        # convert that into a new search
        push @{$searches}, $search;
    }
    else {

        if(   exists $c->req->parameters->{'s0_hoststatustypes'}
           or exists $c->req->parameters->{'s0_type'} ) {
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

=head2 reset_filter

  reset_filter($c)

reset filter from c->request->parameters

=cut
sub reset_filter {
    my($c) = @_;
    delete $c->stash->{'host'};
    delete $c->stash->{'hostgroup'};
    delete $c->stash->{'servicegroup'};
    delete $c->stash->{'service'};
    for my $key (keys %{$c->req->parameters}) {
        delete $c->req->parameters->{$key} if $key =~ m/^dfl_/mx;
        delete $c->req->parameters->{$key} if $key =~ m/^svc_/mx;
        delete $c->req->parameters->{$key} if $key =~ m/^hst_/mx;
    }
    return;
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
    my $host         = $c->req->parameters->{'host'}         || '';
    my $hostgroup    = $c->req->parameters->{'hostgroup'}    || '';
    my $servicegroup = $c->req->parameters->{'servicegroup'} || '';

    $c->stash->{'host'}         = $host         if defined $c->stash;
    $c->stash->{'hostgroup'}    = $hostgroup    if defined $c->stash;
    $c->stash->{'servicegroup'} = $servicegroup if defined $c->stash;

    my @hostfilter;
    my @hostgroupfilter;
    my @servicefilter;
    my @servicegroupfilter;
    if( $host ne 'all' and $host ne '' ) {
        # check for wildcards
        if( CORE::index( $host, '*' ) >= 0 ) {
            # convert wildcards into real regexp
            my $searchhost = $host;
            $searchhost = Thruk::Utils::convert_wildcards_to_regex($searchhost);
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
        $c->stash->{'has_service_filter'} = 1;
    }

    # apply default filter
    my $default_service_text_filter = set_default_filter($c, \@servicefilter);

    my $hostfilter         = Thruk::Utils::combine_filter( '-and', \@hostfilter );
    my $hostgroupfilter    = Thruk::Utils::combine_filter( '-or', \@hostgroupfilter );
    my $servicefilter      = Thruk::Utils::combine_filter( '-and', \@servicefilter );
    my $servicegroupfilter = Thruk::Utils::combine_filter( '-or', \@servicegroupfilter );

    # fill the host/service totals box
    unless($errors or $c->stash->{'minimal'}) {
        Thruk::Utils::Status::fill_totals_box( $c, $hostfilter, $servicefilter ) if defined $c->stash;
    }

    # then add some more filter based on get parameter
    my $hoststatustypes    = $c->req->parameters->{'hoststatustypes'};
    my $hostprops          = $c->req->parameters->{'hostprops'};
    my $servicestatustypes = $c->req->parameters->{'servicestatustypes'};
    my $serviceprops       = $c->req->parameters->{'serviceprops'};

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

    # put our default filter into the search box
    if($default_service_text_filter) {
        push @{ $search->{'text_filter'} }, $default_service_text_filter;
    }

    if( $host ne '' ) {
        push @{ $search->{'text_filter'} },
            {
            'val_pre' => '',
            'type'    => 'host',
            'value'   => $host,
            'op'      => '=',
            };
    }
    if ( $hostgroup ne '' ) {
        push @{ $search->{'text_filter'} },
            {
            'val_pre' => '',
            'type'    => 'hostgroup',
            'value'   => $hostgroup,
            'op'      => '=',
            };
    }
    if ( $servicegroup ne '' ) {
        push @{ $search->{'text_filter'} },
            {
            'val_pre' => '',
            'type'    => 'servicegroup',
            'value'   => $servicegroup,
            'op'      => '=',
            };
        $c->stash->{'has_service_filter'} = 1;
    }

    if($errors) {
        $c->stash->{'has_error'} = 1 if defined $c->stash;
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
    if(!$c->stash->{'has_error'} && (!$c->stash->{'minimal'} || $c->stash->{'play_sounds'}) && ( $prefix eq 'dfl_' or $prefix eq '')) {
        Thruk::Utils::Status::fill_totals_box( $c, $hosttotalsfilter, $servicetotalsfilter );
    }

    # if there is only one search with a single text filter
    # set stash to reflect a classic search
    if(     scalar @{$searches} == 1
        and scalar @{ $searches->[0]->{'text_filter'} } == 1
        and defined $searches->[0]->{'text_filter'}->[0]->{'op'}
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
    my( $c, $hostfilter, $servicefilter, $force ) = @_;

    return 1 if($c->stash->{'no_totals'} && !$force);

    # host status box
    my $host_stats    = {};
    my $service_stats = {};
    if((   defined $c->stash->{style} and $c->stash->{style} eq 'detail'
       or ( $c->stash->{'servicegroup'}
            and ( defined $c->stash->{style} and ($c->stash->{style} eq 'overview' or $c->stash->{style} eq 'grid' or $c->stash->{style} eq 'summary' ))
          ))
        and $servicefilter
      ) {
        # set host status from service query
        my $services = $c->{'db'}->get_hosts_by_servicequery( filter  => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ] );
        $service_stats = {
            'pending'                => 0,
            'ok'                     => 0,
            'warning'                => 0,
            'unknown'                => 0,
            'critical'               => 0,
            'warning_and_unhandled'  => 0,
            'critical_and_unhandled' => 0,
            'unknown_and_unhandled'  => 0,
        };
        $host_stats = {
            'pending'                   => 0,
            'up'                        => 0,
            'down'                      => 0,
            'unreachable'               => 0,
            'down_and_unhandled'        => 0,
            'unreachable_and_unhandled' => 0,
        };
        my %hosts;
        for my $service (@{$services}) {
            if($service->{'has_been_checked'} == 0) {
                $service_stats->{'pending'}++;
            } else {
                if($service->{'state'} == 0) {
                    $service_stats->{'ok'}++;
                }
                elsif($service->{'state'} == 1) {
                    $service_stats->{'warning'}++;
                    $service_stats->{'warning_and_unhandled'}++  if($service->{'scheduled_downtime_depth'} == 0 and $service->{'acknowledged'} == 0 and $service->{'host_scheduled_downtime_depth'} == 0 and $service->{'host_acknowledged'} == 0);
                }
                elsif($service->{'state'} == 2) {
                    $service_stats->{'critical'}++;
                    $service_stats->{'critical_and_unhandled'}++ if($service->{'scheduled_downtime_depth'} == 0 and $service->{'acknowledged'} == 0 and $service->{'host_scheduled_downtime_depth'} == 0 and $service->{'host_acknowledged'} == 0);
                }
                elsif($service->{'state'} == 3) {
                    $service_stats->{'unknown'}++;
                    $service_stats->{'unknown_and_unhandled'}++  if($service->{'scheduled_downtime_depth'} == 0 and $service->{'acknowledged'} == 0 and $service->{'host_scheduled_downtime_depth'} == 0 and $service->{'host_acknowledged'} == 0);
                }
            }
            next if defined $hosts{$service->{'host_name'}};
            $hosts{$service->{'host_name'}} = 1;

            if($service->{'host_has_been_checked'} == 0) {
                $host_stats->{'pending'}++;
            } else{
                if($service->{'host_state'} == 0) {
                    $host_stats->{'up'}++;
                }
                elsif($service->{'host_state'} == 1) {
                    $host_stats->{'down'}++;
                    $host_stats->{'down_and_unhandled'}++        if($service->{'host_scheduled_downtime_depth'} == 0 and $service->{'host_acknowledged'} == 0);
                }
                elsif($service->{'host_state'} == 2) {
                    $host_stats->{'unreachable'}++;
                    $host_stats->{'unreachable_and_unhandled'}++ if($service->{'host_scheduled_downtime_depth'} == 0 and $service->{'host_acknowledged'} == 0);
                }

            }
        }
    } else {
        $host_stats    = $c->{'db'}->get_host_totals_stats(    filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ),    $hostfilter    ] );
        $service_stats = $c->{'db'}->get_service_totals_stats( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ] );
    }
    $c->stash->{'host_stats'}    = $host_stats;
    $c->stash->{'service_stats'} = $service_stats;

    # set audio file to play
    Thruk::Utils::Status::set_audio_file($c);

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

    $c->stash->{'show_filter_table'} = 0 if defined $c->stash;

    # host statustype filter (up,down,...)
    my( $host_statustype_filtername, $host_statustype_filter, $host_statustype_filter_service );
    ( $hoststatustypes, $host_statustype_filtername, $host_statustype_filter, $host_statustype_filter_service )
        = Thruk::Utils::Status::get_host_statustype_filter($hoststatustypes);
    push @hostfilter,    $host_statustype_filter         if defined $host_statustype_filter;
    push @servicefilter, $host_statustype_filter_service if defined $host_statustype_filter_service;

    $c->stash->{'show_filter_table'} = 1 if defined $host_statustype_filter and  defined $c->stash;

    # host props filter (downtime, acknowledged...)
    my( $host_prop_filtername, $host_prop_filter, $host_prop_filter_service );
    ( $hostprops, $host_prop_filtername, $host_prop_filter, $host_prop_filter_service )
        = Thruk::Utils::Status::get_host_prop_filter($hostprops);
    push @hostfilter,    $host_prop_filter         if defined $host_prop_filter;
    push @servicefilter, $host_prop_filter_service if defined $host_prop_filter_service;

    $c->stash->{'show_filter_table'} = 1 if defined $host_prop_filter and  defined $c->stash;

    # service statustype filter (ok,warning,...)
    my( $service_statustype_filtername, $service_statustype_filter_service );
    ( $servicestatustypes, $service_statustype_filtername, $service_statustype_filter_service )
        = Thruk::Utils::Status::get_service_statustype_filter($servicestatustypes, $c);
    push @servicefilter, $service_statustype_filter_service if defined $service_statustype_filter_service;

    $c->stash->{'show_filter_table'} = 1 if defined $service_statustype_filter_service and  defined $c->stash;

    # service props filter (downtime, acknowledged...)
    my( $service_prop_filtername, $service_prop_filter_service );
    ( $serviceprops, $service_prop_filtername, $service_prop_filter_service )
        = Thruk::Utils::Status::get_service_prop_filter($serviceprops, $c);
    push @servicefilter, $service_prop_filter_service if defined $service_prop_filter_service;

    $c->stash->{'show_filter_table'} = 1 if defined $service_prop_filter_service and  defined $c->stash;

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
    for my $filter ( @{ $search->{'text_filter'} } ) {

        # resolve search prefix
        if($filter->{'type'} eq 'search' and $filter->{'value'} =~ m/^(ho|hg|se|sg):/mx) {
            if($1 eq 'ho') { $filter->{'type'} = 'host';         }
            if($1 eq 'hg') { $filter->{'type'} = 'hostgroup';    }
            if($1 eq 'se') { $filter->{'type'} = 'service';      }
            if($1 eq 'sg') { $filter->{'type'} = 'servicegroup'; }
            $filter->{'value'} = substr($filter->{'value'}, 3);
            $filter->{'op'}    = '=';
        }

        my $value  = $filter->{'value'};

        # skip most empty filter
        # 2010-10-25: 3bc748da2 - fixes "livestatus: Sorry, Operator 4 for lists not implemented" error with blank searches
        # 2016-10-14: cannot reproduce anymore, blank searches do what they should do
        #if(    $value =~ m/^\s*$/mx
        #   and $filter->{'type'} ne 'next check'
        #   and $filter->{'type'} ne 'last check'
        #   and $filter->{'type'} ne 'event handler'
        #) {
        #    next;
        #}

        my $op     = '=';
        my $rop    = '=';
        my $listop = '>=';
        my $dateop = '=';
        my $joinop = "-or";
        if( $filter->{'op'} eq '!~' ) { $op = '!~~'; $joinop = "-and"; $listop = '!>='; }
        if( $filter->{'op'} eq '~'  ) { $op = '~~'; }
        if( $filter->{'op'} eq '!=' ) { $op = '!='; $joinop = "-and"; $listop = '!>='; $dateop = '!='; }
        if( $filter->{'op'} eq '>=' ) { $op = '>='; $rop = '<='; $dateop = '>='; }
        if( $filter->{'op'} eq '<=' ) { $op = '<='; $rop = '>='; $dateop = '<='; }

        if( $op eq '!~~' or $op eq '~~' ) {
            $errors++ unless Thruk::Utils::is_valid_regular_expression( $c, $value );
        }

        if( $op eq '=' and $value eq 'all' ) {
            # add a useless filter
            if( $filter->{'type'} eq 'host' ) {
                push @hostfilter, { name => { '!=' => undef } };
                next;
            }
            elsif ( $filter->{'type'} eq 'hostgroup' ) {
                push @hostgroupfilter, { name => { '!=' => undef } };
                next;
            }
            elsif ( $filter->{'type'} eq 'servicegroup' ) {
                push @servicegroupfilter, { name => { '!=' => undef } };
                $c->stash->{'has_service_filter'} = 1;
                next;
            }
        }

        if ( $filter->{'type'} eq 'search' ) {
            # skip empty searches
            next if $value eq '';

            my($hfilter, $sfilter) = Thruk::Utils::Status::get_comments_filter($c, $op, $value);

            my $host_search_filter = [ { name               => { $op     => $value } },
                                       { display_name       => { $op     => $value } },
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
                                          { display_name       => { $op     => $value } },
                                          { groups             => { $listop => $value } },
                                          { plugin_output      => { $op     => $value } },
                                          { long_plugin_output => { $op     => $value } },
                                          { host_name          => { $op     => $value } },
                                          { host_display_name  => { $op     => $value } },
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
                $searchhost = Thruk::Utils::convert_wildcards_to_regex($searchhost);
                push @hostfilter,          { -or => [ name      => { '~~' => $searchhost }, alias      => { '~~' => $searchhost }, address      => { '~~' => $searchhost }, display_name      => { '~~' => $searchhost } ] };
                push @hosttotalsfilter,    { -or => [ name      => { '~~' => $searchhost }, alias      => { '~~' => $searchhost }, address      => { '~~' => $searchhost }, display_name      => { '~~' => $searchhost } ] };
                push @servicefilter,       { -or => [ host_name => { '~~' => $searchhost }, host_alias => { '~~' => $searchhost }, host_address => { '~~' => $searchhost }, host_display_name => { '~~' => $searchhost } ] };
                push @servicetotalsfilter, { -or => [ host_name => { '~~' => $searchhost }, host_alias => { '~~' => $searchhost }, host_address => { '~~' => $searchhost }, host_display_name => { '~~' => $searchhost } ] };
            }
            else {
                push @hostfilter,          { $joinop => [ name      => { $op => $value }, alias      => { $op => $value }, address      => { $op => $value }, display_name      => { $op => $value } ] };
                push @hosttotalsfilter,    { $joinop => [ name      => { $op => $value }, alias      => { $op => $value }, address      => { $op => $value }, display_name      => { $op => $value } ] };
                push @servicefilter,       { $joinop => [ host_name => { $op => $value }, host_alias => { $op => $value }, host_address => { $op => $value }, host_display_name => { $op => $value } ] };
                push @servicetotalsfilter, { $joinop => [ host_name => { $op => $value }, host_alias => { $op => $value }, host_address => { $op => $value }, host_display_name => { $op => $value } ] };
            }
        }
        elsif ( $filter->{'type'} eq 'service' ) {
            push @servicefilter,       { $joinop => [ description => { $op => $value }, display_name => { $op => $value } ] };
            push @servicetotalsfilter, { $joinop => [ description => { $op => $value }, display_name => { $op => $value } ] };
            $c->stash->{'has_service_filter'} = 1;
        }
        elsif ( $filter->{'type'} eq 'hostgroup' ) {
            if($op eq '~~' or $op eq '!~~') {
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
            if($op eq '~~' or $op eq '!~~') {
                my($hfilter, $sfilter) = Thruk::Utils::Status::get_groups_filter($c, $op, $value, 'servicegroup');
                push @servicefilter,       $sfilter;
                push @servicetotalsfilter, $sfilter;
            } else {
                push @servicefilter,       { groups => { $listop => $value } };
                push @servicetotalsfilter, { groups => { $listop => $value } };
            }
            push @servicegroupfilter,  { name   => { $op     => $value } };
            $c->stash->{'has_service_filter'} = 1;
        }
        elsif ( $filter->{'type'} eq 'contact' ) {
            if($op eq '~~' or $op eq '!~~') {
                my($hfilter, $sfilter) = Thruk::Utils::Status::get_groups_filter($c, $op, $value, 'contacts');
                push @hostfilter,          $hfilter;
                push @hosttotalsfilter,    $hfilter;
                push @servicefilter,       $sfilter;
                push @servicetotalsfilter, $sfilter;
            } else {
                push @hostfilter,          { contacts => { $listop => $value } };
                push @hosttotalsfilter,    { contacts => { $listop => $value } };
                push @servicefilter,       { contacts => { $listop => $value } };
                push @servicetotalsfilter, { contacts => { $listop => $value } };
            }
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
        elsif ( $filter->{'type'} eq 'number of services' ) {
            push @hostfilter,    { num_services => { $op => $value } };
            push @servicefilter, { host_num_services => { $op => $value } };
        }
        elsif ( $filter->{'type'} eq 'latency' ) {
            push @hostfilter,    { latency => { $op => $value } };
            push @servicefilter, { latency => { $op => $value } };
        }
        elsif ( $filter->{'type'} eq 'execution time' ) {
            $value = Thruk::Utils::Status::convert_time_amount($value);
            push @hostfilter,    { execution_time => { $op => $value } };
            push @servicefilter, { execution_time => { $op => $value } };
        }
        elsif ( $filter->{'type'} eq '% state change' ) {
            push @hostfilter,    { percent_state_change => { $op => $value } };
            push @servicefilter, { percent_state_change => { $op => $value } };
        }
        elsif ( $filter->{'type'} eq 'current attempt' ) {
            push @hostfilter,    { current_attempt => { $op => $value } };
            push @servicefilter, { current_attempt => { $op => $value } };
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
        elsif ( $filter->{'type'} eq 'plugin output' ) {
            my $cop = '-or';
            if($op eq '!=' or $op eq '!~~') { $cop = '-and' }
            push @hostfilter,    { $cop => [ plugin_output => { $op => $value }, long_plugin_output => { $op => $value } ] };
            push @servicefilter, { $cop => [ plugin_output => { $op => $value }, long_plugin_output => { $op => $value } ] };
        }
        elsif ( $filter->{'type'} eq 'event handler' ) {
            push @hostfilter,    { event_handler => { $op => $value } };
            push @servicefilter, { event_handler => { $op => $value } };
        }
        # Root Problems are only available in Shinken
        elsif ( $filter->{'type'} eq 'rootproblem' && $c->stash->{'enable_shinken_features'}) {
            next unless $c->stash->{'enable_shinken_features'};
            push @hostfilter,          { source_problems      => { $listop => $value } };
            push @hosttotalsfilter,    { source_problems      => { $listop => $value } };
            push @servicefilter,       { source_problems      => { $listop => $value } };
            push @servicetotalsfilter, { source_problems      => { $listop => $value } };
        }
        # Impacts are only available in Shinken
        elsif ( $filter->{'type'} eq 'impact' && $c->stash->{'enable_shinken_features'}) {
            next unless $c->stash->{'enable_shinken_features'};
            push @hostfilter,          { impacts      => { $listop => $value } };
            push @hosttotalsfilter,    { impacts      => { $listop => $value } };
            push @servicefilter,       { impacts      => { $listop => $value } };
            push @servicetotalsfilter, { impacts      => { $listop => $value } };
        }
        # Business Impact (criticity) is only available in Shinken
        elsif ( $filter->{'type'} eq 'business impact' || $filter->{'type'} eq 'priority' ) {
            next unless $c->stash->{'enable_shinken_features'};
            # value has to be numeric, otherwise shinken breaks
            $value =~ s/[^\d]//gmx; $value = 0 unless $value;
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
            $value                 = Thruk::Utils::Status::convert_time_amount($value);
            my($hfilter, $sfilter) = Thruk::Utils::Status::get_downtimes_filter($c, $op, $value);
            push @hostfilter,          $hfilter;
            push @servicefilter,       $sfilter;
        }
        elsif ( $filter->{'type'} eq 'duration' ) {
            my $now = time();
            $value = Thruk::Utils::Status::convert_time_amount($value);
            if(    ($op eq '>=' and ($now - $c->stash->{'last_program_restart'}) >= $value)
                or ($op eq '<=' and ($now - $c->stash->{'last_program_restart'}) <= $value)
                or ($op eq '!=' and ($now - $c->stash->{'last_program_restart'}) != $value)
                or ($op eq '='  and ($now - $c->stash->{'last_program_restart'}) == $value)
               ) {
                push @hostfilter,    { -or => [{ -and => [ last_state_change => { '!=' => 0 },
                                                          last_state_change => { $rop => $now - $value },
                                                        ],
                                              },
                                              { last_state_change => { '=' => 0 } },
                                              ],
                                     };
                push @servicefilter, { -or => [{ -and => [ last_state_change => { '!=' => 0 },
                                                          last_state_change => { $rop => $now - $value },
                                                        ],
                                              },
                                              { last_state_change => { '=' => 0 } },
                                              ],
                                     };
            } else {
                push @hostfilter,    { -and => [ last_state_change => { '!=' => 0 },
                                                 last_state_change => { $rop => $now - $value },
                                               ],
                                     };
                push @servicefilter, { -and => [ last_state_change => { '!=' => 0 },
                                                 last_state_change => { $rop => $now - $value },
                                               ],
                                     };
            }
        }
        elsif ( $filter->{'type'} eq 'notification period' ) {
            push @hostfilter,    { notification_period => { $op => $value } };
            push @servicefilter, { notification_period => { $op => $value } };
        }
        elsif ( $filter->{'type'} eq 'custom variable' ) {
            my $pre = uc($filter->{'val_pre'});
            if(substr($pre, 0, 1) eq '_') { $pre = substr($pre, 1); }
            push @hostfilter,    { custom_variables => { $op => $pre." ".$value } };
            my $cop = '-or';
            if($op eq '!=')  { $cop = '-and' }
            if($op eq '!~~') { $cop = '-and' }
            push @servicefilter, { $cop => [ host_custom_variables => { $op => $pre." ".$value },
                                                  custom_variables => { $op => $pre." ".$value },
                                          ],
                                 };
        }
        else {
            if($filter->{'type'} ne '') {
                confess( "unknown filter: " . $filter->{'type'} );
            }
        }
    }

    # combine the array of filters by AND
    my $hostfilter          = Thruk::Utils::combine_filter( '-and', \@hostfilter );
    my $servicefilter       = Thruk::Utils::combine_filter( '-and', \@servicefilter );
    my $hostgroupfilter     = Thruk::Utils::combine_filter( '-or', \@hostgroupfilter );
    my $servicegroupfilter  = Thruk::Utils::combine_filter( '-or', \@servicegroupfilter );
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

    $number = 15 if !defined $number || $number !~ m/^\d+$/mx || $number <= 0 || $number > 15;
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

    $number = 0 if !defined $number || $number !~ m/^\d+$/mx || $number <= 0 || $number > 67108863;
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
    my( $number, $c ) = @_;

    my @servicestatusfilter;
    my @servicestatusfiltername;

    $number = 31 if !defined $number || $number !~ m/^\d+$/mx || $number <= 0 || $number > 31;
    my $servicestatusfiltername = 'All';
    if( $number and $number != 31 ) {
        $c->stash->{'has_service_filter'} = 1 if $c;
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
    my( $number, $c ) = @_;

    my @service_prop_filter;
    my @service_prop_filtername;

    $number = 0 if !defined $number || $number !~ m/^\d+$/mx || $number <= 0 || $number > 67108863;
    my $service_prop_filtername = 'Any';
    if( $number > 0 ) {
        $c->stash->{'has_service_filter'} = 1 if $c;
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
            push @hostfilter,          { -and => [ comments => { $op => undef }, downtimes => { $op => undef } ]};
            push @servicefilter,       { -and => [ comments => { $op => undef }, downtimes => { $op => undef } ]};
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
        my $combine    = '-and';
        if($op eq '=' or $op eq '~~') {
            $comment_op = '>=';
            $combine    = '-or';
        }
        push @hostfilter,          { $combine => [ comments => { $comment_op => \@comment_ids }, downtimes => { $comment_op => \@downtime_ids } ]};
        push @servicefilter,       { $combine => [ host_comments => { $comment_op => \@comment_ids }, host_downtimes => { $comment_op => \@downtime_ids }, comments => { $comment_op => \@comment_ids }, downtimes => { $comment_op => \@downtime_ids } ]};
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

    my @names;
    if($c->stash->{'cache_groups_filter'}) {
        my $cache = $c->stash->{'cache_groups_filter'};
        if($type eq 'hostgroup') {
            $cache->{$type} = $c->{'db'}->get_hostgroup_names() unless defined $cache->{$type};
        }
        elsif($type eq 'servicegroup') {
            $cache->{$type} = $c->{'db'}->get_servicegroup_names() unless defined $cache->{$type};
        }
        elsif($type eq 'contacts') {
            $cache->{$type} = $c->{'db'}->get_contact_names() unless defined $cache->{$type};
        }
        ## no critic
        @names = grep(/$value/i, @{$cache->{$type}});
        ## use critic
        if(scalar @names == 0) { @names = (''); }
    } else {
        my $groups;
        if($type eq 'hostgroup') {
            $groups = $c->{'db'}->get_hostgroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ), { name => { '~~' => $value }} ], columns => ['name'] );
        }
        elsif($type eq 'servicegroup') {
            $groups = $c->{'db'}->get_servicegroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'servicegroups' ), { name => { '~~' => $value }} ], columns => ['name'] );
        }
        elsif($type eq 'contacts') {
            $groups = $c->{'db'}->get_contacts( filter => [ { name => { '~~' => $value }} ], columns => ['name'] );
        }
        @names = sort keys %{ Thruk::Utils::array2hash([@{$groups}], 'name') };
        if(scalar @names == 0) { @names = (''); }
    }

    my $group_op = '!>=';
    if($op eq '=' or $op eq '~~') {
        $group_op = '>=';
    }

    if($type eq 'hostgroup') {
        push @hostfilter,    { -or => { groups      => { $group_op => \@names } } };
        push @servicefilter, { -or => { host_groups => { $group_op => \@names } } };
    }
    elsif($type eq 'contacts') {
        push @hostfilter,    { -or => { contacts => { $group_op => \@names } } };
        push @servicefilter, { -or => { contacts => { $group_op => \@names } } };
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

    for my $prefix ('', 'host_', 'service_') {
        my $columns = {};
        my $last_col = 50;
        for my $x (0..50) { $columns->{$x} = 1; }
        if(defined $c->req->parameters->{$prefix.'columns'}) {
            $last_col = 0;
            for my $x (0..50) { $columns->{$x} = 0; }
            my $cols = $c->req->parameters->{$prefix.'columns'};
            for my $nr (ref $cols eq 'ARRAY' ? @{$cols} : ($cols)) {
                $columns->{$nr} = 1;
                $last_col++;
            }
        }
        $c->stash->{$prefix.'last_col'} = chr(65+$last_col-1);
        $c->stash->{$prefix.'columns'}  = $columns;
    }
    return;
}


##############################################

=head2 set_custom_title

  set_custom_title($c)

sets page title based on http parameters

=cut
sub set_custom_title {
    my($c) = @_;
    $c->stash->{custom_title} = '';
    if( exists $c->req->parameters->{'title'} ) {
        my $custom_title          = $c->req->parameters->{'title'};
        if(ref $custom_title eq 'ARRAY') { $custom_title = pop @{$custom_title}; }
        $custom_title             =~ s/\+/\ /gmx;
        $c->stash->{custom_title} = Thruk::Utils::Filter::escape_html($custom_title);
        $c->stash->{title}        = $custom_title;
        return 1;
    }
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
    my $uri = $c->req->url();
    my $old = 'status.cgi';
    if($uri =~ m/\/cgi\-bin\/(.*?\.cgi)/mx) {
        $old = $1;
    }

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
    return $c->redirect_to($uri);
}

##############################################

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

##############################################

=head2 convert_time_amount

  convert_time_amount($value)

returns converted amount of time

possible conversions are
1w => 604800
1d => 86400
1h => 3600
1m => 60

=cut
sub convert_time_amount {
    my $value = shift;
    if($value =~ m/^(\d+)(y|w|d|h|m|s)/gmx) {
        if($2 eq 'y') { return $1 * 86400*365; }# year
        if($2 eq 'w') { return $1 * 86400*7; }  # weeks
        if($2 eq 'd') { return $1 * 86400; }    # days
        if($2 eq 'h') { return $1 * 3600; }     # hours
        if($2 eq 'm') { return $1 * 60; }       # minutes
        if($2 eq 's') { return $1 }             # seconds
    }
    return $value;
}

##############################################

=head2 set_audio_file

  set_audio_file($c)

set if browser should play a sound file

=cut
sub set_audio_file {
    my( $c ) = @_;

    return unless $c->stash->{'play_sounds'};

    # pages with host/service totals
    if(defined $c->stash->{'host_stats'} and defined $c->stash->{'service_stats'}) {
        for my $s (qw/unreachable down/) {
            if($c->stash->{'host_stats'}->{$s.'_and_unhandled'} > 0 and defined $c->config->{'cgi_cfg'}->{'host_'.$s.'_sound'}) {
                $c->stash->{'audiofile'} = $c->config->{'cgi_cfg'}->{'host_'.$s.'_sound'};
                return;
            }
        }
        for my $s (qw/critical warning unknown/) {
            if($c->stash->{'service_stats'}->{$s.'_and_unhandled'} > 0 and defined $c->config->{'cgi_cfg'}->{'service_'.$s.'_sound'}) {
                $c->stash->{'audiofile'} = $c->config->{'cgi_cfg'}->{'service_'.$s.'_sound'};
                return;
            }
        }
    }

    # get state from hosts and services (combined pages)
    elsif(defined $c->stash->{'hosts'} and defined $c->stash->{'services'}) {
        my $worst_host = 0;
        for my $h (@{$c->stash->{'hosts'}}) {
            next if $h->{'scheduled_downtime_depth'} >= 1;
            next if $h->{'acknowledged'} == 1;
            next if $h->{'notifications_enabled'} == 0;
            $worst_host = $h->{'state'} if $worst_host < $h->{'state'};
            last if $worst_host >= 2;
        }
        if($worst_host == 2 and defined $c->config->{'cgi_cfg'}->{'host_unreachable_sound'}) {
            $c->stash->{'audiofile'} = $c->config->{'cgi_cfg'}->{'host_unreachable_sound'};
            return;
        }
        if($worst_host == 1 and defined $c->config->{'cgi_cfg'}->{'host_down_sound'}) {
            $c->stash->{'audiofile'} = $c->config->{'cgi_cfg'}->{'host_down_sound'};
            return;
        }

        my $worst_service = 0;
        for my $s (@{$c->stash->{'services'}}) {
            next if $s->{'scheduled_downtime_depth'} >= 1;
            next if $s->{'acknowledged'} == 1;
            next if $s->{'notifications_enabled'} == 0;
            next if $s->{'state'} == 4;
            $worst_service = $s->{'state'} if $worst_service < $s->{'state'};
            last if $worst_service == 3;
        }
        if($worst_service == 1 and defined $c->config->{'cgi_cfg'}->{'service_warning_sound'}) {
            $c->stash->{'audiofile'} = $c->config->{'cgi_cfg'}->{'service_warning_sound'};
            return;
        }
        if($worst_service == 2 and defined $c->config->{'cgi_cfg'}->{'service_critical_sound'}) {
            $c->stash->{'audiofile'} = $c->config->{'cgi_cfg'}->{'service_critical_sound'};
            return;
        }
        if($worst_service == 3 and defined $c->config->{'cgi_cfg'}->{'service_unknown_sound'}) {
            $c->stash->{'audiofile'} = $c->config->{'cgi_cfg'}->{'service_unknown_sound'};
            return;
        }
    }

    if($c->stash->{'audiofile'} eq '' and defined $c->config->{'cgi_cfg'}->{'normal_sound'}) {
        $c->stash->{'audiofile'} = $c->config->{'cgi_cfg'}->{'normal_sound'};
        return;
    }

    return;
}

##############################################

=head2 set_favicon_counter

  set_favicon_counter($c)

set favicon counter

=cut
sub set_favicon_counter {
    my( $c ) = @_;

    my($total_red, $total_yellow, $total_orange) = (0,0,0);

    # pages with host/service totals
    if(defined $c->stash->{'host_stats'} and defined $c->stash->{'service_stats'}) {
        $total_red    =   $c->stash->{'host_stats'}->{'down'}
                        + $c->stash->{'host_stats'}->{'unreachable'}
                        + $c->stash->{'service_stats'}->{'critical'};
        $total_yellow = $c->stash->{'service_stats'}->{'warning'};
        $total_orange = $c->stash->{'service_stats'}->{'unknown'};
    }

    # get state from hosts and services (combined pages)
    elsif(defined $c->stash->{'hosts'} and defined $c->stash->{'services'}) {
        for my $h (@{$c->stash->{'hosts'}}) {
            if($h->{'state'} != 0) { $total_red++ }
        }

        for my $s (@{$c->stash->{'services'}}) {
            if($s->{'state'} == 1) { $total_yellow++; }
            if($s->{'state'} == 2) { $total_red++; }
            if($s->{'state'} == 3) { $total_orange++; }
        }
    }

    my $totals = {
            'red'    => $total_red,
            'yellow' => $total_yellow,
            'orange' => $total_orange,
    };

    return $totals;
}

##############################################

=head2 get_service_matrix

  get_service_matrix($c, [$hostfilter], [$servicefilter])

get matrix of services usable by a minemap

=cut
sub get_service_matrix {
    my( $c, $hostfilter, $servicefilter) = @_;

    $c->stats->profile(begin => "Status::get_service_matrix()");

    my $uniq_hosts = {};

    if(defined $servicefilter) {
        # fetch hostnames first
        my $hostnames = $c->{'db'}->get_hosts_by_servicequery( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $servicefilter ], columns => ['host_name'] );
        for my $svc (@{$hostnames}) {
            $uniq_hosts->{$svc->{'host_name'}} = 1;
        }
    } else {
        # fetch hostnames first
        my $hostnames = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), $hostfilter ], columns => ['name'] );

        # get pages hosts
        for my $hst (@{$hostnames}) {
            $uniq_hosts->{$hst->{'name'}} = 1;
        }
    }

    my @keys = sort keys %{$uniq_hosts};
    Thruk::Backend::Manager::_page_data(undef, $c, \@keys);
    @keys = (); # empty
    my $filter = [];
    for my $host_name (@{$c->stash->{'data'}}) {
        push @{$filter}, { 'host_name' => $host_name };
    }
    $hostfilter = Thruk::Utils::combine_filter( '-or', $filter );
    my $combined_filter = $hostfilter;
    if($servicefilter) {
        $combined_filter = Thruk::Utils::combine_filter( '-and', [ $servicefilter, $hostfilter ] );
    }

    my $extra_columns = [];
    if($c->config->{'use_lmd_core'} && $c->stash->{'show_long_plugin_output'} ne 'inline') {
        push @{$extra_columns}, 'has_long_plugin_output';
    } else {
        push @{$extra_columns}, 'long_plugin_output';
    }

    # get real services
    my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), $combined_filter], extra_columns => $extra_columns );

    # build matrix
    my $matrix        = {};
    my $uniq_services = {};
    my $hosts         = {};
    for my $svc (@{$services}) {
        next unless defined $uniq_hosts->{$svc->{'host_name'}};
        $uniq_services->{$svc->{'description'}} = 1;
        $hosts->{$svc->{'host_name'}} = $svc;
        $matrix->{$svc->{'host_name'}}->{$svc->{'description'}} = $svc;
    }

    $c->stats->profile(end => "Status::get_service_matrix()");

    return($uniq_services, $hosts, $matrix);
}

##############################################

=head2 serveraction

  serveraction($c)

run server action from custom action menu

=cut
sub serveraction {
    my($c, $macros) = @_;
    $macros = {} unless defined $macros;

    return(1, 'invalid request') unless Thruk::Utils::check_csrf($c);

    my $host    = $c->req->parameters->{'host'};
    my $service = $c->req->parameters->{'service'};
    my $link    = $c->req->parameters->{'link'};
    my $action;

    if($link =~ m/^server:\/\/(.*)$/mx) {
        $action = $1;
    } else {
        return(1, 'not a valid customaction url');
    }

    $c->log->debug('running server action: '.$action.' for user '.$c->stash->{'remote_user'});

    my @args = split(/\//mx, $action);
    $action = shift @args;
    if(!defined $c->config->{'action_menu_actions'}->{$action}) {
        return(1, 'customaction '.$action.' is not defined');
    }
    my @cmdline = split(/\s+/mx, $c->config->{'action_menu_actions'}->{$action});
    my $cmd = shift @cmdline;
    # expand ~ in $cmd
    my @cmd = glob($cmd);
    if($cmd[0]) { $cmd = $cmd[0]; }
    $c->log->debug('raw cmd line: '.$cmd.' "'.(join('" "', @cmdline)).'"');
    if(!-x $cmd) {
        return(1, $cmd.' is not executable');
    }

    # replace macros
    my $obj;
    if($host || $service) {
        my $objs;
        if($service) {
            $objs = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { host_name => $host, description => $service } ] );
        } else {
            $objs = $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), { name => $host } ] );
        }
        $obj = $objs->[0];
        return(1, 'no such object') unless $obj;
    }

    %{$macros} = (%{$macros}, %{$c->{'db'}->get_macros({host => $obj, service => $service ? $obj : undef, filter_user => 0})});
    $macros->{'$REMOTE_USER$'}    = $c->stash->{'remote_user'};
    $macros->{'$DASHBOARD_ID$'}   = $c->req->parameters->{'dashboard'} if $c->req->parameters->{'dashboard'};
    $macros->{'$DASHBOARD_ICON$'} = $c->req->parameters->{'icon'}      if $c->req->parameters->{'icon'};
    for my $arg (@cmdline, @args) {
        my $rc;
        ($arg, $rc) = $c->{'db'}->replace_macros($arg, {}, $macros);
    }
    $c->log->debug('parsed cmd line: '.$cmd.' "'.(join('" "', @cmdline)).'"');

    my($rc, $output);
    eval {
        ($rc, $output) = Thruk::Utils::IO::cmd($c, [$cmd, @cmdline, @args]);
    };
    if($@) {
        return('1', $@);
    }
    return($rc, $output);
}

##############################################

=head2 set_default_filter

  set_default_filter($c, [$servicefilter])

checks if a global default service should be users. Returns textfilter
and optionally adds that filter to a list of servicefilters.

=cut
sub set_default_filter {
    my($c, $servicefilter ) = @_;
    return unless $c->config->{'default_service_filter'};
    my $default_service_filter_op  = '~';
    my $default_service_filter_val = $c->config->{'default_service_filter'};
    if($default_service_filter_val =~ m/^\!(.*)$/mx) {
        $default_service_filter_op  = '!~';
        $default_service_filter_val = $1;
    }
    if($servicefilter) {
        push @{$servicefilter}, [ { 'description' => { $default_service_filter_op.'~' => $default_service_filter_val } } ];
    }
    my $default_service_text_filter = {
            'val_pre' => '',
            'type'    => 'service',
            'value'   => $default_service_filter_val,
            'op'      => $default_service_filter_op,
    };
    return($default_service_text_filter);
}

##############################################
sub _is_defined {
    my($a, $b) = @_;
    return $a if defined $a;
    return $b;
}

##############################################

=head2 get_host_columns

  get_host_columns($c)

returns list of host columns

=cut
sub get_host_columns {
    my($c) = @_;

    my $columns = [];
    if($c->stash->{'show_backends_in_table'} == 2) {
        push @{$columns},
        { title => "Site",                 "field" => "peer_name",            "checked" => 1 };
    }
    push @{$columns}, (
        { title => "Host",                 "field" => "name",                 "checked" => 1 },
        { title => "Status",               "field" => "state",                "checked" => 1 },
        { title => "Last Check",           "field" => "last_check",           "checked" => 1 },
        { title => "Duration",             "field" => "duration",             "checked" => 1 },
    );
    if($c->stash->{'show_host_attempts'}) {
        push @{$columns},
        { title => "Attempt",              "field" => "current_attempt",      "checked" => 1 };
    }
    if($c->stash->{'show_backends_in_table'} == 1) {
        push @{$columns},
        { title => "Site",                 "field" => "peer_name",            "checked" => 1 };
    }
    push @{$columns}, (
        { title => "Status Information",   "field" => "plugin_output",        "checked" => 1 },
    );
    if(!$c->stash->{'show_backends_in_table'}) {
        push @{$columns},
        { title => "Site",                 "field" => "peer_name",            "checked" => 0 };
    }
    if(!$c->stash->{'show_host_attempts'}) {
        push @{$columns},
        { title => "Attempt",              "field" => "current_attempt",      "checked" => 0 };
    }
    push @{$columns}, (
        { title => "Address",              "field" => "address",              "checked" => 0 },
        { title => "Check Command",        "field" => "check_command",        "checked" => 0 },
        { title => "Check Interval",       "field" => "check_interval",       "checked" => 0 },
        { title => "Check Period",         "field" => "check_period",         "checked" => 0 },
        { title => "Contacts",             "field" => "contacts",             "checked" => 0 },
        { title => "Comments",             "field" => "comments",             "checked" => 0 },
        { title => "Event Handler",        "field" => "event_handler",        "checked" => 0 },
        { title => "Execution Time",       "field" => "execution_time",       "checked" => 0 },
        { title => "Groups",               "field" => "groups",               "checked" => 0 },
        { title => "Latency",              "field" => "latency",              "checked" => 0 },
        { title => "Next Check",           "field" => "next_check",           "checked" => 0 },
        { title => "Notification Period",  "field" => "notification_period",  "checked" => 0 },
        { title => "Percent State Change", "field" => "percent_state_change", "checked" => 0 },
    );
    if($c->config->{'show_custom_vars'}) {
        for my $var (@{$c->config->{'show_custom_vars'}}) {
            push @{$columns},
            { title => $var,               "field" => "cust_".$var,           "checked" => 0 };
        }
    }

    my @selected;
    for my $col (@{$columns}) {
        if($col->{'checked'}) {
            push @selected, $col->{'field'};
        }
    }
    $c->stash->{'default_host_columns'} = $c->config->{'default_host_columns'} || join(",", @selected);
    $c->stash->{'default_host_columns'} =~ s/\s+//gmx;
    return($columns);
}

##############################################

=head2 get_service_columns

  get_service_columns($c)

returns list of service columns

=cut
sub get_service_columns {
    my($c) = @_;

    my $columns = [
        { title => "Host",                 "field" => "host_name",            "checked" => 1 },
    ];
    if($c->stash->{'show_backends_in_table'} == 2) {
        push @{$columns},
        { title => "Site",                 "field" => "peer_name",            "checked" => 1 };
    }
    push @{$columns}, (
        { title => "Service",              "field" => "description",          "checked" => 1 },
        { title => "Status",               "field" => "state",                "checked" => 1 },
        { title => "Last Check",           "field" => "last_check",           "checked" => 1 },
        { title => "Duration",             "field" => "duration",             "checked" => 1 },
        { title => "Attempt",              "field" => "current_attempt",      "checked" => 1 },
    );
    if($c->stash->{'show_backends_in_table'} == 1) {
        push @{$columns},
        { title => "Site",                 "field" => "peer_name",            "checked" => 1 };
    }
    push @{$columns}, (
        { title => "Status Information",   "field" => "plugin_output",        "checked" => 1 },
    );
    if(!$c->stash->{'show_backends_in_table'}) {
        push @{$columns},
        { title => "Site",                 "field" => "peer_name",            "checked" => 0 };
    }
    push @{$columns}, (
        { title => "Host Address",         "field" => "host_address",         "checked" => 0 },
        { title => "Host Groups",          "field" => "host_groups",          "checked" => 0 },
        { title => "Check Command",        "field" => "check_command",        "checked" => 0 },
        { title => "Check Interval",       "field" => "check_interval",       "checked" => 0 },
        { title => "Check Period",         "field" => "check_period",         "checked" => 0 },
        { title => "Contacts",             "field" => "contacts",             "checked" => 0 },
        { title => "Comments",             "field" => "comments",             "checked" => 0 },
        { title => "Event Handler",        "field" => "event_handler",        "checked" => 0 },
        { title => "Execution Time",       "field" => "execution_time",       "checked" => 0 },
        { title => "Groups",               "field" => "groups",               "checked" => 0 },
        { title => "Latency",              "field" => "latency",              "checked" => 0 },
        { title => "Next Check",           "field" => "next_check",           "checked" => 0 },
        { title => "Notification Period",  "field" => "notification_period",  "checked" => 0 },
        { title => "Percent State Change", "field" => "percent_state_change", "checked" => 0 },
    );
    if($c->config->{'show_custom_vars'}) {
        for my $var (@{$c->config->{'show_custom_vars'}}) {
            push @{$columns},
            { title => $var,               "field" => "cust_".$var,           "checked" => 0 };
        }
    }


    my @selected;
    for my $col (@{$columns}) {
        if($col->{'checked'}) {
            push @selected, $col->{'field'};
        }
    }
    $c->stash->{'default_service_columns'} = $c->config->{'default_service_columns'} || join(",", @selected);
    $c->stash->{'default_service_columns'} =~ s/\s+//gmx;
    return($columns);
}

##############################################

=head2 sort_table_columns

  sort_table_columns($columns, $params)

sort columns based on request parameters

=cut
sub sort_table_columns {
    my($columns, $params) = @_;
    if(!$params) { return($columns); }

    my $hashed = {};
    for my $col (@{$columns}) {
        $hashed->{$col->{'field'}} = $col;
    }

    my $sorted = [];
    for my $param (split/,/mx, $params) {
        my($key,$title) = split(/:/mx, $param, 2);
        if($hashed->{$key}) {
            $hashed->{$key}->{'checked'} = 1;
            if(defined $title) {
                $title = Thruk::Utils::Filter::escape_html($title);
                $hashed->{$key}->{'orig'}  = $hashed->{$key}->{'title'};
                $hashed->{$key}->{'title'} = $title;
            }
            push @{$sorted}, $hashed->{$key};
            delete $hashed->{$key};
        }
    }
    # add missing
    for my $col (@{$columns}) {
        if($hashed->{$col->{'field'}}) {
            $hashed->{$col->{'field'}}->{'checked'} = 0;
            push @{$sorted}, $hashed->{$col->{'field'}};
        }
    }
    return($sorted);
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
    my $comments_by_host         = {};
    my $comments_by_host_service = {};
    if($downtimes) {
        for my $downtime ( @{$downtimes} ) {
            if( defined $downtime->{'service_description'} and $downtime->{'service_description'} ne '' ) {
                push @{ $comments_by_host_service->{ $downtime->{'host_name'} }->{ $downtime->{'service_description'} } }, $downtime;
            }
            else {
                push @{ $comments_by_host->{ $downtime->{'host_name'} } }, $downtime;
            }
        }
    }
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

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
