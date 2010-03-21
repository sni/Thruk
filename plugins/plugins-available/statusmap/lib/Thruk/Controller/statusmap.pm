package Thruk::Controller::statusmap;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::statusmap - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


######################################

=head2 statusmap_cgi

page: /thruk/cgi-bin/statusmap.cgi

=cut
sub statusmap_cgi : Path('/thruk/cgi-bin/statusmap.cgi') {
    my ( $self, $c ) = @_;
    return $c->detach('/statusmap/index');
}

##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    my $hosts = $c->{'live'}->selectall_arrayref("GET hosts\n".Thruk::Utils::get_auth_filter($c, 'hosts')."\nColumns: state name address has_been_checked last_state_change", { Slice => {}, AddPeer => 1 });
    # order by address
    $c->stash->{hosts}        = Thruk::Utils::sort($c, $hosts, ['address'], 'ASC');

    $c->stash->{title}        = 'Network Map';
    $c->stash->{page}         = 'statusmap';
    $c->stash->{template}     = 'statusmap.tt';
    $c->stash->{infoBoxTitle} = 'Network Map For All Hosts';

    return 1;
}


=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
