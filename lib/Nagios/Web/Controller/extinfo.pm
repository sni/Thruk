package Nagios::Web::Controller::extinfo;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Nagios::Web::Helper;

=head1 NAME

Nagios::Web::Controller::extinfo - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;
    my $type = $c->{'request'}->{'parameters'}->{'type'} || 0;

    my $infoBoxTitle;
    if($type == 0) {
        $infoBoxTitle = 'Nagios Process Information';
        $c->detach('/error/index/1') unless $c->check_user_roles( "authorized_for_system_information" );
        $self->_process_process_info_page($c);
    }
    if($type == 1) {
        $infoBoxTitle = 'Host Information';
        $self->_process_host_page($c);
    }
    if($type == 2) {
        $infoBoxTitle = 'Service Information';
        $self->_process_service_page($c);
    }
    if($type == 3) {
        $infoBoxTitle = 'All Host and Service Comments';
    }
    if($type == 4) {
        $infoBoxTitle = 'Performance Information';
        $self->_process_perf_info_page($c);
    }
    if($type == 5) {
        $infoBoxTitle = 'Hostgroup Information';
        $self->_process_hostgroup_cmd_page($c);
    }
    if($type == 6) {
        $infoBoxTitle = 'All Host and Service Scheduled Downtime';
        $self->_process_downtimes_page($c);
    }
    if($type == 7) {
        $infoBoxTitle = 'Check Scheduling Queue';
        $self->_process_scheduling_page($c);
    }
    if($type == 8) {
        $infoBoxTitle = 'Servicegroup Information';
        $self->_process_servicegroup_cmd_page($c);
    }

    $c->stash->{title}          = 'Extended Information';
    $c->stash->{infoBoxTitle}   = $infoBoxTitle;
    $c->stash->{page}           = 'extinfo';
    $c->stash->{template}       = 'extinfo_type_'.$type.'.tt';
}


##########################################################
# SUBS
##########################################################

##########################################################
# create the downtimes page
sub _process_downtimes_page {
    my ( $self, $c ) = @_;
    $c->stash->{'hostdowntimes'}    = $c->{'live'}->selectall_arrayref("GET downtimes\nFilter: service_description = ", { Slice => {} });
    $c->stash->{'servicedowntimes'} = $c->{'live'}->selectall_arrayref("GET downtimes\nFilter: service_description != ", { Slice => {} });
}

##########################################################
# create the host info page
sub _process_host_page {
    my ( $self, $c ) = @_;

    my $hostname = $c->{'request'}->{'parameters'}->{'host'};
    $c->detach('/error/index/5') unless defined $hostname;

    my $host = $c->{'live'}->selectrow_hashref("GET hosts\nFilter: name = $hostname");
    $c->detach('/error/index/5') unless defined $host;

    $c->stash->{'host'} = $host;
}

##########################################################
# create the hostgroup cmd page
sub _process_hostgroup_cmd_page {
    my ( $self, $c ) = @_;

    my $hostgroup = $c->{'request'}->{'parameters'}->{'hostgroup'};
    $c->detach('/error/index/5') unless defined $hostgroup;

    my($hostgroup_name,$hostgroup_alias) = $c->{'live'}->selectrow_array("GET hostgroups\nColumns: name alias\nFilter: name = $hostgroup\nLimit: 1");
    $c->detach('/error/index/5') unless defined $hostgroup_name;

    $c->stash->{'hostgroup'}       = $hostgroup_name;
    $c->stash->{'hostgroup_alias'} = $hostgroup_alias;
}

##########################################################
# create the service info page
sub _process_service_page {
    my ( $self, $c ) = @_;

    my $hostname = $c->{'request'}->{'parameters'}->{'host'};
    $c->detach('/error/index/5') unless defined $hostname;

    my $servicename = $c->{'request'}->{'parameters'}->{'service'};
    $c->detach('/error/index/5') unless defined $servicename;

    my $service = $c->{'live'}->selectrow_hashref("GET services\nFilter: host_name = $hostname\nFilter: description = $servicename");
    $c->detach('/error/index/5') unless defined $service;

    $c->stash->{'service'} = $service;
}

