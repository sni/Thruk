TP.trendIconsetsStore = Ext.create('Ext.data.Store', {
    fields: ['name', 'sample', 'value', 'fileset'],
    proxy: {
        type: 'ajax',
        url:  'panorama.cgi?task=userdata_trendiconsets',
        reader: {
            type: 'json',
            root: 'data'
        }
    },
    autoLoad: true,
    data : thruk_trendiconset_data
});

Ext.define('TP.IconWidgetAppearanceTrend', {

    alias:  'tp.icon.appearance.trend',

    defaultDrawItem: true,
    defaultDrawIcon: true,
    shrinkable:      true,

    constructor: function(config) {
        var me = this;
        Ext.apply(me, config);
    },

    /* always change icon, even on inactive tabs */
    updateRenderAlways: function(xdata) {
        this.iconSetSourceFromState(xdata);
    },

    iconSetSourceFromState: function(xdata, retry) {
        var This  = this;
        var panel = This.panel;
        if(retry == undefined) { retry = 0; } else { retry++; }
        if(xdata       == undefined) { xdata = panel.xdata; }
        if(xdata.stateHist == undefined) { xdata.stateHist = panel.xdata.stateHist; }
        var tab   = Ext.getCmp(panel.panel_id);
        if(!panel.icon) {
            panel.setRenderItem(xdata);
            return;
        }
        var iconsetName = xdata.appearance.trendiconset;
        if(!iconsetName) { iconsetName = "default_16"; }
        var newSrc = 'unknown';

        // get iconset from store
        var rec = TP.trendIconsetsStore.findRecord('value', iconsetName);
        var obj;
        if(rec == null) {
            newSrc = Ext.BLANK_IMAGE_URL;
        }
        else if(panel.iconType == 'host') {
            obj = panel.host;
        } else {
            obj = panel.service;
        }

        if(xdata.stateHist == undefined) { xdata.stateHist = {}; }
        if(xdata.appearance["trendsource"]) {
            var matches = xdata.appearance["trendsource"].match(/^perfdata:(.*)$/);
            if(matches && matches[1]) {

                var key = matches[1];
                var macros = TP.getPanelMacros(panel);
                var unit;
                var now      = Number(new Date().getTime() / 1000).toFixed(0);

                var rangevs  = TP.timeframe2seconds(xdata.appearance.trendrangevs);
                var offsetvs = TP.timeframe2seconds(xdata.appearance.trendoffsetvs);
                var startvs  = now - rangevs - offsetvs;
                var endvs    = now - offsetvs;

                var rangein  = TP.timeframe2seconds(xdata.appearance.trendrangein || '0m');
                var startin  = now - rangein;
                var endin    = now;

                var delete_before = now;
                if(xdata.appearance.trendfunctionin != 'current') {
                    delete_before = startin;
                }
                if(xdata.appearance.trendfunctionvs != 'fixed' && delete_before > startvs) {
                    delete_before = startvs;
                }

                /* try to fill performance data stateHist from pnp4nagios (every hour) */
                if(This.lastFetch == undefined || This.lastFetch < (now - 3600)) {
                    var pnp = This.fetchGraphValues(key, panel, obj, xdata.stateHist, delete_before, now, function() {
                        This.iconSetSourceFromState(xdata, retry);
                    });
                    if(pnp) { return; }
                }

                if(macros.perfdata[key]) {
                    var p = macros.perfdata[key];
                    var r = TP.getPerfDataMinMax(p, 100);
                    unit = p.unit;
                    if(xdata.stateHist[key] == undefined) { xdata.stateHist[key] = []; }
                    if(xdata.stateHist[key].length == 0 || xdata.stateHist[key][xdata.stateHist[key].length-1][0] != obj.last_check) {
                        xdata.stateHist[key].push([obj.last_check, p.val]);
                        // cleanup old values (only in locked mode, so we do not delete the history just because someone trys different settings)
                        if(panel.locked) {
                            var newStateHist = {};
                            if(xdata.appearance.trendfunctionin != 'current' || xdata.appearance.trendfunctionvs != 'fixed') {
                                var data = xdata.stateHist[key];
                                newStateHist[key] = [];
                                for(var nr=0; nr<data.length; nr++) {
                                    if(data[nr][0] > delete_before) {
                                        newStateHist[key].push(data[nr]);
                                    }
                                }
                            }
                            xdata.stateHist = newStateHist;
                        }
                        panel.saveIconsStates();
                    }
                }

                var labelValues = {};
                if(xdata.stateHist[key]) {
                    var data = xdata.stateHist[key];

                    /* calculate `compare` value with given function */
                    var tmp     = This.getBaseValue(xdata.appearance.trendfunctionin, data, startin, endin);
                    var cur     = tmp.base;
                    var countin = tmp.count;

                    /* calculate `against` value with given function */
                    tmp         = This.getBaseValue(xdata.appearance.trendfunctionvs, data, startvs, endvs, xdata.appearance.trendfixedvs);
                    var countvs = tmp.count;
                    var base    = tmp.base;

                    /* try to fetch performance data from pnp4nagios if none matched (not more than every 5 minutes) */
                    if(countvs == 0 && retry == 0 && This.lastFetch < (now - 300)) {
                        var pnp = This.fetchGraphValues(key, panel, obj, xdata.stateHist, delete_before, now, function() {
                            This.iconSetSourceFromState(xdata, retry);
                        });
                        if(pnp) { return; }
                    }

                    var trendcalculationhint = '';
                    /* select image from base */
                    if(obj == undefined && xdata.state == 3) {
                        newSrc = 'unknown';
                        trendcalculationhint = 'host/service not found -> unknown';
                    }
                    else if(!macros.perfdata[key] && obj != undefined) {
                        newSrc = 'unknown';
                        trendcalculationhint = 'got no performance data for '+key+' -> unknown';
                    }
                    else if(base != undefined) {
                        /* getting trend with zero base is hard because the change would be unlimited */
                        newSrc = 'neutral';
                        var change;
                        if(base === 0 && cur === 0) {
                            change = 0;
                        } else {
                            if(base === 0) { base = 0.000001; }
                        }
                        change = ((cur - base) / base) * 100;
                        if(     xdata.appearance.trendverybad  > 0 && change > xdata.appearance.trendverybad)  { newSrc = 'very_bad'; }
                        else if(xdata.appearance.trendverybad  < 0 && change < xdata.appearance.trendverybad)  { newSrc = 'very_bad'; }
                        else if(xdata.appearance.trendbad      > 0 && change > xdata.appearance.trendbad)      { newSrc = 'bad'; }
                        else if(xdata.appearance.trendbad      < 0 && change < xdata.appearance.trendbad)      { newSrc = 'bad'; }
                        else if(xdata.appearance.trendverygood > 0 && change > xdata.appearance.trendverygood) { newSrc = 'very_good'; }
                        else if(xdata.appearance.trendverygood < 0 && change < xdata.appearance.trendverygood) { newSrc = 'very_good'; }
                        else if(xdata.appearance.trendgood     > 0 && change > xdata.appearance.trendgood)     { newSrc = 'good'; }
                        else if(xdata.appearance.trendgood     < 0 && change < xdata.appearance.trendgood)     { newSrc = 'good'; }

                        var baseFormat = '%d';
                        if(     base < 0.00001 && base > -0.00001) { baseFormat = '%s';   }
                        else if(base < 0.0001  && base > -0.0001)  { baseFormat = '%.7f'; }
                        else if(base < 0.001   && base > -0.001)   { baseFormat = '%.6f'; }
                        else if(base < 0.01    && base > -0.01)    { baseFormat = '%.5f'; }
                        else if(base < 0.1     && base > -0.1)     { baseFormat = '%.4f'; }
                        else if(base < 1       && base > -1)       { baseFormat = '%.3f'; }
                        else if(base < 10      && base > -10)      { baseFormat = '%.2f'; }
                        else if(base < 100     && base > -100)     { baseFormat = '%.1f'; }
                        labelValues = { against: sprintf(baseFormat, base), compare: sprintf(baseFormat, cur), result: sprintf("%.2f", change) };
                        if(xdata.appearance.trendfunctionin == 'current') {
                            trendcalculationhint = sprintf("compare current value -> "+baseFormat+"%s<br>",
                                                           cur,
                                                           (unit || '')
                                                );
                        } else {
                            trendcalculationhint = sprintf("compare %s value over %d value%s in timerange (%s - %s) -> "+baseFormat+"%s<br>",
                                                           xdata.appearance.trendfunctionin,
                                                           countin,
                                                           countin != 1 ? 's' : '',
                                                           strftime("%H:%M", startin),
                                                           strftime("%H:%M", endin),
                                                           cur,
                                                           (unit || '')
                                                );
                        }
                        if(xdata.appearance.trendfunctionvs == 'fixed') {
                            trendcalculationhint += sprintf("against fixed value -> "+baseFormat+"%s<br>",
                                                           base,
                                                           (unit || '')
                                                );
                        } else {
                            trendcalculationhint += sprintf("against %s over %d value%s in timerange (%s - %s) -> "+baseFormat+"%s<br>",
                                                           xdata.appearance.trendfunctionvs,
                                                           countvs,
                                                           countvs != 1 ? 's' : '',
                                                           strftime("%H:%M", startvs),
                                                           strftime("%H:%M", endin),
                                                           base,
                                                           (unit || '')
                                                );
                        }
                        trendcalculationhint += sprintf("= %.2f%% -> %s",
                                                       change,
                                                       newSrc.replace('_', '')
                                            );
                    } else {
                        newSrc = 'neutral';
                        trendcalculationhint = 'not enough data to calculate current image -> neutral';
                    }

                    if(trendcalculationhint && TP.iconSettingsWindow && TP.iconSettingsWindow.panel.id == panel.id) {
                        Ext.getCmp('trendcalculationhint').update(trendcalculationhint);
                    }
                }
                /* make calculation hints available in labels */
                if(obj) {
                    if(!obj.trend) {
                        /* first run, reschedule label update */
                        var tab = Ext.getCmp(panel.panel_id);
                        tab.scheduleRedrawAllLabels();
                    }
                    obj.trend = labelValues;
                }
            }
        }

        if(rec != null && rec.data.fileset[newSrc]) {
            newSrc = '../usercontent/images/trend/'+iconsetName+'/'+rec.data.fileset[newSrc];
        }
        if(panel.src != undefined && panel.src != newSrc && panel.locked && panel.el) {
            TP.timeouts['timeout_' + panel.id + '_flicker'] = window.setTimeout(Ext.bind(TP.flickerImg, panel, [panel.el.id]), 200);
        }
        panel.src = newSrc;
        panel.icon.setAttributes({src: newSrc}).redraw();
        panel.iconFixSize(xdata);
        if(!TP.isThisTheActiveTab(panel)) { panel.hide(); }
    },

    getBaseValue: function(func, data, start, end, fixed) {
        var count = 0;
        var base  = 0;
        if(func == 'current') {
            base = data[data.length-1][1];
            count++;
        }
        else if(func == 'fixed') {
            base = fixed;
            count++;
        }
        else if(func == "average") {
            var sum = 0;
            for(var nr=0; nr<data.length; nr++) {
                if(data[nr][0] > start && data[nr][0] < end) {
                    sum = sum + data[nr][1];
                    count++;
                }
            }
            base = sum / count;
        }
        else if(func == "median") {
            var raw = [];
            for(var nr=0; nr<data.length; nr++) {
                if(data[nr][0] > start && data[nr][0] < end) {
                    count++;
                    raw.push(data[nr][1])
                }
            }
            base = TP.median(raw);
        }
        return({base: base, count: count});
    },

    fetchGraphValues: function(key, panel, obj, stateHist, start, end, finishCallback) {
        if(!obj) { return(false); }
        var url = obj.action_url_expanded;
        if(!url) { return(false); }
        url = url.replace(/'.*$/, '');
        url = url.replace(/\/graph\?/, '/xport/json/?');
        if(!url.match(/pnp/)) { return(false); }
        var now = Number(new Date().getTime() / 1000).toFixed(0);
        if(start == undefined) { start = now-(86400*3); }
        if(end   == undefined) { end   = now; }
        url += '&start='+start;
        url += '&end='+end;
        this.lastFetch = Number(new Date().getTime() / 1000).toFixed(0);
        Ext.Ajax.cors                = true;
        Ext.Ajax.useDefaultXhrHeader = false;
        Ext.Ajax.request({
            url:     url,
            method: 'POST',
            callback: function(options, success, response) {
                var tmp  = TP.getResponse(panel, response);
                if(tmp && tmp.meta && tmp.meta.legend && tmp.meta.legend.entry) {
                    for(var nr=0; nr<tmp.meta.legend.entry.length; nr++) {
                        var legend = tmp.meta.legend.entry[nr];
                        var start  = Number(tmp.meta.start);
                        var step   = Number(tmp.meta.step);
                        var matches = legend.match(/^(.*)_AVERAGE$/);
                        if(matches && matches[1] == key) {
                            stateHist[key] = [];
                            for(var x=0; x<tmp.data.row.length; x++) {
                                stateHist[key].push([start, Number(tmp.data.row[x].v[nr])]);
                                start = start+step;
                            }
                        }
                    }
                    panel.saveIconsStates();
                }
                if(finishCallback) {
                    finishCallback();
                }
            }
        });
        return(true);
    },

    getAppearanceTabItems: function(panel) {
        return([{
            fieldLabel:   'Icon Set',
            id:           'trendiconset_field',
            xtype:        'combobox',
            name:         'trendiconset',
            cls:          'trend',
            store:         TP.trendIconsetsStore,
            value:        '',
            displayField: 'name',
            valueField:   'value',
            listConfig : {
                getInnerTpl: function(displayField) {
                    return '<div class="x-combo-list-item"><img src="{sample}" height=16 width=16 style="vertical-align:top; margin-right: 3px;">{name}<\/div>';
                }
            },
            listeners: {
                change: function(This) { TP.iconSettingsGlobals.renderUpdate(undefined, true); }
            }
        }, {
            xtype:      'panel',
            cls:        'trend',
            html:       'Place image sets in: '+usercontent_folder+'/images/trend/',
            bodyCls:    'form-hint',
            padding:    '0 0 10 60',
            border:      0
        }, {
            fieldLabel:   'Source',
            cls:          'trend',
            name:         'trendsource',
            xtype:        'combobox',
            id:           'trendsourceStore',
            displayField: 'name',
            valueField:   'value',
            queryMode:    'local',
            store:       { fields: ['name', 'value'], data: [] },
            editable:      false,
            value:         panel.xdata.appearance.trendsource,
            listeners:   { focus: function() { TP.iconSettingsGlobals.perfDataUpdate() }, change: function() { TP.iconSettingsGlobals.renderUpdate(); } },
        }, {
            fieldLabel: 'Compare',
            xtype:      'fieldcontainer',
            cls:        'trend',
            layout:    { type: 'hbox', align: 'stretch' },
            defaults: {
                listeners: {
                    change: function() {
                        TP.trendCheckFormVisibility(panel);
                        TP.iconSettingsGlobals.renderUpdate();
                    },
                    afterrender: function() {
                        TP.trendCheckFormVisibility(panel);
                    }
                }
            },
            items: [{
                    xtype:      'combobox',
                    name:       'trendfunctionin',
                    id:         'trendfunctionin',
                    editable:    false,
                    valueField: 'value',
                    displayField: 'name',
                    value:       panel.xdata.appearance.trendfunctionin || 'current',
                    store        : Ext.create('Ext.data.Store', {
                        fields: ['value', 'name'],
                        data:   [{name: 'current value', value: 'current'}, {name: 'average', value: 'average'}, {name: 'median', value: 'median'}]
                    }),
                    flex: 1
                },
                {   xtype:      'label',
                    text:       'over the last:',
                    margins:    {top: 3, right: 2, bottom: 0, left: 10},
                    id:         'trendrangeinlabel'
                }, {
                    xtype:      'combobox',
                    name:       'trendrangein',
                    id:         'trendrangein',
                    valueField: 'value',
                    displayField: 'name',
                    value:       panel.xdata.appearance.trendrangein || '5m',
                    store        : Ext.create('Ext.data.Store', {
                        fields: ['value', 'name'],
                        data:   [{name: '5m',  value: '5m'},
                                 {name: '10m', value: '10m'},
                                 {name: '30m', value: '30m'},
                                 {name: '60m', value: '60m'}
                                ]
                    }),
                    flex: 1
                }]
        }, {
            fieldLabel: 'Against',
            xtype:      'fieldcontainer',
            cls:        'trend',
            layout:    { type: 'hbox', align: 'stretch' },
            defaults: { listeners: { change: function() { TP.trendCheckFormVisibility(panel); TP.iconSettingsGlobals.renderUpdate() } } },
            items: [{
                    xtype:      'combobox',
                    name:       'trendfunctionvs',
                    id:         'trendfunctionvs',
                    editable:    false,
                    valueField: 'value',
                    displayField: 'name',
                    value:       panel.xdata.appearance.trendfunctionvs || 'average',
                    store        : Ext.create('Ext.data.Store', {
                        fields: ['value', 'name'],
                        data:   [{name: 'average', value: 'average'}, {name: 'median', value: 'median'}, {name: 'fixed', value: 'fixed'}]
                    }),
                    flex: 1
                },
                { xtype: 'label', text: 'over:', margins: {top: 3, right: 2, bottom: 0, left: 10}, id: 'trendoverlabelvs' },
                {
                    xtype:      'combobox',
                    name:       'trendrangevs',
                    id:         'trendrangevs',
                    valueField: 'value',
                    displayField: 'name',
                    value:       panel.xdata.appearance.trendrangevs || '60m',
                    store        : Ext.create('Ext.data.Store', {
                        fields: ['value', 'name'],
                        data:   [{name: '5m',  value: '5m'},
                                 {name: '10m', value: '10m'},
                                 {name: '30m', value: '30m'},
                                 {name: '60m', value: '60m'},
                                 {name: '3h',  value: '3h'},
                                 {name: '6h',  value: '6h'},
                                 {name: '12h', value: '12h'},
                                 {name: '1d',  value: '1d'}
                                ]
                    }),
                    flex: 1
                },
                { xtype: 'label', text: 'with an offset of:', margins: {top: 3, right: 2, bottom: 0, left: 10}, id: 'trendoffsetlabelvs' },
                {
                    xtype:      'combobox',
                    name:       'trendoffsetvs',
                    id:         'trendoffsetvs',
                    valueField: 'value',
                    displayField: 'name',
                    value:       panel.xdata.appearance.trendoffsetvs || '0m',
                    store        : Ext.create('Ext.data.Store', {
                        fields: ['value', 'name'],
                        data:   [{name: '0m',  value: '0m'},
                                 {name: '5m',  value: '5m'},
                                 {name: '10m', value: '10m'},
                                 {name: '30m', value: '30m'},
                                 {name: '60m', value: '60m'},
                                 {name: '3h',  value: '3h'},
                                 {name: '6h',  value: '6h'},
                                 {name: '12h', value: '12h'},
                                 {name: '1d',  value: '1d'}
                                ]
                    }),
                    flex: 1
                },
                { xtype: 'label', text: 'of:', margins: {top: 3, right: 2, bottom: 0, left: 10}, id: 'trendfixedlabelvs' },
                { xtype: 'numberfield', name: 'trendfixedvs', id: 'trendfixedvs', value: panel.xdata.appearance.trendfixedvs || '1' }]
        }, {
            xtype:      'panel',
            cls:        'trend',
            html:       '',
            id:         'trendcalculationhint',
            bodyCls:    'form-hint',
            padding:    '0 0 10 60',
            border:      0
        }, {
            fieldLabel:     'Thresholds',
            xtype:          'fieldcontainer',
            cls:            'trend',
            layout:         { type: 'table', columns: 4 },
            defaults:      { listeners: { change: function() { TP.iconSettingsGlobals.renderUpdate() } } },
            items: [
                { xtype: 'label', text: 'very good:', tdAttrs: { style: 'padding: 0 2px 0 0;' } },
                { xtype: 'numberunit', name: 'trendverygood', unit: '%', width: 65, value: panel.xdata.appearance.trendverygood || '-10%' },
                { xtype: 'label', text: 'good:', tdAttrs: { style: 'padding: 0 2px 0 20px;' } },
                { xtype: 'numberunit', name: 'trendgood', unit: '%', width: 65, value: panel.xdata.appearance.trendgood || '-5%' },

                { xtype: 'label', text: 'very bad:', tdAttrs: { style: 'padding: 0 2px 0 0;' } },
                { xtype: 'numberunit', name: 'trendverybad', unit: '%', width: 65, value: panel.xdata.appearance.trendverybad || '10%' },
                { xtype: 'label', text: 'bad:', tdAttrs: { style: 'padding: 0 2px 0 20px;' } },
                { xtype: 'numberunit', name: 'trendbad', unit: '%', width: 65, value: panel.xdata.appearance.trendbad || '5%' },
            ]
         }]);
    }
});

TP.trendCheckFormVisibility = function(panel) {
    var trendfunctionin = Ext.getCmp('trendfunctionin').getValue();
    if(trendfunctionin == 'current' || trendfunctionin == '') {
        Ext.getCmp('trendrangein').setDisabled(true);
        if(Ext.getCmp('trendrangeinlabel').el && Ext.getCmp('trendrangeinlabel').el.dom) {
            Ext.getCmp('trendrangeinlabel').el.dom.style.opacity = 0.3;
        }
    } else {
        Ext.getCmp('trendrangein').setDisabled(false);
        if(Ext.getCmp('trendrangeinlabel').el && Ext.getCmp('trendrangeinlabel').el.dom) {
            Ext.getCmp('trendrangeinlabel').el.dom.style.opacity = 1;
        }
    }

    var trendfunctionvs = Ext.getCmp('trendfunctionvs').getValue();
    if(trendfunctionvs == 'fixed') {
        Ext.getCmp('trendfixedvs').show();
        Ext.getCmp('trendfixedlabelvs').show();
        Ext.getCmp('trendoffsetlabelvs').hide();
        Ext.getCmp('trendoffsetvs').hide();
        Ext.getCmp('trendoverlabelvs').hide();
        Ext.getCmp('trendrangevs').hide();
    } else {
        Ext.getCmp('trendfixedvs').hide();
        Ext.getCmp('trendfixedlabelvs').hide();
        Ext.getCmp('trendoffsetlabelvs').show();
        Ext.getCmp('trendoffsetvs').show();
        Ext.getCmp('trendoverlabelvs').show();
        Ext.getCmp('trendrangevs').show();
    }
}
