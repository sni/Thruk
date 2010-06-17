package Thruk::Controller::history;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::history - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    my($start,$end);
    my $filter  = "";
    my $timeframe = 86400;

    my $oldestfirst = $c->{'request'}->{'parameters'}->{'oldestfirst'} || 0;
    my $archive     = $c->{'request'}->{'parameters'}->{'archive'}     || 0;
    my $type        = $c->{'request'}->{'parameters'}->{'type'}        || 0;
    my $statetype   = $c->{'request'}->{'parameters'}->{'statetype'}   || 0;
    my $noflapping  = $c->{'request'}->{'parameters'}->{'noflapping'}  || 0;
    my $nodowntime  = $c->{'request'}->{'parameters'}->{'nodowntime'}  || 0;
    my $nosystem    = $c->{'request'}->{'parameters'}->{'nosystem'}    || 0;
    my $host        = $c->{'request'}->{'parameters'}->{'host'}        || 'all';
    my $service     = $c->{'request'}->{'parameters'}->{'service'};

    if(defined $service and $host ne 'all') {
        $c->stash->{infoBoxTitle} = 'Service Alert History';
    } elsif($host ne 'all') {
        $c->stash->{infoBoxTitle} = 'Host Alert History';
    } else {
        $c->stash->{infoBoxTitle} = 'Alert History';
    }

    my $param_start = $c->{'request'}->{'parameters'}->{'start'};
    my $param_end   = $c->{'request'}->{'parameters'}->{'end'};

    # start / end date from formular values?
    if(defined $param_start and defined $param_end) {
        # convert to timestamps
        $start = Thruk::Utils::parse_date($c, $param_start);
        $end   = Thruk::Utils::parse_date($c, $param_end);
    }
    if(!defined $start or $start == 0 or !defined $end or $end == 0) {
        # start with today 00:00
        $start = Thruk::Utils::parse_date($c, "today 00:00");
        $end   = $start + $timeframe;
    }
    if($archive eq '+1') {
        $start = $start + $timeframe;
        $end   = $end   + $timeframe;
    }
    elsif($archive eq '-1') {
        $start = $start - $timeframe;
        $end   = $end   - $timeframe;
    }

    # swap date if they are mixed up
    if($start > $end) {
        my $tmp = $start;
        $start = $end;
        $end   = $tmp;
    }

    $filter .= "Filter: time >= $start\n";
    $filter .= "Filter: time <= $end\n";

    # type filter
    my $typefilter = $self->_get_log_type_filter($type);
    if($typefilter ne '') { $typefilter = "\n".$typefilter."And: 2\n"; }

    # normal alerts
    my @prop_filter;
    if($statetype == 0) {
        push @prop_filter, "Filter: type = SERVICE ALERT".$typefilter;
        push @prop_filter, "Filter: type = HOST ALERT".$typefilter;
    }
    elsif($statetype == 1) {
        push @prop_filter, "Filter: type = SERVICE ALERT\nFilter: options ~ ;SOFT;\nAnd: 2".$typefilter;
        push @prop_filter, "Filter: type = HOST ALERT\nFilter: options ~ ;SOFT;\nAnd: 2".$typefilter;
    }
    if($statetype == 2) {
        push @prop_filter, "Filter: type = SERVICE ALERT\nFilter: options ~ ;HARD;\nAnd: 2".$typefilter;
        push @prop_filter, "Filter: type = HOST ALERT\nFilter: options ~ ;HARD;\nAnd: 2".$typefilter;
    }

    # add flapping messages
    unless($noflapping) {
        push @prop_filter, "Filter: type = SERVICE FLAPPING ALERT";
        push @prop_filter, "Filter: type = HOST FLAPPING ALERT";
    }

    # add downtime messages
    unless($nodowntime) {
        push @prop_filter, "Filter: type = SERVICE DOWNTIME ALERT";
        push @prop_filter, "Filter: type = HOST DOWNTIME ALERT";
    }

    # join type filter together
    $filter .= join("\n", @prop_filter)."\nOr: ".(scalar @prop_filter)."\n";

    my $filternum = 0;

    # service filter
    if(defined $service and $host ne 'all') {
        $filter .= "Filter: host_name = $host\n";
        $filter .= "Filter: service_description = $service\n";
        $filter .= "And: 3\n";
        $filternum++;
    }
    # host filter
    elsif($host ne 'all') {
        $filter .= "Filter: host_name = $host\n";
        $filter .= "And: 2\n";
        $filternum++;
    }

    # add system messages
    unless($nosystem) {
        $filter .= "Filter: type ~ starting\.\.\.\n";
        $filter .= "Filter: type ~ shutting\ down\.\.\.\n";
        $filter .= "Or: 3\n";
    }


    my $query = "GET log\nColumns: time type options state\n".$filter;
    #$c->log->debug($query);
    $query   .= Thruk::Utils::Auth::get_auth_filter($c, 'log');

    my $logs = $c->{'live'}->selectall_arrayref($query, { Slice => 1, AddPeer => 1});

    my $order = "DESC";
    if($oldestfirst) {
        $order = "ASC";
    }
    my $sortedlogs = Thruk::Utils::sort($c, $logs, 'time', $order);

    $c->stash->{logs}             = $sortedlogs;
    $c->stash->{archive}          = $archive;
    $c->stash->{type}             = $type;
    $c->stash->{statetype}        = $statetype;
    $c->stash->{noflapping}       = $noflapping;
    $c->stash->{nodowntime}       = $nodowntime;
    $c->stash->{nosystem}         = $nosystem;
    $c->stash->{oldestfirst}      = $oldestfirst;
    $c->stash->{start}            = $start;
    $c->stash->{end}              = $end;
    $c->stash->{host}             = $host;
    $c->stash->{service}          = $service;
    $c->stash->{title}            = 'History';
    $c->stash->{page}             = 'history';
    $c->stash->{template}         = 'history.tt';
    $c->stash->{'no_auto_reload'} = 1;

    return 1;
}

