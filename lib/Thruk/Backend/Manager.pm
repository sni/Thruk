package Thruk::Backend::Manager;

use strict;
use warnings;
use Carp;
use Module::Find;
use Digest::MD5  qw(md5_hex);
use Data::Page;
use Thruk::Utils::Livestatus;

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

    # do we have a deprecated config in use?
    my $deprecated_conf = Thruk::Utils::Livestatus::get_livestatus_conf();
    if(defined $deprecated_conf and !defined $config) {
        croak("The <Component Monitoring::Livestatus> configuration is deprecated, please use '<Component Thruk::Backend>' instead.\nYour converted config would be:\n\n".Thruk::Utils::Livestatus::convert_config($deprecated_conf)."\nplease update your thruk_local.conf");
    }


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

    my $contactgroups = $self->_do_on_peers("get_contactgroups_by_contact", $username);

    $cached_data->{'contactgroups'} = $contactgroups;
    $c->cache->set($username, $cached_data);
    return $contactgroups;
}

########################################

=head2 _do_on_peers

  _do_on_peers

returns a result for a sub called on all peers

=cut
sub _do_on_peers {
    my($self, $sub, $arg) = @_;

    my($result,$type);
    eval {
        for my $peer (@{$self->get_peers()}) {
            next unless $peer->{'enabled'} == 1;
            $self->{'stats'}->profile(begin => "_do_on_peers() - ".$peer->{'name'});
            ($result->{$peer->{'key'}}, $type) = $peer->{'class'}->$sub(@{$arg});
            $self->{'stats'}->profile(end   => "_do_on_peers() - ".$peer->{'name'});
        }
    };
    $self->{'log'}->error($@) if $@;

    # howto merge the answers?
    my $data;
    if($sub eq 'get_hostgroups') {
        $data = $self->_merge_hostgroup_answer($result);
    }
    elsif($sub eq 'get_servicegroups') {
        $data = $self->_merge_servicegroup_answer($result);
    }
    else {
        $data = $self->_merge_answer($result, $type);
    }

    if(    $sub =~ m/^get_/
       and ref $arg eq 'ARRAY'
       and scalar @{$arg}%2 == 0
      ) {
        my %arg = @{$arg};

        if($arg{'remove_duplicates'} and scalar keys %{$result} > 1) {
            $data = $self->_remove_duplicates($data);
        }

        if($arg{'sort'}) {
            $data = $self->_sort($data, $arg{'sort'});
        }

        if($arg{'pager'}) {
            $data = $self->_page_data($arg{'pager'}, $data);
        }
    }

    return $data;
}

########################################

=head2 _remove_duplicates

  _remove_duplicates($data)

removes duplicate entries from a array of hashes

=cut
sub _remove_duplicates {
    my $self = shift;
    my $data = shift;

    $self->{'stats'}->profile(begin => "Utils::remove_duplicates()");

    # calculate md5 sums
    my $uniq = {};
    for my $dat (@{$data}) {
        my $peer_key  = $dat->{'peer_key'};  delete $dat->{'peer_key'};
        my $peer_name = $dat->{'peer_name'}; delete $dat->{'peer_name'};
        my $peer_addr = $dat->{'peer_addr'}; delete $dat->{'peer_addr'};
        my $md5 = md5_hex(join(';', values %{$dat}));
        if(!defined $uniq->{$md5}) {
            $dat->{'peer_key'}  = $peer_key;
            $dat->{'peer_name'} = $peer_name;
            $dat->{'peer_addr'} = $peer_addr;

            $uniq->{$md5} = {
                              'data'      => $dat,
                              'peer_key'  => [ $peer_key ],
                              'peer_name' => [ $peer_name ],
                              'peer_addr' => [ $peer_addr ],
                            };
        } else {
            push @{$uniq->{$md5}->{'peer_key'}},  $peer_key;
            push @{$uniq->{$md5}->{'peer_name'}}, $peer_name;
            push @{$uniq->{$md5}->{'peer_addr'}}, $peer_addr;
        }
    }

    my $return = [];
    for my $data (values %{$uniq}) {
        $data->{'data'}->{'backend'} = {
            'peer_key'  => $data->{'peer_key'},
            'peer_name' => $data->{'peer_name'},
            'peer_addr' => $data->{'peer_addr'},
        };
        push @{$return}, $data->{'data'};

    }

    $self->{'stats'}->profile(end => "Utils::remove_duplicates()");
    return($return);
}

