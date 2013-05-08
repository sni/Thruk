package Thruk::Controller::cmd;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';
use Data::Dumper;
use Template;

=head1 NAME

Thruk::Controller::cmd - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

##########################################################
sub index : Path : Args(0) : MyAction('AddDefaults') {
    my( $self, $c ) = @_;
    my $errors = 0;

    $c->stash->{'now'}           = time();
    $c->stash->{title}           = "External Command Interface";
    $c->stash->{infoBoxTitle}    = "External Command Interface";
    $c->stash->{no_auto_reload}  = 1;
    $c->stash->{page}            = 'cmd';
    $c->stash->{'form_errors'}   = [];
    $c->stash->{'commands2send'} = {};

    # fill in some defaults
    for my $param (qw/send_notification plugin_output performance_data sticky_ack force_notification broadcast_notification fixed ahas com_data persistent hostgroup host service force_check childoptions ptc use_expire servicegroup backend/) {
        $c->request->parameters->{$param} = '' unless defined $c->request->parameters->{$param};
    }
    for my $param (qw/com_id down_id hours minutes start_time end_time expire_time plugin_state trigger not_dly/) {
        $c->request->parameters->{$param} = 0 unless defined $c->request->parameters->{$param};
    }

    $c->request->parameters->{com_data} =~ s/\n//gmx;

    Thruk::Utils::ssi_include($c);

    $c->stash->{'cmd_typ'} = $c->{'request'}->{'parameters'}->{'cmd_typ'} || '';

    # check if authorization is enabled
    if( $c->config->{'cgi_cfg'}->{'use_authentication'} == 0 and $c->config->{'cgi_cfg'}->{'use_ssl_authentication'} == 0 ) {
        return $c->detach('/error/index/3');
    }

    # read only user?
    return $c->detach('/error/index/11') if $c->check_user_roles('authorized_for_read_only');

    # set authorization information
    my $query_options = { Slice => 1 };
    if( defined $c->{'request'}->{'parameters'}->{'backend'} ) {
        my $backend = $c->{'request'}->{'parameters'}->{'backend'};
        $query_options = { Slice => 1, Backend => [$backend] };
    }

    $self->_set_host_service_from_down_com_ids($c);

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
    my $quick_command = $c->{'request'}->{'parameters'}->{'quick_command'};
    my $quick_confirm = $c->{'request'}->{'parameters'}->{'confirm'};
    if( defined $quick_confirm and $quick_confirm eq 'no' ) {
        $c->{'request'}->{'parameters'}->{'cmd_typ'} = 'c'.$quick_command;
        delete $c->{'request'}->{'parameters'}->{'cmd_mod'};
        $c->stash->{'cmd_typ'} = 'c'.$quick_command;
        $self->_check_for_commands($c);
    }
    elsif( defined $quick_command and $quick_command or $c->stash->{'cmd_typ'} =~ m/^c(\d+)$/mx ) {
        if(defined $1) {
            $quick_command = $1;
            my $backends = $c->{'request'}->{'parameters'}->{'backend'};
            if(ref $c->{'request'}->{'parameters'}->{'backend'} eq 'ARRAY') {
                $backends = join('|', @{$c->{'request'}->{'parameters'}->{'backend'}});
            }
            if(defined $c->{'request'}->{'parameters'}->{'service'} and $c->{'request'}->{'parameters'}->{'service'} ne '') {
                $c->{'request'}->{'parameters'}->{'selected_services'} =
                        $c->{'request'}->{'parameters'}->{'host'}
                        .';'.$c->{'request'}->{'parameters'}->{'service'}
                        .';'.$backends;
            } else {
                $c->{'request'}->{'parameters'}->{'selected_hosts'}    =
                        $c->{'request'}->{'parameters'}->{'host'}
                        .';;'.$backends;
            }
        }
        my $cmd_typ;
        $c->{'request'}->{'parameters'}->{'cmd_mod'}           = 1;
        $c->{'request'}->{'parameters'}->{'trigger'}           = 0;
        $c->{'request'}->{'parameters'}->{'selected_hosts'}    = '' unless defined $c->{'request'}->{'parameters'}->{'selected_hosts'};
        $c->{'request'}->{'parameters'}->{'selected_services'} = '' unless defined $c->{'request'}->{'parameters'}->{'selected_services'};
        $c->{'request'}->{'parameters'}->{'selected_ids'}      = '' unless defined $c->{'request'}->{'parameters'}->{'selected_ids'};
        my @hostdata    = split /,/mx, $c->{'request'}->{'parameters'}->{'selected_hosts'};
        my @servicedata = split /,/mx, $c->{'request'}->{'parameters'}->{'selected_services'};
        my @idsdata     = split /,/mx, $c->{'request'}->{'parameters'}->{'selected_ids'};
        $self->{'spread_startdates'} = $self->_generate_spread_startdates( $c, scalar @hostdata + scalar @servicedata, $c->request->parameters->{'start_time'}, $c->request->parameters->{'spread'} );

        # persistent can be set in two ways
        if(    $c->{'request'}->{'parameters'}->{'persistent'} eq 'ack'
           and $c->{'request'}->{'parameters'}->{'persistent_ack'}) {
            $c->{'request'}->{'parameters'}->{'persistent'} = 1;
        }
        elsif(    $c->{'request'}->{'parameters'}->{'persistent'} eq 'comments'
           and $c->{'request'}->{'parameters'}->{'persistent_comments'}) {
            $c->{'request'}->{'parameters'}->{'persistent'} = 1;
        }
        else {
            $c->{'request'}->{'parameters'}->{'persistent'} = 0;
        }

        # comments / downtimes quick commands
        for my $id (@idsdata) {
            my($typ, $id, $backend) = split(/_/m,$id, 3);
            $c->{'request'}->{'parameters'}->{'backend'} = $backend;
            if($typ eq 'hst' and defined $host_quick_commands->{$quick_command} ) {
                $cmd_typ = $host_quick_commands->{$quick_command};
            }
            elsif($typ eq 'svc' and defined $service_quick_commands->{$quick_command} ) {
                $cmd_typ = $service_quick_commands->{$quick_command};
            }
            else {
                return $c->detach('/error/index/7');
            }
            $c->{'request'}->{'parameters'}->{'cmd_typ'} = $cmd_typ;
            if($quick_command == 5) {
                $c->{'request'}->{'parameters'}->{'down_id'} = $id;
            } elsif($quick_command == 13 ) {
                $c->{'request'}->{'parameters'}->{'com_id'}  = $id;
            }
            $self->_set_host_service_from_down_com_ids($c);
            if( $self->_do_send_command($c) ) {
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
            my( $host, $service, $backend ) = split /;/mx, $hostdata;
            my @backends                    = split /\|/mx, defined $backend ? $backend : '';
            $c->stash->{'lasthost'}         = $host;
            $c->{'request'}->{'parameters'}->{'cmd_typ'} = $cmd_typ;
            $c->{'request'}->{'parameters'}->{'host'}    = $host;
            $c->{'request'}->{'parameters'}->{'backend'} = \@backends;
            if( $quick_command == 5 ) {
                if($c->{'request'}->{'parameters'}->{'active_downtimes'}) {
                    $self->_remove_all_downtimes( $c, $host, undef, 'active' );
                }
                if($c->{'request'}->{'parameters'}->{'future_downtimes'}) {
                    $self->_remove_all_downtimes( $c, $host, undef, 'future' );
                }
            }
            else {
                if( $self->_do_send_command($c) ) {
                    $c->log->debug("command for host $host succeeded");
                }
                else {
                    $errors++;
                    Thruk::Utils::set_message( $c, 'fail_message', "command for host $host failed" );
                    $c->log->debug("command for host $host failed");
                    $c->log->debug( Dumper( $c->stash->{'form_errors'} ) );
                }
            }
        }

        # service quick commands
        my $lastservice;
        for my $servicedata ( split /,/mx, $c->{'request'}->{'parameters'}->{'selected_services'} ) {
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
            $c->{'request'}->{'parameters'}->{'cmd_typ'} = $cmd_typ;
            $c->{'request'}->{'parameters'}->{'host'}    = $host;
            $c->{'request'}->{'parameters'}->{'service'} = $service;
            $c->{'request'}->{'parameters'}->{'backend'} = \@backends;
            if( $quick_command == 5 ) {
                if($c->{'request'}->{'parameters'}->{'active_downtimes'}) {
                    $self->_remove_all_downtimes( $c, $host, $service, 'active' );
                }
                if($c->{'request'}->{'parameters'}->{'future_downtimes'}) {
                    $self->_remove_all_downtimes( $c, $host, $service, 'future' );
                }
            }
            else {
                if( $self->_do_send_command($c) ) {
                    $c->log->debug("command for $service on host $host succeeded");
                }
                else {
                    $errors++;
                    Thruk::Utils::set_message( $c, 'fail_message', "command for $service on host $host failed" );
                    $c->log->debug("command for $service on host $host failed");
                    $c->log->debug( Dumper( $c->stash->{'form_errors'} ) );
                }
            }
        }

        Thruk::Utils::set_message( $c, 'success_message', 'Commands successfully submitted' ) unless $errors;
        delete $c->{'request'}->{'parameters'}->{'backend'};
        $self->_redirect_or_success( $c, -1 );
    }

    # normal page call
    else {
        $self->_check_for_commands($c);
    }

    if($c->{'request'}->{'parameters'}->{'json'} and $c->stash->{'form_errors'}) {
        $c->stash->{'json'} = {'success' => 0, errors => $c->stash->{'form_errors'} };
        return $c->detach('View::JSON');
    }

    return 1;
}

######################################
# remove downtimes
sub _remove_all_downtimes {
    my( $self, $c, $host, $service, $type ) = @_;

    my $backends = $c->{'request'}->{'parameters'}->{'backend'};

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
        $c->{'request'}->{'parameters'}->{'down_id'} = $id;
        if( $self->_do_send_command($c) ) {
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
    my( $self, $c ) = @_;

    my $cmd_typ = $c->{'request'}->{'parameters'}->{'cmd_typ'};
    my $cmd_mod = $c->{'request'}->{'parameters'}->{'cmd_mod'};
    return $c->detach('/error/index/6') unless defined $cmd_typ;

    if( defined $c->config->{'command_disabled'}->{$cmd_typ} ) {
        return $c->detach('/error/index/12');
    }

    # command commited?
    if( defined $cmd_mod and $self->_do_send_command($c) ) {
        Thruk::Utils::set_message( $c, 'success_message', 'Commands successfully submitted' );
        $self->_redirect_or_success( $c, -2 );
    }
    else {

        # no command submited, view commands page (can be nonnumerical)
        if( $cmd_typ eq "55" or $cmd_typ eq "56" or $cmd_typ eq "86" ) {
            $c->stash->{'hostdowntimes'}    = $c->{'db'}->get_downtimes(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), service_description => undef ]);
            $c->stash->{'servicedowntimes'} = $c->{'db'}->get_downtimes(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), service_description => { '!=' => undef } ]);
        }

        $c->stash->{'backend'} = $c->{'request'}->{'parameters'}->{'backend'} || '';

        my $comment_author = $c->user->username;
        $comment_author = $c->user->alias if defined $c->user->alias;
        $c->stash->{comment_author} = $comment_author;
        $c->stash->{cmd_tt}         = 'cmd.tt';
        $c->stash->{template}       = 'cmd/cmd_typ_' . $cmd_typ . '.tt';

        # set a valid referer
        my $referer = $c->{'request'}->{'parameters'}->{'referer'} || $c->{'request'}->{'headers'}->{'referer'} || '';
        $referer =~ s/&amp;/&/gmx;
        $referer =~ s/&/&amp;/gmx;
        $c->stash->{referer} = $referer;
    }

    return 1;
}