##########################################################
# create the servicegroup cmd page
sub _process_servicegroup_cmd_page {
    my ( $self, $c ) = @_;

    my $servicegroup = $c->{'request'}->{'parameters'}->{'servicegroup'};
    $c->detach('/error/index/5') unless defined $servicegroup;

    my($servicegroup_name,$servicegroup_alias) = $c->{'live'}->selectrow_array("GET servicegroups\nColumns: name alias\nFilter: name = $servicegroup\nLimit: 1");
    $c->detach('/error/index/5') unless defined $servicegroup_name;

    $c->stash->{'servicegroup'}       = $servicegroup_name;
    $c->stash->{'servicegroup_alias'} = $servicegroup_alias;
}

##########################################################
# create the scheduling page
sub _process_scheduling_page {
    my ( $self, $c ) = @_;

    my $sorttype   = $c->{'request'}->{'parameters'}->{'sorttype'}   || 1;
    my $sortoption = $c->{'request'}->{'parameters'}->{'sortoption'} || 7;

    my $order = "ASC";
    $order = "DESC" if $sorttype == 2;

    my $sortoptions = {
                '1' => [ ['host_name', 'description'],   'host name'       ],
                '2' => [ 'description',                  'service name'    ],
                '4' => [ 'last_check',                   'last check time' ],
                '7' => [ 'next_check',                   'next check time' ],
    };
    $sortoption = 7 if !defined $sortoptions->{$sortoption};

    my $services = $c->{'live'}->selectall_arrayref("GET services\nColumns: host_name description next_check last_check check_options active_checks_enabled\nFilter: active_checks_enabled = 1\nFilter: check_options != 0\nOr: 2", { Slice => {} });
    my $hosts    = $c->{'live'}->selectall_arrayref("GET hosts\nColumns: name next_check last_check check_options active_checks_enabled\nFilter: active_checks_enabled = 1\nFilter: check_options != 0\nOr: 2", { Slice => {}, rename => { 'name' => 'host_name' } });
    my $queue    = Nagios::Web::Helper->sort($c, [@{$hosts}, @{$services}], $sortoptions->{$sortoption}->[0], $order);
    $c->stash->{'queue'}   = $queue;
    $c->stash->{'order'}   = $order;
    $c->stash->{'sortkey'} = $sortoptions->{$sortoption}->[1];
}


##########################################################
# create the process info page
sub _process_process_info_page {
    my ( $self, $c ) = @_;

    # all other data is already set in addDefaults
    $c->stash->{'nagios_data_source'} = $c->{'live'}->peer_name();
}

