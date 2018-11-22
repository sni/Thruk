package Thruk::Controller::cmd;

use strict;
use warnings;
use Data::Dumper;

=head1 NAME

Thruk::Controller::cmd - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

=head2 index

=cut

##########################################################
sub index {
    my( $c ) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_CACHED_DEFAULTS);

    my $errors = 0;

    $c->stash->{'now'}               = time();
    $c->stash->{title}               = "External Command Interface";
    $c->stash->{infoBoxTitle}        = "External Command Interface";
    $c->stash->{no_auto_reload}      = 1;
    $c->stash->{page}                = 'cmd';
    $c->stash->{'form_errors'}       = [];
    $c->stash->{'commands2send'}     = {};
    $c->stash->{'extra_log_comment'} = {};

    # fill in some defaults
    for my $param (qw/send_notification plugin_output performance_data sticky_ack force_notification broadcast_notification fixed ahas com_data persistent hostgroup host service force_check childoptions ptc use_expire servicegroup backend/) {
        $c->req->parameters->{$param} = '' unless defined $c->req->parameters->{$param};
    }
    for my $param (qw/com_id down_id hours minutes start_time end_time expire_time plugin_state trigger not_dly/) {
        $c->req->parameters->{$param} = 0 unless defined $c->req->parameters->{$param};
    }

    $c->req->parameters->{com_data} =~ s/\n//gmx;

    Thruk::Utils::ssi_include($c);

    $c->stash->{'cmd_typ'} = $c->req->parameters->{'cmd_typ'} || '';

    # check if authorization is enabled
    if( $c->config->{'cgi_cfg'}->{'use_authentication'} == 0 and $c->config->{'cgi_cfg'}->{'use_ssl_authentication'} == 0 ) {
        return $c->detach('/error/index/3');
    }

    # read only user?
    return $c->detach('/error/index/11') if $c->check_user_roles('authorized_for_read_only');

    # set authorization information
    my $query_options = { Slice => 1 };
    if( defined $c->req->parameters->{'backend'} ) {
        my $backend = $c->req->parameters->{'backend'};
        $query_options = { Slice => 1, Backend => [$backend] };
    }

    _set_host_service_from_down_com_ids($c);

    my $host_quick_commands = {
        1  => 96,    # reschedule host check
        2  => 55,    # schedule downtime
        3  => 1,     # add comment
        4  => 33,    # add acknowledgement
        5  => 78,    # remove active downtimes
        6  => 20,    # remove all comments
        7  => 51,    # remove acknowledgement
        8  => 47,    # enable active checks
        9  => 48,    # disable active checks
        10 => 24,    # enable notifications
        11 => 25,    # disable notifications
        12 => 87,    # submit passive check result
        13 => 2,     # delete single comment
        14 => 154,   # reset modified attributes
    };
    my $service_quick_commands = {
        1  => 7,     # reschedule service check
        2  => 56,    # schedule downtime
        3  => 3,     # add comment
        4  => 34,    # acknowledge
        5  => 79,    # remove active downtimes
        6  => 21,    # remove all comments
        7  => 52,    # remove acknowledgement
        8  => 5,     # enable active checks
        9  => 6,     # disable active checks
        10 => 22,    # enable notifications
        11 => 23,    # disable notifications
        12 => 30,    # submit passive check result
        13 => 4,     # delete single comment
        14 => 155,   # reset modified attributes
    };

    # did we receive a quick command from the status page?
    my $quick_command = $c->req->parameters->{'quick_command'};
    my $quick_confirm = $c->req->parameters->{'confirm'};
    if( defined $quick_confirm and $quick_confirm eq 'no' ) {
        $c->req->parameters->{'cmd_typ'} = 'c'.$quick_command;
        delete $c->req->parameters->{'cmd_mod'};
        $c->stash->{'cmd_typ'} = 'c'.$quick_command;
        _check_for_commands($c);
    }
    elsif( defined $quick_command and $quick_command or $c->stash->{'cmd_typ'} =~ m/^c(\d+)$/mx ) {
        if(defined $1) {
            $quick_command = $1;
            my $backends = $c->req->parameters->{'backend'};
            if(ref $c->req->parameters->{'backend'} eq 'ARRAY') {
                $backends = join('|', @{$c->req->parameters->{'backend'}});
            }
            if(defined $c->req->parameters->{'service'} and $c->req->parameters->{'service'} ne '') {
                $c->req->parameters->{'selected_services'} =
                        $c->req->parameters->{'host'}
                        .';'.$c->req->parameters->{'service'}
                        .';'.$backends;
            } else {
                $c->req->parameters->{'selected_hosts'}    =
                        $c->req->parameters->{'host'}
                        .';;'.$backends;
            }
        }
        my $cmd_typ;
        $c->req->parameters->{'cmd_mod'}           = 2;
        $c->req->parameters->{'trigger'}           = 0;
        $c->req->parameters->{'selected_hosts'}    = '' unless defined $c->req->parameters->{'selected_hosts'};
        $c->req->parameters->{'selected_services'} = '' unless defined $c->req->parameters->{'selected_services'};
        $c->req->parameters->{'selected_ids'}      = '' unless defined $c->req->parameters->{'selected_ids'};
        my @hostdata    = split /,/mx, $c->req->parameters->{'selected_hosts'};
        my @servicedata = split /,/mx, $c->req->parameters->{'selected_services'};
        my @idsdata     = split /,/mx, $c->req->parameters->{'selected_ids'};
        $c->{'spread_startdates'} = generate_spread_startdates( $c, scalar @hostdata + scalar @servicedata, $c->req->parameters->{'start_time'}, $c->req->parameters->{'spread'} );

        # persistent can be set in two ways
        if(    $c->req->parameters->{'persistent'} eq 'ack'
           and $c->req->parameters->{'persistent_ack'}) {
            $c->req->parameters->{'persistent'} = 1;
        }
        elsif(    $c->req->parameters->{'persistent'} eq 'comments'
           and $c->req->parameters->{'persistent_comments'}) {
            $c->req->parameters->{'persistent'} = 1;
        }
        else {
            $c->req->parameters->{'persistent'} = 0;
        }

        # comments / downtimes quick commands
        for my $id (@idsdata) {
            my($typ, $id, $backend) = split(/_/m,$id, 3);
            $c->{'db'}->enable_backends($backend, 1);
            if($typ eq 'hst' and defined $host_quick_commands->{$quick_command} ) {
                $cmd_typ = $host_quick_commands->{$quick_command};
            }
            elsif($typ eq 'svc' and defined $service_quick_commands->{$quick_command} ) {
                $cmd_typ = $service_quick_commands->{$quick_command};
            }
            else {
                return $c->detach('/error/index/7');
            }
            $c->req->parameters->{'cmd_typ'} = $cmd_typ;
            if($quick_command == 5) {
                $c->req->parameters->{'down_id'} = $id;
            } elsif($quick_command == 13 ) {
                $c->req->parameters->{'com_id'}  = $id;
            }
            _set_host_service_from_down_com_ids($c);
            if( _do_send_command($c) ) {
                $c->log->debug("command succeeded");
            }
            else {
                $errors++;
                Thruk::Utils::set_message( $c, 'fail_message', "command failed" );
            }
        }

        # host quick commands
        for my $hostdata (@hostdata) {
            if( defined $host_quick_commands->{$quick_command} ) {
                $cmd_typ = $host_quick_commands->{$quick_command};
            }
            else {
                return $c->detach('/error/index/7');
            }
            #my( $host, $service, $backend )...
            my( $host, undef, $backend ) = split /;/mx, $hostdata;
            my @backends                 = split /\|/mx, defined $backend ? $backend : '';
            $c->stash->{'lasthost'}      = $host;
            $c->req->parameters->{'cmd_typ'} = $cmd_typ;
            $c->req->parameters->{'host'}    = $host;
            $c->{'db'}->enable_backends(\@backends, 1);
            if( $quick_command == 5 ) {
                if($c->req->parameters->{'active_downtimes'}) {
                    _remove_all_downtimes( $c, $host, undef, 'active' );
                }
                if($c->req->parameters->{'future_downtimes'}) {
                    _remove_all_downtimes( $c, $host, undef, 'future' );
                }
            }
            else {
                if( _do_send_command($c) ) {
                    $c->log->debug("command for host $host succeeded");
                }
                else {
                    $errors++;
                    if($c->stash->{'thruk_message'}) {
                        Thruk::Utils::append_message( $c, "\ncommand for host $host failed" );
                    } else {
                        Thruk::Utils::set_message( $c, 'fail_message', "command for host $host failed" );
                    }
                    Thruk::Utils::append_message( $c, ', '.$c->stash->{'form_errors'}->[0]{'message'}) if $c->stash->{'form_errors'}->[0];
                    $c->log->debug("command for host $host failed");
                    $c->log->debug( Dumper( $c->stash->{'form_errors'} ) );
                }
            }
        }

        # service quick commands
        for my $servicedata ( split /,/mx, $c->req->parameters->{'selected_services'} ) {
            if( defined $service_quick_commands->{$quick_command} ) {
                $cmd_typ = $service_quick_commands->{$quick_command};
            }
            else {
                return $c->detach('/error/index/7');
            }
            my( $host, $service, $backend ) = split /;/mx, $servicedata;
            my @backends                    = split /\|/mx, $backend;
            $c->stash->{'lasthost'}         = $host;
            $c->stash->{'lastservice'}      = $service;
            $c->req->parameters->{'cmd_typ'} = $cmd_typ;
            $c->req->parameters->{'host'}    = $host;
            $c->req->parameters->{'service'} = $service;
            $c->{'db'}->enable_backends(\@backends, 1);
            if( $quick_command == 5 ) {
                if($c->req->parameters->{'active_downtimes'}) {
                    _remove_all_downtimes( $c, $host, $service, 'active' );
                }
                if($c->req->parameters->{'future_downtimes'}) {
                    _remove_all_downtimes( $c, $host, $service, 'future' );
                }
            }
            else {
                if( _do_send_command($c) ) {
                    $c->log->debug("command for $service on host $host succeeded");
                }
                else {
                    $errors++;
                    if($c->stash->{'thruk_message'}) {
                        Thruk::Utils::append_message( $c, "\ncommand for $service on host $host failed" );
                    } else {
                        Thruk::Utils::set_message( $c, 'fail_message', "command for $service on host $host failed" );
                    }
                    Thruk::Utils::append_message( $c, ', '.$c->stash->{'form_errors'}->[0]{'message'}) if $c->stash->{'form_errors'}->[0];
                    $c->log->debug("command for $service on host $host failed");
                    $c->log->debug( Dumper( $c->stash->{'form_errors'} ) );
                }
            }
        }

        Thruk::Utils::set_message( $c, 'success_message', 'Commands successfully submitted' ) unless $errors;
        delete $c->req->parameters->{'backend'};
        _redirect_or_success( $c, -1 );
    }

    # normal page call
    else {
        _check_for_commands($c);
    }

    if($c->req->parameters->{'json'} and $c->stash->{'form_errors'}) {
        my $json = {'success' => ($c->stash->{'form_errors'} && scalar @{$c->stash->{'form_errors'}}) > 0 ? 0 : 1, errors => $c->stash->{'form_errors'} };
        return $c->render(json => $json);
    }

    return 1;
}

