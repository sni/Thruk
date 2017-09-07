package Thruk::Backend::Provider::HTTP;

use strict;
use warnings;
use Data::Dumper;
use Module::Load qw/load/;
use JSON::XS qw/decode_json encode_json/;
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
    my($class, $options, $peerconfig, $config, $product_prefix, $thruk_config) = @_;

    die("need at least one peer. Minimal options are <options>peer = http://hostname/thruk</options>\ngot: ".Dumper($options)) unless defined $options->{'peer'};

    my $self = {
        'fast_query_timeout'   => 10,
        'timeout'              => 100,
        'logs_timeout'         => 100,
        'config'               => $config,
        'peerconfig'           => $peerconfig,
        'product_prefix'       => $product_prefix,
        'key'                  => '',
        'name'                 => $options->{'name'},
        'addr'                 => $options->{'peer'},
        'auth'                 => $options->{'auth'},
        'proxy'                => $options->{'proxy'},
        'remote_name'          => $options->{'remote_name'} || '', # request this remote peer
        'remotekey'            => '',
        'min_backend_version'  => 1.63,
        'verify_hostname'      => $thruk_config->{'ssl_verify_hostnames'},
    };
    bless $self, $class;

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

=head2 _raw_query

send a raw query to the backend

=cut
sub _raw_query {
    my($self, $query) = @_;
    my $res = $self->_req('_raw_query', [$query]);
    return $res->[2];
}

##########################################################

=head2 reconnect

recreate lwp object

=cut
sub reconnect {
    my($self) = @_;

    my $verify_hostname = 1;
    $verify_hostname = $self->{'verify_hostname'} if defined $self->{'verify_hostname'};
    if(!$self->{'modules_loaded'}) {
        if(!defined $ENV{'THRUK_CURL'} || $ENV{'THRUK_CURL'} == 0) {
            if(defined $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} and $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} == 0 and $self->{'addr'} =~ m/^https:/mx) {
                $verify_hostname = 0;
                eval {
                    # required for new IO::Socket::SSL versions
                    load IO::Socket::SSL;
                    IO::Socket::SSL::set_ctx_defaults( SSL_verify_mode => 0 );
                };
            }
        }
        load Thruk::UserAgent;
    }

    # correct address
    $self->{'addr'} =~ s|remote\.cgi$||mx;
    $self->{'addr'} =~ s|/$||mx;
    $self->{'addr'} =~ s|cgi-bin$||mx;
    $self->{'addr'} =~ s|/$||mx;
    my $pp = $self->{'product_prefix'} || 'thruk';
    $self->{'addr'} =~ s|\Q$pp\E$||mx;
    $self->{'addr'} =~ s|/$||mx;
    $self->{'addr'} .= '/'.$pp.'/cgi-bin/remote.cgi';

    $self->{'ua'} = Thruk::UserAgent->new({ use_curl => $ENV{'THRUK_CURL'} ? 1 : 0 });
    $self->{'ua'}->timeout($self->{'timeout'});
    $self->{'ua'}->protocols_allowed( [ 'http', 'https'] );
    $self->{'ua'}->agent('Thruk');
    $self->{'ua'}->ssl_opts(verify_hostname => $verify_hostname);
    if($self->{'proxy'}) {
        # http just works
        $self->{'ua'}->proxy('http', $self->{'proxy'});
        # ssl depends on which class we have
        if($INC{'IO/Socket/SSL.pm'}) {
            ## no critic
            $ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = "IO::Socket::SSL";
            ## use critic
            my $con_proxy = $self->{'proxy'};
            $con_proxy =~ s#^(http|https)://#connect://#mx;
            $self->{'ua'}->proxy('https', $con_proxy);
        } else {
            # ssl proxy only works this way, see http://community.activestate.com/forum-topic/lwp-https-requests-proxy
            ## no critic
            $ENV{'HTTPS_PROXY'} = $self->{'proxy'} if $self->{'proxy'};
            ## use critic
            # env proxy breaks the ssl proxy above
            #$self->{'ua'}->env_proxy();
        }
    }
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

=head2 renew_logcache

  renew_logcache

renew logcache

=cut
sub renew_logcache {
    my($self, $c) = @_;
    return unless defined $self->{'_peer'}->{'logcache'};
    # renew cache?
    if(!defined $self->{'lastcacheupdate'} || $self->{'lastcacheupdate'} < time()-5) {
        $self->{'lastcacheupdate'} = time();
        $self->{'_peer'}->logcache->_import_logs($c, 'update', 0, $self->peer_key());
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
    $self->{'ua'} || $self->reconnect();
    $self->{'ua'}->timeout($self->{'fast_query_timeout'});
    my $res = $self->_req('get_processinfo');
    $self->{'ua'}->timeout($self->{'timeout'});
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
    }
    return($data, $typ, $size);
}

