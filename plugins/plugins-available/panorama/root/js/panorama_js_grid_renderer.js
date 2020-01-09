/* render date */
TP.render_date = function(v, td, item) {
    if(v == 0)  { return 'never'; }
    if(v == -1) { return ''; }
    return TP.date_format(v);
}

/* render real date */
TP.render_real_date = function(v, td, item) {
    if(v == null) { return 'never'; }
    // convert to timestamp first
    return "<div title='"+v+"'>"+TP.date_format(v.getTime() / 1000)+"<\/div>";
}

/* just add title */
TP.add_title  = function(v, td, item, row, col, store, view) {
    return "<div title='"+v+"'>"+v+"<\/div>";
}

/* render icon image */
TP.render_icon = function(v, td, item, row, col, store, view) {
    return "<img src='"+logo_path_prefix+v+"' border='0' width='20' height='20' alt='"+item.data.icon_image_alt+"' title='"+item.data.icon_image_alt+"'>";
}

/* render log icon */
TP.render_icon_log = function(v, td, item) {
    return "<div style=\"width:20px;height:20px;background-image:url(../themes/"+theme+"/images/"+v+");background-position:center center;background-repeat:no-repeat;\">&nbsp;<\/div>";
}

/* render site status icon */
TP.render_icon_site = function(v, td, item, row, col, store, view) {
    var title="";
    if(item.data.runtime=="") {
        title="title=\""+item.data.version+"\"";
    };
    var panel = view.up().up();
    var tab   = panel.tab;
    if(tab.activeBackends != undefined && tab.activeBackends[item.data.id] == false) {
        v = 'sport_golf.png';
    }
    return "<div class=\"clickable\" "+title+" onclick=\"TP.toggleBackend(this, \'"+panel.id+"\', \'"+item.data.id+"\')\" style=\"width:20px;height:20px;background-image:url(../plugins/panorama/images/"+v+");background-position:center center;background-repeat:no-repeat;\">&nbsp;<\/div>";
}

/* render enabled / disabled switch */
TP.render_enabled_switch = function(v, td, item) {
    if(v==1) {
        return "On";
    };
    return "Off";
}

/* render yes / no */
TP.render_yes_no = function(v, td, item) {
    if(v==1) {
        return "Yes";
    };
    return "No";
}

/* render On / Off */
TP.render_on_off = function(v, td, item) {
    if(v==1) {
        return "On";
    };
    return "Off";
}

/* return text status for service */
TP.text_host_status = function(v) {
    var state = 'Unknown';
         if(v==0) { state = 'Up';          }
    else if(v==1) { state = 'Down';        }
    else if(v==2) { state = 'Unreachable'; }
    else if(v==4) { state = 'Pending';     }
    return(state);
}

/* return text status */
TP.text_status = function(v, isHost) {
    if(isHost) { return(TP.text_host_status(v)); }
    return(TP.text_service_status(v));
}

/* render host status */
TP.render_host_status = function(v, td, item) {
    var state;
    if(item.data.has_been_checked==0) {
        state = 'Pending';
    } else {
        state = TP.text_host_status(v);
    }

    td.tdCls = state.toUpperCase();
    return state;
}

/* return text status for service */
TP.text_service_status = function(v) {
    var state = 'Unknown';
         if(v==0) { state = 'Ok';       }
    else if(v==1) { state = 'Warning';  }
    else if(v==2) { state = 'Critical'; }
    else if(v==4) { state = 'Pending';  }
    return(state);
}

/* render service status */
TP.render_service_status = function(v, td, item) {
    var state;
    if(item.data.has_been_checked==0) {
        state = 'Pending';
    } else {
        state = TP.text_service_status(v);
    }

    td.tdCls = state.toUpperCase();
    return state;
}

/* render status totals */
TP.render_statuscount = function(v, td, item, row, col, store, view) {
    if(v > 0) {
        td.tdCls = item.data.state.toUpperCase();
    }
    return v;
}

