package Thruk::Controller::showlog;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::showlog - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=head2 index

=cut

##########################################################
sub index {
    my ( $c ) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_CACHED_DEFAULTS);

    my($start,$end);
    my $filter;
    my $timeframe = 86400;

    my $oldestfirst = $c->req->parameters->{'oldestfirst'} || 0;
    my $archive     = $c->req->parameters->{'archive'}     || 0;
    my $param_start = $c->req->parameters->{'start'};
    my $param_end   = $c->req->parameters->{'end'};

    # start / end date from formular values?
    if(defined $param_start and defined $param_end) {
        # convert to timestamps
        $start = Thruk::Utils::parse_date($c, $param_start);
        $end   = Thruk::Utils::parse_date($c, $param_end);
    }
    if(!defined $start || $start == 0 || !defined $end || $end == 0) {
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
    my $pattern         = $c->req->parameters->{'pattern'};
    my $exclude_pattern = $c->req->parameters->{'exclude_pattern'};
    my $errors = 0;
    if(defined $pattern and $pattern !~ m/^\s*$/mx) {
        $errors++ unless(Thruk::Utils::is_valid_regular_expression($c, $pattern));
        push @{$filter}, { message => { '~~' => $pattern }};
    }
    if(defined $exclude_pattern and $exclude_pattern !~ m/^\s*$/mx) {
        $errors++ unless Thruk::Utils::is_valid_regular_expression($c, $exclude_pattern);
        push @{$filter}, { message => { '!~~' => $exclude_pattern }};
    }

    my $host    = $c->req->parameters->{'host'}    || '';
    my $service = $c->req->parameters->{'service'} || '';
    if($service) {
        push @{$filter}, {
                -or => [
                        { -and => [
                            { host_name           => $host },
                            { service_description => $service},
                        ]},
                        { -and => [
                            {type    => 'EXTERNAL COMMAND' },
                            {message => { '~~' => '(\s|;)'.quotemeta($host).';'.quotemeta($service).'(;|$)' }},
                        ]},
                ],
        };
    }
    elsif($host) {
        push @{$filter}, {
                -or => [
                        { host_name => $host },
                        { -and => [
                            {type    => 'EXTERNAL COMMAND' },
                            {message => { '~~' => '(\s|;)'.quotemeta($host).'(;|$)' }},
                        ]},
                ],
        };
    }
    $c->stash->{'host'}    = $host;
    $c->stash->{'service'} = $service;

    my $order = "DESC";
    if($oldestfirst) {
        $order = "ASC";
    }

    my $total_filter;
    if($errors == 0) {
        $total_filter = Thruk::Utils::combine_filter('-and', $filter);
    }

    if( defined $c->req->parameters->{'view_mode'} and $c->req->parameters->{'view_mode'} eq 'xls' ) {
        $c->stash->{'template'}    = 'excel/logs.tt';
        $c->stash->{'file_name'}   = 'logs.xls';
        $c->stash->{'log_filter'}  = { filter => [$total_filter, Thruk::Utils::Auth::get_auth_filter($c, 'log')],
                                      sort => {$order => 'time'},
                                    };
        return Thruk::Utils::External::perl($c, { expr => 'Thruk::Utils::logs2xls($c)', message => 'please stand by while your report is being generated...' });
    } else {
        $c->stats->profile(begin => "showlog::updatecache");
        return if $c->{'db'}->renew_logcache($c);
        $c->stats->profile(end   => "showlog::updatecache");

        $c->stats->profile(begin => "showlog::fetch");
        $c->{'db'}->get_logs(filter => [$total_filter, Thruk::Utils::Auth::get_auth_filter($c, 'log')], sort => {$order => 'time'}, pager => 1);
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


1;
