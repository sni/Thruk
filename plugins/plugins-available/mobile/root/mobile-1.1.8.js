/* create the jquery mobile object */
jQuery(document).bind("mobileinit", function(){
    jQuery.mobile.page.prototype.options.backBtnText      = "back";
    jQuery.mobile.page.prototype.options.addBackBtn       = true;

    // theme?
    var theme = readCookie('thruk_mtheme');
    if(theme != undefined) {
        set_theme(theme);
    } else {
        set_theme('d');
    }

});

/* initialize all events */
jQuery(document).ready(function(e){
    /* refresh button on start page */
    jQuery("#refresh").bind( "vclick", function(event, ui) {
        refresh_host_status(true);
        refresh_service_status(true);
        return false;
    });

    /* bind option theme button */
    jQuery("A.theme_button").bind("vclick", function(event, ui) {
        var now         = new Date();
        var expires     = new Date(now.getTime() + (10*365*86400*1000)); // let the cookie expire in 10 years
        document.cookie = "thruk_mtheme=" + this.dataset.theme + "; path=/; expires=" + expires.toGMTString() + ";";
        window.location.reload();
    });

    /* bind full client button */
    jQuery("A#full_client_link").bind("vclick", function(event, ui) {
        document.cookie = "thruk_mobile=0; path=/;";
        window.location.assign(url_prefix + 'thruk/');
    });

    /* Options */
    jQuery('#options').bind('pageshow', function(event, info){
        page_options();
    });

    /* Last Alerts */
    jQuery('#last_alerts').bind('pageshow', function(event, info){
        page_alerts();
    });

    /* Last Notifications */
    jQuery('#last_notification').bind('pageshow', function(event, info){
        page_notifications();
    });

    /* Services List */
    jQuery('#services_list').bind('pageshow', function(event, info){
        page_services_list();
    });

    /* Hosts List */
    jQuery('#hosts_list').bind('pageshow', function(event, data){
        page_hosts_list();
    });

    /* Host */
    jQuery('#host').bind('pageshow', function(event, data){
        page_host();
    });

    /* Service */
    jQuery('#service').bind('pageshow', function(event, data){
        page_service();
    });

    /* Home */
    jQuery('#home').bind('pageshow', function(event, data){
        page_home();
    });

    /* set selected backends for options page */
    jQuery('.backend_checkbox').bind('change', function(event){
        var backend = event.target.name;
        if(event.target.checked) {
            current_backend_states[backend] = 0;
        } else {
            current_backend_states[backend] = 2;
        }
    });
    jQuery('#options_save').bind('vclick', function(event){
        var serialized = "";
        for(var key in current_backend_states){
            state = 2;
            if(jQuery("#backend_"+key).attr("checked")) {
                state = 0;
            }
            serialized += '&'+key+'='+state;
        };
        serialized = serialized.substring(1);
        document.cookie = "thruk_backends="+serialized+ "; path=/;";
    });

    /* refresh problems */
    jQuery('#problems').bind('pageshow', function(event, data){
        page_problems();
    });

    /* refresh list of hosts */
    jQuery('#hosts').bind('pageshow', function(event, data){
        page_hosts();
    });

    /* refresh list of services */
    jQuery('#services').bind('pageshow', function(event, data){
        page_services();
    });

    /* initialize numbers */
    refresh_host_status();
    refresh_service_status();

    /* hide notice about fullscreen mode */
    if(window.navigator.standalone == true) {
        jQuery('#fullscreenteaser').hide();
    }
});


/* send debug output to firebug console */
function debug(str) {
    if (window.console != undefined) {
        console.debug(str);
    }
}

/* return host status text */
function get_host_status(host) {
    if(host.has_been_checked == 0) { return("PENDING"); }
    if(host.state == 0) { return("UP"); }
    if(host.state == 1) { return("DOWN"); }
    if(host.state == 2) { return("UNREACHABLE"); }
}

/* return host status class */
function get_host_class(host) {
    if(host.has_been_checked == 0) { return("hostPENDING"); }
    return(get_host_class_for_state(host.state));
}

