package Thruk::Backend::Peer;

use warnings;
use strict;
use Carp;
use Scalar::Util qw/weaken/;

use Thruk::Backend::Manager ();
use Thruk::Base ();

## no lint
use Thruk::Backend::Provider::Livestatus ();
## use lint

our $AUTOLOAD;

=head1 NAME

Thruk::Backend::Manager - Manager of backend connections

=head1 DESCRIPTION

Manager of backend connections

=head1 METHODS

=cut

##########################################################
# use static list instead of slow module find
$Thruk::Backend::Peer::Provider = [
          'Thruk::Backend::Provider::Livestatus',
          'Thruk::Backend::Provider::ConfigOnly',
          'Thruk::Backend::Provider::HTTP',
          'Thruk::Backend::Provider::Mysql',
];
$Thruk::Backend::Peer::ProviderLoaded = {
          'livestatus' => 'Thruk::Backend::Provider::Livestatus',
};

##########################################################

=head2 new

create new peer

=cut

sub new {
    my($class, $peer_config, $thruk_config, $existing_keys) = @_;
    my $self = {
        'peer_config'   => $peer_config,
        'thruk_config'  => $thruk_config,
        'existing_keys' => $existing_keys,
    };
    bless $self, $class;
    $self->_initialise_peer();
    return $self;
}

##########################################################

=head2 peer_key

return peer key

=cut

sub peer_key {
    my($self) = @_;
    return $self->{'class'}->peer_key();
}

##########################################################

=head2 peer_name

return peer name

=cut

sub peer_name {
    my($self) = @_;
    return $self->{'class'}->peer_name();
}

##########################################################

=head2 remotekey

return peer key the backend uses on the remote side

=cut

sub remotekey {
    my($self) = @_;
    die("remotekey not set") unless $self->{'remotekey'};
    return($self->{'remotekey'});
}

##########################################################

=head2 peer_list

return peer address list (without fallbacks)

=cut

sub peer_list {
    my($self) = @_;
    return($self->{'peer_list'});
}

##########################################################

=head2 peer_list_fallback

return fallback peer address list

=cut

sub peer_list_fallback {
    my($self) = @_;
    return $self->{'peer_config'}->{'options'}->{'fallback_peer'} if($self->{'peer_config'}->{'options'}->{'fallback_peer'});
    return([]);
}

##########################################################

=head2 is_local

returns true if backend is local

=cut

sub is_local {
    my($self) = @_;
    for my $addr (@{$self->peer_list()}) {
        return 1 if($addr && $addr !~ m/:/mx);
    }
    return;
}

##########################################################

=head2 create_backend

  create_backend()

return a new backend class

=cut

sub _create_backend {
    my($self) = @_;
    my $peer_config  = $self->{'peer_config'};
    my $thruk_config = $self->{'thruk_config'};
    my $name         = $peer_config->{'name'};
    my $type         = lc $peer_config->{'type'};
    my $class;

    if($type eq 'livestatus') {
        # speed up things here, since this class is 99% of the use cases
        $class = 'Thruk::Backend::Provider::Livestatus';
    }
    elsif($Thruk::Backend::Peer::ProviderLoaded->{$type}) {
        $class = $Thruk::Backend::Peer::ProviderLoaded->{$type};
    } else {
        my @provider = grep { $_ =~ m/::$type$/mxi } @{$Thruk::Backend::Peer::Provider};
        if(scalar @provider == 0) {
            my $list = join(', ', @{$Thruk::Backend::Peer::Provider});
            $list =~ s/Thruk::Backend::Provider:://gmx;
            die('unknown type in peer configuration, choose from: '.$list);
        }
        $class   = $provider[0];
        my $require = $class;
        $require =~ s/::/\//gmx;
        require $require . ".pm";
        $class->import;
        $Thruk::Backend::Peer::ProviderLoaded->{$type} = $class;
    }

    $peer_config->{'options'}->{'name'} = $name;

    # disable keepalive for now, it does not work and causes lots of problems
    $peer_config->{'options'}->{'keepalive'} = 0 if defined $peer_config->{'options'}->{'keepalive'};

    my $obj = $class->new($peer_config, $thruk_config);
    return $obj;
}


