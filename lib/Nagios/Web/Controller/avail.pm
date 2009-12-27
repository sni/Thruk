package Nagios::Web::Controller::avail;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Nagios::Web::Controller::avail - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Nagios::Web::Controller::avail in avail.');
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