######################################
# remove downtimes
sub _remove_all_downtimes {
    my( $c, $host, $service, $type ) = @_;

    my $backends = $c->req->parameters->{'backend'};

    # send the command
    my $options = {};
    $options->{backend}  = $backends if defined $backends;
    $options->{'filter'} = [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), host_name => $host, service_description => $service ];

    # active downtimes
    my $now = time();
    if($type eq 'active') {
        push @{$options->{'filter'}}, start_time => { '<=' => $now };
    }
    elsif($type eq 'future') {
        push @{$options->{'filter'}}, start_time => { '>=' => $now };
    }

    # get list of all downtimes
    my $data = $c->{'db'}->get_downtimes(%{$options});
    my @ids     = keys %{Thruk::Utils::array2hash($data, 'id')};
    for my $id ( @ids ) {
        $c->req->parameters->{'down_id'} = $id;
        if( _do_send_command($c) ) {
            $c->log->debug("removing downtime $id succeeded");
            Thruk::Utils::set_message( $c, 'success_message', "removing downtime $id succeeded" );
        }
        else {
            $c->log->debug("removing downtime $id failed");
            Thruk::Utils::set_message( $c, 'fail_message', "removing downtime $id failed" );
            $c->log->debug( Dumper( $c->stash->{'form_errors'} ) );
        }
    }

    return 1;
}