/* render hostname in service grid */
TP.render_service_host = function(v, td, item, row, col, store, view) {
    if(row == 0 || view.lastHost == undefined || view.lastHost != v) {
        view.lastHost = v;
        var hstate = 'Up';
        if(item.data.host_state==1) { hstate = 'Unreachable'; }
        if(item.data.host_state==2) { hstate = 'Down';        }
        td.tdCls = 'BG_'+hstate.toUpperCase();
        return TP.render_clickable_host(v, td, item, row, col, store, view);
    }
    return '';
}

/* render last check date */
TP.render_last_check = function(v, td, item) {
    if(item.data.last_check) {
        return TP.date_format(item.data.last_check);
    } else {
        return 'never';
    }
}

/* render duration */
TP.render_duration = function(v, td, item) {
    var d   = new Date();
    var now = Math.floor(d.getTime() / 1000);
    if(item.data.last_state_change) {
        return TP.duration(now - item.data.last_state_change);
    } else {
        var peer_key      = item.data.peer_key;
        var program_start = initial_backends[peer_key].program_start;
        return TP.duration(now - program_start)+'+';
    }
}

/* render peer name */
TP.render_peer_name = function(v, td, item) {
    var peer_key = item.data.peer_key;
    return(initial_backends[peer_key].name);
}

/* render current attempt */
TP.render_attempt = function(v, td, item) {
    var ret = item.data.current_attempt + '/' + item.data.max_check_attempts;
    if(!show_notification_number) { return(ret);}
    if(item.data.current_notification_number > 0) {
       ret = ret + ' #'+ item.data.current_notification_number;
    }
    if(item.data.first_notification_delay > 0) {
        var first_remaining = TP.calculate_first_notification_delay_remaining(item.data);
        if(first_remaining >= 0) {
            ret = ret + ' ~'+first_remaining+'min';
        }
    }
    return ret;
}

/* render check type */
TP.render_check_type = function(v, td, item) {
    if(v==0) { return "Active" }
    return "Passive";
}

/* render value of systat */
TP.render_systat_value = function(v, td, item, row, col, store, view) {
    if(item.data.cat == 'CPU') {
        return v + '%';
    }
    if(item.data.cat == 'Memory') {
        return v + 'MB';
    }
    return v;
}

/* render graph of systat */
TP.render_systat_graph = function(v, td, item, row, col, store, view) {
    if(item.data.warn == '') {
        return '';
    }
    var val = item.data.value;
    if(val > item.data.max) { val = item.data.max; }
    var perc   = Math.floor(val/item.data.max*100);
    var status = 'ok';
    if(item.data.value > item.data.warn) { status = 'warn'; }
    if(item.data.value > item.data.crit) { status = 'crit'; }
    td.tdCls = 'systat_graph';
    return "<div><div style='width:"+perc+"%; height: 15px;' class='systat_"+status+"'>&nbsp;<\/div><\/div>";
}

