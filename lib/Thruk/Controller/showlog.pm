package Thruk::Controller::showlog;

use strict;
use warnings;
use Date::Calc qw/Localtime Mktime/;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::showlog - Catalyst Controller

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

    my $query = "GET log\nColumns: time type options state\n".$filter;
    $query   .= Thruk::Utils::get_auth_filter($c, 'log');

    $c->stats->profile(begin => "showlog::fetch");
    my $logs = $c->{'live'}->selectall_arrayref($query, { Slice => 1, AddPeer => 1});
    $c->stats->profile(end   => "showlog::fetch");

    my $order = "DESC";
    if($oldestfirst) {
        $order = "ASC";
    }
    my $sortedlogs = Thruk::Utils::sort($c, $logs, 'time', $order);

    Thruk::Utils::page_data($c, $sortedlogs);

    $c->stash->{archive}          = $archive;
    $c->stash->{start}            = $start;
    $c->stash->{end}              = $end;
    $c->stash->{endname}          = $endname;
    $c->stash->{oldestfirst}      = $oldestfirst;
    $c->stash->{title}            = 'Log File';
    $c->stash->{infoBoxTitle}     = 'Event Log';
    $c->stash->{page}             = 'showlog';
    $c->stash->{template}         = 'showlog.tt';
    $c->stash->{'no_auto_reload'} = 1;

    return 1;
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
