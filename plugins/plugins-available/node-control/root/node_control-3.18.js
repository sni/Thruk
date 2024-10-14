var ms_row_refresh_interval = 3000;
var ms_refresh_timer;
// add background refresh for all rows currently spinning
jQuery(document).ready(function() {
    window.clearTimeout(ms_refresh_timer);
    ms_refresh_timer = window.setTimeout(function() {
        refresh_all_changed_rows(null);
    }, ms_row_refresh_interval)
});

// used for updating all (visible) servers
function nc_run_all(mainBtn, cls, extraData) {
    var list = [];
    jQuery(cls).each(function(i, el) {
        if(jQuery(el).is(":visible") && !jQuery(el).hasClass("invisible")) {
            list.push(el);
        }
    });

    if(list.length == 0) {
        return;
    }

    setBtnSpinner(mainBtn, true);
    var running = 0;
    var startNext = function() {
        if(list.length == 0) {
            if(running == 0) {
                setBtnNoSpinner(mainBtn);
            }
            return;
        }
        running++;
        var btn = list.shift();
        setBtnSpinner(btn, true);
        var form = jQuery(btn).parents('FORM');
        submitFormInBackground(form, function() {
            running--;
            setBtnNoSpinner(btn);
            startNext();

            refresh_all_changed_rows_now(null, 'TD.js-node-row');
        }, extraData);
    }
    for(var x = 0; x < ms_parallel; x++) {
        startNext();
    }
}

function nc_action_with_popup(btn, formData, peer_key) {
    var form = jQuery(btn).parents('FORM');
    setBtnSpinner(btn, true);
    submitFormInBackground(form, function(form, success, data, textStatus, jqXHR) {
        if(data && data.job) {
            additionalParams["showjob"]  = data.job;
            additionalParams["showpeer"] = peer_key;
        }
        reloadPage();
    }, formData);
    return false;
}

function refresh_all_changed_rows_now(extraData, selector) {
    window.clearTimeout(ms_refresh_timer);
    ms_refresh_timer = window.setTimeout(function() {
        refresh_all_changed_rows(extraData, selector);
    }, 200)
}

function refresh_all_changed_rows(extraData, selector) {
    window.clearTimeout(ms_refresh_timer);
    if(!selector) { selector = "DIV.spinner"; }
    var rows = jQuery(selector).parents("TR");
    if(rows.length == 0) {
        return;
    }
    jQuery.ajax({
        url:     'node_control.cgi',
        data:     extraData,
        complete: function(data, textStatus, jqXHR) {
            if(data && data.responseText) {
                var table = jQuery(rows[0]).parents('TABLE')[0];
                jQuery(rows).each(function(i, el) {
                    if(el.id && data.responseText.match(el.id)) {
                        var newRow = jQuery(data.responseText).find('#'+el.id);
                        if(newRow.length > 0) { // removes omd service status rows otherwise
                            jQuery('#'+el.id).replaceWith(newRow);
                        } else {
                            console.log("found no new row in result for id: "+el.id);
                        }
                    }
                });
                table.dataset["search"] = "";
                jQuery("#table_search_input").focus();
                applyRowStripes(table);
            }
            rows = jQuery("DIV.spinner").parents("TR");
            if(rows.length > 0) {
                ms_refresh_timer = window.setTimeout(function() {
                    ms_refresh_timer = refresh_all_changed_rows(extraData, selector);
                }, ms_row_refresh_interval)
            }
        }
    });
}

// used to update service status
function nc_omd_service(btn, extraData) {
    setBtnSpinner(btn, true);

    var form = jQuery(btn).parents('FORM');
    submitFormInBackground(form, function(form, success, data, textStatus, jqXHR) {
        // update service row
        refresh_all_changed_rows({action: 'omd_status', modal: 1, peer: extraData['peer']}, 'TD.js-omd-status-'+extraData["peer"]+'-'+extraData["service"]);

        // update node row
        refresh_all_changed_rows(null, 'TD.js-node-row');
    }, extraData);
}

// used to update peer status
function nc_peer_state(btn, extraData) {
    setBtnSpinner(btn, true);

    var form = jQuery(btn).parents('FORM');
    submitFormInBackground(form, function(form, success, data, textStatus, jqXHR) {
        // update service row
        refresh_all_changed_rows({action: 'peer_status', modal: 1, peer: extraData['peer']}, 'TD.js-omd-status-'+extraData["peer"]+'-'+extraData["type"]);

        // update node row
        refresh_all_changed_rows(null, 'TD.js-node-row');
    }, extraData);
}
