/*******************************************************************************
88888888ba  88888888ba  88888888888 88888888888
88      "8b 88      "8b 88          88
88      ,8P 88      ,8P 88          88
88aaaaaa8P' 88aaaaaa8P' 88aaaaa     88aaaaa
88""""""'   88""""88'   88"""""     88"""""
88          88    `8b   88          88
88          88     `8b  88          88
88          88      `8b 88888888888 88
*******************************************************************************/

var refreshPage      = 1;
var cmdPaneState     = 0;
var curRefreshVal    = 0;
var additionalParams = new Object();
var removeParams     = new Object();
var scrollToPos      = 0;
var refreshTimer;
var backendSelTimer;
var lastRowSelected;
var lastRowHighlighted;
var verifyTimer;
var iPhone           = false;
if(window.navigator && window.navigator.userAgent) {
    iPhone           = window.navigator.userAgent.match(/iPhone|iPad/i) ? true : false;
}

// needed to keep the order
var hoststatustypes    = new Array( 1, 2, 4, 8 );
var servicestatustypes = new Array( 1, 2, 4, 8, 16 );
var hostprops          = new Array( 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288, 1048576, 2097152, 4194304, 8388608, 16777216, 33554432 );
var serviceprops       = new Array( 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288, 1048576, 2097152, 4194304, 8388608, 16777216, 33554432 );

/*******************************************************************************
  ,ad8888ba,  88888888888 888b      88 88888888888 88888888ba  88   ,ad8888ba,
 d8"'    `"8b 88          8888b     88 88          88      "8b 88  d8"'    `"8b
d8'           88          88 `8b    88 88          88      ,8P 88 d8'
88            88aaaaa     88  `8b   88 88aaaaa     88aaaaaa8P' 88 88
88      88888 88"""""     88   `8b  88 88"""""     88""""88'   88 88
Y8,        88 88          88    `8b 88 88          88    `8b   88 Y8,
 Y8a.    .a88 88          88     `8888 88          88     `8b  88  Y8a.    .a8P
  `"Y88888P"  88888888888 88      `888 88888888888 88      `8b 88   `"Y8888Y"'
*******************************************************************************/

/* send debug output to firebug console */
var debug = function(str) {}
if(typeof thruk_debug_js !== 'undefined' && thruk_debug_js != undefined && thruk_debug_js) {
    if(typeof window.console === "object" && window.console.debug) {
        /* overwrite debug function, so caller information is not replaced */
        debug = window.console.debug.bind(console);
    }
}

window.addEventListener('load', function(evt) {
    try {
        if(top.frames && top.frames['side']) {
            top.frames['side'].is_reloading = false;
        }
    }
    catch(err) { debug(err); }
}, false);

/* do initial things */
function init_page() {
    jQuery('input.deletable').wrap('<span class="deleteicon" />').after(jQuery('<span/>').click(function() {
        jQuery(this).prev('input').val('').focus();
    }));

    // init some buttons
    if(has_jquery_ui) {
        jQuery('BUTTON.thruk_button').button();
        jQuery('A.thruk_button').button();
        jQuery('INPUT.thruk_button').button();

        jQuery('.thruk_button_refresh').button({
            icons: {primary: 'ui-refresh-button'}
        });
        jQuery('.thruk_button_add').button({
            icons: {primary: 'ui-add-button'}
        });
        jQuery('.thruk_button_save').button({
            icons: {primary: 'ui-save-button'}
        });

        jQuery('.thruk_radioset').buttonset();

        /* list wizard */
        jQuery('button.members_wzd_button').button({
            icons: {primary: 'ui-wzd-button'},
            text: false,
            label: 'open list wizard'
        }).click(function() {
            init_tool_list_wizard(this.id, this.name);
            return false;
        });
    }

    var newUrl = window.location.href;
    var scroll = newUrl.match(/(\?|\&)scrollTo=([\d\.]+)/);
    if(scroll) {
        scrollToPos = scroll[2];
    }

    var saved_hash = readCookie('thruk_preserve_hash');
    if(saved_hash != undefined) {
        set_hash(saved_hash);
        cookieRemove('thruk_preserve_hash');
    }

    // add title for things that might overflow
    jQuery(document).on('mouseenter', '.mightOverflow', function() {
      var This = jQuery(this);
      var title = This.attr('title');
      if(!title) {
        if(this.offsetWidth < this.scrollWidth) {
          This.attr('title', This.text().replace(/<\!\-\-[\s\S]*\-\->/, '').replace(/^\s*/, '').replace(/\s*$/, ''));
        }
      } else {
        if(this.offsetWidth >= this.scrollWidth && title == This.text()) {
          This.removeAttr('title');
        }
      }
    });

    // store browsers timezone in a cookie so we can use it in later requests
    cookieSave("thruk_tz", getBrowserTimezone());

    cleanUnderscoreUrl();
}

function getBrowserTimezone() {
    var timezone;
    try {
        if(Intl.DateTimeFormat().resolvedOptions().timeZone) {
            timezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
        } else {
            var offset = (new Date()).getTimezoneOffset()/60;
            if(offset == 0) {
                timezone = "UTC";
            }
            if(offset < 0) {
                timezone = "UTC"+offset;
            }
            if(offset > 0) {
                timezone = "UTC+"+offset;
            }
        }
    } catch(e) {}
    return(timezone);
}

function thruk_onerror(msg, url, line, col, error) {
  if(error_count > 5) {
    debug("too many errors, not logging any more...");
    window.onerror = undefined;
  }
  try {
    thruk_errors.unshift("Url: "+url+" Line "+line+"\nError: " + msg);
    // hide errors from saved pages
    if(window.location.protocol != 'http:' && window.location.protocol != 'https:') { return false; }
    // hide errors in line 0
    if(line == 0) { return false; }
    // hide errors from plugins and addons
    if(url.match(/^chrome:/)) { return false; }
    // skip some errors
    var skip = false;
    for(var nr = 0; nr < skip_js_errors.length; nr++) {
        if(msg.match(skip_js_errors[nr])) { skip = true; }
    }
    if(skip) { return; }
    error_count++;
    var text = getErrorText(thruk_debug_details, error);
    if(show_error_reports == "server" || show_error_reports == "both") {
        sendJSError(url_prefix+"cgi-bin/remote.cgi?log", text);
    }
    if(show_error_reports == "1" || show_error_reports == "both") {
        showBugReport('bug_report', text);
    }
  }
  catch(e) { debug(e); }
  return false;
}

/* remove ugly ?_=... from url */
function cleanUnderscoreUrl() {
    var newUrl = window.location.href;
    if (history.replaceState) {
        newUrl = cleanUnderscore(newUrl);
        try {
            history.replaceState({}, "", newUrl);
        } catch(err) { debug(err) }
    }
}

function cleanUnderscore(str) {
    str = str.replace(/\?_=\d+/g, '?');
    str = str.replace(/\&_=\d+/g, '');
    str = str.replace(/\?scrollTo=[\d\.]+/g, '?');
    str = str.replace(/\&scrollTo=[\d\.]+/g, '');
    str = str.replace(/\?autoShow=\w+/g, '?');
    str = str.replace(/\&autoShow=\w+/g, '');
    str = str.replace(/\?$/g, '');
    str = str.replace(/\?&/g, '?');
    return(str);
}

function bodyOnLoad(refresh) {
    if(scrollToPos > 0) {
        window.scroll(0, scrollToPos);
        scrollToPos = 0;
    }
    if(refresh) {
        if(window.parent && window.parent.location && String(window.parent.location.href).match(/\/panorama\.cgi/)) {
            stopRefresh();
        } else if(String(window.location.href).match(/\/panorama\.cgi/)) {
            stopRefresh();
        } else {
            setRefreshRate(refresh);
        }
    }
    init_page();
}

/* save scroll value */
function saveScroll() {
    var scroll = getPageScroll();
    if(scroll > 0) {
        additionalParams['scrollTo'] = scroll;
        delete removeParams['scrollTo'];
    } else {
        delete additionalParams['scrollTo'];
        removeParams['scrollTo'] = true;
    }
}

/* hide a element by id */
function hideElement(id, icon) {
  var pane;
  if(typeof(id) == 'object') {
    pane = id;
  }
  else {
    pane = document.getElementById(id);
  }
  if(!pane) {
    if(thruk_debug_js) { alert("ERROR: got no element for id in hideElement(): " + id); }
    return;
  }
  pane.style.display    = 'none';
  pane.style.visibility = 'hidden';

  var img = document.getElementById(icon);
  if(img && img.src) {
    img.src = img.src.replace(/icon_minimize\.gif/g, "icon_maximize.gif");
  }
}

/* show a element by id */
var close_elements = [];
function showElement(id, icon, bodyclose, bodycloseelement, bodyclosecallback) {
  var pane;
  if(typeof(id) == 'object') {
    pane = id;
  }
  else {
    pane = document.getElementById(id);
  }
  if(!pane) {
    if(thruk_debug_js) { alert("ERROR: got no element for id in showElement(): " + id); }
    return;
  }
  pane.style.display    = '';
  pane.style.visibility = 'visible';

  var img = document.getElementById(icon);
  if(img && img.src) {
    img.src = img.src.replace(/icon_maximize\.gif/g, "icon_minimize.gif");
  }

  if(bodyclose) {
    remove_close_element(id);
    window.setTimeout(function() {
        addEvent(document, 'click', close_and_remove_event);
        var found = false;
        jQuery.each(close_elements, function(key, value) {
            if(value[0] == id) {
                found = true;
            }
        });
        if(!found) {
            close_elements.push([id, icon, bodycloseelement, bodyclosecallback])
        }
    }, 50);
  }
}

/* remove element from close elements list */
function remove_close_element(id) {
    var new_elems = [];
    jQuery.each(close_elements, function(key, value) {
        if(value[0] != id) {
            new_elems.push(value);
        }
    });
    close_elements = new_elems;
    if(new_elems.length == 0) {
        removeEvent(document, 'click', close_and_remove_event);
    }
}

/* close and remove eventhandler */
function close_and_remove_event(evt) {
    evt = (evt) ? evt : ((window.event) ? event : null);
    if(close_elements.length == 0) {
        return;
    }
    var x,y;
    if(evt) {
        evt = jQuery.event.fix(evt); // make pageX/Y available in IE
        x = evt.pageX;
        y = evt.pageY;

        // hilight click itself
        //hilight_area(x-5, y-5, x + 5, y + 5, 1000, 'blue');
    }
    var new_elems = [];
    jQuery.each(close_elements, function(key, value) {
        var obj    = document.getElementById(value[0]);
        if(value[2]) {
            obj = jQuery(value[2])[0];
        }
        var inside = false;
        if(x && y && obj) {
            var width  = jQuery(obj).outerWidth();
            var height = jQuery(obj).outerHeight();
            var offset = jQuery(obj).offset();

            var x1 = offset['left'] - 15;
            var x2 = offset['left'] + width  + 15;
            var y1 = offset['top']  - 15;
            var y2 = offset['top']  + height + 15;

            // check if we clicked inside or outside the object we have to close
            if( x >= x1 && x <= x2 && y >= y1 && y <= y2 ) {
                inside = true;
            }

            // hilight checked area
            //var color = inside ? 'green' : 'red';
            //hilight_area(x1, y1, x2, y2, 1000, color);
        }

        // make sure our event target is not a subelement of the panel to close
        if(!inside && evt) {
            inside = is_el_subelement(evt.target, obj);
        }

        if(evt && inside) {
            new_elems.push(value);
        } else {
            if(value[3]) {
                value[3]();
            }
            hideElement(value[0], value[1]);
        }
    });
    close_elements = new_elems;
    if(new_elems.length == 0) {
        removeEvent(document, 'click', close_and_remove_event);
    }
}

/* toggle a element by id and load content from remote */
function toggleElementRemote(id, part, bodyclose) {
    var elements = jQuery('#'+id);
    if(!elements[0]) {
        if(thruk_debug_js) { alert("ERROR: got no panel for id in toggleElementRemote(): " + id); }
        return false;
    }
    resetRefresh();
    var el = elements[0];
    /* fetched already, just toggle */
    if(el.innerHTML) {
        toggleElement(id, undefined, bodyclose);
        return;
    }
    /* add loading image and fetch content */
    var append = "";
    if(has_debug_options) {
        append += "&debug=1";
    }
    el.innerHTML = "<img src='"+url_prefix + 'themes/' + theme + '/images/loading-icon.gif'+"'>";
    showElement(id, undefined, bodyclose);
    jQuery('#'+id).load(url_prefix+'cgi-bin/parts.cgi?part='+part+append, {}, function(text, status, req) {
        showElement(id, undefined, bodyclose);
        resetRefresh();
    })
}

/* toggle a element by id */
function toggleElement(id, icon, bodyclose, bodycloseelement, bodyclosecallback) {
  var pane = document.getElementById(id);
  if(!pane) {
    if(thruk_debug_js) { alert("ERROR: got no panel for id in toggleElement(): " + id); }
    return false;
  }
  resetRefresh();
  if(pane.style.visibility == "hidden" || pane.style.display == 'none') {
    showElement(id, icon, bodyclose, bodycloseelement, bodyclosecallback);
    return true;
  }
  else {
    hideElement(id, icon);
    // if we hide something, check if we have to close others too
    // but only if the element to close is not a subset of an existing to_close_element
    var inside = false;
    jQuery.each(close_elements, function(key, value) {
        var obj    = document.getElementById(value[0]);
        if(value[2]) {
            obj = jQuery(value[2])[0];
        }
        inside = is_el_subelement(pane, obj);
        if(inside) {
            return false; // break jQuery.each
        }
    });
    if(!inside) {
        try {
          close_and_remove_event();
        } catch(err) { debug(err) }
    }
    return false;
  }
}

/* return true if obj A is a subelement from obj B */
function is_el_subelement(obj_a, obj_b) {
    if(obj_a == obj_b) {
        return true;
    }
    while(obj_a.parentNode != undefined) {
        obj_a = obj_a.parentNode;
        if(obj_a == obj_b) {
            return true;
        }
    }
    return false;
}

/* save settings in a cookie */
function prefSubmit(url, current_theme) {
  var sel         = document.getElementById('pref_theme')
  if(current_theme != sel.value) {
    additionalParams['theme']      = '';
    additionalParams['reload_nav'] = 1;
    cookieSave('thruk_theme', sel.value);
    reloadPage();
  }
}

/* save settings in a cookie */
function prefSubmitSound(url, value) {
  cookieSave('thruk_sounds', value);
  reloadPage();
}

/* save something in a cookie */
function cookieSave(name, value, expires, domain) {
  var now       = new Date();
  var expirestr = '';

  // let the cookie expire in 10 years by default
  if(expires == undefined) { expires = 10*365*86400; }

  if(expires > 0) {
    expires   = new Date(now.getTime() + (expires*1000));
    expirestr = " expires=" + expires.toGMTString() + ";";
  }

  var cookieStr = name+"="+value+"; path="+cookie_path+";"+expirestr;

  if(domain) {
    cookieStr += ";domain="+domain;
  }

  document.cookie = cookieStr;
}

/* remove existing cookie */
function cookieRemove(name, path) {
    if(path == undefined) {
        path = cookie_path;
    }
    document.cookie = name+"=del; path="+path+";expires=Thu, 01 Jan 1970 00:00:01 GMT";
}

/* return cookie value */
var cookies;
function readCookie(name,c,C,i){
    if(cookies){ return cookies[name]; }

    c = document.cookie.split('; ');
    cookies = {};

    for(i=c.length-1; i>=0; i--){
       C = c[i].split('=');
       cookies[C[0]] = C[1];
    }

    return cookies[name];
}

/* page refresh rate */
function setRefreshRate(rate) {
  curRefreshVal = rate;
  var obj = document.getElementById('refresh_rate');
  if(refreshPage == 0) {
    if(obj) {
        obj.innerHTML = "This page will not refresh automatically <input type='button' value='refresh now' onClick='reloadPage()'>";
    }
  }
  else {
    if(obj) {
        obj.innerHTML = "Update in "+rate+" seconds <input type='button' value='stop' onClick='stopRefresh()'>";
    }
    if(rate == 0) {
      var has_auto_reload_fn = false;
      try {
        if(auto_reload_fn && typeof(auto_reload_fn) == 'function') {
            has_auto_reload_fn = true;
        }
      } catch(err) {}
      if(has_auto_reload_fn) {
        auto_reload_fn(function(state) {
            if(state) {
                var d = new Date();
                var new_date = d.strftime(datetime_format_long);
                jQuery('#infoboxdate').html(new_date);
            } else {
                jQuery('#infoboxdate').html('<span class="fail_message">refresh failed<\/span>');
            }
        });
        resetRefresh();
      } else {
        reloadPage();
      }
    }
    if(rate > 0) {
      newRate = rate - 1;
      window.clearTimeout(refreshTimer);
      refreshTimer = window.setTimeout("setRefreshRate(newRate)", 1000);
    }
  }
}

/* reset refresh interval */
function resetRefresh() {
  window.clearTimeout(refreshTimer);
  if( typeof refresh_rate == "number" ) {
    setRefreshRate(refresh_rate);
  } else {
    stopRefresh();
  }
}

/* stops the reload interval */
function stopRefresh() {
  refreshPage = 0;
  setRefreshRate(0);
}

/* is this an array? */
function is_array(o) {
    return typeof(o) == 'object' && (o instanceof Array);
}

