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

=head2 index

=cut

##########################################################
sub index {
    my ( $c ) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::Constants::ADD_CACHED_DEFAULTS);

    return if Thruk::Utils::External::render_page_in_background($c);

    my($start,$end) = Thruk::Utils::get_start_end_from_date_select_params($c);
    my $oldestfirst = $c->req->parameters->{'oldestfirst'} || 0;
    my $showsites   = $c->req->parameters->{'showsites'}   || 0;

    my $filter;
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
                        $c->config->{'logcache'} ? {} : { -and => [
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
                        $c->config->{'logcache'} ? {} : { -and => [
                            {type    => 'EXTERNAL COMMAND' },
                            {message => { '~~' => '(\s|;)'.quotemeta($host).'(;|$)' }},
                        ]},
                ],
        };
    }
    $c->stash->{'host'}    = $host;
    $c->stash->{'service'} = $service;

    if(defined $c->req->parameters->{'class'}) {
        push @{$filter}, { class => $c->req->parameters->{'class'} };
    }
    if(defined $c->req->parameters->{'type'}) {
        push @{$filter}, { type => $c->req->parameters->{'type'} };
    }

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
                                       sort   => {$order => 'time'},
                                     };
        return Thruk::Utils::External::perl($c, { expr => 'Thruk::Utils::logs2xls($c)', message => 'please stand by while your report is being generated...' });
    } else {
        $c->stats->profile(begin => "showlog::updatecache");
        $c->{'db'}->renew_logcache($c);
        $c->stats->profile(end   => "showlog::updatecache");

        $c->stats->profile(begin => "showlog::fetch");
        $c->stash->{'logs_from_compacted_zone'} = 0;
        $c->{'db'}->get_logs(filter => [$total_filter, Thruk::Utils::Auth::get_auth_filter($c, 'log')], sort => {$order => 'time'}, pager => 1, limit => 1000000); # not using a limit here, makes mysql not use an index
        $c->stats->profile(end   => "showlog::fetch");
    }

    if($c->stash->{'logs_from_compacted_zone'}) {
        $c->stash->{has_jquery_ui} = 1;
    }

    $c->stash->{start}            = $start;
    $c->stash->{end}              = $end;
    $c->stash->{pattern}          = $pattern         || '';
    $c->stash->{exclude_pattern}  = $exclude_pattern || '';
    $c->stash->{oldestfirst}      = $oldestfirst;
    $c->stash->{showsites}        = $showsites;
    $c->stash->{title}            = 'Log File';
    $c->stash->{infoBoxTitle}     = 'Event Log';
    $c->stash->{page}             = 'showlog';
    $c->stash->{template}         = 'showlog.tt';
    $c->stash->{'no_auto_reload'} = 1;

    Thruk::Utils::ssi_include($c);

    return 1;
}


1;