/* return host status class */
function get_host_class_for_state(state) {
    if(state == 0) { return("hostUP"); }
    if(state == 1) { return("hostDOWN"); }
    if(state == 2) { return("hostUNREACHABLE"); }
    if(state == 3) { return("hostPENDING"); }
}

/* return service status text */
function get_service_status(service) {
    if(service.has_been_checked == 0) { return("PENDING"); }
    if(service.state == 0) { return("OK"); }
    if(service.state == 1) { return("WARNING"); }
    if(service.state == 2) { return("CRITICAL"); }
    if(service.state == 3) { return("UNKNOWN"); }
}

/* return service status class */
function get_service_class(service) {
    if(service.has_been_checked == 0) { return("servicePENDING"); }
    return(get_service_class_for_state(service.state));
}

/* return service status class */
function get_service_class_for_state(state) {
    if(state == 0) { return("serviceOK"); }
    if(state == 1) { return("serviceWARNING"); }
    if(state == 2) { return("serviceCRITICAL"); }
    if(state == 3) { return("serviceUNKNOWN"); }
    if(state == 4) { return("servicePENDING"); }
    alert('unknown state' +  state);
}

/* return current unix timestamp */
function unixtime() {
    var d = new Date();
    return(Math.round(d.getTime()/1000));
}

/* return formated timestamp */
function format_time(timestamp) {
    var d   = new Date();
    d.setTime(timestamp*1000);
    var now = new Date();
    if(dateFormat(d, "yyyy-mm-dd") == dateFormat(now, "yyyy-mm-dd")) {
        return(dateFormat(d, "HH:MM:ss"));
    }
    return(dateFormat(d, "yyyy-mm-dd  HH:MM:ss"));
}

/* return duration format */
function format_duration(seconds, peer_key) {
    var now      = unixtime();
    var duration = undefined;
    if(seconds > 0) {
        duration = now - seconds;
    } else if(program_starts[peer_key] != undefined) {
        duration = now - program_starts[peer_key];
    }
    if(duration != undefined) {
        duration = filter_duration(duration);
        if(seconds == 0) {
            duration = duration+'+';
        }
        return(duration);
    }
    return('');
}

/* return human readable duration */
function filter_duration(duration) {
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

    if(days > 0) {
        return(""+minus+days+"d "+hours+"h "+minutes+"m "+seconds+"s");
    }
    if(hours > 0) {
        return(""+minus+hours+"h "+minutes+"m "+seconds+"s");
    }
    return(""+minus+minutes+"m "+seconds+"s");
}

/* set theme */
function set_theme(theme) {
    jQuery.mobile.page.prototype.options.backBtnTheme     = theme;
    jQuery.mobile.page.prototype.options.headerTheme      = theme;
    jQuery.mobile.page.prototype.options.contentTheme     = theme;
    jQuery.mobile.page.prototype.options.footerTheme      = theme;

    jQuery.mobile.listview.prototype.options.headerTheme  = theme;
    jQuery.mobile.listview.prototype.options.theme        = theme;
    jQuery.mobile.listview.prototype.options.dividerTheme = theme;

    jQuery.mobile.listview.prototype.options.splitTheme   = theme;
    jQuery.mobile.listview.prototype.options.countTheme   = theme;
    jQuery.mobile.listview.prototype.options.filterTheme  = theme;
}

