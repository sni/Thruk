package Thruk::Controller::outages;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::outages - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;


    my $outages = $c->{'live'}->selectall_arrayref("GET hosts\n".Thruk::Utils::get_auth_filter($c, 'hosts')."
Columns: name last_state_change childs
Filter: state = 1
Filter: childs !=
And: 2
", { Slice => 1, AddPeer => 1 });

    if(defined $outages and scalar @{$outages} > 0) {
        my $hostcomments = Thruk::Utils::get_hostcomments($c);
        my $all_hosts = $c->{'live'}->selectall_hashref("GET hosts\n".Thruk::Utils::get_auth_filter($c, 'hosts')."
Columns: name childs num_services
", 'name');

        for my $host (@{$outages}) {

            # get number of comments
            $host->{'comment_count'} = 0;
            if(defined $hostcomments->{$host->{'name'}}) {
                $host->{'comment_count'} = scalar keys %{$hostcomments->{$host->{'name'}}};
            }

            # count number of affected hosts / services
            my($affected_hosts,$affected_services) = $self->_count_affected_hosts_and_services($c, $host->{'name'}, $all_hosts);
            $host->{'affected_hosts'}    = $affected_hosts;
            $host->{'affected_services'} = $affected_services;

            $host->{'severity'} = int($affected_hosts + $affected_services/4);
        }
    }

    # sort by severity
    my $sortedoutages = Thruk::Utils::sort($c, $outages, 'severity', 'DESC');

    $c->stash->{outages}        = $sortedoutages;
    $c->stash->{title}          = 'Network Outages';
    $c->stash->{infoBoxTitle}   = 'Network Outages';
    $c->stash->{page}           = 'outages';
    $c->stash->{template}       = 'outages.tt';

    Thruk::Utils::ssi_include($c);

    return 1;
}

##########################################################
# create the status details page
sub _count_affected_hosts_and_services {
    my($self, $c, $host, $all_hosts ) = @_;

    my $affected_hosts    = 0;
    my $affected_services = 0;

    return(0,0) if !defined $all_hosts->{$host};

    if(defined $all_hosts->{$host}->{'childs'} and $all_hosts->{$host}->{'childs'} ne '') {
        for my $child (split/,/mx, $all_hosts->{$host}->{'childs'}) {
            my($child_affected_hosts,$child_affected_services) = $self->_count_affected_hosts_and_services($c, $child, $all_hosts);
            $affected_hosts    += $child_affected_hosts;
            $affected_services += $child_affected_services;
        }
    }

    # add number of directly affected hosts
    $affected_hosts++;

    # add number of directly affected services
    $affected_services += $all_hosts->{$host}->{'num_services'};

    return($affected_hosts, $affected_services);
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
