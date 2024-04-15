package Thruk::Agents::SNClient;

use warnings;
use strict;
use Carp qw/confess/;
use Cpanel::JSON::XS qw/decode_json/;

use Monitoring::Config::Object ();
use Thruk::Utils ();
use Thruk::Utils::Agents ();
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::Agents::SNClient - implements snclient based agent configuration

=cut

my $settings = {
    'type'          => 'snclient',
    'icon'          => 'snclient.png',
    'icon_dark'     => 'snclient_dark.png',
    'default_port'  => 8443,
    'check_nsc_web_extra_options' => '-t 35',
};

=head1 METHODS

=cut

##########################################################

=head2 new

    new($c, $host)

returns agent object from livestatus host

=cut
sub new {
    my($class, $host) = @_;
    my $self = {};
    bless $self, $class;
    return($self);
}

##########################################################

=head2 settings

    settings()

returns settings for this agent

=cut
sub settings {
    return($settings);
}

##########################################################

=head2 get_config_objects

    get_config_objects($c, $data, $checks_config)

returns list of Monitoring::Objects for the host / services along with list of objects to remove

=cut
sub get_config_objects {
    my($self, $c, $data, $checks_config, $fresh) = @_;

    my $backend  = $data->{'backend'}  || die("missing backend");
    my $hostname = $data->{'hostname'} || die("missing hostname");
    my $ip       = $data->{'ip'}       // '';
    my $section  = $data->{'section'}  // '';
    my $password = $data->{'password'} // '';
    my $port     = $data->{'port'}     || $settings->{'default_port'};
    my $mode     = $data->{'mode'}     || 'https';

    $section =~ s|^\/*||gmx if $section;
    $section =~ s|\/*$||gmx if $section;
    $section =~ s|\/+|/|gmx if $section;
    my $filename = $section ? sprintf('agents/%s/%s.cfg', $section, $hostname) : sprintf('agents/%s.cfg', $hostname);
    my $objects  = $c->{'obj_db'}->get_objects_by_name('host', $hostname);
    my $hostobj;
    if(!$objects || scalar @{$objects} == 0) {
        # create new one
        $hostobj = Monitoring::Config::Object->new( type    => 'host',
                                                   coretype => $c->{'obj_db'}->{'coretype'},
                                                );
        $hostobj->{'conf'}->{'host_name'} = $hostname;
        $hostobj->{'conf'}->{'alias'}     = $hostname;
        $hostobj->{'conf'}->{'address'}   = $ip || $hostname;
    } else {
        $hostobj = $objects->[0];
        $hostobj->{'_prev_conf'} = Thruk::Utils::dclone($hostobj->{'conf'});
        $password = $password || $hostobj->{'conf'}->{'_AGENT_PASSWORD'};
    }
    $hostobj->{'_filename'} = $filename;
    $hostobj->{'conf'}->{'address'} = $ip if $ip;

    my $perf_template      = 'srv-pnp';
    my $host_perf_template = 'host-pnp';
    if($ENV{'CONFIG_GRAFANA'} && $ENV{'CONFIG_GRAFANA'} eq 'on') {
        $perf_template      = 'srv-perf';
        $host_perf_template = 'host-perf';
    }
    $perf_template      = $c->config->{'Thruk::Agents'}->{'snclient'}->{'perf_template'}      // $perf_template;
    $host_perf_template = $c->config->{'Thruk::Agents'}->{'snclient'}->{'host_perf_template'} // $host_perf_template;

    $hostobj->{'conf'}->{'use'} = [$host_perf_template, ($section ? _make_section_template("host", $section) : 'generic-thruk-agent-host')];

    my @list = ($hostobj);
    my @remove;

    my $hostdata = $hostobj->{'conf'} // {};

    my $services       = Thruk::Utils::Agents::get_host_agent_services($c, $hostobj);
    my $services_by_id = Thruk::Utils::Agents::get_host_agent_services_by_id($services);

    my $settings = $hostdata->{'_AGENT_CONFIG'} ? decode_json($hostdata->{'_AGENT_CONFIG'}) : {};
    for my $key (sort keys %{$checks_config}) {
        if($key =~ /^options\.(.*)$/mx) {
            my $opt_name = $1;
            if($checks_config->{$key} ne '') {
                $settings->{'options'}->{$opt_name} = $checks_config->{$key};
            } else {
                delete $settings->{'options'}->{$opt_name};
            }
        }
    }

    # save services
    my $checks = Thruk::Utils::Agents::get_services_checks($c, $backend, $hostname, $hostobj, "snclient", $password, $fresh, $section, $mode, $settings->{'options'});
    my $checks_hash = Thruk::Base::array2hash($checks, "id");

    if(!$checks || scalar @{$checks} == 0) {
        return;
    }

    confess("missing host config") unless $checks_hash->{'_host'};
    for my $key (sort keys %{$checks_hash->{'_host'}->{'conf'}}) {
        $hostdata->{$key} = $checks_hash->{'_host'}->{'conf'}->{$key};
    }
    my $section_changed = (!defined $hostdata->{'_AGENT_SECTION'} || $hostdata->{'_AGENT_SECTION'} ne $section);
    $hostdata->{'_AGENT_SECTION'}  = $section;
    $hostdata->{'_AGENT_PORT'}     = $port;
    delete $hostdata->{'_AGENT_MODE'};
    if($mode && $mode ne 'https') {
        $hostdata->{'_AGENT_MODE'} = $mode;
    }

    my $template = $section ? _make_section_template("service", $section) : 'generic-thruk-agent-service';

    for my $id (sort keys %{$checks_hash}) {
        next if $id eq '_host';
        my $type = $checks_config->{'check.'.$id} // 'off';
        my $args = $checks_config->{'args.'.$id}  // '';
        my $chk  = $checks_hash->{$id};
        confess("no name") unless $chk->{'name'};
        my $svc = $services_by_id->{$chk->{'id'}} // $services->{$chk->{'name'}};
        if(!$svc && $type eq 'keep') {
            $type = 'on';
            $checks_config->{'check.'.$id} = 'on';
        }
        if(!$svc && $type eq 'on') {
            # create new one
            $svc = Monitoring::Config::Object->new( type     => 'service',
                                                    coretype => $c->{'obj_db'}->{'coretype'},
                                                    );
        }

        if($type eq 'new') {
            $settings->{'disabled'} = Thruk::Base::array_remove($settings->{'disabled'}, $id);
            push @remove, $svc if $svc;
            next;
        }

        if($type eq 'off') {
            push @remove, $svc if $svc;
            # only save disabled information if it was disabled manually, not when disabled by config
            # and only if it wasn't orphanded
            if(!$chk->{'disabled'} && $chk->{'exists'} ne 'obsolete') {
                push @{$settings->{'disabled'}}, $id;
            }
            next;
        }
        $svc->{'_filename'} = $filename;
        $svc->{'_prev_conf'} = Thruk::Utils::dclone($svc->{'conf'});
        my @templates = ($template);
        unshift @templates, $perf_template unless $chk->{'noperf'};

        if($fresh || $type eq 'on' || ($chk->{'svc_conf'}->{'_AGENT_ARGS'}//'') ne ($args//'')) {
            if(!defined $chk->{'svc_conf'}->{'service_description'}) {
                # these are obsolete services, just keep them as is
                next;
            }
            $settings->{'disabled'} = Thruk::Base::array_remove($settings->{'disabled'}, $id);
            $svc->{'conf'} = $chk->{'svc_conf'};
            $svc->{'conf'}->{'use'} = \@templates;
            delete $chk->{'svc_conf'}->{'_AGENT_ARGS'};
            my $extra = _get_extra_opts_svc($c, $svc->{'conf'}->{'service_description'}, $hostname, $section);
            if($args) { # user supplied manual overrides
                $chk->{'svc_conf'}->{'_AGENT_ARGS'}    = $args;
                $chk->{'svc_conf'}->{'check_command'} .= " ".$args;
            } else {
                # check for default args
                $args = _get_default_args($c, $svc->{'conf'}->{'service_description'}, $hostname, $section);
                for my $ex (@{$extra}) {
                    for my $key (sort keys %{$ex}) {
                        $args = $ex->{$key} if $key eq 'args';
                    }
                }
                $chk->{'svc_conf'}->{'check_command'} .= " ".$args if $args;
            }

            # escape exclamation marks in check command (except the first one)
            my($cmd, $args) = split(/\!/mx, $chk->{'svc_conf'}->{'check_command'}, 2);
            $args =~ s/\\\!/!/gmx;
            $args =~ s/\!/\\!/gmx;
            $chk->{'svc_conf'}->{'check_command'} = sprintf("%s!%s", $cmd, $args);

            $svc->{'comments'} = ["# autogenerated check: ".$svc->{'conf'}->{'service_description'} ];

            # set extra service options
            for my $ex (@{$extra}) {
                for my $key (sort keys %{$ex}) {
                    next if $key eq 'host';
                    next if $key eq 'match';
                    next if $key eq 'service';
                    next if $key eq 'section';
                    next if $key eq 'host_name';
                    next if $key eq 'args';
                    $chk->{'svc_conf'}->{$key} = $ex->{$key};
                }
            }

            push @list, $svc;
            next;
        }
        if($section_changed && $svc->{'conf'}) {
            $svc->{'conf'}->{'use'} = \@templates;
            push @list, $svc;
            next;
        }
    }

    my $json = Cpanel::JSON::XS->new->canonical;
    if($settings->{'disabled'}) {
        $settings->{'disabled'} = Thruk::Base::array_uniq($settings->{'disabled'});
        if(scalar @{$settings->{'disabled'}} == 0) {
            delete $settings->{'disabled'};
        }
    }
    my $settings_str = $json->encode($settings);
    if($settings_str ne ($hostdata->{'_AGENT_CONFIG'}//"")) {
        $hostdata->{'_AGENT_CONFIG'} = $settings_str;
    }

    # set extra host options
    my $extra = _get_extra_opts_hst($c, $hostname, $section);
    my $host_check;
    for my $ex (@{$extra}) {
        for my $key (sort keys %{$ex}) {
            next if $key eq 'host';
            next if $key eq 'match';
            next if $key eq 'section';
            next if $key eq 'host_name';
            next if $key eq 'name';
            $hostdata->{$key} = $ex->{$key};
            $host_check = $ex->{$key} if $key eq 'check_command';
        }
    }

    my $proxy_cmd = _check_proxy_command($c, $settings->{'options'});
    # if there is a proxy command, we have to set a check_command for hosts
    if($proxy_cmd) {
        $hostdata->{'check_command'} = $host_check || $c->config->{'Thruk::Agents'}->{'snclient'}->{'host_check'} ||
                                       "\$USER1\$/check_icmp -H \$HOSTADDRESS\$ -w 3000.0,80% -c 5000.0,100% -p 5";
        $hostdata->{'check_command'} =
            sprintf("check_thruk_agent!%s%s",
                $proxy_cmd,
                $hostdata->{'check_command'},
            );
    }
    $hostobj->{'conf'} = $hostdata;

    _add_templates($c, \@list, $section);

    return(\@list, \@remove);
}

##########################################################
sub _add_templates {
    my($c, $list, $section) = @_;

    return unless $section;

    my @paths = split(/\//mx, $section);
    my $cur = "";
    my $parent_svc = "generic-thruk-agent-service";
    my $parent_hst = "generic-thruk-agent-host";
    while(scalar @paths > 0) {
        my $p = shift @paths;
        $cur = ($cur ? $cur."/" : "").$p;
        my $svc = Monitoring::Config::Object->new( type  => 'service',
                                                coretype => $c->{'obj_db'}->{'coretype'},
                                                );
        $svc->{'_filename'} = sprintf('agents/%s/templates.cfg', $cur);
        my $name = _make_section_template("service", $cur);
        $svc->{'conf'} = {
            "name"      => $name,
            "use"       => [$parent_svc],
            "register"  => 0,
        };
        my $objects = $c->{'obj_db'}->get_objects_by_name("service", $name);
        if(!$objects || scalar @{$objects} == 0) {
            push @{$list}, $svc;
        }
        $parent_svc = $name;

        $name = _make_section_template("host", $cur);
        my $hst = Monitoring::Config::Object->new( type  => 'host',
                                                coretype => $c->{'obj_db'}->{'coretype'},
                                                );
        $hst->{'_filename'} = sprintf('agents/%s/templates.cfg', $cur);
        $hst->{'conf'} = {
            "name"      => $name,
            "use"       => [$parent_hst],
            "register"  => 0,
        };
        $objects = $c->{'obj_db'}->get_objects_by_name("host", $name);
        if(!$objects || scalar @{$objects} == 0) {
            push @{$list}, $hst;
        }
        $parent_hst = $name;
    }

    return;
}

##########################################################

=head2 get_services_checks

    get_services_checks($c, $hostname, $hostobj, $password, $fresh, $section, $mode, $options)

returns list of Monitoring::Objects for the host / services

=cut
sub get_services_checks {
    my($self, $c, $hostname, $hostobj, $password, $fresh, $section, $mode, $options) = @_;
    my $datafile = $c->config->{'var_path'}.'/agents/hosts/'.$hostname.'.json';
    if(!-r $datafile) {
        return([]);
    }

    my $checks  = [];
    my $data    = Thruk::Utils::IO::json_lock_retrieve($datafile);
    $settings = {};
    if($hostobj && $hostobj->{'conf'}->{'_AGENT_CONFIG'}) {
        $settings = decode_json($hostobj->{'conf'}->{'_AGENT_CONFIG'});
    }
    $checks = _extract_checks(
                    $c,
                    $data->{'inventory'},
                    $hostname,
                    $password,
                    $fresh,
                    $section,
                    $mode,
                    $options // $settings->{'options'} // {},
                ) if $data->{'inventory'};

    return($checks);
}

##########################################################

=head2 get_inventory

    get_inventory($c, $c, $address, $hostname, $password, $port, $mode)

returns json structure from inventory api call.

=cut
sub get_inventory {
    my($self, $c, $address, $hostname, $password, $port, $mode) = @_;

    my $proto = "https";
    $proto = "http" if($mode && $mode eq 'http');
    die("no password supplied") unless $password;
    my $command  = "check_snclient";
    my $args     = sprintf("%s -p '%s' -r -u '%s://%s:%d/api/v1/inventory'",
        _check_nsc_web_extra_options($c, $mode),
        $password,
        $proto,
        ($address || $hostname),
        $port,
    );

    my $cmd = {
        command_name => 'check_snclient',
        command_line => '$USER1$/check_nsc_web $ARG1$',
    };

    my $extra_templates = [];
    push @{$extra_templates}, {
        type => 'host',
        name => 'generic-thruk-agent-host',
        file => 'agents/templates.cfg',
        conf => {
            'name'  => 'generic-thruk-agent-host',
            'use'   => ['generic-host'],
        },
    };
    push @{$extra_templates}, {
        type => 'service',
        name => 'generic-thruk-agent-service',
        file => 'agents/templates.cfg',
        conf => {
            'name'  => 'generic-thruk-agent-service',
            'use'   => ['generic-service'],
        },
    };

    Thruk::Utils::Agents::check_for_check_commands($c, [$cmd], $extra_templates);

    _debug("scan command: %s!%s", $command, $args);
    my $output = $c->{'obj_db'}->get_plugin_preview($c,
                                        $command,
                                        $args,
                                        $hostname,
                                        '',
                                    );
    $output = Thruk::Base::trim_whitespace($output) if $output;
    if($output =~ m/^\{/mx) {
        my $data;
        eval {
            $data = decode_json($output);
        };
        my $err = $@;
        if($err) {
            die($err);
        }
        return $data;
    }
    die($output || 'no output from inventory scan command');
}

##########################################################
sub _extract_checks {
    my($c, $inventory, $hostname, $password, $fresh, $section, $mode, $options) = @_;
    my $checks = [];

    # get available modules
    my $modules = Thruk::Utils::find_modules('Thruk/Agents/SNClient/Checks/*.pm');
    for my $mod (@{$modules}) {
        require $mod;
        $mod =~ s/\//::/gmx;
        $mod =~ s/\.pm$//gmx;
        $mod->import;
        my $add = $mod->get_checks($c, $inventory, $hostname, $password, $section);
        push @{$checks}, @{$add} if $add;
    }

    my $proxy_cmd = _check_proxy_command($c, $options);

    # compute host configuration
    my $hostdata = {};
    $hostdata->{'_AGENT'} = 'snclient';
    $password = '' unless defined $password;
    $hostdata->{'_AGENT_PASSWORD'} = $password if($password ne ''); # only if changed
    push @{$checks}, {
        'id'       => '_host',
        'conf'     => $hostdata,
    };

    # compute service configuration
    for my $chk (@{$checks}) {
        next if $chk->{'id'} eq '_host';
        my $svc_password = '$_HOSTAGENT_PASSWORD$';
        if($password ne '' && $password =~ m/^\$.*\$$/mx) {
            $svc_password = $password;
        }
        my $proto = "https";
        $proto = "http" if($mode && $mode eq 'http');
        my $command = sprintf(
                "check_thruk_agent!%s\$USER1\$/check_nsc_web %s %s -p '%s' -u '%s://%s:%s' '%s'",
                $proxy_cmd,
                _check_nsc_web_extra_options($c, $mode),
                ($chk->{'nscweb'} // ''),
                $svc_password,
                $proto,
                '$HOSTADDRESS$',
                '$_HOSTAGENT_PORT$',
                $chk->{'check'},
        );
        my $interval = $c->config->{'Thruk::Agents'}->{'snclient'}->{'check_interval'} // 1;
        if($chk->{'check'} eq 'inventory') {
            $command  = 'check_thruk_agent!'.$proxy_cmd.'$USER4$/bin/thruk agents check inventory \'$HOSTNAME$\'';
            $interval = $c->config->{'Thruk::Agents'}->{'snclient'}->{'inventory_interval'} // 60;
        }
        if($chk->{'check'} eq 'check_os_updates') {
            $interval = $c->config->{'Thruk::Agents'}->{'snclient'}->{'os_updates_interval'} // 60;
        }
        if($chk->{'args'}) {
            if(ref $chk->{'args'} eq 'ARRAY') {
                for my $arg (@{$chk->{'args'}}) {
                    $command .= sprintf(" %s", $arg);
                }
            } else {
                for my $arg (sort keys %{$chk->{'args'}}) {
                    $command .= sprintf(" %s='%s'", $arg, $chk->{'args'}->{$arg});
                }
            }
        }

        $chk->{'name'} =~ s|[`~!\$%^&*\|'"<>?,()=]*||gmx; # remove nasty chars from object name
        $chk->{'name'} =~ s|\\$||gmx; # remove trailing slashes from service names, ex.: in windows drives

        $chk->{'svc_conf'} = {
            'host_name'           => $hostname,
            'service_description' => $chk->{'name'},
            'check_interval'      => $interval,
            'retry_interval'      => $c->config->{'Thruk::Agents'}->{'snclient'}->{'retry_interval'}     // 0.5,
            'max_check_attempts'  => $c->config->{'Thruk::Agents'}->{'snclient'}->{'max_check_attempts'} // 5,
            'check_command'       => $command,
            '_AGENT_AUTO_CHECK'   => $chk->{'id'},
        };
        $chk->{'svc_conf'}->{'parents'} = $chk->{'parent'} if $chk->{'parent'};
        $chk->{'args'} = "";

        for my $attr (qw/contacts contactgroups/) {
            my $data = Thruk::Base::list($c->config->{'Thruk::Agents'}->{'snclient'}->{'default_'.$attr});
            $data    = Thruk::Base::comma_separated_list(join(",", @{$data}));
            if(scalar @{$data} > 0) {
                $chk->{'svc_conf'}->{$attr} = join(",", @{$data});
            }
        }
    }

    return $checks;
}

##########################################################

=head2 make_info

    make_info($data)

returns check info as string

=cut
sub make_info {
    my($data) = @_;
    return "" unless $data;
    return(Thruk::Utils::dump_params($data, 5000, 0));
}

##########################################################

=head2 make_name

    make_name($template, $macros)

returns check name based on template

=cut
sub make_name {
    my($tmpl, $macros) = @_;
    my $name = $tmpl;
    if($macros) {
        for my $key (sort keys %{$macros}) {
            my $val = $macros->{$key};
            $name =~ s|$key|$val|gmx;
        }
    }
    $name =~ s/\s*$//gmx;
    $name =~ s/^\s*//gmx;
    return($name);
}

