package Thruk::Controller::histogram;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::histogram - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    # set defaults
    $c->stash->{title}            = 'Histogram';
    $c->stash->{infoBoxTitle}     = 'Host and Service Alert Histogram';
    $c->stash->{page}             = 'histogram';
    $c->stash->{'no_auto_reload'} = 1;

    Thruk::Utils::ssi_include($c);

    # Step 1 - select report type
    $self->_show_step_1($c);

    return 1;
}


##########################################################
sub _show_step_1 {
    my ( $self, $c ) = @_;

    $c->stats->profile(begin => "_show_step_1()");
    $c->stash->{template} = 'histogram_step_1.tt';
    $c->stats->profile(end => "_show_step_1()");

    return 1;
}


=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
