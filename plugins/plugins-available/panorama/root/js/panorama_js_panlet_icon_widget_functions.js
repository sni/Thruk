/* get summarized table for hosts */
TP.get_summarized_hoststatus = function(item) {
    var table = '<table class="ministatus"><tr>';
    table += '<th>Up<\/th><th>Down<\/th><th>Unreachable<\/th><th>Pending<\/th><\/tr><tr>';
    table += '<td class='+(item.up          ? 'UP'          : 'miniEmpty')+'>'+item.up+'<\/td>';
    table += '<td class='+(item.down        ? 'DOWN'        : 'miniEmpty')+'>'+item.down+'<\/td>';
    table += '<td class='+(item.unreachable ? 'UNREACHABLE' : 'miniEmpty')+'>'+item.unreachable+'<\/td>';
    table += '<td class='+(item.pending     ? 'PENDING'     : 'miniEmpty')+'>'+item.pending+'<\/td>';
    table += '<\/tr><\/table>';
    return(table);
}

/* get summarized table for services */
TP.get_summarized_servicestatus = function(item) {
    var table = '<table class="ministatus"><tr>';
    table += '<th>Ok<\/th><th>Warning<\/th><th>Unknown<\/th><th>Critical<\/th><th>Pending<\/th><\/tr><tr>';
    table += '<td class='+(item.ok       ? 'OK'       : 'miniEmpty')+'>'+item.ok+'<\/td>';
    table += '<td class='+(item.warning  ? 'WARNING'  : 'miniEmpty')+'>'+item.warning+'<\/td>';
    table += '<td class='+(item.unknown  ? 'UNKNOWN'  : 'miniEmpty')+'>'+item.unknown+'<\/td>';
    table += '<td class='+(item.critical ? 'CRITICAL' : 'miniEmpty')+'>'+item.critical+'<\/td>';
    table += '<td class='+(item.pending  ? 'PENDING'  : 'miniEmpty')+'>'+item.pending+'<\/td>';
    table += '<\/tr><\/table>';
    return(table);
}

/* returns group status */
TP.get_group_status = function(options) {
    var group          = options.group,
        order          = options.order,
        incl_svc       = options.incl_svc,
        incl_hst       = options.incl_hst,
        incl_ack       = options.incl_ack, // alert acks as well, basically means acks are threated as unacked
        incl_downtimes = options.incl_downtimes; // assume no downtime
    if(!order) { order = default_state_order }
    if(group.hosts    == undefined) { group.hosts    = {} }
    if(group.services == undefined) { group.services = {} }

    var totals = { services: {}, hosts: {} };
    if(incl_svc) {
        // since ok, crit,... contain the downtimes and acks as well, override with the plain_ ones.
        totals.services.ok       = group.services.plain_ok;;
        totals.services.critical = group.services.plain_critical;
        totals.services.warning  = group.services.plain_warning;
        totals.services.unknown  = group.services.plain_unknown;
        totals.services.pending  = group.services.plain_pending;
        if(incl_ack) {
            totals.services.critical += group.services.ack_critical;
            totals.services.warning  += group.services.ack_warning;
            totals.services.unknown  += group.services.ack_unknown;
        }
        if(incl_downtimes) {
            totals.services.critical += group.services.downtime_critical;
            totals.services.warning  += group.services.downtime_warning;
            totals.services.unknown  += group.services.downtime_unknown;
        }
    }
    if(incl_hst) {
        totals.hosts.up          = group.hosts.plain_up;
        totals.hosts.down        = group.hosts.plain_down;
        totals.hosts.unreachable = group.hosts.plain_unreachable;
        totals.hosts.pending     = group.hosts.plain_pending;
        if(incl_ack) {
            totals.hosts.down        = group.hosts.ack_down;
            totals.hosts.unreachable = group.hosts.ack_unreachable;
        }
        if(incl_downtimes) {
            totals.hosts.down        = group.hosts.downtime_down;
            totals.hosts.unreachable = group.hosts.downtime_unreachable;
        }
    }

    var s;
    var acknowledged = false;
    var downtime     = false;
    var hostProblem  = false;
    for(var x = 0; x < order.length; x++) {
        switch (order[x]) {
            case "down":
                if(incl_hst && totals.hosts.down > 0)                 { s = 1; hostProblem = true; }
                break;
            case "unreachable":
                if(incl_hst && totals.hosts.unreachable > 0)          { s = 2; hostProblem = true; }
                break;
            case "unknown":
                if(incl_svc && totals.services.unknown > 0)           { s = 3; }
                break;
            case "acknowledged_unknown":
                if(incl_svc && group.services.ack_unknown > 0)        { s = 3; acknowledged = true; }
                break;
            case "downtime_unknown":
                if(incl_svc && group.services.downtime_unknown > 0)   { s = 3; downtime = true; }
                break;
            case "acknowledged_unreachable":
                if(incl_hst && group.hosts.ack_unreachable > 0)       { s = 2; hostProblem = true; acknowledged = true; }
                break;
            case "acknowledged_down":
                if(incl_hst && group.hosts.ack_down > 0)              { s = 1; hostProblem = true; acknowledged = true; }
                break;
            case "downtime_down":
                if(incl_hst && group.hosts.downtime_down > 0)         { s = 1; hostProblem = true; downtime = true; }
                break;
            case "downtime_unreachable":
                if(incl_hst && group.hosts.downtime_unreachable > 0)  { s = 2; hostProblem = true; downtime = true; }
                break;
            case "critical":
                if(incl_svc && totals.services.critical > 0)          { s = 2; }
                break;
            case "acknowledged_critical":
                if(incl_svc && group.services.ack_critical > 0)       { s = 2; acknowledged = true; }
                break;
            case "downtime_critical":
                if(incl_svc && group.services.downtime_critical > 0)  { s = 2; downtime = true; }
                break;
            case "warning":
                if(incl_svc && totals.services.warning > 0)           { s = 1; }
                break;
            case "acknowledged_warning":
                if(incl_svc && group.services.ack_warning > 0)        { s = 1; acknowledged = true; }
                break;
            case "downtime_warning":
                if(incl_svc && group.services.downtime_warning > 0)   { s = 1; downtime = true; }
                break;
            case "ok":
                if(incl_svc && totals.services.ok > 0)                { s = 0; }
                break;
            case "up":
                if(incl_hst && totals.hosts.up > 0)                   { s = 0; }
                break;
            case "downtime_up":
                if(incl_hst && group.hosts.downtime_up > 0)           { s = 0; downtime = true; }
                break;
            case "downtime_ok":
                if(incl_svc && group.services.downtime_ok > 0)        { s = 0; downtime = true; }
                break;
            case "pending":
                if(incl_svc && totals.services.pending > 0)           { s = 4; }
                if(incl_hst && totals.hosts.pending > 0)              { s = 4; hostProblem = true; }
                break;
            case "downtime_pending":
                if(incl_svc && group.services.downtime_pending > 0)   { s = 4; downtime = true; }
                if(incl_hst && group.hosts.downtime_pending > 0)      { s = 4; hostProblem = true; downtime = true; }
                break;
            default:
                //throw new Error("unhandled state: '"+order[x]+"'");
                break;
        }
        // first hit sets the current overall state
        if(s != undefined) {
            break;
        }
    }

    if(s == undefined) {
        s = 3;
    }

    return({state: s, downtime: downtime, acknowledged: acknowledged, hostProblem: hostProblem });
}

