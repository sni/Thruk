package Nagios::Web::Controller::status;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Nagios::Web::Controller::status - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    my $allowed_subpages = {'detail' => 1, 'grid' => 1, 'hostdetail' => 1, 'overview' => 1, 'summmary' => 1};
    my $style = $c->{'request'}->{'parameters'}->{'style'} || 'detail';
    $style = 'detail' unless defined $allowed_subpages->{$style};

    if($style eq 'detail') {
        $self->_process_details_page($c);
    }
    elsif($style eq 'hostdetail') {
        $self->_process_hostdetails_page($c);
    }

    $c->stash->{title}          = 'Current Network Status';
    $c->stash->{infoBoxTitle}   = 'Current Network Status';
    $c->stash->{page}           = 'status';
    $c->stash->{template}       = 'status_'.$style.'.tt';
}

##########################################################
# create the hostdetails page
sub _process_hostdetails_page {
    my ( $self, $c ) = @_;

    # which hostgroup to display?
    my $hostgroup = $c->{'request'}->{'parameters'}->{'hostgroup'} || 'all';
    my $hostfilter    = "";
    my $servicefilter = "";
    if($hostgroup ne 'all') {
        $hostfilter    = "\nFilter: groups >= $hostgroup";
        $servicefilter = "\nFilter: host_groups >= $hostgroup";
    }

    # TODO: add comments into hosts.comments and hosts.comment_count
    my $hosts = $c->{'live'}->selectall_arrayref("GET hosts$hostfilter", { Slice => {} });
    for my $host (@{$hosts}) {
        $host->{'comment_count'} = 0;
    }

    # host status box
    my $host_stats = $c->{'live'}->selectrow_hashref("GET hosts$hostfilter
Stats: has_been_checked = 1
Stats: state = 0
StatsAnd: 2 as up

Stats: has_been_checked = 1
Stats: state = 1
StatsAnd: 2 as down

Stats: has_been_checked = 1
Stats: state = 2
StatsAnd: 2 as unreachable

Stats: has_been_checked = 0 as pending
");

    # services status box
    my $service_stats = $c->{'live'}->selectrow_hashref("GET services$servicefilter
Stats: has_been_checked = 1
Stats: state = 0
StatsAnd: 2 as ok

Stats: has_been_checked = 1
Stats: state = 1
StatsAnd: 2 as warning

Stats: has_been_checked = 1
Stats: state = 2
StatsAnd: 2 as critical

Stats: has_been_checked = 1
Stats: state = 3
StatsAnd: 2 as unknown

Stats: has_been_checked = 0 as pending
");

    # do the sort
    my $sorttype   = $c->{'request'}->{'parameters'}->{'sorttype'}   || 1;
    my $sortoption = $c->{'request'}->{'parameters'}->{'sortoption'} || 7;
    my $order = "ASC";
    $order = "DESC" if $sorttype == 2;
    my $sortoptions = {
                '1' => [ 'name',                'host name'       ],
                '4' => [ 'last_check',          'last check time' ],
                '6' => [ 'last_state_change',   'state duration'  ],
                '8' => [ 'state',               'host status'     ],
    };
    $sortoption = 1 if !defined $sortoptions->{$sortoption};
    my $sortedhosts = Nagios::Web::Helper->sort($c, $hosts, $sortoptions->{$sortoption}->[0], $order);

    $c->stash->{'orderby'}       = $sortoptions->{$sortoption}->[1];
    $c->stash->{'orderdir'}      = $order;
    $c->stash->{'hostgroup'}     = $hostgroup;
    $c->stash->{'hosts'}         = $sortedhosts;
    $c->stash->{'host_stats'}    = $host_stats;
    $c->stash->{'service_stats'} = $service_stats;
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
