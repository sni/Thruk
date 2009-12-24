package Nagios::Web::Controller::config;

use strict;
use warnings;
use parent 'Catalyst::Controller';

=head1 NAME

Nagios::Web::Controller::config - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) :MyAction('AddDefaults') {
    my ( $self, $c ) = @_;

    $c->detach('/error/index/8') unless $c->check_user_roles( "authorized_for_configuration_information" );

    $c->stash->{title}            = 'Configuration';
    $c->stash->{infoBoxTitle}     = 'Configuration';
    $c->stash->{page}             = 'config';
    $c->stash->{template}         = 'config.tt';
    $c->stash->{'no_auto_reload'} = 1;

    my $type = $c->{'request'}->{'parameters'}->{'type'};
    $c->stash->{type}             = $type;
    return unless defined $type;
    if($type eq 'commands') {
        $c->stash->{data}     = $c->{'live'}->selectall_hashref("GET commands\nColumns: name line", 'name');
        $c->stash->{template} = 'config_commands.tt';
    }
    elsif($type eq 'contacts') {
        $c->stash->{data}     = $c->{'live'}->selectall_hashref("GET contacts\nColumns: name alias email pager service_notification_period host_notification_period", 'name');
        $c->stash->{template} = 'config_contacts.tt';
    }
    elsif($type eq 'hosts') {
        $c->stash->{commands} = $c->{'live'}->selectall_hashref("GET commands\nColumns: name line", 'name');
        $c->stash->{data}     = $c->{'live'}->selectall_hashref("GET hosts\nColumns: name alias address parents max_check_attempts check_interval retry_interval check_command check_period obsess_over_host active_checks_enabled accept_passive_checks check_freshness contacts notification_interval first_notification_delay notification_period event_handler_enabled flap_detection_enabled low_flap_threshold high_flap_threshold process_performance_data notes notes_url action_url icon_image icon_image_alt", 'name', { AddPeer => 1 });
        $c->stash->{template} = 'config_hosts.tt';
    }
}


=head1 AUTHOR

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
