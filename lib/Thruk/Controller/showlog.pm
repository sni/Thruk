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
        # Format: 2010-03-02 00:00:00
        if($param_start =~ m/(\d{4})\-(\d{2})\-(\d{2})\ (\d{2}):(\d{2}):(\d{2})/mx) {
            $start = Mktime($1,$2,$3, $4,$5,$6);
        }
        if($param_end =~ m/(\d{4})\-(\d{2})\-(\d{2})\ (\d{2}):(\d{2}):(\d{2})/mx) {
            $end = Mktime($1,$2,$3, $4,$5,$6);
        }
    }
    if(!defined $start or $start == 0 or !defined $end or $end == 0) {
        # start with today 00:00
        my ($year,$month,$day, $hour,$min,$sec, $doy,$dow,$dst) = Localtime();
        $hour = 0; $min = 0; $sec = 0;
        my $today = Mktime($year,$month,$day, $hour,$min,$sec);
        $start = $today;
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
    if(defined $pattern and $pattern !~ m/^\s*$/mx) {
        $filter .= "Filter: message ~~ $pattern\n";
    }
# TODO: does not work yet
#    if(defined $exclude_pattern and $exclude_pattern !~ m/^\s*$/mx) {
#        $filter .= "Filter: message !~~ $exclude_pattern\nAnd: 2\n";
#    }

    my $query = "GET log\nColumns: time type message state\n".$filter;

    $query   .= Thruk::Utils::get_auth_filter($c, 'log');

    $c->stats->profile(begin => "showlog::fetch");
    my $logs = $c->{'live'}->selectall_arrayref($query, { Slice => 1, AddPeer => 1});
    $c->stats->profile(end   => "showlog::fetch");

    if(defined $exclude_pattern and $exclude_pattern !~ m/^\s*$/mx) {
        my $newlogs = [];
        my $tmp_pattern = $exclude_pattern;
        $tmp_pattern =~ s/\ /\\ /gmx;
        for my $log (@{$logs}) {
            push @{$newlogs}, $log if $log->{'message'} !~ m/$tmp_pattern/mx;
        }
        $logs = $newlogs;
    }


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

    return 1;
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
