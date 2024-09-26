package Thruk::Controller::node_control;

use warnings;
use strict;

use Thruk::Action::AddDefaults ();
use Thruk::Backend::Manager ();
use Thruk::NodeControl::Utils ();
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::Controller::node_control - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

##########################################################

=head2 index

=cut
sub index {
    my ( $c ) = @_;

    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::Constants::ADD_SAFE_DEFAULTS);

    # no permissions at all
    return $c->detach('/error/index/8') unless $c->check_user_roles("admin");

    $c->stash->{title}                 = 'Node Control';
    $c->stash->{template}              = 'node_control.tt';
    $c->stash->{infoBoxTitle}          = 'Node Control';
    $c->stash->{plugin_name}           = Thruk::Utils::get_plugin_name(__FILE__, __PACKAGE__);
    $c->stash->{'has_jquery_ui'}       = 1;

    my $config               = Thruk::NodeControl::Utils::config($c);
    my $parallel_actions     = $config->{'parallel_tasks'} // 3;
    $c->stash->{ms_parallel} = $parallel_actions;

    $c->stash->{'show_os_updates'}  = $config->{'os_updates'} // 1;
    $c->stash->{'show_pkg_install'} = $config->{'pkg_install'} // 1;
    $c->stash->{'show_pkg_cleanup'} = $config->{'pkg_cleanup'} // 1;
    $c->stash->{'show_all_button'}  = $config->{'all_button'} // 1;
    $c->stash->{'skip_confirm'}     = $config->{'skip_confirms'} ? 'noop_' : '';

    my $action = $c->req->parameters->{'action'} || 'list';

    if($action && $action ne 'list') {
        if($action eq 'save_options') {
            Thruk::NodeControl::Utils::save_config($c, {
                'omd_default_version'   => $c->req->parameters->{'omd_default_version'},
            });
            Thruk::Utils::set_message( $c, { style => 'success_message', msg => 'settings saved sucessfully' });
            return $c->redirect_to($c->stash->{'url_prefix'}."cgi-bin/node_control.cgi");
        }

        my $rc;
        eval {
            $rc = _node_action($c, $action);
        };
        if($@) {
            _warn("action %s failed: %s", $action, $@);
            return($c->render(json => {'success' => 0, 'error' => $@}));
        }
        if(!$rc && !$c->{'rendered'}) {
            _warn("action %s failed", $action);
            return($c->render(json => {'success' => 0, 'error' => 'action failed'}));
        }
        return(1);
    }

    my $servers = [];
    for my $peer (@{Thruk::NodeControl::Utils::get_peers($c)}) {
        push @{$servers}, Thruk::NodeControl::Utils::get_server($c, $peer, $config);
    }

    if(!$config->{'omd_default_version'}) {
        my(undef, $version) = Thruk::Utils::IO::cmd("omd version -b");
        chomp($version);
        Thruk::NodeControl::Utils::save_config($c, {
            'omd_default_version'   => $version,
        });
        $config->{'omd_default_version'} = $version;
    }
    my $available_omd_versions = [$config->{'omd_default_version'}];
    map { push @{$available_omd_versions}, @{$_->{omd_available_versions}} } @{$servers};
    $available_omd_versions = [reverse sort @{Thruk::Base::array_uniq($available_omd_versions)}];

    $c->stash->{omd_default_version}    = $config->{'omd_default_version'},
    $c->stash->{omd_available_versions} = $available_omd_versions;

    # sort servers by section, host_name, site
    map { $_->{'section'} = '' if $_->{'section'} eq 'Default' } @{$servers};
    $servers = Thruk::Backend::Manager::sort_result({}, $servers, ['section', 'peer_name', 'host_name', 'omd_site']);

    $c->stash->{data} = $servers;

    return 1;
}

