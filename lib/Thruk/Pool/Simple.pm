package Thruk::Pool::Simple;

use warnings;
use strict;
use threads qw/yield/;
use Thread::Queue ();
use Cpanel::JSON::XS qw/decode_json encode_json/;
#use Thruk::Timer qw/timing_breakpoint/;

sub new {
    my ($class, %arg) = @_;
    #&timing_breakpoint('Pool::Simple::new');
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
    #&timing_breakpoint('Pool::Simple::new '.$self->{'size'}.' threads created');
    return $self;
}

sub add_bulk {
    my($self, $jobs) = @_;
    #&timing_breakpoint('Pool::Simple::add_bulk');
    my @encoded;
    for my $job (@{$jobs}) {
        push @encoded, encode_json($job);
    }
    #&timing_breakpoint('Pool::Simple::add_bulk encoded');
    $self->{workq}->enqueue(@encoded);
    $self->{num} += scalar @encoded;
    #&timing_breakpoint('Pool::Simple::add_bulk done');
    yield;
    return;
}

sub remove_all {
    my($self) = @_;
    my @res = $self->{retq}->dequeue($self->{num});
    $self->{num} = 0;
    #&timing_breakpoint('Pool::Simple::remove_all dequeue');
    my @encoded;
    for my $res (@res) {
        push @encoded, decode_json($res);
    }
    #&timing_breakpoint('Pool::Simple::remove_all decoded');
    return(\@encoded);
}

sub shutdown {
    #&timing_breakpoint('Pool::Simple::shutdown');
    for my $thr (threads->list()) {
        $thr->kill('KILL')->detach();
    }
    #&timing_breakpoint('Pool::Simple::shutdown done');
    return;
}

END {
    &shutdown();
}

sub _handle_work {
    my($self) = @_;
    local $SIG{'KILL'} = sub { exit; };
    while(my $job = $self->{workq}->dequeue()) {
        #&timing_breakpoint('Pool::Simple::_handle_work waited');
        my $enc = decode_json($job);
        #&timing_breakpoint('Pool::Simple::_handle_work decoded');
        my $res = $self->{'handler'}(@{$enc});
        #&timing_breakpoint('Pool::Simple::_handle_work worked');
        $enc = encode_json($res);
        #&timing_breakpoint('Pool::Simple::_handle_work encoded');
        $self->{retq}->enqueue($enc);
        #&timing_breakpoint('Pool::Simple::_handle_work enqueued');
        yield;
    }
    # done
    threads->detach;
    return;
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

Jobs can be submitted to and handled by multi-threaded workers
managed by the pool.

=cut
