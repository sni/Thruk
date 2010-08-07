package Thruk::Backend::Manager;

use strict;
use warnings;
use Carp;
use Module::Find;

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
    my $class = shift;
    my $self = {
        'backends' => [],
    };
    bless $self, $class;

    my $config = Thruk->config->{'Thruk::Backend'};

    return unless defined $config;
    return unless defined $config->{'peer'};

    $self->_initialise_backends($config->{'peer'});

    # check if we initialized at least one backend
    return if scalar @{$self->{'backends'}} == 0;

    return $self;
}

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

    my $require = $class;
    $require    =~ s/::/\//gmx;
    require $require.".pm";
    $class->import;
    my $peer = {
        'name'   => $config->{'name'},
        'type'   => $config->{'type'},
        'hidden' => $config->{'hidden'},
        'groups' => $config->{'groups'},
        'class'  => $class->new($config->{'options'}),
    };
    $peer->{'key'}  = $peer->{'class'}->peer_key();
    $peer->{'addr'} = $peer->{'class'}->peer_addr();

    return $peer;
}

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
