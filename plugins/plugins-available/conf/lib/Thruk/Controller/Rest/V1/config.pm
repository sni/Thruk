package Thruk::Controller::Rest::V1::config;

use strict;
use warnings;
use Storable qw/dclone/;
use Time::HiRes qw/sleep/;
use Cpanel::JSON::XS qw//;

use Thruk::Controller::rest_v1;
use Thruk::Controller::conf;
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
# you will find available attributes here: http://www.naemon.org/documentation/usersguide/objectdefinitions.html#host

##########################################################
# REST PATH: POST /hosts/<name>/config
# replace host configuration completely, use PATCH to only update specific attributes

##########################################################
# REST PATH: PATCH /hosts/<name>/config
# update host configuration partially

##########################################################
# REST PATH: DELETE /hosts/<name>/config
# deletes given host from configuration

##########################################################
# REST PATH: GET /hostgroups/<name>/config
# returns configuration for given hostgroup
# you will find available attributes here: http://www.naemon.org/documentation/usersguide/objectdefinitions.html#hostgroup

##########################################################
# REST PATH: POST /hostgroups/<name>/config
# replace hostgroups configuration completely, use PATCH to only update specific attributes

##########################################################
# REST PATH: PATCH /hostgroups/<name>/config
# update hostgroup configuration partially

##########################################################
# REST PATH: DELETE /hostgroups/<name>/config
# deletes given hostgroup from configuration

##########################################################
# REST PATH: GET /servicegroups/<name>/config
# returns configuration for given servicegroup
# you will find available attributes here: http://www.naemon.org/documentation/usersguide/objectdefinitions.html#servicegroup

##########################################################
# REST PATH: POST /servicegroups/<name>/config
# replace servicegroup configuration completely, use PATCH to only update specific attributes

##########################################################
# REST PATH: PATCH /servicegroups/<name>/config
# update servicegroup configuration partially

##########################################################
# REST PATH: DELETE /servicegroups/<name>/config
# deletes given servicegroup from configuration

##########################################################
# REST PATH: GET /contacts/<name>/config
# returns configuration for given contact
# you will find available attributes here: http://www.naemon.org/documentation/usersguide/objectdefinitions.html#contact

##########################################################
# REST PATH: POST /contacts/<name>/config
# replace contact configuration completely, use PATCH to only update specific attributes

##########################################################
# REST PATH: PATCH /contacts/<name>/config
# update contact configuration partially

##########################################################
# REST PATH: DELETE /contact/<name>/config
# deletes given contact from configuration

##########################################################
# REST PATH: GET /contactgroups/<name>/config
# returns configuration for given contactgroup
# you will find available attributes here: http://www.naemon.org/documentation/usersguide/objectdefinitions.html#contactgroup

##########################################################
# REST PATH: POST /contactgroups/<name>/config
# replace contactgroup configuration completely, use PATCH to only update specific attributes

##########################################################
# REST PATH: PATCH /contactgroups/<name>/config
# update contactgroup configuration partially

##########################################################
# REST PATH: DELETE /contactgroups/<name>/config
# deletes given contactgroup from configuration

##########################################################
# REST PATH: GET /timeperiods/<name>/config
# returns configuration for given timeperiod
# you will find available attributes here: http://www.naemon.org/documentation/usersguide/objectdefinitions.html#timeperiod

##########################################################
# REST PATH: POST /timeperiods/<name>/config
# replace timeperiod configuration completely, use PATCH to only update specific attributes

##########################################################
# REST PATH: PATCH /timeperiods/<name>/config
# update timeperiods configuration partially

##########################################################
# REST PATH: DELETE /timeperiods/<name>/config
# deletes given timeperiod from configuration

##########################################################
# REST PATH: GET /commands/<name>/config
# returns configuration for given command
# you will find available attributes here: http://www.naemon.org/documentation/usersguide/objectdefinitions.html#command

##########################################################
# REST PATH: POST /commands/<name>/config
# replace command configuration completely, use PATCH to only update specific attributes

##########################################################
# REST PATH: PATCH /commands/<name>/config
# update command configuration partially

