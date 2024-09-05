ace.define("ace/mode/naemon_highlight_rules",["require","exports","module","ace/lib/oop","ace/lib/lang","ace/mode/text_highlight_rules"], function(require, exports, module) {
"use strict";

var oop = require("../lib/oop");
var lang = require("../lib/lang");
var TextHighlightRules = require("./text_highlight_rules").TextHighlightRules;
var reservedKeywords = exports.reservedKeywords = "define";
var reservedObjects = exports.reservedObjects = "command|contact|host|service|contactgroup|hostgroup|servicegroup|timeperiod|servicedependency|hostdependency";
var reservedAttributes = exports.reservedAttributes = {
    'command'           : "use|command_name|register|name|command_line",
    'contact'           : "can_submit_commands|name|register|contactgroups|host_notification_commands|service_notification_commands|host_notification_period|address3|service_notifications_enabled|address1|address4|use|address5|host_notification_options|service_notification_options|address6|contact_name|retain_status_information|pager|alias|email|service_notification_period|retain_nonstatus_information|address2|host_notifications_enabled",
    'contactgroup'      : "members|alias|contactgroup_members|use|contactgroup_name|name|register",
    'host'              : "notes|notification_period|event_handler|host_name|action_url|hostgroups|low_flap_threshold|check_freshness|name|register|retain_nonstatus_information|check_interval|alias|high_flap_threshold|parents|flap_detection_options|max_check_attempts|statusmap_image|display_name|icon_image_alt|passive_checks_enabled|first_notification_delay|retry_interval|notes_url|event_handler_enabled|flap_detection_enabled|notification_options|notifications_enabled|icon_image|contacts|initial_state|retain_status_information|obsess_over_host|address|active_checks_enabled|contact_groups|check_command|notification_interval|check_period|stalking_options|vrml_image|use|2d_coords|3d_coords|freshness_threshold|process_perf_data",
    'hostdependency'    : "dependency_period|notification_failure_criteria|use|dependent_hostgroup_name|host_name|name|dependent_host_name|register|hostgroup_name|inherits_parent|execution_failure_criteria",
    'hostgroup'         : "action_url|notes_url|register|name|hostgroup_members|use|hostgroup_name|notes|members|alias",
    'service'           : "check_freshness|name|register|low_flap_threshold|host_name|action_url|notification_period|event_handler|is_volatile|notes|hostgroup_name|max_check_attempts|flap_detection_options|high_flap_threshold|retain_nonstatus_information|check_interval|notification_options|notifications_enabled|flap_detection_enabled|icon_image|retry_interval|first_notification_delay|obsess_over_service|notes_url|event_handler_enabled|passive_checks_enabled|display_name|icon_image_alt|use|stalking_options|process_perf_data|freshness_threshold|check_period|notification_interval|check_command|contact_groups|retain_status_information|active_checks_enabled|servicegroups|service_description|initial_state|contacts",
    'servicedependency' : "host_name|dependent_host_name|name|register|hostgroup_name|inherits_parent|dependent_servicegroup_name|execution_failure_criteria|notification_failure_criteria|dependency_period|use|dependent_service_description|service_description|dependent_hostgroup_name",
    'servicegroup'      : "action_url|notes_url|name|register|use|members|notes|servicegroup_members|alias|servicegroup_name",
    'timeperiod'        : "saturday|thursday|timeperiod_name|monday|register|name|friday|use|sunday|tuesday|wednesday|exception|alias|exclude"
};

var numRe = exports.numRe = "\\-?(?:(?:[0-9]+)|(?:[0-9]*\\.[0-9]+))";

var NaemonHighlightRules = function() {
    var joinedReservedAttributes = [];
    for(var key in reservedAttributes) {
        joinedReservedAttributes.push(reservedAttributes[key]);
    }
    var keywordMapper = this.createKeywordMapper({
        "keyword": reservedKeywords,
        "object": reservedObjects,
        "constant.language": joinedReservedAttributes.join("|")
    }, "identifier");

    this.$rules = {
        "start" : [{
            token : "comment",
            regex : ";.*$",
        }, {
            token : "comment",
            regex : "#.*$",
        }, {
            token: "paren.lparen",
            regex: "\\{",
            push:  "ruleset"
        }, {
            token: "keyword",
            regex: "[a-z]+"
        }, {
            token: "object",
            regex: "[a-z]+"
        }, {
            caseInsensitive: true
        }],

        "ruleset" : [{
            token : "paren.rparen",
            regex : "\\}",
            next:   "pop"
        }, {
            token : "comment",
            regex : ";.*$",
        }, {
            token : "string", // single line
            regex : '["](?:(?:\\\\.)|(?:[^"\\\\]))*?["]'
        }, {
            token : "string", // single line
            regex : "['](?:(?:\\\\.)|(?:[^'\\\\]))*?[']"
        }, {
            token : "comment",
            regex : "#.*$",
        }, {
            token : "constant.numeric",
            regex : numRe
        }, {
            token : keywordMapper,
            regex : "\\-?[a-zA-Z_][a-zA-Z0-9_\\-]*"
        }, {
            caseInsensitive: true
        }]
    };

    this.normalizeRules();
};

oop.inherits(NaemonHighlightRules, TextHighlightRules);
exports.NaemonHighlightRules = NaemonHighlightRules;
});

