package Thruk::Backend::Provider::Livestatus;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Monitoring::Livestatus::Class;
use parent 'Thruk::Backend::Provider::Base';

=head1 NAME

Thruk::Backend::Provider::Livestatus - connection provider for livestatus connections

=head1 DESCRIPTION

connection provider for livestatus connections

=head1 METHODS

=cut
##########################################################

=head2 new

create new manager

=cut
sub new {
    my( $class, $config ) = @_;
    my $self = {
        'live' => Monitoring::Livestatus::Class->new($config),
    };
    bless $self, $class;

    return $self;
}

##########################################################

=head2 peer_key

return the peers key

=cut
sub peer_key {
    my $self = shift;
    return $self->{'live'}->{'backend_obj'}->peer_key();
}


##########################################################

=head2 peer_addr

return the peers address

=cut
sub peer_addr {
    my $self = shift;
    return $self->{'live'}->{'backend_obj'}->peer_addr();
}

##########################################################

=head2 get_processinfo

return the process info

=cut
sub get_processinfo {
    my $self = shift;
    return $self->{'live'}
            ->table('status')
            ->columns(qw/
                accept_passive_host_checks accept_passive_service_checks check_external_commands
                check_host_freshness check_service_freshness enable_event_handlers enable_flap_detection
                enable_notifications execute_host_checks execute_service_checks last_command_check
                last_log_rotation livestatus_version nagios_pid obsess_over_hosts obsess_over_services
                process_performance_data program_start program_version interval_length
            /)
            ->options({AddPeer => 1})
            ->hashref_hash('peer_key');
}

##########################################################

=head2 get_can_submit_commands

returns if this user is allowed to submit commands

=cut
sub get_can_submit_commands {
    my $self = shift;
    my $user = shift;
    confess("no user") unless defined $user;
    return $self->{'live'}
            ->table('contacts')
            ->columns(qw/can_submit_commands
                         alias/)
            ->filter({ name => $user })
            ->options({AddPeer => 1})
            ->hashref_array();
}

##########################################################

=head2 get_contactgroups_by_contact

  get_contactgroups_by_contact

returns a list of contactgroups by contact

=cut
sub get_contactgroups_by_contact {
    my($self,$username) = @_;

    my $contactgroups = {};
    my $data = $self->{'live'}
                ->table('contactgroups')
                ->columns(qw/name/)
                ->filter({ members => { '>=' => $username }})
                ->options({AddPeer => 1})
                ->hashref_array();
    for my $group (@{$data}) {
        $contactgroups->{$group->{'name'}} = 1;
    }

    return $contactgroups;
}

##########################################################

=head2 get_table

  get_table

generic function to return a table with options

=cut
sub get_table {
    my $self    = shift;
    my $table   = shift;
    my $options = shift;

    my $class = $self->{'live'}->table($table);
    if(defined $options->{'columns'}) {
        $class = $class->columns(@{$options->{'columns'}});
    }
    if(defined $options->{'filter'}) {
        $class = $class->filter(@{$options->{'filter'}});
    }

    $options->{'options'}->{'AddPeer'} = 1;
    $class = $class->options($options->{'options'});

    if(defined $options->{'sort'}) {
        # TODO
    }

    return $class->hashref_array();
}

##########################################################

=head2 get_hosts

  get_hosts

returns a list of hosts

=cut
sub get_hosts {
    my($self, %options) = @_;
    $options{'columns'} = [qw/
        active_checks_enabled accept_passive_checks acknowledged action_url_expanded
        address alias check_command check_period checks_enabled check_options check_type current_attempt
        current_notification_number event_handler_enabled execution_time
        flap_detection_enabled groups has_been_checked icon_image_alt
        icon_image_expanded is_executing is_flapping last_check
        last_notification last_state_change latency long_plugin_output
        max_check_attempts name next_check notes_expanded notes_url_expanded
        notifications_enabled notification_period obsess_over_host parents percent_state_change
        perf_data plugin_output scheduled_downtime_depth state state_type
        /];
    return $self->get_table('hosts', \%options);
}

##########################################################

=head2 get_servives

  get_services

returns a list of services

=cut
sub get_services {
    my($self, %options) = @_;
    $options{'columns'} = [qw/
        active_checks_enabled accept_passive_checks acknowledged action_url_expanded checks_enabled
        check_options check_type current_attempt current_notification_number
        description event_handler_enabled execution_time flap_detection_enabled
        groups has_been_checked host_address host_alias host_name icon_image_alt
        icon_image_expanded is_executing is_flapping last_check last_notification
        last_state_change latency long_plugin_output max_check_attempts next_check
        notes_expanded notes_url_expanded notifications_enabled obsess_over_service
        percent_state_change perf_data plugin_output scheduled_downtime_depth
        state state_type
        /];
    return $self->get_table('services', \%options);
}

##########################################################

=head2 get_comments

  get_comments

returns a list of comments

=cut
sub get_comments {
    my($self, %options) = @_;
    $options{'columns'} = [qw/
        author comment entry_time entry_type expires
        expire_time host_name id persistent service_description
        source type
        /];
    return $self->get_table('comments', \%options);
}

##########################################################

=head2 get_downtimes

  get_downtimes

returns a list of downtimes

=cut
sub get_downtimes {
    my($self, %options) = @_;
    $options{'columns'} = [qw/
        author comment end_time entry_time fixed host_name
        id start_time service_description triggered_by
        /];
    return $self->get_table('downtimes', \%options);
}

##########################################################

=head2 get_contactgroups

  get_contactgroups

returns a list of contactgroups

=cut
sub get_contactgroups {
    my($self, %options) = @_;
    $options{'columns'} = [qw/
        name alias members
        /];
    return $self->get_table('contactgroups', \%options);
}

##########################################################

=head2 get_timeperiods

  get_timeperiods

returns a list of timeperiods

=cut
sub get_timeperiods {
    my($self, %options) = @_;
    $options{'columns'} = [qw/
        name alias
        /];
    return $self->get_table('timeperiods', \%options);
}

##########################################################

=head2 get_commands

  get_commands

returns a list of commands

=cut
sub get_commands {
    my($self, %options) = @_;
    $options{'columns'} = [qw/
        name line
        /];
    return $self->get_table('commands', \%options);
}

##########################################################

=head2 get_contacts

  get_contacts

returns a list of contacts

=cut
sub get_contacts {
    my($self, %options) = @_;
    $options{'columns'} = [qw/
        name alias email pager service_notification_period host_notification_period
        /];
    return $self->get_table('contacts', \%options);
}

##########################################################

=head2 get_scheduling_queue

  get_scheduling_queue

returns the scheduling queue

=cut
sub get_scheduling_queue {
    my($self, $c, %options) = @_;
    my $services = $self->get_services(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'services'),
                                                 { '-or' => [{ 'active_checks_enabled' => '1' },
                                                            { 'check_options' => { '!=' => '0' }}]
                                                 }
                                                 ]
                                      );
    my $hosts    = $self->get_hosts(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'hosts'),
                                              { '-or' => [{ 'active_checks_enabled' => '1' },
                                                         { 'check_options' => { '!=' => '0' }}]
                                              }
                                              ],
                                    options => { rename => { 'name' => 'host_name' } }
                                    );

    my $queue = [];
    if(defined $services) {
        push @{$queue}, @{$services};
    }
    if(defined $hosts) {
        push @{$queue}, @{$hosts};
    }
    return $queue;
}


=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
