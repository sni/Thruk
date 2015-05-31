package Thruk::Controller::restricted;

use strict;
use warnings;

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
    $c->stash->{'template'} = 'passthrough.tt';
    $c->stash->{'text'}     = 'FAIL';

    unless ($c->user_exists) {
        return 1 unless ($c->authenticate( {} ));
    }
    $c->stash->{'text'} = 'OK: '.$c->user->get('username') if $c->user_exists;

    return 1;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