######################################
# view our success page or redirect to referer
sub _redirect_or_success {
    my( $self, $c, $how_far_back ) = @_;

    my $wait = defined $c->config->{'use_wait_feature'} ? $c->config->{'use_wait_feature'} : 0;
    if($self->_bulk_send($c)) {
        $c->log->debug("bulk sending commands succeeded");
    } else {
        Thruk::Utils::set_message( $c, 'fail_message', 'Sending Commands failed' );
        $wait = 0;
    }

    # no need to wait when no command was sent
    if(defined $ENV{'THRUK_NO_COMMANDS'} or $c->request->parameters->{'test_only'}) {
        $wait = 0;
    }

    # only wait if we got original backends
    my $backends = Thruk::Utils::list($c->{'request'}->{'parameters'}->{'backend'});
    if($wait and defined $c->{'request'}->{'parameters'}->{'backend.orig'}) {
        my $backends_str = join('|', @{$backends});
        my $backendsorig = join('|', @{Thruk::Utils::list($c->{'request'}->{'parameters'}->{'backend.orig'})});
        $wait = 0 if $backends_str ne $backendsorig;
    }

    my $has_spaces = 0;
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
        next unless $v =~ m/^Livestatus\s(.*)$/mx;
        my $v_num = $1;
        if(!Thruk::Utils::version_compare($v_num, '1.1.3')) {
            $wait = 0;
        }
        if(!Thruk::Utils::version_compare($v_num, '1.1.12') and $has_spaces) {
            $wait = 0;
        }
    }

    $c->stash->{how_far_back} = $how_far_back;

    my $referer = $c->{'request'}->{'parameters'}->{'referer'} || '';
    if( $referer ne '' or $c->{'request'}->{'parameters'}->{'json'}) {
        # send a wait header?
        if(    $wait
           and defined $c->stash->{'lasthost'}
           and defined $c->stash->{'start_time_unix'}
           and $c->stash->{'start_time_unix'} <= $c->stash->{'now'}
        ) {
            my($waittrigger, $waitcondition);
            # reschedules
            if($c->{'request'}->{'parameters'}->{'cmd_typ'} == 7 or $c->{'request'}->{'parameters'}->{'cmd_typ'} == 96) {
                $waittrigger   = 'check';
                $waitcondition = 'last_check >= '.$c->stash->{'now'};
            }
            # add downtime
            if($c->{'request'}->{'parameters'}->{'cmd_typ'} == 55 or $c->{'request'}->{'parameters'}->{'cmd_typ'} == 56) {
                $waittrigger   = 'downtime';
                $waitcondition = 'scheduled_downtime_depth > 0';
            }
            # remove downtime
            if($c->{'request'}->{'parameters'}->{'cmd_typ'} == 78 or $c->{'request'}->{'parameters'}->{'cmd_typ'} == 79) {
                $waittrigger   = 'downtime';
                $waitcondition = 'scheduled_downtime_depth = 0';
            }
            # add acknowledged
            if($c->{'request'}->{'parameters'}->{'cmd_typ'} == 33 or $c->{'request'}->{'parameters'}->{'cmd_typ'} == 34) {
                $waittrigger   = 'command';
                $waitcondition = 'acknowledged = 1';
            }
            # remove acknowledged
            if($c->{'request'}->{'parameters'}->{'cmd_typ'} == 51 or $c->{'request'}->{'parameters'}->{'cmd_typ'} == 52) {
                $waittrigger   = 'command';
                $waitcondition = 'acknowledged = 0';
            }
            if($waittrigger) {
                my $options = {
                            'header' => {
                                'WaitTimeout'   => ($c->config->{'wait_timeout'} * 1000),
                                'WaitTrigger'   => $waittrigger,
                                'WaitCondition' => $waitcondition,
                            }
                };
                if(!defined $c->stash->{'lastservice'} or $c->stash->{'lastservice'} eq '') {
                    $options->{'header'}->{'WaitObject'} = $c->stash->{'lasthost'};
                    $c->{'db'}->get_hosts(  filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ),
                                                       { 'name' => $c->stash->{'lasthost'} } ],
                                            columns => [ 'name' ],
                                            options => $options
                                        );
                }
                if(defined $c->stash->{'lastservice'} and $c->stash->{'lastservice'} ne '') {
                    $options->{'header'}->{'WaitObject'} = $c->stash->{'lasthost'}.";".$c->stash->{'lastservice'};
                    $c->{'db'}->get_services( filter  => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ),
                                                          { 'host_name'   => $c->stash->{'lasthost'} },
                                                          { 'description' => $c->stash->{'lastservice'} }
                                                         ],
                                              columns => [ 'description' ],
                                              options => $options
                                            );
                }
                if(defined $c->stash->{'additional_wait'}) {
                    sleep(1);
                }
            }
        }
        else {
            # just do nothing for a second
            sleep(1);
        }

        if($c->{'request'}->{'parameters'}->{'json'}) {
            $c->stash->{'json'} = {'success' => 1};
            return $c->detach('View::JSON');
        }
        else {
            $c->response->redirect($referer);
        }
    }
    else {
        if($c->{'request'}->{'parameters'}->{'json'}) {
            $c->stash->{'json'} = {'success' => 1};
            return $c->detach('View::JSON');
        }
        $c->stash->{template} = 'cmd_success.tt';
    }

    return;
}

