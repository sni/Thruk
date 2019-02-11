Ext.define('TP.IconWidgetAppearanceSpeedometer', {

    alias:  'tp.icon.appearance.speedometer',

    constructor: function(config) {
        var me = this;
        Ext.apply(me, config);
    },

    /* update render item on active tab only */
    updateRenderActive: function(xdata, forceColor) {
        this.speedoRender(xdata, forceColor);
    },

    setRenderItem: function(xdata) {
        var panel = this.panel;
        panel.add({
            xtype:       'tp_speedochart',
            store:        [0],
            panel:        panel,
            insetPadding: xdata.appearance.speedomargin > 0 ? xdata.appearance.speedomargin + 20 : 10,
            shadow:       xdata.appearance.speedoshadow,
            donut:        xdata.appearance.speedodonut,
            needle:       xdata.appearance.speedoneedle,
            axis_margin:  xdata.appearance.speedomargin == 0 ? 0.1 : xdata.appearance.speedomargin,
            axis_steps:   xdata.appearance.speedosteps,
            axis_min:     xdata.appearance.speedoaxis_min ? xdata.appearance.speedoaxis_min : 0,
            axis_max:     xdata.appearance.speedoaxis_max ? xdata.appearance.speedoaxis_max : 0,
            listeners: {
                afterrender: function(This, eOpts) {
                    panel.itemRendering = false;
                    panel.chart = This;
                    panel.updateRender(xdata);
                },
                resize: function(This, width, height, oldWidth, oldHeight, eOpts) {
                    panel.updateRender(xdata);
                }
            }
        });
    },

    /* renders speedometer chart */
    speedoRender: function(xdata, forceColor) {
        var panel = this.panel;
        if(xdata == undefined) { xdata = panel.xdata; }
        if(xdata.appearance.type != 'speedometer') { return }
        if(!panel.chart) {
            panel.setRenderItem(xdata);
            return;
        }
        var extraSpace = 0;
        if(!panel.items.getAt || !panel.items.getAt(0)) { return; }
        panel.items.getAt(0).setSize(xdata.appearance.speedowidth, xdata.appearance.speedowidth/1.8);
        panel.setSize(xdata.appearance.speedowidth, xdata.appearance.speedowidth/1.8);
        var colors = {
            pending:  xdata.appearance.speedocolor_pending  ? xdata.appearance.speedocolor_pending  : '#ACACAC',
            ok:       xdata.appearance.speedocolor_ok       ? xdata.appearance.speedocolor_ok       : '#00FF33',
            warning:  xdata.appearance.speedocolor_warning  ? xdata.appearance.speedocolor_warning  : '#FFDE00',
            unknown:  xdata.appearance.speedocolor_unknown  ? xdata.appearance.speedocolor_unknown  : '#FF9E00',
            critical: xdata.appearance.speedocolor_critical ? xdata.appearance.speedocolor_critical : '#FF5B33',
            bg:       xdata.appearance.speedocolor_bg       ? xdata.appearance.speedocolor_bg       : '#DDDDDD'
        };

        // which source to use
        var state  = xdata.state, value = 0, min = 0, max = 100;
        var warn_min, warn_max, crit_min, crit_max;
        var factor = xdata.appearance.speedofactor == '' ? Number(1) : Number(xdata.appearance.speedofactor);
        if(isNaN(factor)) { factor = 1; }

        if(state == undefined) { state = panel.xdata.state; }
        if(xdata.appearance.speedosource == undefined) { xdata.appearance.speedosource = 'problems'; }
        var matchesP = xdata.appearance.speedosource.match(/^perfdata:(.*)$/);
        var matchesA = xdata.appearance.speedosource.match(/^avail:(.*)$/);
        if(matchesP && matchesP[1]) {
            var macros  = TP.getPanelMacros(panel);
            if(macros.perfdata[matchesP[1]]) {
                var p = macros.perfdata[matchesP[1]];
                value = p.val;
                var r = TP.getPerfDataMinMax(p, '?');
                if(Ext.isNumeric(r.max)) {
                    max   = r.max * factor;
                }
                min   = r.min * factor;
                if(Ext.isNumeric(p.warn_min)) { warn_min = p.warn_min * factor; }
                if(Ext.isNumeric(p.warn_max)) { warn_max = p.warn_max * factor; }
                if(Ext.isNumeric(p.crit_min)) { crit_min = p.crit_min * factor; }
                if(Ext.isNumeric(p.crit_max)) { crit_max = p.crit_max * factor; }
            }
        }
        else if(matchesA && matchesA[1]) {
            if(TP.availabilities && TP.availabilities[panel.id] && TP.availabilities[panel.id][matchesA[1]] && TP.availabilities[panel.id][matchesA[1]].last != undefined) {
                value = Number(TP.availabilities[panel.id][matchesA[1]].last);
                max   = 100;
                min   = 0;
            }
        }
        else if(xdata.appearance.speedosource == 'problems' || xdata.appearance.speedosource == 'problems_warn') {
            var totals = panel.getTotals(xdata, colors);
            max = 0;
            Ext.Array.each(totals, function(t,i) {
                max += t.value;
                if(t.name == 'critical' || t.name == 'unknown' || t.name == 'down' || t.name == 'unreachable') {
                    value += t.value;
                }
                if(xdata.appearance.speedosource == 'problems_warn' && t.name == 'warning') {
                    value += t.value;
                }
            });
        }
        // override min / max by option
        if(xdata.appearance.speedomin != undefined && xdata.appearance.speedomin != '') { min = Number(xdata.appearance.speedomin); }
        if(xdata.appearance.speedomax != undefined && xdata.appearance.speedomax != '') { max = Number(xdata.appearance.speedomax); }

        if(panel.chart.axes.getAt(0).minimum != min || panel.chart.axes.getAt(0).maximum != max) {
            if(!isNaN(min) && !isNaN(max)) {
                xdata.appearance.speedoaxis_min = min;
                xdata.appearance.speedoaxis_max = max;
                panel.setRenderItem(xdata);
                return;
            }
        }

        value *= factor;

        /* inverted value? */
        if(xdata.appearance.speedoinvert) {
            value = max - value;
        }
        if(value > max) { value = max; } // value cannot exceed speedo
        if(value < min) { value = min; } // value cannot exceed speedo
        var color_fg = colors['unknown'];
        if(state == 0) { color_fg = colors['ok'];       }
        if(state == 1) { color_fg = colors['warning'];  }
        if(state == 2) { color_fg = colors['critical']; }
        if(state == 3) { color_fg = colors['unknown'];  }
        if(state == 4) { color_fg = colors['pending'];  }

        /* translate host state */
        if(panel.iconType == 'host') {
            if(state == 1) { color_fg = colors['critical']; }
            if(state == 2) { color_fg = colors['warning'];  }
        }

        if(panel.chart.surface.existingGradients == undefined) { panel.chart.surface.existingGradients = {} }

        /* warning / critical thresholds */
        panel.chart.series.getAt(0).ranges = [];
        panel.chart.series.getAt(0).lines  = [];
        if(xdata.appearance.speedo_thresholds == 'undefined') { xdata.appearance.speedo_thresholds = 'line'; }
        if(value == 0) { value = 0.0001; } // doesn't draw anything otherwise
        var color_bg = this.speedoGetColor(colors, 0, forceColor, 'bg');
        if(!!xdata.appearance.speedoneedle) {
            if(xdata.appearance.speedo_thresholds == 'hide') {
                color_bg = this.speedoGetColor(color_fg, xdata.appearance.speedogradient, forceColor)
            }
            else if(xdata.appearance.speedo_thresholds == 'filled') {
                color_bg = this.speedoGetColor(colors, xdata.appearance.speedogradient, forceColor, 'ok')
            }
        }
        panel.chart.series.getAt(0).ranges.push({
            from:  min,
            to:    max,
            color: color_bg
        });
        if(warn_max != undefined) {
            if(xdata.appearance.speedo_thresholds == 'fill') {
                if(warn_min == undefined) {
                    warn_min = warn_max;
                    if(crit_min != undefined) {
                        warn_max = crit_min;
                    }
                    else if(crit_max != undefined) {
                        warn_max = crit_max;
                    }
                    else {
                        warn_max = max;
                    }
                }
                panel.chart.series.getAt(0).ranges.push({
                    from:  warn_min,
                    to:    warn_max,
                    color: this.speedoGetColor(colors, xdata.appearance.speedogradient, forceColor, 'warning')
                });
            }
            else if(xdata.appearance.speedo_thresholds == 'line') {
                panel.chart.series.getAt(0).lines.push({
                    value: warn_max,
                    color: this.speedoGetColor(colors, 0, forceColor, 'warning')
                });
                if(warn_min != undefined && warn_min != warn_max) {
                    panel.chart.series.getAt(0).lines.push({
                        value: warn_min,
                        color: this.speedoGetColor(colors, 0, forceColor, 'warning')
                    });
                }
            }
        }
        if(crit_max != undefined) {
            if(xdata.appearance.speedo_thresholds == 'fill') {
                if(crit_min == undefined) { crit_min = crit_max; crit_max = max; }
                panel.chart.series.getAt(0).ranges.push({
                    from:  crit_min,
                    to:    crit_max,
                    color: this.speedoGetColor(colors, xdata.appearance.speedogradient, forceColor, 'critical')
                });
            }
            else if(xdata.appearance.speedo_thresholds == 'line') {
                panel.chart.series.getAt(0).lines.push({
                    value: crit_max,
                    color: this.speedoGetColor(colors, 0, forceColor, 'critical')
                });
                if(crit_min != undefined && crit_min != crit_max) {
                    panel.chart.series.getAt(0).lines.push({
                        value: crit_min,
                        color: this.speedoGetColor(colors, 0, forceColor, 'critical')
                    });
                }
            }
        }

        if(!xdata.appearance.speedoneedle) {
            panel.chart.series.getAt(0).ranges.push({
                from:  0,
                to:    value,
                color: this.speedoGetColor(color_fg, xdata.appearance.speedogradient, forceColor)
            });
        }
        panel.chart.series.getAt(0).value = value;
        if(panel.chart.series.getAt(0).setValue)   { panel.chart.series.getAt(0).setValue(value); }
        if(xdata.appearance.speedocolor_axis_color) {
            panel.chart.axes.getAt(0).labelArray.forEach(function (el) {
                el.setAttributes({ stroke: xdata.appearance.speedocolor_axis_color, fill: xdata.appearance.speedocolor_axis_color }, true);
            });
        }
        if(panel.chart.series.getAt(0).drawSeries) { panel.chart.series.getAt(0).drawSeries();    }
    },

    speedoGetColor: function(colors, gradient_val, forceColor, type) {
        var panel = this.panel;
        var color;
        if(type != undefined) {
            color = colors[type];
            if(forceColor && forceColor.scope.name == "speedocolor_"+type) { color = forceColor.color; }
        } else {
            color = colors;
            if(forceColor) { color = forceColor.color; }
        }
        if(gradient_val != 0) {
            var gradient = TP.createGradient(color, gradient_val);
            if(panel.chart.surface.existingGradients[gradient.id] == undefined) {
                panel.chart.surface.existingGradients[gradient.id] = true;
                panel.chart.surface.addGradient(gradient);
            }
            return('url(#'+gradient.id+')');
        }
        return(color);
    },

    settingsWindowAppearanceTypeChanged: function() {
        // fill in defaults
        var panel  = this.panel;
        var values = Ext.getCmp('appearanceForm').getForm().getValues();
        if(!values['speedowidth']) {
            var defaultSpeedoSource = 'problems';
            var macros              = TP.getPanelMacros(panel);
            for(var key in macros.perfdata) {
                // use first available performance key as default
                if(defaultSpeedoSource == 'problems') {
                    defaultSpeedoSource = 'perfdata:'+key;
                    break;
                }
            }
            values['speedowidth']             = 180;
            values['speedoshadow']            = false;
            values['speedoneedle']            = false;
            values['speedodonut']             = 0;
            values['speedogradient']          = 0;
            values['speedosource']            = defaultSpeedoSource;
            values['speedomargin']            =  5;
            values['speedosteps']             = 10;
            values['speedocolor_ok']          = '#199C0F';
            values['speedocolor_warning']     = '#CDCD0A';
            values['speedocolor_critical']    = '#CA1414';
            values['speedocolor_unknown']     = '#CC740F';
            values['speedocolor_bg']          = '#DDDDDD';
            values['speedo_thresholds']       = 'line';
            Ext.getCmp('appearanceForm').getForm().setValues(values);
        }
    },

    getAppearanceTabItems: function(panel) {
        return([{
            fieldLabel: 'Size',
            xtype:      'fieldcontainer',
            cls:        'speedometer',
            layout:     'table',
            defaults: { listeners: { change: function() { TP.iconSettingsGlobals.renderUpdate(undefined, true) } } },
            items: [{ xtype: 'label', text: 'Width:', style: 'margin-left: 0; margin-right: 2px;' },
                    { xtype: 'numberunit', name: 'speedowidth', unit: 'px', width: 65, value: panel.xdata.appearance.speedowidth },
                    { xtype: 'label', text: 'Shadow:', style: 'margin-left: 0px; margin-right: 2px;', hidden: true },
                    { xtype: 'checkbox', name: 'speedoshadow', hidden: true },
                    { xtype: 'label', text: 'Needle:', style: 'margin-left: 8px; margin-right: 2px;' },
                    { xtype: 'checkbox', name: 'speedoneedle' },
                    { xtype: 'label', text: 'Donut:', style: 'margin-left: 8px; margin-right: 2px;' },
                    { xtype: 'numberunit', allowDecimals: false, width: 60, name: 'speedodonut', unit: '%' }
                ]
        }, {
            fieldLabel: 'Axis',
            xtype:      'fieldcontainer',
            cls:        'speedometer',
            layout:     'table',
            defaults: { listeners: { change: function() { TP.iconSettingsGlobals.renderUpdate(undefined, true) } } },
            items: [
            { xtype: 'label', text: 'Steps:', style: 'margin-left: 0px; margin-right: 2px;' },
            {
                xtype:      'numberfield',
                allowDecimals: false,
                width:       40,
                name:       'speedosteps',
                step:        1,
                minValue:    0,
                maxValue:    1000
            },
            { xtype: 'label', text: 'Margin:', style: 'margin-left: 8px; margin-right: 2px;' },
            {
                xtype:      'numberunit',
                allowDecimals: false,
                width:       55,
                name:       'speedomargin',
                unit:       'px'
            },
            { xtype: 'label', text: 'Color:', style: 'margin-left: 8px; margin-right: 2px;' },
            {
                xtype:          'colorcbo',
                name:           'speedocolor_axis_color',
                value:           panel.xdata.appearance.speedocolor_axis_color,
                width:           80
            },
            { xtype: 'label', text: 'Thresholds:', style: 'margin-left: 8px; margin-right: 2px;' },
            {
                name:       'speedo_thresholds',
                xtype:      'combobox',
                store:      ['hide', 'line', 'fill'],
                value:      'line',
                editable:    false,
                width:       60
            }
            ]
        }, {
            fieldLabel: 'Colors',
            cls:        'speedometer',
            xtype:      'fieldcontainer',
            layout:      { type: 'table', columns: 4, tableAttrs: { style: { width: '100%' } } },
            defaults:    {
                listeners: { change: function() { TP.iconSettingsGlobals.renderUpdate(undefined, undefined, 0)  } },
                mouseover: function(color) { TP.iconSettingsGlobals.renderUpdate({color: color, scope: this }, undefined, 0); },
                mouseout:  function(color) { TP.iconSettingsGlobals.renderUpdate(undefined,                    undefined, 0); }
            },
            items: [
                { xtype: 'label', text: panel.iconType == 'host' ? 'Up: ' : 'Ok: ' },
                {
                    xtype:          'colorcbo',
                    name:           'speedocolor_ok',
                    value:           panel.xdata.appearance.speedocolor_ok,
                    width:           80,
                    tdAttrs:       { style: 'padding-right: 10px;'},
                    colorGradient: { start: '#D3D3AE', stop: '#00FF00' }
                },
                { xtype: 'label', text: panel.iconType == 'host' ? 'Unreachable: ' : 'Warning: ' },
                {
                    xtype:          'colorcbo',
                    name:           'speedocolor_warning',
                    value:           panel.xdata.appearance.speedocolor_warning,
                    width:           80,
                    colorGradient: { start: '#E1E174', stop: '#FFFF00' }
                },
                { xtype: 'label', text: panel.iconType == 'host' ? 'Down: ' : 'Critical: ' },
                {
                    xtype:          'colorcbo',
                    name:           'speedocolor_critical',
                    value:           panel.xdata.appearance.speedocolor_critical,
                    width:           80,
                    colorGradient: { start: '#D3AEAE', stop: '#FF0000' }
                },
                { xtype: 'label', text: 'Unknown:' },
                {
                    xtype:          'colorcbo',
                    name:           'speedocolor_unknown',
                    value:           panel.xdata.appearance.speedocolor_unknown,
                    width:           80,
                    colorGradient: { start: '#DAB891', stop: '#FF8900' }
                },
                { xtype: 'label', text: 'Background:' },
                {
                    xtype:          'colorcbo',
                    name:           'speedocolor_bg',
                    value:           panel.xdata.appearance.speedocolor_bg,
                    width:           80
                },
                { xtype: 'label', text: 'Gradient:' },
                {
                    xtype:      'numberfield',
                    allowDecimals: true,
                    width:       80,
                    name:       'speedogradient',
                    maxValue:    1,
                    minValue:   -1,
                    step:        0.05,
                    value:       panel.xdata.appearance.speedogradient
                }
            ]
        }, {
            fieldLabel:   'Source',
            name:         'speedosource',
            xtype:        'combobox',
            cls:          'speedometer',
            id:           'speedosourceStore',
            displayField: 'name',
            valueField:   'value',
            queryMode:    'local',
            store:       { fields: ['name', 'value'], data: [] },
            editable:      false,
            listeners: { focus:  function() { TP.iconSettingsGlobals.perfDataUpdate() },
                         change: function() { TP.iconSettingsGlobals.renderUpdate(undefined, true) }
            }
        }, {
            fieldLabel: 'Options',
            xtype:      'fieldcontainer',
            cls:        'speedometer',
            layout:      { type: 'table', columns: 6, tableAttrs: { style: { width: '100%' } } },
            defaults: { listeners: { change: function() { TP.iconSettingsGlobals.renderUpdate(undefined, true) } } },
            items: [
                { xtype: 'label', text: 'Invert:', style: 'margin-left: 0; margin-right: 2px;' },
                { xtype: 'checkbox', name: 'speedoinvert' },
                { xtype: 'label', text: 'Min:', style: 'margin-left: 8px; margin-right: 2px;' },
                { xtype: 'numberfield', allowDecimals: true, width: 70, name: 'speedomin', step: 1 },
                { xtype: 'label', text: 'Max:', style: 'margin-left: 8px; margin-right: 2px;' },
                { xtype: 'numberfield', allowDecimals: true, width: 70, name: 'speedomax', step: 1 },
                { xtype: 'label', text: 'Factor:', style: 'margin-left: 0; margin-right: 2px;' },
                { xtype: 'textfield', width: 120, name: 'speedofactor', colspan: 5, emptyText: '100, 0.01, 1e3, 1e-6 ...' }
            ]
        }]);
    }
});
