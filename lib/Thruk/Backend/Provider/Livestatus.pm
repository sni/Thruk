package Thruk::Backend::Provider::Livestatus;

use warnings;
use strict;
use Carp qw/confess/;
use Data::Dumper qw/Dumper/;
use POSIX ();

use Monitoring::Livestatus::Class::Lite ();
use Thruk::Timer qw/timing_breakpoint/;
use Thruk::Utils::IO ();

use base 'Thruk::Backend::Provider::Base';

# contains most stats column definitions
$Thruk::Backend::Provider::Livestatus::stats_columns = {};


=head1 NAME

Thruk::Backend::Provider::Livestatus - connection provider for livestatus connections

=head1 DESCRIPTION

connection provider for livestatus connections

=head1 METHODS

=cut

##########################################################
$Thruk::Backend::Provider::Livestatus::callbacks = {
                            'empty_callback' => sub { return '' },
};

$Thruk::Backend::Provider::Livestatus::default_host_columns = [qw/
    accept_passive_checks acknowledged action_url action_url_expanded
    active_checks_enabled address alias check_command check_freshness check_interval
    check_options check_period check_type checks_enabled childs comments current_attempt
    current_notification_number event_handler event_handler_enabled execution_time
    custom_variable_names custom_variable_values
    first_notification_delay flap_detection_enabled groups has_been_checked
    high_flap_threshold icon_image icon_image_alt icon_image_expanded
    is_executing is_flapping last_check last_notification last_state_change
    latency low_flap_threshold max_check_attempts name
    next_check notes notes_expanded notes_url notes_url_expanded notification_interval
    notification_period notifications_enabled num_services_crit num_services_ok
    num_services_pending num_services_unknown num_services_warn num_services obsess_over_host
    parents percent_state_change perf_data plugin_output process_performance_data
    retry_interval scheduled_downtime_depth state state_type modified_attributes_list
    last_time_down last_time_unreachable last_time_up display_name
    in_check_period in_notification_period
/];
$Thruk::Backend::Provider::Livestatus::extra_host_columns = [qw/
    contacts contact_groups long_plugin_output services comments_with_info downtimes_with_info last_update
/];
$Thruk::Backend::Provider::Livestatus::extra_hostgroup_columns = [qw/
    num_hosts
    num_hosts_down num_hosts_pending num_hosts_unreach num_hosts_up
    num_services
    num_services_hard_crit num_services_hard_ok num_services_hard_unknown num_services_hard_warn
    num_services_crit num_services_ok num_services_pending num_services_unknown num_services_warn
    worst_host_state worst_service_hard_state worst_service_state

/];

$Thruk::Backend::Provider::Livestatus::default_service_columns = [qw/
    accept_passive_checks acknowledged action_url action_url_expanded
    active_checks_enabled check_command check_interval check_options
    check_period check_type checks_enabled comments current_attempt
    current_notification_number description event_handler event_handler_enabled
    custom_variable_names custom_variable_values
    execution_time first_notification_delay flap_detection_enabled groups
    has_been_checked high_flap_threshold host_acknowledged host_action_url_expanded
    host_active_checks_enabled host_address host_alias host_checks_enabled host_check_type
    host_latency host_plugin_output host_perf_data host_current_attempt host_check_command
    host_comments host_groups host_has_been_checked host_icon_image_expanded host_icon_image_alt
    host_is_executing host_is_flapping host_notes host_name host_notes_url_expanded
    host_notifications_enabled host_scheduled_downtime_depth host_state host_accept_passive_checks
    host_last_state_change
    icon_image icon_image_alt icon_image_expanded is_executing is_flapping
    last_check last_notification last_state_change latency
    low_flap_threshold max_check_attempts next_check notes notes_expanded
    notes_url notes_url_expanded notification_interval notification_period
    notifications_enabled obsess_over_service percent_state_change perf_data
    plugin_output process_performance_data retry_interval scheduled_downtime_depth
    state state_type modified_attributes_list
    last_time_critical last_time_ok last_time_unknown last_time_warning
    display_name host_display_name host_custom_variable_names host_custom_variable_values
    in_check_period in_notification_period host_parents
/];
$Thruk::Backend::Provider::Livestatus::extra_service_columns = [qw/
    contacts contact_groups long_plugin_output comments_with_info downtimes_with_info host_contacts host_contact_groups last_update
/];
$Thruk::Backend::Provider::Livestatus::extra_servicegroup_columns = [qw/
    num_services
    num_services_hard_crit num_services_hard_ok num_services_hard_unknown num_services_hard_warn
    num_services_crit num_services_ok num_services_pending num_services_unknown num_services_warn worst_service_state
/];

$Thruk::Backend::Provider::Livestatus::default_contact_columns = [qw/
    name alias email pager service_notification_period host_notification_period
/];
$Thruk::Backend::Provider::Livestatus::extra_contact_columns = [qw/
    id can_submit_commands groups modified_attributes_list
    custom_variable_names custom_variable_values
    host_notifications_enabled service_notifications_enabled
    host_notification_commands service_notification_commands
    in_host_notification_period in_service_notification_period
    address1 address2 address3 address4 address5 last_update
/];

$Thruk::Backend::Provider::Livestatus::default_logs_columns = [qw/
    class time type state host_name service_description plugin_output message options state_type contact_name
/];

$Thruk::Backend::Provider::Livestatus::default_comments_columns = [qw/
    author comment entry_time entry_type expires
    expire_time host_name id persistent service_description
    source type
/];
$Thruk::Backend::Provider::Livestatus::extra_comments_columns = [
    @{_add_service_prefix([@{$Thruk::Backend::Provider::Livestatus::default_service_columns}, @{$Thruk::Backend::Provider::Livestatus::extra_service_columns}])},
];

$Thruk::Backend::Provider::Livestatus::default_downtimes_columns = [qw/
    author comment end_time entry_time fixed host_name
    id start_time service_description triggered_by duration
/];
$Thruk::Backend::Provider::Livestatus::extra_downtimes_columns = [
    @{_add_service_prefix([@{$Thruk::Backend::Provider::Livestatus::default_service_columns}, @{$Thruk::Backend::Provider::Livestatus::extra_service_columns}])},
];

##########################################################

=head2 new

create new manager

=cut
sub new {
    my($class, $peer_config, $thruk_config) = @_;

    my $options = {};
    # clone options, otherwise $peer_config->options would end up being a Lite class and cannot be reused
    for my $key (keys %{$peer_config->{'options'}}) {
        $options->{$key} = $peer_config->{'options'}->{$key};
    }
    confess("need at least one peer. Minimal options are <options>peer = /path/to/your/socket</options>\ngot: ".Dumper($peer_config)) unless defined $options->{'peer'};

    my $self = {
        'live'                 => Monitoring::Livestatus::Class::Lite->new($options),
        'naemon_optimizations' => 0,
        'lmd_optimizations'    => 0,
        'fetch_command'        => $peer_config->{'logcache_fetchlogs_command'} || $thruk_config->{'logcache_fetchlogs_command'},
    };
    bless $self, $class;

    return $self;
}

##########################################################

=head2 reconnect

recreate database connection

=cut
sub reconnect {
    my($self) = @_;
    if(defined $self->{'_peer'}->{'logcache'}) {
        $self->{'_peer'}->logcache->reconnect();
    }
    return;
}

##########################################################

=head2 peer_key

return the peers key