##########################################################
# REST PATH: DELETE /commands/<name>/config
# deletes given command from configuration
Thruk::Controller::rest_v1::register_rest_path_v1(['GET','DELETE','PATCH','POST'], qr%^/(host|hostgroup|servicegroup|timeperiod|contact|contactgroup|command|)s?/([^/]+)/config?$%mx, \&_rest_get_config, ["admin"]);
sub _rest_get_config {
    my($c, undef, $type, $name, $name2) = @_;
    my $live = [];
    my $method = $c->req->method();
    if($type eq 'host') {
        $live = $c->{'db'}->get_hosts(filter => [ name => $name ], columns => [qw/name/]);
    } elsif($type eq 'service') {
        $live = $c->{'db'}->get_services(filter => [ host_name => $name, description => $name2 ], columns => [qw/host_name description/]);
    } elsif($type eq 'hostgroup') {
        $live = $c->{'db'}->get_hostgroups(filter => [ name => $name ], columns => [qw/name/]);
    } elsif($type eq 'servicegroup') {
        $live = $c->{'db'}->get_servicegroups(filter => [ name => $name ], columns => [qw/name/]);
    } elsif($type eq 'contact') {
        $live = $c->{'db'}->get_contacts(filter => [ name => $name ], columns => [qw/name/]);
    } elsif($type eq 'contactgroups') {
        $live = $c->{'db'}->get_contactgroups(filter => [ name => $name ], columns => [qw/name/]);
    } elsif($type eq 'timeperiod') {
        $live = $c->{'db'}->get_timeperiods(filter => [ name => $name ], columns => [qw/name/]);
    }
    my $data    = [];
    my $changed = 0;
    for my $l (@{$live}) {
        my $peer_key = $c->stash->{'param_backend'} = $l->{'peer_key'};
        _set_object_model($c, $peer_key) || next;
        my $objs;
        if($type eq 'service') {
            $objs = $c->{'obj_db'}->get_services_by_name($name, $name2);
        } else {
            $objs = $c->{'obj_db'}->get_objects_by_name($type, $name, 0);
        }
        next unless $objs;
        my $obj_model_changed = 0;
        for my $o (@{$objs}) {
            if($method eq 'DELETE') {
                next if $o->{'file'}->readonly();
                $c->{'obj_db'}->delete_object($o);
                $obj_model_changed = 1;
                $changed++;
                next;
            }
            if($method eq 'PATCH') {
                $obj_model_changed = 1;
                for my $key (sort keys %{$c->req->parameters}) {
                    if(!defined $c->req->parameters->{$key} || $c->req->parameters->{$key} eq '') {
                        delete $o->{'conf'}->{$key};
                    } else {
                        $o->{'conf'}->{$key} = $c->req->parameters->{$key};
                    }
                }
                $c->{'obj_db'}->update_object($o, $o->{'conf'}, join("\n", @{$o->{'comments'}}));
                $changed++;
                next;
            }
            if($method eq 'POST') {
                if(scalar keys %{$c->req->parameters} == 0) {
                    return({
                        'message'     => 'use DELETE to remove objects completely',
                        'description' => 'using POST without parameters would remove the object, use the DELETE method instead.',
                        'code'        => 400,
                        'failed'      => Cpanel::JSON::XS::true,
                    });
                }
                $obj_model_changed = 1;
                my $conf = {};
                for my $key (sort keys %{$c->req->parameters}) {
                    if(defined $c->req->parameters->{$key}) {
                        $conf->{$key} = $c->req->parameters->{$key};
                    }
                }
                $c->{'obj_db'}->update_object($o, $conf, join("\n", @{$o->{'comments'}}));
                $changed++;
                next;
            }
            my $conf = dclone($o->{'conf'});
            $conf->{'_FILE'}     = $o->{'file'}->{'path'}.':'.$o->{'line'};
            $conf->{'_READONLY'} = 1 if $o->{'file'}->readonly();
            $conf->{'peer_key'} = $l->{'peer_key'};
            push @{$data}, $conf;
        }
        if($obj_model_changed) {
            Thruk::Utils::Conf::store_model_retention($c, $peer_key);
        }
    }
    if($method eq 'DELETE' || $method eq 'PATCH' || $method eq 'POST') {
        return({
            'message'     => sprintf('%s %d objects successfully.', $method eq 'DELETE' ? 'removed' : 'changed', $changed),
            'count'       => $changed,
        });
    }
    return($data);
}

##########################################################
# REST PATH: GET /services/<host_name>/<service>/config
# returns configuration for given service
# you will find available attributes here: http://www.naemon.org/documentation/usersguide/objectdefinitions.html#service

##########################################################
# REST PATH: POST /services/<host_name>/<service>/config
# replace service configuration completely, use PATCH to only update specific attributes

##########################################################
# REST PATH: PATCH /services/<host_name>/<service>/config
# update service configuration partially

##########################################################
# REST PATH: DELETE /services/<host_name>/<service>/config
# deletes given service from configuration
Thruk::Controller::rest_v1::register_rest_path_v1(['GET','DELETE','PATCH', 'POST'], qr%^/(service)s?/([^/]+)/([^/]+)/config?$%mx, \&_rest_get_config, ["admin"]);

##########################################################
# REST PATH: GET /config/diff
# returns diff between filesystem and stashed config changes
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/config/diff$%mx, \&_rest_get_config_diff, ["admin"]);
sub _rest_get_config_diff {
    my($c) = @_;
    my $diff = [];
    my($backends) = $c->{'db'}->select_backends("get_");
    for my $peer_key (@{$backends}) {
        _set_object_model($c, $peer_key) || next;
        my $changed_files = $c->{'obj_db'}->get_changed_files();
        for my $file (@{$changed_files}) {
            push @{$diff}, {
                'peer_key' => $peer_key,
                'output'   => $file->diff(),
                'file'     => $file->{'path'},
            };
        }
    }
    return($diff);
}

