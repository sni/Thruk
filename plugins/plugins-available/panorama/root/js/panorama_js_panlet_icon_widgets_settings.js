/* Shape Settings Tab */
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
TP.iconsetsStore = Ext.create('Ext.data.Store', {
    fields: ['name', 'sample', 'value', 'fileset'],
    proxy: {
        type: 'ajax',
        url:  'panorama.cgi?task=userdata_iconsets&withempty=1',
        reader: {
            type: 'json',
            root: 'data'
        }
    },
    autoLoad: true,
    data : thruk_iconset_data
});
TP.iconTypesStore = Ext.create('Ext.data.Store', {
    fields: ['name', 'value', 'icon'],
    autoLoad: false,
    data : [{value:'TP.HostStatusIcon',         name:'Host',          icon:url_prefix+'plugins/panorama/images/server.png'},
            {value:'TP.HostgroupStatusIcon',    name:'Hostgroup',     icon:url_prefix+'plugins/panorama/images/server_link.png'},
            {value:'TP.ServiceStatusIcon',      name:'Service',       icon:url_prefix+'plugins/panorama/images/computer.png'},
            {value:'TP.ServicegroupStatusIcon', name:'Service Group', icon:url_prefix+'plugins/panorama/images/computer_link.png'},
            {value:'TP.FilterStatusIcon',       name:'Custom Filter', icon:url_prefix+'plugins/panorama/images/page_find.png'}
    ]
});

