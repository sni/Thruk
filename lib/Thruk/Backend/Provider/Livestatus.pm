package Thruk::Backend::Provider::Livestatus;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Monitoring::Livestatus::Class;
use Thruk::Utils;
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

    # set name of backend
    $config->{'options'}->{'name'} = $config->{'name'};

    die("need at least a peer. Minmal options are <options>peer = /path/to/your/socket</options>") unless defined $config->{'options'}->{'peer'};

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

=head2 peer_name

return the peers name

=cut
sub peer_name {
    my $self = shift;
    return $self->{'live'}->{'backend_obj'}->peer_name();
}

##########################################################

=head2 send_command

send a command

=cut
sub send_command {
    my($self, %options) = @_;
    $self->{'live'}->{'backend_obj'}->do($options{'command'});
    return;
}

##########################################################

=head2 get_processinfo

return the process info

=cut
sub get_processinfo {
    my $self  = shift;
    my $c     = shift;
    my $cache = shift;
    my $data  =  $self->{'live'}
                  ->table('status')
                  ->columns(qw/
                      accept_passive_host_checks accept_passive_service_checks check_external_commands
                      check_host_freshness check_service_freshness enable_event_handlers enable_flap_detection
                      enable_notifications execute_host_checks execute_service_checks last_command_check
                      last_log_rotation livestatus_version nagios_pid obsess_over_hosts obsess_over_services
                      process_performance_data program_start program_version interval_length
                  /)
                  ->options({AddPeer => 1, rename => { 'livestatus_version' => 'data_source_version' }})
                  ->hashref_pk('peer_key');

    # do the livestatus version check
    my $cached_already_warned_about_livestatus_version = $cache->get('already_warned_about_livestatus_version');
    if(!defined $cached_already_warned_about_livestatus_version and defined $c->config->{'min_livestatus_version'}) {
        unless(Thruk::Utils::version_compare($c->config->{'min_livestatus_version'}, $data->{$self->peer_key()}->{'data_source_version'})) {
            $cache->set('already_warned_about_livestatus_version', 1);
            $c->log->warn("backend '".$self->peer_name()."' uses too old livestatus version: '".$data->{$self->peer_key()}->{'data_source_version'}."', minimum requirement is at least '".$c->config->{'min_livestatus_version'}."'. Upgrade if you experience problems.");
        }
    }
    $data->{$self->peer_key()}->{'data_source_version'} = "Livestatus ".$data->{$self->peer_key()}->{'data_source_version'};

    $self->{'last_program_start'} = $data->{$self->peer_key()}->{'program_start'};

    return($data, 'HASH');
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
    confess("no user") unless defined $username;

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

=head2 get_hosts

  get_hosts

returns a list of hosts

=cut
sub get_hosts {
    my($self, %options) = @_;

    # try to reduce the amount of transfered data
    my($size, $limit) = $self->_get_query_size('hosts', \%options, 'name', 'name');
    if(defined $size) {
        # then set the limit for the real query
        $options{'options'}->{'limit'} = $limit;
    }

    $options{'columns'} = [qw/
        accept_passive_checks acknowledged action_url action_url_expanded
        active_checks_enabled address alias check_command check_freshness check_interval
        check_options check_period check_type checks_enabled childs comments current_attempt
        current_notification_number event_handler_enabled execution_time
        first_notification_delay flap_detection_enabled groups has_been_checked
        high_flap_threshold icon_image icon_image_alt icon_image_expanded
        is_executing is_flapping last_check last_notification last_state_change
        latency long_plugin_output low_flap_threshold max_check_attempts name
        next_check notes notes_expanded notes_url notes_url_expanded notification_interval
        notification_period notifications_enabled num_services_crit num_services_ok
        num_services_pending num_services_unknown num_services_warn num_services obsess_over_host
        parents percent_state_change perf_data plugin_output process_performance_data
        retry_interval scheduled_downtime_depth state state_type
                /];
    $options{'options'}->{'callbacks'}->{'last_state_change_plus'} = sub { my $row = shift; return $row->{'last_state_change'} || $self->{'last_program_start'}; };
    my $data = $self->_get_table('hosts', \%options);

    unless(wantarray) {
        confess("get_hosts() should not be called in scalar context");
    }

    return($data, undef, $size);
}

##########################################################

=head2 get_host_names

  get_host_names

returns a list of host names

=cut
sub get_host_names{
    my($self, %options) = @_;
    $options{'columns'} = [qw/name/];
    my $data = $self->_get_hash_table('hosts', 'name', \%options);
    my $keys = defined $data ? [keys %{$data}] : [];

    unless(wantarray) {
        confess("get_host_names () should not be called in scalar context");
    }

    return($keys, 'uniq');
}

##########################################################

=head2 get_hostgroups

  get_hostgroups

returns a list of hostgroups

=cut
sub get_hostgroups {
    my($self, %options) = @_;
    $options{'columns'} = [qw/
        name alias members action_url notes notes_url
        /];
    return $self->_get_table('hostgroups', \%options);
}

##########################################################

=head2 get_hostgroup_names

  get_hostgroup_names

returns a list of hostgroup names

=cut
sub get_hostgroup_names {
    my($self, %options) = @_;
    $options{'columns'} = [qw/name/];
    my $data = $self->_get_hash_table('hostgroups', 'name', \%options);
    my $keys = defined $data ? [keys %{$data}] : [];

    unless(wantarray) {
        confess("get_hostgroup_names() should not be called in scalar context");
    }
    return($keys, 'uniq');
}

##########################################################

=head2 get_services

  get_services

returns a list of services

=cut
sub get_services {
    my($self, %options) = @_;

    # try to reduce the amount of transfered data
    my($size, $limit) = $self->_get_query_size('services', \%options, 'description', 'host_name', 'description');
    if(defined $size) {
        # then set the limit for the real query
        $options{'options'}->{'limit'} = $limit;
    }

    $options{'columns'} = [qw/
        accept_passive_checks acknowledged action_url action_url_expanded
        active_checks_enabled check_command check_interval check_options
        check_period check_type checks_enabled comments current_attempt
        current_notification_number description event_handler event_handler_enabled
        execution_time first_notification_delay flap_detection_enabled groups
        has_been_checked high_flap_threshold host_acknowledged host_action_url_expanded
        host_active_checks_enabled host_address host_alias host_checks_enabled
        host_comments host_groups host_has_been_checked host_icon_image_expanded host_icon_image_alt
        host_is_executing host_is_flapping host_name host_notes_url_expanded
        host_notifications_enabled host_scheduled_downtime_depth host_state
        icon_image icon_image_alt icon_image_expanded is_executing is_flapping
        last_check last_notification last_state_change latency long_plugin_output
        low_flap_threshold max_check_attempts next_check notes notes_expanded
        notes_url notes_url_expanded notification_interval notification_period
        notifications_enabled obsess_over_service percent_state_change perf_data
        plugin_output process_performance_data retry_interval scheduled_downtime_depth
        state state_type
        /];

    $options{'options'}->{'callbacks'}->{'last_state_change_plus'} = sub { my $row = shift; return $row->{'last_state_change'} || $self->{'last_program_start'}; };
    my $data = $self->_get_table('services', \%options);
    unless(wantarray) {
        confess("get_services() should not be called in scalar context");
    }
    return($data, undef, $size);
}

##########################################################

=head2 get_service_names

  get_service_names

returns a list of service names

=cut
sub get_service_names {
    my($self, %options) = @_;
    $options{'columns'} = [qw/description/];
    my $data = $self->_get_hash_table('services', 'description', \%options);
    my $keys = defined $data ? [keys %{$data}] : [];
    unless(wantarray) {
        confess("get_service_names() should not be called in scalar context");
    }
    return($keys, 'uniq');
}

##########################################################

=head2 get_servicegroups

  get_servicegroups

returns a list of servicegroups

=cut
sub get_servicegroups {
    my($self, %options) = @_;
    $options{'columns'} = [qw/
        name alias members action_url notes notes_url
        /];
    return $self->_get_table('servicegroups', \%options);
}

##########################################################

=head2 get_servicegroup_names

  get_servicegroup_names

returns a list of servicegroup names

=cut
sub get_servicegroup_names {
    my($self, %options) = @_;
    $options{'columns'} = [qw/name/];
    my $data = $self->_get_hash_table('servicegroups', 'name', \%options);
    my $keys = defined $data ? [keys %{$data}] : [];
    unless(wantarray) {
        confess("get_servicegroup_names() should not be called in scalar context");
    }
    return($keys, 'uniq');
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
    return $self->_get_table('comments', \%options);
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
    my $data = $self->_get_table('downtimes', \%options);

    return $data;
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
    return $self->_get_table('contactgroups', \%options);
}

##########################################################

=head2 get_logs

  get_logs

returns logfile entries

=cut
sub get_logs {
    my($self, %options) = @_;
    $options{'columns'} = [qw/
        class time type state host_name service_description plugin_output message contact_name command_name state_type
        /];
    return $self->_get_table('log', \%options);
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

    # fill in values not provided by livestatus
    $options{'options'}->{'callbacks'}->{'exclusion'} = sub { return ""; };
    $options{'options'}->{'callbacks'}->{'sunday'}    = sub { return ""; };
    $options{'options'}->{'callbacks'}->{'monday'}    = sub { return ""; };
    $options{'options'}->{'callbacks'}->{'tuesday'}   = sub { return ""; };
    $options{'options'}->{'callbacks'}->{'wednesday'} = sub { return ""; };
    $options{'options'}->{'callbacks'}->{'thursday'}  = sub { return ""; };
    $options{'options'}->{'callbacks'}->{'friday'}    = sub { return ""; };
    $options{'options'}->{'callbacks'}->{'saturday'}  = sub { return ""; };

    return $self->_get_table('timeperiods', \%options);
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
    return $self->_get_table('commands', \%options);
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
    return $self->_get_table('contacts', \%options);
}

##########################################################

=head2 get_scheduling_queue

  get_scheduling_queue

returns the scheduling queue

=cut
sub get_scheduling_queue {
    my($self, %options) = @_;
    my($services) = $self->get_services(filter => [Thruk::Utils::Auth::get_auth_filter($options{'c'}, 'services'),
                                                 { '-or' => [{ 'active_checks_enabled' => '1' },
                                                            { 'check_options' => { '!=' => '0' }}]
                                                 }
                                                 ]
                                      );
    my($hosts)    = $self->get_hosts(filter => [Thruk::Utils::Auth::get_auth_filter($options{'c'}, 'hosts'),
                                              { '-or' => [{ 'active_checks_enabled' => '1' },
                                                         { 'check_options' => { '!=' => '0' }}]
                                              }
                                              ],
                                    options => { rename => { 'name' => 'host_name' }, callbacks => { 'description' => sub { return ""; } } }
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

##########################################################

=head2 get_host_stats

  get_host_stats

returns the host statistics for the tac page

=cut
sub get_host_stats {
    my($self, %options) = @_;

    my $stats = [
        'total'                     => { -stats => [ 'name' => { '!=' => '' } ]},
        'total_active'              => { -stats => [ 'check_type' => 0 ]},
        'total_passive'             => { -stats => [ 'check_type' => 1 ]},
        'pending'                   => { -stats => [ 'has_been_checked' => 0 ]},
        'pending_and_disabled'      => { -stats => [ 'has_been_checked' => 0, 'active_checks_enabled' => 0 ]},
        'pending_and_scheduled'     => { -stats => [ 'has_been_checked' => 0, 'scheduled_downtime_depth' => { '>' => 0 } ]},
        'up'                        => { -stats => [ 'has_been_checked' => 1, 'state' => 0 ]},
        'up_and_disabled'           => { -stats => [ 'has_been_checked' => 1, 'state' => 0, 'active_checks_enabled' => 0 ]},
        'up_and_scheduled'          => { -stats => [ 'has_been_checked' => 1, 'state' => 0, 'scheduled_downtime_depth' => { '>' => 0 } ]},
        'down'                      => { -stats => [ 'has_been_checked' => 1, 'state' => 1 ]},
        'down_and_ack'              => { -stats => [ 'has_been_checked' => 1, 'state' => 1, 'acknowledged' => 1 ]},
        'down_and_scheduled'        => { -stats => [ 'has_been_checked' => 1, 'state' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]},
        'down_and_disabled'         => { -stats => [ 'has_been_checked' => 1, 'state' => 1, 'active_checks_enabled' => 0 ]},
        'down_and_unhandled'        => { -stats => [ 'has_been_checked' => 1, 'state' => 1, 'active_checks_enabled' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0 ]},
        'unreachable'               => { -stats => [ 'has_been_checked' => 1, 'state' => 2 ]},
        'unreachable_and_ack'       => { -stats => [ 'has_been_checked' => 1, 'state' => 2, 'acknowledged' => 1 ]},
        'unreachable_and_scheduled' => { -stats => [ 'has_been_checked' => 1, 'state' => 2, 'scheduled_downtime_depth' => { '>' => 0 } ]},
        'unreachable_and_disabled'  => { -stats => [ 'has_been_checked' => 1, 'state' => 2, 'active_checks_enabled' => 0 ]},
        'unreachable_and_unhandled' => { -stats => [ 'has_been_checked' => 1, 'state' => 2, 'active_checks_enabled' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0 ]},
        'flapping'                  => { -stats => [ 'is_flapping' => 1 ]},
        'flapping_disabled'         => { -stats => [ 'flap_detection_enabled' => 0 ]},
        'notifications_disabled'    => { -stats => [ 'notifications_enabled' => 0 ]},
        'eventhandler_disabled'     => { -stats => [ 'event_handler_enabled' => 0 ]},
        'active_checks_disabled'    => { -stats => [ 'active_checks_enabled' => 0 ]},
        'passive_checks_disabled'   => { -stats => [ 'accept_passive_checks' => 0 ]},
        'outages'                   => { -stats => [ 'state' => 1, 'childs' => {'!=' => undef } ]},
    ];
    my $class = $self->_get_class('hosts', \%options);

    my $rows = $class->stats($stats)->hashref_array();

    unless(wantarray) {
        confess("get_host_stats() should not be called in scalar context");
    }
    return(\%{$rows->[0]}, 'SUM');
}

##########################################################

=head2 get_service_stats

  get_service_stats

returns the services statistics for the tac page

=cut
sub get_service_stats {
    my($self, %options) = @_;

    my $stats = [
        'total'                     => { -stats => [ 'description' => { '!=' => '' } ]},
        'total_active'              => { -stats => [ 'check_type' => 0 ]},
        'total_passive'             => { -stats => [ 'check_type' => 1 ]},
        'pending'                   => { -stats => [ 'has_been_checked' => 0 ]},
        'pending_and_disabled'      => { -stats => [ 'has_been_checked' => 0, 'active_checks_enabled' => 0 ]},
        'pending_and_scheduled'     => { -stats => [ 'has_been_checked' => 0, 'scheduled_downtime_depth' => { '>' => 0 } ]},
        'ok'                        => { -stats => [ 'has_been_checked' => 1, 'state' => 0 ]},
        'ok_and_disabled'           => { -stats => [ 'has_been_checked' => 1, 'state' => 0, 'active_checks_enabled' => 0 ]},
        'ok_and_scheduled'          => { -stats => [ 'has_been_checked' => 1, 'state' => 0, 'scheduled_downtime_depth' => { '>' => 0 } ]},
        'warning'                   => { -stats => [ 'has_been_checked' => 1, 'state' => 1 ]},
        'warning_and_disabled'      => { -stats => [ 'has_been_checked' => 1, 'state' => 1, 'active_checks_enabled' => 0 ]},
        'warning_and_scheduled'     => { -stats => [ 'has_been_checked' => 1, 'state' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]},
        'warning_and_ack'           => { -stats => [ 'has_been_checked' => 1, 'state' => 1, 'acknowledged' => 1 ]},
        'warning_on_down_host'      => { -stats => [ 'has_been_checked' => 1, 'state' => 1, 'host_state' => { '!=' => 0 } ]},
        'warning_and_unhandled'     => { -stats => [ 'has_been_checked' => 1, 'state' => 1, 'host_state' => 0, 'active_checks_enabled' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0 ]},
        'critical'                  => { -stats => [ 'has_been_checked' => 1, 'state' => 2 ]},
        'critical_and_disabled'     => { -stats => [ 'has_been_checked' => 1, 'state' => 2, 'active_checks_enabled' => 0 ]},
        'critical_and_scheduled'    => { -stats => [ 'has_been_checked' => 1, 'state' => 2, 'scheduled_downtime_depth' => { '>' => 0 } ]},
        'critical_and_ack'          => { -stats => [ 'has_been_checked' => 1, 'state' => 2, 'acknowledged' => 1 ]},
        'critical_on_down_host'     => { -stats => [ 'has_been_checked' => 1, 'state' => 2, 'host_state' => { '!=' => 0 } ]},
        'critical_and_unhandled'    => { -stats => [ 'has_been_checked' => 1, 'state' => 2, 'host_state' => 0, 'active_checks_enabled' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0 ]},
        'unknown'                   => { -stats => [ 'has_been_checked' => 1, 'state' => 3 ]},
        'unknown_and_disabled'      => { -stats => [ 'has_been_checked' => 1, 'state' => 3, 'active_checks_enabled' => 0 ]},
        'unknown_and_scheduled'     => { -stats => [ 'has_been_checked' => 1, 'state' => 3, 'scheduled_downtime_depth' => { '>' => 0 } ]},
        'unknown_and_ack'           => { -stats => [ 'has_been_checked' => 1, 'state' => 3, 'acknowledged' => 1 ]},
        'unknown_on_down_host'      => { -stats => [ 'has_been_checked' => 1, 'state' => 3, 'host_state' => { '!=' => 0 } ]},
        'unknown_and_unhandled'     => { -stats => [ 'has_been_checked' => 1, 'state' => 3, 'host_state' => 0, 'active_checks_enabled' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0 ]},
        'flapping'                  => { -stats => [ 'is_flapping' => 1 ]},
        'flapping_disabled'         => { -stats => [ 'flap_detection_enabled' => 0 ]},
        'notifications_disabled'    => { -stats => [ 'notifications_enabled' => 0 ]},
        'eventhandler_disabled'     => { -stats => [ 'event_handler_enabled' => 0 ]},
        'active_checks_disabled'    => { -stats => [ 'active_checks_enabled' => 0 ]},
        'passive_checks_disabled'   => { -stats => [ 'accept_passive_checks' => 0 ]},
    ];
    my $class = $self->_get_class('services', \%options);
    my $rows = $class->stats($stats)->hashref_array();

    unless(wantarray) {
        confess("get_service_stats() should not be called in scalar context");
    }
    return(\%{$rows->[0]}, 'SUM');
}

##########################################################

=head2 get_performance_stats

  get_performance_stats

returns the service /host execution statistics

=cut
sub get_performance_stats {
    my($self, %options) = @_;

    my $now    = time();
    my $min1   = $now - 60;
    my $min5   = $now - 300;
    my $min15  = $now - 900;
    my $min60  = $now - 3600;
    my $minall = $self->{'last_program_start'};

    my $data = {};
    for my $type (qw{hosts services}) {
        my $stats = [
            $type.'_active_sum'      => { -stats => [ 'check_type' => 0 ]},
            $type.'_active_1_sum'    => { -stats => [ 'check_type' => 0, 'has_been_checked' => 1, 'last_check' => { '>=' => $min1 } ]},
            $type.'_active_5_sum'    => { -stats => [ 'check_type' => 0, 'has_been_checked' => 1, 'last_check' => { '>=' => $min5 } ]},
            $type.'_active_15_sum'   => { -stats => [ 'check_type' => 0, 'has_been_checked' => 1, 'last_check' => { '>=' => $min15 }]},
            $type.'_active_60_sum'   => { -stats => [ 'check_type' => 0, 'has_been_checked' => 1, 'last_check' => { '>=' => $min60 }]},
            $type.'_active_all_sum'  => { -stats => [ 'check_type' => 0, 'has_been_checked' => 1, 'last_check' => { '>=' => $minall }]},

            $type.'_passive_sum'     => { -stats => [ 'check_type' => 1 ]},
            $type.'_passive_1_sum'   => { -stats => [ 'check_type' => 1, 'has_been_checked' => 1, 'last_check' => { '>=' => $min1 } ]},
            $type.'_passive_5_sum'   => { -stats => [ 'check_type' => 1, 'has_been_checked' => 1, 'last_check' => { '>=' => $min5 } ]},
            $type.'_passive_15_sum'  => { -stats => [ 'check_type' => 1, 'has_been_checked' => 1, 'last_check' => { '>=' => $min15 }]},
            $type.'_passive_60_sum'  => { -stats => [ 'check_type' => 1, 'has_been_checked' => 1, 'last_check' => { '>=' => $min60 }]},
            $type.'_passive_all_sum' => { -stats => [ 'check_type' => 1, 'has_been_checked' => 1, 'last_check' => { '>=' => $minall }]},
        ];
        my $class = $self->_get_class($type, \%options);
        my $rows = $class->stats($stats)->hashref_array();
        $data = { %{$data}, %{$rows->[0]} };

        # add stats for active checks
        $stats = [
            $type.'_execution_time_sum'      => { -stats => [ 'sum execution_time' ]},
            $type.'_latency_sum'             => { -stats => [ 'sum latency' ]},
            $type.'_active_state_change_sum' => { -stats => [ 'sum percent_state_change' ]},
            $type.'_execution_time_min'      => { -stats => [ 'min execution_time' ]},
            $type.'_latency_min'             => { -stats => [ 'min latency' ]},
            $type.'_active_state_change_min' => { -stats => [ 'min percent_state_change' ]},
            $type.'_execution_time_max'      => { -stats => [ 'max execution_time' ]},
            $type.'_latency_max'             => { -stats => [ 'max latency' ]},
            $type.'_active_state_change_max' => { -stats => [ 'max percent_state_change' ]},
        ];
        $class = $self->_get_class($type, \%options);
        $rows = $class
                    ->filter([ has_been_checked => 1, check_type => 0 ])
                    ->stats($stats)->hashref_array();
        $data = { %{$data}, %{$rows->[0]} };

        # add stats for passive checks
        $stats = [
            $type.'_passive_state_change_sum' => { -stats => [ 'sum percent_state_change' ]},
            $type.'_passive_state_change_min' => { -stats => [ 'min percent_state_change' ]},
            $type.'_passive_state_change_max' => { -stats => [ 'max percent_state_change' ]},
        ];
        $class = $self->_get_class($type, \%options);
        $rows = $class
                    ->filter([ has_been_checked => 1, check_type => 1 ])
                    ->stats($stats)->hashref_array();
        $data = { %{$data}, %{$rows->[0]} };
    }

    unless(wantarray) {
        confess("get_performance_stats() should not be called in scalar context");
    }
    return($data, 'STATS');
}

##########################################################

=head2 get_extra_perf_stats

  get_extra_perf_stats

returns the service /host execution statistics

=cut
sub get_extra_perf_stats {
    my($self, %options) = @_;

    my $class = $self->_get_class('status', \%options);
    my $data  =  $class
                  ->columns(qw/
                        cached_log_messages connections connections_rate host_checks
                        host_checks_rate requests requests_rate service_checks
                        service_checks_rate neb_callbacks neb_callbacks_rate
                  /)
                  ->hashref_array();

    if(defined $data) {
        $data = shift @{$data};
    }

    unless(wantarray) {
        confess("get_extra_perf_stats() should not be called in scalar context");
    }
    return($data, 'SUM');
}


##########################################################

=head2 _get_class

  _get_class

generic function to return a table class

=cut
sub _get_class {
    my $self      = shift;
    my $table     = shift;
    my $options   = shift;

    my $class = $self->{'live'}->table($table);
    if(defined $options->{'columns'}) {
        if(ref $options->{'columns'} ne 'ARRAY') {
            confess("not a arrayref: ".Dumper($options->{'confess'}));
        }
        $class = $class->columns(@{$options->{'columns'}});
    }
    if(defined $options->{'filter'}) {
        if(ref $options->{'filter'} ne 'ARRAY') {
            confess("not a arrayref: ".Dumper($options->{'filter'}));
        }
        if(scalar @{$options->{'filter'}} > 0) {
            $class = $class->filter([@{$options->{'filter'}}]);
        }
    }

    $options->{'options'}->{'AddPeer'} = 1;
    $class = $class->options($options->{'options'});

    return $class;
}

##########################################################

=head2 _get_table

  _get_table

generic function to return a table with options

=cut
sub _get_table {
    my $self      = shift;
    my $table     = shift;
    my $options   = shift;

    my $class = $self->_get_class($table, $options);
    my $data  = $class->hashref_array() || [];
    return $data;
}

##########################################################

=head2 _get_hash_table

  _get_hash_table

generic function to return a hash table with options

=cut
sub _get_hash_table {
    my $self      = shift;
    my $table     = shift;
    my $key       = shift;
    my $options   = shift;

    my $class = $self->_get_class($table, $options);
    my $data  = $class->hashref_pk() || {};
    return $data;
}


##########################################################

=head2 _get_query_size

  _get_query_size

returns the size of a query, used to reduce the amount of transfered data

=cut
sub _get_query_size {
    my $self    = shift;
    my $table   = shift;
    my $options = shift;
    my $key     = shift;
    my $sortby1 = shift;
    my $sortby2 = shift;

    # only if paging is enabled
    return unless defined $options->{'pager'};
    return unless defined $options->{'sort'};
    return unless ref $options->{'sort'} eq 'HASH';
    return unless defined $options->{'sort'}->{'ASC'};
    if(ref $options->{'sort'}->{'ASC'} eq 'ARRAY') {
        return if defined $sortby1 and $options->{'sort'}->{'ASC'}->[0] ne $sortby1;
        return if defined $sortby2 and $options->{'sort'}->{'ASC'}->[1] ne $sortby2;
    } else {
        return if defined $sortby1 and $options->{'sort'}->{'ASC'} ne $sortby1;
    }

    my $c = $options->{'pager'};
    my $entries = $c->{'request'}->{'parameters'}->{'entries'} || $c->stash->{'default_page_size'};
    return if $entries !~ m/^\d+$/mx;

    my $page = $c->{'request'}->{'parameters'}->{'page'} || 1;
    $entries = $entries * $page;

    my $stats = [
        'total' => { -stats => [ $key => { '!=' => undef } ]},
    ];
    my $class = $self->_get_class($table, $options);
    my $rows = $class->stats($stats)->hashref_array();
    my $size = $rows->[0]->{'total'};

    unless(wantarray) {
        confess("_get_query_size() should not be called in scalar context");
    }
    return($size, $entries);
}

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
