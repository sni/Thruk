package Thruk::Backend::Manager;

use strict;
use warnings;
use Carp qw/confess croak/;
use Digest::MD5 qw(md5_hex);
use Data::Dumper qw/Dumper/;
use Scalar::Util qw/looks_like_number/;
use Time::HiRes qw/gettimeofday tv_interval/;
use Thruk ();
use Thruk::Utils ();
#use Thruk::Timer qw/timing_breakpoint/;

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
    my( $class ) = @_;
    my $self = {
        'initialized'         => 0,
        'state_hosts'         => {},
        'local_hosts'         => {},
        'backends'            => [],
        'backend_debug'       => 0,
        'sections'            => {},
        'by_key'              => {},
        'by_name'             => {},
        'last_program_starts' => {},
    };
    bless $self, $class;
    return $self;
}

##########################################################

=head2 init

initialize this model

=cut

sub init {
    my( $self, %options ) = @_;

    for my $key (%options) {
        $self->{$key} = $options{$key};
    }

    return if $self->{'initialized'} == 1;

    # retain order
    $self->{'backends'} = [];
    for my $key (@{$Thruk::Backend::Pool::peer_order}) {
        push @{$self->{'backends'}}, $Thruk::Backend::Pool::peers->{$key};
    }

    # check if we initialized at least one backend
    return if scalar @{ $self->{'backends'} } == 0;

    $self->{'sections'} = {};
    $self->{'sections_depth'} = 0;
    for my $peer (@{$self->get_peers(1)}) {
        $self->{'by_key'}->{$peer->{'key'}}   = $peer;
        $self->{'by_name'}->{$peer->{'name'}} = $peer;

        if($peer->{'state_host'}) {
            $self->{'state_hosts'}->{$peer->{'key'}} = { source => $peer->{'state_host'} };
        } else {
            $self->{'local_hosts'}->{$peer->{'key'}} = 1;
        }
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

    $self->{'initialized'} = 1;

    return 1;
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
    my($self, $all) = @_;
    return \@{$self->{'backends'}} if $all;

    my @peers;
    for my $b (@{$self->{'backends'}}) {
        push @peers, $b if $b->{'addr'};
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
    my $peer = $self->{'by_key'}->{$key};
    return $peer if $peer;
    $peer = $self->{'by_name'}->{$key};
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
    return $self->{'by_name'}->{$name};
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

enables all backends

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
                                        columns => [qw/host_name description active_checks_enabled check_options last_check next_check check_interval is_executing has_been_checked in_check_period/,
                                                    $options{'servicefilter'} ? qw/host_active_checks_enabled host_check_options host_last_check host_next_check host_check_interval host_is_executing host_has_been_checked host_in_check_period/ :()],
                                      );
    my($hosts);
    if($options{'servicefilter'}) {
        # extract hosts from services
        my $uniq = {};
        for my $s (@{$services}) {
            next if defined $uniq->{$s->{'host_name'}};
            next unless ($s->{'host_active_checks_enabled'} == 1 || $s->{'host_check_options'} != 0);
            next unless $s->{'host_check_interval'};
            my $host = {
                host_name               => $s->{'host_name'},
                description             => '',
                active_checks_enabled   => $s->{'host_active_checks_enabled'},
                check_options           => $s->{'host_check_options'},
                last_check              => $s->{'host_last_check'},
                next_check              => $s->{'host_next_check'},
                check_interval          => $s->{'host_check_interval'},
                is_executing            => $s->{'host_is_executing'},
                has_been_checked        => $s->{'host_has_been_checked'},
                in_check_period         => $s->{'host_in_check_period'},
            };
            $uniq->{$s->{'host_name'}} = $host;
        }
        $hosts = [values %{$uniq}];
    } else {
        ($hosts)    = $self->get_hosts(filter => [Thruk::Utils::Auth::get_auth_filter($c, 'hosts'),
                                                  { '-or' => [{ 'active_checks_enabled' => '1' },
                                                             { 'check_options' => { '!=' => '0' }}],
                                                  }, $options{'hostfilter'}],
                                         options => { rename => { 'name' => 'host_name' }, callbacks => { 'description' => 'empty_callback' } },
                                         columns => [qw/name active_checks_enabled check_options last_check next_check check_interval is_executing has_been_checked in_check_period/],
                                        );
    }

    my $queue = [];
    if(defined $services) {
        push @{$queue}, @{$services};
    }
    if(defined $hosts) {
        push @{$queue}, @{$hosts};
    }
    $queue = $self->_sort( $queue, $options{'sort'} ) if defined $options{'sort'};
    $self->_page_data( $c, $queue ) if defined $options{'pager'};
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
    push @args, ('last_program_starts', $self->{'last_program_starts'});
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
    push @args, ('last_program_starts', $self->{'last_program_starts'});
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
    push @args, ('last_program_starts', $self->{'last_program_starts'});
    return $self->_do_on_peers('get_services', \@args );
}

########################################

=head2 get_contactgroups_by_contact

  get_contactgroups_by_contact

returns a list of contactgroups by contact

=cut

sub get_contactgroups_by_contact {
    my( $self, $c, $username, $reload ) = @_;

    my $cached_data = {};
    $cached_data    = $c->cache->get->{'users'}->{$username} if defined $username;
    if( !$reload && defined $cached_data->{'contactgroups'} ) {
        return $cached_data->{'contactgroups'};
    }

    my $data = $self->_do_on_peers( "get_contactgroups_by_contact", [ $username ], undef, $self->get_default_backends());
    my $contactgroups = {};
    for my $group (@{$data}) {
        $contactgroups->{$group->{'name'}} = 1;
    }

    $cached_data->{'contactgroups'} = $contactgroups;
    $c->cache->set('users', $username, $cached_data);
    $c->stash->{'contactgroups'} = $data if($c->stash->{'remote_user'} && $username eq $c->stash->{'remote_user'});
    return $contactgroups;
}

########################################

=head2 get_hostgroup_names_from_hosts

  get_hostgroup_names_from_hosts

returns a list of hostgroups but get list from hosts in order to
respect permissions

=cut

sub get_hostgroup_names_from_hosts {
    my($self, @args) = @_;
    if(scalar @args == 0) { return $self->get_hostgroup_names(); }
    my $hosts = $self->get_hosts( @args, 'columns', ['groups'] );
    my $groups = {};
    for my $host (@{$hosts}) {
        for my $group (@{$host->{'groups'}}) {
            $groups->{$group} = 1;
        }
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
    my($self, @args) = @_;
    if(scalar @args == 0) { return $self->get_servicegroup_names(); }
    my $services = $self->get_services( @args, 'columns', ['groups'] );
    my $groups = {};
    for my $service (@{$services}) {
        for my $group (@{$service->{'groups'}}) {
            $groups->{$group} = 1;
        }
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
    my $c = $Thruk::Request::c;
    eval {
        $self->_do_on_peers( 'reconnect', \@args);
    };
    $c->log->debug($@) if $@;
    return 1;
}

########################################

=head2 expand_command

  expand_command

expand a command line with host/service data

=cut

sub expand_command {
    my( $self, %data ) = @_;
    croak("no host")    unless defined $data{'host'};
    my $host     = $data{'host'};
    my $service  = $data{'service'};
    my $command  = $data{'command'};
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
        my $return = {
            'line'          => 'no command defined',
            'line_expanded' => '',
            'note'          => '',
        };
        return $return;
    }

    # get command data
    my $expanded;
    if(defined $command) {
        $expanded = $command->{'line'};
    } else {
        my $commands = $self->get_commands( filter => [ { 'name' => $name } ] );
        $expanded = $commands->[0]->{'line'};
    }

    my $rc;
    eval {
        ($expanded,$rc) = $self->_replace_macros({string => $expanded, host => $host, service => $service, args => \@com_args});
        $expanded = $self->_obfuscate({string => $expanded, host => $host, service => $service, args => \@com_args});
        $command_name = $self->_obfuscate({string => $command_name, host => $host, service => $service, args => \@com_args});
    };

    # does it still contain macros?
    my $note = "";
    if($@) {
        $note = $@;
        $note =~ s/\s+at\s+\/.*?$//mx;
    } elsif(!$rc) {
        $note = "could not expand all macros!";
    }

    my $return = {
        'line'          => $command_name,
        'line_expanded' => $expanded,
        'note'          => $note,
    };
    return $return;
}

########################################

=head2 set_backend_state_from_local_connections

  set_backend_state_from_local_connections

enables/disables remote backends based on a state from local instances

=cut

sub set_backend_state_from_local_connections {
    my( $self, $disabled, $safe, $cached_data ) = @_;
    $safe = Thruk::ADD_DEFAULTS unless defined $safe;

    my $c = $Thruk::Request::c;

    return $disabled unless scalar keys %{$self->{'local_hosts'}} >= 1;
    return $disabled unless scalar keys %{$self->{'state_hosts'}} >= 1;

    $c->stats->profile( begin => "set_backend_state_from_local_connections() " );

    my $options = [
        'backend', [ keys %{$self->{'local_hosts'}} ],
        'columns', [qw/address name alias state/],
    ];

    my @filter;
    for my $host (values %{$self->{'state_hosts'}}) {
        push @filter, { '-or' => [ { name    => { '=' => $host->{'source'} } },
                                   { alias   => { '=' => $host->{'source'} } },
                                   { address => { '=' => $host->{'source'} } },
                      ]};
    }
    push @{$options}, 'filter', [ Thruk::Utils::combine_filter( '-or', \@filter ) ];


    for(1..3) {
        # reset failed states, otherwise retry would be useless
        $self->reset_failed_backends();

        eval {
            my $data;
            if($safe == Thruk::ADD_CACHED_DEFAULTS) {
                $data = $cached_data->{'local_states'};
            }
            $data = $self->_do_on_peers( "get_hosts", $options ) unless defined $data;
            for my $host (@{$data}) {
                # find matching keys
                my $key;
                for my $state_key (keys %{$self->{'state_hosts'}}) {
                    my $name = $self->{'state_hosts'}->{$state_key}->{'source'};
                    next unless $name;
                    $key = $state_key if $host->{'name'}    eq $name;
                    $key = $state_key if $host->{'address'} eq $name;
                    $key = $state_key if $host->{'alias'}   eq $name;

                    next unless defined $key;
                    next if defined $disabled->{$key} and $disabled->{$key} == 2;

                    $self->{'state_hosts'}->{$key}->{'name'} = $host->{'name'};

                    my $peer = $self->get_peer_by_key($key);

                    if($host->{'state'} == 0) {
                        $c->log->debug($key." -> enabled by local state check (".$host->{'name'}.")");
                        $peer->{'enabled'}    = 1 unless $peer->{'enabled'} == 2; # not for hidden ones
                        $peer->{'runnning'}   = 1;
                        $peer->{'last_error'} = 'UP: peer check via local instance(s) returned state: '.Thruk::Utils::translate_host_status($host->{'state'});
                    } else {
                        $c->log->debug($key." -> disabled by local state check (".$host->{'name'}.")");
                        $self->disable_backend($key);
                        $peer->{'runnning'}   = 0;
                        $peer->{'last_error'} = 'ERROR: peer check via local instance(s) returned state: '.Thruk::Utils::translate_host_status($host->{'state'});
                        $disabled->{$key}     = 1;
                    }
                }
            }
            $cached_data->{'local_states'} = $data;
        };
        if($@) {
            sleep(1);
        } else {
            last;
        }
    }
    # log errors only once
    if($@) {
        return $disabled if $safe;
        $c->log->error("failed setting states by local check");
        $c->log->debug($@);
    }

    $c->stats->profile( end => "set_backend_state_from_local_connections() " );

    return $disabled;
}

########################################

=head2 logcache_stats

  logcache_stats($c)

return logcache statistics

=cut

sub logcache_stats {
    my($self, $c, $with_dates) = @_;
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
        @stats = Thruk::Backend::Provider::Mysql->_log_stats($c);
    } else {
        die("unknown type: ".$type);
    }
    my $stats = Thruk::Utils::array2hash(\@stats, 'key');

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

=head2 renew_logcache

  renew_logcache($c, [$noforks])

update the logcache

=cut

sub renew_logcache {
    my($self, $c, $noforks) = @_;
    $noforks = 0 unless defined $noforks;
    return unless defined $c->config->{'logcache'};
    return if !$c->config->{'logcache_delta_updates'};
    my $rc;
    eval {
        $rc = $self->_renew_logcache($c, $noforks);
    };
    if($@) {
        $c->log->error($@);
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
    $c->log->debug("get_comments_by_pattern() has been called: host = $host, service = $svc, pattern = $pattern");
    my $options  = {'filter' => [{'host_name' => $host}, {'service_description' => $svc}, {'comment' => {'~' => $pattern}}]};
    my $comments = $self->get_comments(%{$options});
    my $ids      = [];
    for my $comm (@{$comments}) {
        my ($cmd) = $comm->{'comment'} =~ m/^DISABLE_([A-Z_]+):/mx;
        $c->log->debug("found comment for command DISABLE_$cmd with ID $comm->{'id'} on backend $comm->{'peer_key'}");
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
    my($get_results_for, undef, undef) = $self->select_backends('renew_logcache', \@args);
    my $check = 0;
    $self->{'logcache_checked'} = {} unless defined $self->{'logcache_checked'};
    for my $key (@{$get_results_for}) {
        if(!defined $self->{'logcache_checked'}->{$key}) {
            $self->{'logcache_checked'}->{$key} = 1;
            $check = 1;
        }
    }

    if($check) {
        $c->stash->{'backends'} = $get_results_for;
        my $stats = $self->logcache_stats($c);
        my $backends2import = [];
        for my $key (@{$get_results_for}) {
            push @{$backends2import}, $key unless defined $stats->{$key};
        }

        if($c->config->{'logcache_import_command'}) {
            local $ENV{'THRUK_BACKENDS'} = join(';', @{$get_results_for});
            local $ENV{'THRUK_LOGCACHE'} = $c->config->{'logcache'};
            if(scalar @{$backends2import} > 0) {
                local $ENV{'THRUK_LOGCACHE_MODE'} = 'import';
                local $ENV{'THRUK_BACKENDS'} = join(';', @{$backends2import});
                return Thruk::Utils::External::cmd($c, { cmd      => $c->config->{'logcache_import_command'},
                                                        message   => 'please stand by while your initial logfile cache will be created...',
                                                        forward   => $c->req->url,
                                                        nofork    => $noforks,
                                                        });
            } else {
                local $ENV{'THRUK_LOGCACHE_MODE'} = 'update';
                my($rc, $output) = Thruk::Utils::IO::cmd($c, $c->config->{'logcache_import_command'});
                if($rc != 0) {
                    Thruk::Utils::set_message( $c, { style => 'fail_message', msg => $output });
                }
            }
        } else {
            my $type = '';
            $type = 'mysql' if $c->config->{'logcache'} =~ m/^mysql/mxi;
            if(scalar @{$backends2import} > 0) {
                return Thruk::Utils::External::perl($c, { expr      => 'Thruk::Backend::Provider::'.(ucfirst $type).'->_import_logs($c, "import")',
                                                        message   => 'please stand by while your initial logfile cache will be created...',
                                                        forward   => $c->req->url,
                                                        backends  => $backends2import,
                                                        nofork    => $noforks,
                                                        });
            }

            $self->_do_on_peers( 'renew_logcache', \@args, 1);
        }
    }
    return;
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
        my $peer = $c->{'db'}->get_peer_by_key($key);
        $peer->logcache->_disconnect() if $peer->{'_logcache'};
    }
    return;
}

########################################

=head2 get_logs_start_end_no_filter

  get_logs_start_end_no_filter($peer)

returns date of first and last log entry

=cut
sub get_logs_start_end_no_filter {
    my($peer) = @_;
    my($start, $end);

    my @steps = (86400*365, 86400*30, 86400*7, 86400);

    my $time = time();
    for my $step (reverse @steps) {
        (undef, $end) = @{$peer->get_logs_start_end(nocache => 1, filter => [{ time => {'>=' => time() - $step }}])};
        last if $end;
    }

    # fetching logs without any filter is a terrible bad idea
    # try to determine start date, simply requesting min/max without filter parses all logfiles
    # so we try a very early date, since requests with an non-existing timerange a super fast
    # (livestatus has an index on all files with start and end timestamp and only parses the file if it matches)

    $time = time() - 86400 * 365 * 10; # assume 10 years as earliest date we want to import, can be overridden by specifing a forcestart anyway
    for my $step (@steps) {
        while($time <= time()) {
            my($data) = $peer->get_logs(nocache => 1, filter => [{ time => { '<=' => $time }}], columns => [qw/time/], options => { limit => 1 });
            if($data && $data->[0]) {
                $time  = $time - $step;
                last;
            }
            $time = $time + $step;
        }
        if($time > time()) {
            $time  = $time - $step;
        }
        $start = $time;
    }
    ($start, undef) = @{$peer->get_logs_start_end(nocache => 1, filter => [{ time => {'>=' => $start - 86400 }}, { time => {'<=' => $start + 86400 }}])};

    return($start, $end);
}

########################################

=head2 lmd_stats

  lmd_stats($c)

return lmd statistics

=cut

sub lmd_stats {
    my($self, $c) = @_;
    return unless defined $c->config->{'use_lmd_core'};
    $self->reset_failed_backends();
    my $stats = $self->get_sites( backend => $self->peer_key() );
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
                        my $sub_rc;
                        ($replacement, $sub_rc) = $self->_get_replaced_string($replacement, $macros, 1);
                        $rc = 0 unless $sub_rc;
                    }
                }
                $block = $replacement;
            } else {
                $rc = 0;
            }
        }
        $res .= $block;
    }

    $res = $self->_get_obfuscated_string($res, $macros);

    return($res, $rc);
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
    if (defined $macros->{'$_SERVICEOBFUSCATE_ME$'}) {
        eval {
            ## no critic
            $string =~ s/$macros->{'$_SERVICEOBFUSCATE_ME$'}/\*\*\*/g;
            ## use critic
        };
    }
    if (defined $macros->{'$_HOSTOBFUSCATE_ME$'}) {
        eval {
            ## no critic
            $string =~ s/$macros->{'$_HOSTOBFUSCATE_ME$'}/\*\*\*/g;
            ## use critic
        };
    }

    my $c = $Thruk::Request::c;
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
    my $c = $Thruk::Request::c;

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
    $macros->{'$HOSTNOTESURL$'}       = (defined $host->{'host_notes_url_expanded'}) ? $host->{'host_notes_url_expanded'} : $host->{'notes_url_expanded'};
    $macros->{'$HOSTDURATION$'}       = (defined $host->{'host_last_state_change'})  ? $host->{'host_last_state_change'}  : $host->{'last_state_change'};
    $macros->{'$HOSTDURATION$'}       = (defined $macros->{'$HOSTDURATION$'})        ? time() - $macros->{'$HOSTDURATION$'} : 0;
    $macros->{'$HOSTSTATE$'}          = (defined $macros->{'$HOSTSTATEID$'})         ? $c->config->{'nagios'}->{'host_state_by_number'}->{$macros->{'$HOSTSTATEID$'}} : 0;
    $macros->{'$HOSTDURATION$'}       = (defined $macros->{'$HOSTDURATION$'})        ? time() - $macros->{'$HOSTDURATION$'} : 0;
    $macros->{'$HOSTSTATETYPE'}       = (defined $macros->{'$HOSTSTATETYPE'})        ? $macros->{'$HOSTSTATETYPE'} == 1 ? 'HARD' : 'SOFT' : '';
    $macros->{'$HOSTBACKENDNAME$'}    = '';
    $macros->{'$HOSTBACKENDADDRESS$'} = '';
    my $peer = defined $host->{'peer_key'} ? $self->get_peer_by_key($host->{'peer_key'}) : undef;
    if($peer) {
        $macros->{'$HOSTBACKENDNAME$'}    = (defined $peer->{'name'}) ? $peer->{'name'} : '';
        $macros->{'$HOSTBACKENDADDRESS$'} = (defined $peer->{'addr'}) ? $peer->{'addr'} : '';
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
    my $c = $Thruk::Request::c;

    # normal service macros
    $macros->{'$SERVICEDESC$'}           = $service->{'description'};
    $macros->{'$SERVICESTATEID$'}        = $service->{'state'};
    $macros->{'$SERVICESTATE$'}          = $c->config->{'nagios'}->{'service_state_by_number'}->{$service->{'state'}};
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

  _do_on_peers($function, $options)

returns a result for a function called for all peers

  $function is the name of the function called on our peers
  $options is a hash:
  {
    backend => []     # array of backends where this sub should be called
  }

=cut

sub _do_on_peers {
    my( $self, $function, $arg, $force_serial, $backends) = @_;
    my $c = $Thruk::Request::c;

    $c->stats->profile( begin => '_do_on_peers('.$function.')');

    my($get_results_for, $arg_array, $arg_hash) = $self->select_backends($function, $arg);
    $get_results_for = $backends if $backends;
    my %arg = %{$arg_hash};
    $arg = $arg_array;

    $c->log->debug('livestatus: '.$function.': '.join(', ', @{$get_results_for})) if Thruk->debug;

    # send query to selected backends
    my $num_selected_backends = scalar @{$get_results_for};
    if($function ne 'send_command' && $function ne 'get_processinfo') {
        $c->stash->{'num_selected_backends'} = $num_selected_backends;
        $c->stash->{'selected_backends'}     = $get_results_for;
    }

    my($result, $type, $totalsize, $skip_lmd);
    if($ENV{'THRUK_USE_LMD'}
       && ($function =~ m/^get_/mx || $function eq 'send_command')
       && ($function ne 'get_logs' || !$c->config->{'logcache'})
       ) {
        eval {
            ($result, $type, $totalsize) = $self->_get_result_lmd($get_results_for, $function, $arg);
        };
        if($@ && !$c->stash->{'lmd_ok'}) {
            Thruk::Utils::LMD::check_proc($c->config, $c, 1);
            sleep(1);
            # then retry again
            eval {
                ($result, $type, $totalsize) = $self->_get_result_lmd($get_results_for, $function, $arg);
            };
            if($@) {
                my $err = $@;
                if($err =~ m|(failed\s+to\s+connect.*)\s+at\s+|mx) {
                    $err = $1;
                }
                elsif($err =~ m|(failed\s+to\s+open\s+socket\s+[^:]+:.*?)\s+at\s+|mx) {
                    $err = $1;
                }
                if(!$c->stash->{'lmd_ok'}) {
                    $c->stash->{'lmd_error'} = $Thruk::Backend::Pool::lmd_peer->peer_addr().": ".$err;
                    $c->stash->{'remote_user'} = 'thruk' unless $c->stash->{'remote_user'};
                    Thruk::Utils::External::perl($c, { expr => 'Thruk::Utils::LMD::kill_if_not_responding($c, $c->config);', background => 1 });
                }
                die("internal lmd error - ".($c->stash->{'lmd_error'} || $@));
            }
        }
    } else {
        $skip_lmd = 1;
        ($result, $type, $totalsize) = $self->_get_result($get_results_for, $function, $arg, $force_serial);
    }
    local $ENV{'THRUK_USE_LMD'} = "" if $skip_lmd;

    #&timing_breakpoint('_get_result: '.$function);
    if(!defined $result && $num_selected_backends != 0) {
        # we don't need a full stacktrace for known errors
        my $err = $@; # only set if there is exact one backend
        if($err =~ m/(couldn't\s+connect\s+to\s+server\s+[^\s]+)/mx) {
            die($1);
        }
        # failed to open socket /tmp/live.sock: No such file or directory
        elsif($err =~ m|(failed\s+to\s+open\s+socket\s+[^:]+:.*?)\s+at\s+|mx) {
            confess($1);
        }
        # failed to connect at .../Class/Lite.pm line 245.
        elsif($err =~ m|(failed\s+to\s+connect)\s+at\s+|mx) {
            die($1);
        }
        elsif($err =~ m|(hit\s\+.*?timeout\s+on.*?)\s+at\s+|mx) {
            die($1);
        }
        elsif($err =~ m|^(DBI\s+.*?)\s+at\s+|mx) {
            die($1);
        }
        elsif($err =~ m|(^\d{3}:\s+.*?)\s+at\s+|mx) {
            die($1);
        }
        elsif($err) {
            die($err);
        } else {
            # multiple backends and all fail
            # die with a small error for know, usually an empty result means that
            # none of our backends were reachable
            die('undefined result');
            #local $Data::Dumper::Deepcopy = 1;
            #my $msg = "Error in _do_on_peers: '".($err ? $err : 'undefined result')."'\n";
            #for my $b (@{$get_results_for}) {
            #    $msg   .= $b.": ".($c->stash->{'failed_backends'}->{$b} || '')."\n";
            #}
            #$msg   .= "called as '".(ref $function ? Dumper($function) : $function)."\n";
            #$msg   .= "with args: ".Dumper(\%arg);
            #confess($msg);
        }
    }
    $type = '' unless defined $type;
    $type = lc $type;

    # extract some extra data
    if($function eq 'get_processinfo' && ref $result eq 'HASH') {
        # update configtool settings
        # and update last_program_starts
        # (set in Thruk::Utils::CLI::_cmd_raw)
        for my $key (keys %{$result}) {
            my $res;
            $res = $result->{$key}->{$key};
            if($result->{$key}->{'configtool'}) {
                $res = $result->{$key};
            }
            if($res && $res->{'configtool'}) {
                my $peer = $self->get_peer_by_key($key);
                # do not overwrite local configuration with remote configtool settings
                # only use remote if the local one is empty
                next if(scalar keys %{$peer->{'configtool'}} != 0 && !$peer->{'configtool'}->{'remote'});
                $peer->{'configtool'} = { remote => 1 };
                for my $attr (keys %{$res->{'configtool'}}) {
                    $peer->{'configtool'}->{$attr} = $res->{'configtool'}->{$attr};
                }
            }
        }
    }

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
            $data = $self->_remove_duplicates($data);
            $totalsize = scalar @{$data} unless $ENV{'THRUK_USE_LMD'};
            $must_resort = 1;
        }

        if(!$ENV{'THRUK_USE_LMD'} || $must_resort) {
            if( $arg{'sort'} ) {
                if($type ne 'sorted' or scalar keys %{$result} > 1) {
                    $data = $self->_sort( $data, $arg{'sort'} );
                }
            }

            if( $arg{'limit'} ) {
                $data = _limit( $data, $arg{'limit'} );
            }
        }

        if( $arg{'pager'} ) {
            local $ENV{'THRUK_USE_LMD'} = undef if $must_resort;
            $data = $self->_page_data(undef, $data, undef, $totalsize);
        }
    }

    # strict templates require icinga2 undef values to be replaced
    if($c->config->{'View::TT'}->{'STRICT'}) {
        my $replace = 0;
        for my $key (@{$get_results_for}) {
            if($c->stash->{'pi_detail'}->{$key}->{'data_source_version'} && $c->stash->{'pi_detail'}->{$key}->{'data_source_version'} =~ m/Livestatus\ r2\./mx) {
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

    $data = $self->_set_result_defaults($function, $data);

    $c->stats->profile( end => '_do_on_peers('.$function.')');

    return $data;
}

########################################

=head2 select_backends

  select_backends($function, [$args])

select backends we want to run functions on

=cut

sub select_backends {
    my($self, $function, $arg) = @_;
    my $c = $Thruk::Request::c;
    confess("no context") unless $c;

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
            if($c->stash->{'use_pager'}) {
                $arg{'pager'} = {
                    entries  => $c->req->parameters->{'entries'} || $c->stash->{'default_page_size'},
                    page     => $c->req->parameters->{'page'} || 1,
                    next     => exists $c->req->parameters->{'next'}      || $c->req->parameters->{'next.x'},
                    previous => exists $c->req->parameters->{'previous'}  || $c->req->parameters->{'previous.x'},
                    first    => exists $c->req->parameters->{'first'}     || $c->req->parameters->{'first.x'},
                    last     => exists $c->req->parameters->{'last'}      || $c->req->parameters->{'last.x'},
                    pages    => $c->req->parameters->{'total_pages'}      || '',
                };
            } else {
                $arg{'pager'} = {};
            }
        }

        # no paging except on html pages
        my $view_mode = $c->req->parameters->{'view_mode'} || 'html';
        if($view_mode ne 'html') {
            delete $arg{'pager'};
            delete $c->stash->{'use_pager'};
        }

        if(   $function eq 'get_hosts'
           or $function eq 'get_services'
           ) {
            $arg{'enable_shinken_features'} = $c->stash->{'enable_shinken_features'};
        }

        @{$arg} = %arg;
    }

    # send query to selected backends
    my $get_results_for = [];
    for my $peer ( @{ $self->get_peers() } ) {
        if($c->stash->{'failed_backends'}->{$peer->{'key'}}) {
            if(!$ENV{'THRUK_USE_LMD'}) {
                $c->log->debug("skipped peer (down): ".$peer->{'name'}) if Thruk->trace;
                next;
            }
        }
        if(defined $backends) {
            unless(defined $backends->{$peer->{'key'}}) {
                $c->log->debug("skipped peer (undef): ".$peer->{'name'}) if Thruk->trace;
                next;
            }
        }
        elsif($peer->{'enabled'} != 1) {
            $c->log->debug("skipped peer (disabled): ".$peer->{'name'}) if Thruk->trace;
            next;
        }
        push @{$get_results_for}, $peer->{'key'};
    }
    if(defined $backends && $backends->{'ALL'}) {
        push @{$get_results_for}, 'ALL';
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
    if($ENV{'THRUK_NO_CONNECTION_POOL'}
       or $force_serial
       or scalar @{$peers} <= 1)
    {
        return $self->_get_result_serial($peers, $function, $arg);
    }
    return $self->_get_result_parallel($peers, $function, $arg);
}

########################################

=head2 _get_result_lmd

  _get_result_lmd($peers, $function, $arguments)

returns result for given function using lmd

=cut

sub _get_result_lmd {
    my($self,$peers, $function, $arg) = @_;
    my ($totalsize, $result, $type) = (0, []);
    my $c  = $Thruk::Request::c;
    my $t1 = [gettimeofday];
    $c->stats->profile( begin => "_get_result_lmd($function)");

    delete $c->stash->{'lmd_ok'};
    delete $c->stash->{'lmd_error'};

    if(scalar @{$peers} == 0) {
        return($result, $type, $totalsize);
    }

    my $peer = $Thruk::Backend::Pool::lmd_peer;
    $peer->{'live'}->default_backends(@{$peers});
    my @res = $peer->$function(@{$arg});
    $peer->{'live'}->default_backends();
    ($result, $type, $totalsize) = @res;

    my $elapsed = tv_interval($t1);
    $c->stash->{'total_backend_waited'} += $elapsed;

    my $meta = $peer->{'live'}->{'backend_obj'}->{'meta_data'};
    if($meta) {
        $c->stash->{'lmd_ok'} = 1;
    }
    # update failed backends
    if($meta && $meta->{'failed'}) {
        for my $key (@{$peers}) {
            next if $key eq 'ALL';
            delete $c->stash->{'failed_backends'}->{$key};
            my $peer = $self->get_peer_by_key($key);
            $peer->{'enabled'}    = 1 unless $peer->{'enabled'} == 2; # not for hidden ones
            $peer->{'runnning'}   = 1;
            $peer->{'last_error'} = 'OK';
        }
        for my $key (keys %{$meta->{'failed'}}) {
            $c->stash->{'failed_backends'}->{$key} = $meta->{'failed'}->{$key};
            my $peer = $self->get_peer_by_key($key);
            $peer->{'runnning'}   = 0;
            $peer->{'last_error'} = $meta->{'failed'}->{$key};
        }
        if(scalar keys %{$meta->{'failed'}} == @{$peers}) {
            die("did not get a valid response for at least any site");
        }
    }
    # REMOVE AFTER: 01.01.2020
    if($meta && $meta->{'total'}) {
        $totalsize = $meta->{'total'};
    }
    # </REMOVE AFTER>
    if($meta && $meta->{'total_count'}) {
        $totalsize = $meta->{'total_count'};
    }

    if($function eq 'get_hostgroups' || $function eq 'get_servicegroups' || ($type && (lc($type) eq 'file' || lc($type) eq 'stats'))) {
        my $key = @{$self->get_peers()}[0]->{'key'};
        $result = { $key => $result };
    }

    if($function eq 'send_command') {
        $result = [];
    }

    $c->stats->profile( end => "_get_result_lmd($function)");
    return($result, $type, $totalsize);
}

########################################

=head2 _get_result_serial

  _get_result_serial($peers, $function, $arguments)

returns result for given function

=cut

sub _get_result_serial {
    my($self,$peers, $function, $arg) = @_;
    my ($totalsize, $result, $type) = (0);
    my $c  = $Thruk::Request::c;
    my $t1 = [gettimeofday];
    $c->stats->profile( begin => "_get_result_serial($function)");

    for my $key (@{$peers}) {
        my $peer = $self->get_peer_by_key($key);
        # skip already failed peers for this request
        next if $c->stash->{'failed_backends'}->{$key};

        my @res = Thruk::Backend::Pool::do_on_peer($key, $function, $arg);
        my $res = shift @res;
        my($typ, $size, $data, $last_error) = @{$res};
        chomp($last_error) if $last_error;
        if(!$last_error && defined $size) {
            $totalsize += $size;
            $type       = $typ;
            $result->{ $key } = $data;
        }
        #&timing_breakpoint('_get_result_serial fetched: '.$key);
        $c->stash->{'failed_backends'}->{$key} = $last_error if $last_error;
        $peer->{'last_error'} = $last_error;
    }

    my $elapsed = tv_interval($t1);
    $c->stash->{'total_backend_waited'} += $elapsed;

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
    my $c = $Thruk::Request::c;

    $c->stats->profile( begin => "_get_result_parallel(".join(',', @{$peers}).")");

    my @jobs;
    for my $key (@{$peers}) {
        # skip already failed peers for this request
        if(!$c->stash->{'failed_backends'}->{$key}) {
            push @jobs, [$key, $function, $arg];
        }
    }
    $Thruk::Backend::Pool::pool->add_bulk(\@jobs);

    my $times = {};
    my $results = $Thruk::Backend::Pool::pool->remove_all();
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

    my @timessorted = reverse sort { $times->{$a} <=> $times->{$b} } keys(%{$times});
    $c->stash->{'total_backend_waited'} += $times->{$timessorted[0]};
    $c->stats->profile( comment => "slowest site: ".$timessorted[0].' -> '.$times->{$timessorted[0]});

    $c->stats->profile( end => "_get_result_parallel(".join(',', @{$peers}).")");
    return($result, $type, $totalsize);
}

########################################

=head2 _remove_duplicates

  _remove_duplicates($data)

removes duplicate entries from a array of hashes

=cut

sub _remove_duplicates {
    my $self = shift;
    my $data = shift;
    my $c    = $Thruk::Request::c;

    $c->stats->profile( begin => "Utils::remove_duplicates()" );

    # calculate md5 sums
    my $uniq = {};
    for my $dat ( @{$data} ) {
        my $peer_key = delete $dat->{'peer_key'};
        my $peer_name = $c->stash->{'pi_detail'}->{$peer_key}->{'peer_name'};
        my $str       = join( ';', grep(defined, sort values %{$dat}));
        utf8::encode($str);
        my $md5       = md5_hex($str);
        if( !defined $uniq->{$md5} ) {
            $dat->{'peer_key'}  = $peer_key;
            $dat->{'peer_name'} = $peer_name;

            $uniq->{$md5} = {
                'data'      => $dat,
                'peer_key'  => [$peer_key],
                'peer_name' => [$peer_name],
            };
        }
        else {
            push @{ $uniq->{$md5}->{'peer_key'} },  $peer_key;
            push @{ $uniq->{$md5}->{'peer_name'} }, $peer_name;
        }
    }

    my $return = [];
    for my $data ( values %{$uniq} ) {
        $data->{'data'}->{'backend'} = {
            'peer_key'  => $data->{'peer_key'},
            'peer_name' => $data->{'peer_name'},
        };
        push @{$return}, $data->{'data'};

    }

    $c->stats->profile( end => "Utils::remove_duplicates()" );
    return ($return);
}

########################################

=head2 page_data

  page_data($c, $data)

adds paged data set to the template stash.
Data will be available as 'data'
The pager itself as 'pager'

=cut

sub page_data {
    local $ENV{'THRUK_USE_LMD'} = undef;
    return(_page_data(undef, @_));
}

########################################

=head2 _page_data

  _page_data($c, $data, [$result_size], [$total_size])

adds paged data set to the template stash.
Data will be available as 'data'
The pager itself as 'pager'

=cut

sub _page_data {
    my $self                = shift;
    my $c                   = shift || $Thruk::Request::c;
    my $data                = shift || [];
    return $data unless defined $c;
    my $default_result_size = shift || $c->stash->{'default_page_size'};
    my $totalsize           = shift;

    # set some defaults
    my $pager = { current_page => 1, total_entries => 0 };
    $c->stash->{'pager'} = $pager;
    $c->stash->{'pages'} = 0;
    $c->stash->{'data'}  = $data;

    # page only in html mode
    my $view_mode = $c->req->parameters->{'view_mode'} || 'html';
    return $data unless $view_mode eq 'html';
    my $entries = $c->req->parameters->{'entries'} || $default_result_size;
    return $data unless defined $entries;
    $c->stash->{'entries_per_page'} = $entries;

    # we dont use paging at all?
    unless($c->stash->{'use_pager'}) {
        $pager->{'total_entries'} = ($totalsize || scalar @{$data});
        return $data;
    }

    if(defined $totalsize) {
        $pager->{'total_entries'} = $totalsize;
    } else {
        $pager->{'total_entries'} = scalar @{$data};
    }
    if($entries eq 'all') { $entries = $pager->{'total_entries'}; }
    my $pages = 0;
    if($entries > 0) {
        $pages = POSIX::ceil($pager->{'total_entries'} / $entries);
    }
    else {
        $c->stash->{'data'} = $data;
        return $data;
    }
    if($pager->{'total_entries'} == 0) {
        $c->stash->{'data'} = $data;
        return $data;
    }

    my $page = 1;
    # current page set by get parameter
    if(defined $c->req->parameters->{'page'}) {
        $page = $c->req->parameters->{'page'};
    }
    # current page set by jump anchor
    elsif(defined $c->req->parameters->{'jump'}) {
        my $nr = 0;
        my $jump = $c->req->parameters->{'jump'};
        if(exists $data->[0]->{'description'}) {
            for my $row (@{$data}) {
                $nr++;
                if(defined $row->{'host_name'} and defined $row->{'description'} and $row->{'host_name'}."_".$row->{'description'} eq $jump) {
                    $page = POSIX::ceil($nr / $entries);
                    last;
                }
            }
        }
        elsif(exists $data->[0]->{'name'}) {
            for my $row (@{$data}) {
                $nr++;
                if(defined $row->{'name'} and $row->{'name'} eq $jump) {
                    $page = POSIX::ceil($nr / $entries);
                    last;
                }
            }
        }
    }

    # last/first/prev or next button pressed?
    if(   exists $c->req->parameters->{'next'}
       or exists $c->req->parameters->{'next.x'} ) {
        $page++;
    }
    elsif (   exists $c->req->parameters->{'previous'}
           or exists $c->req->parameters->{'previous.x'} ) {
        $page-- if $page > 1;
    }
    elsif (    exists $c->req->parameters->{'first'}
            or exists $c->req->parameters->{'first.x'} ) {
        $page = 1;
    }
    elsif (    exists $c->req->parameters->{'last'}
            or exists $c->req->parameters->{'last.x'} ) {
        $page = $pages;
    }

    if(!defined $page)      { $page = 1; }
    if($page !~ m|^\d+$|mx) { $page = 1; }
    if($page < 0)           { $page = 1; }
    if($page > $pages)      { $page = $pages; }

    $c->stash->{'current_page'} = $page;
    $pager->{'current_page'}    = $page;

    if($entries eq 'all') {
        $c->stash->{'data'} = $data;
    }
    else {
        if(!$ENV{'THRUK_USE_LMD'}) {
            if($page == $pages) {
                $data = [splice(@{$data}, $entries*($page-1), $pager->{'total_entries'} - $entries*($page-1))];
            } else {
                $data = [splice(@{$data}, $entries*($page-1), $entries)];
            }
        }
        $c->stash->{'data'} = $data;
    }

    $c->stash->{'pages'} = $pages;

    # set some variables to avoid undef values in templates
    $c->stash->{'pager_previous_page'} = $page > 1      ? $page - 1 : 0;
    $c->stash->{'pager_next_page'}     = $page < $pages ? $page + 1 : 0;

    return $data;
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
    $c = $Thruk::Request::c unless $c;
    confess("no c") unless $c;
    $c->stash->{'failed_backends'} = {};
    return;
}

##########################################################

=head2 AUTOLOAD

  AUTOLOAD()

redirects sub calls to out backends

=cut

sub AUTOLOAD {
    my $self = shift;
    my $name = $AUTOLOAD;
    my $type = ref($self) or confess "$self is not an object, called as (" . $name . ")";
    $name =~ s/.*://mx;    # strip fully-qualified portion
    return $self->_do_on_peers( $name, \@_ );
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
    my $c      = $Thruk::Request::c;
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
    my $c      = $Thruk::Request::c;
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
                $groups->{ $row->{'name'} }->{'members'} = [ @{ $row->{'members'} } ] if $row->{'members'};
            }
            else {
                $groups->{ $row->{'name'} }->{'members'} = [ @{ $groups->{ $row->{'name'} }->{'members'} }, @{ $row->{'members'} } ] if $row->{'members'};
            }

            if( !defined $groups->{ $row->{'name'} }->{'backends_hash'} ) { $groups->{ $row->{'name'} }->{'backends_hash'} = {} }
            $groups->{ $row->{'name'} }->{'backends_hash'}->{$key} = $name;
        }
    }

    # set backends used
    for my $group ( values %{$groups} ) {
        $group->{'backend'} = [];
        @{ $group->{'backend'} }  = sort values %{ $group->{'backends_hash'} };
        @{ $group->{'peer_key'} } = sort keys %{ $group->{'backends_hash'} } unless defined $group->{'peer_key'};
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
    my $c      = $Thruk::Request::c;
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
                $groups->{ $row->{'name'} }->{'members'} = [ @{ $row->{'members'} } ] if $row->{'members'};
            }
            else {
                $groups->{ $row->{'name'} }->{'members'} = [ @{ $groups->{ $row->{'name'} }->{'members'} }, @{ $row->{'members'} } ] if $row->{'members'};
            }
            if( !defined $groups->{ $row->{'name'} }->{'backends_hash'} ) { $groups->{ $row->{'name'} }->{'backends_hash'} = {} }
            $groups->{$row->{'name'}}->{'backends_hash'}->{$key} = $name;
        }
    }

    # set backends used
    for my $group ( values %{$groups} ) {
        $group->{'backend'} = [];
        @{ $group->{'backend'} } = sort values %{ $group->{'backends_hash'} };
        @{ $group->{'peer_key'} } = sort keys %{ $group->{'backends_hash'} } unless defined $group->{'peer_key'};
        delete $group->{'backends_hash'};
    }

    my @return = values %{$groups};

    $c->stats->profile( end => "_merge_servicegroup_answer()" );

    return ( \@return );
}

