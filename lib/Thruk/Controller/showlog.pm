package Thruk::Controller::showlog;

use strict;
use warnings;
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

    my($start,$end);
    my $filter  = "";
    my $timeframe = 86400;

    my $oldestfirst = $c->{'request'}->{'parameters'}->{'oldestfirst'} || 0;
    my $archive     = $c->{'request'}->{'parameters'}->{'archive'}     || 0;
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


    # additional filters set?
    my $pattern         = $c->{'request'}->{'parameters'}->{'pattern'};
    my $exclude_pattern = $c->{'request'}->{'parameters'}->{'exclude_pattern'};
    my @filter;
    if(defined $pattern and $pattern !~ m/^\s*$/mx) {
        push @filter, "Filter: message ~~ $pattern\n";
    }
    if(defined $exclude_pattern and $exclude_pattern !~ m/^\s*$/mx) {
        push @filter, "Filter: message !~~ $exclude_pattern\n";
    }
    $filter .= Thruk::Utils::combine_filter(\@filter, 'And');

    my $query = "GET log\nColumns: time type message state\n".$filter;

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
    $c->stash->{pattern}          = $pattern;
    $c->stash->{exclude_pattern}  = $exclude_pattern;
    $c->stash->{oldestfirst}      = $oldestfirst;
    $c->stash->{title}            = 'Log File';
    $c->stash->{infoBoxTitle}     = 'Event Log';
    $c->stash->{page}             = 'showlog';
    $c->stash->{template}         = 'showlog.tt';
    $c->stash->{'no_auto_reload'} = 1;

    Thruk::Utils::ssi_include($c);

    return 1;
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