ace.define("ace/mode/matching_brace_outdent",["require","exports","module","ace/range"], function(require, exports, module) {
"use strict";

var Range = require("../range").Range;

var MatchingBraceOutdent = function() {};

(function() {
    this.checkOutdent = function(line, input) {
        if (! /^\s+$/.test(line))
            return false;
        return /^\s*\}/.test(input);
    };

    this.autoOutdent = function(doc, row) {
        var line = doc.getLine(row);
        var match = line.match(/^(\s*\})/);

        if (!match) return 0;

        var column = match[1].length;
        var openBracePos = doc.findMatchingBracket({row: row, column: column});

        if (!openBracePos || openBracePos.row == row) return 0;

        var indent = this.$getIndent(doc.getLine(openBracePos.row));
        doc.replace(new Range(row, 0, row, column-1), indent);
    };

    this.$getIndent = function(line) {
        return line.match(/^\s*/)[0];
    };

}).call(MatchingBraceOutdent.prototype);

exports.MatchingBraceOutdent = MatchingBraceOutdent;
});



ace.define("ace/mode/folding/cstyle",["require","exports","module","ace/lib/oop","ace/range","ace/mode/folding/fold_mode"], function(require, exports, module) {
"use strict";

var oop = require("../../lib/oop");
var Range = require("../../range").Range;
var BaseFoldMode = require("./fold_mode").FoldMode;

var FoldMode = exports.FoldMode = function(commentRegex) {
    if (commentRegex) {
        this.foldingStartMarker = new RegExp(
            this.foldingStartMarker.source.replace(/\|[^|]*?$/, "|" + commentRegex.start)
        );
        this.foldingStopMarker = new RegExp(
            this.foldingStopMarker.source.replace(/\|[^|]*?$/, "|" + commentRegex.end)
        );
    }
};
oop.inherits(FoldMode, BaseFoldMode);

(function() {

    this.foldingStartMarker = /(\{|\[)[^\}\]]*$|^\s*(\/\*)/;
    this.foldingStopMarker = /^[^\[\{]*(\}|\])|^[\s\*]*(\*\/)/;
    this.singleLineBlockCommentRe= /^\s*(\/\*).*\*\/\s*$/;
    this.tripleStarBlockCommentRe = /^\s*(\/\*\*\*).*\*\/\s*$/;
    this.startRegionRe = /^\s*(\/\*|\/\/)#?region\b/;
    this._getFoldWidgetBase = this.getFoldWidget;
    this.getFoldWidget = function(session, foldStyle, row) {
        var line = session.getLine(row);

        if (this.singleLineBlockCommentRe.test(line)) {
            if (!this.startRegionRe.test(line) && !this.tripleStarBlockCommentRe.test(line))
                return "";
        }

        var fw = this._getFoldWidgetBase(session, foldStyle, row);

        if (!fw && this.startRegionRe.test(line))
            return "start"; // lineCommentRegionStart

        return fw;
    };

    this.getFoldWidgetRange = function(session, foldStyle, row, forceMultiline) {
        var line = session.getLine(row);

        if (this.startRegionRe.test(line))
            return this.getCommentRegionBlock(session, line, row);

        var match = line.match(this.foldingStartMarker);
        if (match) {
            var i = match.index;

            if (match[1])
                return this.openingBracketBlock(session, match[1], row, i);

            var range = session.getCommentFoldRange(row, i + match[0].length, 1);

            if (range && !range.isMultiLine()) {
                if (forceMultiline) {
                    range = this.getSectionRange(session, row);
                } else if (foldStyle != "all")
                    range = null;
            }

            return range;
        }

        if (foldStyle === "markbegin")
            return;

        var match = line.match(this.foldingStopMarker);
        if (match) {
            var i = match.index + match[0].length;

            if (match[1])
                return this.closingBracketBlock(session, match[1], row, i);

            return session.getCommentFoldRange(row, i, -1);
        }
    };

    this.getSectionRange = function(session, row) {
        var line = session.getLine(row);
        var startIndent = line.search(/\S/);
        var startRow = row;
        var startColumn = line.length;
        row = row + 1;
        var endRow = row;
        var maxRow = session.getLength();
        while (++row < maxRow) {
            line = session.getLine(row);
            var indent = line.search(/\S/);
            if (indent === -1)
                continue;
            if  (startIndent > indent)
                break;
            var subRange = this.getFoldWidgetRange(session, "all", row);

            if (subRange) {
                if (subRange.start.row <= startRow) {
                    break;
                } else if (subRange.isMultiLine()) {
                    row = subRange.end.row;
                } else if (startIndent == indent) {
                    break;
                }
            }
            endRow = row;
        }

        return new Range(startRow, startColumn, endRow, session.getLine(endRow).length);
    };
    this.getCommentRegionBlock = function(session, line, row) {
        var startColumn = line.search(/\s*$/);
        var maxRow = session.getLength();
        var startRow = row;

        var re = /^\s*(?:\/\*|\/\/|--)#?(end)?region\b/;
        var depth = 1;
        while (++row < maxRow) {
            line = session.getLine(row);
            var m = re.exec(line);
            if (!m) continue;
            if (m[1]) depth--;
            else depth++;

            if (!depth) break;
        }

        var endRow = row;
        if (endRow > startRow) {
            return new Range(startRow, startColumn, endRow, line.length);
        }
    };

}).call(FoldMode.prototype);

});