######################################
# command disabled by config?
sub _check_for_commands {
    my( $c ) = @_;

    my $cmd_typ = $c->req->parameters->{'cmd_typ'};
    my $cmd_mod = $c->req->parameters->{'cmd_mod'} || 0;
    return $c->detach('/error/index/6') unless defined $cmd_typ;

    if(Thruk::Utils::command_disabled($c, $cmd_typ)) {
        return $c->detach('/error/index/12');
    }

    # command commited?
    $c->stash->{'use_csrf'} = 1;
    if( $cmd_mod == 2 and _do_send_command($c) ) {
        Thruk::Utils::set_message( $c, 'success_message', 'Commands successfully submitted' );
        _redirect_or_success( $c, -2 );
    }
    else {
        # no command submited, view commands page (can be nonnumerical)
        if( $cmd_typ eq "55" or $cmd_typ eq "56" or $cmd_typ eq "86" ) {
            $c->stash->{'hostdowntimes'}    = $c->{'db'}->get_downtimes(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), service_description => undef ]);
            $c->stash->{'servicedowntimes'} = $c->{'db'}->get_downtimes(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), service_description => { '!=' => undef } ]);
        }

        $c->stash->{'backend'} = $c->req->parameters->{'backend'} || '';

        my $comment_author = $c->user->get('username');
        $comment_author = $c->user->get('alias') if $c->user->get('alias');
        $c->stash->{comment_author} = $comment_author;
        $c->stash->{cmd_tt}         = 'cmd.tt';
        $c->stash->{template}       = 'cmd/cmd_typ_' . $cmd_typ . '.tt';

        # set a valid referer
        my $referer = $c->req->parameters->{'referer'} || $c->req->header('referer') || '';
        $referer =~ s/&amp;/&/gmx;
        $referer =~ s/&/&amp;/gmx;
        $c->stash->{referer} = $referer;
    }

    return 1;
}

