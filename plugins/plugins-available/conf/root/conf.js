function set_sub(nr) {
    for(x=1;x<=3;x++) {
        /* reset table rows */
        if(x != nr) {
            $$('.sub_'+x).each(function(elem) {
                elem.style.display = "none";
            });
        }
        $$('.sub_'+nr).each(function(elem) {
            elem.style.display = "";
        });

        /* reset buttons */
        obj = document.getElementById("sub_"+x);
        styleElements(obj, "data", 1);
    }
    obj = document.getElementById("sub_"+nr);
    styleElements(obj, "data confSelected", 1);


    return false;
}

var running_number = 0;
function add_conf_attribute(table, key) {

    running_number--;
    if(key != 'customvariable' && key != 'exception') {
        $('new_' + key + '_btn').style.display = "none";
    }

    // add new row
    tbl = $(table);
    var tblBody        = tbl.tBodies[0];
    var currentLastRow = tblBody.rows.length - 3;

    var newObj   = tblBody.rows[0].cloneNode(true);
    newObj.id                 = "el_" + running_number;
    newObj.style.display      = "";
    newObj.cells[0].innerHTML = key;
    newObj.cells[0].abbr      = key;
    newObj.cells[1].abbr      = key;
    newObj.cells[0].innerHTML = newObj.cells[0].innerHTML.replace(/del_0/g, 'del_'+running_number);
    newObj.cells[1].innerHTML = newObj.cells[1].innerHTML.replace(/del_0/g, 'del_'+running_number);
    newObj.cells[2].innerHTML = unescape(fields.get(key).input.unescapeHTML().replace(/&quot;/g, '"'));
    newObj.cells[2].innerHTML = newObj.cells[2].innerHTML.replace(/id_key\d+/g, 'id_key'+running_number);
    newObj.cells[3].abbr      = unescape(fields.get(key).help.unescapeHTML().replace(/&quot;/g, '"'));

    if(key == 'customvariable' || key == 'exception') {
        var value = "";
        if(key == 'customvariable') {
            value = "_";
        }
        newObj.cells[0].innerHTML = "<input type=\"text\" name=\"objkey." + running_number + "\" value=\"" + value + "\" class=\"attrkey\" onchange=\"$('id_key" + running_number + "').name='obj.'+this.value\">";
        newObj.cells[2].innerHTML = newObj.cells[2].innerHTML.replace(/id_key\d+/g, 'id_'+running_number);
    }

    tblBody.insertBefore(newObj, tblBody.rows[tblBody.rows.length -2]);

    reset_table_row_classes(table, 'dataEven', 'dataOdd');

    // otherwise button icons are missing
    init_conf_tool_buttons();

    /* effect works only on table cells */
    jQuery(newObj.cells).effect('highlight', {}, 2000);

    return false;
}

/* remove an table row from the attributes table */
function remove_conf_attribute(key, nr) {

    var btn = $('new_' + key + '_btn');
    if(btn) {
        btn.style.display = "";
    }

    row   = $(nr).parentNode.parentNode;
    table = row.parentNode.parentNode;

    var field = fields.get(key)
    if(field) {
        field.input = escape(row.cells[2].innerHTML);
    }

    row.remove();
    reset_table_row_classes(table.id, 'dataEven', 'dataOdd');
    return false;
}

/* initialize all buttons */
function init_conf_tool_buttons() {
    jQuery('.conf_save_button').button({
        icons: {primary: 'ui-save-button'}
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
        width:       'auto',
        maxWidth:    1024,
        position:   'top',
        close:       function(event, ui) { ajax_search.hide_results(undefined, 1); return true; }
    });
    jQuery('#' + id + 'accept').button({
        icons: {primary: 'ui-ok-button'}
    }).click(function() {
        ajax_search.hide_results(undefined, 1);
        $d.dialog('close');
        // set values in original inputs
        args = collect_args(id);
        document.getElementById(cmd_arg_id).value = args;
        document.getElementById(cmd_inp_id).value = document.getElementById(id + "inp_command").value;
        return false;
    });

    init_plugin_help_accordion(id);

    $d.dialog('open');

    last_cmd_name_value = '';
    do_update_command_line(id, cmd_name);

    return;
}

