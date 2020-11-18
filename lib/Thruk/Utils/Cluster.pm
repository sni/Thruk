package Thruk::Utils::Cluster;

=head1 NAME

Thruk::Utils::Cluster - Cluster Utilities Collection for Thruk

=head1 DESCRIPTION

Cluster Utilities Collection for Thruk

=cut

use strict;
use warnings;
use Thruk::Utils;
use Thruk::Utils::IO;
use Thruk::Utils::Crypt;
use Thruk::Backend::Provider::HTTP;
use Time::HiRes qw/gettimeofday tv_interval/;
use Carp qw/confess/;
use Data::Dumper qw/Dumper/;
use Thruk::Utils::Log qw/:all/;

my $context;

##########################################################

=head1 METHODS

=head2 new

create new cluster instance

=cut
sub new {
    my($class, $thruk) = @_;
    my $self = {
        nodes        => [],
        nodes_by_url => {},
        nodes_by_id  => {},
        config       => $thruk->config,
        registerfile => $thruk->config->{'var_path'}.'/cluster/nodes',
        localstate   => $thruk->config->{'tmp_path'}.'/cluster/nodes',
    };
    bless $self, $class;

    Thruk::Utils::IO::mkdir_r($self->{'config'}->{'var_path'}.'/cluster');
    Thruk::Utils::IO::mkdir_r($self->{'config'}->{'tmp_path'}.'/cluster');

    return $self;
}

##########################################################

=head2 load_statefile

load statefile and fill node structures

=cut
sub load_statefile {
    my($self) = @_;
    my $c = $Thruk::Utils::Cluster::context;
    $c->stats->profile(begin => "cluster::load_statefile") if $c;

    my $nodes = {};
    my $state = Thruk::Utils::IO::json_lock_retrieve($self->{'localstate'}) || {};
    my $now   = time();

    $self->{'nodes'}        = [];
    $self->{'nodes_by_url'} = {};
    $self->{'nodes_by_id'}  = {};

    # dynamic clusters
    my $registered;
    if(scalar @{$self->{'config'}->{'cluster_nodes'}} == 1) {
        # use registered urls from registerfile file
        $registered = Thruk::Utils::IO::json_lock_retrieve($self->{'registerfile'}) || {};
        for my $key (sort keys %{$registered}) {
            my $n = $state->{$key} || {};
            $n->{'node_url'} = $registered->{$key}->{'node_url'};

            # no contact in last x seconds, remove it completely from cluster
            if($registered->{$key}->{'last_update'} < $now - $self->{'config'}->{'cluster_node_stale_timeout'}) {
                Thruk::Utils::IO::json_lock_patch($self->{'registerfile'}, {
                    $key => undef,
                }, { pretty => 1 });
                next:
            }
            $nodes->{$key} = $n;
        }
    }
    # fixed size clusters
    else {
        my $x = 0;
        for my $url (@{$self->{'config'}->{'cluster_nodes'}}) {
            # get node from state file if possible
            $url = $self->_replace_url_macros($url);
            my $key = "node".$x;
            for my $k (sort keys %{$state}) {
                my $n = $state->{$k};
                if($n && $n->{'node_url'} && $url eq $n->{'node_url'}) {
                    $url = $n->{'node_url'};
                    $key = $n->{'node_id'} || $k;
                    last;
                }
            }
            my $n = $state->{$key} || {};
            $n->{'node_url'} = $url;
            $nodes->{$key} = $n;
            $x++;
        }
    }

    # add node to store
    for my $key (sort keys %{$nodes}) {
        my $n = $nodes->{$key};
        $n->{'node_id'}       = $key;
        push @{$self->{'nodes'}}, $n;
        $self->{'nodes_by_id'}->{$key} = $n;
        $self->{'nodes_by_url'}->{$n->{'node_url'}} = $n;
    }

    $self->{'node'} = $self->_find_my_node();
    $self->{'node'}->{'node_id'}     = $Thruk::NODE_ID;
    $self->{'node'}->{'hostname'}    = $Thruk::HOSTNAME;
    $self->{'node'}->{'pids'}->{$$}  = $now;
    if(!defined $self->{'node'}->{'maintenance'}) {
        # get status from registerfile
        $registered = Thruk::Utils::IO::json_lock_retrieve($self->{'registerfile'}) unless defined $registered;
        $self->{'node'}->{'maintenance'} = $registered->{$Thruk::NODE_ID}->{'maintenance'} // 0;
    }

    # set defaults
    for my $key (sort keys %{$nodes}) {
        my $n = $nodes->{$key};
        # set some defaults
        $n->{'hostname'}      = '' unless defined $n->{'hostname'};
        $n->{'last_contact'}  =  0 unless $n->{'last_contact'};
        $n->{'last_error'}    = '' unless $n->{'last_error'};
        $n->{'response_time'} = '' unless defined $n->{'response_time'};
        $n->{'version'}       = '' unless defined $n->{'version'};
        $n->{'branch'}        = '' unless defined $n->{'branch'};
        $n->{'maintenance'}   = 0  unless defined $n->{'maintenance'};
    }

    $self->check_stale_pids();

    # sort nodes by url
    @{$self->{'nodes'}} = sort { $a->{'node_url'} cmp $b->{'node_url'} } @{$self->{'nodes'}};

    Thruk::Utils::IO::json_lock_store($self->{'localstate'}, $self->{'nodes_by_id'}, { pretty => 1 });
    $c->stats->profile(end => "cluster::load_statefile") if $c;
    return $nodes;
}