##########################################################
sub _get_log_type_filter {
    my ( $self, $number ) = @_;

    $number = 0 if !defined $number or $number <= 0 or $number > 511;
    my $filter = '';
    if($number > 0) {
        my @prop_filter;
        my @bits = reverse split(/\ */mx, unpack("B*", pack("N", int($number))));

        if($bits[0]) {  # 1 - All service alerts
            push @prop_filter, "Filter: service_description !=";
        }
        if($bits[1]) {  # 2 - All host alerts
            push @prop_filter, "Filter: service_description = ";
        }
        if($bits[2]) {  # 4 - Service warning
            push @prop_filter, "Filter: state = 1\nFilter: service_description != \nAnd: 2";
        }
        if($bits[3]) {  # 8 - Service unknown
            push @prop_filter, "Filter: state = 3\nFilter: service_description != \nAnd: 2";
        }
        if($bits[4]) {  # 16 - Service critical
            push @prop_filter, "Filter: state = 2\nFilter: service_description != \nAnd: 2";
        }
        if($bits[5]) {  # 32 - Service recovery
            push @prop_filter, "Filter: state = 0\nFilter: service_description != \nAnd: 2";
        }
        if($bits[6]) {  # 64 - Host down
            push @prop_filter, "Filter: state = 1\nFilter: service_description = \nAnd: 2";
        }
        if($bits[7]) {  # 128 - Host unreachable
            push @prop_filter, "Filter: state = 2\nFilter: service_description = \nAnd: 2";
        }
        if($bits[8]) {  # 256 - Host recovery
            push @prop_filter, "Filter: state = 0\nFilter: service_description = \nAnd: 2";
        }

        if(scalar @prop_filter > 1) {
            $filter .= join("\n", @prop_filter)."\nOr: ".(scalar @prop_filter)."\n";
        }
        elsif(scalar @prop_filter == 1) {
            $filter .= $prop_filter[0]."\n";
        }
    }
    return($filter);
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
