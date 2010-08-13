package Thruk::Controller::cmd;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';
use Data::Dumper;
use Template;
use Time::HiRes qw( usleep );

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

    $c->stash->{title}          = "External Command Interface";
    $c->stash->{infoBoxTitle}   = "External Command Interface";
    $c->stash->{no_auto_reload} = 1;
    $c->stash->{page}           = 'cmd';
    $c->stash->{'form_errors'}  = [];

    # fill in some defaults
    for my $param (qw/send_notification plugin_output performance_data sticky_ack force_notification broadcast_notification fixed ahas com_data not_dly persistent hostgroup host service force_check childoptions ptc servicegroup/) {
        $c->request->parameters->{$param} = '' unless defined $c->request->parameters->{$param};
    }
    for my $param (qw/com_id down_id hour minutes start_time end_time plugin_state trigger /) {
        $c->request->parameters->{$param} = 0 unless defined $c->request->parameters->{$param};
    }

    Thruk::Utils::ssi_include($c);

    $c->stash->{'cmd_typ'} = $c->{'request'}->{'parameters'}->{'cmd_typ'} || '';

    # check if authorization is enabled
    if( $c->config->{'cgi_cfg'}->{'use_authentication'} == 0 and $c->config->{'cgi_cfg'}->{'use_ssl_authentication'} == 0 ) {
        $c->detach('/error/index/3');
    }

    # read only user?
    $c->detach('/error/index/11') if $c->check_user_roles('is_authorized_for_read_only');

    # set authorization information
    my $query_options = { Slice => 1 };
    if( defined $c->{'request'}->{'parameters'}->{'backend'} ) {
        my $backend = $c->{'request'}->{'parameters'}->{'backend'};
        $query_options = { Slice => 1, Backend => [$backend] };
    }

    my($data);

    # for comment ids
    if( defined $c->{'request'}->{'parameters'}->{'com_id'} ) {
        $data = $c->{'db'}->get_comments(filter => [ id => $c->{'request'}->{'parameters'}->{'com_id'} ]);
    }

    # for downtime ids
    if( defined $c->{'request'}->{'parameters'}->{'down_id'} ) {
        $data = $c->{'db'}->get_downtimes(filter => [ id => $c->{'request'}->{'parameters'}->{'down_id'} ]);
    }
    if( defined $data->[0] ) {
        $c->{'request'}->{'parameters'}->{'host'}    = $data->[0]->{'host_name'};
        $c->{'request'}->{'parameters'}->{'service'} = $data->[0]->{'service_description'};
    }

    my $host_quick_commands = {
        1  => 96,    # reschedule host check
        2  => 55,    # schedule downtime
        3  => 1,     # add comment
        4  => 33,    # add acknowledgement
        5  => 78,    # remove all downtimes
        6  => 20,    # remove all comments
        7  => 51,    # remove acknowledgement
        8  => 47,    # enable active checks
        9  => 48,    # disable active checks
        10 => 24,    # enable notifications
        11 => 25,    # disable notifications
        12 => 87,    # submit passive check result
    };
    my $service_quick_commands = {
        1  => 7,     # reschedule service check
        2  => 56,    # schedule downtime
        3  => 3,     # add comment
        4  => 34,    # acknowledge
        5  => 79,    # remove all downtimes
        6  => 21,    # remove all comments
        7  => 52,    # remove acknowledgement
        8  => 5,     # enable active checks
        9  => 6,     # disable active checks
        10 => 22,    # enable notifications
        11 => 23,    # disable notifications
        12 => 30,    # submit passive check result
    };

    # did we receive a quick command from the status page?
    my $quick_command = $c->{'request'}->{'parameters'}->{'quick_command'};
    if( defined $quick_command and $quick_command ) {
        my $cmd_typ;
        $c->{'request'}->{'parameters'}->{'cmd_mod'}           = 1;
        $c->{'request'}->{'parameters'}->{'trigger'}           = 0;
        $c->{'request'}->{'parameters'}->{'selected_hosts'}    = '' unless defined $c->{'request'}->{'parameters'}->{'selected_hosts'};
        $c->{'request'}->{'parameters'}->{'selected_services'} = '' unless defined $c->{'request'}->{'parameters'}->{'selected_services'};
        my @hostdata    = split /,/mx, $c->{'request'}->{'parameters'}->{'selected_hosts'};
        my @servicedata = split /,/mx, $c->{'request'}->{'parameters'}->{'selected_services'};
        $self->{'spread_startdates'} = $self->_generate_spread_startdates( $c, scalar @hostdata + scalar @servicedata, $c->request->parameters->{'start_time'}, $c->request->parameters->{'spread'} );

        for my $hostdata (@hostdata) {
            if( defined $host_quick_commands->{$quick_command} ) {
                $cmd_typ = $host_quick_commands->{$quick_command};
            }
            else {
                $c->detach('/error/index/7');
            }
            $c->{'request'}->{'parameters'}->{'cmd_typ'} = $cmd_typ;
            my( $host, $service, $backend ) = split /;/mx, $hostdata;
            $c->{'request'}->{'parameters'}->{'host'}    = $host;
            $c->{'request'}->{'parameters'}->{'backend'} = $backend;
            if( $quick_command == 5 ) {
                $self->_remove_all_downtimes( $c, $host );
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

        for my $servicedata ( split /,/mx, $c->{'request'}->{'parameters'}->{'selected_services'} ) {
            if( defined $service_quick_commands->{$quick_command} ) {
                $cmd_typ = $service_quick_commands->{$quick_command};
            }
            else {
                $c->detach('/error/index/7');
            }
            $c->{'request'}->{'parameters'}->{'cmd_typ'} = $cmd_typ;
            my( $host, $service, $backend ) = split /;/mx, $servicedata;
            $c->{'request'}->{'parameters'}->{'host'}    = $host;
            $c->{'request'}->{'parameters'}->{'service'} = $service;
            $c->{'request'}->{'parameters'}->{'backend'} = $backend;
            if( $quick_command == 5 ) {
                $self->_remove_all_downtimes( $c, $host, $service );
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
        $self->_redirect_or_success( $c, -1 );
    }

    # normal page call
    else {
        $self->_check_for_commands($c);
    }

    return 1;
}

######################################
# remove downtimes
sub _remove_all_downtimes {
    my( $self, $c, $host, $service ) = @_;

    # get list of all downtimes
    my @ids;
    if( defined $service ) {
        my $data = $c->{'db'}->get_downtimes(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), host_name => $host, service_description => $service ]);
        @ids     = keys %{Thruk::Utils::array2hash($data, 'id')};
    }
    else {
        my $data = $c->{'db'}->get_downtimes(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), host_name => $host, service_description => undef ]);
        @ids     = keys %{Thruk::Utils::array2hash($data, 'id')};
    }
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
    $c->detach('/error/index/6') unless defined $cmd_typ;
    $self->_cmd_is_disabled( $c, $cmd_typ );

    # command commited?
    if( defined $cmd_mod and $self->_do_send_command($c) ) {
        Thruk::Utils::set_message( $c, 'success_message', 'Commands successfully submitted' );
        $self->_redirect_or_success( $c, -2 );
    }
    else {

        # no command submited, view commands page
        if( $cmd_typ == 55 or $cmd_typ == 56 ) {
            $c->stash->{'hostdowntimes'}    = $c->{'db'}->get_downtimes(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), service_description => undef ]);
            $c->stash->{'servicedowntimes'} = $c->{'db'}->get_downtimes(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), service_description => { '!=' => undef } ]);
        }

        #my @possible_backends = $c->{'db'}->peer_key();
        #$c->stash->{'backends'} = \@possible_backends;
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
# command disabled by config?
sub _cmd_is_disabled {
    my( $self, $c, $cmd_typ ) = @_;

    my $not_allowed = Thruk->config->{'command_disabled'};
    if( defined $not_allowed ) {
        my %command_disabled;
        if( ref $not_allowed eq 'ARRAY' ) {
            for my $num ( @{$not_allowed} ) {
                $command_disabled{$num} = 1;
            }
        }
        else {
            $command_disabled{$not_allowed} = 1;
        }
        if( defined $command_disabled{$cmd_typ} ) {
            $c->detach('/error/index/12');
        }
    }

    return 1;
}

