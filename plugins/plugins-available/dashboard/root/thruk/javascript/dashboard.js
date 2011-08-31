/*
################################################################
#                     SIGMA Informatique
################################################################
#
# AUTEUR :	SIGMA INFORMATIQUE
#
# OBJET  :	Dashboard plugin
#
# DESC   :	Overload one Thruk.js function for delete some filters on display filter
#
#
################################################################
# Copyright © 2011 Sigma Informatique. All rights reserved.
# Copyright © 2010 Thruk Developer Team.
# Copyright © 2009 Nagios Core Development Team and Community Contributors.
# Copyright © 1999-2009 Ethan Galstad.
################################################################
*/

/* add a new filter selector to this table */
function add_new_filter(search_prefix, table) {
  pane_prefix   = search_prefix.substring(0,4);
  search_prefix = search_prefix.substring(4);
  search_prefix = search_prefix.substring(0,3);
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
  var substyle   = document.getElementById('substyle').value;
  if(substyle == 'host') {
	var options    = new Array(
								 'Hostgroup'
								);
  }
  if(substyle == 'service') {
	var options    = new Array(
								 'Servicegroup'
								);
  }
  
  typeselect.onchange   = verify_op;
  typeselect.setAttribute('name', pane_prefix + search_prefix + 'type');
  typeselect.setAttribute('id', pane_prefix + search_prefix + nr + '_ts');
  add_options(typeselect, options);

  var opselect          = document.createElement('select');
  var options           = new Array('~', '!~', '=', '!=');
  opselect.setAttribute('name', pane_prefix + search_prefix + 'op');
  opselect.setAttribute('id', pane_prefix + search_prefix + nr + '_to');
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
  newInput.setAttribute('name', pane_prefix + search_prefix + 'value');
  newInput.setAttribute('id',   pane_prefix + search_prefix + nr + '_value');
  if(ajax_search_enabled) {
    newInput.onclick = ajax_search.init;
  }
  var newCell1       = newRow.insertCell(1);
  newCell1.className = "filterValueInput";
  newCell1.appendChild(newInput);

  // add third cell
  var img            = document.createElement('input');
  img.type           = 'image';
  img.src            = url_prefix + "thruk/themes/"+theme+"/images/minus.gif";
  img.className      = 'filter_button';
  img.onclick        = delete_filter_row;
  var newCell2       = newRow.insertCell(2);
  newCell2.className = "filterValueNoHighlight";
  newCell2.appendChild(img);
}