##########################################################
# create the performance info page
sub _process_perf_info_page {
    my ( $self, $c ) = @_;

    my $now    = time();
    my $min1   = $now - 60;
    my $min5   = $now - 300;
    my $min15  = $now - 900;
    my $min60  = $now - 3600;
    my $minall = $c->stash->{'pi'}->{'program_start'};

    my $check_stats;
    for my $type (qw{hosts services}) {
        $check_stats->{$type} = {
            'active_sum'                => 0,
            'active_1_min'              => 0,
            'active_5_min'              => 0,
            'active_15_min'             => 0,
            'active_60_min'             => 0,
            'active_all_min'            => 0,

            'active_1_min_perc'         => 0,
            'active_5_min_perc'         => 0,
            'active_15_min_perc'        => 0,
            'active_60_min_perc'        => 0,
            'active_all_min_perc'       => 0,

            'execution_time_min'        => undef,
            'execution_time_max'        => undef,
            'execution_time_avg'        => 0,
            'execution_time_sum'        => 0,

            'latency_min'               => undef,
            'latency_max'               => undef,
            'latency_avg'               => 0,
            'latency_sum'               => 0,

            'active_state_change_min'   => undef,
            'active_state_change_max'   => undef,
            'active_state_change_avg'   => 0,
            'active_state_change_sum'   => 0,

            'passive_sum'               => 0,
            'passive_1_min'             => 0,
            'passive_5_min'             => 0,
            'passive_15_min'            => 0,
            'passive_60_min'            => 0,
            'passive_all_min'           => 0,

            'passive_1_min_perc'        => 0,
            'passive_5_min_perc'        => 0,
            'passive_15_min_perc'       => 0,
            'passive_60_min_perc'       => 0,
            'passive_all_min_perc'      => 0,

            'passive_state_change_min'  => undef,
            'passive_state_change_max'  => undef,
            'passive_state_change_avg'  => 0,
            'passive_state_change_sum'  => 0,
        };

        for my $data (@{$c->{'live'}->selectall_arrayref("GET $type\nColumns: execution_time has_been_checked last_check latency percent_state_change check_type", { Slice => 1 })}) {
            if($data->{'check_type'} == 0) {
                $check_stats->{$type}->{'active_sum'}++;
            } else {
                $check_stats->{$type}->{'passive_sum'}++;
            }

            if($data->{'has_been_checked'}) {

                # active checks
                if($data->{'check_type'} == 0) {
                    if($data->{'last_check'} >= $min1)   { $check_stats->{$type}->{'active_1_min'}++;   }
                    if($data->{'last_check'} >= $min5)   { $check_stats->{$type}->{'active_5_min'}++;   }
                    if($data->{'last_check'} >= $min15)  { $check_stats->{$type}->{'active_15_min'}++;  }
                    if($data->{'last_check'} >= $min60)  { $check_stats->{$type}->{'active_60_min'}++;  }
                    if($data->{'last_check'} >= $minall) { $check_stats->{$type}->{'active_all_min'}++; }

                    # sum up all values to calculate averages later
                    $check_stats->{$type}->{'execution_time_sum'}       += $data->{'execution_time'};
                    $check_stats->{$type}->{'latency_sum'}              += $data->{'latency'};
                    $check_stats->{$type}->{'active_state_change_sum'}  += $data->{'percent_state_change'};

                    # check min/max values
                    if(!defined $check_stats->{$type}->{'execution_time_min'} or $check_stats->{$type}->{'execution_time_min'} > $data->{'execution_time'}) {
                        $check_stats->{$type}->{'execution_time_min'} = $data->{'execution_time'};
                    }
                    if(!defined $check_stats->{$type}->{'execution_time_max'} or $check_stats->{$type}->{'execution_time_max'} < $data->{'execution_time'}) {
                        $check_stats->{$type}->{'execution_time_max'} = $data->{'execution_time'};
                    }

                    if(!defined $check_stats->{$type}->{'latency_min'} or $check_stats->{$type}->{'latency_min'} > $data->{'latency'}) {
                        $check_stats->{$type}->{'latency_min'} = $data->{'latency'};
                    }
                    if(!defined $check_stats->{$type}->{'latency_max'} or $check_stats->{$type}->{'latency_max'} < $data->{'latency'}) {
                        $check_stats->{$type}->{'latency_max'} = $data->{'latency'};
                    }

                    if(!defined $check_stats->{$type}->{'active_state_change_min'} or $check_stats->{$type}->{'active_state_change_min'} > $data->{'percent_state_change'}) {
                        $check_stats->{$type}->{'active_state_change_min'} = $data->{'percent_state_change'};
                    }
                    if(!defined $check_stats->{$type}->{'active_state_change_max'} or $check_stats->{$type}->{'active_state_change_max'} < $data->{'percent_state_change'}) {
                        $check_stats->{$type}->{'active_state_change_max'} = $data->{'percent_state_change'};
                    }
                }
                # passive checks
                else {
                    $check_stats->{$type}->{'passive_sum'}++;
                    if($data->{'last_check'} >= $min1)   { $check_stats->{$type}->{'passive_1_min'}++;   }
                    if($data->{'last_check'} >= $min5)   { $check_stats->{$type}->{'passive_5_min'}++;   }
                    if($data->{'last_check'} >= $min15)  { $check_stats->{$type}->{'passive_15_min'}++;  }
                    if($data->{'last_check'} >= $min60)  { $check_stats->{$type}->{'passive_60_min'}++;  }
                    if($data->{'last_check'} >= $minall) { $check_stats->{$type}->{'passive_all_min'}++; }

                    # sum up all values to calculate averages later
                    $check_stats->{$type}->{'passive_state_change_sum'} += $data->{'percent_state_change'};

                    # check min/max values
                    if(!defined $check_stats->{$type}->{'passive_state_change_min'} or $check_stats->{$type}->{'passive_state_change_min'} > $data->{'percent_state_change'}) {
                        $check_stats->{$type}->{'active_state_change_min'} = $data->{'percent_state_change'};
                    }
                    if(!defined $check_stats->{$type}->{'passive_state_change_max'} or $check_stats->{$type}->{'passive_state_change_max'} < $data->{'percent_state_change'}) {
                        $check_stats->{$type}->{'passive_state_change_max'} = $data->{'percent_state_change'};
                    }
                }
            }
        }

        # calculate averages
        if($check_stats->{$type}->{'active_sum'} > 0) {
            $check_stats->{$type}->{'execution_time_avg'}       = $check_stats->{$type}->{'execution_time_sum'}       / $check_stats->{$type}->{'active_sum'};
            $check_stats->{$type}->{'latency_avg'}              = $check_stats->{$type}->{'latency_sum'}              / $check_stats->{$type}->{'active_sum'};
            $check_stats->{$type}->{'active_state_change_avg'}  = $check_stats->{$type}->{'active_state_change_sum'}  / $check_stats->{$type}->{'active_sum'};
        } else {
            $check_stats->{$type}->{'execution_time_avg'}       = 0;
            $check_stats->{$type}->{'latency_avg'}              = 0;
            $check_stats->{$type}->{'active_state_change_avg'}  = 0;
        }
        if($check_stats->{$type}->{'passive_sum'} > 0) {
            $check_stats->{$type}->{'passive_state_change_avg'} = $check_stats->{$type}->{'passive_state_change_sum'} / $check_stats->{$type}->{'passive_sum'};
        } else {
            $check_stats->{$type}->{'passive_state_change_avg'} = 0;
        }

        # calculate percentages
        if($check_stats->{$type}->{'active_sum'} > 0) {
            $check_stats->{$type}->{'active_1_min_perc'}   = $check_stats->{$type}->{'active_1_min'}   / $check_stats->{$type}->{'active_sum'} * 100;
            $check_stats->{$type}->{'active_5_min_perc'}   = $check_stats->{$type}->{'active_5_min'}   / $check_stats->{$type}->{'active_sum'} * 100;
            $check_stats->{$type}->{'active_15_min_perc'}  = $check_stats->{$type}->{'active_15_min'}  / $check_stats->{$type}->{'active_sum'} * 100;
            $check_stats->{$type}->{'active_60_min_perc'}  = $check_stats->{$type}->{'active_60_min'}  / $check_stats->{$type}->{'active_sum'} * 100;
            $check_stats->{$type}->{'active_all_min_perc'} = $check_stats->{$type}->{'active_all_min'} / $check_stats->{$type}->{'active_sum'} * 100;
        }

        if($check_stats->{$type}->{'passive_sum'} > 0) {
            $check_stats->{$type}->{'passive_1_min_perc'}   = $check_stats->{$type}->{'passive_1_min'}   / $check_stats->{$type}->{'passive_sum'} * 100;
            $check_stats->{$type}->{'passive_5_min_perc'}   = $check_stats->{$type}->{'passive_5_min'}   / $check_stats->{$type}->{'passive_sum'} * 100;
            $check_stats->{$type}->{'passive_15_min_perc'}  = $check_stats->{$type}->{'passive_15_min'}  / $check_stats->{$type}->{'passive_sum'} * 100;
            $check_stats->{$type}->{'passive_60_min_perc'}  = $check_stats->{$type}->{'passive_60_min'}  / $check_stats->{$type}->{'passive_sum'} * 100;
            $check_stats->{$type}->{'passive_all_min_perc'} = $check_stats->{$type}->{'passive_all_min'} / $check_stats->{$type}->{'passive_sum'} * 100;
        }
    }
#use Data::Dumper;
#$Data::Dumper::Sortkeys = 1;
#print Dumper($check_stats);

    $c->stash->{'stats'}      = $check_stats;

    $c->stash->{'live_stats'} = $c->{'live'}->selectrow_arrayref("GET status\nColumns: connections connections_rate host_checks host_checks_rate requests requests_rate service_checks service_checks_rate neb_callbacks neb_callbacks_rate", { Slice => 1 });

}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
