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
var additionalParams = new Hash({});
var refreshTimer;
var backendSelTimer;
var lastRowSelected;

// needed to keep the order
var hoststatustypes    = new Array( 1, 2, 4, 8 );
var servicestatustypes = new Array( 1, 2, 4, 8, 16 );
var hostprops          = new Array( 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288 );
var serviceprops       = new Array( 1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 32768, 65536, 131072, 262144, 524288 );

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

/* hide a element by id */
function hideElement(id) {
  var pane;
  if(typeof(id) == 'object') {
    pane = id;
  }
  else {
    pane = document.getElementById(id);
  }
  if(!pane) { alert("ERROR: got no element for id in hideElement(): " + id); return; }
  pane.style.display    = 'none';
  pane.style.visibility = 'hidden';
}

/* show a element by id */
function showElement(id) {
  var pane;
  if(typeof(id) == 'object') {
    pane = id;
  }
  else {
    pane = document.getElementById(id);
  }
  if(!pane) { alert("ERROR: got no element for id in showElement(): " + id); return; }
  pane.style.display    = '';
  pane.style.visibility = 'visible';
}

/* toggle a element by id */
function toggleElement(id) {
  var pane = document.getElementById(id);
  if(!pane) {
    alert("ERROR: got no panel for id in toggleElement(): " + id);
    return false;
  }
  if(pane.style.visibility == "hidden" || pane.style.display == 'none') {
    showElement(id);
    return true;
  }
  else {
    hideElement(id);
    return false;
  }
}

/* hide message */
function close_message() {
    obj = document.getElementById('thruk_message');
    obj.style.display = "none";
}

/* toggle the visibility of the preferences pane */
function togglePreferencePane(state) {
    toggleElement('pref_pane');
}

/* save settings in a cookie */
function prefSubmit(url, current_theme) {
  var sel         = document.getElementById('pref_theme')
  var now         = new Date();
  var expires     = new Date(now.getTime() + (10*365*86400*1000)); // let the cookie expire in 10 years
  if(current_theme != sel.value) {
    document.cookie = "thruk_theme="+sel.value + "; path=/; expires=" + expires.toGMTString() + ";";
    window.status   = "thruk preferences saved";
    reloadPage();
  }
}

/* page refresh rate */
function setRefreshRate(rate) {
  curRefreshVal = rate;
  var obj = document.getElementById('refresh_rate');
  if(refreshPage == 0) {
    obj.innerHTML = "<span id='refresh_rate'>This page will not refresh automatically <input type='button' value='refresh now' onClick='reloadPage()'></span>";
  }
  else {
    obj.innerHTML = "<span id='refresh_rate'>Update in "+rate+" seconds <input type='button' value='stop' onClick='stopRefresh()'></span>";
    if(rate == 0) {
      reloadPage();
    }
    if(rate > 0) {
      newRate = rate - 1;
      window.clearTimeout(refreshTimer);
      refreshTimer = window.setTimeout("setRefreshRate(newRate)", 1000);
    }
  }
}

/* stops the reload interval */
function stopRefresh() {
  refreshPage = 0;
  setRefreshRate(0);
}

/* reloads the current page and adds some parameter from a hash */
var a;
var b;
function reloadPage() {
  var obj = document.getElementById('refresh_rate');
  obj.innerHTML = "<span id='refresh_rate'>page will be refreshed...</span>";

  var origUrl = new String(window.location);
  var newUrl  = origUrl;
  var index   = newUrl.indexOf('?');
  var urlArgs = new Hash();
  if(index != -1) {
    newUrl  = newUrl.substring(0, index);
    origUrl  = origUrl.replace(/\+/g, " ");
    urlArgs = new Hash(origUrl.parseQuery());
  }

  additionalParams.each(function(pair) {
    if(pair.key == 'hidesearch' || pair.key == 'hidetop' || pair.key == 'backend' ) { // check for valid options to set here
      urlArgs.set(pair.key, pair.value);
    }
  });
  var newParams = Object.toQueryString(urlArgs);

  if(newParams != '') {
    newUrl = newUrl + '?' + newParams;
  }

  if(newUrl == origUrl) {
    window.location.reload(true);
  }
  else {
    window.location = newUrl;
  }
}

/* set border color as mouse over for top row buttons*/
function button_over(button)
{
   button.style.borderColor = "#555555";
}
function button_out(button)
{
   button.style.borderColor = "#999999";
}