/* set hosts status */
var last_host_refresh = 0;
var unhandled_host_problems = 0;
function refresh_host_status(force, update_backends) {
    if(force           == undefined) { force           = false; }
    if(update_backends == undefined) { update_backends = false; }
    var date = new Date;
    var now  = parseInt(date.getTime() / 1000);
    if(force == false && now < last_host_refresh + 15) {
        return false;
    }
    last_host_refresh = now;

    ['up', 'down', 'unreachable', 'pending', 'down_and_unhandled', 'unreachable_and_unhandled', 'unhandled' ].forEach(function(el){
        jQuery('.hosts_'+el+'_panel').hide();
    });

    jQuery.get('mobile.cgi', { data: 'host_stats', _:unixtime() },
        function(data, textStatus, XMLHttpRequest) {
            extract_data(data);
            data = data.data;
            ['up', 'down', 'unreachable', 'pending', 'total', 'down_and_unhandled', 'unreachable_and_unhandled'].forEach(function(el){
                var val = eval("data."+el);
                jQuery('.hosts_'+el).text(val)
                if(val > 0) { jQuery('.hosts_'+el+'_panel').show(); }
            });
            unhandled_host_problems = data.down_and_unhandled + data.unreachable_and_unhandled;
            jQuery('.hosts_unhandled').text('Host:' + unhandled_host_problems);
            jQuery('.hosts_unhandled_panel').hide();
            if(unhandled_host_problems > 0) {
                jQuery('.hosts_unhandled_panel').show();
            }
            if(update_backends) {
                refresh_backends();
            }
            if(unhandled_service_problems + unhandled_host_problems > 0) {
                jQuery('.no_problems').hide();
            } else {
                jQuery('.no_problems').show();
            }
        },
    'json');
}

/* set service status */
var last_service_refresh = 0;
var unhandled_service_problems = 0;
function refresh_service_status(force) {
    if(force == undefined) { force = false; }
    var date = new Date;
    var now  = parseInt(date.getTime() / 1000);
    if(force == false && now < last_service_refresh + 15) {
        return false;
    }
    last_service_refresh = now;

    ['ok', 'warning', 'critical', 'unknown', 'pending', 'unhandled', 'critical_and_unhandled', 'unknown_and_unhandled'].forEach(function(el){
        jQuery('.services_'+el+'_panel').hide();
    });
    jQuery.get('mobile.cgi', { data: 'service_stats', _:unixtime() },
        function(data, textStatus, XMLHttpRequest) {
            extract_data(data);
            data = data.data;
            ['ok', 'warning', 'critical', 'unknown', 'pending', 'total', 'critical_and_unhandled', 'unknown_and_unhandled'].forEach(function(el){
                var val = eval("data."+el);
                jQuery('.services_'+el).text(val)
                if(val > 0) { jQuery('.services_'+el+'_panel').show(); }
            });
            unhandled_service_problems = data.critical_and_unhandled + data.unknown_and_unhandled;
            jQuery('.services_unhandled').text('Service:' + unhandled_service_problems);
            jQuery('.services_unhandled_panel').hide();
            if(unhandled_service_problems > 0) {
                jQuery('.services_unhandled_panel').show();
            }
            if(unhandled_service_problems + unhandled_host_problems > 0) {
                jQuery('.no_problems').hide();
            } else {
                jQuery('.no_problems').show();
            }
        },
    'json');
}

/* refresh backends from global variable */
function refresh_backends() {
    if(current_backend_states != undefined) {
        number=0;
        for(var key in current_backend_states){
            number++;
            if(current_backend_states[key].state == 0 || current_backend_states[key].state == 1) {
                jQuery("#backend_"+key).attr("checked",true).checkboxradio("refresh");
            }
            if(current_backend_states[key].state == 1) {
                jQuery("#b_lab_"+key).addClass('hostDOWN');
            }
        };
        if(number > 1) {
            jQuery('#backend_chooser').show();
        }
    } else {
        jQuery('#backend_chooser').hide();
    }
}


/* set concetion status from data connection */
function extract_data(data) {
    current_backend_states = data.connection_status;
    program_starts         = data.program_starts;
    return;
}

/* Options Page */
function page_options() {
    jQuery('.waiting').show();
    if(current_backend_states == undefined) {
        refresh_host_status(true, true);
    } else {
        refresh_backends();
    }
    jQuery('.waiting').hide();
}

