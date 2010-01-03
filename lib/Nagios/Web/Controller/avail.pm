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

    # Step 1
    $c->stash->{title}            = 'Nagios Availability';
    $c->stash->{infoBoxTitle}     = 'Availability Report';
    $c->stash->{page}             = 'avail';
    $c->stash->{template}         = 'avail_step_1.tt';
    $c->stash->{'no_auto_reload'} = 1;

    my $report_type    = $c->{'request'}->{'parameters'}->{'report_type'};
    my $get_date_parts = $c->{'request'}->{'parameters'}->{'get_date_parts'};
    my $hosts          = $c->{'request'}->{'parameters'}->{'hosts'};
    my $hostgroups     = $c->{'request'}->{'parameters'}->{'hostgroups'};
    my $services       = $c->{'request'}->{'parameters'}->{'services'};
    my $servicegroups  = $c->{'request'}->{'parameters'}->{'servicegroups'};

    # set infobox title
    if(defined $report_type) {
        if($report_type eq 'hosts') {
            $c->stash->{infoBoxTitle} = 'Host Availability Report';
        }
        if($report_type eq 'hostgroups') {
            $c->stash->{infoBoxTitle} = 'Hostgroup Availability Report';
        }
        if($report_type eq 'servicegroups') {
            $c->stash->{infoBoxTitle} = 'Servicegroup Availability Report';
        }
        if($report_type eq 'services') {
            $c->stash->{infoBoxTitle} = 'Service Availability Report';
        }
    }

    # Step 3
    if(defined $get_date_parts) {
        $c->stash->{timeperiods} = $c->{'live'}->selectall_arrayref("GET timeperiods\nColumns: name".Nagios::Web::Helper::get_auth_filter($c, 'timeperiods'), { Slice => 1});
        $c->stash->{template}    = 'avail_step_3.tt';
    }

    # Step 2
    elsif(defined $report_type) {
        my $data;
        if($report_type eq 'hosts') {
            $data = $c->{'live'}->selectall_arrayref("GET hosts\nColumns: name".Nagios::Web::Helper::get_auth_filter($c, 'hosts'), { Slice => 1});
        }
        if($report_type eq 'hostgroups') {
            $data = $c->{'live'}->selectall_arrayref("GET hostgroups\nColumns: name".Nagios::Web::Helper::get_auth_filter($c, 'hostgroups'), { Slice => 1});
        }
        if($report_type eq 'servicegroups') {
            $data = $c->{'live'}->selectall_arrayref("GET servicegroups\nColumns: name".Nagios::Web::Helper::get_auth_filter($c, 'servicegroups'), { Slice => 1});
        }
        if($report_type eq 'services') {
            $data = $c->{'live'}->selectall_arrayref("GET services\nColumns: host_name description".Nagios::Web::Helper::get_auth_filter($c, 'services'), { Slice => 1});
            for my $dat (@{$data}) {
                $dat->{'name'} = $dat->{'host_name'}.';'.$dat->{'description'};
            }
        }

        if(defined $data) {
            $c->stash->{data}        = Nagios::Web::Helper->sort($c, $data, 'name');
            $c->stash->{template}    = 'avail_step_2.tt';
        }
    }

    $c->stash->{report_type}  = $report_type;
    $c->stash->{hosts}        = $hosts;
    $c->stash->{hostgroups}   = $hostgroups;
    $c->stash->{services}     = $services;
    $c->stash->{servicegroups} = $servicegroups;

}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
