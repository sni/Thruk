/* some page rendering functions have to take
 * place after the first html rendering.
 * ex.: page wrapping tables
 */

var page_renumber_required = 0;
function reports_body_end() {
    set_vertical_header();
    split_paged_tables();

    // reorder page numbers
    if(page_renumber_required) {
        var page = 0;
        jQuery('DIV.page').each(function(nr, el) {
            jQuery(el).find("DIV.footer").html(page++);
        });
    }

    // insert anchors for easy testing on html pages
    jQuery('DIV.page').each(function(nr, el) {
        jQuery('<a name="page'+(nr+1)+'">').insertBefore(el);
    });
}

/* split too height tables in several pages */
function set_vertical_header() {
    jQuery('TABLE.vertical_header').each(function(x, table) {
        var firstrow = jQuery(table).find('TR')[0];

        // wrap cell content in divs and extract max-width
        var max_width = 20;
        jQuery(firstrow).find('TD, TH').each(function(y, cell) {
            jQuery(cell).html('<div style="white-space:nowrap;">'+cell.innerHTML+'</div>');
            var div = jQuery(jQuery(cell).find('DIV')[0]);
            var width = div.width();
            if(max_width < width) { max_width = width; }
            div.css('width', '18px');
            div.addClass('vertical');
        });
        max_width = max_width + 5;

        jQuery(firstrow).find('TD, TH').each(function(y, cell) {
            jQuery(cell).css('height', max_width+'px');
        });
    });
}

/* split too height tables in several pages */
function split_paged_tables() {
    jQuery('TABLE.paged_table').each(function(nr, table) {
        table = jQuery(table);
        var table_height = table.height();
        var matches = table.attr('class').match(/max_height_(\d+)/);
        if(matches && matches[1] < table_height) {
            split_table(table, parseInt(matches[1]));
            page_renumber_required = 1;
        }
    });
}

/* split a table into smaller chunks */
function split_table(table, max_height) {
    var page = table.closest('DIV.page');
    var cloned = page.clone();
    page.after(cloned);

    // remove things which should stay on the last page only
    page.find('.split_pages_lastpage_only').remove();

    // find rows till max height and remove all rows below
    var num_removed;
    jQuery(table.find('TBODY > TR').toArray().reverse()).each(function(nr, tr) {
        if(table.height() > max_height) {
            jQuery(tr).remove();
        } else {
            num_removed = nr;
            return false;
        }
        return true;
    });
    var num_trs = cloned.find('TABLE.paged_table > TBODY > TR').length;
    var lastrow = num_trs - num_removed;

    // find rows on the cloned table and remove all from the page above
    // except first row
    var headers = 0;
    if(table.hasClass('headers2')) { headers = 1; }
    cloned.find('TABLE.paged_table > TBODY > TR').each(function(nr, tr) {
        if(nr > headers && nr < lastrow ) {
            jQuery(tr).remove();
        }
    });
    var cloned_table     = cloned.find('TABLE.paged_table');
    var new_table_height = cloned_table.height();
    if(new_table_height > max_height) {
        split_table(cloned_table, max_height);
    }
}

/* render the total sla graph */
function render_total_sla_graph(nr, title, data, sla, graph_min_sla, type, label, max_entries_per_page) {
    // split on multiple pages?
    if(data.length > max_entries_per_page) {
        render_total_sla_graph_chunked(nr, title, data, sla, graph_min_sla, type, label, max_entries_per_page);
        return;
    }

    var height = data.length * 20;
    if(height < 300) { height = 300; }
    if(height > 650) { height = 650; }
    jQuery("#flotgraph"+nr).css('height', height+"px");

    var ticks = [];
    jQuery(data).each(function(x, val) {
        ticks.push([x+1, " "]);
    });

    var d1 = {
        label: title,
        color: "rgb(82, 167, 82)",
        bars: { show: true, horizontal: true },
        data: data
    }
    var d2 = {
        color: "rgb(236, 193, 77)",
        lines: { show: true },
        data: [[sla,0], [sla, 9999]]
    }
    jQuery.plot(jQuery("#flotgraph"+nr), [d1,d2], {
        series: {
            bars: {
                show: false,
                barWidth: 0.9,
                align: 'center',
                fillColor: { colors: [ { opacity: 1.0 }, { opacity: 0.6 } ] }
            },
            lines: { show: false, fill: false }
        },
        yaxis: {
            min:   0.5,
            max:   data.length + 0.5,
            ticks: ticks
        },
        xaxis: {
            min:   graph_min_sla,
            max:   100
        },
        legend: { position: 'se' },
        hooks: {
            bindEvents: [
                function(plot, eventHolder) {
                    /* now replace empty lables with offset span */
                    var labelHTML = jQuery('#flotgraph'+nr+' DIV.axis_y DIV');
                    jQuery(label).each(function(x, val) {
                        labelHTML[x].innerHTML = val;
                    });
                }
            ]
        }
    });
    return;
}

/* render graph in multiple chunks / pages */
function render_total_sla_graph_chunked(nr, title, data, sla, graph_min_sla, type, label, max_entries_per_page) {
    page_renumber_required = 1;
    var pages  = Math.ceil(data.length / max_entries_per_page);
    var fpage  = jQuery("#flotgraph"+nr).closest('DIV.page');
    fpage.find("#flotgraph"+nr).attr('id', 'flotgraph'+nr+'_0');
    var lastpage = fpage;
    for(var x = 1; x < pages; x++) {
        var cloned = fpage.clone();
        cloned.find("#flotgraph"+nr+'_0').attr('id', 'flotgraph'+nr+'_'+x);
        cloned.find('SCRIPT').remove();
        lastpage.after(cloned);
        // remove things which should stay on the last page only
        if(x != pages - 1) {
            cloned.find('.split_pages_lastpage_only').remove();
        }
        lastpage = cloned;
    };
    // remove things which should stay on the last page only
    fpage.find('.split_pages_lastpage_only').remove();

    data  = data.reverse();
    label = label.reverse();
    for(var x = 0; x < pages; x++) {
        var data_chunk  = data.splice(0, max_entries_per_page);
        var label_chunk = label.splice(0, max_entries_per_page);
        data_chunk  = data_chunk.reverse();
        label_chunk = label_chunk.reverse();
        // label & data has to be renumbered
        var new_data = [];
        jQuery(data_chunk).each(function(nr, d) {
            new_data.push([d[0], (nr+1)]);
        });
        render_total_sla_graph(nr+'_'+x, title, new_data, sla, graph_min_sla, type, label_chunk, max_entries_per_page);
    }
    return;
}