##########################################################

=head2 get_sites

  get_sites

returns a list of lmd sites

=cut
sub get_sites {
    my($self, @options) = @_;
    my $res = $self->_req('get_sites', \@options);
    my($typ, $size, $data) = @{$res};
    return($data, $typ, $size);
}

##########################################################

=head2 get_can_submit_commands

returns if this user is allowed to submit commands

=cut
sub get_can_submit_commands {
    my($self,$user) = @_;
    $self->{'ua'} || $self->reconnect();
    $self->{'ua'}->timeout($self->{'fast_query_timeout'});
    my $res = $self->_req('get_can_submit_commands', [$user]);
    #my($typ, $size, $data) = @{$res};
    return $res->[2];
}

##########################################################

=head2 get_contactgroups_by_contact

  get_contactgroups_by_contact

returns a list of contactgroups by contact

=cut
sub get_contactgroups_by_contact {
    my($self,$user) = @_;
    $self->{'ua'} || $self->reconnect();
    $self->{'ua'}->timeout($self->{'fast_query_timeout'});
    confess("no user") unless defined $user;
    my $res = $self->_req('get_contactgroups_by_contact', [$user]);
    #my($typ, $size, $data) = @{$res};
    return $res->[2];
}

##########################################################

=head2 get_hosts

  get_hosts

returns a list of hosts

=cut
sub get_hosts {
    my($self, @options) = @_;
    my $res = $self->_req('get_hosts', \@options);
    #my($typ, $size, $data)...
    my(undef, $size, $data) = @{$res};
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
    #my($typ, $size, $data) = @{$res};
    return($res->[2], undef);
}

##########################################################

=head2 get_host_names

  get_host_names

returns a list of host names

=cut
sub get_host_names{
    my($self, @options) = @_;
    my $res = $self->_req('get_host_names', \@options);
    #my($typ, $size, $data) = @{$res};
    return($res->[2], 'uniq');
}

##########################################################

=head2 get_hostgroups

  get_hostgroups

returns a list of hostgroups

=cut
sub get_hostgroups {
    my($self, @options) = @_;
    my $res = $self->_req('get_hostgroups', \@options);
    #my($typ, $size, $data) = @{$res};
    return $res->[2];
}

##########################################################

=head2 get_hostgroup_names

  get_hostgroup_names

returns a list of hostgroup names

=cut
sub get_hostgroup_names {
    my($self, @options) = @_;
    my $res = $self->_req('get_hostgroup_names', \@options);
    #my($typ, $size, $data) = @{$res};
    return($res->[2], 'uniq');
}

##########################################################

=head2 get_services

  get_services

returns a list of services

=cut
sub get_services {
    my($self, @options) = @_;
    my $res = $self->_req('get_services', \@options);
    #my($typ, $size, $data) = @{$res};
    return($res->[2], undef, $res->[1]);
}

##########################################################

=head2 get_service_names

  get_service_names

returns a list of service names

=cut
sub get_service_names {
    my($self, @options) = @_;
    my $res = $self->_req('get_service_names', \@options);
    #my($typ, $size, $data) = @{$res};
    return($res->[2], 'uniq');
}

##########################################################

=head2 get_servicegroups

  get_servicegroups

returns a list of servicegroups

=cut
sub get_servicegroups {
    my($self, @options) = @_;
    my $res = $self->_req('get_servicegroups', \@options);
    #my($typ, $size, $data) = @{$res};
    return $res->[2];
}

##########################################################

=head2 get_servicegroup_names

  get_servicegroup_names

returns a list of servicegroup names

=cut
sub get_servicegroup_names {
    my($self, @options) = @_;
    my $res = $self->_req('get_servicegroup_names', \@options);
    #my($typ, $size, $data) = @{$res};
    return($res->[2], 'uniq');
}

##########################################################

=head2 get_comments

  get_comments

returns a list of comments

=cut
sub get_comments {
    my($self, @options) = @_;
    my $res = $self->_req('get_comments', \@options);
    #my($typ, $size, $data) = @{$res};
    return $res->[2];
}

##########################################################

=head2 get_downtimes

  get_downtimes

returns a list of downtimes

=cut
sub get_downtimes {
    my($self, @options) = @_;
    my $res = $self->_req('get_downtimes', \@options);
    #my($typ, $size, $data) = @{$res};
    return $res->[2];
}

##########################################################

=head2 get_contactgroups

  get_contactgroups

returns a list of contactgroups

=cut
sub get_contactgroups {
    my($self, @options) = @_;
    my $res = $self->_req('get_contactgroups', \@options);
    #my($typ, $size, $data) = @{$res};
    return $res->[2];
}

