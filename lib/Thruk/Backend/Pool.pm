package Thruk::Backend::Pool;

use warnings;
use strict;
use Carp qw/confess/;
use Cwd ();
use Scalar::Util qw/weaken/;
use Time::HiRes qw/gettimeofday tv_interval/;

use Thruk::Backend::Manager ();
use Thruk::Backend::Peer ();
use Thruk::Backend::Provider::Livestatus ();
use Thruk::Base ();
use Thruk::Constants qw/:add_defaults :peer_states/;
use Thruk::Utils::IO ();

use Plack::Util::Accessor qw(peers peer_order lmd_peer thread_pool);

#use Thruk::Timer qw/timing_breakpoint/;
#&timing_breakpoint('starting pool');


=head1 NAME

Thruk::Backend::Pool - Pool of backend connections

=head1 DESCRIPTION

Pool of backend connections

=head1 METHODS

=cut

########################################

=head2 new

  Thruk::Backend::Pool->new($backend_configs)

return new db connection pool

=cut

sub new {
    my($class, $backend_configs) = @_;
    my $self = {
        'peer_order' => [],     # keys in correct order
        'objects'    => [],     # peer objects in correct order
        'peers'      => {},     # peer objects by key
        'by_name'    => {},     # peer objects by name
        'xs'         => 0,      # flag wether xs is available
        'lmd_peer'   => undef,  # lmd peer
    };
    bless $self, $class;

    #&timing_breakpoint('creating pool');

    eval {
        require Thruk::Utils::XS;
        Thruk::Utils::XS->import();
        $self->{'xs'} = 1;
    };

    # change into home folder so we can use relative paths
    if($ENV{'OMD_ROOT'}) {
        ## no critic
        $ENV{'THRUKOLDPWD'} = Cwd::getcwd();
        $ENV{'HOME'} = $ENV{'OMD_ROOT'};
        ## use critic
        chdir($ENV{'HOME'});
    }

    my $config       = Thruk::Base->config;
    my $peer_configs = Thruk::Base::list($backend_configs || $config->{'Thruk::Backend'}->{'peer'});
    my $num_peers    = scalar @{$peer_configs};
    my $pool_size;
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
        my $lmd_peer = Thruk::Backend::Provider::Livestatus->new({options => {
                                                peer      => $config->{'lmd_remote'} // $config->{'tmp_path'}.'/lmd/live.sock',
                                                peer_key  => 'lmdpeer',
                                                retries_on_connection_error => 0,
                                            }});
        $lmd_peer->peer_key('lmdpeer');
        $lmd_peer->{'lmd_optimizations'} = 1;
        $self->{'lmd_peer'} = $lmd_peer;
        if($config->{'lmd_remote'}) {
            my $p = Thruk::Backend::Peer->new({
                options  => {
                    peer   => $config->{'lmd_remote'},
                },
                name     => "lmd",
                type     => "livestatus",
                id       => 'LMD',
            });
            $p->{'disabled'} = HIDDEN_LMD_PARENT;
            $self->peer_add($p, $config, {});
        }
    }

    if(!defined $ENV{'THRUK_CURL'} || $ENV{'THRUK_CURL'} == 0) {
        if($https_count > 1) {
            # https://metacpan.org/pod/Net::SSLeay#Using-Net::SSLeay-in-multi-threaded-applications
            eval {
                use threads ();
                require Net::SSLeay;
                require IO::Socket::SSL;

                Net::SSLeay::load_error_strings();
                Net::SSLeay::SSLeay_add_ssl_algorithms();
                Net::SSLeay::randomize();
            };
            if($@) {
                die('IO::Socket::SSL and Net::SSLeay (>=1.43) is required for multiple parallel https connections: '.$@);
            }
            ## no lint
            if(!$Net::SSLeay::VERSION || $Net::SSLeay::VERSION < 1.43) {
                die('Net::SSLeay (>=1.43) is required for multiple parallel https connections, you have '.($Net::SSLeay::VERSION ? $Net::SSLeay::VERSION : 'unknown'));
            }
            ## use lint
            if($INC{'Crypt/SSLeay.pm'}) {
                die('Crypt::SSLeay must not be loaded for multiple parallel https connections!');
            }
        }
    }

    if($num_peers > 0) {
        my $peer_keys   = {};
        for my $peer_config (@{$peer_configs}) {
            my $peer = Thruk::Backend::Peer->new($peer_config, $config, $peer_keys);
            $peer_keys->{$peer->{'key'}} = 1;
            $self->peer_add($peer);
            if($peer_config->{'groups'} && !$config->{'deprecations_shown'}->{'backend_groups'}) {
                $Thruk::Globals::deprecations_log = [] unless defined $Thruk::Globals::deprecations_log;
                push @{$Thruk::Globals::deprecations_log}, "*** DEPRECATED: using groups option in peers is deprecated and will be removed in future releases.";
                $config->{'deprecations_shown'}->{'backend_groups'} = 1;
            }
        }
        #&timing_breakpoint('peers created');
        if($pool_size > 1) {
            printf(STDERR "mem:% 7s MB before pool with %d members\n", Thruk::Utils::IO::get_memory_usage(), $pool_size) if($ENV{'THRUK_PERFORMANCE_DEBUG'} && $ENV{'THRUK_PERFORMANCE_DEBUG'} >= 2);
            ## no critic
            $SIG{'USR1'}  = undef if $SIG{'USR1'};
            ## use critic
            require Thruk::Pool::Simple;
            $self->{'thread_pool'} = Thruk::Pool::Simple->new(
                size    => $pool_size,
                handler => sub { $self->_do_thread(@_) },
            );
            weaken($self->{'thread_pool'}->{'handler'});
            printf(STDERR "mem:% 7s MB after pool\n", Thruk::Utils::IO::get_memory_usage()) if($ENV{'THRUK_PERFORMANCE_DEBUG'} && $ENV{'THRUK_PERFORMANCE_DEBUG'} >= 2);
        } else {
            printf(STDERR "mem:% 7s MB without pool\n", Thruk::Utils::IO::get_memory_usage()) if($ENV{'THRUK_PERFORMANCE_DEBUG'} && $ENV{'THRUK_PERFORMANCE_DEBUG'} >= 2);
            ## no critic
            $ENV{'THRUK_NO_CONNECTION_POOL'} = 1;
            ## use critic
        }
    }

    #&timing_breakpoint('creating pool done');
    return($self);
}

