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

    my $view_mode = $c->req->parameters->{'view_mode'} || 'html';
    if($view_mode eq 'json') {
        my $data = {
            stats       => $c->stash->{'stats'},
            hosts       => $c->stash->{'host_stats'},
            services    => $c->stash->{'service_stats'},
        };
        return $c->render(json => $data);
    }


    # set audio file to play
    Thruk::Utils::Status::set_audio_file($c);

    Thruk::Utils::ssi_include($c);

    return 1;
}

1;
