var running_number = 0;
function add_conf_attribute(table, key, rt) {

    var value = "";
    if(fields[key] == undefined) {
        value = key;
        key   = 'customvariable';
    }
    if(fields[key] == undefined) {
        return false;
    }

    running_number--;
    if(key != 'customvariable' && key != 'exception') {
        jQuery('#new_' + key + '_btn').css('display', 'none');
    }

    // add new row
    tbl = document.getElementById(table);
    var tblBody        = tbl.tBodies[0];

    var newObj   = tblBody.rows[0].cloneNode(true);
    newObj.id                 = "el_" + running_number;
    newObj.style.display      = "";
    newObj.cells[0].innerHTML = key;
    newObj.cells[0].abbr      = key;
    newObj.cells[1].abbr      = key;
    newObj.cells[0].innerHTML = newObj.cells[0].innerHTML.replace(/del_0/g, 'del_'+running_number);
    newObj.cells[1].innerHTML = newObj.cells[1].innerHTML.replace(/del_0/g, 'del_'+running_number);
    newObj.cells[2].innerHTML = unescape(unescapeHTML(fields[key].input).replace(/&quot;/g, '"'));
    newObj.cells[2].innerHTML = newObj.cells[2].innerHTML.replace(/id_key\d+/g, 'id_key'+running_number);
    newObj.cells[3].abbr      = unescape(unescapeHTML(fields[key].help).replace(/&quot;/g, '"'));

    if(key == 'customvariable' || key == 'exception') {
        if(key == 'customvariable' && value.substr(0,1) != '_') {
            value = "_"+value.toUpperCase();
        }
        newObj.cells[0].innerHTML = "<input type=\"text\" name=\"objkey." + running_number + "\" value=\"" + value + "\" class=\"attrkey\" onchange=\"jQuery('.obj_" + running_number + "').attr('name', 'obj.'+this.value)\" id='id_customvariable0_key'>";
        newObj.cells[2].innerHTML = newObj.cells[2].innerHTML.replace(/id_key\d+/g, 'id_'+running_number);
        newObj.cells[2].innerHTML = newObj.cells[2].innerHTML.replace(/class="obj_customvariable"/g, 'class="obj_customvariable obj_'+running_number+'"');
    }
    if(key == 'customvariable') {
        newObj.cells[2].innerHTML = newObj.cells[2].innerHTML.replace(/id="id_customvariable0"/g, 'id="id_customvariable'+running_number+'"');
        newObj.cells[0].innerHTML = newObj.cells[0].innerHTML.replace(/id_customvariable0_key/g, 'id_customvariable'+running_number+'_key');
    }

    // insert row at 3rd last position
    tblBody.insertBefore(newObj, tblBody.rows[tblBody.rows.length -3]);

    reset_table_row_classes(table, 'dataEven', 'dataOdd');

    // otherwise button icons are missing
    init_conf_tool_buttons();

    /* effect works only on table cells */
    jQuery(newObj.cells).effect('highlight', {}, 2000);

    // return id of new added input
    if(rt != undefined && rt == true) {
        var inp     = newObj.cells[2].innerHTML;
        var matches = inp.match(/id=([^\s]+?)\s/);
        if(matches != null) {
            var id = matches[1].replace('"', '');
            return matches[1];
        }
    }
    return false;
}

/* remove an table row from the attributes table */
function remove_conf_attribute(key, nr) {

    jQuery('#new_' + key + '_btn').css('display', '');

    row   = document.getElementById(nr).parentNode.parentNode;
    table = row.parentNode.parentNode;

    var field = fields[key];
    if(field) {
        field.input = escape(row.cells[2].innerHTML);
    }

    var p = row.parentNode;
    p.removeChild(row);
    reset_table_row_classes(table.id, 'dataEven', 'dataOdd');
    return false;
}