######################################
# view our success page or redirect to referer
sub _redirect_or_success {
    my( $c, $how_far_back, $just_return ) = @_;

    my $wait = defined $c->config->{'use_wait_feature'} ? $c->config->{'use_wait_feature'} : 0;
    if(bulk_send($c, $c->stash->{'commands2send'})) {
        $c->log->debug("bulk sending commands succeeded");
    } else {
        Thruk::Utils::set_message( $c, 'fail_message', 'Sending Commands failed' );
        $wait = 0;
    }

    # no need to wait when no command was sent
    if(defined $ENV{'THRUK_NO_COMMANDS'} or $c->req->parameters->{'test_only'}) {
        $wait = 0;
    }

    # only wait if we got original backends
    my $backends = Thruk::Utils::list($c->req->parameters->{'backend'});
    if($wait and defined $c->req->parameters->{'backend.orig'}) {
        my $backends_str = join('|', @{$backends});
        my $backendsorig = join('|', @{Thruk::Utils::list($c->req->parameters->{'backend.orig'})});
        $wait = 0 if $backends_str ne $backendsorig;
    }

    my $has_spaces = 0;
    my $seperator  = ';';
    # skip hosts and services containing spaces
    # livestatus supports semicolon since version 1.1.11 i3
    if(   $c->stash->{'lasthost'}    =~ m/\s+/gmx
       or $c->stash->{'lastservice'} =~ m/\s+/gmx) {
       $has_spaces = 1;
    }

    # skip wait feature on old livestatus versions
    # wait feature has been introduced with version 1.1.3
    for my $b (@{$backends}) {
        my $v = $c->stash->{'pi_detail'}->{$b}->{'data_source_version'};
        next unless defined $v;
        next if $v =~ m/\-naemon$/mx;
        next unless $v =~ m/^Livestatus\s(.*)$/mx;
        my $v_num = $1;
        if(!Thruk::Utils::version_compare($v_num, '1.1.3')) {
            $wait = 0;
        }
        if(!Thruk::Utils::version_compare($v_num, '1.1.12')) {
            $seperator = ' ';
            # won't work with spaces in that version
            if($has_spaces) {
                $wait = 0;
            }
        }
    }

    $c->stash->{how_far_back} = $how_far_back;

    my $referer = $c->req->parameters->{'referer'} || '';
    if( $referer ne '' or $c->req->parameters->{'json'}) {
        # send a wait header?
        if(    $wait
           and defined $c->stash->{'lasthost'}
           and defined $c->stash->{'start_time_unix'}
           and $c->stash->{'start_time_unix'} <= $c->stash->{'now'}
        ) {
            my($waitcondition);
            # reschedules
            if($c->req->parameters->{'cmd_typ'} == 7 or $c->req->parameters->{'cmd_typ'} == 96) {
                $waitcondition = 'last_check >= '.$c->stash->{'now'};
            }
            # add downtime
            if($c->req->parameters->{'cmd_typ'} == 55 or $c->req->parameters->{'cmd_typ'} == 56) {
                $waitcondition = 'scheduled_downtime_depth > 0';
            }
            # remove downtime
            if($c->req->parameters->{'cmd_typ'} == 78 or $c->req->parameters->{'cmd_typ'} == 79) {
                $waitcondition = 'scheduled_downtime_depth = 0';
            }
            # add acknowledged
            if($c->req->parameters->{'cmd_typ'} == 33 or $c->req->parameters->{'cmd_typ'} == 34) {
                $waitcondition = 'acknowledged = 1';
            }
            # remove acknowledged
            if($c->req->parameters->{'cmd_typ'} == 51 or $c->req->parameters->{'cmd_typ'} == 52) {
                $waitcondition = 'acknowledged = 0';
            }
            if($waitcondition and $c->stash->{'lasthost'}) {
                my $options = {
                            'header' => {
                                'WaitTimeout'   => ($c->config->{'wait_timeout'} * 1000),
                                'WaitTrigger'   => 'all', # using something else seems not to work all the time
                                'WaitCondition' => $waitcondition,
                            },
                };
                eval { # this query is not critical, so it can safely fail
                    if(!defined $c->stash->{'lastservice'} || $c->stash->{'lastservice'} eq '') {
                        $options->{'header'}->{'WaitObject'} = $c->stash->{'lasthost'};
                        $c->{'db'}->get_hosts(  filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ),
                                                           { 'name' => $c->stash->{'lasthost'} } ],
                                                columns => [ 'name' ],
                                                options => $options,
                                            );
                    }
                    if(defined $c->stash->{'lastservice'} and $c->stash->{'lastservice'} ne '') {
                        $options->{'header'}->{'WaitObject'} = $c->stash->{'lasthost'}.$seperator.$c->stash->{'lastservice'};
                        $c->{'db'}->get_services( filter  => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ),
                                                              { 'host_name'   => $c->stash->{'lasthost'} },
                                                              { 'description' => $c->stash->{'lastservice'} },
                                                             ],
                                                  columns => [ 'description' ],
                                                  options => $options,
                                                );
                    }
                };
                $c->log->debug(Dumper($@)) if $@;
                if(defined $c->stash->{'additional_wait'}) {
                    sleep(1);
                }
            }
        }
        else {
            # just do nothing for a second
            sleep(1);
        }

        return if $just_return;
        if($c->req->parameters->{'json'}) {
            my $json = {'success' => 1};
            return $c->render(json => $json);
        }
        else {
            $c->redirect_to($referer);
        }
    }
    else {
        return if $just_return;
        if($c->req->parameters->{'json'}) {
            my $json = {'success' => 1};
            return $c->render(json => $json);
        }
        $c->stash->{template} = 'cmd_success.tt';
    }

    return;
}

