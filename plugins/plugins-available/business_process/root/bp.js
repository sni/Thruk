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
    return;
}

/* do the layout */
function bp_render(containerId, nodes, edges) {
    dagre.layout()
        //.debugLevel(4)
        .nodes(nodes)
        .edges(edges)
        .nodeSep(30)
        .rankDir("TB")
        .run();

    nodes.forEach(function(u) {
        // move node
        jQuery('#'+u.dagre.id).css('left', u.dagre.x+'px').css('top', u.dagre.y+'px');
    });

    edges.forEach(function(e) {
        bp_plump(containerId, e.sourceId, e.targetId);
    });

    return;
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
