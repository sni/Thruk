package Thruk::Controller::Rest::V1::config;

use strict;
use warnings;
use Storable qw/dclone/;
use Time::HiRes qw/sleep/;
use Cpanel::JSON::XS qw//;
use File::Slurp qw/read_file/;

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
# REST PATH: GET /config/files
# returns all config files
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/config/files?$%mx, \&_rest_get_config_files, ["admin"]);
sub _rest_get_config_files {
    my($c) = @_;
    my $method = $c->req->method();
    my($backends) = $c->{'db'}->select_backends("get_");
    my $data = [];
    my $content_required = Thruk::Controller::rest_v1::column_required($c, 'content');
    for my $peer_key (@{$backends}) {
        _set_object_model($c, $peer_key) || next;
        for my $file (@{$c->{'obj_db'}->{'files'}}) {
            my $f = {
                peer_key => $peer_key,
                path     => $file->{'display'},
                md5      => $file->{'md5'},
                mtime    => $file->{'mtime'},
                readonly => $file->readonly(),
            };
            $f->{'content'} = scalar read_file($file->{'path'}) if $content_required;
            push @{$data}, $f;
        }
    }
    return($data);
}

##########################################################
# REST PATH: GET /hosts/<name>/config
# Returns configuration for given host.
# You will find available attributes here: http://www.naemon.org/documentation/usersguide/objectdefinitions.html#host

##########################################################
# REST PATH: POST /hosts/<name>/config
# Replace host configuration completely, use PATCH to only update specific attributes.

##########################################################
# REST PATH: PATCH /hosts/<name>/config
# Update host configuration partially.

##########################################################
# REST PATH: DELETE /hosts/<name>/config
# Deletes given host from configuration.

##########################################################
# REST PATH: GET /hostgroups/<name>/config
# Returns configuration for given hostgroup.
# You will find available attributes here: http://www.naemon.org/documentation/usersguide/objectdefinitions.html#hostgroup

##########################################################
# REST PATH: POST /hostgroups/<name>/config
# Replace hostgroups configuration completely, use PATCH to only update specific attributes.

##########################################################
# REST PATH: PATCH /hostgroups/<name>/config
# Update hostgroup configuration partially.

##########################################################
# REST PATH: DELETE /hostgroups/<name>/config
# Deletes given hostgroup from configuration.

##########################################################
# REST PATH: GET /servicegroups/<name>/config
# Returns configuration for given servicegroup.
# You will find available attributes here: http://www.naemon.org/documentation/usersguide/objectdefinitions.html#servicegroup

##########################################################
# REST PATH: POST /servicegroups/<name>/config
# Replace servicegroup configuration completely, use PATCH to only update specific attributes.

##########################################################
# REST PATH: PATCH /servicegroups/<name>/config
# Update servicegroup configuration partially.

##########################################################
# REST PATH: DELETE /servicegroups/<name>/config
# Deletes given servicegroup from configuration.

##########################################################
# REST PATH: GET /contacts/<name>/config
# Returns configuration for given contact.
# You will find available attributes here: http://www.naemon.org/documentation/usersguide/objectdefinitions.html#contact

##########################################################
# REST PATH: POST /contacts/<name>/config
# Replace contact configuration completely, use PATCH to only update specific attributes.

##########################################################
# REST PATH: PATCH /contacts/<name>/config
# Update contact configuration partially.

##########################################################
# REST PATH: DELETE /contact/<name>/config
# Deletes given contact from configuration.

##########################################################
# REST PATH: GET /contactgroups/<name>/config
# Returns configuration for given contactgroup.
# You will find available attributes here: http://www.naemon.org/documentation/usersguide/objectdefinitions.html#contactgroup

##########################################################
# REST PATH: POST /contactgroups/<name>/config
# Replace contactgroup configuration completely, use PATCH to only update specific attributes.

##########################################################
# REST PATH: PATCH /contactgroups/<name>/config
# Update contactgroup configuration partially.

##########################################################
# REST PATH: DELETE /contactgroups/<name>/config
# Deletes given contactgroup from configuration.

##########################################################
# REST PATH: GET /timeperiods/<name>/config
# Returns configuration for given timeperiod.
# You will find available attributes here: http://www.naemon.org/documentation/usersguide/objectdefinitions.html#timeperiod

##########################################################
# REST PATH: POST /timeperiods/<name>/config
# Replace timeperiod configuration completely, use PATCH to only update specific attributes.