########################################

=head2 _page_data

  _page_data($c, $data)

adds paged data set to the template stash.
Data will be available as 'data'
The pager itself as 'pager'

=cut
sub _page_data {
    my $self                = shift;
    my $c                   = shift;
    my $data                = shift || [];
    my $default_result_size = shift || $c->stash->{'default_page_size'};

    my $entries = $c->{'request'}->{'parameters'}->{'entries'} || $default_result_size;
    my $page    = $c->{'request'}->{'parameters'}->{'page'}    || 1;

    # we dont use paging at all?
    if(!$c->stash->{'use_pager'} or !defined $entries) {
        $c->stash->{'data'}  = $data,
        return 1;
    }

    $c->stash->{'entries_per_page'} = $entries;

    my $pager = new Data::Page;
    $pager->total_entries(scalar @{$data});
    if($entries eq 'all') { $entries = $pager->total_entries; }
    my $pages = 0;
    if($entries > 0) {
        $pages = POSIX::ceil($pager->total_entries / $entries);
    }
    else {
        $c->stash->{'data'}  = $data,
        return $data;
    }

    if(exists $c->{'request'}->{'parameters'}->{'next'}) {
        $page++;
    }
    elsif(exists $c->{'request'}->{'parameters'}->{'previous'}) {
        $page-- if $page > 1;
    }
    elsif(exists $c->{'request'}->{'parameters'}->{'first'}) {
        $page = 1;
    }
    elsif(exists $c->{'request'}->{'parameters'}->{'last'}) {
        $page = $pages;
    }

    if($page < 0)      { $page = 1;      }
    if($page > $pages) { $page = $pages; }

    $c->stash->{'current_page'}     = $page;

    if($entries eq 'all') {
        $c->stash->{'data'}  = $data,
    }
    else {
        $pager->entries_per_page($entries);
        $pager->current_page($page);
        my @data = $pager->splice($data);
        $c->stash->{'data'}  = \@data,
    }

    $c->stash->{'pager'} = $pager;
    $c->stash->{'pages'} = $pages;

    # set some variables to avoid undef values in templates
    $c->stash->{'pager_previous_page'} = $pager->previous_page() || 0;
    $c->stash->{'pager_next_page'}     = $pager->next_page()     || 0;

    return $data;
}
##########################################################

=head2 AUTOLOAD

  AUTOLOAD()

redirects sub calls to out backends

