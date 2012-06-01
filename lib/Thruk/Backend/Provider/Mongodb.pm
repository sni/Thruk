package Thruk::Backend::Provider::Mongodb;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use Thruk::Utils;
use Digest::MD5 qw/md5_hex/;
use MongoDB;
use Tie::IxHash;
use parent 'Thruk::Backend::Provider::Base';

=head1 NAME

Thruk::Backend::Provider::Mongodb - connection provider for mongodb connections

=head1 DESCRIPTION

connection provider for mongodb connections

=head1 METHODS

##########################################################

=head2 new

create new manager

=cut
sub new {
    my( $class, $peer_config, $config, $log ) = @_;

    die("need at least one peer. Minimal options are <options>peer = mongodb_host:port/dbname</options>\ngot: ".Dumper($peer_config)) unless defined $peer_config->{'peer'};

    $peer_config->{'name'} = 'mongo' unless defined $peer_config->{'name'};
    if(!defined $peer_config->{'peer_key'}) {
        my $key = md5_hex($peer_config->{'name'}.$peer_config->{'peer'});
        $peer_config->{'peer_key'} = $key;
    }
    my($dbhost, $dbname);
    if($peer_config->{'peer'} =~ m/^(.*):(\d+)\/(.*)$/mx) {
        $dbhost = $1.":".$2;
        $dbname = $3;
    } else {
        die("mongodb connection must match this form: mongodb_host:port/dbname");
    }

    my $self = {
        'dbhost'      => $dbhost,
        'dbname'      => $dbname,
        'config'      => $config,
        'peer_config' => $peer_config,
        'log'         => $log,
        'stash'       => undef,
        'verbose'     => 0,
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
    delete $self->{'mongo'};
    $self->_db();
    return;
}

##########################################################

=head2 _db

try to connect to db

=cut
sub _db {
    my($self) = @_;
    if(!defined $self->{'mongo'}) {
        $self->{'mongo'} = MongoDB::Connection->new(
                                        host           =>  $self->{'dbhost'},
                                        auto_connect   => 1,
                                        auto_reconnect => 1,
                           );
    }
    my $dbname = $self->{'dbname'};
    return $self->{'mongo'}->$dbname;
}

##########################################################

=head2 peer_key

return the peers key

=cut
sub peer_key {
    my($self, $new_val) = @_;
    if(defined $new_val) {
        $self->{'peer_config'}->{'peer_key'} = $new_val;
    }
    return $self->{'peer_config'}->{'peer_key'};
}


##########################################################

=head2 peer_addr

return the peers address

=cut
sub peer_addr {
    my $self = shift;
    return $self->{'peer_config'}->{'peer'};
}

##########################################################

=head2 peer_name

return the peers name

=cut
sub peer_name {
    my $self = shift;
    return $self->{'peer_config'}->{'name'};
}

##########################################################

=head2 send_command

send a command

=cut
sub send_command {
    my($self, %options) = @_;
    cluck("empty command") if (!defined $options{'command'} or $options{'command'} eq '');
    if($options{'command'} !~ m/^COMMAND\ \[(\d+)\]\ (.*)$/mx) {
        cluck("unknown command");
    }
    my $timestamp = $1;
    my $cmd       = $2;
    $self->_db->cmd
              ->insert({cmd  => $cmd,
                        time => $timestamp,
                      });
    return;
}

##########################################################

=head2 get_processinfo

return the process info

=cut
sub get_processinfo {
    my $self  = shift;
    my $cache = shift;

    my $data = {
        $self->peer_key() => $self->_db->status
                                       ->find_one()
    };
    $self->{'last_program_start'}  = $data->{$self->peer_key()}->{'program_start'};
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

    my @data = $self->_db->contacts
                         ->find({ name => $user })
                         ->fields({can_submit_commands => 1, alias => 1})
                         ->all;
    return \@data;
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
    my($self,$username) = @_;
    confess("no user") unless defined $username;

    my @data = $self->_db->contactgroups
                         ->find({ members => $username })
                         ->fields({name => 1})
                         ->all;
    return \@data;
}

##########################################################

=head2 get_hosts

  get_hosts

returns a list of hosts

=cut
sub get_hosts {
    my($self, %options) = @_;

    unless(wantarray) {
        confess("get_hosts() should not be called in scalar context");
    }

    my @data = $self->_db->hosts
                         ->find($self->_get_filter($options{'filter'}))
                         ->all;
    my $size = scalar @data;
    $self->_add_peer_data(\@data);
    return(\@data, undef, $size);

#    # try to reduce the amount of transfered data
#    my($size, $limit) = $self->_get_query_size('hosts', \%options, 'name', 'name');
#    if(defined $size) {
#        # then set the limit for the real query
#        $options{'options'}->{'limit'} = $limit + 50;
#    }
#
#        if($self->{'stash'}->{'enable_shinken_features'}) {
#            push @{$options{'columns'}},  qw/is_impact source_problems impacts criticity is_problem
#                                             got_business_rule parent_dependencies/;
#        }
#        if(defined $options{'extra_columns'}) {
#            push @{$options{'columns'}}, @{$options{'extra_columns'}};
#        }
#    }
#
#    $options{'options'}->{'callbacks'}->{'last_state_change_plus'} = sub { return $_[0]->{'last_state_change'} || $self->{'last_program_start'}; };
#    my $data = $self->_get_table('hosts', \%options);
#
#
#    return($data, undef, $size);
}

##########################################################

=head2 get_hosts_by_servicequery

  get_hosts_by_servicequery

returns a list of host by a services query

=cut
sub get_hosts_by_servicequery {
    my($self, %options) = @_;

    unless(wantarray) {
        confess("get_hosts_by_servicequery() should not be called in scalar context");
    }

    my @data = $self->_db->services
                         ->find($self->_get_filter($options{'filter'}))
                         ->fields({
                               host_has_been_checked => 1,
                               host_name             => 1,
                               host_state            => 1,
                           })
                         ->all;

    return(\@data, undef);
}

##########################################################

=head2 get_host_names

  get_host_names

returns a list of host names

=cut
sub get_host_names{
    my($self, %options) = @_;

    unless(wantarray) {
        confess("get_host_names () should not be called in scalar context");
    }

    my @data = $self->_db->hosts
                         ->find($self->_get_filter($options{'filter'}))
                         ->fields({'name' => 1})
                         ->all;
    my @result = ();
    for my $d (@data) { push @result, $d->{name} }
    return(\@result, 'uniq');
}

##########################################################

=head2 get_hostgroups

  get_hostgroups

returns a list of hostgroups

=cut
sub get_hostgroups {
    my($self, %options) = @_;

    my @data = $self->_db->hostgroups
                         ->find($self->_get_filter($options{'filter'}))
                         ->fields({name =>1 , alias => 1, members => 1, action_url => 1, notes => 1, notes_url => 1})
                         ->all;
    $self->_add_peer_data(\@data);
    return \@data;
}

##########################################################

=head2 get_hostgroup_names

  get_hostgroup_names

returns a list of hostgroup names

=cut
sub get_hostgroup_names {
    my($self, %options) = @_;

    unless(wantarray) {
        confess("get_hostgroup_names() should not be called in scalar context");
    }

    my @data = $self->_db->hostgroups
                         ->find($self->_get_filter($options{'filter'}))
                         ->fields({name =>1})
                         ->all;

    my @result = ();
    for my $d (@data) { push @result, $d->{name} }
    return(\@result, 'uniq');
}

##########################################################

=head2 get_services

  get_services

returns a list of services

=cut
sub get_services {
    my($self, %options) = @_;

    unless(wantarray) {
        confess("get_services() should not be called in scalar context");
    }

    my @data = $self->_db->services
                         ->find($self->_get_filter($options{'filter'}))
                         ->all;
    my $size = scalar @data;
    $self->_add_peer_data(\@data);
    return(\@data, undef, $size);

    ## try to reduce the amount of transfered data
    #my($size, $limit) = $self->_get_query_size('services', \%options, 'description', 'host_name', 'description');
    #if(defined $size) {
    #    # then set the limit for the real query
    #    $options{'options'}->{'limit'} = $limit + 50;
    #}

    #unless(defined $options{'columns'}) {
    #    $options{'columns'} = [qw/
    #        accept_passive_checks acknowledged action_url action_url_expanded
    #        active_checks_enabled check_command check_interval check_options
    #        check_period check_type checks_enabled comments current_attempt
    #        current_notification_number description event_handler event_handler_enabled
    #        custom_variable_names custom_variable_values
    #        execution_time first_notification_delay flap_detection_enabled groups
    #        has_been_checked high_flap_threshold host_acknowledged host_action_url_expanded
    #        host_active_checks_enabled host_address host_alias host_checks_enabled host_check_type
    #        host_comments host_groups host_has_been_checked host_icon_image_expanded host_icon_image_alt
    #        host_is_executing host_is_flapping host_name host_notes_url_expanded
    #        host_notifications_enabled host_scheduled_downtime_depth host_state host_accept_passive_checks
    #        icon_image icon_image_alt icon_image_expanded is_executing is_flapping
    #        last_check last_notification last_state_change latency long_plugin_output
    #        low_flap_threshold max_check_attempts next_check notes notes_expanded
    #        notes_url notes_url_expanded notification_interval notification_period
    #        notifications_enabled obsess_over_service percent_state_change perf_data
    #        plugin_output process_performance_data retry_interval scheduled_downtime_depth
    #        state state_type modified_attributes_list
    #        last_time_critical last_time_ok last_time_unknown last_time_warning
    #        display_name host_display_name host_custom_variable_names host_custom_variable_values
    #    /];

    #    if($self->{'stash'}->{'enable_shinken_features'}) {
    #        push @{$options{'columns'}},  qw/is_impact source_problems impacts criticity is_problem
    #                                         got_business_rule parent_dependencies/;
    #    }
    #    if(defined $options{'extra_columns'}) {
    #        push @{$options{'columns'}}, @{$options{'extra_columns'}};
    #    }
    #}


    #$options{'options'}->{'callbacks'}->{'last_state_change_plus'} = sub { return $_[0]->{'last_state_change'} || $self->{'last_program_start'}; };
    # make it possible to order by state
    #if(grep {/^state$/mx} @{$options{'columns'}}) {
    #    $options{'options'}->{'callbacks'}->{'state_order'}        = sub { return 4 if $_[0]->{'state'} == 2; return $_[0]->{'state'} };
    #}
    #my $data = $self->_get_table('services', \%options);
    #unless(wantarray) {
    #    confess("get_services() should not be called in scalar context");
    #}

    #return($data, undef, $size);
}

##########################################################

=head2 get_service_names

  get_service_names

returns a list of service names

=cut
sub get_service_names {
    my($self, %options) = @_;

    unless(wantarray) {
        confess("get_service_names() should not be called in scalar context");
    }

    my @data = $self->_db->services
                         ->find($self->_get_filter($options{'filter'}))
                         ->fields({description =>1})
                         ->all;

    my @result = ();
    for my $d (@data) { push @result, $d->{description} }
    return(\@result, 'uniq');
}

##########################################################

=head2 get_servicegroups

  get_servicegroups

returns a list of servicegroups

=cut
sub get_servicegroups {
    my($self, %options) = @_;

    my @data = $self->_db->servicegroups
                         ->find($self->_get_filter($options{'filter'}))
                         ->fields({name =>1 , alias => 1, members => 1, action_url => 1, notes => 1, notes_url => 1})
                         ->all;
    $self->_add_peer_data(\@data);
    return \@data;
}

##########################################################

=head2 get_servicegroup_names

  get_servicegroup_names

returns a list of servicegroup names

=cut
sub get_servicegroup_names {
    my($self, %options) = @_;
    unless(wantarray) {
        confess("get_servicegroup_names() should not be called in scalar context");
    }

    my @data = $self->_db->servicegroups
                         ->find($self->_get_filter($options{'filter'}))
                         ->fields({name =>1})
                         ->all;

    my @result = ();
    for my $d (@data) { push @result, $d->{name} }
    return(\@result, 'uniq');
}

##########################################################

=head2 get_comments

  get_comments

returns a list of comments

=cut
sub get_comments {
    my($self, %options) = @_;

    my @data = $self->_db->comments
                         ->find($self->_get_filter($options{'filter'}))
                         ->all;
    return(\@data);
}

##########################################################

=head2 get_downtimes

  get_downtimes

returns a list of downtimes

=cut
sub get_downtimes {
    my($self, %options) = @_;

    my @data = $self->_db->comments
                         ->find($self->_get_filter($options{'filter'}))
                         ->all;
    return(\@data);
}

##########################################################

=head2 get_contactgroups

  get_contactgroups

returns a list of contactgroups

=cut
sub get_contactgroups {
    my($self, %options) = @_;
    my @data = $self->_db->contactgroups
                         ->find($self->_get_filter($options{'filter'}))
                         ->all;
    return(\@data);
}

##########################################################

=head2 get_logs

  get_logs

returns logfile entries

=cut
sub get_logs {
    my($self, %options) = @_;
    my @data;
    my $sort = {'time' => 1};
    if(defined $options{'sort'}->{'DESC'} and $options{'sort'}->{'DESC'} eq 'time') {
        $sort = {'time' => -1};
    }
    @data = $self->_db->logs
                      ->find($self->_get_filter($options{'filter'}))
                      ->sort($sort)
                      ->all;
    return(\@data, 'sorted');
}

##########################################################

=head2 get_timeperiods

  get_timeperiods

returns a list of timeperiods

=cut
sub get_timeperiods {
    my($self, %options) = @_;
    my @data = $self->_db->timeperiods
                         ->find($self->_get_filter($options{'filter'}))
                         ->all;
    return(\@data);
}

##########################################################

=head2 get_timeperiod_names

  get_timeperiod_names

returns a list of timeperiod names

=cut
sub get_timeperiod_names {
    my($self, %options) = @_;

    unless(wantarray) {
        confess("get_timeperiods_names() should not be called in scalar context");
    }

    my @data = $self->_db->timeperiods
                         ->find($self->_get_filter($options{'filter'}))
                         ->fields({'name' => 1})
                         ->all;
    my @result = ();
    for my $d (@data) { push @result, $d->{name} }
    return(\@result, 'uniq');
}

##########################################################

=head2 get_commands

  get_commands

returns a list of commands

=cut
sub get_commands {
    my($self, %options) = @_;
    my @data = $self->_db->commands
                         ->find($self->_get_filter($options{'filter'}))
                         ->all;
    return(\@data);
}

##########################################################

=head2 get_contacts

  get_contacts

returns a list of contacts

=cut
sub get_contacts {
    my($self, %options) = @_;
    my @data = $self->_db->contacts
                         ->find($self->_get_filter($options{'filter'}))
                         ->all;
    return(\@data);
}

##########################################################

=head2 get_contact_names

  get_contact_names

returns a list of contact names

=cut
sub get_contact_names {
    my($self, %options) = @_;

    unless(wantarray) {
        confess("get_contact_names() should not be called in scalar context");
    }

    my @data = $self->_db->contacts
                         ->find($self->_get_filter($options{'filter'}))
                         ->fields({'name' => 1})
                         ->all;
    my @result = ();
    for my $d (@data) { push @result, $d->{name} }
    return(\@result, 'uniq');
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
                                    # TODO: fix
                                    options => { rename => { 'name' => 'host_name' }, callbacks => { 'description' => sub { return ''; } } }
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

    unless(wantarray) {
        confess("get_host_stats() should not be called in scalar context");
    }

    # TODO: implement %options

    my $map = "function() {
    var state = {
        total: 0,
        total_active: 0,
        total_passive: 0,
        pending: 0,
        pending_and_disabled: 0,
        pending_and_scheduled: 0,
        up: 0,
        up_and_disabled_active: 0,
        up_and_disabled_passive: 0,
        up_and_scheduled: 0,
        down: 0,
        down_and_ack: 0,
        down_and_scheduled: 0,
        down_and_disabled_active: 0,
        down_and_disabled_passive: 0,
        down_and_unhandled: 0,
        unreachable: 0,
        unreachable_and_ack: 0,
        unreachable_and_scheduled: 0,
        unreachable_and_disabled_active: 0,
        unreachable_and_disabled_passive: 0,
        unreachable_and_unhandled: 0,
        flapping: 0,
        flapping_disabled: 0,
        notifications_disabled: 0,
        eventhandler_disabled: 0,
        active_checks_disabled_active: 0,
        active_checks_disabled_passive: 0,
        passive_checks_disabled: 0,
        outages: 0
    };

    state.total++;
    if(this.check_type == 0) { state.total_active++ }
    if(this.check_type == 1) { state.total_passive++ }
    if(this.has_been_checked == 0) { state.pending++ }
    if(this.has_been_checked == 0 && this.active_checks_enabled == 0) { state.pending_and_disabled++ }
    if(this.has_been_checked == 0 && this.scheduled_downtime_depth > 0) { state.pending_and_scheduled++ }
    if(this.has_been_checked == 1 && this.state == 0 ) { state.up++ }
    if(this.check_type == 0 && this.has_been_checked == 1 && this.state == 0 && this.active_checks_enabled == 0 ) { state.up_and_disabled_active++ }
    if(this.check_type == 1 && this.has_been_checked == 1 && this.state == 0 && this.active_checks_enabled == 0 ) { state.up_and_disabled_passive++ }
    if(this.has_been_checked == 1 && this.state == 0 && this.scheduled_downtime_depth > 0 ) { state.up_and_scheduled++ }
    if(this.state == 1) {
        if(this.has_been_checked == 1) { state.down++ }
        if(this.has_been_checked == 1 && this.acknowledged == 1) { state.down_and_ack++ }
        if(this.has_been_checked == 1 && this.scheduled_downtime_depth > 0 ) { state.down_and_scheduled++ }
        if(this.check_type == 0 && this.has_been_checked == 1 && this.active_checks_enabled == 0 ) { state.down_and_disabled_active++ }
        if(this.check_type == 1 && this.has_been_checked == 1 && this.active_checks_enabled == 0 ) { state.down_and_disabled_passive++ }
        if(this.has_been_checked == 1 && this.active_checks_enabled == 0 && this.acknowledged == 0 && this.scheduled_downtime_depth == 0) { state.down_and_unhandled++ }
    }
    if(this.state == 2) {
        if(this.has_been_checked == 1) { state.unreachable++ }
        if(this.has_been_checked == 1 && this.acknowledged == 1) { state.unreachable_and_ack++ }
        if(this.has_been_checked == 1 && this.scheduled_downtime_depth > 0 ) { state.unreachable_and_scheduled++ }
        if(this.check_type == 0 && this.has_been_checked == 1 && this.active_checks_enabled == 0 ) { state.unreachable_and_disabled_active++ }
        if(this.check_type == 1 && this.has_been_checked == 1 && this.active_checks_enabled == 0 ) { state.unreachable_and_disabled_passive++ }
        if(this.has_been_checked == 1 && this.active_checks_enabled == 0 && this.acknowledged == 0 && this.scheduled_downtime_depth == 0) { state.unreachable_and_unhandled++ }
    }
    if(this.is_flapping == 1) { state.flapping++ }
    if(this.flap_detection_enabled == 0) { state.flapping_disabled++ }
    if(this.notifications_enabled == 0) { state.notifications_disabled++ }
    if(this.event_handler_enabledq == 0) { state.eventhandler_disabled++ }
    if(this.check_type == 0 && this.active_checks_enabled == 0) { state.active_checks_disabled_active++ }
    if(this.check_type == 1 && this.active_checks_enabled == 0) { state.active_checks_disabled_passive++ }
    if(this.accept_passive_checks == 0) { state.passive_checks_disabled++ }
    if(this.state == 1 && this.childs.length > 0) { state.outages++ }

    emit( 'res', state );
}";
    my $reduce = "function(key, values) {
    var stats = {
        total: 0,
        total_active: 0,
        total_passive: 0,
        pending: 0,
        pending_and_disabled: 0,
        pending_and_scheduled: 0,
        up: 0,
        up_and_disabled_active: 0,
        up_and_disabled_passive: 0,
        up_and_scheduled: 0,
        down: 0,
        down_and_ack: 0,
        down_and_scheduled: 0,
        down_and_disabled_active: 0,
        down_and_disabled_passive: 0,
        down_and_unhandled: 0,
        unreachable: 0,
        unreachable_and_ack: 0,
        unreachable_and_scheduled: 0,
        unreachable_and_disabled_active: 0,
        unreachable_and_disabled_passive: 0,
        unreachable_and_unhandled: 0,
        flapping: 0,
        flapping_disabled: 0,
        notifications_disabled: 0,
        eventhandler_disabled: 0,
        active_checks_disabled_active: 0,
        active_checks_disabled_passive: 0,
        passive_checks_disabled: 0,
        outages: 0
    };
    values.forEach(function(value) {
      stats.total                            += value.total;
      stats.total_active                     += value.total_active;
      stats.total_passive                    += value.total_passive;
      stats.pending                          += value.pending;
      stats.pending_and_disabled             += value.pending_and_disabled;
      stats.pending_and_scheduled            += value.pending_and_scheduled;
      stats.up                               += value.up;
      stats.up_and_disabled_active           += value.up_and_disabled_active;
      stats.up_and_disabled_passive          += value.up_and_disabled_passive;
      stats.up_and_scheduled                 += value.up_and_scheduled;
      stats.down                             += value.down;
      stats.down_and_ack                     += value.down_and_ack;
      stats.down_and_scheduled               += value.down_and_scheduled;
      stats.down_and_disabled_active         += value.down_and_disabled_active;
      stats.down_and_disabled_passive        += value.down_and_disabled_passive;
      stats.down_and_unhandled               += value.down_and_unhandled;
      stats.unreachable                      += value.unreachable;
      stats.unreachable_and_ack              += value.unreachable_and_ack;
      stats.unreachable_and_scheduled        += value.unreachable_and_scheduled;
      stats.unreachable_and_disabled_active  += value.unreachable_and_disabled_active;
      stats.unreachable_and_disabled_passive += value.unreachable_and_disabled_passive;
      stats.unreachable_and_unhandled        += value.unreachable_and_unhandled;
      stats.flapping                         += value.flapping;
      stats.flapping_disabled                += value.flapping_disabled;
      stats.notifications_disabled           += value.notifications_disabled;
      stats.eventhandler_disabled            += value.eventhandler_disabled;
      stats.active_checks_disabled_active    += value.active_checks_disabled_active;
      stats.active_checks_disabled_passive   += value.active_checks_disabled_passive;
      stats.passive_checks_disabled          += value.passive_checks_disabled;
      stats.outages                          += value.outages;
    });
    return stats;
}";

    my $cmd    = Tie::IxHash->new(
        'mapreduce' => 'hosts',
        'map'       => $map,
        'reduce'    => $reduce,
        'out'       => { inline => 1},
    );
    my $result = $self->_db->run_command($cmd);
    if(ref $result eq 'HASH') {
        return($result->{'results'}->[0]->{'value'}, 'SUM');
    } else {
        die($result);
    }
}