##########################################################
# REST PATH: PATCH /timeperiods/<name>/config
# Update timeperiods configuration partially.

##########################################################
# REST PATH: DELETE /timeperiods/<name>/config
# Deletes given timeperiod from configuration.

##########################################################
# REST PATH: GET /commands/<name>/config
# Returns configuration for given command.
# You will find available attributes here: http://www.naemon.org/documentation/usersguide/objectdefinitions.html#command

##########################################################
# REST PATH: POST /commands/<name>/config
# Replace command configuration completely, use PATCH to only update specific attributes.

##########################################################
# REST PATH: PATCH /commands/<name>/config
# Update command configuration partially.

##########################################################
# REST PATH: DELETE /commands/<name>/config
# Deletes given command from configuration.
Thruk::Controller::rest_v1::register_rest_path_v1(['GET','DELETE','PATCH','POST', 'PUT'], qr%^/(host|hostgroup|servicegroup|timeperiod|contact|contactgroup|command|)s?/([^/]+)/config?$%mx, \&_rest_get_config, ["admin"]);
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
            if(_update_object($c, $method, $o)) {
                $changed++;
                $obj_model_changed = 1;
                next;
            }
            push @{$data}, _add_object($o, $peer_key);
        }
        if($obj_model_changed) {
            Thruk::Utils::Conf::store_model_retention($c, $peer_key);
        }
    }
    if($method eq 'DELETE' || $method eq 'PATCH' || $method eq 'POST' || $method eq 'PUT') {
        return({
            'message'     => sprintf('%s %d objects successfully.', $method eq 'DELETE' ? 'removed' : 'changed', $changed),
            'count'       => $changed,
        });
    }

    $c->req->parameters->{'sort'} = '.TYPE,.ID' unless $c->req->parameters->{'sort'};
    return($data);
}

##########################################################
# REST PATH: GET /services/<host_name>/<service>/config
# Returns configuration for given service.
# You will find available attributes here: http://www.naemon.org/documentation/usersguide/objectdefinitions.html#service

##########################################################
# REST PATH: POST /services/<host_name>/<service>/config
# Replace service configuration completely, use PATCH to only update specific attributes.

##########################################################
# REST PATH: PATCH /services/<host_name>/<service>/config
# Update service configuration partially.

##########################################################
# REST PATH: DELETE /services/<host_name>/<service>/config
# Deletes given service from configuration.
Thruk::Controller::rest_v1::register_rest_path_v1(['GET','DELETE','PATCH', 'POST', 'PUT'], qr%^/(service)s?/([^/]+)/([^/]+)/config?$%mx, \&_rest_get_config, ["admin"]);

##########################################################
# REST PATH: GET /config/objects
# Returns list of all objects.
Thruk::Controller::rest_v1::register_rest_path_v1('GET', qr%^/config/objects?$%mx, \&_rest_get_config_objects, ["admin"]);
sub _rest_get_config_objects {
    my($c) = @_;
    my($backends) = $c->{'db'}->select_backends("get_");
    my $data = [];
    for my $peer_key (@{$backends}) {
        _set_object_model($c, $peer_key) || next;
        my $objs = $c->{'obj_db'}->get_objects();
        for my $o (@{$objs}) {
            push @{$data}, _add_object($o, $peer_key);
        }
    }
    $c->req->parameters->{'sort'} = '.TYPE,.ID' unless $c->req->parameters->{'sort'};
    return($data);
}

##########################################################
# REST PATH: POST /config/objects
# Create new object. Besides the actual object config, requires
# 2 special paramters :FILE and :TYPE.
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/config/objects?$%mx, \&_rest_get_config_objects_new, ["admin"]);
sub _rest_get_config_objects_new {
    my($c) = @_;
    my($backends) = $c->{'db'}->select_backends("get_");
    my $type      = delete $c->req->parameters->{':TYPE'};
    my $new_file  = delete $c->req->parameters->{':FILE'};
    my $created   = 0;
    if(!$type) {
        return({
            'message'     => ':TYPE is a required parameter.',
            'code'        => 400,
        });
    }
    if(!$new_file) {
        return({
            'message'     => ':FILE is a required parameter.',
            'code'        => 400,
        });
    }
    my $objs = [];
    for my $peer_key (@{$backends}) {
        _set_object_model($c, $peer_key) || next;
        my $obj = Monitoring::Config::Object->new( type     => $type,
                                                   coretype => $c->{'obj_db'}->{'coretype'},
                                              );
        my $file = Thruk::Controller::conf::get_context_file($c, $obj, $new_file);
        next unless $file;
        $obj->set_file($file);
        $obj->set_uniq_id($c->{'obj_db'});
        if($c->{'obj_db'}->update_object($obj, \%{$c->req->parameters}, "", 1)) {
            $created++;
            Thruk::Utils::Conf::store_model_retention($c, $peer_key);
            push @{$objs}, _add_object($obj, $peer_key);
        }
    }
    return({
        'message' => sprintf('created %d objects successfully.', $created),
        'count'   => $created,
        'objects' => $objs,
    });
}

