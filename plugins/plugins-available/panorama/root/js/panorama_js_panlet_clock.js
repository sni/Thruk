Ext.define('Timezones', {
    extend: 'Ext.data.Model',
    fields: [
        {name: 'abbr',   type: 'string' },
        {name: 'offset', type: 'int'    },
        {name: 'isdst',  type: 'boolean'},
        {name: 'text',   type: 'string' }
    ]
});

TP.timezoneStore = Ext.create('Ext.data.Store', {
    model: 'Timezones',
    autoLoad: false,
    proxy: {
        type: 'ajax',
        url : 'panorama.cgi?task=timezones',
        reader: {
            type: 'json',
            root: 'data'
        }
    }
});

Ext.define('TP.PanletClock', {
    extend: 'TP.Panlet',

    title: 'Clock',
    height: 120,
    width:  300,
    hideSettingsForm: ['backends'],
    bodyStyle: "background: transparent;",
    style:    { position: 'absolute', zIndex: 50, background: 'transparent' },
    initComponent: function() {
        this.callParent();
        var panel             = this;
        this.xdata.timeformat = '%H:%M';
        this.xdata.timezone   = 'Local Browser';
        this.xdata.showborder = false;
        this.xdata.refresh    = 1;
        this.loader           = {};
        this.refreshHandler = function() {
            var panel = this;
            var d     = new Date();
            var el    = Ext.get(this.id+'-clock');
            if(!el || !el.dom) {
                /* not rendered yet */
                return;
            }
            var newText;
            if(panel.xdata.timezone == "Local Browser") {
                newText = d.strftime(panel.xdata.timeformat);
            } else {
                /* update offset */
                var hour = d.strftime("%H");
                if(panel.lastHour != hour || panel.lastTZ != panel.xdata.timezone) {
                    if(TP.timezoneStore.loading) {
                        /* try again later */
                        window.setTimeout(function() { panel.refreshHandler(); }, 100 );
                        return;
                    }
                    var found = false;
                    TP.timezoneStore.queryBy(function(record, id) {
                        if(record.data.text == panel.xdata.timezone) {
                            found = true;
                            panel.tzOffset = record.data.offset;
                            return false;
                        }
                    });
                    if(!found) {
                        if(TP.timezoneStore.data.length == 0 || TP.timezoneStore.isFiltered()) {
                            TP.timezoneStore.load();
                            /* try again later */
                            window.setTimeout(function() { panel.refreshHandler(); }, 500 );
                            return;
                        }
                        /* totally unknown tz selected */
                        panel.clockItem.update("ERROR: unknown timezone");
                        return;
                    }
                    panel.lastHour = hour;
                    panel.lastTZ   = panel.xdata.timezone;
                }
                var localTime   = d.getTime();
                var localOffset = d.getTimezoneOffset() * 60000;
                var utc         = localTime + localOffset;
                var timestamp   = utc + (1000*panel.tzOffset);
                newText = strftime(panel.xdata.timeformat, timestamp/1000);
            }
            var oldSize = el.getSize();
            el.update(newText);
            var newSize = el.getSize();
            if(oldSize.width != newSize.width || oldSize.height != newSize.height) {
                panel.adjustBodyStyle();
            }
        };

        this.clockItem = this.add({
            xtype:     'panel',
            border:     0,
            html:      '<span id="'+this.id+'-clock" style="white-space: nowrap;"></span>',
            listeners: { resize: function(This, adjWidth, adjHeight, eOpts) { panel.adjustBodyStyle(); } }
        });

        /* set inital value */
        this.addListener('afterrender', function() {
            this.refreshHandler();
        });
    },
    adjustBodyStyle: function() {
        var panel = this;
        panel.clockItem.setBodyStyle("font-family: "+(panel.xdata.fontfamily ? panel.xdata.fontfamily : 'inherit')+";");
        panel.clockItem.setBodyStyle("font-weight: "+(panel.xdata.fontbold ? 'bold' : 'normal')+";");
        panel.clockItem.setBodyStyle("font-style: "+(panel.xdata.fontitalic ? 'italic' : 'normal')+";");
        panel.clockItem.setBodyStyle("color: "+(panel.xdata.fontcolor ? panel.xdata.fontcolor : 'inherit')+";");
        panel.clockItem.setBodyStyle("background: "+(panel.xdata.background ? panel.xdata.background : 'transparent')+";");

        var size   = panel.getSize();
        panel.clockItem.setBodyStyle("font-size: "+(Math.ceil(size.height))+"px;");
        var el     = Ext.get(this.id+'-clock');
        var sizeEl = el.getSize();
        var percX  = (size.width-20) / sizeEl.width;
        var percY  = (size.height)   / sizeEl.height;
        var perc   = Math.min(percX, percY);
        panel.clockItem.setBodyStyle("font-size: "+Math.ceil(Math.ceil(size.height)*perc)+"px;");
        panel.clockItem.setBodyStyle("line-height: "+Math.ceil(Math.ceil(size.height)*perc)+"px;");
    },
    setGearItems: function() {
        var panel = this;
        this.callParent();
        this.addGearItems({
            fieldLabel:     'Time Format',
            xtype:          'textfield',
            name:           'timeformat'
        });
        this.addGearItems({
            fieldLabel:     'Time Zone',
            xtype:          'combobox',
            name:           'timezone',
            displayField:   'text',
            valueField:     'text',
            store:           TP.timezoneStore,
            typeAhead:       true,
            minChars:        1
        });
        TP.addGearBackgroundOptions(panel);
        this.addGearItems({
            xtype:        'fieldcontainer',
            fieldLabel:   'Font',
            layout:      { type: 'hbox', align: 'stretch' },
            items:        [{
                name:         'fontfamily',
                xtype:        'fontcbo',
                value:        'inherit',
                flex:          1,
                editable:      false,
                allowEmpty:    true
            }, {
                xtype:        'colorcbo',
                name:         'fontcolor',
                value:        '#000000'
            }, {
                xtype:        'hiddenfield',
                name:         'fontitalic',
                value:         panel.xdata.fontitalic
            }, {
                xtype:        'button',
                enableToggle:  true,
                name:         'fontitalic',
                icon:         url_prefix+'plugins/panorama/images/text_italic.png',
                margins:      {top: 0, right: 0, bottom: 0, left: 3},
                toggleHandler: function(btn, state) { this.up('form').getForm().setValues({fontitalic: state ? '1' : '' }); },
                listeners: {
                    afterrender: function() { if(panel.xdata.fontitalic) { this.toggle(); } }
                }
            }, {
                xtype:        'hiddenfield',
                name:         'fontbold',
                value:         panel.xdata.fontbold
            }, {
                xtype:        'button',
                enableToggle:  true,
                name:         'fontbold',
                icon:         url_prefix+'plugins/panorama/images/text_bold.png',
                margins:      {top: 0, right: 0, bottom: 0, left: 3},
                toggleHandler: function(btn, state) { this.up('form').getForm().setValues({fontbold: state ? '1' : ''}); },
                listeners: {
                    afterrender: function() { if(panel.xdata.fontbold) { this.toggle(); } }
                }
            }]
        });
    }
});
