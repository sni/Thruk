/* initialize all buttons */
function init_bp_buttons() {
    jQuery('A.bp_button').button();
    jQuery('BUTTON.bp_button').button();

    jQuery('.bp_edit_button').button({
        icons: {primary: 'ui-edit-button'}
    });

    jQuery('.bp_save_button').button({
        icons: {primary: 'ui-save-button'}
    });

    if (document.layers) {
      document.captureEvents(Event.MOUSEDOWN);
    }

    document.onmousedown   = bp_context_menu_open;
    document.oncontextmenu = bp_context_menu_open;
    window.onresize        = bp_redraw;
    return;
}

/* refresh given business process */
var current_node;
var is_refreshing = false;
function bp_refresh(bp_id, node_id, callback, refresh_only) {
    if(is_refreshing) { return false; }
    if(node_id && node_id != 'changed_only') {
        if(!minimal) {
            showElement('bp_status_waiting');
        }
    }
    /* adding timestamp makes IE happy */
    var ts = new Date().getTime();
    var old_nodes = nodes;
    is_refreshing = true;
    jQuery('#bp'+bp_id).load('bp.cgi?_=' + ts + '&action=refresh&edit='+editmode+'&bp='+bp_id+'&update='+(refresh_only ? 0 : 1), [], function(responseText, textStatus, XMLHttpRequest) {
        is_refreshing = false;
        if(!minimal) {
            hideElement('bp_status_waiting');
        }
        if(textStatus == "success") {
            var node = document.getElementById(current_node);
            bp_update_status(null, node);
            if(bp_active_node) {
                jQuery(node).addClass('bp_node_active');
            }
            if(node_id == 'changed_only') {
                // maybe hilight changed nodes in future...
            }
            else if(node_id) {
                jQuery('#'+node_id).effect('highlight', {}, 1500);
            }
            if(node_id == 'node1') {
                // first nodes name is linked to the bp name itself
                var n = bp_get_node(node.id)
                jQuery('#subtitle').html(n.label);
            }
        }
        if(callback) { callback(textStatus == 'success' ? true : false); }
        if(textStatus != 'success') {
            // remove current message
            jQuery('#thruk_message').remove();
            window.clearInterval(thruk_message_fade_timer);

            // responseText contains error?
            var msg = jQuery("SPAN.fail_message", responseText).text();
            thruk_message(1, 'refreshing failed: ' + msg);
        }
    });
    return true;
}

/* refresh business process in background */
function bp_refresh_bg(cb) {
    bp_refresh(bp_id, 'changed_only', cb, true);
}

/* unset active node */
function bp_unset_active_node() {
    if(!bp_context_menu) {
        jQuery('.bp_node_active').removeClass('bp_node_active');
        bp_active_node = undefined;
    }
}

/* close menu */
function bp_context_menu_close_cb() {
    bp_context_menu = false;
    bp_unset_active_node();
}

/* open menu */
var bp_context_menu = false;
var bp_active_node;
function bp_context_menu_open(evt, node) {
    evt = (evt) ? evt : ((window.event) ? event : null);

    var rightclick;
    if (evt.which) rightclick = (evt.which == 3);
    else if (evt.button) rightclick = (evt.button == 2);
    // clicking the wrench icon counts as right click too
    if(evt.target && jQuery(evt.target).hasClass('ui-icon-wrench')) { rightclick = true; }
    if(rightclick && node) {
        bp_context_menu = true;
        bp_unset_active_node();
        jQuery(node).addClass('bp_node_active');
        bp_active_node = node.id;
        bp_update_status(evt, node);
        jQuery("#bp_menu").menu().css('top', evt.pageY+'px').css('left', evt.pageX+'px').unbind('keydown');
        bp_menu_restore();
        // make sure menu does not overlap window
        var h = jQuery(window).height() - jQuery("#bp_menu").height() - 10;
        if(h < evt.pageY) {
            jQuery("#bp_menu").css('top', h+'px');
        }
        if(node.id == 'node1') {
            jQuery('.firstnode').css('display', '');
        } else {
            jQuery('.firstnode').css('display', 'none');
        }
        // first node cannot be removed
        if(node.id == 'node1' || !editmode) {
            jQuery('#bp_menu_remove_node').addClass('ui-state-disabled');
        } else {
            jQuery('#bp_menu_remove_node').removeClass('ui-state-disabled');
        }
    } else if(node) {
        bp_unset_active_node();
        jQuery(node).addClass('bp_node_active');
        bp_active_node = node.id;
        bp_update_status(evt, node);
    } else if(evt.target && jQuery(evt.target).hasClass('bp_container')) {
        bp_unset_active_node();
    }

    // always allow events on input fields
    if(evt.target && evt.target.tagName == "INPUT") {
        return true;
    }

    // don't interrupt user interactions by automatic reload
    resetRefresh();

    if(bp_context_menu) {
        if (evt.stopPropagation) {
            evt.stopPropagation();
        }
        if(evt.preventDefault != undefined) {
            evt.preventDefault();
        }
        evt.cancelBubble = true;
        return false;
    }
    return true;
}