##########################################################

=head2 get_service_stats

  get_service_stats

returns the services statistics for the tac page

=cut
sub get_service_stats {
    my($self, %options) = @_;


    unless(wantarray) {
        confess("get_service_stats() should not be called in scalar context");
    }

    # TODO: implement %options

    my $map = "function() {
    var state = {
        total: 0,
        total_active: 0,
        total_passive: 0,
        pending: 0,
        pending_and_disabled: 0,
        pending_and_scheduled: 0,
        ok: 0,
        ok_and_scheduled: 0,
        ok_and_disabled_active: 0,
        ok_and_disabled_passive: 0,
        warning: 0,
        warning_and_scheduled: 0,
        warning_and_disabled_active: 0,
        warning_and_disabled_passive: 0,
        warning_and_ack: 0,
        warning_on_down_host: 0,
        warning_and_unhandled: 0,
        critical: 0,
        critical_and_scheduled: 0,
        critical_and_disabled_active: 0,
        critical_and_disabled_passive: 0,
        critical_and_ack: 0,
        critical_on_down_host: 0,
        critical_and_unhandled: 0,
        unknown: 0,
        unknown_and_scheduled: 0,
        unknown_and_disabled_active: 0,
        unknown_and_disabled_passive: 0,
        unknown_and_ack: 0,
        unknown_on_down_host: 0,
        unknown_and_unhandled: 0,
        flapping: 0,
        flapping_disabled: 0,
        notifications_disabled: 0,
        eventhandler_disabled: 0,
        active_checks_disabled_active: 0,
        active_checks_disabled_passive: 0,
        passive_checks_disabled: 0,
    };

    state.total++;
    if(this.check_type == 0) { state.total_active++ }
    if(this.check_type == 1) { state.total_passive++ }
    if(this.has_been_checked == 0) { state.pending++ }
    if(this.has_been_checked == 0 && this.active_checks_enabled == 0) { state.pending_and_disabled++ }
    if(this.has_been_checked == 0 && this.scheduled_downtime_depth > 0) { state.pending_and_scheduled++ }

    if(this.state == 0) {
        if(this.has_been_checked == 1) { state.ok ++ }
        if(this.has_been_checked == 1 && this.scheduled_downtime_depth > 0) { state.ok_and_scheduled++ }
        if(this.check_type == 0 && this.has_been_checked == 1 && this.active_checks_enabled == 0) { state.ok_and_disabled_active++ }
        if(this.check_type == 1 && this.has_been_checked == 1 && this.active_checks_enabled == 0) { state.ok_and_disabled_passive++ }
    }
    if(this.state == 1) {
        if(this.has_been_checked == 1) { state.warning++ }
        if(this.has_been_checked == 1 && this.scheduled_downtime_depth > 0) { state.warning_and_scheduled++ }
        if(this.check_type == 0 && this.has_been_checked == 1 && this.active_checks_enabled == 0) { state.warning_and_disabled_active++ }
        if(this.check_type == 1 && this.has_been_checked == 1 && this.active_checks_enabled == 0) { state.warning_and_disabled_passive++ }
        if(this.has_been_checked == 1 && this.acknowledged == 1) { state.warning_and_ack++ }
        if(this.has_been_checked == 1 && this.host_state != 0) { state.warning_on_down_host++ }
        if(this.has_been_checked == 1 && this.host_state == 0 && this.active_checks_enabled == 1 && this.acknowledged == 0 && this.scheduled_downtime_depth == 0) { state.warning_and_unhandled++ }
    }
    if(this.state == 2) {
        if(this.has_been_checked == 1) { state.critical++ }
        if(this.has_been_checked == 1 && this.scheduled_downtime_depth > 0) { state.critical_and_scheduled++ }
        if(this.check_type == 0 && this.has_been_checked == 1 && this.active_checks_enabled == 0) { state.critical_and_disabled_active++ }
        if(this.check_type == 1 && this.has_been_checked == 1 && this.active_checks_enabled == 0) { state.critical_and_disabled_passive++ }
        if(this.has_been_checked == 1 && this.acknowledged == 1) { state.critical_and_ack++ }
        if(this.has_been_checked == 1 && this.host_state != 0) { state.critical_on_down_host++ }
        if(this.has_been_checked == 1 && this.host_state == 0 && this.active_checks_enabled == 1 && this.acknowledged == 0 && this.scheduled_downtime_depth == 0) { state.critical_and_unhandled++ }
    }
    if(this.state == 3) {
        if(this.has_been_checked == 1) { state.unknown++ }
        if(this.has_been_checked == 1 && this.scheduled_downtime_depth > 0) { state.unknown_and_scheduled++ }
        if(this.check_type == 0 && this.has_been_checked == 1 && this.active_checks_enabled == 0) { state.unknown_and_disabled_active++ }
        if(this.check_type == 1 && this.has_been_checked == 1 && this.active_checks_enabled == 0) { state.unknown_and_disabled_passive++ }
        if(this.has_been_checked == 1 && this.acknowledged == 1) { state.unknown_and_ack++ }
        if(this.has_been_checked == 1 && this.host_state != 0) { state.unknown_on_down_host++ }
        if(this.has_been_checked == 1 && this.host_state == 0 && this.active_checks_enabled == 1 && this.acknowledged == 0 && this.scheduled_downtime_depth == 0) { state.unknown_and_unhandled++ }
    }
    if(this.is_flapping == 1) { state.flapping++ }
    if(this.flap_detection_enabled == 0) { state.flapping_disabled++ }
    if(this.notifications_enabled == 0) { state.notifications_disabled++ }
    if(this.event_handler_enabledq == 0) { state.eventhandler_disabled++ }
    if(this.check_type == 0 && this.active_checks_enabled == 0) { state.active_checks_disabled_active++ }
    if(this.check_type == 1 && this.active_checks_enabled == 0) { state.active_checks_disabled_passive++ }
    if(this.accept_passive_checks == 0) { state.passive_checks_disabled++ }

    emit( 'res', state );
}";

    my $reduce = "function(key, values) {
    var stats = {
        total: 0,
        total_active: 0,
        total_passive: 0,
        pending: 0,
        pending_and_disabled: 0,
        pending_and_scheduled: 0,
        ok: 0,
        ok_and_scheduled: 0,
        ok_and_disabled_active: 0,
        ok_and_disabled_passive: 0,
        warning: 0,
        warning_and_scheduled: 0,
        warning_and_disabled_active: 0,
        warning_and_disabled_passive: 0,
        warning_and_ack: 0,
        warning_on_down_host: 0,
        warning_and_unhandled: 0,
        critical: 0,
        critical_and_scheduled: 0,
        critical_and_disabled_active: 0,
        critical_and_disabled_passive: 0,
        critical_and_ack: 0,
        critical_on_down_host: 0,
        critical_and_unhandled: 0,
        unknown: 0,
        unknown_and_scheduled: 0,
        unknown_and_disabled_active: 0,
        unknown_and_disabled_passive: 0,
        unknown_and_ack: 0,
        unknown_on_down_host: 0,
        unknown_and_unhandled: 0,
        flapping: 0,
        flapping_disabled: 0,
        notifications_disabled: 0,
        eventhandler_disabled: 0,
        active_checks_disabled_active: 0,
        active_checks_disabled_passive: 0,
        passive_checks_disabled: 0,
    };
    values.forEach(function(value) {
      stats.total                            += value.total;
      stats.total_active                     += value.total_active;
      stats.total_passive                    += value.total_passive;
      stats.pending                          += value.pending;
      stats.pending_and_disabled             += value.pending_and_disabled;
      stats.pending_and_scheduled            += value.pending_and_scheduled;
      stats.ok                              += value.ok;
      stats.ok_and_scheduled                += value.ok_and_scheduled;
      stats.ok_and_disabled_active          += value.ok_and_disabled_active;
      stats.ok_and_disabled_passive         += value.ok_and_disabled_passive;
      stats.warning                         += value.warning;
      stats.warning_and_scheduled           += value.warning_and_scheduled;
      stats.warning_and_disabled_active     += value.warning_and_disabled_active;
      stats.warning_and_disabled_passive    += value.warning_and_disabled_passive;
      stats.warning_and_ack                 += value.warning_and_ack;
      stats.warning_on_down_host            += value.warning_on_down_host;
      stats.warning_and_unhandled           += value.warning_and_unhandled;
      stats.critical                        += value.critical;
      stats.critical_and_scheduled          += value.critical_and_scheduled;
      stats.critical_and_disabled_active    += value.critical_and_disabled_active;
      stats.critical_and_disabled_passive   += value.critical_and_disabled_passive;
      stats.critical_and_ack                += value.critical_and_ack;
      stats.critical_on_down_host           += value.critical_on_down_host;
      stats.critical_and_unhandled          += value.critical_and_unhandled;
      stats.unknown                         += value.unknown;
      stats.unknown_and_scheduled           += value.unknown_and_scheduled;
      stats.unknown_and_disabled_active     += value.unknown_and_disabled_active;
      stats.unknown_and_disabled_passive    += value.unknown_and_disabled_passive;
      stats.unknown_and_ack                 += value.unknown_and_ack;
      stats.unknown_on_down_host            += value.unknown_on_down_host;
      stats.unknown_and_unhandled           += value.unknown_and_unhandled;
      stats.flapping                        += value.flapping;
      stats.flapping_disabled               += value.flapping_disabled;
      stats.notifications_disabled          += value.notifications_disabled;
      stats.eventhandler_disabled           += value.eventhandler_disabled;
      stats.active_checks_disabled_active   += value.active_checks_disabled_active;
      stats.active_checks_disabled_passive  += value.active_checks_disabled_passive;
      stats.passive_checks_disabled         += value.passive_checks_disabled;
    });
    return stats;
}";


    my $cmd    = Tie::IxHash->new(
        'mapreduce' => 'hosts',
        'map'       => $map,
        'reduce'    => $reduce,
        'out'       => { inline => 1},
    );
    my $result = $self->_db->run_command($cmd);
    if(ref $result eq 'HASH') {
        return($result->{'results'}->[0]->{'value'}, 'SUM');
    } else {
        die($result);
    }
}

