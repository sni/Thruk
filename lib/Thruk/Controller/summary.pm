package Thruk::Controller::summary;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::summary - Catalyst Controller

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
    $c->stash->{title}            = 'Event Summary';
    $c->stash->{infoBoxTitle}     = 'Alert Summary Report';
    $c->stash->{page}             = 'summary';
    $c->stash->{'no_auto_reload'} = 1;

    # Step 1 - select report type
    $self->_show_step_1($c);

    return 1;
}


##########################################################
sub _show_step_1 {
    my ( $self, $c ) = @_;
    $c->stats->profile(begin => "_show_step_1()");

    my @hosts         = sort keys %{$c->{'live'}->selectall_hashref("GET hosts\nColumns: name\n".Thruk::Utils::get_auth_filter($c, 'hosts'), 'name')};
    my @hostgroups    = sort keys %{$c->{'live'}->selectall_hashref("GET hostgroups\nColumns: name\n".Thruk::Utils::get_auth_filter($c, 'hostgroups'), 'name')};
    my @servicegroups = sort keys %{$c->{'live'}->selectall_hashref("GET servicegroups\nColumns: name\n".Thruk::Utils::get_auth_filter($c, 'servicegroups'), 'name')};

    $c->stash->{hosts}         = \@hosts;
    $c->stash->{hostgroups}    = \@hostgroups;
    $c->stash->{servicegroups} = \@servicegroups;
    $c->stash->{template}      = 'summary_step_1.tt';

    $c->stats->profile(end => "_show_step_1()");
    return 1;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
