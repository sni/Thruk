package Nagios::Web::Controller::tac;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Nagios::Web::Controller::tac - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    #print "HTTP 200 OK\nContent-Type: text/html\n\n<pre>\n";
    #my $livestatus = $self->get_livestatus();
    #print Dumper($livestatus);
    $c->stash->{title}          = 'Nagios Tactical Monitoring Overview';
    $c->stash->{infoBoxTitle}   = 'Tactical Monitoring Overview';
    $c->stash->{page}           = 'tac';
    $c->stash->{template}       = 'tac.tt';
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