######################################
# sending commands
sub _do_send_command {
    my( $c ) = @_;

    if($c->stash->{'use_csrf'}) {
        return unless Thruk::Utils::check_csrf($c);
    }

    my $cmd_typ = $c->req->parameters->{'cmd_typ'};
    return $c->detach('/error/index/6') unless defined $cmd_typ;

    # locked author names?
    if( $c->config->{'cgi_cfg'}->{'lock_author_names'} || !defined $c->req->parameters->{'com_author'} ) {
        my $author = $c->user->get('username');
        $author = $c->user->get('alias') if $c->user->get('alias');
        $c->req->parameters->{'com_author'} = $author;
    }

    # replace parsed dates
    my $start_time_unix = 0;
    my $end_time_unix   = 0;
    if( ref $c and defined $c->{'spread_startdates'} and scalar @{ $c->{'spread_startdates'} } > 0 ) {
        my $new_start_time = shift @{ $c->{'spread_startdates'} };
        my $new_date = Thruk::Utils::format_date( $new_start_time, '%Y-%m-%d %H:%M:%S' );
        $c->log->debug( "setting spreaded start date to: " . $new_date );
        $c->req->parameters->{'start_time'} = $new_date;
        $start_time_unix = $new_start_time;
    }
    elsif ( $c->req->parameters->{'start_time'} ) {
        if( $c->req->parameters->{'start_time'} !~ m/(\d{4})\-(\d{2})\-(\d{2})\ (\d{2}):(\d{2}):(\d{2})/mx ) {
            my $new_date = Thruk::Utils::format_date( Thruk::Utils::parse_date( $c, $c->req->parameters->{'start_time'} ), '%Y-%m-%d %H:%M:%S' );
            $c->log->debug( "setting start date to: " . $new_date );
            $c->req->parameters->{'start_time'} = $new_date;
        }
        $start_time_unix = Thruk::Utils::parse_date( $c, $c->req->parameters->{'start_time'} );
    }
    if( $c->req->parameters->{'end_time'} ) {
        if( $c->req->parameters->{'end_time'} !~ m/(\d{4})\-(\d{2})\-(\d{2})\ (\d{2}):(\d{2}):(\d{2})/mx ) {
            my $new_date = Thruk::Utils::format_date( Thruk::Utils::parse_date( $c, $c->req->parameters->{'end_time'} ), '%Y-%m-%d %H:%M:%S' );
            $c->log->debug( "setting end date to: " . $new_date );
            $c->req->parameters->{'end_time'} = $new_date;
        }
        $end_time_unix = Thruk::Utils::parse_date( $c, $c->req->parameters->{'end_time'} );
    }
    if( $c->req->parameters->{'use_expire'}
       and ($cmd_typ == 33 or $cmd_typ == 34)
      ) {
        if($c->req->parameters->{'expire_time'}) {
            if( $c->req->parameters->{'expire_time'} !~ m/(\d{4})\-(\d{2})\-(\d{2})\ (\d{2}):(\d{2}):(\d{2})/mx ) {
                my $new_date = Thruk::Utils::format_date( Thruk::Utils::parse_date( $c, $c->req->parameters->{'expire_time'} ), '%Y-%m-%d %H:%M:%S' );
                $c->log->debug( "setting expire date to: " . $new_date );
                $c->req->parameters->{'expire_time'} = $new_date;
            }
            if($c->req->parameters->{'expire_time'}) {
                $end_time_unix = Thruk::Utils::parse_date( $c, $c->req->parameters->{'expire_time'} );
            }
            $c->req->parameters->{'end_time'} = $c->req->parameters->{'expire_time'};
        }
        unless(defined $c->stash->{'com_data_adjusted'}) {
            $c->req->parameters->{'com_data'} .= ' - The acknowledgement expires at: '.$c->req->parameters->{'end_time'}.'.';
            $c->stash->{'com_data_adjusted'}       = 1;
        }
    }

    return 1 if _check_reschedule_alias($c);

    if(Thruk::Utils::command_disabled($c, $cmd_typ)) {
        return $c->detach('/error/index/12');
    }

    local $c->{'errored'} = 0;
    my $cmd;
    eval {
        Thruk::Views::ToolkitRenderer::render($c, 'cmd/cmd_typ_' . $cmd_typ . '.tt',
            {   c                         => $c,
                cmd_tt                    => 'cmd_line.tt',
                start_time_unix           => $start_time_unix,
                end_time_unix             => $end_time_unix,
                die_on_errors             => 1,
                theme                     => $c->stash->{'theme'},
                url_prefix                => $c->stash->{'url_prefix'},
                has_expire_acks           => $c->stash->{'has_expire_acks'},
                downtime_duration         => $c->stash->{'downtime_duration'},
                expire_ack_duration       => $c->stash->{'expire_ack_duration'},
                force_persistent_comments => $c->stash->{'force_persistent_comments'},
                force_sticky_ack          => $c->stash->{'force_sticky_ack'},
                force_send_notification   => $c->stash->{'force_send_notification'},
                force_persistent_ack      => $c->stash->{'force_persistent_ack'},
                comment_author            => '',
                hostdowntimes             => '',
                servicedowntimes          => '',
        }, \$cmd);
        $cmd =~ s/^\s+//gmx;
        $cmd =~ s/\s+$//gmx;
    };
    if($@) {
        if($@ =~ m/error\ \-\ (.*?)\ at\ /gmx) {
            push @{$c->stash->{'form_errors'}}, $1;
        } else {
            $c->log->error('error in first cmd/cmd_typ_' . $cmd_typ . '.tt: '.$@);
        }
    }

    # unknown command given?
    return $c->detach('/error/index/7') unless defined $cmd;

    # unauthorized?
    return $c->detach('/error/index/10') unless $cmd ne '';

    # check for required fields
    my($form, @errors, $required_fields);
    eval {
        Thruk::Views::ToolkitRenderer::render($c, 'cmd/cmd_typ_' . $cmd_typ . '.tt',
            {   c                         => $c,
                cmd_tt                    => '_get_content.tt',
                start_time_unix           => $start_time_unix,
                end_time_unix             => $end_time_unix,
                theme                     => $c->stash->{'theme'},
                url_prefix                => $c->stash->{'url_prefix'},
                has_expire_acks           => $c->stash->{'has_expire_acks'},
                downtime_duration         => $c->stash->{'downtime_duration'},
                expire_ack_duration       => $c->stash->{'expire_ack_duration'},
                force_persistent_comments => $c->stash->{'force_persistent_comments'},
                force_sticky_ack          => $c->stash->{'force_sticky_ack'},
                force_send_notification   => $c->stash->{'force_send_notification'},
                force_persistent_ack      => $c->stash->{'force_persistent_ack'},
                comment_author            => '',
                hostdowntimes             => '',
                servicedowntimes          => '',
        }, \$form);
    };
    if($@) {
        $c->error('error in second cmd/cmd_typ_' . $cmd_typ . '.tt: '.$@);
        return;
    }
    if( my @matches = $form =~ m/class='(optBoxRequiredItem|optBoxItem)'>(.*?):<\/td>.*?input\s+type='.*?'\s+name='(.*?)'/gmx ) {
        while ( scalar @matches > 0 ) {
            my $req  = shift @matches;
            my $name = shift @matches;
            my $key  = shift @matches;
            if( $req eq 'optBoxRequiredItem') {
                $required_fields->{$key} = $c->req->parameters->{$key};
            }
            if( $req eq 'optBoxRequiredItem' && ( !defined $c->req->parameters->{$key} || $c->req->parameters->{$key} =~ m/^\s*$/mx ) ) {
                push @errors, { message => $name . ' is a required field' };
            }
        }
        if( scalar @errors > 0 ) {
            delete $c->req->parameters->{'cmd_mod'};
            $c->stash->{'form_errors'} = \@errors;
            return;
        }
    }
    if($c->config->{downtime_max_duration}) {
        if($cmd_typ == 55 or $cmd_typ == 56 or $cmd_typ == 84 or $cmd_typ == 121) {
            my $max_duration = Thruk::Utils::expand_duration($c->config->{downtime_max_duration});
            my $end_time_unix = Thruk::Utils::parse_date( $c, $c->req->parameters->{'end_time'} );
            if(($end_time_unix - $start_time_unix) > $max_duration) {
                $c->stash->{'form_errors'} = [{ message => 'Downtime duration exceeds maximum allowed duration: '.Thruk::Utils::Filter::duration($max_duration) }];
                delete $c->req->parameters->{'cmd_mod'};
                return;
            }
            my $duration = $c->req->parameters->{'hours'} * 3600 + $c->req->parameters->{'minutes'} * 60;
            if($duration > $max_duration) {
                $c->stash->{'form_errors'} = [{ message => 'Downtime duration exceeds maximum allowed duration: '.Thruk::Utils::Filter::duration($max_duration) }];
                delete $c->req->parameters->{'cmd_mod'};
                return;
            }
        }
    }

    my($backends_list) = $c->{'db'}->select_backends('send_command');
    for my $cmd_line ( split /\n/mx, $cmd ) {
        utf8::decode($cmd_line);
        $cmd_line = 'COMMAND [' . time() . '] ' . $cmd_line;

        # if the backend list contains multiple entries,
        # send the command only to those backends which actually have that object.
        # this prevents ugly log entries when naemon core cannot find the corresponding object
        if(scalar @{$backends_list} > 1) {
            $backends_list = _get_affected_backends($c, $required_fields, $backends_list);
            if(scalar @{$backends_list} == 0) {
                Thruk::Utils::set_message( $c, 'fail_message', "cannot send command, affected backend list is empty." );
                return;
            }
        }

        my $joined_backends = join(',', @{$backends_list});
        push @{$c->stash->{'commands2send'}->{$joined_backends}}, $cmd_line;

        # add log comment if removing downtimes and comments by id
        if($cmd_typ == 4 or $cmd_typ == 79) {
            $c->stash->{'extra_log_comment'}->{$cmd_line} = '  ('.$c->req->parameters->{'host'}.';'.$c->req->parameters->{'service'}.')';
        }
        if($cmd_typ == 2 or $cmd_typ == 78) {
            $c->stash->{'extra_log_comment'}->{$cmd_line} = '  ('.$c->req->parameters->{'host'}.')';
        }
    }

    # remove comments added by require_comments_for_disable_cmds
    # delete associated comment(s) if we are about to re-enable active checks,
    # notifications or handlers
    add_remove_comments_commands_from_disabled_commands($c, $c->stash->{'commands2send'}, $cmd_typ, $c->req->parameters->{'host'}, $c->req->parameters->{'service'});

    $c->stash->{'start_time_unix'} = $start_time_unix;
    $c->stash->{'lasthost'}        = $c->req->parameters->{'host'};
    $c->stash->{'lastservice'}     = $c->req->parameters->{'service'};

    return 1;
}