######################################
# sending commands
sub _do_send_command {
    my( $self, $c ) = @_;

    my $cmd_typ = $c->{'request'}->{'parameters'}->{'cmd_typ'};
    return $c->detach('/error/index/6') unless defined $cmd_typ;

    # locked author names?
    if( $c->config->{'cgi_cfg'}->{'lock_author_names'} or !defined $c->{'request'}->{'parameters'}->{'com_author'} ) {
        my $author = $c->user->username;
        $author = $c->user->alias if defined $c->user->alias;
        $c->{'request'}->{'parameters'}->{'com_author'} = $author;
    }

    # replace parsed dates
    my $start_time_unix = 0;
    my $end_time_unix   = 0;
    if( defined $self->{'spread_startdates'} and scalar @{ $self->{'spread_startdates'} } > 0 ) {
        my $new_start_time = shift @{ $self->{'spread_startdates'} };
        my $new_date = Thruk::Utils::format_date( $new_start_time, '%Y-%m-%d %H:%M:%S' );
        $c->log->debug( "setting spreaded start date to: " . $new_date );
        $c->request->parameters->{'start_time'} = $new_date;
        $start_time_unix = $new_start_time;
    }
    elsif ( $c->request->parameters->{'start_time'} ) {
        if( $c->request->parameters->{'start_time'} !~ m/(\d{4})\-(\d{2})\-(\d{2})\ (\d{2}):(\d{2}):(\d{2})/mx ) {
            my $new_date = Thruk::Utils::format_date( Thruk::Utils::parse_date( $c, $c->request->parameters->{'start_time'} ), '%Y-%m-%d %H:%M:%S' );
            $c->log->debug( "setting start date to: " . $new_date );
            $c->request->parameters->{'start_time'} = $new_date;
        }
        $start_time_unix = Thruk::Utils::parse_date( $c, $c->request->parameters->{'start_time'} );
    }
    if( $c->request->parameters->{'end_time'} ) {
        if( $c->request->parameters->{'end_time'} !~ m/(\d{4})\-(\d{2})\-(\d{2})\ (\d{2}):(\d{2}):(\d{2})/mx ) {
            my $new_date = Thruk::Utils::format_date( Thruk::Utils::parse_date( $c, $c->request->parameters->{'end_time'} ), '%Y-%m-%d %H:%M:%S' );
            $c->log->debug( "setting end date to: " . $new_date );
            $c->request->parameters->{'end_time'} = $new_date;
        }
        $end_time_unix = Thruk::Utils::parse_date( $c, $c->request->parameters->{'end_time'} );
    }
    if( $c->request->parameters->{'use_expire'}
       and ($cmd_typ == 33 or $cmd_typ == 34)
      ) {
        if($c->request->parameters->{'expire_time'}) {
            if( $c->request->parameters->{'expire_time'} !~ m/(\d{4})\-(\d{2})\-(\d{2})\ (\d{2}):(\d{2}):(\d{2})/mx ) {
                my $new_date = Thruk::Utils::format_date( Thruk::Utils::parse_date( $c, $c->request->parameters->{'expire_time'} ), '%Y-%m-%d %H:%M:%S' );
                $c->log->debug( "setting expire date to: " . $new_date );
                $c->request->parameters->{'expire_time'} = $new_date;
            }
            if($c->request->parameters->{'expire_time'}) {
                $end_time_unix = Thruk::Utils::parse_date( $c, $c->request->parameters->{'expire_time'} );
            }
            $c->request->parameters->{'end_time'} = $c->request->parameters->{'expire_time'};
        }
        unless(defined $c->stash->{'com_data_adjusted'}) {
            $c->request->parameters->{'com_data'} .= ' - The acknowledgement expires at: '.$c->request->parameters->{'end_time'}.'.';
            $c->stash->{'com_data_adjusted'}       = 1;
        }
    }

    return 1 if $self->_check_reschedule_alias($c);

    if( defined $c->config->{'command_disabled'}->{$cmd_typ} ) {
        return $c->detach('/error/index/12');
    }

    my $tt  = Template->new( $c->config->{'View::TT'} );
    my $cmd = '';
    eval {
        $tt->process(
            'cmd/cmd_typ_' . $cmd_typ . '.tt',
            {   c                      => $c,
                cmd_tt                 => 'cmd_line.tt',
                start_time_unix        => $start_time_unix,
                end_time_unix          => $end_time_unix,
                die_on_errors          => 1,
                theme                  => $c->stash->{'theme'},
                url_prefix             => $c->stash->{'url_prefix'},
                has_expire_acks        => $c->stash->{'has_expire_acks'},
                downtime_duration      => $c->stash->{'downtime_duration'},
                expire_ack_duration    => $c->stash->{'expire_ack_duration'},
                comment_author         => '',
                hostdowntimes          => '',
                servicedowntimes       => '',
            },
            \$cmd
        ) || die $tt->error();
        $cmd =~ s/^\s+//gmx;
        $cmd =~ s/\s+$//gmx;
    };
    $c->log->error('error in first cmd/cmd_typ_' . $cmd_typ . '.tt: '.$@) if $@;

    # unknown command given?
    return $c->detach('/error/index/7') unless defined $cmd;

    # unauthorized?
    return $c->detach('/error/index/10') unless $cmd ne '';

    # check for required fields
    my( $form, @errors );
    eval {
        $tt->process(
            'cmd/cmd_typ_' . $cmd_typ . '.tt',
            {   c                      => $c,
                cmd_tt                 => '_get_content.tt',
                start_time_unix        => $start_time_unix,
                end_time_unix          => $end_time_unix,
                theme                  => $c->stash->{'theme'},
                url_prefix             => $c->stash->{'url_prefix'},
                has_expire_acks        => $c->stash->{'has_expire_acks'},
                downtime_duration      => $c->stash->{'downtime_duration'},
                expire_ack_duration    => $c->stash->{'expire_ack_duration'},
                comment_author         => '',
                hostdowntimes          => '',
                servicedowntimes       => '',
            },
            \$form
        ) || die $tt->error();
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
            if( $req eq 'optBoxRequiredItem' and ( !defined $c->{'request'}->{'parameters'}->{$key} or $c->{'request'}->{'parameters'}->{$key} =~ m/^\s*$/mx ) ) {
                push @errors, { message => $name . ' is a required field' };
            }
        }
        if( scalar @errors > 0 ) {
            delete $c->{'request'}->{'parameters'}->{'cmd_mod'};
            $c->stash->{'form_errors'} = \@errors;
            return;
        }
    }

    my $backends      = $c->{'request'}->{'parameters'}->{'backend'};
    my $backends_list = ref $backends eq 'ARRAY' ? $backends : [ $backends ];
    for my $cmd_line ( split /\n/mx, $cmd ) {
        $cmd_line = 'COMMAND [' . time() . '] ' . $cmd_line;
        my $joined_backends = join(',', @{$backends_list});
        push @{$c->stash->{'commands2send'}->{$joined_backends}}, $cmd_line;
    }

    $c->stash->{'start_time_unix'} = $start_time_unix;
    $c->stash->{'lasthost'}        = $c->{'request'}->{'parameters'}->{'host'};
    $c->stash->{'lastservice'}     = $c->{'request'}->{'parameters'}->{'service'};

    return 1;
}

