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

print "200 OK\n";
    my $hosts    = $c->{'live'}->selectall_arrayref("GET hosts\nStats: state = 0\nStats: state = 1\nStats: state = 2\nStats: state = 3\nStats: state = 4", { Slice => {}, rename => { 'name' => 'host_name' } });
    $c->{'live'}->verbose(1);
    my $services = $c->{'live'}->selectall_arrayref("GET services
Stats: state = 0
Stats: state = 1
Stats: state = 2
Stats: state = 3
Stats: state = 4
Stats: host_state != 0
Stats: state = 1
StatsAnd: 2
Stats: host_state != 0
Stats: state = 2
StatsAnd: 2
Stats: host_state != 0
Stats: state = 3
StatsAnd: 2", { Slice => {}, rename => { 'name' => 'host_name' } });
    use Data::Dumper;
    $Data::Dumper::Sortkeys = 1;
    print Dumper($services);
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
