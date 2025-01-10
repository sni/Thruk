package Thruk::Utils::Agents;

use warnings;
use strict;
use Carp qw/confess/;
use Cpanel::JSON::XS qw/decode_json/;

use Monitoring::Config::Object ();
use Thruk::Controller::conf ();
use Thruk::Utils ();
use Thruk::Utils::Conf ();
use Thruk::Utils::External ();
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::Utils::Agents - Utils for agents

=head1 METHODS

=cut

##########################################################

=head2 get_agent_checks_for_host

    get_agent_checks_for_host($c, $backend, $hostname, $hostobj, [$agenttype], [$fresh], [$section])

returns list of checks for this host grouped by type (new, exists, obsolete, disabled) along with the total number of checks.

=cut
sub get_agent_checks_for_host {
    my($c, $backend, $hostname, $hostobj, $agenttype, $fresh, $section, $mode, $options, $inventory_file) = @_;
    $section = $section // $hostobj->{'conf'}->{'_AGENT_SECTION'};

    # extract checks and group by type
    my $flat   = get_services_checks($c, $backend, $hostname, $hostobj, $agenttype, undef, $fresh, $section, $mode, $options, $inventory_file);
    my $checks = Thruk::Base::array_group_by($flat, "exists");
    for my $key (qw/new exists obsolete disabled/) {
        $checks->{$key} = [] unless defined $checks->{$key};

        # sort by name
        $checks->{$key} = [(sort { $a->{'name'} cmp $b->{'name'} } @{$checks->{$key}})];
    }

    return($checks, scalar @{$flat});
}

##########################################################

=head2 update_inventory

    update_inventory($c, $hostname, [$hostobj], [$opt])

returns $data and $err

=cut
sub update_inventory {
    my($c, $hostname, $hostobj, $opt) = @_;

    if(!$hostobj) {
        my $objects = $c->{'obj_db'}->get_objects_by_name('host', $hostname);
        if(!$objects || scalar @{$objects} == 0) {
            $hostobj = $objects->[0];
        }
    }
    confess("hostobj required") unless $hostobj;

    $hostname  = $hostobj->{'conf'}->{'name'} unless $hostname;

    if(Thruk::Base::check_for_nasty_filename($hostname)) {
        die("this hostname contains nasty characters and is not allowed");
    }

    my $address   = $hostobj->{'conf'}->{'address'};
    my $type      = $hostobj->{'conf'}->{'_AGENT'}          // default_agent_type($c);
    my $password  = $opt->{'password'} || $hostobj->{'conf'}->{'_AGENT_PASSWORD'} || $c->config->{'Thruk::Agents'}->{lc($type)}->{'default_password'};
    my $port      = $opt->{'port'}     || $hostobj->{'conf'}->{'_AGENT_PORT'}     // default_port($type);
    my $mode      = $opt->{'mode'}     || $hostobj->{'conf'}->{'_AGENT_MODE'}     // 'https';

    my $class = get_agent_class($type);
    my $agent = $class->new({});
    my $data;
    eval {
        $data = $agent->get_inventory($c, $address, $hostname, $password, $port, $mode);
    };
    my $err = $@;
    if($err) {
        return(undef, $err);
    } else {
        if($data) {
            # save scan results
            Thruk::Utils::IO::mkdir_r($c->config->{'var_path'}.'/agents/hosts');
            Thruk::Utils::IO::json_lock_store($c->config->{'var_path'}.'/agents/hosts/'.$hostname.'.json', $data, { pretty => 1 });
        }
    }

    return($data, undef);
}

##########################################################

=head2 get_services_checks

    get_services_checks($c, $backend, $hostname, $hostobj, $agenttype, $password, $fresh, $section, $mode, $options, $inventory_file, $remove_obsolete)

returns list of checks as flat list.

