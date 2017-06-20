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

    if(bp_no_menu != 1) {
        document.onmousedown   = bp_context_menu_open;
        document.oncontextmenu = bp_context_menu_open;
    }
    window.onresize        = bp_redraw;

    // initialize graph options in edit mode
    if(editmode) {
        bp_fill_select_form({
            select:  {
                'bp_rankDir': bp_graph_options.bp_rankDir
            },
            text:  {
                'bp_edgeSep': bp_graph_options.bp_edgeSep,
                'bp_rankSep': bp_graph_options.bp_rankSep,
                'bp_nodeSep': bp_graph_options.bp_nodeSep
            }
        },'bp_graph_option_form');
    }

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
    var url = 'bp.cgi?_='+ts+'&action=refresh&edit='+editmode+'&bp='+bp_id+'&update='+(refresh_only ? 0 : 1)+"&testmode="+testmode+"&no_menu="+bp_no_menu;
    jQuery('#bp'+bp_id).load(url, testmodes, function(responseText, textStatus, XMLHttpRequest) {
        is_refreshing = false;
        if(!minimal) {
            hideElement('bp_status_waiting');
        }
        if(textStatus == "success") {
            bp_render('container'+bp_id, nodes, edges);
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

/* set test mode for this node */
function bp_test_mode_node(state) {
    testmode = true;
    if(state == -1) {
        delete testmodes[current_node];
    } else {
        testmodes[current_node] = state;
    }
    hideElement('bp_menu');
    bp_context_menu = false;
    bp_refresh(bp_id, 'changed_only', bp_unset_active_node, true);
    return false;
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
    evt = jQuery.event.fix(evt);

    var rightclick;
    if (evt.which) rightclick = (evt.which == 3);   // IE < 9 does not support e.which
    else if (evt.button) rightclick = (evt.button == 2);

    // clicking the wrench icon counts as right click too
    if(evt.target && jQuery(evt.target).hasClass('ui-icon-wrench')) { rightclick = true; }
    if(rightclick && node) {
        bp_unset_active_node();
        bp_context_menu = true;
        jQuery(node).addClass('bp_node_active');
        bp_active_node = node.id;
        bp_update_status(evt, node);
        jQuery('LI.bp_submenu UL').css('display', 'none'); // hide sub menu
        jQuery("#bp_menu").menu()
                          .css('top', evt.pageY+'px')
                          .css('left', evt.pageX+'px')
                          .menu("collapseAll", null, true)    // close sub menus
                          .unbind('keydown');                 // use cursor keys in input field
        bp_menu_restore();
        // make sure menu does not overlap window
        var h = jQuery(window).height() - jQuery("#bp_menu").height() - 10;
        if(h < evt.pageY) {
            jQuery("#bp_menu").css('top', h+'px');
        }
        bp_update_firstnode_css();
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
    bp_context_menu = false;
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
    if(node) {
        jQuery('#bp_menu_remove_node').html(
             'Confirm: <input type="button" value="No" style="width: 50px;" onclick="bp_menu_restore()">'
            +'<input type="button" value="Yes" style="width: 40px;" onclick="bp_confirmed_remove('+node.id+')">'
        );
    }
    return false;
}

/* send remoev request */
function bp_confirmed_remove(node) {
    bp_post_and_refresh('bp.cgi?action=remove_node&bp='+bp_id+'&node='+node.id, []);
    hideElement('bp_menu');
    bp_context_menu = false;
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
        width: 450
    });
    jQuery('.bp_type_btn').button();
    showElement('bp_add_new_node');
}

/* fill in form with current values */
function bp_fill_select_form(data, form) {
    if(!form) {
        form = 'bp_edit_node_form';
    }
    if(data.radio) {
        for(var key in data.radio) {
            var d = data.radio[key];
            jQuery('#'+form).find('INPUT[type=radio][name='+key+']').removeAttr("checked");
            jQuery('#'+form).find('INPUT[type=radio][name='+key+'][value="'+d[0]+'"]').prop("checked","checked");
            jQuery(d[1]).buttonset();
        }
    }
    if(data.text) {
        for(var key in data.text) {
            var d = data.text[key];
            jQuery('#'+form).find('INPUT[name='+key+']').val(d);
        }
    }
    if(data.select) {
        for(var key in data.select) {
            var d = data.select[key];
            jQuery('#'+form).find('SELECT[name='+key+'] option[text="'+d+'"]').attr("selected","selected");
            jQuery('#'+form).find('SELECT[name='+key+'] option[value="'+d+'"]').attr("selected","selected");
        }
    }
}

/* change graph options */
function bp_redraw_changed(name, value) {
    bp_graph_options[name] = value;
    bp_render('container'+bp_id, nodes, edges);
}

/* change input by arrow keys */
function bp_input_keys(evt, input) {
    evt = (evt) ? evt : ((window.event) ? event : null);
    var keyCode      = evt.keyCode;
    var value = Math.ceil(input.value);
    if(keyCode == 38)   { value++; }
    if(keyCode == 40) { value--; }
    input.value = value;
    return false;
}

/* generic node type selection */
function bp_select_type(type) {
    bp_show_edit_node(undefined, false);
    jQuery('.bp_type_box').prop('checked', false).button("refresh");
    jQuery('#bp_check_'+type).prop('checked', true).button("refresh");
    jQuery.each(['status', 'groupstatus', 'fixed', 'at_least', 'not_more', 'equals', 'best', 'worst', 'custom'], function(nr, s) {
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
    if     (type == 'status')      { bp_select_status(node)      }
    else if(type == 'groupstatus') { bp_select_groupstatus(node) }
    else if(type == 'fixed')       { bp_select_fixed(node)       }
    else if(type == 'at_least')    { bp_select_at_least(node)    }
    else if(type == 'not_more')    { bp_select_not_more(node)    }
    else if(type == 'best')        { bp_select_best(node)        }
    else if(type == 'worst')       { bp_select_worst(node)       }
    else if(type == 'equals')      { bp_select_equals(node)      }
    else if(type == 'custom')      { bp_select_custom(node)      }
    jQuery('#bp_function').val(type);
    bp_update_status_function();
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

/* show node type select: groupstatus */
function bp_select_groupstatus(node) {
    if(node && node.func.toLowerCase() == 'groupstatus') {
        bp_fill_select_form({
            radio: { 'bp_arg1_groupstatus': [ node.func_args[0].toLowerCase(), '.bp_groupstatus_radio'] },
            text:  { 'bp_arg2_groupstatus': node.func_args[1],
                     'bp_arg3_groupstatus': node.func_args[2],
                     'bp_arg4_groupstatus': node.func_args[3],
                     'bp_arg5_groupstatus': node.func_args[4],
                     'bp_arg6_groupstatus': node.func_args[5]
                   }
        });
    } else {
        bp_fill_select_form({
            radio: { 'bp_arg1_groupstatus': [ 'hostgroup', '.bp_groupstatus_radio'] },
            text:  { 'bp_arg2_groupstatus': '',
                     'bp_arg3_groupstatus': '',
                     'bp_arg4_groupstatus': '',
                     'bp_arg5_groupstatus': '',
                     'bp_arg6_groupstatus': ''
                   }
        });
    }
    bp_groupstatus_check_changed();
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

/* show node type select: custom */
function bp_select_custom(node) {

    if(node == undefined) {
        node = bp_get_node(current_edit_node);
    }

    // function select field
    var options = [];
    jQuery(cust_func).each(function(nr, f) {
        options.push(new Option(f['function'], f['function']));
    });
    set_select_options("bp_arg1_custom", options, true);

    if(node && node.func.toLowerCase() == 'custom') {
        bp_fill_select_form({
            select:  { 'bp_arg1_custom': node.func_args[0] }
        });
    } else {
        bp_fill_select_form({
            select:  { 'bp_arg1_custom': '' }
        });
    }

    // update help text and attributes
    bp_update_cust_attributes(document.getElementById('bp_arg1_custom'), node);
}

/* update custom function help text */
function bp_update_cust_attributes(select, node) {
    var selected = jQuery(select).val();
    var func;
    jQuery(cust_func).each(function(nr, f) {
        if(f['function'] == selected) {
            func = f;
        }
    });

    // remove old attributes and help
    jQuery('#bp_select_custom > tbody > tr').each(function(nr, row) {
        if(nr >= 3) {
            jQuery(row).remove();
        }
    });

    if(func == undefined) { return; }

    // add new attributes
    jQuery(func['args']).each(function(x, arg) {
        var nr = x + 2;
        var field;
        var val = '';
        if(node && node.func_args) {
            val = node['func_args'][x+1];
        }
        if(arg['type'] == 'text') {
            field = '<input type="text" value="" name="bp_arg'+nr+'_custom" placeholder="'+arg['args']+'"><\/td><\/tr>';
        }
        else if(arg['type'] == 'select') {
            field = '<select name="bp_arg'+nr+'_custom">';
            jQuery(arg['args']).each(function(x, option) {
                field += "<option value='"+option+"'>"+option+"<\/option>";
            });
            field += '<\/select>';
        }
        else if(arg['type'] == 'checkbox') {
            field = '<div id="bp_radio_'+nr+'">';
            jQuery(arg['args']).each(function(y, option) {
                field += '<input type="radio" value="'+option+'" id="bp_custom_'+nr+'_'+y+'" name="bp_arg'+nr+'_custom" /><label for="bp_custom_'+nr+'_'+y+'">'+option+'</label>';
            });
            field += "<\/div>";
        }
        jQuery('#bp_select_custom tr:last').after('<tr><th align="right" valign="top">'+arg['name']+'</th><td align="left">'+field+'<\/td><\/tr>');

        // make buttonset nicer
        if(arg['type'] == 'checkbox') {
            jQuery('#bp_radio_'+nr).buttonset();
        }

        var value = {};
        value['bp_arg'+nr+'_custom'] = val;
        if(arg['type'] == 'text') {
            bp_fill_select_form({ text: value });
        }
        else if(arg['type'] == 'select') {
            bp_fill_select_form({ select: value });
        }
        else if(arg['type'] == 'checkbox') {
            value['bp_arg'+nr+'_custom'] = [val, '#bp_radio_'+nr];
            bp_fill_select_form({ radio: value });
        }
    });

    // add help row
    jQuery('#bp_select_custom tr:last').after('<tr><th align="right" valign="top">Help</th><td align="left" class="bp_type_desc" id="cust_help"><pre>'+func['help']+'<\/pre><\/td><\/tr>');
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

/* return type from group status radio buttons */
function bp_get_type_from_groupstatus() {
    return(jQuery("input[name='bp_arg1_groupstatus']:checked").val());
}

/* host thresholds are only available for hostgroups */
function bp_groupstatus_check_changed() {
    var val = bp_get_type_from_groupstatus();
    if(val == 'servicegroup') {
        jQuery('#bp_arg3_groupstatus').attr('disabled', true);
        jQuery('#bp_arg4_groupstatus').attr('disabled', true);
    } else {
        jQuery('#bp_arg3_groupstatus').attr('disabled', false);
        jQuery('#bp_arg4_groupstatus').attr('disabled', false);
    }
    jQuery('#bp_arg2_groupstatus').attr('placeholder', val);
}
/* show add node dialog */
var $edit_dialog;
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
    jQuery("#edit_dialog_"+bp_id).tabs().dialog({
        autoOpen: false, modal: true,
        width: 470, height: 350,
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
    jQuery("INPUT[name=bp_host_template]").val(bp_template);
    if(node && node.func.toLowerCase() != 'status') {
        jQuery("INPUT[name=bp_host]").val(node.host);
        jQuery("INPUT[name=bp_service]").val(node.service);
        jQuery("INPUT[name=bp_template]").val(node.template);
        jQuery("INPUT[name=bp_contactgroups]").val(node.contactgroups.join(", "));
        jQuery("INPUT[name=bp_contacts]").val(node.contacts.join(", "));
        jQuery("INPUT[name=bp_notification_period]").val(node.notification_period);

        if(node.contactgroups.length == 0) {
            jQuery("INPUT[name=bp_contactgroups]").parents("TR").hide();
        } else {
            jQuery("INPUT[name=bp_contactgroups]").parents("TR").show();
        }
        if(node.contacts.length == 0) {
            jQuery("INPUT[name=bp_contacts]").parents("TR").hide();
        } else {
            jQuery("INPUT[name=bp_contacts]").parents("TR").show();
        }
        if(!node.event_handler) {
            jQuery("INPUT[name=bp_event_handler]").parents("TR").hide();
        } else {
            jQuery("INPUT[name=bp_event_handler]").parents("TR").show();
        }
        if(!node.notification_period) {
            jQuery("INPUT[name=bp_notification_period]").parents("TR").hide();
        } else {
            jQuery("INPUT[name=bp_notification_period]").parents("TR").show();
        }
    } else {
        jQuery("INPUT[name=bp_host]").val('');
        jQuery("INPUT[name=bp_service]").val('');
        jQuery("INPUT[name=bp_template]").val('');
        bpRemoveAttribute('contactgroups');
        bpRemoveAttribute('contacts');
        bpRemoveAttribute('notification_period');
        bpRemoveAttribute('event_handler');
    }
    var checkbox = document.getElementById('bp_create_link');
    if(checkbox) {
        if(node && node.create_obj) { checkbox.checked = node.create_obj }
        else { checkbox.checked = false; }

        if(!node || node.create_obj_ok) {
            jQuery(".create_obj_nok").css('display', 'none');
        } else {
            jQuery(".create_obj_nok").css('display', '');
            checkbox.checked  = false;
        }
    }
    bp_update_obj_create();

    if(checkbox) {
        if(node && node.id == 'node1') {
            checkbox.disabled = true;
        } else {
            if(!node || node.create_obj_ok) {
                checkbox.disabled = false;
            } else {
                checkbox.disabled = true;
            }
        }
    }

    // initialize tabs
    bp_initialize_children_tab(node);
    bp_initialize_filter_tab(node);

    // make dragable again
    if($edit_dialog) {
        $edit_dialog.draggable({handle: ".ui-tabs-nav"}).addClass('ui-draggable');
    }
}

function bpRemoveAttribute(attr) {
    jQuery("INPUT[name=bp_"+attr+"]").parents("TR").hide();
    jQuery("INPUT[name=bp_"+attr+"]").val('');
}

function bpAddAttribute(attr) {
    jQuery("INPUT[name=bp_"+attr+"]").parents("TR").show();
    jQuery("INPUT[name=bp_"+attr+"]").val('');
}

/* initialize filter tab */
function bp_initialize_filter_tab(node) {
    jQuery("INPUT.node_filter").prop("checked", false);
    jQuery("INPUT.node_filter[value=off]").prop("checked", true);
    if(node) {
        jQuery(node.filter).each(function(nr, f) {
            // enable and move to top
            jQuery("TABLE.bp_filter tbody").prepend(jQuery("INPUT.node_filter[value=on][name=bp_filter_"+f+"]").prop("checked", true).closest('tr'));
        });
    }
    jQuery(bp_filter).each(function(nr, f) {
        // enable and move to top
        jQuery("TABLE.bp_filter tbody").prepend(jQuery("INPUT.node_filter[value=global][name=bp_filter_"+f+"]").prop("checked", true).closest('tr'));
    });
}

/* initialize childrens tab */
bp_list_wizard_initialized = {};
function bp_initialize_children_tab(node) {
    selected_nodes   = new Array();
    selected_nodes_h = new Object();
    var options = [];
    if(node) {
        node.depends.forEach(function(d) {
            var val = d[0];
            selected_nodes.push(val);
            selected_nodes_h[val] = 1;
            options.push(new Option(d[1], val));
        });
    }
    set_select_options('bp_'+bp_id+"_selected_nodes", options, false);
    reset_original_options('bp_'+bp_id+"_selected_nodes");

    var first_node = bp_get_node('node1');

    // initialize available nodes
    available_nodes   = new Array();
    available_nodes_h = new Object();
    var options = [];
    nodes.forEach(function(n) {
        var val = n.id;
        if(selected_nodes_h[val])        { return true; } // skip already selected nodes
        if(node && val == node.id)       { return true; } // skip own node
        if(first_node && val == 'node1') { return true; } // skip first/master node
        available_nodes.push(val);
        available_nodes_h[val] = 1;
        options.push(new Option(n.label, val));
        return true;
    });
    set_select_options('bp_'+bp_id+"_available_nodes", options, false);
    reset_original_options('bp_'+bp_id+"_available_nodes");
    sortlist('bp_'+bp_id+"_available_nodes");

    // button has to be initialized only once
    if(bp_list_wizard_initialized[bp_id] != undefined) {
        // reset filter
        jQuery('INPUT.node_filter_available').val('');
        jQuery('INPUT.node_filter_selected').val('');
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

    var n = bp_get_node(node);
    if(n == null) {
        if(thruk_debug_js) { alert("ERROR: got no node in bp_update_status(): " + node+', called from: '+bp_update_status.caller); }
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

    var status_text = n.status_text.replace(/\|.*$/, '');
    jQuery('#bp_status_plugin_output').html("<span id='bp_status_plugin_output_title'>"+status_text+"<\/span>");
    jQuery('#bp_status_plugin_output_title').attr('title', status_text);

    jQuery('#bp_status_last_check').html(n.last_check);
    jQuery('#bp_status_duration').html(n.duration);

    var funct = n.func + '(';
    for(var nr=0; nr<n.func_args.length; nr++) {
        var a = ""+n.func_args[nr];
        if(!a.match(/^(\d+|\d+\.\d+)$/)) { a = "'"+a+"'"; }
        funct += a + ', ';
    }
    funct = funct.replace(/,\s*$/, ''); // remove last ,
    while(funct.match(/, ''$/)) { funct = funct.replace(/, ''$/, ''); } // remove trailing empty args
    funct += ')';
    jQuery('#bp_status_function').html(funct);

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
            host    = n.label;
            service = n.label;
        } else {
            var firstnode = bp_get_node('node1');
            host    = firstnode.label;
            service = n.label;
        }
    }

    // service specific things...
    var link;
    if(service) {
        if(looks_like_regex(service)) {
            var filter = service.replace(/^(w|b):/, '');
            link = "<a href='status.cgi?style=detail&dfl_s0_type=host&dfl_s0_op=%3D&dfl_s0_value="+host+"&dfl_s0_type=service&dfl_s0_op=%7E&dfl_s0_value="+filter+"&backend="+bp_backend+"'><img src='"+url_prefix+"themes/"+theme+"/images/command.png' border='0' alt='Goto Service Details' title='Goto Service Details' width='16' height='16'><\/a>";
        } else {
            link = "<a href='extinfo.cgi?type=2&amp;host="+host+"&service="+service+"&backend="+bp_backend+"'><img src='"+url_prefix+"themes/"+theme+"/images/command.png' border='0' alt='Goto Service Details' title='Goto Service Details' width='16' height='16'><\/a>";
        }
    }

    // host specific things...
    else if(host) {
        link = "<a href='extinfo.cgi?type=1&amp;host="+host+"&backend="+bp_backend+"'><img src='"+url_prefix+"themes/"+theme+"/images/command.png' border='0' alt='Goto Host Details' title='Goto Host Details' width='16' height='16'><\/a>";
    }
    // hostgroup link
    else if(n.hostgroup) {
        link = "<a href='status.cgi?style=detail&hostgroup="+n.hostgroup+"'><img src='"+url_prefix+"themes/"+theme+"/images/command.png' border='0' alt='Goto Hostgroup Details' title='Goto Hostgroup Details' width='16' height='16'><\/a>";
    }

    // servicegroup link
    else if(n.servicegroup) {
        link = "<a href='status.cgi?style=detail&servicegroup="+n.servicegroup+"'><img src='"+url_prefix+"themes/"+theme+"/images/command.png' border='0' alt='Goto Servicegroup Details' title='Goto Servicegroup Details' width='16' height='16'><\/a>";
    }

    jQuery('.bp_status_extinfo_link').css('display', 'none');
    if(link) {
        jQuery('.bp_status_extinfo_link').css('display', '').html(link);
    }

    jQuery('.bp_ref_link').css('display', 'none');
    jQuery("#"+n.id+" .bp_node_bp_ref_icon").css('visibility', 'hidden');
    if(n.bp_ref) {
        jQuery("#"+n.id+" .bp_node_bp_ref_icon").attr("href", "bp.cgi?action=details&bp="+n.bp_ref).css('visibility', '');
        jQuery('.bp_ref_link').css('display', '').html("<a href='bp.cgi?action=details&amp;bp="+n.bp_ref+"'><img src='"+url_prefix+"themes/"+theme+"/images/chart_organisation.png' border='0' alt='Show Business Process' title='Show Business Process' width='16' height='16'><\/a>");
    }

    return false;
}

/* toggle object creation */
function bp_update_obj_create() {
    var checkbox = document.getElementById('bp_create_link');
    if(checkbox) {
        jQuery("INPUT.bp_create").prop('disabled', !checkbox.checked);
    }
}

/* toggle status function disabled fields */
function bp_update_status_function() {
    var type = jQuery('#bp_function').val();
    if(type == "status" || type == "groupstatus") {
        jQuery(".no_supports_link").show();
        jQuery(".supports_link").hide();
    } else {
        jQuery(".no_supports_link").hide();
        jQuery(".supports_link").show();
    }
    bp_update_firstnode_css();
}

/* toggle firstnode class */
function bp_update_firstnode_css() {
    if(bp_active_node == 'node1') {
        jQuery('.firstnode').css('display', '');
    } else {
        jQuery('.firstnode').css('display', 'none');
    }
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
    if(typeof id != 'string') {
        id = id.id;
    }
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
var bp_graph_layout;
function bp_render(containerId, nodes, edges) {
    // first reset zoom
    bp_zoom(1);
    var g = new dagre.Digraph();
    jQuery.each(nodes, function(nr, n) {
        g.addNode(n.id, { label: n.label, width: node_width, height: node_height });
    });
    jQuery.each(edges, function(nr, e) {
        g.addEdge(null, e.sourceId, e.targetId);
    });

    try {
        bp_graph_layout = dagre.layout()
            //.debugLevel(4)
            .nodeSep(bp_graph_options.bp_nodeSep)
            .edgeSep(bp_graph_options.bp_edgeSep)
            .rankSep(bp_graph_options.bp_rankSep)
            .rankDir(bp_graph_options.bp_rankDir)
            .run(g);
    } catch(e) {
        var msg = '<span style="white-space: nowrap; color:red;">Please use Internet Explorer 9 or greater. Or preferable Firefox or Chrome.</span>';
        if(thruk_debug_js) { msg += '<br><div style="width:500px; height: 400px; text-align: left;">Details:<br>'+e+'</div>'; }
        jQuery('.bp_zoom_container').css('height','500px');
        jQuery('#inner_'+containerId).html(msg);
        return;
    }

    bp_graph_layout.eachNode(function(u, value) {
        // move node
        jQuery('#'+u).css('left', (value.x-55)+'px').css('top', (value.y-15)+'px');
    });

    bp_graph_layout.eachEdge(function(e, u, v, value) {
        bp_plump('inner_'+containerId, u, v, value);
    });

    bp_redraw();
}

/* zoom out */
var last_zoom = 1;
function bp_zoom_rel(zoom) {
    bp_zoom(last_zoom + zoom);
    return false;
}

function bp_zoom_reset() {
    bp_zoom(original_zoom);
    return false;
}

/* set zoom level */
function bp_zoom(zoom) {
    // round to 0.05
    zoom = Math.floor((zoom * 20) + 0.05) / 20;
    if(zoom < 0.1) { zoom = 0.1 }
    last_zoom = zoom;
    jQuery('#zoom'+bp_id).css('zoom', zoom)
                           .css('-moz-transform', 'scale('+zoom+')')
                           .css('-moz-transform-origin', '0 0')
                           .css('-o-transform', 'scale('+zoom+')')
                           .css('-o-transform-origin', '0 0')
                           .css('-webkit-transform', 'scale('+zoom+')')
                           .css('-webkit-transform-origin', '0 0');


    // center align inner container
    var zcontainer = document.getElementById('zoom'+bp_id);
    if(zcontainer) {
        var offset = ((graphW - maxX*zoom) / 2);
        if(offset < 0) {offset = 0;}
        zcontainer.style.left = offset+'px';
        zcontainer.style.position = 'absolute';
    }
}

/* draw connector between two nodes */
function bp_plump(containerId, sourceId, targetId, edge) {
    var upper     = document.getElementById(sourceId);
    var lower     = document.getElementById(targetId);
    var container = document.getElementById(containerId);
    if(!upper || !lower ||!container) { return; }

    // get position
    var lpos = jQuery(lower).position();
    var upos = jQuery(upper).position();

    var edge_id = 'edge_'+sourceId+'_'+targetId;
    jQuery('#'+edge_id).remove();
    jQuery(container).append('<div id="'+edge_id+'"><\/div>');
    var edge_container = jQuery('#'+edge_id);

    var srcX = upos.left + 55;
    var srcY = upos.top + 20;
    var tarX = lpos.left + 55;
    var tarY = lpos.top + 20;
    if(bp_graph_options.bp_rankDir == 'TB') {
        // Top -> Bottom Graphs

        // draw "line" from top middle of lower node
        if((tarY - srcY) == 70) {
            // smarter edge placement for normal edges
            bp_draw_edge(edge_container, edge_id, srcX, srcY, srcX, srcY+35);
            bp_draw_edge(edge_container, edge_id, srcX, srcY+35, tarX, srcY+35);
            bp_draw_edge(edge_container, edge_id, tarX, srcY+35, tarX, tarY);
            return;
        }
        //jQuery(edge_container).append('<div class="bp_vedge" style="left: '+srcX+'px; top: '+srcY+'px; width:1px; height: 1px; border: 3px solid green; z-index: 150;"><\/div>');
        //jQuery(edge_container).append('<div class="bp_vedge" style="left: '+tarX+'px; top: '+tarY+'px; width:1px; height: 1px; border: 3px solid red;   z-index: 150;"><\/div>');

        // complicated layout
        var x1 = srcX, y1 = srcY;
        jQuery.each(edge.points, function(nr, p) {
            //jQuery(edge_container).append('<div class="bp_vedge" style="left: '+p.x+'px; top: '+p.y+'px; width:1px; height: 1px; border: 3px solid blue; z-index: 100;"><\/div>');
            bp_draw_edge(edge_container, edge_id, x1, y1, p.x, p.y);
            x1 = p.x; y1 = p.y;
        });
        bp_draw_edge(edge_container, edge_id, x1, y1, tarX, tarY);
    } else {
        // Left -> Right Graphs

        // draw "line" from right middle of left node
        if((tarX - srcX) == 150) {
            // smarter edge placement for normal edges
            bp_draw_edge(edge_container, edge_id, srcX, srcY, srcX+75, srcY);
            bp_draw_edge(edge_container, edge_id, srcX+75, srcY, srcX+75, tarY);
            bp_draw_edge(edge_container, edge_id, srcX+75, tarY, tarX, tarY);
            return;
        }

        // complicated layout
        bp_draw_edge(edge_container, edge_id, srcX, srcY, srcX+75, srcY);
        var x1 = srcX+75, y1 = srcY;
        jQuery.each(edge.points, function(nr, p) {
            //jQuery(edge_container).append('<div class="bp_vedge" style="left: '+p.x+'px; top: '+p.y+'px; width:1px; height: 1px; border: 3px solid blue; z-index: 100;"><\/div>');
            bp_draw_edge(edge_container, edge_id, x1, y1, p.x, p.y);
            x1 = p.x; y1 = p.y;
        });
        bp_draw_edge(edge_container, edge_id, x1, y1, tarX, tarY);
    }

    return;
}

function bp_draw_edge(edge_container, edge_id, x1, y1, x2, y2, recursion_level) {
    var w = x2 - x1;
    var h = y2 - y1;
    if(recursion_level == undefined) { recursion_level = 0; }
    if(w != 0 && h != 0) {
        if(recursion_level > 10) {
            if(thruk_debug_js) { alert("ERROR: deep recursion "+x1+"/"+y1+" "+x2+"/"+y2); }
            return;
        }
        // need two lines
        bp_draw_edge(edge_container, edge_id, x1, y1, x1, y2, recursion_level+1);
        bp_draw_edge(edge_container, edge_id, x1, y2, x2, y2, recursion_level+1);
        return;
    }
    if(w < 0) { x1 = x2; w = -w +2; }
    if(h < 0) { y1 = y2; h = -h +2; }
    var style = 'left: '+x1+'px; top: '+y1+'px;';
    if(h == 0) { cls = 'bp_hedge'; style += ' width:'+w+'px;';  }
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
var maxX = 0, maxY = 0, minY = -1, graphW = 0, graphH = 0;
function bp_redraw(evt) {
    var containerId;
    try {
        containerId = 'container'+bp_id;
    } catch(e) { return false; }
    if(!bp_graph_layout) { return false; }

    maxX = 0;
    maxY = 0;
    bp_graph_layout.eachNode(function(u, value) {
        if(maxX < value.x) { maxX = value.x }
        if(maxY < value.y) { maxY = value.y }
        if(minY == -1 || value.y < minY) { minY = value.y; }
        return true;
    });
    maxX = maxX + 80;
    maxY = maxY + 30;

    // adjust size of container
    var container = document.getElementById('bp'+bp_id);
    if(!container) { return false; }
    graphW = jQuery(window).width() - container.offsetLeft - 5;
    graphH = jQuery(window).height() - container.offsetTop -10;
    if(!minimal) {
        graphW = graphW - 315;
    }
    container.style.width  = graphW+'px';
    container.style.height = graphH+'px';

    var zcontainer = document.getElementById('zoom'+bp_id);
    if(!zcontainer) { return false; }
    zcontainer.style.width  = graphW+'px';
    zcontainer.style.height = graphH+'px';
    zcontainer.style.left   = '0px';

    var icontainer = document.getElementById('container'+bp_id);
    if(!icontainer) { return false; }
    zcontainer.style.width  = maxX+'px';
    zcontainer.style.height = maxY+'px';

    // do we need to zoom in?
    var zoomX = 1, zoomY = 1;
    if(graphW < maxX) {
        zoomX = graphW / maxX;
    }
    if(graphH < maxY) {
        zoomY = graphH / maxY;
    }
    var zoom = zoomY;
    if(zoomX < zoomY) { zoom = zoomX; }
    if(zoom < 1) {
        bp_zoom(zoom);
    } else {
        bp_zoom(1);
    }
    original_zoom = zoom;

    if(!current_node) {
        bp_update_status(null, 'node1');
        current_node = 'node1';
    }

    return true;
}

function bp_remove_search_prefix(search) {
    console.log(search);
    search = search.replace(/^(w|b):/, "");
    console.log(search);
    return(search);
}