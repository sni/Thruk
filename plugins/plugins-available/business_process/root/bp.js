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
function bp_refresh(bp_id, node_id, callback) {
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
    jQuery('#bp'+bp_id).load('bp.cgi?_=' + ts + '&action=refresh&bp='+bp_id, [], function(responseText, textStatus, XMLHttpRequest) {
        is_refreshing = false;
        if(!minimal) {
            hideElement('bp_status_waiting');
        }
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
        if(callback) { callback(textStatus == 'success' ? true : false); }
    });
}

/* refresh business process in background */
function bp_refresh_bg(cb) {
    bp_refresh(bp_id, 'changed_only', cb);
}

/* unset active node */
function bp_unset_active_node() {
    jQuery('.bp_node_active').removeClass('bp_node_active');
    bp_active_node = undefined;
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
        // first node cannot be removed
        if(node.id == 'node1') {
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
    if(evt.target.tagName == "INPUT") {
        return true;
    }

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
    // don't interrupt user interactions by automatic reload
    resetRefresh();
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
    jQuery.post('bp.cgi?action=rename_node&bp='+bp_id+'&node='+node.id+'&label='+text, [], function() {
        bp_refresh(bp_id, node.id);
    });
    hideElement('bp_menu');
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
    jQuery.post('bp.cgi?action=remove_node&bp='+bp_id+'&node='+node.id, [], function() {
        bp_refresh(bp_id);
    });
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
function bp_show_add_node(id) {
    hideElement('bp_menu');
    if(id) {
        current_edit_node_clicked = id;
        if(id == 'new') {
            current_edit_node_clicked = current_node;
        }
        current_edit_node = id;
    }
    var title = 'Change Node';
    if(current_edit_node == 'new') {
        title = 'Create New Node';
    }
    jQuery("#bp_edit_node").dialog({
        modal: true,
        closeOnEscape: true,
        width: 365,
        title: title
    });
    jQuery('.bp_type_btn').button();
    showElement('bp_edit_node');
    jQuery('INPUT.bp_node_id').val(id);
}

/* show node type select for existing nodes */
function bp_show_edit_node() {
    bp_show_add_node(current_node);
}

function bp_fill_select_form(data) {
    if(data.radio) {
        for(var key in data.radio) {
            var d = data.radio[key];
            jQuery('#'+data.form).find('INPUT[name='+key+']').removeAttr("checked");
            jQuery('#'+data.form).find('INPUT[name='+key+'][value="'+d[0]+'"]').attr("checked","checked");
            jQuery(d[1]).buttonset();
        }
    }
    if(data.text) {
        for(var key in data.text) {
            var d = data.text[key];
            jQuery('#'+data.form).find('INPUT[name='+key+']').val(d);
        }
    }
    if(data.label != undefined) {
        jQuery('#'+data.form).find('INPUT[name=bp_label]').val(data.label);
    }
}

/* show node type select: fixed */
function bp_select_fixed() {
    bp_show_dialog('bp_select_fixed', 430, 220);
    jQuery('.bp_fixed_radio').buttonset();
    // insert current values
    var node = bp_get_node(current_edit_node);
    if(node && node.func.toLowerCase() == 'fixed') {
        bp_fill_select_form({
            form:  'bp_select_fixed_form',
            label: node.label,
            radio: { 'bp_arg1': [ node.func_args[0].toUpperCase(), '.bp_fixed_radio'] },
            text:  { 'bp_arg2': node.func_args[1] }
        });
    } else {
        bp_fill_select_form({
            form:  'bp_select_fixed_form',
            label: '',
            radio: { 'bp_arg1': [ 'OK', '.bp_fixed_radio'] },
            text:  { 'bp_arg2': '' }
        });
    }
}

/* show node type select: best */
function bp_select_best() {
    bp_show_dialog('bp_select_best', 430, 150);
    // insert current values
    var node = bp_get_node(current_edit_node);
    if(node && (node.func.toLowerCase() == 'worst' || node.func.toLowerCase() == 'best')) {
        bp_fill_select_form({
            form:  'bp_select_best_form',
            label: node.label
        });
    } else {
        bp_fill_select_form({
            form:  'bp_select_best_form',
            label: ''
        });
    }
}

/* show node type select: worst */
function bp_select_worst() {
    bp_show_dialog('bp_select_worst', 430, 150);
    // insert current values
    var node = bp_get_node(current_edit_node);
    if(node && (node.func.toLowerCase() == 'worst' || node.func.toLowerCase() == 'best')) {
        bp_fill_select_form({
            form:  'bp_select_worst_form',
            label: node.label
        });
    } else {
        bp_fill_select_form({
            form:  'bp_select_worst_form',
            label: ''
        });
    }
}

/* show node type select: equals */
function bp_select_exactly() {
    bp_show_dialog('bp_select_exactly', 430, 180);
    // insert current values
    var node = bp_get_node(current_edit_node);
    if(node && node.func.toLowerCase() == 'equals') {
        bp_fill_select_form({
            form:  'bp_select_exactly_form',
            label: node.label,
            text:  { 'bp_arg1': node.func_args[0] }
        });
    } else {
        bp_fill_select_form({
            form:  'bp_select_exactly_form',
            label: '',
            text:  { 'bp_arg1': '' }
        });
    }
}

/* show node type select: not_more */
function bp_select_not_more() {
    bp_show_dialog('bp_select_not_more', 430, 210);
    // insert current values
    var node = bp_get_node(current_edit_node);
    if(node && (node.func.toLowerCase() == 'not_more' || node.func.toLowerCase() == 'at_least')) {
        bp_fill_select_form({
            form:  'bp_select_not_more_form',
            label: node.label,
            text:  { 'bp_arg1': node.func_args[0], 'bp_arg2': node.func_args[1] }
        });
    } else {
        bp_fill_select_form({
            form:  'bp_select_not_more_form',
            label: '',
            text:  { 'bp_arg1': '', 'bp_arg2': '' }
        });
    }
}

/* show node type select: at_least */
function bp_select_at_least() {
    bp_show_dialog('bp_select_at_least', 430, 210);
    // insert current values
    var node = bp_get_node(current_edit_node);
    if(node && (node.func.toLowerCase() == 'not_more' || node.func.toLowerCase() == 'at_least')) {
        bp_fill_select_form({
            form:  'bp_select_at_least_form',
            label: node.label,
            text:  { 'bp_arg1': node.func_args[0], 'bp_arg2': node.func_args[1] }
        });
    } else {
        bp_fill_select_form({
            form:  'bp_select_at_least_form',
            label: '',
            text:  { 'bp_arg1': '', 'bp_arg2': '' }
        });
    }
}

/* show add node dialog */
function bp_show_dialog(id, w, h) {
    jQuery("#bp_edit_node").dialog("close");
    jQuery("#"+id).dialog({
        modal: true,
        closeOnEscape: true,
        width: w,
        height: h,
        buttons: [
            { text: 'Back',
              click: function() { jQuery(this).dialog("close"); bp_show_add_node(); },
              icons: { primary: "ui-icon-arrowthick-1-w" },
              'class': 'bp_dialog_back_btn'
            },
            { text: 'Create',
              click: function() { bp_edit_node_submit(id+'_form'); jQuery(this).dialog("close"); },
              'class': 'bp_dialog_create_btn'
            }
        ]
    });
}

/* save node */
function bp_edit_node_submit(formId) {
    var data = jQuery('#'+formId).serializeArray();
    var id = current_edit_node_clicked ? current_edit_node_clicked : current_edit_node;
    jQuery.post('bp.cgi?action=edit_node&bp='+bp_id+'&node='+id, data, function() {
        bp_refresh(bp_id);
    });
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
        return;
    }

    var status = n.status;
    if(status == 0) { statusName = 'OK'; }
    if(status == 1) { statusName = 'WARNING'; }
    if(status == 2) { statusName = 'CRITICAL'; }
    if(status == 3) { statusName = 'UNKNOWN'; }
    if(status == 4) { statusName = 'PENDING'; }
    jQuery('#bp_status_status').html('<div class="statusField status'+statusName+'">  '+statusName+'  </div>');
    jQuery('#bp_status_label').html(n.label);
    jQuery('#bp_status_plugin_output').html(n.status_text);
    jQuery('#bp_status_last_check').html(n.last_check);
    jQuery('#bp_status_duration').html(n.duration);
    jQuery('#bp_status_function').html(n.func + '('+n.func_args.join(', ')+')');

    if(n.scheduled_downtime_depth > 0) {
        jQuery('#bp_status_icon_downtime').css('display', 'inherit');
    } else {
        jQuery('#bp_status_icon_downtime').css('display', 'none');
    }
    if(n.acknowledged > 0) {
        jQuery('#bp_status_icon_ack').css('display', 'inherit');
    } else {
        jQuery('#bp_status_icon_ack').css('display', 'none');
    }

    jQuery('.bp_info_host').css('display', 'none');
    jQuery('.bp_info_service').css('display', 'none');

    // service specific things...
    if(node.service != '') {
        jQuery('.bp_info_service').css('display', 'inherit');
    }

    // host specific things...
    else if(node.host != '') {
        jQuery('.bp_info_host').css('display', 'inherit');
    }

    return false;
}

/* fired if mouse if over a node */
function bp_mouse_over_node(evt, node) {
    evt = (evt) ? evt : ((window.event) ? event : null);
    current_node = node.id;
    bp_update_status(evt, node);
}

/* fired if mouse leaves a node */
function bp_mouse_out_node(evt, node) {
    evt = (evt) ? evt : ((window.event) ? event : null);
}


/* return node object by id */
function bp_get_node(id) {
    var node;
    nodes.forEach(function(n) {
        if(n.id == id) {
            node = n;
            return false;
        }
    });
    return node;
}

/* do the layout */
function bp_render(containerId, nodes, edges) {
    // first reset zoom
    bp_zoom('inner_'+containerId, 1);
    dagre.layout()
        //.debugLevel(4)
        .nodes(nodes)
        .edges(edges)
        .nodeSep(20)
        .rankDir("TB")
        .run();

    nodes.forEach(function(u) {
        // move node
        jQuery('#'+u.dagre.id).css('left', (u.dagre.x-55)+'px').css('top', (u.dagre.y-15)+'px');
    });

    edges.forEach(function(e) {
        bp_plump('inner_'+containerId, e.sourceId, e.targetId);
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
function bp_plump(containerId, sourceId, targetId) {
    var upper     = document.getElementById(sourceId);
    var lower     = document.getElementById(targetId);
    var container = document.getElementById(containerId);

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
    jQuery(container).append('<div class="bp_vedge" style="left: '+x+'px; top: '+y+'px; width:1px; height: 10px;"><\/div>');

    // draw vertical line
    var w = (upos.left + upper.offsetWidth / 2) - x;
    if(w < 0) {
        w = -w;
        x = x - w;
    } else {
        x = x + 2;
    }
    jQuery(container).append('<div class="bp_hedge" style="left: '+x+'px; top: '+y+'px; width:'+w+'px; height: 1px;"><\/div>');

    // draw horizontal line
    x = upos.left + upper.offsetWidth / 2;
    y = lpos.top  - 10;
    var h = y - (upos.top + upper.offsetHeight);
    y = y - h;
    jQuery(container).append('<div class="bp_vedge" style="left: '+x+'px; top: '+y+'px; width:1px; height: '+h+'px;"><\/div>');

    return;
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
    containerId = 'container'+bp_id;

    var maxX = 0, maxY = 0, minY = -1, main_node;
    nodes.forEach(function(u) {
        if(maxX < u.dagre.x) { maxX = u.dagre.x }
        if(maxY < u.dagre.y) { maxY = u.dagre.y }
        if(minY == -1 || u.dagre.y < minY) { minY = u.dagre.y; main_node = u; }
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

    if(!current_node) {
        bp_update_status(null, main_node);
        current_node = main_node.id;
    }

    // center align inner container
    var inner = document.getElementById('inner_'+containerId);
    var offset = (w - maxX) / 2;
    if(offset < 0) {offset = 0;}
    inner.style.left = offset+'px';

    return;
}