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
    return;
}

/* refresh given business process */
var current_node;
function bp_refresh(bp_id) {
    bp_active_node = current_node;
    showElement('bp_status_waiting');
    /* adding timestamp makes IE happy */
    var ts = new Date().getTime();
    jQuery('#bp'+bp_id).load('bp.cgi?_=' + ts + '&action=refresh&bp='+bp_id, [], function() {
        hideElement('bp_status_waiting');
        var node = document.getElementById(current_node);
        bp_update_status(null, node);
        jQuery(node).addClass('bp_node_active');
    });
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
    if(rightclick && node) {
        bp_context_menu = true;
        bp_unset_active_node();
        jQuery(node).addClass('bp_node_active');
        jQuery("#bp_menu").menu().css('top', evt.pageY+'px').css('left', evt.pageX+'px');
        showElement('bp_menu', undefined, true, undefined, bp_context_menu_close_cb);
        bp_active_node = node.id;
        bp_update_status(evt, node);
    } else if(node) {
        bp_unset_active_node();
        jQuery(node).addClass('bp_node_active');
        bp_active_node = node.id;
        bp_update_status(evt, node);
    } else if(evt.target && jQuery(evt.target).hasClass('bp_container')) {
        bp_unset_active_node();
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
    return true;
}

/* set status data */
function bp_update_status(evt, node) {
    evt = (evt) ? evt : ((window.event) ? event : null);
    if(bp_active_node != undefined && bp_active_node != node.id) {
        return false;
    }

    nodes.forEach(function(n) {
        if(node.id == n.id) {
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
            return false;
        }
        return true;
    });
    return false;
}

/* do the layout */
function bp_render(containerId, nodes, edges) {
    dagre.layout()
        //.debugLevel(4)
        .nodes(nodes)
        .edges(edges)
        .nodeSep(20)
        .rankDir("TB")
        .run();

    var maxX = 0, maxY = 0;
    nodes.forEach(function(u) {
        // move node
        jQuery('#'+u.dagre.id).css('left', (u.dagre.x-55)+'px').css('top', (u.dagre.y-15)+'px');
        if(maxX < u.dagre.x) { maxX = u.dagre.x }
        if(maxY < u.dagre.y) { maxY = u.dagre.y }
    });
    maxX = maxX + 80;
    maxY = maxY + 30;

    edges.forEach(function(e) {
        bp_plump('inner_'+containerId, e.sourceId, e.targetId);
    });

    // adjust size of container
    var container = document.getElementById(containerId);
    var w = jQuery(window).width() - container.parentNode.offsetLeft - 320;
    var h = jQuery(window).height() - container.parentNode.offsetTop -  10;
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

    return;
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
    zoom = Math.round(zoom * 20) / 20;
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