##########################################################

=head2 get_performance_stats

  get_performance_stats

returns the service /host execution statistics

=cut
sub get_performance_stats {
    my($self, %options) = @_;

    # TODO: implement %options

    my $now    = time();
    my $min1   = $now - 60;
    my $min5   = $now - 300;
    my $min15  = $now - 900;
    my $min60  = $now - 3600;
    my $minall = $self->{'last_program_start'};

    my $map = "function() {
    var state = {
        active_sum: 0,
        active_1_sum: 0,
        active_5_sum: 0,
        active_15_sum: 0,
        active_60_sum: 0,
        active_all_sum: 0,

        passive_sum: 0,
        passive_1_sum: 0,
        passive_5_sum: 0,
        passive_15_sum: 0,
        passive_60_sum: 0,
        passive_all_sum: 0,

        execution_time: undefined,
        latency: undefined,
        active_state_change: undefined,
        passive_state_change: undefined
    };

    if(this.check_type == 0) {
        state.active_sum++;
        if(this.has_been_checked == 1) {
            if(this.last_check >= $min1) { state.active_1_sum++ }
            if(this.last_check >= $min5) { state.active_5_sum++ }
            if(this.last_check >= $min15) { state.active_15_sum++ }
            if(this.last_check >= $min60) { state.active_60_sum++ }
            if(this.last_check >= $minall) { state.active_all_sum++ }
        }
    }

    if(this.check_type == 1) {
        state.passive_sum++;
        if(this.has_been_checked == 1) {
            if(this.last_check >= $min1) { state.passive_1_sum++ }
            if(this.last_check >= $min5) { state.passive_5_sum++ }
            if(this.last_check >= $min15) { state.passive_15_sum++ }
            if(this.last_check >= $min60) { state.passive_60_sum++ }
            if(this.last_check >= $minall) { state.passive_all_sum++ }
        }
    }

    if(this.has_been_checked == 1) {
        if(this.check_type == 0) {
            state.execution_time        = this.execution_time;
            state.latency               = this.latency;
            state.active_state_change   = this.percent_state_change;
        }
        if(this.check_type == 1) {
            state.passive_state_change   = this.percent_state_change;
        }
    }

    emit( 'res', state );
}";
    my $reduce = "function(key, values) {
    var stats = {
        active_sum: 0,
        active_1_sum: 0,
        active_5_sum: 0,
        active_15_sum: 0,
        active_60_sum: 0,
        active_all_sum: 0,

        passive_sum: 0,
        passive_1_sum: 0,
        passive_5_sum: 0,
        passive_15_sum: 0,
        passive_60_sum: 0,
        passive_all_sum: 0,

        execution_time_sum: 0,
        execution_time_min: undefined,
        execution_time_max: 0,
        latency_sum: 0,
        latency_min: undefined,
        latency_max: 0,
        active_state_change_sum: 0,
        active_state_change_min: undefined,
        active_state_change_max: 0,
        passive_state_change_sum: 0,
        passive_state_change_min: undefined,
        passive_state_change_max: 0
    };
    values.forEach(function(value) {
      stats.active_sum      += value.active_sum;
      stats.active_1_sum    += value.active_1_sum;
      stats.active_5_sum    += value.active_5_sum;
      stats.active_15_sum   += value.active_15_sum;
      stats.active_60_sum   += value.active_60_sum;
      stats.active_all_sum  += value.active_all_sum;

      stats.passive_sum     += value.passive_sum;
      stats.passive_1_sum   += value.passive_1_sum;
      stats.passive_5_sum   += value.passive_5_sum;
      stats.passive_15_sum  += value.passive_15_sum;
      stats.passive_60_sum  += value.passive_60_sum;
      stats.passive_all_sum += value.passive_all_sum;

      if(value.execution_time != undefined) {
        stats.execution_time_sum      += value.execution_time;
        if(stats.execution_time_min == undefined) { stats.execution_time_min = value.execution_time }
        if(value.execution_time > stats.execution_time_max) { stats.execution_time_max = value.execution_time }
        if(value.execution_time < stats.execution_time_min) { stats.execution_time_min = value.execution_time }
      }

      if(value.latency != undefined) {
        stats.latency_sum             += value.latency;
        if(stats.latency_min == undefined) { stats.latency_min = value.latency }
        if(value.latency > stats.latency_max) { stats.latency_max = value.latency }
        if(value.latency < stats.latency_min) { stats.latency_min = value.latency }
      }

      if(value.active_state_change != undefined) {
        stats.active_state_change_sum += value.active_state_change;
        if(stats.active_state_change_min == undefined) { stats.active_state_change_min = value.active_state_change }
        if(value.active_state_change > stats.active_state_change_max) { stats.active_state_change_max = value.active_state_change }
        if(value.active_state_change < stats.active_state_change_min) { stats.active_state_change_min = value.active_state_change }
      }

      if(value.passive_state_change != undefined) {
        stats.passive_state_change_sum += value.passive_state_change;
        if(stats.passive_state_change_min == undefined) { stats.passive_state_change_min = value.passive_state_change }
        if(value.passive_state_change > stats.passive_state_change_max) { stats.passive_state_change_max = value.passive_state_change }
        if(value.passive_state_change < stats.passive_state_change_min) { stats.passive_state_change_min = value.passive_state_change }
      }
    });
    return stats;
}";

    my $data = {};
    for my $type (qw{hosts services}) {
        my $cmd    = Tie::IxHash->new(
            'mapreduce' => $type,
            'map'       => $map,
            'reduce'    => $reduce,
            'out'       => { inline => 1},
        );
        my $result = $self->_db->run_command($cmd);
        if(ref $result eq 'HASH') {
            for my $key (keys %{$result->{'results'}->[0]->{'value'}}) {
                $data->{$type.'_'.$key} = $result->{'results'}->[0]->{'value'}->{$key};
            }
        } else {
            die($result);
        }
    }
    for my $key (keys %{$data}) {
        $data->{$key} = 0 unless defined $data->{$key};
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

    unless(wantarray) {
        confess("get_extra_perf_stats() should not be called in scalar context");
    }
    my $data = $self->_db->status
                         ->find_one();
    return($data, 'SUM');
}