##########################################################
sub _initialise_peer {
    my($self) = @_;
    my $peer_config  = $self->{'peer_config'};
    my $thruk_config = $self->{'thruk_config'};

    confess "missing name in peer configuration" unless defined $peer_config->{'name'};
    confess "missing type in peer configuration" unless defined $peer_config->{'type'};

    # parse list of peers for LMD
    $peer_config->{'options'}->{'peer'}          = Thruk::Base::list($peer_config->{'options'}->{'peer'})          if $peer_config->{'options'}->{'peer'};
    $peer_config->{'options'}->{'fallback_peer'} = Thruk::Base::list($peer_config->{'options'}->{'fallback_peer'}) if $peer_config->{'options'}->{'fallback_peer'};
    $self->{'peer_list'}                         = $peer_config->{'options'}->{'peer'};
    $peer_config->{'options'}->{'peer'}          = scalar @{$self->{'peer_list'}} > 0 ? $self->{'peer_list'}->[0] : '';

    $self->{'name'}          = $peer_config->{'name'};
    $self->{'type'}          = $peer_config->{'type'};
    $self->{'active'}        = $peer_config->{'active'} // 1;
    $self->{'hidden'}        = defined $peer_config->{'hidden'} ? $peer_config->{'hidden'} : 0;
    $self->{'display'}       = defined $peer_config->{'display'} ? $peer_config->{'display'} : 1;
    $self->{'groups'}        = $peer_config->{'groups'};
    $self->{'resource_file'} = $peer_config->{'options'}->{'resource_file'};
    $self->{'section'}       = $peer_config->{'section'} || 'Default';
    $self->{'enabled'}       = 1;
    $peer_config->{'configtool'}  = {} unless defined $peer_config->{'configtool'};
    $self->{'class'}         = $self->_create_backend();
    $self->{'configtool'}    = $peer_config->{'configtool'};
    $self->{'last_error'}    = undef;
    $self->{'logcache'}      = undef;
    $self->{'authoritive'}   = $peer_config->{'authoritive'};
    $self->{'verify'}        = $peer_config->{'options'}->{'verify'} // 1;
    $self->{'tags'}          = Thruk::Base::array2hash(Thruk::Base::comma_separated_list($peer_config->{'tags'}));
    $self->{'tags'}->{'live'} = 'live' unless scalar keys %{$self->{'tags'}} > 0;

    # shorten backend id
    my $key = $peer_config->{'id'};
    if(!defined $key) {
        require Digest::MD5;
        $key = substr(Digest::MD5::md5_hex($self->{'class'}->peer_addr." ".$self->{'class'}->peer_name), 0, 5);
    }
    $key =~ s/[^a-zA-Z0-9]//gmx;

    # make sure id is uniq
    my $x      = 0;
    my $tmpkey = $key;
    while(defined $self->{'existing_keys'}->{$tmpkey}) { $tmpkey = $key.$x; $x++; }
    $self->{'key'} = $tmpkey;

    $self->{'class'}->peer_key($self->{'key'});
    $self->{'addr'} = $self->{'class'}->peer_addr();
    if($thruk_config->{'backend_debug'} && Thruk::Base->debug) {
        $self->{'class'}->set_verbose(1);
    }
    $self->{'class'}->{'_peer'} = $self;
    weaken($self->{'class'}->{'_peer'});

    # log cache?
    my $logcache = $peer_config->{'logcache'} // $thruk_config->{'logcache'};
    if($logcache && ($peer_config->{'type'} eq 'livestatus' || $peer_config->{'type'} eq 'http')) {
        if($logcache !~ m/^mysql/mxi) {
            die("no or unknown type in logcache connection: ".$logcache);
        } else {
            $self->{'logcache'} = $logcache;
        }
    }

    return;
}

##########################################################

=head2 logcache

  logcache()

return logcache and create it on demand

=cut
sub logcache {
    my($self) = @_;
    return($self->{'_logcache'}) if $self->{'_logcache'};
    if($self->{'logcache'}) {
        if(!defined $Thruk::Backend::Peer::ProviderLoaded->{'Mysql'}) {
            require Thruk::Backend::Provider::Mysql;
            Thruk::Backend::Provider::Mysql->import;
            $Thruk::Backend::Peer::ProviderLoaded->{'Mysql'} = 1;
        }
        $self->{'_logcache'} = Thruk::Backend::Provider::Mysql->new({options => {
                                                peer     => $self->{'logcache'},
                                                peer_key => $self->{'key'},
                                            }});
        $self->{'class'}->{'logcache'} = $self->{'_logcache'};
        return($self->{'_logcache'});
    }
    return;
}

##########################################################

=head2 get_http_fallback_peer

  get_http_fallback_peer()

return http peer from fallback addr

=cut

sub get_http_fallback_peer {
    my($self) = @_;
    return($self->{'_http_fallback_peer'}) if exists $self->{'_http_fallback_peer'};
    $self->{'_http_fallback_peer'} = undef;

    # check if there is any http source set
    for my $src (@{$self->peer_list}, @{$self->peer_list_fallback}) {
        if($src =~ m/^https?:/mx) {
            $self->{'_http_fallback_peer'} = Thruk::Backend::Manager::fork_http_peer($self, $src);
            last;
        }
    }
    return($self->{'_http_fallback_peer'});
}

