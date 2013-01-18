package Thruk::Backend::Provider::HTTP;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use JSON::XS;
use LWP::UserAgent;
use LWP::ConnCache;
use Thruk::Utils;
use parent 'Thruk::Backend::Provider::Base';

=head1 NAME

Thruk::Backend::Provider::HTTP - connection provider over http

=head1 DESCRIPTION

connection provider for http connections

=head1 METHODS

=cut
##########################################################

=head2 new

create new manager

=cut
sub new {
    my( $class, $options, $peerconfig, $config ) = @_;

    die("need at least one peer. Minimal options are <options>peer = http://hostname/thruk</options>\ngot: ".Dumper($options)) unless defined $options->{'peer'};

    my $self = {
        'timeout'              => 10,
        'logs_timeout'         => 120,
        'config'               => $config,
        'peerconfig'           => $peerconfig,
        'key'                  => '',
        'name'                 => $options->{'name'},
        'addr'                 => $options->{'peer'},
        'auth'                 => $options->{'auth'},
        'proxy'                => $options->{'proxy'},
        'remotekey'            => '',
        'min_backend_version'  => 1.59,
    };
    bless $self, $class;

    $self->reconnect();

    return $self;
}

##########################################################

=head2 peer_key

return the peers key

=cut

sub peer_key {
    my($self, $new_val) = @_;
    if(defined $new_val) {
        $self->{'key'} = $new_val;
    }
    return $self->{'key'};
}

##########################################################

=head2 peer_addr

return the peers address

=cut

sub peer_addr {
    my($self, $new_val) = @_;
    if(defined $new_val) {
        $self->reconnect();
        $self->{'addr'} = $new_val;
    }
    return $self->{'addr'};
}

##########################################################

=head2 peer_name

return the peers name

=cut

sub peer_name {
    my($self, $new_val) = @_;
    if(defined $new_val) {
        $self->{'name'} = $new_val;
    }
    return $self->{'name'};
}

##########################################################

=head2 reconnect

recreate lwp object

=cut
sub reconnect {
    my($self) = @_;

    if(defined $self->{'logcache'}) {
        $self->{'logcache'}->reconnect();
    }

    # correct address
    $self->{'addr'} =~ s|remote\.cgi$||mx;
    $self->{'addr'} =~ s|/$||mx;
    $self->{'addr'} =~ s|cgi-bin$||mx;
    $self->{'addr'} =~ s|/$||mx;
    $self->{'addr'} =~ s|thruk$||mx;
    $self->{'addr'} =~ s|/$||mx;
    $self->{'addr'} .= '/thruk/cgi-bin/remote.cgi';

    $self->{'ua'} = LWP::UserAgent->new;
    $self->{'ua'}->timeout(30);
    $self->{'ua'}->protocols_allowed( [ 'http', 'https'] );
    $self->{'ua'}->conn_cache(LWP::ConnCache->new());
    $self->{'ua'}->agent('Thruk ');
    if($self->{'proxy'}) {
        $self->{'ua'}->proxy(['http'], $self->{'proxy'});
    }
    # ssl proxy only works this way, see http://community.activestate.com/forum-topic/lwp-https-requests-proxy
    $ENV{'HTTPS_PROXY'} = $self->{'proxy'} if $self->{'proxy'};
    # env proxy breaks the ssl proxy above
    #$self->{'ua'}->env_proxy();
    push @{ $self->{'ua'}->requests_redirectable }, 'POST';
    return;
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
    my($self, $c) = @_;
    return unless defined $self->{'logcache'};
    # renew cache?
    if(!defined $self->{'lastcacheupdate'} or $self->{'lastcacheupdate'} < time()-5) {
        $self->{'lastcacheupdate'} = time();
        $self->{'logcache'}->_import_logs($c, 'update', 0, $self->peer_key());
    }
    return;
}

##########################################################

=head2 send_command

send a command

=cut
sub send_command {
    my($self, @options) = @_;
    $self->_req('send_command', \@options);
    return;
}

##########################################################

=head2 get_processinfo

return the process info

