package Thruk::Backend::Manager;

use warnings;
use strict;
use Carp qw/confess croak/;
use Data::Dumper qw/Dumper/;
use MIME::Base64 ();
use Scalar::Util qw/looks_like_number/;
use Time::HiRes qw/gettimeofday tv_interval/;

use Thruk::Backend::Peer ();
use Thruk::Constants ':backend_handling';
use Thruk::Timer qw/timing_breakpoint/;
use Thruk::Utils ();
use Thruk::Utils::Auth ();
use Thruk::Utils::Cache ();
use Thruk::Utils::Log qw/:all/;

our $AUTOLOAD;

=head1 NAME

Thruk::Backend::Manager - Manager of backend connections

=head1 DESCRIPTION

Manager of backend connections

=head1 METHODS

=cut

##########################################################

=head2 new

create new manager

=cut

sub new {
    my($class, $pool) = @_;
    my $self = {
        'pool'                => $pool,
        'last_program_starts' => {},
    };
    confess("no connection pool") unless $pool;
    bless $self, $class;
    $self->update_sections();
    return $self;
}

##########################################################

=head2 pool

returns connection pool

=cut

sub pool {
    my($self) = @_;
    return $self->{'pool'};
}

##########################################################

=head2 peers

returns hash of peers

=cut

sub peers {
    my($self) = @_;
    return $self->{'pool'}->peers;
}

##########################################################

=head2 peer_order

returns list of peers

=cut

sub peer_order {
    my($self) = @_;
    return $self->{'pool'}->peer_order;
}

##########################################################

=head2 authoritive_peer_keys

returns list of authoritive peers (used to fetch can_submit_commands / groups)

=cut

sub authoritive_peer_keys {
    my($self) = @_;
    my @keys;
    for my $peer ( @{ $self->get_peers() } ) {
        push @keys, $peer->{'key'} if $peer->{'authoritive'};
    }
    if(scalar @keys == 0) {
        return $self->peer_key();
    }
    return \@keys;
}

##########################################################

=head2 lmd_peer

returns pools lmd_peer

=cut

sub lmd_peer {
    my($self) = @_;
    return $self->{'pool'}->lmd_peer;
}

##########################################################

=head2 update_sections

calculate sections

=cut

sub update_sections {
    my($self) = @_;

    $self->{'sections'}       = {};
    $self->{'sections_depth'} = 0;
    for my $peer (@{$self->get_peers(1)}) {
        my @sections = split(/\/+/mx, $peer->{'section'});
        if(scalar @sections == 0) {
            @sections = ();
        } elsif($sections[0] eq 'Default') {
            shift @sections;
        }
        my $depth = scalar @sections;
        $self->{'sections_depth'} = $depth if $self->{'sections_depth'} < $depth;
        my $cur_section = $self->{'sections'};
        for my $section (@sections) {
            if(!$cur_section->{'sub'}) {
                $cur_section->{'sub'} = {};
            }
            if(!$cur_section->{'sub'}->{$section}) {
                $cur_section->{'sub'}->{$section} = {};
            }
            $cur_section = $cur_section->{'sub'}->{$section};
        }
        if(!$cur_section->{'peers'}) {
            $cur_section->{'peers'} = [];
        }
        push @{$cur_section->{'peers'}}, $peer->{'key'};
    }

    return;
}


##########################################################

=head2 disable_hidden_backends

  disable_hidden_backends()

returns list of hidden backends

=cut

sub disable_hidden_backends {
    my($self, $disabled_backends, $display_too) = @_;

    $disabled_backends = {} unless $disabled_backends;
    my $peers          = $self->get_peers();

    # only hide them, if we have more than one
    return $disabled_backends if scalar @{$peers} <= 1;

    for my $peer (@{$peers}) {
        if(defined $peer->{'hidden'} and $peer->{'hidden'} == 1) {
            $disabled_backends->{$peer->{'key'}} = 2;
        }
        if($display_too and defined $peer->{'display'} and $peer->{'display'} == 0) {
            $disabled_backends->{$peer->{'key'}} = 2;
        }
    }
    return $disabled_backends;
}

##########################################################

=head2 get_peers

  get_peers([$all])

returns all configured peers (except config-only)

=cut

sub get_peers {
    my($self, $all, $inactive_too) = @_;
    my @peers;

    return $self->pool->{'objects'} if($all && $inactive_too);

    for my $b (@{$self->pool->{'objects'}}) {
        next if(defined $b->{'active'} && !$b->{'active'} && !$inactive_too);
        next if(!$b->{'addr'} && !$all);
        push @peers, $b;
    }
    return \@peers;
}

##########################################################

=head2 get_local_peers

  get_local_peers()

returns all configured peers which use a local unix socket to connect

=cut

sub get_local_peers {
    my($self) = @_;

    my @peers;
    for my $b (@{$self->get_peers()}) {
        push @peers, $b if $b->is_local();
    }
    return \@peers;
}

##########################################################

=head2 get_peer_by_key

  get_peer_by_key()

returns peer by key

=cut

sub get_peer_by_key {
    my($self, $key) = @_;
    confess("missing argument") unless defined $key;
    my $peer = $self->pool->peers->{$key};
    return $peer if $peer;
    $peer = $self->pool->{'by_name'}->{$key};
    return $peer if $peer;
    return;
}

##########################################################

=head2 get_peer_by_name

  get_peer_by_name()

returns peer by name

=cut

sub get_peer_by_name {
    my($self, $name) = @_;
    return $self->pool->{'by_name'}->{$name};
}

##########################################################

=head2 get_http_peers

  get_http_peers([$with_fallbacks])

returns all configured peers which have a http connection type

=cut

sub get_http_peers {
    my($self, $with_fallbacks) = @_;
    my $http_peers = [];
    for my $peer (@{$self->get_peers()}) {
        if($peer->{'type'} eq 'http') {
            push @{$http_peers}, $peer;
        } elsif($with_fallbacks) {
            for my $addr (@{$peer->peer_list()}) {
                if($addr =~ m/^https?:/mx) {
                    push @{$http_peers}, $peer;
                    last;
                }
            }
        }
    }
    return $http_peers;
}

##########################################################

=head2 peer_key

  peer_key()

returns all peer keys

=cut

sub peer_key {
    my($self) = @_;
    my @keys;
    for my $peer ( @{ $self->get_peers() } ) {
        push @keys, $peer->{'key'};
    }
    return \@keys;
}

##########################################################

=head2 sections

  sections()

returns all sections

=cut

sub sections {
    my($self) = @_;
    return $self->{'sections'};
}

##########################################################

=head2 disable_backend

  disable_backend(<key>)

disable backend by key

=cut

sub disable_backend {
    my($self, $key) = @_;

    my $peer = $self->get_peer_by_key($key);
    if( defined $peer ) {
        $peer->{'enabled'} = 0;
    }
    return;
}

##########################################################

=head2 enable_backend

  enable_backend(<key>)

ensable backend by key

=cut

sub enable_backend {
    my($self, $key) = @_;

    my $peer = $self->get_peer_by_key($key);
    if( defined $peer ) {
        $peer->{'enabled'} = 1;
    }
    return;
}

##########################################################

=head2 disable_backends

  disable_backends(<keys_hash>)

disabled backend by key hash

=cut

sub disable_backends {
    my($self, $keys) = @_;

    if( defined $keys ) {
        for my $key ( keys %{$keys} ) {
            if( $keys->{$key} !~ m/^\d+$/mx or $keys->{$key} == 2 or $keys->{$key} == 3 ) {
                $self->disable_backend($key);
            }
        }
    }
    else {
        for my $peer ( @{ $self->get_peers() } ) {
            $peer->{'enabled'} = 0;
        }
    }
    return;
}

##########################################################

=head2 enable_backends

  enable_backends(<keys>, [<exclusive>])

enables all backends. list is additive unless exclusive is used.

=cut

sub enable_backends {
    my($self, $keys, $exclusive) = @_;

    if( defined $keys ) {
        if($exclusive) {
            for my $peer ( @{ $self->get_peers() } ) {
                $peer->{'enabled'} = 0;
            }
        }
        if(ref $keys eq 'ARRAY') {
            my %hash = map { $_ => 1 } @{$keys};
            $keys = \%hash;
        }
        elsif(ref $keys eq '') {
            $keys = { $keys => 1 };
        }

        for my $key ( keys %{$keys} ) {
            $self->enable_backend($key);
        }
    }
    else {
        for my $peer ( @{ $self->get_peers() } ) {
            $peer->{'enabled'} = 1;
        }
    }
    return;
}

##########################################################

=head2 enable_default_backends

  enable_default_backends()

enables all default backends

=cut

sub enable_default_backends {
    my($self) = @_;
    $self->enable_backends($self->get_default_backends(), 1);
    return;
}

##########################################################

=head2 get_default_backends

  get_default_backends()

returns all default backends

=cut

sub get_default_backends {
    my($self) = @_;
    my $defaults = [];
    for my $peer ( @{ $self->get_peers() } ) {
        if(!$peer->{'hidden'}) {
            push @{$defaults}, $peer->{'key'};
        }
    }
    return($defaults);
}

##########################################################

=head2 get_scheduling_queue

  get_scheduling_queue

returns the scheduling queue

=cut
sub get_scheduling_queue {
    my($self, $c, %options) = @_;

    my($services) = $self->get_services(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'services'),
                                                 { '-or' => [{ 'active_checks_enabled' => '1' },
                                                            { 'check_options' => { '!=' => '0' }}],
                                                 }, $options{'servicefilter'}],
                                        columns => $options{'servicecolumns'},
                                       );
    my($hosts);
    if(!$options{'servicefilter'}) {
        ($hosts)    = $self->get_hosts(filter  => [Thruk::Utils::Auth::get_auth_filter($c, 'hosts'),
                                                   { '-or' => [{ 'active_checks_enabled' => '1' },
                                                              { 'check_options' => { '!=' => '0' }}],
                                                   }, $options{'hostfilter'}],
                                        columns => $options{'hostcolumns'},
                                      );
    }

    my $queue = [];
    if(defined $services) {
        push @{$queue}, @{$services};
    }
    if(defined $hosts) {
        push @{$queue}, @{$hosts};
    }
    $queue = $self->sort_result( $queue, $options{'sort'} ) if defined $options{'sort'};
    Thruk::Utils::page_data($c, $queue) if defined $options{'pager'};
    return $queue;
}

########################################

=head2 get_performance_stats

  get_performance_stats

wrapper around get_performance_stats

=cut

