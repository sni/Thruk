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
var origRefreshVal   = 0;
var curRefreshVal    = 0;
var additionalParams = new Hash({});

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
    return;
  }
  if(pane.style.visibility == "" || pane.style.visibility == "hidden") {
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
    toggleElement('pref_pane_button');
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
      setTimeout("setRefreshRate(newRate)", 1000);
    }
  }
}

/* stops the reload interval */
function stopRefresh() {
  refreshPage = 0;
  setRefreshRate(0);
}

/* reloads the current page and adds some parameter from a hash */
function reloadPage() {
  var obj = document.getElementById('refresh_rate');
  obj.innerHTML = "<span id='refresh_rate'>page will be refreshed...</span>";

  var origUrl = new String(window.location);
  var newUrl  = origUrl;
  var index   = newUrl.indexOf('?');
  var urlArgs = new Hash();
  if(index != -1) {
    newUrl  = newUrl.substring(0, index);
    urlArgs = new Hash(origUrl.parseQuery());
  }

  additionalParams.each(function(pair) {
    if(pair.key == 'hidesearch') { // check for valid options to set here
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
  } else {
    button.className = "button_peerDIS";
    current_backend_states.set(backend, 2);
  }

  /* save current selected backends in session cookie */
  document.cookie = "thruk_backends="+current_backend_states.toQueryString()+ "; path=/;";
  if(initial_state != 3) {
    reloadPage();
  }
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
function addRowSelector(id)
{
    var table = document.getElementById(id);
    var rows  = table.tBodies[0].rows;

    // for each table row, beginning with the second ( dont need table header )
    for(var row_nr = 1; row_nr < rows.length; row_nr++) {
        var cells = rows[row_nr].cells;

        // for each cell in a row
        for(var cell_nr = 0; cell_nr < cells.length; cell_nr++) {
            if(pagetype == "hostdetail" || (cell_nr == 0 && cells[0].innerHTML != '')) {
                addEventHandler(cells[cell_nr], 'host');
            }
            else if(cell_nr >= 1) {
                addEventHandler(cells[cell_nr], 'service');
            }
        }
    }
}

/* add the event handler */
function addEventHandler(elem, type) {
    if(type == 'host') {
        elem.onmouseover = highlightHostRow;
        elem.onmouseout  = resetHostRow;
        if(!elem.onclick) {
            elem.onclick     = selectHost;
        }
    }
    if(type == 'service') {
        elem.onmouseover = highlightServiceRow;
        elem.onmouseout  = resetServiceRow;
        if(!elem.onclick) {
            elem.onclick     = selectService;
        }
    }
}

/* returns the first element which has an id */
function getFirstParentId(elem) {
    nr = 0;
    while(nr < 100 && (!elem.id || elem.id == '')) {
        nr++;
        elem = elem.parentNode;
    }
    return elem.id;
}

/* set style for each cell */
function setRowStyle(row_id, style, type, force) {

    var row = document.getElementById(row_id);

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
}

/* save current style and change it*/
function styleElements(elems, style, force) {
    if (elems==null || typeof(elems)!="object" || typeof(elems.length)!="number") {
        elems = new Array(elems);
    }
    for(var x = 0; x < elems.length; x++) {
        if(style == 'original') {
            // reset style to original
            if(elems[x].hasAttribute('origClass') && (elems[x].className == "tableRowHover" || force)) {
                elems[x].className = elems[x].origClass;
            }
        }
        else {
            if(elems[x].className != "tableRowSelected" || force) {
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
function highlightServiceRow(event)
{
    // find id of current row
    var row_id = getFirstParentId(event.target.parentNode);
    setRowStyle(row_id, 'tableRowHover', 'service');
}

/* this is the mouseover function for hosts */
function highlightHostRow(event)
{
    // find id of current row
    var row_id = getFirstParentId(event.target.parentNode);
    setRowStyle(row_id, 'tableRowHover', 'host');
}

/* select this service */
function selectService(event, state)
{
    var row_id;
    if(!event) {
        return;
    }
    // find id of current row
    if(event.target) {
        row_id = getFirstParentId(event.target);

        // dont select row when clicked on a link
        if(event.target.tagName == 'A' || event.target.tagName == 'IMG') {
            resetServiceRow(event);
            return;
        }
    } else {
        row_id = getFirstParentId(event);
    }
    if(!row_id) {
        return;
    }
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
    if(targetState) {
        setRowStyle(row_id, 'tableRowSelected', 'service', true);
        selectedServices.set(row_id, 1);
    } else {
        setRowStyle(row_id, 'original', 'service', true);
        selectedServices.unset(row_id);
    }
    checkCmdPaneVisibility();
}

/* select this host */
function selectHost(event, state)
{
    var row_id;
    if(!event) {
        return;
    }
    // find id of current row
    if(event.target) {
        row_id = getFirstParentId(event.target);

        // dont select row when clicked on a link
        if(event.target.tagName == 'A' || event.target.tagName == 'IMG') {
            resetHostRow(event);
            return;
        }
    } else {
        row_id = getFirstParentId(event);
    }
    if(!row_id) {
        return;
    }
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
    if(targetState) {
        setRowStyle(row_id, 'tableRowSelected', 'host', true);
        selectedHosts.set(row_id, 1);
    } else {
        setRowStyle(row_id, 'original', 'host', true);
        selectedHosts.unset(row_id);
    }
    checkCmdPaneVisibility();
}

/* reset row style unless it has been clicked */
function resetServiceRow(event)
{
    var row_id;
    if(!event) {
        return;
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
    // find id of current row
    var row_id = getFirstParentId(event.target.parentNode);
    setRowStyle(row_id, 'original', 'host');
}
/* select or deselect all services */
function selectAllServices(state) {
    if(state) {
        var classes = new Array('.statusOK', '.statusWARNING', '.statusUNKNOWN', '.statusCRITICAL', '.statusPENDING');
    }
    else {
        var classes = new Array('.tableRowSelected');
    }
    classes.each(function(classname) {
        $$(classname).each(function(obj) {
            selectService(obj, state);
        })
    });
}
function selectServicesByClass(classes) {
    classes.each(function(classname) {
        $$(classname).each(function(obj) {
            selectService(obj, true);
        })
    });
}

/* select or deselect all hosts */
function selectAllHosts(state) {
    if(state) {
        var classes = new Array('.statusHOSTUP', '.statusHOSTDOWN', '.statusHOSTUNREACHABLE');
    }
    else {
        var classes = new Array('.tableRowSelected');
    }
    classes.each(function(classname) {
        $$(classname).each(function(obj) {
            selectHost(obj, state);
        })
    });
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
        /* hide command panel and reenable refresh */
        toggleCmdPane(0);
        refreshPage = 1;
        setRefreshRate(origRefreshVal);
    } else {
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

        /* show command panel and disable page refresh */
        if(refreshPage == 1) {
            origRefreshVal = curRefreshVal;
            toggleCmdPane(1);
        }
        stopRefresh();
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
}

/* hide all form element rows */
function disableAllFormElement() {
    var elems = new Array('row_start', 'row_end', 'row_comment', 'row_reschedule_options', 'row_ack_options');
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
  }
  else {
    pane.style.display    = 'none';
    pane.style.visibility = 'hidden';
    img.style.display     = '';
    img.style.visibility  = 'visible';
    additionalParams.set('hidesearch', 1);
  }
}

/* toggle filter pane */
function toggleFilterPaneSelector(search_prefix, id) {
  var panel;
  var checkbox_name;
  var input_name;
  var checkbox_prefix;

  var search_prefix = search_prefix.substring(0, 3);

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

    /* submit the form if something changed */
    if(sum != orig) {
      form = document.getElementById('filterForm');
      form.submit();
    }
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
  var table = document.getElementById(search_prefix+table);
  if(!table) { alert("ERROR: got no table for id in add_new_filter(): " + search_prefix+table); return; }

  // add new row
  var tblBody        = table.tBodies[0];
  var currentLastRow = tblBody.rows.length - 1;
  var newRow         = tblBody.insertRow(currentLastRow);

  // get first free number of typeselects
  var nr = 0;
  for(var x = 0; x<= 99; x++) {
    tst = document.getElementById(search_prefix + 'typeselect_' + x);
    if(tst) { nr = x+1; }
  }

  // add first cell
  var typeselect        = document.createElement('select');
  var options           = new Array('Search', 'Host', 'Hostgroup', 'Servicegroup');
  typeselect.onchange   = verify_op;
  typeselect.setAttribute('name', search_prefix + 'type');
  typeselect.setAttribute('id', search_prefix + '_' + nr + '_ts');
  add_options(typeselect, options);

  var opselect          = document.createElement('select');
  //var options           = new Array('~', '!~', '=', '!=');
  var options           = new Array('~', '=', '!=');
  opselect.setAttribute('name', search_prefix + 'op');
  opselect.setAttribute('id', search_prefix + '_' + nr + '_to');
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
  var newCell1       = newRow.insertCell(1);
  newCell1.className = "filterValueInput";
  newCell1.appendChild(newInput);

  // add thirds cell
  var img            = document.createElement('input');
  img.type           = 'image';
  img.src            = "/thruk/themes/"+theme+"/images/icon_remove.png";
  img.className      = 'filter_button';
  img.onclick        = delete_filter_row;
  var newCell2       = newRow.insertCell(2);
  newCell2.className = "filterValueNoHighlight";
  newCell2.appendChild(img);
}

/* remove a row */
function delete_filter_row(event) {
  var row;
  if(event.target) {
    row = event.target.parentNode.parentNode;
  } else {
    row = event.parentNode.parentNode;
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
  if (elems==null || typeof(elems)!="object" || typeof(elems.length)!="number") {
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
  };
}

/* remove a search panel */
function deleteSearchPane(id) {
  var search_prefix = id.substring(0, 3);

  var pane = document.getElementById(search_prefix + 'filter_pane');
  var cell = pane.parentNode;
  while(child = cell.firstChild) {
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
  var id  = id.substring(0, id.length -1);
  var box = document.getElementById(id);
  if(box.checked) {
    box.checked = false;
  } else {
    box.checked = true;
  }
}

/* verify operator for search type selects */
function verify_op(e) {
  var selElem;
  if(e.target) {
    selElem = e.target;
  } else {
    selElem = document.getElementById(e);
  }

  // get operator select
  var opElem = document.getElementById(selElem.id.substring(0, selElem.id.length - 1) + 'o');

  var selValue = selElem.options[selElem.selectedIndex].value;

  for(var x = 0; x< opElem.options.length; x++) {
    var curOp = opElem.options[x].value;
    if(curOp == '~' || curOp == '!~') {
      if(selValue == 'hostgroup' || selValue == 'servicegroup') {
        // is this currently selected?
        if(x == opElem.selectedIndex) {
          selectByValue(opElem, '=');
        }
        opElem.options[x].disabled = true;
      } else {
        opElem.options[x].disabled = false;
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