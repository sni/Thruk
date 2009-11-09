package Nagios::Web::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Data::Dumper;
use Nagios::MKLivestatus;

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config->{namespace} = '';

=head1 NAME

Nagios::Web::Controller::Root - Root Controller for Nagios::Web

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=cut

=head2 index

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);

}

# index page
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'index.tt';
}
# main.html
sub main : Path('main.html') {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'main.tt';
}
# side.html
sub side : Path('side.html') {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'side.tt';
}

sub cmd : Path('nagios/cgi-bin/cmd.cgi') :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'cmd.tt';
}

sub status : Path('nagios/cgi-bin/status.cgi') :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;
    my $style = $c->{'request'}->{'parameters'}->{'style'} || 'hostdetail';
    $c->stash->{title}          = 'Current Network Status';
    $c->stash->{infoBoxTitle}   = 'Current Network Status';
    $c->stash->{page}           = 'status';
    $c->stash->{template}       = 'status_'.$style.'.tt';
}

sub extinfo : Path('nagios/cgi-bin/extinfo.cgi') :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;
    #print "HTTP 200 OK\nContent-Type: text/html\n\n<pre>\n";
    #print Dumper($c);
    #print Dumper($self);
    #exit;
    my $type = $c->{'request'}->{'parameters'}->{'type'} || 0;
    $c->stash->{title}          = 'Extended Information';
    $c->stash->{infoBoxTitle}   = 'Nagios Process Information';
    $c->stash->{page}           = 'extinfo';
    $c->stash->{template}       = 'extinfo_type_'.$type.'.tt';
}

sub tac : Path('nagios/cgi-bin/tac.cgi') :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;
    #print "HTTP 200 OK\nContent-Type: text/html\n\n<pre>\n";
    my $livestatus = $self->get_livestatus();
    #print Dumper($livestatus);
    $c->stash->{title}          = 'Nagios Tactical Monitoring Overview';
    $c->stash->{infoBoxTitle}   = 'Tactical Monitoring Overview';
    $c->stash->{page}           = 'tac';
    $c->stash->{template}       = 'tac.tt';
}

sub get_livestatus {
    my $self = shift;

#    my $res = $livestatus->selectall_arrayref("GET services
#Stats: flap_detection_enabled = 1
#Stats: flap_detection_enabled = 0
#Stats: notifications_enabled = 1
#Stats: notifications_enabled = 0
#Stats: event_handler_enabled = 1
#Stats: event_handler_enabled = 0
#Stats: checks_enabled = 1
#Stats: checks_enabled = 0
#Stats: accept_passive_service_checks = 1
#Stats: accept_passive_service_checks = 0
#");
    #print Dumper($res);
}


=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {
    # force catalyst to quit after each request while debugging
    #exit;
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
