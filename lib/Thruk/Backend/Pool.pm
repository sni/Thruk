package Thruk::Backend::Pool;

use strict;
use warnings;

#use Thruk::Timer qw/timing_breakpoint/;
#&timing_breakpoint('starting pool');

use Carp qw/confess/;
use Thruk::Backend::Peer ();
use Thruk ();
use Thruk::Config ();
use Thruk::Utils::IO ();
use Time::HiRes qw/gettimeofday tv_interval/;

=head1 NAME

Thruk::Backend::Pool - Pool of backend connections

=head1 DESCRIPTION

Pool of backend connections

=head1 METHODS

=cut

########################################

=head2 init_backend_thread_pool

  init_backend_thread_pool()

init thread connection pool

=cut

sub init_backend_thread_pool {
    my($backends) = @_;
    our($peer_order, $peers, $pool, $pool_size, $xs, $lmd_peer);
    return if(defined $peers && !$backends);
    #&timing_breakpoint('creating pool');

    $xs = 0;
    eval {
        require Thruk::Utils::XS;
        Thruk::Utils::XS->import();
        $xs = 1;
    };

    # change into home folder so we can use relative paths
    if($ENV{'OMD_ROOT'}) {
        ## no critic
        $ENV{'HOME'} = $ENV{'OMD_ROOT'};
        ## use critic
        chdir($ENV{'HOME'});
    }

    $peer_order  = [];
    $peers       = {};

    my $config       = Thruk->config;
    my $peer_configs = Thruk::Config::list($backends || $config->{'Thruk::Backend'}->{'peer'});
    my $num_peers    = scalar @{$peer_configs};
    if(defined $config->{'connection_pool_size'}) {
        $pool_size   = $config->{'connection_pool_size'};
    } elsif($num_peers >= 3) {
        $pool_size   = $num_peers;
    } else {
        $pool_size   = 1;
    }
    $pool_size       = 1 if $ENV{'THRUK_NO_CONNECTION_POOL'};
    $config->{'deprecations_shown'} = {};
    $pool_size       = $num_peers if $num_peers < $pool_size;


    # if we have multiple https backends, make sure we use the thread safe IO::Socket::SSL
    my $https_count = 0;
    for my $peer_config (@{$peer_configs}) {
        if($peer_config->{'options'} && $peer_config->{'options'}->{'peer'} && $peer_config->{'options'}->{'peer'} =~ m/^https/mxio) {
            $https_count++;
        }
    }

    if($config->{'use_lmd_core'}) {
        $pool_size = 1; # no pool required when using lmd core
        ## no critic
        $ENV{'THRUK_NO_CONNECTION_POOL'} = 1;
        $ENV{'THRUK_USE_LMD'} = 1;
        ## use critic
        eval {
            Thruk::Utils::IO::mkdir_r($config->{'tmp_path'}.'/lmd') ;
        };
        die("could not create lmd ".$config->{'tmp_path'}.'/lmd'.': '.$@) if $@;
        $lmd_peer = Thruk::Backend::Provider::Livestatus->new({options => {
                                                peer      => $config->{'tmp_path'}.'/lmd/live.sock',
                                                peer_key  => 'lmdpeer',
                                                retries_on_connection_error => 0,
                                            }});
        $lmd_peer->peer_key('lmdpeer');
        $lmd_peer->{'lmd_optimizations'} = 1;
    }

    if(!defined $ENV{'THRUK_CURL'} || $ENV{'THRUK_CURL'} == 0) {
        if($https_count > 2 && $pool_size > 1) {
            eval {
                require IO::Socket::SSL;
                IO::Socket::SSL->import();
            };
            if($@) {
                die('IO::Socket::SSL and Net::SSLeay (>1.43) is required for multiple parallel https connections: '.$@);
            }
            if(!$Net::SSLeay::VERSION || $Net::SSLeay::VERSION < 1.43) {
                die('Net::SSLeay (>=1.43) is required for multiple parallel https connections, you have '.($Net::SSLeay::VERSION ? $Net::SSLeay::VERSION : 'unknown'));
            }
            if($INC{'Crypt/SSLeay.pm'}) {
                die('Crypt::SSLeay must not be loaded for multiple parallel https connections!');
            }
        }
    }

    if($num_peers > 0) {
        my  $peer_keys   = {};
        for my $peer_config (@{$peer_configs}) {
            my $peer = Thruk::Backend::Peer->new($peer_config, $config, $peer_keys);
            $peer_keys->{$peer->{'key'}} = 1;
            $peers->{$peer->{'key'}}     = $peer;
            push @{$peer_order}, $peer->{'key'};
            if($peer_config->{'groups'} && !$config->{'deprecations_shown'}->{'backend_groups'}) {
                $Thruk::deprecations_log = [] unless defined $Thruk::deprecations_log;
                push @{$Thruk::deprecations_log}, "*** DEPRECATED: using groups option in peers is deprecated and will be removed in future releases.";
                $config->{'deprecations_shown'}->{'backend_groups'} = 1;
            }
        }
        #&timing_breakpoint('peers created');
        if($pool_size > 1) {
            #printf(STDERR "mem:% 7s MB before pool with %d members\n", get_memory_usage(), $pool_size) if $ENV{'THRUK_PERFORMANCE_DEBUG'};
            ## no critic
            $SIG{'USR1'}  = undef if $SIG{'USR1'};
            ## use critic
            require Thruk::Pool::Simple;
            $pool = Thruk::Pool::Simple->new(
                size    => $pool_size,
                handler => \&_do_thread,
            );
            #printf(STDERR "mem:% 7s MB after pool\n", get_memory_usage()) if $ENV{'THRUK_PERFORMANCE_DEBUG'};
        } else {
            #printf(STDERR "mem:% 7s MB without pool\n", get_memory_usage()) if $ENV{'THRUK_PERFORMANCE_DEBUG'};
            ## no critic
            $ENV{'THRUK_NO_CONNECTION_POOL'} = 1;
            ## use critic
        }
    }

    #&timing_breakpoint('creating pool done');
    return;
}

