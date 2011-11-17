package Thruk::Controller::showlog;

use strict;
use warnings;
use utf8;
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
    my $filter;
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
        my($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time());
        $start = POSIX::mktime(0, 0, 0, $mday, $mon, $year);
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

    push @{$filter}, { time => { '>=' => $start }};
    push @{$filter}, { time => { '<=' => $end }};


    # additional filters set?
    my $pattern         = $c->{'request'}->{'parameters'}->{'pattern'};
    my $exclude_pattern = $c->{'request'}->{'parameters'}->{'exclude_pattern'};
    my $errors = 0;
    if(defined $pattern and $pattern !~ m/^\s*$/mx) {
        $errors++ unless(Thruk::Utils::is_valid_regular_expression($c, $pattern));
        push @{$filter}, { message => { '~~' => $pattern }};
    }
    if(defined $exclude_pattern and $exclude_pattern !~ m/^\s*$/mx) {
        $errors++ unless Thruk::Utils::is_valid_regular_expression($c, $exclude_pattern);
        push @{$filter}, { message => { '!~~' => $exclude_pattern }};
    }

    my $order = "DESC";
    if($oldestfirst) {
        $order = "ASC";
    }

    my $total_filter;
    if($errors == 0) {
        $total_filter = Thruk::Utils::combine_filter('-and', $filter);
    }

    if( defined $c->{'request'}->{'parameters'}->{'view_mode'} and $c->{'request'}->{'parameters'}->{'view_mode'} eq 'xls' ) {
        $c->stash->{'template'}   = 'excel/logs.tt';
        $c->stash->{'file_name'}  = 'logs.xls';
        $c->stash->{'log_filter'} = { filter => [$total_filter, Thruk::Utils::Auth::get_auth_filter($c, 'log')],
                                      sort => {$order => 'time'},
                                    };
        return Thruk::Utils::External::perl($c, { expr => 'Thruk::Utils::logs2xls($c)', message => 'please stand by while your report is being generated...' });
    } else {
        $c->stats->profile(begin => "showlog::fetch");
        $c->{'db'}->get_logs(filter => [$total_filter, Thruk::Utils::Auth::get_auth_filter($c, 'log')], sort => {$order => 'time'}, pager => $c);
        $c->stats->profile(end   => "showlog::fetch");
    }

    $c->stash->{archive}          = $archive;
    $c->stash->{start}            = $start;
    $c->stash->{end}              = $end;
    $c->stash->{pattern}          = $pattern         || '';
    $c->stash->{exclude_pattern}  = $exclude_pattern || '';
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