/* delay update a few millis */
var cmdUpdateTimer;
function update_command_line(id) {
    window.clearTimeout(cmdUpdateTimer);
    cmdUpdateTimer = window.setTimeout("do_update_command_line('"+id+"')", 300);
}

/* update command line */
var last_cmd_name_value = '';
function do_update_command_line(id) {

    // set rest based on detailed command info
    var cmd_name = document.getElementById(id + "inp_command").value;
    var cmd_arg  = document.getElementById(id + "inp_args").value;
    var args     = cmd_arg.split('!');

    if(last_cmd_name_value == cmd_name) {
        hideElement(id + 'wait');
        return;
    }
    last_cmd_name_value = cmd_name;

    // check if its a direct hit from search
    // otherwise an update is useless as it is
    // not a full command
    if(ajax_search && ajax_search.base && ajax_search.base[0] && ajax_search.base[0].data) {
        var found = 0;
        ajax_search.base[0].data.each(function(elem) {
            if(elem == cmd_name) { found++; }
        });
        if(found == 0) {
            return;
        }
    }


    showElement(id + 'wait');
    document.getElementById(id + 'command_line').innerHTML = "";
    new Ajax.Request('conf.cgi?action=json&amp;type=commanddetails&command='+cmd_name, {
        onSuccess: function(transport) {
            var result;
            if(transport.responseJSON != null) {
                result = transport.responseJSON;
            } else {
                result = eval(transport.responseText);
            }
            hideElement(id + 'wait');
            var cmd_line = result[0].cmd_line;

            for(var nr=1;nr<=100;nr++) {
                var regex = new RegExp('\\$ARG'+nr+'\\$', 'g');
                cmd_line = cmd_line.replace(regex, "<input type='text' id='"+id+"arg"+nr+"' class='"+id+"arg"+nr+"' size=15 value='' onclick=\"ajax_search.init(this, 'macro', {url:'conf.cgi?action=json&amp;type=macro', hideempty:true})\" onkeyup='update_other_inputs(this)'>");
            }

            cmd_line = cmd_line.replace(/\ \-/g, "<br>&nbsp;&nbsp;&nbsp;&nbsp;-");
            document.getElementById(id + 'command_line').innerHTML = cmd_line;

            // now set the values to avoid escaping
            for(var nr=1;nr<=100;nr++) {
                jQuery('.'+id+'arg'+nr).val(args[nr-1]);
            }

            // close the helper accordion
            if($accordion && $accordion.children('h3').hasClass('ui-state-active')) {
                $accordion.accordion("activate", false);
            }
        },
        onFailure: function(transport) {
            hideElement(id + 'wait');
            document.getElementById(id + 'command_line').innerHTML = 'error';
        }
    });
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
var last_plugin_help = '';
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
        autoHeight:  false,
        fillSpace:   true,
        change:      function(event, ui) {
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
                    last_plugin_help = current;
                    load_plugin_help(id, current);
                }
            } else {
                hideElement(id + 'wait_help');
            }
        }
    });
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
    new Ajax.Request('conf.cgi?action=json&amp;type=pluginhelp&plugin='+plugin, {
        onSuccess: function(transport) {
            var result;
            if(transport.responseJSON != null) {
                result = transport.responseJSON;
            } else {
                result = eval(transport.responseText);
            }
            hideElement(id + 'wait_help');
            var plugin_help = result[0].plugin_help;
            document.getElementById(id + 'plugin_help').innerHTML = '<pre style="white-space: pre-wrap; height:400px; overflow: scoll;" id="'+id+'plugin_help_pre"><\/pre>';
            jQuery('#' + id + 'plugin_help_pre').text(plugin_help);

            // now set the values to avoid escaping
            for(var nr=1;nr<=100;nr++) {
                jQuery('.'+id+'arg'+nr).val(args[nr-1]);
            }
        },
        onFailure: function(transport) {
            hideElement(id + 'wait_help');
            document.getElementById(id + 'plugin_help').innerHTML = 'error';
        }
    });
}