########################################

=head2 shutdown_backend_thread_pool

  shutdown_backend_thread_pool()

shutdown thread connection pool

=cut

sub shutdown_backend_thread_pool {
    our($peer_order, $peers, $pool, $pool_size);

    if($pool) {
        eval {
            local $SIG{ALRM} = sub { die "alarm\n" };
            alarm(3);
            $pool->shutdown();
            $pool = undef;
        };
        alarm(0);
    }
    return;
}

########################################

=head2 _do_thread

  _do_thread()

do the work on threads

=cut

sub _do_thread {
    my($key, $function, $arg) = @_;
    my $t1 = [gettimeofday];
    my $res = do_on_peer($key, $function, $arg);
    my $elapsed = tv_interval($t1);
    unshift @{$res}, $elapsed;
    unshift @{$res}, $key;
    return($res);
}

########################################

=head2 do_on_peer

  do_on_peer($key, $function, $args)

run a function on a backend peer

=cut

sub do_on_peer {
    my($key, $function, $arg) = @_;

    # make it possible to run code in thread context
    if(ref $arg eq 'ARRAY') {
        for(my $x = 0; $x <= scalar @{$arg}; $x++) {
            if($arg->[$x] and $arg->[$x] eq 'eval') {
                my $inc;
                my $code = $arg->[$x+1];
                if(ref($code) eq 'HASH') {
                    require Cwd;
                    for my $path ('/', (defined $ENV{'OMD_ROOT'} ? $ENV{'OMD_ROOT'}.'/share/thruk/plugins/plugins-available/' : Cwd::getcwd().'/plugins/plugins-available/')) {
                        if(-e $path.'/'.$code->{'inc'}) {
                            $inc  = $path.'/'.$code->{'inc'};
                            last;
                        }
                    }
                    $code = $code->{'code'};
                    push @INC, $inc if $inc;
                }
                ## no critic
                eval($code);
                ## use critic
                if($@) {
                    require Data::Dumper;
                    Data::Dumper->import();
                    die("eval failed:".Dumper(Cwd::getcwd(), $arg, $@));
                }
                pop @INC if $inc;
            }
        }
    }

    my $peer = $Thruk::Backend::Pool::peers->{$key};
    confess("no peer for key: $key, got: ".join(', ', keys %{$Thruk::Backend::Pool::peers})) unless defined $peer;
    my($type, $size, $data, $last_error);
    my $errors = 0;
    while($errors < 3) {
        eval {
            ($data,$type,$size) = $peer->{'class'}->$function(@{$arg});
            if(defined $data && !defined $size) {
                if(ref $data eq 'ARRAY') {
                    $size = scalar @{$data};
                }
                elsif(ref $data eq 'HASH') {
                    $size = scalar keys %{$data};
                }
            }
            $size = 0 unless defined $size;
        };
        if($@) {
            $last_error = $@;
            $last_error =~ s/^(.*?)\n.*$/$1/sgmx;
            $last_error =~ s/\s+at\s+.*?\s+line\s+\d+\s*//gmx;
            $last_error =~ s/thread\s+\d+\.?//gmx;
            $last_error =~ s/^ERROR:\ //gmx;
            $last_error = "ERROR: ".$last_error;
            $errors++;
            if($last_error =~ m/can't\ get\ db\ response,\ not\ connected\ at/mx) {
                $peer->{'class'}->reconnect();
            } else {
                last;
            }
        } else {
            last;
        }
    }

    # don't keep connections open
    if($peer->{'_logcache'}) {
        $peer->logcache->_disconnect();
    }

    return([$type, $size, $data, $last_error]);
}

########################################

=head2 get_memory_usage

  get_memory_usage([$pid])

return memory usage of pid or own process if no pid specified

=cut

sub get_memory_usage {
    my($pid) = @_;
    $pid = $$ unless defined $pid;
    my $page_size_in_kb = 4;
    if(sysopen(my $fh, "/proc/$pid/statm", 0)) {
        sysread($fh, my $line, 255) or die $!;
        CORE::close($fh);
        my(undef, $rss) = split(/\s+/mx, $line,  3);
        return(sprintf("%.2f", ($rss*$page_size_in_kb)/1024));
    }
    my $rsize;
    open(my $ph, '-|', "ps -p $pid -o rss") or die("ps failed: $!");
    while(my $line = <$ph>) {
        if($line =~ m/(\d+)/mx) {
            $rsize = sprintf("%.2f", $1/1024);
        }
    }
    CORE::close($ph);
    return($rsize);
}

########################################

1;
