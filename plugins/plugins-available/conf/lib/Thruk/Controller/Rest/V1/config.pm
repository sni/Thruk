package Thruk::Controller::Rest::V1::config;

use strict;
use warnings;
use Storable qw/dclone/;

use Thruk::Controller::rest_v1;
use Thruk::Utils::Conf;

=head1 NAME

Thruk::Controller::Rest::V1::config - Config Tool Rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=cut

##########################################################
# REST PATH: GET /hosts/<name>/config
# returns configuration for given host

##########################################################
# REST PATH: GET /hostgroups/<name>/config
# returns configuration for given hostgroup

##########################################################
# REST PATH: GET /servicegroups/<name>/config
# returns configuration for given servicegroup
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/(host|hostgroup|servicegroup)s?/([^/]+)/config?$%mx, \&_rest_get_config, ["admin"]);
sub _rest_get_config {
    my($c, undef, $type, $name, $name2) = @_;
    my $live = [];
    if($type eq 'host') {
        $live = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), name => $name ], columns => [qw/name peer_key/]);
    } elsif($type eq 'service') {
        $live = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), host_name => $name, description => $name2 ], columns => [qw/host_name description peer_key/]);
    } elsif($type eq 'hostgroup') {
        $live = $c->{'db'}->get_hostgroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hostgroups'), name => $name ], columns => [qw/name peer_key/]);
    } elsif($type eq 'servicegroup') {
        $live = $c->{'db'}->get_servicegroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'servicegroups'), name => $name ], columns => [qw/name peer_key/]);
    }
    my $data = [];
    $c->config->{'no_external_job_forks'} = 1;
    for my $l (@{$live}) {
        $c->stash->{'param_backend'} = $l->{'peer_key'};
        Thruk::Utils::Conf::set_object_model($c);
        next unless $c->{'obj_db'};
        my $objs;
        if($type eq 'service') {
            my $objs = $c->{'obj_db'}->get_services_by_name($name, $name2);
            for my $o (@{$objs}) {
                my $conf = dclone($o->{'conf'});
                $conf->{'_FILE'} = $o->{'file'}->{'path'}.':'.$o->{'line'};
                push @{$data}, $conf;
            }
        } else {
            $objs = $c->{'obj_db'}->get_objects_by_name($type, $name, 0);
        }
        next unless $objs;
        for my $o (@{$objs}) {
            my $conf = dclone($o->{'conf'});
            $conf->{'_FILE'} = $o->{'file'}->{'path'}.':'.$o->{'line'};
            push @{$data}, $conf;
        }
    }
    return($data);
}

##########################################################
# REST PATH: GET /service/<host_name>/<service>/config
# returns configuration for given service
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/(service)s?/([^/]+)/([^/]+)/config?$%mx, \&_rest_get_config, ["admin"]);

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
