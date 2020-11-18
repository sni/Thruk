package Thruk::Controller::Rest::V1::cluster;

use strict;
use warnings;
use Thruk::Controller::rest_v1;
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::Controller::Rest::V1::cluster - Cluster rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=cut

##########################################################
# REST PATH: GET /thruk/cluster
# lists cluster nodes
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/cluster$%mx, \&_rest_get_thruk_cluster, ['authorized_for_system_information']);
sub _rest_get_thruk_cluster {
    my($c) = @_;
    $c->cluster->load_statefile();
    return($c->cluster->{'nodes'});
}

##########################################################
# REST PATH: GET /thruk/cluster/heartbeat
# should not be used, use POST method instead
# REST PATH: POST /thruk/cluster/heartbeat
# send cluster heartbeat to all other nodes
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/thruk/cluster/heartbeat$%mx, \&_rest_get_thruk_cluster_heartbeat, ['admin']);
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/cluster/heartbeat$%mx, \&_rest_get_thruk_cluster_heartbeat, ['admin']);
sub _rest_get_thruk_cluster_heartbeat {
    my($c) = @_;
    return({ 'message' => 'cluster disabled', 'description' => 'this is a single node installation and not clustered', code => 501 }) unless $c->cluster->is_clustered();
    if($c->req->method() eq 'GET') {
        return({ 'message' => 'bad request', description => 'POST method required', code => 400 });
    }

    # cron mode: cron starts heartbeat every minute, if heartbeat interval is less than a minute, do multiple checks and sleep meanwhile
    if($ENV{'THRUK_CRON'} && $c->config->{'cluster_heartbeat_interval'} > 0 && $c->config->{'cluster_heartbeat_interval'} < 60) {
        local $ENV{'THRUK_CRON'} = undef;
        my $start = time();
        while(time() - $start < 60) {
            my $now = time();
            _rest_get_thruk_cluster_heartbeat($c);
            sleep($c->config->{'cluster_heartbeat_interval'} - (time() - $now));
        }
        return;
    }
    alarm(60);
    my $nodes = $c->cluster->heartbeat();
    alarm(0);
    return({ 'message' => 'heartbeat send', 'nodes' => $nodes });
}

##########################################################
# REST PATH: POST /thruk/cluster/restart
# restarts all cluster nodes sequentially
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/thruk/cluster/restart$%mx, \&_rest_get_thruk_cluster_restart, ['admin']);
sub _rest_get_thruk_cluster_restart {
    my($c) = @_;
    return({ 'message' => 'cluster disabled', 'description' => 'this is a single node installation and not clustered', code => 501 }) unless $c->cluster->is_clustered();
    if($c->req->method() eq 'GET') {
        return({ 'message' => 'bad request', description => 'POST method required', code => 400 });
    }

    alarm(60);
    local $ENV{'THRUK_SKIP_CLUSTER'} = 0; # allow further subsequent cluster calls
    $c->cluster->load_statefile();
    my $nodes = {};
    for my $n (@{$c->cluster->{'nodes'}}) {
        next if $c->cluster->is_it_me($n);
        _debug(sprintf("restarting node: %s -> %s", $Thruk::HOSTNAME, $n->{'hostname'}|| $n->{'node_url'}));
        # run stop on all nodes, apache will start them again automatically
        $c->cluster->run_cluster($n, "Thruk::Utils::stop_all", [$c]);
        _debug(sprintf("restarting node: %s -> %s: done", $Thruk::HOSTNAME, $n->{'hostname'}|| $n->{'node_url'}));
    }

    # ping nodes to start at least one process
    for my $n (@{$c->cluster->{'nodes'}}) {
        next if $c->cluster->is_it_me($n);
        _debug(sprintf("sending heartbeat: %s -> %s", $Thruk::HOSTNAME, $n->{'hostname'}|| $n->{'node_url'}));
        $nodes->{$n->{'node_id'}} = $c->cluster->run_cluster($n, "Thruk::Utils::Cluster::pong", [$c, $n->{'node_id'}, $n->{'node_url'}])->[0];
        _debug(sprintf("sending heartbeat: %s -> %s: done", $Thruk::HOSTNAME, $n->{'hostname'}|| $n->{'node_url'}));
    }

    alarm(0);

    # stop our own process gracefully
    $c->app->stop_all();

    return({'message' => 'all cluster nodes restarted', 'nodes' => $nodes});
}

##########################################################
# REST PATH: GET /thruk/cluster/<id>
# return cluster state for given node.
#
# See `/thruk/cluster/` for the description of the attributes.
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/thruk/cluster/([^/]+)$%mx, \&_rest_get_thruk_cluster_node_by_id, ['authorized_for_system_information']);
sub _rest_get_thruk_cluster_node_by_id {
    my($c, $path_info, $node_id) = @_;
    $c->cluster->load_statefile();
    ($node_id) = @{$c->cluster->expand_node_ids($node_id)};
    return($c->cluster->{'nodes_by_id'}->{$node_id}) if $node_id;
    return({ 'message' => 'no such cluster node', code => 404 });
}

##########################################################

1;
