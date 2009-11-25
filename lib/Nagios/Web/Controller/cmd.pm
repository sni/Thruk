package Nagios::Web::Controller::cmd;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Nagios::Web::Controller::cmd - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

######################################
# index page
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    $c->stash->{title}          = "External Command Interface";
    $c->stash->{infoBoxTitle}   = "External Command Interface";
    $c->stash->{no_auto_reload} = 1;
    $c->stash->{page}           = 'cmd';

    my $cmd_typ = $c->{'request'}->{'parameters'}->{'cmd_typ'};
    $c->detach('/error/index/6') unless defined $cmd_typ;

    my $cmd_mod = $c->{'request'}->{'parameters'}->{'cmd_mod'};

    # command commited?
    if(defined $cmd_mod) {
        $self->_do_send_command($c);
        use Data::Dumper;
        $c->log->debug(Dumper($c->{'request'}->{'parameters'}));
    } else {
        # no command submited, view commands page
        if($cmd_typ == 55 or $cmd_typ == 56) {
            $c->stash->{'hostdowntimes'}    = $c->{'live'}->selectall_arrayref("GET downtimes\nFilter: service_description = ", { Slice => {} });
            $c->stash->{'servicedowntimes'} = $c->{'live'}->selectall_arrayref("GET downtimes\nFilter: service_description != ", { Slice => {} });
        }

        my $comment_author          = $c->user->username;
        $comment_author             = $c->user->alias if defined $c->user->alias;
        $c->stash->{comment_author} = $comment_author;
        $c->stash->{template}       = 'cmd/cmd_typ_'.$cmd_typ.'.tt';
    }
}


######################################
# sending commands
sub _do_send_command {
    my ( $self, $c ) = @_;

    use Data::Dumper;
    $c->log->debug(Dumper($c->{'request'}->{'parameters'}));

    my $cmd_typ = $c->{'request'}->{'parameters'}->{'cmd_typ'};
    $c->detach('/error/index/6') unless defined $cmd_typ;

    my $host        = $c->{'request'}->{'parameters'}->{'host'}         || '';
    my $service     = $c->{'request'}->{'parameters'}->{'service'}      || '';
    my $not_dly     = $c->{'request'}->{'parameters'}->{'not_dly'}      || 0;
    my $author      = $c->{'request'}->{'parameters'}->{'com_author'}   || '';
    my $comment     = $c->{'request'}->{'parameters'}->{'com_data'}     || '';
    my $com_id      = $c->{'request'}->{'parameters'}->{'com_id'}       || 0;
    my $persistent  = $c->{'request'}->{'parameters'}->{'persistent'}   || 0;
    my $start_time  = $c->{'request'}->{'parameters'}->{'start_time'}   || 0;
    my $force_check = $c->{'request'}->{'parameters'}->{'force_check'}  || 0;

    # calculate timestamp
    $start_time = Nagios::Web::Helper->str2time($start_time) if $start_time > 0;

    # locked author names?
    if($c->{'cgi_cfg'}->{'lock_author_names'}) {
        $author = $c->user->username;
        $author = $c->user->alias if defined $c->user->alias;
    }

    # which command to send?
    my $cmd;
    if($cmd_typ == 1) {
        $cmd = 'ADD_HOST_COMMENT;'.$host.';'.$persistent.';'.$author.';'.$comment;
    }
    elsif($cmd_typ == 2) {
        $cmd = 'DEL_HOST_COMMENT;'.$com_id;
    }
    elsif($cmd_typ == 3) {
        $cmd = 'ADD_SERVICE_COMMENT;'.$host.';'.$service.';'.$persistent.';'.$author.';'.$comment;
    }
    elsif($cmd_typ == 4) {
        $cmd = 'DEL_SERVICE_COMMENT;'.$com_id;
    }
    elsif($cmd_typ == 5) {
        $cmd = 'ENABLE_SVC_CHECK;'.$host.';'.$service;
    }
    elsif($cmd_typ == 6) {
        $cmd = 'DISABLE_SVC_CHECK;'.$host.';'.$service;
    }
    elsif($cmd_typ == 7) {
        if($force_check) {
            $cmd = 'SCHEDULE_FORCED_SVC_CHECK;'.$host.';'.$service.';'.$start_time;
        } else {
            $cmd = 'SCHEDULE_SVC_CHECK;'.$host.';'.$service.';'.$start_time;
        }
    }
    elsif($cmd_typ == 9) {
        $cmd = 'DELAY_SERVICE_NOTIFICATION;'.$host.';'.$service.';'.(time() + $not_dly * 60);
    }
    elsif($cmd_typ == 10) {
        $cmd = 'DELAY_HOST_NOTIFICATION;'.$host.';'.(time() + $not_dly * 60);
    }

    # unknown command given?
    $c->detach('/error/index/7') unless defined $cmd;

    # send the command
    $c->{'live'}->do("COMMAND [".time()."] $cmd");

    $c->stash->{template} = 'cmd_success.tt';

    # send a dummy command because livestatus breaks after a command
    eval {
        my $dummy = $c->{'live'}->selectall_arrayref("GET downtimes", { Slice => {} });
    };
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