/* initialize all buttons */
function init_conf_tool_buttons() {
    jQuery('INPUT.conf_button').button();
    jQuery('BUTTON.conf_button').button();
    jQuery('.radioset').buttonset();

    jQuery('.conf_save_button').button({
        icons: {primary: 'ui-save-button'}
    });
    jQuery('.conf_apply_button').button({
        icons: {primary: 'ui-apply-button'}
    });
    jQuery('.conf_back_button').button({
        icons: {primary: 'ui-l-arrow-button'}
    });
    jQuery('.conf_save_reload_button').button({
        icons: {primary: 'ui-save_reload-button'}
    });
    jQuery('.conf_delete_button').button({
        icons: {primary: 'ui-delete-button'}
    });
    jQuery('.conf_cleanup_button').button({
        icons: {primary: 'ui-wrench-button'}
    })
    jQuery('.conf_cut_button').button({
        icons: {primary: 'ui-cut-button'}
    })
    jQuery('.conf_next_button').button({
        icons: {primary: 'ui-r-arrow-button'}
    })

    jQuery('.conf_preview_button').button({
        icons: {primary: 'ui-preview-button'}
    }).click(function() {
        check_plugin_exec(this.id);
        return false;
    });

    var $dialog = jQuery('#new_attribute_pane')
      .dialog({
        dialogClass: 'dialogWithDropShadow',
        autoOpen:    false,
        title:      'Select New Attributes',
        width:      'auto',
        position:   'top'
    });
    jQuery('#attr_opener').button({
        icons: {primary: 'ui-add-button'}
    }).click(function() {
        $dialog.dialog('open');
        return false;
    });

    jQuery('#finish_button').button({
        icons: {primary: 'ui-ok-button'}
    }).click(function() {
        $dialog.dialog('close');
        return false;
    });

    /* command wizard */
    jQuery('button.cmd_wzd_button').button({
        icons: {primary: 'ui-wzd-button'},
        text: false,
        label: 'open command line wizard'
    }).click(function() {
        init_conf_tool_command_wizard(this.id);
        return false;
    });

    /* command line wizard / plugins */
    jQuery('button.plugin_wzd_button').button({
        icons: {primary: 'ui-wzd-button'},
        text: false,
        label: 'open command line wizard'
    }).click(function() {
        init_conf_tool_plugin_wizard(this.id);
        return false;
    });

    /* command line wizard / plugins */
    jQuery('button.ip_wzd_button').button({
        icons: {primary: 'ui-wzd-button'},
        text: false,
        label: 'set ip based on current hostname'
    }).click(function() {
        var host = jQuery('#attr_table').find('.obj_host_name').val();
        if(host == undefined) {
            return false;
        }

        jQuery.ajax({
            url: 'conf.cgi',
            data: {
                action: 'json',
                type:   'dig',
                host:   host,
                token:  user_token
            },
            type: 'POST',
            success: function(data) {
                jQuery('#attr_table').find('.obj_address').val(data.address).effect('highlight', {}, 1000);
            }
        });
        return false;
    });

    /* list wizard */
    jQuery('button.members_wzd_button').button({
        icons: {primary: 'ui-wzd-button'},
        text: false,
        label: 'open list wizard'
    }).click(function() {
        init_conf_tool_list_wizard(this.id, this.name);
        return false;
    });

    jQuery('TD.attrValue').button();
    return;
}

/* handle command wizard dialog */
function init_conf_tool_command_wizard(id) {
    id = id.substr(0, id.length -3);

    // set initial values
    var cmd_inp_id = document.getElementById(id + "orig_inp1").value;
    var cmd_arg_id = document.getElementById(id + "orig_inp2").value;
    var cmd_name   = document.getElementById(cmd_inp_id).value;
    var cmd_arg    = document.getElementById(cmd_arg_id).value;
    document.getElementById(id + "inp_command").value = cmd_name;
    document.getElementById(id + "inp_args").value    = cmd_arg;

    var $d = jQuery('#' + id + 'dialog')
      .dialog({
        dialogClass: 'dialogWithDropShadow',
        autoOpen:    false,
        width:       642,
        position:   'top',
        close:       function(event, ui) { do_command_line_updates=0; ajax_search.hide_results(undefined, 1); return true; }
    });
    jQuery('#' + id + 'accept').button({
        icons: {primary: 'ui-ok-button'}
    }).click(function() {
        do_command_line_updates=0;
        ajax_search.hide_results(undefined, 1);
        $d.dialog('close');
        // set values in original inputs
        var args = collect_args(id);
        document.getElementById(cmd_arg_id).value = args;
        document.getElementById(cmd_inp_id).value = document.getElementById(id + "inp_command").value;
        return false;
    });

    init_plugin_help_accordion(id);

    $d.dialog('open');

    last_cmd_name_value = '';
    do_command_line_updates=1;
    update_command_line(id, cmd_name);

    return;
}