##########################################################

=head2 register

registers this cluster node in the cluster statefile

=cut
sub register {
    my($self, $c) = @_;
    $Thruk::Utils::Cluster::context = $c;

    # in dynamic clustering, we need to register ourself so others know about us
    if(scalar @{$self->{'config'}->{'cluster_nodes'}} == 1) {
        Thruk::Utils::IO::json_lock_patch($self->{'registerfile'}, {
            $Thruk::NODE_ID => {
                node_url    => $self->_build_node_url() || '',
                last_update => time(),
            },
        }, { pretty => 1 });
    }

    $self->load_statefile();
    return;
}

##########################################################

=head2 unregister

removes ourself from the cluster statefile

=cut
sub unregister {
    my($self) = @_;
    return unless $Thruk::NODE_ID;
    return unless -s $self->{'localstate'};
    Thruk::Utils::IO::json_lock_patch($self->{'localstate'}, {
        $Thruk::NODE_ID => {
            pids => { $$ => undef },
        },
    }, { pretty => 1 });
    return;
}

##########################################################

=head2 refresh

refresh this cluster node in the cluster statefile

=cut
sub refresh {
    my($self) = @_;

    my $now = time();
    if($self->{'node'}->{'pids'}->{$$} && $self->{'node'}->{'pids'}->{$$} > $now - (5+int(rand(20)))) {
        return;
    }

    Thruk::Utils::IO::json_lock_patch($self->{'localstate'}, {
        $Thruk::NODE_ID => {
            pids => { $$ => $now },
        },
    }, { pretty => 1 });
    $self->{'node'}->{'pids'}->{$$}  = $now;
    return;
}

##########################################################

=head2 is_clustered

return 1 if a cluster is configured

=cut
sub is_clustered {
    my($self) = @_;
    return 0 if !$self->{'config'}->{'cluster_enabled'};
    return 1 if scalar keys %{$self->{nodes_by_url}} > 1;
    return 1 if scalar @{$self->{'config'}->{'cluster_nodes'}} > 1;
    return 0;
}

##########################################################

=head2 node_ids

return list of node ids

=cut
sub node_ids {
    my($self) = @_;
    return([keys %{$self->{nodes_by_id}}]);
}

##########################################################

=head2 run_cluster

run something on our cluster

    - type: can be
        - 'once'      runs job on current node unless it is in progress already
        - 'all'       runs job on all nodes
        - 'others'    runs job on all other nodes
        - <node url>  runs job on given node[s]
    - sub: class / sub name
    - args: arguments

returns 0 if no cluster is in use and caller can continue locally
returns 1 if a 'once' job runs somewhere already
returns list of results for each specified node