##########################################################

=head2 check_host_match

    check_host_match($config)

returns true if check is enabled on this host

=cut
sub check_host_match {
    my($hosts) = @_;
    return(Thruk::Utils::Agents::check_wildcard_match($Thruk::Globals::HOSTNAME, $hosts));
}

##########################################################

=head2 get_disabled_config

    get_disabled_config($c, $key, $default)

returns disabled config for this key with a fallback

=cut
sub get_disabled_config {
    my($c, $key, $fallback) = @_;

    my $dis =   $c->config->{'Thruk::Agents'}->{'snclient'}->{'disable'}->{$key}
              ? $c->config->{'Thruk::Agents'}->{'snclient'}->{'disable'}
              : { $key => $fallback };
    return($dis);
}

##########################################################
sub _check_nsc_web_extra_options {
    my($c, $mode) = @_;
    my $options = $c->config->{'Thruk::Agents'}->{'snclient'}->{'check_nsc_web_extra_options'}
            // $settings->{'check_nsc_web_extra_options'};
    $options = $options." -k " if($mode && $mode eq 'insecure');
    return($options);
}

##########################################################
sub _check_proxy_command {
    my($c, $options) = @_;
    my $proxy = "";
    if($options->{'offline'}) {
        $proxy = sprintf("\$USER4\$/share/thruk/script/maybe_offline -H '\$HOSTNAME\$' -s '\$SERVICEDESC\$' -o '%s' -- ", $options->{'offline'});
    }
    return $proxy;
}