ace.define("ace/mode/naemon_completions",["require","exports","module"], function(require, exports, module) {
"use strict";

var NaemonCompletions = function() {};
(function() {
    var highlight_rules = require("./naemon_highlight_rules");
    this.getCompletions = function(state, session, pos, prefix) {
        var token = session.getTokenAt(pos.row, pos.column);
        if(token) {
            if(token.type == "keyword") {
                var line = session.getLine(pos.row).substr(0, pos.column);
                if(line.match(/^define /)) {
                    return highlight_rules.reservedObjects.split(/\|/).map(function(obj){
                        return {
                            caption: obj,
                            snippet: obj+' {\n    $0\n}',
                            meta:   "object",
                            score:   Number.MAX_VALUE
                        };
                    });
                } else {
                    return highlight_rules.reservedKeywords.split(/\|/).map(function(keyword){
                        return {
                            caption: keyword,
                            snippet: keyword+' ',
                            meta:   "keyword",
                            score:   Number.MAX_VALUE
                        };
                    });
                }
            }
            if(token.type == "identifier") {
                var row = pos.row;
                while(row >= 0) {
                    var line = session.getLine(row);
                    var matches = line.match(/define\s+(.*?)(\s|\{)/);
                    if(matches && matches[1]) {
                        var attributes = highlight_rules.reservedAttributes[matches[1]];
                        if(attributes) {
                            return attributes.split(/\|/).map(function(attr){
                                return {
                                    caption: attr,
                                    snippet: attr+' ',
                                    meta:   "attribute",
                                    score:   Number.MAX_VALUE
                                };
                            });
                        }
                    }
                    row--;
                }
            }
        }
        return [];
    };
}).call(NaemonCompletions.prototype);
exports.NaemonCompletions = NaemonCompletions;
});


ace.define("ace/mode/naemon",["require","exports","module","ace/lib/oop","ace/mode/text","ace/mode/naemon_highlight_rules","ace/mode/matching_brace_outdent","ace/mode/naemon_completions","ace/mode/behaviour/naemon","ace/mode/folding/cstyle"], function(require, exports, module) {
"use strict";

var oop = require("../lib/oop");
var TextMode = require("./text").Mode;
var NaemonHighlightRules = require("./naemon_highlight_rules").NaemonHighlightRules;
var MatchingBraceOutdent = require("./matching_brace_outdent").MatchingBraceOutdent;
var NaemonCompletions = require("./naemon_completions").NaemonCompletions;
var CStyleFoldMode = require("./folding/cstyle").FoldMode;

var Mode = function() {
    this.HighlightRules = NaemonHighlightRules;
    this.$outdent = new MatchingBraceOutdent();
    this.foldingRules = new CStyleFoldMode();
    this.$completer = new NaemonCompletions();
};
oop.inherits(Mode, TextMode);

(function() {

    this.foldingRules = "cStyle";
    this.lineCommentStart = "#|;";

    this.getNextLineIndent = function(state, line, tab) {
        var indent = this.$getIndent(line);
        var tokens = this.getTokenizer().getLineTokens(line, state).tokens;
        if (tokens.length && tokens[tokens.length-1].type == "comment") {
            return indent;
        }

        var match = line.match(/^.*\{\s*$/);
        if (match) {
            indent += tab;
        }

        return indent;
    };

    this.checkOutdent = function(state, line, input) {
        return this.$outdent.checkOutdent(line, input);
    };

    this.autoOutdent = function(state, doc, row) {
        this.$outdent.autoOutdent(doc, row);
    };

    this.getCompletions = function(state, session, pos, prefix) {
        return this.$completer.getCompletions(state, session, pos, prefix);
    };

    this.$id = "ace/mode/naemon";
}).call(Mode.prototype);

exports.Mode = Mode;

});
