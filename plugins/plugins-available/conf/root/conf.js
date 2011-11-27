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
        width:      'auto'
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
        width:      'auto'
    });
    jQuery('#' + id + 'accept').button({
        icons: {primary: 'ui-ok-button'}
    }).click(function() {
        $d.dialog('close');
        // set values in original inputs
        args = collect_args(id);
        document.getElementById(cmd_arg_id).value = args;
        document.getElementById(cmd_inp_id).value = document.getElementById(id + "inp_command").value;
        return false;
    });

    $d.dialog('open');
    document.getElementById(cmd_arg_id).focus();

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

    if(last_cmd_name_value == cmd_name) { return; }
    last_cmd_name_value = cmd_name;

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
                var regex = new RegExp('\\$ARG'+nr+'\\$');
                if(args[nr-1] == undefined) { args[nr-1] = ''; }
                cmd_line = cmd_line.replace(regex, "<input type='text' id='"+id+"arg"+nr+"' size=15 value='"+args[nr-1]+"' onclick=\"ajax_search.init(this, 'macro', 'conf.cgi?action=json&amp;type=macro')\">");
            }

            cmd_line = cmd_line.replace(/\ \-/g, "<br>&nbsp;&nbsp;&nbsp;&nbsp;-");
            document.getElementById(id + 'command_line').innerHTML = cmd_line;
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
