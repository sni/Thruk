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