######################################
# view our success page or redirect to referer
sub _redirect_or_success {
    my( $self, $c, $how_far_back ) = @_;

    $c->stash->{how_far_back} = $how_far_back;

    my $referer = $c->{'request'}->{'parameters'}->{'referer'} || '';
    if( $referer ne '' ) {

        # wait 0.3 seconds, so the command is probably already processed
        usleep(300000);
        $c->redirect($referer);
    }
    else {
        $c->stash->{template} = 'cmd_success.tt';
    }

    return 1;
}

######################################
# sending commands
sub _do_send_command {
    my( $self, $c ) = @_;

    my $cmd_typ = $c->{'request'}->{'parameters'}->{'cmd_typ'};
    $c->detach('/error/index/6') unless defined $cmd_typ;

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

    my $tt  = Template->new( $c->{'View::TT'} );
    my $cmd = '';
    eval {
        $tt->process(
            'cmd/cmd_typ_' . $cmd_typ . '.tt',
            {   c                => $c,
                cmd_tt           => 'cmd_line.tt',
                start_time_unix  => $start_time_unix,
                end_time_unix    => $end_time_unix,
                die_on_errors    => 1,
                theme            => $c->stash->{'theme'},
                comment_author   => '',
                hostdowntimes    => '',
                servicedowntimes => '',
            },
            \$cmd
        ) || die $tt->error();
        $cmd =~ s/^\s+//gmx;
        $cmd =~ s/\s+$//gmx;
    };
    $c->log->error('error in first cmd/cmd_typ_' . $cmd_typ . '.tt: '.$@) if $@;

    # unknown command given?
    $c->detach('/error/index/7') unless defined $cmd;

    # unauthorized?
    $c->detach('/error/index/10') unless $cmd ne '';

    # check for required fields
    my( $form, @errors );
    eval {
        $tt->process(
            'cmd/cmd_typ_' . $cmd_typ . '.tt',
            {   c               => $c,
                cmd_tt          => '_get_content.tt',
                start_time_unix => $start_time_unix,
                end_time_unix   => $end_time_unix,
                theme           => $c->stash->{'theme'},
                comment_author   => '',
                hostdowntimes    => '',
                servicedowntimes => '',
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
            return (0);
        }
    }

    # is a backend selected?
    my $backends          = $c->{'request'}->{'parameters'}->{'backend'};
    my @possible_backends = $c->{'db'}->peer_key();
    if( scalar @possible_backends > 1 and !defined $backends ) {
        delete $c->{'request'}->{'parameters'}->{'cmd_mod'};
        push @errors, { message => 'please select a backend' };
        $c->stash->{'form_errors'} = \@errors;
        return (0);
    }

    # send the command
    my $options = {};
    if( defined $backends ) {
        $c->log->debug( "sending to backends: " . Dumper($backends) );
        $options->{backend} = $backends;
    }

    for my $cmd_line ( split /\n/mx, $cmd ) {
        $cmd_line = 'COMMAND [' . time() . '] ' . $cmd_line;
        $options->{'command'} = $cmd_line;
        if($c->request->parameters->{'test_only'}) {
            $c->log->debug( 'not sending (TESTMODE) ' . $cmd_line );
        } else {
            $c->log->debug( 'sending ' . $cmd_line );
            $c->{'db'}->send_command( %{$options} );
            $c->log->info( '[' . $c->user->username . '] cmd: ' . $cmd_line );
        }
    }

    return (1);
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

    for my $x ( 0 .. $number ) {
        push @{$spread_dates}, int( $starttimestamp + ( $x * $delta ) );
    }

    return $spread_dates;
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