##########################################################

=head2 get_logs

  get_logs

returns logfile entries

=cut
sub get_logs {
    my($self, @options) = @_;
    my %options = @options;
    if(defined $self->{'_peer'}->{'logcache'} && !defined $options{'nocache'}) {
        $options{'collection'} = 'logs_'.$self->peer_key();
        return $self->{'_peer'}->logcache->get_logs(%options);
    }

    my $use_file = 0;
    if($options{'file'}) {
        # remote backends should not save to files
        $use_file = delete $options{'file'};
        @options = %options;
    }
    # increased timeout for logs
    $self->{'ua'} || $self->reconnect();
    $self->{'ua'}->timeout($self->{'logs_timeout'});
    my $res = $self->_req('get_logs', \@options);
    #my($typ, $size, $data) = @{$res};
    $self->{'ua'}->timeout($self->{'timeout'});

    return(Thruk::Utils::IO::save_logs_to_tempfile($res->[2]), 'file') if $use_file;
    return $res->[2];
}


##########################################################

=head2 get_timeperiods

  get_timeperiods

returns a list of timeperiods

=cut
sub get_timeperiods {
    my($self, @options) = @_;
    my $res = $self->_req('get_timeperiods', \@options);
    #my($typ, $size, $data) = @{$res};
    return $res->[2];
}

##########################################################

=head2 get_timeperiod_names

  get_timeperiod_names

returns a list of timeperiod names

=cut
sub get_timeperiod_names {
    my($self, @options) = @_;
    my $res = $self->_req('get_timeperiod_names', \@options);
    #my($typ, $size, $data) = @{$res};
    return($res->[2], 'uniq');
}

##########################################################

=head2 get_commands

  get_commands

returns a list of commands

=cut
sub get_commands {
    my($self, @options) = @_;
    my $res = $self->_req('get_commands', \@options);
    #my($typ, $size, $data) = @{$res};
    return $res->[2];
}

##########################################################

=head2 get_contacts

  get_contacts

returns a list of contacts

=cut
sub get_contacts {
    my($self, @options) = @_;
    my $res = $self->_req('get_contacts', \@options);
    #my($typ, $size, $data) = @{$res};
    return $res->[2];
}

##########################################################

=head2 get_contact_names

  get_contact_names

returns a list of contact names

=cut
sub get_contact_names {
    my($self, @options) = @_;
    my $res = $self->_req('get_contact_names', \@options);
    #my($typ, $size, $data) = @{$res};
    return($res->[2], 'uniq');
}

##########################################################

=head2 get_host_stats

  get_host_stats

returns the host statistics for the tac page

=cut
sub get_host_stats {
    my($self, @options) = @_;
    my $res = $self->_req('get_host_stats', \@options);
    #my($typ, $size, $data) = @{$res};
    return($res->[2], 'SUM');
}

##########################################################

=head2 get_host_totals_stats

  get_host_totals_stats

returns the host statistics used on the service/host details page

=cut
sub get_host_totals_stats {
    my($self, @options) = @_;
    my $res = $self->_req('get_host_totals_stats', \@options);
    #my($typ, $size, $data) = @{$res};
    return($res->[2], 'SUM');
}

##########################################################

=head2 get_service_stats

  get_service_stats

returns the services statistics for the tac page

=cut
sub get_service_stats {
    my($self, @options) = @_;
    my $res = $self->_req('get_service_stats', \@options);
    #my($typ, $size, $data) = @{$res};
    return($res->[2], 'SUM');
}

##########################################################

=head2 get_service_totals_stats

  get_service_totals_stats

returns the services statistics used on the service/host details page

=cut
sub get_service_totals_stats {
    my($self, @options) = @_;
    my $res = $self->_req('get_service_totals_stats', \@options);
    #my($typ, $size, $data) = @{$res};
    return($res->[2], 'SUM');
}

##########################################################

=head2 get_performance_stats

  get_performance_stats

returns the service / host execution statistics

=cut
sub get_performance_stats {
    my($self, @options) = @_;
    my $res = $self->_req('get_performance_stats', \@options);
    #my($typ, $size, $data) = @{$res};
    return($res->[2], 'STATS');
}

##########################################################

=head2 get_extra_perf_stats

  get_extra_perf_stats

returns the service /host execution statistics

=cut
sub get_extra_perf_stats {
    my($self, @options) = @_;
    my $res = $self->_req('get_extra_perf_stats', \@options);
    #my($typ, $size, $data) = @{$res};
    return($res->[2], 'SUM');
}

##########################################################

=head2 _get_logs_start_end

  _get_logs_start_end

returns first and last logfile entry

