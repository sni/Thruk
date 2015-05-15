package Thruk::Controller::minemap;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::minemap - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

##########################################################

=head2 add_routes

page: /thruk/cgi-bin/minemap.cgi

=cut

sub add_routes {
    my($self, $app, $routes) = @_;

    $routes->{'/thruk/cgi-bin/minemap.cgi'} = 'Thruk::Controller::minemap::index';

    Thruk::Utils::Menu::insert_sub_item('Current Status', 'Service Groups', {
                                    'href'  => $app->config->{'Thruk::Plugin::Minemap'}->{'default_link'} || $app->config->{'minemap_default_link'} || '/thruk/cgi-bin/minemap.cgi',
                                    'name'  => 'Mine Map',
    });

    Thruk::Utils::Status::add_view({'group' => 'Mine Map',
                                    'name'  => 'Mine Map',
                                    'value' => 'minemap',
                                    'url'   => 'minemap.cgi',
    });

    $app->config->{'has_feature_minemap'} = 1;

    return;
}

##########################################################

=head2 index

minemap index page

=cut
sub index {
    my ( $c ) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_DEFAULTS);

    # set some defaults
    Thruk::Utils::Status::set_default_stash($c);

    my $style = $c->req->parameters->{'style'} || 'minemap';
    if($style ne 'minemap') {
        return if Thruk::Utils::Status::redirect_view($c, $style);
    }

    # do the filter
    my( $hostfilter, $servicefilter, $groupfilter ) = Thruk::Utils::Status::do_filter($c);
    return if $c->stash->{'has_error'};

    my($uniq_services, $hosts, $matrix) = Thruk::Utils::Status::get_service_matrix($c, $hostfilter, $servicefilter);
    $c->stash->{services}     = $uniq_services;
    $c->stash->{hostnames}    = $hosts;
    $c->stash->{matrix}       = $matrix;

    my $longest_service = 1;
    for my $s (keys %{$uniq_services}) {
        my $len = length $s;
        $longest_service = $len if $len > $longest_service;
    }

    $c->stash->{head_height}   = 7*$longest_service;
    $c->stash->{style}         = 'minemap';
    $c->stash->{substyle}      = 'service';
    $c->stash->{title}         = 'Mine Map';
    $c->stash->{show_top_pane} = 1;
    $c->stash->{page}          = 'status';
    $c->stash->{template}      = 'minemap.tt';
    $c->stash->{infoBoxTitle}  = 'Mine Map';

    Thruk::Utils::ssi_include($c);

    Thruk::Utils::Status::set_custom_title($c);

    return 1;
}


=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
