package Thruk::Controller::showlog;

use warnings;
use strict;

use Thruk::Action::AddDefaults ();
use Thruk::Utils::Auth ();
use Thruk::Utils::External ();

=head1 NAME

Thruk::Controller::showlog - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index {
    my($c) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::Constants::ADD_CACHED_DEFAULTS);

    return if Thruk::Utils::External::render_page_in_background($c);

    my $filter = [];
    my($start,$end) = Thruk::Utils::get_start_end_from_date_select_params($c);
    my $showsites   = $c->req->parameters->{'showsites'}   || 0;
    my $oldestfirst = $c->req->parameters->{'oldestfirst'} || 0;
    my $type        = $c->req->parameters->{'type'};
    my $statetype   = $c->req->parameters->{'statetype'}   || 0;
    my $noflapping  = $c->req->parameters->{'noflapping'}  || 0;
    my $nodowntime  = $c->req->parameters->{'nodowntime'}  || 0;
    my $nosystem    = $c->req->parameters->{'nosystem'}    || 0;
    my $host        = $c->req->parameters->{'host'}        // '';
    my $service     = $c->req->parameters->{'service'}     // 'all';

    if(!defined $type) {
        $type = $c->req->uri =~ m/history\.cgi/mx ? 0 : '';
    }

    # time filter
    push @{$filter}, { time => { '>=' => $start }};
    push @{$filter}, { time => { '<'  => $end }};

    # host filter
    $host = '' if $host eq 'all';
    if($host ne '') {
        push @{$filter}, { host_name => $host };
    }

    # service filter
    if($service ne 'all' && ($service ne '' || $host ne '')) {
        push @{$filter}, { service_description => $service };
    }

    # type filter
    my $typefilter = $type eq '' ? [] : _get_log_type_filter($type);

    # normal alerts
    my @prop_filter;
    if($statetype eq "0") {
        if($type ne '') {
            push @prop_filter, { -and => [{ type => 'SERVICE ALERT'} , $typefilter ]};
            push @prop_filter, { -and => [{ type => 'HOST ALERT'} , $typefilter ]};
        }
    }
    elsif($statetype eq "1") {
        push @prop_filter, { -and => [{ type => 'SERVICE ALERT' }, { state_type => { '=' => 'SOFT' }} , $typefilter ]};
        push @prop_filter, { -and => [{ type => 'HOST ALERT' }, { state_type => { '=' => 'SOFT' }} , $typefilter ]};
    }
    if($statetype eq "2") {
        push @prop_filter, { -and => [{ type => 'SERVICE ALERT' }, { state_type=> { '=' => 'HARD' }} , $typefilter ]};
        push @prop_filter, { -and => [{ type => 'HOST ALERT' }, { state_type => { '=' => 'HARD' }} , $typefilter ]};
    }

    if($type ne '') {
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
            push @prop_filter, { class => 2 };
        }
    }

    if(defined $c->req->parameters->{'class'}) {
        push @{$filter}, { class => $c->req->parameters->{'class'} };
    }

    # join type filter together
    push @{$filter}, { -or => \@prop_filter } if scalar @prop_filter > 0;

    # additional filters set?
    my $pattern         = $c->req->parameters->{'pattern'};
    my $exclude_pattern = $c->req->parameters->{'exclude_pattern'};
    my $errors = 0;
    if(defined $pattern && $pattern !~ m/^\s*$/mx) {
        $errors++ unless(Thruk::Utils::is_valid_regular_expression($c, $pattern));
        push @{$filter}, { message => { '~~' => $pattern }};
    }
    if(defined $exclude_pattern && $exclude_pattern !~ m/^\s*$/mx) {
        $errors++ unless Thruk::Utils::is_valid_regular_expression($c, $exclude_pattern);
        push @{$filter}, { message => { '!~~' => $exclude_pattern }};
    }
    if($service ne '' && $service ne 'all') {
        push @{$filter}, {
                -or => [
                        { -and => [
                            { host_name           => $host || '.*' },
                            { service_description => $service},
                        ]},
                        $c->config->{'logcache'} ? {} : { -and => [
                            {type    => 'EXTERNAL COMMAND' },
                            {message => { '~~' => '(\s|;)'.($host ? quotemeta($host) : '.*').';'.quotemeta($service).'(;|$)' }},
                        ]},
                ],
        };
    }
    elsif($host) {
        push @{$filter}, {
                -or => [
                        { host_name => $host },
                        $c->config->{'logcache'} ? {} : { -and => [
                            {type    => 'EXTERNAL COMMAND' },
                            {message => { '~~' => '(\s|;)'.quotemeta($host).'(;|$)' }},
                        ]},
                ],
        };
    }

    my $total_filter;
    if($errors == 0) {
        $total_filter = Thruk::Utils::combine_filter('-and', $filter);
    }

    my $order = "DESC";
    if($oldestfirst) {
        $order = "ASC";
    }

    if( defined $c->req->parameters->{'view_mode'} and $c->req->parameters->{'view_mode'} eq 'xls' ) {
        $c->stash->{'template'}   = 'excel/logs.tt';
        $c->stash->{'file_name'}  = 'logs.xls';
        $c->stash->{'log_filter'} = { filter => [$total_filter, Thruk::Utils::Auth::get_auth_filter($c, 'log')],
                                      sort => {$order => 'time'},
                                    };
        return Thruk::Utils::External::perl($c, { expr => 'Thruk::Utils::logs2xls($c)', message => 'please stand by while your report is being generated...' });
    } else {
        $c->stats->profile(begin => "showlog::updatecache");
        $c->db->renew_logcache($c);
        $c->stats->profile(end   => "showlog::updatecache");

        $c->stats->profile(begin => "showlog::fetch");
        $c->stash->{'logs_from_compacted_zone'} = 0;
        $c->db->get_logs(filter => [$total_filter, Thruk::Utils::Auth::get_auth_filter($c, 'log')], sort => {$order => 'time'}, pager => 1, limit => 1000000); # not using a limit here, makes mysql not use an index
        $c->stats->profile(end   => "showlog::fetch");
    }

    $c->stash->{pattern}          = $pattern         || '';
    $c->stash->{exclude_pattern}  = $exclude_pattern || '';
    $c->stash->{type}             = $type;
    $c->stash->{statetype}        = $statetype;
    $c->stash->{noflapping}       = $noflapping;
    $c->stash->{nodowntime}       = $nodowntime;
    $c->stash->{nosystem}         = $nosystem;
    $c->stash->{oldestfirst}      = $oldestfirst;
    $c->stash->{showsites}        = $showsites;
    $c->stash->{start}            = $start;
    $c->stash->{end}              = $end;
    $c->stash->{host}             = $host    || '';
    $c->stash->{service}          = $service || '';
    $c->stash->{title}            = 'Log File';
    $c->stash->{infoBoxTitle}     = $type eq '' ? 'Event Log' : 'Alert History';
    $c->stash->{page}             = 'showlog';
    $c->stash->{template}         = 'showlog.tt';
    $c->stash->{'no_auto_reload'} = 1;

    return 1;
}

##########################################################
sub _get_log_type_filter {
    my ( $number ) = @_;

    $number = 0 if !defined $number || $number <= 0 || $number > 511;
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

1;
