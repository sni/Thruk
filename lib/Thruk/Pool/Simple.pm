package Thruk::Pool::Simple;
use 5.008;
use strict;
use threads;
use threads::shared;
use warnings;
use Carp;
use JSON::XS qw/decode_json encode_json/;
use Thread::Queue;
use Thread::Semaphore;

our $VERSION = '0.25';

sub new {
    my ($class, %arg) = @_;
    my %config : shared
      = (min => ($arg{min} || 1),
         max => ($arg{max} || 10),
         load => ($arg{load} || 20),
        );
    my %handler;
    for (qw(init pre do post)) {
        next unless exists $arg{$_} && ref $arg{$_} eq 'ARRAY';
        $handler{$_} = $arg{$_}
    }
    my $self = &share({});
    $self->{config} = \%config;
    $self->{pending} = Thread::Queue->new();
    $self->{submitted} = &share({});
    $self->{done} = &share({});
    my $state : shared = 0;
    $self->{state} = \$state;
    my $worker : shared = 0;
    $self->{worker} = \$worker;
    $self->{shutdown_lock} = Thread::Semaphore->new();
    bless $self, $class;
    $self->{shutdown_lock}->down();
    my $thr = threads->new(
        sub {
            $self->_run(\%handler);
            $self->{shutdown_lock}->up();
        }) or croak "fail to create new thread";
    $thr->detach();
    return $self;
}

sub _run {
    my ($self, $handler) = @_;
    while (1) {
        last if $self->terminating();
        if ($self->busy()) {
            $self->_increase($handler);
        }
        else {
            sleep 1;
        }
        threads->yield();
    }
    my $worker = $self->{worker};
    {
        lock $$worker;
        cond_wait $$worker while $$worker;
    }
    return;
}

sub _increase {
    my ($self, $handler) = @_;
    my $max = do { lock %{$self->{config}}; $self->{config}{max} };
    my $worker = do { lock ${$self->{worker}}; ${$self->{worker}} };
    return unless $worker < $max;

    $self->_handle_func($handler->{init});

    eval {
        threads->create(\&_handle, $self, $handler)->detach();
        lock ${$self->{worker}};
        ++${$self->{worker}};
    };
    carp "fail to add new thread: $@" if $@;
    return;
}

sub _handle {
    my ($self, $handler) = @_;

    $self->_handle_func($handler->{pre});

    my $do = $handler->{do};
    my $func = defined $do ? shift @$do : undef;
    eval {
        while (!$self->terminating()) {
            my ($id, $job) = unpack 'Na*', $self->{pending}->dequeue();
            $self->_state(-2) && last unless $id;
            $self->_drop($id) && next unless $self->job_exists($id);

            my $arg = decode_json($job);
            my @ret;
            if ($id % 3 == 2) {  # void context
                if (defined $func) {
                    eval {
                        ## no critic
                        no strict 'refs';
                        ## use critic
                        scalar $func->((@$do, @$arg));
                    };
                    $self->_drop($id);
                    next;
                }
            }
            elsif ($id % 3 == 1) { # list context
                if (defined $func) {
                    @ret = eval {
                        ## no critic
                        no strict 'refs';
                        ## use critic
                        $func->((@$do, @$arg));
                    };
                }
            }
            else { # scalar context
                if (defined $func) {
                    $ret[0] = eval {
                        ## no critic
                        no strict 'refs';
                        ## use critic
                        $func->((@$do, @$arg));
                    };
                }
            }

            $self->_drop($id) && next unless $self->job_exists($id);

            if ($@) {
                @ret = ('e', $@);
            }
            else {
                unshift @ret, 'n';
            }
            my $ret = JSON::XS->new->utf8->convert_blessed->encode(\@ret);
            {
                lock %{$self->{done}};
                $self->{done}{$id} = $ret;
                cond_signal %{$self->{done}};
            }
        }
        continue {
            threads->yield();
        }
    };
    carp "job handling error: $@" if $@;

    $self->_handle_func($handler->{post});

    my $worker = $self->{worker};
    lock $$worker;
    --$$worker;
    return cond_signal $$worker;
}

sub _handle_func {
    my ($self, $handler) = @_;
    return unless defined $handler;
    my @arg = @$handler;
    my $func = shift @arg;
    if (defined $func) {
        eval {
            ## no critic
            no strict 'refs';
            ## use critic
            $func->(@arg);
        };
        carp $@ if $@;
    }
    return;
}

sub _state {
    my $self = shift;
    my $state = $self->{state};
    lock $$state;
    return $$state unless @_;
    my $s = shift;
    $$state = $s;
    return $s;
}

sub join {
    my ($self, $nb) = @_;
    $self->_state(-1);
    my $max = do { lock %{$self->{config}}; $self->{config}{max} };
    $self->{pending}->enqueue((pack('Na*', 0, '')) x $max);
    return if $nb;
    $self->{shutdown_lock}->down();
    sleep 1; # cool down, otherwise may coredump while run tests
    return;
}

sub detach {
    my ($self) = @_;
    return $self->join(1);
}