/* restores menu if possible */
function bp_menu_restore() {
    if(original_menu) { // restore original menu
        jQuery('#bp_menu').html(original_menu);
    }
    showElement('bp_menu', undefined, true, undefined, bp_context_menu_close_cb);
    jQuery('.ui-state-focus').removeClass('ui-state-focus');
}

/* make node renameable */
function bp_show_rename(evt) {
    evt = (evt) ? evt : ((window.event) ? event : null);
    bp_menu_save();
    bp_menu_restore();
    var node = bp_get_node(current_node);
    jQuery('#bp_menu_rename_node').html(
         '<input type="text" value="'+node.label+'" id="bp_rename_text" style="width:100px;" onkeyup="bp_submit_on_enter(event, \'bp_rename_btn\')">'
        +'<input type="button" value="OK" style="width:40px;" id="bp_rename_btn" onclick="bp_confirmed_rename('+node.id+')">'
    );
    document.getElementById('bp_rename_text').focus();
    setCaretToPos(document.getElementById('bp_rename_text'), node.label.length);
    return(bp_no_more_events(evt))
}

/* send rename request */
function bp_confirmed_rename(node) {
    var text = jQuery('#bp_rename_text').val();
    bp_post_and_refresh('bp.cgi?action=rename_node&bp='+bp_id+'&node='+node.id+'&label='+text, [], node.id);
    hideElement('bp_menu');
}