##########################################################

=head2 cmd

  cmd($c, $cmd, [$background_options])

return result of cmd

=cut
sub cmd {
    my @args = @_;
    my($self, $c, $cmd, $background_options, $env) = @_;
    my($rc, $out) = (0, "");
    if($background_options) {
        $background_options->{"background"} = 1;
        $background_options->{"cmd"}        = $cmd;
        $background_options->{"env"}        = $env if $env;
    }
    if($self->{'type'} eq 'http') {
        # forward by http federation
        if($self->{'federation'}
            && scalar @{$self->{'fed_info'}->{'type'}} >= 2
            && $self->{'fed_info'}->{'type'}->[1] eq 'http'
        ) {
            require Thruk::Utils;
            my $url = Thruk::Utils::get_remote_thruk_url_path($c, $self->{'key'});

            my $comm = [$cmd];
            # setting env requires Thruk <= 3.20
            my $v_num = $self->get_remote_thruk_version($c);
            if($v_num && Thruk::Utils::version_compare($v_num, '3.19.20240920')) {
                $comm = [$cmd, { env => $env }];
            }
            my $options = {
                'action'      => 'raw',
                'sub'         => 'Thruk::Utils::IO::cmd',
                'remote_name' => $self->{'class'}->{'remote_name'},
                'args'        => $comm,
            };
            if($background_options) {
                $options->{'sub'}  = 'Thruk::Utils::External::cmd';
                $options->{'args'} = ['Thruk::Context', $background_options];
            }
            require Cpanel::JSON::XS;
            my $postdata = Cpanel::JSON::XS::encode_json({ data => Cpanel::JSON::XS::encode_json({
                credential => $self->{'class'}->{'auth'},
                options    => $options,
            })});

            require HTTP::Request;
            my $header = ['Content-Type' => 'application/json; charset=UTF-8'];
            my $req    = HTTP::Request->new('POST', $url.'cgi-bin/remote.cgi', $header, $postdata);

            require Thruk::Controller::proxy;
            my $res = Thruk::Controller::proxy::proxy_request($c, $self->{'key'}, $url.'cgi-bin/remote.cgi', $req);
            my $result;
            eval {
                $result = Cpanel::JSON::XS::decode_json($res->content());
            };
            my $err = $@;
            if($err) {
                die(Thruk::Utils::http_response_error($res));
            }
            if(ref $result->{'output'} ne 'ARRAY') {
                $out = $result->{'output'};
                $rc  = -1;
                return($rc, $out);
            }
            ($rc, $out) = @{$result->{'output'}};
            if($background_options) {
                ($out) = @{$result->{'output'}};
            }
            return($rc, $out);
        }

        if($background_options) {
            ($out) = @{$self->{'class'}->request("Thruk::Utils::External::cmd", ['Thruk::Context', $background_options], { timeout => 120 })};
        } else {
            my $comm = [$cmd];
            # setting env requires Thruk <= 3.20
            my $v_num = $self->get_remote_thruk_version($c);
            if($v_num && Thruk::Utils::version_compare($v_num, '3.19.20240920')) {
                $comm = [$cmd, { env => $env }];
            }
            ($rc, $out) = @{$self->{'class'}->request("Thruk::Utils::IO::cmd", $comm, { timeout => 120 })};
        }
        return($rc, $out);
    }

    if(my $http_peer = $self->get_http_fallback_peer()) {
        shift @args;
        return($http_peer->cmd(@args));
    }

    if($background_options) {
        require Thruk::Utils::External;
        $out = Thruk::Utils::External::cmd($c, $background_options);
    } else {
        require Thruk::Utils::IO;
        ($rc, $out) = Thruk::Utils::IO::cmd($cmd, { env => $env });
    }

    return($rc, $out);
}

##########################################################

=head2 rpc

  rpc($c, $sub, $args)

return result of sub call

