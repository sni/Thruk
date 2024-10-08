package Thruk::Pool::Simple;

use warnings;
use strict;
use Cpanel::JSON::XS qw/decode_json encode_json/;
use Thread::Queue ();
use threads qw/yield/;

use Thruk::Timer qw/timing_breakpoint/;
use Thruk::Utils::Log qw/:all/;

sub new {
    my ($class, %arg) = @_;
    &timing_breakpoint('Pool::Simple::new');
    die('no size given')    unless $arg{'size'};
    die('no handler given') unless $arg{'handler'};
    my $self = {
        size     => $arg{'size'},
        handler  => $arg{'handler'},
    };
    $self->{workq} = Thread::Queue->new();
    $self->{retq}  = Thread::Queue->new();
    $self->{num}   = 0;
    bless $self, $class;

    for my $num (1..$self->{'size'}) {
        threads->create('_handle_work', $self, $num);
    }
    &timing_breakpoint('Pool::Simple::new '.$self->{'size'}.' threads created');
    return $self;
}

sub add_bulk {
    my($self, $jobs) = @_;
    &timing_breakpoint('Pool::Simple::add_bulk');
    my @encoded;
    for my $job (@{$jobs}) {
        push @encoded, encode_json((ref $job && ref $job eq 'ARRAY') ? $job : [$job]);
    }
    &timing_breakpoint('Pool::Simple::add_bulk encoded');
    $self->{workq}->enqueue(@encoded);
    $self->{num} += scalar @encoded;
    &timing_breakpoint('Pool::Simple::add_bulk done');
    yield;
    return;
}

sub remove_all {
    my($self, $cb) = @_;
    &timing_breakpoint('Pool::Simple::remove_all dequeue');
    my @encoded;
    while($self->{num} > 0) {
        my $res = $self->{retq}->dequeue();
        $self->{num}--;
        if($res) {
            $res = decode_json($res);
        }
        if($cb) {
            $res = &{$cb}($res);
        }
        push @encoded, $res if $res;
    }
    &timing_breakpoint('Pool::Simple::remove_all decoded');
    return(\@encoded);
}

sub shutdown {
    &timing_breakpoint('Pool::Simple::shutdown');
    for my $thr (threads->list()) {
        $thr->kill('KILL')->detach();
    }
    &timing_breakpoint('Pool::Simple::shutdown done');
    return;
}

END {
    &shutdown();
}

sub _handle_work {
    my($self, $workernum) = @_;
    local $SIG{'KILL'} = sub { exit; };
    local $SIG{'INT'} = sub { exit; };
    local $ENV{'THRUK_WORKER_NUM'} = $workernum;
    while(my $job = $self->{workq}->dequeue()) {
        &timing_breakpoint('Pool::Simple::_handle_work waited');
        my @res;
        eval {
            my $enc = decode_json($job);
            &timing_breakpoint('Pool::Simple::_handle_work decoded');
            @res = $self->{'handler'}(@{$enc});
        };
        if($@) {
            _warn("worker failed: %s", $@);
        }
        &timing_breakpoint('Pool::Simple::_handle_work worked');
        my $enc = encode_json(\@res);
        &timing_breakpoint('Pool::Simple::_handle_work encoded');
        $self->{retq}->enqueue($enc);
        &timing_breakpoint('Pool::Simple::_handle_work enqueued');
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
                 handler => \&handle,       # call this sub to handle jobs
               );

  $pool->add_bulk([\@arg1, \@arg2, ...])    # put some work onto the queue

  my @results = $pool->remove_all();        # get all results (blocks till all threads are finished)

=head1 DESCRIPTION

C<Thruk::Pool::Simple> provides a simple thread-pool implementaion
without external dependencies outside core modules.

Jobs can be submitted to and handled by multi-threaded workers
managed by the pool.

=head1 METHODS

=head2 new

    new( %options )

    options:

    - size    => 3,              # number of workers
    - handler => \&handle,       # call this sub to handle jobs

returns new thread pool.

=head2 add_bulk

    add_bulk( \@jobs )

adds jobs to queue, returns nothing.

=head2 remove_all

    remove_all([$callback])

get all results (blocks till all threads are finished).

optional callback will be called with result as first argument.

=head2 shutdown

    shutdown()

shutdown all threads, wil be called automatically at END.

=cut
