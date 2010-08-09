package Thruk::Backend::Manager;

use strict;
use warnings;
use Carp;
use Module::Find;

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
    my($class, %options) = @_;
    my $self = {
        'stats'    => undef,
        'log'      => undef,
        'backends' => [],
    };
    bless $self, $class;

    for my $opt_key (keys %options) {
        if(exists $self->{$opt_key}) {
            $self->{$opt_key} = $options{$opt_key};
        }
        else {
            croak("unknown option: $opt_key");
        }
    }

    my $config = Thruk->config->{'Thruk::Backend'};

    return unless defined $config;
    return unless defined $config->{'peer'};

    $self->_initialise_backends($config->{'peer'});

    # check if we initialized at least one backend
    return if scalar @{$self->{'backends'}} == 0;

    return $self;
}

##########################################################

=head2 get_peers

  get_peers()

returns all configured peers

=cut
sub get_peers {
    my $self = shift;
    my @peers = @{$self->{'backends'}};
    return \@peers;
}

##########################################################

=head2 get_peer_by_key

  get_peer_by_key()

returns all peer by key

=cut
sub get_peer_by_key {
    my $self = shift;
    my $key  = shift;
    for my $peer (@{$self->get_peers()}) {
        return $peer if $peer->{'key'} eq $key;
    }
    return undef;
}

##########################################################

=head2 peer_key

  peer_key()

returns all peer keys

=cut
sub peer_key {
    my $self = shift;
    my @keys;
    for my $peer (@{$self->get_peers()}) {
        push @keys, $peer->{'key'};
    }
    return \@keys;
}

##########################################################

=head2 disable_backend

  disable_backend(<key>)

disable backend by key