##########################################################
sub _merge_stats_answer {
    my($self, $data) = @_;
    my $c = $Thruk::Request::c;
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
    if($ENV{'THRUK_USE_LMD'}) {
        return($data);
    }
    my $return;

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

=head2 _sort

  _sort($data, $sortby)

sort a array of hashes by hash keys

  sortby can be a scalar

  $sortby = 'name'

  sortby can be an array

  $sortby = [ 'name', 'description' ]

  sortby can be an hash

  $sortby = { 'DESC' => [ 'name', 'description' ] }

=cut

sub _sort {
    my($self, $data, $sortby) = @_;
    my $c = $Thruk::Request::c;
    my( @sorted, $key, $order );

    $c->stats->profile( begin => "_sort()" ) if $c;

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
        $c->stats->profile( end => "_sort()" ) if $c;
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

    $c->stats->profile( end => "_sort()" ) if $c;

    return ( \@sorted );
}

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
    my $c      = $Thruk::Request::c;

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
    elsif($function eq "get_service_stats" || $function eq "get_service_totals_stats") {
        $data = {};
        for my $key (qw{
                        total total_active total_passive pending pending_and_disabled pending_and_scheduled ok ok_and_disabled ok_and_scheduled
                        warning warning_and_disabled warning_and_scheduled warning_and_ack warning_on_down_host warning_and_unhandled critical
                        critical_and_disabled critical_and_scheduled critical_and_ack critical_on_down_host critical_and_unhandled
                        unknown unknown_and_disabled unknown_and_scheduled unknown_and_ack unknown_on_down_host unknown_and_unhandled
                        flapping flapping_disabled notifications_disabled eventhandler_disabled active_checks_disabled passive_checks_disabled
                        critical_and_disabled_active critical_and_disabled_passive warning_and_disabled_active warning_and_disabled_passive
                        unknown_and_disabled_active unknown_and_disabled_passive ok_and_disabled_active ok_and_disabled_passive
                        active_checks_disabled_active active_checks_disabled_passive
                     }) {
            $data->{$key} = 0;
        }
    }
    elsif($function eq "get_host_stats" || $function eq "get_host_totals_stats") {
        $data = {};
        for my $key (qw{
                        total total_active total_passive pending pending_and_disabled pending_and_scheduled up up_and_disabled up_and_scheduled
                        down down_and_ack down_and_scheduled down_and_disabled down_and_unhandled unreachable unreachable_and_ack unreachable_and_scheduled
                        unreachable_and_disabled unreachable_and_unhandled flapping flapping_disabled notifications_disabled eventhandler_disabled active_checks_disabled passive_checks_disabled outages
                        down_and_disabled_active down_and_disabled_passive unreachable_and_disabled_active unreachable_and_disabled_passive up_and_disabled_active
                        up_and_disabled_passive active_checks_disabled_active active_checks_disabled_passive
                     }) {
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

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
