/* create the jquery mobile object */
jQuery(document).bind("mobileinit", function(){
    jQuery.mobile.page.prototype.options.backBtnText = "back";
    jQuery.mobile.page.prototype.options.addBackBtn  = true;

    jQuery(document).ajaxError(function() {
        fail_all_backends();
    });
});

/* initialize all events */
jQuery(document).ready(function(e){
    set_default_theme();

    /* refresh button on start page */
    jQuery("#refresh").bind( "vclick", function(event, ui) {
        refresh_host_status(true);
        refresh_service_status(true);
        return false;
    });

    /* bind option theme button */
    jQuery("A.theme_button").bind("vclick", function(event, ui) {
        set_theme(this.dataset.val);
    });

    /* bind full client button */
    jQuery("A#full_client_link").bind("vclick", function(event, ui) {
        document.cookie = "thruk_mobile=0; path="+cookie_path+";";
        window.location.assign(url_prefix);
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
    jQuery('#button_options_back').bind('vclick', function(event){
        /* back from options, alias cancel */
        set_default_theme();
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
        document.cookie = "thruk_backends="+serialized+ "; path="+cookie_path+";";

        /* save theme */
        var now         = new Date();
        var expires     = new Date(now.getTime() + (10*365*86400*1000)); // let the cookie expire in 10 years
        document.cookie = "thruk_mtheme=" + thruk_theme + "; path="+cookie_path+"; expires=" + expires.toGMTString() + ";";

        refresh_host_status(true, true);
        refresh_service_status(true, true);
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
var thruk_theme;
function set_theme(theme) {
    jQuery('DIV[data-role="page"]').removeClass("ui-page-theme-a ui-page-theme-b").addClass("ui-page-theme-" + theme);
    thruk_theme = theme;
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

    ['ok', 'warning', 'critical', 'unknown', 'pending', 'unhandled', 'warning_and_unhandled', 'critical_and_unhandled', 'unknown_and_unhandled'].forEach(function(el){
        jQuery('.services_'+el+'_panel').hide();
    });
    jQuery.get('mobile.cgi', { data: 'service_stats', _:unixtime() },
        function(data, textStatus, XMLHttpRequest) {
            extract_data(data);
            data = data.data;
            ['ok', 'warning', 'critical', 'unknown', 'pending', 'total', 'warning_and_unhandled', 'critical_and_unhandled', 'unknown_and_unhandled'].forEach(function(el){
                var val = eval("data."+el);
                jQuery('.services_'+el).text(val)
                if(val > 0) { jQuery('.services_'+el+'_panel').show(); }
            });
            unhandled_service_problems = data.warning_and_unhandled + data.critical_and_unhandled + data.unknown_and_unhandled;
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
        for(var key in current_backend_states) {
            number++;
            if(current_backend_states[key].state == 0 || current_backend_states[key].state == 1) {
                jQuery("#backend_"+key).attr("checked",true).checkboxradio("refresh");
            }
            if(current_backend_states[key].state == 1) {
                jQuery("#b_lab_"+key).addClass('hostDOWN');
            }
        }
        jQuery('#backend_chooser').hide();
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

    if(current_backend_states != undefined) {
        failed_backends=0;
        for(var key in current_backend_states) {
            if(current_backend_states[key].state == 1) {
                failed_backends++;
            }
        }
    }
    jQuery('#button_options').removeClass('hostDOWN');

    if(failed_backends > 0) {
        jQuery('#button_options').addClass('hostDOWN');
    }

    return;
}

/* set all backends in fail state */
function fail_all_backends() {
    jQuery('#button_options').addClass('hostDOWN');
    for(var key in current_backend_states) {
        jQuery("#b_lab_"+key).addClass('hostDOWN');
    }
}

ThrukMobile = {
    /* Options Page */
    page_options: function(eventType, matchObj, ui, page, evt) {
        jQuery('.waiting').show();
        if(current_backend_states == undefined) {
            refresh_host_status(true, true);
        } else {
            refresh_backends();
        }
        jQuery('.waiting').hide();
    },

    /* Alert List Page */
    page_alerts: function(eventType, matchObj, ui, page, evt, pagenr) {
        pagenr = list_pager_init(pagenr, 'alerts_list');
        jQuery.get('mobile.cgi', {
                data: 'alerts',
                page: pagenr
            },
            function(data, textStatus, XMLHttpRequest) {
                list_pager_data(pagenr, data, 'alerts_list', function() { ThrukMobile.page_alerts(eventType, matchObj, ui, page, evt, ++pagenr); }, function(entry) {
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
    },

    /* Notifications Page */
    page_notifications: function(eventType, matchObj, ui, page, evt, pagenr) {
        pagenr = list_pager_init(pagenr, 'notification_list');
        jQuery.get('mobile.cgi', {
                data: 'notifications',
                page: pagenr
            },
            function(data, textStatus, XMLHttpRequest) {
                list_pager_data(pagenr, data, 'notification_list', function() { ThrukMobile.page_notifications(eventType, matchObj, ui, page, evt, ++pagenr); }, function(entry) {
                    if(entry.service_description) {
                        jQuery('#notification_list').append('<li class="'+get_service_class_for_state(entry.state)+'"><span class="date">' + format_time(entry.time) + '</span><br>' + entry.host_name+' - '+ entry.service_description +'</li>');
                    } else {
                        jQuery('#notification_list').append('<li class="'+get_host_class_for_state(entry.state)+'"><span class="date">' + format_time(entry.time) + '</span><br>' + entry.host_name+'</li>');
                    }
                });
            },
            'json'
        );
    },

    /* Services List Page */
    page_services_list: function(eventType, matchObj, ui, page, evt, pagenr) {
        pagenr     = list_pager_init(pagenr, 'services_list_data');
        var params = get_params();
        jQuery.get('mobile.cgi', {
                data:               'services',
                servicestatustypes: params['servicestatustypes'],
                serviceprops:       params['serviceprops'],
                hoststatustypes:    params['hoststatustypes'],
                page:               pagenr,
                _:                  unixtime()
            },
            function(data, textStatus, XMLHttpRequest) {
                list_pager_data(pagenr, data, 'services_list_data', function() { ThrukMobile.page_services_list(eventType, matchObj, ui, page, evt, ++pagenr); }, function(entry) {
                    var icons = get_list_icons(entry);
                    jQuery('#services_list_data').append('<li class="'+get_service_class(entry)+'"><a href="#service?host='+encoder(entry.host_name)+'&service='+encoder(entry.description)+'&backend=' + entry.peer_key + '">' + entry.host_name+' - '+ entry.description +icons+'</a></li>');
                });
            },
            'json'
        );
    },

    /* Hosts List Page */
    page_hosts_list: function(eventType, matchObj, ui, page, evt, pagenr) {
        pagenr     = list_pager_init(pagenr, 'hosts_list_data');
        var params = get_params();
        jQuery.get('mobile.cgi', {
                data:           'hosts',
                hoststatustypes: params['hoststatustypes'],
                hostprops:       params['hostprops'],
                page:            pagenr,
                _:               unixtime()
            },
            function(data, textStatus, XMLHttpRequest) {
                list_pager_data(pagenr, data, 'hosts_list_data', function() { ThrukMobile.page_hosts_list(eventType, matchObj, ui, page, evt, ++pagenr); }, function(entry) {
                    var icons = get_list_icons(entry);
                    jQuery('#hosts_list_data').append('<li class="'+get_host_class(entry)+'"><a href="#host?host='+encoder(entry.name)+'&backend=' + entry.peer_key + '">' + entry.name +icons+'</a></li>');
                });
            },
            'json'
        );
    },

    /* Host Page */
    page_host: function(eventType, matchObj, ui, page, evt) {
        var params = get_params();
        hide_common_extinfo('host');
        jQuery.get('mobile.cgi', {
                data:    'hosts',
                host:    params['host'],
                backend: params['backend'],
                _:       unixtime()
            },
            function(data, textStatus, XMLHttpRequest) {
                var host = show_common_extinfo('host', data);
                if(host != undefined) {
                    jQuery('.host_name').text(host.name);
                    jQuery('#host_state').removeClass().text(get_host_status(host)).addClass(get_host_class(host));
                    jQuery('.host_referer').val('mobile.cgi#host?host='+encoder(params['host']));
                    jQuery('.selected_hosts').val(params['host']);
                    show_common_acks_n_downtimes('host', host, data.comments, data.downtimes);
                }
            },
            'json'
        );
    },

    /* Service Page */
    page_service: function(eventType, matchObj, ui, page, evt) {
        hide_common_extinfo('service');
        var params = get_params();
        jQuery.get('mobile.cgi', {
                data:    'services',
                host:    params['host'],
                service: params['service'],
                backend: params['backend'],
                _:       unixtime()
            },
            function(data, textStatus, XMLHttpRequest) {
                var service = show_common_extinfo('service', data);
                if(service != undefined) {
                    jQuery('.service_name').html(service.host_name + '<br>' + service.description);
                    jQuery('#service_state').removeClass().text(get_service_status(service)).addClass(get_service_class(service));
                    jQuery('.service_referer').val('mobile.cgi#service?host='+encoder(params['host'])+'&service='+encoder(params['service']));
                    jQuery('.selected_services').val(params['host']+';'+params['service']);
                    show_common_acks_n_downtimes('service', service, data.comments, data.downtimes);
                }
            },
            'json'
        );
    },

    /* Home Page */
    page_home: function(eventType, matchObj, ui, page, evt) {
        refresh_host_status();
        refresh_service_status();
    },

    /* Problems Page */
    page_problems: function(eventType, matchObj, ui, page, evt) {
        refresh_host_status();
        refresh_service_status();
        jQuery('DIV#problems:visible UL.hosts_by_status_list').listview('refresh');
        jQuery('DIV#problems:visible UL.services_by_status_list').listview('refresh');
    },

    /* Hosts Page */
    page_hosts: function(eventType, matchObj, ui, page, evt) {
        refresh_host_status();
        jQuery('DIV#hosts:visible .hosts_by_status_list').listview('refresh');
    },

    /* Services Page */
    page_services: function(eventType, matchObj, ui, page, evt) {
        refresh_service_status();
        jQuery('DIV#services:visible .services_by_status_list').listview('refresh');
    },

    /* Host Cmd Page */
    page_host_cmd: function(eventType, matchObj, ui, page, evt) {
        var params = get_params();
        jQuery('.host_name').text(params['host']);
        jQuery('.host_referer').val('mobile.cgi#host?host='+encoder(params['host']));
    },

    /* Service Cmd Page */
    page_service_cmd: function(eventType, matchObj, ui, page, evt) {
        var params = get_params();
        jQuery('.service_name').html(params['host'] + '<br>' + params['service']);
        jQuery('.service_referer').val('mobile.cgi#service?host='+encoder(params['host'])+'&service='+encoder(params['service']));
    }
};

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

/* encode strings */
function encoder(str) {
    return encodeURIComponent(str);
}

/* decode strings */
function decoder(str) {
    return decodeURIComponent(str);
}

/* return parameter from url */
function get_params() {
    var str    = document.location.hash;
    str        = str.replace(/#+.*\?/, '');
    var params = {};
    jQuery(str.split('&')).each(function(x, s) {
        p = s.split('=');
        params[p[0]] = decoder(p[1]);
    });
    return(params);
}

/* initialize list */
function list_pager_init(page, list) {
    if(page == undefined) { page = 1; }
    if(page == 1) {
        jQuery('#'+list).children().remove();
    } else {
        jQuery('.more').find('A').text('loading...');
    }
    jQuery.mobile.loading('show');
    jQuery('#'+list+':visible').listview('refresh');
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
    jQuery.mobile.loading('hide');
    jQuery.each(data.data, function(index, entry) {
        row_callback(entry);
    });
    if(data.more != undefined) {
        jQuery('#'+list).append('<li data-icon="false" class="more"><a href="#">more...</a></li>');
        jQuery('.more').bind('vclick', more_callback);
    }
    jQuery('#'+list+':visible').listview('refresh');
}

/* hide elements from extinfo pages */
function hide_common_extinfo(typ) {
    jQuery.mobile.loading('show');
    ['attempt', 'name', 'state', 'duration', 'exec_time', 'last_check', 'next_check', 'check_type', 'plugin_output', 'current_notification_number'].forEach(function(el){
        jQuery('#'+typ+'_'+el).text('');
    });
    ['ack_form', 'acknowledged', 'downtime', 'pnp_url'].forEach(function(el){
        jQuery('.'+typ+'_'+el).hide();
    });
}

/* show common elements from extinfo pages */
function show_common_extinfo(typ, data, comments) {
    extract_data(data);
    jQuery.mobile.loading('hide');
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
        if(escape_html_tags) {
            jQuery('#'+typ+'_plugin_output').text(obj.plugin_output);
        } else {
            jQuery('#'+typ+'_plugin_output').html(obj.plugin_output);
        }
        if(obj.current_notification_number > 0) {
            jQuery('#'+typ+'_current_notification_number').text(obj.current_notification_number);
        } else {
            jQuery('#'+typ+'_current_notification_number').text('none');
        }
        if(obj.acknowledged == 0 && obj.state > 0) {
            jQuery('.'+typ+'_ack_form').show();
            if(typ == 'host') {
                jQuery('A.'+typ+'_ack_form').attr('href', '#host_cmd?host='+encoder(obj.name)+'&q=4');
            }
            if(typ == 'service') {
                jQuery('A.'+typ+'_ack_form').attr('href', '#service_cmd?host='+encoder(obj.host_name)+'&service='+encoder(obj.description)+'&q=4');
            }
        }
        /* pnp */
        if(data.pnp_url != undefined && data.pnp_url != '') {
            var hostname    = obj.name;
            var description = '_HOST_';
            if(obj.host_name != undefined) {
                hostname    = obj.host_name;
                description = obj.description;
            }
            jQuery('.'+typ+'_pnp_url').show();
            jQuery('#'+typ+'_pnp_img').attr('src', data.pnp_url + '/image?host='+encoder(hostname)+'&srv='+encoder(description)+'&view=1&source=0');
            jQuery('#'+typ+'_pnp_lnk').attr('href', data.pnp_url + '/mobile/graph/'+encoder(hostname)+'/'+encoder(description));
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
                txt += '<li>';
                txt += '<a href="#" onclick="alert(&quot;'+ format_time(com.entry_time) + '\\n' + com.author + '\\n' + com.comment+'&quot;);"><img src="' + url_prefix + 'plugins/mobile/img/ack.gif" class="ui-li-icon">';
                txt += '' + com.author + ': ' + com.comment + '<\/a>';
                txt += '<a href="cmd.cgi?cmd_mod=2';
                if(typ == 'host') {
                    txt += '&cmd_typ=51&host='+encoder(obj.name)+'&referer='+encoder('mobile.cgi#host?host='+obj.name);
                }
                if(typ == 'service') {
                    txt += '&cmd_typ=52&host='+encoder(obj.host_name)+'&service='+encoder(obj.description)+'&referer='+encoder('mobile.cgi#service?host='+obj.host_name+'&service='+obj.description);
                }
                txt += '" data-icon="delete" data-iconpos="notext" data-inline="true" data-ajax=false>remove</a>';
                txt += '<\/li>';
            }
        });
        jQuery('#'+typ+'_ack').html('<ul data-role="listview" id="'+typ+'_ack_list" data-inset="true"> ' + txt+'</ul>');
        jQuery('#'+typ+'_ack_list').listview();
    }
    if(typ == 'host') {
        jQuery('.selected_hosts').val(obj.name);
    }
    if(typ == 'service') {
        jQuery('.selected_services').val(obj.host_name+';'+obj.description);
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
        jQuery('#'+typ+'_downtime').html('<img src="' + url_prefix + 'plugins/mobile/img/downtime.gif" alt="acknowledged"> ' + txt+'<hr>');
    }
}

/* set list icons for downtimes & acknowledements */
function get_list_icons(obj) {
    var icons = '';
    if(obj.acknowledged == 1) {
        icons += ' <img src="' + url_prefix + 'plugins/mobile/img/ack.gif"> ';
    }
    if(obj.notifications_enabled == 0) {
        icons += ' <img src="' + url_prefix + 'plugins/mobile/img/ndisabled.gif"> ';
    }
    if(strict_passive_mode) {
        if(obj.check_type == 0 && obj.active_checks_enabled == 0) {
            icons += ' <img src="' + url_prefix + 'plugins/mobile/img/disabled.gif"> ';
        }
        if(obj.check_type == 1 && obj.accept_passive_checks == 0) {
            icons += ' <img src="' + url_prefix + 'plugins/mobile/img/disabled.gif"> ';
        }
        if(obj.check_type == 1 && obj.accept_passive_checks == 1) {
            icons += ' <img src="' + url_prefix + 'plugins/mobile/img/passiveonly.gif"> ';
        }
    } else {
        if(obj.active_checks_enabled == 0 && obj.accept_passive_checks == 0) {
            icons += ' <img src="' + url_prefix + 'plugins/mobile/img/disabled.gif"> ';
        }
        else if(obj.active_checks_enabled == 0) {
            icons += ' <img src="' + url_prefix + 'plugins/mobile/img/passiveonly.gif"> ';
        }
    }
    if(obj.scheduled_downtime_depth > 0) {
        icons += ' <img src="' + url_prefix + 'plugins/mobile/img/downtime.gif"> ';
    }
    if(icons != '') {
        icons = '<span class="ui-li-count ui-btn-up-c ui-btn-corner-all"> '+icons+' </span>';
    }
    return(icons);
}

/* set default theme */
function set_default_theme() {
    // theme?
    var theme = readCookie('thruk_mtheme');
    if(theme != undefined && (theme == 'a' || theme == 'b')) {
        set_theme(theme);
    } else {
        set_theme('a');
    }
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