/* update command line */
var last_cmd_name_value = '';
var do_command_line_updates = 0;
function update_command_line(id) {

    if(do_command_line_updates == 0) {
        return;
    }

    // set rest based on detailed command info
    var cmd_name = document.getElementById(id + "inp_command").value;
    var cmd_arg  = document.getElementById(id + "inp_args").value;
    var args     = cmd_arg.split('!');

    if(last_cmd_name_value == cmd_name) {
        window.setTimeout("update_command_line('"+id+"')", 300);
        hideElement(id + 'wait');
        return;
    }
    last_cmd_name_value = cmd_name;

    // check if its a direct hit from search
    // otherwise an update is useless as it is
    // not a full command
    if(ajax_search && ajax_search.base && ajax_search.base[0] && ajax_search.base[0].data) {
        var found = 0;
        jQuery.each(ajax_search.base[0].data, function(nr, elem) {
            if(elem == cmd_name) { found++; }
        });
        if(found == 0) {
            window.setTimeout("update_command_line('"+id+"')", 300);
            return;
        }
    }


    showElement(id + 'wait');
    document.getElementById(id + 'command_line').innerHTML = "";

    jQuery.ajax({
        url: 'conf.cgi',
        type: 'POST',
        data: {
            action: 'json',
            type:   'commanddetails',
            command: cmd_name,
            token:   user_token
        },
        success: function(data) {
            hideElement(id + 'wait');
            var cmd_line = data[0].cmd_line;
            for(var nr=1;nr<=100;nr++) {
                var regex = new RegExp('\\$ARG'+nr+'\\$', 'g');
                cmd_line = cmd_line.replace(regex, "<\/td><td><input type='text' id='"+id+"arg"+nr+"' class='cmd_line_inp_wzd "+id+"arg"+nr+"' size=15 value='' onclick=\"ajax_search.init(this, 'macro', {url:'conf.cgi?action=json&amp;type=macro&amp;withuser=1&plugin=', append_value_of:'"+id+"inp_command', hideempty:true, list:'[ =\\\']'})\" onkeyup='update_other_inputs(this)'><\/td><td>");
            }

            cmd_line = cmd_line.replace(/\ \-/g, "<\/td><\/tr><\/table><table class='command_line_wzd'><tr><td>-");
            cmd_line = "<table class='command_line_wzd first'><tr><td>"+cmd_line+"<\/td><\/tr><\/table>"
            cmd_line = cmd_line.replace(/<td>\s*<\/td>/g, "");
            document.getElementById(id + 'command_line').innerHTML = cmd_line;

            // now set the values to avoid escaping
            for(var nr=1;nr<=100;nr++) {
                jQuery('.'+id+'arg'+nr).val(args[nr-1]);
            }

            close_accordion();
        },
        error: function() {
            hideElement(id + 'wait');
            document.getElementById(id + 'command_line').innerHTML = '<font color="red"><b>error<\/b><\/font>';
        }
    });

    window.setTimeout("update_command_line('"+id+"')", 300);
}

function collect_args(id) {
    var args = new Array();
    for(var x=1; x<=100;x++) {
        var objs = jQuery('#'+id+'arg'+x);
        if(objs[0] != undefined) {
            args.push(objs[0].value);
        } else {
            args.push('');
        }
    }
    // remove trailing empty elements
    for (var i=args.length-1; i>0; i--) {
        if(args[i] == '') {
            args.pop();
        } else {
            i=0;
        }
    }

    return args.join('!');
}