=cut
sub peer_key {
    my($self, $new_val) = @_;
    if(defined $new_val) {
        $self->{'live'}->{'backend_obj'}->{'key'} = $new_val;
    }
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

=head2 _raw_query

send a raw query to the backend

=cut
sub _raw_query {
    my($self, $query) = @_;

    # closing a socket sends SIGPIPE to reader
    # https://riptutorial.com/posix/example/17424/handle-sigpipe-generated-by-write---in-a-thread-safe-manner
    local $SIG{PIPE} = 'IGNORE';

    my($socket, $msg, undef) = $self->{'live'}->{'backend_obj'}->_send_socket_do($query);
    die($msg) if $msg;
    shutdown($socket, 1) if $query =~ m/^COMMAND/mx;
    local $/ = undef;
    my $res = <$socket>;
    $self->{'live'}->{'backend_obj'}->_close();
    return($res);
}

##########################################################

=head2 send_command

send a command

=cut
sub send_command {
    my($self, %options) = @_;
    cluck("empty command") if (!defined $options{'command'} || $options{'command'} eq '');
    if($options{'backend'} && $self->{'lmd_optimizations'}) {
        my $backend_header = 'Backends: '.join(" ", @{$options{'backend'}});
        my $new_commands = [];
        for my $cmd (split/\n+/mx, $options{'command'}) {
            push @{$new_commands}, $cmd."\n".$backend_header;
        }
        $options{'command'} = join("\n\n", @{$new_commands});
    }
    $self->{'live'}->{'backend_obj'}->do($options{'command'}, \%options);
    return;
}

##########################################################

=head2 get_processinfo

return the process info

=cut
sub get_processinfo {
    my($self, %options) = @_;
    my $key = $self->peer_key();
    my $data;
    if(defined $options{'data'}) {
        $data = { $key => $options{'data'}->[0] };
    } else {
        unless(defined $options{'columns'}) {
            $options{'columns'} = [qw/
                          accept_passive_host_checks accept_passive_service_checks check_external_commands
                          check_host_freshness check_service_freshness enable_event_handlers enable_flap_detection
                          enable_notifications execute_host_checks execute_service_checks last_command_check
                          last_log_rotation livestatus_version nagios_pid obsess_over_hosts obsess_over_services
                          process_performance_data program_start program_version interval_length
            /];
            if(defined $options{'extra_columns'}) {
                push @{$options{'columns'}}, @{$options{'extra_columns'}};
            }
            if($ENV{'THRUK_USE_LMD'}) {
                push @{$options{'columns'}}, 'thruk';
                push @{$options{'columns'}}, 'configtool';
                push @{$options{'columns'}}, 'peer_name';
                push @{$options{'columns'}}, 'peer_addr';
                push @{$options{'columns'}}, 'lmd_last_cache_update';
            }
        }
        $options{'columns'} = $self->_clean_columns("processinfo", $options{'columns'});

        $options{'options'}->{AddPeer} = 1 unless defined $options{'options'}->{AddPeer};
        $options{'options'}->{rename}  = { 'livestatus_version' => 'data_source_version' };
        $options{'options'}->{wrapped_json} = $self->{'lmd_optimizations'};

        $data = $self->_optimize(
                $self->{'live'}
                     ->table('status')
                     ->columns(@{$options{'columns'}})
                     ->options($options{'options'}))
                     ->hashref_pk('peer_key');
        return $data if $self->{'lmd_optimizations'};
    }

    $data->{$key}->{'data_source_version'} = "Livestatus ".($data->{$key}->{'data_source_version'} || 'unknown');
    $self->{'naemon_optimizations'} = $data->{$key}->{'data_source_version'} =~ m/([\d\.]+).*?\-naemon$/mx ? _normalize_version_number($1) : 0;

    # naemon checks external commands on arrival
    if(defined $data->{$key}->{'program_start'} && $data->{$key}->{'last_command_check'} == $data->{$key}->{'program_start'}) {
        $data->{$key}->{'last_command_check'} = time();
    }
    return($data, 'HASH');
}

##########################################################

=head2 get_sites

return the sites list from lmd

=cut
sub get_sites {
    my($self, %options) = @_;
    return($options{'data'}) if($options{'data'});
    unless(defined $options{'columns'}) {
        $options{'columns'} = [qw/
            peer_key peer_name key name addr status bytes_send bytes_received queries
            last_error last_update last_online response_time idling last_query
            parent section lmd_last_cache_update
            federation_key federation_name federation_addr federation_type
        /];
        if(defined $options{'extra_columns'}) {
            push @{$options{'columns'}}, @{$options{'extra_columns'}};
        }
    }
    return $self->_get_table('sites', \%options);
}

##########################################################

=head2 get_can_submit_commands

returns if this user is allowed to submit commands

=cut
sub get_can_submit_commands {
    my($self, $user, $data) = @_;
    confess("no user") unless defined $user;
    return $data if $data;
    $data = $self->_optimize(
            $self->{'live'}
                    ->table('contacts')
                    ->columns(qw/can_submit_commands
                                 alias email/)
                    ->filter({ name => $user })
                    ->options({AddPeer => 1}))
                    ->hashref_array();
    return($data);
}

##########################################################

=head2 get_contactgroups_by_contact

  get_contactgroups_by_contact

returns a list of contactgroups by contact

$VAR1 = [
          {
            'peer_addr' => '/omd/sites/devel/tmp/run/live',
            'name' => 'omd',
            'peer_key' => '78bcd',
            'peer_name' => 'devel'
          },
          ...
        ];

=cut
sub get_contactgroups_by_contact {
    my($self,$username, $data) = @_;
    confess("no user") unless defined $username;
    return $data if $data;

    $data = $self->_optimize(
            $self->{'live'}
                    ->table('contactgroups')
                    ->columns(qw/name/)
                    ->filter({ members => { '>=' => $username }})
                    ->options({AddPeer => 1}))
                    ->hashref_array();

    return $data;
}

##########################################################

=head2 get_hosts

  get_hosts

returns a list of hosts

=cut
sub get_hosts {
    my($self, %options) = @_;
    return($options{'data'}) if($options{'data'});

    if($options{'options'}->{'callbacks'}) {
        %options = %{Thruk::Utils::IO::dclone(\%options)};
        $self->_replace_callbacks($options{'options'}->{'callbacks'});
    }

    # optimized naemon with wrapped_json output
    if($self->{'lmd_optimizations'} || $self->{'naemon_optimizations'}) {
        $self->_optimized_for_wrapped_json(\%options, "hosts");
        &timing_breakpoint('optimized get_hosts') if $self->{'optimized'};
    }

    # try to reduce the amount of transfered data
    my($size, $limit);
    if(!$self->{'optimized'} && defined $options{'pager'} && !defined $options{'options'}->{'limit'}) {
        ($size, $limit) = $self->_get_query_size('hosts', \%options, 'name', 'name');
        if(defined $size) {
            # then set the limit for the real query
            $options{'options'}->{'limit'} = $limit;
        }
    }

    unless(defined $options{'columns'}) {
        $options{'columns'} = [@{$Thruk::Backend::Provider::Livestatus::default_host_columns}];
        if($options{'enable_shinken_features'}) {
            push @{$options{'columns'}},  qw/is_impact source_problems impacts criticity is_problem realm poller_tag
                                             got_business_rule parent_dependencies/;
        }
        if(defined $options{'extra_columns'}) {
            push @{$options{'columns'}}, @{$options{'extra_columns'}};
        }
        if($self->{'lmd_optimizations'}) {
            push @{$options{'columns'}}, 'last_state_change_order';
            push @{$options{'columns'}}, 'lmd_last_cache_update';
        } else {
            my $last_program_start = $options{'last_program_starts'}->{$self->peer_key()} || 0;
            $options{'options'}->{'callbacks'}->{'last_state_change_order'} = sub { return $_[0]->{'last_state_change'} || $last_program_start; };
        }
        # only available since > 1.0.9
        if($self->{'lmd_optimizations'} || $self->{'naemon_optimizations'} > 1000009) {
            push @{$options{'columns'}},  qw/depends_exec depends_notify/;
        }
    }
    $options{'columns'} = $self->_clean_columns("hosts", $options{'columns'});

    # get result
    my $data = $self->_get_table('hosts', \%options);

    # set total size
    if(!$size && $self->{'optimized'}) {
        $size = $self->{'live'}->{'backend_obj'}->{'meta_data'}->{'total_count'};
    }

    unless(wantarray) {
        confess("get_hosts() should not be called in scalar context");
    }
    return($data, undef, $size);
}

##########################################################

=head2 get_hosts_by_servicequery

  get_hosts_by_servicequery

returns a list of host by a services query

=cut
sub get_hosts_by_servicequery {
    my($self, %options) = @_;
    return($options{'data'}) if($options{'data'});

    unless(defined $options{'columns'}) {
        $options{'columns'} = [qw/
            host_has_been_checked host_name host_state host_scheduled_downtime_depth host_acknowledged
            has_been_checked state scheduled_downtime_depth acknowledged
        /];
        if(defined $options{'extra_columns'}) {
            push @{$options{'columns'}}, @{$options{'extra_columns'}};
        }
    }
    $options{'columns'} = $self->_clean_columns("services", $options{'columns'});

    my $data = $self->_get_table('services', \%options);
    unless(wantarray) {
        confess("get_hosts_by_servicequery() should not be called in scalar context");
    }
    return($data, undef);
}

##########################################################

=head2 get_host_names

  get_host_names

returns a list of host names

=cut
sub get_host_names{
    my($self, %options) = @_;
    if($options{'data'}) {
        my %indexed;
        for my $row (@{$options{'data'}}) { $indexed{$row->{'name'}} = 1; }
        my @keys = keys %indexed;
        return(\@keys, 'uniq');
    }
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
    return($options{'data'}) if($options{'data'});
    unless(defined $options{'columns'}) {
        $options{'columns'} = [qw/
            name alias members action_url notes notes_url
        /];
        if(defined $options{'extra_columns'}) {
            push @{$options{'columns'}}, @{$options{'extra_columns'}};
        }
    }
    $options{'columns'} = $self->_clean_columns("hostgroups", $options{'columns'});
    return $self->_get_table('hostgroups', \%options);
}

##########################################################

=head2 get_hostgroup_names

  get_hostgroup_names

returns a list of hostgroup names

=cut
sub get_hostgroup_names {
    my($self, %options) = @_;
    if($options{'data'}) {
        my %indexed;
        for my $row (@{$options{'data'}}) { $indexed{$row->{'name'}} = 1; }
        my @keys = keys %indexed;
        return(\@keys, 'uniq');
    }
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
    return($options{'data'}) if($options{'data'});

    # optimized naemon with wrapped_json output
    if($self->{'lmd_optimizations'} || $self->{'naemon_optimizations'}) {
        $self->_optimized_for_wrapped_json(\%options, "services");
        &timing_breakpoint('optimized get_services') if $self->{'optimized'};
    }

    # try to reduce the amount of transfered data
    my($size, $limit);
    if(!$self->{'optimized'} && defined $options{'pager'} && !defined $options{'options'}->{'limit'}) {
        ($size, $limit) = $self->_get_query_size('services', \%options, 'description', 'host_name', 'description');
        if(defined $size) {
            # then set the limit for the real query
            $options{'options'}->{'limit'} = $limit;
        }
    }

    unless(defined $options{'columns'}) {
        $options{'columns'} = [@{$Thruk::Backend::Provider::Livestatus::default_service_columns}];

        if($options{'enable_shinken_features'}) {
            push @{$options{'columns'}},  qw/is_impact source_problems impacts criticity is_problem poller_tag
                                             got_business_rule parent_dependencies/;
        }
        # only available since > 1.0.9
        if($self->{'lmd_optimizations'} || $self->{'naemon_optimizations'} > 1000009) {
            push @{$options{'columns'}},  qw/depends_exec depends_notify parents/;
        }
        if($self->{'lmd_optimizations'}) {
            push @{$options{'columns'}}, 'lmd_last_cache_update';
        }
        if(defined $options{'extra_columns'}) {
            push @{$options{'columns'}}, @{$options{'extra_columns'}};
        }
    }
    $options{'columns'} = $self->_clean_columns("services", $options{'columns'});


    if($self->{'lmd_optimizations'}) {
        push @{$options{'columns'}}, 'last_state_change_order';
        if(grep {/^state$/mx} @{$options{'columns'}}) {
            push @{$options{'columns'}}, 'state_order';
        }
    } else {
        my $last_program_start = $options{'last_program_starts'}->{$self->peer_key()} || 0;
        $options{'options'}->{'callbacks'}->{'last_state_change_order'} = sub { return $_[0]->{'last_state_change'} || $last_program_start; };

        # make it possible to order by state
        if(grep {/^state$/mx} @{$options{'columns'}}) {
            $options{'options'}->{'callbacks'}->{'state_order'} = sub { return 4 if $_[0]->{'state'} == 2; return $_[0]->{'state'} };
        }
    }

    # workaround a problem with services beeing reverse sorted if the only filter is a host_name filter
    if($options{'filter'}) {
        my $filter = $options{'filter'};
        while(ref $filter eq 'ARRAY' && scalar @{$filter} == 1) {
            $filter = $filter->[0];
        }
        if(ref $filter eq 'HASH') {
            my @keys = keys %{$filter};
            if(scalar @keys == 1 && $keys[0] eq 'host_name') {
                delete $options{'options'}->{'limit'};
            }
        }
        $options{'filter'} = [$filter];
    }

    # get result
    my $data = $self->_get_table('services', \%options);

    # set total size
    if(!$size && $self->{'optimized'}) {
        $size = $self->{'live'}->{'backend_obj'}->{'meta_data'}->{'total_count'};
    }

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

    return($options{'data'}, 'uniq') if($options{'data'});

    $options{'columns'} = [qw/description/];
    my $class = $self->_get_class('services', \%options);
    if($class->apply_filter('servicenames')) {
        my $rows = $class->hashref_array();
        unless(wantarray) {
            confess("get_service_names() should not be called in scalar context");
        }
        my @names;
        for my $row (@{$rows}) { push @names, $row->{'description'}; }
        return(\@names, 'uniq');
    }

    # use a filter which is always true, we only want the uniq service names
    my $stats = [
        'total'     => { -isa => { -and => [ 'description' => { '!=' => '' } ]}},
    ];
    $class->reset_filter()->stats($stats)->save_filter('servicenames');
    return($self->get_service_names(%options));
}

##########################################################

=head2 get_servicegroups

  get_servicegroups

returns a list of servicegroups

=cut
sub get_servicegroups {
    my($self, %options) = @_;
    return($options{'data'}) if($options{'data'});
    unless(defined $options{'columns'}) {
        $options{'columns'} = [qw/
            name alias members action_url notes notes_url
        /];
        if(defined $options{'extra_columns'}) {
            push @{$options{'columns'}}, @{$options{'extra_columns'}};
        }
    }
    $options{'columns'} = $self->_clean_columns("servicegroups", $options{'columns'});
    return $self->_get_table('servicegroups', \%options);
}

##########################################################

=head2 get_servicegroup_names

  get_servicegroup_names

returns a list of servicegroup names

=cut
sub get_servicegroup_names {
    my($self, %options) = @_;
    if($options{'data'}) {
        my %indexed;
        for my $row (@{$options{'data'}}) { $indexed{$row->{'name'}} = 1; }
        my @keys = keys %indexed;
        return(\@keys, 'uniq');
    }
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
    return($options{'data'}) if($options{'data'});

    # optimized naemon with wrapped_json output
    if($self->{'lmd_optimizations'} || $self->{'naemon_optimizations'}) {
        $self->_optimized_for_wrapped_json(\%options, "comments");
        &timing_breakpoint('optimized get_services') if $self->{'optimized'};
    }

    # try to reduce the amount of transfered data
    my($size, $limit);
    if(!$self->{'optimized'} && defined $options{'pager'} && !defined $options{'options'}->{'limit'}) {
        ($size, $limit) = $self->_get_query_size('comments', \%options, 'service_description', 'host_name', 'service_description');
        if(defined $size) {
            # then set the limit for the real query
            $options{'options'}->{'limit'} = $limit;
        }
    }

    unless(defined $options{'columns'}) {
        $options{'columns'} = [@{$Thruk::Backend::Provider::Livestatus::default_comments_columns}];
        if(defined $options{'extra_columns'}) {
            push @{$options{'columns'}}, @{$options{'extra_columns'}};
        }
    }
    $options{'columns'} = $self->_clean_columns("comments", $options{'columns'});
    my $data = $self->_get_table('comments', \%options);

    # set total size
    if(!$size && $self->{'optimized'}) {
        $size = $self->{'live'}->{'backend_obj'}->{'meta_data'}->{'total_count'};
    }

    unless(wantarray) {
        confess("get_comments() should not be called in scalar context");
    }
    return($data, undef, $size);
}

##########################################################

=head2 get_downtimes

  get_downtimes

returns a list of downtimes

=cut
sub get_downtimes {
    my($self, %options) = @_;
    return($options{'data'}) if($options{'data'});

    # optimized naemon with wrapped_json output
    if($self->{'lmd_optimizations'} || $self->{'naemon_optimizations'}) {
        $self->_optimized_for_wrapped_json(\%options, "downtimes");
        &timing_breakpoint('optimized get_services') if $self->{'optimized'};
    }

    # try to reduce the amount of transfered data
    my($size, $limit);
    if(!$self->{'optimized'} && defined $options{'pager'} && !defined $options{'options'}->{'limit'}) {
        ($size, $limit) = $self->_get_query_size('downtimes', \%options, 'service_description', 'host_name', 'service_description');
        if(defined $size) {
            # then set the limit for the real query
            $options{'options'}->{'limit'} = $limit;
        }
    }

    unless(defined $options{'columns'}) {
        $options{'columns'} = [@{$Thruk::Backend::Provider::Livestatus::default_downtimes_columns}];
        if(defined $options{'extra_columns'}) {
            push @{$options{'columns'}}, @{$options{'extra_columns'}};
        }
    }
    $options{'columns'} = $self->_clean_columns("downtimes", $options{'columns'});
    my $data = $self->_get_table('downtimes', \%options);

    # set total size
    if(!$size && $self->{'optimized'}) {
        $size = $self->{'live'}->{'backend_obj'}->{'meta_data'}->{'total_count'};
    }

    unless(wantarray) {
        confess("get_downtimes() should not be called in scalar context");
    }
    return($data, undef, $size);
}

##########################################################

=head2 get_contactgroups

  get_contactgroups

returns a list of contactgroups

=cut
sub get_contactgroups {
    my($self, %options) = @_;
    return($options{'data'}) if($options{'data'});

    # optimized naemon with wrapped_json output
    if($self->{'lmd_optimizations'} || $self->{'naemon_optimizations'}) {
        $self->_optimized_for_wrapped_json(\%options, "contactgroups");
        &timing_breakpoint('optimized get_contactgroups') if $self->{'optimized'};
    }

    # try to reduce the amount of transfered data
    my($size, $limit);
    if(!$self->{'optimized'} && defined $options{'pager'} && !defined $options{'options'}->{'limit'}) {
        ($size, $limit) = $self->_get_query_size('contactgroups', \%options, 'name', 'name');
        if(defined $size) {
            # then set the limit for the real query
            $options{'options'}->{'limit'} = $limit;
        }
    }

    unless(defined $options{'columns'}) {
        $options{'columns'} = [qw/
            name alias members
        /];
        if(defined $options{'extra_columns'}) {
            push @{$options{'columns'}}, @{$options{'extra_columns'}};
        }
    }
    $options{'columns'} = $self->_clean_columns("contactgroups", $options{'columns'});

    # get result
    my $data = $self->_get_table('contactgroups', \%options);

    # set total size
    if(!$size && $self->{'optimized'}) {
        $size = $self->{'live'}->{'backend_obj'}->{'meta_data'}->{'total_count'};
    }

    unless(wantarray) {
        confess("get_contactgroups() should not be called in scalar context");
    }
    return($data, undef, $size);
}

##########################################################

=head2 get_logs

  get_logs

returns logfile entries

=cut
sub get_logs {
    my($self, %options) = @_;
    if(Thruk::Backend::Provider::Base::can_use_logcache($self, \%options)) {
        $options{'collection'} = 'logs_'.$self->peer_key();
        return $self->{'_peer'}->logcache->get_logs(%options);
    }
    # replace auth filter with real filter
    if(defined $options{'filter'}) {
        for my $f (@{$options{'filter'}}) {
            if(ref $f eq 'HASH' && $f->{'auth_filter'}) {
                $f = $f->{'auth_filter'}->{'filter'};
            }
        }
    }
    # try to reduce the amount of transfered data
    my($size, $limit);
    if(!$self->{'optimized'} && defined $options{'pager'} && !$options{'file'} && !defined $options{'options'}->{'limit'}) {
        ($size, $limit) = $self->_get_query_size('log', \%options, 'time', 'DESC', 'time');
        if(defined $size) {
            # then set the limit for the real query
            $options{'options'}->{'limit'} = $limit;
        }
    }
    unless(defined $options{'columns'}) {
        $options{'columns'} = [@{$Thruk::Backend::Provider::Livestatus::default_logs_columns}];
        if(defined $options{'extra_columns'}) {
            push @{$options{'columns'}}, @{$options{'extra_columns'}};
        }
    }
    $options{'columns'} = $self->_clean_columns("logs", $options{'columns'});

    if(!wantarray && !$options{'file'}) {
        confess("get_logs() should not be called in scalar context unless using the file option");
    }

    my $logs;
    if($self->{'fetch_command'}) {
        return($self->_fetchlogs_external_command(\%options));
    }

    $logs = [reverse @{$self->_get_table('log', \%options)}];
    return(Thruk::Utils::IO::save_logs_to_tempfile($logs), 'file') if $options{'file'};
    return($logs, undef, $size);
}


##########################################################

=head2 get_timeperiods

  get_timeperiods

returns a list of timeperiods

=cut
sub get_timeperiods {
    my($self, %options) = @_;
    return($options{'data'}) if($options{'data'});
    unless(defined $options{'columns'}) {
        $options{'columns'} = [qw/
            name alias
        /];
        if(defined $options{'extra_columns'}) {
            push @{$options{'columns'}}, @{$options{'extra_columns'}};
        }
        if($self->{'lmd_optimizations'} || $self->{'naemon_optimizations'}) {
            push @{$options{'columns'}}, qw/exclusions/;
        }
    }
    $options{'columns'} = $self->_clean_columns("timeperiods", $options{'columns'});

    return $self->_get_table('timeperiods', \%options);
}

##########################################################

=head2 get_timeperiod_names

  get_timeperiod_names

returns a list of timeperiod names

=cut
sub get_timeperiod_names {
    my($self, %options) = @_;
    if($options{'data'}) {
        my %indexed;
        for my $row (@{$options{'data'}}) { $indexed{$row->{'name'}} = 1; }
        my @keys = keys %indexed;
        return(\@keys, 'uniq');
    }
    $options{'columns'} = [qw/name/];
    my $data = $self->_get_hash_table('timeperiods', 'name', \%options);
    my $keys = defined $data ? [keys %{$data}] : [];
    unless(wantarray) {
        confess("get_timeperiods_names() should not be called in scalar context");
    }
    return($keys, 'uniq');
}

##########################################################

=head2 get_commands

  get_commands

returns a list of commands

=cut
sub get_commands {
    my($self, %options) = @_;
    return($options{'data'}) if($options{'data'});
    unless(defined $options{'columns'}) {
        $options{'columns'} = [qw/
            name line
        /];
        if(defined $options{'extra_columns'}) {
            push @{$options{'columns'}}, @{$options{'extra_columns'}};
        }
    }
    $options{'columns'} = $self->_clean_columns("commands", $options{'columns'});
    return $self->_get_table('commands', \%options);
}

##########################################################

=head2 get_contacts

  get_contacts

returns a list of contacts

=cut
sub get_contacts {
    my($self, %options) = @_;
    return($options{'data'}) if($options{'data'});

    # optimized naemon with wrapped_json output
    if($self->{'lmd_optimizations'} || $self->{'naemon_optimizations'}) {
        $self->_optimized_for_wrapped_json(\%options, "contacts");
        &timing_breakpoint('optimized get_contacts') if $self->{'optimized'};
    }

    # try to reduce the amount of transfered data
    my($size, $limit);
    if(!$self->{'optimized'} && defined $options{'pager'} && !defined $options{'options'}->{'limit'}) {
        ($size, $limit) = $self->_get_query_size('contacts', \%options, 'name', 'name');
        if(defined $size) {
            # then set the limit for the real query
            $options{'options'}->{'limit'} = $limit;
        }
    }

    unless(defined $options{'columns'}) {
        $options{'columns'} = [@{$Thruk::Backend::Provider::Livestatus::default_contact_columns}];
        if(defined $options{'extra_columns'}) {
            push @{$options{'columns'}}, @{$options{'extra_columns'}};
        }
    }
    $options{'columns'} = $self->_clean_columns("contacts", $options{'columns'});

    # get result
    my $data = $self->_get_table('contacts', \%options);

    # set total size
    if(!$size && $self->{'optimized'}) {
        $size = $self->{'live'}->{'backend_obj'}->{'meta_data'}->{'total_count'};
    }

    unless(wantarray) {
        confess("get_contacts() should not be called in scalar context");
    }
    return($data, undef, $size);
}

##########################################################

=head2 get_contact_names

  get_contact_names

returns a list of contact names

=cut
sub get_contact_names {
    my($self, %options) = @_;
    if($options{'data'}) {
        my %indexed;
        for my $row (@{$options{'data'}}) { $indexed{$row->{'name'}} = 1; }
        my @keys = keys %indexed;
        return(\@keys, 'uniq');
    }
    $options{'columns'} = [qw/name/];
    my $data = $self->_get_hash_table('contacts', 'name', \%options);
    my $keys = defined $data ? [keys %{$data}] : [];

    unless(wantarray) {
        confess("get_contact_names() should not be called in scalar context");
    }
    return($keys, 'uniq');
}

##########################################################

=head2 get_contactgroup_names

  get_contactgroup_names

returns a list of contactgroup names

=cut
sub get_contactgroup_names {
    my($self, %options) = @_;
    if($options{'data'}) {
        my %indexed;
        for my $row (@{$options{'data'}}) { $indexed{$row->{'name'}} = 1; }
        my @keys = keys %indexed;
        return(\@keys, 'uniq');
    }
    $options{'columns'} = [qw/name/];
    my $data = $self->_get_hash_table('contactgroups', 'name', \%options);
    my $keys = defined $data ? [keys %{$data}] : [];

    unless(wantarray) {
        confess("get_contactgroup_names() should not be called in scalar context");
    }
    return($keys, 'uniq');
}

##########################################################

=head2 get_host_stats

  get_host_stats

returns the host statistics for the tac page

=cut

$Thruk::Backend::Provider::Livestatus::stats_columns->{'host_stats'} = [
    'total'                             => { -isa => { -and => [ 'name' => { '!=' => '' } ]}},
    'total_active'                      => { -isa => { -and => [ 'check_type' => 0 ]}},
    'total_passive'                     => { -isa => { -and => [ 'check_type' => 1 ]}},
    'pending'                           => { -isa => { -and => [ 'has_been_checked' => 0 ]}},
    'plain_pending'                     => { -isa => { -and => [ 'has_been_checked' => 0, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'pending_and_disabled'              => { -isa => { -and => [ 'has_been_checked' => 0, 'active_checks_enabled' => 0 ]}},
    'pending_and_scheduled'             => { -isa => { -and => [ 'has_been_checked' => 0, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'up'                                => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 0 ]}},
    'plain_up'                          => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 0, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'up_and_disabled_active'            => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 0, 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'up_and_disabled_passive'           => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 0, 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'up_and_scheduled'                  => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 0, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'down'                              => { -isa => { -and => [ 'state' => 1 ]}},
    'plain_down'                        => { -isa => { -and => [ 'state' => 1, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'down_and_ack'                      => { -isa => { -and => [ 'state' => 1, 'acknowledged' => 1 ]}},
    'down_and_scheduled'                => { -isa => { -and => [ 'state' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'down_and_disabled_active'          => { -isa => { -and => [ 'state' => 1, 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'down_and_disabled_passive'         => { -isa => { -and => [ 'state' => 1, 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'down_and_unhandled'                => { -isa => { -and => [ 'state' => 1, 'active_checks_enabled' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0 ]}},
    'unreachable'                       => { -isa => { -and => [ 'state' => 2 ]}},
    'plain_unreachable'                 => { -isa => { -and => [ 'state' => 2, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'unreachable_and_ack'               => { -isa => { -and => [ 'state' => 2, 'acknowledged' => 1 ]}},
    'unreachable_and_scheduled'         => { -isa => { -and => [ 'state' => 2, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'unreachable_and_disabled_active'   => { -isa => { -and => [ 'state' => 2, 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'unreachable_and_disabled_passive'  => { -isa => { -and => [ 'state' => 2, 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'unreachable_and_unhandled'         => { -isa => { -and => [ 'state' => 2, 'active_checks_enabled' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0 ]}},
    'flapping'                          => { -isa => { -and => [ 'is_flapping' => 1 ]}},
    'flapping_disabled'                 => { -isa => { -and => [ 'flap_detection_enabled' => 0 ]}},
    'notifications_disabled'            => { -isa => { -and => [ 'notifications_enabled' => 0 ]}},
    'eventhandler_disabled'             => { -isa => { -and => [ 'event_handler_enabled' => 0 ]}},
    'active_checks_disabled_active'     => { -isa => { -and => [ 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'active_checks_disabled_passive'    => { -isa => { -and => [ 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'passive_checks_disabled'           => { -isa => { -and => [ 'accept_passive_checks' => 0 ]}},
    'outages'                           => { -isa => { -and => [ 'state' => 1, 'childs' => {'!=' => undef } ]}},
];
sub get_host_stats {
    my($self, %options) = @_;

    if($options{'data'}) {
        return($options{'data'}->[0], 'SUM');
    }

    if($options{'hard_states_only'}) {
        delete $options{'hard_states_only'};
        return($self->_get_host_stats_hard(%options));
    }

    my $class = $self->_get_class('hosts', \%options);
    if($class->apply_filter('hoststats')) {
        my $rows = $class->hashref_array();
        unless(wantarray) {
            confess("get_host_stats() should not be called in scalar context");
        }
        return($rows, 'GROUP_STATS') if defined $options{'columns'};
        return(\%{$rows->[0]}, 'SUM');
    }

    $class->reset_filter()->stats($Thruk::Backend::Provider::Livestatus::stats_columns->{'host_stats'})->save_filter('hoststats');
    return($self->get_host_stats(%options));
}

##########################################################
# same as get_host_stats, but counts soft states as ok
$Thruk::Backend::Provider::Livestatus::stats_columns->{'host_stats_hard'} = [
    'total'                             => { -isa => { -and => [ 'name' => { '!=' => '' } ]}},
    'total_active'                      => { -isa => { -and => [ 'check_type' => 0 ]}},
    'total_passive'                     => { -isa => { -and => [ 'check_type' => 1 ]}},
    'pending'                           => { -isa => { -and => [ 'has_been_checked' => 0 ]}},
    'plain_pending'                     => { -isa => { -and => [ 'has_been_checked' => 0, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'pending_and_disabled'              => { -isa => { -and => [ 'has_been_checked' => 0, 'active_checks_enabled' => 0 ]}},
    'pending_and_scheduled'             => { -isa => { -and => [ 'has_been_checked' => 0, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'up'                                => { -isa => { -and => [ 'has_been_checked' => 1, { -or => [ 'state_type' => 0, 'state' => 0 ]}]}},
    'plain_up'                          => { -isa => { -and => [ 'has_been_checked' => 1, { -or => [ 'state_type' => 0, 'state' => 0 ]}, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'up_and_disabled_active'            => { -isa => { -and => [ 'has_been_checked' => 1, { -or => [ 'state_type' => 0, 'state' => 0 ]}, 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'up_and_disabled_passive'           => { -isa => { -and => [ 'has_been_checked' => 1, { -or => [ 'state_type' => 0, 'state' => 0 ]}, 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'up_and_scheduled'                  => { -isa => { -and => [ 'has_been_checked' => 1, { -or => [ 'state_type' => 0, 'state' => 0 ]}, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'down'                              => { -isa => { -and => [ 'state_type' => 1, 'state' => 1 ]}},
    'plain_down'                        => { -isa => { -and => [ 'state_type' => 1, 'state' => 1, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'down_and_ack'                      => { -isa => { -and => [ 'state_type' => 1, 'state' => 1, 'acknowledged' => 1 ]}},
    'down_and_scheduled'                => { -isa => { -and => [ 'state_type' => 1, 'state' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'down_and_disabled_active'          => { -isa => { -and => [ 'state_type' => 1, 'state' => 1, 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'down_and_disabled_passive'         => { -isa => { -and => [ 'state_type' => 1, 'state' => 1, 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'down_and_unhandled'                => { -isa => { -and => [ 'state_type' => 1, 'state' => 1, 'active_checks_enabled' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0 ]}},
    'unreachable'                       => { -isa => { -and => [ 'state_type' => 1, 'state' => 2 ]}},
    'plain_unreachable'                 => { -isa => { -and => [ 'state_type' => 1, 'state' => 2, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'unreachable_and_ack'               => { -isa => { -and => [ 'state_type' => 1, 'state' => 2, 'acknowledged' => 1 ]}},
    'unreachable_and_scheduled'         => { -isa => { -and => [ 'state_type' => 1, 'state' => 2, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'unreachable_and_disabled_active'   => { -isa => { -and => [ 'state_type' => 1, 'state' => 2, 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'unreachable_and_disabled_passive'  => { -isa => { -and => [ 'state_type' => 1, 'state' => 2, 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'unreachable_and_unhandled'         => { -isa => { -and => [ 'state_type' => 1, 'state' => 2, 'active_checks_enabled' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0 ]}},
    'flapping'                          => { -isa => { -and => [ 'is_flapping' => 1 ]}},
    'flapping_disabled'                 => { -isa => { -and => [ 'flap_detection_enabled' => 0 ]}},
    'notifications_disabled'            => { -isa => { -and => [ 'notifications_enabled' => 0 ]}},
    'eventhandler_disabled'             => { -isa => { -and => [ 'event_handler_enabled' => 0 ]}},
    'active_checks_disabled_active'     => { -isa => { -and => [ 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'active_checks_disabled_passive'    => { -isa => { -and => [ 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'passive_checks_disabled'           => { -isa => { -and => [ 'accept_passive_checks' => 0 ]}},
    'outages'                           => { -isa => { -and => [ 'state' => 1, 'childs' => {'!=' => undef } ]}},
];
sub _get_host_stats_hard {
    my($self, %options) = @_;

    my $class = $self->_get_class('hosts', \%options);
    if($class->apply_filter('hoststats_hard')) {
        my $rows = $class->hashref_array();
        unless(wantarray) {
            confess("_get_host_stats_hard() should not be called in scalar context");
        }
        return($rows, 'GROUP_STATS') if defined $options{'columns'};
        return(\%{$rows->[0]}, 'SUM');
    }


    $class->reset_filter()->stats($Thruk::Backend::Provider::Livestatus::stats_columns->{'host_stats_hard'})->save_filter('hoststats_hard');
    return($self->_get_host_stats_hard(%options));
}

##########################################################

=head2 get_host_totals_stats

  get_host_totals_stats

returns the host statistics used on the service/host details page

=cut

$Thruk::Backend::Provider::Livestatus::stats_columns->{'host_totals_stats'} = [
    'total'                             => { -isa => { -and => [ 'name' => { '!=' => '' } ]}},
    'pending'                           => { -isa => { -and => [ 'has_been_checked' => 0 ]}},
    'up'                                => { -isa => { -and => [ 'state' => 0, 'has_been_checked' => 1 ]}},
    'down'                              => { -isa => { -and => [ 'state' => 1 ]}},
    'down_and_unhandled'                => { -isa => { -and => [ 'state' => 1, 'active_checks_enabled' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0 ]}},
    'unreachable'                       => { -isa => { -and => [ 'state' => 2 ]}},
    'unreachable_and_unhandled'         => { -isa => { -and => [ 'state' => 2, 'active_checks_enabled' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0 ]}},
];
sub get_host_totals_stats {
    my($self, %options) = @_;

    if($options{'data'}) {
        return($options{'data'}->[0], 'SUM');
    }

    my $class = $self->_get_class('hosts', \%options);
    if($class->apply_filter('hoststatstotals')) {
        my $rows = $class->hashref_array();
        unless(wantarray) {
            confess("get_host_totals_stats() should not be called in scalar context");
        }
        return($rows, 'GROUP_STATS') if defined $options{'columns'};
        return(\%{$rows->[0]}, 'SUM');
    }

    $class->reset_filter()->stats($Thruk::Backend::Provider::Livestatus::stats_columns->{'host_totals_stats'})->save_filter('hoststatstotals');
    return($self->get_host_totals_stats(%options));
}

##########################################################

=head2 get_host_less_stats

  get_host_less_stats

same as get_host_stats but less numbers and therefore faster

=cut

$Thruk::Backend::Provider::Livestatus::stats_columns->{'host_less_stats'} = [
    'total'                             => { -isa => { -and => [ 'name' => { '!=' => '' } ]}},
    'pending'                           => { -isa => { -and => [ 'has_been_checked' => 0 ]}},
    'up'                                => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 0 ]}},
    'plain_up'                          => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 0, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'up_and_scheduled'                  => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 0, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'down'                              => { -isa => { -and => [ 'state' => 1 ]}},
    'plain_down'                        => { -isa => { -and => [ 'state' => 1, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'down_and_ack'                      => { -isa => { -and => [ 'state' => 1, 'acknowledged' => 1 ]}},
    'down_and_scheduled'                => { -isa => { -and => [ 'state' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'down_and_unhandled'                => { -isa => { -and => [ 'state' => 1, 'active_checks_enabled' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0 ]}},
    'unreachable'                       => { -isa => { -and => [ 'state' => 2 ]}},
    'plain_unreachable'                 => { -isa => { -and => [ 'state' => 2, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'unreachable_and_ack'               => { -isa => { -and => [ 'state' => 2, 'acknowledged' => 1 ]}},
    'unreachable_and_scheduled'         => { -isa => { -and => [ 'state' => 2, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'unreachable_and_unhandled'         => { -isa => { -and => [ 'state' => 2, 'active_checks_enabled' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0 ]}},
];
sub get_host_less_stats {
    my($self, %options) = @_;

    if($options{'data'}) {
        return($options{'data'}->[0], 'SUM');
    }

    my $class = $self->_get_class('hosts', \%options);
    if($class->apply_filter('hoststatsless')) {
        my $rows = $class->hashref_array();
        unless(wantarray) {
            confess("get_host_less_stats() should not be called in scalar context");
        }
        return($rows, 'GROUP_STATS') if defined $options{'columns'};
        return(\%{$rows->[0]}, 'SUM');
    }

    $class->reset_filter()->stats($Thruk::Backend::Provider::Livestatus::stats_columns->{'host_less_stats'})->save_filter('hoststatsless');

    return($self->get_host_less_stats(%options));
}

##########################################################

=head2 get_service_stats

  get_service_stats

returns the services statistics for the tac page

=cut

$Thruk::Backend::Provider::Livestatus::stats_columns->{'service_stats'} = [
    'total'                             => { -isa => { -and => [ 'description' => { '!=' => '' } ]}},
    'total_active'                      => { -isa => { -and => [ 'check_type' => 0 ]}},
    'active_checks_disabled_active'     => { -isa => { -and => [ 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'total_passive'                     => { -isa => { -and => [ 'check_type' => 1 ]}},
    'active_checks_disabled_passive'    => { -isa => { -and => [ 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'pending'                           => { -isa => { -and => [ 'has_been_checked' => 0 ]}},
    'plain_pending'                     => { -isa => { -and => [ 'has_been_checked' => 0, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'pending_and_disabled'              => { -isa => { -and => [ 'has_been_checked' => 0, 'active_checks_enabled' => 0 ]}},
    'pending_and_scheduled'             => { -isa => { -and => [ 'has_been_checked' => 0, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'ok'                                => { -isa => { -and => [ 'state' => 0, 'has_been_checked' => 1 ]}},
    'plain_ok'                          => { -isa => { -and => [ 'state' => 0, 'has_been_checked' => 1, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'ok_and_scheduled'                  => { -isa => { -and => [ 'state' => 0, 'has_been_checked' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'ok_and_disabled_active'            => { -isa => { -and => [ 'state' => 0, 'has_been_checked' => 1, 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'ok_and_disabled_passive'           => { -isa => { -and => [ 'state' => 0, 'has_been_checked' => 1, 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'warning'                           => { -isa => { -and => [ 'state' => 1 ]}},
    'plain_warning'                     => { -isa => { -and => [ 'state' => 1, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'warning_and_scheduled'             => { -isa => { -and => [ 'state' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'warning_and_disabled_active'       => { -isa => { -and => [ 'state' => 1, 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'warning_and_disabled_passive'      => { -isa => { -and => [ 'state' => 1, 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'warning_and_ack'                   => { -isa => { -and => [ 'state' => 1, 'acknowledged' => 1 ]}},
    'warning_on_down_host'              => { -isa => { -and => [ 'state' => 1, 'host_state' => { '!=' => 0 } ]}},
    'warning_and_unhandled'             => { -isa => { -and => [ 'state' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_state' => 0, 'host_acknowledged' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
    'critical'                          => { -isa => { -and => [ 'state' => 2 ]}},
    'plain_critical'                    => { -isa => { -and => [ 'state' => 2, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'critical_and_scheduled'            => { -isa => { -and => [ 'state' => 2, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'critical_and_disabled_active'      => { -isa => { -and => [ 'state' => 2, 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'critical_and_disabled_passive'     => { -isa => { -and => [ 'state' => 2, 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'critical_and_ack'                  => { -isa => { -and => [ 'state' => 2, 'acknowledged' => 1 ]}},
    'critical_on_down_host'             => { -isa => { -and => [ 'state' => 2, 'host_state' => { '!=' => 0 } ]}},
    'critical_and_unhandled'            => { -isa => { -and => [ 'state' => 2, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_state' => 0, 'host_acknowledged' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
    'unknown'                           => { -isa => { -and => [ 'state' => 3 ]}},
    'plain_unknown'                     => { -isa => { -and => [ 'state' => 3, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'unknown_and_scheduled'             => { -isa => { -and => [ 'state' => 3, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'unknown_and_disabled_active'       => { -isa => { -and => [ 'state' => 3, 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'unknown_and_disabled_passive'      => { -isa => { -and => [ 'state' => 3, 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'unknown_and_ack'                   => { -isa => { -and => [ 'state' => 3, 'acknowledged' => 1 ]}},
    'unknown_on_down_host'              => { -isa => { -and => [ 'state' => 3, 'host_state' => { '!=' => 0 } ]}},
    'unknown_and_unhandled'             => { -isa => { -and => [ 'state' => 3, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_state' => 0, 'host_acknowledged' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
    'flapping'                          => { -isa => { -and => [ 'is_flapping' => 1 ]}},
    'flapping_disabled'                 => { -isa => { -and => [ 'flap_detection_enabled' => 0 ]}},
    'notifications_disabled'            => { -isa => { -and => [ 'notifications_enabled' => 0 ]}},
    'eventhandler_disabled'             => { -isa => { -and => [ 'event_handler_enabled' => 0 ]}},
    'passive_checks_disabled'           => { -isa => { -and => [ 'accept_passive_checks' => 0 ]}},
];
sub get_service_stats {
    my($self, %options) = @_;

    if($options{'data'}) {
        return($options{'data'}->[0], 'SUM');
    }

    if($options{'hard_states_only'}) {
        delete $options{'hard_states_only'};
        return($self->_get_service_stats_hard(%options));
    }

    my $class = $self->_get_class('services', \%options);
    if($class->apply_filter('servicestats')) {
        my $rows = $class->hashref_array();
        unless(wantarray) {
            confess("get_service_stats() should not be called in scalar context");
        }
        return($rows, 'GROUP_STATS') if defined $options{'columns'};
        return(\%{$rows->[0]}, 'SUM');
    }

    $class->reset_filter()->stats($Thruk::Backend::Provider::Livestatus::stats_columns->{'service_stats'})->save_filter('servicestats');
    return($self->get_service_stats(%options));
}

##########################################################
# same as get_service_stats, but counts soft states as up

$Thruk::Backend::Provider::Livestatus::stats_columns->{'service_stats_hard'} = [
    'total'                             => { -isa => { -and => [ 'description' => { '!=' => '' } ]}},
    'total_active'                      => { -isa => { -and => [ 'check_type' => 0 ]}},
    'active_checks_disabled_active'     => { -isa => { -and => [ 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'total_passive'                     => { -isa => { -and => [ 'check_type' => 1 ]}},
    'active_checks_disabled_passive'    => { -isa => { -and => [ 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'pending'                           => { -isa => { -and => [ 'has_been_checked' => 0 ]}},
    'plain_pending'                     => { -isa => { -and => [ 'has_been_checked' => 0, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'pending_and_disabled'              => { -isa => { -and => [ 'has_been_checked' => 0, 'active_checks_enabled' => 0 ]}},
    'pending_and_scheduled'             => { -isa => { -and => [ 'has_been_checked' => 0, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'ok'                                => { -isa => { -and => [ { -or => [ 'state_type' => 0, 'state' => 0 ]}, 'has_been_checked' => 1 ]}},
    'plain_ok'                          => { -isa => { -and => [ { -or => [ 'state_type' => 0, 'state' => 0 ]}, 'has_been_checked' => 1, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'ok_and_scheduled'                  => { -isa => { -and => [ { -or => [ 'state_type' => 0, 'state' => 0 ]}, 'has_been_checked' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'ok_and_disabled_active'            => { -isa => { -and => [ { -or => [ 'state_type' => 0, 'state' => 0 ]}, 'has_been_checked' => 1, 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'ok_and_disabled_passive'           => { -isa => { -and => [ { -or => [ 'state_type' => 0, 'state' => 0 ]}, 'has_been_checked' => 1, 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'warning'                           => { -isa => { -and => [ 'state_type' => 1, 'state' => 1 ]}},
    'plain_warning'                     => { -isa => { -and => [ 'state_type' => 1, 'state' => 1, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'warning_and_scheduled'             => { -isa => { -and => [ 'state_type' => 1, 'state' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'warning_and_disabled_active'       => { -isa => { -and => [ 'state_type' => 1, 'state' => 1, 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'warning_and_disabled_passive'      => { -isa => { -and => [ 'state_type' => 1, 'state' => 1, 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'warning_and_ack'                   => { -isa => { -and => [ 'state_type' => 1, 'state' => 1, 'acknowledged' => 1 ]}},
    'warning_on_down_host'              => { -isa => { -and => [ 'state_type' => 1, 'state' => 1, 'host_state' => { '!=' => 0 } ]}},
    'warning_and_unhandled'             => { -isa => { -and => [ 'state_type' => 1, 'state' => 1, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_state' => 0, 'host_acknowledged' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
    'critical'                          => { -isa => { -and => [ 'state_type' => 1, 'state' => 2 ]}},
    'plain_critical'                    => { -isa => { -and => [ 'state_type' => 1, 'state' => 2, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'critical_and_scheduled'            => { -isa => { -and => [ 'state_type' => 1, 'state' => 2, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'critical_and_disabled_active'      => { -isa => { -and => [ 'state_type' => 1, 'state' => 2, 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'critical_and_disabled_passive'     => { -isa => { -and => [ 'state_type' => 1, 'state' => 2, 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'critical_and_ack'                  => { -isa => { -and => [ 'state_type' => 1, 'state' => 2, 'acknowledged' => 1 ]}},
    'critical_on_down_host'             => { -isa => { -and => [ 'state_type' => 1, 'state' => 2, 'host_state' => { '!=' => 0 } ]}},
    'critical_and_unhandled'            => { -isa => { -and => [ 'state_type' => 1, 'state' => 2, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_state' => 0, 'host_acknowledged' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
    'unknown'                           => { -isa => { -and => [ 'state_type' => 1, 'state' => 3 ]}},
    'plain_unknown'                     => { -isa => { -and => [ 'state_type' => 1, 'state' => 3, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'unknown_and_scheduled'             => { -isa => { -and => [ 'state_type' => 1, 'state' => 3, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'unknown_and_disabled_active'       => { -isa => { -and => [ 'state_type' => 1, 'state' => 3, 'check_type' => 0, 'active_checks_enabled' => 0 ]}},
    'unknown_and_disabled_passive'      => { -isa => { -and => [ 'state_type' => 1, 'state' => 3, 'check_type' => 1, 'active_checks_enabled' => 0 ]}},
    'unknown_and_ack'                   => { -isa => { -and => [ 'state_type' => 1, 'state' => 3, 'acknowledged' => 1 ]}},
    'unknown_on_down_host'              => { -isa => { -and => [ 'state_type' => 1, 'state' => 3, 'host_state' => { '!=' => 0 } ]}},
    'unknown_and_unhandled'             => { -isa => { -and => [ 'state_type' => 1, 'state' => 3, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_state' => 0, 'host_acknowledged' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
    'flapping'                          => { -isa => { -and => [ 'is_flapping' => 1 ]}},
    'flapping_disabled'                 => { -isa => { -and => [ 'flap_detection_enabled' => 0 ]}},
    'notifications_disabled'            => { -isa => { -and => [ 'notifications_enabled' => 0 ]}},
    'eventhandler_disabled'             => { -isa => { -and => [ 'event_handler_enabled' => 0 ]}},
    'passive_checks_disabled'           => { -isa => { -and => [ 'accept_passive_checks' => 0 ]}},
];
sub _get_service_stats_hard {
    my($self, %options) = @_;

    my $class = $self->_get_class('services', \%options);
    if($class->apply_filter('servicestats_hard')) {
        my $rows = $class->hashref_array();
        unless(wantarray) {
            confess("_get_service_stats_hard() should not be called in scalar context");
        }
        return($rows, 'GROUP_STATS') if defined $options{'columns'};
        return(\%{$rows->[0]}, 'SUM');
    }

    $class->reset_filter()->stats($Thruk::Backend::Provider::Livestatus::stats_columns->{'service_stats_hard'})->save_filter('servicestats_hard');
    return($self->_get_service_stats_hard(%options));
}

##########################################################

=head2 get_service_totals_stats

  get_service_totals_stats

returns the services statistics used on the service/host details page

=cut

$Thruk::Backend::Provider::Livestatus::stats_columns->{'service_totals_stats'} = [
    'total'                             => { -isa => { -and => [ 'description' => { '!=' => '' } ]}},
    'pending'                           => { -isa => { -and => [ 'has_been_checked' => 0 ]}},
    'ok'                                => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 0 ]}},
    'warning'                           => { -isa => { -and => [ 'state' => 1 ]}},
    'warning_and_unhandled'             => { -isa => { -and => [ 'state' => 1, 'host_state' => 0, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_acknowledged' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
    'critical'                          => { -isa => { -and => [ 'state' => 2 ]}},
    'critical_and_unhandled'            => { -isa => { -and => [ 'state' => 2, 'host_state' => 0, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_acknowledged' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
    'unknown'                           => { -isa => { -and => [ 'state' => 3 ]}},
    'unknown_and_unhandled'             => { -isa => { -and => [ 'state' => 3, 'host_state' => 0, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_acknowledged' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
];
sub get_service_totals_stats {
    my($self, %options) = @_;

    if($options{'data'}) {
        return($options{'data'}->[0], 'SUM');
    }

    my $class = $self->_get_class('services', \%options);
    if($class->apply_filter('servicestatstotals')) {
        my $rows = $class->hashref_array();
        unless(wantarray) {
            confess("get_service_totals_stats() should not be called in scalar context");
        }
        return($rows, 'GROUP_STATS') if defined $options{'columns'};
        return(\%{$rows->[0]}, 'SUM');
    }

    $class->reset_filter()->stats($Thruk::Backend::Provider::Livestatus::stats_columns->{'service_totals_stats'})->save_filter('servicestatstotals');
    return($self->get_service_totals_stats(%options));
}

##########################################################

=head2 get_service_less_stats

  get_service_less_stats

same as get_service_stats but less numbers and therefore faster

=cut

# unhandled are required for playing sounds on details page
$Thruk::Backend::Provider::Livestatus::stats_columns->{'service_less_stats'} = [
    'total'                             => { -isa => { -and => [ 'description' => { '!=' => '' } ]}},
    'pending'                           => { -isa => { -and => [ 'has_been_checked' => 0 ]}},
    'ok'                                => { -isa => { -and => [ 'has_been_checked' => 1, 'state' => 0 ]}},
    'plain_ok'                          => { -isa => { -and => [ 'state' => 0, 'has_been_checked' => 1, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'warning'                           => { -isa => { -and => [ 'state' => 1 ]}},
    'plain_warning'                     => { -isa => { -and => [ 'state' => 1, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'warning_and_scheduled'             => { -isa => { -and => [ 'state' => 1, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'warning_and_unhandled'             => { -isa => { -and => [ 'state' => 1, 'host_state' => 0, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_acknowledged' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
    'critical'                          => { -isa => { -and => [ 'state' => 2 ]}},
    'plain_critical'                    => { -isa => { -and => [ 'state' => 2, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'critical_and_ack'                  => { -isa => { -and => [ 'state' => 2, 'acknowledged' => 1 ]}},
    'critical_and_scheduled'            => { -isa => { -and => [ 'state' => 2, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'critical_and_unhandled'            => { -isa => { -and => [ 'state' => 2, 'host_state' => 0, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_acknowledged' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
    'unknown'                           => { -isa => { -and => [ 'state' => 3 ]}},
    'plain_unknown'                     => { -isa => { -and => [ 'state' => 3, 'scheduled_downtime_depth' => 0, 'acknowledged' => 0 ]}},
    'unknown_and_ack'                   => { -isa => { -and => [ 'state' => 3, 'acknowledged' => 1 ]}},
    'unknown_and_scheduled'             => { -isa => { -and => [ 'state' => 3, 'scheduled_downtime_depth' => { '>' => 0 } ]}},
    'unknown_and_unhandled'             => { -isa => { -and => [ 'state' => 3, 'host_state' => 0, 'acknowledged' => 0, 'scheduled_downtime_depth' => 0, 'host_acknowledged' => 0, 'host_scheduled_downtime_depth' => 0 ]}},
];
sub get_service_less_stats {
    my($self, %options) = @_;

    if($options{'data'}) {
        return($options{'data'}->[0], 'SUM');
    }

    my $class = $self->_get_class('services', \%options);
    if($class->apply_filter('servicestatsless')) {
        my $rows = $class->hashref_array();
        unless(wantarray) {
            confess("get_service_less_stats() should not be called in scalar context");
        }
        return($rows, 'GROUP_STATS') if defined $options{'columns'};
        return(\%{$rows->[0]}, 'SUM');
    }

    $class->reset_filter()->stats($Thruk::Backend::Provider::Livestatus::stats_columns->{'service_less_stats'})->save_filter('servicestatsless');
    return($self->get_service_less_stats(%options));
}

##########################################################

=head2 get_performance_stats

  get_performance_stats

returns the service /host execution statistics

=cut
sub get_performance_stats {
    my($self, %options) = @_;

    if($options{'data'}) {
        my $d = $options{'data'};
        my $data = {%{$d->[0]->[0]}, %{$d->[1]->[0]}, %{$d->[2]->[0]}, %{$d->[3]->[0]}, %{$d->[4]->[0]}, %{$d->[5]->[0]}, };
        return($data, 'STATS');
    }

    my $now    = time();
    my $min1   = $now -   60;
    my $min5   = $now -  300;
    my $min15  = $now -  900;
    my $min60  = $now - 3600;
    my $minall = $options{'last_program_starts'}->{$self->peer_key()} || 0;

    my $data = {};
    for my $type (qw{hosts services}) {
        my $stats = [
            $type.'_active_sum'      => { -isa => { -and => [ 'check_type' => 0 ]}},
            $type.'_active_1_sum'    => { -isa => { -and => [ 'check_type' => 0, 'has_been_checked' => 1, 'last_check' => { '>=' => $min1   }]}},
            $type.'_active_5_sum'    => { -isa => { -and => [ 'check_type' => 0, 'has_been_checked' => 1, 'last_check' => { '>=' => $min5   }]}},
            $type.'_active_15_sum'   => { -isa => { -and => [ 'check_type' => 0, 'has_been_checked' => 1, 'last_check' => { '>=' => $min15  }]}},
            $type.'_active_60_sum'   => { -isa => { -and => [ 'check_type' => 0, 'has_been_checked' => 1, 'last_check' => { '>=' => $min60  }]}},
            $type.'_active_all_sum'  => { -isa => { -and => [ 'check_type' => 0, 'has_been_checked' => 1, 'last_check' => { '>=' => $minall }]}},

            $type.'_passive_sum'     => { -isa => { -and => [ 'check_type' => 1 ]}},
            $type.'_passive_1_sum'   => { -isa => { -and => [ 'check_type' => 1, 'has_been_checked' => 1, 'last_check' => { '>=' => $min1   }]}},
            $type.'_passive_5_sum'   => { -isa => { -and => [ 'check_type' => 1, 'has_been_checked' => 1, 'last_check' => { '>=' => $min5   }]}},
            $type.'_passive_15_sum'  => { -isa => { -and => [ 'check_type' => 1, 'has_been_checked' => 1, 'last_check' => { '>=' => $min15  }]}},
            $type.'_passive_60_sum'  => { -isa => { -and => [ 'check_type' => 1, 'has_been_checked' => 1, 'last_check' => { '>=' => $min60  }]}},
            $type.'_passive_all_sum' => { -isa => { -and => [ 'check_type' => 1, 'has_been_checked' => 1, 'last_check' => { '>=' => $minall }]}},
        ];
        $options{'filter'} = $options{$type.'_filter'};
        my $class = $self->_get_class($type, \%options);
        my $rows = $class->stats($stats)->hashref_array();
        $data = { %{$data}, %{$rows->[0]} } if($rows && $rows->[0]);

        # add stats for active checks
        $stats = [
            $type.'_execution_time_sum'      => { -isa => [ -sum => 'execution_time' ]},
            $type.'_execution_time_avg'      => { -isa => [ -avg => 'execution_time' ]},
            $type.'_latency_sum'             => { -isa => [ -sum => 'latency' ]},
            $type.'_latency_avg'             => { -isa => [ -avg => 'latency' ]},
            $type.'_active_state_change_sum' => { -isa => [ -sum => 'percent_state_change' ]},
            $type.'_execution_time_min'      => { -isa => [ -min => 'execution_time' ]},
            $type.'_latency_min'             => { -isa => [ -min => 'latency' ]},
            $type.'_active_state_change_min' => { -isa => [ -min => 'percent_state_change' ]},
            $type.'_execution_time_max'      => { -isa => [ -max => 'execution_time' ]},
            $type.'_latency_max'             => { -isa => [ -max => 'latency' ]},
            $type.'_active_state_change_max' => { -isa => [ -max => 'percent_state_change' ]},
        ];
        $class = $self->_get_class($type, \%options);
        $rows = $class
                    ->filter([ check_type => 0, has_been_checked => 1 ])
                    ->stats($stats)->hashref_array();
        $data = { %{$data}, %{$rows->[0]} } if($rows && $rows->[0]);

        # add stats for passive checks
        $stats = [
            $type.'_passive_state_change_sum' => { -isa => [ -sum => 'percent_state_change' ]},
            $type.'_passive_state_change_min' => { -isa => [ -min => 'percent_state_change' ]},
            $type.'_passive_state_change_max' => { -isa => [ -max => 'percent_state_change' ]},
        ];
        $class = $self->_get_class($type, \%options);
        $rows  = $class->filter([ check_type => 1, has_been_checked => 1 ])
                       ->stats($stats)->hashref_array();
        $data  = { %{$data}, %{$rows->[0]} } if($rows && $rows->[0]);
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

    if($options{'data'}) {
        return($options{'data'}->[0], 'SUM');
    }

    my $class = $self->_get_class('status', \%options);
    my $data  =  $class
                  ->columns(qw/
                        cached_log_messages connections connections_rate host_checks
                        host_checks_rate requests requests_rate service_checks
                        service_checks_rate neb_callbacks neb_callbacks_rate
                        log_messages log_messages_rate forks forks_rate
                  /)
                  ->hashref_array();

    if(defined $data && !$ENV{'THRUK_USE_LMD'}) {
        $data = shift @{$data};
    }

    unless(wantarray) {
        confess("get_extra_perf_stats() should not be called in scalar context");
    }
    return($data, 'SUM');
}

##########################################################

=head2 set_verbose

  set_verbose

sets verbose mode for this backend and returns old value

=cut
sub set_verbose {
    my($self, $val) = @_;
    my $old = $self->{'live'}->{'backend_obj'}->{'verbose'};
    $self->{'live'}->{'backend_obj'}->{'verbose'} = $val;
    $self->{'live'}->{'backend_obj'}->{'logger'}  = $self->{'log'};
    return($old);
}

##########################################################

=head2 _get_class

  _get_class($tablename, $options)

generic function to return a table class

=cut
sub _get_class {
    my($self, $table, $options) = @_;

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

    $options->{'options'}->{'AddPeer'} = 0 if(!defined $options->{'AddPeer'} || $options->{'AddPeer'} == 0);

    $class = $class->options($options->{'options'});

    return $class;
}

##########################################################

=head2 _get_table

  _get_table

generic function to return a table with options

=cut
sub _get_table {
    my($self, $table, $options) = @_;
    my $class = $self->_optimize($self->_get_class($table, $options));
    my $data  = $class->hashref_array() || [];

    return $data;
}

##########################################################

=head2 _optimize

  _optimize

return livestatus::lite class with enhanced options

=cut
sub _optimize {
    my($self, $class) = @_;

    return $class unless $self->{'lmd_optimizations'};

    if($class->{'_columns'} && $class->{'_options'}) {
        $class->{'_options'}->{'AddPeer'} = 0;
        push @{$class->{'_columns'}}, 'peer_key';
    }
    return $class;
}

##########################################################

=head2 _get_hash_table

  _get_hash_table

generic function to return a hash table with options

=cut
sub _get_hash_table {
    my($self, $table, $key, $options) = @_;
    my $class = $self->_get_class($table, $options);
    my $data  = $class->hashref_pk($key) || {};
    return $data;
}


##########################################################

=head2 _get_query_size

  _get_query_size

returns the size of a query, used to reduce the amount of transfered data

=cut
sub _get_query_size {
    my($self, $table, $options, $key, $sortby1, $sortby2) = @_;

    # only if paging is enabled
    return unless defined $options->{'pager'};
    if(defined $options->{'sort'}) {
        return unless ref $options->{'sort'} eq 'HASH';
        if($options->{'sort'}->{'DESC'} && $sortby1 && $sortby1 eq 'DESC') {
            return if(!$sortby2 || $sortby2 ne $options->{'sort'}->{'DESC'});
        } else {
            return unless defined $options->{'sort'}->{'ASC'};
            if(ref $options->{'sort'}->{'ASC'} eq 'ARRAY') {
                return if defined $sortby1 and $options->{'sort'}->{'ASC'}->[0] ne $sortby1;
                return if defined $sortby2 and $options->{'sort'}->{'ASC'}->[1] ne $sortby2;
            } else {
                return if defined $sortby1 and $options->{'sort'}->{'ASC'} ne $sortby1;
            }
        }
    }

    my $entries = $options->{'pager'}->{'entries'};
    return unless defined $entries;
    return if $entries !~ m/^\d+$/mx;

    my $stats = [
        'total' => { -isa => [ $key => { '!=' => ($key eq 'time' ? '-1' : undef) } ]},
    ];
    my $oldcolumns = delete $options->{'columns'};
    my $class = $self->_get_class($table, $options);
    my $rows = $class->stats($stats)->hashref_array();
    $options->{'columns'} = $oldcolumns if $oldcolumns;
    my $size = $rows->[0]->{'total'};
    return unless defined $size;

    my $pages = 0;
    my $page  = $options->{'pager'}->{'page'};
    if( $entries > 0 ) {
        $pages = POSIX::ceil( $size / $entries );
    }
    if( $page < 0 ) { $page = 1; }
    unless(wantarray) {
        confess("_get_query_size() should not be called in scalar context");
    }
    $entries  = $entries * $page;
    return($size, $entries);
}

##########################################################

=head2 get_logs_start_end

  get_logs_start_end

returns first and last logfile entry

=cut
sub get_logs_start_end {
    return(_get_logs_start_end(@_));
}

##########################################################

=head2 _get_logs_start_end

  _get_logs_start_end

returns the min/max timestamp for given logs

=cut
sub _get_logs_start_end {
    my($self, %options) = @_;
    if(defined $self->{'_peer'}->{'logcache'} && !defined $options{'nocache'}) {
        $options{'collection'} = 'logs_'.$self->peer_key();
        return $self->{'_peer'}->logcache->_get_logs_start_end(%options);
    }
    if(!$options{'filter'} || scalar @{$options{'filter'}} == 0) {
        # not a good idea, try to assume earliest date without parsing all logfiles
        my($start, $end) = Thruk::Backend::Provider::Base::get_logs_start_end_no_filter($self);
        return([$start, $end]);
    }

    if($self->{'fetch_command'}) {
        my($logs) = ($self->_fetchlogs_external_command(\%options));
        if(scalar @{$logs} > 0) {
            my $start = $logs->[0]->{'time'};
            my $end   = $logs->[scalar @{$logs}-1]->{'time'};
            return([$start, $end]);
        }
    }

    my $class = $self->_get_class('log', \%options);
    my $rows  = $class->stats([ 'start' => { -isa => [ -min => 'time' ]},
                                'end'   => { -isa => [ -max => 'time' ]},
                             ])
                      ->hashref_array();
    return([$rows->[0]->{'start'}, $rows->[0]->{'end'}]);
}

##########################################################

=head2 renew_logcache

  renew_logcache

renew logcache

=cut
sub renew_logcache {
    my($self, $c) = @_;
    return unless defined $self->{'_peer'}->{'logcache'};
    # renew cache?
    if(!defined $self->{'lastcacheupdate'} || $self->{'lastcacheupdate'} < time()-5) {
        $self->{'_peer'}->logcache->_import_logs($c, 'update', $self->peer_key());
        $self->{'lastcacheupdate'} = time();
    }
    return;
}

##########################################################
sub _replace_callbacks {
    my($self,$callbacks) = @_;
    return unless defined $callbacks;
    for my $key (keys %{$callbacks}) {
        next if ref $callbacks->{$key} eq 'CODE';
        my $callback = $Thruk::Backend::Provider::Livestatus::callbacks->{$callbacks->{$key}};
        confess("no callback for ".$key." -> ".$callbacks->{$key}) unless defined $callback;
        $callbacks->{$key} = $callback;
    }
    return;
}

##########################################################
sub _optimized_for_wrapped_json {
    my($self, $options, $table) = @_;
    $self->{'optimized'} = 0;

    if($options->{'sort'}) {
        $options->{'options'}->{'sort'} = [];
        if(ref $options->{'sort'} eq '') {
            $options->{'sort'} = { ASC => [ $options->{'sort'} ] };
        }
        elsif(ref $options->{'sort'} eq 'ARRAY') {
            $options->{'sort'} = { ASC => $options->{'sort'} };
        }
        for my $order (keys %{$options->{'sort'}}) {
            if(ref $options->{'sort'}->{$order} ne 'ARRAY') {
                $options->{'sort'}->{$order} = [$options->{'sort'}->{$order}];
            }
            for my $key (@{$options->{'sort'}->{$order}}) {
                my $col = $key;
                if($col =~ m/^cust__(.*)$/mx) {
                    if($self->{'lmd_optimizations'}) {
                        $col = "custom_variables ".$1;
                        if($table && $table eq 'services') {
                            push @{$options->{'options'}->{'sort'}}, 'host_'.$col.' '.(lc $order);
                            push @{$options->{'extra_columns'}}, "host_custom_variables";
                        }
                        push @{$options->{'extra_columns'}}, "custom_variables";
                    } else {
                        delete $options->{'options'}->{'sort'};
                        return;
                    }
                }
                push @{$options->{'options'}->{'sort'}}, $col.' '.(lc $order);
                if($self->{'lmd_optimizations'}) {
                    if($key eq 'peer_name') {
                        $options->{'extra_columns'} = [] unless $options->{'extra_columns'};
                        push @{$options->{'extra_columns'}}, "peer_name";
                    }
                } else {
                    if(   $key eq 'last_state_change_order'
                       || $key eq 'state_order'
                       || $key eq 'peer_name'
                    ) {
                        delete $options->{'options'}->{'sort'};
                        return;
                    }
                }
            }
        }
    }

    $options->{'options'}->{'wrapped_json'} = 1;
    if($options->{'pager'} && $options->{'pager'}->{'entries'} && $options->{'pager'}->{'entries'} =~ m/^\d+$/mx) {
        my $page = ($options->{'pager'}->{'page'} || 1);
        # offset can only be used if this is the only backend...
        # so use the minimal limit for now
        if($self->{'lmd_optimizations'}) {
            $options->{'options'}->{'offset'} = ($page-1) * $options->{'pager'}->{'entries'};
            $options->{'options'}->{'limit'} = $options->{'pager'}->{'entries'};
        } else {
            $options->{'options'}->{'limit'}  = $page * $options->{'pager'}->{'entries'};
        }
    }
    $self->{'optimized'} = 1;
    return;
}

##########################################################
sub _fetchlogs_external_command {
    my($self, $options) = @_;

    my($start, $end);
    if($options->{'filter'} && scalar @{$options->{'filter'}} == 1 && scalar keys %{$options->{'filter'}->[0]} == 1 && $options->{'filter'}->[0]->{'-and'}) {
        $options->{'filter'}->[0] = $options->{'filter'}->[0]->{'-and'};
    }
    while($options->{'filter'} && ref($options->{'filter'}) eq 'ARRAY' && scalar @{$options->{'filter'}} == 1 && ref($options->{'filter'}->[0]) eq 'ARRAY') {
        $options->{'filter'} = $options->{'filter'}->[0];
    }
    for my $f (@{$options->{'filter'}}) {
        for my $key (keys %{$f}) {
            confess("unsupported filter: ".$key.Dumper($options)) if $key ne 'time';
            for my $op (keys %{$f->{$key}}) {
                if($op eq '<=') {
                    if($end) { confess("duplicate end filter"); }
                    $end   = $f->{$key}->{$op};
                }
                elsif($op eq '>=') {
                    if($start) { confess("duplicate start filter"); }
                    $start = $f->{$key}->{$op};
                } else {
                    confess("unsupported operator: ".$op);
                }
            }
        }
    }

    local $ENV{'THRUK_BACKEND'} = $self->{'id'};
    local $ENV{'THRUK_LOGCACHE_LIMIT'} = $options->{'options'}->{'limit'} if $options->{'options'}->{'limit'};
    local $ENV{'THRUK_LOGCACHE_START'} = $start if $start;
    local $ENV{'THRUK_LOGCACHE_END'}   = $end if $end;

    require File::Temp;
    my($fh, $filename) = File::Temp::tempfile();
    my $cmd = $self->{'fetch_command'}.' > '.$filename;
    my($rc, $output) = Thruk::Utils::IO::cmd($cmd);
    if($rc != 0) {
        die("fetchlogs cmd failed, rc ".$rc.": ".$cmd."\n".$output);
    }
    if($options->{'file'}) {
        return($filename, 'file');
    }

    require Monitoring::Availability::Logs;
    my $logstore = Monitoring::Availability::Logs->new(log_file => $filename);
    my $logs = $logstore->get_logs();
    unlink($filename);

    return($logs, undef, scalar @{$logs});
}

##########################################################
sub _normalize_version_number {
    my($version) = @_;
    my $num   = 0;
    my $power = 6;
    for my $part (split/\./mx, $version) {
        if($part =~ /(\d+)/mx) {
            $num += $1 * 10**$power;
        }
        $power -= 3;
    }
    return(int($num));
}

##########################################################
sub _add_service_prefix {
    my($list) = @_;
    my $newlist = [];
    for my $el (@{$list}) {
        my $item = "$el";
        if($item !~ m/^host_/mx) {
            $item =~ s/^/service_/gmx;
        }
        push @{$newlist}, $item;
    }
    return($newlist);
}

##########################################################
sub _clean_columns {
    my($self, $table, $columns) = @_;

    # last_update is a naemon / lmd specific column
    if(!$self->{'lmd_optimizations'} && !$self->{'naemon_optimizations'}) {
        $columns = Thruk::Base::array_remove($columns, "last_update");
    }

    if($table eq 'contacts') {
        # icinga 2 does not know about those columns
        if(!$self->{'lmd_optimizations'} && !$self->{'naemon_optimizations'}) {
            $columns = Thruk::Base::array_remove($columns, "id");
            $columns = Thruk::Base::array_remove($columns, "groups");
            $columns = Thruk::Base::array_remove($columns, "custom_variable_names");
            $columns = Thruk::Base::array_remove($columns, "custom_variable_values");
            $columns = Thruk::Base::array_remove($columns, "host_notification_commands");
            $columns = Thruk::Base::array_remove($columns, "service_notification_commands");
            $columns = Thruk::Base::array_remove($columns, "address1");
            $columns = Thruk::Base::array_remove($columns, "address2");
            $columns = Thruk::Base::array_remove($columns, "address3");
            $columns = Thruk::Base::array_remove($columns, "address4");
            $columns = Thruk::Base::array_remove($columns, "address5");
        }
    }

    return($columns);
}

##########################################################

1;
