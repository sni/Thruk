package Thruk::Controller::history;

use strict;
use warnings;
use utf8;
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
    my $timeframe = 86400;
    my $filter;

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

    # type filter
    my $typefilter = $self->_get_log_type_filter($type);

    # normal alerts
    my @prop_filter;
    if($statetype == 0) {
        push @prop_filter, { -and => [{ type => 'SERVICE ALERT'} , $typefilter ]};
        push @prop_filter, { -and => [{ type => 'HOST ALERT'} , $typefilter ]};
    }
    elsif($statetype == 1) {
        push @prop_filter, { -and => [{ type => 'SERVICE ALERT', options => { '~' => ';SOFT;' }} , $typefilter ]};
        push @prop_filter, { -and => [{ type => 'HOST ALERT', options => { '~' => ';SOFT;' }} , $typefilter ]};
    }
    if($statetype == 2) {
        push @prop_filter, { -and => [{ type => 'SERVICE ALERT', options => { '~' => ';HARD;' }} , $typefilter ]};
        push @prop_filter, { -and => [{ type => 'HOST ALERT', options => { '~' => ';HARD;' }} , $typefilter ]};
    }

    # add flapping messages
    unless($noflapping) {
        push @prop_filter, { type => 'SERVICE FLAPPING ALERT' };
        push @prop_filter, { type => 'HOST FLAPPING ALERT' };
    }

    # add downtime messages
    unless($nodowntime) {
        push @prop_filter, { type => 'SERVICE DOWNTIME ALERT' };
        push @prop_filter, { type => 'HOST DOWNTIME ALERT' };
    }

    # add system messages
    unless($nosystem) {
        push @prop_filter, { type => { '~' => 'starting\.\.\.' }};
        push @prop_filter, { type => { '~' => 'shutting\ down\.\.\.' }};
    }

    # join type filter together
    push @{$filter}, { -or => \@prop_filter };

    # service filter
    if(defined $service and $host ne 'all') {
        push @{$filter}, { host_name => $host };
        push @{$filter}, { service_description => $service };
    }
    # host filter
    elsif($host ne 'all') {
        push @{$filter}, { host_name => $host };
    }

    my $total_filter = Thruk::Utils::combine_filter('-and', $filter);

    my $order = "DESC";
    if($oldestfirst) {
        $order = "ASC";
    }

    if( defined $c->{'request'}->{'parameters'}->{'view_mode'} and $c->{'request'}->{'parameters'}->{'view_mode'} eq 'xls' ) {
        $c->stash->{'template'}   = 'excel/logs.tt';
        $c->stash->{'file_name'}  = 'history.xls';
        $c->stash->{'log_filter'} = { filter => [$total_filter, Thruk::Utils::Auth::get_auth_filter($c, 'log')],
                                      sort => {$order => 'time'},
                                    };
        my $id = Thruk::Utils::External::perl($c, { expr => 'Thruk::Utils::logs2xls($c)', message => 'please stand by while your report is being generated...' });
        return $c->redirect($c->stash->{'url_prefix'}."thruk/cgi-bin/job.cgi?job=".$id);
    } else {
        $c->stats->profile(begin => "history::fetch");
        $c->{'db'}->get_logs(filter => [$total_filter, Thruk::Utils::Auth::get_auth_filter($c, 'log')], sort => {$order => 'time'}, pager => $c);
        $c->stats->profile(end => "history::fetch");
    }

    $c->stash->{archive}          = $archive;
    $c->stash->{type}             = $type;
    $c->stash->{statetype}        = $statetype;
    $c->stash->{noflapping}       = $noflapping;
    $c->stash->{nodowntime}       = $nodowntime;
    $c->stash->{nosystem}         = $nosystem;
    $c->stash->{oldestfirst}      = $oldestfirst;
    $c->stash->{start}            = $start;
    $c->stash->{end}              = $end;
    $c->stash->{host}             = $host    || '';
    $c->stash->{service}          = $service || '';
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
    my @prop_filter;
    if($number > 0) {
        my @bits = reverse split(/\ */mx, unpack("B*", pack("N", int($number))));

        if($bits[0]) {  # 1 - All service alerts
            push @prop_filter, { service_description => { '!=' => undef }};
        }
        if($bits[1]) {  # 2 - All host alerts
            push @prop_filter, { service_description => undef };
        }
        if($bits[2]) {  # 4 - Service warning
            push @prop_filter, { state => 1, service_description => { '!=' => undef }};
        }
        if($bits[3]) {  # 8 - Service unknown
            push @prop_filter, { state => 3, service_description => { '!=' => undef }};
        }
        if($bits[4]) {  # 16 - Service critical
            push @prop_filter, { state => 2, service_description => { '!=' => undef }};
        }
        if($bits[5]) {  # 32 - Service recovery
            push @prop_filter, { state => 0, service_description => { '!=' => undef }};
        }
        if($bits[6]) {  # 64 - Host down
            push @prop_filter, { state => 1, service_description => undef };
        }
        if($bits[7]) {  # 128 - Host unreachable
            push @prop_filter, { state => 2, service_description => undef };
        }
        if($bits[8]) {  # 256 - Host recovery
            push @prop_filter, { state => 0, service_description => undef };
        }
    }
    return Thruk::Utils::combine_filter('-or', \@prop_filter);
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