=cut
sub get_services_checks {
    my($c, $backend, $hostname, $hostobj, $agenttype, $password, $fresh, $section, $mode, $options, $inventory_file) = @_;
    my $checks   = [];
    return($checks) unless $hostname;

    # http backends must check inventory on remote host
    # otherwise the local inventory check would result in different checks
    set_object_model($c, $backend) unless $c->{'obj_db'};
    if($c->{'obj_db'}->is_remote()) {
        my $peer = $c->db->get_peer_by_key($backend);
        confess("no peer found by name: ".$backend) unless $peer;
        confess("no remotekey") unless $peer->remotekey();
        confess("need agenttype") unless $agenttype;
        my @res = $c->db->rpc($backend, __PACKAGE__."::get_services_checks", [$c, $peer->remotekey(), $hostname, undef, $agenttype, $password, $fresh, $section, $mode, $options], 1);
        return($res[0]);
    }

    if(!$hostobj) {
        my $objects = $c->{'obj_db'}->get_objects_by_name('host', $hostname);
        if($objects && scalar @{$objects} > 0) {
            $hostobj = $objects->[0];
        } else {
            if(!$agenttype) {
                confess("need either hostobj or agenttype");
            }
        }
    }

    my $type = $agenttype // $hostobj->{'conf'}->{'_AGENT'};
    $password = $password || $c->config->{'Thruk::Agents'}->{lc($type)}->{'default_password'};

    my $agent = build_agent($agenttype // $hostobj);
    $checks = $agent->get_services_checks($c, $hostname, $hostobj, $password, $fresh, $section, $mode, $options, $inventory_file);
    _set_checks_category($c, $hostname, $hostobj, $checks, $type, $fresh);

    return($checks);
}

##########################################################

=head2 get_host_agent_services

    get_host_agent_services($c, $hostobj)

returns list of services for given host object.

=cut
sub get_host_agent_services {
    my($c, $hostobj) = @_;
    die("uninitialized objects database") unless $c->{'obj_db'};
    my $objects = $c->{'obj_db'}->get_services_for_host($hostobj);
    return({}) unless $objects && $objects->{'host'};
    return($objects->{'host'});
}

##########################################################

=head2 get_host_agent_services_by_id

    get_host_agent_services_by_id($services)

transforms list of services into hash by check id

=cut
sub get_host_agent_services_by_id {
    my($services) = @_;
    my $by_id = {};
    for my $svc (values %{$services}) {
        my $id = $svc->{'conf'}->{'_AGENT_AUTO_CHECK'};
        $by_id->{$id} = $svc if $id;
    }
    return($by_id);
}

##########################################################

=head2 find_agent_module_names

    find_agent_module_names()

returns available agent class names

=cut
sub find_agent_module_names {
    my $modules = _find_agent_modules();
    my $list = [];
    for my $mod (@{$modules}) {
        my $name = $mod;
        $name =~ s/Thruk::Agents:://gmx;
        push @{$list}, $name;
    }
    return($list);
}

##########################################################

=head2 get_agent_class

    get_agent_class($type)

returns agent class for given type

=cut
sub get_agent_class {
    my($type) = @_;
    confess("no type") unless $type;
    my $modules  = _find_agent_modules();
    my @provider = grep { $_ =~ m/::$type$/mxi } @{$modules};
    if(scalar @provider == 0) {
        die('unknown type \''.$type.'\' in agent configuration, choose from: '.join(', ', @{find_agent_module_names()}));
    }
    return($provider[0]);
}

##########################################################

=head2 build_agent

    build_agent($hostdata | $hostobj)

returns agent based on host (livestatus) data

=cut
sub build_agent {
    my($host) = @_;
    my $c = $Thruk::Globals::c;

    my($agenttype, $hostdata, $section, $port, $mode);
    if(!ref $host) {
        $agenttype = $host;
        $hostdata  = {};
    }
    elsif($host->{'conf'}) {
        # host config object
        $agenttype = $host->{'conf'}->{'_AGENT'};
        $section   = $host->{'conf'}->{'_AGENT_SECTION'};
        $port      = $host->{'conf'}->{'_AGENT_PORT'};
        $mode      = $host->{'conf'}->{'_AGENT_MODE'};
        $hostdata  = $host->{'conf'};
    } else {
        my $vars  = Thruk::Utils::get_custom_vars($c, $host);
        $agenttype = $vars->{'AGENT'};
        $section   = $vars->{'AGENT_SECTION'};
        $port      = $vars->{'AGENT_PORT'};
        $mode      = $vars->{'AGENT_MODE'};
        $hostdata  = $host;
    }
    my $class = get_agent_class($agenttype);
    my $agent = $class->new($hostdata);

    my $settings = $agent->settings();
    # merge some attributes to top level
    for my $key (qw/type/) {
        $agent->{$key} = $settings->{$key} // '';
    }
    $agent->{'section'} = $section || $settings->{'section'} // '';
    $agent->{'port'}    = $port    || $settings->{'default_port'} // '';
    $agent->{'mode'}    = $mode    || 'https';

    if($c->stash->{'theme'} =~ m/dark/mxi) {
        $agent->{'icon'} = $settings->{'icon_dark'};
    }
    $agent->{'icon'} = $agent->{'icon'} // $settings->{'icon'} // '';

    return($agent);
}

##########################################################

=head2 check_for_check_commands

    check_for_check_commands($c, [$extra_cmd], [$extra_objects])

create agent check commands if missing

=cut
sub check_for_check_commands {
    my($c, $agent_cmds, $extra_objects) = @_;

    $agent_cmds = [] unless defined $agent_cmds;
    push @{$agent_cmds}, {
        command_name => 'check_thruk_agent',
        command_line => '$ARG1$',
    };

    my $changed = 0;
    for my $cmd (@{$agent_cmds}) {
        $changed++ unless _ensure_command_exists($c, 'command', $cmd->{'command_name'}, $cmd, 'agents/commands.cfg');
    }

    if($extra_objects) {
        for my $ex (@{$extra_objects}) {
            $changed++ unless _ensure_command_exists($c, $ex->{'type'}, $ex->{'name'}, $ex->{'conf'}, $ex->{'file'});
        }
    }

    if($changed) {
        if($c->{'obj_db'}->commit($c)) {
            $c->stash->{'obj_model_changed'} = 1;
        }
        Thruk::Utils::Conf::store_model_retention($c, $c->stash->{'param_backend'});
    }

    return;
}

##########################################################

=head2 set_object_model

    set_object_model($c, $peer_key, [$retries])

returns 1 on success, 0 on redirects. Dies otherwise.

=cut
sub set_object_model {
    my($c, $peer_key, $retries) = @_;
    $retries = 0 unless defined $retries;

    confess("no peer key set") unless $peer_key;

    $c->stash->{'param_backend'} = $peer_key;
    delete $c->{'obj_db'};
    my $rc = Thruk::Utils::Conf::set_object_model($c, undef, $peer_key);
    if($rc == 0 && $c->stash->{set_object_model_err}) {
        if($retries < 3 && $c->stash->{"model_job"}) {
            my $is_running = Thruk::Utils::External::wait_for_job($c, $c->stash->{"model_job"}, 30);
            if(!$is_running) {
                return(set_object_model($c, $peer_key, $retries+1));
            }
        }
        die(sprintf("backend %s returned error: %s", $peer_key, $c->stash->{set_object_model_err}));
    }
    delete $c->req->parameters->{'refreshdata'};
    if(!$c->{'obj_db'}) {
        die(sprintf("backend %s has no config tool settings", $peer_key));
    }
    # make sure we did not fallback on some default backend
    if($c->stash->{'param_backend'} ne $peer_key) {
        die(sprintf("backend %s has no config tool settings", $peer_key));
    }
    if($c->{'obj_db'}->{'errors'} && scalar @{$c->{'obj_db'}->{'errors'}} > 0) {
        _error(join("\n", @{$c->{'obj_db'}->{'errors'}}));
        die(sprintf("failed to initialize objects of peer %s", $peer_key));
    }
    return 1;
}

##########################################################
#sets exists attribute for checks, can be:
# - exists: already exists as services
# - new: does not yet exist as services
# - obsolete: exists as services but not in inventory anymore
# - disabled: exists in inventory but is disabled by user config
sub _set_checks_category {
    my($c, $hostname, $hostobj, $checks, $agenttype, $fresh) = @_;

    my $services = $hostobj ? get_host_agent_services($c, $hostobj) : {};
    my $services_by_id = get_host_agent_services_by_id($services);
    my $settings = $hostobj->{'conf'}->{'_AGENT_CONFIG'} ? decode_json($hostobj->{'conf'}->{'_AGENT_CONFIG'}) : {};

    my $excludes = $c->config->{'Thruk::Agents'}->{lc($agenttype)}->{'exclude'};

    my $existing = {};
    for my $chk (@{$checks}) {
        next if $chk->{'id'} eq '_host';
        my $name = $chk->{'name'};
        $existing->{$chk->{'id'}} = 1;
        my $svc = $services_by_id->{$chk->{'id'}} // $services->{$name};
        if($svc && $svc->{'conf'}->{'_AGENT_AUTO_CHECK'}) {
            $chk->{'exists'} = 'exists';
            $chk->{'_svc'}   = $svc;
            $chk->{'args'}   = $chk->{'args'} || $svc->{'conf'}->{'_AGENT_ARGS'} || '';
            if($chk->{'disabled'}) {
                $chk->{'exists'} = 'obsolete';
            }
        } else {
            # disabled manually from previous inventory run
            if($settings && $settings->{'disabled'} && Thruk::Base::array_contains($chk->{'id'}, $settings->{'disabled'})) {
                $chk->{'exists'} = 'disabled';
            }
            elsif($chk->{'disabled'}) {
                # disabled by 'disable' configuration
                $chk->{'exists'} = 'disabled';
            }
            elsif(_is_excluded($hostname, $chk, $excludes)) {
                # disabled by 'exclude' configuration
                $chk->{'exists'} = 'disabled';
            } else {
                $chk->{'exists'} = 'new';
            }
        }
    }

    for my $name (sort keys %{$services}) {
        my $svc = $services->{$name};
        my $id  = $svc->{'conf'}->{'_AGENT_AUTO_CHECK'};
        next unless $id;
        next if $existing->{$id};

        push @{$checks}, { 'id' => $id, 'name' => $name, exists => 'obsolete'};
    }

    return;
}

##########################################################

=head2 remove_host

    remove_host($c, $hostname, $backend)

remove hosts, returns 1 if successful

=cut
sub remove_host {
    my($c, $hostname, $backend) = @_;

    return unless Thruk::Utils::Agents::set_object_model($c, $backend);

    my $objects = $c->{'obj_db'}->get_objects_by_name('host', $hostname);
    for my $hostobj (@{$objects}) {
        my $services = $c->{'obj_db'}->get_services_for_host($hostobj);
        my $remove_host = 1;
        if($services && $services->{'host'}) {
            my $removed = 0;
            for my $name (sort keys %{$services->{'host'}}) {
                my $svc = $services->{'host'}->{$name};
                next unless $svc->{'conf'}->{'_AGENT_AUTO_CHECK'};
                $c->{'obj_db'}->delete_object($svc);
                $removed++;
            }
            if($removed < scalar keys %{$services->{'host'}}) {
                $remove_host = 0;
            }
        }

        # only remove host if it has been created here
        if($remove_host) {
            if($hostobj->{'conf'}->{'_AGENT'}) {
                $c->{'obj_db'}->delete_object($hostobj);
            }
        } else {
            # remove agent related custom variables but keep host
            for my $key (sort keys %{$hostobj->{'conf'}}) {
                if($key =~ m/^_AGENT/mx) {
                    delete $hostobj->{'conf'}->{$key};
                }
            }
            $c->{'obj_db'}->update_object($hostobj, $hostobj->{'conf'}, "", 1);
        }

        # remove inventory files
        unlink($c->config->{'var_path'}.'/agents/hosts/'.$hostname.'.json');
    }

    if($c->{'obj_db'}->commit($c)) {
        $c->stash->{'obj_model_changed'} = 1;
    }
    Thruk::Utils::Conf::store_model_retention($c, $c->stash->{'param_backend'});

    return(1);
}

##########################################################

=head2 default_agent_type

    default_agent_type()

returns default agent type

=cut
sub default_agent_type {
    my($c) = @_;
    my $types = find_agent_module_names();
    return(lc($types->[0]));
}

##########################################################

=head2 default_port

    default_port()

returns default port for given agent type

=cut
sub default_port {
    my($type) = @_;
    my $agent = get_agent_class($type);
    my $settings = $agent->settings();
    return($settings->{'default_port'});
}

##########################################################

=head2 to_id

    to_id($name)

returns name with special characters replaced

=cut
sub to_id {
    my($name) = @_;
    $name =~ s/[^a-zA-Z0-9:._\-\/]/_/gmx;
    return($name);
}

##########################################################

=head2 scan_agent

    scan_agent($c, $params)

returns error if updates fails or undef on success

=cut
sub scan_agent {
    my($c, $params) = @_;

    my $agenttype = $params->{'type'};
    my $hostname  = $params->{'hostname'};
    my $address   = $params->{'ip'};
    my $password  = $params->{'password'};
    my $mode      = $params->{'mode'};
    my $backend   = $params->{'backend'};
    my $port      = $params->{'port'} || default_port($agenttype);

    return("failed to initialize object model") unless set_object_model($c, $backend);

    # http backends must run inventory on remote host
    # otherwise the local inventory check would result in different checks
    if($c->{'obj_db'}->is_remote()) {
        my $peer = $c->db->get_peer_by_key($backend);
        confess("no peer found by name: ".$backend) unless $peer;
        confess("no remotekey") unless $peer->remotekey();
        $params->{'backend'} = $peer->remotekey();
        my @res = $c->db->rpc($backend, __PACKAGE__."::scan_agent", [$c, $params], 1);
        return($res[0]);
    }

    # use existing password
    if(!$password) {
        my $objects = $c->{'obj_db'}->get_objects_by_name('host', $hostname);
        if($objects && scalar @{$objects} > 0) {
            my $obj = $objects->[0]->{'conf'};
            $password = $obj->{'_AGENT_PASSWORD'};
        }
    }
    $password = $password || $c->config->{'Thruk::Agents'}->{lc($agenttype)}->{'default_password'};

    my $class = get_agent_class($agenttype);
    my $agent = $class->new({});
    my $data;
    eval {
        $data = $agent->get_inventory($c, $address, $hostname, $password, $port, $mode);
    };
    my $err = $@;
    if($err) {
        $err = Thruk::Base::trim_whitespace($err);
        if($err =~ m/\Qflag provided but not defined\E/mx) {
            $err = "please update check_nsc_web\n".$err;
        }
        _error($err);
        return($err);
    } else {
        # save scan results
        Thruk::Utils::IO::mkdir_r($c->config->{'var_path'}.'/agents/hosts');
        Thruk::Utils::IO::json_lock_store($c->config->{'var_path'}.'/agents/hosts/'.$hostname.'.json', $data, { pretty => 1 });
    }

    return;
}

##########################################################

=head2 check_wildcard_match

    check_wildcard_match($string, $config)

returns true if attribute matches given config

=cut
sub check_wildcard_match {
    my($str, $pattern) = @_;
    $pattern = Thruk::Base::list($pattern);
    return "ANY" if scalar @{$pattern} == 0;
    for my $raw (@{$pattern}) {
        my $p = $raw;
        $p =~ s/\.\*/*/gmx;
        $p =~ s/\*/.*/gmx;
        return "ANY" if $p eq 'ANY';
        return "ANY" if $p eq '.*';
        if(!defined $str) {
            _warn(Carp::longmess("undef wildcard match"));
            return(undef);
        }
        ## no critic
        return $p if $str =~ m/$p/i;
        ## use critic
    }
    return(undef);
}

##########################################################

=head2 check_disable

    check_disable($data, $disabled_config, $keys)

returns if checks disabled for given config

=cut
sub check_disable {
    my($data, $disabled_config, $keys) = @_;
    $keys = Thruk::Base::list($keys);
    for my $conf_key (@{$keys}) {
        my $conf = $disabled_config->{$conf_key} // next;
        for my $attr (sort keys %{$conf}) {
            my $val = $data->{$attr} // '';
            for my $pattern (@{Thruk::Base::list($conf->{$attr})}) {
                if(_check_pattern($val, $pattern)) {
                    return sprintf("disabled by '<disabled %s>' configuration:\nmatching filter '%s %s'\ncurrent value: '%s'",
                        $conf_key, $attr, $pattern, $val);
                }
            }
        }
    }
    return(0);
}

##########################################################

=head2 validate_params

    validate_params($hostname, $section)

returns undef or error message

=cut
sub validate_params {
    my($hostname, $section) = @_;
    if(Thruk::Base::check_for_nasty_filename($hostname)) {
        return("this hostname is not allowed");
    }

    if($hostname =~ m/^-/mx) {
        return("this hostname is not allowed");
    }

    if($section) {
        my @sections = split/\//mx, $section;
        for my $sect (@sections) {
            if(Thruk::Base::check_for_nasty_filename($sect)) {
                return("this section is not allowed");
            }
        }
    }

    return;
}

##########################################################

=head2 remove_orphaned_agent_templates

    remove_orphaned_agent_templates($c)

removes agent templates which are no longer used

=cut
sub remove_orphaned_agent_templates {
    my($c) = @_;
    my $result = $c->{'obj_db'}->_check_orphaned_objects();
    for my $hst (@{$result}) {
        next unless $hst->{'type'} eq 'host';
        next unless defined $hst->{'obj'}->{'conf'}->{'register'};
        next unless $hst->{'obj'}->{'conf'}->{'register'} == 0;
        next unless $hst->{'obj'}->{'conf'}->{'name'} =~ m/^agent\-/mx;
        $c->{'obj_db'}->delete_object($hst->{'obj'});
    }
    return;
}

##########################################################

=head2 sort_config_objects

    sort_config_objects($c)

sort objects by service name with host on top

=cut
sub sort_config_objects {
    my($c) = @_;
    my $hosts = $c->{'obj_db'}->get_objects_by_type("host");
    for my $hst (@{$hosts}) {
        my $file = $hst->{'file'};
        next unless $file->{'changed'};
        next unless $hst->{'conf'}->{'_AGENT'};
        # sort by type and name
        my $line = 1;
        for my $obj (sort { $a->{'type'} cmp $b->{'type'} || ($a->{'conf'}->{'service_description'}//'') cmp ($b->{'conf'}->{'service_description'}//'') } @{$file->{'objects'}}) {
            $obj->{'line'} = $line++;
        }
    }

    return;
}

##########################################################

=head2 migrate_hostname

    migrate_hostname($c, $old, $new, $section)

rename agent host

=cut
sub migrate_hostname {
    my($c, $old_host, $hostname, $section) = @_;
    # hostname has changed
    if(!$old_host || $hostname eq $old_host) {
        return;
    }

    # move objects file
    my($hostobj, $file);
    my $objects  = $c->{'obj_db'}->get_objects_by_name('host', $old_host);
    if($objects && scalar @{$objects} == 1) {
        $hostobj = $objects->[0];
    } else {
        return;
    }

    my $services = get_host_agent_services($c, $hostobj);

    my $filename = $section ? sprintf('agents/%s/%s.cfg', $section, $hostname) : sprintf('agents/%s.cfg', $hostname);
    $file = Thruk::Controller::conf::get_context_file($c, $hostobj, $filename);
    $hostobj->{'conf'}->{'host_name'} = $hostname;
    $hostobj->{'conf'}->{'alias'}     = $hostname;
    $c->{'obj_db'}->update_object($hostobj, $hostobj->{'conf'}, $hostobj->{'comments'}, 1);
    $c->{'obj_db'}->move_object($hostobj, $file, 0);

    # move services
    for my $descr (sort keys %{$services}) {
        my $svc = $services->{$descr};
        $svc->{'conf'}->{'host_name'} = $hostname;
        $c->{'obj_db'}->update_object($svc, $svc->{'conf'}, $svc->{'comments'}, 1);
        $c->{'obj_db'}->move_object($svc, $file, 0);
    }

    # rename data file
    my $df1 = $c->config->{'var_path'}.'/agents/hosts/'.$hostname.'.json';
    my $df2 = $c->config->{'var_path'}.'/agents/hosts/'.$old_host.'.json';
    my $d1 = Thruk::Utils::IO::saferead($df1);
    my $d2 = Thruk::Utils::IO::saferead($df2);
    if(defined $d2 && !defined $d1) {
        Thruk::Utils::IO::write($df1, $d2);
    }
    Thruk::Utils::IO::unlink($df2);

    return;
}

##########################################################
sub _check_pattern {
    my($val, $pattern) = @_;
    for my $entry (@{Thruk::Base::list($pattern)}) {
        my $f = "$entry"; # make copy
        my $op = '=';
        if($f =~ m/^([\!=~]+)\s+(.*)$/mx) {
            $op = $1;
            $f  = $2;
        }
        if($op eq '=' || $op eq '==') {
            return 1 if $val eq $f;
            return 1 if $f eq 'ANY';
            return 1 if $f eq '*';
        }
        elsif($op eq '!=' || $op eq '!==') {
            return 1 if $val ne $f;
        }
        elsif($op eq '~' || $op eq '~~') {
            ## no critic
            return 1 if $val =~ m/$f/;
            ## use critic
        }
        elsif($op eq '!~' || $op eq '!~~') {
            ## no critic
            return 1 if $val !~ m/$f/;
            ## use critic
        } else {
            die("unknown operator: $op");
        }
    }
    return(0);
}

##########################################################
sub _ensure_command_exists {
    my($c, $type, $name, $data, $filename) = @_;

    my $objects = $c->{'obj_db'}->get_objects_by_name($type, $name);
    if($objects && scalar @{$objects} > 0) {
        return 1;
    }

    my $obj = Monitoring::Config::Object->new( type     => $type,
                                               coretype => $c->{'obj_db'}->{'coretype'},
                                            );
    my $file = Thruk::Controller::conf::get_context_file($c, $obj, $filename);
    die("creating file failed") unless $file;
    $obj->set_file($file);
    $obj->set_uniq_id($c->{'obj_db'});
    $c->{'obj_db'}->update_object($obj, $data, "", 1);
    return;
}

##########################################################
sub _find_agent_modules {
    our $modules;
    return $modules if defined $modules;

    $modules = Thruk::Utils::find_modules('/Thruk/Agents/*.pm');
    for my $mod (@{$modules}) {
        require $mod;
        $mod =~ s/\//::/gmx;
        $mod =~ s/\.pm$//gmx;
        $mod->import;
    }
    return $modules;
}

##########################################################
# returns true if check matches any of the given excludes
sub _is_excluded {
    my($hostname, $chk, $excludes) = @_;
    return unless $excludes;
    $excludes = Thruk::Base::list($excludes);
    for my $ex (@{$excludes}) {
        $ex->{'host'} = "ANY" unless defined $ex->{'host'};
        if(!_check_pattern($hostname, $ex->{'host'})) {
            next;
        }
        return 1 if _check_pattern($chk->{'name'}, $ex->{'name'});
        return 1 if _check_pattern($chk->{'id'},   $ex->{'type'});
    }
    return(0);
}

##########################################################

1;