sub get_performance_stats {
    my($self, @args) = @_;
    # inject last_program_starts
    push @args, ('last_program_starts', $self->{'last_program_starts'}//{});
    return $self->_do_on_peers('get_performance_stats', \@args );
}

########################################

=head2 get_hosts

  get_hosts

wrapper around get_hosts

=cut

sub get_hosts {
    my($self, @args) = @_;
    # inject last_program_starts
    push @args, ('last_program_starts', $self->{'last_program_starts'}//{});
    return $self->_do_on_peers('get_hosts', \@args );
}

########################################

=head2 get_services

  get_services

wrapper around get_services

=cut

sub get_services {
    my($self, @args) = @_;
    # inject last_program_starts
    push @args, ('last_program_starts', $self->{'last_program_starts'}//{});
    return $self->_do_on_peers('get_services', \@args );
}

########################################

=head2 get_host_stats_by_servicequery

  get_host_stats_by_servicequery

calculate host statistics from services query

=cut

sub get_host_stats_by_servicequery {
    my($self, @args) = @_;
    my %args = @args;
    $args{'columns'} = [qw/host_name host_check_type host_has_been_checked host_scheduled_downtime_depth host_state host_state_type
                           host_acknowledged host_is_flapping host_event_handler_enabled host_accept_passive_checks
                           host_active_checks_enabled host_flap_detection_enabled host_notifications_enabled host_childs
                          /];
    my $hard_states_only = delete $args{'hard_states_only'};
    @args = %args;
    my $services = $self->_do_on_peers('get_services', \@args );
    my $data = $self->_set_result_defaults('get_host_stats', []);
    my $uniq = {};
    for my $s (@{$services}) {
        next if $uniq->{$s->{'host_name'}};
        $uniq->{$s->{'host_name'}} = 1;
        my $host_state = $s->{'host_state'};
        if($hard_states_only && $s->{'host_state_type'} != 1) {
            # soft states count as up
            $host_state = 0;
        }
        $data->{'total'}++;
        $data->{'total_active'}++                      if $s->{'host_check_type'} == 0;
        $data->{'total_passive'}++                     if $s->{'host_check_type'} == 1;
        $data->{'pending'}++                           if $s->{'host_has_been_checked'} == 0;
        $data->{'plain_pending'}++                     if $s->{'host_has_been_checked'} == 0 && $s->{'host_scheduled_downtime_depth'} == 0 && $s->{'host_acknowledged'} == 0;
        $data->{'pending_and_disabled'}++              if $s->{'host_has_been_checked'} == 0 && $s->{'host_active_checks_enabled'} == 0;
        $data->{'pending_and_scheduled'}++             if $s->{'host_has_been_checked'} == 0 && $s->{'host_scheduled_downtime_depth'} > 0;
        $data->{'up'}++                                if $s->{'host_has_been_checked'} == 1 && $host_state == 0;
        $data->{'plain_up'}++                          if $s->{'host_has_been_checked'} == 1 && $host_state == 0 && $s->{'host_scheduled_downtime_depth'} == 0 && $s->{'host_acknowledged'} == 0;
        $data->{'up_and_disabled_active'}++            if $s->{'host_check_type'} == 0 && $s->{'host_has_been_checked'} == 1 && $host_state == 0 && $s->{'host_active_checks_enabled'} == 0;
        $data->{'up_and_disabled_passive'}++           if $s->{'host_check_type'} == 1 && $s->{'host_has_been_checked'} == 1 && $host_state == 0 && $s->{'host_active_checks_enabled'} == 0;
        $data->{'up_and_scheduled'}++                  if $s->{'host_has_been_checked'} == 1 && $host_state == 0 && $s->{'host_scheduled_downtime_depth'} > 0;
        $data->{'down'}++                              if $s->{'host_has_been_checked'} == 1 && $host_state == 1;
        $data->{'plain_down'}++                        if $s->{'host_has_been_checked'} == 1 && $host_state == 1 && $s->{'host_scheduled_downtime_depth'} == 0 && $s->{'host_acknowledged'} == 0;
        $data->{'down_and_ack'}++                      if $s->{'host_has_been_checked'} == 1 && $host_state == 1 && $s->{'host_acknowledged'} == 1;
        $data->{'down_and_scheduled'}++                if $s->{'host_has_been_checked'} == 1 && $host_state == 1 && $s->{'host_scheduled_downtime_depth'} > 0;
        $data->{'down_and_disabled_active'}++          if $s->{'host_check_type'} == 0 && $s->{'host_has_been_checked'} == 1 && $host_state == 1 && $s->{'host_active_checks_enabled'} == 0;
        $data->{'down_and_disabled_passive'}++         if $s->{'host_check_type'} == 1 && $s->{'host_has_been_checked'} == 1 && $host_state == 1 && $s->{'host_active_checks_enabled'} == 0;
        $data->{'down_and_unhandled'}++                if $s->{'host_has_been_checked'} == 1 && $host_state == 1 && $s->{'host_active_checks_enabled'} == 1 && $s->{'host_acknowledged'} == 0 && $s->{'host_scheduled_downtime_depth'} == 0;
        $data->{'unreachable'}++                       if $s->{'host_has_been_checked'} == 1 && $host_state == 2;
        $data->{'plain_unreachable'}++                 if $s->{'host_has_been_checked'} == 1 && $host_state == 2 && $s->{'host_scheduled_downtime_depth'} == 0 && $s->{'host_acknowledged'} == 0;
        $data->{'unreachable_and_ack'}++               if $s->{'host_has_been_checked'} == 1 && $host_state == 2 && $s->{'host_acknowledged'} == 1;
        $data->{'unreachable_and_scheduled'}++         if $s->{'host_has_been_checked'} == 1 && $host_state == 2 && $s->{'host_scheduled_downtime_depth'} > 0;
        $data->{'unreachable_and_disabled_active'}++   if $s->{'host_check_type'} == 0 && $s->{'host_has_been_checked'} == 1 && $host_state == 2 && $s->{'host_active_checks_enabled'} == 0;
        $data->{'unreachable_and_disabled_passive'}++  if $s->{'host_check_type'} == 1 && $s->{'host_has_been_checked'} == 1 && $host_state == 2 && $s->{'host_active_checks_enabled'} == 0;
        $data->{'unreachable_and_unhandled'}++         if $s->{'host_has_been_checked'} == 1 && $host_state == 2 && $s->{'host_active_checks_enabled'} == 1 && $s->{'host_acknowledged'} == 0 && $s->{'host_scheduled_downtime_depth'} == 0;
        $data->{'flapping'}++                          if $s->{'host_is_flapping'} == 1;
        $data->{'flapping_disabled'}++                 if $s->{'host_flap_detection_enabled'} == 0;
        $data->{'notifications_disabled'}++            if $s->{'host_notifications_enabled'} == 0;
        $data->{'eventhandler_disabled'}++             if $s->{'host_event_handler_enabled'} == 0;
        $data->{'active_checks_disabled_active'}++     if $s->{'host_check_type'} == 0 && $s->{'host_active_checks_enabled'} == 0;
        $data->{'active_checks_disabled_passive'}++    if $s->{'host_check_type'} == 1 && $s->{'host_active_checks_enabled'} == 0;
        $data->{'passive_checks_disabled'}++           if $s->{'host_accept_passive_checks'} == 0;
        $data->{'outages'}++                           if $host_state == 1 && scalar @{$s->{'host_childs'}} > 0;
    }
    return($data);
}

########################################

=head2 get_all_child_hosts

  get_all_child_hosts

returns list of all recursive child hosts

=cut

sub get_all_child_hosts {
    my($self, $host) = @_;
    my %args;
    $args{'last_program_starts'} = $self->{'last_program_starts'}//{};
    $args{'columns'} = [qw/name childs/];
    $args{'filter'}  = [{ childs => { '!=' => '' }}];
    my @args = %args;
    my $data = $self->_do_on_peers('get_hosts', \@args );
    $data = Thruk::Base::array2hash($data, 'name');
    my $hosts = {};
    _add_child_host($data->{$host}, $hosts, $data);

    return([sort keys %{$hosts}]);
}

sub _add_child_host {
    my($h, $hosts, $data) = @_;
    for my $child (@{$h->{'childs'}}) {
        next if $hosts->{$child};
        $hosts->{$child} = 1;
        _add_child_host($data->{$child}, $hosts, $data);
    }
    return;
}

########################################

=head2 get_host_stats_by_backend

  get_hosts

wrapper around get_hosts

=cut

sub get_host_stats_by_backend {
    my($self, @args) = @_;
    my $res = {};
    if($ENV{'THRUK_USE_LMD'}) {
        push @args, "columns", ["peer_key"];
        $res = $self->_do_on_peers('get_host_less_stats', \@args );
        # add peer name
        for my $key (keys %{$res}) {
            $res->{$key}->{'peer_name'} = Thruk::Utils::Filter::peer_name($res->{$key}) // '';
        }
    } else {
        # without LMD we have to ask all backends
        my($result) = $self->_do_on_peers('get_host_less_stats', \@args, undef, undef, 1);
        # add peer name
        for my $key (keys %{$result}) {
            $res->{$key} = $result->{$key};
            $res->{$key}->{'peer_key'}  = $key;
            $res->{$key}->{'peer_name'} = Thruk::Utils::Filter::peer_name($res->{$key}) // '';
        }
    }
    return($res);
}

########################################

=head2 get_contactgroups_by_contact

  get_contactgroups_by_contact

returns a list of contactgroups by contact

=cut

sub get_contactgroups_by_contact {
    my($self, $username) = @_;
    confess("no user") if(!defined $username || ref $username ne "");
    if($self->{'get_contactgroups_by_contact_cache'}) {
        return($self->{'get_contactgroups_by_contact_cache'}->{$username} // {});
    }
    my $data = $self->_do_on_peers( "get_contactgroups_by_contact", [ $username ], undef, $self->authoritive_peer_keys());
    my $contactgroups = {};
    for my $group (@{$data}) {
        $contactgroups->{$group->{'name'}} = 1;
    }
    return $contactgroups;
}

########################################

=head2 get_hostgroup_names_from_hosts

  get_hostgroup_names_from_hosts

returns a list of hostgroups but get list from hosts in order to
respect permissions

=cut

sub get_hostgroup_names_from_hosts {
    my($self, %args) = @_;
    # clean args if possible
    if(defined $args{'filter'} && scalar @{$args{'filter'}} == 0) {
        delete $args{'filter'};
    }
    if(scalar keys %args == 0) { return $self->get_hostgroup_names(); }
    $args{'filter'} = [] unless $args{'filter'};
    push @{$args{'filter'}}, { 'groups' => { '!=' => '' }};
    my $hosts = $self->get_hosts( %args, 'columns', ['groups'] );
    my $groups = {};
    for my $host (@{$hosts}) {
        map { $groups->{$_} = 1; } @{$host->{'groups'}};
    }
    my @sorted = sort keys %{$groups};
    return \@sorted;
}

########################################

=head2 get_servicegroup_names_from_services

  get_servicegroup_names_from_services

returns a list of servicegroups but get list from services in order to
respect permissions

=cut

sub get_servicegroup_names_from_services {
    my($self, %args) = @_;
    # clean args if possible
    if(defined $args{'filter'} && scalar @{$args{'filter'}} == 0) {
        delete $args{'filter'};
    }
    if(scalar keys %args == 0) { return $self->get_servicegroup_names(); }
    $args{'filter'} = [] unless $args{'filter'};
    push @{$args{'filter'}}, { 'groups' => { '!=' => '' }};
    my $services = $self->get_services( %args, 'columns', ['groups'] );
    my $groups = {};
    for my $service (@{$services}) {
        map { $groups->{$_} = 1; } @{$service->{'groups'}};
    }
    my @sorted = sort keys %{$groups};
    return \@sorted;
}

########################################

=head2 reconnect

  reconnect

runs reconnect on all peers

=cut

sub reconnect {
    my($self, @args) = @_;
    return 1 unless $Thruk::Globals::c;
    eval {
        $self->_do_on_peers( 'reconnect', \@args);
    };
    _debug($@) if $@;
    return 1;
}

########################################

=head2 expand_command

  expand_command

expand a command line with host/service data

=cut

sub expand_command {
    my( $self, %data ) = @_;
    croak("no host") unless defined $data{'host'};
    my $host     = $data{'host'};
    my $service  = $data{'service'};
    my $command  = $data{'command'};  # optional reference to a command object from the commands tabls
    my $commands = $data{'commands'}; # optional lookup table for commands
    my $source   = $data{'source'};

    my $obj          = $host;
    my $command_name = $host->{'check_command'};
    if(defined $service) {
        $command_name = $service->{'check_command'};
        $obj          = $service;
    }

    # different source?
    if(defined $source and $source ne 'check_command') {
        if($obj->{$source}) {
            $command_name = $obj->{$source};
        } else {
            $source  = uc($source);
            $source  =~ s/^_//mx;
            my $vars = Thruk::Utils::get_custom_vars(undef, $obj);
            $command_name = $vars->{$source} || '';
        }
    }

    my($name, @com_args) = split(/(?<!\\)!/mx, $command_name, 255);

    # it is possible to define hosts without a command
    if(!defined $name || $name =~ m/^\s*$/mx) {
        return({
            'line'          => 'no command defined',
            'line_expanded' => '',
            'note'          => '',
        });
    }

    # get command data
    my $expanded;
    if(defined $command) {
        $expanded = $command->{'line'};
    } else {
        if(defined $commands) {
            my $cmd = $commands->{Thruk::Base::list($obj->{'peer_key'})->[0]}->{$name};
            if($cmd) {
                $expanded = $cmd->{'line'};
            }
        } else {
            my $commands = $self->get_commands( filter => [ { 'name' => $name } ], backend => Thruk::Base::list($obj->{'peer_key'}) );
            $expanded = $commands->[0]->{'line'};
        }
    }

    if(!$expanded) {
        return({
            'line'          => '',
            'line_expanded' => '',
            'note'          => '',
        });
    }

    my($rc, $obfuscated, $orig);
    eval {
        ($expanded,$rc, $obfuscated) = $self->_replace_macros({string => $expanded, host => $host, service => $service, args => \@com_args, obfuscate => $data{'obfuscate'}});
        $orig = $expanded;
        $expanded = $self->_obfuscate({string => $expanded, host => $host, service => $service, args => \@com_args}) if(!defined $data{'obfuscate'} || $data{'obfuscate'});
        $obfuscated = 1 if $orig ne $expanded;
        $command_name = $self->_obfuscate({string => $command_name, host => $host, service => $service, args => \@com_args}) if(!defined $data{'obfuscate'} || $data{'obfuscate'});
    };

    # does it still contain macros?
    my $note = "";
    if($@) {
        $note = $@;
        $note =~ s/\s+at\s+\/.*?$//mx;
    } elsif(!$rc) {
        $note = "could not expand all macros!";
    }

    # unescape $$
    $expanded =~ s{\$\$}{\$}gmx;
    $orig     =~ s{\$\$}{\$}gmx;

    my $return = {
        'line'          => $command_name,
        'line_expanded' => $expanded,
        'obfuscated'    => $obfuscated ? 1 : 0,
        'line_orig'     => $orig, # not obfuscated
        'note'          => $note,
        'host'          => $host    ? ($host->{'host_name'} // $host->{'name'}) : '',
        'service'       => $service ? $service->{'description'} : '',
        'backend'       => Thruk::Utils::Filter::peer_name($obj) // '',
    };
    return $return;
}

########################################

=head2 logcache_stats

  logcache_stats($c)

return logcache statistics

=cut

sub logcache_stats {
    my($self, $c, $with_dates, $backends) = @_;
    return unless defined $c->config->{'logcache'};

    my $type = '';
    $type = 'mysql' if $c->config->{'logcache'} =~ m/^mysql/mxi;
    my(@stats);
    if($type eq 'mysql') {
        if(!defined $Thruk::Backend::Manager::ProviderLoaded->{'Mysql'}) {
            require Thruk::Backend::Provider::Mysql;
            Thruk::Backend::Provider::Mysql->import;
            $Thruk::Backend::Manager::ProviderLoaded->{'Mysql'} = 1;
        }
        @stats = Thruk::Backend::Provider::Mysql->_log_stats($c, $backends);
    } else {
        die("unknown type: ".$type);
    }
    my $stats = Thruk::Base::array2hash(\@stats, 'key');

    if($with_dates) {
        for my $key (keys %{$stats}) {
            my $peer  = $self->get_peer_by_key($key);
            my($start, $end) = @{$peer->logcache->get_logs_start_end()};
            $stats->{$key}->{'start'} = $start;
            $stats->{$key}->{'end'}   = $end;
        }
    }

    # clean up connections
    close_logcache_connections($c);

    return $stats;
}

########################################

=head2 logcache_existing_caches

  logcache_existing_caches($c)

return peer ids of existing log caches

=cut
sub logcache_existing_caches {
    my($self, $c) = @_;

    my $type = '';
    $type = 'mysql' if $c->config->{'logcache'} =~ m/^mysql/mxi;
    my $stats;
    if($type eq 'mysql') {
        if(!defined $Thruk::Backend::Manager::ProviderLoaded->{'Mysql'}) {
            require Thruk::Backend::Provider::Mysql;
            Thruk::Backend::Provider::Mysql->import;
            $Thruk::Backend::Manager::ProviderLoaded->{'Mysql'} = 1;
        }
        $stats = Thruk::Backend::Provider::Mysql->get_existing_caches($c);
    } else {
        die("unknown type: ".$type);
    }

    # clean up connections
    close_logcache_connections($c);

    return($stats);
}

########################################

=head2 get_logs

  get_logs(@args)

retrieve logfiles

=cut
sub get_logs {
    my($self, @args) = @_;
    my $c = $Thruk::Globals::c;

    local $ENV{'THRUK_NOLOGCACHE'} = 1 if (defined $c->req->parameters->{'logcache'} && $c->req->parameters->{'logcache'} == 0);

    my $data;
    eval {
        $data = $self->_do_on_peers( 'get_logs', \@args);
    };
    my $err = $@;
    if($err && !$data && $err =~ m/Table.*doesn't\s*exist/mx) {
        $err =~ s/\s+at\s+.*?\.pm\s+line\s+\d+\.//gmx;
        $c->stash->{errorMessage}     = "Logfilecache Unavailable";
        $c->stash->{errorDescription} = "logcache tables do not exist, please setup logcache update first.\n"
                                       ."See <b><a href='https://thruk.org/documentation/logfile-cache.html'>the documentation</a></b> for details or try to <b><a href='".Thruk::Utils::Filter::uri_with($c, {logcache_update => 1})."'>run import manually</a></b>.\n"
                                       .$err;
        return($c->detach('/error/index/99'));
    } elsif($err) {
        die($err);
    }
    return($data);
}

########################################

=head2 renew_logcache

  renew_logcache($c, [$noforks])

update the logcache, returns 1 on success or undef otherwise

=cut
sub renew_logcache {
    my($self, $c, $noforks) = @_;
    $noforks = 0 unless defined $noforks;
    return 1 unless defined $c->config->{'logcache'};
    # set to import only to get faster initial results
    local $c->config->{'logcache_delta_updates'} = 1 if $c->req->parameters->{'logcache_update'};
    local $c->config->{'logcache_delta_updates'} = 2 unless $c->config->{'logcache_delta_updates'};
    return 1 if !$c->config->{'logcache_delta_updates'};
    my $rc;
    eval {
        $rc = $self->_renew_logcache($c, $noforks);
    };
    my $err = $@;
    if($err) {
        # initial import redirects to job page
        if($err =~ m/\Qprevent further page processing\E/mx) {
            die($err);
        }
        _error($err);
        $c->stash->{errorMessage}     = "Logfilecache Unavailable";
        $c->stash->{errorDescription} = $@;
        $c->stash->{errorDescription} =~ s/\s+at\s+.*?\.pm\s+line\s+\d+\.//gmx;
        return $c->detach('/error/index/99');
    }
    return $rc;
}

########################################

=head2 get_comments_by_pattern

  get_comments_by_pattern($c, $host, $svc, $pattern)

retrieve backend and ID of host or service comment(s) that match the given pattern

=cut

sub get_comments_by_pattern {
    my ($self, $c, $host, $svc, $pattern) = @_;
    _debug("get_comments_by_pattern() has been called: host = $host, service = ".($svc||'').", pattern = $pattern");
    my $options  = {'filter' => [{'host_name' => $host}, {'service_description' => $svc}, {'comment' => {'~' => $pattern}}]};
    my $comments = $self->get_comments(%{$options});
    my $ids      = [];
    for my $comm (@{$comments}) {
        my ($cmd) = $comm->{'comment'} =~ m/^DISABLE_([A-Z_]+):/mx;
        _debug("found comment for command DISABLE_$cmd with ID $comm->{'id'} on backend $comm->{'peer_key'}");
        push @{$ids}, {'backend' => $comm->{'peer_key'}, 'id' => $comm->{'id'}};
    }
    return $ids;
}

########################################

=head2 _renew_logcache

  _renew_logcache($c)

update the logcache (internal sub)

=cut

sub _renew_logcache {
    my($self, @args) = @_;
    my($c, $noforks) = @args;

    # check if this is the first import at all
    # and do a external import in that case
    #my($get_results_for, $arg_array, $arg_hash)...
    my($get_results_for) = $self->select_backends('renew_logcache', \@args);
    my $check = 0;
    $self->{'logcache_checked'} = {} unless defined $self->{'logcache_checked'};
    for my $key (@{$get_results_for}) {
        if(!defined $self->{'logcache_checked'}->{$key}) {
            $self->{'logcache_checked'}->{$key} = 1;
            $check = 1;
        }
    }
    return 1 unless $check;

    $c->stash->{'backends'} = $get_results_for;
    my $exists = $self->logcache_existing_caches($c) // [];
    $exists = Thruk::Base::array2hash($exists);

    my $backends2import = [];
    for my $key (@{$get_results_for}) {
        my $peer = $c->db->get_peer_by_key($key);
        next unless $peer->{'logcache'};
        next if($peer && $exists->{$key});
        push @{$backends2import}, $key;
    }

    if($c->config->{'logcache_import_command'}) {
        local $ENV{'THRUK_BACKENDS'} = join(';', @{$get_results_for});
        local $ENV{'THRUK_LOGCACHE'} = $c->config->{'logcache'};
        if(scalar @{$backends2import} > 0) {
            local $ENV{'THRUK_LOGCACHE_MODE'} = 'import';
            local $ENV{'THRUK_BACKENDS'} = join(';', @{$backends2import});
            require Thruk::Utils::External;
            my $job = Thruk::Utils::External::cmd($c,
                                            { cmd        => $c->config->{'logcache_import_command'},
                                              message    => 'please stand by while your initial logfile cache will be created...',
                                              forward    => $c->req->url,
                                              nofork     => $noforks,
                                              background => 1,
                                            });
            return $c->redirect_to_detached($c->stash->{'url_prefix'}."cgi-bin/job.cgi?job=".$job);
        } else {
            return 1 if $c->config->{'logcache_delta_updates'} == 2; # return in import only mode
            local $ENV{'THRUK_LOGCACHE_MODE'} = 'update';
            my($rc, $output) = Thruk::Utils::IO::cmd($c->config->{'logcache_import_command'});
            if($rc != 0) {
                Thruk::Utils::set_message( $c, { style => 'fail_message', msg => $output });
            }
        }
    } else {
        my $type = '';
        $type = 'mysql' if $c->config->{'logcache'} =~ m/^mysql/mxi;
        if(scalar @{$backends2import} > 0) {
            require Thruk::Utils::External;
            my $job = Thruk::Utils::External::perl($c,
                                             { expr       => 'Thruk::Backend::Provider::'.(ucfirst $type).'->_import_logs($c, "import")',
                                               message    => 'please stand by while your initial logfile cache will be created...',
                                               forward    => $c->req->url,
                                               backends   => $backends2import,
                                               nofork     => $noforks,
                                               background => 1,
                                            });
            return $c->redirect_to_detached($c->stash->{'url_prefix'}."cgi-bin/job.cgi?job=".$job);
        }

        return 1 if $c->config->{'logcache_delta_updates'} == 2; # return in import only mode
        $self->_do_on_peers( 'renew_logcache', \@args, 1);
    }
    return 1;
}

########################################

=head2 close_logcache_connections

  close_logcache_connections($c)

close all logcache connections

=cut
sub close_logcache_connections {
    my($c) = @_;
    # clean up connections
    for my $key (@{$c->stash->{'backends'}}) {
        my $peer = $c->db->get_peer_by_key($key);
        $peer->logcache->_disconnect() if $peer->{'_logcache'};
    }
    return;
}

########################################

=head2 lmd_stats

  lmd_stats($c)

return lmd statistics

=cut

sub lmd_stats {
    my($self, $c) = @_;
    return unless defined $c->config->{'use_lmd_core'};
    require Thruk::Utils::LMD;
    $self->reset_failed_backends();
    my($backends) = $self->select_backends();
    my $stats = $self->get_sites( backend => $backends );
    my($status, undef) = Thruk::Utils::LMD::status($c->config);
    my $start_time = $status->[0]->{'start_time'};
    my $now = time();
    for my $stat (@{$stats}) {
        $stat->{'bytes_send_rate'}     = $stat->{'bytes_send'} / ($now - $start_time);
        $stat->{'bytes_received_rate'} = $stat->{'bytes_received'} / ($now - $start_time);
    }
    return($stats);
}

########################################

=head2 _get_macros

  _get_macros

returns a hash of macros

=cut

sub _get_macros {
    my $self    = shift;
    my $args    = shift;
    my $macros  = shift || {};

    my $host        = $args->{'host'};
    my $service     = $args->{'service'};
    my $filter_user = (defined $args->{'filter_user'}) ? $args->{'filter_user'} : 1;

    # arguments
    my $x = 1;
    for my $arg (@{$args->{'args'}}) {
        $macros->{'$ARG'.$x.'$'} = $arg;
        $x++;
    }

    # user macros...
    unless(defined $args->{'skip_user'}) {
        $self->_set_user_macros({peer_key => $host->{'peer_key'}, filter => $filter_user}, $macros);
    }

    # host macros
    if(defined $host) {
        $self->_set_host_macros($host, $macros);
    }

    # service macros
    if(defined $service) {
        $self->_set_service_macros($service, $macros);
    }

    # date macros
    my $now           = time();
    my $time          = Thruk::Utils::format_date($now, '%H:%M:%S' );
    my $date          = Thruk::Utils::format_date($now, '%Y-%m-%d' );
    my $longdatetime  = Thruk::Utils::format_date($now, '%a %b %e %H:%M:%S %Z %Y' );
    my $shortdatetime = $date." ".$time;
    $macros->{'$SHORTDATETIME$'} = $shortdatetime;
    $macros->{'$LONGDATETIME$'}  = $longdatetime;
    $macros->{'$DATE$'}          = $date;
    $macros->{'$TIME$'}          = $time;
    $macros->{'$TIMET$'}         = $now;

    return $macros;
}

########################################

=head2 replace_macros

  replace_macros($string, $args, [$macros])

replace macros in given string.

returns ($result, $rc)

$args should be:
{
    host      => host object (or service object)
    service   => service object
    skip_user => 0/1   # skips user macros
    args      => list of arguments
}

=cut

sub replace_macros {
    my( $self, $string, $args, $macros ) = @_;
    $macros  = $self->_get_macros($args) unless defined $macros;
    return $self->_get_replaced_string($string, $macros);
}

########################################

=head2 get_macros

  get_macros($args)

returns a hash of macros

$args should be:
{
    host        => host object (or service object)
    service     => service object
    skip_user   => 0/1   # skips user macros
    filter_user => 0/1   # filters user macros
    args        => list of arguments
}

=cut

sub get_macros {
    my $self    = shift;
    return($self->_get_macros(@_));
}

########################################
sub _replace_macros {
    my( $self, $args ) = @_;

    my $string  = $args->{'string'};
    my $macros  = $self->_get_macros($args);
    $macros->{'obfuscate'} = $args->{'obfuscate'} if defined $args->{'obfuscate'};
    return $self->_get_replaced_string($string, $macros);
}

########################################

=head2 _get_replaced_string

  _get_replaced_string

returns replaced string

=cut

sub _get_replaced_string {
    my( $self, $string, $macros, $skip_args ) = @_;
    my $rc  = 1;
    my $obfuscated = 0;
    my $res = "";
    return($res, $rc) unless defined $string;
    for my $block (split/(\$[\w\d_:\-]+\$)/mx, $string) {
        next if $block eq '';
        if(substr($block,0,1) eq '$' and substr($block, -1) eq '$') {
            if(defined $macros->{$block} or $block =~ m/^\$ARG\d+\$/mx) {
                my $replacement = $macros->{$block};
                $replacement    = '' unless defined $replacement;
                if($block =~ m/\$ARG\d+\$$/mx) {
                    if($skip_args) {
                        $replacement = $block;
                    } else {
                        my($sub_rc, $sub_obfuscated);
                        ($replacement, $sub_rc, $sub_obfuscated) = $self->_get_replaced_string($replacement, $macros, 1);
                        $rc = 0 unless $sub_rc;
                        $obfuscated = 1 if $sub_obfuscated;
                    }
                }
                $block = $replacement;
            } else {
                $rc = 0;
            }
        }
        $res .= $block;
    }

    my $orig = $res;
    $res = $self->_get_obfuscated_string($res, $macros);
    $obfuscated = 1 if $orig ne $res;

    return($res, $rc, $obfuscated);
}

########################################
sub _obfuscate {
    my( $self, $args ) = @_;

    my $string  = $args->{'string'};
    my $macros  = $self->_get_macros($args);

    return $self->_get_obfuscated_string($string, $macros);
}

########################################

=head2 _get_obfuscated_string

  _get_obfuscated_string

replace sensitive data with ***

=cut

sub _get_obfuscated_string {
    my( $self, $string, $macros ) = @_;

    if(defined $macros->{'obfuscate'} && !$macros->{'obfuscate'}) {
        return $string;
    }

    # regexp pattern
    for my $m ($macros->{'$_SERVICEOBFUSCATE_ME$'}, $macros->{'$_HOSTOBFUSCATE_ME$'}, $macros->{'$_SERVICEOBFUSCATE_REGEXP$'}, $macros->{'$_HOSTOBFUSCATE_REGEXP$'}, $macros->{'$_SERVICEOBFUSCATE_REGEX$'}, $macros->{'$_HOSTOBFUSCATE_REGEX$'}) {
        next unless defined $m;
        if($m =~ m/^(b64|base64):(.*)$/gmx) {
            $m = MIME::Base64::decode_base64($2);
        }
        eval {
            ## no critic
            $string =~ s/$m/\*\*\*/g;
            ## use critic
        };
    }

    # string pattern
    for my $m ($macros->{'$_SERVICEOBFUSCATE_STRING$'}, $macros->{'$_HOSTOBFUSCATE_STRING$'}, $macros->{'$_SERVICEOBFUSCATE_STR$'}, $macros->{'$_HOSTOBFUSCATE_STR$'}) {
        next unless defined $m;
        if($m =~ m/^(b64|base64):(.*)$/gmx) {
            $m = MIME::Base64::decode_base64($2);
        }
        eval {
            ## no critic
            $string =~ s/\Q$m\E/\*\*\*/g;
            ## use critic
        };
    }

    my $c = $Thruk::Globals::c;
    if($c->config->{'commandline_obfuscate_pattern'}) {
        for my $pattern (@{$c->config->{'commandline_obfuscate_pattern'}}) {
            ## no critic
            eval('$string =~ s'.$pattern.'g');
            ## use critic
        }
    }

    return $string;
}

########################################

=head2 _set_host_macros

  _set_host_macros

set host macros

=cut

sub _set_host_macros {
    my( $self, $host, $macros ) = @_;

    # normal host macros
    $macros->{'$HOSTADDRESS$'}        = (defined $host->{'host_address'})            ? $host->{'host_address'}            : $host->{'address'};
    $macros->{'$HOSTNAME$'}           = (defined $host->{'host_name'})               ? $host->{'host_name'}               : $host->{'name'};
    $macros->{'$HOSTALIAS$'}          = (defined $host->{'host_alias'})              ? $host->{'host_alias'}              : $host->{'alias'};
    $macros->{'$HOSTSTATEID$'}        = (defined $host->{'host_state'})              ? $host->{'host_state'}              : $host->{'state'};
    $macros->{'$HOSTSTATETYPE'}       = (defined $host->{'host_state_type'})         ? $host->{'host_state_type'}         : $host->{'state_type'};
    $macros->{'$HOSTLATENCY$'}        = (defined $host->{'host_latency'})            ? $host->{'host_latency'}            : $host->{'latency'};
    $macros->{'$HOSTOUTPUT$'}         = (defined $host->{'host_plugin_output'})      ? $host->{'host_plugin_output'}      : $host->{'plugin_output'};
    $macros->{'$HOSTPERFDATA$'}       = (defined $host->{'host_perf_data'})          ? $host->{'host_perf_data'}          : $host->{'perf_data'};
    $macros->{'$HOSTATTEMPT$'}        = (defined $host->{'host_current_attempt'})    ? $host->{'host_current_attempt'}    : $host->{'current_attempt'};
    $macros->{'$MAXHOSTATTEMPTS$'}    = (defined $host->{'host_max_check_attempts'}) ? $host->{'host_max_check_attempts'} : $host->{'max_check_attempts'};
    $macros->{'$HOSTDOWNTIME$'}       = (defined $host->{'host_scheduled_downtime_depth'}) ? $host->{'host_scheduled_downtime_depth'} : $host->{'scheduled_downtime_depth'};
    $macros->{'$HOSTCHECKCOMMAND$'}   = (defined $host->{'host_check_command'})      ? $host->{'host_check_command'}      : $host->{'check_command'};
    $macros->{'$HOSTNOTES$'}          = (defined $host->{'host_notes'})              ? $host->{'host_notes'}              : $host->{'notes'};
    $macros->{'$HOSTNOTESURL$'}       = (defined $host->{'host_notes_url_expanded'}) ? $host->{'host_notes_url_expanded'} : $host->{'notes_url_expanded'};
    $macros->{'$HOSTDURATION$'}       = (defined $host->{'host_last_state_change'})  ? $host->{'host_last_state_change'}  : $host->{'last_state_change'};
    $macros->{'$HOSTDURATION$'}       = (defined $macros->{'$HOSTDURATION$'})        ? time() - $macros->{'$HOSTDURATION$'} : 0;
    $macros->{'$HOSTSTATE$'}          = Thruk::Utils::Filter::hoststate2text($macros->{'$HOSTSTATEID$'}) // "";
    $macros->{'$HOSTSTATETYPE'}       = (defined $macros->{'$HOSTSTATETYPE'})        ? $macros->{'$HOSTSTATETYPE'} == 1 ? 'HARD' : 'SOFT' : '';
    $macros->{'$HOSTBACKENDNAME$'}    = '';
    $macros->{'$HOSTBACKENDADDRESS$'} = '';
    my $peer = defined $host->{'peer_key'} ? $self->get_peer_by_key($host->{'peer_key'}) : undef;
    if($peer) {
        $macros->{'$HOSTBACKENDNAME$'}    = (defined $peer->{'name'}) ? $peer->{'name'} : '';
        $macros->{'$HOSTBACKENDADDRESS$'} = (defined $peer->{'addr'}) ? $peer->{'addr'} : '';
        $macros->{'$HOSTBACKENDID$'}      = (defined $peer->{'key'})  ? $peer->{'key'}  : '';
    }

    my $prefix = (defined $host->{'host_custom_variable_names'}) ? 'host_' : '';

    # host user macros
    my $x = 0;
    if(ref $host->{$prefix.'custom_variable_names'} eq 'ARRAY') {
        for my $key (@{$host->{$prefix.'custom_variable_names'}}) {
            $macros->{'$_HOST'.$key.'$'}  = $host->{$prefix.'custom_variable_values'}->[$x];
            $x++;
        }
    }

    return $macros;
}

########################################

=head2 _set_service_macros

  _set_service_macros

sets service macros

=cut

sub _set_service_macros {
    my( $self, $service, $macros ) = @_;

    # normal service macros
    $macros->{'$SERVICEDESC$'}           = $service->{'description'};
    $macros->{'$SERVICESTATEID$'}        = $service->{'state'};
    $macros->{'$SERVICESTATE$'}          = Thruk::Utils::Filter::state2text($service->{'state'}) // "";
    $macros->{'$SERVICESTATETYPE$'}      = $service->{'state_type'} ? 'HARD' : 'SOFT';
    $macros->{'$SERVICELATENCY$'}        = $service->{'latency'};
    $macros->{'$SERVICEOUTPUT$'}         = $service->{'plugin_output'};
    $macros->{'$SERVICEPERFDATA$'}       = $service->{'perf_data'};
    $macros->{'$SERVICEATTEMPT$'}        = $service->{'current_attempt'};
    $macros->{'$MAXSERVICEATTEMPTS$'}    = $service->{'max_check_attempts'};
    $macros->{'$SERVICECHECKCOMMAND$'}   = $service->{'check_command'};
    $macros->{'$SERVICEBACKENDID$'}      = $service->{'peer_key'};
    $macros->{'$SERVICENOTESURL$'}       = $service->{'notes_url_expanded'};
    $macros->{'$SERVICEDURATION$'}       = time() - $service->{'last_state_change'};
    $macros->{'$SERVICEDOWNTIME$'}       = $service->{'scheduled_downtime_depth'};
    my $peer = defined $service->{'peer_key'} ? $self->get_peer_by_key($service->{'peer_key'}) : undef;
    if($peer) {
        $macros->{'$SERVICEBACKENDNAME$'}    = (defined $peer->{'name'}) ? $peer->{'name'} : '';
        $macros->{'$SERVICEBACKENDADDRESS$'} = (defined $peer->{'addr'}) ? $peer->{'addr'} : '';
    }

    # service user macros...
    my $x = 0;
    if(ref $service->{'custom_variable_names'} eq 'ARRAY') {
        for my $key (@{$service->{'custom_variable_names'}}) {
            $macros->{'$_SERVICE'.$key.'$'} = $service->{'custom_variable_values'}->[$x];
            $x++;
        }
    }

    return $macros;
}

########################################

=head2 _do_on_peers

  _do_on_peers($function, $args, [ $force_serial ], [ $backends ], [ $raw_result ])

returns a result for a function called for all peers

  $function is the name of the function called on our peers
  $args is a hash:
  {
    backend => []     # array of backends where this sub should be called
  }

=cut

sub _do_on_peers {
    my( $self, $function, $arg, $force_serial, $backends, $raw_result ) = @_;
    my $c = $Thruk::Globals::c;
    confess("no context") unless $c;

    $c->stats->profile( begin => '_do_on_peers('.$function.')');

    my($get_results_for, $arg_array, $arg_hash) = $self->select_backends($function, $arg);
    $get_results_for = $backends if $backends;
    my %arg = %{$arg_hash};
    $arg = $arg_array;

    # send query to selected backends
    my $num_selected_backends = scalar @{$get_results_for};
    if($function ne 'send_command' && $function ne 'get_processinfo') {
        $c->stash->{'num_selected_backends'} = $num_selected_backends;
        $c->stash->{'selected_backends'}     = $get_results_for;
    }

    my($result, $type, $totalsize, $err, $skip_lmd);
    if($ENV{'THRUK_USE_LMD'}
        && ($function =~ m/^get_/mx || $function eq 'send_command')
        && ($function ne 'get_logs' || !$c->config->{'logcache'})
    ) {
        _debug('livestatus (by lmd): '.$function.': '.join(', ', @{$get_results_for})) if Thruk::Base->debug;
        ($result, $type, $totalsize, $err) = $self->_get_result_lmd_with_retries($c, $get_results_for, $function, $arg, 1);
    } else {
        $skip_lmd = 1;
        _debug('livestatus (no lmd): '.$function.': '.join(', ', @{$get_results_for})) if Thruk::Base->debug;
        ($result, $type, $totalsize, $err) = $self->_get_result($get_results_for, $function, $arg, $force_serial);
    }
    local $ENV{'THRUK_USE_LMD'} = "" if $skip_lmd;

    for my $key (sort keys %{$c->stash->{'failed_backends'}}) {
        # cleanup errors a bit
        $c->stash->{'failed_backends'}->{$key} =~ s/^ERROR:\s*//mx;
        $c->stash->{'failed_backends'}->{$key} =~ s/,\s*<GEN1>\s*line\s*\d+\.$//mx;
    }

    &timing_breakpoint('_get_result: '.$function);
    if(!defined $result || $err) {
        if(!$err) {
            $err = join("\n", map { Thruk::Utils::Filter::peer_name($_).": ".$c->stash->{'failed_backends'}->{$_} } sort keys %{$c->stash->{'failed_backends'}});
        }
        my($short_err, undef) = Thruk::Utils::extract_connection_error($err);
        _debug($err);
        _debug2(Carp::longmess("backend error"));
        $err = $short_err if $short_err;
        $c->stash->{'backend_error'} = $err;
        if($function eq 'send_command'
            || $c->stash->{backend_errors_handling} == DIE
            || ($ENV{'THRUK_MODE'}//'') eq 'TEST'
            || $err =~ m/^\Qbad request:\E/gmx
        ) {
            die($err);
        }
    }

    # extract some extra data
    if($function eq 'get_processinfo' && ref $result eq 'HASH') {
        # update configtool settings
        # and update last_program_starts
        # (set in Thruk::Utils::CLI::_cmd_raw)
        for my $key (keys %{$result}) {
            my $res = $result->{$key}->{$key};
            if($result->{$key}->{'configtool'} || $result->{$key}->{'thruk'}) {
                $res = $result->{$key};
            }
            if($res && ($res->{'configtool'} || ($res->{'thruk'} && $res->{'thruk'}->{'configtool'}))) {
                my $peer = $self->get_peer_by_key($key);
                $peer->{'thrukextras'} = $res->{'thruk'} if $res->{'thruk'};
                if($res->{'remote_peer_key'}) { # set from HTTP.pm
                    $peer->{'remotekey'} = $res->{'remote_peer_key'};
                }
                if($res->{'thruk'} && $res->{'thruk'}->{'remotekey'}) { # set via LMD
                    $peer->{'remotekey'} = $res->{'thruk'}->{'remotekey'};
                }

                next if $peer->{'configtool'}->{'disable'};
                my $configtool = $res->{'configtool'} // $res->{'thruk'}->{'configtool'};
                next if $configtool->{'disable'};
                # do not overwrite local configuration with remote configtool settings
                # only use remote if the local one is empty
                next if(scalar keys %{$peer->{'configtool'}} != 0 && !$peer->{'configtool'}->{'remote'});
                $peer->{'configtool'} = { remote => 1 };
                for my $attr (keys %{$configtool}) {
                    $peer->{'configtool'}->{$attr} = $configtool->{$attr};
                }
            }
        }
    }

    return($result, $type, $totalsize) if $raw_result;

    $type = '' unless defined $type;
    $type = lc $type;

    # howto merge the answers?
    my($data, $must_resort);
    if( $type eq 'file' ) {
        $data = $result;
    }
    elsif( $type eq 'uniq' ) {
        $data = $self->_merge_answer( $result, $type );
        my %seen = ();
        my @uniq = sort( grep { !$seen{$_}++ } @{$data} );
        $data = \@uniq;
    }
    elsif ( $type eq 'stats' ) {
        $data = $self->_merge_stats_answer($result);
    }
    elsif ( $type eq 'sum' ) {
        $data = $self->_sum_answer($result);
    }
    elsif ( $function eq 'get_hostgroups' ) {
        $result = {} if $num_selected_backends == 0;
        $data = $self->_merge_hostgroup_answer($result);
        $must_resort = 1;
    }
    elsif ( $function eq 'get_servicegroups' ) {
        $result = {} if $num_selected_backends == 0;
        $data = $self->_merge_servicegroup_answer($result);
        $must_resort = 1;
    }
    else {
        $data = $self->_merge_answer( $result, $type );
    }
    if($function eq 'get_logs' && !$c->config->{'logcache'}) {
        $must_resort = 1;
    }

    # additional data processing, paging, sorting and limiting
    if(scalar keys %arg > 0) {
        if( $arg{'remove_duplicates'} ) {
            $data = remove_duplicates($data);
            $totalsize = scalar @{$data} unless $ENV{'THRUK_USE_LMD'};
        }

        if(!$ENV{'THRUK_USE_LMD'} || $must_resort) {
            if( $arg{'sort'} ) {
                if($type ne 'sorted' or scalar keys %{$result} > 1) {
                    $data = $self->sort_result( $data, $arg{'sort'} );
                }
            }

            if( $arg{'limit'} ) {
                $data = _limit( $data, $arg{'limit'} );
            }
        }

        if($arg{'pager'} && ref $data eq 'ARRAY') {
            my $already_paged = $ENV{'THRUK_USE_LMD'} ? 1 : 0;
            if($arg{'pager'}->{'entries'} && $arg{'pager'}->{'entries'} =~ /^\d+$/mx && scalar @{$data} > $arg{'pager'}->{'entries'}) {
                $already_paged = 0;
            }
            $data = Thruk::Utils::page_data($c, $data, undef, $totalsize, $already_paged);
        }
    }

    # strict templates require icinga2 undef values to be replaced
    if($c->config->{'thruk_author'}) {
        my $replace = 0;
        for my $key (@{$get_results_for}) {
            if(Thruk::Utils::Filter::is_icinga2($key)) {
                $replace = 1;
                last;
            }
        }
        # replace undef values
        if($replace) {
            # but only in lists of hashes
            if(ref $data eq 'ARRAY' && $data->[0] && ref $data->[0] eq 'HASH') {
                for my $row (@{$data}) {
                    for my $key (keys %{$row}) {
                        $row->{$key} = '' unless defined $row->{$key};
                    }
                }
            }
        }
    }

    if($type eq 'group_stats' || ($function =~ /stats/mx && $arg{'columns'})) {
        $data = $self->_set_result_group_stats($function, $data, $arg{'columns'});
    } else {
        $data = $self->_set_result_defaults($function, $data);
    }

    $c->stats->profile( end => '_do_on_peers('.$function.')');

    return($data, $totalsize) if wantarray;
    return $data;
}

########################################

=head2 select_backends

  select_backends($function, [$args])

select backends we want to run functions on

=cut

sub select_backends {
    my($self, $function, $arg) = @_;
    my $c = $Thruk::Globals::c;
    confess("no context") unless $c;

    $function = 'get_' unless $function;

    # do we have to send the query to all backends or just a few?
    my(%arg, $backends);
    if(     ( $function =~ m/^get_/mxo or $function eq 'send_command')
        and ref $arg eq 'ARRAY'
        and scalar @{$arg} % 2 == 0 )
    {
        %arg = @{$arg};

        if( $arg{'backend'} ) {
            if(ref $arg{'backend'} eq 'ARRAY') {
                for my $b (@{$arg{'backend'}}) {
                    $backends->{$b} = 1;
                }
            } else {
                for my $b (split(/,/mxo,$arg{'backend'})) {
                    $backends->{$b} = 1;
                }
            }
        }
        if(exists $arg{'pager'}) {
            delete $arg{'pager'};
            $arg{'pager'} = {
                entries     => $c->req->parameters->{'entries'} // $c->stash->{'default_page_size'},
                page        => $c->req->parameters->{'page'} // 1,
                total_pages => 1,
            };
        }

        # no paging except on html pages
        my $view_mode = $c->req->parameters->{'view_mode'} || 'html';
        if($view_mode ne 'html') {
            delete $arg{'pager'};
        }

        if(   $function eq 'get_hosts'
           or $function eq 'get_services'
           ) {
            $arg{'enable_shinken_features'} = $c->stash->{'enable_shinken_features'};
        }

        if(exists $arg{'limit'}) {
            $arg{'options'}->{'limit'} = delete $arg{'limit'};
        }

        @{$arg} = %arg;
    }

    # send query to selected backends
    my $get_results_for = [];
    for my $peer ( @{ $self->get_peers() } ) {
        if($c->stash->{'failed_backends'}->{$peer->{'key'}}) {
            if(!$ENV{'THRUK_USE_LMD'}) {
                _debug("skipped peer (down): ".$peer->{'name'}) if Thruk::Base->trace;
                next;
            }
        }
        if(defined $backends) {
            unless(defined $backends->{$peer->{'key'}}) {
                _debug("skipped peer (undef): ".$peer->{'name'}) if Thruk::Base->trace;
                next;
            }
        }
        elsif($peer->{'enabled'} != 1) {
            _debug("skipped peer (disabled): ".$peer->{'name'}) if Thruk::Base->trace;
            next;
        }
        push @{$get_results_for}, $peer->{'key'};
    }
    if(defined $backends && $backends->{'ALL'}) {
        push @{$get_results_for}, 'ALL';
    }
    if(defined $backends && $backends->{'LOCAL'}) {
        push @{$get_results_for}, 'LOCAL';
    }
    return($get_results_for, $arg, \%arg);
}


########################################

=head2 _get_result

  _get_result($peers, $function, $args)

run function on several peers and collect result.

=cut

sub _get_result {
    my($self, $peers, $function, $arg, $force_serial) = @_;

    my($result, $type, $totalsize);
    eval {
        if($ENV{'THRUK_NO_CONNECTION_POOL'} || $force_serial || scalar @{$peers} <= 1) {
            ($result, $type, $totalsize) = $self->_get_result_serial($peers, $function, $arg);
        } else {
            ($result, $type, $totalsize) = $self->_get_result_parallel($peers, $function, $arg);
        }
    };
    my $err = $@;

    return($result, $type, $totalsize, $err);
}

########################################

=head2 _get_result_lmd

  _get_result_lmd($peers, $function, $arguments)

returns result for given function using lmd

=cut

sub _get_result_lmd {
    my($self,$peers, $function, $arg) = @_;
    my ($totalsize, $result, $type) = (0, []);
    my $c  = $Thruk::Globals::c;
    my $t1 = [gettimeofday];
    $c->stats->profile( begin => "_get_result_lmd($function)");

    delete $c->stash->{'lmd_ok'};
    delete $c->stash->{'lmd_error'};

    if(scalar @{$peers} == 0) {
        _add_query_stats($c, 0, $function, $arg, {});
        return($result, $type, $totalsize);
    }

    my $peer = $self->lmd_peer;
    $peer->{'live'}->default_backends(@{$peers});
    my @res = $peer->$function(@{$arg});
    $peer->{'live'}->default_backends();
    ($result, $type, $totalsize) = @res;

    my $elapsed = tv_interval($t1);
    my $meta = $peer->{'live'}->{'backend_obj'}->{'meta_data'};
    _add_query_stats($c, $elapsed, $function, $arg, $meta);

    if($meta) {
        $c->stash->{'lmd_ok'} = 1;
    }
    # update failed backends
    if($meta && $meta->{'failed'}) {
        for my $key (@{$peers}) {
            next if $key eq 'ALL';
            delete $c->stash->{'failed_backends'}->{$key};
            my $peer = $self->get_peer_by_key($key);
            next unless $peer;
            $peer->{'enabled'}    = 1 unless $peer->{'enabled'} == 2; # not for hidden ones
            $peer->{'runnning'}   = 1;
            $peer->{'last_error'} = 'OK';
        }
        for my $key (keys %{$meta->{'failed'}}) {
            $c->stash->{'failed_backends'}->{$key} = $meta->{'failed'}->{$key};
            my $peer = $self->get_peer_by_key($key);
            next unless $peer;
            $peer->{'runnning'}   = 0;
            $peer->{'last_error'} = $meta->{'failed'}->{$key};
        }
        if(scalar keys %{$meta->{'failed'}} == scalar @{$peers} && scalar @{$peers} > 0) {
            _debug("%s: none of the %d selected backends were available", $function, scalar @{$peers});
            $c->stash->{'backend_error'} = 1;
        }
    }

    if($meta && $meta->{'total_count'}) {
        $totalsize = $meta->{'total_count'};
    }

    if($function eq 'get_hostgroups' || $function eq 'get_servicegroups' || ($type && (lc($type) eq 'file' || lc($type) eq 'stats'))) {
        # sort result by peer_key
        if(ref $result eq 'ARRAY' && $result->[0] && ref $result->[0] eq 'HASH' && $result->[0]->{'peer_key'}) {
            my $sorted_result = {};
            for my $r (@{$result}) {
                my $key = $r->{'peer_key'};
                $sorted_result->{$key} = [] unless $sorted_result->{$key};
                push @{$sorted_result->{$key}}, $r;
            }
            $result = $sorted_result;
        } else {
            # if no peer_key is available, simply use the first one
            my $key = @{$self->get_peers()}[0]->{'key'};
            $result = { $key => $result };
        }
    }

    if($function eq 'send_command') {
        $result = [];
    }

    $c->stats->profile( end => "_get_result_lmd($function)");
    return($result, $type, $totalsize);
}

########################################
sub _get_result_lmd_with_retries {
    my($self, $c, $peers, $function, $arg, $retries) = @_;

    my($result, $type, $totalsize);
    eval {
        ($result, $type, $totalsize) = $self->_get_result_lmd($peers, $function, $arg);
    };
    my $err = $@;
    return($result, $type, $totalsize, undef) unless $err;

    _debug($err) if $err;
    if($err && $err =~ m/^502:|bad\ request:/mx) { # lmd sends error 502 if all backends are down
        $c->stash->{'lmd_ok'} = 1;
    }

    # catch command errors
    if($function eq 'send_command' && (!$err || $err =~ m/^\d+:\s/mx)) {
        return($result, $type, $totalsize, $err);
    }

    if($err && !$c->stash->{'lmd_ok'}) {
        $c->stats->profile( begin => "_get_result_lmd_with_retries, check lmd proc");
        require Thruk::Utils::LMD;
        Thruk::Utils::LMD::check_proc($c->config, $c, ($ENV{'THRUK_CLI_SRC'} && $ENV{'THRUK_CLI_SRC'} eq 'FCGI') ? 1 : 0);
        sleep(1);
        $c->stats->profile( end => "_get_result_lmd_with_retries, check lmd proc");

        # then retry again
        if($retries > 0) {
            $retries = $retries - 1;
            return($self->_get_result_lmd_with_retries($c, $peers, $function, $arg, $retries));
        }

        # no more retries
        my $code = 500;
        if($err =~ m|^(\d+):\s*(.*)$|smx) {
            $code = $1;
            $err  = $2 || $err;
        }
        my($short_err, undef) = Thruk::Utils::extract_connection_error($err);
        $err = $short_err if $short_err;

        if($code != 502) {
            $c->stash->{'lmd_error'} = $self->lmd_peer->peer_addr().": ".$err;
            $c->stash->{'remote_user'} = 'thruk' unless $c->stash->{'remote_user'};
            require Thruk::Utils::External;
            Thruk::Utils::External::perl($c, { expr => 'Thruk::Utils::LMD::kill_if_not_responding($c, $c->config);', background => 1 });
        }
        $err = "internal lmd error - ".($c->stash->{'lmd_error'} || $err);
    }

    return($result, $type, $totalsize, $err);
}

########################################

=head2 _get_result_serial

  _get_result_serial($peers, $function, $arguments)

returns result for given function

=cut

sub _get_result_serial {
    my($self,$peers, $function, $arg) = @_;
    my ($totalsize, $result, $type) = (0);
    my $c  = $Thruk::Globals::c;
    my $t1 = [gettimeofday];
    $c->stats->profile( begin => "_get_result_serial($function)");

    for my $key (@{$peers}) {
        # skip already failed peers for this request
        next if $c->stash->{'failed_backends'}->{$key};

        my @res = $self->pool->do_on_peer($key, $function, $arg);
        my $res = shift @res;
        my($typ, $size, $data, $last_error) = @{$res};
        chomp($last_error) if $last_error;
        if(!$last_error && defined $size) {
            $totalsize += $size;
            $type       = $typ;
            $result->{ $key } = $data;
        }
        &timing_breakpoint('_get_result_serial fetched: '.$key);
        $c->stash->{'failed_backends'}->{$key} = $last_error if $last_error;
        my $peer = $self->get_peer_by_key($key);
        $peer->{'last_error'} = $last_error;
    }

    my $elapsed = tv_interval($t1);
    _add_query_stats($c, $elapsed, $function, $arg);

    $c->stats->profile( end => "_get_result_serial($function)");
    return($result, $type, $totalsize);
}

########################################

=head2 _get_result_parallel

  _get_result_parallel($peers, $function, $arguments)

returns result for given function and args using the worker pool

=cut

sub _get_result_parallel {
    my($self, $peers, $function, $arg) = @_;
    my ($totalsize, $result, $type) = (0);
    my $t1 = [gettimeofday];
    my $c = $Thruk::Globals::c;

    $c->stats->profile( begin => "_get_result_parallel(".join(',', @{$peers}).")");

    my @jobs;
    for my $key (@{$peers}) {
        # skip already failed peers for this request
        if(!$c->stash->{'failed_backends'}->{$key}) {
            push @jobs, [$key, $function, $arg];
        }
    }
    $self->pool->thread_pool->add_bulk(\@jobs);

    my $times = {};
    my $results = $self->pool->thread_pool->remove_all();
    for my $res (@{$results}) {
        my($key, $time, $typ, $size, $data, $last_error) = @{$res};
        $times->{$key} = $time;
        chomp($last_error) if $last_error;
        my $peer = $self->get_peer_by_key($key);
        $c->stash->{'failed_backends'}->{$key} = $last_error if $last_error;
        $peer->{'last_error'} = $last_error;
        if(!$last_error && defined $size) {
            $totalsize += $size;
            $type       = $typ;
            $result->{$key} = $data;
        }
    }

    my $elapsed = tv_interval($t1);
    my @timessorted = reverse sort { $times->{$a} <=> $times->{$b} } keys(%{$times});
    my $slowest = sprintf("slowest site: %s -> %.4f", $timessorted[0], $times->{$timessorted[0]});
    _add_query_stats($c, $elapsed, $function, $arg, undef, $slowest);

    $c->stats->profile( comment => $slowest);

    $c->stats->profile( end => "_get_result_parallel(".join(',', @{$peers}).")");
    return($result, $type, $totalsize);
}

########################################

=head2 remove_duplicates

  remove_duplicates($data)

removes duplicate entries from a array of hashes

=cut

sub remove_duplicates {
    my($data) = @_;
    my $c = $Thruk::Globals::c;

    $c->stats->profile( begin => "Utils::remove_duplicates()" );

    if($data && $data->[0] && ref($data->[0]) eq 'HASH') {
        $data = Thruk::Base::array_uniq_obj($data);
    }
    elsif($data && $data->[0] && ref($data->[0]) eq 'ARRAY') {
        $data = Thruk::Base::array_uniq_list($data);
    } else {
        $data = Thruk::Base::array_uniq($data);
    }

    $c->stats->profile( end => "Utils::remove_duplicates()" );
    return($data);
}

########################################

=head2 reset_failed_backends

  reset_failed_backends([ $c ])

Reset failed backends cache. Retries
are useless unless reseting this cache
because failed backends won't be asked
twice per request.

=cut

sub reset_failed_backends {
    my($self, $c) = @_;
    $c = $Thruk::Globals::c unless $c;
    confess("no c") unless $c;
    $c->stash->{'failed_backends'} = {};
    return;
}

##########################################################

=head2 AUTOLOAD

  AUTOLOAD()

redirects sub calls to our backends

=cut

sub AUTOLOAD {
    my($self, @args) = @_;
    my $name = $AUTOLOAD;
    my $type = ref($self) || confess("$self is not an object, called as (".$name.")");
    confess("called $type instead of Thruk::Backend::Manager") if $type ne 'Thruk::Backend::Manager';
    $name =~ s/.*://mx; # strip fully-qualified part
    return(&_do_on_peers($self, $name, \@args));
}

##########################################################

=head2 DESTROY

  DESTROY()

destroy this

=cut

sub DESTROY {
}

##########################################################
sub _merge_answer {
    my($self, $data, $type) = @_;
    if($ENV{'THRUK_USE_LMD'}) {
        return($data);
    }
    my $c      = $Thruk::Globals::c;
    my $return = [];
    if( defined $type and $type eq 'hash' ) {
        $return = {};
    }

    $c->stats->profile( begin => "_merge_answer()" );

    if(defined $data->{'_all_'}) {
        $return = $data->{_all_};
    }

    # iterate over original peers to retain order
    for my $peer ( @{ $self->get_peers() } ) {
        my $key  = $peer->{'key'};
        my $name = $peer->{'name'};
        next if !defined $data->{$key};
        confess("not a hash") unless ref $data eq 'HASH';

        if( ref $data->{$key} eq 'ARRAY' ) {
            $return = [] unless defined $return;
            if(defined $data->{$key}->[0] && ref $data->{$key}->[0] eq 'HASH') {
                map {
                    $_->{'peer_key'}  = $key;
                    $_->{'peer_name'} = $name;
                } @{$data->{$key}};
            }
            $return = [ @{$return}, @{$data->{$key}} ];
        }
        elsif ( ref $data->{$key} eq 'HASH' ) {
            $return = {} unless defined $return;
            $return = {} unless ref $return eq 'HASH';
            my $tmp = $data->{$key};
            map {
                $tmp->{$_}->{'peer_key'} = $key;
                $tmp->{$_}->{'peer_name'} = $name;
            } keys %{$data->{$key}};
            $return = { %{$return}, %{$data->{$key} } };
        }
        else {
            push @{$return}, $data->{$key};
        }
    }

    $c->stats->profile( end => "_merge_answer()" );

    return ($return);
}

##########################################################
# merge hostgroups and merge 'members' of matching groups
sub _merge_hostgroup_answer {
    my($self, $data) = @_;
    my $c      = $Thruk::Globals::c;
    my $groups = {};

    $c->stats->profile( begin => "_merge_hostgroup_answer()" );

    # iterate over original peers to retain order
    for my $peer ( @{ $self->get_peers() } ) {
        my $key  = $peer->peer_key();
        my $name = $peer->peer_name();
        next if !defined $data->{$key};
        confess("not an array ref") if ref $data->{$key} ne 'ARRAY';

        for my $row ( @{ $data->{$key} } ) {
            if( !defined $groups->{ $row->{'name'} } ) {
                $groups->{ $row->{'name'} } = $row;
                $groups->{ $row->{'name'} }->{'backends_hash'} = { $key => $name };
                next;
            }

            $groups->{ $row->{'name'} }->{'members'} = [ @{ $groups->{ $row->{'name'} }->{'members'} }, @{ $row->{'members'} } ] if $row->{'members'};
            $groups->{ $row->{'name'} }->{'num_hosts'} += $row->{'num_hosts'} if defined $row->{'num_hosts'};
            $groups->{ $row->{'name'} }->{'backends_hash'}->{$key} = $name;
        }
    }

    # set backends used
    for my $group ( values %{$groups} ) {
        $group->{'peer_name'} = [sort values %{ $group->{'backends_hash'}}];
        $group->{'peer_key'}  = [sort keys %{ $group->{'backends_hash'}}];
        delete $group->{'backends_hash'};
    }
    my @return = values %{$groups};

    $c->stats->profile( end => "_merge_hostgroup_answer()" );

    return ( \@return );
}

##########################################################
# merge servicegroups and merge 'members' of matching groups
sub _merge_servicegroup_answer {
    my($self, $data) = @_;
    my $c      = $Thruk::Globals::c;
    my $groups = {};

    $c->stats->profile( begin => "_merge_servicegroup_answer()" );

    # iterate over original peers to retain order
    for my $peer ( @{ $self->get_peers() } ) {
        my $key  = $peer->peer_key();
        my $name = $peer->peer_name();
        next if !defined $data->{$key};
        confess("not an array ref") if ref $data->{$key} ne 'ARRAY';

        for my $row ( @{ $data->{$key} } ) {
            if( !defined $groups->{ $row->{'name'} } ) {
                $groups->{ $row->{'name'} } = $row;
                $groups->{ $row->{'name'} }->{'backends_hash'} = { $key => $name };
                next;
            }

            $groups->{ $row->{'name'} }->{'members'} = [ @{ $groups->{ $row->{'name'} }->{'members'} }, @{ $row->{'members'} } ] if $row->{'members'};
            $groups->{$row->{'name'}}->{'backends_hash'}->{$key} = $name;
        }
    }

    # set backends used
    for my $group ( values %{$groups} ) {
        $group->{'peer_name'} = [sort values %{ $group->{'backends_hash'}}];
        $group->{'peer_key'}  = [sort keys %{ $group->{'backends_hash'}}];
        delete $group->{'backends_hash'};
    }

    my @return = values %{$groups};

    $c->stats->profile( end => "_merge_servicegroup_answer()" );

    return ( \@return );
}

##########################################################
sub _merge_stats_answer {
    my($self, $data) = @_;
    my $c = $Thruk::Globals::c;
    my $return;

    $c->stats->profile( begin => "_merge_stats_answer()" );

    my @peers = keys %{$data};
    return if scalar @peers == 0;

    my $first = shift @peers;
    for my $key ( keys %{ $data->{$first} } ) {
        $return->{$key} = $data->{$first}->{$key};
        if( $key =~ m/_sum$/mxo ) {
            for my $peername ( @peers ) { $return->{$key} += $data->{$peername}->{$key}; }
        }
        elsif ( $key =~ m/_min$/mxo ) {
            for my $peername ( @peers ) { $return->{$key} = $data->{$peername}->{$key} if $return->{$key} > $data->{$peername}->{$key}; }
        }
        elsif ( $key =~ m/_max$/mxo ) {
            for my $peername ( @peers ) { $return->{$key} = $data->{$peername}->{$key} if $return->{$key} < $data->{$peername}->{$key}; }
        }
    }

    # percentages and averages?
    for my $key ( keys %{$return} ) {
        if( $key =~ m/^(.*)_(\d+|all)_sum$/mxo ) {
            my $pkey = $1 . '_sum';
            my $nkey = $1 . '_' . $2 . '_perc';
            if( exists $return->{$pkey} and $return->{$pkey} > 0 ) {
                $return->{$nkey} = $return->{$key} / $return->{$pkey} * 100;
            }
            else {
                $return->{$nkey} = 0;
            }
        }

        # active averages
        for my $akey (
            qw/execution_time_sum
            latency_sum
            active_state_change_sum/
            )
        {
            if( $key =~ m/(hosts|services)_$akey/mx ) {
                my $type = $1;
                my $nkey = $type . '_' . $akey;
                $nkey =~ s/_sum$/_avg/mxo;
                $return->{$nkey} = 0;
                if( $return->{$key} > 0 and $return->{ $type . '_active_sum' } > 0 ) {
                    $return->{$nkey} = $return->{$key} / $return->{ $type . '_active_sum' };
                }
            }
        }

        # passive averages
        for my $akey (qw/passive_state_change_sum/) {
            if( $key =~ m/(hosts|services)_$akey/mx ) {
                my $type = $1;
                my $nkey = $type . '_' . $akey;
                $nkey =~ s/_sum$/_avg/mxo;
                $return->{$nkey} = 0;
                if( $return->{$key} > 0 ) {
                    $return->{$nkey} = $return->{$key} / $return->{ $type . '_passive_sum' };
                }
            }
        }
    }

    $c->stats->profile( end => "_merge_stats_answer()" );

    return $return;
}

##########################################################
sub _sum_answer {
    my($self, $data) = @_;
    my $return;

    if($ENV{'THRUK_USE_LMD'}) {
        if(ref $data ne 'ARRAY') {
            return($data);
        }
        if(scalar @{$data} == 1) {
            return($data->[0]);
        }
        for my $row (@{$data}) {
            for my $key (keys %{$row}) {
                if($key eq 'peer_key') {
                    $return->{$key} = [] unless $return->{$key};
                    push @{$return->{$key}}, $row->{$key};
                }
                elsif(looks_like_number($row->{$key})) {
                    $return->{$key} = 0 unless $return->{$key};
                    $return->{$key} += $row->{$key};
                }
            }
        }
        return($return);
    }

    my @peers = keys %{$data};
    return if scalar @peers == 0;

    my $first = shift @peers;
    for my $key ( keys %{ $data->{$first} } ) {
        $return->{$key} = $data->{$first}->{$key};

        if($key eq 'peer_key') {
            $return->{$key} .= ','.join(',', @peers);
        }
        elsif ( looks_like_number( $data->{$first}->{$key} ) ) {
            for my $peername ( @peers ) { $return->{$key} += ($data->{$peername}->{$key} // 0); }
        }
    }

    return $return;
}

########################################

=head2 sort_result

  sort_result($data, $sortby)

sort a array of hashes by hash keys

  sortby can be a scalar

  $sortby = 'name'

  sortby can be an array

  $sortby = [ 'name', 'description' ]

  sortby can be an hash

  $sortby = { 'DESC' => [ 'name', 'description' ] }

=cut

sub sort_result {
    my($self, $data, $sortby) = @_;
    my $c = $Thruk::Globals::c;
    my( @sorted, $key, $order );

    $c->stats->profile( begin => "sort_result()" ) if $c;

    $key = $sortby;
    if( ref $sortby eq 'HASH' ) {
        if(defined $sortby->{'ASC'} and defined $sortby->{'DESC'}) {
            confess('unusual sort config:\n'.Dumper($sortby));
        }
        for my $ord (qw/ASC DESC/) {
            if( defined $sortby->{$ord} ) {
                $key   = $sortby->{$ord};
                $order = $ord;
                last;
            }
        }
    }

    if( !defined $key ) { confess('missing options in sort()'); }

    $order = "ASC" if !defined $order;

    if(ref $data ne 'ARRAY') { confess("Not an ARRAY reference: ".Dumper($data)); }
    if(!defined $data || scalar @{$data} == 0) {
        $c->stats->profile( end => "sort_result()" ) if $c;
        return \@sorted;
    }

    my @keys;
    if( ref($key) eq 'ARRAY' ) {
        @keys = @{$key};
    }
    else {
        @keys = ($key);
    }

    for my $key (@keys) {
        # add extra column for custom variables
        if($key =~ m/^cust__(.*)$/mx) {
            my $cust = $1;
            for my $d (@{$data}) {
                my $vars = Thruk::Utils::get_custom_vars($c, $d, '', 1);
                $d->{$key} = $vars->{$cust} || $vars->{'HOST'.$cust} || '';
            }
        }
    }

    my @compares;
    for my $key (@keys) {

        # sort numeric
        if( defined $data->[0]->{$key} and looks_like_number($data->[0]->{$key}) ) {
            push @compares, '$a->{"'.$key.'"} <=> $b->{"'.$key.'"}';
        }

        # sort alphanumeric
        else {
            push @compares, '$a->{"'.$key.'"} cmp $b->{"'.$key.'"}';
        }
    }
    my $sortstring = join( ' || ', @compares );

    ## no critic
    no warnings;    # sorting by undef values generates lots of errors
    if( uc $order eq 'ASC' ) {
        eval '@sorted = sort {'.$sortstring.'} @{$data};';
    }
    else {
        eval '@sorted = reverse sort {'.$sortstring.'} @{$data};';
    }
    use warnings;
    ## use critic

    if(scalar @sorted == 0 && $@) {
        confess($@);
    }

    $c->stats->profile( end => "sort_result()" ) if $c;

    return ( \@sorted );
}

# keep alias for backwards compatibility
*_sort = \&sort_result;

########################################

=head2 _sort_nr

  _sort_nr($data, $sortby)

sort a array of array by array nr

  sortby must be an array

  [<nr>, <direction>]

  ex.:

  [5, 'asc']
  [5, 'asc', 13, 'desc']

=cut

sub _sort_nr {
    my($data, $sortby) = @_;

    if(ref $data ne 'ARRAY') { confess("Not an ARRAY reference: ".Dumper($data)); }
    if(scalar @{$data} == 0) {
        return([]);
    }

    my @compares;
    while(@{$sortby}) {
        my $nr  = shift @{$sortby};
        my $dir = shift @{$sortby};

        # sort numeric
        if( defined $data->[0]->[$nr] and $data->[0]->[$nr] =~ m/^[\d\.\-]+$/xm ) {
            if(lc $dir eq 'asc') {
                push @compares, '$a->["'.$nr.'"] <=> $b->["'.$nr.'"]';
            } else {
                push @compares, '$b->["'.$nr.'"] <=> $a->["'.$nr.'"]';
            }
        }

        # sort alphanumeric
        else {
            if(lc $dir eq 'asc') {
                push @compares, '$a->["'.$nr.'"] cmp $b->["'.$nr.'"]';
            } else {
                push @compares, '$b->["'.$nr.'"] cmp $a->["'.$nr.'"]';
            }
        }
    }
    my $sortstring = join( ' || ', @compares );

    my @sorted;
    ## no critic
    no warnings;    # sorting by undef values generates lots of errors
    eval '@sorted = sort {'.$sortstring.'} @{$data};';
    use warnings;
    ## use critic

    if(scalar @sorted == 0 && $@) {
        confess(Dumper($sortstring, $sortby, $@));
    }

    return(\@sorted);
}

########################################

=head2 _limit

  _limit($data, $limit)

returns data limited by limit

=cut

sub _limit {
    my($data, $limit) = @_;

    return $data unless defined $limit and $limit > 0;

    if( scalar @{$data} > $limit ) {
        @{$data} = @{$data}[ 0 .. $limit ];
        return $data;
    }

    return ($data);
}


########################################

=head2 _set_user_macros

  _set_user_macros($args, $macros)

Sets the USER1-256 macros from a resource file. Shinken supports all kind of
macros in resource file, so just replace everything from the resource file.

$args should be:
{
    peer_key      => peer key for the host
    filter        => 0/1   # only add allowed macros
    file          => location of resource file
    args          => list of arguments
}

=cut

sub _set_user_macros {
    my $self   = shift;
    my $args   = shift;
    my $macros = shift || {};
    my $c      = $Thruk::Globals::c or confess("Thruk::Request::c undefined");

    my $search = $args->{'search'} || 'expand_user_macros';
    my $filter = (defined $args->{'filter'}) ? $args->{'filter'} : 1;
    my $vars   = ref $c->config->{$search} eq 'ARRAY' ? $c->config->{$search} : [ $c->config->{$search} ];

    my $res;
    if(defined $args->{'file'}) {
        $res = Thruk::Utils::read_resource_file($args->{'file'});
    }
    if(!defined $res && defined $args->{'peer_key'}) {
        my $backend = $self->get_peer_by_key($args->{'peer_key'});
        if(defined $backend->{'resource_file'}) {
            $res = Thruk::Utils::read_resource_file($backend->{'resource_file'});
        }
    }
    unless(defined $res) {
        $res = Thruk::Utils::read_resource_file($c->config->{'resource_file'});
    }

    if(defined $res) {
        for my $key (keys %{$res}) {
            if($filter and scalar @{$vars}) {
                my $found = 0;
                (my $k = $key) =~ s/\$//gmx;

                for my $test (@{$vars}) {
                    if($test eq 'ALL') {
                        $filter = 0;
                        $found  = 1;
                        last;
                    }

                    if($test eq 'NONE') {
                        # return an empty hash
                        return {};
                    }

                    if($k eq $test) {
                        $found = 1;
                        last;
                    } else {
                        my $v = "".$test;
                        next if CORE::index($v, '*') == -1;
                        $v =~ s/\*/.*/gmx;
                        if($k =~ m/^$v$/mx) {
                            $found = 1;
                            last;
                        }
                    }
                }

                if(!$found) {
                    next;
                }
            }

            $macros->{$key} = $res->{$key};
        }
    }

    return $macros;
}


########################################

=head2 _set_result_defaults

  _set_result_defaults()

set defaults for some results

=cut

sub _set_result_defaults {
    my($self, $function, $data) = @_;

    if(ref $data ne 'ARRAY') {
        return($data);
    }

    my $stats_name;
    if($function =~ m/get_(.*)$/mx) {
        $stats_name = $1;
    }

    # set some defaults if no backends where selected
    if($function eq "get_performance_stats") {
        $data = {};
        for my $type (qw{hosts services}) {
            for my $key (qw{_active_sum _active_1_sum _active_5_sum _active_15_sum _active_60_sum _active_all_sum
                            _active_1_perc _active_5_perc _active_15_perc _active_60_perc _active_all_perc
                            _passive_sum _passive_1_sum _passive_5_sum _passive_15_sum _passive_60_sum _passive_all_sum
                            _passive_1_perc _passive_5_perc _passive_15_perc _passive_60_perc _passive_all_perc
                            _execution_time_sum _latency_sum _active_state_change_sum _execution_time_min _latency_min _active_state_change_min _execution_time_max _latency_max
                            _active_state_change_max _passive_state_change_sum _passive_state_change_min _passive_state_change_max
                            _execution_time_avg _latency_avg _active_state_change_avg _passive_state_change_avg
                        }) {
                $data->{$type.$key} = 0;
            }
        }
    }
    elsif($stats_name && $Thruk::Backend::Provider::Livestatus::stats_columns->{$stats_name}) {
        $data = {};
        for my $key (@{$Thruk::Backend::Provider::Livestatus::stats_columns->{$stats_name}}) {
            next if ref $key;
            $data->{$key} = 0;
        }
    }
    elsif($function eq "get_extra_perf_stats") {
        $data = {};
        for my $key (qw{
                        cached_log_messages connections connections_rate host_checks
                        host_checks_rate requests requests_rate service_checks
                        service_checks_rate neb_callbacks neb_callbacks_rate
                        log_messages log_messages_rate forks forks_rate
                     }) {
            $data->{$key} = 0;
        }
    }
    return $data;
}

########################################

=head2 _set_result_group_stats

  _set_result_group_stats()

set defaults for some results

=cut

sub _set_result_group_stats {
    my($self, $function, $data, $columns) = @_;

    my $group_key = join(",", @{$columns});

    my $res = {};
    for my $row (@{$data}) {
        $res->{$row->{$group_key}} = $row;
    }

    return($res);
}

########################################

=head2 fill_get_can_submit_commands_cache

  fill_get_can_submit_commands_cache($c)

fills cached used by get_can_submit_commands

=cut

sub fill_get_can_submit_commands_cache {
    my($self) = @_;
    my $data = $self->get_contacts(columns => [qw/name email alias can_submit_commands/], "backends" => $self->authoritive_peer_keys() );
    my $hashed = {};
    for my $d (@{$data}) {
        $hashed->{$d->{'name'}} = [] unless defined $hashed->{$d->{'name'}};
        push @{$hashed->{$d->{'name'}}}, $d;
    }
    $self->{'get_can_submit_commands_cache'} = $hashed;
    return;
}

########################################

=head2 get_can_submit_commands

  get_can_submit_commands

wrapper around get_can_submit_commands

=cut

sub get_can_submit_commands {
    my($self, @args) = @_;
    if($self->{'get_can_submit_commands_cache'} && scalar @args == 1) {
        return($self->{'get_can_submit_commands_cache'}->{$args[0]} // []);
    }
    return $self->_do_on_peers('get_can_submit_commands', \@args, undef, $self->authoritive_peer_keys() );
}

########################################

=head2 fill_get_contactgroups_by_contact_cache

  fill_get_contactgroups_by_contact_cache($c)

fills cached used by get_contactgroups_by_contact

=cut

sub fill_get_contactgroups_by_contact_cache {
    my($self) = @_;
    my $contactgroups = $self->get_contactgroups(columns => [qw/name members/], "backends" => $self->authoritive_peer_keys());
    my $groups = {};
    for my $group (@{$contactgroups}) {
        for my $member (@{$group->{'members'}}) {
            $groups->{$member}->{$group->{'name'}} = 1;
        }
    }
    $self->{'get_contactgroups_by_contact_cache'} = $groups;
    return;
}

########################################

=head2 rpc

  rpc($backend, $function, $args)

returns remote call result

=cut

sub rpc {
    my($self, $backend, $function, $args, $keep_su) = @_;
    my $c = $Thruk::Globals::c;
    if(ref $backend eq '') {
        $backend = $self->get_peer_by_key($backend);
    }
    if(!$backend) {
        die("no such backend");
    }
    if($backend->{'type'} ne 'http') {
        die("only supported for http backends");
    }
    _debug(sprintf("[%s] rpc: %s", $backend->{'name'}, $function));
    my @res;
    eval {
        @res = $backend->{'class'}->rpc($c, $function, $args, $keep_su);
    };
    my $err = $@;
    if($err) {
        die(sprintf("[%s] rpc: %s", $backend->{'name'}, $err));
    }
    return(@res);
}

########################################

=head2 page_data

  page_data(...)

wrapper for Thruk::Utils::page_data

=cut

sub page_data {
    return(Thruk::Utils::page_data(@_));
}

########################################

=head2 fork_http_peer

  fork_http_peer($peer, $httpsrc)

create http backend based on livestatus backend which has multiple sources including http ones

=cut

sub fork_http_peer {
    my($peer, $httpsrc) = @_;
    my $options = Thruk::Utils::IO::dclone($peer->{'peer_config'});
    $options->{'options'}->{'peer'} = $httpsrc;
    $options->{'type'}              = 'http';
    $peer = Thruk::Backend::Peer->new($options, $peer->{'thruk_config'}, {});
    return $peer;
}

########################################
sub _add_query_stats {
    my($c, $elapsed, $function, $args, $meta, $comment) = @_;
    return unless($ENV{'THRUK_PERFORMANCE_DEBUG'} || $ENV{'THRUK_JOB_ID'});

    $c->stash->{'total_backend_waited'} += $elapsed;
    $c->stash->{'total_backend_queries'}++;
    $c->stash->{'db_profiles'} = [] unless $c->stash->{'db_profiles'};
    my $profile = {
        function          => $function,
        affected_backends => $c->stash->{'num_selected_backends'},
        duration          => $elapsed,
        meta              => $meta,
        query             => delete $ENV{'THRUK_DB_LAST_QUERY'},
        comment           => $comment,
    };
    $profile->{'stack'} = Carp::longmess($function) if(defined $ENV{'THRUK_PERFORMANCE_DEBUG'} && $ENV{'THRUK_PERFORMANCE_DEBUG'} > 1);
    if(ref $args eq 'ARRAY' && scalar @{$args} % 2 == 0) {
        my %arg = @{$args};
        $profile->{'filter'}     = $arg{'filter'}     if defined $arg{'filter'};
        $profile->{'debug_hint'} = $arg{'debug_hint'} if defined $arg{'debug_hint'};
    }
    if(!$profile->{'debug_hint'}) {
        my $stack = $profile->{'stack'} || Carp::longmess($function);
        if($stack =~ m/lib\/Thruk\/Controller\/(\S+\.pm)\ line\ (\d+)/mx) {
            $profile->{'debug_hint'} = sprintf("%s:%s", $1, $2);
        }
    }
    push @{$c->stash->{'db_profiles'}}, $profile;
    return;
}

########################################

=head2 caching_query

  caching_query($cache_file, $function, $args, $convert_in, $store_separate)

returns db query results and caches them by peer key until backend got restarted

=cut

sub caching_query {
    my($self, $cache_file, $function, $args, $convert_in, $store_separate) = @_;
    my $c = $Thruk::Globals::c;

    $c->stats->profile(begin => "caching_query: ".$function);
    my($selected_backends) = $args->{'backend'} || $c->db->select_backends($function, []);
    my $required_backends = [];

    my $cache;
    my $cached = {};
    if($store_separate) {
        for my $peer_key (@{$selected_backends}) {
            my $cache  = Thruk::Utils::Cache->new($cache_file."/".$peer_key.".cache");
            $cached->{$peer_key} = $cache->get() || {};
        }
    } else {
        $cache  = Thruk::Utils::Cache->new($cache_file);
        my $cached = $cache->get() || {};
    }
    for my $peer_key (@{$selected_backends}) {
        if(!defined $cached->{$peer_key} || !defined $c->stash->{'pi_detail'}->{$peer_key} || !defined $cached->{$peer_key}->{'program_start'} || !defined $c->stash->{'pi_detail'}->{$peer_key}->{'program_start'} || $cached->{$peer_key}->{'program_start'} < $c->stash->{'pi_detail'}->{$peer_key}->{'program_start'}) {
            push @{$required_backends}, $peer_key;
        }
    }

    if(scalar @{$required_backends} > 0) {
        $args = {} unless defined $args;
        $args->{'backends'} = $required_backends;
        my @args = %{$args};
        my $data = $self->_do_on_peers($function, \@args);
        for my $peer_key (@{$required_backends}) {
            $cached->{$peer_key} = {
                program_start => $c->stash->{'pi_detail'}->{$peer_key}->{'program_start'},
                data          => [],
            }
        }
        for my $row (@{$data}) {
            if($convert_in) {
                my $peer_key = delete $row->{'peer_key'};
                push @{$cached->{$peer_key}->{'data'}}, &{$convert_in}($row);
            } else {
                push @{$cached->{$row->{'peer_key'}}->{'data'}}, $row;
            }
        }

        if($store_separate) {
            for my $peer_key (@{$required_backends}) {
                my $cache  = Thruk::Utils::Cache->new($cache_file."/".$peer_key.".cache");
                $cache->set($cached->{$peer_key});
            }
            # simply remove all files older than 24h
            my $yesterday = time() - 86400;
            for my $file (glob($cache_file."/*.cache")) {
                my @stat = stat($file);
                if($stat[9] < $yesterday) {
                    unlink($file);
                }
            }
        } else {
            # remove old backends
            my $all_peer_keys = {};
            for my $key (@{$c->db->peer_order}) { $all_peer_keys->{$key} = 1; }
            for my $key (keys %{$cached}) {
                delete $cached->{$key} unless $all_peer_keys->{$key};
            }
            $cache->set($cached);
        }
    }

    # create result set from all selected backends
    my $res = {};
    for my $peer_key (@{$selected_backends}) {
        $res->{$peer_key} = $cached->{$peer_key}->{'data'};
    }

    $c->stats->profile(end => "caching_query: ".$function);
    return($res);
}

########################################

1;