=cut
sub run_cluster {
    my($self, $type, $sub, $args) = @_;
    return 0 unless $self->is_clustered();
    return 0 if $ENV{'THRUK_SKIP_CLUSTER'};
    local $ENV{'THRUK_SKIP_CLUSTER'} = 1;

    my $c = $Thruk::Utils::Cluster::context || confess("uninitialized cluster");

    my $nodes = Thruk::Utils::list($type);
    if($type eq 'all' || $type eq 'others') {
        $nodes = $self->{'nodes'};
    }

    if($type eq 'once') {
        return 0 unless $ENV{'THRUK_CRON'};
        confess("no args supported") if $args;
        # check if cmd is already running
        my $digest = Thruk::Utils::Crypt::hexdigest(sprintf("%s-%s-%s", POSIX::strftime("%Y-%m-%d %H:%M", localtime()), $sub, Dumper($args)));
        my $jobs_path = $c->config->{'var_path'}.'/cluster/jobs';
        Thruk::Utils::IO::mkdir_r($jobs_path);
        Thruk::Utils::IO::write($jobs_path.'/'.$digest, $Thruk::NODE_ID."\n", undef, 1);
        my $lock = [split(/\n/mx, Thruk::Utils::IO::read($jobs_path.'/'.$digest))]->[0];
        if($lock ne $Thruk::NODE_ID) {
            _debug(sprintf("run_cluster once: %s running on %s already", $sub, $lock));
            return(1);
        }
        $self->_cleanup_jobs_folder();
        _debug(sprintf("run_cluster once: %s starting on %s", $sub, $lock));

        # continue and run on this node
        return(0);
    }

    # expand nodeurls/ids
    my @nodeids = @{$self->expand_node_ids(@{$nodes})};

    # if request contains only a single node and thats our own id, simply pass, no need to run that through extra web request
    if(scalar @nodeids == 1 && $self->is_it_me($nodeids[0])) {
        return(0);
    }

    # replace $c in args with placeholder
    $args = Thruk::Utils::encode_arg_refs($args);

    # run function on each cluster node
    my $res = [];
    for my $n (@nodeids) {
        next unless $self->{'nodes_by_id'}->{$n};
        next if($type eq 'others' && $self->is_it_me($n));
        _debug(sprintf("%s trying on %s", $sub, $n));
        my $node = $self->{'nodes_by_id'}->{$n};
        my $http = Thruk::Backend::Provider::HTTP->new({
                            options => {
                                peer => $node->{'node_url'},
                                auth => $c->config->{'secret_key'},
                            },
                        }, $c->config);
        my $t1   = [gettimeofday];
        my $r;
        eval {
            $r = $http->request($sub, $args, { want_data => 1 });
        };
        my $err = $@;
        my $elapsed = tv_interval($t1);
        if($err) {
            $err =~ s/^(OMD:.*?)\ at\ \/.*$/$1/gmx;
            if(!$node->{'last_error'} && !$node->{'maintenance'}) {
                _error(sprintf("%s failed on %s: %s", $sub, $node->{'hostname'}, $@));
            } else {
                _debug(sprintf("%s failed on %s: %s", $sub, $node->{'hostname'}, $@));
            }
            Thruk::Utils::IO::json_lock_patch($c->cluster->{'localstate'}, {
                $n => {
                    last_error => $err,
                },
            }, { pretty => 1 });
            $node->{'last_error'} = $err;
        } else {
            if($sub =~ m/Cluster::pong/mx) {
                if($n ne $r->{'output'}->[0]->{'node_id'}) {
                    my $new_id = $r->{'output'}->[0]->{'node_id'};
                    $self->{'nodes_by_id'}->{$new_id} = delete $self->{'nodes_by_id'}->{$n};
                    $n = $new_id;
                    Thruk::Utils::IO::json_lock_store($self->{'localstate'}, $self->{'nodes_by_id'}, { pretty => 1 });
                }
                Thruk::Utils::IO::json_lock_patch($c->cluster->{'localstate'}, {
                    $n => {
                        last_contact  => time(),
                        last_error    => '',
                        response_time => $elapsed,
                        version       => $r->{'version'},
                        branch        => $r->{'branch'},
                        hostname      => $r->{'output'}->[0]->{'hostname'},
                        node_id       => $n,
                        maintenance   => $r->{'output'}->[0]->{'maintenance'},
                    },
                }, { pretty => 1 });
            } else {
                Thruk::Utils::IO::json_lock_patch($c->cluster->{'localstate'}, {
                    $n => {
                        last_contact  => time(),
                        last_error    => '',
                    },
                }, { pretty => 1 });
            }
        }
        $r = $r->{'output'} if $r;
        if(ref $r eq 'ARRAY' && scalar @{$r} == 1) {
            push @{$res}, $r->[0];
        } else {
            push @{$res}, $r;
        }
    }

    return $res;
}

##########################################################

=head2 kill

  kill($c, $node, $signal, @pids)

