package Thruk::Controller::avail;

use strict;
use warnings;
use utf8;
use Data::Dumper;
use Monitoring::Availability;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::avail - Catalyst Controller

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
    $c->stash->{title}            = 'Availability';
    $c->stash->{infoBoxTitle}     = 'Availability Report';
    $c->stash->{page}             = 'avail';
    $c->stash->{'no_auto_reload'} = 1;

    Thruk::Utils::ssi_include($c);

    # lookup parameters
    my $report_type    = $c->{'request'}->{'parameters'}->{'report_type'}  || '';
    my $timeperiod     = $c->{'request'}->{'parameters'}->{'timeperiod'};
    my $host           = $c->{'request'}->{'parameters'}->{'host'}         || '';
    my $hostgroup      = $c->{'request'}->{'parameters'}->{'hostgroup'}    || '';
    my $service        = $c->{'request'}->{'parameters'}->{'service'}      || '';
    my $servicegroup   = $c->{'request'}->{'parameters'}->{'servicegroup'} || '';


    # set them for our template
    $c->stash->{report_type}  = $report_type;
    $c->stash->{host}         = $host;
    $c->stash->{hostgroup}    = $hostgroup;
    $c->stash->{service}      = $service;
    $c->stash->{servicegroup} = $servicegroup;

    # set infobox title
    if($report_type eq 'servicegroups'  or $servicegroup) {
        $c->stash->{infoBoxTitle} = 'Servicegroup Availability Report';
    }
    elsif($report_type eq 'services'    or $service) {
        $c->stash->{infoBoxTitle} = 'Service Availability Report';
    }
    elsif($report_type eq 'hosts'       or $host) {
        $c->stash->{infoBoxTitle} = 'Host Availability Report';
    }
    elsif($report_type eq 'hostgroups'  or $hostgroup) {
        $c->stash->{infoBoxTitle} = 'Hostgroup Availability Report';
    }



    # Step 2 - select specific host/service/group
    if($report_type and $self->_show_step_2($c, $report_type)) {
    }

    # Step 3 - select date parts
    elsif(exists $c->{'request'}->{'parameters'}->{'get_date_parts'} and $self->_show_step_3($c)) {
    }

    # Step 4 - create report
    elsif(!$report_type
       and ($host or $service or $servicegroup or $hostgroup)
       and $self->_create_report($c)) {
    }



    # Step 1 - select report type
    else {
        $self->_show_step_1($c);
    }

    return 1;
}

##########################################################
sub _show_step_1 {
    my ( $self, $c ) = @_;

    $c->stats->profile(begin => "_show_step_1()");
    $c->stash->{template} = 'avail_step_1.tt';
    $c->stats->profile(end => "_show_step_1()");

    return 1;
}


##########################################################
sub _show_step_2 {
    my ( $self, $c, $report_type ) = @_;

    $c->stats->profile(begin => "_show_step_2($report_type)");

    my $data;
    if($report_type eq 'hosts') {
        $data = $c->{'live'}->selectall_hashref("GET hosts\nColumns: name\n".Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), 'name');
    }
    elsif($report_type eq 'hostgroups') {
        $data = $c->{'live'}->selectall_hashref("GET hostgroups\nColumns: name\n".Thruk::Utils::Auth::get_auth_filter($c, 'hostgroups'), 'name');
    }
    elsif($report_type eq 'servicegroups') {
        $data = $c->{'live'}->selectall_hashref("GET servicegroups\nColumns: name\n".Thruk::Utils::Auth::get_auth_filter($c, 'servicegroups'), 'name');
    }
    elsif($report_type eq 'services') {
        my $services = $c->{'live'}->selectall_arrayref("GET services\n".Thruk::Utils::Auth::get_auth_filter($c, 'services')."\nColumns: host_name description", { Slice => 1});
        for my $service (@{$services}) {
            $data->{$service->{'host_name'}.";".$service->{'description'}} = 1;
        }
    }
    else {
        return 0;
    }

    my @sorted = sort keys %{$data};
    $c->stash->{data}        = \@sorted;
    $c->stash->{template}    = 'avail_step_2.tt';

    $c->stats->profile(end => "_show_step_2($report_type)");

    return 1;
}

##########################################################
sub _show_step_3 {
    my ( $self, $c ) = @_;

    $c->stats->profile(begin => "_show_step_3()");

    my @timeperiods = sort keys %{$c->{'live'}->selectall_hashref("GET timeperiods\nColumns: name\n".Thruk::Utils::Auth::get_auth_filter($c, 'timeperiods'), 'name')};
    $c->stash->{timeperiods} = \@timeperiods;
    $c->stash->{template}    = 'avail_step_3.tt';

    my($host,$service);
    $service = $c->{'request'}->{'parameters'}->{'service'};
    if($service and CORE::index($service, ';') > 0) {
        ($host,$service) = split/;/mx, $c->{'request'}->{'parameters'}->{'service'};
        $c->stash->{host}    = $host;
        $c->stash->{service} = $service;
    }

    $c->stats->profile(end => "_show_step_3()");

    return 1;
}

##########################################################
sub _create_report {
    my ( $self, $c ) = @_;
    my $start_time   = time();

    $c->stats->profile(begin => "_create_report()");

    Thruk::Utils::calculate_availability($c);

    # finished
    $c->stash->{time_token} = time() - $start_time;
    $c->stats->profile(end => "_create_report()");

    return 1;
}

=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
