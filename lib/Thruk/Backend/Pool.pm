package Thruk::Backend::Pool;

use strict ();
use warnings ();
use threads ();

use Thruk::Pool::Simple ();
use Thruk::Backend::Peer ();
use Config::General ();

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
    our($peer_order, $peers, $pool);
    if(defined $peers) {
        return;
    }

    $peer_order  = [];
    $peers       = {};

    my $config       = get_config();
    my $peer_configs = $config->{'Component'}->{'Thruk::Backend'}->{'peer'} || $config->{'Thruk::Backend'}->{'peer'};
    $peer_configs    = ref $peer_configs eq 'HASH' ? [ $peer_configs ] : $peer_configs;
    $peer_configs    = [] unless defined $peer_configs;
    my $pool_size    = defined $config->{'connection_pool_size'} ? $config->{'connection_pool_size'} : 100;
    my $num_peers    = scalar @{$peer_configs};
    my $use_curl     = $config->{'use_curl'};
    $config->{'deprecations_shown'} = {};
    $pool_size       = $num_peers if $num_peers < $pool_size;

    if($num_peers > 0) {
        my  $peer_keys   = {};
        for my $peer_config (@{$peer_configs}) {
            $peer_config->{'use_curl'} = $use_curl;
            my $peer = Thruk::Backend::Peer->new( $peer_config, $config->{'logcache'}, $peer_keys );
            $peer_keys->{$peer->{'key'}} = 1;
            $peers->{$peer->{'key'}}     = $peer;
            push @{$peer_order}, $peer->{'key'};
            if($peer_config->{'groups'} and !$config->{'deprecations_shown'}->{'backend_groups'}) {
                print STDERR "*** DEPRECATED: using groups option in peers is deprecated and will be removed in future releases.\n";
                $config->{'deprecations_shown'}->{'backend_groups'} = 1;
            }
        }
        if($num_peers > 1) {
            $Storable::Eval    = 1;
            $Storable::Deparse = 1;
            $SIG{'USR1'}  = undef;
            $pool = Thruk::Pool::Simple->new(
                min      => $pool_size,
                max      => $pool_size,
                do       => [\&Thruk::Backend::Pool::_do_thread ],
            );
            # wait till we got all worker running
            my $worker = 0;
            while($worker < $pool_size) { sleep(0.3); $worker = do { lock ${$pool->{worker}}; ${$pool->{worker}} }; }
        } else {
            $ENV{'THRUK_NO_CONNECTION_POOL'} = 1;
        }
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
    return(do_on_peer($key, $function, $arg));
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
                ## no critic
                eval($arg->[$x+1]);
                ## use critic
            }
        }
    }

    my $peer = $Thruk::Backend::Pool::peers->{$key};
    confess("no peer for key: $key, got: ".join(', ', keys %{$Thruk::Backend::Pool::peers})) unless defined $peer;
    my($type, $size, $data, $last_error);
    my $errors = 0;
    while($errors < 3) {
        eval {
            ($data,$type,$size) = $peer->{'class'}->$function( @{$arg} );
            if(defined $data and !defined $size) {
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
            $last_error =~ s/\s+at\s+.*?\s+line\s+\d+//gmx;
            $last_error =~ s/thread\s+\d+//gmx;
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
    if($peer->{'logcache'}) {
        $peer->{'logcache'}->_disconnect();
    }

    return([$type, $size, $data, $last_error]);
}

########################################

=head2 get_config

  get_config()

return small thruks config without defaults. Needed for the backends only.

=cut

sub get_config {
    for my $path ('.', $ENV{'CATALYST_CONFIG'}, $ENV{'THRUK_CONFIG'}) {
        next unless defined $path;
        push @files, $path.'/thruk.conf'       if -f $path.'/thruk.conf';
        push @files, $path.'/thruk_local.conf' if -f $path.'/thruk_local.conf';
    }

    my %config;
    for my $file (@files) {
        my %conf = Config::General::ParseConfig($file);
        for my $key (keys %conf) {
            if(defined $config{$key} and ref $config{$key} eq 'HASH') {
                $config{$key} = { %{$config{$key}}, %{$conf{$key}} };
            } else {
                $config{$key} = $conf{$key};
            }
        }
    }

    $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = $config{'ssl_verify_hostnames'};

    return \%config;
}

########################################

=head1 AUTHOR

Sven Nierlein, 2013, <sven.nierlein@consol.de>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
