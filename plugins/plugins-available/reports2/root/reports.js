/* initialize all buttons */
function init_report_tool_buttons() {
    jQuery('A.report_button').button();
    jQuery('BUTTON.report_button').button();

    jQuery('.report_edit_button').button({
        icons: {primary: 'ui-edit-button'}
    });

    jQuery('.report_save_button').button({
        icons: {primary: 'ui-save-button'}
    });

    jQuery('.right_arrow_button').button({
        icons: {primary: 'ui-r-arrow-button'}
    });

    jQuery('.add_button').button({
        icons: {primary: 'ui-add-button'}
    });

    jQuery('.report_small_remove_button').button({
        icons: {primary: 'ui-remove-button'},
        text: false
    });

    jQuery('.radioset').buttonset();

    jQuery('.report_remove_button').button({
        icons: {primary: 'ui-remove-button'}
    }).click(function() {
        return confirm('really delete?');
    });
}

/* update report list status */
function update_reports_status() {
    /* adding timestamp makes IE happy */
    var ts = new Date().getTime();
    jQuery('#reports_table').load('reports2.cgi?_=' + ts + ' #statusTable');

    // now count is_running elements
    size = jQuery('.is_running').size();
    if(size == 0) {
        window.clearInterval(update_reports_status_int);
    }
}

/* update reports edit step2 */
var tmpDiv;
var updateRetries;
function update_reports_type(nr, tpl) {
    /* adding timestamp makes IE happy */
    var ts = new Date().getTime();
    tmpDiv = jQuery("<div></div>").load('reports2.cgi?report='+nr+'&template='+tpl+'&action=edit2&_=' + ts);
    updateRetries = 0;
    window.setTimeout(update_reports_type_step2, 100);
}
function update_reports_type_step2() {
    updateRetries = updateRetries + 1;
    if(updateRetries == 30) {
        return;
    }
    if(tmpDiv.find('TR.report_options').length == 0) {
        window.setTimeout(update_reports_type_step2, 100);
        return;
    }

    jQuery('TR.report_options').remove();
    tmpDiv.find('TR.report_options').insertAfter('#new_reports_options')
    // scroll to bottom
    window.scroll(0, jQuery(document).height());
    jQuery('TR.report_options TD').effect('highlight', {}, 1000);
}

/* show hide specific types of reports */
function reports_view(typ) {
    // show owner column?
    if(typ == 'all' || typ == 'public') {
        jQuery('#reports_table .usercol').each(function(nr, el) {
            showElement(el);
        });
    } else {
        jQuery('#reports_table .usercol').each(function(nr, el) {
            hideElement(el);
        });
    }

    if(typ == 'all') {
        jQuery('#reports_table TR').each(function(nr, el) {
            showElement(el);
        });
    } else {
        jQuery('#reports_table TR').each(function(nr, el) {
            if(nr > 0) {
                hideElement(el);
            }
        });
        jQuery('#reports_table TR.'+typ).each(function(nr, el) {
            showElement(el);
        });
    }
    set_hash(typ);
}