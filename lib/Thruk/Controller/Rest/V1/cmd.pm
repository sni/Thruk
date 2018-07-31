package Thruk::Controller::Rest::V1::cmd;

use strict;
use warnings;
use Cpanel::JSON::XS qw/decode_json/;

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
Thruk::Controller::rest_v1::register_rest_path_v1('POST', qr%^/(system)/cmd/([^/]+)%mx,                                    \&_rest_get_external_command);
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
        $cmd      = $cmd_data->{$type.'s'}->{$cmd_name};
        if(!$c->check_cmd_permissions('system')) {
            return({ 'message' => 'you are not allowed to run system commands', 'description' => 'you don\' have the system_commands role', code => 403 });
        }
    }
    if(!$cmd) {
        return({ 'message' => 'no such command', 'description' => 'there is no command '.$cmd_name.' for type '.$type, code => 404 });
    }

    for my $arg (@{$cmd->{'args'}}) {
        my $val = $c->req->parameters->{$arg};
        if(!defined $val) {
            return({ 'message' => 'missing argument: '.$arg, 'description' => $arg.' is a required argument', code => 400 });
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

    my($backends) = $c->{'db'}->select_backends('send_command');
    my $commands = {};
    for my $b (@{$backends}) {
        $commands->{$b} = [$cmd_line];
    }
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
# sends the ACKNOWLEDGE_HOST_PROBLEM command.
# required arguments: sticky_ack, send_notification, persistent_comment, comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/acknowledge_host_problem.html for details.

# REST PATH: POST /hosts/<name>/cmd/acknowledge_host_problem_expire
# sends the ACKNOWLEDGE_HOST_PROBLEM_EXPIRE command.
# required arguments: sticky_ack, send_notification, persistent_comment, end_time, comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/acknowledge_host_problem_expire.html for details.

# REST PATH: POST /hosts/<name>/cmd/add_host_comment
# sends the ADD_HOST_COMMENT command.
# required arguments: comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/add_host_comment.html for details.

# REST PATH: POST /hosts/<name>/cmd/change_host_modattr
# sends the CHANGE_HOST_MODATTR command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/change_host_modattr.html for details.

# REST PATH: POST /hosts/<name>/cmd/del_all_host_comments
# sends the DEL_ALL_HOST_COMMENTS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/del_all_host_comments.html for details.

# REST PATH: POST /hosts/<name>/cmd/delay_host_notification
# sends the DELAY_HOST_NOTIFICATION command.
# required arguments: notification_time
# see http://www.naemon.org/documentation/developer/externalcommands/delay_host_notification.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_all_notifications_beyond_host
# sends the DISABLE_ALL_NOTIFICATIONS_BEYOND_HOST command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_all_notifications_beyond_host.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_host_check
# sends the DISABLE_HOST_CHECK command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_host_check.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_host_event_handler
# sends the DISABLE_HOST_EVENT_HANDLER command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_host_event_handler.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_host_flap_detection
# sends the DISABLE_HOST_FLAP_DETECTION command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_host_flap_detection.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_host_notifications
# sends the DISABLE_HOST_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_host_notifications.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_host_svc_checks
# sends the DISABLE_HOST_SVC_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_host_svc_checks.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_host_svc_notifications
# sends the DISABLE_HOST_SVC_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_host_svc_notifications.html for details.

# REST PATH: POST /hosts/<name>/cmd/disable_passive_host_checks
# sends the DISABLE_PASSIVE_HOST_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_passive_host_checks.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_all_notifications_beyond_host
# sends the ENABLE_ALL_NOTIFICATIONS_BEYOND_HOST command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_all_notifications_beyond_host.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_host_and_child_notifications
# sends the ENABLE_HOST_AND_CHILD_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_host_and_child_notifications.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_host_check
# sends the ENABLE_HOST_CHECK command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_host_check.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_host_event_handler
# sends the ENABLE_HOST_EVENT_HANDLER command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_host_event_handler.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_host_flap_detection
# sends the ENABLE_HOST_FLAP_DETECTION command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_host_flap_detection.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_host_notifications
# sends the ENABLE_HOST_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_host_notifications.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_host_svc_checks
# sends the ENABLE_HOST_SVC_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_host_svc_checks.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_host_svc_notifications
# sends the ENABLE_HOST_SVC_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_host_svc_notifications.html for details.

# REST PATH: POST /hosts/<name>/cmd/enable_passive_host_checks
# sends the ENABLE_PASSIVE_HOST_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_passive_host_checks.html for details.

# REST PATH: POST /hosts/<name>/cmd/process_host_check_result
# sends the PROCESS_HOST_CHECK_RESULT command.
# required arguments: plugin_state, plugin_output, performance_data
# see http://www.naemon.org/documentation/developer/externalcommands/process_host_check_result.html for details.

# REST PATH: POST /hosts/<name>/cmd/remove_host_acknowledgement
# sends the REMOVE_HOST_ACKNOWLEDGEMENT command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/remove_host_acknowledgement.html for details.

# REST PATH: POST /hosts/<name>/cmd/schedule_and_propagate_host_downtime
# sends the SCHEDULE_AND_PROPAGATE_HOST_DOWNTIME command.
# required arguments: start_time, end_time, fixed, triggered_by, duration, comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/schedule_and_propagate_host_downtime.html for details.

# REST PATH: POST /hosts/<name>/cmd/schedule_and_propagate_triggered_host_downtime
# sends the SCHEDULE_AND_PROPAGATE_TRIGGERED_HOST_DOWNTIME command.
# required arguments: start_time, end_time, fixed, triggered_by, duration, comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/schedule_and_propagate_triggered_host_downtime.html for details.

# REST PATH: POST /hosts/<name>/cmd/schedule_forced_host_check
# sends the SCHEDULE_FORCED_HOST_CHECK command.
# required arguments: start_time
# see http://www.naemon.org/documentation/developer/externalcommands/schedule_forced_host_check.html for details.

# REST PATH: POST /hosts/<name>/cmd/schedule_forced_host_svc_checks
# sends the SCHEDULE_FORCED_HOST_SVC_CHECKS command.
# required arguments: start_time
# see http://www.naemon.org/documentation/developer/externalcommands/schedule_forced_host_svc_checks.html for details.

# REST PATH: POST /hosts/<name>/cmd/schedule_host_check
# sends the SCHEDULE_HOST_CHECK command.
# required arguments: start_time
# see http://www.naemon.org/documentation/developer/externalcommands/schedule_host_check.html for details.

# REST PATH: POST /hosts/<name>/cmd/schedule_host_downtime
# sends the SCHEDULE_HOST_DOWNTIME command.
# required arguments: start_time, end_time, fixed, triggered_by, duration, comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/schedule_host_downtime.html for details.

# REST PATH: POST /hosts/<name>/cmd/schedule_host_svc_checks
# sends the SCHEDULE_HOST_SVC_CHECKS command.
# required arguments: start_time
# see http://www.naemon.org/documentation/developer/externalcommands/schedule_host_svc_checks.html for details.

# REST PATH: POST /hosts/<name>/cmd/schedule_host_svc_downtime
# sends the SCHEDULE_HOST_SVC_DOWNTIME command.
# required arguments: start_time, end_time, fixed, triggered_by, duration, comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/schedule_host_svc_downtime.html for details.

# REST PATH: POST /hosts/<name>/cmd/send_custom_host_notification
# sends the SEND_CUSTOM_HOST_NOTIFICATION command.
# required arguments: options, comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/send_custom_host_notification.html for details.

# REST PATH: POST /hosts/<name>/cmd/start_obsessing_over_host
# sends the START_OBSESSING_OVER_HOST command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/start_obsessing_over_host.html for details.

# REST PATH: POST /hosts/<name>/cmd/stop_obsessing_over_host
# sends the STOP_OBSESSING_OVER_HOST command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/stop_obsessing_over_host.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/acknowledge_svc_problem
# sends the ACKNOWLEDGE_SVC_PROBLEM command.
# required arguments: sticky_ack, send_notification, persistent_comment, comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/acknowledge_svc_problem.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/acknowledge_svc_problem_expire
# sends the ACKNOWLEDGE_SVC_PROBLEM_EXPIRE command.
# required arguments: sticky_ack, send_notification, persistent_comment, end_time, comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/acknowledge_svc_problem_expire.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/add_svc_comment
# sends the ADD_SVC_COMMENT command.
# required arguments: comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/add_svc_comment.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/change_svc_modattr
# sends the CHANGE_SVC_MODATTR command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/change_svc_modattr.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/del_all_svc_comments
# sends the DEL_ALL_SVC_COMMENTS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/del_all_svc_comments.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/delay_svc_notification
# sends the DELAY_SVC_NOTIFICATION command.
# required arguments: notification_time
# see http://www.naemon.org/documentation/developer/externalcommands/delay_svc_notification.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/disable_passive_svc_checks
# sends the DISABLE_PASSIVE_SVC_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_passive_svc_checks.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/disable_svc_check
# sends the DISABLE_SVC_CHECK command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_svc_check.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/disable_svc_event_handler
# sends the DISABLE_SVC_EVENT_HANDLER command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_svc_event_handler.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/disable_svc_flap_detection
# sends the DISABLE_SVC_FLAP_DETECTION command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_svc_flap_detection.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/disable_svc_notifications
# sends the DISABLE_SVC_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_svc_notifications.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/enable_passive_svc_checks
# sends the ENABLE_PASSIVE_SVC_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_passive_svc_checks.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/enable_svc_check
# sends the ENABLE_SVC_CHECK command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_svc_check.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/enable_svc_event_handler
# sends the ENABLE_SVC_EVENT_HANDLER command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_svc_event_handler.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/enable_svc_flap_detection
# sends the ENABLE_SVC_FLAP_DETECTION command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_svc_flap_detection.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/enable_svc_notifications
# sends the ENABLE_SVC_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_svc_notifications.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/process_service_check_result
# sends the PROCESS_SERVICE_CHECK_RESULT command.
# required arguments: plugin_state, plugin_output, performance_data
# see http://www.naemon.org/documentation/developer/externalcommands/process_service_check_result.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/remove_svc_acknowledgement
# sends the REMOVE_SVC_ACKNOWLEDGEMENT command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/remove_svc_acknowledgement.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/schedule_forced_svc_check
# sends the SCHEDULE_FORCED_SVC_CHECK command.
# required arguments: start_time
# see http://www.naemon.org/documentation/developer/externalcommands/schedule_forced_svc_check.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/schedule_svc_check
# sends the SCHEDULE_SVC_CHECK command.
# required arguments: start_time
# see http://www.naemon.org/documentation/developer/externalcommands/schedule_svc_check.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/schedule_svc_downtime
# sends the SCHEDULE_SVC_DOWNTIME command.
# required arguments: start_time, end_time, fixed, triggered_by, duration, comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/schedule_svc_downtime.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/send_custom_svc_notification
# sends the SEND_CUSTOM_SVC_NOTIFICATION command.
# required arguments: options, comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/send_custom_svc_notification.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/start_obsessing_over_svc
# sends the START_OBSESSING_OVER_SVC command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/start_obsessing_over_svc.html for details.

# REST PATH: POST /services/<host>/<service>/cmd/stop_obsessing_over_svc
# sends the STOP_OBSESSING_OVER_SVC command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/stop_obsessing_over_svc.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/disable_hostgroup_host_checks
# sends the DISABLE_HOSTGROUP_HOST_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_hostgroup_host_checks.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/disable_hostgroup_host_notifications
# sends the DISABLE_HOSTGROUP_HOST_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_hostgroup_host_notifications.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/disable_hostgroup_svc_checks
# sends the DISABLE_HOSTGROUP_SVC_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_hostgroup_svc_checks.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/disable_hostgroup_svc_notifications
# sends the DISABLE_HOSTGROUP_SVC_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_hostgroup_svc_notifications.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/enable_hostgroup_host_checks
# sends the ENABLE_HOSTGROUP_HOST_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_hostgroup_host_checks.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/enable_hostgroup_host_notifications
# sends the ENABLE_HOSTGROUP_HOST_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_hostgroup_host_notifications.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/enable_hostgroup_svc_checks
# sends the ENABLE_HOSTGROUP_SVC_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_hostgroup_svc_checks.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/enable_hostgroup_svc_notifications
# sends the ENABLE_HOSTGROUP_SVC_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_hostgroup_svc_notifications.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/schedule_hostgroup_host_downtime
# sends the SCHEDULE_HOSTGROUP_HOST_DOWNTIME command.
# required arguments: start_time, end_time, fixed, duration, comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/schedule_hostgroup_host_downtime.html for details.

# REST PATH: POST /hostgroups/<name>/cmd/schedule_hostgroup_svc_downtime
# sends the SCHEDULE_HOSTGROUP_SVC_DOWNTIME command.
# required arguments: start_time, end_time, fixed, duration, comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/schedule_hostgroup_svc_downtime.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/disable_servicegroup_host_checks
# sends the DISABLE_SERVICEGROUP_HOST_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_servicegroup_host_checks.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/disable_servicegroup_host_notifications
# sends the DISABLE_SERVICEGROUP_HOST_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_servicegroup_host_notifications.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/disable_servicegroup_svc_checks
# sends the DISABLE_SERVICEGROUP_SVC_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_servicegroup_svc_checks.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/disable_servicegroup_svc_notifications
# sends the DISABLE_SERVICEGROUP_SVC_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_servicegroup_svc_notifications.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/enable_servicegroup_host_checks
# sends the ENABLE_SERVICEGROUP_HOST_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_servicegroup_host_checks.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/enable_servicegroup_host_notifications
# sends the ENABLE_SERVICEGROUP_HOST_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_servicegroup_host_notifications.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/enable_servicegroup_svc_checks
# sends the ENABLE_SERVICEGROUP_SVC_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_servicegroup_svc_checks.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/enable_servicegroup_svc_notifications
# sends the ENABLE_SERVICEGROUP_SVC_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_servicegroup_svc_notifications.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/schedule_servicegroup_host_downtime
# sends the SCHEDULE_SERVICEGROUP_HOST_DOWNTIME command.
# required arguments: start_time, end_time, fixed, duration, comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/schedule_servicegroup_host_downtime.html for details.

# REST PATH: POST /servicegroups/<name>/cmd/schedule_servicegroup_svc_downtime
# sends the SCHEDULE_SERVICEGROUP_SVC_DOWNTIME command.
# required arguments: start_time, end_time, fixed, duration, comment_author, comment_data
# see http://www.naemon.org/documentation/developer/externalcommands/schedule_servicegroup_svc_downtime.html for details.

# REST PATH: POST /system/cmd/del_host_comment
# sends the DEL_HOST_COMMENT command.
# required arguments: comment_id
# see http://www.naemon.org/documentation/developer/externalcommands/del_host_comment.html for details.

# REST PATH: POST /system/cmd/del_host_downtime
# sends the DEL_HOST_DOWNTIME command.
# required arguments: downtime_id
# see http://www.naemon.org/documentation/developer/externalcommands/del_host_downtime.html for details.

# REST PATH: POST /system/cmd/del_svc_comment
# sends the DEL_SVC_COMMENT command.
# required arguments: comment_id
# see http://www.naemon.org/documentation/developer/externalcommands/del_svc_comment.html for details.

# REST PATH: POST /system/cmd/del_svc_downtime
# sends the DEL_SVC_DOWNTIME command.
# required arguments: downtime_id
# see http://www.naemon.org/documentation/developer/externalcommands/del_svc_downtime.html for details.

# REST PATH: POST /system/cmd/disable_event_handlers
# sends the DISABLE_EVENT_HANDLERS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_event_handlers.html for details.

# REST PATH: POST /system/cmd/disable_failure_prediction
# sends the DISABLE_FAILURE_PREDICTION command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_failure_prediction.html for details.

# REST PATH: POST /system/cmd/disable_flap_detection
# sends the DISABLE_FLAP_DETECTION command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_flap_detection.html for details.

# REST PATH: POST /system/cmd/disable_notifications
# sends the DISABLE_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_notifications.html for details.

# REST PATH: POST /system/cmd/disable_performance_data
# sends the DISABLE_PERFORMANCE_DATA command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/disable_performance_data.html for details.

# REST PATH: POST /system/cmd/enable_event_handlers
# sends the ENABLE_EVENT_HANDLERS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_event_handlers.html for details.

# REST PATH: POST /system/cmd/enable_failure_prediction
# sends the ENABLE_FAILURE_PREDICTION command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_failure_prediction.html for details.

# REST PATH: POST /system/cmd/enable_flap_detection
# sends the ENABLE_FLAP_DETECTION command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_flap_detection.html for details.

# REST PATH: POST /system/cmd/enable_notifications
# sends the ENABLE_NOTIFICATIONS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_notifications.html for details.

# REST PATH: POST /system/cmd/enable_performance_data
# sends the ENABLE_PERFORMANCE_DATA command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/enable_performance_data.html for details.

# REST PATH: POST /system/cmd/restart_process
# sends the RESTART_PROCESS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/restart_process.html for details.

# REST PATH: POST /system/cmd/shutdown_process
# sends the SHUTDOWN_PROCESS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/shutdown_process.html for details.

# REST PATH: POST /system/cmd/start_accepting_passive_host_checks
# sends the START_ACCEPTING_PASSIVE_HOST_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/start_accepting_passive_host_checks.html for details.

# REST PATH: POST /system/cmd/start_accepting_passive_svc_checks
# sends the START_ACCEPTING_PASSIVE_SVC_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/start_accepting_passive_svc_checks.html for details.

# REST PATH: POST /system/cmd/start_executing_host_checks
# sends the START_EXECUTING_HOST_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/start_executing_host_checks.html for details.

# REST PATH: POST /system/cmd/start_executing_svc_checks
# sends the START_EXECUTING_SVC_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/start_executing_svc_checks.html for details.

# REST PATH: POST /system/cmd/start_obsessing_over_host_checks
# sends the START_OBSESSING_OVER_HOST_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/start_obsessing_over_host_checks.html for details.

# REST PATH: POST /system/cmd/start_obsessing_over_svc_checks
# sends the START_OBSESSING_OVER_SVC_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/start_obsessing_over_svc_checks.html for details.

# REST PATH: POST /system/cmd/stop_accepting_passive_host_checks
# sends the STOP_ACCEPTING_PASSIVE_HOST_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/stop_accepting_passive_host_checks.html for details.

# REST PATH: POST /system/cmd/stop_accepting_passive_svc_checks
# sends the STOP_ACCEPTING_PASSIVE_SVC_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/stop_accepting_passive_svc_checks.html for details.

# REST PATH: POST /system/cmd/stop_executing_host_checks
# sends the STOP_EXECUTING_HOST_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/stop_executing_host_checks.html for details.

# REST PATH: POST /system/cmd/stop_executing_svc_checks
# sends the STOP_EXECUTING_SVC_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/stop_executing_svc_checks.html for details.

# REST PATH: POST /system/cmd/stop_obsessing_over_host_checks
# sends the STOP_OBSESSING_OVER_HOST_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/stop_obsessing_over_host_checks.html for details.

# REST PATH: POST /system/cmd/stop_obsessing_over_svc_checks
# sends the STOP_OBSESSING_OVER_SVC_CHECKS command.
# this command does not require any arguments.
# see http://www.naemon.org/documentation/developer/externalcommands/stop_obsessing_over_svc_checks.html for details.

{"hostgroups":{"disable_hostgroup_host_checks":{"args":[],"name":"disable_hostgroup_host_checks"},"disable_hostgroup_host_notifications":{"args":[],"name":"disable_hostgroup_host_notifications"},"disable_hostgroup_svc_checks":{"args":[],"name":"disable_hostgroup_svc_checks"},"disable_hostgroup_svc_notifications":{"args":[],"name":"disable_hostgroup_svc_notifications"},"enable_hostgroup_host_checks":{"args":[],"name":"enable_hostgroup_host_checks"},"enable_hostgroup_host_notifications":{"args":[],"name":"enable_hostgroup_host_notifications"},"enable_hostgroup_svc_checks":{"args":[],"name":"enable_hostgroup_svc_checks"},"enable_hostgroup_svc_notifications":{"args":[],"name":"enable_hostgroup_svc_notifications"},"schedule_hostgroup_host_downtime":{"args":["start_time","end_time","fixed","duration","comment_author","comment_data"],"name":"schedule_hostgroup_host_downtime"},"schedule_hostgroup_svc_downtime":{"args":["start_time","end_time","fixed","duration","comment_author","comment_data"],"name":"schedule_hostgroup_svc_downtime"}},"hosts":{"acknowledge_host_problem":{"args":["sticky_ack","send_notification","persistent_comment","comment_author","comment_data"],"name":"acknowledge_host_problem"},"acknowledge_host_problem_expire":{"args":["sticky_ack","send_notification","persistent_comment","end_time","comment_author","comment_data"],"name":"acknowledge_host_problem_expire"},"add_host_comment":{"args":["comment_author","comment_data"],"name":"add_host_comment"},"change_host_modattr":{"args":[],"name":"change_host_modattr"},"del_all_host_comments":{"args":[],"name":"del_all_host_comments"},"delay_host_notification":{"args":["notification_time"],"name":"delay_host_notification"},"disable_all_notifications_beyond_host":{"args":[],"name":"disable_all_notifications_beyond_host"},"disable_host_check":{"args":[],"name":"disable_host_check"},"disable_host_event_handler":{"args":[],"name":"disable_host_event_handler"},"disable_host_flap_detection":{"args":[],"name":"disable_host_flap_detection"},"disable_host_notifications":{"args":[],"name":"disable_host_notifications"},"disable_host_svc_checks":{"args":[],"name":"disable_host_svc_checks"},"disable_host_svc_notifications":{"args":[],"name":"disable_host_svc_notifications"},"disable_passive_host_checks":{"args":[],"name":"disable_passive_host_checks"},"enable_all_notifications_beyond_host":{"args":[],"name":"enable_all_notifications_beyond_host"},"enable_host_and_child_notifications":{"args":[],"name":"enable_host_and_child_notifications"},"enable_host_check":{"args":[],"name":"enable_host_check"},"enable_host_event_handler":{"args":[],"name":"enable_host_event_handler"},"enable_host_flap_detection":{"args":[],"name":"enable_host_flap_detection"},"enable_host_notifications":{"args":[],"name":"enable_host_notifications"},"enable_host_svc_checks":{"args":[],"name":"enable_host_svc_checks"},"enable_host_svc_notifications":{"args":[],"name":"enable_host_svc_notifications"},"enable_passive_host_checks":{"args":[],"name":"enable_passive_host_checks"},"process_host_check_result":{"args":["plugin_state","plugin_output","performance_data"],"name":"process_host_check_result"},"remove_host_acknowledgement":{"args":[],"name":"remove_host_acknowledgement"},"schedule_and_propagate_host_downtime":{"args":["start_time","end_time","fixed","triggered_by","duration","comment_author","comment_data"],"name":"schedule_and_propagate_host_downtime"},"schedule_and_propagate_triggered_host_downtime":{"args":["start_time","end_time","fixed","triggered_by","duration","comment_author","comment_data"],"name":"schedule_and_propagate_triggered_host_downtime"},"schedule_forced_host_check":{"args":["start_time"],"name":"schedule_forced_host_check"},"schedule_forced_host_svc_checks":{"args":["start_time"],"name":"schedule_forced_host_svc_checks"},"schedule_host_check":{"args":["start_time"],"name":"schedule_host_check"},"schedule_host_downtime":{"args":["start_time","end_time","fixed","triggered_by","duration","comment_author","comment_data"],"name":"schedule_host_downtime"},"schedule_host_svc_checks":{"args":["start_time"],"name":"schedule_host_svc_checks"},"schedule_host_svc_downtime":{"args":["start_time","end_time","fixed","triggered_by","duration","comment_author","comment_data"],"name":"schedule_host_svc_downtime"},"send_custom_host_notification":{"args":["options","comment_author","comment_data"],"name":"send_custom_host_notification"},"start_obsessing_over_host":{"args":[],"name":"start_obsessing_over_host"},"stop_obsessing_over_host":{"args":[],"name":"stop_obsessing_over_host"}},"servicegroups":{"disable_servicegroup_host_checks":{"args":[],"name":"disable_servicegroup_host_checks"},"disable_servicegroup_host_notifications":{"args":[],"name":"disable_servicegroup_host_notifications"},"disable_servicegroup_svc_checks":{"args":[],"name":"disable_servicegroup_svc_checks"},"disable_servicegroup_svc_notifications":{"args":[],"name":"disable_servicegroup_svc_notifications"},"enable_servicegroup_host_checks":{"args":[],"name":"enable_servicegroup_host_checks"},"enable_servicegroup_host_notifications":{"args":[],"name":"enable_servicegroup_host_notifications"},"enable_servicegroup_svc_checks":{"args":[],"name":"enable_servicegroup_svc_checks"},"enable_servicegroup_svc_notifications":{"args":[],"name":"enable_servicegroup_svc_notifications"},"schedule_servicegroup_host_downtime":{"args":["start_time","end_time","fixed","duration","comment_author","comment_data"],"name":"schedule_servicegroup_host_downtime"},"schedule_servicegroup_svc_downtime":{"args":["start_time","end_time","fixed","duration","comment_author","comment_data"],"name":"schedule_servicegroup_svc_downtime"}},"services":{"acknowledge_svc_problem":{"args":["sticky_ack","send_notification","persistent_comment","comment_author","comment_data"],"name":"acknowledge_svc_problem"},"acknowledge_svc_problem_expire":{"args":["sticky_ack","send_notification","persistent_comment","end_time","comment_author","comment_data"],"name":"acknowledge_svc_problem_expire"},"add_svc_comment":{"args":["comment_author","comment_data"],"name":"add_svc_comment"},"change_svc_modattr":{"args":[],"name":"change_svc_modattr"},"del_all_svc_comments":{"args":[],"name":"del_all_svc_comments"},"delay_svc_notification":{"args":["notification_time"],"name":"delay_svc_notification"},"disable_passive_svc_checks":{"args":[],"name":"disable_passive_svc_checks"},"disable_svc_check":{"args":[],"name":"disable_svc_check"},"disable_svc_event_handler":{"args":[],"name":"disable_svc_event_handler"},"disable_svc_flap_detection":{"args":[],"name":"disable_svc_flap_detection"},"disable_svc_notifications":{"args":[],"name":"disable_svc_notifications"},"enable_passive_svc_checks":{"args":[],"name":"enable_passive_svc_checks"},"enable_svc_check":{"args":[],"name":"enable_svc_check"},"enable_svc_event_handler":{"args":[],"name":"enable_svc_event_handler"},"enable_svc_flap_detection":{"args":[],"name":"enable_svc_flap_detection"},"enable_svc_notifications":{"args":[],"name":"enable_svc_notifications"},"process_service_check_result":{"args":["plugin_state","plugin_output","performance_data"],"name":"process_service_check_result"},"remove_svc_acknowledgement":{"args":[],"name":"remove_svc_acknowledgement"},"schedule_forced_svc_check":{"args":["start_time"],"name":"schedule_forced_svc_check"},"schedule_svc_check":{"args":["start_time"],"name":"schedule_svc_check"},"schedule_svc_downtime":{"args":["start_time","end_time","fixed","triggered_by","duration","comment_author","comment_data"],"name":"schedule_svc_downtime"},"send_custom_svc_notification":{"args":["options","comment_author","comment_data"],"name":"send_custom_svc_notification"},"start_obsessing_over_svc":{"args":[],"name":"start_obsessing_over_svc"},"stop_obsessing_over_svc":{"args":[],"name":"stop_obsessing_over_svc"}},"system":{"del_host_comment":{"args":["comment_id"],"name":"del_host_comment"},"del_host_downtime":{"args":["downtime_id"],"name":"del_host_downtime"},"del_svc_comment":{"args":["comment_id"],"name":"del_svc_comment"},"del_svc_downtime":{"args":["downtime_id"],"name":"del_svc_downtime"},"disable_event_handlers":{"args":[],"name":"disable_event_handlers"},"disable_failure_prediction":{"args":[],"name":"disable_failure_prediction"},"disable_flap_detection":{"args":[],"name":"disable_flap_detection"},"disable_notifications":{"args":[],"name":"disable_notifications"},"disable_performance_data":{"args":[],"name":"disable_performance_data"},"enable_event_handlers":{"args":[],"name":"enable_event_handlers"},"enable_failure_prediction":{"args":[],"name":"enable_failure_prediction"},"enable_flap_detection":{"args":[],"name":"enable_flap_detection"},"enable_notifications":{"args":[],"name":"enable_notifications"},"enable_performance_data":{"args":[],"name":"enable_performance_data"},"restart_process":{"args":[],"name":"restart_process"},"shutdown_process":{"args":[],"name":"shutdown_process"},"start_accepting_passive_host_checks":{"args":[],"name":"start_accepting_passive_host_checks"},"start_accepting_passive_svc_checks":{"args":[],"name":"start_accepting_passive_svc_checks"},"start_executing_host_checks":{"args":[],"name":"start_executing_host_checks"},"start_executing_svc_checks":{"args":[],"name":"start_executing_svc_checks"},"start_obsessing_over_host_checks":{"args":[],"name":"start_obsessing_over_host_checks"},"start_obsessing_over_svc_checks":{"args":[],"name":"start_obsessing_over_svc_checks"},"stop_accepting_passive_host_checks":{"args":[],"name":"stop_accepting_passive_host_checks"},"stop_accepting_passive_svc_checks":{"args":[],"name":"stop_accepting_passive_svc_checks"},"stop_executing_host_checks":{"args":[],"name":"stop_executing_host_checks"},"stop_executing_svc_checks":{"args":[],"name":"stop_executing_svc_checks"},"stop_obsessing_over_host_checks":{"args":[],"name":"stop_obsessing_over_host_checks"},"stop_obsessing_over_svc_checks":{"args":[],"name":"stop_obsessing_over_svc_checks"}}}