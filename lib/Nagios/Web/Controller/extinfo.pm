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
        $self->_process_comments_page($c);
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
sub _process_comments_page {
    my ( $self, $c ) = @_;
    $c->stash->{'hostcomments'}    = $c->{'live'}->selectall_arrayref("GET comments\nFilter: service_description = ", { Slice => {} });
    $c->stash->{'servicecomments'} = $c->{'live'}->selectall_arrayref("GET comments\nFilter: service_description != ", { Slice => {} });
}

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

    $c->stash->{'host'}     = $host;

    my $comments       = $c->{'live'}->selectall_arrayref("GET comments\nFilter: host_name = $hostname\nFilter: service_description =\nColumns: author id comment_data comment_type entry_time entry_type expire_time expires persistent source", { Slice => 1 });
    my $sortedcomments = Nagios::Web::Helper->sort($c, $comments, 'id', 'DESC');
    $c->stash->{'comments'} = $sortedcomments;
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

    my $comments       = $c->{'live'}->selectall_arrayref("GET comments\nFilter: host_name = $hostname\nFilter: service_description = $servicename\nColumns: author id comment_data comment_type entry_time entry_type expire_time expires persistent source", { Slice => 1 });
    my $sortedcomments = Nagios::Web::Helper->sort($c, $comments, 'id', 'DESC');
    $c->stash->{'comments'} = $sortedcomments;
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

    $c->stash->{'stats'}      = Nagios::Web::Helper->get_service_exectution_stats($c);
    $c->stash->{'live_stats'} = $c->{'live'}->selectrow_arrayref("GET status\nColumns: connections connections_rate host_checks host_checks_rate requests requests_rate service_checks service_checks_rate neb_callbacks neb_callbacks_rate", { Slice => 1 });

}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
