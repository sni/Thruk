function zoomOut(plot) {
    jQuery.each(plot.getXAxes(), function(_, axis) {
        var opts = axis.options;
        opts.min = undefined;
        opts.max = undefined;
    });
    croshair_locked = false;
    plot.unlockCrosshair();
    try {
        plot.resize();
        plot.setupGrid();
    } catch(e) {}
    plot.draw();
    jQuery('#raw_top').find("tr:gt(0)").remove();
    jQuery('#raw_top_div').css({'display': 'none'});
}

var updateDetailsTableTimestamp;
function updateDetailsTable(index, fetch) {
    var keys = [];
    jQuery.each(plots, function(name, plot) { keys.push(name); });
    var timestamp = plots[keys[0]].getData()[0].data[index][0];
    var date = new Date(timestamp);
    jQuery('#time').html(date.toLocaleString());

    if(plots['load']) {
        jQuery('#load1').html(plots['load'].getData()[0].data[index][1]);
        jQuery('#load5').html(plots['load'].getData()[1].data[index][1]);
        jQuery('#load15').html(plots['load'].getData()[2].data[index][1]);
    }

    if(plots['cpu']) {
        jQuery('#cpu_us').html(plots['cpu'].getData()[0].data[index][1]+"%");
        if(plots['cpu'].getData().length >= 4) {
            jQuery('#cpu_sy').html(plots['cpu'].getData()[1].data[index][1]+"%");
            jQuery('#cpu_ni').html(plots['cpu'].getData()[2].data[index][1]+"%");
            jQuery('#cpu_wa').html(plots['cpu'].getData()[3].data[index][1]+"%");
        }
    }

    if(plots['mem']) {
        jQuery('#mem').html(plots['mem'].getData()[0].data[index][1]+"MB");
        if(plots['mem'].getData().length >= 4) {
            jQuery('#mem_used').html(_ifNotNull(plots['mem'].getData()[1].data[index][1], "MB"));
            jQuery('#buffers').html(_ifNotNull(plots['mem'].getData()[2].data[index][1], "MB"));
            jQuery('#cached').html(_ifNotNull(plots['mem'].getData()[3].data[index][1], "MB"));
        }
    }

    if(plots['swap']) {
        jQuery('#swap').html(plots['swap'].getData()[0].data[index][1]+"MB");
        jQuery('#swap_used').html(plots['swap'].getData()[1].data[index][1]+"MB");
    }

    jQuery('#detailstable').css({display: 'inherit'});

    updateDetailsTableTimestamp = timestamp;
    if(fetch) {
        fetchTopData(50);
    } else {
        jQuery('#raw_top').find("tr:gt(0)").remove();
        jQuery('#raw_top_div').css({'display': 'none'});
    }
}

var fetchTopDataInterval;
function fetchTopData(delay) {
    if(delay == undefined) {
        delay = 2000;
    }
    window.clearInterval(fetchTopDataInterval);
    fetchTopDataInterval = window.setTimeout(fetchTopDataDo, delay);
}

function fetchTopDataDo() {
    /* fetch top data */
    jQuery.ajax({
        url: url_prefix + 'cgi-bin/omd.cgi?action=top_data&time='+Math.floor(updateDetailsTableTimestamp/1000)+"&folder=[% folder | uri %]",
        type: 'POST',
        success: function(data) {
            removeParams['pid'] = true;
            var uri = 'omd.cgi?action=top_details&folder=[% folder | uri %]&expand=1&time='+Math.floor(updateDetailsTableTimestamp/1000);
            if(data && data.raw) {
                jQuery('#raw_top').find("tr:gt(0)").remove();
                jQuery.each(data.raw, function(_, row) {
                    var newRow = '<tr>';
                    jQuery.each(row, function(i, cell) {
                        if(i == 0) {
                            newRow += '<td><a href="'+uri+'&pid='+cell+'">'+cell+'<\/a><\/td>';
                        } else if(i == 4) {
                            newRow += '<td>'+row[12]+'m<\/td>';
                        } else if(i == 5) {
                            newRow += '<td>'+row[13]+'m<\/td>';
                        } else if(i <= 11) {
                            newRow += '<td>'+cell+'<\/td>';
                        }
                    });
                    newRow += '<\/tr>';
                    jQuery('#raw_top tbody').append(newRow);
                });
                jQuery('#raw_top_div').css({'display': 'inherit'});
                jQuery('#raw_top').trigger("update");
                jQuery('#filename').html(data.file);
                _reapply_table_sorter();
            } else {
                jQuery('#raw_top').find("tr:gt(0)").remove();
                jQuery('#raw_top_div').css({'display': 'none'});
            }
        }
    });
}

function _getTooltipFromSeries(date, series, index, unit, skipEmpty, toFixed) {
    var tooltip = "<table class='tooltip'><tr><td class='date'>"+date+"</td>";
    var x = 0;
    jQuery.each(series, function(i, s) {
        x++;
        if(!skipEmpty || s.data[index][1] != 0) {
            var val = s.data[index][1];
            if(toFixed != undefined) { val = Number(val).toFixed(toFixed); }
            if(x > 1) {
                tooltip += "<tr><td></td>";
            }
            tooltip += "<td class='var'>"+s.label + ":</td>";
            tooltip += "<td class='val'>"+_ifNotNull(val, unit)+"</td></tr>";
        }
    });
    tooltip += "</table>";
    return(tooltip);
}

function _max_or_default(fallback, series) {
    var max = fallback;
    jQuery.each(series, function(_, s) {
        jQuery.each(s.data, function(_, d) {
            if(max < d[1]) { max = d[1]; }
        });
    });
    return(max);
}

function _trim_number(num) {
    // reduce precision for numbers like: 0.6000000000000001
    var str = ""+num;
    if(str.match(/^\d\..*0+1$/)) {
        num = Number(str.replace(/^(\d\.\d).*0+1$/, "$1"));
    }
    return(num);
}

function _reapply_table_sorter() {
    var table = document.getElementById('raw_top');
    if(table) {
        table.dataset["search"] = "";
    }
    jQuery("#table_search_input").focus();
}

function _ifNotNull(num, unit) {
    if(!unit) { unit = ""; }
    if(num != null) {
        return(num+unit);
    }
    return("");
}

function _backgroundColor() {
    var backgroundColor = "#F0F0ED";
    if(jQuery("HTML").hasClass("dark")) {
        backgroundColor = "#333";
    }
    return(backgroundColor);
}