package Nagios::Web::Controller::extinfo;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Nagios::Web::Controller::extinfo - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index 

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Nagios::Web::Controller::extinfo in extinfo.');
}


=head1 AUTHOR

Sven Nierlein,,,

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