/* Alert List Page */
function page_alerts(page) {
    page = list_pager_init(page, 'alerts_list');
    jQuery.get('mobile.cgi', {
            data: 'alerts'
        },
        function(data, textStatus, XMLHttpRequest) {
            list_pager_data(page, data, 'alerts_list', function() { page_alerts(++page); }, function(entry) {
                var listitem = '';
                if(entry.service_description) {
                    listitem = '<li class="'+get_service_class_for_state(entry.state)+'">';
                } else {
                    listitem = '<li class="'+get_host_class_for_state(entry.state)+'">';
                }
                var message = entry.message.substring(13);
                message = message.replace(entry.type+':', '');
                if(message.length > 60) {
                    message = message.substring(0,60) + '...';
                }
                listitem += '<span class="logdate">' + format_time(entry.time) + '<\/span>';
                listitem += '<span class="logtype">' + entry.type + '<\/span>';
                listitem += '<br><span class="logmsg">' + message + '<\/span><\/li>';
                jQuery('#alerts_list').append(listitem);
            });
        },
        'json'
    );
}

/* Notifications Page */
function page_notifications(page) {
    page = list_pager_init(page, 'notification_list');
    jQuery.get('mobile.cgi', {
            data: 'notifications'
        },
        function(data, textStatus, XMLHttpRequest) {
            list_pager_data(page, data, 'notification_list', function() { page_notifications(++page); }, function(entry) {
                if(entry.service_description) {
                    jQuery('#notification_list').append('<li class="'+get_service_class_for_state(entry.state)+'"><span class="date">' + format_time(entry.time) + '</span><br>' + entry.host_name+' - '+ entry.service_description +'</li>');
                } else {
                    jQuery('#notification_list').append('<li class="'+get_host_class_for_state(entry.state)+'"><span class="date">' + format_time(entry.time) + '</span><br>' + entry.host_name+'</li>');
                }
            });
        },
        'json'
    );
}

/* Services List Page */
function page_services_list(page) {
    page       = list_pager_init(page, 'services_list_data');
    var params = get_params();
    jQuery.get('mobile.cgi', {
            data:               'services',
            servicestatustypes: params['servicestatustypes'],
            serviceprops:       params['serviceprops'],
            hoststatustypes:    params['hoststatustypes'],
            page:               page,
            _:                  unixtime()
        },
        function(data, textStatus, XMLHttpRequest) {
            list_pager_data(page, data, 'services_list_data', function() { page_services_list(++page); }, function(entry) {
                var icons = get_list_icons(entry);
                jQuery('#services_list_data').append('<li class="'+get_service_class(entry)+'"><a href="#service?host='+escape(entry.host_name)+'&service='+escape(entry.description)+'" data-ajax="false">' + entry.host_name+' - '+ entry.description +icons+'</a></li>');
            });
        },
        'json'
    );
}

/* Hosts List Page */
function page_hosts_list(page) {
    page       = list_pager_init(page, 'hosts_list_data');
    var params = get_params();
    jQuery.get('mobile.cgi', {
            data:           'hosts',
            hoststatustypes: params['hoststatustypes'],
            hostprops:       params['hostprops'],
            page:            page,
            _:               unixtime()
        },
        function(data, textStatus, XMLHttpRequest) {
            list_pager_data(page, data, 'hosts_list_data', function() { page_hosts_list(++page); }, function(entry) {
                var icons = get_list_icons(entry);
                jQuery('#hosts_list_data').append('<li class="'+get_host_class(entry)+'"><a href="#host?host='+escape(entry.name)+'" data-ajax="false">' + entry.name +icons+'</a></li>');
            });
        },
        'json'
    );
}

/* Host Page */
function page_host() {
    var params = get_params();
    hide_common_extinfo('host');
    jQuery.get('mobile.cgi', {
            data: 'hosts',
            host: params['host'],
            _:    unixtime()
        },
        function(data, textStatus, XMLHttpRequest) {
            var host = show_common_extinfo('host', data);
            if(host != undefined) {
                jQuery('#host_name').text(host.name);
                jQuery('#host_state').removeClass().text(get_host_status(host)).addClass(get_host_class(host));
                jQuery('#host_referer').val('mobile.cgi#host?host='+escape(host.name));
                show_common_acks_n_downtimes('host', host, data.comments, data.downtimes);
            }
        },
        'json'
    );
}

