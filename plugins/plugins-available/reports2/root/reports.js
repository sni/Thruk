/* initialize all buttons */
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
    if(tmpDiv.find('TR.js-report-options').length == 0) {
        window.setTimeout(update_reports_type_step2, 100);
        return;
    }

    // replace settings
    jQuery('TR.js-report-options').remove();
    tmpDiv.find('TR.js-report-options').insertAfter('#new_reports_options')

    // scroll to report settings
    jQuery('TR.js-report-options TD').effect('highlight', {}, 1000);
    jQuery([document.documentElement, document.body]).animate({
        scrollTop: jQuery("#report_type").offset().top
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
        jQuery('#reportsTable .js-usercol').each(function(nr, el) {
            showElement(el);
        });
    } else {
        jQuery('#reportsTable .js-usercol').each(function(nr, el) {
            hideElement(el);
        });
    }

    if(typ == 'all') {
        jQuery('#reportsTable TR').each(function(nr, el) {
            jQuery(el).removeClass('hidden');
        });
    } else {
        jQuery('#reportsTable TR').each(function(nr, el) {
            if(nr > 0) {
                if(jQuery(el).hasClass(typ)) {
                    jQuery(el).removeClass('hidden');
                } else {
                    jQuery(el).addClass('hidden');
                }
            }
        });
    }

    jQuery(".js-tabs").removeClass("active");
    if(typ == 'my')          { jQuery('#view1').addClass('active') }
    else if(typ == 'public') { jQuery('#view2').addClass('active') }
    else if(typ == 'all')    { jQuery('#view3').addClass('active') }
    else                     { jQuery('#view1').addClass('active') }
    set_hash(typ, 1);

    updatePagerCount('reportsTable');
}

/* collect total number of affected hosts and services */
var reports_update_affected_sla_objects_running = "";
function reports_update_affected_sla_objects(input) {
    var form = jQuery(input).closest('FORM');

    // only useful if there is a affected objects output field
    if(form.find('TR.report_type_affected_sla_objects SPAN.value').length == 0) {
        return;
    }

    var span1 = form.find('TR.report_type_affected_sla_objects SPAN.name');
    var span2 = form.find('TR.report_type_affected_sla_objects SPAN.value');
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
        console.log(e);
    }

    form = jQuery(form).clone();
    jQuery(form).find(".template").remove();

    var data = {
        action:         'check_affected_objects',
        emptyok:        '1',
        template:        form.find('SELECT[name=template]').val(),
        backends:        backends,
        backends_toggle: (form.find('INPUT[name=backends_toggle]').val() || form.find('INPUT[name=report_backends_toggle]').val()),
        param:           form.serialize()
    };
    var dataStr = JSON.stringify(data);
    if(reports_update_affected_sla_objects_running == dataStr) {
        return;
    }
    reports_update_affected_sla_objects_running = dataStr;
    showElement('reports_waiting');
    hideElement(span2[0].id);
    jQuery.ajax({
        url:  'reports2.cgi',
        data: data,
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
            span1.removeClass('textALERT');
            span2.removeClass('textALERT');
            span1.attr('title', '');
            span2.attr('title', '');
            span2.html(msg);
            if(data['too_many'] != undefined && data['too_many'] == 1) {
                span1.addClass('textALERT');
                span2.addClass('textALERT');
                span1.attr('title', 'too many objects, please use more specific filter');
                span2.attr('title', 'too many objects, please use more specific filter');
            }
            if(data['error']) {
                console.log('getting affected objects failed: ' + data['error']);
            }
        },
        error: function(jqXHR, textStatus, errorThrown) {
            thruk_xhr_error('getting affected objects failed: ', '', textStatus, jqXHR, errorThrown, true);
            hideElement('reports_waiting');
            showElement(span2[0].id);
            span2.html("&nbsp;");
        }
    });
}
