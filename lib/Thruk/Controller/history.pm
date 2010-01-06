package Thruk::Controller::history;

use strict;
use warnings;
use Date::Calc qw/Localtime Mktime/;
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

    my $filter  = "";

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

    # start with today 00:00
    my $timeperiod = 86400;
    my($endname);
    if($archive == 0) {
        $endname = 'Present..';
    }
    my ($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
    $hour = 0; $min = 0; $sec = 0;
    my $today = Mktime($year,$month,$day, $hour,$min,$sec);
    my $end   = $today - ($timeperiod * ($archive-1));
    my $start = $end - $timeperiod;

    $filter .= "Filter: time >= $start\n";
    $filter .= "Filter: time <= $end\n";

    # type filter
    my $typefilter = $self->_get_log_type_filter($type);
    if($typefilter ne '') { $typefilter = "\n".$typefilter."And: 2\n"; }

    # normal alerts
    my @prop_filter;
    if($statetype == 0) {
        push @prop_filter, "Filter: message = SERVICE ALERT".$typefilter;
        push @prop_filter, "Filter: message = HOST ALERT".$typefilter;
    }
    elsif($statetype == 1) {
        push @prop_filter, "Filter: message = SERVICE ALERT\nFilter: options ~ ;SOFT;\nAnd: 2".$typefilter;
        push @prop_filter, "Filter: message = HOST ALERT\nFilter: options ~ ;SOFT;\nAnd: 2".$typefilter;
    }
    if($statetype == 2) {
        push @prop_filter, "Filter: message = SERVICE ALERT\nFilter: options ~ ;HARD;\nAnd: 2".$typefilter;
        push @prop_filter, "Filter: message = HOST ALERT\nFilter: options ~ ;HARD;\nAnd: 2".$typefilter;
    }

    # add flapping messages
    unless($noflapping) {
        push @prop_filter, "Filter: message = SERVICE FLAPPING ALERT";
        push @prop_filter, "Filter: message = HOST FLAPPING ALERT";
    }

    # add downtime messages
    unless($nodowntime) {
        push @prop_filter, "Filter: message = SERVICE DOWNTIME ALERT";
        push @prop_filter, "Filter: message = HOST DOWNTIME ALERT";
    }

    # join type filter together
    $filter .= join("\n", @prop_filter)."\nOr: ".(scalar @prop_filter)."\n";

    my $filternum = 0;

    # service filter
    if(defined $service) {
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
        $filter .= "Filter: message ~ starting\.\.\.\n";
        $filter .= "Filter: message ~ shutting\ down\.\.\.\n";
        $filter .= "Or: 3\n";
    }


    my $query = "GET log\nColumns: time message options state\n".$filter;
    #$c->log->debug($query);
    $query   .= Thruk::Helper::get_auth_filter($c, 'log');

    my $logs = $c->{'live'}->selectall_arrayref($query, { Slice => 1, AddPeer => 1});

    if(!$oldestfirst) {
        @{$logs} = reverse @{$logs};
    }

    $c->stash->{logs}             = $logs;
    $c->stash->{archive}          = $archive;
    $c->stash->{type}             = $type;
    $c->stash->{statetype}        = $statetype;
    $c->stash->{noflapping}       = $noflapping;
    $c->stash->{nodowntime}       = $nodowntime;
    $c->stash->{nosystem}         = $nosystem;
    $c->stash->{oldestfirst}      = $oldestfirst;
    $c->stash->{start}            = $start;
    $c->stash->{end}              = $end;
    $c->stash->{endname}          = $endname;
    $c->stash->{host}             = $host;
    $c->stash->{service}          = $service;
    $c->stash->{title}            = 'History';
    $c->stash->{page}             = 'history';
    $c->stash->{template}         = 'history.tt';
    $c->stash->{'no_auto_reload'} = 1;
}

##########################################################
sub _get_log_type_filter {
    my ( $self, $number ) = @_;

    $number = 0 if !defined $number or $number <= 0 or $number > 511;
    my $filter = '';
    if($number > 0) {
        my @prop_filter;
        my @bits = reverse split(/ */, unpack("B*", pack("N", int($number))));

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