TP.iconSettingsWindow = undefined;
TP.iconShowEditDialog = function(panel) {
    panel.stateful = false;
    var tab      = Ext.getCmp(panel.panel_id);
    var lastType = panel.xdata.appearance.type;

    // make sure only one window is open at a time
    if(TP.iconSettingsWindow != undefined) {
        TP.iconSettingsWindow.destroy();
    }
    tab.disableMapControlsTemp();

    TP.resetMoveIcons();
    TP.skipRender = false;

    var defaultSpeedoSource = 'problems';
    var perfDataUpdate = function() {
        // ensure fresh and correct performance data
        window.perfdata = {};
        panel.setIconLabel(undefined, true);

        // update speedo
        var data = [['number of problems',                  'problems'],
                    ['number of problems (incl. warnings)', 'problems_warn']];
        for(var key in perfdata) {
            if(defaultSpeedoSource == 'problems') { defaultSpeedoSource = 'perfdata:'+key; }
            var r = TP.getPerfDataMinMax(perfdata[key], '?');
            var options = r.min+" - "+r.max;
            data.push(['Perf. Data: '+key+' ('+options+')', 'perfdata:'+key]);
        }
        /* use availability data as source */
        var xdata = TP.get_icon_form_xdata(settingsWindow);
        if(xdata.label && xdata.label.labeltext && TP.availabilities && TP.availabilities[panel.id]) {
            var avail = TP.availabilities[panel.id];
            for(var key in avail) {
                var d = avail[key];
                var last    = d.last != undefined ? d.last : '...';
                if(last == -1) { last = '...'; }
                var options = d.opts['d'];
                if(d.opts['tm']) {
                    options    += '/'+d.opts['tm'];
                }
                data.push(['Availability: '+last+'% ('+options+')', 'avail:'+key]);
            }
        }
        var cbo = Ext.getCmp('speedosourceStore');
        TP.updateArrayStoreKV(cbo.store, data);

        // update shape
        var data = [['fixed', 'fixed']];
        for(var key in perfdata) {
            var r = TP.getPerfDataMinMax(perfdata[key], 100);
            var options = r.min+" - "+r.max;
            data.push(['Perf. Data: '+key+' ('+options+')', 'perfdata:'+key]);
        }
        var cbo = Ext.getCmp('shapesourceStore');
        TP.updateArrayStoreKV(cbo.store, data);
        var cbo = Ext.getCmp('connectorsourceStore');
        TP.updateArrayStoreKV(cbo.store, data);
    }

    /* General Settings Tab */
    var stateUpdate = function() {
        var xdata = TP.get_icon_form_xdata(settingsWindow);
        TP.updateAllIcons(Ext.getCmp(panel.panel_id), panel.id, xdata);
        labelUpdate();
        // update performance data stores
        perfDataUpdate();
    }

    var generalItems = panel.getGeneralItems();
    if(generalItems != undefined && panel.xdata.cls != 'TP.StaticIcon') {
        generalItems.unshift({
            xtype:        'combobox',
            name:         'newcls',
            fieldLabel:   'Filter Type',
            displayField: 'name',
            valueField:   'value',
            store:         TP.iconTypesStore,
            editable:      false,
            listConfig : {
                getInnerTpl: function(displayField) {
                    return '<div class="x-combo-list-item"><img src="{icon}" height=16 width=16 style="vertical-align:top; margin-right: 3px;">{name}<\/div>';
                }
            },
            value: panel.xdata.cls,
            listeners: {
                change: function(This, newValue, oldValue, eOpts) {
                    if(TP.iconSettingsWindow == undefined) { return; }
                    TP.iconSettingsWindow.mask('changing...');
                    var key   = panel.id;
                    var xdata = TP.get_icon_form_xdata(settingsWindow);
                    var conf  = {xdata: xdata};
                    conf.xdata.cls = newValue;

                    panel.redrawOnly = true;
                    panel.destroy();

                    TP.timeouts['timeout_' + key + '_show_settings'] = window.setTimeout(function() {
                        TP.iconSettingsWindow.skipRestore = true;
                        /* does not exist when changing a newly placed icon */
                        if(TP.cp.state[key]) {
                            TP.cp.state[key].xdata.cls = newValue;
                        }
                        panel = TP.add_panlet({id:key, skip_state:true, tb:tab, autoshow:true, state:conf, type:newValue}, false);
                        panel.xdata = conf.xdata;
                        panel.classChanged = newValue;
                        TP.iconShowEditDialog(panel);
                        TP.cp.state[key].xdata.cls = oldValue;
                    }, 50);
                }
            }
        });
    }
    var generalTab = {
        title : 'General',
        type  : 'panel',
        hidden: generalItems != undefined ? false : true,
        items: [{
            xtype : 'panel',
            layout: 'fit',
            border: 0,
            items: [{
                    xtype:           'form',
                    id:              'generalForm',
                    bodyPadding:     2,
                    border:          0,
                    bodyStyle:       'overflow-y: auto;',
                    submitEmptyText: false,
                    defaults:      { anchor: '-12', labelWidth: panel.generalLabelWidth || 132, listeners: { change: function(This, newValue, oldValue, eOpts) { if(newValue != "") { stateUpdate() } } } },
                    items:           generalItems
            }]
        }]
    };

    var updateDisabledFields = function(xdata) {
        var originalRenderUpdate = renderUpdate;
        renderUpdate = Ext.emptyFn;
        Ext.getCmp('shapeheightfield').setDisabled(xdata.appearance.shapelocked);
        Ext.getCmp('shapetogglelocked').toggle(xdata.appearance.shapelocked);
        Ext.getCmp('pieheightfield').setDisabled(xdata.appearance.pielocked);
        Ext.getCmp('pietogglelocked').toggle(xdata.appearance.pielocked);
        if(xdata.appearance.type == "connector" || xdata.appearance.type == "none") {
            Ext.getCmp('rotationfield').setVisible(false);
        } else {
            Ext.getCmp('rotationfield').setVisible(true);
        }
        renderUpdate = originalRenderUpdate;
    };

    /* Layout Settings Tab */
    var layoutTab = {
        title: 'Layout',
        type:  'panel',
        items: [{
            xtype : 'panel',
            layout: 'fit',
            border: 0,
            items: [{
                xtype:           'form',
                id:              'layoutForm',
                bodyPadding:     2,
                border:          0,
                bodyStyle:       'overflow-y: auto;',
                submitEmptyText: false,
                defaults:      { anchor: '-12', labelWidth: 80 },
                items: [{
                    fieldLabel: 'Position',
                    xtype:      'fieldcontainer',
                    layout:     'table',
                    items: [{ xtype: 'label', text:  'x:', style: 'margin-left: 0; margin-right: 2px;' },
                            { xtype: 'numberfield', name:  'x', width: 55, value: panel.xdata.layout.x, listeners: {
                                change: function(This, newValue, oldValue, eOpts) {
                                    if(!panel.noMoreMoves) {
                                        panel.noMoreMoves = true;
                                        var y = Number(This.up('panel').getValues().y);
                                        panel.setPosition(newValue, y);
                                        panel.noMoreMoves = false;
                                    }
                                }
                            }},
                            { xtype: 'label', text:  'y:', style: 'margin-left: 10px; margin-right: 2px;' },
                            { xtype: 'numberfield', name:  'y', width: 55, value: panel.xdata.layout.y, listeners: {
                                change: function(This, newValue, oldValue, eOpts) {
                                    if(!panel.noMoreMoves) {
                                        panel.noMoreMoves = true;
                                        var x = Number(This.up('panel').getValues().x);
                                        panel.setPosition(x, newValue);
                                        panel.noMoreMoves = false;
                                    }
                                }
                            }},
                            { xtype: 'label', text: '(use cursor keys)', style: 'margin-left: 10px;', cls: 'form-hint' }
                    ]
                }, {
                    fieldLabel:   'Rotation',
                    xtype:        'numberunit',
                    allowDecimals: false,
                    name:         'rotation',
                    id:           'rotationfield',
                    unit:         '°',
                    minValue:     -360,
                    maxValue:      360,
                    step:           15,
                    value:         panel.xdata.layout.rotation != undefined ? panel.xdata.layout.rotation : 0,
                    listeners:   { change: function(This) { var xdata = TP.get_icon_form_xdata(settingsWindow); panel.applyRotation(This.value, xdata); } }
                }, {
                    fieldLabel:   'Z-Index',
                    xtype:        'numberfield',
                    allowDecimals: false,
                    name:         'zindex',
                    minValue:      -10,
                    maxValue:      100,
                    step:            1,
                    value:         panel.xdata.layout.zindex != undefined ? panel.xdata.layout.zindex : 0,
                    listeners:   { change: function(This) { var xdata = TP.get_icon_form_xdata(settingsWindow); panel.applyZindex(This.value, xdata); } }
                }, {
                    fieldLabel:   'Scale',
                    id:           'layoutscale',
                    xtype:        'numberunit',
                    unit:         '%',
                    allowDecimals: true,
                    name:         'scale',
                    minValue:        0,
                    maxValue:    10000,
                    step:            1,
                    value:         panel.xdata.layout.scale != undefined ? panel.xdata.layout.scale : 100,
                    listeners:   { change: function(This) { var xdata = TP.get_icon_form_xdata(settingsWindow); panel.applyScale(This.value, xdata); } },
                    disabled:     (panel.hasScale || panel.xdata.appearance.type == 'icon') ? false : true,
                    hidden:        panel.iconType == 'text' ? true : false
                }]
            }]
        }]
    };

    TP.shapesStore.load();
    var renderUpdate   = Ext.emptyFn;
    var renderUpdateDo = function(forceColor, forceRenderItem) {
        if(TP.skipRender) { return; }
        var xdata = TP.get_icon_form_xdata(settingsWindow);
        if(panel.iconType == 'image') { panel.setRenderItem(xdata); }
        if(xdata.appearance      == undefined) { return; }
        if(xdata.appearance.type == undefined) { return; }
        if(xdata.appearance.type == 'shape') { forceRenderItem = true; }
        if(xdata.appearance.type != lastType || forceRenderItem) {
            if(panel.setRenderItem) { panel.setRenderItem(xdata, forceRenderItem); }
        }
        lastType = xdata.appearance.type;
        if(xdata.appearance.type == 'shape') {
            panel.shapeRender(xdata, forceColor);
        }
        if(xdata.appearance.type == 'pie') {
            panel.pieRender(xdata, forceColor);
        }
        if(xdata.appearance.type == 'speedometer') {
            panel.speedoRender(xdata, forceColor);
        }
        if(xdata.appearance.type == 'connector') {
            panel.connectorRender(xdata, forceColor);
        }
        labelUpdate();
        updateDisabledFields(xdata);
    }
    var appearanceTab = {
        title: 'Appearance',
        type:  'panel',
        hidden: panel.hideAppearanceTab,
        listeners: { show: perfDataUpdate },
        items: [{
            xtype : 'panel',
            layout: 'fit',
            border: 0,
            items: [{
                xtype:           'form',
                id:              'appearanceForm',
                bodyPadding:     2,
                border:          0,
                bodyStyle:       'overflow-y: auto;',
                submitEmptyText: false,
                defaults:      { anchor: '-12', labelWidth: 60, listeners: { change: function() { renderUpdate(); } } },
                items: [{
                    /* appearance type */
                    xtype:      'combobox',
                    fieldLabel: 'Type',
                    name:       'type',
                    store:      [['none','Label Only'], ['icon','Icon'], ['connector', 'Line / Arrow / Watermark'], ['pie', 'Pie Chart'], ['speedometer', 'Speedometer'], ['shape', 'Shape']],
                    id:         'appearance_types',
                    editable:    false,
                    listeners: {
                        change: function(This, newValue, oldValue, eOpts) {
                            Ext.getCmp('appearanceForm').items.each(function(f, i) {
                                if(f.cls != undefined) {
                                    if(f.cls.match(newValue)) {
                                        f.show();
                                    } else {
                                        f.hide();
                                    }
                                }
                            });
                            if(newValue == 'icon' || panel.hasScale) {
                                Ext.getCmp('layoutscale').setDisabled(false);
                            } else {
                                Ext.getCmp('layoutscale').setDisabled(true);
                            }
                            if(newValue == 'shape') {
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
                                }
                                var originalRenderUpdate = renderUpdate;
                                renderUpdate = Ext.emptyFn;
                                Ext.getCmp('appearanceForm').getForm().setValues(values);
                                renderUpdate = originalRenderUpdate;
                            }

                            if(newValue == 'pie') {
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
                                }
                                Ext.getCmp('appearanceForm').getForm().setValues(values);
                            }

                            if(newValue == 'speedometer') {
                                // fill in defaults
                                var values = Ext.getCmp('appearanceForm').getForm().getValues();
                                if(!values['speedowidth']) {
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
                                }
                                Ext.getCmp('appearanceForm').getForm().setValues(values);
                            }

                            if(newValue == 'connector') {
                                // fill in defaults
                                var values = Ext.getCmp('appearanceForm').getForm().getValues();
                                if(!values['connectorwidth']) {
                                    var pos = panel.getPosition();
                                    values['connectorfromx']             = pos[0]-100;
                                    values['connectorfromy']             = pos[1];
                                    values['connectortox']               = pos[0]+100;
                                    values['connectortoy']               = pos[1];
                                    values['connectorwidth']             = 3;
                                    values['connectorarrowtype']         = 'both';
                                    values['connectorarrowwidth']        = 10;
                                    values['connectorarrowlength']       = 20;
                                    values['connectorarrowinset']        = 2;
                                    values['connectorcolor_ok']          = '#199C0F';
                                    values['connectorcolor_warning']     = '#CDCD0A';
                                    values['connectorcolor_critical']    = '#CA1414';
                                    values['connectorcolor_unknown']     = '#CC740F';
                                    values['connectorgradient']          =  0;
                                    values['connectorsource']            = 'fixed';
                                }
                                var originalRenderUpdate = renderUpdate;
                                renderUpdate = Ext.emptyFn;
                                Ext.getCmp('appearanceForm').getForm().setValues(values);
                                renderUpdate = originalRenderUpdate;
                            }

                            renderUpdate();
                        }
                    }
                },

                /* Icons */
                {
                    fieldLabel:   'Icon Set',
                    id:           'iconset_field',
                    xtype:        'combobox',
                    name:         'iconset',
                    cls:          'icon',
                    store:         TP.iconsetsStore,
                    value:        '',
                    emptyText:    'use dashboards default icon set',
                    displayField: 'name',
                    valueField:   'value',
                    listConfig : {
                        getInnerTpl: function(displayField) {
                            return '<div class="x-combo-list-item"><img src="{sample}" height=16 width=16 style="vertical-align:top; margin-right: 3px;">{name}<\/div>';
                        }
                    },
                    listeners: {
                        change: function(This) { renderUpdate(undefined, true); }
                    }
                }, {
                    xtype:      'panel',
                    cls:        'icon',
                    html:       'Place image sets in: '+usercontent_folder+'/images/status/',
                    style:      'text-align: center;',
                    bodyCls:    'form-hint',
                    padding:    '10 0 0 0',
                    border:      0
                },


                /* Shapes */
                {
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
                        change: function(This) { renderUpdate(); }
                    }
                }, {
                    fieldLabel: 'Size',
                    xtype:      'fieldcontainer',
                    name:       'shapesize',
                    cls:        'shape',
                    layout:     'table',
                    defaults: { listeners: { change: function() { renderUpdate() } } },
                    items: [{ xtype: 'label', text: 'Width:', style: 'margin-left: 0; margin-right: 2px;' },
                            { xtype: 'numberunit', name: 'shapewidth', unit: 'px', width: 65, value: panel.xdata.appearance.shapewidth },
                            { xtype: 'label', text: 'Height:', style: 'margin-left: 10px; margin-right: 2px;' },
                            { xtype: 'numberunit', name: 'shapeheight', unit: 'px', width: 65, value: panel.xdata.appearance.shapeheight, id: 'shapeheightfield' },
                            { xtype: 'button', width: 22, icon: url_prefix+'plugins/panorama/images/link.png', enableToggle: true, style: 'margin-left: 2px; margin-top: -6px;', id: 'shapetogglelocked',
                                toggleHandler: function(btn, state) { this.up('form').getForm().setValues({shapelocked: state ? '1' : '' }); renderUpdate(); }
                            },
                            { xtype: 'hidden', name: 'shapelocked' }
                    ]
                }, {
                    fieldLabel: 'Colors',
                    cls:        'shape',
                    xtype:      'fieldcontainer',
                    layout:      { type: 'table', columns: 4, tableAttrs: { style: { width: '100%' } } },
                    defaults:    {
                        listeners: { change:    function()      { renderUpdateDo() }     },
                                     mouseover: function(color) { renderUpdateDo(color); },
                                     mouseout:  function(color) { renderUpdateDo();      }
                    },
                    items: [
                        { xtype: 'label', text: panel.iconType == 'host' ? 'Up: ' : 'Ok: ' },
                        {
                            xtype:          'colorcbo',
                            name:           'shapecolor_ok',
                            value:           panel.xdata.appearance.shapecolor_ok,
                            width:           80,
                            tdAttrs:       { style: 'padding-right: 10px;'},
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
                        listeners:   { change: function() { renderUpdate(); } }
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
                        listeners:   { focus: perfDataUpdate, change: function() { renderUpdate(); } },
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
                },


                /* Connector */
                {
                    fieldLabel: 'From',
                    xtype:      'fieldcontainer',
                    name:       'connectorfrom',
                    cls:        'connector',
                    layout:     { type: 'hbox', align: 'stretch' },
                    defaults:   { listeners: { change: function() { renderUpdate(); } } },
                    items:        [{
                        xtype:        'label',
                        text:         'x',
                        margins:      {top: 3, right: 2, bottom: 0, left: 7}
                    }, {
                        xtype:        'numberunit',
                        allowDecimals: false,
                        name:         'connectorfromx',
                        width:         70,
                        unit:         'px',
                        value:         panel.xdata.appearance.connectorfromx
                    }, {
                        xtype:        'label',
                        text:         'y',
                        margins:      {top: 3, right: 2, bottom: 0, left: 7}
                    }, {
                        xtype:        'numberunit',
                        allowDecimals: false,
                        name:         'connectorfromy',
                        width:         70,
                        unit:         'px',
                        value:         panel.xdata.appearance.connectorfromy
                    },{
                        xtype:        'label',
                        text:         'Endpoints',
                        margins:      {top: 3, right: 2, bottom: 0, left: 7}
                    }, {
                        xtype:        'combobox',
                        name:         'connectorarrowtype',
                        width:         70,
                        matchFieldWidth: false,
                        value:         panel.xdata.appearance.connectorarrowtype,
                        store:         ['both', 'left', 'right', 'none'],
                        listConfig : {
                            getInnerTpl: function(displayField) {
                                return '<div class="x-combo-list-item"><img src="'+url_prefix+'plugins/panorama/images/connector_type_{field1}.png" height=16 width=77 style="vertical-align:top; margin-right: 3px;"> {field1}<\/div>';
                            }
                        }
                    }]
                },
                {
                    fieldLabel: 'To',
                    xtype:      'fieldcontainer',
                    name:       'connectorto',
                    cls:        'connector',
                    layout:     { type: 'hbox', align: 'stretch' },
                    defaults:   { listeners: { change: function() { renderUpdate(); } } },
                    items:        [{
                        xtype:        'label',
                        text:         'x',
                        margins:      {top: 3, right: 2, bottom: 0, left: 7}
                    }, {
                        xtype:        'numberunit',
                        allowDecimals: false,
                        name:         'connectortox',
                        width:         70,
                        unit:         'px',
                        value:         panel.xdata.appearance.connectortox
                    }, {
                        xtype:        'label',
                        text:         'y',
                        margins:      {top: 3, right: 2, bottom: 0, left: 7}
                    }, {
                        xtype:        'numberunit',
                        allowDecimals: false,
                        name:         'connectortoy',
                        width:         70,
                        unit:         'px',
                        value:         panel.xdata.appearance.connectortoy
                    }]
                },
                {
                    fieldLabel: 'Size',
                    xtype:      'fieldcontainer',
                    name:       'connectorsize',
                    cls:        'connector',
                    layout:     { type: 'hbox', align: 'stretch' },
                    defaults:   { listeners: { change: function() { renderUpdate(); } } },
                    items:        [{
                        xtype:        'label',
                        text:         'Width',
                        margins:      {top: 3, right: 2, bottom: 0, left: 7}
                    }, {
                        xtype:        'numberunit',
                        allowDecimals: false,
                        name:         'connectorwidth',
                        width:         60,
                        unit:         'px',
                        value:         panel.xdata.appearance.connectorwidth
                    }, {
                        xtype:        'label',
                        text:         'Variable Width',
                        margins:      {top: 3, right: 2, bottom: 0, left: 7}
                    }, {
                        xtype:        'checkbox',
                        name:         'connectorvariable'
                    }]
                },
                {
                    fieldLabel: 'Endpoints',
                    xtype:      'fieldcontainer',
                    name:       'connectorarrow',
                    cls:        'connector',
                    layout:     { type: 'hbox', align: 'stretch' },
                    defaults:   { listeners: { change: function() { renderUpdate(); } } },
                    items:        [{
                        xtype:        'label',
                        text:         'Width',
                        margins:      {top: 3, right: 2, bottom: 0, left: 7}
                    }, {
                        xtype:        'numberunit',
                        allowDecimals: false,
                        name:         'connectorarrowwidth',
                        width:         60,
                        unit:         'px',
                        minValue:      0,
                        value:         panel.xdata.appearance.connectorarrowwidth
                    }, {
                        xtype:        'label',
                        text:         'Length',
                        margins:      {top: 3, right: 2, bottom: 0, left: 7}
                    }, {
                        xtype:        'numberunit',
                        allowDecimals: false,
                        name:         'connectorarrowlength',
                        width:         60,
                        minValue:      0,
                        unit:         'px',
                        value:         panel.xdata.appearance.connectorarrowlength
                    }, {
                        xtype:        'label',
                        text:         'Inset',
                        margins:      {top: 3, right: 2, bottom: 0, left: 7}
                    }, {
                        xtype:        'numberunit',
                        allowDecimals: false,
                        name:         'connectorarrowinset',
                        width:         60,
                        unit:         'px',
                        value:         panel.xdata.appearance.connectorarrowinset
                    }]
                }, {
                    fieldLabel: 'Colors',
                    cls:        'connector',
                    xtype:      'fieldcontainer',
                    layout:      { type: 'table', columns: 4, tableAttrs: { style: { width: '100%' } } },
                    defaults:    {
                        listeners: { change:    function()      { renderUpdateDo() }     },
                                     mouseover: function(color) { renderUpdateDo(color); },
                                     mouseout:  function(color) { renderUpdateDo();      }
                    },
                    items: [
                        { xtype: 'label', text: panel.iconType == 'host' ? 'Up ' : 'Ok ' },
                        {
                            xtype:          'colorcbo',
                            name:           'connectorcolor_ok',
                            value:           panel.xdata.appearance.connectorcolor_ok,
                            width:           80,
                            tdAttrs:       { style: 'padding-right: 10px;'},
                            colorGradient: { start: '#D3D3AE', stop: '#00FF00' }
                        },
                        { xtype: 'label', text: panel.iconType == 'host' ? 'Unreachable ' : 'Warning ' },
                        {
                            xtype:          'colorcbo',
                            name:           'connectorcolor_warning',
                            value:           panel.xdata.appearance.connectorcolor_warning,
                            width:           80,
                            colorGradient: { start: '#E1E174', stop: '#FFFF00' }
                        },
                        { xtype: 'label', text: panel.iconType == 'host' ? 'Down ' : 'Critical ' },
                        {
                            xtype:          'colorcbo',
                            name:           'connectorcolor_critical',
                            value:           panel.xdata.appearance.connectorcolor_critical,
                            width:           80,
                            colorGradient: { start: '#D3AEAE', stop: '#FF0000' }
                        },
                        { xtype: 'label', text: 'Unknown ', hidden: panel.iconType == 'host' ? true : false },
                        {
                            xtype:          'colorcbo',
                            name:           'connectorcolor_unknown',
                            value:           panel.xdata.appearance.connectorcolor_unknown,
                            width:           80,
                            colorGradient: { start: '#DAB891', stop: '#FF8900' },
                            hidden:          panel.iconType == 'host' ? true : false
                    }]
                }, {
                    fieldLabel: 'Gradient',
                    cls:        'connector',
                    xtype:      'fieldcontainer',
                    layout:      { type: 'hbox', align: 'stretch' },
                    items: [{
                        xtype:        'numberfield',
                        allowDecimals: true,
                        name:         'connectorgradient',
                        maxValue:      1,
                        minValue:     -1,
                        step:          0.05,
                        value:         panel.xdata.appearance.connectorgradient,
                        width:         55,
                        listeners:   { change: function() { renderUpdate(); } }
                    },
                    { xtype: 'label', text: 'Source', margins: {top: 2, right: 2, bottom: 0, left: 10} },
                    {
                        name:         'connectorsource',
                        xtype:        'combobox',
                        id:           'connectorsourceStore',
                        displayField: 'name',
                        valueField:   'value',
                        queryMode:    'local',
                        store:       { fields: ['name', 'value'], data: [] },
                        editable:      false,
                        value:         panel.xdata.appearance.connectorsource,
                        listeners:   { focus: perfDataUpdate, change: function() { renderUpdate(); } },
                        flex:          1
                    }]
                }, {
                    fieldLabel: 'Options',
                    xtype:      'fieldcontainer',
                    cls:        'connector',
                    layout:     'table',
                    defaults: { listeners: { change: function() { renderUpdate(undefined, true) } } },
                    items: [
                            { xtype: 'label', text: 'Cust. Perf. Data Min', style: 'margin-left: 0px; margin-right: 2px;' },
                            { xtype: 'numberfield', allowDecimals: true, width: 70, name: 'connectormin', step: 100 },
                            { xtype: 'label', text: 'Max', style: 'margin-left: 8px; margin-right: 2px;' },
                            { xtype: 'numberfield', allowDecimals: true, width: 70, name: 'connectormax', step: 100 }
                        ]
                },


                /* Pie Chart */
                {
                    fieldLabel: 'Size',
                    xtype:      'fieldcontainer',
                    cls:        'pie',
                    layout:     'table',
                    defaults: { listeners: { change: function() { renderUpdate() } } },
                    items: [{ xtype: 'label', text: 'Width:', style: 'margin-left: 0; margin-right: 2px;' },
                            { xtype: 'numberunit', name: 'piewidth', unit: 'px', width: 65, value: panel.xdata.appearance.piewidth },
                            { xtype: 'label', text: 'Height:', style: 'margin-left: 10px; margin-right: 2px;' },
                            { xtype: 'numberunit', name: 'pieheight', unit: 'px', width: 65, value: panel.xdata.appearance.pieheight, id: 'pieheightfield' },
                            { xtype: 'button', width: 22, icon: url_prefix+'plugins/panorama/images/link.png', enableToggle: true, style: 'margin-left: 2px; margin-top: -6px;', id: 'pietogglelocked',
                                toggleHandler: function(btn, state) { this.up('form').getForm().setValues({pielocked: state ? '1' : '' }); renderUpdate(); }
                            },
                            { xtype: 'hidden', name: 'pielocked' }
                    ]
                }, {
                    fieldLabel: 'Options',
                    xtype:      'fieldcontainer',
                    cls:        'pie',
                    layout:     'table',
                    defaults: { listeners: { change: function() { renderUpdate(undefined, true) } } },
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
                        unit:       'px'
                    }]
                }, {
                    fieldLabel: 'Colors',
                    cls:        'pie',
                    xtype:      'fieldcontainer',
                    layout:      { type: 'table', columns: 4, tableAttrs: { style: { width: '100%' } } },
                    defaults:    {
                        listeners: { change:    function()      { renderUpdateDo() }     },
                                     mouseover: function(color) { renderUpdateDo(color); },
                                     mouseout:  function(color) { renderUpdateDo();      }
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
                },


                /* Speedometer Chart */
                {
                    fieldLabel: 'Size',
                    xtype:      'fieldcontainer',
                    cls:        'speedometer',
                    layout:     'table',
                    defaults: { listeners: { change: function() { renderUpdate(undefined, true) } } },
                    items: [{ xtype: 'label', text: 'Width:', style: 'margin-left: 0; margin-right: 2px;' },
                            { xtype: 'numberunit', name: 'speedowidth', unit: 'px', width: 65, value: panel.xdata.appearance.speedowidth },
                            { xtype: 'label', text: 'Shadow:', style: 'margin-left: 0px; margin-right: 2px;', hidden: true },
                            { xtype: 'checkbox', name: 'speedoshadow', hidden: true },
                            { xtype: 'label', text: 'Needle:', style: 'margin-left: 8px; margin-right: 2px;' },
                            { xtype: 'checkbox', name: 'speedoneedle' },
                            { xtype: 'label', text: 'Donut:', style: 'margin-left: 8px; margin-right: 2px;' },
                            { xtype: 'numberunit', allowDecimals: false, width: 60, name: 'speedodonut', unit: 'px' }
                        ]
                }, {
                    fieldLabel: 'Axis',
                    xtype:      'fieldcontainer',
                    cls:        'speedometer',
                    layout:     'table',
                    defaults: { listeners: { change: function() { renderUpdate(undefined, true) } } },
                    items: [
                    { xtype: 'label', text: 'Steps:', style: 'margin-left: 0px; margin-right: 2px;' },
                    {
                        xtype:      'numberfield',
                        allowDecimals: false,
                        width:       60,
                        name:       'speedosteps',
                        step:        1,
                        minValue:    0,
                        maxValue:    1000
                    },
                    { xtype: 'label', text: 'Margin:', style: 'margin-left: 8px; margin-right: 2px;' },
                    {
                        xtype:      'numberunit',
                        allowDecimals: false,
                        width:       60,
                        name:       'speedomargin',
                        unit:       'px'
                    }]
                }, {
                    fieldLabel: 'Colors',
                    cls:        'speedometer',
                    xtype:      'fieldcontainer',
                    layout:      { type: 'table', columns: 4, tableAttrs: { style: { width: '100%' } } },
                    defaults:    {
                        listeners: { change:    function()      { renderUpdateDo() }     },
                                     mouseover: function(color) { renderUpdateDo(color); },
                                     mouseout:  function(color) { renderUpdateDo();      }
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
                    listeners: { focus:  perfDataUpdate,
                                 change: function() { renderUpdate(undefined, true) }
                    }
                }, {
                    fieldLabel: 'Options',
                    xtype:      'fieldcontainer',
                    cls:        'speedometer',
                    layout:     'table',
                    defaults: { listeners: { change: function() { renderUpdate(undefined, true) } } },
                    items: [{ xtype: 'label', text: 'Invert:', style: 'margin-left: 0; margin-right: 2px;' },
                            { xtype: 'checkbox', name: 'speedoinvert' },
                            { xtype: 'label', text: 'Min:', style: 'margin-left: 8px; margin-right: 2px;' },
                            { xtype: 'numberfield', allowDecimals: true, width: 70, name: 'speedomin', step: 100 },
                            { xtype: 'label', text: 'Max:', style: 'margin-left: 8px; margin-right: 2px;' },
                            { xtype: 'numberfield', allowDecimals: true, width: 70, name: 'speedomax', step: 100 }
                        ]
                }]
            }]
        }]
    };

    /* Link Settings Tab */
    var server_actions_menu = [];
    Ext.Array.each(action_menu_actions, function(name, i) {
        server_actions_menu.push({
            text:    name,
            icon:    url_prefix+'plugins/panorama/images/cog.png',
            handler: function(This, eOpts) { This.up('form').getForm().setValues({link: 'server://'+name+'/'}) }
        });
    });
    var action_menus_menu = [];
    Ext.Array.each(action_menu_items, function(val, i) {
        var name = val[0];
        action_menus_menu.push({
            text:    name,
            icon:    url_prefix+'plugins/panorama/images/cog.png',
            handler: function(This, eOpts) { This.up('form').getForm().setValues({link: 'menu://'+name+'/'}) }
        });
    });
    var linkTab = {
        title: 'Link',
        type:  'panel',
        items: [{
            xtype : 'panel',
            layout: 'fit',
            border: 0,
            items: [{
                xtype:           'form',
                id:              'linkForm',
                bodyPadding:     2,
                border:          0,
                bodyStyle:       'overflow-y: auto;',
                submitEmptyText: false,
                defaults:      { anchor: '-12', labelWidth: 132 },
                items: [{
                    fieldLabel: 'Hyperlink',
                    xtype:      'textfield',
                    name:       'link',
                    emptyText:  'http://... or predefined from below'
                }, {
                    fieldLabel: 'Predefined Links',
                    xtype:      'fieldcontainer',
                    items:      [{
                        xtype:      'button',
                        text:       'Choose',
                        icon:       url_prefix+'plugins/panorama/images/world.png',
                        menu:       {
                            items: [{
                                text: 'My Dashboards',
                                icon: url_prefix+'plugins/panorama/images/user_suit.png',
                                menu: [{
                                    text:    'Loading...',
                                    icon:    url_prefix+'plugins/panorama/images/loading-icon.gif',
                                    disabled: true
                                }]
                            }, {
                                text: 'Public Dashboards',
                                icon: url_prefix+'plugins/panorama/images/world.png',
                                menu: [{
                                    text:    'Loading...',
                                    icon:    url_prefix+'plugins/panorama/images/loading-icon.gif',
                                    disabled: true
                                }]
                            }, {
                                text:    'Show Details',
                                icon:    url_prefix+'plugins/panorama/images/application_view_columns.png',
                                handler: function(This, eOpts) { This.up('form').getForm().setValues({link: 'dashboard://show_details'}) }
                            }, {
                                text:    'Refresh',
                                icon:    url_prefix+'plugins/panorama/images/arrow_refresh.png',
                                handler: function(This, eOpts) { This.up('form').getForm().setValues({link: 'dashboard://refresh'}) }
                            }, {
                                text: 'Server Actions',
                                icon: url_prefix+'plugins/panorama/images/lightning_go.png',
                                menu: server_actions_menu,
                                disabled: server_actions_menu.length > 0 ? false : true
                            }, {
                                text: 'Action Menus',
                                icon: url_prefix+'plugins/panorama/images/lightning_go.png',
                                menu: action_menus_menu,
                                disabled: action_menus_menu.length > 0 ? false : true
                            }],
                            listeners: {
                                afterrender: function(This, eOpts) {
                                    TP.load_dashboard_menu_items(This.items.get(0).menu, 'panorama.cgi?task=dashboard_list&list=my',     function(val) { This.up('form').getForm().setValues({link: 'dashboard://'+val.replace(/^tabpan-tab_/,'')})}, true);
                                    TP.load_dashboard_menu_items(This.items.get(1).menu, 'panorama.cgi?task=dashboard_list&list=public', function(val) { This.up('form').getForm().setValues({link: 'dashboard://'+val.replace(/^tabpan-tab_/,'')})}, true);
                                }
                            }
                        }
                    }]
                }, {
                    fieldLabel: 'New Tab',
                    xtype:      'checkbox',
                    name:       'newtab',
                    boxLabel:   '(opens links in new tab or window)'
                }]
            }]
        }]
    };

    /* Label Settings Tab */
    var labelUpdate = function() { var xdata = TP.get_icon_form_xdata(settingsWindow); panel.setIconLabel(xdata.label || {}, true); };
    var labelTab = {
        title: 'Label',
        type:  'panel',
        items: [{
            xtype : 'panel',
            layout: 'fit',
            border: 0,
            items: [{
                xtype:           'form',
                id:              'labelForm',
                bodyPadding:     2,
                border:          0,
                bodyStyle:       'overflow-y: auto;',
                submitEmptyText: false,
                defaults:      { anchor: '-12', labelWidth: 80, listeners: { change: labelUpdate } },
                items: [{
                    fieldLabel:   'Labeltext',
                    xtype:        'fieldcontainer',
                    layout:      { type: 'hbox', align: 'stretch' },
                    items: [{
                        xtype:        'textfield',
                        name:         'labeltext',
                        flex:          1,
                        id:           'label_textfield',
                        listeners:   { change: labelUpdate }
                    }, {
                        xtype:        'button',
                        icon:         url_prefix+'plugins/panorama/images/lightning_go.png',
                        margins:      {top: 0, right: 0, bottom: 0, left: 3},
                        tooltip:       'open label editor wizard',
                        handler:       function(btn) {
                            TP.openLabelEditorWindow(panel);
                        }
                    }]
                }, {
                    fieldLabel:   'Color',
                    xtype:        'colorcbo',
                    name:         'fontcolor',
                    value:        '#000000',
                    mouseover:     function(color) { var oldValue=this.getValue(); this.setValue(color); labelUpdate(); this.setRawValue(oldValue); },
                    mouseout:      function(color) { labelUpdate(); }
                }, {
                    xtype:        'fieldcontainer',
                    fieldLabel:   'Font',
                    layout:      { type: 'hbox', align: 'stretch' },
                    defaults:    { listeners: { change: labelUpdate } },
                    items:        [{
                        name:         'fontfamily',
                        xtype:        'fontcbo',
                        value:        '',
                        flex:          1,
                        editable:      false
                    }, {
                        xtype:        'numberunit',
                        allowDecimals: false,
                        name:         'fontsize',
                        width:         60,
                        unit:         'px',
                        margins:      {top: 0, right: 0, bottom: 0, left: 3},
                        value:         panel.xdata.label.fontsize != undefined ? panel.xdata.label.fontsize : 14
                    }, {
                        xtype:        'hiddenfield',
                        name:         'fontitalic',
                        value:         panel.xdata.label.fontitalic
                    }, {
                        xtype:        'button',
                        enableToggle:  true,
                        name:         'fontitalic',
                        icon:         url_prefix+'plugins/panorama/images/text_italic.png',
                        margins:      {top: 0, right: 0, bottom: 0, left: 3},
                        toggleHandler: function(btn, state) { this.up('form').getForm().setValues({fontitalic: state ? '1' : '' }); },
                        listeners: {
                            afterrender: function() { if(panel.xdata.label.fontitalic) { this.toggle(); } }
                        }
                    }, {
                        xtype:        'hiddenfield',
                        name:         'fontbold',
                        value:         panel.xdata.label.fontbold
                    }, {
                        xtype:        'button',
                        enableToggle:  true,
                        name:         'fontbold',
                        icon:         url_prefix+'plugins/panorama/images/text_bold.png',
                        margins:      {top: 0, right: 0, bottom: 0, left: 3},
                        toggleHandler: function(btn, state) { this.up('form').getForm().setValues({fontbold: state ? '1' : ''}); },
                        listeners: {
                            afterrender: function() { if(panel.xdata.label.fontbold) { this.toggle(); } }
                        }
                    }]
                }, {
                    xtype:        'fieldcontainer',
                    fieldLabel:   'Position',
                    layout:      { type: 'hbox', align: 'stretch' },
                    defaults:    { listeners: { change: labelUpdate } },
                    items:        [{
                        name:         'position',
                        xtype:        'combobox',
                        store:        ['below', 'above', 'left', 'right', 'center', 'top-left'],
                        value:        'below',
                        flex:          1,
                        editable:      false
                    }, {
                        xtype:        'label',
                        text:         'Offset: x',
                        margins:      {top: 3, right: 2, bottom: 0, left: 7}
                    }, {
                        xtype:        'numberunit',
                        allowDecimals: false,
                        name:         'offsetx',
                        width:         60,
                        unit:         'px'
                    }, {
                        xtype:        'label',
                        text:         'y',
                        margins:      {top: 3, right: 2, bottom: 0, left: 7}
                    }, {
                        xtype:        'numberunit',
                        allowDecimals: false,
                        name:         'offsety',
                        width:         60,
                        unit:         'px'
                    }]
                }, {
                    fieldLabel:   'Orientation',
                    name:         'orientation',
                    xtype:        'combobox',
                    store:        ['horizontal', 'vertical'],
                    value:        'horizontal',
                    editable:      false
                }, {
                    fieldLabel:   'Background',
                    xtype:        'colorcbo',
                    name:         'bgcolor',
                    value:        '',
                    mouseover:     function(color) { var oldValue=this.getValue(); this.setValue(color); labelUpdate(); this.setRawValue(oldValue); },
                    mouseout:      function(color) { labelUpdate(); }
                }, {
                    xtype:        'fieldcontainer',
                    fieldLabel:   'Border',
                    layout:      { type: 'hbox', align: 'stretch' },
                    defaults:    { listeners: { change: labelUpdate } },
                    items:        [{
                        xtype:        'colorcbo',
                        name:         'bordercolor',
                        value:        '',
                        mouseover:     function(color) { var oldValue=this.getValue(); this.setValue(color); labelUpdate(); this.setRawValue(oldValue); },
                        mouseout:      function(color) { labelUpdate(); },
                        flex:          1,
                        margins:      {top: 0, right: 3, bottom: 0, left: 0}
                    }, {
                        xtype:        'numberunit',
                        allowDecimals: false,
                        name:         'bordersize',
                        width:         60,
                        unit:         'px'
                    }]
                }, {
                    fieldLabel: 'Backgr. Size',
                    xtype:      'fieldcontainer',
                    layout:     'table',
                    items: [{ xtype: 'label', text:  'width:', style: 'margin-left: 0; margin-right: 2px;' },
                            { xtype: 'numberfield', name:  'width', width: 55, value: panel.xdata.label.width, listeners: {
                                change: function(This, newValue, oldValue, eOpts) {
                                    labelUpdate();
                                }
                            }},
                            { xtype: 'label', text:  'height:', style: 'margin-left: 10px; margin-right: 2px;' },
                            { xtype: 'numberfield', name:  'height', width: 55, value: panel.xdata.label.height, listeners: {
                                change: function(This, newValue, oldValue, eOpts) {
                                    labelUpdate();
                                }
                            }}
                        ]
                    }
                ]
            }]
        }]
    };

    /* Source Tab */
    var sourceTab = {
        title: 'Source',
        type:  'panel',
        listeners: {
            activate: function(This) {
                var xdata = TP.get_icon_form_xdata(settingsWindow);
                var j     = Ext.JSON.encode(xdata);
                try {
                    j = JSON.stringify(xdata, null, 2);
                } catch(err) {
                    TP.logError(panel.id, "jsonStringifyException", err);
                }
                this.down('form').getForm().setValues({source: j, sourceError: ''});
            }
        },
        items: [{
            xtype : 'panel',
            layout: 'fit',
            border: 0,
            items: [{
                xtype:           'form',
                id:              'sourceForm',
                bodyPadding:     2,
                border:          0,
                bodyStyle:       'overflow-y: auto;',
                submitEmptyText: false,
                defaults:      { anchor: '-12', labelWidth: 50 },
                items: [{
                    fieldLabel:     'Source',
                    xtype:          'textarea',
                    name:           'source',
                    height:         190
                }, {
                    fieldLabel:     ' ',
                    labelSeparator: '',
                    xtype:          'fieldcontainer',
                    items: [{
                        xtype:      'button',
                        name:       'sourceapply',
                        text:       'Apply',
                        width:       100,
                        handler: function(btn) {
                            var values = Ext.getCmp('sourceForm').getForm().getValues();
                            try {
                                var xdata = Ext.JSON.decode(values.source);
                                TP.setIconSettingsValues(xdata);
                            } catch(err) {
                                TP.logError(panel.id, "jsonDecodeException", err);
                                Ext.getCmp('sourceForm').getForm().setValues({sourceError: err});
                            }
                        }
                    }]
                }, {
                    fieldLabel:     ' ',
                    labelSeparator: '',
                    xtype:          'displayfield',
                    name:           'sourceError',
                    value:          ''
                }]
            }]
        }]
    };

    var tabPanel = new Ext.TabPanel({
        activeTab         : panel.initialSettingsTab ? panel.initialSettingsTab : 0,
        enableTabScroll   : true,
        items             : [
            generalTab,
            layoutTab,
            appearanceTab,
            linkTab,
            labelTab,
            sourceTab
        ]
    });

    /* add current available backends */
    var backendItem = TP.getFormField(Ext.getCmp("generalForm"), 'backends');
    if(backendItem) {
        TP.updateArrayStoreKV(backendItem.store, TP.getAvailableBackendsTab(tab));
        if(backendItem.store.count() <= 1) { backendItem.hide(); }
    }

    var settingsWindow = new Ext.Window({
        height:  350,
        width:   400,
        layout: 'fit',
        items:   tabPanel,
        panel:   panel,
        title:  'Icon Settings',
        buttonAlign: 'center',
        fbar: [/* panlet setting cancel button */
               { xtype:  'button',
                 text:   'cancel',
                 handler: function(This) {
                    settingsWindow.destroy();
                 }
               },
               /* panlet setting save button */
               { xtype:  'button',
                 text:   'save',
                 handler: function() {
                    settingsWindow.skipRestore = true;
                    panel.stateful = true;
                    delete panel.xdata.label;
                    delete panel.xdata.link;
                    var xdata = TP.get_icon_form_xdata(settingsWindow);
                    TP.log('['+this.id+'] icon config updated: '+Ext.JSON.encode(xdata));
                    for(var key in xdata) { panel.xdata[key] = xdata[key]; }
                    panel.applyState({xdata: panel.xdata});
                    if(panel.classChanged) {
                        panel.xdata.cls = panel.classChanged;
                    }
                    panel.forceSaveState();
                    delete TP.iconSettingsWindow;
                    settingsWindow.destroy();
                    panel.firstRun = false;
                    panel.applyXdata();
                    var tab = Ext.getCmp(panel.panel_id);
                    TP.updateAllIcons(tab, panel.id);
                    TP.updateAllLabelAvailability(tab, panel.id);
                 }
               }
        ],
        listeners: {
            afterRender: function (This) {
                var form = This.items.getAt(0).items.getAt(1).down('form').getForm();
                this.nav = Ext.create('Ext.util.KeyNav', this.el, {
                    'left':  function(evt){ form.setValues({x: Number(form.getValues().x)-1}); },
                    'right': function(evt){ form.setValues({x: Number(form.getValues().x)+1}); },
                    'up':    function(evt){ form.setValues({y: Number(form.getValues().y)-1}); },
                    'down':  function(evt){ form.setValues({y: Number(form.getValues().y)+1}); },
                    ignoreInputFields: true,
                    scope: panel
                });
            },
            destroy: function() {
                delete TP.iconSettingsWindow;
                panel.stateful = true;

                if(!settingsWindow.skipRestore) {
                    // if we cancel directly after adding a new icon, destroy it
                    tab.enableMapControlsTemp();
                    if(panel.firstRun) {
                        panel.destroy();
                    } else {
                        if(panel.classChanged) {
                            var key = panel.id;
                            panel.redrawOnly = true;
                            panel.destroy();
                            TP.timeouts['timeout_' + key + '_show_settings'] = window.setTimeout(function() {
                                panel = TP.add_panlet({id:key, skip_state:true, tb:tab, autoshow:true}, false);
                                TP.updateAllIcons(Ext.getCmp(panel.panel_id), panel.id);
                            }, 50);
                            return;
                        } else {
                            // restore position and layout
                            if(panel.setRenderItem) { panel.setRenderItem(undefined, true); }
                            if(TP.cp.state[panel.id])  { panel.applyXdata(TP.cp.state[panel.id].xdata); }
                        }
                    }
                }
                if(panel.el) {
                    panel.el.dom.style.outline = "";
                    panel.setIconLabel();
                }
                if(panel.dragEl1 && panel.dragEl1.el) { panel.dragEl1.el.dom.style.outline = ""; }
                if(panel.dragEl2 && panel.dragEl2.el) { panel.dragEl2.el.dom.style.outline = ""; }
                if(panel.labelEl && panel.labelEl.el) { panel.labelEl.el.dom.style.outline = ""; }
                TP.updateAllIcons(Ext.getCmp(panel.panel_id)); // workaround to put labels in front
            }
        }
    }).show();
    tab.body.unmask();

    TP.setIconSettingsValues(panel.xdata);
    TP.iconSettingsWindow = settingsWindow;

    // new mouseover tips while settings are open
    TP.iconTip.hide();

    // move settings window next to panel itself
    var showAtPos = TP.getNextToPanelPos(panel, settingsWindow.width, settingsWindow.height);
    panel.setIconLabel(undefined, true);
    settingsWindow.showAt(showAtPos);
    TP.iconSettingsWindow.panel = panel;

    settingsWindow.renderUpdateDo = renderUpdateDo;
    renderUpdate = function(forceColor, forceRenderItem) {
        if(TP.skipRender) { return; }
        TP.reduceDelayEvents(TP.iconSettingsWindow, function() {
            if(TP.skipRender)          { return; }
            if(!TP.iconSettingsWindow) { return; }
            TP.iconSettingsWindow.renderUpdateDo(forceColor, forceRenderItem);
        }, 100, 'timeout_settings_render_update');
    };
    settingsWindow.renderUpdate = renderUpdate;
    renderUpdate();

    /* highlight current icon */
    if(panel.xdata.appearance.type == "connector") {
        panel.dragEl1.el.dom.style.outline = "2px dotted orange";
        panel.dragEl2.el.dom.style.outline = "2px dotted orange";
    } else if (panel.iconType == "text") {
        panel.labelEl.el.dom.style.outline = "2px dotted orange";
    } else {
        panel.el.dom.style.outline = "2px dotted orange";
    }

    window.setTimeout(function() {
        TP.iconSettingsWindow.toFront();
    }, 100);
    TP.modalWindows.push(settingsWindow);
};