=cut
sub get_processinfo {
    my $self = shift;
    my $res = $self->_req('get_processinfo');
    my($typ, $size, $data) = @{$res};
    if($data) {
        # set remote key from data
        my @rkeys = keys %{$data};
        my $rkey  = $rkeys[0];
        if($self->{'remotekey'} ne $self->{'key'}) {
            $self->{'remotekey'} = $rkey;
        }
        $data->{$self->{'key'}} = delete $data->{$self->{'remotekey'}};
        $data->{$self->{'key'}}->{'peer_key'} = $self->{'key'};

        # update configtool settings
        for my $key (keys %{$self->{'config'}->{'configtool'}}) {
            delete $self->{'config'}->{'configtool'}->{$key};
        }
        if($data->{$self->{'key'}}->{'configtool'}) {
            for my $key (keys %{$data->{$self->{'key'}}->{'configtool'}}) {
                $self->{'config'}->{'configtool'}->{$key} = $data->{$self->{'key'}}->{'configtool'}->{$key};
            }
        }
    }
    return($data, $typ, $size);
}

##########################################################

=head2 get_can_submit_commands

returns if this user is allowed to submit commands

=cut
sub get_can_submit_commands {
    my($self,$user) = @_;
    my $res = $self->_req('get_can_submit_commands', [$user]);
    my($typ, $size, $data) = @{$res};
    return $data;
}

##########################################################

=head2 get_contactgroups_by_contact

  get_contactgroups_by_contact

returns a list of contactgroups by contact

=cut
sub get_contactgroups_by_contact {
    my($self,$user) = @_;
    confess("no user") unless defined $user;
    my $res = $self->_req('get_contactgroups_by_contact', [$user]);
    my($typ, $size, $data) = @{$res};
    return $data;
}

##########################################################

=head2 get_hosts

  get_hosts

returns a list of hosts

=cut
sub get_hosts {
    my($self, @options) = @_;
    my $res = $self->_req('get_hosts', \@options);
    my($typ, $size, $data) = @{$res};
    return($data, undef, $size);
}

##########################################################

=head2 get_hosts_by_servicequery

  get_hosts_by_servicequery

returns a list of host by a services query

=cut
sub get_hosts_by_servicequery {
    my($self, @options) = @_;
    my $res = $self->_req('get_hosts_by_servicequery', \@options);
    my($typ, $size, $data) = @{$res};
    return($data, undef);
}

##########################################################

=head2 get_host_names

  get_host_names

returns a list of host names

=cut
sub get_host_names{
    my($self, @options) = @_;
    my $res = $self->_req('get_host_names', \@options);
    my($typ, $size, $data) = @{$res};
    return($data, 'uniq');
}

##########################################################

=head2 get_hostgroups

  get_hostgroups

returns a list of hostgroups

=cut
sub get_hostgroups {
    my($self, @options) = @_;
    my $res = $self->_req('get_hostgroups', \@options);
    my($typ, $size, $data) = @{$res};
    return $data;
}

##########################################################

=head2 get_hostgroup_names

  get_hostgroup_names

returns a list of hostgroup names

=cut
sub get_hostgroup_names {
    my($self, @options) = @_;
    my $res = $self->_req('get_hostgroup_names', \@options);
    my($typ, $size, $data) = @{$res};
    return($data, 'uniq');
}

##########################################################

=head2 get_services

  get_services

returns a list of services

=cut
sub get_services {
    my($self, @options) = @_;
    my $res = $self->_req('get_services', \@options);
    my($typ, $size, $data) = @{$res};
    return($data, undef, $size);
}

##########################################################

=head2 get_service_names

  get_service_names

returns a list of service names

=cut
sub get_service_names {
    my($self, @options) = @_;
    my $res = $self->_req('get_service_names', \@options);
    my($typ, $size, $data) = @{$res};
    return($data, 'uniq');
}

##########################################################

=head2 get_servicegroups

  get_servicegroups

returns a list of servicegroups

=cut
sub get_servicegroups {
    my($self, @options) = @_;
    my $res = $self->_req('get_servicegroups', \@options);
    my($typ, $size, $data) = @{$res};
    return $data;
}

