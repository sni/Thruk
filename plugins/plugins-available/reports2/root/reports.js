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
    jQuery('.report_clone_button').button({
        icons: {primary: 'ui-clone-button'}
    });

    jQuery('.report_email_button').button({
        icons: {primary: 'ui-email-button'}
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

    jQuery('.radioset INPUT[type=radio]').button({icon:false});
    jQuery('.radioset').controlgroup({});

    jQuery('.report_remove_button').button({
        icons: {primary: 'ui-remove-button'}
    }).click(function() {
        return confirm('really delete?');
    });
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

    // replace settings
    jQuery('TR.report_options').remove();
    tmpDiv.find('TR.report_options').insertAfter('#new_reports_options')

    // scroll to report settings
    jQuery('TR.report_options TD').effect('highlight', {}, 1000);
    jQuery([document.documentElement, document.body]).animate({
        scrollTop: $("#report_type").offset().top
    }, 1000);
}

/* show hide specific types of reports */
var last_reports_typ;
function reports_view(typ) {
    if(typ == undefined) {
        typ = last_reports_typ;
    }
    last_reports_typ = typ;

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
            jQuery(el).removeClass('tab_hidden');
        });
    } else {
        jQuery('#reports_table TR').each(function(nr, el) {
            if(nr > 0) {
                if(jQuery(el).hasClass(typ)) {
                    jQuery(el).removeClass('tab_hidden');
                } else {
                    jQuery(el).addClass('tab_hidden');
                }
            }
        });
    }
    set_hash(typ, 1);
}

/* collect total number of affected hosts and services */
function reports_update_affected_sla_objects(input) {
    var form = jQuery(input).closest('FORM');

    // only useful if there is a affected objects output field
    if(form.find('TR.report_type_affected_sla_objects SPAN.value').lenght == 0) {
        return;
    }

    var span1 = form.find('TR.report_type_affected_sla_objects SPAN.name');
    var span2 = form.find('TR.report_type_affected_sla_objects SPAN.value');
    showElement('reports_waiting');
    hideElement(span2[0].id);
    var backends = form.find('SELECT[name=report_backends]').val();
    try {
        // only get all backends if using the _backend_select_multi.tt
        if(document.getElementById('available_backends') != undefined) {
            var options = jQuery('#report_backends option');
            var backends = jQuery.map(options ,function(option) {
                return option.value;
            });
        }
    } catch(e) {
        debug(e);
    }
    jQuery.ajax({
        url:  'reports2.cgi',
        data: {
                action:         'check_affected_objects',
                host:            form.find('INPUT[name="params.host"]').val(),
                service:         form.find('INPUT[name="params.service"]').val(),
                hostgroup:       form.find('INPUT[name="params.hostgroup"]').val(),
                servicegroup:    form.find('INPUT[name="params.servicegroup"]').val(),
                template:        form.find('SELECT[name=template]').val(),
                backends:        backends,
                backends_toggle: (form.find('INPUT[name=backends_toggle]').val() || form.find('INPUT[name=report_backends_toggle]').val()),
                param:           form.serialize()
        },
        type: 'POST',
        cache: false,
        success: function(data) {
            hideElement('reports_waiting');
            showElement(span2[0].id);
            var msg = "none";
            if(data.hosts > 0 && data.services > 0) {
                msg = data.hosts + " host"+(data.hosts == 1 ? '' : 's')+", "+data.services+" service"+(data.services == 1 ? '' : 's');
            }
            else if(data.hosts > 0 && data.services == 0) {
                msg = data.hosts + " host"+(data.hosts == 1 ? '' : 's');
            }
            else if(data.hosts == 0 && data.services > 0) {
                msg = data.services+" service"+(data.services == 1 ? '' : 's');
            }
            span1.removeClass('error');
            span2.removeClass('error');
            span1.attr('title', '');
            span2.attr('title', '');
            span2.html(msg);
            if(data['too_many'] != undefined && data['too_many'] == 1) {
                span1.addClass('error');
                span2.addClass('error');
                span1.attr('title', 'too many objects, please use more specific filter');
                span2.attr('title', 'too many objects, please use more specific filter');
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            hideElement('reports_waiting');
            showElement(span2[0].id);
            thruk_message(1, 'getting affected objects failed: - ' + jqXHR.status + ' ' + errorThrown);
        }
    });
}
