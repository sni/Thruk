Ext.define('TP.IconWidgetAppearancePie', {

    alias:  'tp.icon.appearance.pie',

    constructor: function(config) {
        var me = this;
        Ext.apply(me, config);
    },

    /* update render item on active tab only */
    updateRenderActive: function(xdata, forceColor) {
        this.pieRender(xdata, forceColor);
    },

    setRenderItem: function(xdata) {
        var panel = this.panel;
        var pieStore = Ext.create('Ext.data.Store', {
            fields: ['name','value'],
            data:  []
        });
        panel.add({
            xtype:  'tp_piechart',
            store:   pieStore,
            panel:   panel,
            animate: false,
            shadow:  false, // xdata.appearance.pieshadow, // not working atm
            donut:   xdata.appearance.piedonut,
            listeners: {
                afterrender: function(This, eOpts) {
                    panel.itemRendering = false;
                    panel.chart = This;
                    panel.updateRender(xdata);
                }
            }
        });
    },

    /* renders pie chart */
    pieRender: function(xdata, forceColor) {
        var panel = this.panel;
        if(xdata == undefined) { xdata = panel.xdata; }
        if(xdata.appearance.type != 'pie') { return }
        if(!panel.chart) {
            panel.setRenderItem(xdata);
            return;
        }
        if(panel.itemRendering) { return; }
        if(xdata.appearance.pielocked) { xdata.appearance.pieheight = xdata.appearance.piewidth; }
        if(!panel.items.getAt || !panel.items.getAt(0)) { return; }
        panel.items.getAt(0).setSize(xdata.appearance.piewidth, xdata.appearance.pieheight);
        panel.setSize(xdata.appearance.piewidth, xdata.appearance.pieheight);
        var colors = {
            up:          xdata.appearance.piecolor_up          ? xdata.appearance.piecolor_up          : '#00FF33',
            down:        xdata.appearance.piecolor_down        ? xdata.appearance.piecolor_down        : '#FF5B33',
            unreachable: xdata.appearance.piecolor_unreachable ? xdata.appearance.piecolor_unreachable : '#FF7A59',
            pending:     xdata.appearance.piecolor_pending     ? xdata.appearance.piecolor_pending     : '#ACACAC',
            ok:          xdata.appearance.piecolor_ok          ? xdata.appearance.piecolor_ok          : '#00FF33',
            warning:     xdata.appearance.piecolor_warning     ? xdata.appearance.piecolor_warning     : '#FFDE00',
            unknown:     xdata.appearance.piecolor_unknown     ? xdata.appearance.piecolor_unknown     : '#FF9E00',
            critical:    xdata.appearance.piecolor_critical    ? xdata.appearance.piecolor_critical    : '#FF5B33'
        };
        var totals   = panel.getTotals(xdata, colors);
        var colorSet = [];
        if(panel.chart.surface.existingGradients == undefined) { panel.chart.surface.existingGradients = {} }
        Ext.Array.each(totals, function(t,i) {
            var color = t.color;
            if(forceColor) { color = forceColor; }
            if(xdata.appearance.piegradient != 0) {
                var gradient = TP.createGradient(color, xdata.appearance.piegradient);
                if(panel.chart.surface.existingGradients[gradient.id] == undefined) {
                    panel.chart.surface.existingGradients[gradient.id] = true;
                    panel.chart.surface.addGradient(gradient);
                }
                colorSet.push('url(#'+gradient.id+')');
            } else {
                colorSet.push(color);
            }
        });
        panel.chart.series.getAt(0).colorSet = colorSet;
        var pieStore = Ext.create('Ext.data.Store', {
            fields: ['name','value'],
            data:  []
        });
        TP.updateArrayStoreHash(pieStore, totals);
        panel.chart.bindStore(pieStore);
        panel.chart.panel.xdata.showlabel    = !!xdata.appearance.pielabel;
        panel.chart.panel.xdata.showlabelVal = !!xdata.appearance.pielabelval;
        panel.chart.setShowLabel();
    },

    settingsWindowAppearanceTypeChanged: function() {
        // fill in defaults
        var values = Ext.getCmp('appearanceForm').getForm().getValues();
        if(!values['piewidth']) {
            values['piewidth']             = 50;
            values['pieheight']            = 50;
            values['pielocked']            = true;
            values['pieshadow']            = false;
            values['piedonut']             = 0;
            values['pielabel']             = false;
            values['piegradient']          = 0;
            values['piecolor_ok']          = '#199C0F';
            values['piecolor_warning']     = '#CDCD0A';
            values['piecolor_critical']    = '#CA1414';
            values['piecolor_unknown']     = '#CC740F';
            values['piecolor_up']          = '#199C0F';
            values['piecolor_down']        = '#CA1414';
            values['piecolor_unreachable'] = '#CA1414';
            Ext.getCmp('appearanceForm').getForm().setValues(values);
        }
    },

    getAppearanceTabItems: function(panel) {
        return([{
            fieldLabel: 'Size',
            xtype:      'fieldcontainer',
            cls:        'pie',
            layout:     'table',
            defaults: { listeners: { change: function() { TP.iconSettingsGlobals.renderUpdate() } } },
            items: [{ xtype: 'label', text: 'Width:', style: 'margin-left: 0; margin-right: 2px;' },
                    { xtype: 'numberunit', name: 'piewidth', unit: 'px', width: 65, value: panel.xdata.appearance.piewidth },
                    { xtype: 'label', text: 'Height:', style: 'margin-left: 10px; margin-right: 2px;' },
                    { xtype: 'numberunit', name: 'pieheight', unit: 'px', width: 65, value: panel.xdata.appearance.pieheight, id: 'pieheightfield' },
                    { xtype: 'button', width: 22, icon: url_prefix+'plugins/panorama/images/link.png', enableToggle: true, style: 'margin-left: 2px; margin-top: -6px;', id: 'pietogglelocked',
                        toggleHandler: function(btn, state) { this.up('form').getForm().setValues({pielocked: state ? '1' : '' }); TP.iconSettingsGlobals.renderUpdate(); }
                    },
                    { xtype: 'hidden', name: 'pielocked' }
            ]
        }, {
            fieldLabel: 'Options',
            xtype:      'fieldcontainer',
            cls:        'pie',
            layout:     'table',
            defaults: { listeners: { change: function() { TP.iconSettingsGlobals.renderUpdate(undefined, true) } } },
            items: [
            { xtype: 'label', text: 'Shadow:', style: 'margin-left: 0px; margin-right: 2px;', hidden: true },
            {
                xtype:      'checkbox',
                name:       'pieshadow',
                hidden:      true
            },
            { xtype: 'label', text: 'Label Name:', style: 'margin-left: 8px; margin-right: 2px;' },
            {
                xtype:      'checkbox',
                name:       'pielabel'
            },
            { xtype: 'label', text: 'Label Value:', style: 'margin-left: 8px; margin-right: 2px;' },
            {
                xtype:      'checkbox',
                name:       'pielabelval'
            },
            { xtype: 'label', text: 'Donut:', style: 'margin-left: 8px; margin-right: 2px;' },
            {
                xtype:      'numberunit',
                allowDecimals: false,
                width:       60,
                name:       'piedonut',
                unit:       '%'
            }]
        }, {
            fieldLabel: 'Colors',
            cls:        'pie',
            xtype:      'fieldcontainer',
            layout:      { type: 'table', columns: 4, tableAttrs: { style: { width: '100%' } } },
            defaults:    {
                listeners: { change:    function()      { TP.iconSettingsGlobals.renderUpdate(undefined, undefined, 0)  },
                           },
                mouseover: function(color) { TP.iconSettingsGlobals.renderUpdate(color,     undefined, 0); },
                mouseout:  function(color) { TP.iconSettingsGlobals.renderUpdate(undefined, undefined, 0); }
            },
            items: [
                { xtype: 'label', text: 'Ok:' },
                {
                    xtype:          'colorcbo',
                    name:           'piecolor_ok',
                    value:           panel.xdata.appearance.piecolor_ok,
                    width:           80,
                    tdAttrs:       { style: 'padding-right: 10px;'},
                    colorGradient: { start: '#D3D3AE', stop: '#00FF00' }
                },
                { xtype: 'label', text: 'Warning:' },
                {
                    xtype:          'colorcbo',
                    name:           'piecolor_warning',
                    value:           panel.xdata.appearance.piecolor_warning,
                    width:           80,
                    colorGradient: { start: '#E1E174', stop: '#FFFF00' }
                },
                { xtype: 'label', text: 'Critical:' },
                {
                    xtype:          'colorcbo',
                    name:           'piecolor_critical',
                    value:           panel.xdata.appearance.piecolor_critical,
                    width:           80,
                    colorGradient: { start: '#D3AEAE', stop: '#FF0000' }
                },
                { xtype: 'label', text: 'Unknown:' },
                {
                    xtype:          'colorcbo',
                    name:           'piecolor_unknown',
                    value:           panel.xdata.appearance.piecolor_unknown,
                    width:           80,
                    colorGradient: { start: '#DAB891', stop: '#FF8900' }
                },
                { xtype: 'label', text: 'Up:' },
                {
                    xtype:          'colorcbo',
                    name:           'piecolor_up',
                    value:           panel.xdata.appearance.piecolor_up,
                    width:           80,
                    colorGradient: { start: '#D3D3AE', stop: '#00FF00' }
                },
                { xtype: 'label', text: 'Down:' },
                {
                    xtype:          'colorcbo',
                    name:           'piecolor_down',
                    value:           panel.xdata.appearance.piecolor_down,
                    width:           80,
                    colorGradient: { start: '#D3AEAE', stop: '#FF0000' }
                },
                { xtype: 'label', text: 'Unreachable:' },
                {
                    xtype:          'colorcbo',
                    name:           'piecolor_unreachable',
                    value:           panel.xdata.appearance.piecolor_unreachable,
                    width:           80,
                    colorGradient: { start: '#D3AEAE', stop: '#FF0000' }
                },
                { xtype: 'label', text: 'Gradient:' },
                {
                    xtype:      'numberfield',
                    allowDecimals: true,
                    width:       80,
                    name:       'piegradient',
                    maxValue:    1,
                    minValue:   -1,
                    step:        0.05,
                    value:       panel.xdata.appearance.piegradient
                }
            ]
        }]);
    }
});
