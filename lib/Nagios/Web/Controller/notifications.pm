package Nagios::Web::Controller::notifications;

use strict;
use warnings;
use Date::Calc qw/Localtime Mktime/;
use parent 'Catalyst::Controller';

=head1 NAME

Nagios::Web::Controller::notifications - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    my $type        = $c->{'request'}->{'parameters'}->{'type'}        || 0;
    my $archive     = $c->{'request'}->{'parameters'}->{'archive'}     || 0;
    my $contact     = $c->{'request'}->{'parameters'}->{'contact'}     || '';
    my $host        = $c->{'request'}->{'parameters'}->{'host'}        || '';
    my $service     = $c->{'request'}->{'parameters'}->{'service'}     || '';
    my $oldestfirst = $c->{'request'}->{'parameters'}->{'oldestfirst'} || 0;

    my $filter  = $self->_get_log_prop_filter($type);

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

    if($service ne '') {
        $c->stash->{infoBoxTitle}   = 'Service Notifications';
        $filter .= "Filter: host_name = $host\n" if $host ne 'all';
        $filter .= "Filter: service_description = $service\n";
    }
    if($host ne '') {
        $c->stash->{infoBoxTitle}   = 'Host Notifications';
        $filter .= "Filter: host_name = $host\n" if $host ne 'all';
    } elsif($contact ne '') {
        $c->stash->{infoBoxTitle}   = 'Contact Notifications';
        $filter .= "Filter: contact_name = $contact\n" if $contact ne 'all';
    }

    my $query = "GET log\n$filter\n";
    $query   .= "Columns: message host_name service_description plugin_output state time command_name contact_name options\n";
    $query   .= "Filter: class = 3\n";
    $query   .= Nagios::Web::Helper::get_auth_filter($c, 'log');

    my $notifications = $c->{'live'}->selectall_arrayref($query, { Slice => 1, AddPeer => 1});

    if(!$oldestfirst) {
        @{$notifications} = reverse @{$notifications};
    }

    $c->stash->{oldestfirst}      = $oldestfirst;
    $c->stash->{type}             = $type;
    $c->stash->{archive}          = $archive;
    $c->stash->{start}            = $start;
    $c->stash->{end}              = $end;
    $c->stash->{endname}          = $endname;
    $c->stash->{host}             = $host;
    $c->stash->{service}          = $service;
    $c->stash->{contact}          = $contact;
    $c->stash->{notifications}    = $notifications;
    $c->stash->{title}            = 'Alert Notifications';
    $c->stash->{page}             = 'notifications';
    $c->stash->{template}         = 'notifications.tt';
    $c->stash->{'no_auto_reload'} = 1;
}


##########################################################
sub _get_log_prop_filter {
    my ( $self, $number ) = @_;

    $number = 0 if !defined $number or $number <= 0 or $number > 32767;
    my $filter = '';
    if($number > 0) {
        my @prop_filter;
        my @bits = reverse split(/ */, unpack("B*", pack("N", int($number))));

        if($bits[0]) {  # 1 - All service notifications
            push @prop_filter, "Filter: service_description !=";
        }
        if($bits[1]) {  # 2 - All host notifications
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
        if($bits[9]) {  # 512 - Service acknowledgements
            push @prop_filter, "Filter: service_description != \nFilter: options ~ ;ACKNOWLEDGEMENT\nAnd: 2";
        }
        if($bits[10]) {  # 1024 - Host acknowledgements
            push @prop_filter, "Filter: service_description = \nFilter: options ~ ;ACKNOWLEDGEMENT\nAnd: 2";
        }
        if($bits[11]) {  # 2048 - Service flapping
            push @prop_filter, "Filter: service_description != \nFilter: options ~ ;FLAPPING\nAnd: 2";
        }
        if($bits[12]) {  # 4096 - Host flapping
            push @prop_filter, "Filter: service_description = \nFilter: options ~ ;FLAPPING\nAnd: 2";
        }
        if($bits[13]) {  # 8192 - Service custom
            push @prop_filter, "Filter: service_description != \nFilter: options ~ ;CUSTOM\nAnd: 2";
        }
        if($bits[14]) {  # 16384 - Host custom
            push @prop_filter, "Filter: service_description = \nFilter: options ~ ;CUSTOM\nAnd: 2";
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
