package Thruk::Controller::notifications;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::notifications - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index {
    my ( $c ) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_DEFAULTS);

    my($start,$end);
    my $timeframe = 86400;
    my $filter;

    my $type        = $c->req->parameters->{'type'}        || 0;
    my $archive     = $c->req->parameters->{'archive'}     || 0;
    my $contact     = $c->req->parameters->{'contact'}     || '';
    my $host        = $c->req->parameters->{'host'}        || '';
    my $service     = $c->req->parameters->{'service'}     || '';
    my $oldestfirst = $c->req->parameters->{'oldestfirst'} || 0;

    push @{$filter}, _get_log_prop_filter($type);

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

    if($host eq '' and $service eq '' and $contact eq '') {
        $host = 'all';
    }

    if($host ne '') {
        $c->stash->{infoBoxTitle}   = 'Host Notifications';
        push @{$filter}, { host_name => $host } if $host ne 'all';
    }
    if($service ne '') {
        $c->stash->{infoBoxTitle}   = 'Service Notifications';
        push @{$filter}, { service_description => $service };
    }
    if($contact ne '') {
        $c->stash->{infoBoxTitle}   = 'Contact Notifications';
        push @{$filter}, { contact_name => $contact } if $contact ne 'all';
    }

    push @{$filter}, { class => 3 };

    my $total_filter = Thruk::Utils::combine_filter('-and', $filter);

    my $order = "DESC";
    if($oldestfirst) {
        $order = "ASC";
    }


    if( defined $c->req->parameters->{'view_mode'} and $c->req->parameters->{'view_mode'} eq 'xls' ) {
        $c->stash->{'template'}   = 'excel/notifications.tt';
        $c->stash->{'file_name'}  = 'notifications.xls';
        $c->stash->{'log_filter'} = { filter => [$total_filter, Thruk::Utils::Auth::get_auth_filter($c, 'log')],
                                      sort   => {$order => 'time'},
                                    };
        return Thruk::Utils::External::perl($c, { expr => 'Thruk::Utils::logs2xls($c)', message => 'please stand by while your report is being generated...' });
    } else {
        $c->stats->profile(begin => "notifications::updatecache");
        return if $c->{'db'}->renew_logcache($c);
        $c->stats->profile(end   => "notifications::updatecache");

        $c->stats->profile(begin => "notifications::fetch");
        $c->{'db'}->get_logs(filter => [$total_filter, Thruk::Utils::Auth::get_auth_filter($c, 'log')], sort => {$order => 'time'}, pager => 1);
        $c->stats->profile(end => "notifications::fetch");
    }

    $c->stash->{oldestfirst}      = $oldestfirst;
    $c->stash->{type}             = $type;
    $c->stash->{archive}          = $archive;
    $c->stash->{start}            = $start;
    $c->stash->{end}              = $end;
    $c->stash->{host}             = $host;
    $c->stash->{service}          = $service;
    $c->stash->{contact}          = $contact;
    $c->stash->{title}            = 'Alert Notifications';
    $c->stash->{page}             = 'notifications';
    $c->stash->{template}         = 'notifications.tt';
    $c->stash->{'no_auto_reload'} = 1;

    Thruk::Utils::ssi_include($c);

    return 1;
}


##########################################################
sub _get_log_prop_filter {
    my ( $number ) = @_;

    $number = 0 if !defined $number || $number <= 0 || $number > 32767;
    my @prop_filter;
    if($number > 0) {
        my @bits = reverse split(/\ */mx, unpack("B*", pack("N", int($number))));

        if($bits[0]) {  # 1 - All service notifications
            push @prop_filter, { service_description => { '!=' => undef }};
        }
        if($bits[1]) {  # 2 - All host notifications
            push @prop_filter, { service_description => undef };
        }
        if($bits[2]) {  # 4 - Service warning
            push @prop_filter, { -and => [ state => 1, service_description => { '!=' => undef }]};
        }
        if($bits[3]) {  # 8 - Service unknown
            push @prop_filter, { -and => [ state => 3, service_description => { '!=' => undef }]};
        }
        if($bits[4]) {  # 16 - Service critical
            push @prop_filter, { -and => [ state => 2, service_description => { '!=' => undef }]};
        }
        if($bits[5]) {  # 32 - Service recovery
            push @prop_filter, { -and => [ state => 0, service_description => { '!=' => undef }]};
        }
        if($bits[6]) {  # 64 - Host down
            push @prop_filter, { -and => [ state => 1, service_description => undef ]};
        }
        if($bits[7]) {  # 128 - Host unreachable
            push @prop_filter, { -and => [ state => 2, service_description => undef ]};
        }
        if($bits[8]) {  # 256 - Host recovery
            push @prop_filter, { -and => [ state => 0, service_description => undef ]};
        }
        if($bits[9]) {  # 512 - Service acknowledgements
            push @prop_filter, { -and => [ message => { '~' => ';ACKNOWLEDGEMENT' }, service_description => { '!=' => undef }]};
        }
        if($bits[10]) {  # 1024 - Host acknowledgements
            push @prop_filter, { -and => [ message => { '~' => ';ACKNOWLEDGEMENT' }, service_description => undef ]};
        }
        if($bits[11]) {  # 2048 - Service flapping
            push @prop_filter, { -and => [ message => { '~' => ';FLAPPING' }, service_description => { '!=' => undef }]};
        }
        if($bits[12]) {  # 4096 - Host flapping
            push @prop_filter, { -and => [ message => { '~' => ';FLAPPING' }, service_description => undef ]};
        }
        if($bits[13]) {  # 8192 - Service custom
            push @prop_filter, { -and => [ message => { '~' => ';CUSTOM' }, service_description => { '!=' => undef }]};
        }
        if($bits[14]) {  # 16384 - Host custom
            push @prop_filter, { -and => [ message => { '~' => ';CUSTOM' }, service_description => undef ]};
        }
    }
    return Thruk::Utils::combine_filter('-or', \@prop_filter);
}

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