/* Service Page */
function page_service() {
    hide_common_extinfo('service');
    var params = get_params();
    jQuery.get('mobile.cgi', {
            data:    'services',
            host:    params['host'],
            service: params['service'],
            _:       unixtime()
        },
        function(data, textStatus, XMLHttpRequest) {
            var service = show_common_extinfo('service', data);
            if(service != undefined) {
                jQuery('#service_name').html(service.host_name + '<br>' + service.description);
                jQuery('#service_state').removeClass().text(get_service_status(service)).addClass(get_service_class(service));
                jQuery('#service_referer').val('mobile.cgi#service?host='+escape(service.host_name)+'&service='+escape(service.description));
                show_common_acks_n_downtimes('service', service, data.comments, data.downtimes);
            }
        },
        'json'
    );
}

/* Home Page */
function page_home() {
    refresh_host_status();
    refresh_service_status();
}

/* Problems Page */
function page_problems() {
    refresh_host_status();
    refresh_service_status();
    jQuery('DIV#problems UL.hosts_by_status_list').listview('refresh');
    jQuery('DIV#problems UL.services_by_status_list').listview('refresh');
}

/* Hosts Page */
function page_hosts() {
    refresh_host_status();
    jQuery('DIV#hosts .hosts_by_status_list').listview('refresh');
}

/* Services Page */
function page_services() {
    refresh_service_status();
    jQuery('DIV#services .services_by_status_list').listview('refresh');
}

/* get cookie value */
function readCookie(name) {
    var nameEQ = name + "=";
    var ca = document.cookie.split(';');
    for(var i=0;i < ca.length;i++) {
        var c = ca[i];
        while (c.charAt(0)==' ') c = c.substring(1,c.length);
        if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
    }
    return null;
}