##########################################################

=head2 set_verbose

  set_verbose

sets verbose mode for this backend and returns old value

=cut
sub set_verbose {
    my($self, $val) = @_;
    my $old = $self->{'verbose'};
    $self->{'verbose'} = $val;
    return($old);
}

##########################################################

=head2 set_stash

  set_stash

make stash accessible for the backend

=cut
sub set_stash {
    my($self, $stash) = @_;
    $self->{'stash'} = $stash;
    return;
}

##########################################################

=head2 renew_logcache

  renew_logcache

renew logcache

=cut
sub renew_logcache {
    return;
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
    confess("_get_query_size()");

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

    my $stats = [
        'total' => { -isa => [ $key => { '!=' => undef } ]},
    ];
    my $class = $self->_get_class($table, $options);
    my $rows = $class->stats($stats)->hashref_array();
    my $size = $rows->[0]->{'total'};
    return unless defined $size;

    my $pages = 0;
    my $page  = $c->{'request'}->{'parameters'}->{'page'} || 1;
    if( $entries > 0 ) {
        $pages = POSIX::ceil( $size / $entries );
    }
    if( exists $c->{'request'}->{'parameters'}->{'next'} )         { $page++; }
    elsif ( exists $c->{'request'}->{'parameters'}->{'previous'} ) { $page--; }
    elsif ( exists $c->{'request'}->{'parameters'}->{'first'} )    { $page = 1; }
    elsif ( exists $c->{'request'}->{'parameters'}->{'last'} )     { $page = $pages; }
    if( $page < 0 ) { $page = 1; }

    unless(wantarray) {
        confess("_get_query_size() should not be called in scalar context");
    }
    $entries  = $entries * $page;
    return($size, $entries);
}

