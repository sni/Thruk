package Nagios::Web::Controller::outages;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Nagios::Web::Controller::outages - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    $c->stash->{title}          = 'Network Outages';
    $c->stash->{infoBoxTitle}   = 'Network Outages';
    $c->stash->{page}           = 'outages';
    $c->stash->{template}       = 'outages.tt';
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
