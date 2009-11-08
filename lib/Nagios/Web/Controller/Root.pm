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

sub cmd : Path('nagios/cgi-bin/cmd.cgi') {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'cmd.tt';
}

sub extinfo : Path('nagios/cgi-bin/extinfo.cgi') {
    my ( $self, $c ) = @_;
    $c->stash->{template} = 'extinfo.tt';
}

sub tac : Path('nagios/cgi-bin/tac.cgi') {
    my ( $self, $c ) = @_;
    print "HTTP 200 OK\nContent-Type: text/html\n\n<pre>\n";
    my $livestatus = $self->get_livestatus();
    print Dumper($livestatus);
    $c->stash->{title}          = 'Nagios Tactical Monitoring Overview';
    $c->stash->{infoBoxTitle}   = 'Tactical Monitoring Overview';
    $c->stash->{page}           = 'tac';
    $c->stash->{template}       = 'tac.tt';
}

sub get_livestatus {
    my $self = shift;

    my $livestatus = Nagios::MKLivestatus->new(
                                'socket'   => Nagios::Web->config->{livesocket_path},
                                'verbose'  => Nagios::Web->config->{'livesocket_verbose'},
    );

    my $res = $livestatus->selectall_arrayref("GET services
Stats: flap_detection_enabled = 1
Stats: flap_detection_enabled = 0
Stats: notifications_enabled = 1
Stats: notifications_enabled = 0
Stats: event_handler_enabled = 1
Stats: event_handler_enabled = 0
Stats: checks_enabled = 1
Stats: checks_enabled = 0
Stats: accept_passive_service_checks = 1
Stats: accept_passive_service_checks = 0
");
    print Dumper($res);
}


=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

=head1 AUTHOR

sven,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
