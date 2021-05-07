package Thruk::Controller::restricted;

use warnings;
use strict;

=head1 NAME

Thruk::Controller::restricted - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=head2 index

=cut
sub index {
    my ( $c ) = @_;

    $c->res->headers->content_type('text/plain');
    $c->stash->{'template'}   = 'passthrough.tt';
    $c->stash->{'text'}       = 'FAIL';
    $c->stash->{'navigation'} = 'off'; # would be useless here, so set it non-empty, otherwise AddDefaults::end would read it again

    $c->authenticate(skip_db_access => 1) unless $c->user_exists;
    if($c->user_exists) {
        $c->stash->{'text'} = 'OK: '.$c->user->get('username');
    } else {
        $c->stash->{'text'} = 'ERROR: failed to authenticate';
    }

    return 1;
}

##########################################################

1;