=cut
sub rpc {
    my($self, $c, $sub, @args) = @_;
    my @res;
    if($self->{'type'} eq 'http') {
        if($self->{'federation'} && scalar @{$self->{'fed_info'}->{'type'}} >= 2 && $self->{'fed_info'}->{'type'}->[1] eq 'http') {
            require Thruk::Utils;
            my $url = Thruk::Utils::get_remote_thruk_url_path($c, $self->{'key'});

            my $options = {
                'action'      => 'raw',
                'sub'         => $sub,
                'remote_name' => $self->{'class'}->{'remote_name'},
                'args'        => \@args,
            };
            require Cpanel::JSON::XS;
            my $postdata = Cpanel::JSON::XS::encode_json({ data => Cpanel::JSON::XS::encode_json({
                credential => $self->{'class'}->{'auth'},
                options    => $options,
            })});

            require HTTP::Request;
            my $header = ['Content-Type' => 'application/json; charset=UTF-8'];
            my $req    = HTTP::Request->new('POST', $url.'cgi-bin/remote.cgi', $header, $postdata);

            require Thruk::Controller::proxy;
            my $res    = Thruk::Controller::proxy::proxy_request($c, $self->{'key'}, $url.'cgi-bin/remote.cgi', $req);
            my $result = Cpanel::JSON::XS::decode_json($res->content());
            @res = @{$result->{'output'}};
        } else {
            @res = @{$self->{'class'}->request($sub, \@args, { timeout => 120 })};
        }

    } elsif(my $http_peer = $self->get_http_fallback_peer()) {
        my @args = @_;
        shift @args;
        return($http_peer->rpc(@args));
    }
    else {
        my $pkg_name     = $sub;
        $pkg_name        =~ s%::[^:]+$%%mx;
        my $function_ref = \&{$sub};
        eval {
            if($pkg_name && $pkg_name !~ m/^CORE/mx) {
                require Module::Load;
                Module::Load::load($pkg_name);
            }
            @res = &{$function_ref}(@args);
        };
    }

    return(@res);
}

##########################################################

=head2 job_data

  job_data($c, $jobid)

return job data

=cut
sub job_data {
    my(@args) = @_;
    my($self, $c, $jobid) = @args;

    require Thruk::Utils::External;
    my $data = Thruk::Utils::External::read_job($c, $jobid);
    return($data) if $data;

    if($self->{'type'} eq 'http') {
        if($self->{'federation'} && scalar @{$self->{'fed_info'}->{'type'}} >= 2 && $self->{'fed_info'}->{'type'}->[1] eq 'http') {
            require Thruk::Utils;
            my $url = Thruk::Utils::get_remote_thruk_url_path($c, $self->{'key'});

            my $options = {
                'action'      => 'raw',
                'sub'         => 'Thruk::Utils::External::read_job',
                'remote_name' => $self->{'class'}->{'remote_name'},
                'args'        => ['Thruk::Context', $jobid],
            };
            require Cpanel::JSON::XS;
            my $postdata = Cpanel::JSON::XS::encode_json({ data => Cpanel::JSON::XS::encode_json({
                credential => $self->{'class'}->{'auth'},
                options    => $options,
            })});

            require HTTP::Request;
            my $header = ['Content-Type' => 'application/json; charset=UTF-8'];
            my $req    = HTTP::Request->new('POST', $url.'cgi-bin/remote.cgi', $header, $postdata);

            require Thruk::Controller::proxy;
            my $res    = Thruk::Controller::proxy::proxy_request($c, $self->{'key'}, $url.'cgi-bin/remote.cgi', $req);
            my $result = Cpanel::JSON::XS::decode_json($res->content());
            ($data) = @{$result->{'output'}};
        } else {
            ($data) = @{$self->{'class'}->request("Thruk::Utils::External::read_job", ['Thruk::Context', $jobid])};
        }
    } elsif(my $http_peer = $self->get_http_fallback_peer()) {
        shift @args;
        return($http_peer->job_data(@args));
    }
    return($data);
}

##########################################################

=head2 is_peer_machine_reachable_by_http

  is_peer_machine_reachable_by_http()

returns true if there is a thruk instance reachable by http for this peer

=cut
sub is_peer_machine_reachable_by_http {
    my($self) = @_;

    return if $self->is_local();

    # check the last/final address in a federation setup and check whether it connects locally or not
    if($self->{'federation'}) {
        my $final_addr = $self->{'fed_info'}->{'addr'}->[scalar @{$self->{'fed_info'}->{'addr'}} - 1];
        if($final_addr =~ m%^https?:%mx) {
            return 1; # a final http address is ok
        }
        if($final_addr =~ m%:%mx) {
            return; # final tcp connection does not work
        }
        # probably a final local unix address
        return 1;
    }

    # nonlocal http connection
    if($self->{'type'} eq 'http') {
        return 1;
    }

    if($self->get_http_fallback_peer()) {
        return 1;
    }

    return;
}

##########################################################

=head2 get_remote_thruk_version

  get_remote_thruk_version()

returns version of remote thruk instance

=cut
sub get_remote_thruk_version {
    my($self, $c) = @_;
    my $key = $self->{'key'};
    if($c->stash->{'pi_detail'}->{$key}
       && $c->stash->{'pi_detail'}->{$key}->{'thruk'}
       && $c->stash->{'pi_detail'}->{$key}->{'thruk'}->{'thruk_version'}) {
       return($c->stash->{'pi_detail'}->{$key}->{'thruk'}->{'thruk_version'});
    }
    return;
}

##########################################################

1;