##########################################################
# REST PATH: PATCH /config/objects/<id>
# Update object configuration partially.
# REST PATH: POST /config/objects/<id>
# Replace object configuration completely.
# REST PATH: DELETE /config/objects/<id>
# Remove given object from configuration.
Thruk::Controller::rest_v1::register_rest_path_v1(['DELETE', 'POST', 'PUT', 'PATCH'], qr%^/config/objects?/([^/]+)$%mx, \&_rest_get_config_objects_update, ["admin"]);
sub _rest_get_config_objects_update {
    my($c, undef, $id) = @_;
    my($backends) = $c->{'db'}->select_backends("get_");
    my $changed = 0;
    my $method = $c->req->method();
    for my $peer_key (@{$backends}) {
        _set_object_model($c, $peer_key) || next;
        my $obj = $c->{'obj_db'}->get_object_by_id($id);
        next unless $obj;
        if(_update_object($c, $method, $obj)) {
            $changed++;
            Thruk::Utils::Conf::store_model_retention($c, $peer_key);
        }
    }
    return({
        'message'     => sprintf('%s %d objects successfully.', $method eq 'DELETE' ? 'removed' : 'changed', $changed),
        'count'       => $changed,
    });
}

##########################################################
# REST PATH: GET /config/diff
# Returns differences between filesystem and stashed config changes.
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
# Returns result from config check.
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
# Saves stashed configuration changes to disk.
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
# Reloads configuration with the configured reload command.
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
# Reverts stashed configuration changes.
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/config/revert$%mx, \&_rest_get_config_revert, ["admin"]);

##########################################################
# REST PATH: POST /config/discard
# Reverts stashed configuration changes.
# Alias for /config/revert
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
sub _add_object {
    my($o, $peer_key) = @_;
    my $conf = dclone($o->{'conf'});
    $conf->{':ID'}       = $o->{'id'};
    $conf->{':TYPE'}     = $o->{'type'};
    $conf->{':FILE'}     = $o->{'file'}->{'path'}.':'.$o->{'line'};
    $conf->{':READONLY'} = $o->{'file'}->readonly() ? 1 : 0;
    $conf->{':PEER_KEY'} = $peer_key;
    return($conf);
}

##########################################################
sub _update_object {
    my($c, $method, $o) = @_;
    my $changed = 0;
    if($method eq 'DELETE') {
        next if $o->{'file'}->readonly();
        $c->{'obj_db'}->delete_object($o);
        $changed++;
    }
    elsif($method eq 'PATCH') {
        for my $key (sort keys %{$c->req->parameters}) {
            if(!defined $c->req->parameters->{$key} || $c->req->parameters->{$key} eq '') {
                delete $o->{'conf'}->{$key};
            } else {
                $o->{'conf'}->{$key} = $c->req->parameters->{$key};
            }
        }
        $c->{'obj_db'}->update_object($o, $o->{'conf'}, join("\n", @{$o->{'comments'}}));
        $changed++;
    }
    elsif($method eq 'POST') {
        if(scalar keys %{$c->req->parameters} == 0) {
            return({
                'message'     => 'use DELETE to remove objects completely',
                'description' => 'using POST without parameters would remove the object, use the DELETE method instead.',
                'code'        => 400,
            });
        }
        my $conf = {};
        for my $key (sort keys %{$c->req->parameters}) {
            if(defined $c->req->parameters->{$key}) {
                $conf->{$key} = $c->req->parameters->{$key};
            }
        }
        $c->{'obj_db'}->update_object($o, $conf, join("\n", @{$o->{'comments'}}));
        $changed++;
    }
    return($changed);
}
##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
