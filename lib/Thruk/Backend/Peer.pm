package Thruk::Backend::Peer;

use strict;
use warnings;
use Carp;
use Scalar::Util qw/weaken/;
use Digest::MD5 qw(md5_hex);
use Thruk::Backend::Provider::Livestatus;

our $AUTOLOAD;

=head1 NAME

Thruk::Backend::Manager - Manager of backend connections

=head1 DESCRIPTION

Manager of backend connections

=head1 METHODS

=cut

##########################################################
# use static list instead of slow module find
$Thruk::Backend::Manager::Provider = [
          'Thruk::Backend::Provider::Livestatus',
          'Thruk::Backend::Provider::ConfigOnly',
          'Thruk::Backend::Provider::HTTP',
          'Thruk::Backend::Provider::Mysql',
];
$Thruk::Backend::Manager::ProviderLoaded = {
          'livestatus' => 'Thruk::Backend::Provider::Livestatus',
};

##########################################################

=head2 new

create new peer

=cut

sub new {
    my($class, $config, $thruk_config, $existing_keys, $use_shadow_naemon) = @_;
    my $self = {
        'config'        => $config,
        'existing_keys' => $existing_keys,
    };
    bless $self, $class;
    $self->_initialise_peer($config, $thruk_config, $use_shadow_naemon);
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
    if($self->{'peer_list'}) {
        my $list = [@{$self->{'peer_list'}}];
        if($self->{'class'}->{'config'}->{'options'}->{'fallback_peer'}) {
            push @{$list}, $self->{'class'}->{'config'}->{'options'}->{'fallback_peer'};
        }
        return($list);
    }
    elsif($self->{'class'}->{'config'}->{'options'}->{'fallback_peer'}) {
        return([$self->{'config'}->{'options'}->{'fallback_peer'}, $self->{'addr'}]);
    }
    return([$self->{'addr'}]);
}

##########################################################

=head2 create_backend

  create_backend()

return a new backend class

=cut

sub _create_backend {
    my($self, $config, $peerconfig, $product_prefix, $thruk_config) = @_;

    my $name    = $config->{'name'};
    my $type    = lc $config->{'type'};
    my $options = $config->{'options'};
    my $class;

    if($type eq 'livestatus') {
        # speed up things here, since this class is 99% of the use cases
        $class = 'Thruk::Backend::Provider::Livestatus';
    }
    elsif($Thruk::Backend::Manager::ProviderLoaded->{$type}) {
        $class = $Thruk::Backend::Manager::ProviderLoaded->{$type};
    } else {
        my @provider = grep { $_ =~ m/::$type$/mxi } @{$Thruk::Backend::Manager::Provider};
        if(scalar @provider == 0) {
            my $list = join(', ', @{$Thruk::Backend::Manager::Provider});
            $list =~ s/Thruk::Backend::Provider:://gmx;
            die('unknown type in peer configuration, choose from: '.$list);
        }
        $class   = $provider[0];
        my $require = $class;
        $require =~ s/::/\//gmx;
        require $require . ".pm";
        $class->import;
        $Thruk::Backend::Manager::ProviderLoaded->{$type} = $class;
    }

    $options->{'name'} = $name;

    # disable keepalive for now, it does not work and causes lots of problems
    $options->{'keepalive'} = 0 if defined $options->{'keepalive'};

    my $obj = $class->new($options, $peerconfig, $config, $product_prefix, $thruk_config);
    return $obj;
}