########################################

=head2 peer_add

  peer_add($peer)

add peer to pool

=cut

sub peer_add {
    my($self, $peer) = @_;
    $self->{'peers'}->{$peer->{'key'}}    = $peer;
    $self->{'by_name'}->{$peer->{'name'}} = $peer;
    push @{$self->{'peer_order'}}, $peer->{'key'};
    push @{$self->{'objects'}}, $peer;
    return;
}

########################################

=head2 peer_remove

  peer_remove($key|$peer)

remove peer from pool

=cut

sub peer_remove {
    my($self, $key) = @_;
    my $peer;
    if(ref $key eq '') {
        $peer = $self->{'peers'}->{$key};
    } else {
        $peer = $key;
        $key  = $peer->{'key'};
    }
    delete $self->{'peers'}->{$key};
    delete $self->{'by_name'}->{$peer->{'name'}};
    $self->{'peer_order'} = Thruk::Base::array_remove($self->{'peer_order'}, $key);
    $self->{'objects'}    = Thruk::Base::array_remove($self->{'objects'}, $peer);
    return;
}

########################################

=head2 shutdown_threads

  shutdown_threads()

shutdown thread connection pool

=cut

sub shutdown_threads {
    my($self) = @_;

    return unless $self->{'thread_pool'};
    eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm(3);
        $self->{'thread_pool'}->shutdown();
        delete $self->{'thread_pool'};
    };
    alarm(0);
    return;
}

########################################

=head2 _do_thread

  _do_thread()

do the work on threads

=cut

sub _do_thread {
    my($self, $key, $function, $arg) = @_;
    my $t1 = [gettimeofday];
    my $res = $self->do_on_peer($key, $function, $arg);
    my $elapsed = tv_interval($t1);
    unshift @{$res}, $elapsed;
    unshift @{$res}, $key;
    return(@{$res});
}

########################################

=head2 do_on_peer

  do_on_peer($self, $key, $function, $args)

run a function on a backend peer

=cut

sub do_on_peer {
    my($self, $key, $function, $arg) = @_;

    # make it possible to run code in thread context
    my $arg_hash = {};
    if(ref $arg eq 'ARRAY') {
        for(my $x = 0; $x < scalar @{$arg}; $x += 2) {
            $arg_hash->{$arg->[$x]} = $arg->[$x+1];
            if($arg->[$x] and $arg->[$x] eq 'eval') {
                my $inc;
                my $code = $arg->[$x+1];
                if(ref($code) eq 'HASH') {
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

    my $peer = $self->{'peers'}->{$key};
    confess("no peer for key: $key, got: ".join(', ', keys %{$self->{'peers'}})) unless defined $peer;
    if($arg_hash->{'force_type'} && $arg_hash->{'force_type'} eq 'http') {
        if(lc($peer->{'type'}) ne 'http') {
            for my $src (@{$peer->{'peer_list'}}) {
                if($src =~ m/^https?:/mx) {
                    $peer = Thruk::Backend::Manager::fork_http_peer($peer, $src);
                    last;
                }
            }
        }
    }
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

=head2 set_logger

  set_logger($logger, $verbose)

set logger object for all pool peers and sets verbose

=cut

sub set_logger {
    my($self, $logger, $verbose) = @_;
    for my $peer (values %{$self->{'peers'}}) {
        next unless $peer->{'class'};
        next unless $peer->{'class'}->{'live'};
        next unless $peer->{'class'}->{'live'}->{'backend_obj'};
        my $peer_cls = $peer->{'class'}->{'live'}->{'backend_obj'};
        $peer_cls->{'logger'} = $logger;
        $peer_cls->verbose($verbose);
    }
    return;
}

########################################

1;