##########################################################
sub _make_section_template {
    my($type, $section) = @_;
    return("agent-".$type."-".$section);
}

##########################################################
sub _get_default_args {
    my($c, $name, $hostname, $section) = @_;
    my $args = Thruk::Base::list($c->config->{'Thruk::Agents'}->{'snclient'}->{'args'});
    my $res;
    for my $arg (@{$args}) {
        next unless Thruk::Utils::Agents::check_wildcard_match($name, ($arg->{'match'} // 'ANY'));
        next unless Thruk::Agents::SNClient::check_host_match($arg->{'host'});
        next unless Thruk::Utils::Agents::check_wildcard_match($section, ($arg->{'section'} // 'ANY'));
        $res = $arg->{'value'};
    }

    return $res;
}

##########################################################
sub _get_extra_opts_hst {
    my($c, $hostname, $section) = @_;
    my $opts = Thruk::Base::list($c->config->{'Thruk::Agents'}->{'snclient'}->{'extra_host_opts'});
    my $res = [];
    for my $opt (@{$opts}) {
        next unless Thruk::Utils::Agents::check_wildcard_match($hostname, ($opt->{'match'} // 'ANY'));
        next unless Thruk::Agents::SNClient::check_host_match($opt->{'host'});
        next unless Thruk::Utils::Agents::check_wildcard_match($section, ($opt->{'section'} // 'ANY'));
        push @{$res}, $opt;
    }

    return $res;
}

##########################################################
sub _get_extra_opts_svc {
    my($c, $name, $hostname, $section) = @_;
    my $opts = Thruk::Base::list($c->config->{'Thruk::Agents'}->{'snclient'}->{'extra_service_opts'});
    my $res = [];
    for my $opt (@{$opts}) {
        next unless Thruk::Utils::Agents::check_wildcard_match($name, ($opt->{'match'} // 'ANY'));
        next unless Thruk::Utils::Agents::check_wildcard_match($name, ($opt->{'service'} // 'ANY'));
        next unless Thruk::Agents::SNClient::check_host_match($opt->{'host'});
        next unless Thruk::Utils::Agents::check_wildcard_match($section, ($opt->{'section'} // 'ANY'));
        push @{$res}, $opt;
    }

    return $res;
}

##########################################################

1;