/* toggle querys for this backend */
function toggleBackend(backend) {
  var button        = document.getElementById('button_' + backend);

  initial_state = initial_backend_states.get(backend);
  if(button.className == "button_peerDIS") {
    if(initial_state == 1) {
      button.className = 'button_peerDOWN';
    }
    else if(initial_state == 3) {
      button.className = 'button_peerHID';
    }
    else {
        button.className = 'button_peerUP';
    }
    current_backend_states.set(backend, 0);
  } else if(button.className == "button_peerHID") {
    button.className = 'button_peerUP';
    current_backend_states.set(backend, 0);
    additionalParams.set('backend', undefined);
  } else {
    button.className = "button_peerDIS";
    current_backend_states.set(backend, 2);
  }

  /* save current selected backends in session cookie */
  document.cookie = "thruk_backends="+current_backend_states.toQueryString()+ "; path=/;";
  //if(initial_state != 3) {
    window.clearTimeout(backendSelTimer);
    backendSelTimer  = window.setTimeout('reloadPage()', 1000);
  //}
}

/* toogle checkbox by id */
function toggleCheckBox(id) {
  var box = document.getElementById(id);
  if(box.checked) {
    box.checked = false;
  } else {
    box.checked = true;
  }
}

// unselect current text seletion
function unselectCurrentSelection(obj)
{
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

/* returns true if the shift key is pressed for that event */
var no_more_events = 0;
function is_shift_pressed(e) {

  if(no_more_events) {
    return false;
  }

  if(e && e.shiftKey) {
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
var selectedServices = new Hash;
var selectedHosts    = new Hash;
var noEventsForId    = new Hash;

/* add mouseover eventhandler for all cells and execute it once */
function addRowSelector(id)
{
    var row   = document.getElementById(id);
    var cells = row.cells;

    // remove this eventhandler, it has to fire only once
    if(noEventsForId.get(id)) {
        return false;
    }
    if( row.detachEvent ) {
        noEventsForId.set(id, 1);
    } else {
        row.onmouseover = undefined;
    }

    // reset all current highlighted rows
    $$('td.tableRowHover').each(function(e) {
        resetHostRow(e);
        resetServiceRow(e);
    });

    // for each cell in a row
    for(var cell_nr = 0; cell_nr < cells.length; cell_nr++) {
        if(pagetype == "hostdetail" || (cell_nr == 0 && cells[0].innerHTML != '')) {
            setRowStyle(id, 'tableRowHover', 'host');
            addEventHandler(cells[cell_nr], 'host');
        }
        else if(cell_nr >= 1) {
            setRowStyle(id, 'tableRowHover', 'service');
            addEventHandler(cells[cell_nr], 'service');
        }
    }
}

/* add the event handler */
function addEventHandler(elem, type) {
    if(type == 'host') {
        addEvent(elem, 'mouseover', highlightHostRow);
        addEvent(elem, 'mouseout',  resetHostRow);
        if(!elem.onclick) {
            elem.onclick = selectHost;
        }
    }
    if(type == 'service') {
        addEvent(elem, 'mouseover', highlightServiceRow);
        addEvent(elem, 'mouseout',  resetServiceRow);
        if(!elem.onclick) {
            elem.onclick = selectService;
        }
    }
}

/* add additional eventhandler to object */
function addEvent( obj, type, fn ) {
  if ( obj.attachEvent ) {
    obj['e'+type+fn] = fn;
    obj[type+fn] = function(){obj['e'+type+fn]( window.event );}
    obj.attachEvent( 'on'+type, obj[type+fn] );
  } else
    obj.addEventListener( type, fn, false );
}

/* remove an eventhandler from object */
function removeEvent( obj, type, fn ) {
  if ( obj.detachEvent ) {
    obj.detachEvent( 'on'+type, obj[type+fn] );
    obj[type+fn] = null;
  } else
    obj.removeEventListener( type, fn, false );
}


/* returns the first element which has an id */
function getFirstParentId(elem) {
    if(!elem) {
        alert("ERROR: got no element in getFirstParentId()");
        return false;
    }
    nr = 0;
    while(nr < 10 && !elem.id) {
        nr++;
        if(!elem.parentNode) {
            //alert("ERROR: element has no parentNode in getFirstParentId(): " + elem);
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
        //alert("ERROR: got no row in setRowStyle(): " + row_id);
        return false;
    }

    // for each cells in this row
    var cells = row.cells;
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

/* save current style and change it*/
function styleElements(elems, style, force) {
    if (elems == null || ( typeof(elems) != "object" && typeof(elems) != "function" ) || typeof(elems.length) != "number") {
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
                elems[x].className = elems[x].origclass;
            }
        }
        else {
            if(elems[x].className != "tableRowSelected" || force) {
                // save style in custom attribute
                if(elems[x].className != "undefined" && elems[x].className != "tableRowSelected" && elems[x].className != "tableRowHover") {
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
function highlightServiceRow()
{
    // reset all current highlighted rows
    $$('td.tableRowHover').each(function(e) {
        resetHostRow(e);
        resetServiceRow(e);
    });

    // find id of current row
    var row_id = getFirstParentId(this);
    if(!row_id) {
      return;
    }
    setRowStyle(row_id, 'tableRowHover', 'service');
}

/* this is the mouseover function for hosts */
function highlightHostRow()
{
    // reset all current highlighted rows
    $$('td.tableRowHover').each(function(e) {
        resetHostRow(e);
        resetServiceRow(e);
    });

    // find id of current row
    var row_id = getFirstParentId(this);
    if(!row_id) {
      return;
    }
    setRowStyle(row_id, 'tableRowHover', 'host');
}

/* select this service */
function selectService(event, state)
{
    unselectCurrentSelection();
    var row_id;
    // find id of current row
    if(event && event.target) {
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
function selectServiceByIdEvent(row_id, state, event)
{
    if(is_shift_pressed(event) && lastRowSelected != undefined) {
      no_more_events = 1;
      var id1 = parseInt(row_id.substring(1));
      var id2 = parseInt(lastRowSelected.substring(1));

      // all selected should get the same state
      state = false;
      if(selectedServices.get(lastRowSelected)) {
        state = true;
      }

      // selected top down?
      if(id1 > id2) {
        var tmp = id2;
        id2 = id1;
        id1 = tmp;
      }

      for(var x = id1; x < id2; x++) {
        selectServiceByIdEvent('r'+x, state);
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
    var targetState;
    if(!Object.isUndefined(state)) {
        targetState = state;
    }
    else if(selectedServices.get(row_id)) {
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
        setRowStyle(row_id, 'tableRowSelected', 'service', true);
        selectedServices.set(row_id, 1);
    } else {
        setRowStyle(row_id, 'original', 'service', true);
        selectedServices.unset(row_id);
    }
    return true;
}

/* select this host */
function selectHost(event, state)
{
    unselectCurrentSelection();

    var row_id;
    // find id of current row
    if(event && event.target) {
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

    if(is_shift_pressed(event) && lastRowSelected != undefined) {
      no_more_events = 1;
      var id1 = parseInt(row_id.substring(1));
      var id2 = parseInt(lastRowSelected.substring(1));

      // all selected should get the same state
      state = false;
      if(selectedHosts.get(lastRowSelected)) {
        state = true;
      }

      // selected top down?
      if(id1 > id2) {
        var tmp = id2;
        id2 = id1;
        id1 = tmp;
      }

      for(var x = id1; x < id2; x++) {
        selectHostByIdEvent('r'+x, state);
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
    var targetState;
    if(!Object.isUndefined(state)) {
        targetState = state;
    }
    else if(selectedHosts.get(row_id)) {
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
    if(row.cells[0].innerHTML == "") {
      return true;
    }

    if(targetState) {
        setRowStyle(row_id, 'tableRowSelected', 'host', true);
        selectedHosts.set(row_id, 1);
    } else {
        setRowStyle(row_id, 'original', 'host', true);
        selectedHosts.unset(row_id);
    }
    return true;
}


/* reset row style unless it has been clicked */
function resetServiceRow(event)
{
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
        return;
    }
    setRowStyle(row_id, 'original', 'service');
}

/* reset row style unless it has been clicked */
function resetHostRow(event)
{
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
        return;
    }
    setRowStyle(row_id, 'original', 'host');
}

/* select or deselect all services */
function selectAllServices(state) {
    var x = 0;
    while(selectServiceById('r'+x, state)) {
        // disable next row
        x++;
    };

    checkCmdPaneVisibility();
}
/* select services by class name */
function selectServicesByClass(classes) {
    classes.each(function(classname) {
        $$(classname).each(function(obj) {
            selectService(obj, true);
        })
    });
}

/* select hosts by class name */
function selectHostsByClass(classes) {
    classes.each(function(classname) {
        $$(classname).each(function(obj) {
            selectHost(obj, true);
        })
    });
}

/* select or deselect all hosts */
function selectAllHosts(state) {
    var x = 0;
    while(selectHostById('r'+x, state)) {
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
    var size = selectedServices.size() + selectedHosts.size();
    if(size == 0) {
        /* hide command panel */
        toggleCmdPane(0);
    } else {
        setRefreshRate(refresh_rate);

        /* set submit button text */
        var btn = document.getElementById('multi_cmd_submit_button');
        var ssize = selectedServices.size();
        var hsize = selectedHosts.size();
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
function collectFormData() {

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

    var services = new Array();
    selectedServices.keys().each(function(row_id) {
        services.push(servicesHash.get(row_id));
    });
    service_form = document.getElementById('selected_services');
    service_form.value = services.join(',');

    var hosts = new Array();
    selectedHosts.keys().each(function(row_id) {
        hosts.push(servicesHash.get(row_id));
    });
    host_form = document.getElementById('selected_hosts');
    host_form.value = hosts.join(',');

    return(true);
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
    }
    if(value == 3) { /* add comment */
        enableFormElement('row_comment');
        enableFormElement('row_comment_options');
    }
    if(value == 4) { /* add acknowledgement */
        enableFormElement('row_comment');
        enableFormElement('row_ack_options');
    }
    if(value == 5) { /* remove downtimes */
    }
    if(value == 6) { /* remove comments */
    }
    if(value == 7) { /* remove acknowledgement */
    }
    if(value == 8) { /* enable active checks */
    }
    if(value == 9) { /* disable active checks */
    }
    if(value == 10) { /* enable notifications */
    }
    if(value == 11) { /* disable notifications */
    }
    if(value == 12) { /* submit passive check result */
        enableFormElement('row_submit_options');
    }
}

/* hide all form element rows */
function disableAllFormElement() {
    var elems = new Array('row_start', 'row_end', 'row_comment', 'row_reschedule_options', 'row_ack_options', 'row_comment_options', 'row_submit_options');
    elems.each(function(id) {
        obj = document.getElementById(id);
        obj.style.display = "none";
    });
}

/* show this form row */
function enableFormElement(id) {
    obj = document.getElementById(id);
    obj.style.display = "";
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
function toggleFilterPane() {
  var pane = document.getElementById('all_filter_table');
  var img  = document.getElementById('filter_button');
  if(pane.style.display == 'none') {
    pane.style.display    = '';
    pane.style.visibility = 'visible';
    img.style.display     = 'none';
    img.style.visibility  = 'hidden';
    additionalParams.set('hidesearch', 2);
    document.getElementById('hidesearch').value = 2;
  }
  else {
    pane.style.display    = 'none';
    pane.style.visibility = 'hidden';
    img.style.display     = '';
    img.style.visibility  = 'visible';
    additionalParams.set('hidesearch', 1);
    document.getElementById('hidesearch').value = 1;
  }
}

/* toggle filter pane */
function toggleFilterPaneSelector(search_prefix, id) {
  var panel;
  var checkbox_name;
  var input_name;
  var checkbox_prefix;

  search_prefix = search_prefix.substring(0, 3);

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
    alert("ERROR: unknown id in toggleFilterPaneSelector(): " + search_prefix + id);
    return;
  }
  if(!toggleElement(search_prefix+panel)) {
    accept_filter_types(search_prefix, checkbox_name, input_name, checkbox_prefix);
  } {
    set_filter_types(search_prefix, input_name, checkbox_prefix);
  }
}

/* calculate the sum for a filter */
function accept_filter_types(search_prefix, checkbox_names, result_name, checkbox_prefix) {
    var inp  = document.getElementsByName(search_prefix + result_name);
    if(!inp || inp.length == 0) { alert("ERROR: no element in accept_filter_types() for: " + search_prefix + result_name); return; }
    var orig = inp[0].value;
    var sum = 0;
    var elems = Array.from(document.getElementsByName(search_prefix + checkbox_names));
    elems.each(function(elem) {
        if(elem.checked) {
            sum += parseInt(elem.value);
        }
    });
    inp[0].value = sum;

    set_filter_name(search_prefix, checkbox_names, checkbox_prefix, parseInt(sum));

    /* removed submit, its inconsistend to submit the form sometimes and sometimes not */
    /* submit the form if something changed */
    //if(sum != orig) {
    //  form = document.getElementById('filterForm');
    //  form.submit();
    //}
}

/* set the initial state of filter checkboxes */
function set_filter_types(search_prefix, initial_id, checkbox_prefix) {
    var inp = document.getElementsByName(search_prefix + initial_id);
    if(!inp || inp.length == 0) { alert("ERROR: no element in set_filter_types() for: " + search_prefix + initial_id); return; }
    var initial_value = parseInt(inp[0].value);
    var bin  = initial_value.toString(2);
    var bits = new Array(); bits = bin.split('').reverse();
    for (var index = 0, len = bits.length; index < len; ++index) {
        var bit = bits[index];
        var nr  = Math.pow(2, index);
        var checkbox = document.getElementById(search_prefix + checkbox_prefix + nr);
        if(!checkbox) { alert("ERROR: got no checkbox for id in set_filter_types(): " + search_prefix + checkbox_prefix + nr); return; }
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
    alert('ERROR: unknown prefix in set_filter_name(): ' + checkbox_prefix);
  }

  var checked_ones = new Array();
  order.each(function(bit) {
    checkbox = document.getElementById(search_prefix + checkbox_prefix + bit);
    if(!checkbox) { alert('ERROR: got no checkbox in set_filter_name(): ' + search_prefix + checkbox_prefix + bit); }
    if(checkbox.checked) {
      nameElem = document.getElementById(search_prefix + checkbox_prefix + bit + 'n');
      if(!nameElem) { alert('ERROR: got no element in set_filter_name(): ' + search_prefix + checkbox_prefix + bit + 'n'); }
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

/* add a new filter selector to this table */
function add_new_filter(search_prefix, table) {
  search_prefix = search_prefix.substring(0,3);
  table = document.getElementById(search_prefix+table);
  if(!table) { alert("ERROR: got no table for id in add_new_filter(): " + search_prefix+table); return; }

  // add new row
  var tblBody        = table.tBodies[0];
  var currentLastRow = tblBody.rows.length - 1;
  var newRow         = tblBody.insertRow(currentLastRow);

  // get first free number of typeselects
  var nr = 0;
  for(var x = 0; x<= 99; x++) {
    tst = document.getElementById(search_prefix + x + '_ts');
    if(tst) { nr = x+1; }
  }

  // add first cell
  var typeselect        = document.createElement('select');
  var options           = new Array('Search', 'Host', 'Service', 'Hostgroup', 'Servicegroup', 'Contact','Parent', 'Last Check', 'Next Check');
  typeselect.onchange   = verify_op;
  typeselect.setAttribute('name', search_prefix + 'type');
  typeselect.setAttribute('id', search_prefix + nr + '_ts');
  add_options(typeselect, options);

  var opselect          = document.createElement('select');
  var options           = new Array('~', '!~', '=', '!=', '<=', '>=');
  opselect.setAttribute('name', search_prefix + 'op');
  opselect.setAttribute('id', search_prefix + nr + '_to');
  add_options(opselect, options);

  var newCell0 = newRow.insertCell(0);
  newCell0.nowrap    = "true";
  newCell0.className = "filterName";
  newCell0.appendChild(typeselect);
  newCell0.appendChild(opselect);

  // add second cell
  var newInput       = document.createElement('input');
  newInput.type      = 'text';
  newInput.value     = '';
  newInput.setAttribute('name', search_prefix + 'value');
  newInput.setAttribute('id',   search_prefix + nr + '_value');
  if(ajax_search_enabled) {
    newInput.onclick = ajax_search.init;
  }
  var newCell1       = newRow.insertCell(1);
  newCell1.className = "filterValueInput";
  newCell1.appendChild(newInput);

  var calImg = document.createElement('img');
  calImg.src = "/thruk/themes/"+theme+"/images/calendar.png";
  calImg.className = "cal_icon";
  calImg.alt = "choose date";
  var link   = document.createElement('a');
  link.href  = "javascript:show_cal('" + search_prefix + nr + "_value')";
  link.setAttribute('id',   search_prefix + nr + '_cal');
  link.style.display    = "none";
  link.style.visibility = "hidden";
  link.appendChild(calImg);
  newCell1.appendChild(link);

  // add third cell
  var img            = document.createElement('input');
  img.type           = 'image';
  img.src            = "/thruk/themes/"+theme+"/images/minus.gif";
  img.className      = 'filter_button';
  img.onclick        = delete_filter_row;
  var newCell2       = newRow.insertCell(2);
  newCell2.className = "filterValueNoHighlight";
  newCell2.appendChild(img);
}

/* remove a row */
function delete_filter_row(event) {
  var row;
  if(event && event.target) {
    row = event.target.parentNode.parentNode;
  } else if(event) {
    row = event.parentNode.parentNode;
  } else {
    row = this.parentNode.parentNode;
  }
  row.parentNode.deleteRow(row.rowIndex);
  return false;
}

/* add options to a select */
function add_options(select, options) {
  options.each(function(text) {
    var opt = document.createElement('option');
    opt.text     = text;
    opt.value    = text.toLowerCase();
    select.options[select.options.length] = opt;
  });
}

/* create a complete new filter pane */
function new_filter(cloneObj, parentObj, btnId) {
  var search_prefix = btnId.substring(0, 3);
  var origObj  = document.getElementById(search_prefix+cloneObj);
  if(!origObj) { alert("ERROR: no elem to clone in new_filter() for: " + search_prefix + cloneObj); }
  var newObj   = origObj.cloneNode(true);

  var new_prefix = 's' + (parseInt(search_prefix.substring(1)) + 1) + '_';

  // replace ids and names
  var tags = new Array('A', 'INPUT', 'TABLE', 'TR', 'TD', 'SELECT', 'INPUT', 'DIV', 'IMG');
  tags.each(function(tag) {
      var elems = newObj.getElementsByTagName(tag);
      replaceIdAndNames(elems, new_prefix);
  });

  // replace id of panel itself
  replaceIdAndNames(newObj, new_prefix);

  var tblObj   = document.getElementById(parentObj);
  var tblBody  = tblObj.tBodies[0];
  var nextCell = tblBody.rows[0].cells.length;
  var newCell  = tblBody.rows[0].insertCell(nextCell);
  newCell.setAttribute('valign', 'top');
  newCell.appendChild(newObj);

  // hide the original button
  hideElement(btnId);
  hideBtn = document.getElementById(new_prefix + 'filter_button_mini');
  if(hideBtn) { hideElement(hideBtn); }
  hideElement(new_prefix + 'btn_accept_search');
  showElement(new_prefix + 'btn_del_search');

  hideBtn = document.getElementById(new_prefix + 'filter_title');
  if(hideBtn) { hideElement(hideBtn); }
}

/* replace ids and names for elements */
function replaceIdAndNames(elems, new_prefix) {
  if (elems == null || ( typeof(elems) != "object" && typeof(elems) != "function" ) || typeof(elems.length) != "number") {
    elems = new Array(elems);
  }
  for(var x = 0; x < elems.length; x++) {
    var elem = elems[x];
    if(elem.id) {
        var new_id = elem.id.replace(/^s\d+_/, new_prefix);
        elem.setAttribute('id', new_id);
    }
    if(elem.name) {
        var new_name = elem.name.replace(/^s\d+_/, new_prefix);
        elem.setAttribute('name', new_name);
    }

    if(ajax_search_enabled && elem.tagName == 'INPUT' && elem.type == 'text') {
      elem.onclick = ajax_search.init;
    }
  };
}

/* remove a search panel */
function deleteSearchPane(id) {
  var search_prefix = id.substring(0, 3);

  var pane = document.getElementById(search_prefix + 'filter_pane');
  var cell = pane.parentNode;
  while(cell.firstChild) {
      child = cell.firstChild;
      cell.removeChild(child);
  }

  // show last "new search" button
  var last_nr = 0;
  for(var x = 0; x<= 99; x++) {
      tst = document.getElementById('s'+x+'_' + 'new_filter');
      if(tst && 's'+x+'_' != search_prefix) { last_nr = x; }
  }
  showElement('s'+last_nr+'_' + 'new_filter');

  return false;
}

/* toogle checkbox for attribute filter */
function toggleFilterCheckBox(id) {
  id  = id.substring(0, id.length -1);
  var box = document.getElementById(id);
  if(box.checked) {
    box.checked = false;
  } else {
    box.checked = true;
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

  // check if the right operator are active
  for(var x = 0; x< opElem.options.length; x++) {
    var curOp = opElem.options[x].value;
    if(curOp == '~' || curOp == '!~') {
      if(selValue != 'search' && selValue != 'host' && selValue != 'service' ) {
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
      } else {
        opElem.options[x].style.display = "";
      }
    }

    if(curOp == '<=' || curOp == '>=') {
      if(selValue != 'next check' && selValue != 'last check' ) {
        // is this currently selected?
        if(x == opElem.selectedIndex) {
          // only <= and >= are allowed for list searches
          selectByValue(opElem, '=');
        }
        opElem.options[x].style.display = "none";
      } else {
        opElem.options[x].style.display = "";
      }
    }
  }
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
  var formInput = document. getElementById('hidetop');
  if(toggleElement('top_pane')) {
    additionalParams.set('hidetop', 0);
    formInput.value = 0;
  } else {
    additionalParams.set('hidetop', 1);
    formInput.value = 1;
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

function show_cal(id) {
  var dateObj   = new Date();
  var date_val  = document.getElementById(id).value;
  var date_time = date_val.split(" ");
  if(date_time.length == 2) {
    var dates     = date_time[0].split('-');
    var times     = date_time[1].split(':');
    dateObj   = new Date(dates[0], (dates[1]-1), dates[2], times[0], times[1], times[2]);
  }
  else {
    times = new Array(0,0,0);
  }

  var cal = Calendar.setup({
      time: Calendar.printDate(dateObj, '%H%M'),
      date: Calendar.dateToInt(dateObj),
      showTime: true,
      fdow: 1,
      weekNumbers: true,
      onSelect: function() {
        var newDateObj = new Date(this.selection.print('%Y'), (this.selection.print('%m')-1), this.selection.print('%d'), this.getHours(), this.getMinutes(), times[2]);
        document.getElementById(id).value = Calendar.printDate(newDateObj, '%Y-%m-%d %H:%M:%S');
        this.hide();
      },
      onBlur: function() {
        var newDateObj = new Date(this.selection.print('%Y'), (this.selection.print('%m')-1), this.selection.print('%d'), this.getHours(), this.getMinutes(), times[2]);
        document.getElementById(id).value = Calendar.printDate(newDateObj, '%Y-%m-%d %H:%M:%S');
      }
  });
  cal.selection.set(Calendar.dateToInt(dateObj));
  cal.popup(id);
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
var a;
var ajax_search = {
    url             : '/thruk/cgi-bin/status.cgi?format=search',
    max_results     : 12,
    input_field     : 'NavBarSearchItem',
    result_pan      : 'search-results',
    update_interval : 3600, // update at least every hour
    search_type     : 'all',

    base            : new Array(),
    initialized     : false,
    cur_select      : -1,
    result_size     : false,
    cur_results     : false,
    cur_pattern     : false,
    timer           : false,

    /* initialize search */
    init: function(elem) {
        if(elem && elem.id) {
        } else if(this.id) {
          elem = this;
        } else {
          return false;
        }

        ajax_search.input_field = elem.id;

        var input = document.getElementById(ajax_search.input_field);
        input.onkeyup = ajax_search.suggest;
        input.setAttribute("autocomplete", "off");
        input.blur();   // blur & focus the element, otherwise the first
        input.focus();  // click would result in the browser autocomplete

        var tmpElem = input;
        while(tmpElem && tmpElem.parentNode) {
            tmpElem = tmpElem.parentNode;
            if(tmpElem.tagName == 'FORM') {
                tmpElem.onsubmit = ajax_search.hide_results;
            }
        }

        // set type from select
        var type_selector_id = elem.id.replace('_value', '_ts');
        var selector = document.getElementById(type_selector_id);
        ajax_search.search_type = 'all';
        if(selector && selector.tagName == 'SELECT') {
            var search_type = selector.options[selector.selectedIndex].value;
            if(search_type == 'host' || search_type == 'hostgroup' || search_type == 'service' || search_type == 'servicegroup') {
                ajax_search.search_type = search_type;
            }
            if(search_type == 'parent') {
                ajax_search.search_type = 'host';
            }
        }

        var date = new Date;
        var now  = parseInt(date.getTime() / 1000);
        // update every hour (frames searches wont update otherwise)
        if(ajax_search.initialized && now > ajax_search.initialized - ajax_search.update_interval) {
            ajax_search.suggest();
            return false;
        }
        ajax_search.initialized = now;
        new Ajax.Request(ajax_search.url, {
            onSuccess: function(transport) {
                if(transport.responseJSON != null) {
                    ajax_search.base = transport.responseJSON;
                } else {
                    ajax_search.base = eval(transport.responseText);
                }
                ajax_search.suggest();
            }
        });

        document.onkeydown  = ajax_search.arrow_keys;
        document.onclick    = ajax_search.hide_results;

        return false;
    },

    /* hide the search results */
    hide_results: function(event) {
        if(event && event.target) {
        }
        else {
            event  = this;
        }
        try {
            // dont hide search result if clicked on the input field
            if(event.target.tagName == 'INPUT') { return; }
        }
        catch(e) {
            // doesnt matter
        }

        var panel = document.getElementById(ajax_search.result_pan);
        if(!panel) { return; }
        hideElement(panel);
    },

    /* wrapper around suggest() to avoid multiple running searches */
    suggest: function(evt) {
        window.clearTimeout(ajax_search.timer);

        // dont suggest on enter
        evt = (evt) ? evt : ((window.event) ? event : null);
        if(evt) {
            var keyCode = evt.keyCode;
            if(keyCode == 13 || keyCode == 108) {
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
        if(ajax_search.base.size() == 0) { return; }

        pattern = input.value;
        if(pattern.length >= 1 || ajax_search.search_type != 'all') {

            // remove empty strings from pattern array
            pattern = pattern.split(" ");
            var trimmed_pattern = new Array();
            pattern.each(function(sub_pattern) {
                if(sub_pattern != '') {
                    trimmed_pattern.push(sub_pattern);
                }
            });
            pattern = trimmed_pattern;

            var results = new Array();
            ajax_search.base.each(function(search_type) {
                var sub_results = new Array();
                var top_hits = 0;
                if(ajax_search.search_type == 'all' || ajax_search.search_type + 's' == search_type.name) {
                  search_type.data.each(function(data) {
                      result_obj = new Object({ 'name': data, 'relevance': 0 });
                      var found = 0;
                      pattern.each(function(sub_pattern) {
                          var index = data.indexOf(sub_pattern);
                          if(index != -1) {
                              found++;
                              if(index == 0) { // perfect match, starts with pattern
                                  result_obj.relevance += 100;
                              } else {
                                  result_obj.relevance += 1;
                              }
                          }
                      });
                      // only if all pattern were found
                      if(found == pattern.size()) {
                          result_obj.display = data;
                          sub_results.push(result_obj);
                          if(result_obj.relevance >= 100) { top_hits++; }
                      }
                  });
                }
                if(sub_results.size() > 0) {
                    sub_results = sub_results.sortBy(function(s) {
                        return((-1 * s.relevance) + s.name);
                    });
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
        ajax_search_res = results;
        ajax_search_pat = pattern;
        ajax_search_sel = selected;

        var panel = document.getElementById(ajax_search.result_pan);
        var input = document.getElementById(ajax_search.input_field);
        if(!panel) { return; }

        size = results.size();
        if(size == 1 && results[0].results[0].display == input.value) {
            return;
        }

        results = results.sortBy(function(s) {
            return(-1 * s.top_hits);
        });

        var resultHTML = '<ul>';
        var x = 0;
        var results_per_type = Math.ceil(ajax_search.max_results / results.size());
        results.each(function(type) {
            var cur_count = 0;
            resultHTML += '<li><b><i>' + ( type.results.size() ) + ' ' + type.name.substring(0,1).toUpperCase() + type.name.substring(1) + '<\/i><\/b><\/li>';
            type.results.each(function(data) {
                if(cur_count <= results_per_type) {
                    var name = data.display;
                    pattern.each(function(sub_pattern) {
                        name = name.replace(sub_pattern, "<b>" + sub_pattern + "<\/b>");
                    });
                    var classname = "item";
                    if(selected != -1 && selected == x) {
                        classname = "item ajax_search_selected";
                    }
                    resultHTML += '<li> <a href="" class="' + classname + '" onclick="return ajax_search.set_result(\'' + data.display +'\')"> ' + name +'<\/a><\/li>';
                    x++;
                    cur_count++;
                }
            });
        });
        ajax_search.result_size = x;
        resultHTML += '<\/ul>';
        if(results.size() == 0) {
            resultHTML += '<a href="#">no results found</a>';
        }

        panel.innerHTML = resultHTML;

        var style = panel.style;
        var coords    = ajax_search.get_coordinates(input);
        style.left    = coords[0] + "px";
        style.top     = (coords[1] + input.offsetHeight + 2) + "px";
        style.display = "block";

        showElement(panel);
    },

    /* set the value into the input field */
    set_result: function(value) {
        var input = document.getElementById(ajax_search.input_field);
        input.value = value;
        ajax_search.cur_select = -1;
        ajax_search.hide_results();
        input.focus();
        return false;
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
                var el = document.getElementsByClassName('ajax_search_selected');
                if(el[0]) {
                    el[0].focus();
                }
            }
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
    }
}