##########################################################

=head2 _add_peer_data

  _add_peer_data

add peer name, addr and key to result array

=cut
sub _add_peer_data {
    my($self, $data) = @_;
    for my $d (@{$data}) {
        $d->{'peer_name'} = $self->peer_name;
        $d->{'peer_addr'} = $self->peer_addr;
        $d->{'peer_key'}  = $self->peer_key;
    }
    return $data;
}

##########################################################

=head2 _get_filter

  _get_filter

return mongodb filter

=cut
sub _get_filter {
    my($self, $inp) = @_;
    my $filter = $self->_get_subfilter($inp);
    return $filter;
}

##########################################################

=head2 _get_subfilter

  _get_subfilter

return mongodb filter

=cut
sub _get_subfilter {
    my($self, $inp, $operator) = @_;
    my $filter = {};
    return '' unless defined $inp;

    # remove single valued arrays
    if(ref $inp eq 'ARRAY') {
        if(scalar @{$inp} == 1) {
            return $self->_get_subfilter($inp->[0]);
        }
        elsif(scalar @{$inp} == 0) {
            return({});
        }
    }

    # remove -and/-or with single value
    if(ref $inp eq 'HASH' and scalar keys %{$inp} == 1) {
        my $op = [keys   %{$inp}]->[0];
        my $v  = [values %{$inp}]->[0];
        if($op eq '-or' or $op eq '-and') {
            if(ref $v eq 'ARRAY' and scalar @{$v} == 1) {
                return $self->_get_subfilter($v, $op);
            }
            if(ref $v eq 'HASH' and scalar keys %{$v} == 1) {
                return $self->_get_subfilter($v, $op);
            }
        }
    }

    # and filter from lists
    if(ref $inp eq 'ARRAY') {
        $filter = [];
        my $x   = 0;
        my $num = scalar @{$inp};
        while($x < $num) {
            if(exists $inp->[$x+1] and ref $inp->[$x] eq '' and ref $inp->[$x+1] eq 'HASH') {
                my $key = $inp->[$x];
                my $val = $inp->[$x+1];
                push @{$filter}, $self->_get_subfilter({$key => $val});
                $x=$x+2;
                next;
            }
            # [ 'key', 'value' ] => { 'key' => 'value' }
            elsif(exists $inp->[$x+1] and ref $inp->[$x] eq '' and ref $inp->[$x+1] eq '') {
                my $key = $inp->[$x];
                my $val = $inp->[$x+1];
                push @{$filter}, $self->_get_subfilter({$key => $val});
                $x=$x+2;
                next;
            }
            if(defined $inp->[$x]) {
                push @{$filter}, $self->_get_subfilter($inp->[$x]);
            }
            $x++;
        }
        if(defined $operator and ($operator eq '-and' or $operator eq '-or')) {
            return($filter);
        }
        if(scalar @{$filter} == 1) {
            return($filter->[0]);
        }
        return({ '$and' => $filter });
    }

    if(ref $inp eq 'HASH') {
        for my $key (keys %{$inp}) {
            my $val = $inp->{$key};
            # simple operator
            if(ref $val eq 'HASH' and scalar keys %{$val} == 1) {
                my $op = [keys   %{$val}]->[0];
                my $v  = [values %{$val}]->[0];

                # { key => { '~~' => 'val' }}
                if($op eq '~~') {
                    $filter->{$key} = qr/$v/imx;
                    next;
                }
                # { key => { '~' => 'val' }}
                if($op eq '~') {
                    $filter->{$key} = qr/$v/mx;
                    next;
                }
                # { key => { '=' => 'val' }}
                if($op eq '=') {
                    $filter->{$key} = $v;
                    next;
                }
            }

            if($key eq '-or') {
                $filter->{'$or'} = $self->_get_subfilter($val, '-or');
            }
            elsif($key eq '-and') {
                $filter->{'$and'} = $self->_get_subfilter($val, '-and');
            }
            elsif($key eq '!=') {
                $filter->{'$ne'} = $self->_get_subfilter($val);
            }
            # in lists
            elsif($key eq '>=' && $val !~ m/^[\d\.]+$/mx) {
                if(ref $val eq 'ARRAY') {
                    $filter->{'$in'} = $val;
                } else {
                    $filter->{'$in'} = [ $val ];
                }
            }
            elsif($key eq '>=') {
                $filter->{'$gte'} = $val;
            }
            elsif($key eq '<=') {
                $filter->{'$lte'} = $val;
            }
            elsif($key eq '!>=') {
                $filter->{'$nin'} = [ $val ];
            }
            elsif($key eq '!~~') {
                $filter->{'$not'} = qr/$val/imx;
            }
            elsif($key eq '!~') {
                $filter->{'$not'} = qr/$val/mx;
            }
            else {
                $filter->{$key} = $self->_get_subfilter($val);
            }
        }
        # multiple hash keys have to be an array
        if(scalar keys %{$filter} > 1) {
            my @filter;
            for my $key (keys %{$filter}) {
                push @filter, {$key => $filter->{$key}};
            }
            return \@filter;
        }
        # remove single and / or
        if(scalar keys %{$filter} == 1) {
            my $key = [ keys %{$filter} ]->[0];
            if($key eq '$and' or $key eq '$or') {
                my $val = $filter->{$key};
                if(ref $val eq 'ARRAY' and scalar @{$val} == 1) {
                    return $val->[0];
                }
            }
        }
        return $filter;
    }

    return $inp;
}