sub busy {
    my ($self) = @_;
    my $worker = do { lock ${$self->{worker}}; ${$self->{worker}} };
    my ($min, $max, $load) = do { lock %{$self->{config}}; @{$self->{config}}{'min', 'max', 'load'} };
    my $pending = $self->{pending}->pending();

    # do not count the fake job added after join()
    $pending -= $max if $self->_state() == -1;
    return $worker < $min || $pending > $worker * $load;
}

sub terminating {
    my ($self) = @_;
    my $state = $self->_state();
    my $job = do { lock %{$self->{submitted}}; keys %{$self->{submitted}} };
    return 1 if $state == -1 && !$job;
    return 1 if $state == -2;
    return;
}

sub config {
    my $self = shift;
    my $config = $self->{config};
    lock %$config;
    return %$config unless @_;
    %$config = (%$config, @_);
    return %$config;
}

sub add {
    my $self = shift;
    my $context = wantarray;
    $context = 2 unless defined $context; # void context = 2
    my $arg = encode_json(\@_);
    my $id;
    while (1) {
        $id = int(rand(time()));
        next unless $id;
        ++$id unless $context == $id % 3;
        ++$id unless $context == $id % 3;
        do {
            lock %{$self->{submitted}};
            next if $self->job_exists($id);
            {
                # this is necessary as some cancelled jobs may slip in
                lock %{$self->{done}};
                delete $self->{done}{$id};
            }
            $self->{pending}->enqueue(pack('Na*', $id, $arg));
            $self->{submitted}{$id} = 1;
        };
        last;
    }
    return $id;
}

sub job_exists {
    my ($self, $id) = @_;
    lock %{$self->{submitted}};
    return $self->{submitted}{$id};
}

sub job_done {
    my ($self, $id) = @_;
    lock %{$self->{done}};
    return $self->{done}{$id};
}

sub _drop {
    my ($self, $id) = @_;
    lock %{$self->{submitted}};
    return delete $self->{submitted}{$id};
}

sub _remove {
    my ($self, $id, $nb) = @_;
    return if $id % 3 == 2;
    return unless $self->job_exists($id);
    my ($exist, $ret);
    {
        lock %{$self->{done}};
        if (!$nb) {
            cond_wait %{$self->{done}} until exists $self->{done}{$id};
            cond_signal %{$self->{done}} if 1 < keys %{$self->{done}};
        }
        $exist = ($ret) = delete $self->{done}{$id};
    }
    $self->_drop($id) if $exist;
    return $exist unless defined $ret;
    $ret = decode_json($ret);
    my $err = shift @$ret;
    croak $ret->[0] if $err eq 'e';
    return ($exist, @$ret) if $id % 3 == 1;
    return ($exist, $ret->[0]);
}

sub remove {
    my ($self, $id) = @_;
    my ($exist, @ret) = $self->_remove($id);
    return @ret;
}


sub remove_nb {
    my ($self, $id) = @_;
    return $self->_remove($id, 1);
}

sub cancel {
    my ($self, $id) = @_;
    my ($exist) = eval { $self->remove_nb($id) };
    if (!$exist) {
        lock %{$self->{submitted}};
        $self->{submitted}{$id} = 0;
    }
    return;
}

sub cancel_all {
    my ($self) = @_;
    my @id = do { lock %{$self->{submitted}}; keys %{$self->{submitted}} };
    for (@id) {
        $self->cancel($_);
    }
    return;
}

1;
__END__

=head1 NAME

Thruk::Pool::Simple - A simple thread-pool implementation

=head1 SYNOPSIS

  use Thruk::Pool::Simple;

  my $pool = Thruk::Pool::Simple->new(
                 min => 3,           # at least 3 workers
                 max => 5,           # at most 5 workers
                 load => 10,         # increase worker if on average every worker has 10 jobs waiting
                 init => [\&init_handle, $arg1, $arg2, ...]   # run before creating worker thread
                 pre => [\&pre_handle, $arg1, $arg2, ...]   # run after creating worker thread
                 do => [\&do_handle, $arg1, $arg2, ...]     # job handler for each worker
                 post => [\&post_handle, $arg1, $arg2, ...] # run before worker threads end
               );

  my ($id1) = $pool->add(@arg1); # call in list context
  my $id2 = $pool->add(@arg2);   # call in scalar conetxt
  $pool->add(@arg3)              # call in void context

  my @ret = $pool->remove($id1); # get result (block)
  my $ret = $pool->remove_nb($id2); # get result (no block)

  $pool->cancel($id1);           # cancel the job
  $pool->cancel_all();           # cancel all jobs

  $pool->join();                 # wait till all jobs are done
  $pool->detach();               # don't wait.

=head1 DESCRIPTION

C<Thruk::Pool::Simple> provides a simple thread-pool implementaion
without external dependencies outside core modules.

Jobs can be submitted to and handled by multi-threaded `workers'
managed by the pool.

=head1 AUTHOR

Jianyuan Wu, E<lt>jwu@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 by Jianyuan Wu

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
