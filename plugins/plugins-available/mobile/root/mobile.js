/* create the jquery mobile object */
var filter = undefined;

jQuery(document).bind("mobileinit", function(){
    jQuery.mobile.page.prototype.options.backBtnText      = "back";
    jQuery.mobile.page.prototype.options.addBackBtn       = true;
    jQuery.mobile.page.prototype.options.backBtnTheme     = "d";
    jQuery.mobile.page.prototype.options.headerTheme      = "d";
    jQuery.mobile.page.prototype.options.contentTheme     = "c";
    jQuery.mobile.page.prototype.options.footerTheme      = "d";

    jQuery.mobile.listview.prototype.options.headerTheme  = "d";
    jQuery.mobile.listview.prototype.options.theme        = "d";
    jQuery.mobile.listview.prototype.options.dividerTheme = "d";

    jQuery.mobile.listview.prototype.options.splitTheme   = "d";
    jQuery.mobile.listview.prototype.options.countTheme   = "d";
    jQuery.mobile.listview.prototype.options.filterTheme  = "d";
});

/* initialize all events */
jQuery(document).ready(function(e){
    /* refresh button on start page */
    jQuery("#refresh").bind( "vclick", function(event, ui) {
        refresh_host_status();
        refresh_service_status();
        return false;
    });

    /* bind filter settings to links */
    jQuery("LI.hosts_pending_panel A.hosts_list").bind(     "vclick", function(event, ui) { filter={ hoststatustypes:1 }; });
    jQuery("LI.hosts_up_panel A.hosts_list").bind(          "vclick", function(event, ui) { filter={ hoststatustypes:2 }; });
    jQuery("LI.hosts_down_panel A.hosts_list").bind(        "vclick", function(event, ui) { filter={ hoststatustypes:4 }; });
    jQuery("LI.hosts_unreachable_panel A.hosts_list").bind( "vclick", function(event, ui) { filter={ hoststatustypes:8 }; });

    jQuery('#last_notification').bind('pageinit', function(event, info){
        jQuery('#notification_list').children().remove();
        jQuery('#notification_list').append('<li><img src="' + url_prefix + 'thruk/plugins/mobile/img/loading.gif" alt="loading"> loading</li>');
        jQuery.get('mobile.cgi', {
                data: 'notifications',
                limit:25
            },
            function(data, textStatus, XMLHttpRequest) {
                // empty list
                jQuery('#notification_list').children().remove();
                jQuery.each(data, function(index, entry) {
                    if(entry.service_description) {
                        jQuery('#notification_list').append('<li class="'+get_service_class_for_state(entry.state)+'"><a href="#"><span class="date">' + entry.formated_time + '</span><br>' + entry.host_name+' - '+ entry.service_description +'</a></li>');
                    } else {
                        jQuery('#notification_list').append('<li class="'+get_host_class_for_state(entry.state)+'"><a href="#"><span class="date">' + entry.formated_time + '</span><br>' + entry.host_name+'</a></li>');
                    }
                });
                jQuery('#notification_list').listview('refresh');
                // add a more button
                // TODO:
                //jQuery('#notification_list').append('<li class="more"><a href="#more">load 25 more</a></li>');
            },
            'json');
    });

    jQuery('#services_list').bind('pageshow', function(event, info){
        // empty list
        jQuery('#services_list_data').children().remove();
        jQuery('#services_list_data').append('<li><img src="' + url_prefix + 'thruk/plugins/mobile/img/loading.gif" alt="loading"> loading</li>');
        jQuery.get('mobile.cgi', {
                data: 'services',
                filter: filter,
                // limit:25,
                _:unixtime()
            },
            function(data, textStatus, XMLHttpRequest) {
                jQuery('#services_list_data').children().remove();
                jQuery.each(data, function(index, entry) {
                    jQuery('#services_list_data').append('<li class="'+get_service_class(entry)+'"><a href="#service">' + entry.host_name+' - '+ entry.description +'</a></li>');
                });
                jQuery('#services_list_data').listview('refresh');
                // add a more button
                // TODO:
                //jQuery('#services_list').append('<li class="more"><a href="#more">load 25 more</a></li>');
            },
            'json');
    });

    jQuery('#hosts_list').bind('pageshow', function(event, data){
        // empty list
        jQuery('#hosts_list_data').children().remove();
        jQuery('#hosts_list_data').append('<li><img src="' + url_prefix + 'thruk/plugins/mobile/img/loading.gif" alt="loading"> loading</li>');
        jQuery.get('mobile.cgi', {
                data: 'hosts',
                filter: filter,
                // limit:25,
                _:unixtime()
            },
            function(data, textStatus, XMLHttpRequest) {
                jQuery('#hosts_list_data').children().remove();
                jQuery.each(data, function(index, entry) {
                    jQuery('#hosts_list_data').append('<li class="'+get_host_class(entry)+'"><a href="#host">' + entry.name +'</a></li>');
                });
                jQuery('#hosts_list_data').listview('refresh');
                // add a more button
                // TODO:
                //jQuery('#services_list').append('<li class="more"><a href="#more">load 25 more</a></li>');
            },
            'json');
    });

    /* refresh list of hosts */
    jQuery('#hosts').bind('pageshow', function(event, data){
        jQuery('#hosts_by_status_list').listview('refresh');
    });

    /* refresh list of services */
    jQuery('#services').bind('pageshow', function(event, data){
        jQuery('#services_by_status_list').listview('refresh');
    });

    refresh_host_status();
    refresh_service_status();
});