##########################################################
# REST PATH: POST /config/check
# returns result from config check
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/config/check$%mx, \&_rest_get_config_check, ["admin"]);
sub _rest_get_config_check {
    my($c) = @_;
    local $c->config->{'no_external_job_forks'} = undef;
    my($backends) = $c->{'db'}->select_backends("get_");
    my $jobs = [];
    # start jobs in background
    for my $peer_key (@{$backends}) {
        _set_object_model($c, $peer_key) || next;
        my $job = Thruk::Utils::External::perl($c, {
                                                    expr       => 'Thruk::Controller::conf::_config_check($c)',
                                                    message    => 'please stand by while configuration is beeing checked...',
                                                    background => 1,
        });
        push @{$jobs}, [$job, $peer_key];
    }
    # wait for all jobs to complete
    my $check = [];
    for my $data (@{$jobs}) {
        my($job, $peer_key) = @{$data};
        my($is_running) = Thruk::Utils::External::get_status($c, $job);
        while($is_running) {
            ($is_running) = Thruk::Utils::External::get_status($c, $job);
            sleep(0.2);
        }
        my($out,$err,$time,$dir,$stash,$rc) = Thruk::Utils::External::get_result($c, $job);
        push @{$check}, {
            'peer_key' => $peer_key,
            'output'   => $stash->{'original_output'},
            'failed'   => $rc ? Cpanel::JSON::XS::false : Cpanel::JSON::XS::true,
        };
    }
    return($check);
}

##########################################################
# REST PATH: POST /config/save
# saves stashed config changes to disk
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/config/save$%mx, \&_rest_get_config_save, ["admin"]);
sub _rest_get_config_save {
    my($c) = @_;
    my($backends) = $c->{'db'}->select_backends("get_");
    my $saved = 0;
    for my $peer_key (@{$backends}) {
        _set_object_model($c, $peer_key) || next;
        if($c->{'obj_db'}->commit($c)) {
            $saved++;
        }
        Thruk::Utils::Conf::store_model_retention($c, $peer_key);
    }
    return({
        'message'     => sprintf('successfully saved changes for %d site%s.', $saved, $saved != 1 ? 's' : '' ),
        'count'       => $saved,
    });
}

##########################################################
# REST PATH: POST /config/reload
# reloads configuration with the configured reload command
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/config/reload$%mx, \&_rest_get_config_reload, ["admin"]);
sub _rest_get_config_reload {
    my($c) = @_;
    local $c->config->{'no_external_job_forks'} = undef;
    my($backends) = $c->{'db'}->select_backends("get_");
    my $jobs = [];
    # start jobs in background
    for my $peer_key (@{$backends}) {
        _set_object_model($c, $peer_key) || next;
        my $job = Thruk::Utils::External::perl($c, {
                                                    expr       => 'Thruk::Controller::conf::_config_reload($c)',
                                                    message    => 'please stand by while configuration is beeing reloaded...',
                                                    background => 1,
        });
        push @{$jobs}, [$job, $peer_key];
    }
    # wait for all jobs to complete
    my $reloads = [];
    for my $data (@{$jobs}) {
        my($job, $peer_key) = @{$data};
        my($is_running) = Thruk::Utils::External::get_status($c, $job);
        while($is_running) {
            ($is_running) = Thruk::Utils::External::get_status($c, $job);
            sleep(0.2);
        }
        my($out,$err,$time,$dir,$stash,$rc) = Thruk::Utils::External::get_result($c, $job);
        push @{$reloads}, {
            'peer_key' => $peer_key,
            'output'   => $stash->{'original_output'},
            'failed'   => $rc ? Cpanel::JSON::XS::false : Cpanel::JSON::XS::true,
        };
    }
    return($reloads);
}

##########################################################
# REST PATH: POST /config/revert
# reverts stashed configuration changes
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/config/revert$%mx, \&_rest_get_config_revert, ["admin"]);

##########################################################
# REST PATH: POST /config/discard
# reverts stashed configuration changes.
# alias for /config/revert
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/config/discard$%mx, \&_rest_get_config_revert, ["admin"]);
sub _rest_get_config_revert {
    my($c) = @_;
    my($backends) = $c->{'db'}->select_backends("get_");
    my $reverted = 0;
    for my $peer_key (@{$backends}) {
        _set_object_model($c, $peer_key) || next;
        $c->{'obj_db'}->discard_changes();
        $reverted++;
        Thruk::Utils::Conf::store_model_retention($c, $peer_key);
    }
    return({
        'message'     => sprintf('successfully reverted stashed changes for %d site%s.', $reverted, $reverted != 1 ? 's' : '' ),
        'count'       => $reverted,
    });
}

##########################################################
sub _set_object_model {
    my($c, $peer_key) = @_;
    local $c->config->{'no_external_job_forks'} = 1;
    $c->stash->{'param_backend'} = $peer_key;
    Thruk::Utils::Conf::set_object_model($c);
    delete $c->req->parameters->{'refreshdata'};
    return 1 if $c->{'obj_db'};
    return;
}
##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
