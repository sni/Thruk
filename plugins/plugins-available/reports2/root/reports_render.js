/* some page rendering functions have to take
 * place after the first html rendering.
 * ex.: page wrapping tables
 */
jQuery(document).ready(function() {
    split_paged_tables();
});

/* split too height tables in several pages */
function split_paged_tables() {
    jQuery('TABLE.paged_table').each(function(nr, table) {
        table = jQuery(table);
        var table_height = table.height();
        var matches = table.attr('class').match(/max_height_(\d+)/);
        if(matches && matches[1] < table_height) {
            split_table(table, parseInt(matches[1]));

            // reorder page numbers
            var page = 0;
            jQuery("DIV.footer").each(function(nr, div) {
                div.innerHTML = page++;
            });
        }
    });
}

/* split a table into smaller chunks */
function split_table(table, max_height) {
    var page = table.closest('DIV.page');
    var cloned = page.clone();
    page.after(cloned);

    // find rows till max height and remove all rows below
    var firstrow, top, lastrow;
    table.find('TBODY > TR').each(function(nr, tr) {
        if(nr == 0) {
            firstrow = tr;
            top = jQuery(firstrow).position().top;
        } else {
            var tr_bottom = jQuery(tr).position().top + jQuery(tr).height();
            if(tr_bottom > top + max_height) {
                if(lastrow == undefined) {
                    lastrow = nr;
                }
                jQuery(tr).remove();
            }
        }
    });

    // find rows on the cloned table and remove all from the page above
    // except first row
    cloned.find('TABLE.paged_table > TBODY > TR').each(function(nr, tr) {
        if(nr > 0 && nr < lastrow ) {
            jQuery(tr).remove();
        }
    });
    var cloned_table     = cloned.find('TABLE.paged_table');
    var new_table_height = cloned_table.height();
    if(new_table_height > max_height) {
        split_table(cloned_table, max_height);
    }
}