/* render plugin output */
TP.render_plugin_output = function(v, td, item) {
    var type = 'Host';
    if(item.data.description != undefined) { type = 'Service'; }
    if(item.data.has_been_checked == 0) {
        if(item.data.active_checks_enabled == 0) {
            return(type+' is not scheduled to be checked...');
        } else {
            return(type+' check scheduled for '+TP.date_format(item.data.next_check));
        }
    }
    if(item.data.long_plugin_output) {
        var long_plugin_output     = item.data.long_plugin_output.replace(/"/g, "&quot;");
        long_plugin_output     = long_plugin_output.replace(/'/g, "");
        long_plugin_output     = long_plugin_output.replace(/\\n/g, "<br>");
        long_plugin_output     = long_plugin_output.replace(/(\r\n|\n|\r)/gm,"");
        long_plugin_output     = long_plugin_output.replace(/&/g, "&amp;");
        return "<div class='clickable' style='color:blue;' onClick=\"Ext.Msg.alert('Plugin Output', '"+long_plugin_output+"')\">"+v+"<\/div>";
    }
    return v;
}

/* render host icons in service grid */
TP.render_host_service_icons = function(v, td, item, row, col, store, view) {
    var d = item.data;
    if(row == 0 || view.lastHostIcon == undefined || view.lastHostIcon != d.host_display_name) {
        view.lastHostIcon = d.host_display_name;
    } else {
        return '';
    }
    var data = {
        name:                     d.host_name,
        notifications_enabled:    d.host_notifications_enabled,
        check_type:               d.host_check_type,
        active_checks_enabled:    d.host_active_checks_enabled,
        accept_passive_checks:    d.host_accept_passive_checks,
        is_flapping:              d.host_is_flapping,
        acknowledged:             d.host_acknowledged,
        comments:                 d.host_comments,
        scheduled_downtime_depth: d.host_scheduled_downtime_depth,
        action_url_expanded:      d.host_action_url_expanded,
        notes_url_expanded:       d.host_notes_url_expanded,
        icon_image_expanded:      d.host_icon_image_expanded,
        icon_image_alt:           d.host_icon_image_alt,
        custom_variable_names:    d.host_custom_variable_names,
        custom_variable_values:   d.host_custom_variable_values,
        THRUK_ACTION_MENU:        item.raw.HOSTTHRUK_ACTION_MENU
    };
    return TP.render_host_icons(v, td, item, row, col, store, view, data);
}

/* render host icons */
TP.render_host_icons = function(v, td, item, row, col, store, view, data) {
    var icons = '';
    var d     = item.data;
    if(data != undefined) {
        d = data;
    }
    if(d.notifications_enabled == 0)   { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/ndisabled.gif" alt="Notifications for this host have been disabled" title="Notifications for this host have been disabled" border="0" height="20" width="20">'; }
    var passive_icon ='passiveonly.gif';
    if(hide_passive_icon) {
        passive_icon ='empty.gif';
    }
    if(strict_passive_mode) {
        if(d.check_type == 0 && d.active_checks_enabled == 0) { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/disabled.gif" alt="Checks of this host have been disabled" title="Checks of this host have been disabled" border="0" height="20" width="20">'; }
        if(d.check_type == 1 && d.accept_passive_checks == 0) { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/disabled.gif" alt="Checks of this host have been disabled" title="Checks of this host have been disabled" border="0" height="20" width="20">'; }
        if(d.check_type == 1 && d.accept_passive_checks == 1) { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/'+passive_icon+'" border="0" width="20" height="20" alt="Active checks of the host have been disabled - only passive checks are being accepted" title="This host is checked passive">'; }
    } else {
        if(d.active_checks_enabled == 0 && d.accept_passive_checks == 0) { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/disabled.gif" alt="Checks of this host have been disabled" title="Checks of this host have been disabled" border="0" height="20" width="20">'; }
        else if(d.active_checks_enabled == 0) { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/'+passive_icon+'" border="0" width="20" height="20" alt="Active checks of the host have been disabled - only passive checks are being accepted" title="Active checks of the host have been disabled - only passive checks are being accepted">'; }
    }

    if(d.is_flapping)                  { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/flapping.gif" alt="This host is flapping between states" border="0" height="20" width="20">'; }
    if(d.acknowledged)                 { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/ack.gif" alt="This host problem has been acknowledged" border="0" height="20" width="20">'; }
    if(d.comments.length > 0)          { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/comment.gif" alt="This host has '+d.comments.length+' comments associated with it" border="0" height="20" width="20" class="clickable" onclick="return(host_comments_popup(\''+d.name+'\', \''+((item && item.raw) ? item.raw.peer_key : '')+'\'))">'; }
    if(d.scheduled_downtime_depth > 0) { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/downtime.gif" alt="This host is currently in a period of scheduled downtime" border="0" height="20" width="20" class="clickable" onclick="return(host_downtimes_popup(\''+d.name+'\', \''+((item && item.raw) ? item.raw.peer_key : '')+'\'))">'; }
    if(d.action_url_expanded )         { icons += "<a href='"+d.action_url_expanded+"' target='_blank'><img src='"+url_prefix+"themes/"+theme+"/images/"+action_icon(d, host_action_icon)+"' border='0' width='20' height='20' alt='Perform Extra Host Actions' title='Perform Extra Host Actions'><\/a>"; }
    if(d.notes_url_expanded )          { icons += "<a href='"+d.notes_url_expanded+"' target='_blank'><img src='"+url_prefix+"themes/"+theme+"/images/notes.gif' border='0' width='20' height='20' alt='View Extra Host Notes' title='View Extra Host Notes'><\/a>"; }
    if(d.icon_image_expanded )         { icons += "<img src='"+logo_path_prefix+d.icon_image_expanded+"' border='0' width='20' height='20' alt='"+d.icon_image_alt+"' title='"+d.icon_image_alt+"'>"; }
    var action_menu = d.THRUK_ACTION_MENU || (item && item.raw) ? item.raw.THRUK_ACTION_MENU : null;
    if(action_menu) {
        icons += TP.addActionIconsFromMenu(action_menu, d.name);
    }
    return icons;
}

/* render service icons */
TP.render_service_icons = function(v, td, item, row, col, store, view, data) {
    var icons = '';
    var d     = item.data;
    if(data != undefined) {
        d = data;
    }
    if(d.notifications_enabled == 0)   { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/ndisabled.gif" alt="Notifications for this service have been disabled" title="Notifications for this service have been disabled" border="0" height="20" width="20">'; }
    var passive_icon ='passiveonly.gif';
    if(hide_passive_icon) {
        passive_icon ='empty.gif';
    }
    if(strict_passive_mode) {
        if(d.check_type == 0 && d.active_checks_enabled == 0) { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/disabled.gif" alt="Checks of this service have been disabled" title="Checks of this service have been disabled" border="0" height="20" width="20">'; }
        if(d.check_type == 1 && d.accept_passive_checks == 0) { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/disabled.gif" alt="Checks of this service have been disabled" title="Checks of this service have been disabled" border="0" height="20" width="20">'; }
        if(d.check_type == 1 && d.accept_passive_checks == 1) { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/'+passive_icon+'" border="0" width="20" height="20" alt="Active checks of the service have been disabled - only passive checks are being accepted" title="This service is checked passive">'; }
    } else {
        if(d.active_checks_enabled == 0 && d.accept_passive_checks == 0) { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/disabled.gif" alt="Checks of this service have been disabled" title="Checks of this service have been disabled" border="0" height="20" width="20">'; }
        else if(d.active_checks_enabled == 0) { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/'+passive_icon+'" border="0" width="20" height="20" alt="Active checks of the service have been disabled - only passive checks are being accepted" title="Active checks of the service have been disabled - only passive checks are being accepted">'; }
    }

    if(d.is_flapping)                  { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/flapping.gif" alt="This service is flapping between states" border="0" height="20" width="20">'; }
    if(d.acknowledged)                 { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/ack.gif" alt="This service problem has been acknowledged" border="0" height="20" width="20">'; }
    if(d.comments.length > 0)          { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/comment.gif" alt="This service has '+d.comments.length+' comments associated with it" border="0" height="20" width="20" class="clickable" onclick="return(service_comments_popup(\''+d.host_name+'\', \''+d.description+'\', \''+((item && item.raw) ? item.raw.peer_key : '')+'\'))">'; }
    if(d.scheduled_downtime_depth > 0) { icons += '<img src="'+url_prefix+'themes/'+theme+'/images/downtime.gif" alt="This service is currently in a period of scheduled downtime" border="0" height="20" width="20" class="clickable" onclick="return(service_downtimes_popup(\''+d.host_name+'\', \''+d.description+'\', \''+((item && item.raw) ? item.raw.peer_key : '')+'\'))">'; }
    if(d.action_url_expanded )         { icons += "<a href='"+d.action_url_expanded+"' target='_blank'><img src='"+url_prefix+"themes/"+theme+"/images/"+action_icon(d, service_action_icon)+"' border='0' width='20' height='20' alt='Perform Extra Service Actions' title='Perform Extra Service Actions'><\/a>"; }
    if(d.notes_url_expanded )          { icons += "<a href='"+d.notes_url_expanded+"' target='_blank'><img src='"+url_prefix+"themes/"+theme+"/images/notes.gif' border='0' width='20' height='20' alt='View Extra Service Notes' title='View Extra Service Notes'><\/a>"; }
    if(d.icon_image_expanded )         { icons += "<img src='"+logo_path_prefix+d.icon_image_expanded+"' border='0' width='20' height='20' alt='"+d.icon_image_alt+"' title='"+d.icon_image_alt+"'>"; }
    var action_menu = d.THRUK_ACTION_MENU || (item && item.raw) ? item.raw.THRUK_ACTION_MENU : null;
    if(action_menu) {
        icons += TP.addActionIconsFromMenu(action_menu, d.host_name, d.description);
    }
    return icons;
}

/* make host clickable */
TP.render_clickable_host = function(v, td, item, row, col, store, view) {
    td.tdCls += ' clickable';
    var host  = item.data.host_name ? item.data.host_name : item.data.name;
    host      = host.replace(/\\/g, '\\\\');
    return "<div class='clickable' onClick=\"TP.add_panlet({type:'TP.PanletHost', conf: { userOpened: true, xdata: { host: '"+host+"'}}})\">"+v+"<\/div>";
}

/* make host clickable */
TP.render_clickable_host_list = function(v, td, item, row, col, store, view) {
    td.tdCls += ' clickable';
    var msg = '';
    var host  = item.data.host_name ? item.data.host_name : item.data.name;
    if(row == 0 || view.lastHostParent == undefined || view.lastHostParent != host) {
        view.lastHostParent = host;
    } else {
        return '';
    }
    for(var nr=0; nr<v.length; nr++) {
        host = v[nr];
        msg += "<span class='clickable' onClick=\"TP.add_panlet({type:'TP.PanletHost', conf: { userOpened: true, xdata: { host: '"+host+"'}}})\">"+host+"<\/span>";
        if(nr+1 < v.length) {
            msg += ", ";
        }
    }
    return msg;
}

/* make service description clickable */
TP.render_clickable_service = function(v, td, item, row, col, store, view) {
    td.tdCls = 'clickable';
    var description = item.data.service_description || item.data.description || '';
    description = description.replace(/\\/g, '\\\\');
    var host_name   = item.data.host_name.replace(/\\/g, '\\\\');
    return "<div class='clickable' onClick=\"TP.add_panlet({type:'TP.PanletService', conf: { userOpened: true, xdata: { host: '"+host_name+"', service: '"+description+"'}}})\">"+v+"<\/div>";
}

/* render action url */
TP.render_action_url = function(v, td, item, row, col, store, view) {
    if (v) {
        return "<a href='"+v+"' target='_blank'><img src='"+url_prefix+"themes/"+theme+"/images/action.gif' border='0' width='20' height='20' alt='Perform Extra Actions' title='Perform Extra Actions'><\/a>";
    } else {
        return "";
    }
}

/* render notes url */
TP.render_notes_url = function(v, td, item, row, col, store, view) {
    if (v) {
        return "<a href='"+v+"' target='_blank'><img src='"+url_prefix+"themes/"+theme+"/images/notes.gif' border='0' width='20' height='20' alt='View Extra Notes' title='View Extra Notes'><\/a>";
    } else {
        return "";
    }
}


/* render gearman queues */
TP.render_gearman_queue = function(v, td, item, row, col, store, view) {
    td.tdCls = '';
    if(item.data.worker * 10 <= item.data.waiting) {
        td.tdCls = 'BG_WARNING';
    }
    if(item.data.worker * 20 <= item.data.waiting) {
        td.tdCls = 'BG_DOWN';
    }
    if(item.data.worker == 0 && item.data.waiting > 0) {
        td.tdCls = 'BG_DOWN';
    }
    if(item.data.waiting == 0) {
        td.tdCls = '';
    }
    return v;
}

/* create performance bar */
TP.render_perfbar = function(v, td, item, row, col, store, view) {
    if(perf_bar_mode == 'off') {
        return "";
    }
    var r =  perf_table(false, item.data.state, item.data.plugin_output, item.data.perf_data, item.data.check_command, "");
    if(r == false) { return ""; }
    td.tdCls = "less_padding";
    return r;
}

/* toggle visibility of dashboards */
TP.render_dashboard_toggle_visible = function(v, td, item, row, col, store, view) {
    var actions = "";
    var tab = Ext.getCmp(item.data.id);
    if(tab && tab.rendered) {
        actions += "<div class='clickable' title='removes dashboard from current view' onclick='Ext.getCmp(\""+item.data.id+"\").destroy(); TP.dashboardsSettingGrid.getView().refresh(); return false;' style='margin-left: -5px; width:20px;height:20px;background-image:url(../plugins/panorama/images/eye.png);background-position:center center;background-repeat:no-repeat;'>&nbsp;<\/div>";
    } else {
        actions += "<div class='clickable' title='adds this dashboard to current view' onclick='TP.add_pantab(\""+item.data.id+"\"); return false;' style='margin-left: -5px; width:20px;height:20px;background-image:url(../plugins/panorama/images/bullet_white.png);background-position:center center;background-repeat:no-repeat;'>&nbsp;<\/div>";
    }
    return(actions);
}

/* make long pluginout not break layout */
TP.render_long_pluginoutput = function(v, td, item, row, col, store, view) {
    v = v.replace(/\\n/g, "");
    v = v.replace(/(\r\n|\n|\r)/gm,"");
    v = v.replace(/<\s*/gm,"&lt;");
    v = v.replace(/>/gm,"&gt;");
    return v;
}

/* render direct link */
TP.render_directlink = function(v, td, item, row, col, store, view) {
    return "<a target='_blank' href='panorama.cgi?map="+item.data.name+"'><img src='"+url_prefix+"plugins/panorama/images/application_put.png' border='0' width='16' height='16' alt='direct url' title='open this dashboard only (new window)'><\/a>";
}

/* render enabled / disabled switch */
TP.render_entry_type = function(v, td, item) {
    if(v==1) { return "User Comment"; };
    if(v==2) { return "Scheduled Downtime"; };
    if(v==3) { return "Flap Detection"; };
    if(v==4) { return "Acknowledgement"; };
    return "?";
}

/* format timestamp */
TP.date_format = function(t, f) {
    var d = new Date(t*1000);
    if(f != undefined) {
        return Ext.Date.format(d, f);
    }
    if(Ext.Date.format(new Date(), "Y-m-d") == Ext.Date.format(d, "Y-m-d")) {
        return Ext.Date.format(d, "H:i:s");
    }
    return Ext.Date.format(d, "Y-m-d H:i:s");
}

/* format duration */
TP.duration = function(duration) {
    var minus = '';
    if(duration < 0) {
        duration = duration * -1;
        minus    = '-';
    }

    var days    = 0;
    var hours   = 0;
    var minutes = 0;
    var seconds = 0;
    if(duration >= 86400) {
        days     = Math.floor(duration/86400);
        duration = duration%86400;
    }
    if(duration >= 3600) {
        hours    = Math.floor(duration/3600);
        duration = duration%3600;
    }
    if(duration >= 60) {
        minutes  = Math.floor(duration/60);
        duration = duration%60;
    }
    seconds = duration;

    return(""+minus+days+"d "+hours+"h "+minutes+"m "+seconds+"s");
}

/* calculate remaining time till next notification */
TP.calculate_first_notification_delay_remaining = function(obj) {
    if(obj.state == 0) { return -1; }

    var first_problem_time = -1;
    if(obj.last_time_ok != undefined) {
        first_problem_time = obj.last_time_ok;
        if((obj.last_time_warning < first_problem_time) && (obj.last_time_warning > obj.last_time_ok)) {
            first_problem_time = obj.last_time_warning;
        }
        if((obj.last_time_unknown < first_problem_time) && (obj.last_time_unknown > obj.last_time_ok)) {
            first_problem_time = obj.last_time_unknown;
        }
        if((obj.last_time_critical < first_problem_time) && (obj.last_time_critical > obj.last_time_ok)) {
            first_problem_time = obj.last_time_critical;
        }
    }
    else if(obj.last_time_up != undefined) {
        first_problem_time = obj.last_time_up;
        if((obj.last_time_down < first_problem_time) && (obj.last_time_down > obj.last_time_up)) {
            first_problem_time = obj.last_time_down;
        }
        if((obj.last_time_unreachable < first_problem_time) && (obj.last_time_unreachable > obj.last_time_up)) {
            irst_problem_time = obj.last_time_unreachable;
        }
    }
    if(first_problem_time == 0) { return -1; }
    var d = new Date;
    var t = Math.floor(d.getTime() / 1000);
    var remaining_min = Math.floor((t - first_problem_time) / 60);
    if(remaining_min > obj.first_notification_delay) {
        return -1;
    }

    return(obj.first_notification_delay - remaining_min);
}

/* return action info icon */
function action_icon(o, action_icon) {
    for(var nr=0; nr<o.custom_variable_names.length; nr++) {
        if(o.custom_variable_names[nr] == 'ACTION_ICON') {
            return o.custom_variable_values[nr];
        }
    }
    return action_icon;
}

TP.addActionIconsFromMenu = function(action_menu_name, host, service) {
    var icons = "";
    var menuData = TP.parseActionMenuItemsStr(action_menu_name, '', '', '', {}, true);
    if(Ext.isArray(menuData)) {
        Ext.Array.forEach(menuData, function(icon, i) {
            icons += TP.addActionIcon(icon, action_menu_name, host, service);
        });
    } else {
        icons += TP.addActionIcon(menuData, action_menu_name, host, service);
    }
    return(icons);
}

TP.addActionIcon = function(icon, menuName, host, service) {
    var href = "";
    if(icon.action) {
        href = icon.action;
    }
    else {
        href = "menu://"+menuName;
    }
    var icon = '<a href="'+href+'" target="'+(icon.target || '')+'" onclick="return(TP.checkActionLink(this))" data-host="'+encodeURIComponent(host||'')+'" data-service="'+encodeURIComponent(service||'')+'">'
              +'<img src="'+replace_macros(icon.icon)+'" alt="'+replace_macros(icon.title||icon.label)+'" border="0" height="20" width="20">'
              +'</a>';
    return(icon);
}

TP.checkActionLink = function(a) {
    var panel = undefined;

    // find panel by iterating all parents
    var p = a;
    var panel;
    while(p.parentNode) {
        p = p.parentNode;
        if(p.id) {
            panel = Ext.getCmp(p.id);
            if(panel && panel.tab && panel.tab.id) {
                break;
            }
            panel = null;
        }
    }
    if(!panel) {
        return(false);
    }
    openActionUrlWithFakePanel(a, panel, a.href, decodeURIComponent(a.dataset.host || ''), decodeURIComponent(a.dataset.service || ''), a.target);
    return(false);
}