##########################################################
sub _initialise_peer {
    my($self, $config, $thruk_config, $use_shadow_naemon) = @_;

    my $logcache       = $thruk_config->{'logcache'};
    my $product_prefix = $thruk_config->{'product_prefix'};

    confess "missing name in peer configuration" unless defined $config->{'name'};
    confess "missing type in peer configuration" unless defined $config->{'type'};

    # parse list of peers for LMD
    if($self->{'config'}->{'options'}->{'peer'} && ref $self->{'config'}->{'options'}->{'peer'} eq 'ARRAY') {
        $self->{'peer_list'} = $self->{'config'}->{'options'}->{'peer'};
        $self->{'config'}->{'options'}->{'peer'} = $self->{'config'}->{'options'}->{'peer'}->[0];
    }
    $self->{'name'}          = $config->{'name'};
    $self->{'type'}          = $config->{'type'};
    $self->{'hidden'}        = defined $config->{'hidden'} ? $config->{'hidden'} : 0;
    $self->{'display'}       = defined $config->{'display'} ? $config->{'display'} : 1;
    $self->{'groups'}        = $config->{'groups'};
    $self->{'resource_file'} = $config->{'options'}->{'resource_file'};
    $self->{'section'}       = $config->{'section'} || 'Default';
    $self->{'enabled'}       = 1;
    $config->{'configtool'}  = {} unless defined $config->{'configtool'};
    $self->{'class'}         = $self->_create_backend($config, $self->{'config'}, $product_prefix, $thruk_config);
    $self->{'configtool'}    = $config->{'configtool'};
    $self->{'last_error'}    = undef;
    $self->{'logcache'}      = undef;
    $self->{'state_host'}    = $config->{'state_host'};
    $self->{'use_shadow'}    = $config->{'use_shadow'};

    # shorten backend id
    my $key = substr(md5_hex($self->{'class'}->peer_addr." ".$self->{'class'}->peer_name), 0, 5);
    $key    = $config->{'id'} if defined $config->{'id'};
    $key    =~ s/[^a-zA-Z0-9]//gmx;

    # make sure id is uniq
    my $x      = 0;
    my $tmpkey = $key;
    while(defined $self->{'existing_keys'}->{$tmpkey}) { $tmpkey = $key.$x; $x++; }
    $self->{'key'} = $tmpkey;

    $self->{'class'}->peer_key($self->{'key'});
    $self->{'addr'} = $self->{'class'}->peer_addr();
    if($self->{'backend_debug'} and Thruk->debug) {
        $self->{'class'}->set_verbose(1);
    }
    $self->{'class'}->{'_peer'} = $self;
    weaken($self->{'class'}->{'_peer'});

    # state hosts
    my $addr              = $self->{'addr'};
    $self->{'local'}      = 0;
    $self->{'state_host'} = $config->{'state_host'};
    if($addr) {
        if($self->{'type'} eq 'http') {
            $addr =~ s/^http(|s):\/\///mx;
            $addr =~ s/\/.*$//mx;
        }
        if($self->{'type'} eq 'livestatus') {
            $addr =~ s/^tls:\/\///mx;
            $addr =~ s/:.*$//mx;
        }

        if($self->{'state_host'}) {
            $self->{'local'} = 0;
        }
        elsif($addr =~ m/^\//mx or $addr eq 'localhost' or $addr =~ /^127\.0\.0\./mx) {
            $self->{'local'} = 1;
        } else {
            $self->{'local'} = 0;
            $self->{'state_host'} = $addr;
        }
    }

    # log cache?
    if(defined $logcache and ($config->{'type'} eq 'livestatus' or $config->{'type'} eq 'http')) {
        if($logcache !~ m/^mysql/mxi) {
            die("no or unknown type in logcache connection: ".$logcache);
        } else {
            $self->{'logcache'} = $logcache;
        }
    }

    # livestatus booster
    if($use_shadow_naemon) {
        if($ENV{'NO_SHADOW_NAEMON'}) {
            undef $use_shadow_naemon;
        }
        elsif(defined $self->{'use_shadow'} && $self->{'use_shadow'} == 0) {
            undef $use_shadow_naemon;
        }
        elsif($self->{'local'} == 1 && (!defined $self->{'use_shadow'} || $self->{'use_shadow'} == 0)) {
            undef $use_shadow_naemon;
        }
        elsif($config->{'type'} ne 'livestatus' && !$config->{'options'}->{'fallback_peer'}) {
            undef $use_shadow_naemon;
        }
    }
    if($use_shadow_naemon && !$ENV{'NO_SHADOW_NAEMON'}) {
        $self->{'cacheproxy'} = Thruk::Backend::Provider::Livestatus->new({
                                                peer      => $use_shadow_naemon.'/'.$self->{'key'}.'/live',
                                                peer_key  => $self->{'key'},
                                                #keepalive => 1,
                                            });
        $self->{'cacheproxy'}->peer_key($self->{'key'});
        $self->{'cacheproxy'}->{'naemon_optimizations'} = 1;
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
        if(!defined $Thruk::Backend::Manager::ProviderLoaded->{'Mysql'}) {
            require Thruk::Backend::Provider::Mysql;
            Thruk::Backend::Provider::Mysql->import;
            $Thruk::Backend::Manager::ProviderLoaded->{'Mysql'} = 1;
        }
        $self->{'_logcache'} = Thruk::Backend::Provider::Mysql->new({
                                                peer     => $self->{'logcache'},
                                                peer_key => $self->{'key'},
                                            });
        $self->{'class'}->{'logcache'} = $self->{'_logcache'};
        return($self->{'_logcache'});
    }
    return;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