##########################################################

=head2 get_servicegroup_names

  get_servicegroup_names

returns a list of servicegroup names

=cut
sub get_servicegroup_names {
    my($self, @options) = @_;
    my $res = $self->_req('get_servicegroup_names', \@options);
    my($typ, $size, $data) = @{$res};
    return($data, 'uniq');
}

##########################################################

=head2 get_comments

  get_comments

returns a list of comments

=cut
sub get_comments {
    my($self, @options) = @_;
    my $res = $self->_req('get_comments', \@options);
    my($typ, $size, $data) = @{$res};
    return $data;
}

##########################################################

=head2 get_downtimes

  get_downtimes

returns a list of downtimes

=cut
sub get_downtimes {
    my($self, @options) = @_;
    my $res = $self->_req('get_downtimes', \@options);
    my($typ, $size, $data) = @{$res};
    return $data;
}

##########################################################

=head2 get_contactgroups

  get_contactgroups

returns a list of contactgroups

=cut
sub get_contactgroups {
    my($self, @options) = @_;
    my $res = $self->_req('get_contactgroups', \@options);
    my($typ, $size, $data) = @{$res};
    return $data;
}

##########################################################

=head2 get_logs

  get_logs

returns logfile entries

=cut
sub get_logs {
    my($self, @options) = @_;
    my %options = @options;
    if(defined $self->{'logcache'} and !defined $options{'nocache'}) {
        $options{'collection'} = 'logs_'.$self->peer_key();
        return $self->{'logcache'}->get_logs(@options);
    }
    # increased timeout for logs
    $self->{'ua'}->timeout($self->{'logs_timeout'});
    my $res = $self->_req('get_logs', \@options);
    my($typ, $size, $data) = @{$res};
    $self->{'ua'}->timeout($self->{'timeout'});
    return $data;
}


##########################################################

=head2 get_timeperiods

  get_timeperiods

returns a list of timeperiods

=cut
sub get_timeperiods {
    my($self, @options) = @_;
    my $res = $self->_req('get_timeperiods', \@options);
    my($typ, $size, $data) = @{$res};
    return $data;
}

##########################################################

=head2 get_timeperiod_names

  get_timeperiod_names

returns a list of timeperiod names

=cut
sub get_timeperiod_names {
    my($self, @options) = @_;
    my $res = $self->_req('get_timeperiod_names', \@options);
    my($typ, $size, $data) = @{$res};
    return($data, 'uniq');
}

##########################################################

=head2 get_commands

  get_commands

returns a list of commands

=cut
sub get_commands {
    my($self, @options) = @_;
    my $res = $self->_req('get_commands', \@options);
    my($typ, $size, $data) = @{$res};
    return $data;
}

##########################################################

=head2 get_contacts

  get_contacts

returns a list of contacts

=cut
sub get_contacts {
    my($self, @options) = @_;
    my $res = $self->_req('get_contacts', \@options);
    my($typ, $size, $data) = @{$res};
    return $data;
}

##########################################################

=head2 get_contact_names

  get_contact_names

returns a list of contact names

=cut
sub get_contact_names {
    my($self, @options) = @_;
    my $res = $self->_req('get_contact_names', \@options);
    my($typ, $size, $data) = @{$res};
    return($data, 'uniq');
}

##########################################################

=head2 get_host_stats

  get_host_stats

returns the host statistics for the tac page

=cut
sub get_host_stats {
    my($self, @options) = @_;
    my $res = $self->_req('get_host_stats', \@options);
    my($typ, $size, $data) = @{$res};
    return($data, 'SUM');
}

##########################################################

=head2 get_service_stats

  get_service_stats

returns the services statistics for the tac page

=cut
sub get_service_stats {
    my($self, @options) = @_;
    my $res = $self->_req('get_service_stats', \@options);
    my($typ, $size, $data) = @{$res};
    return($data, 'SUM');
}

##########################################################

=head2 get_performance_stats

  get_performance_stats

returns the service / host execution statistics