=cut
sub _get_logs_start_end {
    my($self, @options) = @_;
    my $res = $self->_req('_get_logs_start_end', \@options);
    return($res->[0]);
}

##########################################################

=head2 _req

  _req($sub, $options)

returns result for given request

=cut
sub _req {
    my($self, $sub, $args, $redirects) = @_;
    $redirects = 0 unless defined $redirects;

    # clean code refs
    _clean_code_refs($args);

    my $options = {
        'action'        => 'raw',
        'sub'           => $sub,
        'remote_name'   => $self->{'remote_name'},
        'args'          => $args,
    };
    if(defined $args and ref $args eq 'HASH') {
        $options->{'auth'} = $args->{'auth'} if defined $args->{'auth'};
    }

    $self->{'ua'} || $self->reconnect();
    my $response = _ua_post_with_timeout(
                        $self->{'ua'},
                        $self->{'addr'},
                        { data => encode_json({
                                    credential => $self->{'auth'},
                                    options    => $options,
                                }),
                        },
                    );

    if($response->{'_request'}->{'_uri'} =~ m/job\.cgi(\?|&|%3f)job=(.*)$/mx) {
        $self->_wait_for_remote_job($2);
        $redirects++;
        die("too many redirects") if $redirects > 2;
        return $self->_req($sub, $args, $redirects);
    }

    if($response->is_success) {
        my $data;
        eval {
            $data = decode_json($response->decoded_content);
        };
        #die($@."\nrequest:\n".Dumper($response)) if $@;
        die($@."\n") if $@;
        if($data->{'rc'} == 1) {
            my $remote_version = $data->{'version'};
            $remote_version = $remote_version.'~'.$data->{'branch'} if $data->{'branch'};
            if($data->{'output'} =~ m/no\ such\ command/mx) {
                die('backend too old, version returned: '.($remote_version || 'unknown'));
            }
            if(defined $data->{'version'} && ($data->{'version'} < $self->{'min_backend_version'})) {
                die('backend too old, version returned: '.($remote_version || 'unknown'));
            }
            die('internal error: '.$data->{'output'}) if $data->{'output'};
            die('protocol error: '.Dumper($data));
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
    die(_format_response_error($response));
}

##########################################################

=head2 _ua_post_with_timeout

  _ua_post_with_timeout($ua, $url, $data)

return http response but ensure timeout on request.

=cut

sub _ua_post_with_timeout {
    my($ua, $url, $data) = @_;
    my $timeout_for_client = $ua->timeout();
    # set alarm
    local $SIG{ALRM} = sub { die("hit ".$timeout_for_client."s timeout on ".$url) };
    alarm($timeout_for_client);
    $ua->ssl_opts(timeout => $timeout_for_client, Timeout => $timeout_for_client);

    # make sure nobody else calls alarm in between
    {
        ## no critic
        no warnings qw(redefine prototype);
        *CORE::GLOBAL::alarm = sub {};
        ## use critic
    }

    # try to fetch result
    my $res = $ua->post($url, $data);

    # restore alarm handler and disable alarm
    *CORE::GLOBAL::alarm = *CORE::alarm;
    alarm(0);

    return $res;
}

##########################################################

=head2 _wait_for_remote_job

  _wait_for_remote_job($jobid)

wait till remote job is finished and return that data

=cut
sub _wait_for_remote_job {
    my($self, $jobid) = @_;
    my $res;
    while(1) {
        $res = $self->_req('job', $jobid);
        if($res->[2] =~ m/jobid:([^:]+):0/mx) {
            sleep(1);
            next;
        }
        last;
    }
    my $last_error = "";
    return([undef,
            1,
           [$res->[2]->{'rc'}, $res->[2]->{'out'}],
            $last_error]
    );
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
sub _clean_code_refs {
    my($var) = @_;
    if(ref $var eq 'ARRAY') {
        for (@{$var}) {
            if(ref $_ eq 'CODE') {
                $_ = '';
            } else {
                _clean_code_refs($_);
            }
        }
    }
    elsif(ref $var eq 'HASH') {
        for my $key (keys %{$var}) {
            if(ref $var->{$key} eq 'CODE') {
                delete $var->{$key};
            } else {
                _clean_code_refs($var->{$key});
            }
        }
    }
    return;
}

##########################################################
sub _format_response_error {
    my($response) = @_;
    my $message = "";
    if($response->decoded_content && $response->decoded_content =~ m|<h1>(OMD:.*?)</h1>|sxm) {
        return($1);
    }
    if($response->decoded_content && $response->decoded_content =~ m|<!\-\-error:(.*?)\-\->|sxm) {
        $message = "\n".$1;
    }
    if(defined $response) {
        return $response->code().': '.$response->message().$message;
    } else {
        return Dumper($response);
    }
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