/* returns state position */
TP.get_state_position = function(order, state, isHostProblem, acknowledged, downtime) {
    var pos;
    for(var x = 0; x < order.length; x++) {
        switch (order[x]) {
            case "down":
                if(state == 1 && isHostProblem && !acknowledged && !downtime)   { pos = x; }
                break;
            case "unreachable":
                if(state == 2 && isHostProblem && !acknowledged && !downtime)   { pos = x; }
                break;
            case "unknown":
                if(state == 3 && !isHostProblem && !acknowledged && !downtime)  { pos = x; }
                break;
            case "acknowledged_unknown":
                if(state == 3 && !isHostProblem && acknowledged)                { pos = x; }
                break;
            case "downtime_unknown":
                if(state == 3 && !isHostProblem && downtime)                    { pos = x; }
                break;
            case "acknowledged_unreachable":
                if(state == 2 && isHostProblem && acknowledged)                 { pos = x; }
                break;
            case "acknowledged_down":
                if(state == 1 && isHostProblem && acknowledged)                 { pos = x; }
                break;
            case "downtime_down":
                if(state == 1 && isHostProblem && downtime)                     { pos = x; }
                break;
            case "downtime_unreachable":
                if(state == 2 && isHostProblem && downtime)                     { pos = x; }
                break;
            case "critical":
                if(state == 2 && !isHostProblem && !acknowledged && !downtime)  { pos = x; }
                break;
            case "acknowledged_critical":
                if(state == 2 && !isHostProblem && acknowledged)                { pos = x; }
                break;
            case "downtime_critical":
                if(state == 2 && !isHostProblem && downtime)                    { pos = x; }
                break;
            case "warning":
                if(state == 1 && !isHostProblem && !acknowledged && !downtime)  { pos = x; }
                break;
            case "acknowledged_warning":
                if(state == 1 && !isHostProblem && acknowledged)                { pos = x; }
                break;
            case "downtime_warning":
                if(state == 1 && !isHostProblem && downtime)                    { pos = x; }
                break;
            case "ok":
                if(state == 0 && !isHostProblem && !acknowledged && !downtime)  { pos = x; }
                break;
            case "up":
                if(state == 0 && isHostProblem && !acknowledged && !downtime)   { pos = x; }
                break;
            case "downtime_up":
                if(state == 0 && isHostProblem && downtime)                     { pos = x; }
                break;
            case "downtime_ok":
                if(state == 0 && !isHostProblem && downtime)                    { pos = x; }
                break;
            case "pending":
                if(state == 4 && !acknowledged && !downtime)                    { pos = x; }
                break;
            case "downtime_pending":
                if(state == 4 && downtime)                                      { pos = x; }
                break;
            default:
                //throw new Error("unhandled state: '"+order[x]+"'");
                break;
        }
        // first hit sets the current overall state
        if(pos != undefined) {
            break;
        }
    }
    if(pos == undefined) {
        return(0);
    }
    return(order.length - pos);
}