##########################################################
sub _node_action {
    my($c, $action) = @_;

    my $config = Thruk::NodeControl::Utils::config($c);
    my $key    = $c->req->parameters->{'peer'};
    if(!$key) {
        return($c->render(json => {'success' => 0, "error" => "no peer key supplied"}));
    }
    my $peer = $c->db->get_peer_by_key($key);
    if(!$peer) {
        return($c->render(json => {'success' => 0, "error" => "no such peer found by key"}));
    }

    if($action eq 'update') {
        return unless Thruk::Utils::check_csrf($c);
        my $facts = Thruk::NodeControl::Utils::ansible_get_facts($c, $peer, 1);
        return($c->render(json => {'success' => 1}));
    }

    if($action eq 'facts') {
        $c->stash->{s}          = Thruk::NodeControl::Utils::get_server($c, $peer);
        $c->stash->{template}   = 'node_control_facts.tt';
        $c->stash->{modal}      = $c->req->parameters->{'modal'} // 0;
        $c->stash->{no_tt_trim} = 1;
        return 1;
    }

    if($action eq 'log') {
        my $log = $c->req->parameters->{'type'};
        return unless $log =~ m/^[a-z]+$/mx;
        $c->stash->{s}          = Thruk::NodeControl::Utils::get_server($c, $peer);
        $c->stash->{log}        = Thruk::Utils::IO::saferead_decoded($c->config->{'var_path'}.'/node_control/'.$peer->{'key'}.'_'.$log.'.log');
        $c->stash->{log_type}   = $log;
        $c->stash->{template}   = 'node_control_logs.tt';
        $c->stash->{modal}      = $c->req->parameters->{'modal'} // 0;
        $c->stash->{no_tt_trim} = 1;
        return 1;
    }

    if($action eq 'omd_status') {
        $c->stash->{s}          = Thruk::NodeControl::Utils::get_server($c, $peer);
        $c->stash->{template}   = 'node_control_omd_status.tt';
        $c->stash->{modal}      = $c->req->parameters->{'modal'} // 0;
        return 1;
    }

    if($action eq 'peer_status') {
        $c->stash->{s}          = Thruk::NodeControl::Utils::get_server($c, $peer);
        $c->stash->{template}   = 'node_control_peer_status.tt';
        $c->stash->{modal}      = $c->req->parameters->{'modal'} // 0;
        return 1;
    }
    if($action eq 'peer_on') {
        return(_omd_peer_cmd($c, $peer, $c->req->parameters->{'type'}, "on"));
    }
    if($action eq 'peer_off') {
        return(_omd_peer_cmd($c, $peer, $c->req->parameters->{'type'}, "off"));
    }

    if($action eq 'omd_stop') {
        return(_omd_service_cmd($c, $peer, "stop"));
    }

    if($action eq 'omd_start') {
        return(_omd_service_cmd($c, $peer, "start"));
    }

    if($action eq 'omd_restart') {
        return(_omd_service_cmd($c, $peer, "restart"));
    }

    if($action eq 'cleanup') {
        return unless Thruk::Utils::check_csrf($c);
        return($c->render(json => {'success' => 0, 'error' => "cleanup is disabled by config"})) unless $config->{'pkg_cleanup'};
        my $job = Thruk::NodeControl::Utils::omd_cleanup($c, $peer);
        return($c->render(json => {'success' => 1, job => $job})) if $job;
        return($c->render(json => {'success' => 0, 'error' => "failed to start job"}));
    }

    if($action eq 'omd_install') {
        return unless Thruk::Utils::check_csrf($c);
        return($c->render(json => {'success' => 0, 'error' => "pkg installation is disabled by config"})) unless $config->{'pkg_install'};
        my $job = Thruk::NodeControl::Utils::omd_install($c, $peer, $config->{'omd_default_version'});
        return($c->render(json => {'success' => 1, job => $job})) if $job;
        return($c->render(json => {'success' => 0, 'error' => "failed to start job"}));
    }

    if($action eq 'omd_update') {
        return unless Thruk::Utils::check_csrf($c);
        my $job = Thruk::NodeControl::Utils::omd_update($c, $peer, $config->{'omd_default_version'});
        return($c->render(json => {'success' => 1, job => $job})) if $job;
        return($c->render(json => {'success' => 0, 'error' => "failed to start job"}));
    }

    if($action eq 'omd_install_update_cleanup') {
        return unless Thruk::Utils::check_csrf($c);
        my $job = Thruk::NodeControl::Utils::omd_install_update_cleanup($c, $peer, $config->{'omd_default_version'});
        return($c->render(json => {'success' => 1, job => $job})) if $job;
        return($c->render(json => {'success' => 0, 'error' => "failed to start job"}));
    }

    if($action eq 'os_update') {
        return unless Thruk::Utils::check_csrf($c);
        return($c->render(json => {'success' => 0, 'error' => "os updates are disabled by config"})) unless $config->{'os_updates'};
        my $job = Thruk::NodeControl::Utils::os_update($c, $peer, $config->{'omd_default_version'});
        return($c->render(json => {'success' => 1, job => $job})) if $job;
        return($c->render(json => {'success' => 0, 'error' => "failed to start job"}));
    }

    if($action eq 'os_sec_update') {
        return unless Thruk::Utils::check_csrf($c);
        return($c->render(json => {'success' => 0, 'error' => "os updates are disabled by config"})) unless $config->{'os_updates'};
        my $job = Thruk::NodeControl::Utils::os_sec_update($c, $peer, $config->{'omd_default_version'});
        return($c->render(json => {'success' => 1, job => $job})) if $job;
        return($c->render(json => {'success' => 0, 'error' => "failed to start job" }));
    }

    return;
}