/* updates all inputs with the same class */
function update_other_inputs(elem) {
    var val = elem.value;
    jQuery('.'+elem.id).val(val);
}

/* handle command line wizard dialog */
var last_plugin_help = undefined;
function init_conf_tool_plugin_wizard(id) {
    id = id.substr(0, id.length -3);

    // set initial values
    var cmd_inp_id = document.getElementById(id + "orig_inp").value;
    var cmd_line   = document.getElementById(cmd_inp_id).value;
    document.getElementById(id + "inp_args").value = '';
    var index = cmd_line.indexOf(" ");
    if(index != -1) {
        var args = cmd_line.substr(index + 1);
        document.getElementById(id + "inp_args").value = args;
        cmd_line = cmd_line.substr(0, index);
    };
    document.getElementById(id + "inp_plugin").value = cmd_line;

    var $d = jQuery('#' + id + 'dialog')
      .dialog({
        dialogClass: 'dialogWithDropShadow',
        autoOpen:    false,
        width:       'auto',
        maxWidth:    1024,
        position:    'top',
        close:       function(event, ui) { ajax_search.hide_results(undefined, 1); return true; }
    });
    jQuery('#' + id + 'accept').button({
        icons: {primary: 'ui-ok-button'}
    }).click(function() {
        ajax_search.hide_results(undefined, 1);
        $d.dialog('close');
        // set values in original inputs
        var newcmd = document.getElementById(id+'inp_plugin').value;
        if(document.getElementById(id+'inp_args').value != '') {
            newcmd = newcmd + " " + document.getElementById(id+'inp_args').value
        }
        document.getElementById(cmd_inp_id).value = newcmd;
        return false;
    });

    init_plugin_help_accordion(id);

    $d.dialog('open');

    return;
}

var $accordion;
function init_plugin_help_accordion(id) {
    $accordion = jQuery("#"+id+"help_accordion").accordion({
        collapsible: true,
        active:      'none',
        clearStyle:  true,
        heightStyle: 'content',
        fillSpace:   true,
        activate:    function(event, ui) {
            if(ui.newHeader.size() == 0) {
                // accordion is closing
                return;
            }
            if(ui.newHeader[0].innerHTML.indexOf('Preview') != -1) {
                init_plugin_exec(id);
            }
            if(ui.newHeader[0].innerHTML.indexOf('Plugin Help') != -1) {
                check_plugin_help(id);
            }
            return;
        }
    });
}

function check_plugin_help(id) {
    var current;
    var input = document.getElementById(id+'inp_plugin');
    if(input) {
        current = input.value;
    } else {
        input = document.getElementById(id+'inp_command');
        if(input) {
            current = input.value;
        }
    }
    if(current) {
        if(current != last_plugin_help) {
            load_plugin_help(id, current);
        }
    } else {
        document.getElementById(id + 'plugin_help').innerHTML = 'please select a plugin first';
        hideElement(id + 'wait_help');
    }
}

function load_plugin_help(id, plugin) {
    document.getElementById(id + 'plugin_help').innerHTML = "";
    if(plugin == '') {
        hideElement(id + 'wait_help');
        return;
    }

    // verify accordion is really open
    if(!$accordion || $accordion.children('h3').hasClass('ui-state-active') == false) {
        hideElement(id + 'wait_help');
        return;
    }

    showElement(id + 'wait_help');
    last_plugin_help = plugin;

    jQuery.ajax({
        url: 'conf.cgi',
        data: {
            action: 'json',
            type:   'pluginhelp',
            plugin:  plugin,
            token:   user_token
        },
        type: 'POST',
        success: function(data) {
            hideElement(id + 'wait_help');
            var plugin_help = data[0].plugin_help;
            document.getElementById(id + 'plugin_help').innerHTML = '<pre style="white-space: pre-wrap; height:400px; overflow: scoll;" id="'+id+'plugin_help_pre"><\/pre>';
            jQuery('#' + id + 'plugin_help_pre').text(plugin_help);
        },
        error: function() {
            hideElement(id + 'wait_help');
            document.getElementById(id + 'plugin_help').innerHTML = '<font color="red"><b>error<\/b><\/font>';
        }
    });
}