TP.resetMoveIcons = function() {
    Ext.Array.each(TP.moveIcons, function(item) {
        item.el.dom.style.outline = "";
        if(item.labelEl) {
            item.labelEl.el.dom.style.outline = "";
        }
    });
    TP.moveIcons = undefined;
    if(TP.keynav) {
        TP.keynav.destroy();
        TP.keynav = undefined;
    }
    if(TP.lassoEl) {
        TP.lassoEl.destroy();
        TP.lassoEl = undefined;
    }
}

TP.createIconMoveKeyNav = function() {
    if(TP.keynav) { return; }
    TP.keynav = Ext.create('Ext.util.KeyNav', Ext.getBody(), {
        'left':  function(evt){ if(TP.moveIcons && TP.moveIcons[0]) { var pos = TP.moveIcons[0].getPosition(); TP.moveIcons[0].setPosition(pos[0]-1, pos[1]); }},
        'right': function(evt){ if(TP.moveIcons && TP.moveIcons[0]) { var pos = TP.moveIcons[0].getPosition(); TP.moveIcons[0].setPosition(pos[0]+1, pos[1]); }},
        'up':    function(evt){ if(TP.moveIcons && TP.moveIcons[0]) { var pos = TP.moveIcons[0].getPosition(); TP.moveIcons[0].setPosition(pos[0], pos[1]-1); }},
        'down':  function(evt){ if(TP.moveIcons && TP.moveIcons[0]) { var pos = TP.moveIcons[0].getPosition(); TP.moveIcons[0].setPosition(pos[0], pos[1]+1); }},
        'esc':   function(evt){ TP.resetMoveIcons(); },
        ignoreInputFields: true
    });
}


/* delay link opening to allow double click menu */
TP.iconClickHandler = function(id) {
    if(Ext.getCmp(id).passClick) { return true; }
    window.clearTimeout(TP.timeouts['click'+id]);
    TP.timeouts['click'+id] = window.setTimeout(function() {
        TP.iconClickHandlerDo(id);
    }, 200);
    return false;
}
/* actually open the clicked link */
TP.iconClickHandlerDo = function(id) {
    var panel = Ext.getCmp(id);
    if(!panel || !panel.xdata || !panel.xdata.link || !panel.xdata.link.link) {
        return(false);
    }
    var link    = panel.xdata.link.link;
    var newTab  = panel.xdata.link.newtab;
    if(!panel.locked) {
        TP.Msg.msg("info_message~~icon links are disabled in edit mode, would have openend:<br><b>"+link+"</b>"+(newTab?'<br>(in a new tab)':''));
        return(false);
    }
    var target = "";
    if(newTab) {
        target = '_blank';
    }
    return(TP.iconClickHandlerExec(id, link, panel, target));
}