######################################

=head2 bulk_send

    send all collected commands at once

=cut
sub bulk_send {
    my($c, $commands) = @_;

    for my $backends (keys %{$commands}) {
        # remove duplicate commands
        my $commands2send     = Thruk::Utils::array_uniq($commands->{$backends});

        # bulk send only 100 at a time
        while(@{$commands2send}) {
            my $bucket = [ splice @{$commands2send}, 0, 100 ];
            _bulk_send_backend($c, $backends, $bucket);
        }
    }
    return 1;
}

sub _bulk_send_backend {
    my($c, $backends, $commands2send) = @_;

    my $options = {};
    map(chomp, @{$commands2send});
    $options->{'command'} = join("\n\n", @{$commands2send});
    $options->{'backend'} = [ split(/,/mx, $backends) ];
    return 1 if $options->{'command'} eq '';

    my @names;
    for my $b (ref $backends eq 'ARRAY' ? @{$backends} : ($backends)) {
        my $peer = $c->{'db'}->get_peer_by_key($b);
        push @names, (defined $peer ? $peer->peer_name() : $b);
    }
    my $backends_string = join(',', @names);

    my $testmode = 0;
    $testmode    = 1 if (defined $ENV{'THRUK_NO_COMMANDS'} or $c->req->parameters->{'test_only'});

    for my $cmd (@{$commands2send}) {
        utf8::decode($cmd);
        my $logstr = sprintf('%s[%s][%s] cmd: %s%s',
                                ($testmode ? 'TESTMODE: ' : ''),
                                $c->user->get('username'),
                                $backends_string,
                                $cmd,
                                ($c->stash->{'extra_log_comment'}->{$cmd} || ''),
                            );
        if($ENV{'THRUK_TEST_CMD_NO_LOG'}) {
            $ENV{'THRUK_TEST_CMD_NO_LOG'} .= "\n".$logstr;
        } else {
            $c->log->info($logstr);
        }
    }
    if(!$testmode) {
        $c->{'db'}->send_command( %{$options} );
        my $cached_proc = $c->cache->get->{'global'} || {};
        for my $key (split(/,/mx, $backends)) {
            delete $cached_proc->{'processinfo'}->{$key};
        }
        $c->cache->set('global', $cached_proc);
    }

    return 1;
}