=cut
sub disable_backend {
    my $self = shift;
    my $key  = shift;

    my $peer = $self->get_peer_by_key($key);
    if(defined $peer) {
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
    my $self = shift;
    my $key  = shift;

    my $peer = $self->get_peer_by_key($key);
    if(defined $peer) {
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
    my $self = shift;
    my $keys = shift;

    if(defined $keys) {
        for my $key (keys %{$keys}) {
            if($keys->{$key} == 2 or $keys->{$key} == 3 ) {
                $self->disable_backend($key);
            }
        }
    } else {
        for my $peer (@{$self->get_peers()}) {
            $peer->{'enabled'} = 0;
        }
    }
    return;
}

##########################################################

=head2 enable_backends

  enable_backends(<keys>)

enables all backends

=cut
sub enable_backends {
    my $self = shift;
    my $keys = shift;

    if(defined $keys) {
        for my $key (keys %{$keys}) {
            $self->enable_backend($key);
        }
    } else {
        for my $peer (@{$self->get_peers()}) {
            $peer->{'enabled'} = 1;
        }
    }
    return;
}

########################################

=head2 get_contactgroups_by_contact

  get_contactgroups_by_contact

returns a list of contactgroups by contact

=cut
sub get_contactgroups_by_contact {
    my($self,$c,$username) = @_;

    my $cache = $c->cache;
    my $cached_data = $cache->get($username);
    if(defined $cached_data->{'contactgroups'}) {
        return $cached_data->{'contactgroups'};
    }

    my $contactgroups = $self->do_on_peers("get_contactgroups_by_contact", $username);

    $cached_data->{'contactgroups'} = $contactgroups;
    $c->cache->set($username, $cached_data);
    return $contactgroups;
}

########################################

=head2 do_on_peers

  do_on_peers

returns a result for a sub called on all peers

=cut
sub do_on_peers {
    my($self,$sub, $arg) = @_;

    my $result;
    eval {
        for my $peer (@{$self->get_peers()}) {
            next unless $peer->{'enabled'} == 1;
            $self->{'stats'}->profile(begin => "do_on_peers() - ".$peer->{'name'});
            $result->{$peer->{'key'}} = $peer->{'class'}->$sub(@{$arg});
            $self->{'stats'}->profile(end   => "do_on_peers() - ".$peer->{'name'});
        }
    };
    $self->{'log'}->error($@) if $@;

    return $self->_merge_answer($result);
}

##########################################################

=head2 AUTOLOAD

  AUTOLOAD()

redirects sub calls to out backends

=cut
sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
        or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://mx;   # strip fully-qualified portion

    return $self->do_on_peers($name, \@_);

    #$result = $self->{'backends'}->[0]->$name(@_);
    #if(@_) {
    #    $result = $self->{'backends'}->[0]->{'class'}->$name(@_);
    #} else {
    #    $result = $self->{'backends'}->[0]->{'class'}->$name();
    #}
}

##########################################################

=head2 DESTROY

  DESTROY()

destroy this

=cut
sub DESTROY {
};


##########################################################
sub _initialise_backends {
    my $self   = shift;
    my $config = shift;

    confess "no backend config" unless defined $config;

    # get a list of our backend provider modules
    my @provider = findsubmod("Thruk::Backend::Provider");
    @provider = grep {$_ !~ m/::Base$/} @provider;

    # did we get a single peer or a list of peers?
    my @peer_configs;
    if(ref $config eq 'HASH') {
        push @peer_configs, $config;
    }
    elsif(ref $config eq 'ARRAY') {
        @peer_configs = @{$config};
    }
    else {
        confess "invalid backend config, must be hash or an array of hashes";
    }

    # initialize peers
    for my $peer_conf (@peer_configs) {
        my $peer = $self->_initialise_peer($peer_conf, \@provider);
        push @{$self->{'backends'}}, $peer if defined $peer;
    }

    return;
}

##########################################################
sub _initialise_peer {
    my $self     = shift;
    my $config   = shift;
    my $provider = shift;

    confess "missing name in peer configuration" unless defined $config->{'name'};
    confess "missing type in peer configuration" unless defined $config->{'type'};

    my @provider = grep {$_ =~ m/::$config->{'type'}$/i} @{$provider};
    confess "unknown type in peer configuration" unless scalar @provider > 0;
    my $class = $provider[0];
    
    if(lc $config->{'type'} eq 'livestatus') {
        $config->{'options'}->{'name'} = $config->{'name'};
    }

    my $require = $class;
    $require    =~ s/::/\//gmx;
    require $require.".pm";
    $class->import;
    my $peer = {
        'name'    => $config->{'name'},
        'type'    => $config->{'type'},
        'hidden'  => $config->{'hidden'},
        'groups'  => $config->{'groups'},
        'enabled' => 1,
        'class'   => $class->new($config->{'options'}),
    };
    $peer->{'key'}  = $peer->{'class'}->peer_key();
    $peer->{'addr'} = $peer->{'class'}->peer_addr();

    return $peer;
}

##########################################################
sub _merge_answer {
    my $self   = shift;
    my $data   = shift;
    my $return;

    $self->{'stats'}->profile(begin => "_merge_answer()");

    # iterate over original peers to retain order
    for my $peer (@{$self->get_peers()}) {
        my $key = $peer->{'key'};
        next if !defined $data->{$key};

        if(ref $data->{$key} eq 'ARRAY') {
            $return = [] unless defined $return;
            $return = [ @{$return}, @{$data->{$key}} ];
        } elsif(ref $data->{$key} eq 'HASH') {
            $return = {} unless defined $return;
            $return = { %{$return}, %{$data->{$key}} };
        } else {
            push @{$return}, $data->{$key};
        }
    }

    $self->{'stats'}->profile(end => "_merge_answer()");

    return($return);
}

##########################################################
sub _sum_answer {
    my $self   = shift;
    my $data   = shift;
    my $return;

    $self->{'stats'}->profile(begin => "_sum_answer()");

    for my $peername (keys %{$data}) {
        if(ref $data->{$peername} eq 'HASH') {
            for my $key (keys %{$data->{$peername}}) {
                if(!defined $return->{$key}) {
                    $return->{$key} = $data->{$peername}->{$key};
                } elsif(looks_like_number($data->{$peername}->{$key})) {
                    $return->{$key} += $data->{$peername}->{$key};
                }
            }
        }
        elsif(ref $data->{$peername} eq 'ARRAY') {
            my $x = 0;
            for my $val (@{$data->{$peername}}) {
                if(!defined $return->[$x]) {
                    $return->[$x] = $data->{$peername}->[$x];
                } else {
                    $return->[$x] += $data->{$peername}->[$x];
                }
                $x++;
            }
        } elsif(defined $data->{$peername}) {
            $return = 0 unless defined $return;
            next unless defined $data->{$peername};
            $return += $data->{$peername};
        }
    }

    $self->{'stats'}->profile(end => "_sum_answer()");

    return $return;
}

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
