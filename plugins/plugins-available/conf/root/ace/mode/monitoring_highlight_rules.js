define('ace/mode/monitoring_highlight_rules', function(require, exports, module) {

var oop = require("pilot/oop");
var lang = require("pilot/lang");
var TextHighlightRules = require("ace/mode/text_highlight_rules").TextHighlightRules;

var MonitoringHighlightRules = function() {

    var buildinConstants = lang.arrayToMap(
        (
         // <objecttypes>
         "host|hostgroup|hostextinfo|hostdependency|hostescalation|service|servicegroup|serviceextinfo|servicedependency|serviceescalation|command|timeperiod|contact|contactgroup"
         // </objecttypes>
        ).split("|")
    );

    var builtinFunctions = lang.arrayToMap(
        (
         // <objectattributes>
         "name|register|use|2d_coords|3d_coords|action_url|active_checks_enabled|address|address1|address2|address3|address4|address5|address6|alias|can_submit_commands|check_command|check_freshness|check_interval|check_period|checks_enabled|command_line|command_name|contactgroup_members|contactgroup_name|contactgroups|contact_groups|contact_name|contacts|dependency_period|dependent_description|dependent_host|dependent_hostgroup|dependent_hostgroup_name|dependent_hostgroups|dependent_host_name|dependent_service_description|description|display_name|email|escalation_options|escalation_period|event_handler|event_handler_enabled|exception|exclude|execution_failure_criteria|execution_failure_options|failure_prediction_enabled|first_notification|first_notification_delay|flap_detection_enabled|flap_detection_options|freshness_threshold|friday|gd2_image|high_flap_threshold|host|hostgroup|hostgroup_members|hostgroup_name|hostgroups|host_groups|host_name|host_notification_commands|host_notification_options|host_notification_period|host_notifications_enabled|hosts|icon_image|icon_image_alt|inherits_parent|initial_state|is_volatile|last_notification|low_flap_threshold|master_description|master_host|master_host_name|master_service_description|max_check_attempts|members|monday|normal_check_interval|notes|notes_url|notification_failure_criteria|notification_failure_options|notification_interval|notification_options|notification_period|notifications_enabled|obsess_over_host|obsess_over_service|pager|parallelize_check|parents|passive_checks_enabled|process_perf_data|retain_nonstatus_information|retain_status_information|retry_check_interval|retry_interval|saturday|service_description|servicegroup_members|servicegroup_name|servicegroups|service_groups|service_notification_commands|service_notification_options|service_notification_period|service_notifications_enabled|stalking_options|statusmap_image|sunday|thursday|timeperiod_name|tuesday|vrml_image|wednesday"
         // </objectattributes>
        ).split("|")
    );

    // regexp must not have capturing parentheses. Use (?:) instead.
    // regexps are ordered -> the first match is used

    this.$rules = {
        "start" : [
            {
                token : "comment",
                regex : "^\\s*#.*$"
            }, {
                token : "comment",
                regex : ";.*$"
            }, {
                token : "keyword",
                regex : "^\\s*define\\b"
            }, {
                token : "keyword.operator",
                regex : "\\$[a-zA-Z0-9_]*\\$"
            }, {
                token : function(space, value) {
                    if (buildinConstants.hasOwnProperty(value))
                        return ["identifier", "constant.language"];
                    else if (builtinFunctions.hasOwnProperty(value))
                        return ["identifier", "support.function"];
                    else
                        return ["identifier", "identifier"];
                },
                regex : "(\\s)([a-zA-Z0-9_]+)\\b"
            }, {
                token : "lparen",
                regex : "[[({]"
            }, {
                token : "rparen",
                regex : "[\\])}]"
            }
        ],
        "qqstring" : [
            {
                token : "string",
                regex : '(?:(?:\\\\.)|(?:[^"\\\\]))*?"',
                next : "start"
            }, {
                token : "string",
                merge : true,
                regex : '.+'
            }
        ],
        "qstring" : [
            {
                token : "string",
                regex : "(?:(?:\\\\.)|(?:[^'\\\\]))*?'",
                next : "start"
            }, {
                token : "string",
                merge : true,
                regex : '.+'
            }
        ]
    };
};

oop.inherits(MonitoringHighlightRules, TextHighlightRules);

exports.MonitoringHighlightRules = MonitoringHighlightRules;
});