cluster aware kill wrapper

=cut
sub kill {
    my($self, $c, $node, $sig, @pids) = @_;
    my $res = $self->run_cluster($node, "Thruk::Utils::Cluster::kill", [$self, $c, $node, $sig, @pids]);
    if(!$res) {
        return(CORE::kill($sig, @pids));
    }
    return($res->[0]);
}

##########################################################

=head2 pong

  pong($c, $node)

return a ping request

=cut
sub pong {
    my($c, $node, $url) = @_;
    # update our url
    $c->cluster->load_statefile();
    if($c->cluster->{'node'}->{'node_url'} && $c->cluster->{'node'}->{'node_url'} ne $url) {
        Thruk::Utils::IO::json_lock_patch($c->cluster->{'localstate'}, {
            $Thruk::NODE_ID => {
                node_url => $url,
            },
        }, { pretty => 1 });
        $c->cluster->{'node'}->{'node_url'} = $url;
    }
    return({
        time        => time(),
        node_id     => $Thruk::NODE_ID,
        hostname    => $Thruk::HOSTNAME,
        version     => $c->config->{'version'},
        branch      => $c->config->{'branch'},
        maintenance => $c->cluster->{'node'}->{'maintenance'},
    });
}

##########################################################

=head2 is_it_me

  is_it_me($self, $node|$node_id|$node_url)

returns true if this us

=cut
sub is_it_me {
    my($self, $n) = @_;
    if(ref $n eq 'HASH' && $n->{'node_id'} && $n->{'node_id'} eq $Thruk::NODE_ID) {
        return(1);
    }
    if($n eq $Thruk::NODE_ID) {
        return(1);
    }
    if($self->{'nodes_by_url'}->{$n} && $self->{'nodes_by_url'}->{$n}->{'key'} eq $Thruk::NODE_ID) {
        return(1);
    }
    return(0);
}

##########################################################

=head2 maint

  maint($self, $node, [$value])

returns true if this node is in maintenance mode.

=cut
sub maint {
    my($self, $node, $val) = @_;
    my $c = $Thruk::Utils::Cluster::context;
    $node = $c->cluster->{'node'} unless defined $node;
    my $old = $node->{'maintenance'} ? 1 : 0;
    if(defined $val) {
        confess("cluster not ready") unless($node && $node->{'node_id'});
        # is that us?
        if($self->is_it_me($node)) {
            # save to both files, otherwise information would be lost after an omd update where the tmp fs might be remountet
            for my $file ($self->{'registerfile'}, $self->{'localstate'}) {
                Thruk::Utils::IO::json_lock_patch($file, {
                    $node->{'node_id'} => {
                        maintenance => $val,
                    },
                }, { pretty => 1 });
            }
            $node->{'maintenance'} = $val;
            # update others
            $self->run_cluster('others', "Thruk::Utils::Cluster::heartbeat", [$self, $node->{'node_id'}]);
        } else {
            $self->run_cluster($node, "Thruk::Utils::Cluster::maint", [$self, undef, $val]);
            $self->run_cluster('all', "Thruk::Utils::Cluster::heartbeat", [$self]);
        }
    }
    return $old;
}

##########################################################

=head2 heartbeat

  heartbeat($self, [$node_id])

request pong from other nodes (or node if if given)

=cut
sub heartbeat {
    my($self, $node_id) = @_;
    local $ENV{'THRUK_SKIP_CLUSTER'} = 0; # allow further subsequent cluster calls
    my $c = $Thruk::Utils::Cluster::context;
    $c->cluster->load_statefile();
    my $nodes = {};
    for my $n (@{$c->cluster->{'nodes'}}) {
        next if $c->cluster->is_it_me($n);
        next if(defined $node_id && $n->{'node_id'} ne $node_id);
        _debug(sprintf("sending heartbeat: %s -> %s", $Thruk::HOSTNAME, $n->{'hostname'}|| $n->{'node_url'}));
        $nodes->{$n->{'node_id'}} = $c->cluster->run_cluster($n, "Thruk::Utils::Cluster::pong", [$c, $n->{'node_id'}, $n->{'node_url'}])->[0];
        _debug(sprintf("sending heartbeat: %s -> %s: done", $Thruk::HOSTNAME, $n->{'hostname'}|| $n->{'node_url'}));
    }
    return($nodes);
}

