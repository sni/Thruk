/* create the jquery mobile object */
var filter = undefined;
var jQT = new jQuery.jQTouch({
      icon: url_prefix + 'thruk/plugins/mobile/jqtouch/img/thruk.png',
      addGlossToIcon: false,
      startupScreen: url_prefix + 'thruk/plugins/mobile/jqtouch/img/startup.png',
      statusBar: 'black',
      initializeTouch: 'a, .touch',
      preloadImages: [
          url_prefix + 'thruk/plugins/mobile/jqtouch/img/whiteButton.png',
          url_prefix + 'thruk/plugins/mobile/jqtouch/img/toolButton.png',
          url_prefix + 'thruk/plugins/mobile/jqtouch/img/loading.gif',
          url_prefix + 'thruk/plugins/mobile/jqtouch/img/02-redo.png',
          url_prefix + 'thruk/plugins/mobile/jqtouch/img/thruk.png',
          url_prefix + 'thruk/plugins/mobile/jqtouch/img/startup.png',
          url_prefix + 'thruk/plugins/mobile/jqtouch/img/06-search.png',
          url_prefix + 'thruk/themes/Classic/images/logo_thruk_small.png'
        ]
});

/* initialize all events */
jQuery(document).ready(function(e){
  refresh_host_status();
  refresh_service_status();

  jQuery('#reload').bind('click', function(event, ui){
    refresh_host_status();
    refresh_service_status();
    return false;
  });

  jQuery('#last_notification').bind('pageAnimationEnd', function(event, info){
    if(info.direction == 'in') {
      jQuery.get('mobile.cgi', {
              data: 'notifications',
              limit:25
            },
            function(data, textStatus, XMLHttpRequest) {
              // empty list
              jQuery('#notification_list').children().remove();
              jQuery.each(data, function(index, entry) {
                if(entry.service_description) {
                  jQuery('#notification_list').append('<li class="arrow '+get_service_class_for_state(entry.state)+'"><a href="#"><span class="date">' + entry.formated_time + '</span><br>' + entry.host_name+' - '+ entry.service_description +'</a></li>');
                } else {
                  jQuery('#notification_list').append('<li class="arrow '+get_host_class_for_state(entry.state)+'"><a href="#"><span class="date">' + entry.formated_time + '</span><br>' + entry.host_name+'</a></li>');
                }
              });
              // add a more button
              // TODO:
              //jQuery('#notification_list').append('<li class="more"><a href="#more">load 25 more</a></li>');
            },
            'json');
    } else {
      // empty list
      jQuery('#notification_list').children().remove();
      jQuery('#notification_list').append('<li><img src="' + url_prefix + 'thruk/plugins/mobile/jqtouch/img/loading.gif" alt="loading"> loading</li>');
    }
  });

  jQuery('#services_list').bind('pageAnimationEnd', function(event, info){
    if(info.direction == 'in') {
      // empty list
      jQuery('#services_list_data').children().remove();
      jQuery.get('mobile.cgi', {
              data: 'services',
              filter: filter,
              limit:25,
              _:unixtime()
            },
            function(data, textStatus, XMLHttpRequest) {
              jQuery.each(data, function(index, entry) {
                  jQuery('#services_list_data').append('<li class="arrow '+get_service_class(entry)+'"><a href="#service" onclick="current_host=\'' + entry.host_name+'\';current_service=\'' + entry.description+'\'">' + entry.host_name+' - '+ entry.description +'</a></li>');
              });
              // add a more button
              // TODO:
              //jQuery('#services_list').append('<li class="more"><a href="#more">load 25 more</a></li>');
            },
            'json');
    } else {
      // empty list
      jQuery('#notification_list').children().remove();
      jQuery('#notification_list').append('<li><img src="' + url_prefix + 'thruk/plugins/mobile/jqtouch/img/loading.gif" alt="loading"> loading</li>');
    }
  });

  jQuery('#hosts_list').bind('pageAnimationEnd', function(event, info){
    if(info.direction == 'in') {
      // empty list
      jQuery('#hosts_list_data').children().remove();
      jQuery.get('mobile.cgi', {
              data: 'hosts',
              filter: filter,
              limit:25,
              _:unixtime()
            },
            function(data, textStatus, XMLHttpRequest) {
              jQuery.each(data, function(index, entry) {
                  jQuery('#hosts_list_data').append('<li class="arrow '+get_host_class(entry)+'"><a href="#service" onclick="current_host=\'' + entry.name+'\';">' + entry.name +'</a></li>');
              });
              // add a more button
              // TODO:
              //jQuery('#services_list').append('<li class="more"><a href="#more">load 25 more</a></li>');
            },
            'json');
    } else {
      // empty list
      jQuery('#notification_list').children().remove();
      jQuery('#notification_list').append('<li><img src="' + url_prefix + 'thruk/plugins/mobile/jqtouch/img/loading.gif" alt="loading"> loading</li>');
    }
  });

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