######################################

=head2 generate_spread_startdates

    generate spreaded start dates

=cut
sub generate_spread_startdates {
    my($c, $number, $starttime, $spread) = @_;
    my $spread_dates = [];

    # check for a valid number
    if( !defined $spread || $spread !~ m/^\d+$/mx || $spread <= 1 ) {
        return;
    }

    # check for a valid number
    if( $number !~ m/^\d+$/mx || $number <= 1 ) {
        return;
    }

    my $starttimestamp = Thruk::Utils::parse_date( $c, $starttime );

    # spreading wont help if the start is in the past
    $starttimestamp = time() if $starttimestamp < time();

    # calculate time between checks
    my $delta = $spread / $number;
    $c->log->debug( "calculating spread with delta: " . $delta . " seconds" );

    for my $x ( 1 .. $number ) {
        push @{$spread_dates}, int( $starttimestamp + ( $x * $delta ) );
    }

    return $spread_dates;
}


######################################
# should this command be redirected?
sub _check_reschedule_alias {
    my( $c ) = @_;

    # only for service reschedule requests
    return unless $c->req->parameters->{'cmd_typ'} == 7;

    # only if we have alias definitons
    return unless defined $c->config->{'command_reschedule_alias'};

    my $servicename = $c->req->parameters->{'service'};
    my $hostname    = $c->req->parameters->{'host'};

    my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { 'host_name' => $hostname }, { 'description' => $servicename }, ] );
    return unless defined $services;
    my $service = $services->[0];
    return unless defined $service;

    # only passive services
    return if $service->{'has_been_checked'} == 1 and $service->{'check_type'} == 0;

    my $aliases     = ref $c->config->{'command_reschedule_alias'} eq 'ARRAY'
                        ? $c->config->{'command_reschedule_alias'}
                        : [ $c->config->{'command_reschedule_alias'} ];

    for my $alias (@{$aliases}) {
        my($pattern, $master) = split/\s*;\s*/mx, $alias, 2;
        if($c->req->parameters->{'service'} =~ /$pattern/mx) {
            $c->req->parameters->{'service'} = $master;
            $c->stash->{'additional_wait'} = 1;
            return;
        }

        my $commands = $service->{'check_command'};
        next unless defined $commands;
        # my($command, $args)...
        my($command, undef) = split(/!/mx, $commands, 2);
        next unless defined $command;
        if($command =~ /$pattern/mx) {
            $c->req->parameters->{'service'} = $master;
            $c->stash->{'additional_wait'} = 1;
            return;
        }
    }

    return;
}


