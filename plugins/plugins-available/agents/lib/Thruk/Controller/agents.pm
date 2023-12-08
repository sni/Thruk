package Thruk::Controller::agents;

use warnings;
use strict;
use Cpanel::JSON::XS qw/decode_json/;

use Thruk::Action::AddDefaults ();
use Thruk::Backend::Manager ();
use Thruk::Controller::conf ();
use Thruk::Timer qw/timing_breakpoint/;
use Thruk::Utils::Agents ();
use Thruk::Utils::Auth ();
use Thruk::Utils::Conf ();
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::Controller::agents - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

##########################################################

=head2 index

=cut
sub index {
    my($c) = @_;
    &timing_breakpoint('index start');

    return unless Thruk::Action::AddDefaults::add_defaults($c);

    return $c->detach('/error/index/8') unless $c->check_user_roles("admin");

    $c->stash->{title}         = 'Agents';
    $c->stash->{page}          = 'agents';
    $c->stash->{template}      = 'agents.tt';

    $c->stash->{build_agent}   = \&Thruk::Utils::Agents::build_agent;

    $c->stash->{no_tt_trim}    = 1;
    $c->stash->{'plugin_name'} = Thruk::Utils::get_plugin_name(__FILE__, __PACKAGE__);

    # always convert backend name to key
    my $backend  = $c->req->parameters->{'backend'};
    if($backend) {
        my $peer = $c->db->get_peer_by_key($backend);
        if($peer) {
            $c->req->parameters->{'backend'} = $peer->{'key'};
            $backend = $peer->{'key'};
        }
    }

    Thruk::Utils::ssi_include($c);

    my $action = $c->req->parameters->{'action'} || 'show';
    $c->stash->{action} = $action;

       if($action eq 'show')   { _process_show($c); }
    elsif($action eq 'new')    { _process_new($c); }
    elsif($action eq 'edit')   { _process_edit($c); }
    elsif($action eq 'scan')   { _process_scan($c); }
    elsif($action eq 'save')   { _process_save($c); }
    elsif($action eq 'remove') { _process_remove($c); }
    elsif($action eq 'json')   { _process_json($c); }
    else { return $c->detach_error({ msg  => 'no such action', code => 400 }); }

    if($backend || $c->stash->{'param_backend'} || $c->req->parameters->{'backend'}) {
        Thruk::Utils::Agents::set_object_model($c, $backend || $c->stash->{'param_backend'} || $c->req->parameters->{'backend'}) unless $c->{'obj_db'};
    }
    $c->stash->{'reload_required'} = ($c->{'obj_db'} && $c->{'obj_db'}->{'last_changed'}) ? 1 : 0;

    if($action eq 'show') {
        $c->stash->{'reload_required'} = $c->req->parameters->{'activate'} // $c->stash->{'reload_required'};
        $c->stash->{'backend_chooser'} = 'select';
        $c->stash->{'param_backend'} = '';
        $c->req->parameters->{'backend'} = $backend;
        my($selected) = $c->db->select_backends('get_status');
        Thruk::Action::AddDefaults::update_site_panel_hashes($c, $selected);
    }

    return;
}

##########################################################
sub _process_show {
    my($c) = @_;

    my $hosts = $c->db->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ),
                                              'custom_variables' => { '~' => 'AGENT .+' },
                                            ],
                                 );
    for my $hst (@{$hosts}) {
        Thruk::Utils::set_allowed_rows_data($hst, 1);
    }
    $c->stash->{data} = Thruk::Backend::Manager::sort_result({}, $hosts, ['_AGENT_SECTION', 'name', 'peer_name']);

    my $services = $c->db->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ),
                                         'host_custom_variables' => { '~' => 'AGENT .+' },
                                         'description' => { '~' => '^(agent version|agent inventory)$' },
                                        ],
                                 );
    my $info = {};
    for my $svc (@{$services}) {
        my $extra = $info->{$svc->{'host_name'}} // {};
        if($svc->{'description'} eq 'agent version') {
            my $v = $svc->{'plugin_output'};
            $extra->{'version'}          = "";
            if($svc->{'state'} == 0) {
                $v =~ s/^.*\sv/v/gmx;
                $extra->{'version'}      = $v;
            }
            $extra->{'state'}            = $svc->{'state'};
            $extra->{'plugin_output'}    = $svc->{'plugin_output'};
            $extra->{'has_been_checked'} = $svc->{'has_been_checked'};
        }
        if($svc->{'description'} eq 'agent inventory') {
            $extra->{'inv_state'}        = $svc->{'state'};
            $extra->{'inv_out'}          = $svc->{'plugin_output'};
            $extra->{'inv_out'}          =~ s/^\w+\ \-\ //gmx;
        }
        $info->{$svc->{'host_name'}} = $extra;
    }
    $c->stash->{info} = $info;

    # set fallback backend for start page so the apply button can be shown
    if(!$c->req->parameters->{'backend'} && !$c->stash->{'param_backend'}) {
        my $config_backends = Thruk::Utils::Conf::get_backends_with_obj_config($c);
        if($config_backends && scalar keys %{$config_backends} >= 1) {
            $c->req->parameters->{'backend'} = (sort keys %{$config_backends})[0];
        }
    }

    Thruk::Utils::Agents::set_object_model($c, $c->stash->{'param_backend'} || $c->req->parameters->{'backend'}) unless $c->{'obj_db'};

    return;
}

