package Thruk::Controller::login;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::login - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    $c->stash->{'theme'}    = $c->config->{'default_theme'};
    $c->stash->{'page'}     = 'splashpage';
    $c->stash->{'template'} = 'login.tt';

    my $login  = $c->request->parameters->{'login'}    || '';
    my $pass   = $c->request->parameters->{'password'} || '';
    my $submit = $c->request->parameters->{'submit'}   || '';

    if($submit ne '') {
        Thruk::Utils::set_message( $c, 'fail_message', 'login is currently disabled' );
    }

    Thruk::Utils::ssi_include($c);

    return 1;
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
