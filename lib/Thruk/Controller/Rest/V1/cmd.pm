package Thruk::Controller::Rest::V1::cmd;

use strict;
use warnings;
use Cpanel::JSON::XS qw/decode_json/;
use Storable qw/dclone/;

use Thruk::Utils;
use Thruk::Controller::rest_v1;
use Thruk::Controller::cmd;

=head1 NAME

Thruk::Controller::Rest::V1::cmd - External commands rest interface version 1

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=cut

##########################################################
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/(hosts?|hostgroups?|servicegroups?|contacts?|contactgroups?)/([^/]+)/cmd/([^/]+)%mx, \&_rest_get_external_command);
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/(services?)/([^/]+)/([^/]+)/cmd/([^/]+)%mx, \&_rest_get_external_command);
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/(system|core|)/cmd/([^/]+)%mx,              \&_rest_get_external_command);
sub _rest_get_external_command {
    my($c, undef, $type, @args) = @_;
    my $cmd_data = get_rest_external_command_data();
    my($cmd, $cmd_name, $name, $description, @cmd_args);
    my $required_fields = {};
    $type =~ s/s$//gmx;
    if($type eq 'core') { $type = 'system'; }
    if($type =~ m/^(host|hostgroup|servicegroup|contact|contactgroup)$/mx) {
        $name     = shift @args;
        $cmd_name = shift @args;
        $cmd      = $cmd_data->{$type.'s'}->{$cmd_name};
        push @cmd_args, $name;
        $required_fields->{$type} = $name;

        if(!$c->check_cmd_permissions($type, $name)) {
            return({ 'message' => 'you are not allowed to run this command', 'description' => 'you don\' have command permissions for '.$type.' '.$name, code => 403 });
        }
    }
    elsif($type =~ m/^(service)$/mx) {
        $name        = shift @args;
        $description = shift @args;
        $cmd_name    = shift @args;
        $cmd         = $cmd_data->{$type.'s'}->{$cmd_name};
        $required_fields->{'host'} = $name;
        $required_fields->{$type} = $description;
        push @cmd_args, $name;
        push @cmd_args, $description;
        if(!$c->check_cmd_permissions($type, $description, $name)) {
            return({ 'message' => 'you are not allowed to run this command', 'description' => 'you don\' have command permissions for '.$type.' '.$description.' on host '.$name, code => 403 });
        }
    } else {
        $cmd_name = shift @args;
        $cmd      = $cmd_data->{$type}->{$cmd_name};
        if(!$c->check_cmd_permissions('system')) {
            return({ 'message' => 'you are not allowed to run system commands', 'description' => 'you don\' have the system_commands role', code => 403 });
        }
    }
    if(!$cmd) {
        return({ 'message' => 'no such command', 'description' => 'there is no command '.$cmd_name.' for type '.$type, code => 404 });
    }

    my $required = Thruk::Utils::array2hash($cmd->{'required'});
    for my $arg (@{$cmd->{'args'}}) {
        my $val = $c->req->parameters->{$arg};
        # set some defaults
        if(!defined $val) {
            if($arg eq 'comment_author')     { $val = $c->stash->{'remote_user'}; }
            if($arg eq 'fixed')              { $val = 1; }
            if($arg eq 'duration')           { $val = 0; }
            if($arg eq 'plugin_state')       { $val = 0; }
            if($arg eq 'options')            { $val = 0; }
            if($arg eq 'triggered_by')       { $val = 0; }
            if($arg eq 'start_time')         { $val = time(); }
            if($arg eq 'end_time')           { $val = time() + $c->config->{'downtime_duration'}; }
            if($arg eq 'sticky_ack')         { $val = 1; }
            if($arg eq 'send_notification')  { $val = $c->config->{'cmd_defaults'}->{'send_notification'} // 1; }
            if($arg eq 'sticky_ack')         { $val = $c->config->{'cmd_defaults'}->{'sticky_ack'} // 1; }
            if($arg eq 'persistent_comment') { $val = $c->config->{'cmd_defaults'}->{'persistent_comment'} // 1; }
        }
        # still not defined?
        if(!defined $val) {
            if($required->{$arg}) {
                return({ 'message' => 'missing argument: '.$arg, 'description' => $arg.' is a required argument', code => 400 });
            }
            $val = "";
        }
        if($arg eq 'start_time' || $arg eq 'end_time' || $arg eq 'notification_time') {
            $val = Thruk::Utils::parse_date( $c, $val);
        }
        if($arg eq 'performance_data') {
            # simply amend performance_data to the plugin_output
            if($val ne "") {
                $cmd_args[(scalar @cmd_args)-1] .= '|'.$val;
            }
            next;
        }
        push @cmd_args, $val;
    }

    # add missing value for reseting modified attributes
    if($cmd->{'name'} eq 'change_host_modattr' || $cmd->{'name'} eq 'change_svc_modattr') {
        push @cmd_args, 0;
    }

    my $cmd_line = "COMMAND [".time()."] ".uc($cmd->{'name'});
    if(scalar @cmd_args > 0) {
        $cmd_line .= ';'.join(';', @cmd_args);
    }
    my $cmd_list = [$cmd_line];

    if($cmd->{'requires_comment'} && $c->config->{'require_comments_for_disable_cmds'}) {
        if(!$c->req->parameters->{'comment_data'}) {
            return({ 'message' => 'missing argument: comment_data', 'description' => 'comment_data is a required argument', code => 400 });
        }
        if($description) {
            push @{$cmd_list}, sprintf("COMMAND [%d] ADD_SVC_COMMENT;%s;%s;1;%s;%s: %s", time(), $name, $description, $c->stash->{'remote_user'}, uc($cmd->{'name'}), $c->req->parameters->{'comment_data'});
        } else {
            push @{$cmd_list}, sprintf("COMMAND [%d] ADD_HOST_COMMENT;%s;1;%s;%s: %s", time(), $name, $c->stash->{'remote_user'}, uc($cmd->{'name'}), $c->req->parameters->{'comment_data'});
        }
    }

    my($backends) = $c->{'db'}->select_backends('send_command');
    if(scalar @{$backends} > 1) {
        $backends= Thruk::Controller::cmd::_get_affected_backends($c, $required_fields, $backends);
        if(scalar @{$backends} == 0) {
            return({ 'message' => 'cannot send command, affected backend list is empty.', code => 400 });
        }
    }

    my $commands = {};
    for my $b (@{$backends}) {
        $commands->{$b} = dclone($cmd_list); # must be cloned, otherwise add_remove_comments_commands_from_disabled_commands appends command multiple times
    }

    # handle custom commands
    if($cmd->{'name'} eq 'del_active_host_downtimes' || $cmd->{'name'} eq 'del_active_service_downtimes') {
        $commands = {};
        my $options = {};
        $options->{backend}  = $backends if defined $backends;
        if($cmd->{'name'} eq 'del_active_host_downtimes') {
            $options->{'filter'} = [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), host_name => $name, service_description => undef ];
        } else {
            $options->{'filter'} = [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), host_name => $name, service_description => $description ];
        }
        push @{$options->{'filter'}}, start_time => { '<=' => time() };
        my $data = $c->{'db'}->get_downtimes(%{$options});
        for my $d (@{$data}) {
            $commands->{$d->{'peer_key'}} = [] unless defined $commands->{$d->{'peer_key'}};
            if($d->{'service_description'}) {
                push @{$commands->{$d->{'peer_key'}}}, sprintf("COMMAND [%d] DEL_SVC_DOWNTIME;%d", time(), $d->{'id'});
            } else {
                push @{$commands->{$d->{'peer_key'}}}, sprintf("COMMAND [%d] DEL_HOST_DOWNTIME;%d", time(), $d->{'id'});
            }
        }
    }

    Thruk::Controller::cmd::add_remove_comments_commands_from_disabled_commands($c, $commands, $cmd->{'nr'}, $name, $description);
    Thruk::Controller::cmd::bulk_send($c, $commands);
    if($c->stash->{'last_command_error'}) {
        return({ 'message' => 'sending command failed', 'error' => $c->stash->{'last_command_error'}, code => 400, commands => join("\n", @{$c->stash->{'last_command_lines'}}) });
    }
    return({ 'message' => 'Command successfully submitted', commands => join("\n", @{$c->stash->{'last_command_lines'} // []}) });
}

##########################################################

=head2 get_rest_external_command_data

  get_rest_external_command_data()

return list of available commands grouped by type

=cut
sub get_rest_external_command_data {
    our $cmd_data;
    if(!$cmd_data) {
        my $data = "";
        while(<DATA>) {
            my $line = $_;
            next if $line =~ m/^\s*\#/mx;
            next if $line =~ m/^\s*$/mx;
            $data .= $line;
        }
        $cmd_data = decode_json($data);
    }
    return($cmd_data);
}
##########################################################

1;

__DATA__
# REST PATH: POST /hosts/<name>/cmd/acknowledge_host_problem
# Sends the ACKNOWLEDGE_HOST_PROBLEM command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * sticky_ack
#   * send_notification
#   * persistent_comment
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/acknowledge_host_problem.html for details.

# REST PATH: POST /hosts/<name>/cmd/acknowledge_host_problem_expire
# Sends the ACKNOWLEDGE_HOST_PROBLEM_EXPIRE command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * sticky_ack
#   * send_notification
#   * persistent_comment
#   * end_time
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/acknowledge_host_problem_expire.html for details.

# REST PATH: POST /hosts/<name>/cmd/add_host_comment
# Sends the ADD_HOST_COMMENT command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * persistent_comment
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/add_host_comment.html for details.

# REST PATH: POST /hosts/<name>/cmd/change_custom_host_var
# Changes the value of a custom host variable.
#
# Required arguments:
#
#   * name
#   * value
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_custom_host_var.html for details.

# REST PATH: POST /hosts/<name>/cmd/change_host_check_command
# Changes the check command for a particular host to be that specified by the 'check_command' option. The 'check_command' option specifies the short name of the command that should be used as the new host check command. The command must have been configured in Naemon before it was last (re)started.
#
# Required arguments:
#
#   * checkcommand
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_host_check_command.html for details.

# REST PATH: POST /hosts/<name>/cmd/change_host_check_timeperiod
# Changes the valid check period for the specified host.
#
# Required arguments:
#
#   * timeperiod
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_host_check_timeperiod.html for details.

# REST PATH: POST /hosts/<name>/cmd/change_host_event_handler
# Changes the event handler command for a particular host to be that specified by the 'event_handler_command' option. The 'event_handler_command' option specifies the short name of the command that should be used as the new host event handler. The command must have been configured in Naemon before it was last (re)started.
#
# Required arguments:
#
#   * eventhandler
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_host_event_handler.html for details.

# REST PATH: POST /hosts/<name>/cmd/change_host_modattr
# Sends the CHANGE_HOST_MODATTR command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_host_modattr.html for details.

# REST PATH: POST /hosts/<name>/cmd/change_host_notification_timeperiod
# Changes the host notification timeperiod to what is specified by the 'notification_timeperiod' option. The 'notification_timeperiod' option should be the short name of the timeperiod that is to be used as the service notification timeperiod. The timeperiod must have been configured in Naemon before it was last (re)started.
#
# Required arguments:
#
#   * timeperiod
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_host_notification_timeperiod.html for details.

# REST PATH: POST /hosts/<name>/cmd/change_max_host_check_attempts
# Changes the maximum number of check attempts (retries) for a particular host.
#
# Required arguments:
#
#   * interval
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_max_host_check_attempts.html for details.

# REST PATH: POST /hosts/<name>/cmd/change_normal_host_check_interval
# Changes the normal (regularly scheduled) check interval for a particular host.
#
# Required arguments:
#
#   * interval
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_normal_host_check_interval.html for details.

# REST PATH: POST /hosts/<name>/cmd/change_retry_host_check_interval
# Changes the retry check interval for a particular host.
#
# Required arguments:
#
#   * interval
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_retry_host_check_interval.html for details.

# REST PATH: POST /hosts/<name>/cmd/del_active_host_downtimes
# Removes all currently active downtimes for this host.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/del_active_host_downtimes.html for details.

# REST PATH: POST /hosts/<name>/cmd/del_all_host_comments
# Sends the DEL_ALL_HOST_COMMENTS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/del_all_host_comments.html for details.

# REST PATH: POST /hosts/<name>/cmd/delay_host_notification
# Sends the DELAY_HOST_NOTIFICATION command.
#
# Required arguments:
#
#   * notification_time
#
# See http://www.naemon.org/documentation/developer/externalcommands/delay_host_notification.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_all_notifications_beyond_host
# Sends the DISABLE_ALL_NOTIFICATIONS_BEYOND_HOST command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_all_notifications_beyond_host.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_host_and_child_notifications
# Sends the DISABLE_HOST_AND_CHILD_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_host_and_child_notifications.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_host_check
# Sends the DISABLE_HOST_CHECK command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_host_check.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_host_event_handler
# Sends the DISABLE_HOST_EVENT_HANDLER command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_host_event_handler.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_host_flap_detection
# Sends the DISABLE_HOST_FLAP_DETECTION command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_host_flap_detection.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_host_notifications
# Sends the DISABLE_HOST_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_host_notifications.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_host_svc_checks
# Sends the DISABLE_HOST_SVC_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_host_svc_checks.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_host_svc_notifications
# Sends the DISABLE_HOST_SVC_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_host_svc_notifications.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_passive_host_checks
# Sends the DISABLE_PASSIVE_HOST_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_passive_host_checks.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_all_notifications_beyond_host
# Sends the ENABLE_ALL_NOTIFICATIONS_BEYOND_HOST command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_all_notifications_beyond_host.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_host_and_child_notifications
# Sends the ENABLE_HOST_AND_CHILD_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_host_and_child_notifications.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_host_check
# Sends the ENABLE_HOST_CHECK command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_host_check.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_host_event_handler
# Sends the ENABLE_HOST_EVENT_HANDLER command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_host_event_handler.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_host_flap_detection
# Sends the ENABLE_HOST_FLAP_DETECTION command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_host_flap_detection.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_host_notifications
# Sends the ENABLE_HOST_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_host_notifications.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_host_svc_checks
# Sends the ENABLE_HOST_SVC_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_host_svc_checks.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_host_svc_notifications
# Sends the ENABLE_HOST_SVC_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_host_svc_notifications.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_passive_host_checks
# Sends the ENABLE_PASSIVE_HOST_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_passive_host_checks.html for details.

# REST PATH: POST /hosts/<name>/cmd/process_host_check_result
# Sends the PROCESS_HOST_CHECK_RESULT command.
#
# Required arguments:
#
#   * plugin_output
#
# Optional arguments:
#
#   * plugin_state
#   * performance_data
#
# See http://www.naemon.org/documentation/developer/externalcommands/process_host_check_result.html for details.

# REST PATH: POST /hosts/<name>/cmd/remove_host_acknowledgement
# Sends the REMOVE_HOST_ACKNOWLEDGEMENT command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/remove_host_acknowledgement.html for details.

# REST PATH: POST /hosts/<name>/cmd/schedule_and_propagate_host_downtime
# Sends the SCHEDULE_AND_PROPAGATE_HOST_DOWNTIME command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * start_time
#   * end_time
#   * fixed
#   * triggered_by
#   * duration
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/schedule_and_propagate_host_downtime.html for details.

# REST PATH: POST /hosts/<name>/cmd/schedule_and_propagate_triggered_host_downtime
# Sends the SCHEDULE_AND_PROPAGATE_TRIGGERED_HOST_DOWNTIME command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * start_time
#   * end_time
#   * fixed
#   * triggered_by
#   * duration
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/schedule_and_propagate_triggered_host_downtime.html for details.

# REST PATH: POST /hosts/<name>/cmd/schedule_forced_host_check
# Sends the SCHEDULE_FORCED_HOST_CHECK command.
#
# Optional arguments:
#
#   * start_time
#
# See http://www.naemon.org/documentation/developer/externalcommands/schedule_forced_host_check.html for details.

# REST PATH: POST /hosts/<name>/cmd/schedule_forced_host_svc_checks
# Sends the SCHEDULE_FORCED_HOST_SVC_CHECKS command.
#
# Optional arguments:
#
#   * start_time
#
# See http://www.naemon.org/documentation/developer/externalcommands/schedule_forced_host_svc_checks.html for details.

# REST PATH: POST /hosts/<name>/cmd/schedule_host_check
# Sends the SCHEDULE_HOST_CHECK command.
#
# Optional arguments:
#
#   * start_time
#
# See http://www.naemon.org/documentation/developer/externalcommands/schedule_host_check.html for details.

# REST PATH: POST /hosts/<name>/cmd/schedule_host_downtime
# Sends the SCHEDULE_HOST_DOWNTIME command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * start_time
#   * end_time
#   * fixed
#   * triggered_by
#   * duration
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/schedule_host_downtime.html for details.

# REST PATH: POST /hosts/<name>/cmd/schedule_host_svc_checks
# Sends the SCHEDULE_HOST_SVC_CHECKS command.
#
# Optional arguments:
#
#   * start_time
#
# See http://www.naemon.org/documentation/developer/externalcommands/schedule_host_svc_checks.html for details.

# REST PATH: POST /hosts/<name>/cmd/schedule_host_svc_downtime
# Sends the SCHEDULE_HOST_SVC_DOWNTIME command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * start_time
#   * end_time
#   * fixed
#   * triggered_by
#   * duration
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/schedule_host_svc_downtime.html for details.

# REST PATH: POST /hosts/<name>/cmd/send_custom_host_notification
# Sends the SEND_CUSTOM_HOST_NOTIFICATION command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * options
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/send_custom_host_notification.html for details.

# REST PATH: POST /hosts/<name>/cmd/set_host_notification_number
# Sets the current notification number for a particular host. A value of 0 indicates that no notification has yet been sent for the current host problem. Useful for forcing an escalation (based on notification number) or replicating notification information in redundant monitoring environments. Notification numbers greater than zero have no noticeable affect on the notification process if the host is currently in an UP state.
#
# Required arguments:
#
#   * number
#
# See http://www.naemon.org/documentation/developer/externalcommands/set_host_notification_number.html for details.

# REST PATH: POST /hosts/<name>/cmd/start_obsessing_over_host
# Sends the START_OBSESSING_OVER_HOST command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/start_obsessing_over_host.html for details.

# REST PATH: POST /hosts/<name>/cmd/stop_obsessing_over_host
# Sends the STOP_OBSESSING_OVER_HOST command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/stop_obsessing_over_host.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/acknowledge_svc_problem
# Sends the ACKNOWLEDGE_SVC_PROBLEM command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * sticky_ack
#   * send_notification
#   * persistent_comment
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/acknowledge_svc_problem.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/acknowledge_svc_problem_expire
# Sends the ACKNOWLEDGE_SVC_PROBLEM_EXPIRE command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * sticky_ack
#   * send_notification
#   * persistent_comment
#   * end_time
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/acknowledge_svc_problem_expire.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/add_svc_comment
# Sends the ADD_SVC_COMMENT command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * persistent_comment
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/add_svc_comment.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/change_custom_svc_var
# Changes the value of a custom service variable.
#
# Required arguments:
#
#   * name
#   * value
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_custom_svc_var.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/change_max_svc_check_attempts
# Changes the maximum number of check attempts (retries) for a particular service.
#
# Required arguments:
#
#   * attempts
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_max_svc_check_attempts.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/change_normal_svc_check_interval
# Changes the normal (regularly scheduled) check interval for a particular service
#
# Required arguments:
#
#   * interval
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_normal_svc_check_interval.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/change_retry_svc_check_interval
# Changes the retry check interval for a particular service.
#
# Required arguments:
#
#   * interval
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_retry_svc_check_interval.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/change_svc_check_command
# Changes the check command for a particular service to be that specified by the 'check_command' option. The 'check_command' option specifies the short name of the command that should be used as the new service check command. The command must have been configured in Naemon before it was last (re)started.
#
# Required arguments:
#
#   * checkcommand
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_svc_check_command.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/change_svc_check_timeperiod
# Changes the check timeperiod for a particular service to what is specified by the 'check_timeperiod' option. The 'check_timeperiod' option should be the short name of the timeperod that is to be used as the service check timeperiod. The timeperiod must have been configured in Naemon before it was last (re)started.
#
# Required arguments:
#
#   * timeperiod
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_svc_check_timeperiod.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/change_svc_event_handler
# Changes the event handler command for a particular service to be that specified by the 'event_handler_command' option. The 'event_handler_command' option specifies the short name of the command that should be used as the new service event handler. The command must have been configured in Naemon before it was last (re)started.
#
# Required arguments:
#
#   * eventhandler
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_svc_event_handler.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/change_svc_modattr
# Sends the CHANGE_SVC_MODATTR command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_svc_modattr.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/change_svc_notification_timeperiod
# Changes the service notification timeperiod to what is specified by the 'notification_timeperiod' option. The 'notification_timeperiod' option should be the short name of the timeperiod that is to be used as the service notification timeperiod. The timeperiod must have been configured in Naemon before it was last (re)started.
#
# Required arguments:
#
#   * timeperiod
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_svc_notification_timeperiod.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/del_active_service_downtimes
# Removes all currently active downtimes for this service.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/del_active_service_downtimes.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/del_all_svc_comments
# Sends the DEL_ALL_SVC_COMMENTS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/del_all_svc_comments.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/delay_svc_notification
# Sends the DELAY_SVC_NOTIFICATION command.
#
# Required arguments:
#
#   * notification_time
#
# See http://www.naemon.org/documentation/developer/externalcommands/delay_svc_notification.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/disable_passive_svc_checks
# Sends the DISABLE_PASSIVE_SVC_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_passive_svc_checks.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/disable_svc_check
# Sends the DISABLE_SVC_CHECK command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_svc_check.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/disable_svc_event_handler
# Sends the DISABLE_SVC_EVENT_HANDLER command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_svc_event_handler.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/disable_svc_flap_detection
# Sends the DISABLE_SVC_FLAP_DETECTION command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_svc_flap_detection.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/disable_svc_notifications
# Sends the DISABLE_SVC_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_svc_notifications.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/enable_passive_svc_checks
# Sends the ENABLE_PASSIVE_SVC_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_passive_svc_checks.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/enable_svc_check
# Sends the ENABLE_SVC_CHECK command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_svc_check.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/enable_svc_event_handler
# Sends the ENABLE_SVC_EVENT_HANDLER command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_svc_event_handler.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/enable_svc_flap_detection
# Sends the ENABLE_SVC_FLAP_DETECTION command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_svc_flap_detection.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/enable_svc_notifications
# Sends the ENABLE_SVC_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_svc_notifications.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/process_service_check_result
# Sends the PROCESS_SERVICE_CHECK_RESULT command.
#
# Required arguments:
#
#   * plugin_output
#
# Optional arguments:
#
#   * plugin_state
#   * performance_data
#
# See http://www.naemon.org/documentation/developer/externalcommands/process_service_check_result.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/remove_svc_acknowledgement
# Sends the REMOVE_SVC_ACKNOWLEDGEMENT command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/remove_svc_acknowledgement.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/schedule_forced_svc_check
# Sends the SCHEDULE_FORCED_SVC_CHECK command.
#
# Optional arguments:
#
#   * start_time
#
# See http://www.naemon.org/documentation/developer/externalcommands/schedule_forced_svc_check.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/schedule_svc_check
# Sends the SCHEDULE_SVC_CHECK command.
#
# Optional arguments:
#
#   * start_time
#
# See http://www.naemon.org/documentation/developer/externalcommands/schedule_svc_check.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/schedule_svc_downtime
# Sends the SCHEDULE_SVC_DOWNTIME command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * start_time
#   * end_time
#   * fixed
#   * triggered_by
#   * duration
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/schedule_svc_downtime.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/send_custom_svc_notification
# Sends the SEND_CUSTOM_SVC_NOTIFICATION command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * options
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/send_custom_svc_notification.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/set_svc_notification_number
# Sets the current notification number for a particular service. A value of 0 indicates that no notification has yet been sent for the current service problem. Useful for forcing an escalation (based on notification number) or replicating notification information in redundant monitoring environments. Notification numbers greater than zero have no noticeable affect on the notification process if the service is currently in an OK state.
#
# Required arguments:
#
#   * number
#
# See http://www.naemon.org/documentation/developer/externalcommands/set_svc_notification_number.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/start_obsessing_over_svc
# Sends the START_OBSESSING_OVER_SVC command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/start_obsessing_over_svc.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/stop_obsessing_over_svc
# Sends the STOP_OBSESSING_OVER_SVC command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/stop_obsessing_over_svc.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/disable_hostgroup_host_checks
# Sends the DISABLE_HOSTGROUP_HOST_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_hostgroup_host_checks.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/disable_hostgroup_host_notifications
# Sends the DISABLE_HOSTGROUP_HOST_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_hostgroup_host_notifications.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/disable_hostgroup_passive_host_checks
# Disables passive checks for all hosts in a particular hostgroup.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_hostgroup_passive_host_checks.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/disable_hostgroup_passive_svc_checks
# Disables passive checks for all services associated with hosts in a particular hostgroup.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_hostgroup_passive_svc_checks.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/disable_hostgroup_svc_checks
# Sends the DISABLE_HOSTGROUP_SVC_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_hostgroup_svc_checks.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/disable_hostgroup_svc_notifications
# Sends the DISABLE_HOSTGROUP_SVC_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_hostgroup_svc_notifications.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/enable_hostgroup_host_checks
# Sends the ENABLE_HOSTGROUP_HOST_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_hostgroup_host_checks.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/enable_hostgroup_host_notifications
# Sends the ENABLE_HOSTGROUP_HOST_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_hostgroup_host_notifications.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/enable_hostgroup_passive_host_checks
# Enables passive checks for all hosts in a particular hostgroup.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_hostgroup_passive_host_checks.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/enable_hostgroup_passive_svc_checks
# Enables passive checks for all services associated with hosts in a particular hostgroup.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_hostgroup_passive_svc_checks.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/enable_hostgroup_svc_checks
# Sends the ENABLE_HOSTGROUP_SVC_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_hostgroup_svc_checks.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/enable_hostgroup_svc_notifications
# Sends the ENABLE_HOSTGROUP_SVC_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_hostgroup_svc_notifications.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/schedule_hostgroup_host_downtime
# Sends the SCHEDULE_HOSTGROUP_HOST_DOWNTIME command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * start_time
#   * end_time
#   * fixed
#   * triggered_by
#   * duration
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/schedule_hostgroup_host_downtime.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/schedule_hostgroup_svc_downtime
# Sends the SCHEDULE_HOSTGROUP_SVC_DOWNTIME command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * start_time
#   * end_time
#   * fixed
#   * triggered_by
#   * duration
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/schedule_hostgroup_svc_downtime.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/disable_servicegroup_host_checks
# Sends the DISABLE_SERVICEGROUP_HOST_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_servicegroup_host_checks.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/disable_servicegroup_host_notifications
# Sends the DISABLE_SERVICEGROUP_HOST_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_servicegroup_host_notifications.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/disable_servicegroup_passive_host_checks
# Disables the acceptance and processing of passive checks for all hosts that have services that are members of a particular service group.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_servicegroup_passive_host_checks.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/disable_servicegroup_passive_svc_checks
# Disables the acceptance and processing of passive checks for all services in a particular servicegroup.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_servicegroup_passive_svc_checks.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/disable_servicegroup_svc_checks
# Sends the DISABLE_SERVICEGROUP_SVC_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_servicegroup_svc_checks.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/disable_servicegroup_svc_notifications
# Sends the DISABLE_SERVICEGROUP_SVC_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_servicegroup_svc_notifications.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/enable_servicegroup_host_checks
# Sends the ENABLE_SERVICEGROUP_HOST_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_servicegroup_host_checks.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/enable_servicegroup_host_notifications
# Sends the ENABLE_SERVICEGROUP_HOST_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_servicegroup_host_notifications.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/enable_servicegroup_passive_host_checks
# Enables the acceptance and processing of passive checks for all hosts that have services that are members of a particular service group.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_servicegroup_passive_host_checks.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/enable_servicegroup_passive_svc_checks
# Enables the acceptance and processing of passive checks for all services in a particular servicegroup.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_servicegroup_passive_svc_checks.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/enable_servicegroup_svc_checks
# Sends the ENABLE_SERVICEGROUP_SVC_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_servicegroup_svc_checks.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/enable_servicegroup_svc_notifications
# Sends the ENABLE_SERVICEGROUP_SVC_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_servicegroup_svc_notifications.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/schedule_servicegroup_host_downtime
# Sends the SCHEDULE_SERVICEGROUP_HOST_DOWNTIME command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * start_time
#   * end_time
#   * fixed
#   * triggered_by
#   * duration
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/schedule_servicegroup_host_downtime.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/schedule_servicegroup_svc_downtime
# Sends the SCHEDULE_SERVICEGROUP_SVC_DOWNTIME command.
#
# Required arguments:
#
#   * comment_data
#
# Optional arguments:
#
#   * start_time
#   * end_time
#   * fixed
#   * triggered_by
#   * duration
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/schedule_servicegroup_svc_downtime.html for details.

# REST PATH: POST /system/cmd/change_global_host_event_handler
# Changes the global host event handler command to be that specified by the 'event_handler_command' option. The 'event_handler_command' option specifies the short name of the command that should be used as the new host event handler. The command must have been configured in Naemon before it was last (re)started.
#
# Required arguments:
#
#   * eventhandler
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_global_host_event_handler.html for details.

# REST PATH: POST /system/cmd/change_global_svc_event_handler
# Changes the global service event handler command to be that specified by the 'event_handler_command' option. The 'event_handler_command' option specifies the short name of the command that should be used as the new service event handler. The command must have been configured in Naemon before it was last (re)started.
#
# Required arguments:
#
#   * eventhandler
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_global_svc_event_handler.html for details.

# REST PATH: POST /system/cmd/del_downtime_by_host_name
# This command deletes all downtimes matching the specified filters.
#
# Optional arguments:
#
#   * hostname
#   * service_desc
#   * start_time
#   * comment
#
# See http://www.naemon.org/documentation/developer/externalcommands/del_downtime_by_host_name.html for details.

# REST PATH: POST /system/cmd/del_downtime_by_hostgroup_name
# This command deletes all downtimes matching the specified filters.
#
# Optional arguments:
#
#   * hostgroup_name
#   * hostname
#   * service_desc
#   * start_time
#   * comment
#
# See http://www.naemon.org/documentation/developer/externalcommands/del_downtime_by_hostgroup_name.html for details.

# REST PATH: POST /system/cmd/del_downtime_by_start_time_comment
# This command deletes all downtimes matching the specified filters.
#
# Optional arguments:
#
#   * start_time
#   * comment
#
# See http://www.naemon.org/documentation/developer/externalcommands/del_downtime_by_start_time_comment.html for details.

# REST PATH: POST /system/cmd/del_host_comment
# Sends the DEL_HOST_COMMENT command.
#
# Required arguments:
#
#   * comment_id
#
# See http://www.naemon.org/documentation/developer/externalcommands/del_host_comment.html for details.

# REST PATH: POST /system/cmd/del_host_downtime
# Sends the DEL_HOST_DOWNTIME command.
#
# Required arguments:
#
#   * downtime_id
#
# See http://www.naemon.org/documentation/developer/externalcommands/del_host_downtime.html for details.

# REST PATH: POST /system/cmd/del_svc_comment
# Sends the DEL_SVC_COMMENT command.
#
# Required arguments:
#
#   * comment_id
#
# See http://www.naemon.org/documentation/developer/externalcommands/del_svc_comment.html for details.

# REST PATH: POST /system/cmd/del_svc_downtime
# Sends the DEL_SVC_DOWNTIME command.
#
# Required arguments:
#
#   * downtime_id
#
# See http://www.naemon.org/documentation/developer/externalcommands/del_svc_downtime.html for details.

# REST PATH: POST /system/cmd/disable_event_handlers
# Sends the DISABLE_EVENT_HANDLERS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_event_handlers.html for details.

# REST PATH: POST /system/cmd/disable_flap_detection
# Sends the DISABLE_FLAP_DETECTION command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_flap_detection.html for details.

# REST PATH: POST /system/cmd/disable_host_freshness_checks
# Disables freshness checks of all hosts on a program-wide basis.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_host_freshness_checks.html for details.

# REST PATH: POST /system/cmd/disable_notifications
# Sends the DISABLE_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_notifications.html for details.

# REST PATH: POST /system/cmd/disable_performance_data
# Sends the DISABLE_PERFORMANCE_DATA command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_performance_data.html for details.

# REST PATH: POST /system/cmd/disable_service_freshness_checks
# Disables freshness checks of all services on a program-wide basis.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_service_freshness_checks.html for details.

# REST PATH: POST /system/cmd/enable_event_handlers
# Sends the ENABLE_EVENT_HANDLERS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_event_handlers.html for details.

# REST PATH: POST /system/cmd/enable_flap_detection
# Sends the ENABLE_FLAP_DETECTION command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_flap_detection.html for details.

# REST PATH: POST /system/cmd/enable_host_freshness_checks
# Enables freshness checks of all services on a program-wide basis. Individual services that have freshness checks disabled will not be checked for freshness.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_host_freshness_checks.html for details.

# REST PATH: POST /system/cmd/enable_notifications
# Sends the ENABLE_NOTIFICATIONS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_notifications.html for details.

# REST PATH: POST /system/cmd/enable_performance_data
# Sends the ENABLE_PERFORMANCE_DATA command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_performance_data.html for details.

# REST PATH: POST /system/cmd/enable_service_freshness_checks
# Enables freshness checks of all services on a program-wide basis. Individual services that have freshness checks disabled will not be checked for freshness.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_service_freshness_checks.html for details.

# REST PATH: POST /system/cmd/read_state_information
# Causes Naemon to load all current monitoring status information from the state retention file. Normally, state retention information is loaded when the Naemon process starts up and before it starts monitoring. WARNING: This command will cause Naemon to discard all current monitoring status information and use the information stored in state retention file! Use with care.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/read_state_information.html for details.

# REST PATH: POST /system/cmd/restart_process
# Sends the RESTART_PROCESS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/restart_process.html for details.

# REST PATH: POST /system/cmd/restart_program
# Restarts the Naemon process.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/restart_program.html for details.

# REST PATH: POST /system/cmd/save_state_information
# Causes Naemon to save all current monitoring status information to the state retention file. Normally, state retention
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/save_state_information.html for details.

# REST PATH: POST /system/cmd/shutdown_process
# Sends the SHUTDOWN_PROCESS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/shutdown_process.html for details.

# REST PATH: POST /system/cmd/shutdown_program
# Shuts down the Naemon process.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/shutdown_program.html for details.

# REST PATH: POST /system/cmd/start_accepting_passive_host_checks
# Sends the START_ACCEPTING_PASSIVE_HOST_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/start_accepting_passive_host_checks.html for details.

# REST PATH: POST /system/cmd/start_accepting_passive_svc_checks
# Sends the START_ACCEPTING_PASSIVE_SVC_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/start_accepting_passive_svc_checks.html for details.

# REST PATH: POST /system/cmd/start_executing_host_checks
# Sends the START_EXECUTING_HOST_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/start_executing_host_checks.html for details.

# REST PATH: POST /system/cmd/start_executing_svc_checks
# Sends the START_EXECUTING_SVC_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/start_executing_svc_checks.html for details.

# REST PATH: POST /system/cmd/start_obsessing_over_host_checks
# Sends the START_OBSESSING_OVER_HOST_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/start_obsessing_over_host_checks.html for details.

# REST PATH: POST /system/cmd/start_obsessing_over_svc_checks
# Sends the START_OBSESSING_OVER_SVC_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/start_obsessing_over_svc_checks.html for details.

# REST PATH: POST /system/cmd/stop_accepting_passive_host_checks
# Sends the STOP_ACCEPTING_PASSIVE_HOST_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/stop_accepting_passive_host_checks.html for details.

# REST PATH: POST /system/cmd/stop_accepting_passive_svc_checks
# Sends the STOP_ACCEPTING_PASSIVE_SVC_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/stop_accepting_passive_svc_checks.html for details.

# REST PATH: POST /system/cmd/stop_executing_host_checks
# Sends the STOP_EXECUTING_HOST_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/stop_executing_host_checks.html for details.

# REST PATH: POST /system/cmd/stop_executing_svc_checks
# Sends the STOP_EXECUTING_SVC_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/stop_executing_svc_checks.html for details.

# REST PATH: POST /system/cmd/stop_obsessing_over_host_checks
# Sends the STOP_OBSESSING_OVER_HOST_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/stop_obsessing_over_host_checks.html for details.

# REST PATH: POST /system/cmd/stop_obsessing_over_svc_checks
# Sends the STOP_OBSESSING_OVER_SVC_CHECKS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/stop_obsessing_over_svc_checks.html for details.

{"contactgroups":{"disable_contactgroup_host_notifications":{"args":[],"docs":"Disables host notifications for all contacts in a particular contactgroup.","name":"disable_contactgroup_host_notifications","required":[]},
  "disable_contactgroup_svc_notifications":{"args":[],"docs":"Disables service notifications for all contacts in a particular contactgroup.","name":"disable_contactgroup_svc_notifications","required":[]},
  "enable_contactgroup_host_notifications":{"args":[],"docs":"Enables host notifications for all contacts in a particular contactgroup.","name":"enable_contactgroup_host_notifications","required":[]},
  "enable_contactgroup_svc_notifications":{"args":[],"docs":"Enables service notifications for all contacts in a particular contactgroup.","name":"enable_contactgroup_svc_notifications","required":[]}
},
  "contacts":{"change_contact_host_notification_timeperiod":{"args":["timeperiod"],"docs":"Changes the host notification timeperiod for a particular contact to what is specified by the 'notification_timeperiod' option. The 'notification_timeperiod' option should be the short name of the timeperiod that is to be used as the contact's host notification timeperiod. The timeperiod must have been configured in Naemon before it was last (re)started.","name":"change_contact_host_notification_timeperiod","required":["timeperiod"]},
  "change_contact_modattr":{"args":["value"],"docs":"This command changes the modified attributes value for the specified contact. Modified attributes values are used by Naemon to determine which object properties should be retained across program restarts. Thus, modifying the value of the attributes can affect data retention. This is an advanced option and should only be used by people who are intimately familiar with the data retention logic in Naemon.","name":"change_contact_modattr","required":["value"]},
  "change_contact_modhattr":{"args":["value"],"docs":"This command changes the modified host attributes value for the specified contact. Modified attributes values are used by Naemon to determine which object properties should be retained across program restarts. Thus, modifying the value of the attributes can affect data retention. This is an advanced option and should only be used by people who are intimately familiar with the data retention logic in Naemon.","name":"change_contact_modhattr","required":["value"]},
  "change_contact_modsattr":{"args":["value"],"docs":"This command changes the modified service attributes value for the specified contact. Modified attributes values are used by Naemon to determine which object properties should be retained across program restarts. Thus, modifying the value of the attributes can affect data retention. This is an advanced option and should only be used by people who are intimately familiar with the data retention logic in Naemon.","name":"change_contact_modsattr","required":["value"]},
  "change_contact_svc_notification_timeperiod":{"args":["timeperiod"],"docs":"Changes the service notification timeperiod for a particular contact to what is specified by the 'notification_timeperiod' option. The 'notification_timeperiod' option should be the short name of the timeperiod that is to be used as the contact's service notification timeperiod. The timeperiod must have been configured in Naemon before it was last (re)started.","name":"change_contact_svc_notification_timeperiod","required":["timeperiod"]},
  "change_custom_contact_var":{"args":["name","value"],"docs":"Changes the value of a custom contact variable.","name":"change_custom_contact_var","required":["name","value"]},
  "disable_contact_host_notifications":{"args":[],"docs":"Disables host notifications for a particular contact.","name":"disable_contact_host_notifications","required":[]},
  "disable_contact_svc_notifications":{"args":[],"docs":"Disables service notifications for a particular contact.","name":"disable_contact_svc_notifications","required":[]},
  "enable_contact_host_notifications":{"args":[],"docs":"Enables host notifications for a particular contact.","name":"enable_contact_host_notifications","required":[]},
  "enable_contact_svc_notifications":{"args":[],"docs":"Disables service notifications for a particular contact.","name":"enable_contact_svc_notifications","required":[]}
},
"hostgroups":{
  "disable_hostgroup_host_checks":{"args":[],"name":"disable_hostgroup_host_checks","nr":"68","required":[]},
  "disable_hostgroup_host_notifications":{"args":[],"name":"disable_hostgroup_host_notifications","nr":"66","required":[]},
  "disable_hostgroup_passive_host_checks":{"args":[],"docs":"Disables passive checks for all hosts in a particular hostgroup.","name":"disable_hostgroup_passive_host_checks","required":[]},
  "disable_hostgroup_passive_svc_checks":{"args":[],"docs":"Disables passive checks for all services associated with hosts in a particular hostgroup.","name":"disable_hostgroup_passive_svc_checks","required":[]},
  "disable_hostgroup_svc_checks":{"args":[],"name":"disable_hostgroup_svc_checks","nr":"68","required":[]},
  "disable_hostgroup_svc_notifications":{"args":[],"name":"disable_hostgroup_svc_notifications","nr":"64","required":[]},
  "enable_hostgroup_host_checks":{"args":[],"name":"enable_hostgroup_host_checks","nr":"67","required":[]},
  "enable_hostgroup_host_notifications":{"args":[],"name":"enable_hostgroup_host_notifications","nr":"65","required":[]},
  "enable_hostgroup_passive_host_checks":{"args":[],"docs":"Enables passive checks for all hosts in a particular hostgroup.","name":"enable_hostgroup_passive_host_checks","required":[]},
  "enable_hostgroup_passive_svc_checks":{"args":[],"docs":"Enables passive checks for all services associated with hosts in a particular hostgroup.","name":"enable_hostgroup_passive_svc_checks","required":[]},
  "enable_hostgroup_svc_checks":{"args":[],"name":"enable_hostgroup_svc_checks","nr":"67","required":[]},
  "enable_hostgroup_svc_notifications":{"args":[],"name":"enable_hostgroup_svc_notifications","nr":"63","required":[]},
  "schedule_hostgroup_host_downtime":{"args":["start_time","end_time","fixed","triggered_by","duration","comment_author","comment_data"],"name":"schedule_hostgroup_host_downtime","nr":"85","required":["comment_data"]},
  "schedule_hostgroup_svc_downtime":{"args":["start_time","end_time","fixed","triggered_by","duration","comment_author","comment_data"],"name":"schedule_hostgroup_svc_downtime","nr":"85","required":["comment_data"]}
},
"hosts":{
  "acknowledge_host_problem":{"args":["sticky_ack","send_notification","persistent_comment","comment_author","comment_data"],"name":"acknowledge_host_problem","nr":"33","required":["comment_data"]},
  "acknowledge_host_problem_expire":{"args":["sticky_ack","send_notification","persistent_comment","end_time","comment_author","comment_data"],"name":"acknowledge_host_problem_expire","nr":"33","required":["comment_data"]},
  "add_host_comment":{"args":["persistent_comment","comment_author","comment_data"],"name":"add_host_comment","nr":"1","required":["comment_data"]},
  "change_custom_host_var":{"args":["name","value"],"docs":"Changes the value of a custom host variable.","name":"change_custom_host_var","required":["name","value"]},
  "change_host_check_command":{"args":["checkcommand"],"docs":"Changes the check command for a particular host to be that specified by the 'check_command' option. The 'check_command' option specifies the short name of the command that should be used as the new host check command. The command must have been configured in Naemon before it was last (re)started.","name":"change_host_check_command","required":["checkcommand"]},
  "change_host_check_timeperiod":{"args":["timeperiod"],"docs":"Changes the valid check period for the specified host.","name":"change_host_check_timeperiod","required":["timeperiod"]},
  "change_host_event_handler":{"args":["eventhandler"],"docs":"Changes the event handler command for a particular host to be that specified by the 'event_handler_command' option. The 'event_handler_command' option specifies the short name of the command that should be used as the new host event handler. The command must have been configured in Naemon before it was last (re)started.","name":"change_host_event_handler","required":["eventhandler"]},
  "change_host_modattr":{"args":[],"name":"change_host_modattr","nr":"154","required":[]},
  "change_host_notification_timeperiod":{"args":["timeperiod"],"docs":"Changes the host notification timeperiod to what is specified by the 'notification_timeperiod' option. The 'notification_timeperiod' option should be the short name of the timeperiod that is to be used as the service notification timeperiod. The timeperiod must have been configured in Naemon before it was last (re)started.","name":"change_host_notification_timeperiod","required":["timeperiod"]},
  "change_max_host_check_attempts":{"args":["interval"],"docs":"Changes the maximum number of check attempts (retries) for a particular host.","name":"change_max_host_check_attempts","required":["interval"]},
  "change_normal_host_check_interval":{"args":["interval"],"docs":"Changes the normal (regularly scheduled) check interval for a particular host.","name":"change_normal_host_check_interval","required":["interval"]},
  "change_retry_host_check_interval":{"args":["interval"],"docs":"Changes the retry check interval for a particular host.","name":"change_retry_host_check_interval","required":["interval"]},
  "del_active_host_downtimes":{"args":[],"docs":"Removes all currently active downtimes for this host.","name":"del_active_host_downtimes","required":[]},
  "del_all_host_comments":{"args":[],"name":"del_all_host_comments","nr":"20","required":[]},
  "delay_host_notification":{"args":["notification_time"],"name":"delay_host_notification","nr":"10","required":["notification_time"]},
  "disable_all_notifications_beyond_host":{"args":[],"name":"disable_all_notifications_beyond_host","nr":"27","required":[]},
  "disable_host_and_child_notifications":{"args":[],"name":"disable_host_and_child_notifications","nr":"25","required":[],"requires_comment":1},
  "disable_host_check":{"args":[],"name":"disable_host_check","nr":"48","required":[],"requires_comment":1},
  "disable_host_event_handler":{"args":[],"name":"disable_host_event_handler","nr":"44","required":[],"requires_comment":1},
  "disable_host_flap_detection":{"args":[],"name":"disable_host_flap_detection","nr":"58","required":[]},
  "disable_host_notifications":{"args":[],"name":"disable_host_notifications","nr":"29","required":[],"requires_comment":1},
  "disable_host_svc_checks":{"args":[],"name":"disable_host_svc_checks","nr":"16","required":[],"requires_comment":1},
  "disable_host_svc_notifications":{"args":[],"name":"disable_host_svc_notifications","nr":"29","required":[],"requires_comment":1},
  "disable_passive_host_checks":{"args":[],"name":"disable_passive_host_checks","nr":"93","required":[]},
  "enable_all_notifications_beyond_host":{"args":[],"name":"enable_all_notifications_beyond_host","nr":"26","required":[]},
  "enable_host_and_child_notifications":{"args":[],"name":"enable_host_and_child_notifications","nr":"24","required":[]},
  "enable_host_check":{"args":[],"name":"enable_host_check","nr":"47","required":[]},
  "enable_host_event_handler":{"args":[],"name":"enable_host_event_handler","nr":"43","required":[]},
  "enable_host_flap_detection":{"args":[],"name":"enable_host_flap_detection","nr":"57","required":[]},
  "enable_host_notifications":{"args":[],"name":"enable_host_notifications","nr":"28","required":[]},
  "enable_host_svc_checks":{"args":[],"name":"enable_host_svc_checks","nr":"15","required":[]},
  "enable_host_svc_notifications":{"args":[],"name":"enable_host_svc_notifications","nr":"28","required":[]},
  "enable_passive_host_checks":{"args":[],"name":"enable_passive_host_checks","nr":"92","required":[]},
  "process_host_check_result":{"args":["plugin_state","plugin_output","performance_data"],"name":"process_host_check_result","nr":"87","required":["plugin_output"]},
  "remove_host_acknowledgement":{"args":[],"name":"remove_host_acknowledgement","nr":"51","required":[]},
  "schedule_and_propagate_host_downtime":{"args":["start_time","end_time","fixed","triggered_by","duration","comment_author","comment_data"],"name":"schedule_and_propagate_host_downtime","nr":"55","required":["comment_data"]},
  "schedule_and_propagate_triggered_host_downtime":{"args":["start_time","end_time","fixed","triggered_by","duration","comment_author","comment_data"],"name":"schedule_and_propagate_triggered_host_downtime","nr":"55","required":["comment_data"]},
  "schedule_forced_host_check":{"args":["start_time"],"name":"schedule_forced_host_check","nr":"96","required":[]},
  "schedule_forced_host_svc_checks":{"args":["start_time"],"name":"schedule_forced_host_svc_checks","nr":"17","required":[]},
  "schedule_host_check":{"args":["start_time"],"name":"schedule_host_check","nr":"96","required":[]},
  "schedule_host_downtime":{"args":["start_time","end_time","fixed","triggered_by","duration","comment_author","comment_data"],"name":"schedule_host_downtime","nr":"55","required":["comment_data"]},
  "schedule_host_svc_checks":{"args":["start_time"],"name":"schedule_host_svc_checks","nr":"17","required":[]},
  "schedule_host_svc_downtime":{"args":["start_time","end_time","fixed","triggered_by","duration","comment_author","comment_data"],"name":"schedule_host_svc_downtime","nr":"86","required":["comment_data"]},
  "send_custom_host_notification":{"args":["options","comment_author","comment_data"],"name":"send_custom_host_notification","nr":"159","required":["comment_data"]},
  "set_host_notification_number":{"args":["number"],"docs":"Sets the current notification number for a particular host. A value of 0 indicates that no notification has yet been sent for the current host problem. Useful for forcing an escalation (based on notification number) or replicating notification information in redundant monitoring environments. Notification numbers greater than zero have no noticeable affect on the notification process if the host is currently in an UP state.","name":"set_host_notification_number","required":["number"]},
  "start_obsessing_over_host":{"args":[],"name":"start_obsessing_over_host","nr":"101","required":[]},
  "stop_obsessing_over_host":{"args":[],"name":"stop_obsessing_over_host","nr":"102","required":[]}
},
"servicegroups":{
  "disable_servicegroup_host_checks":{"args":[],"name":"disable_servicegroup_host_checks","nr":"114","required":[]},
  "disable_servicegroup_host_notifications":{"args":[],"name":"disable_servicegroup_host_notifications","nr":"112","required":[]},
  "disable_servicegroup_passive_host_checks":{"args":[],"docs":"Disables the acceptance and processing of passive checks for all hosts that have services that are members of a particular service group.","name":"disable_servicegroup_passive_host_checks","required":[]},
  "disable_servicegroup_passive_svc_checks":{"args":[],"docs":"Disables the acceptance and processing of passive checks for all services in a particular servicegroup.","name":"disable_servicegroup_passive_svc_checks","required":[]},
  "disable_servicegroup_svc_checks":{"args":[],"name":"disable_servicegroup_svc_checks","nr":"114","required":[]},
  "disable_servicegroup_svc_notifications":{"args":[],"name":"disable_servicegroup_svc_notifications","nr":"110","required":[]},
  "enable_servicegroup_host_checks":{"args":[],"name":"enable_servicegroup_host_checks","nr":"113","required":[]},
  "enable_servicegroup_host_notifications":{"args":[],"name":"enable_servicegroup_host_notifications","nr":"111","required":[]},
  "enable_servicegroup_passive_host_checks":{"args":[],"docs":"Enables the acceptance and processing of passive checks for all hosts that have services that are members of a particular service group.","name":"enable_servicegroup_passive_host_checks","required":[]},
  "enable_servicegroup_passive_svc_checks":{"args":[],"docs":"Enables the acceptance and processing of passive checks for all services in a particular servicegroup.","name":"enable_servicegroup_passive_svc_checks","required":[]},
  "enable_servicegroup_svc_checks":{"args":[],"name":"enable_servicegroup_svc_checks","nr":"113","required":[]},
  "enable_servicegroup_svc_notifications":{"args":[],"name":"enable_servicegroup_svc_notifications","nr":"109","required":[]},
  "schedule_servicegroup_host_downtime":{"args":["start_time","end_time","fixed","triggered_by","duration","comment_author","comment_data"],"name":"schedule_servicegroup_host_downtime","nr":"122","required":["comment_data"]},
  "schedule_servicegroup_svc_downtime":{"args":["start_time","end_time","fixed","triggered_by","duration","comment_author","comment_data"],"name":"schedule_servicegroup_svc_downtime","nr":"122","required":["comment_data"]}
},
"services":{
  "acknowledge_svc_problem":{"args":["sticky_ack","send_notification","persistent_comment","comment_author","comment_data"],"name":"acknowledge_svc_problem","nr":"34","required":["comment_data"]},
  "acknowledge_svc_problem_expire":{"args":["sticky_ack","send_notification","persistent_comment","end_time","comment_author","comment_data"],"name":"acknowledge_svc_problem_expire","nr":"34","required":["comment_data"]},
  "add_svc_comment":{"args":["persistent_comment","comment_author","comment_data"],"name":"add_svc_comment","nr":"3","required":["comment_data"]},
  "change_custom_svc_var":{"args":["name","value"],"docs":"Changes the value of a custom service variable.","name":"change_custom_svc_var","required":["name","value"]},
  "change_max_svc_check_attempts":{"args":["attempts"],"docs":"Changes the maximum number of check attempts (retries) for a particular service.","name":"change_max_svc_check_attempts","required":["attempts"]},
  "change_normal_svc_check_interval":{"args":["interval"],"docs":"Changes the normal (regularly scheduled) check interval for a particular service","name":"change_normal_svc_check_interval","required":["interval"]},
  "change_retry_svc_check_interval":{"args":["interval"],"docs":"Changes the retry check interval for a particular service.","name":"change_retry_svc_check_interval","required":["interval"]},
  "change_svc_check_command":{"args":["checkcommand"],"docs":"Changes the check command for a particular service to be that specified by the 'check_command' option. The 'check_command' option specifies the short name of the command that should be used as the new service check command. The command must have been configured in Naemon before it was last (re)started.","name":"change_svc_check_command","required":["checkcommand"]},
  "change_svc_check_timeperiod":{"args":["timeperiod"],"docs":"Changes the check timeperiod for a particular service to what is specified by the 'check_timeperiod' option. The 'check_timeperiod' option should be the short name of the timeperod that is to be used as the service check timeperiod. The timeperiod must have been configured in Naemon before it was last (re)started.","name":"change_svc_check_timeperiod","required":["timeperiod"]},
  "change_svc_event_handler":{"args":["eventhandler"],"docs":"Changes the event handler command for a particular service to be that specified by the 'event_handler_command' option. The 'event_handler_command' option specifies the short name of the command that should be used as the new service event handler. The command must have been configured in Naemon before it was last (re)started.","name":"change_svc_event_handler","required":["eventhandler"]},
  "change_svc_modattr":{"args":[],"name":"change_svc_modattr","nr":"155","required":[]},
  "change_svc_notification_timeperiod":{"args":["timeperiod"],"docs":"Changes the service notification timeperiod to what is specified by the 'notification_timeperiod' option. The 'notification_timeperiod' option should be the short name of the timeperiod that is to be used as the service notification timeperiod. The timeperiod must have been configured in Naemon before it was last (re)started.","name":"change_svc_notification_timeperiod","required":["timeperiod"]},
  "del_active_service_downtimes":{"args":[],"docs":"Removes all currently active downtimes for this service.","name":"del_active_service_downtimes","required":[]},
  "del_all_svc_comments":{"args":[],"name":"del_all_svc_comments","nr":"21","required":[]},
  "delay_svc_notification":{"args":["notification_time"],"name":"delay_svc_notification","nr":"9","required":["notification_time"]},
  "disable_passive_svc_checks":{"args":[],"name":"disable_passive_svc_checks","nr":"40","required":[]},
  "disable_svc_check":{"args":[],"name":"disable_svc_check","nr":"6","required":[],"requires_comment":1},
  "disable_svc_event_handler":{"args":[],"name":"disable_svc_event_handler","nr":"46","required":[],"requires_comment":1},
  "disable_svc_flap_detection":{"args":[],"name":"disable_svc_flap_detection","nr":"60","required":[]},
  "disable_svc_notifications":{"args":[],"name":"disable_svc_notifications","nr":"23","required":[],"requires_comment":1},
  "enable_passive_svc_checks":{"args":[],"name":"enable_passive_svc_checks","nr":"39","required":[]},
  "enable_svc_check":{"args":[],"name":"enable_svc_check","nr":"5","required":[]},
  "enable_svc_event_handler":{"args":[],"name":"enable_svc_event_handler","nr":"45","required":[]},
  "enable_svc_flap_detection":{"args":[],"name":"enable_svc_flap_detection","nr":"59","required":[]},
  "enable_svc_notifications":{"args":[],"name":"enable_svc_notifications","nr":"22","required":[]},
  "process_service_check_result":{"args":["plugin_state","plugin_output","performance_data"],"name":"process_service_check_result","nr":"30","required":["plugin_output"]},
  "remove_svc_acknowledgement":{"args":[],"name":"remove_svc_acknowledgement","nr":"52","required":[]},
  "schedule_forced_svc_check":{"args":["start_time"],"name":"schedule_forced_svc_check","nr":"7","required":[]},
  "schedule_svc_check":{"args":["start_time"],"name":"schedule_svc_check","nr":"7","required":[]},
  "schedule_svc_downtime":{"args":["start_time","end_time","fixed","triggered_by","duration","comment_author","comment_data"],"name":"schedule_svc_downtime","nr":"56","required":["comment_data"]},
  "send_custom_svc_notification":{"args":["options","comment_author","comment_data"],"name":"send_custom_svc_notification","nr":"160","required":["comment_data"]},
  "set_svc_notification_number":{"args":["number"],"docs":"Sets the current notification number for a particular service. A value of 0 indicates that no notification has yet been sent for the current service problem. Useful for forcing an escalation (based on notification number) or replicating notification information in redundant monitoring environments. Notification numbers greater than zero have no noticeable affect on the notification process if the service is currently in an OK state.","name":"set_svc_notification_number","required":["number"]},
  "start_obsessing_over_svc":{"args":[],"name":"start_obsessing_over_svc","nr":"99","required":[]},
  "stop_obsessing_over_svc":{"args":[],"name":"stop_obsessing_over_svc","nr":"100","required":[]}
},
"system":{
  "change_global_host_event_handler":{"args":["eventhandler"],"docs":"Changes the global host event handler command to be that specified by the 'event_handler_command' option. The 'event_handler_command' option specifies the short name of the command that should be used as the new host event handler. The command must have been configured in Naemon before it was last (re)started.","name":"change_global_host_event_handler","required":["eventhandler"]},
  "change_global_svc_event_handler":{"args":["eventhandler"],"docs":"Changes the global service event handler command to be that specified by the 'event_handler_command' option. The 'event_handler_command' option specifies the short name of the command that should be used as the new service event handler. The command must have been configured in Naemon before it was last (re)started.","name":"change_global_svc_event_handler","required":["eventhandler"]},
  "del_downtime_by_host_name":{"args":["hostname","service_desc","start_time","comment"],"docs":"This command deletes all downtimes matching the specified filters.","name":"del_downtime_by_host_name","required":[]},
  "del_downtime_by_hostgroup_name":{"args":["hostgroup_name","hostname","service_desc","start_time","comment"],"docs":"This command deletes all downtimes matching the specified filters.","name":"del_downtime_by_hostgroup_name","required":[]},
  "del_downtime_by_start_time_comment":{"args":["start_time","comment"],"docs":"This command deletes all downtimes matching the specified filters.","name":"del_downtime_by_start_time_comment","required":[]},
  "del_host_comment":{"args":["comment_id"],"name":"del_host_comment","nr":"2","required":["comment_id"]},
  "del_host_downtime":{"args":["downtime_id"],"name":"del_host_downtime","nr":"78","required":["downtime_id"]},
  "del_svc_comment":{"args":["comment_id"],"name":"del_svc_comment","nr":"4","required":["comment_id"]},
  "del_svc_downtime":{"args":["downtime_id"],"name":"del_svc_downtime","nr":"79","required":["downtime_id"]},
  "disable_event_handlers":{"args":[],"name":"disable_event_handlers","nr":"42","required":[]},
  "disable_flap_detection":{"args":[],"name":"disable_flap_detection","nr":"62","required":[]},
  "disable_host_freshness_checks":{"args":[],"docs":"Disables freshness checks of all hosts on a program-wide basis.","name":"disable_host_freshness_checks","required":[]},
  "disable_notifications":{"args":[],"name":"disable_notifications","nr":"11","required":[]},
  "disable_performance_data":{"args":[],"name":"disable_performance_data","nr":"83","required":[]},
  "disable_service_freshness_checks":{"args":[],"docs":"Disables freshness checks of all services on a program-wide basis.","name":"disable_service_freshness_checks","required":[]},
  "enable_event_handlers":{"args":[],"name":"enable_event_handlers","nr":"41","required":[]},
  "enable_flap_detection":{"args":[],"name":"enable_flap_detection","nr":"61","required":[]},
  "enable_host_freshness_checks":{"args":[],"docs":"Enables freshness checks of all services on a program-wide basis. Individual services that have freshness checks disabled will not be checked for freshness.","name":"enable_host_freshness_checks","required":[]},
  "enable_notifications":{"args":[],"name":"enable_notifications","nr":"12","required":[]},
  "enable_performance_data":{"args":[],"name":"enable_performance_data","nr":"82","required":[]},
  "enable_service_freshness_checks":{"args":[],"docs":"Enables freshness checks of all services on a program-wide basis. Individual services that have freshness checks disabled will not be checked for freshness.","name":"enable_service_freshness_checks","required":[]},
  "read_state_information":{"args":[],"docs":"Causes Naemon to load all current monitoring status information from the state retention file. Normally, state retention information is loaded when the Naemon process starts up and before it starts monitoring. WARNING: This command will cause Naemon to discard all current monitoring status information and use the information stored in state retention file! Use with care.","name":"read_state_information","required":[]},
  "restart_process":{"args":[],"name":"restart_process","nr":"13","required":[]},
  "restart_program":{"args":[],"docs":"Restarts the Naemon process.","name":"restart_program","required":[]},
  "save_state_information":{"args":[],"docs":"Causes Naemon to save all current monitoring status information to the state retention file. Normally, state retention","name":"save_state_information","required":[]},
  "shutdown_process":{"args":[],"name":"shutdown_process","nr":"14","required":[]},
  "shutdown_program":{"args":[],"docs":"Shuts down the Naemon process.","name":"shutdown_program","required":[]},
  "start_accepting_passive_host_checks":{"args":[],"name":"start_accepting_passive_host_checks","nr":"90","required":[]},
  "start_accepting_passive_svc_checks":{"args":[],"name":"start_accepting_passive_svc_checks","nr":"37","required":[]},
  "start_executing_host_checks":{"args":[],"name":"start_executing_host_checks","nr":"88","required":[]},
  "start_executing_svc_checks":{"args":[],"name":"start_executing_svc_checks","nr":"35","required":[]},
  "start_obsessing_over_host_checks":{"args":[],"name":"start_obsessing_over_host_checks","nr":"94","required":[]},
  "start_obsessing_over_svc_checks":{"args":[],"name":"start_obsessing_over_svc_checks","nr":"49","required":[]},
  "stop_accepting_passive_host_checks":{"args":[],"name":"stop_accepting_passive_host_checks","nr":"91","required":[]},
  "stop_accepting_passive_svc_checks":{"args":[],"name":"stop_accepting_passive_svc_checks","nr":"38","required":[]},
  "stop_executing_host_checks":{"args":[],"name":"stop_executing_host_checks","nr":"89","required":[]},
  "stop_executing_svc_checks":{"args":[],"name":"stop_executing_svc_checks","nr":"36","required":[]},
  "stop_obsessing_over_host_checks":{"args":[],"name":"stop_obsessing_over_host_checks","nr":"95","required":[]},
  "stop_obsessing_over_svc_checks":{"args":[],"name":"stop_obsessing_over_svc_checks","nr":"50","required":[]}}
}