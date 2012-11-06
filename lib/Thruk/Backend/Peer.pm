package Thruk::Backend::Peer;

use strict;
use warnings;
use threads::shared;
use Carp;
use Digest::MD5 qw(md5_hex);
use Data::Page;
use Data::Dumper;
use Scalar::Util qw/ looks_like_number /;
use Encode;
use Thruk::Utils;

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
          'Thruk::Backend::Provider::Mongodb',
          'Thruk::Backend::Provider::ConfigOnly',
];

##########################################################

=head2 new

create new peer

=cut

sub new {
    my( $class, $config, $logcache, $existing_keys ) = @_;
    my $self = {
        'config'        => $config,
        'existing_keys' => $existing_keys,
    };
    bless $self, $class;
    $self->_initialise_peer( $config, $logcache );
    return $self;
}

##########################################################

=head2 create_backend

  create_backend()

return a new backend class

=cut

sub _create_backend {
    my($self, $name, $type, $options, $config, $log) = @_;

    my @provider = grep { $_ =~ m/::$type$/mxi } @{$Thruk::Backend::Manager::Provider};
    confess "unknown type in peer configuration" unless scalar @provider > 0;
    my $class   = $provider[0];
    my $require = $class;
    $require =~ s/::/\//gmx;
    require $require . ".pm";
    $class->import;
    $options->{'name'} = $name;

    # disable keepalive for now, it does not work and causes lots of problems
    $options->{'keepalive'} = 0 if defined $options->{'keepalive'};

    my $obj = $class->new( $options, $config, $log );
    return $obj;
}


##########################################################
sub _initialise_peer {
    my($self, $config, $logcache) = @_;

    confess "missing name in peer configuration" unless defined $config->{'name'};
    confess "missing type in peer configuration" unless defined $config->{'type'};

    $self->{'name'}          = $config->{'name'};
    $self->{'type'}          = $config->{'type'};
    $self->{'hidden'}        = defined $config->{'hidden'} ? $config->{'hidden'} : 0;
    $self->{'groups'}        = $config->{'groups'};
    $self->{'resource_file'} = $config->{'options'}->{'resource_file'};
    $self->{'section'}       = $config->{'section'} || 'Default';
    $self->{'enabled'}       = 1;
    $self->{'class'}         = $self->_create_backend($config->{'name'},
                                                      $config->{'type'},
                                                      $config->{'options'},
                                                      $self->{'config'},
                                                      undef); # log
    $self->{'configtool'}    = $config->{'configtool'} || {};
    $self->{'last_error'}    = undef;
    $self->{'logcache'}      = undef;

    # shorten backend id
    my $key = substr(md5_hex($self->{'class'}->peer_addr." ".$self->{'class'}->peer_name), 0, 5);
    $key    = $config->{'id'} if defined $config->{'id'};

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

    # log cache?
    if(defined $logcache and $config->{'type'} eq 'livestatus') {
        require Thruk::Backend::Provider::Mongodb;
        Thruk::Backend::Provider::Mongodb->import;
        $self->{'logcache'} = Thruk::Backend::Provider::Mongodb->new({
                                                peer     => $logcache,
                                                peer_key => $self->{'key'},
                                            });
        $self->{'class'}->{'logcache'} = $self->{'logcache'};
    }

    return;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2012, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
