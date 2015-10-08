package Monitoring::Livestatus::INET;
use parent 'Monitoring::Livestatus';

use strict;
use warnings;
use IO::Socket::INET ();
use Socket qw(IPPROTO_TCP TCP_NODELAY);
use Carp qw/confess croak/;

=head1 NAME

Monitoring::Livestatus::INET - connector with tcp sockets

=head1 SYNOPSIS

    use Monitoring::Livestatus;
    my $nl = Monitoring::Livestatus::INET->new( 'localhost:9999' );
    my $hosts = $nl->selectall_arrayref("GET hosts");

=head1 CONSTRUCTOR

=head2 new ( [ARGS] )

Creates an C<Monitoring::Livestatus::INET> object. C<new> takes at least the server.
Arguments are the same as in C<Monitoring::Livestatus>.
If the constructor is only passed a single argument, it is assumed to
be a the C<server> specification. Use either socker OR server.

=cut

sub new {
    my($class, @args) = @_;
    unshift(@args, "peer") if scalar @args == 1;
    my(%options) = @args;
    $options{'name'} = $options{'peer'} unless defined $options{'name'};

    $options{'backend'} = $class;
    my $self = Monitoring::Livestatus->new(%options);
    bless $self, $class;
    confess('not a scalar') if ref $self->{'peer'} ne '';

    return $self;
}


########################################

=head1 METHODS

=cut

sub _open {
    my $self = shift;
    my $sock;

    my $remaining = alarm($self->{'connect_timeout'});
    eval {
        local $SIG{'ALRM'} = sub { die("connection timeout"); };
        $sock = IO::Socket::INET->new(
                                         PeerAddr => $self->{'peer'},
                                         Type     => IO::Socket::INET::SOCK_STREAM,
                                         Timeout  => $self->{'connect_timeout'},
                                         );
        if(!defined $sock || !$sock->connected()) {
            my $msg = "failed to connect to $self->{'peer'}: $!";
            if($self->{'errors_are_fatal'}) {
                croak($msg);
            }
            $Monitoring::Livestatus::ErrorCode    = 500;
            $Monitoring::Livestatus::ErrorMessage = $msg;
            alarm(0);
            return;
        }

        setsockopt($sock, IPPROTO_TCP, TCP_NODELAY, 1);

    };
    alarm(0);
    alarm($remaining) if $remaining;

    if($@) {
        $Monitoring::Livestatus::ErrorCode    = 500;
        $Monitoring::Livestatus::ErrorMessage = $@;
        return;
    }

    if(defined $self->{'query_timeout'}) {
        # set timeout
        $sock->timeout($self->{'query_timeout'});
    }

    return($sock);
}


########################################

sub _close {
    my $self = shift;
    my $sock = shift;
    return unless defined $sock;
    return close($sock);
}


1;

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) by Sven Nierlein

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__END__