/* send debug output to firebug console */
function debug(str) {
    if (window.console != undefined) {
        console.debug(str);
    }
}

/* return host status class */
function get_host_class(host) {
    if(host.has_been_checked == 0) { return("hostPENDING"); }
    if(host.state == 0) { return("hostUP"); }
    if(host.state == 1) { return("hostDOWN"); }
    if(host.state == 2) { return("hostUNREACHABLE"); }
    if(host.state == 3) { return("hostPENDING"); }
    alert('unknown state' +  state);
}

/* return host status class */
function get_host_class_for_state(state) {
    if(state == 0) { return("hostUP"); }
    if(state == 1) { return("hostDOWN"); }
    if(state == 2) { return("hostUNREACHABLE"); }
    if(state == 3) { return("hostPENDING"); }
    alert('unknown state' +  state);
}

/* return service status class */
function get_service_class(service) {
    if(service.has_been_checked == 0) { return("servicePENDING"); }
    if(service.state == 0) { return("serviceOK"); }
    if(service.state == 1) { return("serviceWARNING"); }
    if(service.state == 2) { return("serviceCRITICAL"); }
    if(service.state == 3) { return("serviceUNKNOWN"); }
    if(service.state == 4) { return("servicePENDING"); }
    alert('unknown state' +  state);
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

function unixtime() {
    var d = new Date();
    return(d.getTime());
}

/* set hosts status */
function refresh_host_status() {
    jQuery('.hosts_pending_panel').hide();
    jQuery('.hosts_unreachable_panel').hide();
    jQuery('.hosts_down_panel').hide();
    jQuery('.hosts_up_panel').hide();

    jQuery.get('mobile.cgi', { data: 'host_stats', _:unixtime() },
        function(data, textStatus, XMLHttpRequest) {
            jQuery('.hosts_pending').text(data.pending)
            jQuery('.hosts_unreachable').text(data.unreachable)
            jQuery('.hosts_down').text(data.down)
            jQuery('.hosts_up').text(data.up);

            if(data.pending     > 0) { jQuery('.hosts_pending_panel').show(); }
            if(data.unreachable > 0) { jQuery('.hosts_unreachable_panel').show(); }
            if(data.down        > 0) { jQuery('.hosts_down_panel').show(); }
            if(data.up          > 0) { jQuery('.hosts_up_panel').show(); }
        },
    'json');
}

/* set service status */
function refresh_service_status() {
    jQuery('.services_ok_panel').hide();
    jQuery('.services_warning_panel').hide();
    jQuery('.services_critical_panel').hide();
    jQuery('.services_unknown_panel').hide();
    jQuery('.services_pending_panel').hide();
    jQuery.get('mobile.cgi', { data: 'service_stats', _:unixtime() },
        function(data, textStatus, XMLHttpRequest) {
            jQuery('.services_ok').text(data.ok)
            jQuery('.services_warning').text(data.warning)
            jQuery('.services_critical').text(data.critical)
            jQuery('.services_unknown').text(data.unknown)
            jQuery('.services_pending').text(data.pending)

            if(data.ok       > 0) { jQuery('.services_ok_panel').show(); }
            if(data.warning  > 0) { jQuery('.services_warning_panel').show(); }
            if(data.critical > 0) { jQuery('.services_critical_panel').show(); }
            if(data.unknown  > 0) { jQuery('.services_unknown_panel').show(); }
            if(data.pending  > 0) { jQuery('.services_pending_panel').show(); }
        },
    'json');
}

