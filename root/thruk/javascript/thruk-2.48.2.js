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
var curRefreshVal    = 0;
var additionalParams = new Object();
var removeParams     = new Object();
var lastRowSelected;
var lastRowHighlighted;
var iPhone           = false;
if(window.navigator && window.navigator.userAgent) {
    iPhone           = window.navigator.userAgent.match(/iPhone|iPad/i) ? true : false;
}

// thruk global variables
var thrukState = window.thrukState || {
    lastUserInteraction: (new Date()).getTime(),
    lastPageFocus:       (new Date()).getTime()
};
thrukState.lastPageLoaded = (new Date()).getTime();

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

/* do initial things
 * - might be called multiple times, make sure events are not bound twice
 */
function init_page() {
    current_backend_states = {};
    for(var key in initial_backends) { current_backend_states[key] = initial_backends[key]['state']; }
    jQuery('input.deletable').each(function(i, el) {
        // do not add twice
        if(el && el.parentNode && jQuery(el.parentNode).hasClass("deleteicon")) {
            return;
        }
        var extraClass = "";
        if(jQuery(el).hasClass("w-full")) { extraClass = "w-full"; }
        jQuery(el)
            .wrap('<div class="deleteicon '+extraClass+'" />')
            .after(jQuery('<button type="reset" style="display:none;">&times;</button>')
                .click(function() {
                    var This = this;
                    jQuery(This).hide();
                    jQuery(This).prev("INPUT").val("").trigger("change").trigger("keyup");
                    if(jQuery(This).hasClass("autosubmit")) {
                        window.setTimeout(function() {
                            jQuery(This).parents("FORM").submit();
                        }, 200);
                    }
                })
            )
            .on("keyup focus change", function() {
                var This = this;
                jQuery(This).next("BUTTON").each(function(x, b) {
                    if(jQuery(This).val() == "") {
                        jQuery(b).hide();
                    } else {
                        jQuery(b).show();
                    }
                });
            });
    });

    var urlArgs  = toQueryParams();
    if(sort_options && sort_options.type != null && urlArgs.sorttype == null) {
        urlArgs.sorttype   = sort_options.type;
        urlArgs.sortoption = sort_options.option;
    }
    jQuery("A.sort-by").each(function(i, el) {
        var This = this;
        var found = false;
        var className;
        for(var key in This.dataset) {
            if(key.match(/^sortoption/i) && urlArgs[key.toLowerCase()] == This.dataset[key]) {
                found = true;
            }
            if(key.match(/^sorttype/i)) {
                if(urlArgs[key.toLowerCase()] == 1) {
                    className = "sort1";
                } else {
                    className = "sort2";
                }
            }
        }
        if(found) {
            jQuery(This).addClass(className);
        }
    });
    jQuery("A.sort-by").off("click").on("click", function(evt) {
        // prevent fireing from dbl click
        if(evt.originalEvent.detail > 1){
            return false;
        }
        var This = this;
        thrukState.sortClickTimer = window.setTimeout(function() {
            window.clearTimeout(thrukState.sortClickTimer);
            handleSortHeaderClick(This);
        }, 300);
        return(false);
    });

    // try to match a navigation entry
    try {
        check_side_nav_active_item(window.document);
    }
    catch(err) {
        console.log(err);
    }

    jQuery("A.js-modal-command-link")
        .off("click")
        .on("click", function(e) {
            e.preventDefault();
            openModalCommand(this);
            return false;
        });

    jQuery("DIV.js-perf-bar").each(function(i, el) {
        perf_table(el);
    });

    jQuery(".fittext").each(function(i, el) {
        fitText(el);
    });

    var saved_hash = readCookie('thruk_preserve_hash');
    if(saved_hash != undefined) {
        set_hash(saved_hash);
        cookieRemove('thruk_preserve_hash');
    }

    // add title for things that might overflow
    jQuery(document).on('mouseenter', '.truncate', function() {
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
    cookieSave("thruk_screen", JSON.stringify(getScreenData()));
    jQuery(document).off("resize").on("resize", function() {
        cookieSave("thruk_screen", JSON.stringify(getScreenData()));
    });
    jQuery(window).off("resize").on("resize", function() {
        cookieSave("thruk_screen", JSON.stringify(getScreenData()));
    });

    /* show calendar popups for these */
    jQuery("INPUT.cal_popup, INPUT.cal_popup_range, INPUT.cal_popup_clear").off("click").on("click", show_cal);
    jQuery("IMG.cal_popup, I.cal_popup").off("click").on("click", show_cal).addClass("clickable");

    /* toggle passwords */
    jQuery("I.togglePassword").off("click").on("click", togglePasswordVisibility).addClass("clickable");

    var params = toQueryParams();
    if(params["scrollTo"]) {
        applyScroll(params["scrollTo"]);
    }

    cleanUnderscoreUrl();

    if(refresh_rate) {
        try {
            if(window.parent && window.parent.location && String(window.parent.location.href).match(/\/panorama\.cgi/)) {
                stopRefresh();
                jQuery("#refresh_label").html("");
            } else if(String(window.location.href).match(/\/panorama\.cgi/)) {
                stopRefresh();
                jQuery("#refresh_label").html("");
            } else {
                refreshPage = 1;
                setRefreshRate(refresh_rate);
            }
        } catch(err) {
            console.log(err);
        }
    }

    jQuery('.js-striped').each(function(i, el) {
        applyRowStripes(el);
    });

    initLastUserInteraction();
    initNavigation();

    thrukState.lastPageLoaded = (new Date()).getTime();
    jQuery(window).off("focus").on("focus", function() {
        if(refresh_rate != null && refreshPage && curRefreshVal <= 5) {
            reloadPage();
        }
    });

    // break from old frame mode
    try {
        if(window.frameElement && window.frameElement.tagName == "FRAME" && window.top && window.top.location != location) {
            if(String(window.top.location).match(/\/thruk\/#cgi-bin\//)) {
                if(String(window.top.location).replace(/\/thruk\/#cgi-bin\//, "/thruk/cgi-bin/") == String(window.location)) {
                    window.top.location = window.location;
                }
            }
        }
    } catch(err) { console.log(err); }
}

function initLastUserInteraction() {
    jQuery(window)
        .off("mousewheel DOMMouseScroll click keyup")
        .on("mousewheel DOMMouseScroll click keyup", updateLastUserInteraction);

    jQuery(window).off("blur").on("blur", function() {
        thrukState.lastPageFocus = (new Date()).getTime();
    });
    jQuery(window).off("focus").on("focus", function() {
        thrukState.lastPageFocus = (new Date()).getTime();
    });
}


function applyScroll(scrollTo) {
    var scrolls = scrollTo.split("_");
    for(var i = 0; i < scrolls.length; i++) { scrolls[i] = Number(scrolls[i]); }
    if(scrolls[0] > 0 || scrolls[1] > 0) {
        var main = jQuery("MAIN")[0];
        if(main) {
            main.scroll(scrolls[0], scrolls[1]);
        }
    }
    if(scrolls[3] != null && (scrolls[2] > 0 || scrolls[3] > 0)) {
        var mainTable = jQuery(".mainTable")[0];
        if(mainTable) {
            mainTable.scroll(scrolls[2], scrolls[3]);
        }
    }
    if(scrolls[4] != null && scrolls[4] > 0) {
        var navTable = jQuery("DIV.navsectionlinks.scrollauto")[0];
        if(navTable) {
            navTable.scroll(0, scrolls[4]);
        }
    }
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

function getScreenData() {
    var data = {
        height: jQuery(document).height(),
        width:  jQuery(document).width()
    }
    return(data);
}

var error_count = 0;
function thruk_onerror(msg, url, line, col, error) {
  if(error_count > 5) {
    console.log("too many errors, not logging any more...");
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
    var text = getErrorText(error);
    if(show_error_reports == "server" || show_error_reports == "both") {
        sendJSError(url_prefix+"cgi-bin/remote.cgi?log", text);
    }
    if(show_error_reports == "1" || show_error_reports == "both") {
        showBugReport('bug_report', text);
    }
  }
  catch(e) { console.log(e); }
  return false;
}

/* remove ugly ?_=... from url */
function cleanUnderscoreUrl() {
    var newUrl = window.location.href;
    if(history.replaceState) {
        newUrl = cleanUnderscore(newUrl);
        try {
            history.replaceState({}, "", newUrl);
        }
        catch(err) { console.log(err) }
    }
}

function cleanUnderscore(str) {
    str = str.replace(/\?_=\d+/g, '?');
    str = str.replace(/\&_=\d+/g, '');
    str = str.replace(/\?scrollTo=[_\d\.]+/g, '?');
    str = str.replace(/\&scrollTo=[_\d\.]+/g, '');
    str = str.replace(/\?autoShow=\w+/g, '?');
    str = str.replace(/\&autoShow=\w+/g, '');
    str = str.replace(/\?$/g, '');
    str = str.replace(/\?&/g, '?');
    return(str);
}

function updateLastUserInteraction() {
    thrukState.lastUserInteraction = (new Date()).getTime();
}

/* save scroll value */
function saveScroll() {
    var scroll = getPageScroll();

    if(!scroll || scroll.match(/^[0:]*$/)) {
        delete additionalParams['scrollTo'];
        removeParams['scrollTo'] = true;
    }

    additionalParams['scrollTo'] = scroll;
    delete removeParams['scrollTo'];
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
  if(jQuery(pane).hasClass("js-hiddenByClass") || jQuery(pane).hasClass("hidden")) {
    jQuery(pane).addClass("hidden").removeClass("js-hiddenByClass");
  } else {
    pane.style.display    = 'none';
    pane.style.visibility = 'hidden';
  }

  toogleIconImage(icon);
}

/* show a element by id */
var close_elements = [];
function showElement(id, icon, bodyclose, bodycloseelement, bodyclosecallback) {
  var pane;
  if(typeof(id) == 'object') {
    pane = id;
    if(pane.id) {
        id = pane.id;
    }
  }
  else {
    pane = document.getElementById(id);
  }
  if(!pane) {
    if(thruk_debug_js) { alert("ERROR: got no element for id in showElement(): " + id); }
    return;
  }
  if(jQuery(pane).hasClass("hidden")) {
    jQuery(pane).removeClass("hidden").addClass("js-hiddenByClass");
  } else {
    pane.style.display    = '';
    pane.style.visibility = 'visible';
  }

  toogleIconImage(icon);

  if(bodyclose) {
    add_body_close(id, icon, bodycloseelement, bodyclosecallback);
  }
}

/* add_body_close(id, icon, bodycloseelement, bodyclosecallback)
 *
 * adds element to document click close watcher
 * arguments:
 *  - id:                id of the element to hide
 *  - icon:              icon will be toggled (optional)
 *  - bodycloseelement:  jquery selector to test if click is inside those elements (optional)
 *  - bodyclosecallback: callback will be run after element got closed (optional)
 */
function add_body_close(id, icon, bodycloseelement, bodyclosecallback) {
    remove_close_element(id);
    window.setTimeout(function() {
        var found = false;
        jQuery.each(close_elements, function(key, el) {
            if(el.id == id) {
                found = true;
            }
        });
        if(!found) {
            // close all other close elements, unless this one is a sub item of it
            jQuery(close_elements).each(function(i, el) {
                var inside = is_el_subelement(document.getElementById(id), document.getElementById(el.id));
                if(!inside) {
                    close_and_remove_event_run(el);
                    remove_close_element(el.id);
                }
            });

            close_elements.push({
                "id":       id,
                "icon":     icon,
                "elements": bodycloseelement,
                "close_cb": bodyclosecallback
            })
            addEvent(document, 'click', close_and_remove_event);
            addEvent(document, 'keyup', close_and_remove_event);
        }
    }, 50);
}

function toogleIconImage(icon) {
  if(!icon) { return; }
  var img = document.getElementById(icon);
  if(!img) { return; }
  if(img.tagName != "I") { return; }

  if(jQuery(img).hasClass("uil-arrow-from-top")) {
    jQuery(img).removeClass("uil-arrow-from-top");
    jQuery(img).addClass("uil-top-arrow-to-top");
  }
  else if(jQuery(img).hasClass("uil-top-arrow-to-top")) {
    jQuery(img).addClass("uil-arrow-from-top");
    jQuery(img).removeClass("uil-top-arrow-to-top");
  }
}

function setFormBtnSpinner(form) {
    jQuery(form).find("[type=submit], BUTTON.submit").each(function(i, btn) {
        setBtnSpinner(btn);
    });
}

function return_false() {
    return false;
}

function setBtnSpinner(btn, skipTimeout) {
    jQuery(btn).find("I").css("display", "none");
    jQuery(btn).find('div.spinner').remove();
    jQuery(btn).find('I.uil-exclamation').remove();
    jQuery(btn).find('I.fa-check').remove();
    if(jQuery(btn).find("I").length > 0) {
        jQuery(btn).find("I").after('<div class="spinner mr-1"><\/div>');
    } else {
        jQuery(btn).prepend('<div class="spinner mr-1"><\/div>');
    }
    var disableTimer = window.setTimeout(function() {
        // disable delayed, otherwise chrome won't send the form
        setBtnDisabled(btn);
    }, 300);
    jQuery(btn).data("distimer", disableTimer);
    var el = jQuery(btn).first();
    if(el.tagName == "A") {
        el.dataset["href"] = el.href;
        jQuery(btn).on("click", return_false);
        el.href = "#";
    }
    if(!skipTimeout) {
        var timer = window.setTimeout(function() {
            // seomthing didn't work, reset
            setBtnError(btn, "timeout while processing the request");
        }, 30000);
        jQuery(btn).data("timer", timer);
    }
}

function setBtnClearTimer(btn) {
    var timer = jQuery(btn).data("timer");
    if(timer) {
        window.clearTimeout(timer);
    }
    timer = jQuery(btn).data("distimer");
    if(timer) {
        window.clearTimeout(timer);
    }
}

function setBtnNoSpinner(btn) {
    jQuery(btn).find('div.spinner').remove();
    setBtnEnabled(btn);
    jQuery(btn).find("I").css("display", "");
    setBtnClearTimer(btn);
}

function setBtnError(btn, title) {
    setBtnClearTimer(btn);
    jQuery(btn).find('div.spinner').remove();
    jQuery(btn).find('I.uil-exclamation').remove();
    jQuery(btn).find('I.fa-check').remove();
    jQuery(btn).find("I").css("display", "none");
    if(jQuery(btn).find("I").length > 0) {
        jQuery(btn).find("I").after('<I class="uil uil-exclamation round yellow small mr-1"><\/I>');
    } else {
        jQuery(btn).prepend('<I class="uil uil-exclamation round yellow small mr-1"><\/I>');
    }
    setBtnEnabled(btn);
    jQuery(btn).prop('title', title)
    var el = jQuery(btn).first();
    if(el.tagName == "A") {
        el.href = el.dataset["href"];
        jQuery(btn).off("click", return_false);
    }
}

function setBtnSuccess(btn, title) {
    setBtnClearTimer(btn);
    jQuery(btn).find('div.spinner').remove();
    jQuery(btn).find('I.uil-exclamation').remove();
    jQuery(btn).find("I").css("display", "none");
    if(jQuery(btn).find("I").length > 0) {
        jQuery(btn).find("I").after('<I class="fa-solid fa-check round small green mr-1"><\/I>');
    } else {
        jQuery(btn).prepend('<I class="fa-solid fa-check round small green mr-1"><\/I>');
    }
    jQuery(btn).prop('title', title)
    setBtnEnabled(btn);
    var el = jQuery(btn).first();
    if(el.tagName == "A") {
        el.href = el.dataset["href"];
        jQuery(btn).off("click", return_false);
    }
}

function setBtnDisabled(btn) {
    jQuery(btn).prop('disabled', true).addClass(["opacity-50", "not-clickable"]);
}

function setBtnEnabled(btn) {
    jQuery(btn).prop('disabled', false).removeClass(["opacity-50", "not-clickable"]);
}

function toggleAccordion(btn, cb) {
    var closed = jQuery(btn).next("DIV").css("max-height") == "0px";
    if(closed) {
        openAccordion(btn, cb);
        closeAccordionAllExcept(btn);
    } else {
        closeAccordionAll(btn);
    }
}

function openAccordion(btn, cb) {
    var panel = jQuery(btn).next("DIV");
    if(!panel || panel.length == 0) {
        if(thruk_debug_js) { alert("ERROR: got no panel for id in openAccordion(): " + btn); }
        return;
    }
    jQuery(panel).css({
        "transition":"max-height 0.2s ease-out"
    });
    jQuery(panel).css({
        "max-height": panel[0].scrollHeight+"px"
    }).addClass("active");
    jQuery(btn).addClass("active");
    if(cb) {
        cb();
    }
    window.setTimeout(function() {
    jQuery(panel).css({
        "max-height": "max-content"
    });
    }, 200);
}

function closeAccordionAll(btn) {
    jQuery(btn.parentNode).find('> BUTTON').next("DIV").css('max-height', '0').removeClass("active");
    jQuery(btn.parentNode).find('> BUTTON').removeClass("active");
}

function closeAccordionAllExcept(btn) {
    jQuery(btn.parentNode).find('> BUTTON').each(function(i, b) {
        if(b != btn) {
            jQuery(b).next("DIV").css('max-height', '0').removeClass("active");
            jQuery(b).removeClass("active");
        }
    });
}

function handleSortHeaderClick(el) {
    var This    = el;
    var urlArgs = toQueryParams();
    var sortoptionkey;
    var sorttypekey;
    for(var key in This.dataset) {
        if(key.match(/^sortoption/i)) {
            additionalParams[key.toLowerCase()] = This.dataset[key];
            sortoptionkey = key;
        }
        if(key.match(/^sorttype/i)) {
            additionalParams[key.toLowerCase()] = This.dataset[key];
            sorttypekey = key;
        }
    }
    jQuery("A.sort-by").removeClass(["sort1", "sort2"]);
    if(urlArgs[sorttypekey.toLowerCase()] && urlArgs[sorttypekey.toLowerCase()] == 1 && urlArgs[sortoptionkey.toLowerCase()] == This.dataset[sortoptionkey]) {
        additionalParams[sorttypekey.toLowerCase()] = 2;
        jQuery(This).addClass(["sort2"]);
    } else {
        jQuery(This).addClass(["sort1"]);
    }
    removeParams['page'] = true;
    reloadPage(50, true);
}

function openModalCommand(el) {
    var append = "?modal=1";
    if(el.href.match(/\?/)) {
        append = "&modal=1";
    }
    openModalWindowUrl(el.href+append, function() {
        var inputs = jQuery("#modalFG INPUT[required][value='']");
        if(inputs.length == 0) {
            inputs = jQuery("#modalFG INPUT[value='']");
        }
        if(inputs.length == 0) {
            inputs = jQuery("#modalFG BUTTON[type='submit']");
        }
        jQuery(inputs).first().focus();
    });
}

function openModalWindowUrl(url, callback) {
    if(!has_jquery_ui()) {
        load_jquery_ui(function() {
            openModalWindowUrl(url, callback);
        });
        return;
    }
    var content = ''
        +'  <div class="card w-[200px] mx-auto">'
        +'    <div class="head"><h3>Loading...<\/h3><\/div>'
        +'    <div class="body flexcol">'
        +'      <div class="spinner w-10 h-10"><\/div>'
        +'      <button class="w-20 self-center" onclick="closeModalWindow()">Cancel<\/button>'
        +'    <\/div>'
        +'  <\/div>';
    openModalWindow(content);

    jQuery('#modalFG').load(url, {}, function(text, status, req) {
        if(status == "error") {
            jQuery('#modalFG DIV.body').prepend('<div class="textALERT">'+req.status+': '+req.statusText+'<\/div>');
            jQuery('#modalFG DIV.spinner').remove();
        } else {
            init_page();
            jQuery('#modalFG .card').draggable({ handle: "H3, .head" });
            jQuery('#modalFG H3, #modalFG .head').css("cursor", "move");
        }
        if(callback) { callback(text, status, req); }
    });
    return false;
}

var modalElement  = null;
var modalElementP = null;
function openModalWindow(content) {
    jQuery(document.body).append('<div id="modalBG" class="modalBG"><\/div>');
    if(content && content.tagName) {
        modalElementP = content.parentNode;
        jQuery(document.body).append('<div id="modalFG" class="modalFG"><\/div>');
        jQuery('#modalFG').append(jQuery(content));
        content.style.display = "";
        modalElement = content;
    } else {
        jQuery(document.body).append('<div id="modalFG" class="modalFG">'+content+'<\/div>');
    }
    jQuery('#modalFG .card').draggable({ handle: "H3, .head" });
    addEvent(document, 'keydown', closeModalWindowOnEscape);
    return false;
}

function closeModalWindow() {
    if(modalElement) {
        modalElement.style.display = "none";
        jQuery(modalElementP).append(jQuery(modalElement));
        modalElement  = null;
        modalElementP = null;
    }
    jQuery('#modalBG').remove();
    jQuery('#modalFG').remove();
    jQuery('DIV.daterangepicker').remove();
    removeEvent(document, 'keydown', closeModalWindowOnEscape);
}

function closeModalWindowOnEscape(evt) {
    evt = (evt) ? evt : ((window.event) ? event : null);
    var keyCode = evt.keyCode;
    if(keyCode == 27) {
        if(!evt.target || evt.target.tagName != "INPUT") {
            closeModalWindow();
            evt.preventDefault ? evt.preventDefault() : evt.returnValue = false;
            return false;
        }
    }
    return(true);
}

// activate current page in navigation
function check_side_nav_active_item(ctx) {
    if(jQuery('#nav-container').hasClass('collapsed')) { return; }
    var urlArgs = toQueryParams();
    var page    = window.location.href.toString().replace(/\#.*/, '').replace(/^.*\//, '').replace(/\?.*$/, '');

    // compare complete url
    var found   = false;
    var pageUrl = window.location.href.toString();
    jQuery("UL.navsectionlinks A", ctx).each(function(i, el) {
        if(el.href.toString() == pageUrl) {
            found = true;
        }
        if(found) {
            jQuery('UL.navsectionlinks A', ctx).removeClass("active");
            jQuery(el).addClass("active");
            return false;
        }
    });
    if(found) { return; }

    // compare all args from the nav link (with value)
    jQuery("UL.navsectionlinks A", ctx).each(function(i, el) {
        var navPage = el.href.toString().replace(/^.*\//, '').replace(/\?.*$/, '');
        if(navPage == page) {
            var href    = el.href.replace(/^.*\?/, '');
            var navArgs = toQueryParams(href);
            if(Object.keys(navArgs).length == 0) { return(true); }
            found = true;
            for(var key in navArgs) {
                if(!urlArgs[key] || urlArgs[key] != navArgs[key]) {
                    found = false;
                }
            }
            if(found) {
                jQuery('UL.navsectionlinks A', ctx).removeClass("active");
                jQuery(el).addClass("active");
                return false;
            }
        }
    });
    if(found) { return; }

    // compare all args from the nav link (only keyword)
    jQuery("UL.navsectionlinks A", ctx).each(function(i, el) {
        var navPage = el.href.toString().replace(/^.*\//, '').replace(/\?.*$/, '');
        if(navPage == page) {
            var href    = el.href.replace(/^.*\?/, '');
            var navArgs = toQueryParams(href);
            if(Object.keys(navArgs).length == 0) { return(true); }
            found = true;
            for(var key in navArgs) {
                if(!urlArgs[key] || urlArgs[key] != navArgs[key]) {
                    found = false;
                }
            }
            if(found) {
                jQuery('UL.navsectionlinks A', ctx).removeClass("active");
                jQuery(el).addClass("active");
                return false;
            }
        }
    });
    if(found) { return; }

    // compare some main args
    var keyArgs = ["type", "style"];
    jQuery("UL.navsectionlinks A", ctx).each(function(i, el) {
        var navPage = el.href.toString().replace(/^.*\//, '').replace(/\?.*$/, '');
        if(navPage == page) {
            var href    = el.href.replace(/^.*\?/, '');
            var navArgs = toQueryParams(href);
            found = true;
            jQuery(keyArgs).each(function(i, key) {
                if(urlArgs[key]) {
                    if(!navArgs[key] || urlArgs[key] != navArgs[key]) {
                        found = false;
                    }
                } else if(!urlArgs[key] && navArgs[key]) {
                    found = false;
                }
            });
            if(found) {
                jQuery('UL.navsectionlinks A', ctx).removeClass("active");
                jQuery(el).addClass("active");
                return false;
            }
        }
    });

    // compare only main page
    jQuery("UL.navsectionlinks A", ctx).each(function(i, el) {
        var navPage = el.href.toString().replace(/^.*\//, '').replace(/\?.*$/, '');
        if(navPage == page) {
            if(page != "extinfo.cgi") {
                found = true;
                jQuery('UL.navsectionlinks A', ctx).removeClass("active");
                jQuery(el).addClass("active");
                return false;
            }
        }
    });
}

/* set navigation style (from header prefs */
function setNavigationStyle(val) {
    menuState['cl'] = val;

    jQuery("input[type='radio'][name='navigation']").prop("checked", false);
    jQuery("#nav"+val).prop("checked", true);

    // reset
    showElement("navbar");
    remove_close_element('navbar');
    jQuery('BODY').removeClass(['topnav', 'topNavOpen']);
    jQuery('#nav-container').removeClass('collapsed');

    // collapsed menu
    if(val == 1) {
        jQuery('#nav-container').addClass('collapsed');
        jQuery("UL.navsectionlinks").css("display", "");
    }
    // hover menu
    if(val == 2) {
        jQuery('BODY').addClass('topnav');
    }

    cookieSave('thruk_side', toQueryString(menuState));
}

/* initialize navigation buttons */
function initNavigation() {
    // make them toggle
    jQuery('A.navsectiontitle').off("click").click(function() {
        var title = this.text.trim().toLowerCase().replace(/ /g, '_');
        if(jQuery('#nav-container').hasClass('collapsed')) { return; }
        jQuery(this).parent().children("UL.navsectionlinks").slideToggle('fast', function() {
            menuState[title] = this.style.display == 'none' ? 0 : 1;
            cookieSave('thruk_side', toQueryString(menuState));
        });
    });

    jQuery('UL.navsectionlinks A').off("click").click(function() {
        jQuery('UL.navsectionlinks A').removeClass("active");
        jQuery(this).addClass("active");
    });

    jQuery('I.navsectionsubtoggle').off("click").click(function() {
        var title   = jQuery(this).prev("A").text().trim().toLowerCase().replace(/ /g, '_');
        var section = jQuery(this).parent("LI").parents("LI").first().find('A').first().text().trim().toLowerCase().replace(/ /g, '_');
        title = section+'.'+title;
        jQuery(this).next("UL").slideToggle('fast', function() {
            menuState[title] = this.style.display == 'none' ? 0 : 1;
            cookieSave('thruk_side', toQueryString(menuState));
        });
    });

    // button to collapse side menu
    jQuery('.js-menu-collapse').off("click").click(function() {
        jQuery('#nav-container').toggleClass('collapsed');
        if(jQuery('#nav-container').hasClass('collapsed')) {
            setNavigationStyle(1);
        } else {
            setNavigationStyle(0);
        }
    });
    // button to enable overlay menu
    jQuery('.js-menu-hide').off("click").click(function() {
        jQuery('BODY').toggleClass('topnav');
        if(jQuery('BODY').hasClass('topnav')) {
            setNavigationStyle(2);
        } else {
            setNavigationStyle(0);
        }
    });
    // toggle overlay menu button display
    jQuery('#mainNavBtn').off("click").click(function() {
        toggleClass('BODY', 'topNavOpen');
        showElement("navbar");
        jQuery('#nav-container').removeClass('collapsed');
        if(jQuery('BODY').hasClass('topNavOpen')) {
            add_body_close('navbar', null, null, function() {
                jQuery('BODY').removeClass('topNavOpen');
                showElement("navbar");
            });
        }
        return false;
    });

    if(jQuery('#nav-container').hasClass('collapsed')) {
        jQuery("UL.navsectionlinks").css("display", "");
    }
}

function switchTheme(sel) {
    var theme = sel;
    if(sel && sel.tagName) {
        theme = jQuery(sel).val();
    }
    if(is_array(theme)) {
        theme = theme[0];
    }
    cookieSave('thruk_theme', theme);
    jQuery("LINK.maintheme").attr("href", url_prefix+"themes/"+theme+"/stylesheets/"+theme+".css");
    jQuery("IMG").each(function() {
      this.src = this.src.replace(/\/themes\/.*?\//, "/themes/"+theme+"/");
    });
}

/* remove element from close elements list */
function remove_close_element(id) {
    var new_elems = [];
    jQuery.each(close_elements, function(key, el) {
        if(el.id != id) {
            new_elems.push(el);
        }
    });
    close_elements = new_elems;
    if(new_elems.length == 0) {
        removeEvent(document, 'click', close_and_remove_event);
        removeEvent(document, 'keyup', close_and_remove_event);
    }
}

/* close and remove eventhandler */
function close_and_remove_event(evt) {
    evt = (evt) ? evt : ((window.event) ? event : null);
    if(close_elements.length == 0) {
        return;
    }

    // close on level of items on escape
    var keyCode = evt.keyCode;
    if(keyCode != undefined) {
        if(keyCode == 27) {
            if(!evt.target || evt.target.tagName != "INPUT") {
                evt.preventDefault ? evt.preventDefault() : evt.returnValue = false;

                var toClose = close_elements.pop();
                close_and_remove_event_run(toClose);
                return false;
            }
        }
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

    var toClose = close_elements.pop();
    var obj = document.getElementById(toClose.id);
    var inside = checkEvtinElement(obj, evt, x, y);

    if(!inside && toClose.elements) {
        jQuery(toClose.elements).each(function(i, el) {
            inside = checkEvtinElement(el, evt, x, y);
            if(inside) {
                return false; // break jQuery each loop
            }
        });
    }

    if(evt && inside) {
        close_elements.push(toClose);
    } else {
        close_and_remove_event_run(toClose);
    }

    if(close_elements.length == 0) {
        removeEvent(document, 'click', close_and_remove_event);
        removeEvent(document, 'keyup', close_and_remove_event);
    }
}

function close_and_remove_event_run(toClose) {
    hideElement(toClose.id, toClose.icon); // must before the callback because they might check visibility
    if(toClose.close_cb) {
        toClose.close_cb();
    }
}

/* returns true if x/y coords are inside the area of the object */
function checkEvtinElement(obj, evt, x, y) {
    var inside = false;
    if(x && y && obj) {
        inside = checkXYinElement(obj, x, y);
    }

    // make sure our event target is not a subelement of the panel to close
    if(!inside && evt) {
        inside = is_el_subelement(evt.target, obj);
        if(inside) {
            //hilight_obj_area(evt.target, 1000, 'green');
            //hilight_obj_area(obj, 1000, 'green');
        }
    }
    return(inside);
}

/* returns true if x/y coords are inside the area of the object */
function checkXYinElement(obj, x, y) {
    var inside = false;
    var width  = jQuery(obj).outerWidth();
    var height = jQuery(obj).outerHeight();
    var offset = jQuery(obj).offset();

    var x1 = offset['left'] - 5;
    var x2 = offset['left'] + width  + 5;
    var y1 = offset['top']  - 5;
    var y2 = offset['top']  + height + 5;

    // check if we clicked inside or outside the object we have to close
    if( x >= x1 && x <= x2 && y >= y1 && y <= y2 ) {
        inside = true;
    }

    // hilight checked area
    //hilight_area(x1, y1, x2, y2, 1000, inside ? 'green' : 'red');
    return(inside);
}

function toggleFilterPopup(id) {
    toggleElement(id, null, true, '#search-results');
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
    el.innerHTML = "<div class='spinner w-8 h-8 mx-[50%] my-8'>";
    showElement(id, undefined, bodyclose);
    jQuery('#'+id).load(url_prefix+'cgi-bin/parts.cgi?part='+part+append, {}, function(text, status, req) {
        showElement(id, undefined, bodyclose);
        resetRefresh();
    });
}

/* toggle a element by id
   returns:
    - true:  if element is visible now
    - false: if element got switched to invisible
 */
function toggleElement(id, icon, bodyclose, bodycloseelement, bodyclosecallback) {
  var pane = document.getElementById(id) || jQuery(id)[0];
  if(!pane) {
    if(thruk_debug_js) { alert("ERROR: got no panel for id in toggleElement(): " + id); }
    return false;
  }
  resetRefresh();
  if(pane.style.visibility == "hidden" || pane.style.display == 'none' || jQuery(pane).hasClass("hidden")) {
    showElement(id, icon, bodyclose, bodycloseelement, bodyclosecallback);
    return true;
  }
  else {
    hideElement(id, icon);
    // if we hide something, check if we have to close others too
    // but only if the element to close is not a subset of an existing to_close_element
    var inside = false;
    jQuery.each(close_elements, function(key, value) {
        var obj = document.getElementById(value.id);
        inside = is_el_subelement(pane, obj);
        if(inside) {
            return false; // break jQuery.each
        }

        if(value.elements) {
            jQuery(value.elements).each(function(i, e) {
                inside = is_el_subelement(pane, e);
                if(inside) {
                    return false; // break jQuery.each
                }
            });
        }
        if(inside) {
            return false; // break jQuery.each
        }
    });
    if(!inside) {
        try {
          close_and_remove_event();
        } catch(err) { console.log(err); };
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
function prefSubmitSound(url, value) {
  cookieSave('thruk_sounds', value);
  reloadPage(50, true);
}

/* save something in a cookie */
function cookieSave(name, value, expires, domain) {
  var now       = new Date();
  var expirestr = '';

  // let the cookie expire in 10 years by default
  if(expires == undefined) { expires = 10*365*86400; }

  if(expires > 0) {
    expires   = new Date(now.getTime() + (expires*1000));
    expirestr = " expires=" + expires.toGMTString();
  }

  var cookieStr = name+"="+value+"; path="+cookie_path+";"+expirestr;

  if(domain) {
    cookieStr += ";domain="+domain;
  }

  cookieStr += "; samesite=lax";

  // cleanup befor we set new cookie
  cookieRemoveAll(name);

  cookieStr += ";";
  document.cookie = cookieStr;
}

/* remove existing cookie */
function cookieRemove(name) {
    cookieRemoveAll(name);
}

/* remove existing cookie for all sub/domains */
function cookieRemoveAll(name) {
    var path_info = document.location.pathname;
    path_info = path_info.replace(/^\//, "");        // strip off leading slash
    path_info = path_info.replace(/\/[^\/]+$/, "/"); // strip off file part
    var paths = ["/"];
    var path  = "";
    jQuery.each(path_info.split("/"), function(key, part) {
        path = path+"/"+part;
        paths.push(path+"/");
    });

    var domain = "";
    jQuery.each(document.location.hostname.split(".").reverse(), function(key, hostpart) {
        if(domain == "") {
            domain = hostpart;
            return true;
        } else {
            domain = hostpart+"."+domain;
        }
        jQuery.each(paths, function(key2, path) {
            document.cookie = name+"=del; path="+path+";domain="+domain+";expires=Thu, 01 Jan 1970 00:00:01 GMT; samesite=lax;";
        });
    });
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
var remainingRefresh;
function setRefreshRate(rate) {
  if(typeof thruk_static_export !== 'undefined' && thruk_static_export) { return; }
  if(typeof refresh_rate !== 'undefined' && refresh_rate) {
    jQuery("#refresh_label").html(" (&infin;"+refresh_rate+"s)");
  }
  if(rate >= 0 && rate < 20) {
      // check lastUserInteraction date to not refresh while user is interacting with the page
      if(thrukState.lastUserInteraction > ((new Date).getTime() - 20000)) {
          rate = 20;
      }
      // background tab, do not refresh unnecessarily unless focus was gone a few moments ago (3min), but refresh at least every 3 hours
      if(document.visibilityState && document.visibilityState != 'visible' && thrukState.lastPageFocus < ((new Date).getTime() - 180000) && thrukState.lastPageLoaded > ((new Date).getTime() - (3*3600*1000))) {
        jQuery("#refresh_label").html(" <span class='textALERT'>(paused)<\/span>");
        rate = 2;
      }
      // do not refresh when modal window is open
      if(document.getElementById('modalBG')) {
        jQuery("#refresh_label").html(" <span class='textALERT'>(paused)<\/span>");
        rate = 20;
      }
      // do not refresh when dev tools are open
      if((window.outerHeight-window.innerHeight)>250 || (window.outerWidth-window.innerWidth)>250) {
        jQuery("#refresh_label").html(" <span class='textALERT'>(dev tools open, paused)<\/span>");
        rate = 20;
      }
  }
  remainingRefresh = rate;
  curRefreshVal = rate;
  var obj = document.getElementById('refresh_rate');
  if(refreshPage == 0) {
    if(obj) {
        obj.innerHTML = "<span>This page will not refresh automatically<\/span> <input type='button' class='inline-block' value='refresh now' onClick='reloadPage(50, true)'>";
    }
  }
  else {
    if(obj) {
        var msg = "Update in "+rate+" seconds";
        var span = document.getElementById('refresh_rate_info');
        if(span) {
            span.innerHTML = msg;
        } else {
            obj.innerHTML = "<span id='refresh_rate_info'>"+msg+"<\/span> <input type='button' class='inline-block' value='stop' onClick='stopRefresh()'>";
        }
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
        reloadPage(50, true);
      }
    }
    if(rate > 0) {
      newRate = rate - 1;
      window.clearTimeout(thrukState.refreshTimer);
      thrukState.refreshTimer = window.setTimeout(function() {
          setRefreshRate(newRate);
      }, 1000);
    }
  }
}

/* reset refresh interval */
function resetRefresh() {
  window.clearTimeout(thrukState.refreshTimer);
  if( typeof refresh_rate == "number" ) {
    refreshPage = 1;
    setRefreshRate(refresh_rate);
  } else {
    stopRefresh();
  }
}

/* stops the reload interval */
function stopRefresh(silent) {
  refreshPage = 0;
  if(!silent) {
    jQuery("#refresh_label").html(" <span class='textALERT'>(stopped)<\/span>");
  }
  window.clearTimeout(thrukState.refreshTimer);
  setRefreshRate(silent ? -1 : 0);
}

/* is this an array? */
function is_array(o) {
    return typeof(o) == 'object' && (o instanceof Array);
}

function is_object(el) {
    return(typeof(el) == 'object');
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

    if(addTimeAndScroll) {
        // save scroll state
        saveScroll();
    }

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
    } catch(err) { console.log(err) }
}

/* reloads the current page and adds some parameter from a hash */
var isReloading = false;
var reloadPageTimer;
function reloadPage(delay, withReloadButton, freshReload) {
    if(!delay) { delay = 50; }
    if(delay < 500 && withReloadButton) {
        // update button earlier
        resetRefreshButton();
        jQuery("#refresh_button").addClass("fa-spin fa-spin-reverse");
        withReloadButton = false;
    }
    window.clearTimeout(reloadPageTimer);
    reloadPageTimer = window.setTimeout(function() {
        reloadPageDo(withReloadButton, freshReload);
    }, delay);
}

function resetRefreshButton() {
    jQuery("#refresh_button").removeClass("red");
    jQuery("#refresh_button").removeClass("fa-spin fa-spin-reverse");
    jQuery("#refresh_button").find("I").css("display", "");
    jQuery("#refresh_button").find('I.uil-exclamation').remove();
    jQuery("#refresh_button").attr("title", "reload page");
}

function reloadPageDo(withReloadButton, freshReload) {
    if(isReloading) { return; } // prevent  multiple simultanious reloads
    if(withReloadButton) {
        resetRefreshButton();
    }
    isReloading = true;
    stopRefresh(true);
    var obj = document.getElementById('refresh_rate');
    if(obj) {
        obj.innerHTML = "<span id='refresh_rate'>page will be refreshed...</span>";
    }

    var newUrl = getCurrentUrl(true);
    updateUrl();

    if(fav_counter) {
        updateFaviconCounter('Zz', '#F7DA64', true, "10px Bold Tahoma", "#BA2610");
    }

    if(freshReload) {
        redirect_url(newUrl);
        return;
    }

    jQuery.ajax({
        url: newUrl,
        type: 'POST',
        data: {},
        success: function(page) {
            isReloading = false;
            var scrollTo = getPageScroll();
            setInnerHTMLWithScripts(document.documentElement, page);
            init_page();
            if(scrollTo) {
                applyScroll(scrollTo);
                // chrome does not set scroll immediately on page load, wait some milliseconds and set again
                window.setTimeout(function() {
                    applyScroll(scrollTo);
                }, 50);
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            isReloading = false;
            resetRefreshButton();
            jQuery("#refresh_button").addClass("red");
            jQuery("#refresh_button").find("I").css("display", "none");
            jQuery("#refresh_button").prepend('<I class="uil uil-exclamation"><\/I>');
            jQuery("#refresh_button").attr("title", "refreshing page failed: "+textStatus+"\nlast contact: "+duration(((new Date()).getTime()-thrukState.lastPageLoaded)/1000)+" ago");
            thruk_xhr_error('refreshing page failed: ', '', textStatus, jqXHR, errorThrown, null, 60);
        }
    });
}

/* set inner html but execute all scripts */
function setInnerHTMLWithScripts(el, html) {
    el.innerHTML = html;
    jQuery(el).find("script").each(function(i, oldScript) {
        var newScript = document.createElement("script");
        jQuery(oldScript.attributes).each(function(k, attr) {
             newScript.setAttribute(attr.name, attr.value);
        });
        oldScript.parentNode.replaceChild(newScript, oldScript);
        newScript.appendChild(document.createTextNode(oldScript.innerHTML));
    });
}

/* wrapper for window.location which results in
 * Uncaught TypeError: Illegal invocation
 * otherwise. (At least in chrome)
 */
function redirect_url(url) {
    return(window_location_replace(url));
}
function window_location_replace(url) {
    window.location.replace(url);
}

function get_site_panel_backend_button(id, onclick, section, extraClass) {
    if(!extraClass) { extraClass = ""; }
    if(!initial_backends[id] || !initial_backends[id]['cls']) { return(""); }
    var cls = initial_backends[id]['cls'];
    var title = initial_backends[id]['name']+": "+initial_backends[id]['last_error'];
    if(section) {
        title += "\nSection: "+section.replace(/_/g, "/");
    }
    if(cls != "DIS") {
        if(initial_backends[id]['last_online']) {
            title += "\nLast Online: "+duration(initial_backends[id]['last_online'])+" ago";
            if(cls == "UP" && initial_backends[id]['last_error'] != "OK") {
                cls = "WARN";
            }
        }
    }
    var btn = '<input type="button"';
    btn += " id='button_"+id+"'";
    btn += " data-id='"+id+"'";
    btn += " data-section='"+section+"'";
    btn += ' class="button_peer button_peer'+cls+' '+extraClass+'"';
    btn += ' value="'+initial_backends[id]['name']+'"';
    btn += ' title="'+escapeHTML(title).replace(/"/g, "'")+'"';
    if(initial_backends[id]['disabled'] == 5) {
        btn += ' disabled';
    } else {
        btn += ' onClick="'+onclick+'">';
    }

    return(btn);
}

/* create sites popup */
function create_site_panel_popup() {
    if(current_backend_states == undefined) {
        current_backend_states = {};
        for(var key in initial_backends) { current_backend_states[key] = initial_backends[key]['state']; }
    }

    var panel = '';
    if(show_sitepanel == "panel" || show_sitepanel == "list") {
        panel += create_site_panel_popup_panel();
    }
    else if(show_sitepanel == "collapsed") {
        panel += create_site_panel_popup_collapsed();
    }
    else if(show_sitepanel == "tree") {
        panel += create_site_panel_popup_tree();
    }
    document.getElementById('site_panel_content').innerHTML = panel;

    if(show_sitepanel == "tree") {
        create_site_panel_popup_tree_populate();
    }
}

function create_site_panel_popup_panel() {
    var panel = "";
    panel += '<table class="cellspacing w-fit">';
    panel += '  <tr>';
    if(sites["sub"] && keys(sites["sub"]).length > 1 || !sites["sub"]["Default"]) {
        jQuery(keys(sites["sub"]).sort()).each(function(i, subsection) {
            if(sites["sub"][subsection].total == 0) { return; }
            panel += '<th class="borderDefault first:border-l-0 border-l py-0 text-center" onclick="toggleSection([\''+subsection+'\']); return false;" title="'+subsection+'">';
            panel += '<span class="inline-block w-full h-full py-1 rounded clickable hoverable">'+subsection+'<\/span>';
            panel += '<\/th>';
        });
    }
    panel += '  </tr>';
    panel += '  <tr>';
    jQuery(keys(sites["sub"]).sort()).each(function(i, subsection) {
        if(sites["sub"][subsection].total == 0) { return; }
        panel += '<td valign="top" class="subpeers_'+subsection+' borderDefault first:border-l-0 border-l"><div class="flexrow flex-nowrap gap-px"><div class="flexcol gap-px">';
        var count = 0;
        jQuery(_site_panel_flat_peers(sites["sub"][subsection])).each(function(i, pd) {
            panel += get_site_panel_backend_button(pd, "toggleBackend('"+pd+"')", toClsName(subsection), 'w-30');
            count++;
            if(count > 15) { count = 0; panel += '</div><div class="flexcol gap-px">'; }
        });
        panel += '<\/div><\/div></td>';
    });
    panel += '  </tr>';
    panel += '</table>';
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
    var panel = "";
    panel += '<table class="cellspacing w-full min-w-[900px]">';
    jQuery(keys(sites.sub).sort()).each(function(i, sectionname) {
        if(i > 0) {
            panel += '  <tr>';
            panel += '    <td><hr class="py-1"></td>';
            panel += '  </tr>';
        }
        panel += '<tr>';
        panel += '<th class="borderDefault first:border-l-0 border-l p-0" onclick="toggleSection([\''+sectionname+'\']); return false;" title="'+sectionname+'">';
        panel += '<span class="inline-block w-full h-full p-1 rounded clickable hoverable">'+sectionname+'<\/span>';
        panel += '<\/th>';
        panel += '</tr>';
        // show first two levels of sections
        panel += add_site_panel_popup_collapsed_section(sites["sub"][sectionname], [sectionname]);
        // including peers
        if(sites["sub"][sectionname]["peers"]) {
            panel += '  <tr>';
            panel += '    <td><div class="flexrow gap-px">';
            jQuery(sites["sub"][sectionname]["peers"]).each(function(i, pd) {
                panel += get_site_panel_backend_button(pd, "toggleBackend('"+pd+"')", toClsName(sectionname));
            });
            panel += '    <\/div></td>';
            panel += '  </tr>';
        }
    });

    // add top level peers
    if(sites["peers"]) {
        panel += '  <tr>';
        panel += '    <td><hr class="py-1"></td>';
        panel += '  </tr>';
        panel += '  <tr>';
        panel += '    <td><div class="flexrow gap-px">';
        jQuery(sites["peers"]).each(function(i, pd) {
            panel += get_site_panel_backend_button(pd, "toggleBackend('"+pd+"')", "top");
        });
        panel += '    <\/div></td>';
        panel += '  </tr>';
    }

    // add all other peers
    jQuery(keys(sites.sub).sort()).each(function(i, sectionname) {
        panel += add_site_panel_popup_collapsed_peers(sites["sub"][sectionname], [sectionname]);
    });

    panel += '</table>';
    return(panel);
}

function add_site_panel_popup_collapsed_section(section, prefix) {
    var lvl = prefix.length;
    var panel = "";
    var prefixCls = toClsNameList(prefix);
    if(section["sub"]) {
        panel += '  <tr style="'+(lvl > 1 ? 'display: none;' : '')+'" class="subsection subsection_'+prefixCls+' sublvl_'+lvl+'">';
        panel += '    <td align="left" style="padding-left: '+(lvl*10)+'px;">';
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
            panel += "<button class='"+cls+" btn_sites btn_sites_"+prefixCls+"_"+toClsName(sectionname)+"' onClick='toggleSubSectionVisibility("+JSON.stringify(new_prefix)+")'>";
            panel += "<i class='uil uil-folder-open'></i>"+sectionname;
            panel += "<\/button>";
        });
        panel += '    </td>';
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
    var panel = "";
    if(section["peers"]) {
        var prefixCls = toClsNameList(prefix);
        panel += '  <tr class="subpeer subpeers_'+prefixCls+'" style="display: none;">';
        panel += '    <td>';
        panel += '    <hr>';

        panel += '    <table><tr><th>';
        panel += "      <input type='checkbox' onclick='toggleSection("+JSON.stringify(prefix)+");' class='clickable section_check_box_"+prefixCls+"'>";
        panel += "      <a href='#' onclick='toggleSection("+JSON.stringify(prefix)+"); return false;'>";
        panel += prefix.join(' -&gt; ');
        panel += '      </a>';
        panel += '    </th></tr></table>';
        panel += '    <div class="flexrow gap-px">';
        jQuery(section["peers"]).each(function(i, pd) {
            panel += get_site_panel_backend_button(pd, "toggleBackend('"+pd+"')", prefixCls);
        });
        panel += '    <\/div>';
        panel += '    </td>';
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

function create_site_panel_popup_tree() {
    var panel = "";
    panel += '<div class="flexrow flex-nowrap gap-1">';
    panel += '  <div class="w-[200px]" id="site_panel_sections"><\/div>';
    panel += '  <div class="min-h-[200px] min-w-[890px] w-full px-2 border-l borderDefault">';
    panel += '    <div class="flexrow gap-px">';
    jQuery(backend_keys).each(function(i, peer_key) {
        var section = initial_backends[peer_key].section.replace(/\//g, '_');
        panel += get_site_panel_backend_button(peer_key, "toggleBackend('"+peer_key+"')", section, "tree_peer_btn");
    });
    panel += '    <\/div>';
    panel += '  <\/div>';
    panel += '<\/div>';
    return(panel);
}

function create_site_panel_popup_tree_populate() {
    jQuery(".tree_peer_btn").hide();
    if(!has_jquery_ui()) {
        load_jquery_ui(create_site_panel_popup_tree_populate);
        return;
    }

    create_site_panel_popup_tree_make_bookmarks_sortable();

    var site_tree_data = create_site_panel_popup_tree_data(sites, "");

    jQuery("#site_panel_sections").fancytree({
        activeVisible: true, // Make sure, active nodes are visible (expanded).
        aria: false, // Enable WAI-ARIA support.
        autoActivate: false, // Automatically activate a node when it is focused (using keys).
        autoCollapse: true, // Automatically collapse all siblings, when a node is expanded.
        autoScroll: false, // Automatically scroll nodes into visible area.
        clickFolderMode: 2, // 1:activate, 2:expand, 3:activate and expand, 4:activate (dblclick expands)
        checkbox: true, // Show checkboxes.
        debugLevel: 0, // 0:quiet, 1:normal, 2:debug
        disabled: false, // Disable control
        focusOnSelect: true,
        generateIds: false, // Generate id attributes like <span id='fancytree-id-KEY'>
        idPrefix: "ft_", // Used to generate node id´s like <span id='fancytree-id-<key>'>.
        icons: true, // Display node icons.
        keyboard: false, // Support keyboard navigation.
        keyPathSeparator: "/", // Used by node.getKeyPath() and tree.loadKeyPath().
        minExpandLevel: 1, // 1: root node is not collapsible
        selectMode: 3, // 1:single, 2:multi, 3:multi-hier
        tabbable: true, // Whole tree behaves as one single control
        source: site_tree_data,
        // clicking the image or name -> expand tree
        click: function(event, data){
            resetRefresh();
            data.node.setActive();
            data.node.collapseSiblings();
            jQuery(".tree_peer_btn").hide();
            jQuery(data.node.data.peers).each(function(i, peer_key) {
                jQuery("#button_"+peer_key).show();
            });
        },
        // clicking the checkbox -> select/deselect all nodes
        select: function(event, data){
            var state = data.node.isSelected();
            data.node.setActive();
            var section = data.node.key.replace(/^\//, "");
            var regex   = new RegExp("^"+section+"($|\/)");
            for(var peer_key in initial_backends) {
                var peer = initial_backends[peer_key];
                if(peer.section.match(regex)) {
                    toggleBackend(peer_key, state, true);
                }
            }
            if(data.node.folder == false) {
                // root elements
                toggleBackend(data.node.key.replace(/^\//, ""), state, true);
            }
            updateSitePanelCheckBox();
            resetRefresh();
        }
    });

    // activate first section
    jQuery(".fancytree-icon").first().click();
}

function create_site_panel_popup_tree_make_bookmarks_sortable() {
    if(!has_jquery_ui()) {
        load_jquery_ui(create_site_panel_popup_tree_make_bookmarks_sortable);
        return;
    }

    jQuery('#site_panel_bookmark_list').sortable({
        items                : 'BUTTON',
        helper               : 'clone',
        tolerance            : 'pointer',
        cursor               : 'pointer',
        cancel               : '', // would conflict with buttons otherwise
        forcePlaceholderSize : false,
        forceHelperSize      : false,
        axis                 : 'x',
        distance             : 5,
        placeholder          : "site_panel_bookmark_placeholder",
        update               : function(event, ui) {
            var order = [];
            jQuery("#site_panel_bookmark_list > BUTTON").each(function(i, el) {
                order.push(el.dataset["index"]);
            });
            jQuery.ajax({
                url: url_prefix + 'cgi-bin/user.cgi',
                type: 'POST',
                data: {
                    action:   'site_panel_bookmarks',
                    reorder:  '1',
                    order:     order
                }
            });
        }
    });
    return;
}

function create_site_panel_popup_tree_data(d, current, tree) {
    var nodes = [];

    // append folders
    jQuery(keys(d.sub).sort()).each(function(i, sectionname) {
        var iconCls = 'fa-solid fa-folder text-base textSUCCESS';
        if(d.sub[sectionname].down > 0 && d.sub[sectionname].disabled > 0) {
            iconCls = 'fa-solid fa-folder text-base textALERT-mixed';
        } else if(d.sub[sectionname].down > 0) {
            iconCls = 'fa-solid fa-folder text-base textALERT';
        } else if(d.sub[sectionname].up > 0 && d.sub[sectionname].disabled > 0) {
            if(backend_chooser == "switch") {
                iconCls = 'fa-solid fa-folder text-base textSUCCESS';
            } else {
                iconCls = 'fa-solid fa-folder text-base textSUCCESS-mixed';
            }
        } else if(d.sub[sectionname].up == 0) {
            iconCls = 'fa-solid fa-folder text-base textGRAY';
        }
        var selected;
        if(d.sub[sectionname].disabled == 0) {
            selected = true; // enabled
        } else if(d.sub[sectionname].disabled == d.sub[sectionname].total) {
            selected = false; // off
        }
        var key = current + '/' + sectionname;
        nodes.push({
            'key': key,
            'title': '<i class="'+iconCls+'"></i> '+sectionname,
            'folder': true,
            'children': create_site_panel_popup_tree_data(d.sub[sectionname], key, tree),
            'peers': d.sub[sectionname].peers,
            'icon': false,
            'selected': selected,
            'extraClasses': d.sub[sectionname] ? 'has_sub' : 'has_no_sub'
        });
        if(tree) {
            var node  = tree.getNodeByKey(key);
            node.title = '<i class="'+iconCls+'"></i> '+node.title.replace(/<i.*<\/i>/, "");
            if(selected === true) {
                node.setSelected(true, {noEvents: true});
            } else if(selected === false) {
                node.setSelected(false, {noEvents: true});
            }
            node.renderTitle();
        }
    });

    // append root nodes
    if(current == "" && d.peers != undefined && d.peers.length > 0) {
        jQuery(d.peers).each(function(i, peer_key) {
            var peer = initial_backends[peer_key];
            if(!peer) { return true; }
            var iconCls = 'fa-solid fa-circle text-base textSUCCESS';
            var selected = true; // checkbox enabled
            if(current_backend_states[peer_key] == 2) {
                iconCls = 'fa-solid fa-circle text-base textGRAY';
                selected = false; // checkbox off
            } else {
                if(current_backend_states[peer_key] == 1 || initial_backends[peer_key].state == 1) {
                    iconCls = 'fa-solid fa-circle text-base textALERT';
                }
            }
            if(backend_chooser == "switch") {
                if(!array_contains(param_backend, peer_key)) {
                    iconCls = 'fa-solid fa-circle text-base textGRAY';
                    selected = false; // checkbox off
                }
            }
            var key = '/'+peer_key;
            nodes.push({
                'key': key,
                'title': '<i class="'+iconCls+'"></i> '+peer["name"],
                'folder': false,
                'children': [],
                'peers': [peer_key],
                'icon': false,
                'selected': selected
            });
            if(tree) {
                var node  = tree.getNodeByKey(key);
                node.title = '<i class="'+iconCls+'"></i> '+node.title.replace(/<i.*<\/i>/, "");
                if(selected === true) {
                    node.setSelected(true, {noEvents: true});
                }
                if(selected === false) {
                    node.setSelected(false, {noEvents: true});
                }
                node.renderTitle();
            }
        });
    }
    return(nodes);
}

function site_panel_search() {
    var val = jQuery("#site_panel_search").val();
    jQuery(".tree_peer_btn").hide();
    var input = document.getElementById("site_panel_search");
    clearFormInputError(input);
    if(val == "") {
        return;
    }
    jQuery("#site_panel_search").removeClass("invalid");
    var searches = val.split(/\s+/);
    for(var key in initial_backends) {
        var site = initial_backends[key];
        var name = site.section+'/'+site.name;
        var show = true;
        jQuery(searches).each(function(i, v) {
            if(v == "") { return true; }
            try {
                if(!name.match(v)) {
                    show = false;
                    return false;
                }
            } catch(e) {
                addFormInputError(input, e, "below");
            }
        });
        if(show) {
            jQuery("#button_"+key).show();
        }
    }
    updateSitePanelCheckBox();
}

function site_panel_bookmark_save() {
    setBtnSpinner("#site_panel_bookmark_new_save");
    jQuery("#site_panel_bookmark_new_save").attr('disabled', true).val("");
    var name = jQuery("#site_panel_bookmark_new").val();

    var sections = [];
    var backends = [];
    for(var key in current_backend_states) {
        if(current_backend_states[key] != 2) {
            backends.push(key);
        }
    }
    var _gather_sections = function(site, sections, lvl) {
        for(var key in site.sub) {
            var newLvl = (lvl == "" ? key : lvl+'/'+key);
            if(site.sub[key].disabled == 0) {
                sections.push(newLvl);
            } else {
                _gather_sections(site.sub[key], sections, newLvl);
            }
        }
    }
    _gather_sections(sites, sections, "");
    jQuery.ajax({
        url: url_prefix + 'cgi-bin/user.cgi',
        type: 'POST',
        data: {
            action:   'site_panel_bookmarks',
            save:     '1',
            name:      name,
            backends:  backends,
            sections:  sections
        },
        success: function(data) {
            setBtnSuccess("#site_panel_bookmark_new_save", "bookmark saved");
            jQuery("#site_panel_bookmark_new_save").attr('disabled', false).html("save");
            create_site_panel_popup_tree_make_bookmarks_sortable();
            jQuery("#site_panel_bookmark_new").val("").hide();
            jQuery("#site_panel_bookmark_new_save").hide();
            jQuery("#site_panel_bookmark_plus").show();
            jQuery('#site_panel_bookmark_list_container').load(url_prefix + 'cgi-bin/user.cgi #site_panel_bookmark_list',
                undefined,
                function() {
                    create_site_panel_popup_tree_make_bookmarks_sortable();
                });
        }
    });
}

function setBackends(backends, sections, btn) {
    // if delete button is pressed, remove this item
    if(jQuery('#site_panel_bookmark_delete').hasClass("red")) {
        jQuery.ajax({
            url: url_prefix + 'cgi-bin/user.cgi',
            type: 'POST',
            data: {
                action:   'site_panel_bookmarks',
                remove:   '1',
                index:     btn.dataset["index"]
            },
            success: function(data) {
                jQuery(btn).remove();
            }
        });
        return;
    }

    for(var key in initial_backends) {
        toggleBackend(key, 0, true);
    }
    jQuery(backends).each(function(i, key) {
        if(initial_backends[key] != undefined) {
            toggleBackend(key, 1, true);
        }
    });
    var sectionsEnabled = {};
    jQuery(sections).each(function(i, key) {
        for(var peer_key in initial_backends) {
            var regex = new RegExp('^'+key.replace('/', '\\/')+'(/|$)');
            if(initial_backends[peer_key].section.match(regex)) {
                sectionsEnabled[initial_backends[peer_key].section] = true;
            }
        }
        sectionsEnabled[key] = true;
    });
    for(var section in sectionsEnabled) {
        toggleSection(section.split('/'),1);
    }
    updateSitePanelCheckBox();
}

/* toggle site panel */
function toggleSitePanel() {
    if(!document.getElementById('site_panel_content').innerHTML) {
        create_site_panel_popup();
    }
    toggleElement('site_panel', undefined, true, undefined, checkSitePanelChanged);
    checkSitePanelChanged();
}

function checkSitePanelChanged() {
    if(!jQuery('#site_panel').is(":visible")) {
        // immediately reload if there were changes
        if(backends_toggled) {
            removeParams['backends'] = true;
            reloadPage(50, true);
        }
    }

    updateSitePanelCheckBox();
}

/* toggle queries for this backend */
var backends_toggled = false;
function toggleBackend(backend, state, skip_update) {
  resetRefresh();
  var button = jQuery('.button_peer[data-id="'+backend+'"]');
  if(state == undefined) { state = -1; }

  if(backend_chooser == 'switch') {
    jQuery('.button_peer .button_peerUP').removeClass('button_peerUP').addClass('button_peerDIS');
    jQuery('.button_peer .button_peerDOWN').removeClass('button_peerDOWN').addClass('button_peerDIS');
    jQuery(button).removeClass('button_peerDIS').addClass('button_peerUP');
    cookieSave('thruk_conf', backend);
    removeParams['backends'] = true;
    reloadPage(50, true);
    return;
  }

  if(current_backend_states == undefined) {
    current_backend_states = {};
    for(var key in initial_backends) { current_backend_states[key] = initial_backends[key]['state']; }
  }

  var initial_state = initial_backends[backend]['state'];
  var newClass  = undefined;
  if((jQuery(button).hasClass("button_peerDIS") && state == -1) || state == 1) {
    if(initial_state == 1 || (initial_backends[backend]['last_error'] && initial_backends[backend]['last_error'] != "OK")) {
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

  backends_toggled = true;
  /* save current selected backends in session cookie */
  cookieSave('thruk_backends', toQueryString(current_backend_states));
  // remove &backends=... from url, they would overwrite cookie settings
  removeParams['backends'] = true;

  var delay = 2;
  if(jQuery('#site_panel_content').is(':visible')) { delay = 20; }
  if(show_sitepanel == 'collapsed') { delay = 20; }
  if(show_sitepanel == 'tree')      { delay = 30; }
  if(show_sitepanel == 'list') {
    reloadPage(delay*1000, true);
  } else {
    setRefreshRate(delay);
  }

  if(skip_update == undefined || !skip_update) {
    updateSitePanelCheckBox();
  }
  return;
}

/* toggle subsection */
function toggleSubSectionVisibility(subsection) {
    // hide everything
    jQuery('TR.subpeer, TR.subsection').css('display', 'none');
    jQuery('TR.subsection BUTTON').removeClass('button_peer_selected');

    // show parents sections
    var subsectionCls = toClsNameList(subsection);
    var cls = '';
    for(var x = 0; x < subsection.length; x++) {
        if(cls != "") { cls = cls+'_'; }
        cls = cls+toClsName(subsection[x]);
        // show section itself
        jQuery('TR.subsection_'+cls).css('display', '');
        // but hide all subsections
        jQuery('TR.subsection_'+cls+' BUTTON').css('display', 'none');
        // except the one we want to see
        jQuery('BUTTON.btn_sites_'+cls).css('display', '').addClass('button_peer_selected');
    }

    // show section itself
    jQuery('TR.subsection_'+subsectionCls).css('display', '');
    jQuery('TR.subsection_'+subsectionCls+' BUTTON').css('display', '');

    // show peer for this subsection
    jQuery('TR.subpeers_'+subsectionCls).css('display', '');
    jQuery('TR.subpeers_'+subsectionCls+' BUTTON').css('display', '');

    // always show top sections
    jQuery('TR.sublvl_1').css('display', '');
    jQuery('TR.sublvl_1 BUTTON').css('display', '');
}

/* toggle all backends for this section */
function toggleSection(sections, first_state) {
    var section = toClsNameList(sections);
    jQuery('HEADER .button_peer').each(function(i, b) {
        if(b.dataset.section != section) { return(true); }
        if(first_state == undefined) {
            if(jQuery(b).hasClass("button_peerUP") || jQuery(b).hasClass("button_peerDOWN")) {
                first_state = 0;
            } else {
                first_state = 1;
            }
        }
        toggleBackend(b.dataset.id, first_state, true);
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
    var visibleOnly = false;
    if(jQuery("#site_panel_search").val()) {
        visibleOnly = true;
    }
    jQuery('HEADER .button_peer').each(function(i, b) {
        if(visibleOnly && !jQuery(b).is(":visible")) {
            toggleBackend(b.dataset.id, 0, true);
            return(true);
        }
        toggleBackend(b.dataset.id, state, true);
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

    if(jQuery("#site_panel_search").val()) {
        // if search is active, calculate based on visible backend buttons
        jQuery('#all_backends').prop('checked', true);
        jQuery('HEADER .button_peer').each(function(i, b) {
            if(b.dataset.id && !jQuery(b).hasClass("button_peerUP") && jQuery(b).is(":visible")) {
                jQuery('#all_backends').prop('checked', false);
                return;
            }
        });
    }

    if(show_sitepanel == "tree") {
        var tree;
        try {
            tree = jQuery("#site_panel_sections").fancytree("getTree");
        } catch(e) {}
        if(tree) {
            create_site_panel_popup_tree_data(sites, "", tree);
        }
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
    seconds = Math.round(seconds);
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
    var elems = form.getElementsByTagName('select');
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
    jQuery('.js-autohide').css("visibility", "hidden");
}

/* verify time */
var verification_errors = new Object();
function verify_time(id, duration_id) {
    window.clearTimeout(thrukState.verifyTimer);
    thrukState.verifyTimer = window.setTimeout(function() {
        verify_time_do(id, duration_id);
    }, 500);
}
function verify_time_do(id, duration_id) {
    var obj  = document.getElementById(id) || id;
    var obj2 = document.getElementById(duration_id);
    var duration = "";
    if(obj2 && jQuery(obj2).is(":visible")) {
        duration = obj2.value;
    }

    clearFormInputError(obj);
    delete verification_errors[id];

    if(obj.value == "") {
        return;
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
            if(data.verified == "false") {
                console.log(data.error);
                verification_errors[id] = 1;
                addFormInputError(obj, data.error);
            }
        }
    });
}

function clearFormInputError(input) {
    jQuery("DIV.card.alert").remove();
    jQuery(input).removeClass('invalid');
}

function addFormInputError(input, msg, align) {
    clearFormInputError(input);
    jQuery(input).addClass('invalid')
    input.parentNode.style.position = 'relative';
    var top = "-top-8";
    if(align == "below") {
        top = "-bottom-8";
    }
    jQuery("<div class='card alert red p-1 "+top+" whitespace-nowrap'>"+msg+"</div>").insertBefore(input);
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
function refresh_button() {
    reloadPage(50, true);
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
   };
};

/* numeric comparison function */
function compareNumeric(a, b) {
   return a - b;
}

/* make right pane visible */
function cron_change_date(id) {
    // get selected value
    var type_sel = document.getElementById(id);
    var nr       = type_sel.id.match(/_(\d+)$/)[1];
    var type     = type_sel.options[type_sel.selectedIndex].value;
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


function permission_add_row(tbl_id) {
    var tbl            = document.getElementById(tbl_id);
    var tblBody        = tbl.tBodies[0];

    // show header
    tblBody.rows[0].style.display = "";

    /* get second table row */
    var row = tblBody.rows[1];
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

function permission_del_row(el) {
    var row = el;
    /* find first table row */
    while(row.parentNode != undefined && row.tagName != 'TR') { row = row.parentNode; }
    var tbody = row.parentNode;
    row.parentNode.deleteRow(row.rowIndex);

    // show header
    if(tbody.rows.length <= 3) { // header, template row and add button row
        tbody.rows[0].style.display = "none";
    }

    return false;
}

/* remove a row */
function delete_form_row(el) {
    var row = el;
    /* find first table row */
    while(row.parentNode != undefined && row.tagName != 'TR') { row = row.parentNode; }
    row.parentNode.deleteRow(row.rowIndex);
    return false;
}

/* add a row */
function add_form_row(el, row_num_to_clone) {
    var tbl            = el;
    while(tbl.parentNode != undefined && tbl.tagName != 'TABLE') { tbl = tbl.parentNode; }
    var tblBody        = tbl.tBodies[0];

    /* get first table row */
    var row = tblBody.rows[row_num_to_clone];
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
        table_search_timer = window.setTimeout(do_table_search, 300);
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
        if(table.tagName == "DIV") {
            do_table_search_div(id, table, value);
        } else {
            var matches = table.className.match(/searchSubTable_([^\ ]*)/);
            if(matches && matches[1]) {
                jQuery(table).find("TABLE."+matches[1]).each(function(x, t) {
                    do_table_search_table(id, t, value);
                });
            } else {
                do_table_search_table(id, table, value);
            }
        }
    });
}

function do_table_search_table(id, table, value) {
    if(table.dataset["search"] && table.dataset["search"] == value) { return; }
    if(!table.dataset["search"] && !value) { return; }
    /* make tables fixed width to avoid flickering */
    if(table.offsetWidth && !table.style.width) {
        table.style.width = table.offsetWidth+"px";
    }
    table.dataset["search"] = value;
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
    updatePagerCount(id);
    if(table_search_cb[id] != undefined) {
        try {
            table_search_cb[id]();
        } catch(err) {
            console.log(err);
        }
    }
}

function updatePagerCount(table_id) {
    var total = 0;
    jQuery("#"+table_id+" > TBODY > TR").each(function(i, row) {
        if(jQuery(row).hasClass("js-skip-count")) { return(true); }
        if(!jQuery(row).is(":visible"))           { return(true); }
        total++;
    });
    jQuery(".js-pager-totals").text(total);

    if(jQuery("#"+table_id).hasClass("js-striped")) {
        applyRowStripes(document.getElementById(table_id));
    }
}

function do_table_search_div(id, div, value) {
    jQuery(div).children().each(function(i, row) {
        if(jQuery(row).hasClass('table_search_skip')) {
            return;
        }
        var found = 0;
        /* if regex matching fails, use normal matching */
        try {
            if(row.innerHTML.toLowerCase().match(value)) {
                found = 1;
            }
        } catch(err) {
            if(row.innerHTML.toLowerCase().indexOf(value) != -1) {
                found = 1;
            }
        }
        if(found == 0) {
            jQuery(row).addClass('filter_hidden');
        } else {
            jQuery(row).removeClass('filter_hidden');
        }
    });
}

/* show bug report icon */
function showBugReport(id, text) {
    var link = document.getElementById('bug_report-btnEl');
    var raw  = text;
    text = "Please describe what you did:\n\n\n\n\nMake sure the report does not contain confidential information.\n\n---------------\n" + text;
    var href="mailto:"+bug_email_rcpt+"?subject="+encodeURIComponent("Thruk JS Error Report")+"&body="+encodeURIComponent(text);
    if(link) {
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
    text      = "<pre class='overflow-auto'>"+escapeHTML(text)+"<\/pre>";
    var title = "Error Report";
    try {
        overcard({'bodyCls': 'p-2', 'body': text, 'caption': title, 'width': 900 });
    }
    catch(e) {}
    if (window.Ext != undefined) {
        Ext.Msg.alert(title, text);
    }
    return(false);
}

/* create error text for bug reports */
function getErrorText(error) {
    var text = "";
    text = text + "Version:    " + version_info+"\n";
    text = text + "Release:    " + released+"\n";
    text = text + "Url:        " + window.location.pathname + "?" + window.location.search + "\n";
    text = text + "Browser:    " + platform.description + "\n";
    text = text + "UserAgent:  " + navigator.userAgent + "\n";
    text = text + "User:       " + remote_user+ "\n";
    text = text + "Backends:   ";
    var first = 1;
    for(var key in initial_backends) {
        if(!first) { text = text + '            '; }
        text = text + initial_backends[key].state + ' / ' + initial_backends[key].version + ' / ' + initial_backends[key].data_src_version + "\n";
        first = 0;
    }
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
function set_sub(nr, hash) {
    for(var x=1;x<=20;x++) {
        /* reset table rows */
        if(x != nr) {
            jQuery(".sub_"+x).css("display", "none");
            jQuery("#sub_"+x).removeClass("active");
        }
    }

    jQuery(".sub_"+nr).css("display", "");
    jQuery("#sub_"+nr).addClass("active");

    if(hash) {
        set_hash(hash);
    }

    return false;
}

/* select active tabs */
function setTab(id) {
    jQuery('.js-tabs').css('display', 'none');
    jQuery('SPAN.tabs').removeClass("active");
    jQuery('#'+id+'_head').addClass("active");
    jQuery('#'+id).css('display', '');
    return false;
}

/* hilight area of screen */
function hilight_area(x1, y1, x2, y2, duration, color) {
    if(!color)    { color    = 'red'; };
    if(!duration) { duration = 2000; };
    var rnd = Math.floor(Math.random()*10000000);

    jQuery(document.body).append('<div id="hilight_area'+rnd+'" style="width:'+(x2-x1)+'px; height:'+(y2-y1)+'px; position: absolute; background-color: '+color+'; opacity:0.2; top: '+y1+'px; left: '+x1+'px; z-index:10000;">&nbsp;<\/div>');

    window.setTimeout(function() {
       fade('hilight_area'+rnd, 1000, true);
    }, duration);
}

/* hilight area of screen for given object */
function hilight_obj_area(obj, duration, color) {
    var width  = jQuery(obj).outerWidth();
    var height = jQuery(obj).outerHeight();
    var offset = jQuery(obj).offset();

    var x1 = offset['left'] - 5;
    var x2 = offset['left'] + width  + 5;
    var y1 = offset['top']  - 5;
    var y2 = offset['top']  + height + 5;

    hilight_area(x1, y1, x2, y2, duration, color);
}

/* fade element away and optionally remove it */
function fade(id, duration, remove) {
    if(is_array(id)) {
        jQuery(id).each(function(i, el) {
            fade(el, duration, remove);
        });
        return true;
    }
    var el = id;
    if(!is_object(el)) {
        el = document.getElementById(el);
    }
    duration = duration || 500;
    jQuery(el).css({
        visibility: "hidden",
        opacity: "0",
        transition: "visibility 0s "+duration+"ms, opacity "+duration+"ms linear"
    });

    window.setTimeout(function() {
        // completly remove message from dom after fading out
        if(remove) {
            jQuery(el).remove();
            return;
        }
        // remove opacity style, since it confuses the showElement
        jQuery(el).css({
            display: "none",
            visibility: "hidden",
            opacity: "",
            transition: ""
        });
    } , duration + 50);
    return true;
}

var ui_loading = false;
function load_jquery_ui(callback) {
    if(has_jquery_ui() || ui_loading) {
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
            callback(script, textStatus, jqXHR);
            ui_loading = false;
        },
        error:     ajax_xhr_error_logonly,
        cache:     true
    });
}


/* write/return table with performance data */
var thruk_message_fade_timer;
function thruk_message(rc, message, close_timeout) {
    jQuery('#thruk_message').remove();
    window.clearInterval(thruk_message_fade_timer);
    var cls = 'fail_message';
    if(rc == 0) { cls = 'success_message'; }
    var html = ''
        + '<div id="thruk_message" class="card shadow-float fixed p-1 z-50 min-w-[600px] max-w-[90vw] top-14 left-1/2 transform -translate-x-1/2">'
        + '  <div class="flexrow flex-nowrap gap-2 justify-center">'
        + '    <div class="w-5"></div>'
        + '    <div class="flex-grow text-center font-semibold whitespace-nowrap">'
        + '      <span class="' + cls + '">' + message;
    if(rc != 0) {
        html +=   '<i class="uil uil-exclamation round yellow ml-2" title="Errors detected"></i>';
    }
    html += ''
        + '      </span>'
        + '    </div>'
        + '    <div class="w-5">'
        + '      <button class="iconOnly medium" title="close this message" onclick="fade(\'thruk_message\', 500, true);return false;"><i class="uil uil-times"></i></button>'
        + '    </div>'
        + '  </div>'
        + '</div>';

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
    thruk_message_fade_timer = window.setTimeout(function() {
        fade('thruk_message', 500, true);
    }, fade_away_in);
}

/* return absolute host part of current url */
function get_host() {
    var host = window.location.protocol + '//' + window.location.host;
    if(window.location.port != "" && host.indexOf(':' + window.location.port) == -1) {
        host += ':' + window.location.port;
    }
    return(host);
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
    if(history.replaceState) {
        history.replaceState({}, "", value);
    } else {
        window.location.replace(value);
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
function load_overcard_content(id, url, add_pre) {
    var el = document.getElementById(id);
    if(el) {
        el.innerHTML = "<div class='spinner w-8 h-8'><\/div>";
    }
    jQuery.ajax({
        url: url,
        type: 'POST',
        success: function(data) {
            var el = document.getElementById(id);
            if(!el) {
                if(thruk_debug_js) { alert("ERROR: no container found load_overcard_content(): " + id); }
                return;
            }
            if(add_pre) {
                data.data = "<pre>"+data.data+"<\/pre>";
            }
            if(typeof(data) == "string") {
                el.innerHTML = data;
            } else {
                el.innerHTML = data.data;
            }
        },
        error: ajax_xhr_error_logonly
    });
}

function ajax_xhr_error_logonly(jqXHR, textStatus, errorThrown) {
    thruk_xhr_error('request failed: ', '', textStatus, jqXHR, errorThrown, true);
}

function thruk_xhr_error(prefix, responseText, textStatus, jqXHR, errorThrown, logOnly, closeTimeout) {
    var cookie = readCookie('thruk_message');
    var matches;
    var msg;
    if(!cookie && responseText && responseText.match) {
        matches = responseText.match(/<\!\-\-error:(.*):error\-\->/m);
        if(matches && matches[1]) {
            msg = matches[1];
            msg = msg.replace("\n", '<br>');
        }
    }

    if(cookie) {
        cookieRemove('thruk_message');
        msg = cookie;
    }
    else if(msg) {}
    else if(errorThrown && jqXHR && textStatus) {
        msg = jqXHR.status + " - " + errorThrown + " - " + textStatus;
    }
    else if(jqXHR && textStatus) {
        msg = jqXHR.status + " - " + jqXHR.statusText + " - " + textStatus;
    }
    else {
        msg = textStatus;
    }

    if(logOnly) {
        console.log(prefix + msg);
    } else {
        thruk_message(1, prefix + msg, closeTimeout);
    }
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
        console.log("type is different: a" + prefix + " "+typeof(o1)+"       b" + prefix + " "+typeof(o2));
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
            console.log("value is different: a" + prefix + " "+o1+"       b" + prefix + " "+o2);
            return(true);
        }
    } else {
        console.log("don't know how to compare: "+typeof(o1)+" at a"+prefix);
    }
    return(false);
}

/* callback to show popup with host comments */
function host_comments_popup(host_name, peer_key) {
    generic_downtimes_popup("Comments: "+host_name, url_prefix+'cgi-bin/parts.cgi?part=_host_comments&host='+encodeURIComponent(host_name)+"&backend="+peer_key);
}

/* callback to show popup with host downtimes */
function host_downtimes_popup(host_name, peer_key) {
    generic_downtimes_popup("Downtimes: "+host_name, url_prefix+'cgi-bin/parts.cgi?part=_host_downtimes&host='+encodeURIComponent(host_name)+"&backend="+peer_key);
}

/* callback to show popup with service comments */
function service_comments_popup(host_name, service, peer_key) {
    generic_downtimes_popup("Comments: "+host_name+' - '+service, url_prefix+'cgi-bin/parts.cgi?part=_service_comments&host='+encodeURIComponent(host_name)+'&service='+encodeURIComponent(service)+"&backend="+peer_key);
}

/* callback to show popup with service downtimes */
function service_downtimes_popup(host_name, service, peer_key) {
    generic_downtimes_popup("Downtimes: "+host_name+' - '+service, url_prefix+'cgi-bin/parts.cgi?part=_service_downtimes&host='+encodeURIComponent(host_name)+'&service='+encodeURIComponent(service)+"&backend="+peer_key);
}

/* callback to show popup host/service downtimes */
function generic_downtimes_popup(title, url) {
    overcard({
        'body':    '<div id="comments_downtimes_popup"><div class="p-2 spinner"></div><\/div>',
        'caption':  title,
        'minWidth': 800,
        'callback': function(doc) {
            jQuery('#comments_downtimes_popup', doc).load(url, function() {
                var container = doc.getElementById("overcard");
                element_check_visibility(container);
            });
        }
    });
}

function show_plugin_output_popup(target, host, service, backend, escape_html, overcard_options) {
    var caption = decodeURIComponent(host);
    if(service != '') {
        caption += " - "+decodeURIComponent(service);
    }
    caption = escapeHTML(caption);
    overcard(jQuery.extend({ 'bodyCls': 'p-2', 'body': "<div class='plugin_output'><\/div><div class='long_plugin_output'><\/div>", 'caption': caption}, overcard_options));
    jQuery('#overcard .plugin_output').html("<div class='spinner w-8 h-8'><\/div>");

    var url = url_prefix+'r/sites/'+encodeURIComponent(backend)+'/services/'+encodeURIComponent(host)+"/"+encodeURIComponent(service)+"?columns=plugin_output,long_plugin_output"
    if(service == '') {
        url = url_prefix+'r/sites/'+encodeURIComponent(backend)+'/hosts/'+encodeURIComponent(host)+"?columns=plugin_output,long_plugin_output"
    }
    jQuery.get(url, {}, function(data, status, req) {
        jQuery('#overcard .plugin_output').html("");
        if(!data || !data[0]) {
            jQuery('#overcard .plugin_output').html("failed to fetch details: "+status);
            return;
        }
        if(escape_html) {
            var text = jQuery("<div>").text(data[0]["plugin_output"]).html().replace(/\\n/g, "<br>");
            jQuery('#overcard .plugin_output').html(text);
            var text = jQuery("<div>").text(data[0]["long_plugin_output"]).html().replace(/\\n/g, "<br>");
            jQuery('#overcard .long_plugin_output').html(text);
        } else {
            jQuery('#overcard .plugin_output').html(data[0]["plugin_output"].replace(/\\n/g, "<br>"));
            jQuery('#overcard .long_plugin_output').html(data[0]["long_plugin_output"].replace(/\\n/g, "<br>"));
        }
    });
}

function fetch_long_plugin_output(target, host, service, backend, escape_html) {
    jQuery('.long_plugin_output').html("<div class='spinner w-8 h-8'><\/div>");
    var url = url_prefix+'cgi-bin/status.cgi?long_plugin_output=1';
    if(escape_html) {
        jQuery.post(url, {
            host:    host,
            service: svc,
            backend: peer_key
        }, function(text, status, req) {
            text = jQuery("<div>").text(text).html().replace(/\\n/g, "<br>");
            jQuery('.long_plugin_output').html(text)
        });
    } else {
        jQuery('.long_plugin_output').load(url, {
            host:    host,
            service: svc,
            backend: peer_key
        }, function(text, status, req) {
        });
    }
}

/* callback to show service popup */
function fetch_svc_info_popup(el, host, svc, peer_key) {
    jQuery('.service_popup_content').html("<div class='spinner w-10 h-10 border-4'><\/div>");
    var url = url_prefix+'cgi-bin/parts.cgi?part=_service_info_popup';
    jQuery('.service_popup_content').load(url, {
        host:    host,
        service: svc,
        backend: peer_key
    }, function(text, status, req) {
    });
}

function initTableRowSorting(tblId) {
    if(!has_jquery_ui()) {
        load_jquery_ui(function() {
            initTableRowSorting(tblId);
        });
        return;
    }
    if(already_sortable["table_"+tblId]) {
        return;
    }
    already_sortable["table_"+tblId] = true;

    jQuery('#'+tblId).sortable({
        items                : 'TR.sortable',
        helper               : 'clone',
        tolerance            : 'pointer',
        update               : function( event, ui ) {
        }
    });
}

function initExcelExportSorting() {
    if(!has_jquery_ui()) {
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
function initStatusTableColumnSorting(pane_prefix, table_class) {
    if(!has_jquery_ui()) {
        load_jquery_ui(function() {
            initStatusTableColumnSorting(pane_prefix, table_class);
        });
        return;
    }
    if(already_sortable[pane_prefix]) {
        return;
    }
    already_sortable[pane_prefix] = true;

    jQuery('TABLE.'+table_class).each(function(j, table) {
        jQuery(table).find('thead > tr:first-child').sortable({
            items                : '> th',
            helper               : 'clone',
            tolerance            : 'pointer',
            update               : function( event, ui ) {
                var oldIndexes = [];
                var rowsToSort = {};
                var base_table;
                // remove all current rows from the column selector, they will be later readded in the right order
                jQuery('#'+pane_prefix+'_columns_table > tbody > tr').each(function(i, el) {
                    base_table = el.parentNode;
                    var row = el.parentNode.removeChild(el);
                    var field = jQuery(row).find("input").val();
                    rowsToSort[field] = row;
                    oldIndexes.push(field);
                });
                // fetch the target column order based on the current status table header
                var target = [];
                jQuery(table).find('thead > tr:first-child > th').each(function(i, el) {
                    var col = get_column_from_classname(el);
                    if(col) {
                        target.push(col);
                    }
                });
                jQuery(target).each(function(i, el) {
                    if(rowsToSort[el]) {
                        base_table.appendChild(rowsToSort[el]);
                    }
                });
                // remove the current column header and readd them in original order, so later ordering wont skip headers
                var currentHeader = {};
                jQuery(table).find('thead > tr:first-child > th').each(function(i, el) {
                    base_table = el.parentNode;
                    var row = el.parentNode.removeChild(el);
                    var col = get_column_from_classname(el);
                    if(col) {
                        currentHeader[col] = row;
                    }
                });
                oldIndexes.forEach(function(el, i) {
                    if(currentHeader[el]) {
                        base_table.appendChild(currentHeader[el]);
                    }
                });
                updateStatusColumns(pane_prefix, false);
            }
        })
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
    jQuery('TABLE.'+table_class+' > thead > tr:first-child > th').dblclick(function(evt) {
        evt.preventDefault();
        evt.stopImmediatePropagation();
        evt.stopPropagation();
        window.clearTimeout(thrukState.sortClickTimer);
        var th   = evt.target;
        if(th.tagName == "A") { th = th.parentNode; }
        var text = (th.innerText || '').replace(/\s*$/, '');
        jQuery(th).find("*").css("display", "none");
        jQuery("<input type='text' class='header_inline_edit' value='"+text+"'></form>").appendTo(th);
        window.setTimeout(function() {
            jQuery(th).find('INPUT').focus();
            var input = jQuery(th).find('INPUT')[0];
            setCaretToPos(input, text.length);
            jQuery(input).on('keyup blur', function (e) {
                /* submit on enter/return */
                if(e.keyCode == 13 || e.type == "blur") {
                    // restore sort links
                    jQuery(th).find("*").css("display", "");
                    jQuery(th).find("INPUT").remove();
                    var col  = get_column_from_classname(th);
                    var orig = jQuery('#'+pane_prefix+'_col_'+col)[0].title;

                    jQuery(th).find("A").text(input.value);

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
                    jQuery(th).find("*").css("display", "");
                    jQuery(th).find("INPUT").remove();
                }
            });
        }, 100);
    });
    /* enable changing columns header name */
    jQuery('#'+pane_prefix+'_columns_table tbody td.js-column-renameable').dblclick(function(evt) {
        evt.preventDefault();
        evt.stopImmediatePropagation();
        evt.stopPropagation();
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
    var tables = jQuery('.'+id+'_table');
    if(!tables || tables.length == 0) {
        if(thruk_debug_js) { alert("ERROR: no table found in updateStatusColumns(): " + id); }
    }
    jQuery.each(tables, function(i, table) {
        table.style.visibility = "hidden";
        updateStatusColumnsTable(id, table, reloadRequired);
        table.style.visibility = "visible";
    });
}

function updateStatusColumnsTable(id, table, reloadRequired) {
    var changed = false;
    if(reloadRequired == undefined) { reloadRequired = true; }

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
        var current   = (jQuery("A", firstRow.cells[i]).text() || '').trim();
        var newHeadEl = document.getElementById(el.id+'n');
        if(!newHeadEl) {
            if(thruk_debug_js) { alert("ERROR: header element not found in updateStatusColumns(): " + el.id+'n'); }
            return;
        }
        var newHead = newHeadEl.innerHTML.trim();
        if(current != newHead) {
            jQuery("A", firstRow.cells[i]).text(newHead)
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

            var lenghtThresholds = table.dataset["baseColumnLength"];
            if(reloadRequired && table.rows[1] && table.rows[1].cells.length <= lenghtThresholds) {
                additionalParams["autoShow"] = id+"_columns_select";
                delete removeParams['autoShow'];
                jQuery('#'+id+"_columns_select").append("<div class='absolute top-0 left-0 h-full w-full bodyBG font-semibold opacity-95'><div class='spinner w-8 h-8'><\/div><br>fetching table...<\/div>");
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
}

function setDefaultColumns(type, pane_prefix, value) {
    updateUrl();
    if(value == undefined) {
        var urlArgs  = toQueryParams();
        value = urlArgs[pane_prefix+"columns"];
    }

    var data = {
        action:   'set_default_columns',
        type:      type,
        value:     value,
        CSRFtoken: CSRFtoken
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
            thruk_xhr_error('setting default failed: ', '', textStatus, jqXHR, errorThrown);
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
            thruk_xhr_error('fetching side nav sections failed: ', '', textStatus, jqXHR, errorThrown);
        }
    });
    return(false);
}

function submitFormInBackground(form, cb) {
    var data = jQuery(form).serializeArray();
    var url  = jQuery(form).attr("action");
    jQuery.ajax({
        url:   url,
        data: data,
        type: 'POST',
        headers: {
            'Accept': "application/json; charset=utf-8"
        },
        success: function(data, textStatus, jqXHR) {
            if(cb) {
                cb(form);
            }
        },
        error: ajax_xhr_error_logonly
    });
    return(false);
}

function send_form_in_background_and_reload(btn, extraData) {
    var form = jQuery(btn).parents('FORM');
    if(extraData) {
        for(var key in extraData) {
            jQuery('<input />', {
                type:  'hidden',
                name:   key,
                value:  extraData[key]
            }).appendTo(form);
        }
    }
    submitFormInBackground(form, reloadPage);
    setBtnSpinner(btn);
    return(false);
}

function broadcast_show_list(incr) {
    var broadcasts = jQuery(".js-broadcast-panel div.broadcast");
    var curIdx = 0;
    jQuery(broadcasts).each(function(i, n) {
        if(jQuery(n).is(":visible")) {
            jQuery(n).addClass("hidden");
            curIdx = i;
            return(false);
        }
    });
    var newIdx = curIdx+incr;
    jQuery(broadcasts[newIdx]).removeClass("hidden");
    jQuery(".js-broadcast-panel .js-next").css('visibility', '');
    jQuery(".js-broadcast-panel .js-previous").css('visibility', '');
    if(newIdx == broadcasts.length -1) {
        jQuery(".js-broadcast-panel .js-next").css('visibility', 'hidden');
    }
    if(newIdx == 0) {
        jQuery(".js-broadcast-panel .js-previous").css('visibility', 'hidden');
    }
}

function broadcast_dismiss() {
    jQuery('.js-broadcast-panel').hide();
    jQuery.ajax({
        url: url_prefix + 'cgi-bin/broadcast.cgi',
        data: {
            action:   'dismiss',
            CSRFtoken: CSRFtoken
        },
        type: 'POST',
        success: function(data) {},
        error: function(jqXHR, textStatus, errorThrown) {
            thruk_xhr_error('marking broadcast as read failed: ', '', textStatus, jqXHR, errorThrown);
        }
    });
    return(false);
}

function looks_like_regex(str) {
    if(str != undefined && str.match(/[\^\|\*\{\}\[\]]/)) {
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
    if(elements[newIdx] == undefined) {
        jQuery(elements[curIdx]).show();
        return;
    }
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

//returns true if array contains given element
function array_contains(list, needle) {
    if(!list) {
        return(false);
    }
    for(var x=0; x<list.length; x++) {
        if(list[x] === needle) {
            return(true);
        }
    }
    return(false);
}

// checks if user has given group
function hasContactGroup(name) {
    return(array_contains(remote_groups, name));
}

// show stacktrace controls on error page
function nice_stacktrace_init() {
    jQuery(".external").hide();
}

function nice_stacktrace_expand() {
    jQuery(".external").toggle();
}

function removeClass(el, cls) {
    jQuery(el).removeClass(cls);
}
function toggleClass(el, cls) {
    jQuery(el).toggleClass(cls);
}

function updateExportLink(input) {
    var newUrl = getCurrentUrl(false);
    input.value = newUrl;
}

function fitText(el) {
    el = jQuery(el);
    var boxWidth  = el.width();
    var textWidth = el[0].scrollWidth;
    if(textWidth > boxWidth) {
        var size = parseInt(el.css("font-size"), 10);
        el.css("font-size", ""+Math.floor(size * (boxWidth/textWidth))+"px");
    }
}

function togglePasswordVisibility(ev) {
    if(!ev || !ev.target) { return; }
    var el = jQuery(ev.target);
    el.toggleClass("uil-eye");
    el.toggleClass("uil-eye-slash");
    if(el.hasClass("uil-eye")) {
        jQuery("DIV.togglePassword INPUT").attr('type', 'text');
    } else {
        jQuery("DIV.togglePassword INPUT").attr('type', 'password');
    }
}

function copyCode(evt, id) {
    var text = id;
    var pre  = document.getElementById(id)
    if(pre) {
        var code = pre.querySelector("code");
        text = pre.value || pre.innerText;
        if(code) {
            text = code.innerText;
        }
    }
    var result      = "Copied!";
    var removeDelay = 1500;
    if(navigator.clipboard) {
        navigator.clipboard.writeText(text);
    } else {
        removeDelay = 3000;
        result = "Failed to copy";
        if(!window.isSecureContext) {
            result = "https only feature";
        }
    }

    if(!evt) { return; }

    // create tooltip element
    var tooltip = jQuery('<div id="copytooltip" class="tooltiptext"><\/div>').appendTo(document.body)[0];
    tooltip.innerHTML = result;

    // get the position of the hover element
    var boundBox = evt.target.getBoundingClientRect();
    var coordX = boundBox.left;
    var coordY = boundBox.top;

    var width = jQuery(tooltip).width();

    // adjust bubble position
    tooltip.style.left = (coordX - (width/2) + 5).toString() + "px";
    tooltip.style.top = (coordY - 25).toString() + "px";

    // make bubble VISIBLE
    tooltip.style.visibility = "visible";
    tooltip.style.opacity = "1"

    window.setTimeout(function () {
        jQuery(tooltip).remove();
    }, removeDelay);
}

// returns true if query ui is available
function has_jquery_ui() {
    if(jQuery().sortable) {
        return true;
    }
    return false;
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
function print_action_menu(src, options) {
    var backend     = options.backend;
    var host        = options.host;
    var service     = options.service;
    var orientation = options.orientation;
    var show_title  = options.show_title;

    /* obtain reference to current script tag so we could insert the icons here */
    var scriptTag = document.currentScript;

    try {
        if(orientation == undefined) { orientation = 'b-r'; }
        if(typeof src === "function") {
            src = src({config: null, submenu: null, menu_id: 'actionmenu_'+menu_nr, backend: backend, host: host, service: service});
        }
        src = is_array(src) ? src : [src];
        jQuery(src).each(function(i, el) {
            var icon = action_menu_icon(el.icon, options);
            icon.title     = replace_macros(el.title ? el.title : '', undefined, options);
            icon.className += ' action_icon '+(el.menu || el.action ? 'clickable' : '' );
            if(el.menu) {
                icon.nr = menu_nr;
                jQuery(icon).bind("click", function(e) {
                    /* open and show menu */
                    e.preventDefault();
                    e.stopImmediatePropagation();
                    e.stopPropagation();
                    show_action_menu(icon, el.menu, icon.nr, backend, host, service, orientation);
                });
                menu_nr++;
            }
            var item = icon;

            if(el.action) {
                var link = document.createElement('a');
                set_action_menu_link_action(link, el, options);
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

            scriptTag.parentNode.appendChild(item);
            if(show_title && icon.title) {
                var title = document.createTextNode(replace_macros(icon.title, undefined, options));
                scriptTag.parentNode.appendChild(title);
            }
        });
    }
    catch(err) {
        jQuery(scriptTag.parentNode).append('<i class="uil uil-exclamation round yellow" title="'+err+'"><\/i>');
    }
}

/* create icon item */
function action_menu_icon(iconUrl, options) {
    if(iconUrl.match(/^(uil\-|uil\s+)/)) {
        var icon = document.createElement('i');
        icon.className = "uil "+iconUrl;
        return(icon);
    }
    if(iconUrl.match(/^fa\-/)) {
        var icon = document.createElement('i');
        icon.className = "fa-solid "+iconUrl;
        return(icon);
    }
    var icon = document.createElement('img');
    iconUrl  = replace_macros(iconUrl, undefined, options);
    icon.src = iconUrl;
    icon.style.width  = "20px";
    icon.style.height = "20px";
    try {
        // use data url in reports
        if(action_images[iconUrl]) {
            icon.src = action_images[iconUrl];
        }
    } catch(e) {}
    return(icon);
}

/* create link item */
function set_action_menu_link_action(link, menu_entry, options) {
    var href            = replace_macros(menu_entry.action, undefined, options);
    link.href           = href;
    link.dataset["url"] = href; // href is normalized for ex. in chrome which lowercases and urlescapes the link
    if(menu_entry.target) { link.target = menu_entry.target; }
}

/* set a single attribute for given item/link */
function set_action_menu_attr(item, data, backend, host, service, callback) {
    var toReplace = {};
    for(var key in data) {
        // those key are handled separately already
        if(key == "icon" || key == "action" || key == "menu" || key == "label") {
            continue;
        }

        var attr = String(data[key]);
        attr = replace_macros(attr, undefined, {host: host, service: service});
        if(attr.match(/(\$|%24)/)) {
            toReplace[key] = attr;
            continue;
        }
        if(key.match(/^on/)) {
            if(!data.disabled) {
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
            }
        } else {
            item[key] = attr;
        }
    }
    if(Object.keys(toReplace).length > 0) {
        jQuery.ajax({
            url: url_prefix + 'cgi-bin/status.cgi?replacemacros=1',
            data: {
                host:      host,
                service:   service,
                backend:   backend,
                dataJson:  JSON.stringify(toReplace),
                CSRFtoken: CSRFtoken
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
                thruk_xhr_error('could not replace macros: ', '', textStatus, jqXHR, errorThrown);
            }
        });
    } else {
        callback();
    }
}

/* renders the action menu when openend */
var action_menu_options = {};
function show_action_menu(icon, items, nr, backend, host, service, orientation) {
    resetRefresh();

    var id = 'actionmenu_'+nr;
    var container = document.getElementById(id);
    if(container) {
        // always recreate the menu
        container.parentNode.removeChild(container);
        container = null;
    }

    window.setTimeout(function() {
        // otherwise the reset comes before we add our new class
        jQuery(icon).addClass('active');
    }, 30);

    container = document.createElement('div');
    container.className     = 'action_menu';
    container.id            = id;
    container.style.visible = 'hidden';

    var menu = document.createElement('ul');
    container.appendChild(menu);

    // make arguments available
    action_menu_options = {
        host:    host,
        service: service,
        backend: backend
    };

    if(typeof(items) === "function") {
        menu.appendChild(actionGetMenuItem({icon: 'spinner', label: 'loading...'}, id, backend, host, service));
        jQuery.when(items({config: null, submenu: menu, menu_id: id, backend: backend, host: host, service: service}))
        .done(function(data) {
            removeChilds(menu);
            if(!data || !is_array(data)) { return; }
            jQuery(data).each(function(i, submenuitem) {
                menu.appendChild(actionGetMenuItem(submenuitem, id, backend, host, service));
            });
            check_position_and_show_action_menu(id, icon, container, orientation);
            return;
        });
    } else {
        jQuery(items).each(function(i, el) {
            menu.appendChild(actionGetMenuItem(el, id, backend, host, service));
        });
    }

    document.body.appendChild(container);
    check_position_and_show_action_menu(id, icon, container, orientation);
}

function actionGetMenuItem(el, id, backend, host, service) {
    var options = { host: host, service: service, backend: backend};
    var item = document.createElement('li');
    if(el == "-") {
        var hr = document.createElement('hr');
        item.appendChild(hr);
        item.className = 'no-hover';
        return(item);
    }

    var link = document.createElement('a');
    if(el.disabled) {
        item.className = 'disabled no-hover';
    } else {
        item.className = 'clickable';
    }
    if(el.disabled || el.menu || !el.action) {
        jQuery(link).off("click").on("click", function(e) {
            e.preventDefault();
            return(false);
        });
    }
    if(el.icon) {
        var span       = document.createElement('span');
        span.className = 'icon';
        if(el.icon == "spinner") {
            span.innerHTML = "<div class='spinner'><\/div>";
        } else {
            var img   = action_menu_icon(el.icon, options);
            img.title = replace_macros(el.title ? el.title : '', undefined, options);
            span.appendChild(img);
        }
        link.appendChild(span);
    }

    var label;
    if(el.html) {
        label = document.createElement('div');
        label.innerHTML = el.html;
    } else {
        label = document.createElement('span');
        label.innerHTML = replace_macros(el.label, undefined, options);
    }
    link.appendChild(label);

    if(el.action && !el.disabled) {
        if(typeof el.action === "function") {
            jQuery(link).bind("click", {backend: backend, host: host, service: service}, el.action);
        } else {
            set_action_menu_link_action(link, el, options);
        }
    }
    if(el.menu) {
        var expandLabel = document.createElement('span');
        expandLabel.className = "expandable";
        expandLabel.innerHTML = '<i class="uil uil-angle-right"><\/i>';
        link.appendChild(expandLabel);
        var submenu = document.createElement('ul');
        submenu.className = "submenu";
        submenu.style.display = 'none';
        item.appendChild(submenu);
        item.style.position = 'relative';
        jQuery(link).bind("mouseover", function() {
            expandActionSubMenu(item, el, submenu, id, backend, host, service);
        });
    }
    jQuery(link).bind("mouseover", function() {
        // hide all submenus (unless required)
        jQuery('#'+id+' .submenu').each(function(i, s) {
            if(s.parentNode != item) {
                s.required = false;
            }
        });
        var p = link;
        while(p.parentNode && p.id != id) {
            if(jQuery(p).hasClass('submenu')) {
                p.required = true;
            }
            p = p.parentNode;
        }
        jQuery('#'+id+' .submenu').each(function(i, s) {
            if(!s.required) {
                s.ready = false;
                removeChilds(s);
                s.style.display = "none";
            }
        });
    });

    item.appendChild(link);

    /* apply other attributes */
    set_action_menu_attr(link, el, backend, host, service, function() {
        // must be added as callback, otherwise the order of the binds gets mixed up and "onclick confirms" would be called after the click itself
        check_server_action(id, link, backend, host, service, undefined, undefined, undefined, el);
    });
    return(item);
}

function expandActionSubMenu(parent, el, submenu, id, backend, host, service) {
    if(submenu.ready) { return; }

    submenu.required = true;
    submenu.ready = true;
    if(is_array(el.menu)) {
        jQuery(el.menu).each(function(i, submenuitem) {
            submenu.appendChild(actionGetMenuItem(submenuitem, id, backend, host, service));
        });
        submenu.style.display = "";
        checkSubMenuPosition(id, parent, submenu);
        return;
    }

    if(typeof el.menu !== "function") {
        return;
    }
    submenu.appendChild(actionGetMenuItem({icon: 'spinner', label: 'loading...'}, id, backend, host, service));
    submenu.style.display = "";
    checkSubMenuPosition(id, parent, submenu);

    jQuery.when(el.menu({config: el, submenu: submenu, menu_id: id, backend: backend, host: host, service: service}))
        .done(function(data) {
            removeChilds(submenu);
            if(!data || !is_array(data)) { return; }
            jQuery(data).each(function(i, submenuitem) {
                submenu.appendChild(actionGetMenuItem(submenuitem, id, backend, host, service));
            });
            checkSubMenuPosition(id, parent, submenu);
            return;
        });
}

function checkSubMenuPosition(id, parent, submenu) {
    var coords = jQuery('#'+id).offset();
    var screenW = jQuery(document).width();
    submenu.style.top  = "-1px";
    if(coords.left > (screenW / 2)) {
        // we are on the right side of the screen, so place it left of the parent
        var w = jQuery(submenu).outerWidth();
        submenu.style.left = (Math.floor(-w)) + "px";
    } else {
        // place right of parent
        var w = jQuery(parent).outerWidth();
        submenu.style.left = (Math.floor(w)) + "px";
    }
}

function check_position_and_show_action_menu(id, icon, container, orientation) {
    var coords = jQuery(icon).offset();
    if(orientation == 'b-r') {
        container.style.left = (Math.floor(coords.left)) + "px";
    }
    else if(orientation == 'b-l') {
        var w = jQuery(container).outerWidth();
        container.style.left = (Math.floor(coords.left)-w) + "px";
    } else {
        if(thruk_debug_js) { alert("ERROR: unknown orientation in show_action_menu(): " + orientation); }
    }
    container.style.top  = (Math.floor(coords.top) + icon.offsetHeight) + "px";

    jQuery('#'+id+' .submenu').css('display', 'none')
    showElement(id, undefined, true, 'DIV#'+id+' DIV.shadowcontent', reset_action_menu_icons);
}

/* set onclick handler for server actions */
function check_server_action(id, link, backend, host, service, server_action_url, extra_param, callback, config) {
    var href = link.dataset["url"] || link.href;
    href = replace_macros(href, undefined, {host: host, service: service});
    // server action urls
    if(href.match(/^server:\/\//)) {
        if(server_action_url == undefined) {
            server_action_url = url_prefix + 'cgi-bin/status.cgi?serveraction=1';
        }
        var data = {
            host:      host,
            service:   service,
            backend:   backend,
            link:      href,
            CSRFtoken: CSRFtoken
        };
        if(extra_param) {
            for(var key in extra_param) {
                data[key] = extra_param[key];
            }
        }
        if(!link.serverActionClickHandlerAdded) {
            link.serverActionClickHandlerAdded = true;
            jQuery(link).bind("click", function() {
                jQuery(link).find('IMG, I, SPAN.icon').css("display", "none");
                jQuery(link).prepend('<div class="spinner"><\/div>');
                if(config == undefined) { config = {}; }
                jQuery.ajax({
                    url: server_action_url,
                    data: data,
                    type: 'POST',
                    success: function(data) {
                        thruk_message(data.rc, data.msg, config.close_timeout);
                        if(id) { remove_close_element(id); jQuery('#'+id).remove(); }
                        reset_action_menu_icons();
                        jQuery(link).find('IMG, I, SPAN.icon').css("display", "");
                        jQuery(link).find('DIV.spinner').remove();
                        if(callback) { callback(data); }
                    },
                    error: function(jqXHR, textStatus, errorThrown) {
                        thruk_xhr_error('server action failed: ', '', textStatus, jqXHR, errorThrown, false, config.close_timeout);
                        if(id) { remove_close_element(id); jQuery('#'+id).remove();  }
                        reset_action_menu_icons();
                        jQuery(link).find('IMG, I, SPAN.icon').css("display", "");
                        jQuery(link).find('DIV.spinner').remove();
                    }
                });
                return(false);
            });
        }
    }
    // normal urls
    else {
        if(!href.match(/\$/)) {
            // no macros, no problems
            return;
        }
        jQuery(link).bind("mouseover", function() {
            if(!href.match(/\$/)) {
                // no macros, no problems
                return(true);
            }
            if(href.match(/^javascript:/)) {
                // skip javascript links, they will be replace on click
                return(true);
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
            if(!href.match(/\$/)) {
                // no macros, no problems
                return(true);
            }
            if(!href.match(/^javascript:/)) {
                return(true);
            }
            jQuery.ajax({
                url: url_prefix + 'cgi-bin/status.cgi?replacemacros=1',
                data: {
                    host:      host,
                    service:   service,
                    backend:   backend,
                    data:      href,
                    CSRFtoken: CSRFtoken
                },
                type: 'POST',
                success: function(data) {
                    if(data.rc != 0) {
                        thruk_message(1, 'could not replace macros: '+ data.data);
                    } else {
                        link.href = data.data
                        link.click();
                        link.href = href;
                    }
                },
                error: function(jqXHR, textStatus, errorThrown) {
                    thruk_xhr_error('could not replace macros: ', '', textStatus, jqXHR, errorThrown);
                }
            });
            return(false);
        });
    }
}

/* replace common macros */
function replace_macros(input, macros, core_macros) {
    var out = input;
    if(out == undefined) {
        return(out);
    }
    if(macros != undefined) {
        for(var key in macros) {
            var regex  = new RegExp('{{'+key+'}}', 'g');
            out = out.replace(regex, macros[key]);
        }
        return(out);
    }

    // replace some known naemon like macros
    if(core_macros) {
        if(core_macros.host)    { out = out.replace(/\$HOSTNAME\$/g,    core_macros.host); }
        if(core_macros.service) { out = out.replace(/\$SERVICEDESC\$/g, core_macros.service); }
    }

    out = out.replace(/\{\{\s*theme\s*\}\}/g, theme);
    out = out.replace(/\{\{\s*remote_user\s*\}\}/g, remote_user);
    out = out.replace(/\{\{\s*site\s*\}\}/g, omd_site);
    out = out.replace(/\{\{\s*prefix\s*\}\}/g, url_prefix);
    return(out);
}

/* remove active class from action menu icons */
function reset_action_menu_icons() {
    jQuery('.action_icon').removeClass('active');
}

/* close all action menus */
function action_menu_close() {
    reset_action_menu_icons();
    jQuery('.action_menu').hide();
    try {
        Ext.getCmp("iconActionMenu").close();
    } catch(e) {}
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

/* return table with performance data */
function perf_table(container) {
    if(container.firstChild) { return; } // already set
    var result = perf_table_data(container.dataset);
    if(result) {
        jQuery(container).html(result);
        return(true);
    }
    jQuery(container).remove();
    return(false);
}

function perf_table_data(dataset) {
    var add_link      = dataset.addLink;
    var state         = dataset.state;
    var plugin_output = dataset.pluginOutput;
    var perfdata      = dataset.perfdata;
    var check_command = dataset.checkCommand;
    var pnp_url       = dataset.pnpUrl;
    var is_host       = dataset.isHost;
    var no_title      = dataset.noTitle;

    if(is_host == undefined) { is_host = false; }
    if(is_host && state == 1) { state = 2; } // set critical state for host checks
    var perf_data = parse_perf_data(perfdata);
    var cls       = 'not-clickable';
    if(perf_data.length == 0) { return false; }
    if(pnp_url != '') {
        cls = 'clickable';
    }

    var res = perf_parse_data(check_command, state, plugin_output, perf_data);
    if(!res) {
        return(false);
    }
    var result = '';
    res = res.reverse();
    for(var nr=0; nr<res.length; nr++) {
        if(res[nr] != undefined) {
            var graph = res[nr];
            result += '<span class="perf-bar-container '+cls+'" style="width:'+graph.div_width+'px;" '+(no_title ? '' : 'title="'+graph.title+'"')+'>';
            result += '<span class="bg"><\/span>';
            result += '<span class="bar '+graph.cls+'" style="width:'+ graph.bar_width +'px;" '+(no_title ? '' : 'title="'+graph.title+'"')+'><\/span>';
            if(graph.warn_width_min != null) {
                result += '<span class="threshold warn '+cls+'" style="margin-left:'+graph.warn_width_min+'px;"><\/span>';
            }
            if(graph.crit_width_min != null) {
                result += '<span class="threshold crit '+cls+'" style="margin-left:'+graph.crit_width_min+'px;"><\/span>';
            }
            if(graph.warn_width_max != null) {
                result += '<span class="threshold warn '+cls+'" style="margin-left:'+graph.warn_width_max+'px;"><\/span>';
            }
            if(graph.crit_width_max != null) {
                result += '<span class="threshold crit '+cls+'" style="margin-left:'+graph.crit_width_max+'px;"><\/span>';
            }
            result += '<\/span>';
        }
    }
    if(result == '') {
        return(false);
    }

    if(add_link && pnp_url != '') {
        var rel_url = pnp_url.replace('/graph?', '/popup?');
        if(perf_bar_pnp_popup == 1) {
            result = "<a href='"+pnp_url+"' class='tips' rel='"+rel_url+"'>"+result+"<\/a>";
        } else {
            result = "<a href='"+pnp_url+"'>"+result+"<\/a>";
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
            var cls = 'green';
            if(state == 1) { cls = 'yellow'; }
            if(state == 2) { cls = 'red'; }
            if(state == 4) { cls = 'gray'; }
            perc = Math.round(perc / 100 * size);
            var warn_perc_min = null;
            if(d.warn_min != '' && d.warn_min > d.min) {
                warn_perc_min = plot_point(d.warn_min, d.max, size);
                if(warn_perc_min == 0) {warn_perc_min = null;}
            }
            var crit_perc_min = null;
            if(d.crit_min != '' && d.crit_min > d.min) {
                crit_perc_min = plot_point(d.crit_min, d.max, size);
                if(crit_perc_min == 0) {crit_perc_min = null;}
                if(crit_perc_min == warn_perc_min) {warn_perc_min = null;}
            }
            var warn_perc_max = null;
            if(d.warn_max != '' && d.warn_max < d.max) {
                warn_perc_max = plot_point(d.warn_max, d.max, size);
                if(warn_perc_max == size) {warn_perc_max = null;}
            }
            var crit_perc_max = null;
            if(d.crit_max != '' && d.crit_max <= d.max) {
                crit_perc_max = plot_point(d.crit_max, d.max, size);
                if(crit_perc_max == size) {crit_perc_max = null;}
                if(crit_perc_max == warn_perc_max) {warn_perc_max = null;}
            }
            var graph = {
                title:          d.key + ': ' + perf_reduce(d.val, d.unit) + ' of ' + perf_reduce(d.max, d.unit),
                div_width:      size,
                bar_width:      perc,
                cls:            cls,
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
        if(plugin_output) {
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
    var abs = Math.abs(value);
    if(abs >= 100) { return(value.toFixed(0)); }
    if(abs <  10)  { return(value.toFixed(2)); }
    return(value.toFixed(1));
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
      pagetype = 'hostdetail';
    }
    else if(type == 'service') {
      pagetype = 'servicedetail';
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
        if(!elem.onclick) {
            elem.onclick = selectService;
        }
    }
}

/* add additional eventhandler to object */
function addEvent( obj, type, fn ) {
  //console.log("addEvent("+obj+","+type+", ...)");
  if ( obj.attachEvent ) {
    obj['e'+type+fn] = fn;
    obj[type+fn] = function(){obj['e'+type+fn]( window.event );}
    obj.attachEvent( 'on'+type, obj[type+fn] );
  } else
    obj.addEventListener( type, fn, false );
}

/* remove an eventhandler from object */
function removeEvent( obj, type, fn ) {
  //console.log("removeEvent("+obj+","+type+", ...)");
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
    var nr = 0;
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

    for(var x = 0; x < elems.length; x++) {
        if(style == 'original') {
            jQuery(elems[x]).removeClass("tableRowSelected");
        }
        else {
            jQuery(elems[x]).addClass("tableRowSelected");
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
    resetRefresh();
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
        if(event.target.tagName == 'A' || event.target.tagName == 'IMG' || event.target.tagName == 'I') {
            resetServiceRow(event);
            return;
        }
    }
    else if (event && (event.id || event.parentNode)) {
        row_id = getFirstParentId(event);
    }
    if(!row_id) {
        return;
    }

    selectServiceByIdEvent(row_id, state, event);
    unselectCurrentSelection();
}

/* select this service */
function selectServiceByIdEvent(row_id, state, event) {
    resetRefresh();
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
    resetRefresh();
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
    var row = document.getElementById(row_id);
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
    resetRefresh();
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
        if(event.target.tagName == 'A' || event.target.tagName == 'IMG' || event.target.tagName == 'I') {
            resetHostRow(event);
            return;
        }
    }
    else if (event && (event.id || event.parentNode)) {
        row_id = getFirstParentId(event);
    }
    if(!row_id) {
        return;
    }

    selectHostByIdEvent(row_id, state, event);
    unselectCurrentSelection();
}


/* select this service */
function selectHostByIdEvent(row_id, state, event) {
    resetRefresh();
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
    resetRefresh();
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
    var row = document.getElementById(row_id);
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
    resetRefresh();
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
            var tmp = lastRowHighlighted;
            lastRowHighlighted = undefined;
            setRowStyle(tmp, 'original', 'service');
        }
        return;
    }
    removeRowStyle(row_id, ['tableRowHover'], 'service');
}

/* reset row style unless it has been clicked */
function resetHostRow(event) {
    resetRefresh();
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
            var tmp = lastRowHighlighted;
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
    return false;
}
/* select services by class name */
function selectServicesByClass(classes) {
    jQuery.each(classes, function(i, classname) {
        jQuery('DIV.mainTable').find(classname).each(function(i, obj) {
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
    return false;
}

/* toggle the visibility of the command pane */
function toggleCmdPane(state) {
  if(state == 1) {
    showElement('cmd_pane');
  }
  else {
    hideElement('cmd_pane');
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
        btn.innerHTML = "submit command for " + text;
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

    var ids_form = document.getElementById('selected_ids');
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
        var service_form = document.getElementById('selected_services');
        service_form.value = services.join(',');

        var hosts = new Array();
        jQuery.each(selectedHosts, function(row_id, blah) {
            if(row_id.substr(0,4) == "hst_") { obj_hash = hst_Hash; }
            if(row_id.substr(0,4) == "svc_") { obj_hash = svc_Hash; }
            if(row_id.substr(0,4) == "dfl_") { obj_hash = dfl_Hash; }
            row_id = row_id.substr(4);
            hosts.push(obj_hash[row_id]);
        });
        var host_form = document.getElementById('selected_hosts');
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
    var main = jQuery("MAIN").first();
    var scroll = "";
    scroll +=     Number(main.scrollLeft()).toFixed(0);
    scroll += "_"+Number(main.scrollTop()).toFixed(0);

    var mainTable = jQuery(".mainTable").first();
    if(mainTable.length > 0) {
        scroll += "_"+Number(mainTable.scrollLeft()).toFixed(0);
        scroll += "_"+Number(mainTable.scrollTop()).toFixed(0);
    }  else {
        scroll += "__";
    }

    var navTable = jQuery("DIV.navsectionlinks.scrollauto").first();
    if(navTable.length > 0) {
        scroll += "_"+Number(navTable.scrollTop()).toFixed(0);
    }  else {
        scroll += "_";
    }

    return scroll;
}

/* submit a form by id */
function submit_form() {
    var btn = document.getElementById(submit_form_id);
    btn.submit();
}

function submitFormIfChanged(el) {
    var form = jQuery(el)[0];
    if(!form) {
        if(thruk_debug_js) { alert("ERROR: no form found in submitFormIfChanged(): " + el); }
        return;
    }
    var data = jQuery(form).serialize();
    var url  = jQuery(form).attr("action")+"?"+data;
    var curUrl = getCurrentUrl(false).replace(/^.*\//, "");
    if(url != curUrl) {
        setFormBtnSpinner(form);
        jQuery(form).submit();
    }
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
        var obj = document.getElementById(id);
        if(obj) {
            obj.style.display = "none";
        }
    });
}

/* show this form row */
function enableFormElement(id) {
    var obj = document.getElementById(id);
    if(obj) {
        obj.style.display = "";
    }
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
                cell.innerHTML = '<div class="spinner" title="This service is currently executing its servicecheck"><\/div>';
            }
        });
        jQuery.each(selectedHosts, function(row_id, blah) {
            var cell = document.getElementById(row_id + "_h_exec");
            if(cell) {
                cell.innerHTML = '<div class="spinner" title="This service is currently executing its hostcheck"><\/div>';
            }
        });
        var btn = document.getElementById('multi_cmd_submit_button');
        btn.innerHTML = '<div class="spinner mr-1"><\/div>processing commands...';
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
        if(event.target.tagName == 'A' || event.target.tagName == 'IMG' || event.target.tagName == 'I') {
            return true;
        }
    }

    // find id of current row
    var row_id;
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

    // align to parent element
    var pos = jQuery('#'+search_prefix+panel).closest("TD").offset();
    jQuery('#'+search_prefix+panel).css({'top': pos.top, 'left': pos.left});
  }
}

/* calculate the sum for a filter */
function accept_filter_types(search_prefix, checkbox_names, result_name, checkbox_prefix) {
    var inp  = document.getElementsByName(search_prefix + result_name);
    if(!inp || inp.length == 0) {
      if(thruk_debug_js) { alert("ERROR: no element in accept_filter_types() for: " + search_prefix + result_name); }
      return;
    }
    var sum = 0;
    jQuery("input[name="+search_prefix + checkbox_names+"]").each(function(index, elem) {
        if(elem.checked) {
            sum += parseInt(elem.value);
        }
    });
    inp[0].value = sum;

    set_filter_name(search_prefix, checkbox_prefix, parseInt(sum));
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
    var bits = bin.split('').reverse();
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
function set_filter_name(search_prefix, checkbox_prefix, filtervalue) {
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
    var checkbox = document.getElementById(search_prefix + checkbox_prefix + bit);
    if(!checkbox) {
        if(thruk_debug_js) { alert('ERROR: got no checkbox in set_filter_name(): ' + search_prefix + checkbox_prefix + bit); }
    }
    if(checkbox.checked) {
      var nameElem = document.getElementById(search_prefix + checkbox_prefix + bit + 'n');
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

  var target = document.getElementById(search_prefix + checkbox_prefix + 'n');
  target.innerHTML = filtername;
}

function getFilterTypeOptions() {
    var important = new Array(/* when changed, update _status_filter.tt && panorama_js_form_filter.js too! */
        'Search',
        'Host',
        'Service',
        'Hostgroup',
        'Servicegroup',
        '----------------'
    );
    var others = new Array(
        'Action Menu',
        'Check Period',
        'Command',
        'Comment',
        'Contact',
        'Current Attempt',
        'Custom Variable',
        'Dependency',
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
  var pane_prefix = search_prefix.substring(0,4);
  search_prefix   = search_prefix.substring(4);
  var index       = search_prefix.indexOf('_');
  search_prefix   = search_prefix.substring(0,index+1);
  table           = table.substring(4);
  var tbl         = document.getElementById(pane_prefix+search_prefix+table);
  if(!tbl) {
    if(thruk_debug_js) { alert("ERROR: got no table for id in add_new_filter(): " + pane_prefix+search_prefix+table); }
    return;
  }

  // add new row
  var tblBody        = tbl.tBodies[0];
  var currentLastRow = tblBody.rows[tblBody.rows.length - 1];
  var templateRow;
  jQuery(tblBody.rows).each(function(i, row) {
      if(row.className == "template") {
          templateRow = row;
          return false;
      }
  });
  var newRow = templateRow.cloneNode(true);
  jQuery(newRow).removeClass("template").css("display", "");
  currentLastRow.parentNode.insertBefore(newRow, currentLastRow);

  // get first free number of typeselects
  var nr = 0;
  for(var x = 0; x<= 99; x++) {
    var tst = document.getElementById(pane_prefix + search_prefix + x + '_ts');
    if(tst) { nr = x+1; }
  }

  // replace ids recursivly
  jQuery(newRow).find('*').each(function(i, el) {
    if(el.id) {
        el.id = el.id.replace("template", nr);
    }
  });

  // fill in values from last row
  var lastnr=nr-1;
  var lastops = jQuery('#'+pane_prefix + search_prefix + lastnr + '_to');
  if(lastops.length > 0) {
      jQuery('#'+pane_prefix + search_prefix + nr + '_to')[0].selectedIndex    = jQuery('#'+pane_prefix + search_prefix + lastnr + '_to')[0].selectedIndex;
      jQuery('#'+pane_prefix + search_prefix + nr + '_ts')[0].selectedIndex    = jQuery('#'+pane_prefix + search_prefix + lastnr + '_ts')[0].selectedIndex;
      // skip setting value, searching for the same thing twice makes no sense so the value is usually replaced anyway
      //jQuery('#'+pane_prefix + search_prefix + nr + '_value')[0].value         = jQuery('#'+pane_prefix + search_prefix + lastnr + '_value')[0].value;
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
  if(jQuery(row).hasClass("template")) { return; }
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
function new_filter(filter_pane_id) {
    var filter_pane = document.getElementById(filter_pane_id);
    var prevObj     = filter_pane.lastElementChild;
    var newObj      = prevObj.cloneNode(true);
    filter_pane.appendChild(newObj);

    var pane_prefix   = prevObj.id.substring(0,4);
    var search_prefix = prevObj.id.substring(4);
    var new_prefix    = 's' + (parseInt(search_prefix.substring(1)) + 1);

    // replace id of panel itself
    replaceIdAndNames(newObj, pane_prefix+new_prefix);

    // replace ids and names
    jQuery(newObj).find("*").each(function(i, el) {
        if(el.id) {
            replaceIdAndNames(el, pane_prefix+new_prefix);
        }
    });

    check_new_filter_add_button_visiblity(pane_prefix);

    showElement(pane_prefix+new_prefix+"_btn_del_search");
}

function check_new_filter_add_button_visiblity(pane_prefix) {
    // hide add button if maximum search boxes reached
    if(maximum_search_boxes > 0 && jQuery('#'+pane_prefix+'filter_pane DIV.singlefilterpane').length >= maximum_search_boxes) {
        hideElement(pane_prefix+'new_filter_box_btn');
    } else {
        showElement(pane_prefix+'new_filter_box_btn');
    }
}

/* replace ids and names for elements */
function replaceIdAndNames(elem, new_prefix) {
    if(elem.id) {
        var new_id = elem.id.replace(/^\w{3}_s\d+/, new_prefix);
        elem.setAttribute('id', new_id);
    }
    if(elem.name) {
        var new_name = elem.name.replace(/^\w{3}_s\d+/, new_prefix);
        elem.setAttribute('name', new_name);
    }
}

/* replace id and name of a object */
function replace_ids_and_names(elem, new_nr) {
    if(elem.id) {
        var new_id = elem.id.replace(/_\d+$/, '_'+new_nr).replace(/_\d+_/, '_'+new_nr+'_');
        elem.setAttribute('id', new_id);
    }
    if(elem.name) {
        var new_name = elem.name.replace(/_\d+$/, '_'+new_nr).replace(/_\d+_/, '_'+new_nr+'_');
        elem.setAttribute('name', new_name);
    }
    return elem
}

/* remove a search panel */
function deleteSearchPane(btnId) {
    var pane_prefix   = btnId.substring(0,4);
    var search_prefix = btnId.substring(4);
    var index         = search_prefix.indexOf('_');
    var search_prefix = search_prefix.substring(0, index);
    var filterprefix  = pane_prefix+search_prefix;

    var pane  = document.getElementById(filterprefix);
    pane.parentNode.removeChild(pane);

    check_new_filter_add_button_visiblity(pane_prefix);
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
  if(!selElem) { return; }

  // get operator select
  var opElem = document.getElementById(selElem.id.substring(0, selElem.id.length - 1) + 'o');

  var selValue = selElem.options[selElem.selectedIndex].value;

  // do we have to display the datepicker?
  var calElem = document.getElementById(selElem.id.substring(0, selElem.id.length - 2) + 'cal');
  var inpElem = document.getElementById(selElem.id.substring(0, selElem.id.length - 2) + 'value');
  if(selValue == 'next check' || selValue == 'last check' ) {
    showElement(calElem);
    inpElem.onclick = show_cal;
  } else {
    hideElement(calElem);
    jQuery(inpElem).off(); // remove all previous events
    inpElem.picker = false;
    inpElem.onclick = function() { ajax_search.init(this, undefined, {striped: false}); };
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
         && selValue != 'command'
         && selValue != 'action menu'
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
  jQuery(form).find("TR.template").remove();
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

function resetFilter(prefix, d) {
    var filterTable = document.getElementById(prefix+'filterTable');
    // remove all existing text filter
    jQuery(filterTable).find('.js-remove-filter-row').each(function(i, el) {
      jQuery(el).click();
    });

    // add our text filter
    var tablePrefix = prefix.substring(0,4);
    if(d.text_filter ) {
        for(var x = 0; x< d.text_filter.length; x++) {
            var f = d.text_filter[x];
            if(f.val_pre == undefined) { f.val_pre = ""; }
            if(f.value   == undefined) { f.value = ""; }
            add_new_filter(prefix+"add", tablePrefix+"filterTable");
            selectByValue(document.getElementById(prefix+x+"_ts"), f.type);
            selectByValue(document.getElementById(prefix+x+"_to"), f.op);
            document.getElementById(prefix+x+"_val_pre").value = f.val_pre;
            document.getElementById(prefix+x+"_value").value = f.value;

            verify_op(prefix+x+"_ts");
        }
    }

    // set bit values
    jQuery(filterTable).find("INPUT[name="+prefix+"hoststatustypes]").val(d.hoststatustypes);
    jQuery(filterTable).find("INPUT[name="+prefix+"hostprops]").val(d.hostprops);
    jQuery(filterTable).find("INPUT[name="+prefix+"servicestatustypes]").val(d.servicestatustypes);
    jQuery(filterTable).find("INPUT[name="+prefix+"serviceprops]").val(d.serviceprops);
    set_filter_types(prefix, "hoststatustypes", 'ht');
    set_filter_types(prefix, "hostprops", 'hp');
    set_filter_types(prefix, "servicestatustypes", 'st');
    set_filter_types(prefix, "serviceprops", 'sp');
    set_filter_name(prefix, 'ht', parseInt(d.hoststatustypes));
    set_filter_name(prefix, 'hp', parseInt(d.hostprops));
    set_filter_name(prefix, 'st', parseInt(d.servicestatustypes));
    set_filter_name(prefix, 'sp', parseInt(d.serviceprops));

    return;
}

function filterToUrlParam(prefix, filter) {
    var param = {};

    param[prefix+'hoststatustypes']    = filter.hoststatustypes;
    param[prefix+'hostprops']          = filter.hostprops;
    param[prefix+'servicestatustypes'] = filter.servicestatustypes;
    param[prefix+'serviceprops']       = filter.serviceprops;

    param[prefix+'type']    = [];
    param[prefix+'val_pre'] = [];
    param[prefix+'op']      = [];
    param[prefix+'value']   = [];
    if(filter.text_filter) {
        for(var x = 0; x< filter.text_filter.length; x++) {
            var f = filter.text_filter[x];
            param[prefix+'type'].push(f.type);
            param[prefix+'val_pre'].push(f.val_pre);
            param[prefix+'op'].push(f.op);
            param[prefix+'value'].push(f.value);
        }
    }
    return(param);
}

/* toggle visibility of top status informations */
function toggleTopPane() {
  var formInput = document.getElementById('hidetop');
  if(toggleElement('top_pane')) {
    additionalParams['hidetop'] = 0;
    if(formInput) {
        formInput.value = 0;
    }
    hideElement("btn_toggle_top_pane");
  } else {
    additionalParams['hidetop'] = 1;
    if(formInput) {
        formInput.value = 1;
    }
    showElement("btn_toggle_top_pane");
  }
  updateUrl();
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

function show_cal(ev) {
    // clicks in IMG tags redirect to corresponding input field
    if(ev.target.tagName == "IMG" || ev.target.tagName == "I") {
        var matches = ev.target.className.match(/for_([\w_]+)/);
        if(matches && matches[1]) {
            var el = document.getElementById(matches[1]);
            if(el) {
                el.click();
                return;
            }
            if(thruk_debug_js) { alert("ERROR: got no element for id in show_cal(): " + matches[1]); }
            return;
        }
        if(thruk_debug_js) { alert("ERROR: got no for_ class id in show_cal(): " + ev.target.className); }
        return;
    }

    // do not open if target input contains short durations like 2m or 10d
    if(ev.target.tagName == "INPUT") {
        var val = ev.target.value;
        if(String(val).match(/^\d+\w$/)) {
            return;
        }
    }

    var id1       = ev.target.id;
    var hasClear  = ev.target.className.match(/cal_popup_clear/)       ? true : false;
    var hasRange  = ev.target.className.match(/cal_popup_range/)       ? true : false;
    var hasSelect = ev.target.className.match(/cal_popup_select/)      ? true : false;
    var hasSubmit = ev.target.className.match(/cal_popup_auto_submit/) ? true : false;
    var hasCustom = ev.target.className.match(/cal_custom/)            ? true : false;

    if(document.getElementById(id1).picker) {
        return;
    }

    // set known range pairs
    var id2;
    if(hasRange) {
        if(id1 == "start_date") { id2 = "end_date"; }
        if(id1 == "start_time") { id2 = "end_time"; }
        if(id1 == "start")      { id2 = "end"; }
        if(id1 == "t1")         { id2 = "t2"; }
        // show picker at the end date
        if(id2 && id1 != id2) {
            document.getElementById(id2).click();
            return;
        }
        if(!id2) {
            if(id1 == "end_date") { id2 = "start_date"; }
            if(id1 == "end_time") { id2 = "start_time"; }
            if(id1 == "end")      { id2 = "start"; }
            if(id1 == "t2")       { id2 = "t1"; }
        }
    }

    var _parseDate = function(date_val) {
        var date_time = date_val.split(" ");
        if(date_time.length == 1) { date_time[1] = "0:0:0"; }
        if(date_time.length == 2) {
            var dates     = date_time[0].split('-');
            if(dates[2] == undefined) {
                return;
            }
            var times     = date_time[1].split(':');
            if(times[1] == undefined) {
                times = new Array(0,0,0);
            }
            if(times[2] == undefined) {
                times[2] = 0;
            }
            return(new Date(dates[0], (dates[1]-1), dates[2], times[0], times[1], times[2]));
        }
        return;
    };

    var date1 = _parseDate(document.getElementById(id1).value);
    if(!date1) {
        date1 = new Date();
        if(!hasCustom) {
            document.getElementById(id1).value = date1.strftime("%Y-%m-%d %H:%M:%S");
        }
    }
    var date2;
    if(hasRange) {
        date2 = _parseDate(document.getElementById(id2).value);
        if(!date2) {
            date2 = new Date();
            if(!hasCustom) {
                document.getElementById(id2).value = date2.strftime("%Y-%m-%d %H:%M:%S");
            }
        }
        // reverse dates, because we always click on the end date when having ranges
        var tmp = date2;
        date2 = date1;
        date1 = tmp;
    }

    var options = {
        "singleDatePicker": !hasRange,
        "minYear": date1.strftime("%Y") - 5,
        "showDropdowns": true,
        "showWeekNumbers": true,
        "timePicker": true,
        "timePicker24Hour": true,
        "startDate": moment(date1),
        "opens": "center",
        "autoApply": false,
        "linkedCalendars": false,
        "autoUpdateInput": false,
        "alwaysShowCalendars": true,
        "locale": {
            "format": "YYYY-MM-DD hh:mm:ss",
            "firstDay": 1
        }
    };
    if(hasClear) {
        options.locale.cancelLabel = 'Clear';
        jQuery('#'+id1).on('cancel.daterangepicker', function(ev, picker) {
            jQuery(this).val('');
        });
    } else {
        options.cancelButtonClasses = "hidden";
    }
    if(hasRange) {
        options.endDate = moment(date2);
    }
    if(hasSelect) {
        var today = _parseDate((new Date).strftime("%Y-%m-%d"));
        options.ranges = {
            'Today':        [moment().startOf('day'),                        moment(today).add(1, 'days')],
            'Yesterday':    [moment(today).subtract(1, 'days'),              moment(today)],
            'Last 7 Days':  [moment(today).subtract(7, 'days'),              moment(today).add(1, 'days')],
            'Last 30 Days': [moment(today).subtract(30, 'days'),             moment(today).add(1, 'days')],
            'This Month':   [moment().startOf('month'),                      moment().startOf('month').add(1, 'month')],
            'Last Month':   [moment().subtract(1, 'month').startOf('month'), moment().startOf('month')]
        };
    }

    var _onKeyUp = function(ev) {
        var picker = ev.data[0];
        var date1 = _parseDate(document.getElementById(id1).value);
        if(date1) {
            var date = moment(date1);
            picker.setEndDate(date);
            if(!hasRange) {
                picker.setStartDate(date);
            }
        }
        if(hasRange) {
            var date2 = _parseDate(document.getElementById(id2).value);
            if(date2) {
                var date = moment(date2);
                picker.setStartDate(date);
            }
        }
        picker.updateView();
    };

    var _onShow = function(ev, picker, id) {
        picker.container.css("min-width", "300px");
        jQuery(".daterangepicker td.today").each(function() {
            if(!this.className.match(/off/)) {
                jQuery(this).addClass("todayHighlight");
            }
        })
        jQuery('#'+id1).off("keyup");
        jQuery('#'+id2).off("keyup");
        jQuery('#'+id1).on("keyup", [picker], _onKeyUp);
        jQuery('#'+id2).on("keyup", [picker], _onKeyUp);
    };
    var apply = function(start, end, label) {
        if(hasRange) {
            document.getElementById(id1).value = end.format('YYYY-MM-DD HH:mm:ss').replace(/:00$/, '');
            document.getElementById(id2).value = start.format('YYYY-MM-DD HH:mm:ss').replace(/:00$/, '');
        } else {
            document.getElementById(id1).value = start.format('YYYY-MM-DD HH:mm:ss').replace(/:00$/, '');
        }
        // submit the form automatically, no need to press update/apply twice
        if(hasSubmit) {
            jQuery('#'+id1).parents('form:first').submit();
        }
    };

    document.getElementById(id1).picker = true;
    jQuery('#'+id1).on('showCalendar.daterangepicker', function(ev,picker) { _onShow(ev,picker,id1) });
    jQuery('#'+id1).daterangepicker(options, apply);

    // show calendar
    jQuery('#'+id1).click();
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
    input_field     : '',
    result_pan      : 'search-results',
    update_interval : 3600, // update at least every hour
    search_type     : 'all',
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
    limit           : 2000,
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
     *   limit:             int, limit number of results
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
          if(!elem.id) {
              // create uniq id for this field
              var nr = 0;
              if(!type) { type = "all"; }
              while(document.getElementById(type+nr)) { nr++; }
              elem.setAttribute("id", type+nr);
          }
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
        if(options.limit != undefined) {
            ajax_search.limit = options.limit;
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

        var append_value_of;
        if(options.append_value_of != undefined) {
            append_value_of = options.append_value_of;
        } else {
            append_value_of = ajax_search.append_value_of;
        }

        var backend_select;
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

        if(ajax_search.empty == true) {
            if(input.value == ajax_search.emptytxt) {
                jQuery(input).removeClass(ajax_search.emptyclass);
                input.value = "";
            }
        }

        if(jQuery(input).hasClass("js-autoexpand")) {
            jQuery(input).addClass("expanded");
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

        ajax_search.cur_search_url = ajax_search.url;
        if(options.url != undefined) {
            ajax_search.cur_search_url = options.url;
        }

        if(type != undefined) {
            // type can be a callback
            if(typeof(type) == 'function') {
                type = type();
            }
            ajax_search.search_type = type;
            if(!ajax_search.cur_search_url.match(/type=/)) {
                ajax_search.cur_search_url = ajax_search.cur_search_url + "&type=" + type;
            }
        } else {
            type = 'all';
        }

        var appended_value;
        if(append_value_of) {
            var el = document.getElementById(append_value_of);
            if(!el) {
                el = jQuery(append_value_of).first();
                if(el) { el = el[0]; }
            }
            if(el) {
                ajax_search.cur_search_url = ajax_search.cur_search_url + el.value;
                appended_value = el.value;
            } else {
                ajax_search.cur_search_url = ajax_search.url;
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
                        ajax_search.cur_search_url = ajax_search.cur_search_url + '&backend=' + val;
                    });
                }
            }
        }

        input.setAttribute("autocomplete", "off");
        if(!iPhone) {
            ajax_search.dont_hide = true;
            input.blur();   // blur & focus the element, otherwise the first
            input.focus();  // click would result in the browser autocomplete
            if(input.value == "all") {
                jQuery(input).select();
            }
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
               || search_type == 'contactgroup'
               || search_type == 'event handler'
               || search_type == 'command'
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
            if(search_type == 'action menu') {
                ajax_search.search_type = 'custom variable';
                var varFieldId = input.id.replace(/_value$/, '_val_pre');
                var varField   = document.getElementById(varFieldId);
                if(varField) {
                    varField.value = "THRUK_ACTION_MENU";
                }
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
            ajax_search.search_type = "none";
            var varFieldId = input.id.replace(/_value$/, '_val_pre');
            var varField   = document.getElementById(varFieldId);
            if(varField) {
                ajax_search.search_type = "custom value";
                ajax_search.cur_search_url = ajax_search.cur_search_url + "&type=custom value&var=" + varField.value;
            }
        }
        if(ajax_search.search_type == 'hosts')         { ajax_search.search_type = 'host'; }
        if(ajax_search.search_type == 'hostgroups')    { ajax_search.search_type = 'hostgroup'; }
        if(ajax_search.search_type == 'services')      { ajax_search.search_type = 'service'; }
        if(ajax_search.search_type == 'servicegroups') { ajax_search.search_type = 'servicegroup'; }
        if(ajax_search.search_type == 'contacts')      { ajax_search.search_type = 'contact'; }
        if(ajax_search.search_type == 'none') {
            removeEvent( input, 'keyup', ajax_search.suggest );
            return true;
        } else {
            if(   ajax_search.search_type == 'event handler'
               || ajax_search.search_type == 'contact'
               || ajax_search.search_type == 'contactgroup'
               || ajax_search.search_type == 'command'
               || ajax_search.search_type == 'action menu'
               || ajax_search.search_type == 'timeperiod'
            ) {
                if(!ajax_search.cur_search_url.match(/type=/)) {
                    ajax_search.cur_search_url = ajax_search.cur_search_url + "&type=" + ajax_search.search_type;
                }
            }
        }

        // append host value if there is a host input field in the same form
        if(search_type == "service" && !append_value_of) {
            var host;
            var data = jQuery(input).parents('FORM').serializeArray();
            for(var i=0; i<data.length; i++){
                if(data[i].name.match(/_type$/) && data[i].value == "host") {
                    var valueName = data[i].name.replace(/_type$/, "_value");
                    for(var j=0; j<data.length; j++){
                        if(data[j].name == valueName) {
                            host = data[j].value;
                            break;
                        }
                    }
                }
            }
            if(host != undefined) {
                ajax_search.cur_search_url = ajax_search.cur_search_url + "&host=" + encodeURIComponent(host);
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
           && ajax_search.initialized_u == ajax_search.cur_search_url
        ) {
            ajax_search.suggest();
            return false;
        }

        ajax_search.initialized   = now;
        ajax_search.initialized_t = type;
        ajax_search.initialized_a = undefined;
        ajax_search.initialized_q = undefined;
        if(append_value_of) {
            ajax_search.initialized_a = appended_value;
        }
        ajax_search.initialized_u = ajax_search.cur_search_url;

        // disable autocomplete
        var tmpElem = input;
        while(tmpElem && tmpElem.parentNode) {
            tmpElem = tmpElem.parentNode;
            if(tmpElem.tagName == 'FORM') {
                addEvent(tmpElem, 'submit', ajax_search.hide_results);
                tmpElem.setAttribute("autocomplete", "off");
            }
        }

        ajax_search.local_data = false;
        if(options.data != undefined) {
            ajax_search.base = options.data;
            ajax_search.local_data = true;
            ajax_search.suggest();
        } else {
            ajax_search.refresh_data();
        }

        if(!iPhone) {
            addEvent(document, 'keydown', ajax_search.arrow_keys);
            addEvent(document, 'click', ajax_search.hide_results);
        }

        return false;
    },

    refresh_data: function() {
        window.clearTimeout(ajax_search.refresh_timer);
        ajax_search.updating = true;
        var panel = document.getElementById(ajax_search.result_pan);
        if(panel && panel.style.visibility == 'visible') {
            ajax_search.show_results([]); // show loading icon
        }
        ajax_search.refresh_timer = window.setTimeout(ajax_search.refresh_data_do, 300);
    },
    refresh_data_do: function() {
        window.clearTimeout(ajax_search.refresh_timer);
        if(ajax_search.local_data) { return; }
        ajax_search.updating = true;
        ajax_search.error    = false;

        // show searching results
        ajax_search.base = {};
        ajax_search.suggest();
        ajax_search.initialized_q = ajax_search.get_current_input_search_pattern();

        // fill data store
        jQuery.ajax({
            url: ajax_search.cur_search_url,
            data: {
                limit: ajax_search.limit,
                query: ajax_search.initialized_q
            },
            type: 'POST',
            success: function(data) {
                ajax_search.updating=false;
                ajax_search.base = data;
                var panel = document.getElementById(ajax_search.result_pan);
                if(ajax_search.autoopen == true || (panel && panel.style.visibility == 'visible')) {
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
    },

    get_current_input_search_pattern: function() {
        var input = document.getElementById(ajax_search.input_field);
        var pattern = input.value;
        if(pattern == "all") { pattern = ""; }
        if(pattern == "*")   { pattern = ""; }
        if(ajax_search.search_for_cb) {
            pattern = ajax_search.search_for_cb(pattern);
        }
        if(ajax_search.list) {
            /* only use the last list element for search */
            var regex  = new RegExp(ajax_search.list, 'g');
            var range  = getCaret(input);
            var before = pattern.substr(0, range);
            var after  = pattern.substr(range);
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
        pattern = pattern.replace(/\s+$/g, "");
        pattern = pattern.replace(/^\s+/g, "");
        return(pattern);
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

        window.clearTimeout(ajax_search.timer);
        window.clearTimeout(ajax_search.hideTimer);

        var panel = document.getElementById(ajax_search.result_pan);
        if(!panel) { return; }
        /* delay hiding a little moment, otherwise the click
         * on the suggestion would be cancel as the panel does
         * not exist anymore
         */
        if(immediately != undefined) {
            hideElement(ajax_search.result_pan);
            var input = document.getElementById(ajax_search.input_field);
            if(setfocus) {
                ajax_search.stop_events = true;
                window.setTimeout(function() { ajax_search.stop_events=false; }, 200);
                input.focus();
            } else {
                if(input && input.value == "") {
                    jQuery(input).removeClass("expanded");
                }
            }
        }
        else if(ajax_search.cur_select == -1) {
            ajax_search.hideTimer = window.setTimeout(function() {
                if(ajax_search.dont_hide==false) {
                    fade(ajax_search.result_pan, 300);
                    var input = document.getElementById(ajax_search.input_field);
                    if(input && input.value == "") {
                        jQuery(input).removeClass("expanded");
                    }
                }
            }, 150);
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

        ajax_search.timer = window.setTimeout(ajax_search.suggest_do, 100);
        return true;
    },

    /* search some hosts to suggest */
    suggest_do: function() {
        var input = document.getElementById(ajax_search.input_field);
        if(!input) { return; }
        if(ajax_search.base == undefined || ajax_search.base.length == 0) { return; }

        // business impact prioritys are fixed
        if(ajax_search.search_type == 'priority') {
            ajax_search.base = [{ name: 'prioritys', data: ["1","2","3","4","5"] }];
        }

        var search_pattern = ajax_search.get_current_input_search_pattern();
        if(search_pattern.length >= 1 || ajax_search.search_type != 'all') {
            var needs_refresh = false;
            var orig_search_pattern = search_pattern;
            var prefix = search_pattern.substr(0,3);
            if(prefix == 'ho:' || prefix == 'hg:' || prefix == 'se:' || prefix == 'sg:') {
                search_pattern = search_pattern.substr(3);
            }

            // remove empty strings from pattern array
            var pattern = get_trimmed_pattern(search_pattern);
            var results = new Array();
            jQuery.each(ajax_search.base, function(index, search_type) {
                var sub_results = new Array();
                var top_hits = 0;
                var total_relevance = 0;
                if(   (ajax_search.search_type == 'all' && search_type.name != 'timeperiods')
                   || (ajax_search.search_type == 'full')
                   || (ajax_search.templates == "templates" && search_type.name == ajax_search.initialized_t + " templates")
                   || (ajax_search.templates != "templates" && ajax_search.search_type + 's' == search_type.name)
                   || (ajax_search.templates == "both" && ( search_type.name == ajax_search.initialized_t + " templates" || ajax_search.search_type + 's' == search_type.name ))
                  ) {
                  jQuery.each(search_type.data, function(index, data) {
                      var name = data;
                      var alias = '';
                      if(data && data['name']) {
                          name = data['name'];
                      }
                      var search_name = String(name);
                      if(data && data['alias']) {
                          alias = data['alias'];
                          search_name = search_name+' '+alias;
                      }
                      var result_obj = new Object({ 'name': name, 'relevance': 0 });
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
                          total_relevance += result_obj.relevance;
                      }
                  });
                }
                if(ajax_search.initialized_q && !orig_search_pattern.match(ajax_search.initialized_q) && orig_search_pattern != ajax_search.initialized_q) {
                    // filter does not match our data base
                    needs_refresh = true;
                }
                if(ajax_search.initialized_q && ajax_search.initialized_q.length > orig_search_pattern.length) {
                    // data base is more precise than our filter
                    needs_refresh = true;
                }
                if(((search_type.total_none_uniq && search_type.total_none_uniq >= ajax_search.limit) || search_type.data.length >= ajax_search.limit) && ajax_search.initialized_q != search_pattern) {
                    // maximum results number hit
                    needs_refresh = true;
                }
                if(sub_results.length > 0) {
                    if(total_relevance > 0) {
                        sub_results.sort(sort_by('sorter', false));
                    }
                    results.push(Object({ 'name': search_type.name, 'results': sub_results, 'top_hits': top_hits }));
                }
            });

            if(needs_refresh && !ajax_search.local_data) {
                ajax_search.updating = true;
                ajax_search.show_results([]); // show loading icon
                ajax_search.refresh_data();
                return;
            }

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
                // press on the button with given id
                resultHTML += '<li class="res '+(btn.cls ? ' '+btn.cls+' ' : '')+'" onclick="jQuery(\'#'+btn.id+'\').click(); return false;">';
                if(btn.icon) {
                    if(btn.icon.match(/^uil\-/)) {
                        resultHTML += '<i class="uil '+btn.icon+'" style="font-size: 16px; line-height: 15px;"><\/i>';
                    }
                    else if(btn.icon.match(/^fa\-/)) {
                        resultHTML += '<i class="fa-solid '+btn.icon+'" style="font-size: 16px; line-height: 15px;"><\/i>';
                    }
                    else {
                        resultHTML += '<img src="'+ url_prefix + 'themes/' + theme + '/images/' + btn.icon+'">';
                    }
                }
                resultHTML += btn.text;
                resultHTML += '<\/li>';
            });
        }
        var x = 0;
        var results_per_type = Math.ceil(ajax_search.max_results / results.length);
        ajax_search.res   = new Array();
        var limit_hit = false;
        var has_more  = false;
        jQuery.each(results, function(index, type) {
            var cur_count = 0;
            var name = type.name.substring(0,1).toUpperCase() + type.name.substring(1);
            if(type.results.length == 1) { name = name.substring(0, name.length -1); }
            name = name.replace(/ss$/, 's');
            if(type.results.length >= ajax_search.limit && !ajax_search.local_data) {
                resultHTML += '<li class="category">over ' + ( type.results.length ) + ' ' + name + '<\/li>';
                limit_hit = true;
            } else {
                resultHTML += '<li class="category">' + ( type.results.length ) + ' ' + name + '<\/li>';
            }
            jQuery.each(type.results, function(index, data) {
                if(ajax_search.show_all || cur_count <= results_per_type) {
                    var name = data.display || data.name || "";
                    jQuery.each(pattern, function(index, sub_pattern) {
                        if(ajax_search.regex_matching && sub_pattern != "*") {
                            var re = new RegExp('('+sub_pattern+')', "gi");
                            // only replace parts of the string which are not bold yet
                            var parts = name.split(/(<b>.*?<\/b>)/);
                            jQuery.each(parts, function(index2, part) {
                                if(!part.match(/^<b>/)) {
                                    parts[index2] = part.replace(re, "<b>$1<\/b>");
                                }
                            });
                            name = parts.join("");
                        } else {
                            name = name.toLowerCase().replace(sub_pattern.toLowerCase(), "<b>" + sub_pattern + "<\/b>");
                        }
                    });
                    var classname = "";
                    if(selected != -1 && selected == x) {
                        classname = "ajax_search_selected";
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
                    var id = "suggest_item_"+x;
                    if(type.name == 'icons') {
                        var file = data.display.split(" - ");
                        name = "<img src='" + file[1] + "'> " + file[0];
                    }
                    name        = name.replace(/\ \(disabled\)$/, '<span class="disabled"> (disabled)<\/span>');
                    resultHTML += '<li class="res ' + classname + '" id="'+id+'" data-name="' + prefix+data.name +'" onclick="ajax_search.set_result(this.dataset.name); return false;" title="' + data.display + '"> ' + name +'<\/li>';
                    ajax_search.res[x] = prefix+data.name;
                    x++;
                    cur_count++;
                } else {
                    has_more = true;
                }
            });
        });
        if(has_more) {
            var id = "suggest_item_"+x;
            var classname = "";
            if(selected != -1 && selected == x) {
                classname = "ajax_search_selected";
            }
            resultHTML += '<li class="more ' + classname + '" id="'+id+'" data-name="more" onmousedown="ajax_search.set_result(this.dataset.name); return false;">more...<\/li>';
            x++;
        }
        else if(ajax_search.show_all && limit_hit) {
            resultHTML += '<li class="toomany">too many results, be more specific<\/li>';
        }
        ajax_search.result_size = x;
        if(results.length == 0) {
            if(ajax_search.error) {
                resultHTML += '<li class="error">error: '+ajax_search.error+'<\/li>';
            }
            else if(ajax_search.updating) {
                resultHTML += '<li class="loading"><div class="spinner"><\/div> loading...<\/li>';
            } else {
                resultHTML += '<li onclick="ajax_search.onempty()">'+ ajax_search.emptymsg +'<\/li>';
            }
            if(ajax_search.hideempty) {
                ajax_search.hide_results();
                return;
            }
        }
        resultHTML += '<\/ul>';

        panel.innerHTML = resultHTML;

        var style     = panel.style;
        var coords    = jQuery(input).offset();
        style.left    = coords.left + "px";
        style.top     = (coords.top + input.offsetHeight) + "px";
        var size      = jQuery(input).outerWidth();
        if(size < 100) { size = 100; }
        if(size > jQuery(panel).outerWidth()) {
            style.width   = size + "px";
        }

        jQuery(panel).appendTo("BODY");

        showElement(panel);
        ajax_search.stop_events = true;
        window.setTimeout(function() { ajax_search.stop_events=false; }, 200);
        ajax_search.dont_hide=true;
        window.setTimeout(function() { ajax_search.dont_hide=false; }, 500);
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
            var range   = getCaret(input);
            var before  = pattern.substr(0, range);
            var after   = pattern.substr(range);
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
        ajax_search.dont_hide=false;
        window.setTimeout(function() { ajax_search.hide_results(null, 1, 1); }, 100);

        if(ajax_search.onselect != undefined) {
            return ajax_search.onselect(input);
        }

        if(( ajax_search.autosubmit == undefined
             && (
                    jQuery(input).hasClass("autosubmit")
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
                return true;
            }
            if(ajax_search.set_result(ajax_search.res[ajax_search.cur_select])) {
                return false;
            }
            evt.preventDefault ? evt.preventDefault() : evt.returnValue = false;
            return false;
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
};


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
    //23:59_20130125
    var year,month,hour,day,minute;
    hour=str.substring(0,2);
    minute=str.substring(3,5);
    year=str.substring(6,10);
    month=str.substring(10,12)-1;
    day=str.substring(12,14);
    var date=new Date(year, month, day, hour, minute);

    return date.getTime()/1000;
}

function set_graphite_img(start, end, id) {
    var newUrl = graph_url + "&from=" + graphite_format_date(start) + "&until=" + graphite_format_date(end);

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
        for(var x=1;x<=5;x++) {
            var obj = document.getElementById("graphite_th"+x);
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

    var start = graphite_unformat_date(urlArgs["from"]);
    var end   = graphite_unformat_date(urlArgs["until"]);
    var diff  = end - start;

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

    pnp_start = start;
    pnp_end   = end;

    jQuery('#pnpwaitimg').css('display', 'block');
    jQuery('#pnpimg').css('opacity', '0.3');

    jQuery('#pnpimg').one("load", function() {
      jQuery('#pnpimg').css('opacity' , '');
      jQuery('#pnperr').css('display' , 'none');
      jQuery('#pnpwaitimg').css({'display': 'none'});
    })
    .one("error", function(err) {
      jQuery('#pnpwaitimg').css('display', 'none');
      jQuery('#pnpimg').css('display' , 'none');
      jQuery('#pnperr').css('display' , '');
    });

    jQuery('#pnperr').css('display', 'none');
    jQuery('#pnpimg').attr('src', newUrl);

    // set style of buttons
    if(id) {
        id=id.replace(/^#/g, '');
        var obj;
        for(var x=1;x<=5;x++) {
            jQuery('#'+"pnp_th"+x).removeClass("active");
        }
        jQuery('#'+id).addClass("active");
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

    var start = urlArgs["start"];
    var end   = urlArgs["end"];
    var diff  = end - start;

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

    if(theme.match(/dark/i)) {
        newUrl = newUrl+'&theme=dark';
    } else {
        newUrl = newUrl+'&theme=light';
    }

    //add timerange to iconlink, so the target graph matches the preview
    jQuery("#histou_graph_link").attr("href", url_prefix + "#" + histou_url + getParamFrom + getParamTo);

    jQuery('#pnpwaitimg').css('display', 'block');

    jQuery('#histou_iframe').one("load", function() {
      jQuery('#pnpwaitimg').css({'display': 'none'});
    })
    .one("error", function(err) {
      jQuery('#pnpwaitimg').css({'display': 'none'});
    });

    jQuery('#histou_iframe').attr('src', newUrl);

    // set style of buttons
    if(id) {
        id=id.replace(/^#/g, '');
        var obj;
        for(var x=1;x<=5;x++) {
            jQuery('#'+"histou_th"+x).removeClass("active");
        }
        jQuery('#'+id).addClass("active");
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

    var start = urlArgs["from"];
    var end   = urlArgs["to"];
    var diff  = end - start;

    start = (parseInt(diff * factor) + parseInt(start)) / 1000;
    end   = (parseInt(diff * factor) + parseInt(end))   / 1000;

    return set_histou_img(start, end);
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
                var counterTextX = ( metrics.width >= 10 ) ? 6 : 9; // detect counter value position

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
    } catch(err) { console.log(err) }
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

    openModalWindow(document.getElementById((id + 'dialog')));

    // initialize selected members
    selected_members       = new Array();
    var selected_members_h = new Object();
    var options = [];
    var list = jQuery('#'+input_id).val().split(/\s*,\s*/);
    for(var x=0; x<list.length;x+=aggregate) {
        if(list[x] != '') {
            var val = list[x];
            for(var y=1; y<aggregate;y++) {
                val = val+','+list[x+y];
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
                var name  = result[x];
                if(result[x] && result[x]['name']) {
                    name = result[x]['name'];
                }
                if(strip) {
                    name = name.replace(/^(.*)\ \-\ .*$/, '$1');
                }
                if(!selected_members_h[name]) {
                    available_members.push(name);
                    options.push(new Option(name, name));
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

    ajax_search.hide_results(undefined, true);

    // button has to be initialized only once
    if(init_tool_list_wizard_initialized[id] != undefined) {
        // reset filter
        jQuery('#filter_available').val('');
        jQuery('#filter_selected').val('');
        data_filter_select(id+'available_members', '');
        data_filter_select(id+'selected_members', '');
        return;
    }
    init_tool_list_wizard_initialized[id] = true;

    jQuery('#' + id + 'accept').click(function() {
        data_filter_select(id+'available_members', '');
        data_filter_select(id+'selected_members', '');

        var newval = '';
        var lb = document.getElementById(id+"selected_members");
        for(var i=0; i<lb.length; i++)  {
            newval += lb.options[i].value;
            if(i < lb.length-1) {
                newval += ',';
            }
        }
        jQuery('#'+input_id).val(newval);
        closeModalWindow();
        return false;
    });

    return;
}

/*******************************************************************************
  ,ad8888ba,  8b           d8 88888888888 88888888ba    ,ad8888ba,        db        88888888ba  88888888ba,
 d8"'    `"8b `8b         d8' 88          88      "8b  d8"'    `"8b      d88b       88      "8b 88      `"8b
d8'        `8b `8b       d8'  88          88      ,8P d8'               d8'`8b      88      ,8P 88        `8b
88          88  `8b     d8'   88aaaaa     88aaaaaa8P' 88               d8'  `8b     88aaaaaa8P' 88         88
88          88   `8b   d8'    88"""""     88""""88'   88              d8YaaaaY8b    88""""88'   88         88
Y8,        ,8P    `8b d8'     88          88    `8b   Y8,            d8""""""""8b   88    `8b   88         8P
 Y8a.    .a8P      `888'      88          88     `8b   Y8a.    .a8P d8'        `8b  88     `8b  88      .a8P
  `"Y8888Y"'        `8'       88888888888 88      `8b   `"Y8888Y"' d8'          `8b 88      `8b 88888888Y"'
*******************************************************************************/
// replaces the previous overlib library
function overcard(options) {
    var settings = {
        'document': null,
        'body':     '',
        'bodyEl':   null,
        'bodyCls':  '',
        'caption':  '',
        'width':    '',
        'minWidth': 500,
        'callback': null
    };

    for(var key in options) {
        if(key in settings) {
            settings[key] = options[key];
        } else {
            if(thruk_debug_js) { alert("ERROR: unknown option to overcard: " + key); }
        }
    }

    // use iframe if main css cannot be found
    var iframe = document.getElementById("overcard-iframe");
    if(iframe && !settings["document"]) {
        jQuery(iframe).remove();
        iframe = null;
    }
    if(!iframe) {
        if(document.getElementsByClassName("maintheme").length == 0) {
            jQuery('<iframe>', {
                'id':         'overcard-iframe',
                'frameborder': 0,
                'scrolling':  'no',
                'style':      'border: 1px solid; position: absolute; z-index: 1000; border-radius: 8px; visibility: hidden;',
                'class':      'borderDark iframed',
                'src':        'void.cgi'
            }).appendTo('BODY').on('load', function () {
                var iframe = document.getElementById("overcard-iframe");
                iframe = (iframe.contentWindow) ? iframe.contentWindow : (iframe.contentDocument.document) ? iframe.contentDocument.document : iframe.contentDocument;
                settings["document"] = iframe.document;
                jQuery("HTML", iframe.document).css("background-color", "inherit");
                jQuery("MAIN", iframe.document)[0].style.setProperty("padding", "0", "important");
                overcard(settings);
                jQuery("#overcard", iframe.document).removeClass("shadow-float");
            });
            return;
        }
    }

    var doc = settings["document"] || document;
    var containerId = 'overcard';
    // check if container div is already present
    var container = doc.getElementById(containerId);
    if(!container) {
        var containerHTML = ""
            +'<div class="fixed card shadow-float z-50 max-w-full max-h-screen" id="'+containerId+'">'
            +'<div class="head justify-between">'
            +'<h3 id="'+containerId+'_head"><\/h3>'
            +'<button class="iconOnly medium" onClick="toggleElement('+"'"+containerId+"'"+'); removeOvercardIframe(); return false;"><i class="uil uil-times"></i></button>'
            +'<\/div>'
            +'<div class="'+settings['bodyCls']+'" id="'+containerId+'_body"><\/div>'
            +'<\/div>';
        jQuery(containerHTML).appendTo(jQuery("MAIN", doc));
        container = doc.getElementById(containerId);
        var check = function() { element_check_visibility(container); };
        jQuery(container, doc).on('move', check);
        new ResizeObserver(check).observe(container);
    }

    var head = doc.getElementById(containerId+"_head");
    if(settings["caption"]) {
        head.innerHTML = settings["caption"];
        head.style.display = '';
    } else {
        head.style.display = 'none';
    }

    if(settings["width"])    { container.style.width    = settings["width"]+'px'; }
    if(settings["minWidth"]) { container.style.minWidth = settings["minWidth"]+'px'; }

    var body = doc.getElementById(containerId+"_body");
    if(settings["bodyEl"]) {
        if(settings["bodyEl"] && settings["bodyEl"].tagName) {
            jQuery(body).append(jQuery(settings["bodyEl"]));
            settings["bodyEl"].style.display = "";
        } else {
            var bodyEl = doc.getElementById(settings["bodyEl"]);
            bodyEl.style.display = "";
            if(bodyEl) {
                jQuery(body).append(jQuery(bodyEl));
            }
        }
    } else {
        body.innerHTML = settings["body"];
    }

    // place it next to the mouse position
    var posX = mouseX + document.documentElement.scrollLeft + 50;
    var posY = mouseY + document.documentElement.scrollTop;

    if(iframe) {
        iframe.style.left  = posX+'px';
        iframe.style.top   = posY+'px';
        if(settings["width"])    { iframe.style.width    = settings["width"]+'px'; }
        if(settings["minWidth"]) { iframe.style.minWidth = settings["minWidth"]+'px'; }
    } else {
        container.style.left = posX+'px';
        container.style.top  = posY+'px';
    }

    if(iframe) {
        showElement(iframe, null, true, null);
    } else {
        showElement(container, null, true);
    }
    element_check_visibility(container);
    if(settings['callback']) {
        settings['callback'](doc);
    }
    return;
}

function removeOvercardIframe() {
    if(!window.parent) { return; }
    if(!window.parent.document) { return; }
    jQuery("#overcard-iframe", window.parent.document).remove();
}

// save last known mouse position
var mouseX, mouseY;
document.onmousemove = function(evt){
    mouseX = evt.clientX;
    mouseY = evt.clientY;
}
document.onmouseover = function(evt){
    mouseX = evt.clientX;
    mouseY = evt.clientY;
}

function element_check_visibility(el) {
    if(el.style.display == "none") {
        return;
    }
    var rect = el.getBoundingClientRect();
    var offsetX = rect.right  - (window.innerWidth  || document.documentElement.clientWidth);
    var offsetY = rect.bottom - (window.innerHeight || document.documentElement.clientHeight);
    if(offsetX > 0) { el.style.left = Math.max(0, parseInt(el.style.left) - 20 - offsetX)+"px"; }
    if(offsetY > 0) { el.style.top  = Math.max(0, parseInt(el.style.top)  - 20 - offsetY)+"px"; }

    // check parent iframe
    if(!window.parent) { return; }
    if(!window.parent.document) { return; }
    jQuery("#overcard-iframe", window.parent.document).css({
        'width': el.offsetWidth+'px',
        'height': (el.offsetHeight+2)+'px'
    });

    return;
}

// apply row strip manually
function applyRowStripes(el) {
    if(el.tagName == "TABLE") {
        jQuery(el).find("TR").removeClass(["rowOdd", "rowEven"]);
        var x = 0;
        jQuery(el).find("TR:visible").each(function(i, row) {
            if(x%2==0) {
                jQuery(row).addClass("rowEven");
            } else {
                jQuery(row).addClass("rowOdd");
            }
            x++;
        });
    }
}