######################################
# set host / service from downtime / comment ids
sub _set_host_service_from_down_com_ids {
    my( $c ) = @_;
    my $data;

    if( $c->req->parameters->{'com_id'} or $c->req->parameters->{'down_id'} ) {
        $c->req->parameters->{'host'}    = '';
        $c->req->parameters->{'service'} = '';
    }

    # for comment ids
    if( $c->req->parameters->{'com_id'} ) {
        $data = $c->{'db'}->get_comments(filter => [ id => $c->req->parameters->{'com_id'} ]);
    }

    # for downtime ids
    if( $c->req->parameters->{'down_id'} ) {
        $data = $c->{'db'}->get_downtimes(filter => [ id => $c->req->parameters->{'down_id'} ]);
    }

    if( defined $data->[0] ) {
        $c->req->parameters->{'host'}    = $data->[0]->{'host_name'};
        $c->req->parameters->{'service'} = $data->[0]->{'service_description'};
    }
    return;
}

######################################
# return list of backends which have the requested objects
sub _get_affected_backends {
    my($c, $required_fields, $backends) = @_;

    my $data;
    if(defined $required_fields->{'hostgroup'}) {
        $data = $c->{'db'}->get_hostgroups(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ), name => $required_fields->{'hostgroup'}],
                                           columns => [qw/name/] );
    }
    elsif(defined $required_fields->{'servicegroup'}) {
        $data = $c->{'db'}->get_servicegroups(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'servicegroups' ), name => $required_fields->{'servicegroup'}],
                                              columns => [qw/name/] );
    }
    elsif(defined $required_fields->{'service'}) {
        $data = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), description => $required_fields->{'service'}, host_name => $required_fields->{'host'}],
                                         columns => [qw/host_name description/] );
    }
    elsif(defined $required_fields->{'host'}) {
        $data = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), name => $required_fields->{'host'}],
                                      columns => [qw/name/] );
    }

    # return original list unless we have some data
    return($backends) unless $data;

    # extract affected backends
    my $affected_backends = {};
    for my $row (@{$data}) {
        for my $peer_key (@{Thruk::Utils::list($row->{'peer_key'})}) {
            $affected_backends->{$peer_key} = 1;
        }
    }
    return([keys %{$affected_backends}]);
}

######################################

=head2 add_remove_comments_commands_from_disabled_commands

    add comment remove commands for comments added from the `require_comments_for_disable_cmds` option.

=cut
sub add_remove_comments_commands_from_disabled_commands {
    my($c, $list, $cmd_typ, $host, $service) = @_;
    my $cmds_for_type = {
        47 => ['DISABLE_HOST_CHECK'],
        15 => ['DISABLE_HOST_SVC_CHECKS', 'DISABLE_HOST_CHECK'],
        24 => ['DISABLE_HOST_NOTIFICATIONS', 'DISABLE_HOST_AND_CHILD_NOTIFICATIONS'],
        28 => ['DISABLE_HOST_SVC_NOTIFICATIONS', 'DISABLE_HOST_NOTIFICATIONS'],
        43 => ['DISABLE_HOST_EVENT_HANDLER'],
        5  => ['DISABLE_SVC_CHECK'],
        22 => ['DISABLE_SVC_NOTIFICATIONS'],
        45 => ['DISABLE_SVC_EVENT_HANDLER'],
    };
    return unless exists $cmds_for_type->{$cmd_typ};

    for my $cmd (@{$cmds_for_type->{$cmd_typ}}) {
        for my $comm (@{$c->{'db'}->get_comments_by_pattern($c, $host, $service, $cmd)}) {
            $c->log->debug("deleting comment with ID $comm->{'id'} on backend $comm->{'backend'}");
            if ($cmd =~ m/HOST/mx) {
                push @{$list->{$comm->{'backend'}}},
                    sprintf("COMMAND [%d] DEL_HOST_COMMENT;%d\n", time(), $comm->{'id'});
            }
            else {
                push @{$list->{$comm->{'backend'}}},
                    sprintf("COMMAND [%d] DEL_SVC_COMMENT;%d\n", time(), $comm->{'id'});
            }
        }
    }
    return;
}

######################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
