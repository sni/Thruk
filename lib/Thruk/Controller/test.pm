package Thruk::Controller::test;

use strict;
use warnings;
use utf8;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::test - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index

=cut

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    die("test.cgi is disabled unless in test mode!") unless $c->config->{'thruk_debug'};

    $c->stash->{'template'} = 'main.tt';

    my $action = $c->{'request'}->{'parameters'}->{'action'} || '';

    if($action eq 'leak') {
        my $leak = Thruk::Backend::Manager->new();
        $leak->{'test'} = $leak;
        $c->{stash}->{ctx} = $c;
    }

    return 1;
}

=head1 AUTHOR

Sven Nierlein, 2013, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
