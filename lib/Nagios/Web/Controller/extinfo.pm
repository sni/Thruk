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

sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;
    my $type = $c->{'request'}->{'parameters'}->{'type'} || 0;

    #print "HTTP 200 OK\nContent-Type: text/html\n\n<pre>\n";
    #print Dumper($c);
    #print Dumper($self);
    #exit;

    my $infoBoxTitle;
    if($type == 0) {
        $infoBoxTitle = 'Nagios Process Information';
    }
    if($type == 1) {
        $infoBoxTitle = 'Host Information';
    }
    if($type == 2) {
        $infoBoxTitle = 'Service Information';
    }
    if($type == 3) {
        $infoBoxTitle = 'All Host and Service Comments';
    }
    if($type == 4) {
        $infoBoxTitle = 'Performance Information';
    }
    if($type == 5) {
        $infoBoxTitle = 'Hostgroup Information';
    }
    if($type == 6) {
        $infoBoxTitle = 'All Host and Service Scheduled Downtime';
    }
    if($type == 7) {
        $infoBoxTitle = 'Check Scheduling Queue';

        my $sorttype   = $c->{'request'}->{'parameters'}->{'sorttype'}   || 1;
        my $sortoption = $c->{'request'}->{'parameters'}->{'sortoption'} || 7;

        my $order = "ASC";
        $order = "DESC" if $sorttype == 2;

        my $sortoptions = {
                    '1' => [ 'host_name',   'host name'       ],
                    '2' => [ 'description', 'service name'    ],
                    '4' => [ 'last_check',  'last check time' ],
                    '7' => [ 'next_check',  'next check time' ],
        };
        $sortoption = 7 if !defined $sortoptions->{$sortoption};

        my $services = $c->{'live'}->selectall_arrayref("GET services\nColumns: host_name description next_check last_check check_options active_checks_enabled", { Slice => {} });
        my $hosts    = $c->{'live'}->selectall_arrayref("GET hosts\nColumns: name next_check last_check check_options active_checks_enabled", { Slice => {}, rename => { 'name' => 'host_name' } });
        my $queue    = Nagios::Web::Helper->sort($c, [@{$hosts}, @{$services}], $sortoptions->{$sortoption}->[0], $order);
        $c->stash->{'queue'}   = $queue;
        $c->stash->{'order'}   = $order;
        $c->stash->{'sortkey'} = $sortoptions->{$sortoption}->[1];
    }
    if($type == 8) {
        $infoBoxTitle = 'Servicegroup Information';
    }

    $c->stash->{title}          = 'Extended Information';
    $c->stash->{infoBoxTitle}   = $infoBoxTitle;
    $c->stash->{page}           = 'extinfo';
    $c->stash->{template}       = 'extinfo_type_'.$type.'.tt';
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
