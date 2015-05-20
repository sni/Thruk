package Monitoring::Livestatus::UNIX;
use parent 'Monitoring::Livestatus';

use strict;
use warnings;
use IO::Socket::UNIX ();
use Carp qw/confess croak/;

=head1 NAME

Monitoring::Livestatus::UNIX - connector with unix sockets

=head1 SYNOPSIS

    use Monitoring::Livestatus;
    my $nl = Monitoring::Livestatus::UNIX->new( '/var/lib/livestatus/livestatus.sock' );
    my $hosts = $nl->selectall_arrayref("GET hosts");

=head1 CONSTRUCTOR

=head2 new ( [ARGS] )

Creates an C<Monitoring::Livestatus::UNIX> object. C<new> takes at least the socketpath.
Arguments are the same as in C<Monitoring::Livestatus>.
If the constructor is only passed a single argument, it is assumed to
be a the C<socket> specification. Use either socker OR server.

=cut

sub new {
    my($class,@args) = @_;
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
    my $self      = shift;

    if(!-S $self->{'peer'}) {
        my $msg = "failed to open socket $self->{'peer'}: $!";
        if($self->{'errors_are_fatal'}) {
            croak($msg);
        }
        $Monitoring::Livestatus::ErrorCode    = 500;
        $Monitoring::Livestatus::ErrorMessage = $msg;
        return;
    }
    my $sock;
    my $remaining = alarm($self->{'connect_timeout'});
    eval {
        local $SIG{'ALRM'} = sub { die("connection timeout"); };
        $sock = IO::Socket::UNIX->new(
                                        Peer     => $self->{'peer'},
                                        Type     => IO::Socket::UNIX::SOCK_STREAM,
                                    );
        if(!defined $sock || !$sock->connected()) {
            my $msg = "failed to connect to $self->{'peer'}: $!";
            if($self->{'errors_are_fatal'}) {
                croak($msg);
            }
            $Monitoring::Livestatus::ErrorCode    = 500;
            $Monitoring::Livestatus::ErrorMessage = $msg;
            return;
        }
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

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Sven Nierlein

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__END__