function init_plugin_exec(id) {
    var host = jQuery('.obj_host_name').val();
    if(host != undefined) {
        host = host.replace(/\s*,.*$/, '');
        jQuery('#'+id+'inp_preview_host').val(host);
    }
    jQuery('#'+id+'inp_preview_service').val(jQuery('.obj_service_description').val());
}

function check_plugin_exec(id) {
    id          = id.replace(/preview$/, '');
    args        = collect_args(id);
    var host    = jQuery('#'+id+'inp_preview_host').val();
    var service = jQuery('#'+id+'inp_preview_service').val();
    var command = jQuery('#'+id + "inp_command").val();
    jQuery('#'+id + 'plugin_exec_output').text('');
    showElement(id + 'wait_run');

    jQuery.ajax({
        url: 'conf.cgi',
        data: {
            action: 'json',
            type:   'pluginpreview',
            command: command,
            host:    host,
            service: service,
            args:    args,
            token:   user_token
        },
        type: 'POST',
        success: function(data) {
            hideElement(id + 'wait_run');
            var plugin_output = data[0].plugin_output;
            document.getElementById(id + 'plugin_exec_output').innerHTML = '<pre style="white-space: pre-wrap; max-height:300px; overflow: scoll;" id="'+id+'plugin_output_pre"><\/pre>';
            jQuery('#' + id + 'plugin_output_pre').text(plugin_output);
        },
        error: function(transport) {
            hideElement(id + 'wait_run');
            document.getElementById(id + 'plugin_exec_output').innerHTML = '<font color="red"><b>error<\/b><\/font>';
        }
    });
}

function close_accordion() {
    // close the helper accordion
    if($accordion) {
        $accordion.accordion({active: false});
    }
}

