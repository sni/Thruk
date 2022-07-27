package Thruk::Backend::Peer;

use warnings;
use strict;
use Carp;
use Scalar::Util qw/weaken/;

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

=head2 peer_list

return peer address list

=cut

sub peer_list {
    my($self) = @_;
    if($self->{'peer_list'} && scalar @{$self->{'peer_list'}} > 0) {
        my $list = [@{$self->{'peer_list'}}]; # create clone of list
        if($self->{'class'}->{'config'}->{'options'}->{'fallback_peer'}) {
            push @{$list}, $self->{'class'}->{'config'}->{'options'}->{'fallback_peer'};
        }
        return($list);
    }
    elsif($self->{'peer_config'}->{'options'}->{'fallback_peer'}) {
        return([$self->{'peer_config'}->{'options'}->{'fallback_peer'}, $self->{'addr'}]);
    }
    return([$self->{'addr'}]);
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

    my $logcache       = $peer_config->{'logcache'} // $thruk_config->{'logcache'};

    confess "missing name in peer configuration" unless defined $peer_config->{'name'};
    confess "missing type in peer configuration" unless defined $peer_config->{'type'};

    # parse list of peers for LMD
    if($peer_config->{'options'}->{'peer'} && ref $peer_config->{'options'}->{'peer'} eq 'ARRAY') {
        $self->{'peer_list'} = $peer_config->{'options'}->{'peer'};
        $peer_config->{'options'}->{'peer'} = $peer_config->{'options'}->{'peer'}->[0];
    }
    $self->{'name'}          = $peer_config->{'name'};
    $self->{'type'}          = $peer_config->{'type'};
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

    # state hosts
    my $addr              = $self->{'addr'};
    $self->{'local'}      = 0;
    if($addr) {
        if($self->{'type'} eq 'http') {
            $addr =~ s/^http(|s):\/\///mx;
            $addr =~ s/\/.*$//mx;
        }
        if($self->{'type'} eq 'livestatus') {
            $addr =~ s/^tls:\/\///mx;
            $addr =~ s/:.*$//mx;
        }
    }

    # log cache?
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

=head2 cmd

  cmd($c, $cmd)

return result of cmd

=cut
sub cmd {
    my($self, $c, $cmd) = @_;
    my($rc, $out);
    if($self->{'type'} eq 'http') {
        if($self->{'federation'} && scalar @{$self->{'fed_info'}->{'type'}} >= 2 && $self->{'fed_info'}->{'type'}->[1] eq 'http') {
            ($rc, $out) = (1, "federated sites not supported");
            require Thruk::Utils;
            my $url = Thruk::Utils::get_remote_thruk_url($c, $self->{'key'});

            my $options = {
                'action'      => 'raw',
                'sub'         => 'Thruk::Utils::IO::cmd',
                'remote_name' => $self->{'class'}->{'remote_name'},
                'args'        => $cmd,
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
            ($rc, $out) = @{$result->{'output'}};
        } else {
            ($rc, $out) = @{$self->{'class'}->request("Thruk::Utils::IO::cmd", ['Thruk::Context', $cmd], { timeout => 120 })};
        }

    } else {
        require Thruk::Utils::IO;
        ($rc, $out) = Thruk::Utils::IO::cmd($c, $cmd);
    }
    return($rc, $out);
}

##########################################################

1;
