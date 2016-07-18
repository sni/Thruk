Ext.define('TP.IconWidgetAppearanceConnector', {

    alias:  'tp.icon.appearance.connector',

    constructor: function(config) {
        var me = this;
        Ext.apply(me, config);
    },

    setRenderItem: function(xdata) {
        var panel = this.panel;
    },

    /* update render item on active tab only */
    updateRenderActive: function(xdata) {
        this.connectorRender(xdata);
    },

    /* renders connector */
    connectorRender: function(xdata, forceColor, panel) {
        if(panel == undefined) { panel = this.panel; }
        if(xdata == undefined) { xdata = panel.xdata; }
        if(xdata.appearance.type != 'connector') { return }

        if(!panel.surface) {
            panel.setRenderItem(xdata);
            return;
        }

        var fromX     = xdata.appearance.connectorfromx;
        var fromY     = xdata.appearance.connectorfromy;
        var toX       = xdata.appearance.connectortox;
        var toY       = xdata.appearance.connectortoy;
        var arrowtype = xdata.appearance.connectorarrowtype;
        if(isNaN(fromX)) { return; }

        if(!panel.surface.el) { return };

        if(fromX > toX) {
            fromX = xdata.appearance.connectortox;
            fromY = xdata.appearance.connectortoy;
            toX   = xdata.appearance.connectorfromx;
            toY   = xdata.appearance.connectorfromy;
            if(     arrowtype == "right") { arrowtype = "left"; }
            else if(arrowtype == "left")  { arrowtype = "right"; }
        }
        var connectorarrowwidth = xdata.appearance.connectorarrowwidth;

        /* variable arrow sizes */
        var shapeColor = TP.getShapeColor("connector", panel, xdata, forceColor);
        var connectorwidth = xdata.appearance.connectorwidth;
        if(xdata.appearance.connectorvariable) {
            var percent = 100;
            var state   = xdata.state != undefined ? xdata.state : panel.xdata.state;
            if(shapeColor.value != undefined) {
                var min   = shapeColor.range.min;
                var max   = shapeColor.range.max;
                if(xdata.appearance.connectormin != undefined) { min = xdata.appearance.connectormin; }
                if(xdata.appearance.connectormax != undefined) { max = xdata.appearance.connectormax; }
                if(min == undefined) { min = 0; }
                percent = ((shapeColor.value-min) / (max-min)) * 100;
                if(percent > 100) { percent = 100 }
            }
            else if(state == 0) { percent =   0; }
            else if(state == 1) { percent =  50; }
            else if(state == 2) { percent = 100; }
            else if(state == 3) { percent =  50; }
            else if(state == 4) { percent =   0; }
            connectorwidth = connectorwidth * (percent/100);
            if(connectorwidth < 1)    { connectorwidth = 1; }
            if(isNaN(connectorwidth)) { connectorwidth = 1; }
        }

        /* calculate distance, draw horizontal arrow with that length and rotate it later. save a lot of work to rotate by ourselves */
        var distance  = Math.ceil(Math.sqrt(Math.pow(toX-fromX, 2)
                                          + Math.pow(toY-fromY, 2)));
        if(isNaN(distance) || distance == 0) {
            return;
        }
        var start = [ 0, 0 ];
        var end   = [ distance, 0 ];

        /* get angle between points */
        var angle = Math.atan((toY-fromY)/(toX-fromX))*180/Math.PI;

        var points = [[start[0],start[1]]];
        /* top half of left arrow */
        if(arrowtype == "both" || arrowtype == "left") {
            points.push(
                [(start[0]+xdata.appearance.connectorarrowlength), (start[1]-connectorwidth/2-connectorarrowwidth)],
                [(start[0]+xdata.appearance.connectorarrowlength-xdata.appearance.connectorarrowinset), (start[1]-connectorwidth/2)]
            );
        } else {
            points.push(
                [start[0], (start[1]-connectorwidth/2)]
            );
        }

        /* right arrow */
        if(arrowtype == "both" || arrowtype == "right") {
            points.push(
                [end[0]-xdata.appearance.connectorarrowlength+xdata.appearance.connectorarrowinset, (end[1]-connectorwidth/2)],
                [end[0]-xdata.appearance.connectorarrowlength, (end[1]-connectorwidth/2-connectorarrowwidth)],
                [end[0], end[1]],
                [end[0]-xdata.appearance.connectorarrowlength, (end[1]+connectorwidth/2+connectorarrowwidth)],
                [end[0]-xdata.appearance.connectorarrowlength+xdata.appearance.connectorarrowinset, (end[1]+connectorwidth/2)]
            );
        } else {
            points.push(
                [end[0], (end[1]-connectorwidth/2)],
                [end[0], (end[1]+connectorwidth/2)]
            );
        }

        /* bottom half of left arrow */
        if(arrowtype == "both" || arrowtype == "left") {
            points.push(
                [(start[0]+xdata.appearance.connectorarrowlength-xdata.appearance.connectorarrowinset), (start[1]+connectorwidth/2)],
                [(start[0]+xdata.appearance.connectorarrowlength), (start[1]+connectorwidth/2+connectorarrowwidth)]
            );
        } else {
            points.push(
                [start[0], (start[1]+connectorwidth/2)]
            );
        }

        panel.surface.removeAll();
        sprite = panel.surface.add({
            type: "path",
            path: TP.pointsToPath(points),
            fill: shapeColor.color
        });
        sprite.setAttributes({rotate:{degrees: angle, x:0, y:0}}, true);
        var box = sprite.getBBox();
        sprite.setAttributes({translate:{x:-box.x,y:-box.y+(arrowtype == "none" ? connectorarrowwidth : 0)}}, true);
        var newHeight = Math.ceil(Ext.Array.max([connectorarrowwidth+connectorwidth, box.height]));
        panel.setSize(Math.ceil(box.width), newHeight);
        panel.surface.setSize(Math.ceil(box.width), newHeight);
        panel.surface.el.dom.parentNode.style.width  = Math.ceil(box.width)+"px";
        panel.surface.el.dom.parentNode.style.height = newHeight+"px";
        sprite.show(true);
        /* adjust position: first point in path is the rotated start point, so we can get our current offset from there */
        xdata.layout.x = Math.ceil(fromX-box.path[0][1]+box.x);
        xdata.layout.y = Math.ceil(fromY-box.path[0][2]+box.y);
        panel.setRawPosition(xdata.layout.x, xdata.layout.y);
        panel.updateMapLonLat(true);

        /* adjust drag elements position */
        Ext.Array.each([panel.dragEl1, panel.dragEl2], function(dragEl) {
            if(dragEl != undefined) {
                dragEl.suspendEvents();
                dragEl.setPosition(xdata.appearance[dragEl.keyX]+dragEl.offsetX, xdata.appearance[dragEl.keyY]+dragEl.offsetY);
                dragEl.resumeEvents();
                try { dragEl.toFront(); } catch(err) {}
            }
        });

        /* enable popups only over the actual arrow */
        if(!TP.suppressIconTip) {
            sprite.on('mouseover', function(el, evt, eOpts) {
                TP.suppressIconTip = false;
            });
            sprite.on('mouseout', function(el, evt, eOpts) {
                TP.suppressIconTip = true;
            });
            panel.el.on('mouseover', function(evt, el, eOpts) {
                if(evt.target.tagName != "rect") { return; }
                TP.suppressIconTip = true;
            });
            panel.el.on('mouseout', function(evt, el, eOpts) {
                if(evt.target.tagName != "rect") { return; }
                TP.suppressIconTip = false;
            });
            if(panel.labelEl && panel.labelEl.el) {
                panel.labelEl.el.on('mouseover', function(evt, el, eOpts) {
                    TP.suppressIconTip = false;
                });
                panel.labelEl.el.on('mouseout', function(evt, el, eOpts) {
                    TP.suppressIconTip = true;
                });
            }
        }
    },

    settingsWindowAppearanceTypeChanged: function() {
        var panel = this.panel;
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
            Ext.getCmp('appearanceForm').getForm().setValues(values);
        }
    },

    getAppearanceTabItems: function(panel) {
        return([{
            fieldLabel: 'From',
            xtype:      'fieldcontainer',
            name:       'connectorfrom',
            cls:        'connector',
            layout:     { type: 'hbox', align: 'stretch' },
            defaults:   { listeners: { change: function() { TP.iconSettingsGlobals.renderUpdate(); } } },
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
            defaults:   { listeners: { change: function() { TP.iconSettingsGlobals.renderUpdate(); } } },
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
            defaults:   { listeners: { change: function() { TP.iconSettingsGlobals.renderUpdate(); } } },
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
            defaults:   { listeners: { change: function() { TP.iconSettingsGlobals.renderUpdate(); } } },
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
                listeners: { change:    function()      { TP.iconSettingsGlobals.renderUpdate(undefined, undefined, 0)  },
                             mouseover: function(color) { TP.iconSettingsGlobals.renderUpdate(color,     undefined, 0); },
                             mouseout:  function(color) { TP.iconSettingsGlobals.renderUpdate(undefined, undefined, 0); }
                           }
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
                listeners:   { change: function() { TP.iconSettingsGlobals.renderUpdate(); } }
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
                listeners:   { focus: function() { TP.iconSettingsGlobals.perfDataUpdate() }, change: function() { TP.iconSettingsGlobals.renderUpdate(); } },
                flex:          1
            }]
        }, {
            fieldLabel: 'Options',
            xtype:      'fieldcontainer',
            cls:        'connector',
            layout:     'table',
            defaults: { listeners: { change: function() { TP.iconSettingsGlobals.renderUpdate(undefined, true) } } },
            items: [
                    { xtype: 'label', text: 'Cust. Perf. Data Min', style: 'margin-left: 0px; margin-right: 2px;' },
                    { xtype: 'numberfield', allowDecimals: true, width: 70, name: 'connectormin', step: 100 },
                    { xtype: 'label', text: 'Max', style: 'margin-left: 8px; margin-right: 2px;' },
                    { xtype: 'numberfield', allowDecimals: true, width: 70, name: 'connectormax', step: 100 }
                ]
        }]);
    }
});