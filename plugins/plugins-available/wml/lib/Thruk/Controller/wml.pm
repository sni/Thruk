package Thruk::Controller::wml;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::wml - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

##########################################################

=head2 add_routes

page: /thruk/cgi-bin/statuswml.cgi

=cut

sub add_routes {
    my($self, $app, $routes) = @_;

    $routes->{'/thruk/cgi-bin/statuswml.cgi'} = 'Thruk::Controller::wml::index';

    $app->config->{'use_feature_wml'} = 1;

    return;
}

##########################################################

=head2 index

=cut
sub index {
    my($c) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_DEFAULTS);

    my $style='uprobs';
    my $hostfilter = [ { 'state'=> { '>' => 0 } }, {'has_been_checked' => 1}, {'acknowledged' => 0}, {'scheduled_downtime_depth' => 0} ];
    my $servicefilter = [ { 'state'=> { '>' => 0 } }, {'has_been_checked' => 1}, {'acknowledged' => 0}, {'scheduled_downtime_depth' => 0} ];
    if(defined $c->req->parameters->{'style'}) {
       $style=$c->req->parameters->{'style'};
    }

    if ($style eq 'aprobs') {
            $hostfilter = [ { 'state'=> { '>' => 0 } }, {'has_been_checked' => 1} ];
            $servicefilter = [ { 'state'=> { '>' => 0 } }, {'has_been_checked' => 1} ];
    }
    my $services = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter ]);
    my $hosts = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ]);
    $c->stash->{services}  = $services;
    $c->stash->{hosts}     = $hosts;
    $c->stash->{template}  = 'wml.tt';

    return 1;
}

=head1 AUTHOR

Franky Van Liedekerke, 2012

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