##########################################################
sub _build_node_url {
    my($self) = @_;
    my $hostname = $Thruk::HOSTNAME;
    my $url;
    if(scalar @{$self->{'config'}->{'cluster_nodes'}} == 1) {
        $url = $self->{'config'}->{'cluster_nodes'}->[0];
    } else {
        # is there a url in cluster_nodes which matches our hostname?
        for my $tst (@{$self->{'config'}->{'cluster_nodes'}}) {
            if($tst =~ m/\Q$hostname\E/mx) {
                $url = $tst;
                last;
            }
        }
        return "" unless $url;
    }
    $url =~ s%\$hostname\$%$hostname%mxi;
    $url = $self->_replace_url_macros($url);
    return($url);
}

##########################################################
sub _replace_url_macros {
    my($self, $url) = @_;
    my $proto = $self->{'config'}->{'omd_apache_proto'} ? $self->{'config'}->{'omd_apache_proto'} : 'http';
    $url =~ s%\$proto\$%$proto%mxi;
    my $url_prefix = $self->{'config'}->{'url_prefix'};
    $url =~ s%\$url_prefix\$%$url_prefix%mxi;
    $url =~ s%/+%/%gmx;
    $url =~ s%^(https?:/)%$1/%gmx;
    return($url);
}

##########################################################
sub _cleanup_jobs_folder {
    my($self) = @_;
    my $keep = time() - 600;
    my $jobs_path = $self->{'config'}->{'var_path'}.'/cluster/jobs';
    for my $file (glob($jobs_path.'/*')) {
        my @stat = stat($file);
        if($stat[9] && $stat[9] < $keep) {
            unlink($file);
        }
    }
    return;
}

##########################################################
sub _find_my_node {
    my($self) = @_;
    my $node = $self->{'nodes_by_id'}->{$Thruk::NODE_ID};
    return $node if $node;
    my $my_url = $self->_build_node_url() || '';
    return({}) unless $my_url;
    for my $n (@{$self->{'nodes'}}) {
        if($n->{'node_url'} eq $my_url) {
            return($n);
        }
    }
    return({});
}

##########################################################

=head2 expand_node_ids

  expand_node_ids($self, @nodes_ids_and_urls)

convert list of node_ids and node_urls to node_ids only.

=cut
sub expand_node_ids {
    my($self, @nodeids) = @_;
    my $expanded = [];
    for my $id (@nodeids) {
        if(ref $id eq 'HASH' && $id->{'node_id'}) {
            push @{$expanded}, $id->{'node_id'};
        }
        elsif($self->{'nodes_by_id'}->{$id}) {
            push @{$expanded}, $id;
        }
        elsif($self->{'nodes_by_url'}->{$id}) {
            push @{$expanded}, $self->{'nodes_by_url'}->{$id}->{'node_id'};
        }
    }
    return($expanded);
}

##########################################################

=head2 update_cron_file

    update_cron_file($c)

update downtimes cron

=cut
sub update_cron_file {
    my($c) = @_;

    my $cron_entries = [];

    if($c->config->{'cluster_enabled'}) {
        # ensure proper cron.log permission
        open(my $fh, '>>', $c->config->{'var_path'}.'/cron.log');
        Thruk::Utils::IO::close($fh, $c->config->{'var_path'}.'/cron.log');
        my $log = sprintf(">/dev/null 2>>%s/cron.log", $c->config->{'var_path'});
        my $cmd = sprintf("cd %s && %s '%s r -m POST /thruk/cluster/heartbeat ' %s",
                                $c->config->{'project_root'},
                                $c->config->{'thruk_shell'},
                                $c->config->{'thruk_bin'},
                                $log,
                        );
        my $time = '* * * * *';
        $cron_entries = [[$time, $cmd]];
    }
    Thruk::Utils::update_cron_file($c, 'cluster', $cron_entries);
    return;
}

##########################################################

=head2 check_stale_pids

    check_stale_pids($self)

check for stale pids

=cut
sub check_stale_pids {
    my($self) = @_;
    my $node = $self->{'node'};
    return unless $node;
    my $now = time();
    # check for stale pids
    for my $pid (sort keys %{$node->{'pids'}}) {
        next if $now - $node->{'pids'}->{$pid} < 120; # only check old pids
        if($pid != $$ && CORE::kill($pid, 0) != 1) {
            delete $self->{'node'}->{'pids'}->{$pid};
        }
    }
    return;
}

##########################################################

1;