##########################################################
sub _process_new {
    my($c) = @_;

    my $type  = Thruk::Utils::Agents::default_agent_type($c);
    my $agent = {
        'type'     => $type,
        'hostname' => $c->req->parameters->{'hostname'} // 'new',
        'section'  => $c->req->parameters->{'section'}  // '',
        'ip'       => $c->req->parameters->{'ip'}       // '',
        'port'     => $c->req->parameters->{'port'}     // '',
        'password' => $c->req->parameters->{'password'} // $c->config->{'Thruk::Agents'}->{lc($type)}->{'default_password'} // '',
        'peer_key' => $c->req->parameters->{'backend'}  // $c->stash->{'param_backend'},
        'settings' => {},
    };
    return _process_edit($c, $agent);
}

##########################################################
sub _process_edit {
    my($c, $agent) = @_;

    my $hostname = $c->req->parameters->{'hostname'};
    my $backend  = $c->req->parameters->{'backend'};
    my $type     = $c->req->parameters->{'type'} // Thruk::Utils::Agents::default_agent_type($c);
    my $section  = $c->req->parameters->{'section'};

    my $config_backends = Thruk::Utils::Conf::set_backends_with_obj_config($c);
    $c->stash->{config_backends}       = $config_backends;
    $c->stash->{has_multiple_backends} = scalar keys %{$config_backends} > 1 ? 1 : 0;
    $c->stash->{hide_backends_chooser} = 1;

    my $hostobj;
    if(!$agent && $hostname) {
        return unless Thruk::Utils::Agents::set_object_model($c, $backend);
        my $objects = $c->{'obj_db'}->get_objects_by_name('host', $hostname);
        if(!$objects || scalar @{$objects} == 0) {
            return _process_new($c);
        }
        $hostobj = $objects->[0];
        my $obj = $hostobj->{'conf'};
        $agent = {
            'type'     => $type,
            'hostname' => $hostname,
            'ip'       => $obj->{'address'}         // '',
            'section'  => $section // $obj->{'_AGENT_SECTION'} // '',
            'port'     => $obj->{'_AGENT_PORT'}     // '',
            'password' => $obj->{'_AGENT_PASSWORD'} // '',
            'peer_key' => $backend,
            'settings' => decode_json($obj->{'_AGENT_CONFIG'}) // {},
        };
        if($agent->{'settings'}->{'disabled'}) {
            $agent->{'settings'}->{'disabled'} = Thruk::Base::array2hash($agent->{'settings'}->{'disabled'});
        }
    }

    # extract checks
    my($checks, $checks_num) = Thruk::Utils::Agents::get_agent_checks_for_host($c, $backend, $hostname, $hostobj, $type, undef, ($section // $agent->{'section'}));

    my $services = $c->db->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { host_name => $hostname }], backend => $backend );
    $services = Thruk::Base::array2hash($services, "description");

    $c->stash->{services}         = $services;
    $c->stash->{checks}           = $checks;
    $c->stash->{checks_num}       = $checks_num;
    $c->stash->{'no_auto_reload'} = 1;
    $c->stash->{template}         = 'agents_edit.tt';
    $c->stash->{agent}            = $agent;
    $c->stash->{'has_jquery_ui'}  = 1;

    return;
}