=cut
sub get_performance_stats {
    my($self, @options) = @_;
    my $res = $self->_req('get_performance_stats', \@options);
    my($typ, $size, $data) = @{$res};
    return($data, 'STATS');
}

##########################################################

=head2 get_extra_perf_stats

  get_extra_perf_stats

returns the service /host execution statistics

=cut
sub get_extra_perf_stats {
    my($self, @options) = @_;
    my $res = $self->_req('get_extra_perf_stats', \@options);
    my($typ, $size, $data) = @{$res};
    return($data, 'SUM');
}

##########################################################

=head2 _get_logs_start_end

  _get_logs_start_end

returns first and last logfile entry

=cut
sub _get_logs_start_end {
    my($self, @options) = @_;
    my $res = $self->_req('_get_logs_start_end', \@options);
    return($res->[0], $res->[2]);
}

##########################################################

=head2 _req

  _req($sub, $options)

returns result for given request

=cut
sub _req {
    my($self, $sub, $args, $redirects) = @_;
    $redirects = 0 unless defined $redirects;
    my $options = {
        'action' => 'raw',
        'sub'    => $sub,
        'args'   => $args,
    };
    $options->{'auth'} = $args->{'auth'} if defined $args and ref $args eq 'HASH' and defined $args->{'auth'};

    my $response = $self->{'ua'}->post($self->{'addr'}, {
        data => encode_json({
            credential => $self->{'auth'},
            options    => $options,
        })
    });

    if($response->{'_request'}->{'_uri'} =~ m/job\.cgi\?job=(.*)$/mx) {
        $self->_wait_for_remote_job($1);
        $redirects++;
        die("too many redirects") if $redirects > 2;
        return $self->_req($sub, $args, $redirects);
    }

    if($response->is_success) {
        my $data_str = $response->decoded_content;
        my $data;
        eval {
            $data = decode_json($data_str);
        };
        die($@."\ngot: '".$data_str."'") if $@;
        if($data->{'rc'} == 1) {
            my $remote_version = $data->{'version'};
            $remote_version = $remote_version.'~'.$data->{'branch'} if $data->{'branch'};
            if($data->{'output'} =~ m/no\ such\ command/mx) {
                die('backend too old, version returned: '.$remote_version);
            }
            if($data->{'version'} < $self->{'min_backend_version'}) {
                die('backend too old, version returned: '.$remote_version);
            }
            die($data->{'output'});
        }
        if(ref $data->{'output'} eq 'ARRAY') {
            # type, size, data
            if($data->{'output'}->[3]) {
                die($data->{'output'}->[3]);
            }
            $self->_replace_peer_key($data->{'output'}->[2]);

            if(defined $args and ref $args eq 'HASH' and $args->{'wait'} and $data->{'output'}->[2] =~ m/^jobid:(.*)$/mx) {
                return $self->_wait_for_remote_job($1);
            }

            return $data->{'output'};
        }
        die("not an array ref, got ".ref($data->{'output'}));
    }
    die(Thruk::Utils::format_response_error($response));
    return;
}

##########################################################

=head2 _wait_for_remote_job

  _wait_for_remote_job($jobid)

wait till remote job is finished and return that data

=cut
sub _wait_for_remote_job {
    my($self, $jobid) = @_;
    my $res = $self->_req('job', $jobid);
    if($res->[2] =~ m/jobid:([^:]+):0/mx) {
        sleep(1);
        return $self->_wait_for_remote_job($jobid);
    } else {
        my $last_error = "";
        return([undef,
                1,
                [$res->[2]->{'rc'}, $res->[2]->{'out'}],
                $last_error]
        );
    }
}

##########################################################

=head2 _replace_peer_key

  _replace_peer_key($data)

replace remote peer key with our own

=cut
sub _replace_peer_key {
    my($self, $data) = @_;
    return $data unless ref $data eq 'ARRAY';
    for my $r (@{$data}) {
        last unless ref $r eq 'HASH';
        $r->{'peer_key'} = $self->{'key'} if defined $r->{'peer_key'};
    }
    return $data;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
