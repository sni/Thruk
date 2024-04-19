package Thruk::Controller::Rest::V1::docs;

use warnings;
use strict;
use Cpanel::JSON::XS qw/decode_json/;

=head1 NAME

Thruk::Controller::Rest::V1::docs - Contains attributes for all endpoints

=head1 DESCRIPTION

Thruk Controller

=head1 METHODS

=head2 keys

    keys()

returns raw attributes for all rest endpoints

=cut

##########################################################
sub keys {
    our $doc_data;
    if(!$doc_data) {
        my $data = "";
        while(<DATA>) {
            my $line = $_;
            next if $line =~ m/^\s*\#/mx;
            next if $line =~ m/^\s*$/mx;
            $data .= $line;
        }
        $doc_data = decode_json($data);
    }
    return($doc_data);
}

##########################################################

1;

__DATA__
{
 "/checks/stats": {
  "GET": {
   "columns": [
    {
     "description": "percent of active hosts during the last 15 minutes",
     "name": "hosts_active_15_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "amount of active hosts during the last 15 minutes",
     "name": "hosts_active_15_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "same for last minute",
     "name": "hosts_active_1_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "same for last minute",
     "name": "hosts_active_1_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "same for last 5 minutes",
     "name": "hosts_active_5_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "same for last 5 minutes",
     "name": "hosts_active_5_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "same for last 60 minutes",
     "name": "hosts_active_60_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "same for last 60 minutes",
     "name": "hosts_active_60_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "percent of total active hosts",
     "name": "hosts_active_all_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "amount of total active hosts",
     "name": "hosts_active_all_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "average percent state change",
     "name": "hosts_active_state_change_avg",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "maximum state change over all active hosts",
     "name": "hosts_active_state_change_max",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "minimum state change over all active hosts",
     "name": "hosts_active_state_change_min",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "sum state change over all hosts",
     "name": "hosts_active_state_change_sum",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "number of active hosts",
     "name": "hosts_active_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "average execution time over all hosts",
     "name": "hosts_execution_time_avg",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "maximum execution time over all hosts",
     "name": "hosts_execution_time_max",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "minimum execution time over all hosts",
     "name": "hosts_execution_time_min",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "sum execution time over all hosts",
     "name": "hosts_execution_time_sum",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "host latency average",
     "name": "hosts_latency_avg",
     "type": "number",
     "unit": ""
    },
    {
     "description": "minimum host latency",
     "name": "hosts_latency_max",
     "type": "number",
     "unit": ""
    },
    {
     "description": "minimum host latency",
     "name": "hosts_latency_min",
     "type": "number",
     "unit": ""
    },
    {
     "description": "sum latency over all hosts",
     "name": "hosts_latency_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "percent of passive hosts during the last 15 minutes",
     "name": "hosts_passive_15_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "amount of passive hosts during the last 15 minutes",
     "name": "hosts_passive_15_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "same for last minute",
     "name": "hosts_passive_1_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "same for last minute",
     "name": "hosts_passive_1_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "same for last 5 minutes",
     "name": "hosts_passive_5_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "same for last 5 minutes",
     "name": "hosts_passive_5_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "same for last 60 minutes",
     "name": "hosts_passive_60_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "same for last 60 minutes",
     "name": "hosts_passive_60_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "percent of total passive hosts",
     "name": "hosts_passive_all_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "amount of total passive hosts",
     "name": "hosts_passive_all_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "average percent state change for passive hosts",
     "name": "hosts_passive_state_change_avg",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "maximum state change over all passive hosts",
     "name": "hosts_passive_state_change_max",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "minimum state change over all passive hosts",
     "name": "hosts_passive_state_change_min",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "sum state change over all passive hosts",
     "name": "hosts_passive_state_change_sum",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "number of passive hosts",
     "name": "hosts_passive_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "percent of active services during the last 15 minutes",
     "name": "services_active_15_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "amount of active services during the last 15 minutes",
     "name": "services_active_15_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "same for last minute",
     "name": "services_active_1_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "same for last minute",
     "name": "services_active_1_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "same for last 5 minutes",
     "name": "services_active_5_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "same for last 5 minutes",
     "name": "services_active_5_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "same for last 60 minutes",
     "name": "services_active_60_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "same for last 60 minutes",
     "name": "services_active_60_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "percent of total active services",
     "name": "services_active_all_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "amount of total active services",
     "name": "services_active_all_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "average percent state change",
     "name": "services_active_state_change_avg",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "maximum state change over all active services",
     "name": "services_active_state_change_max",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "minimum state change over all active services",
     "name": "services_active_state_change_min",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "sum state change over all services",
     "name": "services_active_state_change_sum",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "number of active services",
     "name": "services_active_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "average execution time over all services",
     "name": "services_execution_time_avg",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "maximum execution time over all services",
     "name": "services_execution_time_max",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "minimum execution time over all services",
     "name": "services_execution_time_min",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "sum execution time over all services",
     "name": "services_execution_time_sum",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "services latency average",
     "name": "services_latency_avg",
     "type": "number",
     "unit": ""
    },
    {
     "description": "minimum services latency",
     "name": "services_latency_max",
     "type": "number",
     "unit": ""
    },
    {
     "description": "minimum services latency",
     "name": "services_latency_min",
     "type": "number",
     "unit": ""
    },
    {
     "description": "sum latency over all services",
     "name": "services_latency_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "percent of passive services during the last 15 minutes",
     "name": "services_passive_15_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "amount of passive services during the last 15 minutes",
     "name": "services_passive_15_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "same for last minute",
     "name": "services_passive_1_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "same for last minute",
     "name": "services_passive_1_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "same for last 5 minutes",
     "name": "services_passive_5_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "same for last 5 minutes",
     "name": "services_passive_5_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "same for last 60 minutes",
     "name": "services_passive_60_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "same for last 60 minutes",
     "name": "services_passive_60_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "percent of total passive services",
     "name": "services_passive_all_perc",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "amount of total passive services",
     "name": "services_passive_all_sum",
     "type": "number",
     "unit": ""
    },
    {
     "description": "average percent state change for passive services",
     "name": "services_passive_state_change_avg",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "maximum state change over all passive services",
     "name": "services_passive_state_change_max",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "minimum state change over all passive services",
     "name": "services_passive_state_change_min",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "sum state change over all passive services",
     "name": "services_passive_state_change_sum",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "number of passive services",
     "name": "services_passive_sum",
     "type": "number",
     "unit": ""
    }
   ]
  }
 },
 "/config/diff": {
  "GET": {
   "columns": [
    {
     "description": "file name of changed file",
     "name": "file",
     "type": "",
     "unit": ""
    },
    {
     "description": "diff output",
     "name": "output",
     "type": "",
     "unit": ""
    },
    {
     "description": "backend id when having multiple sites connected",
     "name": "peer_key",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/config/files": {
  "GET": {
   "columns": [
    {
     "description": "raw file content",
     "name": "content",
     "type": "",
     "unit": ""
    },
    {
     "description": "hex sum for this file",
     "name": "hex",
     "type": "",
     "unit": ""
    },
    {
     "description": "unix timestamp of last modification",
     "name": "mtime",
     "type": "time",
     "unit": ""
    },
    {
     "description": "filesystem path",
     "name": "path",
     "type": "",
     "unit": ""
    },
    {
     "description": "backend id when having multiple sites connected",
     "name": "peer_key",
     "type": "",
     "unit": ""
    },
    {
     "description": "readonly flag",
     "name": "readonly",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/config/fullobjects": {
  "GET": {
   "columns": [
    {
     "description": "object attributes like defined in the source config files",
     "name": "...",
     "type": "",
     "unit": ""
    },
    {
     "description": "filename and line number",
     "name": ":FILE",
     "type": "",
     "unit": ""
    },
    {
     "description": "internal uniq id",
     "name": ":ID",
     "type": "",
     "unit": ""
    },
    {
     "description": "id of remote site",
     "name": ":PEER_KEY",
     "type": "",
     "unit": ""
    },
    {
     "description": "name of remote site",
     "name": ":PEER_NAME",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag whether file is readonly",
     "name": ":READONLY",
     "type": "",
     "unit": ""
    },
    {
     "description": "list of used template",
     "name": ":TEMPLATES",
     "type": "",
     "unit": ""
    },
    {
     "description": "object type, ex.: host",
     "name": ":TYPE",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/config/objects": {
  "GET": {
   "columns": [
    {
     "description": "object attributes like defined in the source config files",
     "name": "...",
     "type": "",
     "unit": ""
    },
    {
     "description": "filename and line number",
     "name": ":FILE",
     "type": "",
     "unit": ""
    },
    {
     "description": "internal uniq id",
     "name": ":ID",
     "type": "",
     "unit": ""
    },
    {
     "description": "id of remote site",
     "name": ":PEER_KEY",
     "type": "",
     "unit": ""
    },
    {
     "description": "name of remote site",
     "name": ":PEER_NAME",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag whether file is readonly",
     "name": ":READONLY",
     "type": "",
     "unit": ""
    },
    {
     "description": "object type, ex.: host",
     "name": ":TYPE",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/config/precheck": {
  "GET": {
   "columns": [
    {
     "description": "list of errors encountered",
     "name": "errors",
     "type": "",
     "unit": ""
    },
    {
     "description": "boolean flag wether configuration check has failed or not",
     "name": "failed",
     "type": "",
     "unit": ""
    },
    {
     "description": "backend id when having multiple sites connected",
     "name": "peer_key",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/hostgroups/<name>/outages": {
  "GET": {
   "columns": [
    {
     "description": "host/service status",
     "name": "class",
     "type": "",
     "unit": ""
    },
    {
     "description": "outage duration in seconds",
     "name": "duration",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "unix timestamp of outage end",
     "name": "end",
     "type": "time",
     "unit": ""
    },
    {
     "description": "host name",
     "name": "host",
     "type": "",
     "unit": ""
    },
    {
     "description": "0/1 flag wether this outage is in a downtime",
     "name": "in_downtime",
     "type": "",
     "unit": ""
    },
    {
     "description": "last plugin output during outage",
     "name": "plugin_output",
     "type": "",
     "unit": ""
    },
    {
     "description": "service description (only for service outages)",
     "name": "service",
     "type": "",
     "unit": ""
    },
    {
     "description": "unix timestamp of outage start",
     "name": "start",
     "type": "time",
     "unit": ""
    },
    {
     "description": "log entry type",
     "name": "type",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/hosts/<name>/availability": {
  "GET": {
   "columns": [
    {
     "description": "total seconds in state down (during downtimes)",
     "name": "scheduled_time_down",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds unknown (during downtimes)",
     "name": "scheduled_time_indeterminate",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds in state unreachable (during downtimes)",
     "name": "scheduled_time_unreachable",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds in state up (during downtimes)",
     "name": "scheduled_time_up",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds in state down",
     "name": "time_down",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds without any data",
     "name": "time_indeterminate_nodata",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds during core not running",
     "name": "time_indeterminate_notrunning",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds outside the given timeperiod",
     "name": "time_indeterminate_outside_timeperiod",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds in state unreachable",
     "name": "time_unreachable",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds in state up",
     "name": "time_up",
     "type": "number",
     "unit": "s"
    }
   ]
  }
 },
 "/hosts/<name>/commandline": {
  "GET": {
   "columns": [
    {
     "description": "name of the check_command including arguments",
     "name": "check_command",
     "type": "",
     "unit": ""
    },
    {
     "description": "full expanded command line (if possible)",
     "name": "command_line",
     "type": "",
     "unit": ""
    },
    {
     "description": "contains the error if expanding failed for some reason",
     "name": "error",
     "type": "",
     "unit": ""
    },
    {
     "description": "host name",
     "name": "host_name",
     "type": "",
     "unit": ""
    },
    {
     "description": "backend id when having multiple sites connected",
     "name": "peer_key",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/hosts/<name>/outages": {
  "GET": {
   "columns": [
    {
     "description": "host/service status",
     "name": "class",
     "type": "",
     "unit": ""
    },
    {
     "description": "outage duration in seconds",
     "name": "duration",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "unix timestamp of outage end",
     "name": "end",
     "type": "time",
     "unit": ""
    },
    {
     "description": "host name",
     "name": "host",
     "type": "",
     "unit": ""
    },
    {
     "description": "0/1 flag wether this outage is in a downtime",
     "name": "in_downtime",
     "type": "",
     "unit": ""
    },
    {
     "description": "last plugin output during outage",
     "name": "plugin_output",
     "type": "",
     "unit": ""
    },
    {
     "description": "unix timestamp of outage start",
     "name": "start",
     "type": "time",
     "unit": ""
    },
    {
     "description": "log entry type",
     "name": "type",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/hosts/outages": {
  "GET": {
   "columns": [
    {
     "description": "host/service status",
     "name": "class",
     "type": "",
     "unit": ""
    },
    {
     "description": "outage duration in seconds",
     "name": "duration",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "unix timestamp of outage end",
     "name": "end",
     "type": "time",
     "unit": ""
    },
    {
     "description": "host name",
     "name": "host",
     "type": "",
     "unit": ""
    },
    {
     "description": "0/1 flag wether this outage is in a downtime",
     "name": "in_downtime",
     "type": "",
     "unit": ""
    },
    {
     "description": "last plugin output during outage",
     "name": "plugin_output",
     "type": "",
     "unit": ""
    },
    {
     "description": "unix timestamp of outage start",
     "name": "start",
     "type": "time",
     "unit": ""
    },
    {
     "description": "log entry type",
     "name": "type",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/hosts/stats": {
  "GET": {
   "columns": [
    {
     "description": "number of active hosts which have active checks disabled",
     "name": "active_checks_disabled_active",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of passive hosts which have active checks disabled",
     "name": "active_checks_disabled_passive",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of down hosts",
     "name": "down",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of down hosts which are acknowledged",
     "name": "down_and_ack",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of active down hosts which have active checks disabled",
     "name": "down_and_disabled_active",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of passive down hosts which have active checks disabled",
     "name": "down_and_disabled_passive",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of down hosts which are in a scheduled downtime",
     "name": "down_and_scheduled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unhandled down hosts",
     "name": "down_and_unhandled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of hosts with eventhandlers disabled",
     "name": "eventhandler_disabled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of flapping hosts",
     "name": "flapping",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of hosts with flapping detection disabled",
     "name": "flapping_disabled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of hosts with notifications disabled",
     "name": "notifications_disabled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of network outages",
     "name": "outages",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of hosts which do not accept passive check results",
     "name": "passive_checks_disabled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of pending hosts",
     "name": "pending",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of pending hosts with active checks disabled",
     "name": "pending_and_disabled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of pending hosts which are in a scheduled downtime",
     "name": "pending_and_scheduled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of down hosts which are not acknowleded or in a downtime",
     "name": "plain_down",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of pending hosts which are not acknowleded or in a downtime",
     "name": "plain_pending",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unreachable hosts which are not acknowleded or in a downtime",
     "name": "plain_unreachable",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of up hosts which are not acknowleded or in a downtime",
     "name": "plain_up",
     "type": "",
     "unit": ""
    },
    {
     "description": "total number of hosts",
     "name": "total",
     "type": "",
     "unit": ""
    },
    {
     "description": "total number of active hosts",
     "name": "total_active",
     "type": "",
     "unit": ""
    },
    {
     "description": "total number of passive hosts",
     "name": "total_passive",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unreachable hosts",
     "name": "unreachable",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unreachable hosts which are acknowledged",
     "name": "unreachable_and_ack",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of active unreachable hosts which have active checks disabled",
     "name": "unreachable_and_disabled_active",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of passive unreachable hosts which have active checks disabled",
     "name": "unreachable_and_disabled_passive",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unreachable hosts which are in a scheduled downtime",
     "name": "unreachable_and_scheduled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unhandled unreachable hosts",
     "name": "unreachable_and_unhandled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of up hosts",
     "name": "up",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of active up hosts which have active checks disabled",
     "name": "up_and_disabled_active",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of passive up hosts which have active checks disabled",
     "name": "up_and_disabled_passive",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of up hosts which are in a scheduled downtime",
     "name": "up_and_scheduled",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/hosts/totals": {
  "GET": {
   "columns": [
    {
     "description": "number of down hosts",
     "name": "down",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of down hosts which are neither acknowledged nor in scheduled downtime",
     "name": "down_and_unhandled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of pending hosts",
     "name": "pending",
     "type": "",
     "unit": ""
    },
    {
     "description": "total number of hosts",
     "name": "total",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unreachable hosts",
     "name": "unreachable",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unreachable hosts which are neither acknowledged nor in scheduled downtime",
     "name": "unreachable_and_unhandled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of up hosts",
     "name": "up",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/index": {
  "GET": {
   "columns": [
    {
     "description": "description of the url",
     "name": "description",
     "type": "",
     "unit": ""
    },
    {
     "description": "protocol to use for this url",
     "name": "protocol",
     "type": "",
     "unit": ""
    },
    {
     "description": "the rest url",
     "name": "url",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/lmd/sites": {
  "GET": {
   "columns": [
    {
     "description": "address of the remote site",
     "name": "addr",
     "type": "",
     "unit": ""
    },
    {
     "description": "total bytes received from this site",
     "name": "bytes_received",
     "type": "number",
     "unit": "bytes"
    },
    {
     "description": "total bytes send to this site",
     "name": "bytes_send",
     "type": "number",
     "unit": "bytes"
    },
    {
     "description": "contains the real address if using federation",
     "name": "federation_addr",
     "type": "",
     "unit": ""
    },
    {
     "description": "contains the real peer key if using federation",
     "name": "federation_key",
     "type": "",
     "unit": ""
    },
    {
     "description": "contains the real name if using federation",
     "name": "federation_name",
     "type": "",
     "unit": ""
    },
    {
     "description": "contains the real backend type if using federation",
     "name": "federation_type",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag if the connection is in idle mode",
     "name": "idling",
     "type": "",
     "unit": ""
    },
    {
     "description": "primary id of this site",
     "name": "key",
     "type": "",
     "unit": ""
    },
    {
     "description": "last error message",
     "name": "last_error",
     "type": "time",
     "unit": ""
    },
    {
     "description": "timestamp when the site was last time online",
     "name": "last_online",
     "type": "time",
     "unit": ""
    },
    {
     "description": "timestamp of the last received query for this site",
     "name": "last_query",
     "type": "time",
     "unit": ""
    },
    {
     "description": "timestamp of the last update",
     "name": "last_update",
     "type": "time",
     "unit": ""
    },
    {
     "description": "same as last_update",
     "name": "lmd_last_cache_update",
     "type": "time",
     "unit": ""
    },
    {
     "description": "name of the site",
     "name": "name",
     "type": "",
     "unit": ""
    },
    {
     "description": "parent id for lmd federation setups",
     "name": "parent",
     "type": "",
     "unit": ""
    },
    {
     "description": "same as `key`",
     "name": "peer_key",
     "type": "",
     "unit": ""
    },
    {
     "description": "same as `name`",
     "name": "peer_name",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of queries received",
     "name": "queries",
     "type": "",
     "unit": ""
    },
    {
     "description": "response time in seconds",
     "name": "response_time",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "thruks section",
     "name": "section",
     "type": "",
     "unit": ""
    },
    {
     "description": "connection status of this site",
     "name": "status",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/servicegroups/<name>/outages": {
  "GET": {
   "columns": [
    {
     "description": "host/service status",
     "name": "class",
     "type": "",
     "unit": ""
    },
    {
     "description": "outage duration in seconds",
     "name": "duration",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "unix timestamp of outage end",
     "name": "end",
     "type": "time",
     "unit": ""
    },
    {
     "description": "host name",
     "name": "host",
     "type": "",
     "unit": ""
    },
    {
     "description": "0/1 flag wether this outage is in a downtime",
     "name": "in_downtime",
     "type": "",
     "unit": ""
    },
    {
     "description": "last plugin output during outage",
     "name": "plugin_output",
     "type": "",
     "unit": ""
    },
    {
     "description": "service description (only for service outages)",
     "name": "service",
     "type": "",
     "unit": ""
    },
    {
     "description": "unix timestamp of outage start",
     "name": "start",
     "type": "time",
     "unit": ""
    },
    {
     "description": "log entry type",
     "name": "type",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/services/<host>/<service>/availability": {
  "GET": {
   "columns": [
    {
     "description": "total seconds in state critical (during downtimes)",
     "name": "scheduled_time_critical",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds unknown (during downtimes)",
     "name": "scheduled_time_indeterminate",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds in state ok (during downtimes)",
     "name": "scheduled_time_ok",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds in state unknown (during downtimes)",
     "name": "scheduled_time_unknown",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds in state warning (during downtimes)",
     "name": "scheduled_time_warning",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds in state critical",
     "name": "time_critical",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds without any data",
     "name": "time_indeterminate_nodata",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds during core not running",
     "name": "time_indeterminate_notrunning",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds outside the given timeperiod",
     "name": "time_indeterminate_outside_timeperiod",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds in state ok",
     "name": "time_ok",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds in state unknown",
     "name": "time_unknown",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "total seconds in state warning",
     "name": "time_warning",
     "type": "number",
     "unit": "s"
    }
   ]
  }
 },
 "/services/<host>/<service>/commandline": {
  "GET": {
   "columns": [
    {
     "description": "name of the check_command including arguments",
     "name": "check_command",
     "type": "",
     "unit": ""
    },
    {
     "description": "full expanded command line (if possible)",
     "name": "command_line",
     "type": "",
     "unit": ""
    },
    {
     "description": "contains the error if expanding failed for some reason",
     "name": "error",
     "type": "",
     "unit": ""
    },
    {
     "description": "host name",
     "name": "host_name",
     "type": "",
     "unit": ""
    },
    {
     "description": "backend id when having multiple sites connected",
     "name": "peer_key",
     "type": "",
     "unit": ""
    },
    {
     "description": "service name",
     "name": "service_description",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/services/<host>/<service>/outages": {
  "GET": {
   "columns": [
    {
     "description": "host/service status",
     "name": "class",
     "type": "",
     "unit": ""
    },
    {
     "description": "outage duration in seconds",
     "name": "duration",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "unix timestamp of outage end",
     "name": "end",
     "type": "time",
     "unit": ""
    },
    {
     "description": "host name",
     "name": "host",
     "type": "",
     "unit": ""
    },
    {
     "description": "0/1 flag wether this outage is in a downtime",
     "name": "in_downtime",
     "type": "",
     "unit": ""
    },
    {
     "description": "last plugin output during outage",
     "name": "plugin_output",
     "type": "",
     "unit": ""
    },
    {
     "description": "service description (only for service outages)",
     "name": "service",
     "type": "",
     "unit": ""
    },
    {
     "description": "unix timestamp of outage start",
     "name": "start",
     "type": "time",
     "unit": ""
    },
    {
     "description": "log entry type",
     "name": "type",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/services/outages": {
  "GET": {
   "columns": [
    {
     "description": "host/service status",
     "name": "class",
     "type": "",
     "unit": ""
    },
    {
     "description": "outage duration in seconds",
     "name": "duration",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "unix timestamp of outage end",
     "name": "end",
     "type": "time",
     "unit": ""
    },
    {
     "description": "host name",
     "name": "host",
     "type": "",
     "unit": ""
    },
    {
     "description": "0/1 flag wether this outage is in a downtime",
     "name": "in_downtime",
     "type": "",
     "unit": ""
    },
    {
     "description": "last plugin output during outage",
     "name": "plugin_output",
     "type": "",
     "unit": ""
    },
    {
     "description": "service description (only for service outages)",
     "name": "service",
     "type": "",
     "unit": ""
    },
    {
     "description": "unix timestamp of outage start",
     "name": "start",
     "type": "time",
     "unit": ""
    },
    {
     "description": "log entry type",
     "name": "type",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/services/stats": {
  "GET": {
   "columns": [
    {
     "description": "number of active services which have active checks disabled",
     "name": "active_checks_disabled_active",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of passive services which have active checks disabled",
     "name": "active_checks_disabled_passive",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of critical services",
     "name": "critical",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of critical services which are acknowledged",
     "name": "critical_and_ack",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of active critical services which have active checks disabled",
     "name": "critical_and_disabled_active",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of passive critical services which have active checks disabled",
     "name": "critical_and_disabled_passive",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of critical services which are in a scheduled downtime",
     "name": "critical_and_scheduled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unhandled critical services",
     "name": "critical_and_unhandled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unhandled critical services on down hosts",
     "name": "critical_on_down_host",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of services with eventhandlers disabled",
     "name": "eventhandler_disabled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of flapping services",
     "name": "flapping",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of services with flapping detection disabled",
     "name": "flapping_disabled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of services with notifications disabled",
     "name": "notifications_disabled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of ok services",
     "name": "ok",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of active ok services which have active checks disabled",
     "name": "ok_and_disabled_active",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of passive ok services which have active checks disabled",
     "name": "ok_and_disabled_passive",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of ok services which are in a scheduled downtime",
     "name": "ok_and_scheduled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of services which do not accept passive check results",
     "name": "passive_checks_disabled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of pending services",
     "name": "pending",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of pending services with active checks disabled",
     "name": "pending_and_disabled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of pending services which are in a scheduled downtime",
     "name": "pending_and_scheduled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of critical services which are not acknowleded or in a downtime",
     "name": "plain_critical",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of ok services which are not acknowleded or in a downtime",
     "name": "plain_ok",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of pending services which are not acknowleded or in a downtime",
     "name": "plain_pending",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unknown services which are not acknowleded or in a downtime",
     "name": "plain_unknown",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of warning services which are not acknowleded or in a downtime",
     "name": "plain_warning",
     "type": "",
     "unit": ""
    },
    {
     "description": "total number of services",
     "name": "total",
     "type": "",
     "unit": ""
    },
    {
     "description": "total number of active services",
     "name": "total_active",
     "type": "",
     "unit": ""
    },
    {
     "description": "total number of passive services",
     "name": "total_passive",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unknown services",
     "name": "unknown",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unknown services which are acknowledged",
     "name": "unknown_and_ack",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of active unknown services which have active checks disabled",
     "name": "unknown_and_disabled_active",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of passive unknown services which have active checks disabled",
     "name": "unknown_and_disabled_passive",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unknown services which are in a scheduled downtime",
     "name": "unknown_and_scheduled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unhandled unknown services",
     "name": "unknown_and_unhandled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unhandled unknown services on down hosts",
     "name": "unknown_on_down_host",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of warning services",
     "name": "warning",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of warning services which are acknowledged",
     "name": "warning_and_ack",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of active warning services which have active checks disabled",
     "name": "warning_and_disabled_active",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of passive warning services which have active checks disabled",
     "name": "warning_and_disabled_passive",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of warning services which are in a scheduled downtime",
     "name": "warning_and_scheduled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unhandled warning services",
     "name": "warning_and_unhandled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unhandled warning services on down hosts",
     "name": "warning_on_down_host",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/services/totals": {
  "GET": {
   "columns": [
    {
     "description": "number of critical services",
     "name": "critical",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of critical services which are neither acknowledged nor in scheduled downtime",
     "name": "critical_and_unhandled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of ok services",
     "name": "ok",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of pending services",
     "name": "pending",
     "type": "",
     "unit": ""
    },
    {
     "description": "total number of services",
     "name": "total",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unknown services",
     "name": "unknown",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of unknown services which are neither acknowledged nor in scheduled downtime",
     "name": "unknown_and_unhandled",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of warning services",
     "name": "warning",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of warning services which are neither acknowledged nor in scheduled downtime",
     "name": "warning_and_unhandled",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/sites": {
  "GET": {
   "columns": [
    {
     "description": "address for this connection",
     "name": "addr",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag wether sites is connected (1) or not (0)",
     "name": "connected",
     "type": "",
     "unit": ""
    },
    {
     "description": "contains the real address if using federation",
     "name": "federation_addr",
     "type": "",
     "unit": ""
    },
    {
     "description": "contains the real peer key if using federation",
     "name": "federation_key",
     "type": "",
     "unit": ""
    },
    {
     "description": "contains the real name if using federation",
     "name": "federation_name",
     "type": "",
     "unit": ""
    },
    {
     "description": "contains the real backend type if using federation",
     "name": "federation_type",
     "type": "",
     "unit": ""
    },
    {
     "description": "id for this backend",
     "name": "id",
     "type": "",
     "unit": ""
    },
    {
     "description": "error message if backend is not connected",
     "name": "last_error",
     "type": "time",
     "unit": ""
    },
    {
     "description": "current local unix timestamp of thruk host",
     "name": "localtime",
     "type": "time",
     "unit": ""
    },
    {
     "description": "name of the backend",
     "name": "name",
     "type": "",
     "unit": ""
    },
    {
     "description": "section name",
     "name": "section",
     "type": "",
     "unit": ""
    },
    {
     "description": "0 (OK), 1 (DOWN)",
     "name": "status",
     "type": "",
     "unit": ""
    },
    {
     "description": "type of the backend",
     "name": "type",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/thruk": {
  "GET": {
   "columns": [
    {
     "description": "rest api version",
     "name": "rest_version",
     "type": "",
     "unit": ""
    },
    {
     "description": "thruk version",
     "name": "thruk_version",
     "type": "",
     "unit": ""
    },
    {
     "description": "thruk release date",
     "name": "thruk_release_date",
     "type": "",
     "unit": ""
    },
    {
     "description": "current server unix timestamp / epoch",
     "name": "localtime",
     "type": "time",
     "unit": ""
    },
    {
     "description": "thruk root folder",
     "name": "project_root",
     "type": "",
     "unit": ""
    },
    {
     "description": "configuration folder",
     "name": "etc_path",
     "type": "",
     "unit": ""
    },
    {
     "description": "variable data folder",
     "name": "var_path",
     "type": "",
     "unit": ""
    },
    {
     "description": "might contain omd version",
     "name": "extra_version",
     "type": "",
     "unit": ""
    },
    {
     "description": "contains link from extra_versions product",
     "name": "extra_link",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/thruk/api_keys": {
  "GET": {
   "columns": [
    {
     "description": "comment of this api key",
     "name": "comment",
     "type": "",
     "unit": ""
    },
    {
     "description": "unixtimestamp of when the key was created",
     "name": "created",
     "type": "",
     "unit": ""
    },
    {
     "description": "used hash algorithm",
     "name": "digest",
     "type": "",
     "unit": ""
    },
    {
     "description": "path to stored file",
     "name": "file",
     "type": "",
     "unit": ""
    },
    {
     "description": "super user keys can enforce a specific user",
     "name": "force_user",
     "type": "",
     "unit": ""
    },
    {
     "description": "hashed private key",
     "name": "hashed_key",
     "type": "",
     "unit": ""
    },
    {
     "description": "ip address of last usage",
     "name": "last_from",
     "type": "time",
     "unit": ""
    },
    {
     "description": "unixtimestamp of last usage",
     "name": "last_used",
     "type": "time",
     "unit": ""
    },
    {
     "description": "list of roles this key is limited too",
     "name": "roles",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag wether this a global superuser key and not bound to a specific user",
     "name": "superuser",
     "type": "",
     "unit": ""
    },
    {
     "description": "username of key owner",
     "name": "user",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/thruk/bp": {
  "GET": {
   "columns": [
    {
     "description": "list of backend ids used for the last calculation",
     "name": "affected_peers",
     "type": "",
     "unit": ""
    },
    {
     "description": "id of backend which hosts the business process",
     "name": "bp_backend",
     "type": "",
     "unit": ""
    },
    {
     "description": "0 - do no create a host object, 1 - create naemon host object",
     "name": "create_host_object",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag wether this is a draft only",
     "name": "draft",
     "type": "",
     "unit": ""
    },
    {
     "description": "list of enabled filters",
     "name": "filter",
     "type": "",
     "unit": ""
    },
    {
     "description": "primary id",
     "name": "id",
     "type": "",
     "unit": ""
    },
    {
     "description": "timestamp of last check result submited",
     "name": "last_check",
     "type": "time",
     "unit": ""
    },
    {
     "description": "timestamp of last state change",
     "name": "last_state_change",
     "type": "time",
     "unit": ""
    },
    {
     "description": "name of this business proces",
     "name": "name",
     "type": "",
     "unit": ""
    },
    {
     "description": "all nodes of this business process",
     "name": "nodes",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag wheter this business process is horizontal or vertical",
     "name": "rankDir",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag if this business process uses hard or soft state types",
     "name": "state_type",
     "type": "",
     "unit": ""
    },
    {
     "description": "current status",
     "name": "status",
     "type": "",
     "unit": ""
    },
    {
     "description": "current status text",
     "name": "status_text",
     "type": "",
     "unit": ""
    },
    {
     "description": "naemon template used for the generated object",
     "name": "template",
     "type": "",
     "unit": ""
    },
    {
     "description": "calculation duration",
     "name": "time",
     "type": "number",
     "unit": "s"
    }
   ]
  }
 },
 "/thruk/broadcasts": {
  "GET": {
   "columns": [
    {
     "description": "annotation icon for this broadcast",
     "name": "annotation",
     "type": "",
     "unit": ""
    },
    {
     "description": "author of the broadcast",
     "name": "author",
     "type": "",
     "unit": ""
    },
    {
     "description": "authors E-Mail address, mainly used as macro",
     "name": "authoremail",
     "type": "",
     "unit": ""
    },
    {
     "description": "list of contactgroups if broadcast should be limited to specific groups",
     "name": "contactgroups",
     "type": "",
     "unit": ""
    },
    {
     "description": "list of contacts if broadcast should be limited to specific contacts",
     "name": "contacts",
     "type": "",
     "unit": ""
    },
    {
     "description": "expire date after which the broadcast won't be displayed anymore",
     "name": "expires",
     "type": "",
     "unit": ""
    },
    {
     "description": "expire data as unix timestamp",
     "name": "expires_ts",
     "type": "time",
     "unit": ""
    },
    {
     "description": "filename",
     "name": "file",
     "type": "",
     "unit": ""
    },
    {
     "description": "hash list of extraceted frontmatter variables",
     "name": "frontmatter",
     "type": "",
     "unit": ""
    },
    {
     "description": "do not show broadcast before this date",
     "name": "hide_before",
     "type": "",
     "unit": ""
    },
    {
     "description": "hide_before as unix timestamp",
     "name": "hide_before_ts",
     "type": "time",
     "unit": ""
    },
    {
     "description": "flag wether broadcast should be displayed on the loginpage as well",
     "name": "loginpage",
     "type": "",
     "unit": ""
    },
    {
     "description": "hash list of macros",
     "name": "macros",
     "type": "",
     "unit": ""
    },
    {
     "description": "name of this broadcast, mostly used for templates",
     "name": "name",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag wether broadcast should be displayed on panorama dashboards",
     "name": "panorama",
     "type": "",
     "unit": ""
    },
    {
     "description": "raw broadcast text",
     "name": "raw_text",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag wether this broadcast is a template",
     "name": "template",
     "type": "",
     "unit": ""
    },
    {
     "description": "processed broadcast message",
     "name": "text",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/thruk/cluster": {
  "GET": {
   "columns": [
    {
     "description": "host name of the cluster node",
     "name": "hostname",
     "type": "",
     "unit": ""
    },
    {
     "description": "timestamp of last successful contact",
     "name": "last_contact",
     "type": "time",
     "unit": ""
    },
    {
     "description": "text of last error message",
     "name": "last_error",
     "type": "time",
     "unit": ""
    },
    {
     "description": "Flag whether this node is in maintenance mode",
     "name": "maintenance",
     "type": "",
     "unit": ""
    },
    {
     "description": "internal id for this node",
     "name": "node_id",
     "type": "",
     "unit": ""
    },
    {
     "description": "url to access this node directly",
     "name": "node_url",
     "type": "",
     "unit": ""
    },
    {
     "description": "list of current process ids of this node",
     "name": "pids",
     "type": "",
     "unit": ""
    },
    {
     "description": "response time in seconds",
     "name": "response_time",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "version information of this node",
     "name": "version",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/thruk/jobs": {
  "GET": {
   "columns": [
    {
     "description": "the executed command line or perl code",
     "name": "cmd",
     "type": "",
     "unit": ""
    },
    {
     "description": "timestamp when the job finished",
     "name": "end",
     "type": "time",
     "unit": ""
    },
    {
     "description": "url to forward when the job is done",
     "name": "forward",
     "type": "",
     "unit": ""
    },
    {
     "description": "thruk node id this job is run on",
     "name": "host_id",
     "type": "",
     "unit": ""
    },
    {
     "description": "hostname of the node",
     "name": "host_name",
     "type": "",
     "unit": ""
    },
    {
     "description": "job id",
     "name": "id",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag whether the job is still running",
     "name": "is_running",
     "type": "",
     "unit": ""
    },
    {
     "description": "current status text",
     "name": "message",
     "type": "",
     "unit": ""
    },
    {
     "description": "percent of completion",
     "name": "percent",
     "type": "number",
     "unit": "%"
    },
    {
     "description": "contains the perl result in case this was a perl job",
     "name": "perl_res",
     "type": "",
     "unit": ""
    },
    {
     "description": "process id",
     "name": "pid",
     "type": "",
     "unit": ""
    },
    {
     "description": "return code",
     "name": "rc",
     "type": "",
     "unit": ""
    },
    {
     "description": "remaining seconds for the job to complete",
     "name": "remaining",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag whether output console will be displayed",
     "name": "show_output",
     "type": "",
     "unit": ""
    },
    {
     "description": "timestamp when the job started",
     "name": "start",
     "type": "time",
     "unit": ""
    },
    {
     "description": "stderr output",
     "name": "stderr",
     "type": "",
     "unit": ""
    },
    {
     "description": "stdout output",
     "name": "stdout",
     "type": "",
     "unit": ""
    },
    {
     "description": "duration in seconds",
     "name": "time",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "username of the owner",
     "name": "user",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/thruk/logcache/stats": {
  "GET": {
   "columns": [
    {
     "description": "db schema version",
     "name": "cache_version",
     "type": "",
     "unit": ""
    },
    {
     "description": "duration of last compact run in seconds",
     "name": "compact_duration",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "timestamp marker where last compact run finished",
     "name": "compact_till",
     "type": "time",
     "unit": ""
    },
    {
     "description": "used size of data in bytes",
     "name": "data_size",
     "type": "number",
     "unit": "bytes"
    },
    {
     "description": "flag wether logcache is enabled for this backend or not",
     "name": "enabled",
     "type": "",
     "unit": ""
    },
    {
     "description": "used size of index in bytes",
     "name": "index_size",
     "type": "number",
     "unit": "bytes"
    },
    {
     "description": "number of items/rows",
     "name": "items",
     "type": "",
     "unit": ""
    },
    {
     "description": "peer key",
     "name": "key",
     "type": "",
     "unit": ""
    },
    {
     "description": "timestamp of last compact run",
     "name": "last_compact",
     "type": "time",
     "unit": ""
    },
    {
     "description": "timestamp of last log entry",
     "name": "last_entry",
     "type": "time",
     "unit": ""
    },
    {
     "description": "timestamp of last optimize run",
     "name": "last_reorder",
     "type": "time",
     "unit": ""
    },
    {
     "description": "timestamp of last update run",
     "name": "last_update",
     "type": "time",
     "unit": ""
    },
    {
     "description": "current lock mode",
     "name": "mode",
     "type": "",
     "unit": ""
    },
    {
     "description": "peer name",
     "name": "name",
     "type": "",
     "unit": ""
    },
    {
     "description": "duration of last reorder run in seconds",
     "name": "reorder_duration",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "human readable status",
     "name": "status",
     "type": "",
     "unit": ""
    },
    {
     "description": "duration of last update run in seconds",
     "name": "update_duration",
     "type": "number",
     "unit": "s"
    }
   ]
  }
 },
 "/thruk/panorama": {
  "GET": {
   "columns": [
    {
     "description": "filename of the dashboard",
     "name": "file",
     "type": "",
     "unit": ""
    },
    {
     "description": "version of dashboard format",
     "name": "file_version",
     "type": "",
     "unit": ""
    },
    {
     "description": "internal id",
     "name": "id",
     "type": "",
     "unit": ""
    },
    {
     "description": "maintenance reason (only if in maintenance mode)",
     "name": "maintenance",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of the dashboard",
     "name": "nr",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of objects",
     "name": "objects",
     "type": "",
     "unit": ""
    },
    {
     "description": "panlet definition",
     "name": "panlet_<nr>",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag whether this dashboard is read-only",
     "name": "readonly",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag whether this is a scripted dashboard",
     "name": "scripted",
     "type": "",
     "unit": ""
    },
    {
     "description": "structure of global dashboard settings",
     "name": "tab",
     "type": "",
     "unit": ""
    },
    {
     "description": "timestamp of last modification",
     "name": "ts",
     "type": "time",
     "unit": ""
    },
    {
     "description": "owner of this dashboard",
     "name": "user",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/thruk/recurring_downtimes": {
  "GET": {
   "columns": [
    {
     "description": "list of backends this downtime is used for",
     "name": "backends",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag used for the downtime command",
     "name": "childoptions",
     "type": "",
     "unit": ""
    },
    {
     "description": "comment used for the downtime command",
     "name": "comment",
     "type": "",
     "unit": ""
    },
    {
     "description": "username who created this downtime",
     "name": "created_by",
     "type": "",
     "unit": ""
    },
    {
     "description": "duration in minutes",
     "name": "duration",
     "type": "number",
     "unit": "minutes"
    },
    {
     "description": "username who last edited this downtime",
     "name": "edited_by",
     "type": "",
     "unit": ""
    },
    {
     "description": "contains the error message if something got wrong with this downtime",
     "name": "error",
     "type": "",
     "unit": ""
    },
    {
     "description": "file number",
     "name": "file",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag whether this should create a fixed downtime",
     "name": "fixed",
     "type": "",
     "unit": ""
    },
    {
     "description": "range in minutes for flexible downtimes",
     "name": "flex_range",
     "type": "number",
     "unit": "minutes"
    },
    {
     "description": "list of hostnames",
     "name": "host",
     "type": "",
     "unit": ""
    },
    {
     "description": "list of hostgroups",
     "name": "hostgroup",
     "type": "",
     "unit": ""
    },
    {
     "description": "unix timestamp of last change",
     "name": "last_changed",
     "type": "time",
     "unit": ""
    },
    {
     "description": "list of schedules",
     "name": "schedule",
     "type": "",
     "unit": ""
    },
    {
     "description": "list of services",
     "name": "service",
     "type": "",
     "unit": ""
    },
    {
     "description": "list of servicegroups",
     "name": "servicegroup",
     "type": "",
     "unit": ""
    },
    {
     "description": "sets the type of the downtime, ex. host or hostgroup",
     "name": "target",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/thruk/reports": {
  "GET": {
   "columns": [
    {
     "description": "list of backends used in this report",
     "name": "backends",
     "type": "",
     "unit": ""
    },
    {
     "description": "email cc address if this report is send by mail",
     "name": "cc",
     "type": "",
     "unit": ""
    },
    {
     "description": "report description",
     "name": "desc",
     "type": "",
     "unit": ""
    },
    {
     "description": "contains error messages (optional)",
     "name": "error",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag wheter the report failed to generate last time",
     "name": "failed",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag wheter the report is public or not",
     "name": "is_public",
     "type": "",
     "unit": ""
    },
    {
     "description": "name of the report",
     "name": "name",
     "type": "",
     "unit": ""
    },
    {
     "description": "number of the report",
     "name": "nr",
     "type": "",
     "unit": ""
    },
    {
     "description": "reporting parameters",
     "name": "params",
     "type": "",
     "unit": ""
    },
    {
     "description": "user/group permission",
     "name": "permissions",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag wheter the report is read-only",
     "name": "readonly",
     "type": "",
     "unit": ""
    },
    {
     "description": "list of cron entries",
     "name": "send_types",
     "type": "",
     "unit": ""
    },
    {
     "description": "template of the report",
     "name": "template",
     "type": "",
     "unit": ""
    },
    {
     "description": "email to address if this report is send by mail",
     "name": "to",
     "type": "",
     "unit": ""
    },
    {
     "description": "owner",
     "name": "user",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/thruk/reports/<nr>": {
  "GET": {
   "columns": [
    {
     "description": "list of selected backends.",
     "name": "backends",
     "type": "",
     "unit": ""
    },
    {
     "description": "carbon-copy for report email.",
     "name": "cc",
     "type": "",
     "unit": ""
    },
    {
     "description": "description.",
     "name": "desc",
     "type": "",
     "unit": ""
    },
    {
     "description": "contains error messages (optional)",
     "name": "error",
     "type": "",
     "unit": ""
    },
    {
     "description": "failed flag.",
     "name": "failed",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag for public reports.",
     "name": "is_public",
     "type": "",
     "unit": ""
    },
    {
     "description": "name of the report.",
     "name": "name",
     "type": "",
     "unit": ""
    },
    {
     "description": "primary id.",
     "name": "nr",
     "type": "",
     "unit": ""
    },
    {
     "description": "report parameters.",
     "name": "params",
     "type": "",
     "unit": ""
    },
    {
     "description": "user/group permission",
     "name": "permissions",
     "type": "",
     "unit": ""
    },
    {
     "description": "readonly flag.",
     "name": "readonly",
     "type": "",
     "unit": ""
    },
    {
     "description": "list of crontab entries.",
     "name": "send_types",
     "type": "",
     "unit": ""
    },
    {
     "description": "report template.",
     "name": "template",
     "type": "",
     "unit": ""
    },
    {
     "description": "email address the report email.",
     "name": "to",
     "type": "",
     "unit": ""
    },
    {
     "description": "owner of the report.",
     "name": "user",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/thruk/sessions": {
  "GET": {
   "columns": [
    {
     "description": "timestamp when session was last time used",
     "name": "active",
     "type": "time",
     "unit": ""
    },
    {
     "description": "remote address of user",
     "name": "address",
     "type": "",
     "unit": ""
    },
    {
     "description": "used hash algorithm",
     "name": "digest",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag whether this is a fake session or not",
     "name": "fake",
     "type": "",
     "unit": ""
    },
    {
     "description": "file name the session data file",
     "name": "file",
     "type": "",
     "unit": ""
    },
    {
     "description": "hashed session id",
     "name": "hashed_key",
     "type": "",
     "unit": ""
    },
    {
     "description": "extra session roles",
     "name": "roles",
     "type": "",
     "unit": ""
    },
    {
     "description": "username of this session",
     "name": "username",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/thruk/stats": {
  "GET": {
   "columns": [
    {
     "description": "business process calculation duration in seconds",
     "name": "business_process_duration_seconds",
     "type": "number",
     "unit": "s"
    },
    {
     "description": "timestamp of last business process calculation",
     "name": "business_process_last_update",
     "type": "time",
     "unit": ""
    },
    {
     "description": "total number of business processes",
     "name": "business_process_total",
     "type": "",
     "unit": ""
    },
    {
     "description": "total number of worker processes used to calculate business processes",
     "name": "business_process_worker_total",
     "type": "",
     "unit": ""
    },
    {
     "description": "total number of active thruk sessions (active during the last 5 minutes)",
     "name": "sessions_active_5min_total",
     "type": "",
     "unit": ""
    },
    {
     "description": "total number of thruk sessions",
     "name": "sessions_total",
     "type": "",
     "unit": ""
    },
    {
     "description": "total number of uniq users active during the last 5 minutes",
     "name": "sessions_uniq_user_5min_total",
     "type": "",
     "unit": ""
    },
    {
     "description": "total number of uniq users",
     "name": "sessions_uniq_user_total",
     "type": "",
     "unit": ""
    },
    {
     "description": "total number of locked thruk users",
     "name": "users_locked_total",
     "type": "",
     "unit": ""
    },
    {
     "description": "total number of thruk users",
     "name": "users_total",
     "type": "",
     "unit": ""
    }
   ]
  }
 },
 "/thruk/users": {
  "GET": {
   "columns": [
    {
     "description": "alias name",
     "name": "alias",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag wether this account is allowed to submit commands",
     "name": "can_submit_commands",
     "type": "",
     "unit": ""
    },
    {
     "description": "email address",
     "name": "email",
     "type": "",
     "unit": ""
    },
    {
     "description": "list of contactgroups",
     "name": "groups",
     "type": "",
     "unit": ""
    },
    {
     "description": "flag wether this account has a thruk profile or not",
     "name": "has_thruk_profile",
     "type": "",
     "unit": ""
    },
    {
     "description": "username",
     "name": "id",
     "type": "",
     "unit": ""
    },
    {
     "description": "timestamp of last successfull login",
     "name": "last_login",
     "type": "time",
     "unit": ""
    },
    {
     "description": "flag wether account is locked or not",
     "name": "locked",
     "type": "",
     "unit": ""
    },
    {
     "description": "list of roles for this user",
     "name": "roles",
     "type": "",
     "unit": ""
    },
    {
     "description": "users selected timezone",
     "name": "tz",
     "type": "",
     "unit": ""
    }
   ]
  }
 }
}
