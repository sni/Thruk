package Thruk::Controller::tac;

use strict;
use warnings;

=head1 NAME

Thruk::Controller::tac - Tactical Overview Controller

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=head2 index

=cut

##########################################################
sub index {
    my($c) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_CACHED_DEFAULTS);

    $c->stash->{'audiofile'}     = '';
    $c->stash->{'stats'}         = $c->{'db'}->get_performance_stats( services_filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ], hosts_filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );
    $c->stash->{'host_stats'}    = $c->{'db'}->get_host_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts')]);
    $c->stash->{'service_stats'} = $c->{'db'}->get_service_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services')]);
    $c->stash->{'title'}         = 'Tactical Monitoring Overview';
    $c->stash->{'infoBoxTitle'}  = 'Tactical Monitoring Overview';
    $c->stash->{'page'}          = 'tac';
    $c->stash->{'template'}      = 'tac.tt';

    # set audio file to play
    Thruk::Utils::Status::set_audio_file($c);

    Thruk::Utils::ssi_include($c);

    return 1;
}

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
