package Nagios::Web::Controller::cmd;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Template;
use Time::HiRes qw( usleep );

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
    } else {
        # no command submited, view commands page
        if($cmd_typ == 55 or $cmd_typ == 56) {
            $c->stash->{'hostdowntimes'}    = $c->{'live'}->selectall_arrayref("GET downtimes\nFilter: service_description = ", { Slice => {} });
            $c->stash->{'servicedowntimes'} = $c->{'live'}->selectall_arrayref("GET downtimes\nFilter: service_description != ", { Slice => {} });
        }

        my $comment_author          = $c->user->username;
        $comment_author             = $c->user->alias if defined $c->user->alias;
        $c->stash->{comment_author} = $comment_author;
        $c->stash->{referer}        = $c->{'request'}->{'headers'}->{'referer'} || '';
        $c->stash->{cmd_tt}         = 'cmd.tt';
        $c->stash->{template}       = 'cmd/cmd_typ_'.$cmd_typ.'.tt';
    }
}


######################################
# sending commands
sub _do_send_command {
    my ( $self, $c ) = @_;

    my $cmd_typ = $c->{'request'}->{'parameters'}->{'cmd_typ'};
    $c->detach('/error/index/6') unless defined $cmd_typ;

    # locked author names?
    if($c->{'cgi_cfg'}->{'lock_author_names'}) {
        my $author = $c->user->username;
        $author    = $c->user->alias if defined $c->user->alias;
        $c->{'request'}->{'parameters'}->{'com_author'} = $author;
    }

    my $tt  = Template->new($c->{'View::TT'});
    my $cmd = '';
    $tt->process( 'cmd/cmd_typ_'.$cmd_typ.'.tt', { c => $c, cmd_tt => 'cmd_line.tt' }, \$cmd ) || die $tt->error();
    $cmd =~ s/^\s+//gmx;
    $cmd =~ s/\s+$//gmx;

    # unknown command given?
    $c->detach('/error/index/7') unless defined $cmd;

    # unauthorized?
    $c->detach('/error/index/8') unless $cmd ne '';

    # send the command
    $cmd = "COMMAND [".time()."] $cmd";
    $c->log->info("sending: $cmd");
    $c->{'live'}->do($cmd);

    # view our success page or redirect to referer
    my $referer = $c->{'request'}->{'parameters'}->{'referer'} || '';
    if($referer ne '') {
        # wait 0.3 seconds, so the command is probably already processed
        usleep(300000);
        $c->redirect($referer);
    } else {
        $c->stash->{template} = 'cmd_success.tt';
    }
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