######################################
# send all collected commands at once
sub _bulk_send {
    my $self         = shift;
    my $c            = shift;
    my @errors;

    for my $backends (keys %{$c->stash->{'commands2send'}}) {
        my $options = {};
        # remove duplicate commands
        my $commands2send     = Thruk::Utils::array_uniq($c->stash->{'commands2send'}->{$backends});
        $options->{'command'} = join("\n\n", @{$commands2send});
        $options->{'backend'} = [ split(/,/mx, $backends) ];
        return 1 if $options->{'command'} eq '';

        my $backends_string = ref $backends eq 'ARRAY' ? join(',', @{$backends}) : $backends;
        $backends_string    = 'all' unless $backends_string;
        if(defined $ENV{'THRUK_NO_COMMANDS'} or $c->request->parameters->{'test_only'}) {
            map { $c->log->info( 'TESTMODE: [' . $c->user->username . ']['.$backends_string.'] cmd: ' . $_ ) } @{$commands2send} unless $ENV{'THRUK_TEST_CMD_NO_LOG'};
        } else {
            $c->{'db'}->send_command( %{$options} );
            map { $c->log->info( '[' . $c->user->username . ']['.$backends_string.'] cmd: ' . $_ ) } @{$commands2send};
        }
    }

    return 1;
}

