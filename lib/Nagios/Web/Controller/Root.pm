package Nagios::Web::Controller::Root;

use strict;
use warnings;
use parent 'Catalyst::Controller';
use Data::Dumper;
use Nagios::MKLivestatus;
use Nagios::Web::Helper;

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

######################################
# begin, running at the begin of every req
#sub begin : Private {
#    my ( $self, $c ) = @_;
#}

######################################
# auto, runs on every request
#sub auto : Private {
#    my ( $self, $c ) = @_;
#
#}

######################################
# default page
sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

######################################
# index page
# we dont want index.html in the url
sub index :Path {
    my ( $self, $c ) = @_;
    $c->redirect("/nagios/");
}
# we dont want index.html in the url
sub index_html : Path('index.html') {
    my ( $self, $c ) = @_;
    $c->redirect('/nagios/');
}
# but if used not via fastcgi/apache, there is no way around
sub nagios_index_html : Path('/nagios/') {
    my ( $self, $c ) = @_;
    $c->redirect('/nagios/index.html');
}

######################################
# tac
sub tac_cgi : Path('nagios/cgi-bin/tac.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/tac/index');
}

######################################
# statusmap
sub statusmap_cgi : Path('nagios/cgi-bin/statusmap.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/statusmap/index');
}

######################################
# status
sub status_cgi : Path('nagios/cgi-bin/status.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/status/index');
}

######################################
# commands
sub cmd_cgi : Path('nagios/cgi-bin/cmd.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/cmd/index');
}

######################################
# outages
sub outages_cgi : Path('nagios/cgi-bin/outages.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/outages/index');
}

######################################
# avail
sub avail_cgi : Path('nagios/cgi-bin/avail.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/avail/index');
}

######################################
# trends
sub trends_cgi : Path('nagios/cgi-bin/trends.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/trends/index');
}

######################################
# history
sub history_cgi : Path('nagios/cgi-bin/history.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/history/index');
}

######################################
# summary
sub summary_cgi : Path('nagios/cgi-bin/summary.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/summary/index');
}

######################################
# histogram
sub histogram_cgi : Path('nagios/cgi-bin/histogram.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/histogram/index');
}

######################################
# notifications
sub notifications_cgi : Path('nagios/cgi-bin/notifications.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/notifications/index');
}

######################################
# showlog
sub showlog_cgi : Path('nagios/cgi-bin/showlog.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/showlog/index');
}

######################################
# extinfo
sub extinfo_cgi : Path('nagios/cgi-bin/extinfo.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/extinfo/index');
}

######################################
# config
sub config_cgi : Path('nagios/cgi-bin/config.cgi') {
    my ( $self, $c ) = @_;
    $c->detach('/config/index');
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {
    my ( $self, $c ) = @_;
    if($c->error) {
        for my $error (@{$c->error}) {
            $c->log->error($error);
        }
        $c->detach('/error/index/13');
    }
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