/* open link or special action for given link */
TP.iconClickHandlerExec = function(id, link, panel, target, config, extraOptions) {
    if(!link) { return; }
    if(config       == undefined) { config       = {}; }
    if(extraOptions == undefined) { extraOptions = {}; }
    if(typeof link === "function") {
        var args = TP.getMenuArgs(panel, target, {menu_id: id, config: config, extraOptions: extraOptions });
        link(args);
        return;
    }
    var special = link.match(/dashboard:\/\/(.+)$/);
    var action  = link.match(/server:\/\/(.+)$/);
    var menu    = link.match(/menu:\/\/(.+)$/);
    if(special && special[1]) {
        link = undefined;
        if(special[1].match(/^\d+$/)) {
            // is that tab already open?
            var tabbar = Ext.getCmp('tabbar');
            var tab_id = "pantab_"+special[1];
            var tab    = Ext.getCmp(tab_id);
            if(tab && tab.rendered) {
                tabbar.setActiveTab(tab);
            } else {
                var replace;
                if(!target) {
                    replace = tabbar.getActiveTab().id;
                }
                TP.add_pantab({ id: tab_id, replace_id: replace });
            }
        }
        else if(special[1] == 'show_details') {
            link = TP.getIconDetailsLink(panel);
        }
        else if(special[1] == 'refresh') {
            var el = panel.getEl();
            TP.updateAllIcons(panel.tab, panel.id, undefined, el)
            el.mask(el.getSize().width > 50 ? "refreshing" : undefined);
        } else {
            TP.Msg.msg("fail_message~~unrecognized link: "+special[1]);
        }
    }
    if(action && action[1]) {
        var params = {
            host:      panel.xdata.general.host,
            service:   panel.xdata.general.service,
            link:      link,
            dashboard: panel.tab.nr(),
            icon:      id,
            CSRFtoken: CSRFtoken
        };
        Ext.Ajax.request({
            url:    url_prefix+'cgi-bin/panorama.cgi?task=serveraction',
            params:  params,
            method: 'POST',
            callback: function(options, success, response) {
                if(extraOptions.callback) { extraOptions.callback(success, extraOptions); }
                if(!success) {
                    if(response.status == 0) {
                        TP.Msg.msg("fail_message~~server action failed");
                    } else {
                        TP.Msg.msg("fail_message~~server action failed: "+response.status+' - '+response.statusText);
                    }
                } else {
                    var data = TP.getResponse(undefined, response);
                    if(data.rc == 0) {
                        if(data.msg != "") {
                            TP.Msg.msg("success_message~~"+data.msg, config.close_timeout);
                        }
                    } else {
                        TP.Msg.msg("fail_message~~"+data.msg, config.close_timeout);
                    }
                }
            }
        });
        return(false);
    }
    if(menu && menu[1]) {
        var menuData = TP.parseActionMenuItemsStr(menu[1], id, panel, target, extraOptions);
        if(!menuData) {
            return(false);
        }
        TP.showIconMenu(menuData, id, panel, target, extraOptions);
        return(false);
    }
    if(link) {
        if(!link.match(/\$/)) {
            // no macros, no problems
            TP.iconClickHandlerClickLink(panel, link, target);
            if(extraOptions.callback) { extraOptions.callback(true, extraOptions); }
        } else {
            var tab = panel.tab;
            Ext.Ajax.request({
                url:    url_prefix+'cgi-bin/status.cgi?replacemacros=1',
                params:  {
                    host:      panel.xdata.general.host,
                    service:   panel.xdata.general.service,
                    backend:   TP.getActiveBackendsPanel(tab, panel),
                    data:      link,
                    CSRFtoken: CSRFtoken
                },
                method: 'POST',
                callback: function(options, success, response) {
                    if(extraOptions.callback) { extraOptions.callback(success, extraOptions); }
                    if(!success) {
                        if(response.status == 0) {
                            TP.Msg.msg("fail_message~~could not replace macros");
                        } else {
                            TP.Msg.msg("fail_message~~could not replace macros: "+response.status+' - '+response.statusText);
                        }
                    } else {
                        var data = TP.getResponse(undefined, response);
                        if(data.rc != 0) {
                            TP.Msg.msg("fail_message~~could not replace macros: "+data.data);
                        } else {
                            TP.iconClickHandlerClickLink(panel, data.data, target);
                        }
                    }
                }
            });

        }
    }
    return(true);
};

TP.showIconMenu = function(menuData, id, panel, target, extraOptions) {
    if(menuData && menuData.then) {
        menuData.then(function(items) {
            var parsed = TP.parseActionMenuItems(items, id, panel, target, extraOptions);
            TP.showIconMenu(parsed, id, panel, target, extraOptions);
            return(false);
        });
        return(false);
    }
    var autoOpen = false;
    if(!Ext.isArray(menuData)) {
        menuData = TP.parseActionMenuItems(menuData, id, panel, target, extraOptions);
        autoOpen = true;
    }
    TP.suppressIconTip = true;
    var menu = Ext.create('Ext.menu.Menu', {
        id: 'iconActionMenu',
        items: menuData,
        listeners: {
            beforehide: function(This) {
                TP.suppressIconTip = false;
                This.destroy();
            },
            move: function(This, x, y) {
                // somehow menu is place offset, even if showBy is called, force the location to our aligned element
                This.showBy(extraOptions.alignTo || panel);
            }
        },
        cls: autoOpen ? 'hidden' : ''
    }).showBy(extraOptions.alignTo || panel);
    if(autoOpen) {
        link = menu.items.get(0);
        link.fireEvent("click");
        menu.hide();
    }
    return(false);
}