######################################
# generate spreaded start dates
sub _generate_spread_startdates {
    my $self         = shift;
    my $c            = shift;
    my $number       = shift;
    my $starttime    = shift;
    my $spread       = shift;
    my $spread_dates = [];

    # check for a valid number
    if( !defined $spread or $spread !~ m/^\d+$/mx or $spread <= 1 ) {
        return;
    }

    # check for a valid number
    if( $number !~ m/^\d+$/mx or $number <= 1 ) {
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
    my( $self, $c ) = @_;

    # only for service reschedule requests
    return unless $c->request->parameters->{'cmd_typ'} == 7;

    # only if we have alias definitons
    return unless defined $c->config->{'command_reschedule_alias'};

    my $servicename = $c->request->parameters->{'service'};
    my $hostname    = $c->request->parameters->{'host'};

    my $services = $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { 'host_name' => $hostname }, { 'description' => $servicename }, ] );
    return unless defined $services;
    my $service = $services->[0];
    return unless defined $service;

    # only passive services
    my $has_been_checked = $service->{'has_been_checked'} || 0;
    my $check_type       = $service->{'check_type'}       || 0;
    return if $service->{'has_been_checked'} == 1 and $service->{'check_type'} == 0;

    my $aliases     = ref $c->config->{'command_reschedule_alias'} eq 'ARRAY'
                        ? $c->config->{'command_reschedule_alias'}
                        : [ $c->config->{'command_reschedule_alias'} ];

    for my $alias (@{$aliases}) {
        my($pattern, $master) = split/\s*;\s*/mx, $alias, 2;
        if($c->request->parameters->{'service'} =~ /$pattern/mx) {
            $c->request->parameters->{'service'} = $master;
            $c->stash->{'additional_wait'} = 1;
            return;
        }

        my $commands = $service->{'check_command'};
        next unless defined $commands;
        my($command, $args) = split(/!/mx, $commands, 2);
        next unless defined $command;
        if($command =~ /$pattern/mx) {
            $c->request->parameters->{'service'} = $master;
            $c->stash->{'additional_wait'} = 1;
            return;
        }
    }

    return;
}


######################################
# set host / service from downtime / comment ids
sub _set_host_service_from_down_com_ids {
    my( $self, $c ) = @_;
    my $data;

    if( $c->{'request'}->{'parameters'}->{'com_id'} or $c->{'request'}->{'parameters'}->{'down_id'} ) {
        $c->{'request'}->{'parameters'}->{'host'}    = '';
        $c->{'request'}->{'parameters'}->{'service'} = '';
    }

    # for comment ids
    if( $c->{'request'}->{'parameters'}->{'com_id'} ) {
        $data = $c->{'db'}->get_comments(filter => [ id => $c->{'request'}->{'parameters'}->{'com_id'} ]);
    }

    # for downtime ids
    if( $c->{'request'}->{'parameters'}->{'down_id'} ) {
        $data = $c->{'db'}->get_downtimes(filter => [ id => $c->{'request'}->{'parameters'}->{'down_id'} ]);
    }

    if( defined $data->[0] ) {
        $c->{'request'}->{'parameters'}->{'host'}    = $data->[0]->{'host_name'};
        $c->{'request'}->{'parameters'}->{'service'} = $data->[0]->{'service_description'};
    }
    return;
}

######################################

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
