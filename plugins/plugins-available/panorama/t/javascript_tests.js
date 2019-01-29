function test_get_group_status_unknown() {
    var group = {"hosts":{"ack_down":0,"ack_unreachable":0,
                          "down":0, "pending":0, "unreachable":0,"up":0,
                          "downtime_down":0,"downtime_unreachable":0,"downtime_up":0,
                          "plain_down":0,"plain_pending":0,"plain_unreachable":0,"plain_up":0},
                 "services":{"ack_critical":0,"ack_unknown":0,"ack_warning":0,
                             "critical":1, "unknown":1,"warning":1, "ok":1,"pending":1,
                             "downtime_critical":0,"downtime_ok":0,"downtime_unknown":0,"downtime_warning":0,
                             "plain_critical":1,"plain_ok":1,"plain_pending":1,"plain_unknown":1,"plain_warning":1
                            }};

    var res = TP.get_group_status({
        group:          group,
        incl_ack:       false,
        incl_downtimes: false,
        incl_svc:       true,
        incl_hst:       false
    });
    //diag(Ext.JSON.encode(res));
    if(res.state != 3) {
        throw Error("res state failed: expected 3 got "+res.state);
    }
    if(res.acknowledged != false) {
        throw Error("res acknowledged failed: expected false got "+res.acknowledged);
    }
    if(res.downtime != false) {
        throw Error("res downtime failed: expected false got "+res.downtime);
    }
    if(res.hostProblem != false) {
        throw Error("res hostProblem failed: expected false got "+res.hostProblem);
    }
    return 1;
}

function test_get_group_status_critical() {
    var group = {"hosts":{"ack_down":0,"ack_unreachable":0,
                          "down":0, "pending":0, "unreachable":0,"up":0,
                          "downtime_down":0,"downtime_unreachable":0,"downtime_up":0,
                          "plain_down":0,"plain_pending":0,"plain_unreachable":0,"plain_up":0},
                 "services":{"ack_critical":0,"ack_unknown":0,"ack_warning":0,
                             "critical":1, "unknown":1,"warning":1, "ok":1,"pending":1,
                             "downtime_critical":0,"downtime_ok":0,"downtime_unknown":1,"downtime_warning":0,
                             "plain_critical":1,"plain_ok":1,"plain_pending":1,"plain_unknown":0,"plain_warning":1
                            }};

    var res = TP.get_group_status({
        group:          group,
        incl_ack:       false,
        incl_downtimes: false,
        incl_svc:       true,
        incl_hst:       false
    });
    //diag(Ext.JSON.encode(res));
    if(res.state != 2) {
        throw Error("res state failed: expected 2 got "+res.state);
    }
    if(res.acknowledged != false) {
        throw Error("res acknowledged failed: expected false got "+res.acknowledged);
    }
    if(res.downtime != false) {
        throw Error("res downtime failed: expected false got "+res.downtime);
    }
    if(res.hostProblem != false) {
        throw Error("res hostProblem failed: expected false got "+res.hostProblem);
    }
    return 1;
}

function test_get_group_status_unknown_downtime() {
    var group = {"hosts":{"ack_down":0,"ack_unreachable":0,
                          "down":0, "pending":0, "unreachable":0,"up":0,
                          "downtime_down":0,"downtime_unreachable":0,"downtime_up":0,
                          "plain_down":0,"plain_pending":0,"plain_unreachable":0,"plain_up":0},
                 "services":{"ack_critical":0,"ack_unknown":0,"ack_warning":0,
                             "critical":0, "unknown":1,"warning":0, "ok":1,"pending":0,
                             "downtime_critical":0,"downtime_ok":0,"downtime_unknown":1,"downtime_warning":0,
                             "plain_critical":0,"plain_ok":1,"plain_pending":0,"plain_unknown":0,"plain_warning":0
                            }};

    var res = TP.get_group_status({
        group:          group,
        incl_ack:       false,
        incl_downtimes: false,
        incl_svc:       true,
        incl_hst:       false
    });
    //diag(Ext.JSON.encode(res));
    if(res.state != 3) {
        throw Error("res state failed: expected 3 got "+res.state);
    }
    if(res.acknowledged != false) {
        throw Error("res acknowledged failed: expected false got "+res.acknowledged);
    }
    if(res.downtime != true) {
        throw Error("res downtime failed: expected true got "+res.downtime);
    }
    if(res.hostProblem != false) {
        throw Error("res hostProblem failed: expected false got "+res.hostProblem);
    }
    return 1;
}

function test_get_group_status_unknown_incl_downtime() {
    var group = {"hosts":{"ack_down":0,"ack_unreachable":0,
                          "down":0, "pending":0, "unreachable":0,"up":0,
                          "downtime_down":0,"downtime_unreachable":0,"downtime_up":0,
                          "plain_down":0,"plain_pending":0,"plain_unreachable":0,"plain_up":0},
                 "services":{"ack_critical":0,"ack_unknown":0,"ack_warning":0,
                             "critical":0, "unknown":1,"warning":0, "ok":1,"pending":0,
                             "downtime_critical":0,"downtime_ok":0,"downtime_unknown":1,"downtime_warning":0,
                             "plain_critical":0,"plain_ok":1,"plain_pending":0,"plain_unknown":0,"plain_warning":0
                            }};

    var res = TP.get_group_status({
        group:          group,
        incl_ack:       false,
        incl_downtimes: true,
        incl_svc:       true,
        incl_hst:       false
    });
    //diag(Ext.JSON.encode(res));
    if(res.state != 3) {
        throw Error("res state failed: expected 3 got "+res.state);
    }
    if(res.acknowledged != false) {
        throw Error("res acknowledged failed: expected false got "+res.acknowledged);
    }
    if(res.downtime != false) {
        throw Error("res downtime failed: expected true got "+res.downtime);
    }
    if(res.hostProblem != false) {
        throw Error("res hostProblem failed: expected false got "+res.hostProblem);
    }
    return 1;
}

function test_timeframe2seconds() {
    var val;
    val = TP.timeframe2seconds('24h');
    if(val != 86400) {
        throw Error("timeframe2seconds expected 86400: got "+val);
    }
    val = TP.timeframe2seconds('12345');
    if(val != 12345) {
        throw Error("timeframe2seconds expected 12345: got "+val);
    }
    val = TP.timeframe2seconds('3m');
    if(val != 180) {
        throw Error("timeframe2seconds expected 180: got "+val);
    }

    // not parsed, fallback to 1hour
    val = TP.timeframe2seconds('3abc');
    if(val != 3600) {
        throw Error("timeframe2seconds expected 3600: got "+val);
    }
    return 1;
}