/* return parameter from url */
function get_params() {
    var str    = document.location.hash;
    str        = str.replace(/#+.*\?/, '');
    var params = {};
    jQuery(str.split('&')).each(function(x, s) {
        p = s.split('=');
        params[p[0]] = unescape(p[1]);
    });
    return(params);
}

/* initialize list */
function list_pager_init(page, list) {
    if(page == undefined) { page = 1; }
    if(page == 1) {
        jQuery('#'+list).children().remove();
    } else {
        jQuery('.more').remove();
    }
    jQuery.mobile.showPageLoadingMsg();
    jQuery('#'+list).listview('refresh');
    return page;
}

/* paged list items */
function list_pager_data(page, data, list, more_callback, row_callback) {
    extract_data(data);
    if(page == 1) {
        jQuery('#'+list).children().remove();
    } else {
        jQuery('.more').remove();
    }
    jQuery.mobile.hidePageLoadingMsg();
    jQuery.each(data.data, function(index, entry) {
        row_callback(entry);
    });
    if(data.more != undefined) {
        jQuery('#'+list).append('<li data-icon="false" class="more"><a href="#">more...</a></li>');
        jQuery('.more').bind('vclick', more_callback);
    }
    jQuery('#'+list).listview('refresh');
}

/* hide elements from extinfo pages */
function hide_common_extinfo(typ) {
    jQuery.mobile.showPageLoadingMsg();
    ['attempt', 'name', 'state', 'duration', 'exec_time', 'last_check', 'next_check', 'check_type', 'plugin_output', 'current_notification_number'].forEach(function(el){
        jQuery('#'+typ+'_'+el).text('');
    });
    ['ack_form', 'acknowledged', 'downtime'].forEach(function(el){
        jQuery('.'+typ+'_'+el).hide();
    });
}

/* show common elements from extinfo pages */
function show_common_extinfo(typ, data, comments) {
    extract_data(data);
    jQuery.mobile.hidePageLoadingMsg();
    var obj = data.data[0];
    if(obj != undefined) {
        var state_type = "SOFT";
        if(obj.state_type == 1) { state_type = "HARD"; }
        jQuery('#'+typ+'_attempt').text(obj.current_attempt + '/' + obj.max_check_attempts + '  (' + state_type + ' state)');
        jQuery('#'+typ+'_duration').text(format_duration(obj.last_state_change, obj.peer_key));
        jQuery('#'+typ+'_exec_time').text(Math.round(obj.execution_time*1000)/1000 + 's');
        if(obj.last_check > 0) {
            jQuery('#'+typ+'_last_check').text(format_time(obj.last_check));
        } else {
            jQuery('#'+typ+'_last_check').text('never');
        }
        if(obj.next_check > 0) {
            jQuery('#'+typ+'_next_check').text(format_time(obj.next_check));
        } else {
            jQuery('#'+typ+'_next_check').text('N/A');
        }
        if(obj.check_type == 0) {
            jQuery('#'+typ+'_check_type').text('ACTIVE');
        } else {
            jQuery('#'+typ+'_check_type').text('PASSIVE');
        }
        jQuery('#'+typ+'_plugin_output').text(obj.plugin_output);
        jQuery('#'+typ+'_current_notification_number').text(obj.current_notification_number);
        if(obj.acknowledged == 0 && obj.state > 0) {
            jQuery('.'+typ+'_ack_form').show();
        }
        return obj;
    }
    jQuery('#'+typ+'_name').text('does not exist');
    jQuery('#'+typ+'_state').text('does not exist');
    return undefined;
}

/* show common acknowledgements and downtimes */
function show_common_acks_n_downtimes(typ, obj, comments, downtimes) {
    // Acknowledgements
    if(obj.acknowledged == 1) {
        var txt = '';
        jQuery('.'+typ+'_acknowledged').show();
        jQuery(comments).each(function(nr, com) {
            if(com.entry_type == 4) {
                txt = com.author + ': ' + com.comment + '<br>';
            }
        });
        jQuery('#'+typ+'_ack').html('<img src="' + url_prefix + 'thruk/plugins/mobile/img/ack.gif" alt="acknowledged"> ' + txt);
    }
    if(typ == 'host') {
        jQuery('#selected_hosts').val(obj.name);
    }
    if(typ == 'service') {
        jQuery('#selected_services').val(obj.host_name+';'+obj.description);
    }
    // Downtimes
    if(obj.scheduled_downtime_depth > 0) {
        var now = unixtime();
        jQuery('.'+typ+'_downtime').show();
        var txt = '';
        jQuery(downtimes).each(function(nr, com) {
            if(com.start_time <= now) {
                txt = com.author + ': ('+format_time(com.start_time)+' - '+format_time(com.end_time)+')<br>' + com.comment;
            }
        });
        jQuery('#'+typ+'_downtime').html('<img src="' + url_prefix + 'thruk/plugins/mobile/img/downtime.gif" alt="acknowledged"> ' + txt);
    }
}

/* set list icons for downtimes & acknowledements */
function get_list_icons(obj) {
    var icons = '';
    if(obj.acknowledged == 1) {
        icons += ' <img src="' + url_prefix + 'thruk/plugins/mobile/img/ack.gif"> ';
    }
    if(obj.scheduled_downtime_depth > 0) {
        icons += ' <img src="' + url_prefix + 'thruk/plugins/mobile/img/downtime.gif"> ';
    }
    if(icons != '') {
        icons = '<span class="ui-li-count ui-btn-up-c ui-btn-corner-all"> '+icons+' </span>';
    }
    return(icons);
}



// URL: http://blog.stevenlevithan.com/archives/date-time-format
/*
 * Date Format 1.2.3
 * (c) 2007-2009 Steven Levithan <stevenlevithan.com>
 * MIT license
 *
 * Includes enhancements by Scott Trenda <scott.trenda.net>
 * and Kris Kowal <cixar.com/~kris.kowal/>
 *
 * Accepts a date, a mask, or a date and a mask.
 * Returns a formatted version of the given date.
 * The date defaults to the current date/time.
 * The mask defaults to dateFormat.masks.default.
 */

var dateFormat = function () {
    var token = /d{1,4}|m{1,4}|yy(?:yy)?|([HhMsTt])\1?|[LloSZ]|"[^"]*"|'[^']*'/g,
        timezone = /\b(?:[PMCEA][SDP]T|(?:Pacific|Mountain|Central|Eastern|Atlantic) (?:Standard|Daylight|Prevailing) Time|(?:GMT|UTC)(?:[-+]\d{4})?)\b/g,
        timezoneClip = /[^-+\dA-Z]/g,
        pad = function (val, len) {
            val = String(val);
            len = len || 2;
            while (val.length < len) val = "0" + val;
            return val;
        };

    // Regexes and supporting functions are cached through closure
    return function (date, mask, utc) {
        var dF = dateFormat;

        // You can't provide utc if you skip other args (use the "UTC:" mask prefix)
        if (arguments.length == 1 && Object.prototype.toString.call(date) == "[object String]" && !/\d/.test(date)) {
            mask = date;
            date = undefined;
        }

        // Passing date through Date applies Date.parse, if necessary
        date = date ? new Date(date) : new Date;
        if (isNaN(date)) throw SyntaxError("invalid date");

        mask = String(dF.masks[mask] || mask || dF.masks["default"]);

        // Allow setting the utc argument via the mask
        if (mask.slice(0, 4) == "UTC:") {
            mask = mask.slice(4);
            utc = true;
        }

        var    _ = utc ? "getUTC" : "get",
            d = date[_ + "Date"](),
            D = date[_ + "Day"](),
            m = date[_ + "Month"](),
            y = date[_ + "FullYear"](),
            H = date[_ + "Hours"](),
            M = date[_ + "Minutes"](),
            s = date[_ + "Seconds"](),
            L = date[_ + "Milliseconds"](),
            o = utc ? 0 : date.getTimezoneOffset(),
            flags = {
                d:    d,
                dd:   pad(d),
                ddd:  dF.i18n.dayNames[D],
                dddd: dF.i18n.dayNames[D + 7],
                m:    m + 1,
                mm:   pad(m + 1),
                mmm:  dF.i18n.monthNames[m],
                mmmm: dF.i18n.monthNames[m + 12],
                yy:   String(y).slice(2),
                yyyy: y,
                h:    H % 12 || 12,
                hh:   pad(H % 12 || 12),
                H:    H,
                HH:   pad(H),
                M:    M,
                MM:   pad(M),
                s:    s,
                ss:   pad(s),
                l:    pad(L, 3),
                L:    pad(L > 99 ? Math.round(L / 10) : L),
                t:    H < 12 ? "a"  : "p",
                tt:   H < 12 ? "am" : "pm",
                T:    H < 12 ? "A"  : "P",
                TT:   H < 12 ? "AM" : "PM",
                Z:    utc ? "UTC" : (String(date).match(timezone) || [""]).pop().replace(timezoneClip, ""),
                o:    (o > 0 ? "-" : "+") + pad(Math.floor(Math.abs(o) / 60) * 100 + Math.abs(o) % 60, 4),
                S:    ["th", "st", "nd", "rd"][d % 10 > 3 ? 0 : (d % 100 - d % 10 != 10) * d % 10]
            };

        return mask.replace(token, function ($0) {
            return $0 in flags ? flags[$0] : $0.slice(1, $0.length - 1);
        });
    };
}();

// Some common format strings
dateFormat.masks = {
    "default":      "ddd mmm dd yyyy HH:MM:ss",
    shortDate:      "m/d/yy",
    mediumDate:     "mmm d, yyyy",
    longDate:       "mmmm d, yyyy",
    fullDate:       "dddd, mmmm d, yyyy",
    shortTime:      "HH:MM:SS",
    mediumTime:     "h:MM:ss TT",
    longTime:       "h:MM:ss TT Z",
    isoDate:        "yyyy-mm-dd",
    isoTime:        "HH:MM:ss",
    isoDateTime:    "yyyy-mm-dd'T'HH:MM:ss",
    isoUtcDateTime: "UTC:yyyy-mm-dd'T'HH:MM:ss'Z'"
};

// Internationalization strings
dateFormat.i18n = {
    dayNames: [
        "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat",
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"
    ],
    monthNames: [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
        "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"
    ]
};

// For convenience...
Date.prototype.format = function (mask, utc) {
    return dateFormat(this, mask, utc);
};
