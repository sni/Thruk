package Thruk::Controller::restricted;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::restricted - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=head2 restricted_cgi

page: /thruk/cgi-bin/restricted.cgi

=cut

sub restricted_cgi : Path('/thruk/cgi-bin/restricted.cgi') {
    my( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/restricted/index');
}

##########################################################

=head2 index

=cut
sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->res->content_type('text/plain');
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

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