##########################################################
sub _process_save {
    my($c) = @_;

    return unless Thruk::Utils::check_csrf($c);
    # don't store in demo mode
    if($c->config->{'demo_mode'}) {
        Thruk::Utils::set_message( $c, 'fail_message', "save is disabled in demo mode" );
        return $c->redirect_to('agents.cgi');
    }

    my $type      = lc($c->req->parameters->{'type'});
    my $hostname  = $c->req->parameters->{'hostname'};
    my $backend   = $c->req->parameters->{'backend'};
    my $section   = $c->req->parameters->{'section'}  // '';
    my $password  = $c->req->parameters->{'password'} || $c->config->{'Thruk::Agents'}->{lc($type)}->{'default_password'};
    my $port      = $c->req->parameters->{'port'};
    my $ip        = $c->req->parameters->{'ip'};

    if(!$hostname) {
        Thruk::Utils::set_message( $c, 'fail_message', "hostname is required");
        return _process_new($c);
    }

    if(!$backend) {
        Thruk::Utils::set_message( $c, 'fail_message', "backend is required");
        return _process_new($c);
    }

    my $err = Thruk::Utils::Agents::validate_params($hostname, $section);
    if($err) {
        Thruk::Utils::set_message( $c, 'fail_message', $err);
        return _process_new($c);
    }

    return unless Thruk::Utils::Agents::set_object_model($c, $backend);

    my $data = {
        hostname => $hostname,
        backend  => $backend,
        section  => $section,
        password => $password,
        port     => $port,
        ip       => $ip,
    };

    my $class   = Thruk::Utils::Agents::get_agent_class($type);
    my $agent   = $class->new();
    my($objects, $remove) = $agent->get_config_objects($c, $data, $c->req->parameters);
    for my $obj (@{$objects}) {
        my $file = Thruk::Controller::conf::get_context_file($c, $obj, $obj->{'_filename'});
        my $oldfile = $obj->{'file'};
        if(defined $file && $file->{'readonly'}) {
            Thruk::Utils::set_message( $c, 'fail_message', sprintf("cannot write to %s, file is marked readonly", $file->{'display'}));
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/agents.cgi?action=edit&hostname=".$hostname."&backend=".$backend);
        }
        if(!$oldfile) {
            $obj->set_file($file);
            $obj->set_uniq_id($c->{'obj_db'});
        } elsif($oldfile->{'path'} ne $file->{'path'}) {
            $c->{'obj_db'}->move_object($obj, $file);
        }
        if(!$c->{'obj_db'}->update_object($obj, $obj->{'conf'}, $obj->{'comments'}, 1)) {
            Thruk::Utils::set_message( $c, 'fail_message', "unable to save changes");
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/agents.cgi?action=edit&hostname=".$hostname."&backend=".$backend);
        }
    }
    for my $obj (@{$remove}) {
        $c->{'obj_db'}->delete_object($obj);
    }

    Thruk::Utils::Agents::remove_orphaned_agent_templates($c);
    Thruk::Utils::Agents::sort_config_objects($c);

    if($c->{'obj_db'}->commit($c)) {
        $c->stash->{'obj_model_changed'} = 1;
    }
    Thruk::Utils::Conf::store_model_retention($c, $c->stash->{'param_backend'});

    Thruk::Utils::set_message( $c, 'success_message', "changes saved successfully");
    return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/agents.cgi?action=edit&hostname=".$hostname."&backend=".$backend);
}

##########################################################
sub _process_remove {
    my($c) = @_;

    return unless Thruk::Utils::check_csrf($c);
    # don't store in demo mode
    if($c->config->{'demo_mode'}) {
        Thruk::Utils::set_message( $c, 'fail_message', "save is disabled in demo mode" );
        return $c->redirect_to('agents.cgi');
    }

    my $hostname  = $c->req->parameters->{'hostname'};
    my $backend   = $c->req->parameters->{'backend'};

    if(!$hostname) {
        Thruk::Utils::set_message( $c, 'fail_message', "hostname is required");
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/agents.cgi");
    }

    if(!$backend) {
        Thruk::Utils::set_message( $c, 'fail_message', "backend is required");
        return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/agents.cgi");
    }

    Thruk::Utils::Agents::remove_host($c, $hostname, $backend);

    Thruk::Utils::set_message( $c, 'success_message', "host $hostname removed successfully, activate to apply changes.");
    return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/agents.cgi?activate=$backend");
}

##########################################################
sub _process_scan {
    my($c, $params, $return) = @_;

    return unless Thruk::Utils::check_csrf($c);

    my $err = Thruk::Utils::Agents::scan_agent($c, $c->req->parameters);
    if($err) {
        _error($err);
        if(length($err) > 100) { $err = substr($err, 0, 97)."..." }
        Thruk::Utils::set_message( $c, 'fail_message', "failed to scan agent: ".$err );

        return $c->render(json => { ok => 0, err => $err });
    }

    return $c->render(json => { ok => 1 });
}

##########################################################
sub _process_json {
    my($c) = @_;

    my $json = [];
    my $type = $c->req->parameters->{'type'} // '';
    if($type eq 'section') {
        my $hosts = $c->db->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ),
                                                'custom_variables' => { '~' => 'AGENT .+' },
                                                ],
                                    );
        my $sections = {};
        for my $hst (@{$hosts}) {
            my $vars  = Thruk::Utils::get_custom_vars($c, $hst);
            $sections->{$vars->{'AGENT_SECTION'}} = 1 if $vars->{'AGENT_SECTION'};
        }
        push @{$json}, { 'name' => "sections", 'data' => [sort keys %{$sections} ] };
    }
    elsif($type eq 'site') {
        my $config_backends = Thruk::Utils::Conf::get_backends_with_obj_config($c);
        my $data = [];
        for my $key (sort keys %{$config_backends}) {
            my $peer = $c->db->get_peer_by_key($key);
            if($peer && $peer->{'name'}) {
                push @{$data}, $peer->{'name'};
            }
            @{$data} = sort @{$data};
        }
        push @{$json}, { 'name' => "sites", 'data' => $data };
    }

    return $c->render(json => $json);
}

##########################################################

1;