/* parse action menu from json string data */
TP.parseActionMenuItemsStr = function(str, id, panel, target, extraOptions, plain) {
    var tmp = str.split(/\//);
    var menuName = tmp.shift();
    var menuArgs = tmp;
    var menu;
    Ext.Array.each(action_menu_items, function(val, i) {
        if(val.name == menuName) {
            menu = val;
            return(false);
        }
    });
    if(!menu) {
        TP.Msg.msg("fail_message~~no such menu: "+str);
        return(false);
    }
    var menuData;
    if(menu.type == "js" && menu["function"] && window[menu["function"]]) {
        try {
            var args = TP.getMenuArgs(panel, target, {menu_id: id, extraOptions: extraOptions, args: menuArgs });
            menuData = window[menu["function"]](args);
        } catch(e) {
            TP.Msg.msg("fail_message~~menu "+str+": failed to run js menu - "+e);
            return(false);
        }
    } else {
        try {
            menuData  = Ext.JSON.decode(menu.data);
        } catch(e) {
            TP.Msg.msg("fail_message~~menu "+str+": failed to parse json - "+e);
            return(false);
        }
    }
    if(!menuData['menu'] || plain) {
        return(menuData);
    }
    return(TP.parseActionMenuItems(menuData['menu'], id, panel, target, extraOptions));
}

TP.parseActionMenuItems = function(items, id, panel, target, extraOptions) {
    if(typeof items === "function") {
        var args = TP.getMenuArgs(panel, target, {menu_id: id, extraOptions: extraOptions });
        return(items(args));
    }
    var menuItems = [];
    Ext.Array.each(items, function(i, x) {
        if(Ext.isString(i)) {
            /* probably a separator, like '-' */
            menuItems.push(i);
        } else {
            var menuItem = {
                text:    i.label,
                icon:    replace_macros(i.icon)
            };
            var handler = function(This, evt) {
                if(i.target) {
                    target = i.target;
                }
                return(TP.iconClickHandlerExec(id, i.action, panel, target, i, extraOptions));
            };
            var listeners = {};
            for(var key in i) {
                if(key != "icon" && key != "action" && key != "menu" && key != "label") {
                    if(key.match(/^on/)) {
                        var fn = new Function(i[key]);
                        if(key == "onclick") {
                            listeners[key.substring(2)] = function() {
                                if(fn()) {
                                    handler();
                                }
                            }
                        } else {
                            listeners[key.substring(2)] = fn;
                        }
                    } else {
                        menuItem[key] = i[key];
                    }
                }
            }
            if(!i.onclick) {
                //listeners["click"] = handler;
                menuItem.handler = handler;
            }
            menuItem.listeners = listeners;

            if(i.html) {
                menuItem.text = i.html;
                menuItem.hideOnClick = false;
                menuItem.disabled = true; // hack to prevent item stealing focus from input fields
                menuItem.disabledCls = '';
            }

            // submenus?
            if(i.menu) {
                if(typeof i.menu === "function") {
                    menuItem.menu = {
                        items: [{
                            text:    'Loading...',
                            icon:    url_prefix+'plugins/panorama/images/loading-icon.gif',
                            disabled: true
                        }],
                        listeners: {
                            beforeshow: function(This, eOpts) {
                                var args = TP.getMenuArgs(panel, target, {menu_id: id, extraOptions: extraOptions });
                                jQuery.when(i.menu(args)).then(function(items) {
                                    var parsed = TP.parseActionMenuItems(items, id, panel, target, extraOptions);
                                    This.removeAll();
                                    Ext.Array.each(parsed, function(i) {
                                        This.add(i);
                                    });
                                })
                            }
                        }
                    };
                } else {
                    menuItem.menu = {
                        items: TP.parseActionMenuItems(i.menu, id, panel, target, extraOptions)
                    }
                }
            }

            menuItems.push(menuItem);
        }
    });
    return(menuItems);
}

TP.getMenuArgs = function(panel, target, args) {
    var tab      = panel.tab;
    args.panel   = panel;
    args.target  = target;
    args.backend = TP.getActiveBackendsPanel(tab, panel);
    args.host    = null;
    args.service = null;
    if(panel && panel.xdata && panel.xdata.general) {
        args.host = panel.xdata.general.host;
        args.service = panel.xdata.general.service;
    }
    return(args);
}

TP.iconClickHandlerClickLink = function(panel, link, target) {
    var oldOnClick=panel.el.dom.onclick;
    panel.el.dom.onclick="";
    panel.el.dom.href=link;
    panel.passClick = true;
    if(target) {
        panel.el.dom.target = target;
    }
    panel.el.dom.click();
    window.setTimeout(function() {
        if(panel && panel.el) {
            // restore original link
            if(panel.xdata.link && panel.xdata.link.link) {
                panel.el.dom.href=panel.xdata.link.link;
            } else {
                panel.el.dom.href="#";
            }
            panel.el.dom.onclick=oldOnClick;
            panel.passClick = false;
        }
    }, 300);
}

/* return link representing the data for this icon */
TP.getIconDetailsLink = function(panel, relativeUrl) {
    if(!panel.xdata || !panel.xdata.general) {
        return('#');
    }
    var cfg = panel.xdata.general;
    var options = {
        backends: TP.getActiveBackendsPanel(panel.tab, panel)
    };
    var base = "status.cgi";
    if(cfg.hostgroup) {
        options.hostgroup = cfg.hostgroup;
    }
    else if(cfg.service) {
        options.host    = cfg.host;
        options.service = cfg.service;
        options.type    = 2;
        base            = "extinfo.cgi";
    }
    else if(cfg.servicegroup) {
        options.servicegroup = cfg.servicegroup;
    }
    else if(cfg.host) {
        options.host = cfg.host;
    }
    else if(cfg.filter) {
        options.filter = cfg.filter;
        options.task   = 'redirect_status';
        base           = 'panorama.cgi';
        if(!cfg.incl_svc) {
            options.style = 'hostdetail';
        }
    }
    else if(cfg.dashboard) {
        options.map    = cfg.dashboard;
        base           = 'panorama.cgi';
        relativeUrl    = true;
    } else {
        return('#');
    }
    if(relativeUrl) {
        return(base+"?"+Ext.Object.toQueryString(options));
    }
    if(use_frames) {
        return(url_prefix+"#cgi-bin/"+base+"?"+Ext.Object.toQueryString(options));
    } else {
        return(base+"?"+Ext.Object.toQueryString(options));
    }
}

/* get gradient for color */
TP.createGradient = function(color, num, color2, percent) {
    if(num == undefined) { num = 0.2; }
    color  = Ext.draw.Color.fromString(color);
    if(color == undefined) { color = Ext.draw.Color.fromString('#DDDDDD'); }
    color2 = color2 ? Ext.draw.Color.fromString(color2) : color;
    var start;
    var end;
    if(num > 0) {
        start = color2.getLighter(Number(num)).toString();
        end   = color.toString();
    } else if (num < 0) {
        start = color.toString();
        end   = color2.getDarker(Number(-num)).toString();
    }
    var colorname1 = color.toString().replace(/^#/, '');
    var colorname2 = color2.toString().replace(/^#/, '');
    var g = {
        id: 'fill'+colorname1+colorname2+num,
        angle: 45,
        stops: {
              0: { color: start }
        }
    };
    if(percent != undefined) {
        if(percent > 10 && percent < 90) {
            g.stops[percent-10] = { color: start };
            g.stops[percent+10] = { color: end };
        } else {
            g.stops[percent] = { color: end };
        }
        g.stops[100] = { color: end };
        g.id         = 'fill'+colorname1+colorname2+num+percent;
    } else {
        g.stops[100] = { color: end };
    }
    return(g);
}

/* extract min/max */
TP.getPerfDataMinMax = function(p, maxDefault) {
    var r = { warn: undefined, crit: undefined, min: 0, max: maxDefault };
    if(p.max)           { r.max = p.max; }
    else if(p.crit_max) { r.max = p.crit_max; }
    else if(p.warn_max) { r.max = p.warn_max; }
    if(p.unit == '%')   { r.max = 100; }

    if(p.min)           { r.min = p.min; }
    return(r);
}

/* return natural size cross browser compatible */
TP.getNatural = function(src) {
    if(TP.imageSizes == undefined) { TP.imageSizes = {} }
    if(TP.imageSizes[src] != undefined) {
        return {width: TP.imageSizes[src][0], height: TP.imageSizes[src][1]};
    }
    img = new Image();
    img.src = src;
    if(img.width > 0 && img.height > 0) {
        TP.imageSizes[src] = [img.width, img.height];
    }
    return {width: img.width, height: img.height};
}

/* calculates availability used in labels */
function availability(panel, opts) {
    TP.lastAvailError = undefined;
    if(panel.iconType == 'hostgroup' || panel.iconType == 'filter') {
        if(panel.xdata.general.incl_hst) { opts['incl_hst'] = 1; }
        if(panel.xdata.general.incl_svc) { opts['incl_svc'] = 1; }
    }
    var opts_enc = Ext.JSON.encode(opts);
    if(TP.availabilities[panel.id] == undefined) { TP.availabilities[panel.id] = {}; }
    var refresh = false;
    var now     = Math.floor(new Date().getTime()/1000);
    if(TP.availabilities[panel.id][opts_enc] == undefined) {
        refresh = true;
        TP.availabilities[panel.id][opts_enc] = {
            opts:         opts,
            last_refresh: TP.iconSettingsWindow == undefined ? now : 0,
            last:        -1
        };
    }
    /* refresh every 30seconds max */
    else if(TP.availabilities[panel.id][opts_enc]['last_refresh'] < now - (thruk_debug_js ? 5 : 30)) {
        refresh = true;
    }
    TP.availabilities[panel.id][opts_enc]['active'] = now;
    if(refresh) {
        if(TP.iconSettingsWindow != undefined) {
            if(!Ext.isNumeric(TP.availabilities[panel.id][opts_enc]['last'])) {
                TP.lastAvailError = TP.availabilities[panel.id][opts_enc]['last'];
            }
            return(TP.availabilities[panel.id][opts_enc]['last']);
        }
        TP.availabilities[panel.id][opts_enc]['last_refresh'] = now;
        TP.updateAllLabelAvailability(panel.tab);
    }
    if(!Ext.isNumeric(TP.availabilities[panel.id][opts_enc]['last'])) {
        TP.lastAvailError = TP.availabilities[panel.id][opts_enc]['last'];
    }
    return(TP.availabilities[panel.id][opts_enc]['last']);
}


TP.iconMoveHandler = function(icon, x, y) {
    var deltaX = x - icon.xdata.layout.x;
    var deltaY = y - icon.xdata.layout.y;
    if(isNaN(deltaX) || isNaN(deltaY)) { return; }
    if(deltaX == 0 && deltaY == 0) { return; }

    // update settings window
    if(TP.iconSettingsWindow) {
        // layout tab
        Ext.getCmp('layoutForm').getForm().setValues({x:x, y:y});
        // appearance tab
        TP.skipRender = true;
        Ext.getCmp('appearanceForm').getForm().setValues({
            connectorfromx: icon.xdata.appearance.connectorfromx + deltaX,
            connectorfromy: icon.xdata.appearance.connectorfromy + deltaY,
            connectortox:   icon.xdata.appearance.connectortox   + deltaX,
            connectortoy:   icon.xdata.appearance.connectortoy   + deltaY
        });
        TP.skipRender = false;
    }
    // update label
    if(icon.setIconLabel) {
        icon.setIconLabelPosition();
    }

    // moving with closed settings window
    if(icon.stateful) {
        if(icon.setIconLabel) {
            if(!icon.locked) {
                icon.xdata.layout.x = Math.floor(x);
                icon.xdata.layout.y = Math.floor(y);
            }

            if(icon.xdata.appearance.type == "connector" && icon.xdata.appearance.connectorfromx != undefined) {
                icon.xdata.appearance.connectorfromx += deltaX;
                icon.xdata.appearance.connectorfromy += deltaY;
                icon.xdata.appearance.connectortox   += deltaX;
                icon.xdata.appearance.connectortoy   += deltaY;
            }
        }

        // move aligned items too
        TP.moveAlignedIcons(deltaX, deltaY, icon.id);
    }

    // update drag elements
    if(icon.dragEl1) { icon.dragEl1.resetDragEl(); }
    if(icon.dragEl2) { icon.dragEl2.resetDragEl(); }

    icon.updateMapLonLat();
    icon.saveState();
}

TP.moveAlignedIcons = function(deltaX, deltaY, skip_id) {
    if(!TP.moveIcons) { return; }
    deltaX = Number(deltaX);
    deltaY = Number(deltaY);
    if(deltaX == 0 && deltaY == 0) { return; }
    Ext.Array.each(TP.moveIcons, function(item) {
        if(item.id != skip_id) {
            if(item.setIconLabel) {
                item.suspendEvents();
                item.xdata.layout.x = Number(item.xdata.layout.x) + deltaX;
                item.xdata.layout.y = Number(item.xdata.layout.y) + deltaY;
                item.setPosition(item.xdata.layout.x, item.xdata.layout.y);
                if(item.xdata.appearance.type == "connector") {
                    item.xdata.appearance.connectorfromx = Number(item.xdata.appearance.connectorfromx) + deltaX;
                    item.xdata.appearance.connectorfromy = Number(item.xdata.appearance.connectorfromy) + deltaY;
                    item.xdata.appearance.connectortox   = Number(item.xdata.appearance.connectortox)   + deltaX;
                    item.xdata.appearance.connectortoy   = Number(item.xdata.appearance.connectortoy)   + deltaY;
                }
                item.setIconLabel();
                item.resumeEvents();
                item.saveState();
            } else {
                item.moveDragEl(deltaX, deltaY);
            }
        }
    });
}

/* convert list of points to svg path */
TP.pointsToPath = function(points) {
    var l = points.length;
    if(l == 0) {return("");}
    var path = "M";
    for(var x = 0; x < l; x++) {
        var p = points[x];
        path += " "+p[0]+","+p[1];
    }
    path += " Z";
    return(path);
}

/* create gradient and return color by state */
TP.getShapeColor = function(type, panel, xdata, forceColor) {
    var state = xdata.state, fillcolor, r, color1, color2;
    var p     = {};
    var perc  = 100;
    if(state == undefined) { state = panel.xdata.state; }

    // host panels use warnings color for unreachable, just the label got changed in the settings menu
    // all other panels must be mapped to service states because they can only define service colors
    if(panel.iconType != 'host' && panel.hostProblem) {
        if(state == 1) { state = 2 }
    }

    if(xdata.appearance[type+"source"] == undefined) { xdata.appearance[type+"source"] = 'fixed'; }
    if(forceColor != undefined) { fillcolor = forceColor; }
    else if(panel.acknowledged && !xdata.general.incl_ack)   { fillcolor = xdata.appearance[type+"color_ok"]; }
    else if(panel.downtime && !xdata.general.incl_downtimes) { fillcolor = xdata.appearance[type+"color_ok"]; }
    else if(state == 0)         { fillcolor = xdata.appearance[type+"color_ok"]; }
    else if(state == 1)         { fillcolor = xdata.appearance[type+"color_warning"]; }
    else if(state == 2)         { fillcolor = xdata.appearance[type+"color_critical"]; }
    else if(state == 3)         { fillcolor = xdata.appearance[type+"color_unknown"]; }
    else if(state == 4)         { fillcolor = "#777777"; }
    if(!fillcolor)              { fillcolor = '#333333'; }

    var matches = xdata.appearance[type+"source"].match(/^perfdata:(.*)$/);
    if(matches && matches[1]) {
        var macros = TP.getPanelMacros(panel);
        if(macros.perfdata[matches[1]]) {
            p      = macros.perfdata[matches[1]];
            r      = TP.getPerfDataMinMax(p, 100);
            color1 = xdata.appearance[type+"color_ok"];
            color2 = xdata.appearance[type+"color_ok"];
            /* inside critical range: V c w o w c  */
            if(p.crit_min != "" && p.val < p.crit_min) {
                color1 = xdata.appearance[type+"color_critical"];
                color2 = xdata.appearance[type+"color_critical"];
                perc   = 100;
            }
            /* above critical threshold: o w c V */
            else if(p.crit_max != "" && p.val > p.crit_max) {
                color1 = xdata.appearance[type+"color_critical"];
                color2 = xdata.appearance[type+"color_critical"];
                perc   = 100;
            }
            /* inside warning range low: c V w o w c */
            else if(p.warn_min != "" && p.val < p.warn_min && p.val > p.crit_min) {
                color1 = xdata.appearance[type+"color_warning"];
                color2 = xdata.appearance[type+"color_critical"];
                perc = Math.floor(((p.warn_min - p.val) / (p.warn_min - p.crit_min))*100);
            }
            /* inside warning range high: c w o w V c */
            else if(p.warn_min != "" && p.val > p.warn_max && p.val < p.crit_max) {
                color1 = xdata.appearance[type+"color_warning"];
                color2 = xdata.appearance[type+"color_critical"];
                perc = Math.floor(((p.val - p.warn_max) / (p.crit_max - p.warn_max))*100);
            }
            /* above warning threshold: o w V c */
            else if(p.warn_max != "" && p.val > p.warn_max) {
                color1 = xdata.appearance[type+"color_warning"];
                color2 = xdata.appearance[type+"color_critical"];
                perc   = Math.floor(((p.val - p.warn_max) / (r.max - p.warn_max))*100);
            }
            /* below warning threshold: o V w c */
            else if(p.warn_max != "" && p.val < p.warn_max) {
                color1 = xdata.appearance[type+"color_ok"];
                color2 = xdata.appearance[type+"color_warning"];
                perc   = Math.floor(((p.val - r.min) / (p.warn_max - r.min))*100);
            }
        }
    }

    if(xdata.appearance[type+"gradient"] != 0) {
        /* dynamic gradient */
        if(panel.surface.existingGradients == undefined) { panel.surface.existingGradients = {}; }
        if(xdata.appearance[type+"source"] != 'fixed' &&  color1 != undefined && color2 != undefined) {
            var gradient = TP.createGradient(color1, xdata.appearance[type+"gradient"], color2, perc);
            if(panel.surface.existingGradients[gradient.id] == undefined) {
                panel.surface.addGradient(gradient);
                panel.surface.existingGradients[gradient.id] = true;
            }
            return({color: "url(#"+gradient.id+")", value: p.val, perfdata: p, range: r});
        } else {
            /* fixed gradient from state color */
            var gradient = TP.createGradient(fillcolor, xdata.appearance[type+"gradient"]);
            if(panel.surface.existingGradients[gradient.id] == undefined) {
                panel.surface.addGradient(gradient);
                panel.surface.existingGradients[gradient.id] = true;
            }
            return({color: "url(#"+gradient.id+")", value: p.val, perfdata: p, range: r});
        }
    }
    /* fixed state color */
    return({color: fillcolor, value: p.val, perfdata: p, range: r});
}

TP.evalInContext = function(js, context) {
    var restore = {};
    for(var key in context) { restore[key] = window[key]; window[key] = context[key]; }
    var res, err;
    try {
        res = eval(js);
    } catch(e) { err = e; }
    for(var key in restore) {
        if(restore[key] == undefined) {
            delete(window[key]);
        } else {
            window[key] = restore[key];
        }
    }
    if(err) { throw(err); }
    return(res);
}

TP.getPanelMacros = function(panel) {
    var macros = { panel: panel };
    if(panel.servicegroup) { macros.totals = panel.servicegroup; macros['alias'] = panel.servicegroup.alias; macros['name'] = panel.servicegroup.name; }
    if(panel.hostgroup)    { macros.totals = panel.hostgroup;    macros['alias'] = panel.hostgroup.alias;    macros['name'] = panel.hostgroup.name; }
    if(panel.results)      { macros.totals = panel.results; }
    if(panel.host)         { for(var key in panel.host)    { macros[key] = panel.host[key];    } macros['performance_data'] = panel.host['perf_data']; }
    if(panel.service)      { for(var key in panel.service) { macros[key] = panel.service[key]; } macros['performance_data'] = panel.service['perf_data']; }
    if(macros.perf_data) {
        macros.perf_data = parse_perf_data(macros['performance_data']);
        macros.perfdata = {};
        for(var x = 0; x < macros.perf_data.length; x++) {
            var d = macros.perf_data[x];
            macros.perfdata[d.key] = d;
        }
    } else {
        macros.perfdata = {};
    }
    return(macros);
}