##########################################################

=head2 _get_logs_start_end

  _get_logs_start_end

returns the min/max timestamp for given logs

=cut
sub _get_logs_start_end {
    my($self, %options) = @_;
    my(@data, $start, $end);
    @data = $self->_db->logs
                      ->find($self->_get_filter($options{'filter'}))
                      ->fields({ 'time' => 1 })
                      ->sort({'time' => 1})
                      ->limit(1)
                      ->all();
    $start = $data[0]->{'time'} if defined $data[0];
    @data = $self->_db->logs
                      ->find($self->_get_filter($options{'filter'}))
                      ->fields({ 'time' => 1 })
                      ->sort({'time' => -1})
                      ->limit(1)
                      ->all();
    $end = $data[0]->{'time'} if defined $data[0];
    return($start, $end);
}

##########################################################

=head2 _import_logs

  _import_logs

imports logs into mongodb

=cut

sub _import_logs {
    my($self, $c, $mode) = @_;

    $c->stats->profile(begin => "Mongodb::_import_logs($mode)");

    my $backend_count = 0;
    my $log_count     = 0;

    Thruk::Action::AddDefaults::_set_possible_backends($c, {}) unless defined $c->stash->{'backends'};

    my $table = 'logs'; # must be logs, otherwise mongodb.pm does not find the table
    my $dropped = 0;
    for my $key (@{$c->stash->{'backends'}}) {
        my $peer = $c->{'db'}->get_peer_by_key($key);
        next unless $peer->{'enabled'};
        $c->stats->profile(begin => "$key");
        $backend_count++;
        $peer->{'logcache'}->reconnect();
        my $db = $peer->{'logcache'}->_db;
        if($mode eq 'import' and !$dropped) {
            $db->run_command({drop => $table});
            $dropped = 1;
        }

        # get start / end timestamp
        my($mstart, $mend);
        my($start, $end);
        my $filter = [];
        if($mode eq 'update') {
            $c->stats->profile(begin => "get last mongo timestamp");
            # get last timestamp from mongodb
            my $mfilter = [];
            push @{$mfilter}, {peer_key => $key};
            ($mstart, $mend) = $peer->{'logcache'}->_get_logs_start_end(filter => $mfilter);
            if(defined $mend) {
                push @{$filter}, {time => { '>=' => $mend }};
                $start = $mend;
            }
            $c->stats->profile(end => "get last mongo timestamp");
        }
        $c->stats->profile(begin => "get livestatus timestamp");
        ($start, $end) = $peer->{'class'}->_get_logs_start_end(filter => $filter);
        $c->stats->profile(end => "get livestatus timestamp");
        #print "\nimporting ", scalar localtime $start, " till ", scalar localtime $end, "\n";
        my $time = $start;
        my $col = $db->$table;
        $col->ensure_index(Tie::IxHash->new('time' => 1, 'host_name' => 1, 'service_description' => 1));
        while($time <= $end) {
            my $stime = scalar localtime $time;
            $c->stats->profile(begin => $stime);
            my $lookup = {};
            #print "\n",scalar localtime $time;
            my($logs) = $peer->{'class'}->get_logs(nocache => 1,
                                                    filter  => [{ '-and' => [
                                                                            { time => { '>=' => $time } },
                                                                            { time => { '<'  => $time + 86400 } }
                                                               ]}]
                                                  );
            if($mode eq 'update') {
                my($mlogs) = $peer->{'class'}->get_logs(
                                                    filter  => [{ '-and' => [
                                                                            { time => { '>=' => $time } },
                                                                            { time => { '<=' => $time + 86400 } }
                                                               ]}]
                                          );
                for my $l (@{$mlogs}) {
                    $lookup->{$l->{'message'}} = 1;
                }
            }

            $time = $time + 86400;
            for my $l (@{$logs}) {
                if($mode eq 'update') {
                    next if defined $lookup->{$l->{'message'}};
                }
                $log_count++;
                #print '.' if $log_count%100 == 0;
                $col->insert($l, {safe => 1});
            }
            $c->stats->profile(end => $stime);
        }
        $c->stats->profile(end => "$key");
    }
    #print "\n";

    $c->stats->profile(end => "Mongodb::_import_logs($mode)");
    return($backend_count, $log_count);
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
