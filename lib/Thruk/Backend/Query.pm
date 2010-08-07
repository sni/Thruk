package Thruk::Backend::Query;

use strict;
use warnings;
use Carp;

our $AUTOLOAD;

=head1 NAME

Thruk::Backend::Query - send queries to our backends

=head1 DESCRIPTION

send queries to our backends

=head1 METHODS

=cut

##########################################################

=head2 new

create new manager

=cut
##########################################################
sub new {
    my( $class, %options ) = @_;
    my $self = {
            'stats'   => undef,
            'log'     => undef,
            'manager' => undef,
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

    return $self;
}

##########################################################

=head2 get_peers

  get_peers()

returns all configured peers

=cut
sub get_peers {
    my $self = shift;
    my @peers = @{$self->{'manager'}->{'backends'}};
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

    my $result;
    my @arg = @_ || qw//;
    $result = $self->{'manager'}->{'backends'}->[0]->{'class'}->$name(@arg);
    #$result = $self->{'backends'}->[0]->$name(@_);
    #if (@_) {
    #    $result = $self->{'backends'}->{'backends'}->[0]->{'class'}->$name(@_);
    #} else {
    #    $result = $self->{'backends'}->{'backends'}->[0]->{'class'}->$name();
    #}

    return $result;
}

##########################################################

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
