package Thruk::Controller::config;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::config - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

##########################################################
sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    $c->stash->{title}            = 'Configuration';
    $c->stash->{infoBoxTitle}     = 'Configuration';
    $c->stash->{page}             = 'config';
    $c->stash->{template}         = 'config.tt';
    $c->stash->{'no_auto_reload'} = 1;

    $c->detach('/error/index/8') unless $c->check_user_roles( "authorized_for_configuration_information" );

    my $type = $c->{'request'}->{'parameters'}->{'type'};
    $c->stash->{type}             = $type;
    return unless defined $type;

    # timeperiods
    if($type eq 'timeperiods') {
        my $data = $c->{'live'}->selectall_arrayref("GET timeperiods\nColumns: name alias", { Slice => 1, AddPeer => 1, Deepcopy => 1, Deepcopy => 1 });
        $data    = Thruk::Utils::remove_duplicates($c, $data);
        $data    = Thruk::Utils::sort($c, $data, 'name');
        $c->stash->{data}     = $data;
        $c->stash->{template} = 'config_timeperiods.tt';
    }

    # commands
    if($type eq 'commands') {
        my $data = $c->{'live'}->selectall_arrayref("GET commands\nColumns: name line", { Slice => 1, AddPeer => 1, Deepcopy => 1 });
        $data    = Thruk::Utils::remove_duplicates($c, $data);
        $data    = Thruk::Utils::sort($c, $data, 'name');
        $c->stash->{data}     = $data;
        $c->stash->{template} = 'config_commands.tt';
    }

    # contacts
    elsif($type eq 'contacts') {
        my $data = $c->{'live'}->selectall_arrayref("GET contacts\nColumns: name alias email pager service_notification_period host_notification_period", { Slice => 1, AddPeer => 1, Deepcopy => 1 });
        $data    = Thruk::Utils::remove_duplicates($c, $data);
        $data    = Thruk::Utils::sort($c, $data, 'name');
        $c->stash->{data}     = $data;
        $c->stash->{template} = 'config_contacts.tt';
    }

    # hosts
    elsif($type eq 'hosts') {
        my $data = $c->{'live'}->selectall_arrayref("GET hosts\nColumns: name alias address parents max_check_attempts check_interval retry_interval check_command check_period obsess_over_host active_checks_enabled accept_passive_checks check_freshness contacts notification_interval first_notification_delay notification_period event_handler_enabled flap_detection_enabled low_flap_threshold high_flap_threshold process_performance_data notes notes_url action_url icon_image icon_image_alt", { Slice => 1, AddPeer => 1, Deepcopy => 1 });
        $data    = Thruk::Utils::remove_duplicates($c, $data);
        $data    = Thruk::Utils::sort($c, $data, 'name');
        $c->stash->{data}     = $data;
        $c->stash->{template} = 'config_hosts.tt';
    }

    # services
    elsif($type eq 'services') {
        my $data = $c->{'live'}->selectall_arrayref("GET services\nColumns: host_name description notifications_enabled max_check_attempts check_interval retry_interval check_command check_period obsess_over_service active_checks_enabled accept_passive_checks contacts notification_interval first_notification_delay notification_period event_handler_enabled flap_detection_enabled low_flap_threshold high_flap_threshold process_performance_data notes notes_url action_url icon_image icon_image_alt", { Slice => 1, AddPeer => 1, Deepcopy => 1 });
        $data = Thruk::Utils::remove_duplicates($c, $data);
        $data = Thruk::Utils::sort($c, $data, [ 'host_name', 'description' ]);
        $c->stash->{data}     = $data;
        $c->stash->{template} = 'config_services.tt';
    }

    # hostgroups
    elsif($type eq 'hostgroups') {
        my $data = $c->{'live'}->selectall_arrayref("GET hostgroups\nColumns: name alias members", { Slice => 1, Deepcopy => 1 });
        my $hostgroups = {};
        for my $hostgroup (@{$data}) {
            if(!defined $hostgroups->{$hostgroup->{'name'}}) {
                $hostgroups->{$hostgroup->{'name'}} = $hostgroup;
                @{$hostgroups->{$hostgroup->{'name'}}->{'members_array'}} = split /,/mx, $hostgroup->{'members'};
            } else {
                push @{$hostgroups->{$hostgroup->{'name'}}->{'members_array'}}, split /,/mx, $hostgroup->{'members'};
            }
        }
        $c->stash->{data}     = $hostgroups;
        $c->stash->{template} = 'config_hostgroups.tt';
    }

    # servicegroups
    elsif($type eq 'servicegroups') {
        my $data = $c->{'live'}->selectall_arrayref("GET servicegroups\nColumns: name alias members", { Slice => 1, Deepcopy => 1 });
        my $servicegroups = {};
        for my $servicegroup (@{$data}) {
            if(!defined $servicegroups->{$servicegroup->{'name'}}) {
                $servicegroups->{$servicegroup->{'name'}} = $servicegroup;
                @{$servicegroups->{$servicegroup->{'name'}}->{'members_array'}} = split /,/mx, $servicegroup->{'members'};
            } else {
                push @{$servicegroups->{$servicegroup->{'name'}}->{'members_array'}}, split /,/mx, $servicegroup->{'members'};
            }
        }
        for my $group (values %{$servicegroups}) {
            for my $service (sort @{$group->{'members_array'}}) {
                my @split = split(/\|/mx,$service);
                push @{$group->{'members_split'}}, \@split;
            }
        }
        $c->stash->{data}     = $servicegroups;
        $c->stash->{template} = 'config_servicegroups.tt';
    }

    return 1;
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
