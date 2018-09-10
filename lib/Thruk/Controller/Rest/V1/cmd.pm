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
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/(hosts?|hostgroups?|servicegroups?)/([^/]+)/cmd/([^/]+)%mx, \&_rest_get_external_command);
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/(services?)/([^/]+)/([^/]+)/cmd/([^/]+)%mx,                 \&_rest_get_external_command);
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/(system|core|)/cmd/([^/]+)%mx,                              \&_rest_get_external_command);
sub _rest_get_external_command {
    my($c, undef, $type, @args) = @_;
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
    my($cmd, $cmd_name, $name, $description, @cmd_args);
    $type =~ s/s$//gmx;
    if($type eq 'core') { $type = 'system'; }
    if($type =~ m/^(host|hostgroup|servicegroup)$/mx) {
        $name     = shift @args;
        $cmd_name = shift @args;
        $cmd      = $cmd_data->{$type.'s'}->{$cmd_name};
        push @cmd_args, $name;

        if(!$c->check_cmd_permissions($type, $name)) {
            return({ 'message' => 'you are not allowed to run this command', 'description' => 'you don\' have command permissions for '.$type.' '.$name, code => 403 });
        }
    }
    elsif($type =~ m/^(service)$/mx) {
        $name        = shift @args;
        $description = shift @args;
        $cmd_name    = shift @args;
        $cmd         = $cmd_data->{$type.'s'}->{$cmd_name};
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
            if($arg eq 'comment_author') { $val = $c->stash->{'remote_user'}; }
            if($arg eq 'fixed')          { $val = 1; }
            if($arg eq 'duration')       { $val = 0; }
            if($arg eq 'triggered_by')   { $val = 0; }
            if($arg eq 'start_time')     { $val = time(); }
            if($arg eq 'end_time')       { $val = time() + $c->config->{'downtime_duration'}; }
        }
        # still not defined?
        if(!defined $val) {
            if($required->{$arg}) {
                return({ 'message' => 'missing argument: '.$arg, 'description' => $arg.' is a required argument', code => 400 });
            }
            $val = "";
        }
        if($arg eq 'start_time' || $arg eq 'end_time') {
            $val = Thruk::Utils::parse_date( $c, $val);
        }
        push @cmd_args, $val;
    }

    my $cmd_line = "COMMAND [".time()."] ".uc($cmd->{'name'});
    if(scalar @cmd_args > 0) {
        $cmd_line .= ';'.join(';', @cmd_args);
    }
    my $cmd_list = [$cmd_line];

    if($cmd->{'requires_comment'}) {
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
    my $commands = {};
    for my $b (@{$backends}) {
        $commands->{$b} = dclone($cmd_list); # must be cloned, otherwise add_remove_comments_commands_from_disabled_commands appends command multiple times
    }
    Thruk::Controller::cmd::add_remove_comments_commands_from_disabled_commands($c, $commands, $cmd->{'nr'}, $name, $description);
    Thruk::Controller::cmd::bulk_send($c, $commands);
    return({ 'message' => 'Command successfully submitted' });
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

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

# REST PATH: POST /hosts/<name>/cmd/change_host_modattr
# Sends the CHANGE_HOST_MODATTR command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_host_modattr.html for details.

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

# REST PATH: POST /services/<host>/<service>/cmd/change_svc_modattr
# Sends the CHANGE_SVC_MODATTR command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/change_svc_modattr.html for details.

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
#   * duration
#   * comment_author
#
# See http://www.naemon.org/documentation/developer/externalcommands/schedule_servicegroup_svc_downtime.html for details.

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

# REST PATH: POST /system/cmd/disable_failure_prediction
# Sends the DISABLE_FAILURE_PREDICTION command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_failure_prediction.html for details.

# REST PATH: POST /system/cmd/disable_flap_detection
# Sends the DISABLE_FLAP_DETECTION command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/disable_flap_detection.html for details.

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

# REST PATH: POST /system/cmd/enable_event_handlers
# Sends the ENABLE_EVENT_HANDLERS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_event_handlers.html for details.

# REST PATH: POST /system/cmd/enable_failure_prediction
# Sends the ENABLE_FAILURE_PREDICTION command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_failure_prediction.html for details.

# REST PATH: POST /system/cmd/enable_flap_detection
# Sends the ENABLE_FLAP_DETECTION command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/enable_flap_detection.html for details.

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

# REST PATH: POST /system/cmd/restart_process
# Sends the RESTART_PROCESS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/restart_process.html for details.

# REST PATH: POST /system/cmd/shutdown_process
# Sends the SHUTDOWN_PROCESS command.
#
# This command does not require any arguments.
#
# See http://www.naemon.org/documentation/developer/externalcommands/shutdown_process.html for details.

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

{"hostgroups":{
  "disable_hostgroup_host_checks":{"args":[],"name":"disable_hostgroup_host_checks","nr":"68","required":[]},
  "disable_hostgroup_host_notifications":{"args":[],"name":"disable_hostgroup_host_notifications","nr":"66","required":[]},
  "disable_hostgroup_svc_checks":{"args":[],"name":"disable_hostgroup_svc_checks","nr":"68","required":[]},
  "disable_hostgroup_svc_notifications":{"args":[],"name":"disable_hostgroup_svc_notifications","nr":"64","required":[]},
  "enable_hostgroup_host_checks":{"args":[],"name":"enable_hostgroup_host_checks","nr":"67","required":[]},
  "enable_hostgroup_host_notifications":{"args":[],"name":"enable_hostgroup_host_notifications","nr":"65","required":[]},
  "enable_hostgroup_svc_checks":{"args":[],"name":"enable_hostgroup_svc_checks","nr":"67","required":[]},
  "enable_hostgroup_svc_notifications":{"args":[],"name":"enable_hostgroup_svc_notifications","nr":"63","required":[]},
  "schedule_hostgroup_host_downtime":{"args":["start_time","end_time","fixed","duration","comment_author","comment_data"],"name":"schedule_hostgroup_host_downtime","nr":"85","required":["comment_data"]},
  "schedule_hostgroup_svc_downtime":{"args":["start_time","end_time","fixed","duration","comment_author","comment_data"],"name":"schedule_hostgroup_svc_downtime","nr":"85","required":["comment_data"]}
},
"hosts":{
  "acknowledge_host_problem":{"args":["sticky_ack","send_notification","persistent_comment","comment_author","comment_data"],"name":"acknowledge_host_problem","nr":"33","required":["comment_data"]},
  "acknowledge_host_problem_expire":{"args":["sticky_ack","send_notification","persistent_comment","end_time","comment_author","comment_data"],"name":"acknowledge_host_problem_expire","nr":"33","required":["comment_data"]},
  "add_host_comment":{"args":["persistent_comment","comment_author","comment_data"],"name":"add_host_comment","nr":"1","required":["comment_data"]},
  "change_host_modattr":{"args":[],"name":"change_host_modattr","nr":"154","required":[]},
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
  "start_obsessing_over_host":{"args":[],"name":"start_obsessing_over_host","nr":"101","required":[]},
  "stop_obsessing_over_host":{"args":[],"name":"stop_obsessing_over_host","nr":"102","required":[]}
},
"servicegroups":{
  "disable_servicegroup_host_checks":{"args":[],"name":"disable_servicegroup_host_checks","nr":"114","required":[]},
  "disable_servicegroup_host_notifications":{"args":[],"name":"disable_servicegroup_host_notifications","nr":"112","required":[]},
  "disable_servicegroup_svc_checks":{"args":[],"name":"disable_servicegroup_svc_checks","nr":"114","required":[]},
  "disable_servicegroup_svc_notifications":{"args":[],"name":"disable_servicegroup_svc_notifications","nr":"110","required":[]},
  "enable_servicegroup_host_checks":{"args":[],"name":"enable_servicegroup_host_checks","nr":"113","required":[]},
  "enable_servicegroup_host_notifications":{"args":[],"name":"enable_servicegroup_host_notifications","nr":"111","required":[]},
  "enable_servicegroup_svc_checks":{"args":[],"name":"enable_servicegroup_svc_checks","nr":"113","required":[]},
  "enable_servicegroup_svc_notifications":{"args":[],"name":"enable_servicegroup_svc_notifications","nr":"109","required":[]},
  "schedule_servicegroup_host_downtime":{"args":["start_time","end_time","fixed","duration","comment_author","comment_data"],"name":"schedule_servicegroup_host_downtime","nr":"122","required":["comment_data"]},
  "schedule_servicegroup_svc_downtime":{"args":["start_time","end_time","fixed","duration","comment_author","comment_data"],"name":"schedule_servicegroup_svc_downtime","nr":"122","required":["comment_data"]}
},
"services":{
  "acknowledge_svc_problem":{"args":["sticky_ack","send_notification","persistent_comment","comment_author","comment_data"],"name":"acknowledge_svc_problem","nr":"34","required":["comment_data"]},
  "acknowledge_svc_problem_expire":{"args":["sticky_ack","send_notification","persistent_comment","end_time","comment_author","comment_data"],"name":"acknowledge_svc_problem_expire","nr":"34","required":["comment_data"]},
  "add_svc_comment":{"args":["persistent_comment","comment_author","comment_data"],"name":"add_svc_comment","nr":"3","required":["comment_data"]},
  "change_svc_modattr":{"args":[],"name":"change_svc_modattr","nr":"155","required":[]},
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
  "start_obsessing_over_svc":{"args":[],"name":"start_obsessing_over_svc","nr":"99","required":[]},
  "stop_obsessing_over_svc":{"args":[],"name":"stop_obsessing_over_svc","nr":"100","required":[]}
},
"system":{
  "del_host_comment":{"args":["comment_id"],"name":"del_host_comment","nr":"2","required":["comment_id"]},
  "del_host_downtime":{"args":["downtime_id"],"name":"del_host_downtime","nr":"78","required":["downtime_id"]},
  "del_svc_comment":{"args":["comment_id"],"name":"del_svc_comment","nr":"4","required":["comment_id"]},
  "del_svc_downtime":{"args":["downtime_id"],"name":"del_svc_downtime","nr":"79","required":["downtime_id"]},
  "disable_event_handlers":{"args":[],"name":"disable_event_handlers","nr":"42","required":[]},
  "disable_failure_prediction":{"args":[],"name":"disable_failure_prediction","nr":"81","required":[]},
  "disable_flap_detection":{"args":[],"name":"disable_flap_detection","nr":"62","required":[]},
  "disable_notifications":{"args":[],"name":"disable_notifications","nr":"11","required":[]},
  "disable_performance_data":{"args":[],"name":"disable_performance_data","nr":"83","required":[]},
  "enable_event_handlers":{"args":[],"name":"enable_event_handlers","nr":"41","required":[]},
  "enable_failure_prediction":{"args":[],"name":"enable_failure_prediction","nr":"80","required":[]},
  "enable_flap_detection":{"args":[],"name":"enable_flap_detection","nr":"61","required":[]},
  "enable_notifications":{"args":[],"name":"enable_notifications","nr":"12","required":[]},
  "enable_performance_data":{"args":[],"name":"enable_performance_data","nr":"82","required":[]},
  "restart_process":{"args":[],"name":"restart_process","nr":"13","required":[]},
  "shutdown_process":{"args":[],"name":"shutdown_process","nr":"14","required":[]},
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