TP.get_icon_form_xdata = function(settingsWindow) {
    var xdata = {
        general:    Ext.getCmp('generalForm').getForm().getValues(),
        layout:     Ext.getCmp('layoutForm').getForm().getValues(),
        appearance: Ext.getCmp('appearanceForm').getForm().getValues(),
        link:       Ext.getCmp('linkForm').getForm().getValues(),
        label:      Ext.getCmp('labelForm').getForm().getValues()
    }
    // clean up
    if(xdata.label.labeltext == '') { delete xdata.label; }
    if(xdata.link.link == '')       { delete xdata.link;  }
    if(xdata.layout.rotation == 0)  { delete xdata.layout.rotation; }
    Ext.getCmp('appearance_types').store.each(function(data, i) {
        var t = data.raw[0];
        for(var key in xdata.appearance) {
            var t2 = t;
            if(t == 'speedometer') { t2 = 'speedo'; }
            var p = new RegExp('^'+t2, 'g');
            if(key.match(p) && t != xdata.appearance.type) {
                delete xdata.appearance[key];
            }
        }
    });
    if(settingsWindow.panel.hideAppearanceTab)  { delete xdata.appearance; }
    if(settingsWindow.panel.iconType == 'text') { delete xdata.general;    }
    if(xdata.appearance) {
        delete xdata.appearance.speedoshadow;
        delete xdata.appearance.pieshadow;
    }
    if(xdata.general) {
        delete xdata.general.newcls;
    }
    return(xdata);
}