=cut
sub AUTOLOAD {
    my $self = shift;
    my $name = $AUTOLOAD;
    my $type = ref($self) or confess "$self is not an object, called as (".$name.")";

    $name =~ s/.*://mx;   # strip fully-qualified portion
    return $self->_do_on_peers($name, \@_);
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
    my $type   = shift;
    my $return = [];
    if(defined $type and lc $type eq 'hash') {
        $return = {};
    }

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
# merge hostgroups and merge 'members' of matching groups
sub _merge_hostgroup_answer {
    my $self   = shift;
    my $data   = shift;
    my $groups = {};

    $self->{'stats'}->profile(begin => "_merge_hostgroup_answer()");

    for my $peer (@{$self->get_peers()}) {
        my $key = $peer->{'key'};
        next if !defined $data->{$key};

        confess("not an array ref") if ref $data->{$key} ne 'ARRAY';

        for my $row (@{$data->{$key}}) {
            if(!defined $groups->{$row->{'name'}}) {
                $groups->{$row->{'name'}} = $row;
                $groups->{$row->{'name'}}->{'members'} = [ @{$row->{'members'}} ];
            } else {
                $groups->{$row->{'name'}}->{'members'} = [ @{$groups->{$row->{'name'}}->{'members'}}, @{$row->{'members'}} ];
            }

            if(!defined $groups->{$row->{'name'}}->{'backends_hash'}) { $groups->{$row->{'name'}}->{'backends_hash'} = {} }
            $groups->{$row->{'name'}}->{'backends_hash'}->{$row->{'peer_name'}} = 1;
        }
    }
    # set backends used
    for my $group (values %{$groups}) {
        $group->{'backend'} = [];
        @{$group->{'backend'}} = sort keys %{$group->{'backends_hash'}};
        delete $group->{'backends_hash'};
    }
    my @return = values %{$groups};

    $self->{'stats'}->profile(end => "_merge_hostgroup_answer()");

    return(\@return);
}

##########################################################
# merge servicegroups and merge 'members' of matching groups
sub _merge_servicegroup_answer {
    my $self   = shift;
    my $data   = shift;
    my $groups = {};

    $self->{'stats'}->profile(begin => "_merge_servicegroup_answer()");
    for my $peer (@{$self->get_peers()}) {
        my $key = $peer->{'key'};
        next if !defined $data->{$key};

        confess("not an array ref") if ref $data->{$key} ne 'ARRAY';

        for my $row (@{$data->{$key}}) {
            if(!defined $groups->{$row->{'name'}}) {
                $groups->{$row->{'name'}} = $row;
                $groups->{$row->{'name'}}->{'members'} = [ @{$row->{'members'}} ];
            } else {
                $groups->{$row->{'name'}}->{'members'} = [ @{$groups->{$row->{'name'}}->{'members'}}, @{$row->{'members'}} ];
            }
            if(!defined $groups->{$row->{'name'}}->{'backends_hash'}) { $groups->{$row->{'name'}}->{'backends_hash'} = {} }
            $groups->{$row->{'name'}}->{'backends_hash'}->{$row->{'peer_name'}} = 1;
        }
    }
    # set backends used
    for my $group (values %{$groups}) {
        $group->{'backend'} = [];
        @{$group->{'backend'}} = sort keys %{$group->{'backends_hash'}};
        delete $group->{'backends_hash'};
    }

    my @return = values %{$groups};

    $self->{'stats'}->profile(end => "_merge_servicegroup_answer()");

    return(\@return);
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
    my $self   = shift;
    my $data   = shift;
    my $sortby = shift;
    my(@sorted, $key, $order);

    $key = $sortby;
    if(ref $sortby eq 'HASH') {
        for $order (qw/ASC DESC/) {
            if(defined $sortby->{$order}) {
                $key = $sortby->{$order};
                last;
            }
        }
    }

    if(!defined $key) { confess('missing options in sort()'); }

    $self->{'stats'}->profile(begin => "_sort()");

    $order = "ASC" if !defined $order;

    return \@sorted if !defined $data;
    return \@sorted if scalar @{$data} == 0;

    my @keys;
    if(ref($key) eq 'ARRAY') {
        @keys = @{$key};
    } else {
        @keys = ($key);
    }

    my @compares;
    for my $key (@keys) {
        # sort numeric
        if(defined $data->[0]->{$key} and $data->[0]->{$key} =~ m/^\d+$/xm) {
            push @compares, '$a->{'.$key.'} <=> $b->{'.$key.'}';
        }
        # sort alphanumeric
        else {
            push @compares, '$a->{'.$key.'} cmp $b->{'.$key.'}';
        }
    }
    my $sortstring = join(' || ', @compares);

    ## no critic
    no warnings; # sorting by undef values generates lots of errors
    if(uc $order eq 'ASC') {
        eval '@sorted = sort { '.$sortstring.' } @{$data};';
    } else {
        eval '@sorted = reverse sort { '.$sortstring.' } @{$data};';
    }
    use warnings;
    ## use critic

    $self->{'stats'}->profile(end => "_sort()");

    return(\@sorted);
}

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
