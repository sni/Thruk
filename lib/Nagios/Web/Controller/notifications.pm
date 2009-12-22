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

sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    my $type        = $c->{'request'}->{'parameters'}->{'type'}        || 0;
    my $archive     = $c->{'request'}->{'parameters'}->{'archive'}     || 0;
    my $contact     = $c->{'request'}->{'parameters'}->{'contact'}     || '';
    my $host        = $c->{'request'}->{'parameters'}->{'host'}        || '';
    my $service     = $c->{'request'}->{'parameters'}->{'service'}     || '';
    my $oldestfirst = $c->{'request'}->{'parameters'}->{'oldestfirst'} || 0;

    my $filter  = "Limit: 1000\n"; # just for debugging now...

    # start with today 00:00
    my $timeperiod = 86400;
    my($endname);
    if($archive == 0) {
        $endname = 'Present..';
    }
    my ($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
    $hour = 0; $min = 0; $sec = 0;
    my $start = Mktime($year,$month,$day, $hour,$min,$sec);
    my $end   = $start - $timeperiod * ($archive + 1);
    $start    = $end - $timeperiod;


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
    $query   .= "Columns: message host_name service_description plugin_output state time command_name contact_name\n";
    $query   .= "Filter: class = 3\n";
    $query   .= Nagios::Web::Helper::get_auth_filter($c, 'log');

    my $notifications = $c->{'live'}->selectall_arrayref($query, { Slice => 1, AddPeer => 1});
#    $notifications = $c->{'live'}->selectall_hashref("GET log\nColumns: class message\nFilter: time >= $start\nFilter: time <= $end\n".Nagios::Web::Helper::get_auth_filter($c, 'log'), 'class');
#use Data::Dumper;
#print "HTTP/1.1 200 OK\n\n<html><pre>";
#$Data::Dumper::Sortkeys = 1;
#print Dumper($query);
#print Dumper($notifications);

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


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
