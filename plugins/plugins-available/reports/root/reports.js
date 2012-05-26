/* initialize all buttons */
function init_report_tool_buttons() {
    jQuery('A.report_button').button();
    jQuery('BUTTON.report_button').button();

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
    jQuery('#reports_table').load('reports.cgi?_=' + ts + ' #statusTable');

    // now count is_running elements
    size = jQuery('.is_running').size();
    if(size == 0) {
        window.clearInterval(update_reports_status_int);
    }
}