/* return url variables as hash */
function toQueryParams(str) {
    var vars = {};
    if(str == undefined) {
        var i = window.location.href.indexOf('?');
        if(i == -1) {
            return vars;
        }
        str = window.location.href.slice(i + 1);
    }
    if (str == "") { return vars; };
    str = str.replace(/#.*$/g, '');
    str = str.split('&');
    for (var i = 0; i < str.length; ++i) {
        var p = [str[i]];
        // cannot use split('=', 2) here since it ignores everything after the limit
        var b = str[i].indexOf("=");
        if(b != -1) {
            p = [str[i].substr(0, b), str[i].substr(b+1)];
        }
        var val;
        if (p.length == 1) {
            val = undefined;
        } else {
            val = decodeURIComponent(p[1].replace(/\+/g, " "));
        }
        if(vars[p[0]] != undefined) {
            if(is_array(vars[p[0]])) {
                vars[p[0]].push(val);
            } else {
                var tmp =  vars[p[0]];
                vars[p[0]] = new Array();
                vars[p[0]].push(tmp);
                vars[p[0]].push(val);
            }
        } else {
            vars[p[0]] = val;
        }
    }
    return vars;
}

/* create query string from object */
function toQueryString(obj) {
    var str = '';
    for(var key in obj) {
        var value = obj[key];
        if(typeof(value) == 'object') {
            for(var key2 in value) {
                var value2 = value[key2];
                str = str + key + '=' + encodeURIComponent(value2) + '&';
            };
        } else if (value == undefined) {
            str = str + key + '&';
        }
        else {
            str = str + key + '=' + encodeURIComponent(value) + '&';
        }
    };
    // remove last &
    str = str.substring(0, str.length-1);
    return str;
}

function getCurrentUrl(addTimeAndScroll) {
    var origHash = window.location.hash;
    var newUrl   = window.location.href;
    newUrl       = newUrl.replace(/#.*$/g, '');

    if(addTimeAndScroll == undefined) { addTimeAndScroll = true; }

    // save scroll state
    saveScroll();

    var urlArgs  = toQueryParams();
    for(var key in additionalParams) {
        urlArgs[key] = additionalParams[key];
    }

    for(var key in removeParams) {
        delete urlArgs[key];
    }

    if(urlArgs['highlight'] != undefined) {
        delete urlArgs['highlight'];
    }

    // make url uniq, otherwise we would to do a reload
    // which reloads all images / css / js too
    if(addTimeAndScroll) {
        urlArgs['_'] = (new Date()).getTime();
    } else {
        delete urlArgs["scrollTo"];
    }

    var newParams = toQueryString(urlArgs);

    newUrl = newUrl.replace(/\?.*$/g, '');
    if(newParams != '') {
        newUrl = newUrl + '?' + newParams;
    }

    if(origHash != '#' && origHash != '') {
        newUrl = newUrl + origHash;
    }
    return(newUrl);
}

function uriWith(uri, params, removeParams) {
    uri  = uri || window.location.href;
    var urlArgs  = toQueryParams(uri);

    for(var key in params) {
        urlArgs[key] = params[key];
    }

    if(removeParams) {
        for(var key in removeParams) {
            delete urlArgs[key];
        }
    }

    var newParams = toQueryString(urlArgs);

    var newUrl = uri.replace(/\?.*$/g, '');
    if(newParams != '') {
        newUrl = newUrl + '?' + newParams;
    }

    return(newUrl);
}

/* update the url by using additionalParams */
function updateUrl() {
    var newUrl = getCurrentUrl(false);
    try {
        history.replaceState({}, "", newUrl);
    } catch(err) { debug(err) }
}

/* reloads the current page and adds some parameter from a hash */
function reloadPage() {
    window.clearTimeout(refreshTimer);
    var obj = document.getElementById('refresh_rate');
    if(obj) {
        obj.innerHTML = "<span id='refresh_rate'>page will be refreshed...</span>";
    }

    var newUrl = getCurrentUrl();

    if(fav_counter) {
        updateFaviconCounter('Zz', '#F7DA64', true, "10px Bold Tahoma", "#BA2610");
    }

    /* set reload mark in side frame */
    if(window.parent.frames) {
        try {
            top.frames['side'].is_reloading = newUrl;
        }
        catch(err) {
            debug(err);
        }
    }

    /*
     * reload new url and replace history
     * otherwise history will contain every
     * single reload
     * and give the browser some time to update refresh buttons
     * and icons
     */
    window.setTimeout("window_location_replace('"+newUrl+"')", 100);
}

/* wrapper for window.location which results in
 * Uncaught TypeError: Illegal invocation
 * otherwise. (At least in chrome)
 */
function window_location_replace(url) {
    window.location.replace(url);
}

function get_site_panel_backend_button(id, styles, onclick, section) {
    if(!initial_backends[id] || !initial_backends[id]['cls']) { return(""); }
    var cls = initial_backends[id]['cls'];
    var title = initial_backends[id]['last_error'];
    if(cls != "DIS") {
        if(initial_backends[id]['last_online'] && initial_backends[id]['last_online'] > 30) {
            title += "\nLast Online: "+duration(initial_backends[id]['last_online'])+" ago";
            if(cls == "UP" && initial_backends[id]['last_error'] != "OK") {
                cls = "WARN";
            }
        }
    }
    var btn = '<input type="button"';
    btn += " id='button_"+id+"'";
    btn += ' class="button_peer'+cls+' backend_'+id+' section_'+section+'"';
    btn += ' value="'+initial_backends[id]['name']+'"';
    btn += ' title="'+escapeHTML(title).replace(/"/, "'")+'"';
    if(initial_backends[id]['disabled'] == 5) {
        btn += ' disabled'
    } else {
        btn += ' onClick="'+onclick+'">';
    }

    return("<div class='backend' style='"+styles+"'>"+btn+"<\/div>");
}

/* create sites header */
function dw(txt) {document.write(txt);}

/* create sites popup */
function create_site_panel_popup() {
    var panel = ''
        +'<div class="shadow"><div class="shadowcontent">'
        +'<table class="site_panel" cellspacing=0 cellpadding=0 width="100%">'
        +'  <tr>'
        +'    <th align="center">'
        +'      <table border=0 cellpadding=0 cellspacing=0 width="100%" style="padding-bottom: 10px;">'
        +'        <tr>';
    if(backend_chooser != 'switch') {
        panel += '      <td width="20"></td>';
        panel += '      <td width="70"></td>';
    }
    panel += '          <td style="padding-right: 20px;">Choose your sites</td>';
    if(backend_chooser != 'switch') {
        panel += '      <td align="right" width="70" class="clickable" onclick="toggleAllSections(true);">enable all</td>';
        panel += '      <td align="left" width="20"><input type="checkbox" id="all_backends" value="" name="all_backends" onclick="toggleAllSections();"></td>';
    }
    panel += '        </tr>';
    panel += '      </table>';
    panel += '    </th>';
    panel += '  </tr>';
    panel += '</table>';

    if(show_sitepanel == "panel") {
        panel += create_site_panel_popup_panel();
    }
    else if(show_sitepanel == "collapsed") {
        panel += create_site_panel_popup_collapsed();
    }

    panel += '<\/div><\/div>';
    document.getElementById('site_panel').innerHTML = panel;
}

function create_site_panel_popup_panel() {
    panel  = '<div class="site_panel_sections" style="overflow: auto;">';
    panel += '<table class="site_panel" cellspacing=0 cellpadding=0 width="100%">';
    panel += '  <tr>';
    if(sites["sub"] && keys(sites["sub"]).length > 1) {
        jQuery(keys(sites["sub"]).sort()).each(function(i, subsection) {
            if(sites["sub"][subsection].total == 0) { return; }
            panel += '<th class="site_panel '+(i==0 ? '' : "notfirst")+'">';
            panel += '  <a href="#" class="sites_subsection" onclick="toggleSection([\''+subsection+'\']); return false;" title="'+subsection+'">'+subsection+'</a>';
            panel += '</th>';
        });
    }
    panel += '  </tr>';
    panel += '  <tr>';
    jQuery(keys(sites["sub"]).sort()).each(function(i, subsection) {
        if(sites["sub"][subsection].total == 0) { return; }
        panel += '<td valign="top" class="site_panel '+(i==0 ? "" : "notfirst")+'" align="center">';
        panel += '<table cellpadding=0 cellspacing=0 border=0><tr class="subpeers_'+subsection+'">';
        panel += '<td valign="top">';
        var count = 0;
        jQuery(_site_panel_flat_peers(sites["sub"][subsection])).each(function(i, pd) {
            panel += get_site_panel_backend_button(pd, "clear: both;", "toggleBackend('"+pd+"')", toClsName(subsection));
            count++;
            if(count > 15) { count = 0; panel += '</td><td valign="top">'; }
        });
        panel += '</td>';
        panel += '</tr></table>';
        panel += '</td>';
    });
    panel += '  </tr>';
    panel += '</table>';
    panel += '<\/div>';
    return(panel);
}

function _site_panel_flat_peers(section) {
    var peers = [];
    if(section["sub"]) {
        jQuery(keys(section["sub"]).sort()).each(function(i, subsection) {
            peers = peers.concat(_site_panel_flat_peers(section["sub"][subsection]));
        });
    }
    if(section["peers"]) {
        jQuery(section["peers"]).each(function(i, p) {
            peers.push(p);
        });
    }
    return(peers);
}

function toClsName(name) {
    name = name.replace(/[^a-zA-Z0-9]+/g, '-');
    return(name);
}

function toClsNameList(list, join_char) {
    var out = [];
    if(join_char == undefined) { join_char = '_'; }
    for(var x = 0; x < list.length; x++) {
        out.push(toClsName(list[x]));
    }
    return(out.join(join_char));
}

function create_site_panel_popup_collapsed() {
    panel  = '<div class="site_panel_sections" style="overflow: auto;">';
    panel += '<table class="site_panel" cellspacing=0 cellpadding=0 width="100%">';
    jQuery(keys(sites.sub).sort()).each(function(i, sectionname) {
        if(i > 0) {
            panel += '  <tr>';
            panel += '    <td><hr class="sites_collapsed"></td>';
            panel += '  </tr>';
        }
        panel += '<tr>';
        panel += ' <th align="left">';
        panel += '   <a href="#" onclick="toggleSection([\''+sectionname+'\']); return false;" title="'+sectionname+'" class="sites_subsection">'+sectionname+'</a>';
        panel += '  </th>';
        panel += '</tr>';
        // show first two levels of sections
        panel += add_site_panel_popup_collapsed_section(sites["sub"][sectionname], [sectionname]);
        // including peers
        if(sites["sub"][sectionname]["peers"]) {
            panel += '  <tr class="subpeer subpeers_'+(toClsName(sectionname))+' sublvl_1">';
            panel += '    <th align="left" style="padding-left: 10px;">';
            jQuery(sites["sub"][sectionname]["peers"]).each(function(i, pd) {
                panel += get_site_panel_backend_button(pd, "", "toggleBackend('"+pd+"')", toClsName(sectionname));
            });
            panel += '    </th>';
            panel += '  </tr>';
        }
    });

    // add top level peers
    if(sites["peers"]) {
        panel += '  <tr class="subpeer subpeers_top">';
        panel += '    <th align="left">';
        panel += '    <hr class="sites_collapsed">';
        jQuery(sites["peers"]).each(function(i, pd) {
            panel += get_site_panel_backend_button(pd, "", "toggleBackend('"+pd+"')", "top");
        });
        panel += '    </th>';
        panel += '  </tr>';
    }

    // add all other peers
    jQuery(keys(sites.sub).sort()).each(function(i, sectionname) {
        panel += add_site_panel_popup_collapsed_peers(sites["sub"][sectionname], [sectionname]);
    });

    panel += '</table>';
    panel += '<\/div>';
    return(panel);
}

function add_site_panel_popup_collapsed_section(section, prefix) {
    var lvl = prefix.length;
    panel = "";
    var prefixCls = toClsNameList(prefix);
    if(section["sub"]) {
        panel += '  <tr style="'+(lvl > 1 ? 'display: none;' : '')+'" class="subsection subsection_'+prefixCls+' sublvl_'+lvl+'">';
        panel += '    <th align="left" style="padding-left: '+(lvl*10)+'px;">';
        jQuery(keys(section["sub"]).sort()).each(function(i, sectionname) {
            var subsection = section["sub"][sectionname];
            var new_prefix = prefix.concat(sectionname);
            var cls = 'button_peerDIS';
            if(subsection.total == subsection.up) { cls = 'button_peerUP'; }
            if(subsection.total == subsection.down) { cls = 'button_peerDOWN'; }
            if(subsection.total == subsection.disabled) { cls = 'button_peerDIS'; }
            if(subsection.up  > 0 && subsection.down > 0) { cls = 'button_peerWARN'; }
            if(subsection.up  > 0 && subsection.disabled > 0 && subsection.down == 0) { cls = 'button_peerUPDIS'; }
            if(subsection.up == 0 && subsection.disabled > 0 && subsection.down > 0) { cls = 'button_peerDOWNDIS'; }
            panel += "<input type='button' class='"+cls+" btn_sites btn_sites_"+prefixCls+"_"+toClsName(sectionname)+"' value='"+sectionname+"' onClick='toggleSubSectionVisibility("+JSON.stringify(new_prefix)+")'>";
        });
        panel += '    </th>';
        panel += '  </tr>';

        jQuery(keys(section["sub"]).sort()).each(function(i, sectionname) {
            var subsection = section["sub"][sectionname];
            var new_prefix = prefix.concat(sectionname);
            panel += add_site_panel_popup_collapsed_section(subsection, new_prefix);
        });
    }

    return(panel);
}

function add_site_panel_popup_collapsed_peers(section, prefix) {
    var lvl = prefix.length;
    panel = "";
    if(section["peers"]) {
        var prefixCls = toClsNameList(prefix);
        panel += '  <tr class="subpeer subpeers_'+prefixCls+'" style="display: none;">';
        panel += '    <th align="left">';
        panel += '    <hr class="sites_collapsed last">';

        panel += '    <table><tr><td>';
        panel += "      <input type='checkbox' onclick='toggleSection("+JSON.stringify(prefix)+");' class='clickable section_check_box_"+prefixCls+"'>";
        panel += '    </td><td style="vertical-align: middle;">';
        panel += "      <a href='#' onclick='toggleSection("+JSON.stringify(prefix)+"); return false;'><b>";
        panel += prefix.join(' -&gt; ');
        panel += '      </b></a>:';
        panel += '    </td></tr></table>';

        jQuery(section["peers"]).each(function(i, pd) {
            panel += get_site_panel_backend_button(pd, "", "toggleBackend('"+pd+"')", prefixCls);
        });
        panel += '    </th>';
        panel += '  </tr>';
    }
    if(section["sub"]) {
        jQuery(keys(section["sub"]).sort()).each(function(i, sectionname) {
            var subsection = section["sub"][sectionname];
            var new_prefix = prefix.concat(sectionname);
            panel += add_site_panel_popup_collapsed_peers(subsection, new_prefix);
        });
    }
    return(panel);
}

/* toggle site panel */
/* $%&$&% site panel position depends on the button height */
function toggleSitePanel() {
    if(!document.getElementById('site_panel').innerHTML) {
        create_site_panel_popup();
    }
    var enabled = toggleElement('site_panel', undefined, true, 'DIV#site_panel DIV.shadowcontent', toggleSitePanel);
    var divs = jQuery('DIV.backend');
    var panel = document.getElementById('site_panel');
    panel.style.top = (divs[0].offsetHeight + 11) + 'px';

    /* make sure site panel does not overlap screen */
    var div = jQuery('DIV.site_panel_sections')[0];
    if(enabled == true) {
        var table = jQuery('TABLE.top_nav')[0];
        var newWidth = table.offsetWidth - 10;
        if(newWidth < div.offsetWidth) {
            div.style.width = newWidth + 'px';
        }
    } else {
        // reset styles till next open
        div.style.width = '';
        // immediately reload if there were changes
        if(additionalParams['reload_nav']) {
            window.clearTimeout(backendSelTimer);
            backendSelTimer  = window.setTimeout('reloadPage()', 50);
        }
    }

    updateSitePanelCheckBox();
}

/* toggle querys for this backend */
function toggleBackend(backend, state, skip_update) {
  resetRefresh();
  var button        = document.getElementById('button_' + backend);
  if(state == undefined) { state = -1; }

  if(backend_chooser == 'switch') {
    jQuery('INPUT.button_peerUP').removeClass('button_peerUP').addClass('button_peerDIS');
    jQuery(button).removeClass('button_peerDIS').addClass('button_peerUP');
    cookieSave('thruk_conf', backend);
    reloadPage();
    return;
  }

  if(current_backend_states == undefined) {
    current_backend_states = {};
    for(var key in initial_backends) { current_backend_states[key] = initial_backends[key]['state']; }
  }

  initial_state = initial_backends[backend]['state'];
  var newClass  = undefined;
  if((jQuery(button).hasClass("button_peerDIS") && state == -1) || state == 1) {
    if(initial_state == 1) {
      newClass = "button_peerDOWN";
    }
    else {
      newClass = "button_peerUP";
    }
    current_backend_states[backend] = 0;
  } else if(jQuery(button).hasClass("button_peerHID") && state != 1) {
    newClass = "button_peerUP";
    current_backend_states[backend] = 0;
    delete additionalParams['backend'];
  } else {
    newClass = "button_peerDIS";
    current_backend_states[backend] = 2;
  }

  /* remove all and set new class */
  jQuery(button).removeClass("button_peerDIS button_peerHID button_peerUP button_peerDOWN").addClass(newClass);

  additionalParams['reload_nav'] = 1;
  /* save current selected backends in session cookie */
  cookieSave('thruk_backends', toQueryString(current_backend_states));
  window.clearTimeout(backendSelTimer);
  var delay = 2500;
  if(show_sitepanel == 'panel')     { delay =  3500; }
  if(show_sitepanel == 'collapsed') { delay = 10000; }
  backendSelTimer  = window.setTimeout('reloadPage()', delay);

  if(skip_update == undefined || !skip_update) {
    updateSitePanelCheckBox();
  }
  return;
}

/* toggle subsection */
function toggleSubSectionVisibility(subsection) {
    // hide everything
    jQuery('TR.subpeer, TR.subsection').css('display', 'none');
    jQuery('TR.subsection INPUT').removeClass('button_peer_selected');

    // show parents sections
    var subsectionCls = toClsNameList(subsection);
    var cls = '';
    for(var x = 0; x < subsection.length; x++) {
        if(cls != "") { cls = cls+'_'; }
        cls = cls+toClsName(subsection[x]);
        // show section itself
        jQuery('TR.subsection_'+cls).css('display', '');
        // but hide all subsections
        jQuery('TR.subsection_'+cls+' INPUT').css('display', 'none');
        // except the one we want to see
        jQuery('INPUT.btn_sites_'+cls).css('display', '').addClass('button_peer_selected');
    }

    // show section itself
    jQuery('TR.subsection_'+subsectionCls).css('display', '');
    jQuery('TR.subsection_'+subsectionCls+' INPUT').css('display', '');

    // show peer for this subsection
    jQuery('TR.subpeers_'+subsectionCls).css('display', '');
    jQuery('TR.subpeers_'+subsectionCls+' INPUT').css('display', '');

    // always show top sections
    jQuery('TR.sublvl_1').css('display', '');
    jQuery('TR.sublvl_1 INPUT').css('display', '');
}

/* toggle all backends for this section */
function toggleSection(sections) {
    var first_state = undefined;
    var section = toClsNameList(sections);
    var regex   = new RegExp('section_'+section+'(_|\\\s|$)');
    jQuery('TABLE.site_panel INPUT[type=button]').each(function(i, b) {
        var id = b.id.replace(/^button_/, '');
        if(!id) { return; }
        if(!b.className.match(regex)) { return; }
        if(first_state == undefined) {
            if(jQuery(b).hasClass("button_peerUP") || jQuery(b).hasClass("button_peerDOWN")) {
                first_state = 0;
            } else {
                first_state = 1;
            }
        }
        toggleBackend(id, first_state, true);
    });

    updateSitePanelCheckBox();
}

/* toggle all backends for all sections */
function toggleAllSections(reverse) {
    var state = 0;
    if(jQuery('#all_backends').prop('checked')) {
        state = 1;
    }
    if(reverse != undefined) {
        if(state == 0) { state = 1; } else { state = 0; }
    }
    jQuery('TABLE.site_panel DIV.backend INPUT').each(function(i, b) {
        if(b.id.match(/^button_/)) {
            var id = b.id.replace(/^button_/, '');
            toggleBackend(id, state, true);
        }
    });

    updateSitePanelCheckBox();
}

/* update all site panel checkboxes and section button */
function updateSitePanelCheckBox() {
    /* count totals */
    count_site_section_totals(sites, []);

    /* enable all button */
    if(sites['disabled'] > 0) {
        jQuery('#all_backends').prop('checked', false);
    } else {
        jQuery('#all_backends').prop('checked', true);
    }
}

/* count totals for a section */
function count_site_section_totals(section, prefix) {
    section.total    = 0;
    section.disabled = 0;
    section.down     = 0;
    section.up       = 0;
    if(section["sub"]) {
        jQuery(keys(section["sub"]).sort()).each(function(i, sectionname) {
            var subsection = section["sub"][sectionname];
            var new_prefix = prefix.concat(sectionname);
            count_site_section_totals(subsection, new_prefix);
            section.total    += subsection.total;
            section.disabled += subsection.disabled;
            section.down     += subsection.down;
            section.up       += subsection.up;
        });
    }

    if(section["peers"]) {
        jQuery(section["peers"]).each(function(i, pd) {
            var btn = document.getElementById("button_"+pd);
            if(!btn) { return; }
            section.total++;
            if(jQuery(btn).hasClass('button_peerDIS') || jQuery(btn).hasClass('button_peerHID')) {
                section.disabled++;
            }
            else if(jQuery(btn).hasClass('button_peerUP')) {
                section.up++;
            }
            else if(jQuery(btn).hasClass('button_peerDOWN')) {
                section.down++;
            }
        });
    }

    if(prefix.length == 0) { return; }

    /* set section button */
    var prefixCls = toClsNameList(prefix);
    var newBtnClass = "";
    if(section.disabled == section.total) {
        newBtnClass = "button_peerDIS";
    }
    else if(section.up == section.total) {
        newBtnClass = "button_peerUP";
    }
    else if(section.down == section.total) {
        newBtnClass = "button_peerDOWN";
    }
    else if(section.down > 0 && section.up > 0) {
        newBtnClass = "button_peerWARN";
    }
    else if(section.up > 0 && section.disabled > 0 && section.down == 0) {
        newBtnClass = "button_peerUPDIS";
    }
    else if(section.disabled > 0 && section.down > 0 && section.up == 0) {
        newBtnClass = "button_peerDOWNDIS";
    }
    jQuery('.btn_sites_' + prefixCls)
            .removeClass("button_peerDIS")
            .removeClass("button_peerDOWN")
            .removeClass("button_peerUP")
            .removeClass("button_peerWARN")
            .removeClass("button_peerUPDIS")
            .removeClass("button_peerDOWNDIS")
            .addClass(newBtnClass);

    /* set section checkbox */
    if(section.disabled > 0) {
        jQuery('.section_check_box_'+prefixCls).prop('checked', false);
    } else {
        jQuery('.section_check_box_'+prefixCls).prop('checked', true);
    }
}

function duration(seconds) {
    if(seconds < 300) {
        return(seconds+" seconds");
    }
    if(seconds < 7200) {
        return(Math.floor(seconds/60)+" minutes");
    }
    if(seconds < 86400*2) {
        return(Math.floor(seconds/3600)+" hours");
    }
    return(Math.floor(seconds/86400)+" days");
}

/* toggle checkbox by id */
function toggleCheckBox(id) {
  var box = document.getElementById(id);
  if(box.checked) {
    box.checked = false;
  } else {
    box.checked = true;
  }
}

/* toggle disabled status */
function toggleDisabled(id) {
  var thing = document.getElementById(id);
  if(thruk_debug_js && thing == undefined) { alert("ERROR: no element in toggleDisabled() for: " + id ); }
  if(thing.disabled) {
    thing.disabled = false;
  } else {
    thing.disabled = true;
  }
}

/* unselect current text seletion */
function unselectCurrentSelection(obj) {
    if (document.selection && document.selection.empty)
    {
        document.selection.empty();
    }
    else
    {
        window.getSelection().removeAllRanges();
    }
    return true;
}

/* return selected text */
function getTextSelection() {
    var t = '';
    if(window.getSelection) {
        t = window.getSelection();
    } else if(document.getSelection) {
        t = document.getSelection();
    } else if(document.selection) {
        t = document.selection.createRange().text;
    }
    return ''+t;
}

/* returns true if the shift key is pressed for that event */
var no_more_events = 0;
function is_shift_pressed(evt) {

  if(no_more_events) {
    return false;
  }

  if(evt && evt.shiftKey) {
    return true;
  }

  try {
    if(event && event.shiftKey) {
      return true;
    }
  }
  catch(err) {
    // errors wont matter here
  }

  return false;
}

/* moves element from one select to another */
function data_select_move(from, to, skip_sort) {
    var from_sel = document.getElementsByName(from);
    if(!from_sel || from_sel.length == 0) {
        if(thruk_debug_js) { alert("ERROR: no element in data_select_move() for: " + from ); }
    }
    var to_sel = document.getElementsByName(to);
    if(!to_sel || to_sel.length == 0) {
        if(thruk_debug_js) { alert("ERROR: no element in data_select_move() for: " + to ); }
    }

    from_sel = from_sel[0];
    to_sel   = to_sel[0];

    if(from_sel.selectedIndex < 0) {
        return;
    }

    var elements = new Array();
    for(var nr = 0; nr < from_sel.length; nr++) {
        if(from_sel.options[nr].selected == true) {
            elements.push(nr);
            var option = from_sel.options[nr];
            if(originalOptions[to] != undefined) {
                originalOptions[to].push(new Option(option.text, option.value));
            }
            if(originalOptions[from] != undefined) {
                jQuery.each(originalOptions[from], function(i, o) {
                    if(o.value == option.value) {
                        originalOptions[from].splice(i, 1);
                        return false;
                    }
                    return true;
                });
            }
        }
    }

    // reverse elements so the later remove doesn't disorder the select
    elements.reverse();

    var elements_to_add = new Array();
    for(var x = 0; x < elements.length; x++) {
        var elem       = from_sel.options[elements[x]];
        var elOptNew   = document.createElement('option');
        elOptNew.text  = elem.text;
        elOptNew.value = elem.value;
        from_sel.remove(elements[x]);
        elements_to_add.push(elOptNew);
    }

    elements_to_add.reverse();
    for(var x = 0; x < elements_to_add.length; x++) {
        var elOptNew = elements_to_add[x];
        try {
          to_sel.add(elOptNew, null); // standards compliant; doesn't work in IE
        }
        catch(ex) {
          to_sel.add(elOptNew); // IE only
        }
    }

    /* sort elements of to field */
    if(!skip_sort) {
        sortlist(to_sel.id);
    }
}

/* filter select field option */
var originalOptions = {};
function data_filter_select(id, filter) {
    var select  = document.getElementById(id);
    var pattern = get_trimmed_pattern(filter);

    if(!select) {
        if(thruk_debug_js) { alert("ERROR: no select in data_filter_select() for: " + id ); }
    }

    var options = select.options;
    /* create backup of original list */
    if(originalOptions[id] == undefined) {
        reset_original_options(id);
    } else {
        options = originalOptions[id];
    }

    /* filter our options */
    var newOptions = [];
    jQuery.each(options, function(i, option) {
        var found = 0;
        jQuery.each(pattern, function(i, sub_pattern) {
            var index = option.text.toLowerCase().indexOf(sub_pattern.toLowerCase());
            if(index != -1) {
                found++;
            }
        });
        /* all pattern found */
        if(found == pattern.length) {
            newOptions.push(option);
        }
    });
    // don't set uniq flag here, otherwise non-uniq lists will be uniq after init
    set_select_options(id, newOptions, false);
}

/* resets originalOptions hash for given id */
function reset_original_options(id) {
    var select  = document.getElementById(id);
    originalOptions[id] = [];
    jQuery.each(select.options, function(i, option) {
        originalOptions[id].push(new Option(option.text, option.value));
    });
}

/* set options for a select */
function set_select_options(id, options, uniq) {
    var select  = document.getElementById(id);
    var uniqs   = {};
    if(select == undefined || select.options == undefined) {
       if(thruk_debug_js) { alert("ERROR: no select found in set_select_options: " + id ); }
       return;
    }
    select.options.length = 0;
    jQuery.each(options, function(i, o) {
        if(!uniq || uniqs[o.text] == undefined) {
            select.options[select.options.length] = o;
            uniqs[o.text] = true;
        }
    });
}

/* select all options for given select form field */
function select_all_options(select_id) {
    // add selected nodes
    jQuery('#'+select_id+' OPTION').prop('selected',true);
}

/* return array of trimmed pattern */
function get_trimmed_pattern(pattern) {
    var trimmed_pattern = new Array();
    jQuery.each(pattern.split(" "), function(index, sub_pattern) {
        sub_pattern = sub_pattern.replace(/\s+$/g, "");
        sub_pattern = sub_pattern.replace(/^\s+/g, "");
        if(sub_pattern != '') {
            trimmed_pattern.push(sub_pattern);
        }
    });
    return trimmed_pattern;
}


/* return keys as array */
function keys(obj) {
    var k = [];
    for(var key in obj) {
        k.push(key);
    }
    return k;
}

/* sort select by value */
function sortlist(id) {
    var selectOptions = jQuery("#"+id+" option");
    selectOptions.sort(function(a, b) {
        if      (a.text > b.text) { return 1;  }
        else if (a.text < b.text) { return -1; }
        else                      { return 0;  }
    });
    jQuery("#"+id).empty().append(selectOptions);
}

/* fetch all select fields and select all options when it is multiple select */
function multi_select_all(form) {
    elems = form.getElementsByTagName('select');
    for(var x = 0; x < elems.length; x++) {
        var sel = elems[x];
        if(sel.multiple == true) {
            for(var nr = 0; nr < sel.length; nr++) {
                sel.options[nr].selected = true;
            }
        }
    }
}

/* remove a bookmark */
function removeBookmark(nr) {
    var pan  = document.getElementById("bm" + nr);
    var panP = pan.parentNode;
    panP.removeChild(pan);
    delete bookmarks["bm" + nr];
}

/* check if element is not emty */
function checknonempty(id, name) {
    var elem = document.getElementById(id);
    if( elem.value == undefined || elem.value == "" ) {
        alert(name + " is a required field");
        return(false);
    }
    return(true);
}

/* hide all waiting icons */
var hide_activity_icons_timer;
function hide_activity_icons() {
    jQuery('img').each(function(i, el) {
        if(el.src.indexOf("/images/waiting.gif") > 0) {
            el.style.visibility = "hidden";
        }
    });
}

/* verify time */
var verification_errors = new Object();
function verify_time(id, duration_id) {
    window.clearTimeout(verifyTimer);
    verifyTimer = window.setTimeout(function() {
        verify_time_do(id, duration_id);
    }, 500);
}
function verify_time_do(id, duration_id) {
    var obj  = document.getElementById(id);
    var obj2 = document.getElementById(duration_id);
    var duration = "";
    if(obj2 && jQuery(obj2).is(":visible")) {
        duration = obj2.value;
    }

    jQuery.ajax({
        url: url_prefix + 'cgi-bin/status.cgi',
        type: 'POST',
        data: {
            verify:     'time',
            time:        obj.value,
            duration:    duration,
            duration_id: duration_id
        },
        success: function(data) {
            var next = jQuery(obj).next();
            if(next[0] && next[0].className == 'smallalert') {
                jQuery(next).remove();
            }
            if(data.verified == "false") {
                debug(data.error);
                verification_errors[id] = 1;
                obj.style.background = "#f8c4c4";
                jQuery("<span class='smallalert'>"+data.error+"</span>").insertAfter(obj);
            } else {
                obj.style.background = "";
                delete verification_errors[id];
            }
        }
    });
}

/* return unescaped html string */
function unescapeHTML(html) {
    return jQuery("<div />").html(html).text();
}

/* return escaped html string */
function escapeHTML(text) {
    return jQuery("<div>").text(text).html();
}

/* reset table row classes */
function reset_table_row_classes(table, c1, c2) {
    var x = 1;
    jQuery('TABLE#'+table+' TR').each(function(i, row) {
        if(jQuery(row).css('display') == 'none') {
            // skip hidden rows
            return true;
        }
        jQuery(row).removeClass(c1);
        jQuery(row).removeClass(c2);
        x++;
        var newclass = c2;
        if(x%2 == 0) {
            newclass = c1;
        }
        jQuery(row).addClass(newclass);
        jQuery(row).children().each(function(i, elem) {
            if(elem.tagName == 'TD') {
                if(jQuery(elem).hasClass(c1) || jQuery(elem).hasClass(c2)) {
                    jQuery(elem).removeClass(c1);
                    jQuery(elem).removeClass(c2);
                    jQuery(elem).addClass(newclass);
                }
            }
        });
    });
}

/* set icon src and refresh page */
function refresh_button(btn) {
    btn.src = url_prefix + 'themes/' + theme + '/images/waiting.gif';
    jQuery(btn).addClass('refreshing');
    window.setTimeout(function() {
        reloadPage();
    }, 100);
}

/* reverse a string */
function reverse(s){
    return s.split("").reverse().join("");
}

/* set selection in text input */
function setSelectionRange(input, selectionStart, selectionEnd) {
    if (input.setSelectionRange) {
        input.focus();
        input.setSelectionRange(selectionStart, selectionEnd);
    }
    else if (input.createTextRange) {
        var range = input.createTextRange();
        range.collapse(true);
        range.moveEnd('character', selectionEnd);
        range.moveStart('character', selectionStart);
        range.select();
    }
}

/* set cursor position in text input */
function setCaretToPos(input, pos) {
    setSelectionRange(input, pos, pos);
}

/* set cursor line in textarea */
function setCaretToLine(input, line) {

    setSelectionRange(input, pos, pos);
}

/* get cursor position in text input */
function getCaret(el) {
    if (el.selectionStart) {
        return el.selectionStart;
    } else if (document.selection) {
        el.focus();

        var r = document.selection.createRange();
        if (r == null) {
            return 0;
        }

        var re = el.createTextRange(),
            rc = re.duplicate();
        re.moveToBookmark(r.getBookmark());
        rc.setEndPoint('EndToStart', re);

        return rc.text.length;
    }
    return 0;
}

/* generic sort function */
var sort_by = function(field, reverse, primer) {

   var key = function (x) {return primer ? primer(x[field]) : x[field]};

   return function (a,b) {
       var A = key(a), B = key(b);
       return (A < B ? -1 : (A > B ? 1 : 0)) * [1,-1][+!!reverse];
   }
}

/* numeric comparison function */
function compareNumeric(a, b) {
   return a - b;
}

/* make right pane visible */
function cron_change_date(id) {
    // get selected value
    type_sel = document.getElementById(id);
    var nr = type_sel.id.match(/_(\d+)$/)[1];
    type     = type_sel.options[type_sel.selectedIndex].value;
    hideElement('div_send_month_'+nr);
    hideElement('div_send_monthday_'+nr);
    hideElement('div_send_week_'+nr);
    hideElement('div_send_day_'+nr);
    hideElement('div_send_cust_'+nr);
    showElement('div_send_'+type+'_'+nr);

    if(type == 'cust') {
        hideElement('hour_select_'+nr);
    } else {
        showElement('hour_select_'+nr);
    }
}

/* remove a row */
function delete_cron_row(el) {
    var row = el;
    /* find first table row */
    while(row.parentNode != undefined && row.tagName != 'TR') { row = row.parentNode; }
    row.parentNode.deleteRow(row.rowIndex);
    return false;
}

/* remove a row */
function add_cron_row(tbl_id) {
    var tbl            = document.getElementById(tbl_id);
    var tblBody        = tbl.tBodies[0];

    /* get first table row */
    var row = tblBody.rows[0];
    var newRow = row.cloneNode(true);

    /* get highest number */
    var new_nr = 1;
    jQuery.each(tblBody.rows, function(i, r) {
        if(r.id) {
            var nr = r.id.match(/_(\d+)$/)[1];
            if(nr >= new_nr) {
                new_nr = parseInt(nr) + 1;
            }
        }
    });

    /* replace ids / names */
    replace_ids_and_names(newRow, new_nr);
    var all = newRow.getElementsByTagName('*');
    for (var i = -1, l = all.length; ++i < l;) {
        var elem = all[i];
        replace_ids_and_names(elem, new_nr);
    }

    newRow.style.display = "";

    var lastRowNr      = tblBody.rows.length - 1;
    var currentLastRow = tblBody.rows[lastRowNr];
    tblBody.insertBefore(newRow, currentLastRow);
}

/* filter table content by search field */
var table_search_input_id, table_search_table_ids, table_search_timer;
var table_search_cb = {};
function table_search(input_id, table_ids, nodelay) {
    table_search_input_id  = input_id;
    table_search_table_ids = table_ids;
    clearTimeout(table_search_timer);
    if(nodelay != undefined) {
        do_table_search();
    } else {
        table_search_timer = window.setTimeout('do_table_search()', 300);
    }
}
/* do the search work */
function do_table_search() {
    var ids      = table_search_table_ids;
    var value    = jQuery('#'+table_search_input_id).val();
    if(value == undefined) {
        return;
    }
    value    = value.toLowerCase();
    set_hash(value, 2);
    jQuery.each(ids, function(nr, id) {
        var table = document.getElementById(id);
        var matches = table.className.match(/searchSubTable_([^\ ]*)/);
        if(matches && matches[1]) {
            jQuery(table).find("TABLE."+matches[1]).each(function(x, t) {
                do_table_search_table(id, t, value);
            });
        } else {
            do_table_search_table(id, table, value);
        }
    });
}

function do_table_search_table(id, table, value) {
    /* make tables fixed width to avoid flickering */
    if(table.offsetWidth) {
        table.width = table.offsetWidth;
    }
    var startWith = 1;
    if(jQuery(table).hasClass('header2')) {
        startWith = 2;
    }
    if(jQuery(table).hasClass('search_vertical')) {
        var totalFound = 0;
        jQuery.each(table.rows[0].cells, function(col_nr, ref_cell) {
            if(col_nr < startWith) {
                return;
            }
            var found = 0;
            jQuery.each(table.rows, function(nr, row) {
                var cell = row.cells[col_nr];
                try {
                    if(cell.innerHTML.toLowerCase().match(value)) {
                        found = 1;
                    }
                } catch(err) {
                    if(cell.innerHTML.toLowerCase().indexOf(value) != -1) {
                        found = 1;
                    }
                }
            });
            jQuery.each(table.rows, function(nr, row) {
                var cell = row.cells[col_nr];
                if(found == 0) {
                    jQuery(cell).addClass('filter_hidden');
                } else {
                    jQuery(cell).removeClass('filter_hidden');
                }
            });
            if(found > 0) {
                totalFound++;
            }
        });
        if(jQuery(table).hasClass('search_hide_empty')) {
            if(totalFound == 0) {
                jQuery(table).addClass('filter_hidden');
            } else {
                jQuery(table).removeClass('filter_hidden');
            }
        }
    } else {
        jQuery.each(table.rows, function(nr, row) {
            if(nr < startWith) {
                return;
            }
            if(jQuery(row).hasClass('table_search_skip')) {
                return;
            }
            var found = 0;
            jQuery.each(row.cells, function(nr, cell) {
                /* if regex matching fails, use normal matching */
                try {
                    if(cell.innerHTML.toLowerCase().match(value)) {
                        found = 1;
                    }
                } catch(err) {
                    if(cell.innerHTML.toLowerCase().indexOf(value) != -1) {
                        found = 1;
                    }
                }
            });
            if(found == 0) {
                jQuery(row).addClass('filter_hidden');
            } else {
                jQuery(row).removeClass('filter_hidden');
            }
        });
    }
    if(table_search_cb[id] != undefined) {
        try {
            table_search_cb[id]();
        } catch(err) {
            debug(err);
        }
    }
}

/* show bug report icon */
function showBugReport(id, text) {
    var link = document.getElementById('bug_report-btnEl');
    var raw  = text;
    var href="mailto:"+bug_email_rcpt+"?subject="+encodeURIComponent("Thruk JS Error Report")+"&body="+encodeURIComponent(text);
    if(link) {
        text = "Please describe what you did:\n\n\n\n\nMake sure the report does not contain confidential information.\n\n---------------\n" + text;
        link.href=href;
    }

    var obj = document.getElementById(id);
    try {
        /* for extjs */
        Ext.getCmp(id).show();
        Ext.getCmp(id).setHref(href);
        Ext.getCmp(id).el.dom.ondblclick    = function() { return showErrorTextPopup(raw) };
        Ext.getCmp(id).el.dom.oncontextmenu = function() { return showErrorTextPopup(raw) };
        Ext.getCmp(id).el.dom.style.zIndex = 1000;
    }
    catch(err) {
        /* for all other pages */
        if(obj) {
            obj.style.display    = '';
            obj.style.visibility = 'visible';
            obj.ondblclick       = function() { return showErrorTextPopup(raw) };
            obj.oncontextmenu    = function() { return showErrorTextPopup(raw) };
        }
    }
}

/* show popup with the current error text */
function showErrorTextPopup(text) {
    text      = "<pre style='text-align:left;'>"+text+"<\/pre>";
    var title = "Error Report";
    if(window.overlib != undefined) {
        try {
            var options = [text,CAPTION,title,WIDTH,900];
            options     = options.concat(info_popup_options);
            overlib.apply(this, options);
        }
        catch(e) {}
    }
    if (window.Ext != undefined) {
        Ext.Msg.alert(title, text);
    }
    return(false);
}

/* create error text for bug reports */
function getErrorText(details, error) {
    var text = "";
    text = text + "Version:    " + version_info+"\n";
    text = text + "Release:    " + released+"\n";
    text = text + "Url:        " + window.location.pathname + "?" + window.location.search + "\n";
    text = text + "Browser:    " + navigator.userAgent + "\n";
    text = text + "Backends:   ";
    var first = 1;
    for(var nr=0; nr<initial_backends.length; nr++) {
        if(!first) { text = text + '            '; }
        text = text + initial_backends[nr].state + ' / ' + initial_backends[nr].version + ' / ' + initial_backends[nr].data_src_version + "\n";
        first = 0;
    }
    text = text + details;
    text = text + "Error List:\n";
    for(var nr=0; nr<thruk_errors.length; nr++) {
        text = text + thruk_errors[nr]+"\n";
    }

    /* try to get a stacktrace */
    var stacktrace = "";
    text += "\n";
    text += "Full Stacktrace:\n";
    if(error && error.stack) {
        text = text + error.stack;
        stacktrace = stacktrace + error.stack;
    }
    try {
        var stack = [];
        var f = arguments.callee.caller;
        while (f) {
            if(f.name != 'thruk_onerror') {
                stack.push(f.name);
            }
            f = f.caller;
        }
        text = text + stack.join("\n");
        stacktrace = stacktrace + stack.join("\n");
    } catch(err) {}

    /* try to get source mapping */
    try {
        var file = error.fileName;
        var line = error.lineNumber;
        /* get filename / line from stack if possible */
        var stackExplode = stacktrace.split(/\n/);
        for(var nr=0; nr<stackExplode.length; nr++) {
            if(!stackExplode[nr].match(/eval/)) {
                var matches = stackExplode[nr].match(/(https?:.*?):(\d+):(\d+)/i);
                if(matches && matches[2]) {
                    file = matches[1];
                    line = Number(matches[2]);
                    nr = stackExplode.length + 1;
                }
            }
        }
        if(window.XMLHttpRequest && file && !file.match("eval")) {
            var xhr = new XMLHttpRequest();
            xhr.open("GET", file);
            xhr.setRequestHeader("Content-Type", "text/plain;charset=UTF-8");
            xhr.send(null);
            var source = xhr.responseText.split(/\n/);
            text += "\n";
            text += "Source:\n";
            if(line > 2) { text += shortenSource(source[line-2]); }
            if(line > 1) { text += shortenSource(source[line-1]); }
            text += shortenSource(source[line]);
        }
    } catch(err) {}

    /* this only works in panorama view */
    /*
     *removed... doesn't help much and just fills the logfile
    try {
        if(TP.logHistory) {
            text += "\n";
            text += "Panorama Log:\n";
            var formatLogEntry = function(entry) {
                var date = Ext.Date.format(entry[0], "Y-m-d H:i:s.u");
                return('['+date+'] '+entry[1]+"\n");
            }
            for(var i=TP.logHistory.length-1; i > 0; i--) {
                text += formatLogEntry(TP.logHistory[i]);
            }
        }
    } catch(err) {}
    */
    text += "\n";
    return(text);
}

/* create error text for bug reports */
function sendJSError(scripturl, text) {
    if(text && window.XMLHttpRequest) {
        var xhr = new XMLHttpRequest();
        text = '---------------\nJS-Error:\n'+text+'---------------\n';
        xhr.open("POST", scripturl);
        xhr.setRequestHeader("Content-Type", "text/plain;charset=UTF-8");
        xhr.send(text);
        thruk_errors = [];
    }
    return;
}

/* return shortened string */
function shortenSource(text) {
    if(text.length > 100) {
        return(text.substr(0, 97)+"...\n");
    }
    return(text+"\n");
}

/* update recurring downtime type select */
function update_recurring_type_select(select_id) {
    var sel = document.getElementById(select_id);
    if(!sel) {
        return;
    }
    var val = sel.options[sel.selectedIndex].value;
    hideElement('input_host');
    hideElement('input_host_options');
    hideElement('input_hostgroup');
    hideElement('input_service');
    hideElement('input_servicegroup');
    if(val == 'Host') {
        showElement('input_host');
        showElement('input_host_options');
    }
    if(val == 'Hostgroup') {
        showElement('input_hostgroup');
        showElement('input_host_options');
    }
    if(val == 'Service') {
        showElement('input_host');
        showElement('input_service');
    }
    if(val == 'Servicegroup') {
        showElement('input_servicegroup');
    }
    return;
}

/* make table header selectable */
function set_sub(nr) {
    for(x=1;x<=10;x++) {
        /* reset table rows */
        if(x != nr) {
            jQuery('.sub_'+x).css('display', 'none');
        }
        jQuery('.sub_'+nr).css('display', '');

        /* reset buttons */
        obj = document.getElementById("sub_"+x);
        if(obj) {
            styleElements(obj, "data", 1);
        }
    }
    obj = document.getElementById("sub_"+nr);
    styleElements(obj, "data dataSelected", 1);


    return false;
}

/* hilight area of screen */
function hilight_area(x1, y1, x2, y2, duration, color) {
    if(!color)    { color    = 'red'; };
    if(!duration) { duration = 2000; };
    var rnd = Math.floor(Math.random()*10000000);

    jQuery(document.body).append('<div id="hilight_area'+rnd+'" style="width:'+(x2-x1)+'px; height:'+(y2-y1)+'px; position: absolute; background-color: '+color+'; opacity:0.2; top: '+y1+'px; left: '+x1+'px; z-index:10000;">&nbsp;<\/div>');

    window.setTimeout(function() {
       fade('hilight_area'+rnd, 1000);
    }, duration);
}

/* fade out using jquery ui, ensure jquery ui loaded */
function fade(id, duration) {
    var success = function(script, textStatus, jqXHR) {
        jQuery('#'+id).hide('fade', {}, duration);
    };

    if(has_jquery_ui) {
        success();
    } else {
        load_jquery_ui(success);
    }

    // completly remove message from dom after fading out
    if(id == 'thruk_message') {
        window.setTimeout("jQuery('#"+id+"').remove()", duration + 1000);
    }
}

var ui_loading = false;
function load_jquery_ui(callback) {
    if(has_jquery_ui || ui_loading) {
        return;
    }
    var css  = document.createElement('link');
    css.href = jquery_ui_css;
    css.rel  = 'stylesheet';
    css.type = 'text/css';
    document.body.appendChild(css);
    ui_loading = true;
    jQuery.ajax({
        url:       jquery_ui_url,
        dataType: 'script',
        success:   function(script, textStatus, jqXHR) {
            has_jquery_ui = true;
            callback(script, textStatus, jqXHR);
            ui_loading = false;
        },
        cache:     true
    });
}


/* write/return table with performance data */
var thruk_message_fade_timer;
function thruk_message(rc, message, close_timeout) {
    jQuery('#thruk_message').remove();
    window.clearInterval(thruk_message_fade_timer);
    cls = 'fail_message';
    if(rc == 0) { cls = 'success_message'; }
    var html = ''
        +'<div id="thruk_message" class="thruk_message '+cls+'" style="position: fixed; z-index: 5000; width: 600px; top: 30px; left: 50%; margin-left:-300px;">'
        +'  <div class="shadow"><div class="shadowcontent">'
        +'  <table cellspacing=2 cellpadding=0 width="100%" style="background: #F0F1EE; border: 1px solid black">'
        +'    <tr>'
        +'      <td align="center">'
        +'        <span class="' + cls + '">' + message + '<\/span>';
    if(rc != 0) {
        html += ''
        +'          <img src="' + url_prefix + 'themes/'+ theme +'/images/error.png" alt="Errors detected" title="Errors detected" width="16" height="16" style="vertical-align: text-bottom">'
    }
    html += ''
        +'      <\/td>'
        +'      <td valign="top" align="right" width="50">'
        +'        <a href="#" onclick="fade(\'thruk_message\', 500);return false;"><img src="' + url_prefix + 'themes/' + theme + '/images/icon_close.gif" border="0" alt="Hide Message" title="Hide Message" width="13" height="12" class="close_button" style="margin-right: 4px;"><\/a>'
        +'      <\/td>'
        +'    <\/tr>'
        +'  <\/table>'
        +'  <\/div><\/div>';

    jQuery("body").append(html);
    var fade_away_in = 5000;
    if(rc != 0) {
        fade_away_in = 30000;
    }
    if(close_timeout != undefined) {
        if(close_timeout == 0) {
            return;
        }
        fade_away_in = close_timeout * 1000;
    }
    thruk_message_fade_timer = window.setTimeout("fade('thruk_message', 500)", fade_away_in);
}

/* return absolute host part of current url */
function get_host() {
    var host = window.location.protocol + '//' + window.location.host;
    if(window.location.port != "" && host.indexOf(':' + window.location.port) == -1) {
        host += ':' + window.location.port;
    }
    return(host);
}

var nohashchange = 0;
function save_url_in_parents_hash() {
    if(nohashchange == 1) {
      nohashchange = 0;
      return;
    }
    var oldloc = new String(window.parent.location);
    oldloc     = oldloc.replace(/#+.*$/, '');
    oldloc     = oldloc.replace(/\?.*$/, '');
    var patt   = new RegExp('\/'+product_prefix+'\/$', 'g');
    if(!oldloc.match(patt)) {
        return;
    }
    var newloc = new String(window.location);
    newloc     = newloc.replace(oldloc, '');
    // changes have to be put in the index.tt too
    newloc     = newloc.replace(/\?_=\d+/g, '');
    newloc     = newloc.replace(/\&_=\d+/g, '');
    newloc     = newloc.replace(/\&reload_nav=\d+/g, '');
    newloc     = newloc.replace(/\?reload_nav=\d+/g, '');
    newloc     = newloc.replace(/\&theme=\w*/g, '');
    newloc     = newloc.replace(/\?theme=\w*/g, '');
    newloc     = newloc.replace(/nav=\&/g, '');
    newloc     = newloc.replace(/\&service_columns=\d+/g, '');
    newloc     = newloc.replace(/\&host_columns=\d+/g, '');
    newloc     = newloc.replace(/\&bookmarks=.*?\&/g, '&');
    newloc     = newloc.replace(/\&bookmarksp=.*?\&/g, '&');
    newloc     = newloc.replace(/\&section=.*?\&/g, '&');
    newloc     = newloc.replace(/\&update\.x=\d+/g, '');
    newloc     = newloc.replace(/\&update\.y=\d+/g, '');
    newloc     = newloc.replace(/\&newname=\&/g, '&');
    newloc     = newloc.replace(/\&view_mode=html\&/g, '&');
    newloc     = newloc.replace(/\&all_col=\&/g, '&');
    newloc     = newloc.replace(/\&bookmark=.*?\&/g, '&');
    newloc     = newloc.replace(/\&referer=.*?\&/g, '&');
    var patt   = new RegExp('^' + get_host(), 'gi');
    newloc     = newloc.replace(patt, '');
    if('#'+newloc != window.parent.location.hash) {
        if(window.parent.history.replaceState) {
            window.parent.history.replaceState({}, "", '#'+newloc);
        } else {
            nohashchange = 1;
            // do not use window.parent.location.replace, as this causes
            // IE to reload the frame page and then the navigation disapears
            window.parent.location.hash = '#'+newloc;
        }
        window.setTimeout("nohashchange=0", 100);
    }
    return;
}

/* set hash of url */
function set_hash(value, nr) {
    if(value == undefined)   { value = ""; }
    if(value == "undefined") { value = ""; }
    var current = get_hash();
    if(nr != undefined) {
        if(current == undefined) {
            current = "";
        }
        var tmp   = current.split('|');
        tmp[nr-1] = value;
        value     = tmp.join('|');
    }
    // make emtpy values nicer, trim trailing pipes
    value = value.replace(/\|$/, '');

    // replace history otherwise we have to press back twice
    if(current == value) { return; }
    if(value == "") {
        value = getCurrentUrl(false).replace(/\#.*$/, "");
    } else {
        value = '#'+value;
    }
    if (history.replaceState) {
        history.replaceState({}, "", value);
    } else {
        window.location.replace(value);
    }
    if(window.parent) {
        try {
            save_url_in_parents_hash();
        } catch(err) { debug(err); }
    }
}

/* get hash of url */
function get_hash(nr) {
    var hash;
    if(window.location.hash != '#') {
        var values = window.location.hash.split("/");
        if(values[0]) {
            hash = values[0].replace(/^#/, '');
        }
    }
    if(nr != undefined) {
        if(hash == undefined) {
            hash = "";
        }
        var tmp = hash.split('|');
        return(tmp[nr-1]);
    }
    return(hash);
}

function preserve_hash() {
    // save hash value for 30 seconds
    cookieSave('thruk_preserve_hash', get_hash(), 60);
}

/* fetch content by ajax and replace content */
function load_overlib_content(id, url, add_pre) {
    jQuery.ajax({
        url: url,
        type: 'POST',
        success: function(data) {
            var el = document.getElementById(id);
            if(el) {
                if(add_pre) {
                    data.data = "<pre>"+data.data+"<\/pre>";
                }
                el.innerHTML = data.data;
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            debug(textStatus);
        }
    });
}

/* update permanent link of excel export */
function updateExcelPermanentLink() {
    var inp  = jQuery('#excel_export_url');
    var data = jQuery(inp).parents('FORM').find('input[name!=bookmark][name!=referer][name!=view_mode][name!=all_col]').serialize();
    var base = jQuery('#excelexportlink')[0].href;
    base = cleanUnderscore(base);
    if(!data) {
        jQuery(inp).val(base);
        return;
    }
    jQuery(inp).val(base + (base.match(/\?/) ? '&' : '&') + data);
    initExcelExportSorting();
}

/* compare two objects and print diff
 * returns true if they differ and false if they are equal
 */
function obj_diff(o1, o2, prefix) {
    if(prefix == undefined) { prefix = ""; }
    if(typeof(o1) != typeof(o2)) {
        debug("type is different: a" + prefix + " "+typeof(o1)+"       b" + prefix + " "+typeof(o2));
        return(true);
    }
    else if(is_array(o1)) {
        for(var nr=0; nr<o1.length; nr++) {
            if(obj_diff(o1[nr], o2[nr], prefix+"["+nr+"]")) {
                return(true);
            }
        }
    }
    else if(typeof(o1) == 'object') {
        for(var key in o1) {
            if(obj_diff(o1[key], o2[key], prefix+"["+key+"]")) {
                return(true);
            }
        }
    } else if(typeof(o1) == 'string' || typeof(o1) == 'number' || typeof(o1) == 'boolean') {
        if(o1 != o2) {
            debug("value is different: a" + prefix + " "+o1+"       b" + prefix + " "+o2);
            return(true);
        }
    } else {
        debug("don't know how to compare: "+typeof(o1)+" at a"+prefix);
    }
    return(false);
}

/* callback to show popup with host comments */
function host_comments_popup(host_name, peer_key) {
    generic_downtimes_popup(host_name+' Comments', url_prefix+'cgi-bin/parts.cgi?part=_host_comments&host='+encodeURIComponent(host_name)+"&backend="+peer_key);
}

/* callback to show popup with host downtimes */
function host_downtimes_popup(host_name, peer_key) {
    generic_downtimes_popup(host_name+' Downtimes', url_prefix+'cgi-bin/parts.cgi?part=_host_downtimes&host='+encodeURIComponent(host_name)+"&backend="+peer_key);
}

/* callback to show popup with service comments */
function service_comments_popup(host_name, service, peer_key) {
    generic_downtimes_popup(host_name+' - '+service+' Comments', url_prefix+'cgi-bin/parts.cgi?part=_service_comments&host='+encodeURIComponent(host_name)+'&service='+encodeURIComponent(service)+"&backend="+peer_key);
}

/* callback to show popup with service downtimes */
function service_downtimes_popup(host_name, service, peer_key) {
    generic_downtimes_popup(host_name+' - '+service+' Downtimes', url_prefix+'cgi-bin/parts.cgi?part=_service_downtimes&host='+encodeURIComponent(host_name)+'&service='+encodeURIComponent(service)+"&backend="+peer_key);
}

/* callback to show popup host/service downtimes */
function generic_downtimes_popup(title, url) {
    var content = "<div id='comments_downtimes_popup'><img src='"+url_prefix + 'themes/' + theme + '/images/loading-icon.gif'+"'><\/div>";
    var options = [content, CAPTION, title,WIDTH,600];
    options = options.concat(info_popup_options);
    overlib.apply(this, options);
    jQuery('#comments_downtimes_popup').load(url);
}

function fetch_long_plugin_output(td, host, service, backend, escape_html) {
    jQuery('.long_plugin_output').html("<img src='"+url_prefix + 'themes/' + theme + '/images/loading-icon.gif'+"'><\/div>");
    var url = url_prefix+'cgi-bin/status.cgi?long_plugin_output=1&host='+host+"&service="+service+"&backend="+backend;
    if(escape_html) {
        jQuery.get(url, {}, function(text, status, req) {
            text = jQuery("<div>").text(text).html().replace(/\\n/g, "<br>");
            jQuery('.long_plugin_output').html(text)
        });
    } else {
        jQuery('.long_plugin_output').load(url, {}, function(text, status, req) {
        });
    }
}

function initExcelExportSorting() {
    if(!has_jquery_ui) {
        load_jquery_ui(function() {
            initExcelExportSorting();
        });
        return;
    }
    if(already_sortable["excel_export"]) {
        return;
    }
    already_sortable["excel_export"] = true;

    jQuery('TABLE.sortable_col_table').sortable({
        items                : 'TR.sortable_row',
        helper               : 'clone',
        tolerance            : 'pointer',
        update               : function( event, ui ) {
            updateExcelPermanentLink();
        }
    });
}

// make the columns sortable
var already_sortable = {};
function initStatusTableColumnSorting(pane_prefix, table_id) {
    if(!has_jquery_ui) {
        load_jquery_ui(function() {
            initStatusTableColumnSorting(pane_prefix, table_id);
        });
        return;
    }
    if(already_sortable[pane_prefix]) {
        return;
    }
    already_sortable[pane_prefix] = true;

    jQuery('#'+table_id+' > tbody > tr:first-child').sortable({
        items                : '> th',
        helper               : 'clone',
        tolerance            : 'pointer',
        update               : function( event, ui ) {
            var oldIndexes = []
            var rowsToSort = {};
            var table;
            // remove all current rows from the column selector, they will be later readded in the right order
            jQuery('#'+pane_prefix+'_columns_table > tbody > tr').each(function(i, el) {
                table = el.parentNode;
                var row = el.parentNode.removeChild(el);
                var field = jQuery(row).find("input").val();
                rowsToSort[field] = row;
                oldIndexes.push(field);
            });
            // fetch the target column order based on the current status table header
            var target = [];
            jQuery('#'+table_id+' > tbody > tr:first-child > th').each(function(i, el) {
                var col = get_column_from_classname(el);
                if(col) {
                    target.push(col);
                }
            });
            jQuery(target).each(function(i, el) {
                table.appendChild(rowsToSort[el]);
            });
            // remove the current column header and readd them in original order, so later ordering wont skip headers
            var currentHeader = {};
            jQuery('#'+table_id+' > tbody > tr:first-child > th').each(function(i, el) {
                table = el.parentNode;
                var row = el.parentNode.removeChild(el);
                var col = get_column_from_classname(el);
                if(col) {
                    currentHeader[col] = row;
                }
            });
            jQuery(oldIndexes).each(function(i, el) {
                table.appendChild(currentHeader[el]);
            });
            updateStatusColumns(pane_prefix, false);
        }
    });
    jQuery('#'+pane_prefix+'_columns_table tbody').sortable({
        items                : '> tr',
        placeholder          : 'column-sortable-placeholder',
        update               : function( event, ui ) {
            /* drag/drop changes the checkbox state, so set checked flag assuming that a moved column should be visible */
            window.setTimeout(function() {
                jQuery(ui.item[0]).find("input").prop('checked', true);
                updateStatusColumns(pane_prefix, false);
            }, 100);
        }
    });
    /* enable changing columns header name */
    jQuery('#'+table_id+' > tbody > tr:first-child > th').dblclick(function(evt) {
        var th = evt.target;
        var text   = (th.innerText || '').replace(/\s*$/, '');
        var childs = removeChilds(th);
        th.innerHTML = "<input type='text' class='header_inline_edit' value='"+text+"'></form>";
        window.setTimeout(function() {
            jQuery(th).find('INPUT').focus();
            var input = jQuery(th).find('INPUT')[0];
            setCaretToPos(input, text.length);
            jQuery(input).on('keyup blur', function (e) {
                /* submit on enter/return */
                if(e.keyCode == 13 || e.type == "blur") {
                    th.innerHTML = escapeHTML(input.value)+" ";
                    // restore sort links
                    addChilds(th, childs, 1);
                    var col  = get_column_from_classname(th);
                    var orig = jQuery('#'+pane_prefix+'_col_'+col)[0].title;

                    var cols = default_columns[pane_prefix];
                    if(additionalParams[pane_prefix+'columns']) {
                        cols = additionalParams[pane_prefix+'columns'];
                    }
                    cols = cols.split(/,/);
                    for(var x = 0; x < cols.length; x++) {
                        var tmp = cols[x].split(/:/, 2);
                        if(tmp[0] == col) {
                            if(orig != input.value) {
                                cols[x] = tmp[0]+':'+input.value;
                            } else {
                                cols[x] = tmp[0];
                            }
                        }
                    }

                    jQuery('#'+pane_prefix+'_col_'+col+'n')[0].innerHTML = input.value;

                    var newVal = cols.join(',');
                    jQuery('#'+pane_prefix+'columns').val(newVal);
                    additionalParams[pane_prefix+'columns'] = newVal;
                    updateUrl();
                }
                /* cancel on escape */
                if(e.keyCode == 27) {
                    th.innerHTML = text+" ";
                    // restore sort links
                    addChilds(th, childs, 1);
                }
            });
        }, 100);
    });
    /* enable changing columns header name */
    jQuery('#'+pane_prefix+'_columns_table tbody td.filterName').dblclick(function(evt) {
        var th = evt.target;
        var text   = (th.innerText || '').replace(/\s*$/, '');
        th.innerHTML = "<input type='text' class='header_inline_edit' value='"+text+"'></form>";
        window.setTimeout(function() {
            jQuery(th).find('INPUT').focus();
            var input = jQuery(th).find('INPUT')[0];
            setCaretToPos(input, text.length);
            jQuery(input).on('keydown blur', function (e) {
                /* submit on enter/return */
                if(e.keyCode == 13 || e.type == "blur") {
                    e.preventDefault();
                    th.innerHTML = escapeHTML(input.value);
                    var col  = get_column_from_classname(th);
                    var orig = jQuery('#'+pane_prefix+'_col_'+col)[0].title;

                    var cols = default_columns[pane_prefix];
                    if(additionalParams[pane_prefix+'columns']) {
                        cols = additionalParams[pane_prefix+'columns'];
                    }
                    cols = cols.split(/,/);
                    for(var x = 0; x < cols.length; x++) {
                        var tmp = cols[x].split(/:/, 2);
                        if(tmp[0] == col) {
                            if(orig != input.value) {
                                cols[x] = tmp[0]+':'+input.value;
                            } else {
                                cols[x] = tmp[0];
                            }
                        }
                    }

                    var header = jQuery('.'+pane_prefix+'_table').find('th.status.col_'+col)[0];
                    var childs = removeChilds(header);
                    header.innerHTML = input.value+" ";
                    addChilds(header, childs, 1);

                    var newVal = cols.join(',');
                    jQuery('#'+pane_prefix+'columns').val(newVal);
                    additionalParams[pane_prefix+'columns'] = newVal;
                    updateUrl();
                }
                /* cancel on escape */
                if(e.keyCode == 27) {
                    e.preventDefault();
                    th.innerHTML = text+" ";
                }
            });
        }, 100);
    });
}

// remove and return all child nodes
function removeChilds(el) {
    var childs = [];
    while(el.firstChild) {
        childs.push(el.removeChild(el.firstChild));
    }
    return(childs);
}

// add all elements as child
function addChilds(el, childs, startWith) {
    if(startWith == undefined) { startWith = 0; }
    for(var x = startWith; x < childs.length; x++) {
        el.appendChild(childs[x]);
    }
}

/* returns the value of the col_.* class */
function get_column_from_classname(el) {
    var classes = el.className.split(/\s+/);
    for(var x = 0; x < classes.length; x++) {
        var m = classes[x].match(/^col_(.*)$/);
        if(m && m[1]) {
            return(m[1]);
        }
    }
    return;
}

// apply status table columns
function updateStatusColumns(id, reloadRequired) {
    resetRefresh();
    var table = jQuery('.'+id+'_table')[0];
    if(!table) {
        if(thruk_debug_js) { alert("ERROR: no table found in updateStatusColumns(): " + id); }
    }
    var changed = false;
    if(reloadRequired == undefined) { reloadRequired = true; }
    table.style.visibility = "hidden";

    removeParams['autoShow'] = true;

    var firstRow = table.rows[0];
    var firstDataRow = [];
    if(table.rows.length > 1) {
        firstDataRow = table.rows[1];
    }
    var selected = [];
    jQuery('.'+id+'_col').each(function(i, el) {
        if(!jQuery(firstRow.cells[i]).hasClass("col_"+el.value)) {
            // need to reorder column
            var targetIndex = i;
            var sourceIndex;
            jQuery(firstRow.cells).each(function(j, c) {
                if(jQuery(c).hasClass("col_"+el.value)) {
                    sourceIndex = j;
                    return false;
                }
            });
            var dataSourceIndex;
            jQuery(firstDataRow.cells).each(function(j, c) {
                if(jQuery(c).hasClass(el.value)) {
                    dataSourceIndex = j;
                    return false;
                }
            });
            if(sourceIndex == undefined && !reloadRequired) {
                if(thruk_debug_js) { alert("ERROR: unknown header column in updateStatusColumns(): " + el.value); }
                return;
            }
            if(firstDataRow.cells && dataSourceIndex == undefined) {
                reloadRequired = true;
            }
            if(sourceIndex) {
                if(firstRow.cells[sourceIndex]) {
                    var cell = firstRow.removeChild(firstRow.cells[sourceIndex]);
                    firstRow.insertBefore(cell, firstRow.cells[targetIndex]);
                }
                changed = true;
            }
            if(dataSourceIndex) {
                jQuery(table.rows).each(function(j, row) {
                    if(j > 0 && row.cells[dataSourceIndex]) {
                        var cell = row.removeChild(row.cells[dataSourceIndex]);
                        row.insertBefore(cell, row.cells[targetIndex]);
                    }
                });
                changed = true;
            }
        }

        // adjust table header text
        var current   = (firstRow.cells[i].innerText || '').trim();
        var newHeadEl = document.getElementById(el.id+'n');
        if(!newHeadEl) {
            if(thruk_debug_js) { alert("ERROR: header element not found in updateStatusColumns(): " + el.id+'n'); }
            table.style.visibility = "visible";
            return;
        }
        var newHead = newHeadEl.innerHTML.trim();
        if(current != newHead) {
            var childs = removeChilds(firstRow.cells[i]);
            firstRow.cells[i].innerHTML = newHead+" ";
            addChilds(firstRow.cells[i], childs, 1);
            changed = true;
        }

        // check visibility of this column
        var display = "none";
        if(el.checked) {
            display = "";
            if(newHead != el.title) {
                selected.push(el.value+':'+newHead);
            } else {
                selected.push(el.value);
            }
        }
        if(table.rows[0].cells[i].style.display != display) {
            changed = true;
            jQuery(table.rows).each(function(j, row) {
                if(row.cells[i]) {
                    row.cells[i].style.display = display;
                }
            });
        }
    });
    if(changed) {
        var newVal = selected.join(",");
        if(newVal != default_columns[id]) {
            jQuery('#'+id+'columns').val(newVal);
            additionalParams[id+'columns'] = newVal;
            delete removeParams[id+'columns'];

            if(reloadRequired && table.rows[1] && table.rows[1].cells.length < 10) {
                additionalParams["autoShow"] = id+"_columns_select";
                delete removeParams['autoShow'];
                jQuery('#'+id+"_columns_select").find("DIV.shadowcontent").append("<div class='overlay'></div>").append("<div class='overlay-text'><img class='overlay' src='"+url_prefix + 'themes/' +  theme + "/images/loading-icon.gif'><br>fetching table...</div>");
                table.style.visibility = "visible";
                reloadPage();
                return;
            }
        } else {
            jQuery('#'+id+'columns').val("");
            delete additionalParams[id+'columns'];
            removeParams[id+'columns'] = true;
        }
        updateUrl();
    }
    table.style.visibility = "visible";
}

/* reload page with with sorting parameters set */
function sort_by_columns(args) {
    for(var key in args) {
        additionalParams[key] = args[key];
    }
    reloadPage();
    return(false);
}

function setDefaultColumns(type, pane_prefix, value) {
    updateUrl();
    if(value == undefined) {
        var urlArgs  = toQueryParams();
        value = urlArgs[pane_prefix+"columns"];
    }

    var data = {
        action:  'set_default_columns',
        type:    type,
        value:   value,
        token:   user_token
    };
    jQuery.ajax({
        url: "status.cgi",
        data: data,
        type: 'POST',
        success: function(data) {
            thruk_message(data.rc, data.msg);
            if(value == "") {
                jQuery("."+pane_prefix+"_reset_columns_btn").attr({disabled: true});
                removeParams[pane_prefix+'columns'] = true;
                reloadPage();
            } else {
                jQuery("."+pane_prefix+"_reset_columns_btn").attr({disabled: false});
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            thruk_message(1, 'setting default failed: '+ textStatus);
        }
    });
    return(false);
}

function refreshNavSections(id) {
    jQuery.ajax({
        url: "status.cgi?type=navsection&format=search",
        type: 'POST',
        success: function(data) {
            if(data && data[0]) {
                jQuery('#'+id).find('option').remove();
                jQuery('#'+id).append(jQuery('<option>', {
                    value: 'Bookmarks',
                    text : 'Bookmarks'
                }));
                jQuery.each(data[0].data, function (i, item) {
                    if(item != "Bookmarks") {
                        jQuery('#'+id).append(jQuery('<option>', {
                            value: item,
                            text : item
                        }));
                    }
                });
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            thruk_message(1, 'fetching side nav sections failed: '+ textStatus);
        }
    });
    return(false);
}

function broadcast_show_list(incr) {
    var broadcasts = jQuery(".broadcast_panel_container div.broadcast");
    var curIdx = 0;
    jQuery(broadcasts).each(function(i, n) {
        if(jQuery(n).is(":visible")) {
            jQuery(n).hide();
            curIdx = i;
            return(false);
        }
    });
    var newIdx = curIdx+incr;
    jQuery(broadcasts[newIdx]).show();
    jQuery(".broadcast_panel_container BUTTON.next").css('visibility', '');
    jQuery(".broadcast_panel_container BUTTON.previous").css('visibility', '');
    if(newIdx == broadcasts.length -1) {
        jQuery(".broadcast_panel_container BUTTON.next").css('visibility', 'hidden');
    }
    if(newIdx == 0) {
        jQuery(".broadcast_panel_container BUTTON.previous").css('visibility', 'hidden');
    }
}

function broadcast_dismiss() {
    jQuery('.broadcast_panel_container').hide();
    jQuery.ajax({
        url: url_prefix + 'cgi-bin/broadcast.cgi',
        data: {
            action: 'dismiss',
            token:  user_token
        },
        type: 'POST',
        success: function(data) {},
        error: function(jqXHR, textStatus, errorThrown) {
            thruk_message(1, 'marking broadcast as read failed: '+ textStatus);
        }
    });
    return(false);
}

function looks_like_regex(str) {
    if(str != undefined && str != null && str.match(/[\^\|\*\{\}\[\]]/)) {
        return(true);
    }
    return(false);
}

function show_list(incr, selector) {
    var elements = jQuery(selector);
    var curIdx = 0;
    jQuery(elements).each(function(i, n) {
        if(jQuery(n).is(":visible")) {
            jQuery(n).hide();
            curIdx = i;
            return(false);
        }
    });
    var newIdx = curIdx+incr;
    jQuery(elements[newIdx]).show();
    jQuery("DIV.controls BUTTON.next").css('visibility', '');
    jQuery("DIV.controls BUTTON.previous").css('visibility', '');
    if(newIdx == elements.length -1) {
        jQuery("DIV.controls BUTTON.next").css('visibility', 'hidden');
    }
    if(newIdx == 0) {
        jQuery("DIV.controls BUTTON.previous").css('visibility', 'hidden');
    }
}

/* split that works more like the perl split and appends the remaining str to the last element, doesn't work with regex */
function splitN(str, separator, limit) {
    str = str.split(separator);

    if(str.length > limit) {
        var ret = str.splice(0, limit);
        ret.push(ret.pop()+separator+str.join(separator));

        return ret;
    }

    return str;
}

/*******************************************************************************
*        db        ,ad8888ba, 888888888888 88   ,ad8888ba,   888b      88
*       d88b      d8"'    `"8b     88      88  d8"'    `"8b  8888b     88
*      d8'`8b    d8'               88      88 d8'        `8b 88 `8b    88
*     d8'  `8b   88                88      88 88          88 88  `8b   88
*    d8YaaaaY8b  88                88      88 88          88 88   `8b  88
*   d8""""""""8b Y8,               88      88 Y8,        ,8P 88    `8b 88
*  d8'        `8b Y8a.    .a8P     88      88  Y8a.    .a8P  88     `8888
* d8'          `8b `"Y8888Y"'      88      88   `"Y8888Y"'   88      `888
*******************************************************************************/

/* print the action menu icons and action icons */
var menu_nr = 0;
function print_action_menu(src, backend, host, service, orientation, show_title) {
    try {
        if(orientation == undefined) { orientation = 'b-r'; }
        src = is_array(src) ? src : [src];
        jQuery(src).each(function(i, el) {
            var icon       = document.createElement('img');
            var icon_url   = replace_macros(el.icon);
            icon.src       = icon_url;
            try {
                // use data url in reports
                if(action_images[icon_url]) {
                    icon.src = action_images[icon_url];
                }
            } catch(e) {}
            icon.className = 'action_icon '+(el.menu || el.action ? 'clickable' : '' );
            if(el.menu) {
                icon.nr = menu_nr;
                jQuery(icon).bind("click", function() {
                    /* open and show menu */
                    show_action_menu(icon, el.menu, icon.nr, backend, host, service, orientation);
                });
                menu_nr++;
            }
            var item = icon;

            if(el.action) {
                var link = document.createElement('a');
                link.href = replace_macros(el.action);
                if(el.target) { link.target = el.target; }
                link.appendChild(icon);
                item = link;
            }

            /* apply other attributes */
            set_action_menu_attr(item, el, backend, host, service, function() {
                // must be added as callback, otherwise the order of the binds gets mixed up and "onclick confirms" would be called after the click itself
                if(el.action) {
                    check_server_action(undefined, item, backend, host, service, undefined, undefined, undefined, el);
                }
            });

            /* obtain reference to current script tag so we could insert the icons here */
            var scriptTag = document.scripts[document.scripts.length - 1];
            scriptTag.parentNode.appendChild(item);
            if(show_title && el.title) {
                var title = document.createTextNode(icon.title);
                scriptTag.parentNode.appendChild(title);
            }
        });
    }
    catch(err) {
        document.write('<img src="'+ url_prefix +'themes/'+ theme +'/images/error.png" title="'+err+'">');
    }
}

/* set a single attribute for given item/link */
function set_action_menu_attr(item, data, backend, host, service, callback) {
    var toReplace = {};
    for(var key in data) {
        // those key are handled separately already
        if(key == "icon" || key == "action" || key == "menu" || key == "label") {
            continue;
        }

        var attr = data[key];
        if(String(attr).match(/\$/)) {
            toReplace[key] = attr;
            continue;
        }
        if(key.match(/^on/)) {
            var cmd = attr;
            jQuery(item).bind(key.substring(2), {cmd: cmd}, function(evt) {
                var cmd = evt.data.cmd;
                var res = new Function(cmd)();
                if(!res) {
                    /* cancel default/other binds when callback returns false */
                    evt.stopImmediatePropagation();
                }
                return(res);
            });
        } else {
            item[key] = attr;
        }
    }
    if(Object.keys(toReplace).length > 0) {
        jQuery.ajax({
            url: url_prefix + 'cgi-bin/status.cgi?replacemacros=1',
            data: {
                host:     host,
                service:  service,
                backend:  backend,
                dataJson: JSON.stringify(toReplace),
                token:    user_token
            },
            type: 'POST',
            success: function(data) {
                if(data.rc != 0) {
                    thruk_message(1, 'could not replace macros: '+ data.data);
                } else {
                    set_action_menu_attr(item, data.data, backend, host, service, callback);
                    callback();
                }
            },
            error: function(jqXHR, textStatus, errorThrown) {
                thruk_message(1, 'could not replace macros: '+ textStatus);
            }
        });
    } else {
        callback();
    }
}

/* renders the action menu when openend */
function show_action_menu(icon, items, nr, backend, host, service, orientation) {
    resetRefresh();

    var id = 'actionmenu_'+nr;
    var container = document.getElementById(id);
    if(container) {
        if(container.style.display == '') {
            /* close if already open */
            reset_action_menu_icons();
            container.style.display = 'none';
            return;
        }
        check_position_and_show_action_menu(id, icon, container, orientation);
    }

    window.setTimeout(function() {
        // otherwise the reset comes before we add our new class
        jQuery(icon).addClass('active');
    }, 30);

    if(container) {
        return;
    }

    container               = document.createElement('div');
    container.className     = 'action_menu';
    container.id            = id;
    container.style.visible = 'hidden';

    var s1 = document.createElement('div');
    container.appendChild(s1);
    s1.className = 'shadow';

    var s2 = document.createElement('div');
    s2.className = 'shadowcontent';
    s1.appendChild(s2);

    var menu = document.createElement('ul');
    s2.appendChild(menu);
    menu.className = 'action_menu';

    jQuery(items).each(function(i, el) {
        var item = document.createElement('li');
        menu.appendChild(item);
        if(el == "-") {
            var hr = document.createElement('hr');
            item.appendChild(hr);
            item.className = 'nohover';
            return(true);
        }

        item.className = 'clickable';
        var link = document.createElement('a');
        if(el.icon) {
            var span       = document.createElement('span');
            span.className = 'icon';
            var img        = document.createElement('img');
            img.src        = replace_macros(el.icon);
            img.title      = el.title ? el.title : '';
            span.appendChild(img);
            link.appendChild(span);
        }
        var label = document.createElement('span');
        label.innerHTML = el.label;
        link.appendChild(label);
        link.href       = replace_macros(el.action);

        item.appendChild(link);

        /* apply other attributes */
        set_action_menu_attr(link, el, backend, host, service, function() {
            // must be added as callback, otherwise the order of the binds gets mixed up and "onclick confirms" would be called after the click itself
            check_server_action(id, link, backend, host, service, undefined, undefined, undefined, el);
        });
        return(true);
    });

    document.body.appendChild(container);
    check_position_and_show_action_menu(id, icon, container, orientation);
}

function check_position_and_show_action_menu(id, icon, container, orientation) {
    var coords = jQuery(icon).offset();
    if(orientation == 'b-r') {
        container.style.left = (Math.floor(coords.left)+12) + "px";
    }
    else if(orientation == 'b-l') {
        var w = jQuery(container).outerWidth();
        container.style.left = (Math.floor(coords.left)-w+33) + "px";
    } else {
        if(thruk_debug_js) { alert("ERROR: unknown orientation in show_action_menu(): " + orientation); }
    }
    container.style.top  = (Math.floor(coords.top) + icon.offsetHeight + 14) + "px";

    showElement(id, undefined, true, 'DIV#'+id+' DIV.shadowcontent', reset_action_menu_icons);
}

/* set onclick handler for server actions */
function check_server_action(id, link, backend, host, service, server_action_url, extra_param, callback, config) {
    // server action urls
    if(link.href.match(/^server:\/\//)) {
        if(server_action_url == undefined) {
            server_action_url = url_prefix + 'cgi-bin/status.cgi?serveraction=1';
        }
        var data = {
            host:    host,
            service: service,
            backend: backend,
            link:    link.href,
            token:   user_token
        };
        if(extra_param) {
            for(var key in extra_param) {
                data[key] = extra_param[key];
            }
        }
        jQuery(link).bind("click", function() {
            var oldSrc = jQuery(link).find('IMG').attr('src');
            jQuery(link).find('IMG').attr({src:  url_prefix + 'themes/' +  theme + '/images/loading-icon.gif', width: 16, height: 16 }).css('margin', '2px 0px');
            if(config == undefined) { config = {}; }
            jQuery.ajax({
                url: server_action_url,
                data: data,
                type: 'POST',
                success: function(data) {
                    thruk_message(data.rc, data.msg, config.close_timeout);
                    if(id) { remove_close_element(id); jQuery('#'+id).remove(); }
                    reset_action_menu_icons();
                    jQuery(link).find('IMG').attr('src', oldSrc);
                    if(callback) { callback(data); }
                },
                error: function(jqXHR, textStatus, errorThrown) {
                    thruk_message(1, 'server action failed: '+ textStatus, config.close_timeout);
                    if(id) { remove_close_element(id); jQuery('#'+id).remove();  }
                    reset_action_menu_icons();
                    jQuery(link).find('IMG').attr('src', oldSrc);
                }
            });
            return(false);
        });
    }
    // normal urls
    else {
        if(!link.href.match(/\$/)) {
            // no macros, no problems
            return;
        }
        jQuery(link).bind("mouseover", function() {
            if(!link.href.match(/\$/)) {
                // no macros, no problems
                return(true);
            }
            if(link.href.match(/^javascript:/)) {
                // skip javascript links, they will be replace on click
                return(true);
            }
            var href;
            if(link.hasAttribute('orighref')) {
                href = link.getAttribute('orighref');
            } else {
                link.setAttribute('orighref', ""+link.href);
                href = link.getAttribute('href');
            }
            var urlArgs = {
                forward:        1,
                replacemacros:  1,
                host:           host,
                service:        service,
                backend:        backend,
                data:           href
            };
            link.setAttribute('href', url_prefix + 'cgi-bin/status.cgi?'+toQueryString(urlArgs));
            return(true);
        });
        jQuery(link).bind("click", function() {
            if(!link.href.match(/\$/)) {
                // no macros, no problems
                return(true);
            }
            if(!link.href.match(/^javascript:/)) {
                return(true);
            }
            var href;
            if(link.hasAttribute('orighref')) {
                href = link.getAttribute('orighref');
            } else {
                link.setAttribute('orighref', ""+link.href);
                href = link.getAttribute('href');
            }
            jQuery.ajax({
                url: url_prefix + 'cgi-bin/status.cgi?replacemacros=1',
                data: {
                    host:    host,
                    service: service,
                    backend: backend,
                    data:    href,
                    token:   user_token
                },
                type: 'POST',
                success: function(data) {
                    if(data.rc != 0) {
                        thruk_message(1, 'could not replace macros: '+ data.data);
                    } else {
                        link.href = data.data
                        link.click();
                        link.href = link.getAttribute('orighref');
                    }
                },
                error: function(jqXHR, textStatus, errorThrown) {
                    thruk_message(1, 'could not replace macros: '+ textStatus);
                }
            });
            return(false);
        });
    }
}

/* replace common macros */
function replace_macros(input, macros) {
    var out = input;
    if(out == undefined) {
        return(out);
    }
    if(macros != undefined) {
        for(var key in macros) {
            var regex  = new RegExp('\{\{'+key+'\}\}', 'g');
            out = out.replace(regex, macros[key]);
        }
        return(out);
    }

    out = out.replace(/\{\{\s*theme\s*\}\}/g, theme);
    out = out.replace(/\{\{\s*remote_user\s*\}\}/g, remote_user);
    out = out.replace(/\{\{\s*site\s*\}\}/g, omd_site);
    out = out.replace(/\{\{\s*prefix\s*\}\}/g, url_prefix);
    return(out);
}

/* remove active class from action menu icons */
function reset_action_menu_icons() {
    jQuery('IMG.action_icon').removeClass('active');
}

/*******************************************************************************
 * 88888888ba  88888888888 88888888ba  88888888888 88888888ba,        db   888888888888   db
 * 88      "8b 88          88      "8b 88          88      `"8b      d88b       88       d88b
 * 88      ,8P 88          88      ,8P 88          88        `8b    d8'`8b      88      d8'`8b
 * 88aaaaaa8P' 88aaaaa     88aaaaaa8P' 88aaaaa     88         88   d8'  `8b     88     d8'  `8b
 * 88""""""'   88"""""     88""""88'   88"""""     88         88  d8YaaaaY8b    88    d8YaaaaY8b
 * 88          88          88    `8b   88          88         8P d8""""""""8b   88   d8""""""""8b
 * 88          88          88     `8b  88          88      .a8P d8'        `8b  88  d8'        `8b
 * 88          88888888888 88      `8b 88          88888888Y"' d8'          `8b 88 d8'          `8b
*******************************************************************************/
function parse_perf_data(perfdata) {
    var matches   = String(perfdata).match(/([^\s]+|'[^']+')=([^\s]*)/gi);
    var perf_data = [];
    if(!matches) { return([]); }
    for(var nr=0; nr<matches.length; nr++) {
        try {
            var tmp = matches[nr].split(/=/);
            tmp[1] += ';;;;';
            tmp[1]  = tmp[1].replace(/,/g, '.');
            tmp[1]  = tmp[1].replace(/;U;/g, '');
            tmp[1]  = tmp[1].replace(/;U$/g, '');
            var data = tmp[1].match(
                /^(-?\d+(\.\d+)?)([^;]*);(((-?\d+|\d*)(\.\d+)?:)|~:)?((-?\d+|\d*)(\.\d+)?)?;(((-?\d+|\d*)(\.\d+)?:)|~:)?((-?\d+|\d*)(\.\d+)?)?;((-?\d+|\d*)(\.\d+)?)?;((-?\d+|\d*)(\.\d+)?)?;*$/
            );
            data[4]  = (data[4]  != null) ? data[4].replace(/~?:/, '')  : '';
            data[11] = (data[11] != null) ? data[11].replace(/~?:/, '') : '';
            if(tmp[0]) {
                tmp[0]   = tmp[0].replace(/^'/, '');
                tmp[0]   = tmp[0].replace(/'$/, '');
            }
            var d = {
                key:      tmp[0],
                perf:     tmp[1],
                val:      (data[1]  != null && data[1]  != '') ? parseFloat(data[1])  : '',
                unit:      data[3]  != null  ? data[3]  :  '',
                warn_min: (data[4]  != null && data[4]  != '') ? parseFloat(data[4])  : '',
                warn_max: (data[8]  != null && data[8]  != '') ? parseFloat(data[8])  : '',
                crit_min: (data[11] != null && data[11] != '') ? parseFloat(data[11]) : '',
                crit_max: (data[15] != null && data[15] != '') ? parseFloat(data[15]) : '',
                min:      (data[18] != null && data[18] != '') ? parseFloat(data[18]) : '',
                max:      (data[21] != null && data[21] != '') ? parseFloat(data[21]) : ''
            };
            perf_data.push(d);
        } catch(el) {}
    }
    return(perf_data);
}

/* write/return table with performance data */
function perf_table(write, state, plugin_output, perfdata, check_command, pnp_url, is_host, no_title) {
    if(is_host == undefined) { is_host = false; }
    if(is_host && state == 1) { state = 2; } // set critical state for host checks
    var perf_data = parse_perf_data(perfdata);
    var cls       = 'notclickable';
    var result    = '';
    if(perf_data.length == 0) { return false; }
    if(pnp_url != '') {
        cls = 'clickable';
    }
    var res = perf_parse_data(check_command, state, plugin_output, perf_data);
    if(res != null) {
        res = res.reverse();
        for(var nr=0; nr<res.length; nr++) {
            if(res[nr] != undefined) {
                var graph = res[nr];
                result += '<div class="perf_bar_bg '+cls+'" style="width:'+graph.div_width+'px;" '+(no_title ? '' : 'title="'+graph.title+'"')+'>';
                if(graph.warn_width_min != null) {
                    result += '<div class="perf_bar_warn '+cls+'" style="width:'+graph.warn_width_min+'px;">&nbsp;<\/div>';
                }
                if(graph.crit_width_min != null) {
                    result += '<div class="perf_bar_crit '+cls+'" style="width:'+graph.crit_width_min+'px;">&nbsp;<\/div>';
                }
                if(graph.warn_width_max != null) {
                    result += '<div class="perf_bar_warn '+cls+'" style="width:'+graph.warn_width_max+'px;">&nbsp;<\/div>';
                }
                if(graph.crit_width_max != null) {
                    result += '<div class="perf_bar_crit '+cls+'" style="width:'+graph.crit_width_max+'px;">&nbsp;<\/div>';
                }
                result += '<img class="perf_bar" src="' + url_prefix + 'themes/' +  theme + '/images/' + graph.pic + '" style="width:'+ graph.img_width +'px;" '+(no_title ? '' : 'title="'+graph.title+'"')+'>';
                result += '<\/div>';
            }
        }
    }
    if(write) {
        if(result != '' && pnp_url != '') {
            var rel_url = pnp_url.replace('\/graph\?', '/popup?');
            if(perf_bar_pnp_popup == 1) {
                document.write("<a href='"+pnp_url+"' class='tips' rel='"+rel_url+"'>");
            } else {
                document.write("<a href='"+pnp_url+"'>");
            }
        }
        document.write(result);
        if(result != '' && pnp_url != '') {
            document.write("<\/a>");
        }
    }
    return result;
}

/* figures out where warning/critical values should go
 * on the perfbars
 */
function plot_point(value, max, size) {
    return(Math.round((Math.abs(value) / max * 100) / 100 * size));
}

/* return human readable perfdata */
function perf_parse_data(check_command, state, plugin_output, perfdata) {
    var size   = 75;
    var result = [];
    var worst_graphs = {};
    for(var nr=0; nr<perfdata.length; nr++) {
        var d = perfdata[nr];
        if(d.max  == '' && d.unit == '%')     { d.max = 100;        }
        if(d.max  == '' && d.crit_max != '')  { d.max = d.crit_max; }
        if(d.max  == '' && d.warn_max != '')  { d.max = d.warn_max; }
        if(d.val !== '' && d.max  !== '')  {
            var perc       = (Math.abs(d.val) / (d.max-d.min) * 100).toFixed(2);
            if(perc < 5)   { perc = 5;   }
            if(perc > 100) { perc = 100; }
            var pic = 'thermok.png';
            if(state == 1) { var pic = 'thermwarn.png'; }
            if(state == 2) { var pic = 'thermcrit.png'; }
            if(state == 4) { var pic = 'thermgrey.png'; }
            perc = Math.round(perc / 100 * size);
            var warn_perc_min = null;
            if(d.warn_min != '' && d.warn_min > d.min) {
                warn_perc_min = plot_point(d.warn_min, d.max, size);
                if(warn_perc_min == 0) {warn_perc_min = null;}
            }
            var crit_perc_min = null;
            if(d.crit_min != '' && d.crit_min > d.min) {
                crit_perc_min = plot_point(d.crit_min, d.max, size)
                if(crit_perc_min == 0) {crit_perc_min = null;}
                if(crit_perc_min == warn_perc_min) {warn_perc_min = null;}
            }
            var warn_perc_max = null;
            if(d.warn_max != '' && d.warn_max < d.max) {
                warn_perc_max = plot_point(d.warn_max, d.max, size);
                if(warn_perc_max == size) {warn_perc_max = null;}
            }
            var crit_perc_max = null;
            if(d.crit_max != '' && d.crit_max < d.max) {
                crit_perc_max = plot_point(d.crit_max, d.max, size)
                if(crit_perc_max == size) {crit_perc_max = null;}
                if(crit_perc_max == warn_perc_max) {warn_perc_max = null;}
            }
            var graph = {
                title:          d.key + ': ' + perf_reduce(d.val, d.unit) + ' of ' + perf_reduce(d.max, d.unit),
                div_width:      size,
                img_width:      perc,
                pic:            pic,
                field:          d.key,
                val:            d.val,
                warn_width_min: warn_perc_min,
                crit_width_min: crit_perc_min,
                warn_width_max: warn_perc_max,
                crit_width_max: crit_perc_max
            };
            if(worst_graphs[state] == undefined) { worst_graphs[state] = {}; }
            worst_graphs[state][perc] = graph;
            result.push(graph);
        }
    }

    var local_perf_bar_mode = custom_perf_bar_adjustments(perf_bar_mode, result, check_command, state, plugin_output, perfdata);

    if(local_perf_bar_mode == 'worst') {
        if(keys(worst_graphs).length == 0) { return([]); }
        var sortedkeys   = keys(worst_graphs).sort(compareNumeric).reverse();
        var sortedgraphs = keys(worst_graphs[sortedkeys[0]]).sort(compareNumeric).reverse();
        return([worst_graphs[sortedkeys[0]][sortedgraphs[0]]]);
    }
    if(local_perf_bar_mode == 'match') {
        // some hardcoded relations
        if(check_command == 'check_mk-cpu.loads') { return(perf_get_graph_from_result('load15', result)); }
        var matches = plugin_output.match(/([\d\.]+)/g);
        if(matches != null) {
            for(var nr=0; nr<matches.length; nr++) {
                var val = matches[nr];
                for(var nr2=0; nr2<result.length; nr2++) {
                    if(result[nr2].val == val) {
                        return([result[nr2]]);
                    }
                }
            }
        }
        // nothing matched, use first
        local_perf_bar_mode = 'first';
    }
    if(local_perf_bar_mode == 'first') {
        return([result[0]]);
    }
    return result;
}

/* try to get only a specific key form our result */
function perf_get_graph_from_result(key, result) {
    for(var nr=0; nr<result.length; nr++) {
        if(result[nr].field == key) {
            return([result[nr]]);
        }
    }
    return(result);
}

/* try to make a smaller number */
function perf_reduce(value, unit) {
    if(value < 1000) { return(''+perf_round(value)+unit); }
    if(value > 1500 && unit == 'B') {
        value = value / 1000;
        unit  = 'KB';
    }
    if(value > 1500 && unit == 'KB') {
        value = value / 1000;
        unit  = 'MB';
    }
    if(value > 1500 && unit == 'MB') {
        value = value / 1000;
        unit  = 'GB';
    }
    if(value > 1500 && unit == 'GB') {
        value = value / 1000;
        unit  = 'TB';
    }
    if(value > 1500 && unit == 'ms') {
        value = value / 1000;
        unit  = 's';
    }
    return(''+perf_round(value)+unit);
}

/* round value to human readable */
function perf_round(value) {
    if((value - parseInt(value)) == 0) { return(value); }
    if(value >= 100) { return(value.toFixed(0)); }
    if(value < 100)  { return(value.toFixed(1)); }
    if(value <  10)  { return(value.toFixed(2)); }
    return(value);
}

/*******************************************************************************
  ,ad8888ba,  88b           d88 88888888ba,
 d8"'    `"8b 888b         d888 88      `"8b
d8'           88`8b       d8'88 88        `8b
88            88 `8b     d8' 88 88         88
88            88  `8b   d8'  88 88         88
Y8,           88   `8b d8'   88 88         8P
 Y8a.    .a8P 88    `888'    88 88      .a8P
  `"Y8888Y"'  88     `8'     88 88888888Y"'

 Mouse Over for Status Table
 to select hosts / services
 for sending quick commands
*******************************************************************************/
var selectedServices = new Object();
var selectedHosts    = new Object();
var noEventsForId    = new Object();
var submit_form_id;
var pagetype         = undefined;

/* add mouseover eventhandler for all cells and execute it once */
function addRowSelector(id, type) {
    var row   = document.getElementById(id);
    var cells = row.cells;

    // remove this eventhandler, it has to fire only once
    if(noEventsForId[id]) {
        return false;
    }
    if( row.detachEvent ) {
        noEventsForId[id] = 1;
    } else {
        row.onmouseover = undefined;
    }

    // reset all current highlighted rows
    reset_all_hosts_and_services();

    if(type == 'host') {
      pagetype = 'hostdetail'
    }
    else if(type == 'service') {
      pagetype = 'servicedetail'
    } else {
      if(thruk_debug_js) { alert("ERROR: unknown table addRowSelector(): " + typ); }
    }

    // for each cell in a row
    var is_host = false;
    for(var cell_nr = 0; cell_nr < cells.length; cell_nr++) {
        if(pagetype == "hostdetail" || (cell_nr == 0 && cells[0].innerHTML != '')) {
            is_host = true;
            if(pagetype == 'hostdetail') {
                addEvent(cells[cell_nr], 'mouseover', set_pagetype_hostdetail);
            } else {
                addEvent(cells[cell_nr], 'mouseover', set_pagetype_servicedetail);
            }
            addEventHandler(cells[cell_nr], 'host');
        }
        else if(cell_nr >= 1) {
            is_host = false;
            addEvent(cells[cell_nr], 'mouseover', set_pagetype_servicedetail);
            addEventHandler(cells[cell_nr], 'service');
        }
    }

    // initial mouseover highlights host&service, reset class here
    if(pagetype == "servicedetail") {
        reset_all_hosts_and_services(true, false);
    }

    if(is_host) {
        //addEvent(row, 'mouseout', resetHostRow);
        appendRowStyle(id, 'tableRowHover', 'host');
    } else {
        //addEvent(row, 'mouseout', resetServiceRow);
        appendRowStyle(id, 'tableRowHover', 'service');
    }
    return true;
}

/* reset all current hosts and service rows */
function reset_all_hosts_and_services(hosts, services) {
    var rows = Array();
    jQuery('td.tableRowHover').each(function(i, el) {
        rows.push(el.parentNode);
    });

    jQuery.unique(rows);
    jQuery(rows).each(function(i, el) {
        resetHostRow(el);
        resetServiceRow(el);
    });
}

/* set right pagetype */
function set_pagetype_hostdetail() {
    pagetype = "hostdetail";
}
function set_pagetype_servicedetail() {
    pagetype = "servicedetail";
}

/* add the event handler */
function addEventHandler(elem, type) {
    if(type == 'host') {
        addEvent(elem, 'mouseover', highlightHostRow);
        if(!elem.onclick) {
            elem.onclick = selectHost;
        }
    }
    if(type == 'service') {
        addEvent(elem, 'mouseover', highlightServiceRow);
        if(!elem.onclick) {
            elem.onclick = selectService;
        }
    }
}

/* add additional eventhandler to object */
function addEvent( obj, type, fn ) {
  //debug("addEvent("+obj+","+type+", ...)");
  if ( obj.attachEvent ) {
    obj['e'+type+fn] = fn;
    obj[type+fn] = function(){obj['e'+type+fn]( window.event );}
    obj.attachEvent( 'on'+type, obj[type+fn] );
  } else
    obj.addEventListener( type, fn, false );
}

/* remove an eventhandler from object */
function removeEvent( obj, type, fn ) {
  //debug("removeEvent("+obj+","+type+", ...)");
  if ( obj.detachEvent ) {
    obj.detachEvent( 'on'+type, obj[type+fn] );
    obj[type+fn] = null;
  } else
    obj.removeEventListener( type, fn, false );
}


/* returns the first element which has an id */
function getFirstParentId(elem) {
    if(!elem) {
        if(thruk_debug_js) { alert("ERROR: got no element in getFirstParentId()"); }
        return false;
    }
    nr = 0;
    while(nr < 10 && !elem.id) {
        nr++;
        if(!elem.parentNode) {
            // this may happen when looking for the parent of a event
            return false;
        }
        elem = elem.parentNode;
    }
    return elem.id;
}

/* set style for each cell */
function setRowStyle(row_id, style, type, force) {

    var row = document.getElementById(row_id);
    if(!row) {
        if(thruk_debug_js) { alert("ERROR: got no row in setRowStyle(): " + row_id); }
        return false;
    }

    // for each cells in this row
    var cells = row.cells;
    if(!cells) {
        return false;
    }
    for(var cell_nr = 0; cell_nr < cells.length; cell_nr++) {
        // only the first cell for hosts
        // all except the first cell for services
        if((type == 'host' && pagetype == 'hostdetail') || (type == 'host' && cell_nr == 0) || (type == 'service' && cell_nr >= 1)) {
            // set style for cell itself
            styleElements(cells[cell_nr], style, force)

            // and for all row elements below
            var elems = cells[cell_nr].getElementsByTagName('TR');
            styleElements(elems, style, force)

            // and for all cell elements below
            var elems = cells[cell_nr].getElementsByTagName('TD');
            styleElements(elems, style, force)
        }
    }
    return true;
}

/* set style for each cell */
function appendRowStyle(row_id, style, type, recursive) {
    var row = document.getElementById(row_id);
    if(!row) {
        if(thruk_debug_js) { alert("ERROR: got no row in appendRowStyle(): " + row_id); }
        return false;
    }
    // for each cells in this row
    var cells = row.cells;
    if(!cells) {
        return false;
    }
    if(recursive == undefined) { recursive = false; }
    for(var cell_nr = 0; cell_nr < cells.length; cell_nr++) {
        // only the first cell for hosts
        // all except the first cell for services
        if((type == 'host' && pagetype == 'hostdetail') || (type == 'host' && cell_nr == 0) || (type == 'service' && cell_nr >= 1)) {
            // set style for cell itself
            addStyle(cells[cell_nr], style)

            if(recursive) {
                // and for all row elements below
                var elems = cells[cell_nr].getElementsByTagName('TR');
                addStyle(elems, style)

                // and for all cell elements below
                var elems = cells[cell_nr].getElementsByTagName('TD');
                addStyle(elems, style)
            }
        }
    }
    return true;
}

/* remove style for each cell */
function removeRowStyle(row_id, styles, type) {

    var row = document.getElementById(row_id);
    if(!row) {
        if(thruk_debug_js) { alert("ERROR: got no row in appendRowStyle(): " + row_id); }
        return false;
    }
    // for each cells in this row
    var cells = row.cells;
    if(!cells) {
        return false;
    }
    for(var cell_nr = 0; cell_nr < cells.length; cell_nr++) {
        // only the first cell for hosts
        // all except the first cell for services
        if((type == 'host' && pagetype == 'hostdetail') || (type == 'host' && cell_nr == 0) || (type == 'service' && cell_nr >= 1)) {
            // set style for cell itself
            removeStyle(cells[cell_nr], styles)

            // and for all row elements below
            var elems = cells[cell_nr].getElementsByTagName('TR');
            removeStyle(elems, styles)

            // and for all cell elements below
            var elems = cells[cell_nr].getElementsByTagName('TD');
            removeStyle(elems, styles)
        }
    }
    return true;
}

/* add style to given element(s) */
function addStyle(elems, style) {
    if (elems == null || ( typeof(elems) != "object" && typeof(elems) != "function" ) || typeof(elems.length) != "number") {
        elems = new Array(elems);
    }
    jQuery.each(elems, function(nr, el) {
        jQuery(el).addClass(style);
    });
    return;
}

/* remove style to given element(s) */
function removeStyle(elems, styles) {
    if (elems == null || ( typeof(elems) != "object" && typeof(elems) != "function" ) || typeof(elems.length) != "number") {
        elems = new Array(elems);
    }
    jQuery.each(elems, function(nr, el) {
        jQuery.each(styles, function(nr, s) {
            jQuery(el).removeClass(s);
        });
    });
    return;
}

/* save current style and change it*/
function styleElements(elems, style, force) {
    if (elems == null ) {
        return;
    }
    if (( typeof(elems) != "object" && typeof(elems) != "function" ) || typeof(elems.length) != "number") {
        elems = new Array(elems);
    }

    if(navigator.appName == "Microsoft Internet Explorer") {
        return styleElementsIE(elems, style, force);
    }
    else {
        return styleElementsFF(elems, style, force);
    }
}

/* save current style and change it (IE only) */
function styleElementsIE(elems, style, force) {
    for(var x = 0; x < elems.length; x++) {
        if(style == 'original') {
            // reset style to original
            if(elems[x].className != "tableRowSelected" || force) {
                if(elems[x].origclass != undefined) {
                    elems[x].className = elems[x].origclass;
                }
            }
        }
        else {
            if(elems[x].className != "tableRowSelected" || force) {
                // save style in custom attribute
                if(elems[x].className != undefined && elems[x].className != "tableRowSelected" && elems[x].className != "tableRowHover") {
                    elems[x].setAttribute('origclass', elems[x].className);
                }

                // set new style
                elems[x].className = style;
            }
        }
    }
}

/* save current style and change it (non IE version) */
function styleElementsFF(elems, style, force) {
    for(var x = 0; x < elems.length; x++) {
        if(style == 'original') {
            // reset style to original
            if(elems[x].hasAttribute('origClass') && (elems[x].className == "tableRowHover" || force)) {
                elems[x].className = elems[x].origClass;
            }
        }
        else {
            if(elems[x].className != "tableRowSelected" || force) {
                // save style in custom attribute
                if(!elems[x].hasAttribute('origClass')) {
                    elems[x].setAttribute('origClass', elems[x].className);
                    elems[x].origClass = elems[x].className;
                }

                // set new style
                elems[x].className = style;
            }
        }
    }
}

/* this is the mouseover function for services */
function highlightServiceRow() {
    // find id of current row
    var row_id = getFirstParentId(this);
    if(!row_id) {
      return;
    }

    // reset all current highlighted rows
    reset_all_hosts_and_services();

    lastRowHighlighted = row_id;
    appendRowStyle(row_id, 'tableRowHover', 'service');
}

/* this is the mouseover function for hosts */
function highlightHostRow() {
    // find id of current row
    var row_id = getFirstParentId(this);
    if(!row_id) {
      return;
    }

    // reset all current highlighted rows
    reset_all_hosts_and_services();

    lastRowHighlighted = row_id;
    appendRowStyle(row_id, 'tableRowHover', 'host');
}

/* select this service */
function selectService(event, state) {
    var t = getTextSelection();
    var l = t.split(/\r?\n|\r/).length;
    if(t != '' && l == 1) {
        /* make text selections easier */
        return;
    }

    unselectCurrentSelection();
    var row_id;
    // find id of current row
    if(event && event.target) {
        /* ex.: FF */
        row_id = getFirstParentId(event.target);

        // dont select row when clicked on a link
        if(event.target.tagName == 'A' || event.target.tagName == 'IMG') {
            resetServiceRow(event);
            return;
        }
    }
    else if (event && (event.id || event.parentNode)) {
        row_id = getFirstParentId(event);
    }
    else {
        /* ex.: IE 7/8 */
        if(window.event.srcElement.tagName == 'A' || window.event.srcElement.tagName == 'IMG') {
            resetServiceRow(event);
            return;
        }
        row_id = getFirstParentId(this);
        event  = this;
    }
    if(!row_id) {
        return;
    }

    selectServiceByIdEvent(row_id, state, event);
    unselectCurrentSelection();
}

/* select this service */
function selectServiceByIdEvent(row_id, state, event) {
    row_id = row_id.replace(/_s_exec$/, '');

    if(is_shift_pressed(event) && lastRowSelected != undefined) {
      no_more_events = 1;
      var id1         = parseInt(row_id.substring(5));
      var id2         = parseInt(lastRowSelected.substring(5));
      var pane_prefix = row_id.substring(0,4);

      // all selected should get the same state
      state = false;
      if(selectedServices[lastRowSelected]) {
        state = true;
      }

      // selected top down?
      if(id1 > id2) {
        var tmp = id2;
        id2 = id1;
        id1 = tmp;
      }

      for(var x = id1; x < id2; x++) {
        selectServiceByIdEvent(pane_prefix+'r'+x, state);
      }
      lastRowSelected = undefined;
      no_more_events  = 0;
    }
    else {
      lastRowSelected = row_id;
    }

    selectServiceById(row_id, state);

    checkCmdPaneVisibility();
}

/* select service row by id */
function selectServiceById(row_id, state) {
    row_id = row_id.replace(/_s_exec$/, '');
    var targetState;
    if(state != undefined) {
        targetState = state;
    }
    else if(selectedServices[row_id]) {
        targetState = false;
    }
    else {
        targetState = true;
    }

    // dont select the empty cells in services view
    row = document.getElementById(row_id);
    if(!row) {
        return false;
    }

    if(targetState) {
        appendRowStyle(row_id, 'tableRowSelected', 'service', true);
        selectedServices[row_id] = 1;
    } else {
        removeRowStyle(row_id, ['tableRowSelected', 'tableRowHover'], 'service');
        delete selectedServices[row_id];
    }
    return true;
}

/* select this host */
function selectHost(event, state) {
    var t = getTextSelection();
    var l = t.split(/\r?\n|\r/).length;
    if(t != '' && l == 1) {
        /* make text selections easier */
        return;
    }
    unselectCurrentSelection();

    var row_id;
    // find id of current row
    if(event && event.target) {
        /* ex.: FF */
        row_id = getFirstParentId(event.target);

        // dont select row when clicked on a link
        if(event.target.tagName == 'A' || event.target.tagName == 'IMG') {
            resetHostRow(event);
            return;
        }
    }
    else if (event && (event.id || event.parentNode)) {
        row_id = getFirstParentId(event);
    }
    else {
        /* ex.: IE 7/8 */
        if(window.event.srcElement.tagName == 'A' || window.event.srcElement.tagName == 'IMG') {
            resetHostRow(event);
            return;
        }
        row_id = getFirstParentId(this);
        event  = this;
    }
    if(!row_id) {
        return;
    }

    selectHostByIdEvent(row_id, state, event);
    unselectCurrentSelection();
}


/* select this service */
function selectHostByIdEvent(row_id, state, event) {
    row_id = row_id.replace(/_h_exec$/, '');

    if(is_shift_pressed(event) && lastRowSelected != undefined) {
      no_more_events = 1;
      var id1         = parseInt(row_id.substring(5));
      var id2         = parseInt(lastRowSelected.substring(5));
      var pane_prefix = row_id.substring(0,4);

      // all selected should get the same state
      state = false;
      if(selectedHosts[lastRowSelected]) {
        state = true;
      }

      // selected top down?
      if(id1 > id2) {
        var tmp = id2;
        id2 = id1;
        id1 = tmp;
      }

      for(var x = id1; x < id2; x++) {
        selectHostByIdEvent(pane_prefix+'r'+x, state);
      }
      lastRowSelected = undefined;
      no_more_events  = 0;
    } else {
      lastRowSelected = row_id;
    }

    selectHostById(row_id, state);

    checkCmdPaneVisibility();
}

/* set host row selected */
function selectHostById(row_id, state) {
    row_id = row_id.replace(/_h_exec$/, '');
    var targetState;
    if(state != undefined) {
        targetState = state;
    }
    else if(selectedHosts[row_id]) {
        targetState = false;
    }
    else {
        targetState = true;
    }

    // dont select the empty cells in services view
    row = document.getElementById(row_id);
    if(!row || !row.cells || row.cells.length == 0) {
      return false;
    }
    if(row.cells[0].innerHTML == "") {
      return true;
    }

    if(targetState) {
        appendRowStyle(row_id, 'tableRowSelected', 'host', true);
        selectedHosts[row_id] = 1;
    } else {
        removeRowStyle(row_id, ['tableRowSelected', 'tableRowHover'], 'host');
        delete selectedHosts[row_id];
    }
    return true;
}


/* reset row style unless it has been clicked */
function resetServiceRow(event) {
    var row_id;
    if(!event) {
        event = this;
    }
    // find id of current row
    if(event.target) {
        row_id = getFirstParentId(event.target);
    } else {
        row_id = getFirstParentId(event);
    }
    if(!row_id) {
        if(lastRowHighlighted) {
            tmp = lastRowHighlighted;
            lastRowHighlighted = undefined;
            setRowStyle(tmp, 'original', 'service');
        }
        return;
    }
    removeRowStyle(row_id, ['tableRowHover'], 'service');
}

/* reset row style unless it has been clicked */
function resetHostRow(event) {
    var row_id;
    if(!event) {
        event = this;
    }
    // find id of current row
    if(event.target) {
        row_id = getFirstParentId(event.target);
    } else {
        row_id = getFirstParentId(event);
    }
    if(!row_id) {
        if(lastRowHighlighted) {
            tmp = lastRowHighlighted;
            lastRowHighlighted = undefined;
            setRowStyle(tmp, 'original', 'host');
        }
        return;
    }
    removeRowStyle(row_id, ['tableRowHover'], 'host');
}

/* select or deselect all services */
function selectAllServices(state, pane_prefix) {
    var x = 0;
    while(selectServiceById(pane_prefix+'r'+x, state)) {
        // disable next row
        x++;
    };

    checkCmdPaneVisibility();
}
/* select services by class name */
function selectServicesByClass(classes) {
    jQuery.each(classes, function(i, classname) {
        jQuery(classname).each(function(i, obj) {
            selectService(obj, true);
        })
    });
    return false;
}

/* select hosts by class name */
function selectHostsByClass(classes) {
    jQuery.each(classes, function(i, classname) {
        jQuery(classname).each(function(i, obj) {
            selectHost(obj, true);
        })
    });
    return false;
}

/* select or deselect all hosts */
function selectAllHosts(state, pane_prefix) {
    var x = 0;
    while(selectHostById(pane_prefix+'r'+x, state)) {
        // disable next row
        x++;
    };

    checkCmdPaneVisibility();
}

/* toggle the visibility of the command pane */
function toggleCmdPane(state) {
  if(state == 1) {
    showElement('cmd_pane');
    cmdPaneState = 1;
  }
  else {
    hideElement('cmd_pane');
    cmdPaneState = 0;
  }
}

/* show command panel if there are services or hosts selected otherwise hide the panel */
function checkCmdPaneVisibility() {
    var ssize = keys(selectedServices).length;
    var hsize = keys(selectedHosts).length;
    var size  = ssize + hsize;
    if(size == 0) {
        /* hide command panel */
        toggleCmdPane(0);
    } else {
        resetRefresh();

        /* set submit button text */
        var btn = document.getElementById('multi_cmd_submit_button');
        var serviceName = "services";
        if(ssize == 1) { serviceName = "service";  }
        var hostName = "hosts";
        if(hsize == 1) { hostName = "host";  }
        var text;
        if( hsize > 0 && ssize > 0 ) {
            text = ssize + " " + serviceName + " and " + hsize + " " + hostName;
        }
        else if( hsize > 0 ) {
            text = hsize + " " + hostName;
        }
        else if( ssize > 0 ) {
            text = ssize + " " + serviceName;
        }
        btn.value = "submit command for " + text;
        check_selected_command();

        /* show command panel */
        toggleCmdPane(1);
    }
}

/* collect selected hosts and services and pack them into nice form data */
function collectFormData(form_id) {

    if(verification_errors != undefined && keys(verification_errors).length > 0) {
        alert('please enter valid data');
        return(false);
    }

    // set activity icon
    check_quick_command();

    // check form values
    var sel = document.getElementById('quick_command');
    var value = sel.value;
    if(value == 2 || value == 3 || value == 4) { /* add downtime / comment / acknowledge */
        if(document.getElementById('com_data').value == '') {
            alert('please enter a comment');
            return(false);
        }
    }

    if(value == 12) { /* submit passive result */
        if(document.getElementById('plugin_output').value == '') {
            alert('please enter a check result');
            return(false);
        }
    }

    ids_form = document.getElementById('selected_ids');
    if(ids_form) {
        // comments / downtime commands
        ids_form.value = keys(selectedHosts).join(',');
    }
    else {
        // regular services commands
        var services = new Array();
        jQuery.each(selectedServices, function(row_id, blah) {
            if(row_id.substr(0,4) == "hst_") { obj_hash = hst_Hash; }
            if(row_id.substr(0,4) == "svc_") { obj_hash = svc_Hash; }
            if(row_id.substr(0,4) == "dfl_") { obj_hash = dfl_Hash; }
            row_id = row_id.substr(4);
            services.push(obj_hash[row_id]);
        });
        service_form = document.getElementById('selected_services');
        service_form.value = services.join(',');

        var hosts = new Array();
        jQuery.each(selectedHosts, function(row_id, blah) {
            if(row_id.substr(0,4) == "hst_") { obj_hash = hst_Hash; }
            if(row_id.substr(0,4) == "svc_") { obj_hash = svc_Hash; }
            if(row_id.substr(0,4) == "dfl_") { obj_hash = dfl_Hash; }
            row_id = row_id.substr(4);
            hosts.push(obj_hash[row_id]);
        });
        host_form = document.getElementById('selected_hosts');
        host_form.value = hosts.join(',');
    }

    // save scroll position to referer
    var form_ref = document.getElementById('form_cmd_referer');
    if(form_ref) {
        form_ref.value += '&scrollTo=' + getPageScroll();
    }

    if(value == 1 ) { // reschedule
        var btn = document.getElementById(form_id);
        if(btn) {
            submit_form_id = form_id;
            window.setTimeout(submit_form, 100);
            return(false);
        }
    }

    return(true);
}

/* return scroll position */
function getPageScroll() {
    var yScroll;
    if (self.pageYOffset) {
        yScroll = self.pageYOffset;
    } else if (document.documentElement && document.documentElement.scrollTop) {
        yScroll = document.documentElement.scrollTop;
    } else if (document.body) {
        yScroll = document.body.scrollTop;
    }
    return Number(yScroll).toFixed(0);
}

/* submit a form by id */
function submit_form() {
    var btn = document.getElementById(submit_form_id);
    btn.submit();
}

/* show/hide options for commands based on the selected command*/
function check_selected_command() {
    var sel = document.getElementById('quick_command');
    var value = sel.value;

    disableAllFormElement();
    if(value == 1) { /* reschedule next check */
        enableFormElement('row_start');
        enableFormElement('row_reschedule_options');
    }
    if(value == 2) { /* add downtime */
        enableFormElement('row_start');
        enableFormElement('row_end');
        enableFormElement('row_comment');
        enableFormElement('row_downtime_options');
    }
    if(value == 3) { /* add comment */
        enableFormElement('row_comment');
        enableFormElement('row_comment_options');
        document.getElementById('opt_persistent').value = 'comments';
    }
    if(value == 4) { /* add acknowledgement */
        enableFormElement('row_comment');
        enableFormElement('row_ack_options');
        document.getElementById('opt_persistent').value = 'ack';
        if(has_expire_acks) {
            enableFormElement('opt_expire');
            if(document.getElementById('opt5').checked == true) {
                enableFormElement('row_expire');
            }
        }
    }
    if(value == 5) { /* remove downtimes */
        enableFormElement('row_down_options');
    }
    if(value == 6) { /* remove comments */
    }
    if(value == 7) { /* remove acknowledgement */
    }
    if(value == 8) { /* enable active checks */
    }
    if(value == 9) { /* disable active checks */
        enableFormElement('row_comment_disable_cmd');
    }
    if(value == 10) { /* enable notifications */
    }
    if(value == 11) { /* disable notifications */
        enableFormElement('row_comment_disable_cmd');
    }
    if(value == 12) { /* submit passive check result */
        enableFormElement('row_submit_options');
    }
}

/* hide all form element rows */
function disableAllFormElement() {
    var elems = new Array('row_start', 'row_end', 'row_comment', 'row_comment_disable_cmd', 'row_downtime_options', 'row_reschedule_options', 'row_ack_options', 'row_comment_options', 'row_submit_options', 'row_expire', 'opt_expire', 'row_down_options');
    jQuery.each(elems, function(index, id) {
        obj = document.getElementById(id);
        obj.style.display = "none";
    });
}

/* show this form row */
function enableFormElement(id) {
    obj = document.getElementById(id);
    obj.style.display = "";
}


/* verify submited command */
function check_quick_command() {
    var sel   = document.getElementById('quick_command');
    var value = sel.value;
    var img;

    // disable hide timer
    window.clearTimeout(hide_activity_icons_timer);

    if(value == 1 ) { // reschedule
        jQuery.each(selectedServices, function(row_id, blah) {
            var cell = document.getElementById(row_id + "_s_exec");
            if(cell) {
                cell.innerHTML = '';
                img            = document.createElement('img');
                img.src        = url_prefix + 'themes/' + theme + '/images/waiting.gif';
                img.height     = 20;
                img.width      = 20;
                img.title      = "This service is currently executing its servicecheck";
                img.alt        = "This service is currently executing its servicecheck";
                cell.appendChild(img);
            }
        });
        jQuery.each(selectedHosts, function(row_id, blah) {
            var cell = document.getElementById(row_id + "_h_exec");
            if(cell) {
                cell.innerHTML = '';
                img            = document.createElement('img');
                img.src        = url_prefix + 'themes/' + theme + '/images/waiting.gif';
                img.height     = 20;
                img.width      = 20;
                img.title      = "This host is currently executing its hostcheck";
                img.alt        = "This host is currently executing its hostcheck";
                cell.appendChild(img);
            }
        });
        var btn = document.getElementById('multi_cmd_submit_button');
        btn.value = "processing commands...";
    }

    return true;
}


/* select this service */
function toggle_comment(event) {
    var t = getTextSelection();
    var l = t.split(/\r?\n|\r/).length;
    if(t != '' && l == 1) {
        /* make text selections easier */
        return false;
    }

    if(!event) {
        event = this;
    }
    if(event && event.target) {
        // dont select row when clicked on a link
        if(event.target.tagName == 'A' || event.target.tagName == 'IMG') {
            return true;
        }
    }

    // find id of current row
    if(event.target) {
        row_id = getFirstParentId(event.target);
    } else {
        row_id = getFirstParentId(event);
    }
    if(!row_id) {
        return false;
    }

    var state = true;
    if(selectedHosts[row_id]) {
        state = false;
    }

    if(is_shift_pressed(event) && lastRowSelected != undefined) {
        no_more_events = 1;

        // all selected should get the same state
        state = false;
        if(selectedHosts[lastRowSelected]) {
            state = true;
        }

        var inside = false;
        jQuery("TR.clickable").each(function(nr, elem) {
          if(! jQuery(elem).is(":visible")) {
            return true;
          }
          if(inside == true) {
            if(elem.id == lastRowSelected || elem.id == row_id) {
                return false;
            }
          }
          else {
            if(elem.id == lastRowSelected || elem.id == row_id) {
              inside = true;
            }
          }
          if(inside == true) {
            selectCommentById(elem.id, state);
          }
          return true;
        });

        // selectCommentById(pane_prefix+x, state);

        lastRowSelected = undefined;
        no_more_events  = 0;
    } else {
        lastRowSelected = row_id;
    }

    selectCommentById(row_id, state);

    // check visibility of command pane
    var number = keys(selectedHosts).length;
    var text = "remove " + number + " " + type;
    if(number != 1) {
        text = text + "s";
    }
    jQuery('#quick_command')[0].options[0].text = text;
    if(number > 0) {
        showElement('cmd_pane');
    } else {
        hideElement('cmd_pane');
    }

    unselectCurrentSelection();

    return false;
}

/* toggle selection of comment on downtimes/comments page */
function selectCommentById(row_id, state) {
    var row   = document.getElementById(row_id);
    if(!row) {
        if(thruk_debug_js) { alert("ERROR: unknown id in selectCommentById(): " + row_id); }
        return false;
    }
    var elems = row.getElementsByTagName('TD');

    if(state == false) {
        delete selectedHosts[row_id];
        styleElements(elems, "original", 1);
    } else {
        selectedHosts[row_id] = row_id;
        styleElements(elems, 'tableRowSelected', 1)
    }
    return false;
}

/* unselect all selections on downtimes/comments page */
function unset_comments() {
    jQuery.each(selectedHosts, function(nr, blah) {
        var row_id = selectedHosts[nr];
        var row    = document.getElementById(row_id);
        var elems  = row.getElementsByTagName('TD');
        styleElements(elems, "original", 1);
        delete selectedHosts[nr];
    });
    hideElement('cmd_pane');
}

/*******************************************************************************
88888888888  88   88     888888888888 88888888888 88888888ba
88           88   88          88      88          88      "8b
88           88   88          88      88          88      ,8P
88aaaaa      88   88          88      88aaaaa     88aaaaaa8P'
88"""""      88   88          88      88"""""     88""""88'
88           88   88          88      88          88    `8b
88           88   88          88      88          88     `8b
88           88   88888888888 88      88888888888 88      `8b

everything needed for displaying and changing filter
on status / host details page
*******************************************************************************/

/* toggle the visibility of the filter pane */
function toggleFilterPane(prefix) {
  //debug("toggleFilterPane(): " + toggleFilterPane.caller);
  var pane = document.getElementById(prefix+'all_filter_table');
  var img  = document.getElementById(prefix+'filter_button');
  if(pane.style.display == 'none') {
    showElement(prefix+'all_filter_table');
    img.style.display     = 'none';
    img.style.visibility  = 'hidden';
  }
  else {
    hideElement(prefix+'all_filter_table');
    img.style.display     = '';
    img.style.visibility  = 'visible';
  }
}

/* toggle filter pane */
function toggleFilterPaneSelector(search_prefix, id) {
  var panel;
  var checkbox_name;
  var input_name;
  var checkbox_prefix;

  search_prefix = search_prefix.substring(0, 7);

  if(id == "hoststatustypes") {
    panel           = 'hoststatustypes_pane';
    checkbox_name   = 'hoststatustype';
    input_name      = 'hoststatustypes';
    checkbox_prefix = 'ht';
  }
  if(id == "hostprops") {
    panel           = 'hostprops_pane';
    checkbox_name   = 'hostprop';
    input_name      = 'hostprops';
    checkbox_prefix = 'hp';
  }
  if(id == "servicestatustypes") {
    panel           = 'servicestatustypes_pane';
    checkbox_name   = 'servicestatustype';
    input_name      = 'servicestatustypes';
    checkbox_prefix = 'st';
  }
  if(id == "serviceprops") {
    panel           = 'serviceprops_pane';
    checkbox_name   = 'serviceprop';
    input_name      = 'serviceprops';
    checkbox_prefix = 'sp';
  }

  if(!panel) {
    if(thruk_debug_js) { alert("ERROR: unknown id in toggleFilterPaneSelector(): " + search_prefix + id); }
    return;
  }
  var accept_callback = function() { accept_filter_types(search_prefix, checkbox_name, input_name, checkbox_prefix)};
  if(!toggleElement(search_prefix+panel, undefined, true, undefined, accept_callback)) {
    accept_callback();
    remove_close_element(search_prefix+panel);
  } {
    set_filter_types(search_prefix, input_name, checkbox_prefix);
  }
}

/* calculate the sum for a filter */
function accept_filter_types(search_prefix, checkbox_names, result_name, checkbox_prefix) {
    var inp  = document.getElementsByName(search_prefix + result_name);
    if(!inp || inp.length == 0) {
      if(thruk_debug_js) { alert("ERROR: no element in accept_filter_types() for: " + search_prefix + result_name); }
      return;
    }
    var orig = inp[0].value;
    var sum = 0;
    jQuery("input[name="+search_prefix + checkbox_names+"]").each(function(index, elem) {
        if(elem.checked) {
            sum += parseInt(elem.value);
        }
    });
    inp[0].value = sum;

    set_filter_name(search_prefix, checkbox_names, checkbox_prefix, parseInt(sum));
}

/* set the initial state of filter checkboxes */
function set_filter_types(search_prefix, initial_id, checkbox_prefix) {
    var inp = document.getElementsByName(search_prefix + initial_id);
    if(!inp || inp.length == 0) {
      if(thruk_debug_js) { alert("ERROR: no element in set_filter_types() for: " + search_prefix + initial_id); }
      return;
    }
    var initial_value = parseInt(inp[0].value);
    var bin  = initial_value.toString(2);
    var bits = new Array(); bits = bin.split('').reverse();
    for (var index = 0, len = bits.length; index < len; ++index) {
        var bit = bits[index];
        var nr  = Math.pow(2, index);
        var checkbox = document.getElementById(search_prefix + checkbox_prefix + nr);
        if(!checkbox) {
          if(thruk_debug_js) { alert("ERROR: got no checkbox for id in set_filter_types(): " + search_prefix + checkbox_prefix + nr); }
          return;
        }
        if(bit == '1') {
            checkbox.checked = true;
        } else {
            checkbox.checked = false;
        }
    }
}

/* set the filtername */
function set_filter_name(search_prefix, checkbox_names, checkbox_prefix, filtervalue) {
  var order;
  if(checkbox_prefix == 'ht') {
    order = hoststatustypes;
  }
  else if(checkbox_prefix == 'hp') {
    order = hostprops;
  }
  else if(checkbox_prefix == 'st') {
    order = servicestatustypes;
  }
  else if(checkbox_prefix == 'sp') {
    order = serviceprops;
  }
  else {
    if(thruk_debug_js) { alert('ERROR: unknown prefix in set_filter_name(): ' + checkbox_prefix); }
  }

  var checked_ones = new Array();
  jQuery.each(order, function(index, bit) {
    checkbox = document.getElementById(search_prefix + checkbox_prefix + bit);
    if(!checkbox) {
        if(thruk_debug_js) { alert('ERROR: got no checkbox in set_filter_name(): ' + search_prefix + checkbox_prefix + bit); }
    }
    if(checkbox.checked) {
      nameElem = document.getElementById(search_prefix + checkbox_prefix + bit + 'n');
      if(!nameElem) {
        if(thruk_debug_js) { alert('ERROR: got no element in set_filter_name(): ' + search_prefix + checkbox_prefix + bit + 'n'); }
      }
      checked_ones.push(nameElem.innerHTML);
    }
  });

  /* some override names */
  if(checkbox_prefix == 'ht') {
    filtername = checked_ones.join(' | ');
    if(filtervalue == 0 || filtervalue == 15) {
      filtername = 'All';
    }
    if(filtervalue == 12) {
      filtername = 'All problems';
    }
  }

  if(checkbox_prefix == 'st') {
    filtername = checked_ones.join(' | ');
    if(filtervalue == 0 || filtervalue == 31) {
      filtername = 'All';
    }
    if(filtervalue == 28) {
      filtername = 'All problems';
    }
  }

  if(checkbox_prefix == 'hp') {
    filtername = checked_ones.join(' & ');
    if(filtervalue == 0) {
      filtername = 'Any';
    }
  }

  if(checkbox_prefix == 'sp') {
    filtername = checked_ones.join(' & ');
    if(filtervalue == 0) {
      filtername = 'Any';
    }
  }

  target = document.getElementById(search_prefix + checkbox_prefix + 'n');
  target.innerHTML = filtername;
}

function getFilterTypeOptions() {
    var important = new Array(/* when changed, update _status_filter.tt too! */
        'Search',
        'Host',
        'Service',
        'Hostgroup',
        'Servicegroup',
        '----------------'
    );
    var others = new Array(
        'Check Period',
        'Comment',
        'Contact',
        'Current Attempt',
        'Custom Variable',
        'Downtime Duration',
        'Duration',
        'Event Handler',
        'Execution Time',
        'Last Check',
        'Latency',
        'Next Check',
        'Notification Period',
        'Number of Services',
        'Parent',
        'Plugin Output',
        '% State Change'
       );
    if(enable_shinken_features) {
        others.unshift('Business Impact');
    }
    var options = Array();
    options = options.concat(important);
    options = options.concat(others.sort());
    return(options);
}

/* add a new filter selector to this table */
function add_new_filter(search_prefix, table) {
  pane_prefix   = search_prefix.substring(0,4);
  search_prefix = search_prefix.substring(4);
  var index     = search_prefix.indexOf('_');
  search_prefix = search_prefix.substring(0,index+1);
  table         = table.substring(4);
  tbl           = document.getElementById(pane_prefix+search_prefix+table);
  if(!tbl) {
    if(thruk_debug_js) { alert("ERROR: got no table for id in add_new_filter(): " + pane_prefix+search_prefix+table); }
    return;
  }

  // add new row
  var tblBody        = tbl.tBodies[0];
  var currentLastRow = tblBody.rows.length - 1;
  var newRow         = tblBody.insertRow(currentLastRow);

  // get first free number of typeselects
  var nr = 0;
  for(var x = 0; x<= 99; x++) {
    tst = document.getElementById(pane_prefix + search_prefix + x + '_ts');
    if(tst) { nr = x+1; }
  }

  // add first cell
  var typeselect = document.createElement('select');
  var options    = getFilterTypeOptions();

  typeselect.onchange   = verify_op;
  typeselect.setAttribute('name', pane_prefix + search_prefix + 'type');
  typeselect.setAttribute('id', pane_prefix + search_prefix + nr + '_ts');
  add_options(typeselect, options);

  var opselect          = document.createElement('select');
  var options           = new Array('~', '!~', '=', '!=', '<=', '>=');
  opselect.setAttribute('name', pane_prefix + search_prefix + 'op');
  opselect.setAttribute('id', pane_prefix + search_prefix + nr + '_to');
  opselect.className='filter_op_select';
  add_options(opselect, options);

  var newCell0 = newRow.insertCell(0);
  newCell0.nowrap    = "true";
  newCell0.className = "filterValueInput";
  newCell0.colSpan   = 2;
  newCell0.appendChild(typeselect);

  var newInputPre    = document.createElement('input');
  newInputPre.type      = 'text';
  newInputPre.value     = '';
  newInputPre.className = 'filter_pre_value';
  newInputPre.setAttribute('name', pane_prefix + search_prefix + 'val_pre');
  newInputPre.setAttribute('id',   pane_prefix + search_prefix + nr + '_val_pre');
  newInputPre.style.display    = "none";
  newInputPre.style.visibility = "hidden";
  if(ajax_search_enabled) {
    newInputPre.onclick = function() { ajax_search.init(this, 'custom variable') };
  }
  newCell0.appendChild(newInputPre);

  newCell0.appendChild(opselect);

  var newInput       = document.createElement('input');
  newInput.type      = 'text';
  newInput.value     = '';
  newInput.setAttribute('name', pane_prefix + search_prefix + 'value');
  newInput.setAttribute('id',   pane_prefix + search_prefix + nr + '_value');
  if(ajax_search_enabled) {
    newInput.onclick = ajax_search.init;
  }
  newCell0.appendChild(newInput);

  if(enable_shinken_features) {
    var newSelect      = document.createElement('select');
    newSelect.setAttribute('name', pane_prefix + search_prefix + 'value_sel');
    newSelect.setAttribute('id', pane_prefix + search_prefix + nr + '_value_sel');
    add_options(newSelect, priorities, 2);
    newSelect.style.display    = "none";
    newSelect.style.visibility = "hidden";
    newCell0.appendChild(newSelect);
  }

  var calImg = document.createElement('img');
  calImg.src = url_prefix + "themes/"+theme+"/images/calendar.png";
  calImg.className = "cal_icon";
  calImg.alt = "choose date";
  var link   = document.createElement('a');
  link.href  = "javascript:show_cal('" + pane_prefix + search_prefix + nr + "_value')";
  link.setAttribute('id', pane_prefix + search_prefix + nr + '_cal');
  link.style.display    = "none";
  link.style.visibility = "hidden";
  link.appendChild(calImg);
  newCell0.appendChild(link);

  // add second cell
  var img            = document.createElement('input');
  img.type           = 'image';
  img.src            = url_prefix + "themes/"+theme+"/images/remove.png";
  var newCell1       = newRow.insertCell(1);
  newCell1.onclick   = delete_filter_row;
  newCell1.className = "newfilter";
  newCell1.appendChild(img);

  // fill in values from last row
  lastnr=nr-1;
  var lastops = jQuery('#'+pane_prefix + search_prefix + lastnr + '_to');
  if(lastops.length > 0) {
      jQuery('#'+pane_prefix + search_prefix + nr + '_to')[0].selectedIndex    = jQuery('#'+pane_prefix + search_prefix + lastnr + '_to')[0].selectedIndex;
      jQuery('#'+pane_prefix + search_prefix + nr + '_ts')[0].selectedIndex    = jQuery('#'+pane_prefix + search_prefix + lastnr + '_ts')[0].selectedIndex;
      jQuery('#'+pane_prefix + search_prefix + nr + '_value')[0].value         = jQuery('#'+pane_prefix + search_prefix + lastnr + '_value')[0].value;
      jQuery('#'+pane_prefix + search_prefix + nr + '_val_pre')[0].value       = jQuery('#'+pane_prefix + search_prefix + lastnr + '_val_pre')[0].value;
  }
  verify_op(pane_prefix + search_prefix + nr + '_ts');
}

/* remove a row */
function delete_filter_row(event) {
  var row;
  if(event && event.target) {
    row = event.target;
  } else if(event) {
    row = event;
  } else {
    row = this;
  }
  /* find first table row */
  while(row.parentNode != undefined && row.tagName != 'TR') { row = row.parentNode; }
  row.parentNode.deleteRow(row.rowIndex);
  return false;
}

/* add options to a select
 * numbered:
 *   undef = value is lowercase text
 *   1     = value is numbered starting at 0
 *   2     = value is revese numbered
 */
function add_options(select, options, numbered) {
    var x = 0;
    if(numbered == 2) { x = options.length; }
    jQuery.each(options, function(index, text) {
        var opt  = document.createElement('option');
        opt.text = text;
        if(text.match(/^\-+$/)) {
            opt.disabled = true;
        }
        if(numbered) {
            opt.value = x;
        } else {
            opt.value = text.toLowerCase();
        }
        select.options[select.options.length] = opt;
        if(numbered == 2) {
            x--;
        } else {
            x++;
        }
    });
}

/* create a complete new filter pane */
function new_filter(cloneObj, parentObj, btnId) {
  pane_prefix       = btnId.substring(0,4);
  btnId             = btnId.substring(4);
  var index         = btnId.indexOf('_');
  var search_prefix = btnId.substring(0, index+1);
  cloneObj          = cloneObj.substring(4);
  var origObj       = document.getElementById(pane_prefix+search_prefix+cloneObj);
  if(!origObj) {
    if(thruk_debug_js) { alert("ERROR: no elem to clone in new_filter() for: " + pane_prefix + search_prefix + cloneObj); }
  }
  var newObj   = origObj.cloneNode(true);

  var new_prefix = 's' + (parseInt(search_prefix.substring(1)) + 1) + '_';

  // replace ids and names
  var tags = new Array('A', 'INPUT', 'TABLE', 'TR', 'TD', 'SELECT', 'INPUT', 'DIV', 'IMG');
  jQuery.each(tags, function(i, tag) {
      var elems = newObj.getElementsByTagName(tag);
      replaceIdAndNames(elems, pane_prefix+new_prefix);
  });

  // replace id of panel itself
  replaceIdAndNames(newObj, pane_prefix+new_prefix);

  var tblObj   = document.getElementById(parentObj);
  var tblBody  = tblObj.tBodies[0];
  var nextRow  = tblBody.rows.length - 1;
  var nextCell = tblBody.rows[nextRow].cells.length;
  if(nextCell > 2) {
    nextCell = 0;
    tblBody.insertRow(nextRow+1);
    nextRow++;
  }
  var newCell  = tblBody.rows[nextRow].insertCell(nextCell);
  newCell.setAttribute('valign', 'top');
  newCell.appendChild(newObj);

  // hide the original button
  hideElement(pane_prefix + btnId);
  hideBtn = document.getElementById(pane_prefix+new_prefix + 'filter_button_mini');
  if(hideBtn) { hideElement( hideBtn); }
  hideElement(pane_prefix + new_prefix + 'btn_accept_search');
  if(document.getElementById(pane_prefix + new_prefix + 'btn_columns')) {
    hideElement(pane_prefix + new_prefix + 'btn_columns');
  }
  showElement(pane_prefix + new_prefix + 'btn_del_search');

  hideBtn = document.getElementById(pane_prefix + new_prefix + 'filter_title');
  if(hideBtn) { hideElement(hideBtn); }

  styler = document.getElementById(pane_prefix + new_prefix + 'style_selector');
  if(styler) { styler.parentNode.removeChild(styler); }
}

/* replace ids and names for elements */
function replaceIdAndNames(elems, new_prefix) {
  if (elems == null || ( typeof(elems) != "object" && typeof(elems) != "function" ) || typeof(elems.length) != "number") {
    elems = new Array(elems);
  }
  for(var x = 0; x < elems.length; x++) {
    var elem = elems[x];
    if(elem.id) {
        var new_id = elem.id.replace(/^\w{3}_s\d+_/, new_prefix);
        elem.setAttribute('id', new_id);
    }
    if(elem.name) {
        var new_name = elem.name.replace(/^\w{3}_s\d+_/, new_prefix);
        elem.setAttribute('name', new_name);
    }

    if(ajax_search_enabled && elem.tagName == 'INPUT' && elem.type == 'text') {
      elem.onclick = ajax_search.init;
    }
  };
}

/* replace id and name of a object */
function replace_ids_and_names(elem, new_nr) {
    if(elem.id) {
        var new_id = elem.id.replace(/_\d+$/, '_'+new_nr);
        elem.setAttribute('id', new_id);
    }
    if(elem.name) {
        var new_name = elem.name.replace(/_\d+$/, '_'+new_nr);
        elem.setAttribute('name', new_name);
    }
    return elem
}

/* remove a search panel */
function deleteSearchPane(id) {
  pane_prefix   = id.substring(0,4);
  id            = id.substring(4);
  var index     = id.indexOf('_');
  search_prefix = id.substring(0,index+1);

  var pane  = document.getElementById(pane_prefix + search_prefix + 'filter_pane');
  var table = jQuery(pane.parentNode).parents('TABLE').first()[0];

  var cell = pane.parentNode;
  while(cell.firstChild) {
      child = cell.firstChild;
      cell.removeChild(child);
  }
  cell.parentNode.removeChild(cell);

  // show last "new search" button
  var last_nr = 0;
  for(var x = 0; x<= 99; x++) {
      tst = document.getElementById(pane_prefix + 's'+x+'_' + 'new_filter');
      if(tst && pane_prefix + 's'+x+'_' != search_prefix) { last_nr = x; }
  }
  showElement( pane_prefix + 's'+last_nr+'_' + 'new_filter');

  // realign search panel to 3 per row.
  // first collect all cells from all rows
  var cells = [];
  for(var rowNum = 0; rowNum < table.rows.length; rowNum++) {
      while(table.rows[rowNum].firstChild) {
        var node = table.rows[rowNum].removeChild(table.rows[rowNum].firstChild);
        if(node.nodeType === document.ELEMENT_NODE) cells.push(node);
      }
  }
  var rowNum = 0;
  for(var i = 0; i < cells.length; i++) {
    table.rows[rowNum].appendChild(cells[i]);
    if(i > 0 && (i+1)%3 == 0) {
        rowNum++;
    }
  }
  // remove last row if its emtpy now
  var rowNum = table.rows.length - 1;
  if(table.rows[rowNum].cells.length == 0) {
    table.deleteRow(table.rows[rowNum].rowIndex);
  }

  return false;
}

/* toggle checkbox for attribute filter */
function toggleFilterCheckBox(id) {
  id  = id.substring(0, id.length -1);
  var box = document.getElementById(id);
  if(box.checked) {
    box.checked = false;
  } else {
    box.checked = true;
  }
}

/* toggle all checkbox for attribute filter */
function toggleAllFilterCheckBox(prefix) {
  var box = document.getElementById(prefix+"ht0");
  var state = false;
  if(box.checked) {
    state = true;
  }
  for(var x = 0; x <= 99; x++) {
      var el = document.getElementById(prefix+'ht'+x);
      if(!el) { break; }
      el.checked = state;
  }
}

/* verify operator for search type selects */
function verify_op(event) {
  var selElem;
  if(event && event.target) {
    selElem = event.target;
  } else if(event) {
    selElem = document.getElementById(event);
  } else {
    selElem = document.getElementById(this.id);
  }

  // get operator select
  var opElem = document.getElementById(selElem.id.substring(0, selElem.id.length - 1) + 'o');

  var selValue = selElem.options[selElem.selectedIndex].value;

  // do we have to display the datepicker?
  var calElem = document.getElementById(selElem.id.substring(0, selElem.id.length - 2) + 'cal');
  if(selValue == 'next check' || selValue == 'last check' ) {
    showElement(calElem);
  } else {
    hideElement(calElem);
  }

  var input  = document.getElementById(selElem.id.substring(0, selElem.id.length - 2) + 'value');
  if(enable_shinken_features) {
    var select = document.getElementById(selElem.id.substring(0, selElem.id.length - 2) + 'value_sel');
    if(selValue == 'business impact' ) {
      showElement(select.id);
      hideElement(input.id);
    } else {
      hideElement(select.id);
      showElement(input.id);
    }
  }
  var pre_in = document.getElementById(selElem.id.substring(0, selElem.id.length - 2) + 'val_pre');
  if(selValue == 'custom variable' ) {
    showElement(pre_in.id);
    jQuery(input).css('width', '80px');
  } else {
    hideElement(pre_in.id);
    jQuery(input).css('width', '');
  }

  // check if the right operator are active
  for(var x = 0; x< opElem.options.length; x++) {
    var curOp = opElem.options[x].value;
    if(curOp == '~' || curOp == '!~') {
      // list of fields which have a ~ or !~ operator
      if(   selValue != 'search'
         && selValue != 'host'
         && selValue != 'service'
         && selValue != 'hostgroup'
         && selValue != 'servicegroup'
         && selValue != 'timeperiod'
         && selValue != 'contact'
         && selValue != 'custom variable'
         && selValue != 'comment'
         && selValue != 'event handler'
         && selValue != 'plugin output') {
        // is this currently selected?
        if(x == opElem.selectedIndex) {
          // only = and != are allowed for list searches
          // so set the corresponding one
          if(curOp == '!~') {
              selectByValue(opElem, '!=');
          } else {
              selectByValue(opElem, '=');
          }
        }
        opElem.options[x].style.display = "none";
        opElem.options[x].disabled      = true;
      } else {
        opElem.options[x].style.display = "";
        opElem.options[x].disabled      = false;
      }
    }

    // list of fields which have a <= or >= operator
    if(curOp == '<=' || curOp == '>=') {
      if(   selValue != 'next check'
         && selValue != 'last check'
         && selValue != 'latency'
         && selValue != 'number of services'
         && selValue != 'current attempt'
         && selValue != 'execution time'
         && selValue != '% state change'
         && selValue != 'duration'
         && selValue != 'downtime duration'
         && selValue != 'business impact') {
        // is this currently selected?
        if(x == opElem.selectedIndex) {
          // only <= and >= are allowed for list searches
          selectByValue(opElem, '=');
        }
        opElem.options[x].style.display = "none";
        opElem.options[x].disabled      = true;
      } else {
        opElem.options[x].style.display = "";
        opElem.options[x].disabled      = false;
      }
    }
  }

  input.title = '';
  if(selValue == 'duration') {
    input.title = "Duration: Input type is seconds. You may use w (week) or d (day), h (hour) or m (minutes). Ex.: 10m for 10 minutes.";
  }
  if(selValue == 'downtime duration') {
    input.title = "Downtime Duration: Input type is seconds. You may use w (week) or d (day), h (hour) or m (minutes). Ex.: 10m for 10 minutes.";
  }
  if(selValue == 'execution time') {
    input.title = "Execution Time: Input type is seconds. You may use w (week) or d (day), h (hour) or m (minutes). Ex.: 10m for 10 minutes.";
  }
}

/* remove columns from get parameters when style has changed */
function check_filter_style_changes(form, pageStyle, columnFieldId) {
  var s_data = jQuery(form).serializeArray();
  for(var i=0; i<s_data.length; i++){
    if(s_data[i].name == "style" && s_data[i].value != pageStyle) {
        jQuery('#'+columnFieldId).val("");
    }
  }
  return true;
}


var status_form_clean = true;
function setNoFormClean() {
    status_form_clean = false;
}

/* remove empty values from form to reduce request size */
function remove_empty_form_params(form) {
  if(!status_form_clean) { return true; }
  var s_data = jQuery(form).serializeArray();
  for(var i=0; i<s_data.length; i++){
    var f = s_data[i];
    if(f["name"].match(/_hoststatustypes$/) && f["value"] == "15") {
        jQuery("INPUT[name='"+f["name"]+"']").remove();
    }
    if(f["name"].match(/_servicestatustypes/) && f["value"] == "31") {
        jQuery("INPUT[name='"+f["name"]+"']").remove();
    }
    if(f["name"].match(/_(host|service)props/) && f["value"] == "0") {
        jQuery("INPUT[name='"+f["name"]+"']").remove();
    }
    if(f["name"].match(/_columns_select$/)) {
        jQuery("INPUT[name='"+f["name"]+"']").remove();
    }
    if(f["name"].match(/^(host|service)_columns$/)) {
        jQuery("INPUT[name='"+f["name"]+"']").remove();
    }
    if(f["name"].match(/^(referer|bookmarks?|section)$/)) {
        jQuery("INPUT[name='"+f["name"]+"']").remove();
    }
  }
//return false;
  return(true);
}

/* select option from a select by value*/
function selectByValue(select, val) {
  for(var x = 0; x< select.options.length; x++) {
    if(select.options[x].value == val) {
      select.selectedIndex = x;
    } else {
      select.options[x].selected = false;
    }
  }
}

/* toggle visibility of top status informations */
function toggleTopPane() {
  var formInput = document.getElementById('hidetop');
  if(toggleElement('top_pane')) {
    additionalParams['hidetop'] = 0;
    formInput.value = 0;
    document.getElementById('btn_toggle_top_pane').src = url_prefix + "themes/" + theme + "/images/icon_minimize.gif";
  } else {
    additionalParams['hidetop'] = 1;
    formInput.value = 1;
    document.getElementById('btn_toggle_top_pane').src = url_prefix + "themes/" + theme + "/images/icon_maximize.gif";
  }
}

/*******************************************************************************
  ,ad8888ba,        db        88
 d8"'    `"8b      d88b       88
d8'               d8'`8b      88
88               d8'  `8b     88
88              d8YaaaaY8b    88
Y8,            d8""""""""8b   88
 Y8a.    .a8P d8'        `8b  88
  `"Y8888Y"' d8'          `8b 88888888888
*******************************************************************************/

var last_cal_hidden = undefined;
var last_cal_id     = undefined;
function show_cal(id, defaultDate) {
  // make calendar toggle
  var now = new Date;
  if(last_cal_hidden != undefined && (now.getTime() - last_cal_hidden) < 150 && (last_cal_id == undefined || last_cal_id == id )) {
    return;
  }

  last_cal_id   = id;
  var dateObj   = new Date();
  var times     = new Array(0,0,0);

  var parseDate = function(id) {
    var date_val  = document.getElementById(id).value;
    var date_time = date_val.split(" ");
    if(date_time.length == 2) {
      var dates     = date_time[0].split('-');
      var times     = date_time[1].split(':');
      if(times[2] == undefined) {
          times = new Array(0,0,0);
      }
      var dateObj = new Date(dates[0], (dates[1]-1), dates[2], times[0], times[1], times[2]);
    }
    return([dateObj, times]);
  }

  var tmp = parseDate(id);
  if(!tmp[0] && defaultDate != undefined) {
    document.getElementById(id).value = defaultDate;
    tmp = parseDate(id);
  }
  dateObj = tmp[0];
  times   = tmp[1];

  var setDate = function() {
    var newDateObj = new Date(this.selection.print('%Y'), (this.selection.print('%m')-1), this.selection.print('%d'), this.getHours(), this.getMinutes(), times[2]);
    document.getElementById(id).value = Calendar.printDate(newDateObj, '%Y-%m-%d %H:%M:%S');
    document.getElementById(id).value = Calendar.printDate(newDateObj, '%Y-%m-%d %H:%M:%S');
    // change end_date as well if new start date is past end date
    if(id == "start_time") {
        var end_date = document.getElementById("end_time");
        if(end_date) {
            var tmp = parseDate("end_time");
            if(newDateObj.getTime() > tmp[0].getTime()) {
                var endDate = new Date(newDateObj.getTime() + (downtime_duration * 1000));
                end_date.value = Calendar.printDate(endDate, '%Y-%m-%d %H:%M:%S');
            }
        }
    }
    var now = new Date; last_cal_hidden = now.getTime();
    jQuery('.DynarchCalendar-topCont').remove();
  }

  var cal = Calendar.setup({
      time: Calendar.printDate(dateObj, '%H%M'),
      date: Calendar.dateToInt(dateObj),
      showTime: true,
      fdow: 1,
      weekNumbers: true,
      onSelect: setDate,
      onBlur:   setDate,
      onTimeChange: function(c, time) {
        time = time - time%5;
        c.setTime(time, true);
      }
  });
  cal.selection.set(Calendar.dateToInt(dateObj));
  var pos    = ajax_search.get_coordinates(jQuery('#'+id)[0]);
  cal.popup(id, "Br/ / /T/r");
  jQuery('.DynarchCalendar-topCont').css('top', (pos[1]+20)+"px");
}

/*******************************************************************************
 ad88888ba  88888888888        db        88888888ba    ,ad8888ba,  88        88
d8"     "8b 88                d88b       88      "8b  d8"'    `"8b 88        88
Y8,         88               d8'`8b      88      ,8P d8'           88        88
`Y8aaaaa,   88aaaaa         d8'  `8b     88aaaaaa8P' 88            88aaaaaaaa88
  `"""""8b, 88"""""        d8YaaaaY8b    88""""88'   88            88""""""""88
        `8b 88            d8""""""""8b   88    `8b   Y8,           88        88
Y8a     a8P 88           d8'        `8b  88     `8b   Y8a.    .a8P 88        88
 "Y88888P"  88888888888 d8'          `8b 88      `8b   `"Y8888Y"'  88        88
*******************************************************************************/
var ajax_search = {
    max_results     : 12,
    input_field     : 'NavBarSearchItem',
    result_pan      : 'search-results',
    update_interval : 3600, // update at least every hour
    search_type     : 'all',
    size            : 150,
    updating        : false,
    error           : false,

    hideTimer       : undefined,
    base            : new Array(),
    res             : new Array(),
    initialized     : false,
    initialized_t   : false,
    initialized_a   : false,
    cur_select      : -1,
    result_size     : false,
    cur_results     : false,
    cur_pattern     : false,
    timer           : false,
    striped         : false,
    autosubmit      : undefined,
    list            : false,
    templates       : 'no',
    hideempty       : false,
    emptymsg        : undefined,
    show_all        : false,
    dont_hide       : false,
    autoopen        : true,
    append_value_of : undefined,
    stop_events     : false,
    empty           : false,
    emptytxt        : '',
    emptyclass      : '',
    onselect        : undefined,
    onemptyclick    : undefined,
    filter          : undefined,
    regex_matching  : false,
    backend_select  : false,
    button_links    : [],
    search_for_cb   : undefined,

    /* initialize search
     *
     * options are {
     *   url:               url to fetch data
     *   striped:           true/false, everything after " - " is trimmed
     *   autosubmit:        true/false, submit form on select
     *   list:              true/false, string is split by , and suggested by last chunk
     *   templates:         no/templates/both, suggest templates
     *   data:              search base data
     *   hideempty:         true/false, hide results when there are no hits
     *   add_prefix:        true/false, add ho:... prefix
     *   append_value_of:   id of input field to append to the original url
     *   empty:             remove text on first access
     *   emptytxt:          text when empty
     *   emptyclass:        class when empty
     *   onselect:          run this function after selecting something
     *   onemptyclick:      when clicking on the empty button
     *   filter:            run this function as additional filter
     *   backend_select:    append value of this backend selector
     *   button_links:      prepend links to buttons on top of result
     *   regex_matching:    match with regular expressions
     *   search_for_cb:     callback to alter the search input
     * }
     */
    init: function(elem, type, options) {
        if(elem && elem.id) {
        } else if(this.id) {
          elem = this;
        } else {
          if(thruk_debug_js) { alert("ERROR: got no element id in ajax_search.init(): " + elem); }
          return false;
        }

        if(options == undefined) { options = {}; };

        ajax_search.url = url_prefix + 'cgi-bin/status.cgi?format=search';
        ajax_search.input_field = elem.id;

        if(ajax_search.stop_events == true) {
            return false;
        }

        if(options.striped != undefined) {
            ajax_search.striped = options.striped;
        }
        if(options.autosubmit != undefined) {
            ajax_search.autosubmit = options.autosubmit;
        }
        if(options.list != undefined) {
            ajax_search.list = options.list;
        }
        if(options.templates != undefined) {
            ajax_search.templates = options.templates;
        } else {
            ajax_search.templates = 'no';
        }
        if(options.hideempty != undefined) {
            ajax_search.hideempty = options.hideempty;
        }
        if(options.add_prefix != undefined) {
            ajax_search.add_prefix = options.add_prefix;
        }
        ajax_search.emptymsg = 'no results found';
        if(options.emptymsg != undefined) {
            ajax_search.emptymsg = options.emptymsg;
        }

        if(options.append_value_of != undefined) {
            append_value_of = options.append_value_of;
        } else {
            append_value_of = ajax_search.append_value_of;
        }

        if(options.backend_select != undefined) {
            backend_select = options.backend_select;
        } else {
            backend_select = ajax_search.backend_select;
        }

        ajax_search.button_links = [];
        if(options.button_links != undefined) {
            ajax_search.button_links = options.button_links;
        }

        ajax_search.empty = false;
        if(options.empty != undefined) {
            ajax_search.empty = options.empty;
        }
        if(options.emptytxt != undefined) {
            ajax_search.emptytxt = options.emptytxt;
        }
        if(options.emptyclass != undefined) {
            ajax_search.emptyclass = options.emptyclass;
        }
        ajax_search.onselect = undefined;
        if(options.onselect != undefined) {
            ajax_search.onselect = options.onselect;
        }
        ajax_search.onemptyclick = undefined;
        if(options.onemptyclick != undefined) {
            ajax_search.onemptyclick = options.onemptyclick;
        }
        ajax_search.filter = undefined;
        if(options.filter != undefined) {
            ajax_search.filter = options.filter;
        }
        ajax_search.search_for_cb = undefined;
        if(options.search_for_cb != undefined) {
            ajax_search.search_for_cb = options.search_for_cb;
        }

        var input = document.getElementById(ajax_search.input_field);
        if(input.disabled) { return false; }
        ajax_search.size = jQuery(input).width();
        if(ajax_search.size < 100) {
            /* minimum is 100px */
            ajax_search.size = 100;
        }

        if(ajax_search.empty == true) {
            if(input.value == ajax_search.emptytxt) {
                jQuery(input).removeClass(ajax_search.emptyclass);
                input.value = "";
            }
        }

        ajax_search.show_all = false;
        var panel = document.getElementById(ajax_search.result_pan);
        if(panel) {
            panel.style.overflowY="";
            panel.style.height="";
        }

        // set type from select
        var type_selector_id = elem.id.replace('_value', '_ts');
        var selector = document.getElementById(type_selector_id);
        ajax_search.search_type = 'all';
        if(!iPhone) {
            addEvent(input, 'keyup', ajax_search.suggest);
            addEvent(input, 'blur',  ajax_search.hide_results);
        }

        var op_selector_id = elem.id.replace('_value', '_to');
        var op_sel         = document.getElementById(op_selector_id);
        ajax_search.regex_matching = false;
        if(op_sel != undefined) {
            var val = jQuery(op_sel).val();
            if(val == '~' || val == '!~') {
                ajax_search.regex_matching = true;
            }
        }
        if(options.regex_matching != undefined) {
            ajax_search.regex_matching = options.regex_matching;
        }

        search_url = ajax_search.url;
        if(options.url != undefined) {
            search_url = options.url;
        }

        if(type != undefined) {
            // type can be a callback
            if(typeof(type) == 'function') {
                type = type();
            }
            ajax_search.search_type = type;
            if(!search_url.match(/type=/)) {
                search_url = search_url + "&type=" + type;
            }
        } else {
            type = 'all';
        }

        var appended_value;
        if(append_value_of) {
            var el = document.getElementById(append_value_of);
            if(el) {
                search_url     = search_url + el.value;
                appended_value = el.value;
            } else {
                search_url     = ajax_search.url;
                appended_value = '';
            }
        }
        if(backend_select) {
            var sel = document.getElementById(backend_select);
            // only if enabled
            if(sel && !sel.disabled) {
                var backends = jQuery('#'+backend_select).val();
                if(backends != undefined) {
                    if(typeof(backends) == 'string') { backends = [backends]; }
                    jQuery.each(backends, function(i, val) {
                        search_url = search_url + '&backend=' + val;
                    });
                }
            }
        }

        input.setAttribute("autocomplete", "off");
        if(!iPhone && !internetExplorer) {
            ajax_search.dont_hide = true;
            input.blur();   // blur & focus the element, otherwise the first
            input.focus();  // click would result in the browser autocomplete
            ajax_search.dont_hide = false;
        }

        if(selector && selector.tagName == 'SELECT') {
            var search_type = selector.options[selector.selectedIndex].value;
            if(   search_type == 'host'
               || search_type == 'hostgroup'
               || search_type == 'service'
               || search_type == 'servicegroup'
               || search_type == 'timeperiod'
               || search_type == 'priority'
               || search_type == 'custom variable'
               || search_type == 'contact'
               || search_type == 'event handler'
            ) {
                ajax_search.search_type = search_type;
            }
            if(search_type == 'parent') {
                ajax_search.search_type = 'host';
            }
            if(search_type == 'check period') {
                ajax_search.search_type = 'timeperiod';
            }
            if(search_type == 'notification period') {
                ajax_search.search_type = 'timeperiod';
            }
            if(search_type == 'business impact') {
                ajax_search.search_type = 'priority';
            }
            if(   search_type == 'comment'
               || search_type == 'next check'
               || search_type == 'last check'
               || search_type == 'latency'
               || search_type == 'number of services'
               || search_type == 'current attempt'
               || search_type == 'execution time'
               || search_type == '% state change'
               || search_type == 'duration'
               || search_type == 'downtime duration'
            ) {
                ajax_search.search_type = 'none';
            }
        }
        if(input.id.match(/_value$/) && ajax_search.search_type == "custom variable") {
            ajax_search.search_type = "none"
            var varFieldId = input.id.replace(/_value$/, '_val_pre');
            var varField   = document.getElementById(varFieldId);
            if(varField) {
                ajax_search.search_type = "custom value"
                search_url = search_url + "&type=custom value&var=" + varField.value;
            }
        }
        if(ajax_search.search_type == 'none') {
            removeEvent( input, 'keyup', ajax_search.suggest );
            return true;
        } else {
            if(   search_type == 'event handler'
               || search_type == 'contact'
            ) {
                if(!search_url.match(/type=/)) {
                    search_url = search_url + "&type=" + ajax_search.search_type;
                }
            }
        }

        var date = new Date;
        var now  = parseInt(date.getTime() / 1000);
        // update every hour (frames searches wont update otherwise)
        if(   ajax_search.initialized
           && now < ajax_search.initialized + ajax_search.update_interval
           && (    append_value_of == undefined && ajax_search.initialized_t == type
               || (append_value_of != undefined && ajax_search.initialized_a == appended_value )
              )
           && ajax_search.initialized_u == search_url
        ) {
            ajax_search.suggest();
            return false;
        }

        ajax_search.initialized   = now;
        ajax_search.initialized_t = type;
        ajax_search.initialized_a = undefined;
        if(append_value_of) {
            ajax_search.initialized_a = appended_value;
        }
        ajax_search.initialized_u = search_url;

        // disable autocomplete
        var tmpElem = input;
        while(tmpElem && tmpElem.parentNode) {
            tmpElem = tmpElem.parentNode;
            if(tmpElem.tagName == 'FORM') {
                addEvent(tmpElem, 'submit', ajax_search.hide_results);
                tmpElem.setAttribute("autocomplete", "off");
            }
        }

        if(options.data != undefined) {
            ajax_search.base = options.data;
            ajax_search.suggest();
        } else {
             ajax_search.updating=true;
             ajax_search.error=false;

            // show searching results
            ajax_search.base = {};
            ajax_search.suggest();

             // fill data store
            jQuery.ajax({
                url: search_url,
                type: 'POST',
                success: function(data) {
                    ajax_search.updating=false;
                    ajax_search.base = data;
                    if(ajax_search.autoopen == true || panel.style.visibility == 'visible') {
                        ajax_search.suggest();
                    }
                    ajax_search.autoopen = true;
                },
                error: function(jqXHR, textStatus, errorThrown) {
                    ajax_search.error=errorThrown;
                    if(ajax_search.error == undefined || ajax_search.error == "") {
                        ajax_search.error = "server unavailable";
                    }
                    ajax_search.updating=false;
                    ajax_search.show_results([]);
                    ajax_search.initialized = false;
                }
            });
        }

        if(!iPhone) {
            addEvent(document, 'keydown', ajax_search.arrow_keys);
            addEvent(document, 'click', ajax_search.hide_results);
        }

        return false;
    },

    /* hide the search results */
    hide_results: function(event, immediately, setfocus) {
        if(ajax_search.dont_hide) { return; }
        if(event && event.target) {
        }
        else {
            event  = this;
        }
        try {
            // dont hide search result if clicked on the input field
            if(event.type != "blur" && event.target.tagName == 'INPUT') { return; }
            // don't close if blur is due to a click inside the search results
            if(event.type == "blur" || event.type == "click") {
                var result_panel = document.getElementById(ajax_search.result_pan);
                var p = event.target;
                var found = false;
                while(p.parentNode) {
                    if(p == result_panel) {
                        found = true;
                        break;
                    }
                    p = p.parentNode;
                }
                if(found) {
                    window.clearTimeout(ajax_search.hideTimer);
                    return;
                }
            }
        }
        catch(err) {
            // doesnt matter
        }
        var panel = document.getElementById(ajax_search.result_pan);
        if(!panel) { return; }
        /* delay hiding a little moment, otherwise the click
         * on the suggestion would be cancel as the panel does
         * not exist anymore
         */
        if(immediately != undefined) {
            hideElement(ajax_search.result_pan);
            if(setfocus) {
                ajax_search.stop_events = true;
                window.setTimeout("ajax_search.stop_events=false;", 200);
                var input = document.getElementById(ajax_search.input_field);
                input.focus();
            }
        }
        else if(ajax_search.cur_select == -1) {
            window.clearTimeout(ajax_search.hideTimer);
            ajax_search.hideTimer = window.setTimeout("if(ajax_search.dont_hide==false){fade('"+ajax_search.result_pan+"', 300)}", 150);
        }
    },

    /* wrapper around suggest_do() to avoid multiple running searches */
    suggest: function(evt) {
        window.clearTimeout(ajax_search.timer);
        // dont suggest on enter
        evt = (evt) ? evt : ((window.event) ? event : null);
        if(evt) {
            var keyCode = evt.keyCode;
            // dont suggest on
            if(   keyCode == 13     // enter
               || keyCode == 108    // KP enter
               || keyCode == 27     // escape
               || keyCode == 16     // shift
               || keyCode == 20     // capslock
               || keyCode == 17     // ctrl
               || keyCode == 18     // alt
               || keyCode == 91     // left windows key
               || keyCode == 92     // right windows key
               || keyCode == 33     // page up
               || keyCode == 34     // page down
               || evt.altKey == true
               || evt.ctrlKey == true
               || evt.metaKey == true
               //|| evt.shiftKey == true // prevents suggesting capitals
            ) {
                return false;
            }
            // tab on keyup opens suggestions for wrong input
            if(keyCode == 9 && evt.type == "keyup") {
                return false;
            }
        }

        ajax_search.timer = window.setTimeout("ajax_search.suggest_do()", 100);
        return true;
    },

    /* search some hosts to suggest */
    suggest_do: function() {
        var input;
        var input = document.getElementById(ajax_search.input_field);
        if(!input) { return; }
        if(ajax_search.base == undefined || ajax_search.base.length == 0) { return; }

        // business impact prioritys are fixed
        if(ajax_search.search_type == 'priority') {
            ajax_search.base = [{ name: 'prioritys', data: ["1","2","3","4","5"] }];
        }

        pattern = input.value;
        if(ajax_search.search_for_cb) {
            pattern = ajax_search.search_for_cb(pattern)
        }
        if(ajax_search.list) {
            /* only use the last list element for search */
            var regex  = new RegExp(ajax_search.list, 'g');
            var range  = jQuery(input).getSelection();
            var before = pattern.substr(0, range.start);
            var after  = pattern.substr(range.start);
            var rever  = reverse(before);
            var index  = rever.search(regex);
            if(index != -1) {
                var index2  = after.search(regex);
                if(index2 != -1) {
                    pattern = reverse(rever.substr(0, index)) + after.substr(0, index2);
                } else {
                    pattern = reverse(rever.substr(0, index)) + after;
                }
            } else {
                // possible on the first elem, then we search for the first delimiter after the cursor
                var index  = pattern.search(regex);
                if(index != -1) {
                    pattern = pattern.substr(0, index);
                }
            }
        }
        if(pattern.length >= 1 || ajax_search.search_type != 'all') {

            prefix = pattern.substr(0,3);
            if(prefix == 'ho:' || prefix == 'hg:' || prefix == 'se:' || prefix == 'sg:') {
                pattern = pattern.substr(3);
            }

            // remove empty strings from pattern array
            pattern = get_trimmed_pattern(pattern);
            var results = new Array();
            jQuery.each(ajax_search.base, function(index, search_type) {
                var sub_results = new Array();
                var top_hits = 0;
                if(   (ajax_search.search_type == 'all' && search_type.name != 'timeperiods')
                   || (ajax_search.search_type == 'full')
                   || (ajax_search.templates == "templates" && search_type.name == ajax_search.initialized_t + " templates")
                   || (ajax_search.templates != "templates" && ajax_search.search_type + 's' == search_type.name)
                   || (ajax_search.templates == "both" && ( search_type.name == ajax_search.initialized_t + " templates" || ajax_search.search_type + 's' == search_type.name ))
                  ) {
                  jQuery.each(search_type.data, function(index, data) {
                      var name = data;
                      var alias = '';
                      if(data['name']) {
                          name = data['name'];
                      }
                      var search_name = name;
                      if(data['alias']) {
                          alias = data['alias'];
                          search_name = search_name+' '+alias;
                      }
                      result_obj = new Object({ 'name': name, 'relevance': 0 });
                      var found = 0;
                      jQuery.each(pattern, function(i, sub_pattern) {
                          var index = search_name.toLowerCase().indexOf(sub_pattern.toLowerCase());
                          if(index != -1) {
                              found++;
                              if(index == 0) { // perfect match, starts with pattern
                                  result_obj.relevance += 100;
                              } else {
                                  result_obj.relevance += 1;
                              }
                          } else {
                              if(sub_pattern == "*") {
                                found++;
                                result_obj.relevance += 1;
                                return;
                              }
                              var re;
                              try {
                                re = new RegExp(sub_pattern, "gi");
                              } catch(err) {
                                console.log('regex failed: ' + sub_pattern);
                                console.log(err);
                                ajax_search.error = "regex failed: "+err;
                                return(false);
                              }
                              if(re != undefined && ajax_search.regex_matching && search_name.match(re)) {
                                  found++;
                                  result_obj.relevance += 1;
                              }
                          }
                      });
                      // additional filter?
                      var rt = true;
                      if(ajax_search.filter != undefined) {
                          rt = ajax_search.filter(name, search_type);
                      }
                      // only if all pattern were found
                      if(rt && found == pattern.length) {
                          result_obj.display = name;
                          if(alias && name != alias) {
                            result_obj.display = name+" - "+alias;
                          }
                          result_obj.sorter = (result_obj.relevance) + result_obj.name;
                          sub_results.push(result_obj);
                          if(result_obj.relevance >= 100) { top_hits++; }
                      }
                  });
                }
                if(sub_results.length > 0) {
                    sub_results.sort(sort_by('sorter', false));
                    results.push(Object({ 'name': search_type.name, 'results': sub_results, 'top_hits': top_hits }));
                }
            });

            ajax_search.cur_results = results;
            ajax_search.cur_pattern = pattern;
            ajax_search.show_results(results, pattern, ajax_search.cur_select);
        }
        else {
            ajax_search.hide_results();
        }
    },

    /* present the results */
    show_results: function(results, pattern, selected) {
        var panel = document.getElementById(ajax_search.result_pan);
        var input = document.getElementById(ajax_search.input_field);
        if(!panel) { return; }
        if(!input) { return; }

        results.sort(sort_by('top_hits', false));

        var resultHTML = '<ul>';
        if(ajax_search.button_links) {
            jQuery.each(ajax_search.button_links, function(i, btn) {
                resultHTML += '<li class="'+(btn.cls ? ' '+btn.cls+' ' : '')+'"><b>';
                resultHTML += '<a href="" class="item" onclick="jQuery(\'#'+btn.id+'\').click(); return false;" style="width:'+ajax_search.size+'px;">';
                if(btn.icon) {
                    resultHTML += '<img src="'+ url_prefix + 'themes/' + theme + '/images/' + btn.icon+'">';
                }
                resultHTML += btn.text;
                resultHTML += '<\/b><\/a><\/li>';
            });
        }
        var x = 0;
        var results_per_type = Math.ceil(ajax_search.max_results / results.length);
        ajax_search.res   = new Array();
        var has_more = 0;
        jQuery.each(results, function(index, type) {
            var cur_count = 0;
            var name = type.name.substring(0,1).toUpperCase() + type.name.substring(1);
            if(type.results.length == 1) { name = name.substring(0, name.length -1); }
            name = name.replace(/ss$/, 's');
            resultHTML += '<li><b><i>' + ( type.results.length ) + ' ' + name + '<\/i><\/b><\/li>';
            jQuery.each(type.results, function(index, data) {
                if(ajax_search.show_all || cur_count <= results_per_type) {
                    var name = data.display;
                    jQuery.each(pattern, function(index, sub_pattern) {
                        if(ajax_search.regex_matching && sub_pattern != "*") {
                            var re = new RegExp('('+sub_pattern+')', "gi");
                            name = name.replace(re, "<b>$1<\/b>");
                        } else {
                            name = name.toLowerCase().replace(sub_pattern.toLowerCase(), "<b>" + sub_pattern + "<\/b>");
                        }
                    });
                    var classname = "item";
                    if(selected != -1 && selected == x) {
                        classname = "item ajax_search_selected";
                    }
                    var prefix = '';
                    if(ajax_search.search_type == "all" || ajax_search.search_type == "full" || ajax_search.add_prefix == true) {
                        if(type.name == 'hosts')             { prefix = 'ho:'; }
                        if(type.name == 'host templates')    { prefix = 'ht:'; }
                        if(type.name == 'hostgroups')        { prefix = 'hg:'; }
                        if(type.name == 'services')          { prefix = 'se:'; }
                        if(type.name == 'service templates') { prefix = 'st:'; }
                        if(type.name == 'servicegroups')     { prefix = 'sg:'; }
                    }
                    var id = "suggest_item_"+x
                    if(type.name == 'icons') {
                        file = data.display.split(" - ");
                        name = "<img src='" + file[1] + "' style='vertical-align: text-bottom; width: 16px; height: 16px;'> " + file[0];
                    }
                    name        = name.replace(/\ \(disabled\)$/, '<span style="color: #EB6900; margin-left: 20px;"> (disabled)<\/span>');
                    resultHTML += '<li><a href="" class="' + classname + '" style="width:'+ajax_search.size+'px;" id="'+id+'" rev="' + prefix+data.name +'" onclick="ajax_search.set_result(this.rev); return false;" title="' + data.display + '"> ' + name +'<\/a><\/li>';
                    ajax_search.res[x] = prefix+data.display;
                    x++;
                    cur_count++;
                } else {
                    has_more = 1;
                }
            });
        });
        if(has_more == 1) {
            var id = "suggest_item_"+x
            var classname = "item";
            if(selected != -1 && selected == x) {
                classname = "item ajax_search_selected";
            }
            resultHTML += '<li> <a href="" class="' + classname + '" style="width:'+ajax_search.size+'px;" id="'+id+'" rev="more" onmousedown="ajax_search.set_result(this.rev); return false;"><b>more...<\/b><\/a><\/li>';
            x++;
        }
        ajax_search.result_size = x;
        if(results.length == 0) {
            resultHTML += '<li>';
            if(ajax_search.error) {
                resultHTML += '<a href="#"><span style="color:red;">error: '+ajax_search.error+'</span></a>';
            }
            else if(ajax_search.updating) {
                resultHTML += '<a href="#"><img src="'+ url_prefix + 'themes/' + theme + '/images/loading-icon.gif" width=16 height=16 style="vertical-align: text-bottom;"> loading...</a>';
            } else {
                resultHTML += '<a href="#" onclick="ajax_search.onempty()">'+ ajax_search.emptymsg +'</a>';
            }
            resultHTML += '</li>';
            if(ajax_search.hideempty) {
                ajax_search.hide_results();
                return;
            }
        }
        resultHTML += '<\/ul>';

        panel.innerHTML = resultHTML;

        var style     = panel.style;
        var coords;
        if(jQuery(input).hasClass("NavBarSearchItem")) {
            // input is wraped in deletable icon span
            coords    = jQuery(input.parentNode).position();
        } else {
            coords    = jQuery(input).offset();
        }
        style.left    = coords.left + "px";
        style.top     = (coords.top + input.offsetHeight + 2) + "px";
        style.display = "block";
        style.width   = ( ajax_search.size -2 ) + "px";

        if(jQuery(input).hasClass("NavBarSearchItem")) {
            style.top   = (coords.top + input.offsetHeight - 4) + "px";
            style.width = ( ajax_search.size + 28 ) + "px";
        }

        /* move dom node to make sure it scrolls with the input field */
        if(jQuery(input).hasClass("NavBarSearchItem")) {
            var tmpElem = input;
            var x = 0;
            // put result div below the form, otherwise clicking a type header would result in a redirect to undefined (#197)
            while(tmpElem && tmpElem.parentNode && x < 7) {
                if(tmpElem.tagName != 'UL') {
                    tmpElem = tmpElem.parentNode;
                }
                x++;
            }
            jQuery('#'+ajax_search.result_pan).insertAfter(tmpElem);
        } else {
            jQuery('#'+ajax_search.result_pan).appendTo('BODY');
        }

        showElement(panel);
        ajax_search.stop_events = true;
        window.setTimeout("ajax_search.stop_events=false;", 200);
        ajax_search.dont_hide=true;
        window.setTimeout("ajax_search.dont_hide=false", 500);
        try { // Error: Can't move focus to the control because it is invisible, not enabled, or of a type that does not accept the focus.
            input.focus();
        } catch(err) {}
    },

    onempty: function() {
        if(ajax_search.onemptyclick != undefined) {
            ajax_search.onemptyclick();
        }
    },

    /* set the value into the input field */
    set_result: function(value) {
        if(value == 'more' || (value == undefined && ajax_search.res.length == ajax_search.cur_select)) {
            window.clearTimeout(ajax_search.hideTimer);
            var panel = document.getElementById(ajax_search.result_pan);
            if(panel) {
                panel.style.overflowY="scroll";
                panel.style.height=jQuery(panel).height()+"px";
            }
            ajax_search.show_all = true;
            ajax_search.show_results(ajax_search.cur_results, ajax_search.cur_pattern, ajax_search.cur_select);
            window.clearTimeout(ajax_search.hideTimer);
            return true;
        }

        if(ajax_search.striped && value != undefined) {
            var values = value.split(" - ", 2);
            value = values[0];
        }

        var input   = document.getElementById(ajax_search.input_field);

        var cursorpos = undefined;
        if(ajax_search.list) {
            var pattern = input.value;
            var regex   = new RegExp(ajax_search.list, 'g');
            var range   = jQuery(input).getSelection();
            var before  = pattern.substr(0, range.start);
            var after   = pattern.substr(range.start);
            var rever   = reverse(before);
            var index   = rever.search(regex);
            if(index != -1) {
                before    = before.substr(0, before.length - index);
                cursorpos = before.length + value.length;
                value     = before + value + after;
            } else {
                // possible on the first elem, then we just add everything after the first delimiter
                var index  = pattern.search(regex);
                if(index != -1) {
                    cursorpos = value.length;
                    value     = value + pattern.substr(index);
                }
            }
        }

        input.value = value;
        ajax_search.cur_select = -1;
        ajax_search.hide_results(null, 1, 1);
        input.focus();
        if(cursorpos) {
            setCaretToPos(input, cursorpos);
        }

        // close suggestions after select
        window.clearTimeout(ajax_search.timer);
        ajax_search.dont_hide==false;
        window.setTimeout('ajax_search.hide_results(null, 1, 1);', 100);

        if(ajax_search.onselect != undefined) {
            return ajax_search.onselect(input);
        }

        if(( ajax_search.autosubmit == undefined
             && (
                    jQuery(input).hasClass("NavBarSearchItem")
                 || ajax_search.input_field == "data.username"
                 || ajax_search.input_field == "data.name"
                 )
           )
           || ajax_search.autosubmit == true
           ) {
            var tmpElem = input;
            while(tmpElem && tmpElem.parentNode) {
                tmpElem = tmpElem.parentNode;
                if(tmpElem.tagName == 'FORM') {
                    tmpElem.submit();
                    return false;
                }
            }
            return false;
        } else {
            return false;
        }
    },

    /* eventhandler for arrow keys */
    arrow_keys: function(evt) {
        evt              = (evt) ? evt : ((window.event) ? event : null);
        if(!evt) { return false; }
        var input        = document.getElementById(ajax_search.input_field);
        var panel        = document.getElementById(ajax_search.result_pan);
        var focus        = false;
        var keyCode      = evt.keyCode;
        var navigateUp   = keyCode == 38;
        var navigateDown = keyCode == 40;

        // arrow keys
        if((!evt.ctrlKey && !evt.metaKey) && panel.style.display != 'none' && (navigateUp || navigateDown)) {
            if(navigateDown && ajax_search.cur_select == -1) {
                ajax_search.cur_select = 0;
                focus = true;
            }
            else if(navigateUp && ajax_search.cur_select == -1) {
                ajax_search.cur_select = ajax_search.result_size - 1;
                focus = true;
            }
            else if(navigateDown) {
                if(ajax_search.result_size > ajax_search.cur_select + 1) {
                    ajax_search.cur_select++;
                    focus = true;
                } else {
                    ajax_search.cur_select = -1;
                    input.focus();
                }
            }
            else if(navigateUp) {
                ajax_search.cur_select--;
                if(ajax_search.cur_select < 0) {
                    ajax_search.cur_select = -1;
                    input.focus();
                }
                else {
                    focus = true;
                }
            }
            ajax_search.show_results(ajax_search.cur_results, ajax_search.cur_pattern, ajax_search.cur_select);
            if(focus) {
                var el = document.getElementById('suggest_item_'+ajax_search.cur_select);
                if(el) {
                    el.focus();
                }
            }
            // ie does not support preventDefault, setting returnValue works
            evt.preventDefault ? evt.preventDefault() : evt.returnValue = false;
            return false;
        }
        // return or enter
        if(keyCode == 13 || keyCode == 108) {
            if(ajax_search.cur_select == -1) {
                return true
            }
            if(ajax_search.set_result(ajax_search.res[ajax_search.cur_select])) {
                return false;
            }
            evt.preventDefault ? evt.preventDefault() : evt.returnValue = false;
            return false
        }
        // hit escape
        if(keyCode == 27) {
            ajax_search.hide_results(undefined, true);
            evt.preventDefault ? evt.preventDefault() : evt.returnValue = false;
            return false;
        }
        return true;
    },

    /* return coordinates for given element */
    get_coordinates: function(element) {
        var offsetLeft = 0;
        var offsetTop = 0;
        while(element.offsetParent){
            offsetLeft += element.offsetLeft;
            offsetTop += element.offsetTop;
            if(element.scrollTop > 0){
                offsetTop -= element.scrollTop;
            }
            element = element.offsetParent;
        }
        return [offsetLeft, offsetTop];
    },

    reset: function() {
        if(ajax_search.empty) {
            var input = document.getElementById(ajax_search.input_field);
            jQuery(input).addClass(ajax_search.emptyclass);
            jQuery(input).val(ajax_search.emptytxt);
        }
    }
}


/*******************************************************************************
GRAPHITE
*******************************************************************************/
function graphite_format_date(date) {
    var d1=new Date(date*1000);

    var curr_year = d1.getFullYear();

    var curr_month = d1.getMonth() + 1; //Months are zero based
    if (curr_month < 10)
        curr_month = "0" + curr_month;

    var curr_date = d1.getDate();
    if (curr_date < 10)
        curr_date = "0" + curr_date;

    var curr_hour = d1.getHours();
    if (curr_hour < 10)
        curr_hour = "0" + curr_hour;

    var curr_min = d1.getMinutes();
    if (curr_min < 10)
        curr_min = "0" + curr_min;

    return curr_hour + "%3A" + curr_min + "_" +curr_year + curr_month + curr_date ;
}

function graphite_unformat_date(str) {
    debug("STR : "+str);
    //23:59_20130125
    var year,month,hour,day,minute;
    hour=str.substring(0,2);
    minute=str.substring(3,5);
    year=str.substring(6,10);
    month=str.substring(10,12)-1;
    day=str.substring(12,14);
    debug(year, month, day, hour, minute);
    var date=new Date(year, month, day, hour, minute);

    debug("date"+date);
    return date.getTime()/1000;
}

function set_graphite_img(start, end, id) {
    //23:59_20130125
    var date_start = new Date(start * 1000);
    var date_end   = new Date(end * 1000);

    var newUrl = graph_url + "&from=" + graphite_format_date(start) + "&until=" + graphite_format_date(end);
    debug(newUrl);

    jQuery('#graphitewaitimg').css('display', 'block');

    jQuery('#graphiteimg').load(function() {
      jQuery('#graphiteimg').css('display' , 'block');
      jQuery('#graphiteerr').css('display' , 'none');
      jQuery('#graphitewaitimg').css({'display': 'none', 'position': 'absolute'});
    })
    .error(function(err) {
      jQuery('#graphitewaitimg').css({'display': 'none', 'position': 'inherit'});
      jQuery('#graphiteimg').css('display' , 'none');
      jQuery('#graphiteerr').css('display' , 'block');
    });

    jQuery('#graphiteerr').css('display' , 'none');
    jQuery('#graphiteimg').attr('src', newUrl);

    // set style of buttons
    if(id) {
        id=id.replace(/^#/g, '');
        for(x=1;x<=5;x++) {
            obj = document.getElementById("graphite_th"+x);
            styleElements(obj, "original", 1);
        }
        obj = document.getElementById(id);
        styleElements(obj, "commentEven pnpSelected", 1);
    } else {
        // get id from hash
        if(window.location.hash != '#') {
            var values = window.location.hash.split("/");
            if(values[0]) {
                id = values[0].replace(/^#/, '');
            }
        }
    }

    if(id) {
        // replace history otherwise we have to press back twice
        var newhash = "#" + id + "/" + start + "/" + end;
        if (history.replaceState) {
            history.replaceState({}, "", newhash);
        } else {
            window.location.replace(newhash);
        }
    }

    // reset reload timer for page
    resetRefresh();

    return false;
}
function move_graphite_img(factor) {
    var urlArgs = new Object(toQueryParams(jQuery('#graphiteimg').attr('src')));

    start = graphite_unformat_date(urlArgs["from"]);
    end   = graphite_unformat_date(urlArgs["until"]);

    diff  = end - start;

    start = parseInt(diff * factor) + parseInt(start);
    end   = parseInt(diff * factor) + parseInt(end);

    return set_graphite_img(start, end);
}


/*******************************************************************************
88888888ba  888b      88 88888888ba
88      "8b 8888b     88 88      "8b
88      ,8P 88 `8b    88 88      ,8P
88aaaaaa8P' 88  `8b   88 88aaaaaa8P'
88""""""'   88   `8b  88 88""""""'
88          88    `8b 88 88
88          88     `8888 88
88          88      `888 88
*******************************************************************************/

function set_png_img(start, end, id, source) {
    if(start  == undefined) { start  = pnp_start; }
    if(end    == undefined) { end    = pnp_end; }
    if(source == undefined) { source = pnp_source; }
    var newUrl = pnp_url + "&start=" + start + "&end=" + end+"&source="+source;
    //debug(newUrl);

    pnp_start = start;
    pnp_end   = end;

    jQuery('#pnpwaitimg').css('display', 'block');

    jQuery('#pnpimg').load(function() {
      jQuery('#pnpimg').css('display' , 'block');
      jQuery('#pnperr').css('display' , 'none');
      jQuery('#pnpwaitimg').css({'display': 'none', 'position': 'absolute'});
    })
    .error(function(err) {
      jQuery('#pnpwaitimg').css({'display': 'none', 'position': 'inherit'});
      jQuery('#pnpimg').css('display' , 'none');
      jQuery('#pnperr').css('display' , 'block');
    });

    jQuery('#pnperr').css('display' , 'none');
    jQuery('#pnpimg').attr('src', newUrl);

    // set style of buttons
    if(id) {
        id=id.replace(/^#/g, '');
        for(x=1;x<=5;x++) {
            obj = document.getElementById("pnp_th"+x);
            styleElements(obj, "original", 1);
        }
        obj = document.getElementById(id);
        styleElements(obj, "commentEven pnpSelected", 1);
    } else {
        // get id from hash
        id = get_hash();
    }

    if(id) {
        // replace history otherwise we have to press back twice
        set_hash(id + "/" + start + "/" + end + "/" + source);
    }

    // reset reload timer for page
    resetRefresh();

    return false;
}

function move_png_img(factor) {
    var urlArgs = new Object(toQueryParams(jQuery('#pnpimg').attr('src')));

    start = urlArgs["start"];
    end   = urlArgs["end"];
    diff  = end - start;

    start = parseInt(diff * factor) + parseInt(start);
    end   = parseInt(diff * factor) + parseInt(end);

    return set_png_img(start, end);
}

function set_histou_img(start, end, id, source) {
    if(start  == undefined) { start  = histou_start; }
    if(end    == undefined) { end    = histou_end; }
    if(source == undefined) { source = histou_source; }

    histou_start = start;
    histou_end   = end;

    var getParamFrom = "&from=" + (start*1000);
    var getParamTo = "&to=" + (end*1000);
    var newUrl = histou_frame_url + getParamFrom + getParamTo + '&panelId='+source;

    //add timerange to iconlink, so the target graph matches the preview
    jQuery("#histou_graph_link").attr("href", histou_url + getParamFrom + getParamTo);

    jQuery('#pnpwaitimg').css('display', 'block');

    jQuery('#histou_iframe').load(function() {
      jQuery('#pnpwaitimg').css({'display': 'none', 'position': 'absolute'});
    })
    .error(function(err) {
      jQuery('#pnpwaitimg').css({'display': 'none', 'position': 'inherit'});
    });

    jQuery('#histou_iframe').attr('src', newUrl);

    // set style of buttons
    if(id) {
        id=id.replace(/^#/g, '');
        for(x=1;x<=5;x++) {
            obj = document.getElementById("histou_th"+x);
            styleElements(obj, "original", 1);
        }
        obj = document.getElementById(id);
        styleElements(obj, "commentEven pnpSelected", 1);
    } else {
        // get id from hash
        id = get_hash();
    }

    if(id) {
        // replace history otherwise we have to press back twice
        set_hash(id + "/" + start + "/" + end + "/" + source);
    }

    // reset reload timer for page
    resetRefresh();

    return false;
}

function move_histou_img(factor) {
    var urlArgs = new Object(toQueryParams(jQuery('#histou_iframe').attr('src')));

    start = urlArgs["from"];
    end   = urlArgs["to"];
    diff  = end - start;

    start = (parseInt(diff * factor) + parseInt(start)) / 1000;
    end   = (parseInt(diff * factor) + parseInt(end))   / 1000;

    return set_histou_img(start, end);
}

/* initialize all buttons */
function init_buttons() {
    jQuery('BUTTON.button').button();

    jQuery('A.report_button').button();
    jQuery('BUTTON.report_button').button();

    jQuery('.save_button').button({
        icons: {primary: 'ui-save-button'}
    });

    jQuery('.right_arrow_button').button({
        icons: {primary: 'ui-r-arrow-button'}
    });

    jQuery('.add_button').button({
        icons: {primary: 'ui-add-button'}
    });

    jQuery('.remove_button').button({
        icons: {primary: 'ui-remove-button'}
    }).click(function() {
        return confirm('really delete?');
    });
}


/*******************************************************************************
88888888888 db  8b           d8 88   ,ad8888ba,   ,ad8888ba,   888b      88
88         d88b `8b         d8' 88  d8"'    `"8b d8"'    `"8b  8888b     88
88        d8'`8b `8b       d8'  88 d8'          d8'        `8b 88 `8b    88
88aaaaa  d8'  `8b `8b     d8'   88 88           88          88 88  `8b   88
88""""" d8YaaaaY8b `8b   d8'    88 88           88          88 88   `8b  88
88     d8""""""""8b `8b d8'     88 Y8,          Y8,        ,8P 88    `8b 88
88    d8'        `8b `888'      88  Y8a.    .a8P Y8a.    .a8P  88     `8888
88   d8'          `8b `8'       88   `"Y8888Y"'   `"Y8888Y"'   88      `888
*******************************************************************************/
/* see https://github.com/antyrat/stackoverflow-favicon-counter for original source */
function updateFaviconCounter(value, color, fill, font, fontColor) {
    var faviconURL = url_prefix + 'themes/' + theme + '/images/favicon.ico';
    var context    = window.parent.frames ? window.parent.document : window.document;
    if(fill == undefined) { fill = true; }
    if(!font)      { font      = "10px Normal Tahoma"; }
    if(!fontColor) { fontColor = "#000000"; }

    var counterValue = null;
    if(jQuery.isNumeric(value)) {
        if(value > 0) {
            counterValue = ( value > 99 ) ? '\u221E' : value;
        }
    } else {
        counterValue = value;
    }

    // breaks on IE8 (and lower)
    try {
        if(counterValue != null) {
            var canvas       = document.createElement("canvas"),
                ctx          = canvas.getContext('2d'),
                faviconImage = new Image();

            canvas.width  = 16;
            canvas.height = 16;

            faviconImage.onload = function() {
                // draw original favicon
                ctx.drawImage(faviconImage, 0, 0);

                // draw counter rectangle holder
                if(fill) {
                    ctx.beginPath();
                    ctx.rect( 5, 6, 16, 10 );
                    ctx.fillStyle = color;
                    ctx.fill();
                }

                // counter font settings
                ctx.font      = font;
                ctx.fillStyle = fontColor;

                // get counter metrics
                var metrics  = ctx.measureText(counterValue );
                counterTextX = ( metrics.width >= 10 ) ? 6 : 9, // detect counter value position

                // draw counter on favicon
                ctx.fillText( counterValue , counterTextX , 15, 16 );

                // append new favicon to document head section
                faviconURL = canvas.toDataURL();
                jQuery('link[rel$=icon]', context).remove();
                jQuery('head', context).append( jQuery('<link rel="shortcut icon" type="image/x-icon" href="' + faviconURL + '"/>' ) );
            }
            faviconImage.src = faviconURL; // create original favicon
        } else {
            // if there is no counter value we draw default favicon
            jQuery('link[rel$=icon]', context).remove();
            jQuery('head', context).append( jQuery('<link rel="shortcut icon" type="image/x-icon" href="' + faviconURL + '"/>' ) );
        }
    } catch(err) { debug(err) }
}

/* save settings in a cookie */
function prefSubmitCounter(url, value) {
  if(value == false) {
      updateFaviconCounter(null);
  }

  cookieSave('thruk_favicon', value);
  // favicon is created from the parent page, so reload that one if we use frames
  try {
    window.parent.location.reload();
  } catch(e) {
    reloadPage();
  }
}


/* handle list wizard dialog */
var available_members = new Array();
var selected_members  = new Array();
var init_tool_list_wizard_initialized = {};
function init_tool_list_wizard(id, type) {
    id = id.substr(0, id.length -3);
    var tmp       = type.split(/,/);
    var input_id  = tmp[0];
    type          = tmp[1];
    var aggregate = Math.abs(tmp[2]);
    var templates = tmp[3] ? true : false;

    var $d = jQuery('#' + id + 'dialog')
      .dialog({
        dialogClass: 'dialogWithDropShadow',
        autoOpen:    false,
        width:       'auto',
        maxWidth:    1024,
        position:    'top',
        close:       function(event, ui) { ajax_search.hide_results(undefined, 1); return true; }
    });

    // initialize selected members
    selected_members   = new Array();
    selected_members_h = new Object();
    var options = [];
    var list = jQuery('#'+input_id).val().split(/\s*,\s*/);
    for(var x=0; x<list.length;x+=aggregate) {
        if(list[x] != '') {
            var val = list[x];
            for(var y=1; y<aggregate;y++) {
                val = val+','+list[x+y]
            }
            selected_members.push(val);
            selected_members_h[val] = 1;
            options.push(new Option(val, val));
        }
    }
    set_select_options(id+"selected_members", options, true);
    sortlist(id+"selected_members");
    reset_original_options(id+"selected_members");

    var strip = true;
    var url = 'status.cgi?format=search&amp;type='+type;
    if(window.location.href.match(/conf.cgi/)) {
        url = 'conf.cgi?action=json&amp;type='+type;
        strip = false;
    }

    // initialize available members
    available_members = new Array();
    jQuery("select#"+id+"available_members").html('<option disabled>loading...<\/option>');
    jQuery.ajax({
        url: url,
        type: 'POST',
        success: function(data) {
            var result = data[0]['data'];
            if(templates) {
                result = data[1]['data'];
            }
            var options = [];
            var size = result.length;
            for(var x=0; x<size;x++) {
                if(strip) {
                    result[x] = result[x].replace(/^(.*)\ \-\ .*/, '$1');
                }
                if(!selected_members_h[result[x]]) {
                    available_members.push(result[x]);
                    options.push(new Option(result[x], result[x]));
                }
            }
            set_select_options(id+"available_members", options, true);
            sortlist(id+"available_members");
            reset_original_options(id+"available_members");
        },
        error: function() {
            jQuery("select#"+id+"available_members").html('<option disabled>error<\/option>');
        }
    });

    // button has to be initialized only once
    if(init_tool_list_wizard_initialized[id] != undefined) {
        // reset filter
        jQuery('INPUT.filter_available').val('');
        jQuery('INPUT.filter_selected').val('');
        data_filter_select(id+'available_members', '');
        data_filter_select(id+'selected_members', '');
        $d.dialog('open');
        return;
    }
    init_tool_list_wizard_initialized[id] = true;

    jQuery('#' + id + 'accept').button({
        icons: {primary: 'ui-ok-button'}
    }).click(function() {
        data_filter_select(id+'available_members', '');
        data_filter_select(id+'selected_members', '');

        var newval = '';
        var lb = document.getElementById(id+"selected_members");
        for(i=0; i<lb.length; i++)  {
            newval += lb.options[i].value;
            if(i < lb.length-1) {
                newval += ',';
            }
        }
        jQuery('#'+input_id).val(newval);
        ajax_search.hide_results(undefined, 1);
        $d.dialog('close');
        return false;
    });

    $d.dialog('open');
    return;
}