/* handle list wizard dialog */
var available_members = new Array();
var selected_members  = new Array();
var init_conf_tool_list_wizard_initialized = {};
function init_conf_tool_list_wizard(id, type) {
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

    // initialize available members
    available_members = new Array();
    jQuery("select#"+id+"available_members").html('<option disabled>loading...<\/option>');
    jQuery.ajax({
        url: 'conf.cgi?action=json&amp;type='+type,
        type: 'POST',
        success: function(data) {
            var result = data[0]['data'];
            if(templates) {
                result = data[1]['data'];
            }
            var options = [];
            var size = result.length;
            for(var x=0; x<size;x++) {
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
    if(init_conf_tool_list_wizard_initialized[id] != undefined) {
        // reset filter
        jQuery('INPUT.filter_available').val('');
        jQuery('INPUT.filter_selected').val('');
        data_filter_select(id+'available_members', '');
        data_filter_select(id+'selected_members', '');
        $d.dialog('open');
        return;
    }
    init_conf_tool_list_wizard_initialized[id] = true;

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

/* filter already displayed attributes */
function new_attr_filter(str) {
    if(jQuery('#new_'+str+'_btn').css('display') == 'none') {
        return false;
    }
    return true;
}

/* new attribute onselect */
function on_attr_select() {
    var key = jQuery('#newattr').val();
    var newid = add_conf_attribute('attr_table', key,true);
    ajax_search.reset();
    if(!newid) { return false; }
    newid = "#"+(newid.replace(/"/g, ''));
    if(key == "customvariable") {
        newid = newid+"_key";
    }
    window.setTimeout(function() {
        ajax_search.hide_results(null, 1);
        jQuery(newid).focus();
        /* move cursor to end of input */
        setCaretToPos(jQuery(newid)[0], jQuery(newid).val().length);
    }
    , 200);
    return newid;
}

/* new attribute onselect */
function on_empty_click(inp) {
    var input = document.getElementById(ajax_search.input_field);
    var v = input.value;
    input.value = 'customvariable';
    var newid = on_attr_select();
    if(!newid) { return(false); }
    newid = newid.replace(/^#/, '');
    var newin = document.getElementById(newid);
    var tr = newin.parentNode.parentNode;
    var td = tr.cells[0].firstChild;
    td.value = v.toUpperCase();
    if(td.value.substr(0,1) != '_') {
        td.value = '_' + td.value;
    }
    newin.name = 'obj.'+td.value;
    return false;
}

/* validate objects edit form */
function conf_validate_object_form(f) {
    var fileselect = jQuery(f).find('#fileselect').first().val();
    if(fileselect != undefined && fileselect == "") {
        alert("please enter filename for this object.");
        return false;
    }
    initial_form_values = jQuery(f).serialize();
    return true;
}

/* if form id is set, append own form value to remote form and submit merged */
function save_reload_apply(formid) {
    if(!formid) { return true; }
    var remoteform = document.getElementById(formid);
    if(!remoteform) { return true; }
    var input = jQuery("<input>", { type: "hidden", name: "save_and_reload", value: "1" });
    jQuery(remoteform).append(jQuery(input));
    if(remoteform.onsubmit()) {
        // does not work in firefox (only after removing an attribute)
        //debug(remoteform.submit());
        jQuery('button.conf_apply_button')[0].click();
    }
    return false;
}

var continue_cb;
function conf_tool_cleanup(btn, link, hide) {
    if(jQuery(btn).hasClass('done')) {
        return(false);
    }
    if(link == "fix_all_serial") {
        jQuery(btn).button({
            icons: {primary: 'ui-waiting-button'},
            disabled: true
        })
        var fix_buttons = jQuery('BUTTON.conf_cleanup_button_fix');
        if(fix_buttons.length > 0) {
            continue_cb = function() {
                conf_tool_cleanup(btn, "fix_all_serial", hide);
            }
            fix_buttons[0].click();
        }
        if(fix_buttons.length == 0) {
            continue_cb = undefined;
            jQuery(btn).button({
                icons: {primary: 'ui-ok-button'},
                label:   'done',
                disabled: false
            }).addClass('done');
        }
        return false;
    }
    jQuery(btn).button({
        icons: {primary: 'ui-waiting-button'},
        disabled: true
    })
    if(hide) {
        /* ensure table width is fixed */
        var table       = jQuery(btn).parents('table')[0];
        var table_width = table.offsetWidth;
        if(!table.style.width) {
            jQuery(table).find('TH').each(function(_, header) {
                header.style.width = jQuery(header).width()+'px';
            });
            table.style.width = jQuery(table).outerWidth()+"px";
            table.style.tableLayout = "fixed";
        }
        /* fade away the table row */
        jQuery(btn).parentsUntil('TABLE', 'TR').fadeOut(100);
        var oldText = jQuery('#hiding_entries').html();
        var hiding  = Number(oldText.match(/\ (\d+)\ /)[1]) + 1;
        jQuery('#hiding_entries').html("hiding "+hiding+" entries.").show();
    }
    jQuery.ajax({
        url:   link,
        data:  {},
        type: 'POST',
        success: function(data) {
            jQuery(btn).button({
                icons:   {primary: 'ui-ok-button'},
                label:   'done',
                disabled: false
            }).addClass('done');
            if(!hide) {
                /* hide ignore button */
                var buttons = jQuery(btn).parentsUntil('TABLE', 'TR').find('BUTTON');
                if(buttons[0]) {
                    jQuery(buttons[0]).button('disable');
                }
                jQuery('#apply_config_changes_icon').show();
            }
            jQuery(btn).removeClass('conf_cleanup_button_fix');
            if(continue_cb) { continue_cb(); }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            jQuery(btn).button({
                icons:   {primary: 'ui-error-button'},
                label:   'failed',
                disabled: false
            })
            jQuery(btn).removeClass('conf_cleanup_button_fix');
        }
    });

    return(false);
}