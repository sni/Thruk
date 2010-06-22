package Thruk::Utils::Livestatus;

use strict;
use warnings;
use Carp;
use Data::Dumper;

=head1 NAME

Thruk::Utils::Livestatus - Utils for livestatus

=head1 DESCRIPTION

Utils for Livestatus

=cut

our $AUTOLOAD;

=head1 METHODS

=head2 new

create new livestatus helper

=cut

##########################################################
sub new {
    my( $class, $c ) = @_;
    my $self     = {
        'log'          => $c->log,
        'stats'        => $c->stats,
    };
    bless $self, $class;
    return unless $self->init_livestatus();
    return $self;
}

######################################

=head2 init_livestatus

  my $conf = init_livestatus()

return the livestatus object

=cut
sub init_livestatus {
    my $self              = shift;

    $self->{'stats'}->profile(begin => "Thruk::Utils::Livestatus::init_livestatus()");

    if(defined $self->{'livestatus'}) {
        $self->{'log'}->debug("got livestatus from cache");
        return($self);
    }
    $self->{'log'}->debug("creating new livestatus");

    my $livestatus_config = $self->get_livestatus_conf();
    if(!defined $livestatus_config or !defined $livestatus_config->{'peer'} ) {
        return;
    }

    if(defined $livestatus_config->{'verbose'} and $livestatus_config->{'verbose'}) {
        $livestatus_config->{'logger'} = $self->{'log'};
    }
    $self->{'livestatus'} = Monitoring::Livestatus::MULTI->new(%{$livestatus_config});

    $self->{'stats'}->profile(end => "Thruk::Utils::Livestatus::init_livestatus()");

    return($self);
}


########################################

=head2 get_livestatus_conf

  get_livestatus_conf()

returns config for livestatus backends

=cut
sub get_livestatus_conf {
    my $self = shift;

    my $livestatus_config = Thruk->config->{'Monitoring::Livestatus'};

    if(defined $livestatus_config) {
        # with only on peer, we have to convert to an array
        if(defined $livestatus_config->{'peer'} and ref $livestatus_config->{'peer'} eq 'HASH') {
            my $peer = $livestatus_config->{'peer'};
            delete $livestatus_config->{'peer'};
            push @{$livestatus_config->{'peer'}}, $peer;
        }
    }

    return($livestatus_config);
}


########################################

=head2 _disable_backends

  _disable_backends()

disable (hide) livestatus backends by key or address

=cut
sub _disable_backends {
    my $self              = shift;
    my $disabled_backends = shift;

    if(defined $disabled_backends) {
        for my $key (keys %{$disabled_backends}) {
            if(defined $disabled_backends->{$key} and ( $disabled_backends->{$key} == 2 or $disabled_backends->{$key} == 3 )) {
                if($self->{'livestatus'}->_get_peer_by_key($key)) {
                    $self->{'log'}->debug("disabled livestatus backend by key: $key");
                    $self->{'livestatus'}->disable($key);
                }
                else {
                    my $peer = $self->{'livestatus'}->_get_peer_by_addr($key);
                    if(defined $peer) {
                        $self->{'log'}->debug("disabled livestatus backend by addr: ".$key);
                        $self->{'livestatus'}->disable($peer->{'key'});
                        $disabled_backends->{$peer->{'key'}} = $disabled_backends->{$key};
                    }
                }
            }
        }
    }
    return 1;
}


########################################

=head2 _get_contactgroups_by_contact

  _get_contactgroups_by_contact

returns a list of contactgroups by contact

=cut
sub _get_contactgroups_by_contact {
    my($self,$c,$username) = @_;

    my $cache = $c->cache;
    my $cached_data = $cache->get($username);
    if(defined $cached_data->{'contactgroups'}) {
        return $cached_data->{'contactgroups'};
    }

    my $contactgroups = {};
    my $data = $self->selectall_arrayref("GET contactgroups\nColumns: name\nFilter: members >= ".$username, { Slice => 1 } );
    for my $group (@{$data}) {
        $contactgroups->{$group->{'name'}} = 1;
    }

    $cached_data->{'contactgroups'} = $contactgroups;
    $c->cache->set($username, $cached_data);
    return $contactgroups;
}

########################################

=head2 AUTOLOAD

  AUTOLOAD()

redirects sub calls to livestatus

=cut
sub AUTOLOAD {
    my $self = shift;
    my $type = ref($self)
        or croak "$self is not an object";

    my $name = $AUTOLOAD;
    $name =~ s/.*://mx;   # strip fully-qualified portion

    my $arg;
    if($name =~ /^select/mx) {
        $arg = substr($_[0], 0, 50);
        $arg =~ s/\n+/\\n/gmx;
        $self->{'log'}->debug("livestatus->".$name."(".$arg."...)");
        $arg = substr($arg, 0, 20);
        $self->{'stats'}->profile(begin => "l->".$name."(".$arg."...)");
    }

    my $result;
    if (@_) {
        $result = $self->{'livestatus'}->$name(@_);
    } else {
        return $self->{'livestatus'}->$name;
    }

    if($name =~ /^select/mx) {
        $self->{'stats'}->profile(end => "l->".$name."(".$arg."...)");
    }

    return $result;
}

########################################

=head2 DESTROY

  DESTROY()

destroy this

=cut
sub DESTROY {
};

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
