package Thruk::Pool::Simple;

use warnings;
use strict;
use threads;
use Thread::Queue;
use JSON::XS qw/decode_json encode_json/;
use Time::HiRes qw/gettimeofday tv_interval/;

sub new {
    my ($class, %arg) = @_;
    die('no size given')    unless $arg{'size'};
    die('no handler given') unless $arg{'handler'};
    my $self = {
        size    => $arg{'size'},
        handler => $arg{'handler'},
    };
    $self->{workq} = Thread::Queue->new();
    $self->{retq}  = Thread::Queue->new();
    $self->{num}   = 0;
    bless $self, $class;

    for(1..$self->{'size'}) {
        threads->create('_handle_work', $self);
    }
    return $self;
}

sub add_bulk {
    my($self, $jobs) = @_;
    my @encoded;
    for my $job (@{$jobs}) {
        push @encoded, encode_json($job);
    }
    $self->{workq}->enqueue(@encoded);
    $self->{num} += scalar @encoded;
    return;
}

sub remove_all {
    my($self) = @_;
    my @res = $self->{retq}->dequeue($self->{num});
    $self->{num} = 0;
    my @encoded;
    for my $res (@res) {
        push @encoded, decode_json($res);
    }
    return(\@encoded);
}

sub shutdown {
    for my $thr (threads->list()) {
        $thr->kill('KILL')->detach();
    }
}

END {
    &shutdown();
}

sub _handle_work {
    my($self) = @_;
    $SIG{'KILL'} = sub { exit; };
    while(my $job = $self->{workq}->dequeue()) {
        last if $job eq 'EXIT';
        my $enc = decode_json($job);
        my $res = $self->{'handler'}(@{$enc});
        $enc = encode_json($res);
        $self->{retq}->enqueue($enc);
    }
    # done
    threads->detach;
}

1;
__END__

=head1 NAME

Thruk::Pool::Simple - A simple thread-pool implementation

=head1 SYNOPSIS

  use Thruk::Pool::Simple;

  my $pool = Thruk::Pool::Simple->new(
                 size    => 3,              # number of workers
                 handler => \&handle,       # call this sub to handle jobswork
               );

  $pool->add_bulk([\@arg1, \@arg2, ...])    # put some work onto the queue

  my @results = $pool->remove_all();        # get all results

=head1 DESCRIPTION

C<Thruk::Pool::Simple> provides a simple thread-pool implementaion
without external dependencies outside core modules.

Jobs can be submitted to and handled by multi-threaded `workers'
managed by the pool.

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