##########################################################
sub _omd_service_cmd {
    my($c, $peer, $cmd) = @_;
    return unless Thruk::Utils::check_csrf($c);
    my $service = $c->req->parameters->{'service'};
    Thruk::NodeControl::Utils::omd_service($c, $peer, $service, $cmd);
    return($c->render(json => {'success' => 1}));
}

##########################################################
sub _omd_peer_cmd {
    my($c, $peer, $type, $status) = @_;
    return unless Thruk::Utils::check_csrf($c);

    my $cmds = {
        "notifications" => { "on"  => "enable_notifications",        "off" => "disable_notifications",
                             "won" => "enable_notifications = 1",   "woff" => "enable_notifications = 0",
                           },
        "hostchecks"    => { "on"  => "start_executing_host_checks", "off" => "stop_executing_host_checks",
                             "won" => "execute_host_checks = 1",    "woff" => "execute_host_checks = 0",
                           },
        "servicechecks" => { "on"  => "start_executing_svc_checks",  "off" => "stop_executing_svc_checks",
                             "won" => "execute_service_checks = 1", "woff" => "execute_service_checks = 0",
                           },
        "eventhandlers" => { "on"  => "enable_event_handlers",       "off" => "disable_event_handlers",
                             "won" => "enable_event_handlers = 1",  "woff" => "enable_event_handlers = 0",
                           },
    };

    my $cmd  = $cmds->{$type}->{$status};
    my $wait = $cmds->{$type}->{"w".$status};

    my $post_token = $c->req->parameters->{'CSRFtoken'} // $c->req->parameters->{'token'};
    my $res        = $c->sub_request('/r/system/cmd/'.$cmd, 'POST', { 'CSRFtoken' => $post_token, 'backend' => $peer->{'key'} });
    if($res && $res->{'message'}) {
        my $options = {
            'header' => {
                'WaitTimeout'   => ($c->config->{'wait_timeout'} * 1000),
                'WaitTrigger'   => 'all',
                'WaitCondition' => $wait,
            },
        };
        $c->db->get_processinfo(columns => [ 'get_processinfo' ], options => $options, 'backend' => $peer->{'key'} );
        return($c->render(json => {'success' => 1, 'message' => $res->{'message'}}));
    }
    return($c->render(json => {'success' => 0, 'error' => "command failed"}));
}

##########################################################

1;