/* post url and refresh on success*/
function bp_post_and_refresh(url, data, node_id) {
    jQuery.ajax({
        url:   url,
        type: 'POST',
        data:  data,
        success: function(data) {
            if(data && data.rc == 0) {
                bp_refresh(bp_id, node_id);
            } else if(data.message) {
                thruk_message(data.rc, data.message);
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            thruk_message(1, errorThrown);
        }
    });
    return;
}

/* remove node after confirm */
function bp_show_remove() {
    bp_menu_save();
    bp_menu_restore();
    var node = bp_get_node(current_node);
    jQuery('#bp_menu_remove_node').html(
         'Confirm: <input type="button" value="No" style="width: 50px;" onclick="bp_menu_restore()">'
        +'<input type="button" value="Yes" style="width: 40px;" onclick="bp_confirmed_remove('+node.id+')">'
    );
    return false;
}

/* send remoev request */
function bp_confirmed_remove(node) {
    bp_post_and_refresh('bp.cgi?action=remove_node&bp='+bp_id+'&node='+node.id, []);
    hideElement('bp_menu');
}

/* run command on enter */
function bp_submit_on_enter(evt, id) {
    evt = (evt) ? evt : ((window.event) ? event : null);
    if(evt.keyCode == 13){
        var btn = document.getElementById(id);
        btn.click();
    }
}

/* show node type select */
var current_edit_node;
var current_edit_node_clicked;
function bp_add_new_node() {
    hideElement('bp_menu');
    current_edit_node         = 'new';
    current_edit_node_clicked = current_node;
    jQuery("#bp_add_new_node").dialog({
        modal: true,
        closeOnEscape: true,
        width: 365
    });
    jQuery('.bp_type_btn').button();
    showElement('bp_add_new_node');
}

/* fill in form with current values */
function bp_fill_select_form(data) {
    var form = 'bp_edit_node_form';
    if(data.radio) {
        for(var key in data.radio) {
            var d = data.radio[key];
            jQuery('#'+form).find('INPUT[type=radio][name='+key+']').removeAttr("checked");
            jQuery('#'+form).find('INPUT[type=radio][name='+key+']][value="'+d[0]+'"]').attr("checked","checked");
            jQuery(d[1]).buttonset();
        }
    }
    if(data.text) {
        for(var key in data.text) {
            var d = data.text[key];
            jQuery('#'+form).find('INPUT[name='+key+']').val(d);
        }
    }
}

/* generic node type selection */
function bp_select_type(type) {
    bp_show_edit_node(undefined, false);
    jQuery('.bp_type_box').attr('checked', false).button("refresh");
    jQuery('#bp_check_'+type).attr('checked', true).button("refresh");
    jQuery.each(['status', 'fixed', 'at_least', 'not_more', 'equals', 'best', 'worst'], function(nr, s) {
        hideElement('bp_select_'+s);
    });
    // change details tab
    showElement('bp_select_'+type);
    // switch to details tab
    jQuery("#edit_dialog_"+bp_id).tabs({ active: 1 });

    // insert current values
    var node = bp_get_node(current_edit_node);
    if(node) {
        jQuery('#bp_edit_node_form').find('INPUT[name=bp_label_'+type+']').val(node.label);
    } else {
        jQuery('#bp_edit_node_form').find('INPUT[name=bp_label_'+type+']').val('');
    }
    if     (type == 'status')   { bp_select_status(node)    }
    else if(type == 'fixed')    { bp_select_fixed(node)     }
    else if(type == 'at_least') { bp_select_at_least(node)  }
    else if(type == 'not_more') { bp_select_not_more(node)  }
    else if(type == 'best')     { bp_select_best(node)      }
    else if(type == 'worst')    { bp_select_worst(node)     }
    else if(type == 'equals')   { bp_select_equals(node)    }
    jQuery('#bp_function').val(type);
}

/* show node type select: status */
function bp_select_status(node) {
    if(node && node.func.toLowerCase() == 'status') {
        bp_fill_select_form({
            text:  { 'bp_arg1_status': node.func_args[0], 'bp_arg2_status': node.func_args[1] }
        });
    } else {
        bp_fill_select_form({
            text:  { 'bp_arg1_status': '', 'bp_arg2_status': '' }
        });
    }
}

/* show node type select: fixed */
function bp_select_fixed(node) {
    if(node && node.func.toLowerCase() == 'fixed') {
        bp_fill_select_form({
            radio: { 'bp_arg1_fixed': [ node.func_args[0].toUpperCase(), '.bp_fixed_radio'] },
            text:  { 'bp_arg2_fixed': node.func_args[1] }
        });
    } else {
        bp_fill_select_form({
            radio: { 'bp_arg1_fixed': [ 'OK', '.bp_fixed_radio'] },
            text:  { 'bp_arg2_fixed': '' }
        });
    }
}

/* show node type select: best */
function bp_select_best(node) {
}

/* show node type select: worst */
function bp_select_worst(node) {
}

/* show node type select: equals */
function bp_select_equals(node) {
    if(node && node.func.toLowerCase() == 'equals') {
        bp_fill_select_form({
            text:  { 'bp_arg1_equals': node.func_args[0] }
        });
    } else {
        bp_fill_select_form({
            text:  { 'bp_arg1_equals': '' }
        });
    }
}

/* show node type select: not_more */
function bp_select_not_more(node) {
    if(node && (node.func.toLowerCase() == 'not_more' || node.func.toLowerCase() == 'at_least')) {
        bp_fill_select_form({
            text:  { 'bp_arg1_not_more': node.func_args[0], 'bp_arg2_not_more': node.func_args[1] }
        });
    } else {
        bp_fill_select_form({
            text:  { 'bp_arg1_not_more': '', 'bp_arg2_not_more': '' }
        });
    }
}

/* show node type select: at_least */
function bp_select_at_least(node) {
    if(node && (node.func.toLowerCase() == 'not_more' || node.func.toLowerCase() == 'at_least')) {
        bp_fill_select_form({
            text:  { 'bp_arg1_at_least': node.func_args[0], 'bp_arg2_at_least': node.func_args[1] }
        });
    } else {
        bp_fill_select_form({
            text:  { 'bp_arg1_at_least': '', 'bp_arg2_at_least': '' }
        });
    }
}

/* show add node dialog */
function bp_show_edit_node(id, refreshType) {
    if(refreshType == undefined) { refreshType = true; }
    hideElement('bp_menu');
    jQuery("#bp_add_new_node").dialog().dialog("close");
    if(id) {
        if(id == 'new') {
            current_edit_node         = 'new';
            current_edit_node_clicked = current_node;
        }
        if(id == 'current') {
            current_edit_node         = current_node;
            current_edit_node_clicked = current_node;
        }
    }
    jQuery('#bp_node_id').val(current_edit_node);
    // tab dialog (http://forum.jquery.com/topic/combining-ui-dialog-and-tabs)
    var $edit_dialog;
    jQuery("#edit_dialog_"+bp_id).tabs().dialog({
        autoOpen: false, modal: true,
        width: 430, height: 320,
        draggable: false, // disable the dialog's drag we're using the tabs titlebar instead
        modal: true,
        closeOnEscape: true,
        buttons: [{
              'text':   current_edit_node == 'new' ? 'Create' : 'Save',
              'click':  function() { bp_edit_node_submit('bp_edit_node_form'); },
              'class': 'bp_dialog_create_btn'
        }],
        create: function() { // turn tabs into dialogs
            // define the elements we're dealing with
            $tabs = jQuery(this).find('.ui-tabs-nav'); $dlg = jQuery(this).parent();
            $edit_dialog = $dlg;
            // clone close button from dialog title and put it in the tabs area
            $dlg.find('.ui-dialog-titlebar-close').appendTo($tabs);
            // make the tabs draggable, give it a class that gracefully adds the move cursor and remove the dialog's original titlebar completely
            $dlg.draggable({handle: ".ui-tabs-nav"})
                .addClass('ui-draggable')
                .find('.ui-dialog-titlebar').remove();
            // give dialog styles to the tabs (would like to do this without adding CSS, but couldn't)
            $dlg.find('.ui-tabs').css('padding', '0px');
            // turn off the highlighting of tabs in chrome, add titlebar style to tabs to give close button correct styling
            $tabs.addClass('ui-dialog-titlebar')
                .find('li, a').css('outline', 'none').mousedown(function(e){ e.stopPropagation(); });
        }
    })
    jQuery('.bp_type_box').button();
    jQuery("#edit_dialog_"+bp_id).dialog("open");

    // show correct type
    var node = bp_get_node(current_edit_node);
    if(node && refreshType) {
        bp_select_type(node.func.toLowerCase());
    }
    if(id && id == 'current') {
        jQuery("#edit_dialog_"+bp_id).tabs({ active: 0 });
    }

    // update object creation status
    if(node && node.func.toLowerCase() != 'status') {
        jQuery("INPUT[name=bp_host]").val(node.host);
        jQuery("INPUT[name=bp_service]").val(node.service);
        jQuery("INPUT[name=bp_service_template]").val(node.template);
    } else {
        jQuery("INPUT[name=bp_host]").val('');
        jQuery("INPUT[name=bp_service]").val('');
        jQuery("INPUT[name=bp_service_template]").val('');
    }
    var checkbox = document.getElementById('bp_create_link');
    if(checkbox) {
        if(node && node.create_obj) { checkbox.checked = node.create_obj }
        else { checkbox.checked = false; }
    }
    bp_update_obj_create();


    if(checkbox) {
        if(node && node.id == 'node1') {
            checkbox.disabled = true;
        } else {
            checkbox.disabled = false;
        }
    }

    // initialize childrens tab
    bp_initialize_children_tab(node);

    // make dragable again
    if($edit_dialog) {
        $edit_dialog.draggable({handle: ".ui-tabs-nav"}).addClass('ui-draggable');
    }
}

/* initialize childrens tab */
bp_list_wizard_initialized = {};
function bp_initialize_children_tab(node) {
    selected_nodes   = new Array();
    selected_nodes_h = new Object();
    var options = [];
    if(node) {
        node.depends.forEach(function(d) {
            var val = d;
            selected_nodes.push(val);
            selected_nodes_h[val] = 1;
            options.push(new Option(val, val));
        });
    }
    set_select_options('bp_'+bp_id+"_selected_nodes", options, true);
    reset_original_options('bp_'+bp_id+"_selected_nodes");

    var first_node = bp_get_node('node1');

    // initialize available nodes
    available_nodes   = new Array();
    available_nodes_h = new Object();
    var options = [];
    nodes.forEach(function(n) {
        var val = n.label;
        if(selected_nodes_h[val])                 { return true; } // skip already selected nodes
        if(node && val == node.label)             { return true; } // skip own node
        if(first_node && val == first_node.label) { return true; } // skip first/master node
        available_nodes.push(val);
        available_nodes_h[val] = 1;
        options.push(new Option(val, val));
        return true;
    });
    set_select_options('bp_'+bp_id+"_available_nodes", options, true);
    sortlist('bp_'+bp_id+"_available_nodes");
    reset_original_options('bp_'+bp_id+"_available_nodes");

    // button has to be initialized only once
    if(bp_list_wizard_initialized[bp_id] != undefined) {
        // reset filter
        jQuery('INPUT.filter_available').val('');
        jQuery('INPUT.filter_selected').val('');
        data_filter_select('bp_'+bp_id+'_available_nodes', '');
        data_filter_select('bp_'+bp_id+'_selected_nodes', '');
    }
    bp_list_wizard_initialized[bp_id] = true;
}

/* save node */
function bp_edit_node_submit(formId) {
    // add selected nodes
    jQuery('#'+formId).find('#bp_'+bp_id+'_selected_nodes OPTION').attr('selected',true);
    var data = jQuery('#'+formId).serializeArray();
    var id = current_edit_node_clicked ? current_edit_node_clicked : current_edit_node;
    bp_post_and_refresh('bp.cgi?action=edit_node&bp='+bp_id+'&node='+id, data, current_edit_node);
    jQuery('#edit_dialog_'+bp_id).dialog("close");
    return false;
}

/* save menu for later restore */
var original_menu;
function bp_menu_save() {
    if(!original_menu) {
        original_menu = jQuery('#bp_menu').html();
    }
}

/* set status data */
function bp_update_status(evt, node) {
    evt = (evt) ? evt : ((window.event) ? event : null);
    if(minimal) {
        return false;
    }
    if(node == null) {
        return false;
    }
    if(bp_active_node != undefined && bp_active_node != node.id) {
        return false;
    }
    var n = bp_get_node(node.id);
    if(n == null) {
        if(thruk_debug_js) { alert("ERROR: got no node in bp_update_status(): " + node.id); }
        return false;
    }

    var status = n.status;
    if(status == 0) { statusName = 'OK'; }
    if(status == 1) { statusName = 'WARNING'; }
    if(status == 2) { statusName = 'CRITICAL'; }
    if(status == 3) { statusName = 'UNKNOWN'; }
    if(status == 4) { statusName = 'PENDING'; }
    jQuery('#bp_status_status').html('<div class="statusField status'+statusName+'">  '+statusName+'  </div>');
    jQuery('#bp_status_label').html(n.label);
    jQuery('#bp_status_plugin_output').html("<span id='bp_status_plugin_output_title'>"+n.status_text+"<\/span>");
    jQuery('#bp_status_plugin_output_title').attr('title', n.status_text);
    jQuery('#bp_status_last_check').html(n.last_check);
    jQuery('#bp_status_duration').html(n.duration);
    jQuery('#bp_status_function').html(n.func + '('+n.func_args.join(', ')+')');

    if(n.scheduled_downtime_depth > 0) {
        jQuery('#bp_status_icon_downtime').css('display', '');
    } else {
        jQuery('#bp_status_icon_downtime').css('display', 'none');
    }
    if(n.acknowledged > 0) {
        jQuery('#bp_status_icon_ack').css('display', '');
    } else {
        jQuery('#bp_status_icon_ack').css('display', 'none');
    }

    jQuery('.bp_status_extinfo_link_host').css('display', 'none');
    jQuery('.bp_status_extinfo_link_service').css('display', 'none');


    var service, host;
    if(n.service) {
        service = n.service;
        host    = n.host;
    }
    else if(n.host) {
        host = n.host;
    }
    else if(n.create_obj) {
        if(n.id == 'node1') {
            host = n.label;
        } else {
            var firstnode = bp_get_node('node1');
            host    = firstnode.label;
            service = n.label;
        }
    }

    // service specific things...
    if(service) {
        jQuery('.bp_status_extinfo_link_service').css('display', '').html("<a href='extinfo.cgi?type=2&amp;host="+host+"&service="+service+"'><img src='"+url_prefix+"thruk/themes/"+theme+"/images/command.png' border='0' alt='Goto Service Details' title='Goto Service Details' width='16' height='16'><\/a>");
    }

    // host specific things...
    else if(host) {
        jQuery('.bp_status_extinfo_link_host').css('display', '').html("<a href='extinfo.cgi?type=1&amp;host="+host+"'><img src='"+url_prefix+"thruk/themes/"+theme+"/images/command.png' border='0' alt='Goto Host Details' title='Goto Host Details' width='16' height='16'><\/a>");
    }

    return false;
}

/* toggle object creation */
function bp_update_obj_create() {
    var checkbox = document.getElementById('bp_create_link');
    jQuery("INPUT.bp_create").attr('disabled', !checkbox.checked);
}

/* fired if mouse if over a node */
function bp_mouse_over_node(evt, node) {
    evt = (evt) ? evt : ((window.event) ? event : null);
    if(bp_context_menu) { return false; }
    current_node = node.id;
    bp_update_status(evt, node);
    return true;
}

/* fired if mouse leaves a node */
function bp_mouse_out_node(evt, node) {
    evt = (evt) ? evt : ((window.event) ? event : null);
}

/* return template type of current node */
function bp_get_template_type() {
    if(current_edit_node_clicked == 'node1') {
        return "host template";
    }
    return "service template";
}

/* return node object by id */
function bp_get_node(id) {
    var node;
    nodes.forEach(function(n) {
        if(n.id == id) {
            node = n;
            return false;
        }
        return true;
    });
    return node;
}

/* do the layout */
function bp_render(containerId, nodes, edges) {
    // first reset zoom
    bp_zoom('inner_'+containerId, 1);
    try {
        dagre.layout()
            //.debugLevel(4)
            .nodes(nodes)
            .edges(edges)
            .nodeSep(20)
            .rankDir("TB")
            .run();
    } catch(e) {
        jQuery('#inner_'+containerId).html('<span style="white-space: nowrap; color:red;">Please use Internet Explorer 9 or greater. Or preferable Firefox or Chrome.</span>');
        return;
    }

    nodes.forEach(function(u) {
        // move node
        jQuery('#'+u.dagre.id).css('left', (u.dagre.x-55)+'px').css('top', (u.dagre.y-15)+'px');
    });

    edges.forEach(function(e) {
        bp_plump('inner_'+containerId, e.sourceId, e.targetId, e);
    });

    bp_redraw();
}

/* zoom out */
var last_zoom = 1;
function bp_zoom_rel(containerId, zoom) {
    bp_zoom(containerId, last_zoom + zoom);
    return false;
}

function bp_zoom_reset(containerId) {
    bp_zoom(containerId, original_zoom);
    return false;
}

/* set zoom level */
function bp_zoom(containerId, zoom) {
    // round to 0.05
    zoom = Math.floor(zoom * 20) / 20;
    last_zoom = zoom;
    jQuery('#'+containerId).css('zoom', zoom)
                                 .css('-moz-transform', 'scale('+zoom+')')
                                 .css('-moz-transform-origin', '0 0');
}

/* draw connector between two nodes */
function bp_plump(containerId, sourceId, targetId, edge) {
    var upper     = document.getElementById(sourceId);
    var lower     = document.getElementById(targetId);
    var container = document.getElementById(containerId);


    var x = edge.source.x;
    var y = edge.source.y;

    var points = [[x,y]];
    edge.dagre.points.forEach(function(p) {
        if(x != p.x && y != p.y) {
            points.push([x, p.y]);
        }
        points.push([p.x, p.y]);
        x = p.x; y = p.y;
    });
    if(x != edge.target.x && y != edge.target.y) {
        points.push([x, edge.target.y]);
    }
    points.push([edge.target.x, edge.target.y]);

    var edge_id = 'edge_'+sourceId+'_'+targetId;
    jQuery(container).append('<div id="'+edge_id+'"><\/div>');
    var edge_container = jQuery('#'+edge_id);

    // non-direct layout
    if(points.length > 5) {
        // move start point outside
        if(points[0][0] < points[2][0]) {
            points[0][0] = points[0][0] + 15;
            points[1][0] = points[1][0] + 15;
        }
        //jQuery(edge_container).append('<div class="bp_vedge" style="left: '+points[0][0]+'px; top: '+points[0][1]+'px; width:1px; height: 1px; border: 3px solid blue; z-index: 100;"><\/div>');
        for(var x = 0; x < points.length -1; x++) {
            var x1 = points[x][0];
            var y1 = points[x][1];
            var x2 = points[x+1][0];
            var y2 = points[x+1][1];
            var w = x2 - x1;
            var h = y2 - y1;
            if(w < 0) {
                w = -w;
                x1 = x2;
                x1 = x1 + 1;
            } else {
                x1 = x1 - 1;
            }
            if(h < 0) { h = -h; y1 = y2; }
            if(w < 0) { w = -w; x1 = x2; }
            bp_draw_edge(edge_container, edge_id, x1, y1, w, h);
        }
    }

    else {
        // get position
        var lpos = jQuery(lower).position();
        var upos = jQuery(upper).position();

        // switch position
        if(lpos.top < upos.top) {
            var tmp = lower;
            lower = upper;
            upper = tmp;

            var tmp = lpos;
            lpos = upos;
            upos = tmp;
        }

        // draw "line" from top middle of lower node
        var x = lpos.left + lower.offsetWidth / 2;
        var y = lpos.top  - 10;
        bp_draw_edge(edge_container, edge_id, x, y, 0, 10);

        // draw vertical line
        var w = (upos.left + upper.offsetWidth / 2) - x;
        if(w < 0) {
            w = -w;
            x = x - w;
        } else {
            x = x + 2;
        }
        bp_draw_edge(edge_container, edge_id, x, y, w, 0);

        // draw horizontal line
        x = upos.left + upper.offsetWidth / 2;
        y = lpos.top  - 10;
        var h = y - (upos.top + upper.offsetHeight);
        y = y - h;
        bp_draw_edge(edge_container, edge_id, x, y, 0, h);
    }

    return;
}

function bp_draw_edge(edge_container, edge_id, x, y, w, h) {
    var style = 'left: '+x+'px; top: '+y+'px;';
    if(h == 0) { cls = 'bp_hedge'; style += ' width:'+w+'px;'; }
    if(w == 0) { cls = 'bp_vedge'; style += ' height:'+h+'px;'; }
    jQuery(edge_container).append('<div class="'+cls+'" style="'+style+'" onmouseover="bp_hover_edge(\''+edge_id+'\')" onmouseout="bp_hover_edge_out(\''+edge_id+'\')"><\/div>');
}

function bp_hover_edge(id) {
    jQuery('#'+id+' .bp_vedge').addClass('bp_vedge_hover');
    jQuery('#'+id+' .bp_hedge').addClass('bp_hedge_hover');

}
function bp_hover_edge_out(id) {
    jQuery('.bp_vedge_hover').removeClass('bp_vedge_hover');
    jQuery('.bp_hedge_hover').removeClass('bp_hedge_hover');
}

/* stop further events */
function bp_no_more_events(evt) {
    if (evt.stopPropagation) {
        evt.stopPropagation();
    }
    if(evt.preventDefault != undefined) {
        evt.preventDefault();
    }
    evt.cancelBubble = true;
    return false;
}

/* redraw nodes and stuff */
function bp_redraw(evt) {
    var containerId;
    try {
        containerId = 'container'+bp_id;
    } catch(e) { return false; }

    var maxX = 0, maxY = 0, minY = -1, main_node;
    nodes.forEach(function(u) {
        if(!u.dagre) { return false }
        if(maxX < u.dagre.x) { maxX = u.dagre.x }
        if(maxY < u.dagre.y) { maxY = u.dagre.y }
        if(minY == -1 || u.dagre.y < minY) { minY = u.dagre.y; main_node = u; }
        return true;
    });
    maxX = maxX + 80;
    maxY = maxY + 30;

    // adjust size of container
    var container = document.getElementById(containerId);
    var w = jQuery(window).width() - container.parentNode.offsetLeft - 5;
    var h = jQuery(window).height() - container.parentNode.offsetTop -10;
    if(!minimal) {
        w = w - 315;
    }
    container.style.width  = w+'px';
    container.style.height = h+'px';

    // do we need to zoom in?
    var zoomX = 1, zoomY = 1;
    if(w < maxX) {
        zoomX = w / maxX;
    }
    if(h < maxY) {
        zoomY = h / maxY;
    }
    var zoom = zoomY;
    if(zoomX < zoomY) { zoom = zoomX; }
    if(zoom < 1) {
        bp_zoom('inner_'+containerId, zoom);
    }
    original_zoom = zoom;

    if(!current_node && main_node) {
        bp_update_status(null, main_node);
        current_node = main_node.id;
    }

    // center align inner container
    var inner = document.getElementById('inner_'+containerId);
    var offset = (w - maxX) / 2;
    if(offset < 0) {offset = 0;}
    inner.style.left = offset+'px';

    return true;
}