TP.openLabelEditorWindow = function(panel) {
    var oldValue  = Ext.getCmp('label_textfield').getValue();
    var perf_data = '';
    window.perfdata = {};
    // ensure fresh and correct performance data
    panel.setIconLabel(undefined, true);
    for(var key in perfdata) {
        delete perfdata[key].perf;
        delete perfdata[key].key;
        for(var key2 in perfdata[key]) {
            var keyname = '.'+key;
            if(key.match(/[^a-zA-Z]/)) { keyname = '[\''+key+'\']'; }
            perf_data += '<tr><td><\/td><td><i>perfdata'+keyname+'.'+key2+'<\/i><\/td><td>'+perfdata[key][key2]+'<\/td><\/tr>'
        }
    }

    var labelEditorWindow = new Ext.Window({
        height:  500,
        width:   650,
        layout: 'fit',
        title:  'Label Editor',
        modal:  true,
        buttonAlign: 'center',
        fbar: [/* panlet setting cancel button */
               { xtype:  'button',
                 text:   'cancel',
                 handler: function(This) {
                    var labelEditorWindow = This.up('window');
                    Ext.getCmp('label_textfield').setValue(oldValue);
                    labelEditorWindow.destroy();
                 }
               },
               /* panlet setting save button */
               { xtype:  'button',
                 text:   'save',
                 handler: function(This) {
                    var labelEditorWindow = This.up('window');
                    Ext.getCmp('label_textfield').setValue(labelEditorWindow.down('textarea').getValue())
                    labelEditorWindow.destroy();
                 }
               }
        ],
        items:   [{
            xtype:           'form',
            bodyPadding:     2,
            border:          0,
            bodyStyle:       'overflow-y: auto;',
            submitEmptyText: false,
            layout:          'anchor',
            defaults:      { width: '99%', labelWidth: 40 },
            items:        [{
                xtype:      'textarea',
                fieldLabel: 'Label',
                value:       Ext.getCmp('label_textfield').getValue().replace(/<br>/g,"<br>\n"),
                id:         'label_textfield_edit',
                height:      90,
                listeners: {
                    change: function(This) {
                        Ext.getCmp('label_textfield').setValue(This.getValue())
                    }
                }
            }, {
                fieldLabel: 'Help',
                xtype:      'fieldcontainer',
                items:      [{
                    xtype:   'label',
                    cls:     'labelhelp',
                    html:    '<p>Use HTML to format your label<br>'
                            +'Ex.: <i>Host &lt;b&gt;{{name}}&lt;/b&gt;<\/i>, Newlines: <i>&lt;br&gt;<\/i><\/p>'
                            +'<p>It is possible to create dynamic labels with {{placeholders}}.<br>'
                            +'Ex.: <i>Host {{name}}: {{plugin_output}}<\/i><\/p>'
                            +'<p>You may also do calculations inside placeholders like this:<br>'
                            +'Ex.: <i>Group XY {{totals.ok}}/{{totals.ok + totals.critical + totals.warning + totals.unknown}}<\/i><\/p>'
                            +'<p>use sprintf to format numbers:<br>'
                            +'Ex.: <i>{{sprintf("%.2f %s",perfdata.rta.val, perfdata.rta.unit)}}<\/i><\/p>'
                            +'<p>use strftime to format timestamps:<br>'
                            +'Ex.: <i>{{strftime("%Y-%m-%d",last_check)}}<\/i><\/p>'
                            +'<p>conditionals are possible:<br>'
                            +'Ex.: <i>{{ if(acknowledged) {...} else {...} }}<\/i><\/p>'

                            +'<p>There are different variables available depending on the type of icon/widget:<br>'
                            +'<table><tr><th>Groups/Filters:<\/th><td><i>totals.services.ok<\/i><\/td><td>totals number of ok services<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>totals.services.warning<\/i><\/td><td>totals number of warning services<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>totals.services.critical<\/i><\/td><td>totals number of critical services<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>totals.services.unknown<\/i><\/td><td>totals number of unknown services<\/td><\/tr>'

                            +'<tr><td><\/td><td><i>totals.hosts.up<\/i><\/td><td>totals number of up hosts<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>totals.hosts.down<\/i><\/td><td>totals number of down hosts<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>totals.hosts.unreachable<\/i><\/td><td>totals number of unreachable hosts<\/td><\/tr>'

                            +'<tr><th>Hosts:<\/th><td><i>name<\/i><\/td><td>Hostname<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>state<\/i><\/td><td>State: 0 - Ok, 1 - Warning, 2 - Critical,...<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>performance_data<\/i><\/td><td>Performance data. Use list below to access specific values<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>has_been_checked<\/i><\/td><td>Has this host been checked: 0 - No, 1 - Yes<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>scheduled_downtime_depth<\/i><\/td><td>Downtime: 0 - No, &gtl;=1 - Yes<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>acknowledged<\/i><\/td><td>Has this host been acknowledged: 0 - No, 1 - Yes<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>last_check<\/i><\/td><td>Timestamp of last check<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>last_state_change<\/i><\/td><td>Timestamp of last state change<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>last_notification<\/i><\/td><td>Timestamp of last notification<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>plugin_output<\/i><\/td><td>Plugin Output<\/td><\/tr>'

                            +'<tr><th>Services:<\/th><td><i>host_name<\/i><\/td><td>Hostname<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>description<\/i><\/td><td>Servicename<\/td><\/tr>'
                            +'<tr><td><\/td><td colspan=2>(other attributes are identical to hosts)<\/td><\/tr>'

                            +'<tr><th>Performance Data:<\/th><td colspan=2>(available performance data with their current values)<\/td><\/tr>'
                            +perf_data

                            +'<tr><th>Availability Data:<\/th><td colspan=2><\/td><\/tr>'
                            +'<tr><td><\/td><td><i>{{ sprintf("%.2f", availability({d: "60m"})) }}%<\/i><\/td><td>availability for the last 60 minutes<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>{{ sprintf("%.2f", availability({d: "24h"})) }}%<\/i><\/td><td>availability for the last 24 hours<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>{{ sprintf("%.2f", availability({d: "7d"})) }}%<\/i><\/td><td>availability for the last 7 days<\/td><\/tr>'
                            +'<tr><td><\/td><td><i>{{ sprintf("%.2f", availability({d: "31d"})) }}%<\/i><\/td><td>availability for the last 31 days<\/td><\/tr>'
                            +'<tr><td><\/td><td colspan=2><i>{{ sprintf("%.2f", availability({d: "24h", tm: "5x8"})) }}%<\/i><\/td><\/tr>'
                            +'<tr><td><\/td><td><\/td><td>availability for the last 24 hours within given timeperiod<\/td><\/tr>'

                            +'<\/table>',
                        listeners: {
                            afterrender: function(This) {
                                var examples = This.el.dom.getElementsByTagName('i');
                                Ext.Array.each(examples, function(el, i) {
                                    el.className = "clickable";
                                    el.onclick   = function(i) {
                                        var cur = Ext.getCmp('label_textfield_edit').getValue();
                                        var val = Ext.htmlDecode(el.innerHTML);
                                        if(!val.match(/\{\{.*?\}\}/) && (val.match(/^perfdata\./) || val.match(/^perfdata\[/) || val.match(/^totals\./) || val.match(/^avail\./) || val.match(/^[a-z_]+$/))) { val = '{{'+val+'}}'; }
                                        if(val.match(/<br>/)) { val += "\n"; }
                                        Ext.getCmp('label_textfield_edit').setValue(cur+val);
                                        Ext.getCmp('label_textfield_edit').up('form').body.dom.scrollTop=0;
                                        Ext.getCmp('label_textfield_edit').focus();
                                    }
                                });
                            }
                        }
                }]
            }]
        }]
    }).show();
    Ext.getCmp('label_textfield').setValue(" ");
    Ext.getCmp('label_textfield').setValue(Ext.getCmp('label_textfield_edit').getValue());
    TP.modalWindows.push(labelEditorWindow);
    labelEditorWindow.toFront();
}

TP.setIconSettingsValues = function(xdata) {
    xdata = TP.clone(xdata);
    // set some defaults
    if(!xdata.label)            { xdata.label = { labeltext: '' }; }
    if(!xdata.label.fontsize)   { xdata.label.fontsize   = 14; }
    if(!xdata.label.bordersize) { xdata.label.bordersize =  1; }
    Ext.getCmp('generalForm').getForm().setValues(xdata.general);
    Ext.getCmp('layoutForm').getForm().setValues(xdata.layout);
    Ext.getCmp('appearanceForm').getForm().setValues(xdata.appearance);
    Ext.getCmp('linkForm').getForm().setValues(xdata.link);
    Ext.getCmp('labelForm').getForm().setValues(xdata.label);
}

TP.getNextToPanelPos = function(panel, width, height) {
    if(!panel || !panel.el) { return([0,0]); }
    var sizes = [];
    sizes.push(panel.getSize().width);
    if(panel.labelEl) {
        sizes.push(panel.labelEl.getSize().width);
    }
    sizes.push(180); // max size of new speedos
    var offsetLeft  = 30;
    var offsetRight = Ext.Array.max(sizes) + 10;
    var offsetY = 40;
    var panelPos     = panel.getPosition();
    var viewPortSize = TP.viewport.getSize();
    if(viewPortSize.width > panelPos[0] + width+offsetRight) {
        panelPos[0] = panelPos[0] + offsetRight;
    } else {
        panelPos[0] = panelPos[0] - width - offsetLeft;
    }
    if(panelPos[1] - 50 < 0) {
        panelPos[1] = offsetY;
    }
    else if(viewPortSize.height > panelPos[1] + height - offsetY) {
        panelPos[1] = panelPos[1] - offsetY;
    } else {
        panelPos[1] = viewPortSize.height - height - offsetY;
    }
    // make sure its on the screen
    if(panelPos[0] <  0) { panelPos[0] =  0; }
    if(panelPos[1] < 20) { panelPos[1] = 20; }
    return(panelPos);
}
