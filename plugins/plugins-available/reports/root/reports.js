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

    jQuery('.report_remove_button').button({
        icons: {primary: 'ui-remove-button'}
    }).click(function() {
        return confirm('really delete?');
    });
}
