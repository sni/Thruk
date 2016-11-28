TP.shapesStore = Ext.create('Ext.data.Store', {
    fields: ['name', 'data'],
    proxy: {
        type: 'ajax',
        url:  'panorama.cgi?task=userdata_shapes',
        reader: {
            type: 'json',
            root: 'data'
        }
    },
    data : thruk_shape_data
});

Ext.define('TP.IconWidgetAppearanceShape', {

    alias:  'tp.icon.appearance.shape',

    defaultDrawItem: true,

    constructor: function(config) {
        var me = this;
        Ext.apply(me, config);
    },

    /* update render item on active tab only */
    updateRenderActive: function(xdata, forceColor) {
        this.shapeRender(xdata, forceColor);
    },

    /* renders shape */
    shapeRender: function(xdata, forceColor, panel) {
        if(panel == undefined) { panel = this.panel; }
        if(xdata == undefined) { xdata = panel.xdata; }
        if(xdata.appearance.type != 'shape') { return }

        if(xdata.appearance.shapename == undefined) { return; }
        if(!panel.surface) {
            panel.setRenderItem(xdata, undefined, forceColor);
            return;
        }
        if(!panel.surface.el) { return };
        var shapeData;
        TP.shapesStore.findBy(function(rec, id) {
            if(rec.data.name == xdata.appearance.shapename) {
                shapeData = rec.data.data;
            }
        });
        if(shapeData == undefined) {
            if(initial_shapes[xdata.appearance.shapename]) {
                shapeData = initial_shapes[xdata.appearance.shapename];
            } else {
                TP.Msg.msg("fail_message~~loading shape '"+xdata.appearance.shapename+"' failed: no such shape");
                return;
            }
        }

        shapeData = shapeData.replace(/,\s*$/, ''); // remove trailing commas
        shapeData += ",fill:'"+(TP.getShapeColor("shape", panel, xdata, forceColor).color)+"'";
        var spriteData;
        try {
            eval("spriteData = {"+shapeData+"};");
        }
        catch(err) {
            TP.logError(panel.id, "labelSpriteEvalException", err);
            TP.Msg.msg("fail_message~~loading shape '"+xdata.appearance.shapename+"' failed: "+err);
            return;
        }
        panel.surface.removeAll();
        sprite = panel.surface.add(spriteData);
        var box = sprite.getBBox();
        var xScale = xdata.appearance.shapewidth/box.width;
        var yScale = xdata.appearance.shapeheight/box.height;
        if(xdata.appearance.shapelocked) { yScale = xScale; }
        if(isNaN(xScale) || isNaN(yScale) || isNaN(box.x)) { return; }
        sprite.setAttributes({scale:{x:xScale,y:yScale}}, true);
        box = sprite.getBBox();
        sprite.setAttributes({translate:{x:-box.x,y:-box.y}}, true);
        panel.setSize(Math.ceil(box.width), Math.ceil(box.height));
        if(panel.items.getAt && panel.items.getAt(0)) {
            panel.items.getAt(0).setSize(Math.ceil(box.width), Math.ceil(box.height));
        }
        sprite.show(true);
    },

    settingsWindowAppearanceTypeChanged: function() {
        // fill in defaults
        var values = Ext.getCmp('appearanceForm').getForm().getValues();
        if(!values['shapename']) {
            values['shapename']           = 'arrow';
            values['shapelocked']         = true;
            values['shapewidth']          = 50;
            values['shapeheight']         = 50;
            values['shapecolor_ok']       = '#199C0F';
            values['shapecolor_warning']  = '#CDCD0A';
            values['shapecolor_critical'] = '#CA1414';
            values['shapecolor_unknown']  = '#CC740F';
            values['shapegradient']       =  0;
            values['shapesource']         =  'fixed';
            Ext.getCmp('appearanceForm').getForm().setValues(values);
        }
    },

    getAppearanceTabItems: function(panel) {
        return([{
            fieldLabel:   'Shape',
            xtype:        'combobox',
            name:         'shapename',
            cls:          'shape',
            store:         TP.shapesStore,
            displayField: 'name',
            valueField:   'name',
            listConfig : {
                getInnerTpl: function(displayField) {
                    TP.tmpid = 0;
                    return '<div class="x-combo-list-item"><span name="{name}" height=16 width=16 style="vertical-align:top; margin-right: 3px;"><\/span>{name}<\/div>';
                }
            },
            listeners: {
                afterrender: function(This) {
                    var me = This;
                    me.shapes = [];
                    This.getPicker().addListener('show', function(This) {
                        Ext.Array.each(This.el.dom.getElementsByTagName('SPAN'), function(item, idx) {
                            TP.show_shape_preview(item, panel, me.shapes);
                        });
                    });
                    This.getPicker().addListener('refresh', function(This) {
                        Ext.Array.each(This.el.dom.getElementsByTagName('SPAN'), function(item, idx) {
                            TP.show_shape_preview(item, panel, me.shapes);
                        });
                    });
                },
                destroy: function(This) {
                    // clean up
                    Ext.Array.each(This.shapes, function(item, idx) { item.destroy() });
                },
                change: function(This) { TP.iconSettingsGlobals.renderUpdate(); }
            }
        }, {
            fieldLabel: 'Size',
            xtype:      'fieldcontainer',
            name:       'shapesize',
            cls:        'shape',
            layout:     'table',
            defaults: { listeners: { change: function() { TP.iconSettingsGlobals.renderUpdate() } } },
            items: [{ xtype: 'label', text: 'Width:', style: 'margin-left: 0; margin-right: 2px;' },
                    { xtype: 'numberunit', name: 'shapewidth', unit: 'px', width: 65, value: panel.xdata.appearance.shapewidth },
                    { xtype: 'label', text: 'Height:', style: 'margin-left: 10px; margin-right: 2px;' },
                    { xtype: 'numberunit', name: 'shapeheight', unit: 'px', width: 65, value: panel.xdata.appearance.shapeheight, id: 'shapeheightfield' },
                    { xtype: 'button', width: 22, icon: url_prefix+'plugins/panorama/images/link.png', enableToggle: true, style: 'margin-left: 2px; margin-top: -6px;', id: 'shapetogglelocked',
                        toggleHandler: function(btn, state) { this.up('form').getForm().setValues({shapelocked: state ? '1' : '' }); TP.iconSettingsGlobals.renderUpdate(); }
                    },
                    { xtype: 'hidden', name: 'shapelocked' }
            ]
        }, {
            fieldLabel: 'Colors',
            cls:        'shape',
            xtype:      'fieldcontainer',
            layout:      { type: 'table', columns: 4, tableAttrs: { style: { width: '100%' } } },
            defaults:    {
                listeners: { change: function() { TP.iconSettingsGlobals.renderUpdate(undefined, undefined, 0); } },
                mouseover: function(color) { TP.iconSettingsGlobals.renderUpdate(color,     undefined, 0); },
                mouseout:  function(color) { TP.iconSettingsGlobals.renderUpdate(undefined, undefined, 0); }
            },
            items: [
                { xtype: 'label', text: panel.iconType == 'host' ? 'Up: ' : 'Ok: ' },
                {
                    xtype:          'colorcbo',
                    name:           'shapecolor_ok',
                    value:           panel.xdata.appearance.shapecolor_ok,
                    width:           80,
                    tdAttrs:       { style: 'padding-right: 11px;'},
                    colorGradient: { start: '#D3D3AE', stop: '#00FF00' }
                },
                { xtype: 'label', text: panel.iconType == 'host' ? 'Unreachable: ' : 'Warning: ' },
                {
                    xtype:          'colorcbo',
                    name:           'shapecolor_warning',
                    value:           panel.xdata.appearance.shapecolor_warning,
                    width:           80,
                    colorGradient: { start: '#E1E174', stop: '#FFFF00' }
                },
                { xtype: 'label', text: panel.iconType == 'host' ? 'Down: ' : 'Critical: ' },
                {
                    xtype:          'colorcbo',
                    name:           'shapecolor_critical',
                    value:           panel.xdata.appearance.shapecolor_critical,
                    width:           80,
                    colorGradient: { start: '#D3AEAE', stop: '#FF0000' }
                },
                { xtype: 'label', text: 'Unknown: ', hidden: panel.iconType == 'host' ? true : false },
                {
                    xtype:          'colorcbo',
                    name:           'shapecolor_unknown',
                    value:           panel.xdata.appearance.shapecolor_unknown,
                    width:           80,
                    colorGradient: { start: '#DAB891', stop: '#FF8900' },
                    hidden:          panel.iconType == 'host' ? true : false
            }]
        }, {
            fieldLabel: 'Gradient',
            cls:        'shape',
            xtype:      'fieldcontainer',
            layout:      { type: 'hbox', align: 'stretch' },
            items: [{
                xtype:        'numberfield',
                allowDecimals: true,
                name:         'shapegradient',
                maxValue:      1,
                minValue:     -1,
                step:          0.05,
                value:         panel.xdata.appearance.shapegradient,
                width:         55,
                listeners:   { change: function() { TP.iconSettingsGlobals.renderUpdate(); } }
            },
            { xtype: 'label', text: 'Source:', margins: {top: 2, right: 2, bottom: 0, left: 10} },
            {
                name:         'shapesource',
                xtype:        'combobox',
                id:           'shapesourceStore',
                displayField: 'name',
                valueField:   'value',
                queryMode:    'local',
                store:       { fields: ['name', 'value'], data: [] },
                editable:      false,
                value:         panel.xdata.appearance.shapesource,
                listeners:   { focus: function() { TP.iconSettingsGlobals.perfDataUpdate() }, change: function() { TP.iconSettingsGlobals.renderUpdate(); } },
                flex:          1
            }]
        }, {
            xtype:      'panel',
            cls:        'shape',
            html:       'Place shapes in: '+usercontent_folder+'/shapes/',
            style:      'text-align: center;',
            bodyCls:    'form-hint',
            padding:    '10 0 0 0',
            border:      0
        }]);
    }
});
