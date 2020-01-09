Ext.define('TP_Sources', {
    extend: 'Ext.data.Model',
    fields: [
        {name: 'image_url', type: 'string'},
        {name: 'name',      type: 'string'},
        {name: 'source',    type: 'number'}
    ]
});

Ext.define('TP_GraphModell', {
    extend: 'Ext.data.Model',
    fields: [
        {name: 'text',       type: 'string'},
        {name: 'url',        type: 'string'},
        {name: 'source_url', type: 'string'}
    ]
});

TP.grafanaStore = Ext.create('Ext.data.Store', {
    pageSize:     10,
    model:       'TP_GraphModell',
    remoteSort:   true,
    remoteFilter: true,
    proxy: {
        type:   'ajax',
        url:    'panorama.cgi?task=grafana_graphs',
        method: 'POST',
        params: {},
        reader: {
            type: 'json',
            root: 'data'
        }
    },
    listeners: {
        beforeload: function(store, operation, eOpts) {
            if(store.panel) {
                store.proxy.extraParams['backends'] = TP.getActiveBackendsPanel(store.panel.tab, store.panel);
                store.proxy.extraParams['query2']   = store.panel.xdata.graph;
            } else {
                store.proxy.extraParams = {};
            }
            return true;
        }
    }
});

Ext.define('TP.PanletGrafana', {
    extend: 'TP.Panlet',

    title: 'GrafanaGraph',
    height: 240,
    width:  420,
    hideSettingsForm: ['backends'],
    bodyStyle: "background: transparent;",
    style:    { position: 'absolute', zIndex: 50, background: 'transparent' },
    initComponent: function() {
        this.callParent();
        var panel             = this;
        this.xdata.url        = '';
        this.xdata.graph      = '';
        this.xdata.source     = grafana_default_panelId;
        this.xdata.time       = '1h';
        this.xdata.showborder = true;
        this.xdata.showtitle  = true;
        this.xdata.showlegend = true;
        this.lastGraph        = '';

        /* update source selector */
        this.updateSource = function(force) {
            var form   = this.down('form').getForm();
            var values = form.getValues();
            if(!values.graph) { return; }
            if(force || (values.graph != this.lastGraph && values.graph.indexOf('host=') != -1)) {
                this.lastGraph = values.graph;
                // get source url for graph
                var url = values.graph;
                var matched = false;
                for(var i=0; i<TP.grafanaStore.data.items.length; i++) {
                    if(TP.grafanaStore.data.items[i].raw.url == url) {
                        url = TP.grafanaStore.data.items[i].raw.source_url;
                        matched = true;
                        break;
                    }
                }
                if(!matched) { return; }

                url = url.replace(/\/grafana\/dashboard\/script\/histou\.js\?/, '/histou/index.php?');
                Ext.Ajax.cors                = true;
                Ext.Ajax.useDefaultXhrHeader = false;
                Ext.Ajax.request({
                    url:     url,
                    method: 'POST',
                    callback: function(options, success, response) {
                        if(!success) { return; }
                        var data = response.responseText;
                        try {
                            data = data.replace(/^[\s\S]*<br>\{/, '{');
                            data = data.replace(/<br><\/pre>$/, '');
                            data = data.replace(/\n/g, '');
                            eval('data = '+data+";");
                        }
                        catch(e) { debug(e); }
                        var sources = [];
                        if(data && data.rows) {
                            for(var i=0; i<data.rows.length; i++) {
                                var row = data.rows[i];
                                for(var k=0; k<row.panels.length; k++) {
                                    var p = row.panels[k];
                                    sources.push({
                                        name:    p.title,
                                        source:  p.id
                                    });
                                }
                            }
                        }
                        if(!panel.gearitem || !panel.gearitem.down('form')) { return; }
                        var source_combo = TP.getFormField(panel.gearitem.down('form'), 'source');
                        source_combo.store.removeAll();
                        for(var nr=0; nr<sources.length; nr++) {
                            source_combo.store.loadRawData(sources[nr], true);
                        }
                        source_combo.setValue(panel.xdata.source);
                    }
                });
            }
        };
        this.loader = {};

        /* update graph source */
        this.refreshHandler = function() {
            if(this.xdata.graph == '') { return; }
            var imgPanel = this.items.getAt(0);
            if(!imgPanel || !imgPanel.el) { // not yet initialized
                return;
            }
            var size = imgPanel.getSize();
            if(size.width <= 1) { return; }
            var url      = this.xdata.graph + '&source='+this.xdata.source;
            var serverTime = Math.round(TP.serverTime());
            url = url + '&from='  + (serverTime - TP.timeframe2seconds(this.xdata.time));
            url = url + '&to='    + serverTime;
            if(this.heightFixed == undefined) {
                this.heightFixed = size.height;
            }
            this.heightOverflow = 0;
            if(this.xdata.showtitle != undefined && !this.xdata.showtitle) {
                url = url + '&disablePanelTitle=1';
                this.heightOverflow += 20;
            }
            if(this.xdata.showlegend != undefined && !this.xdata.showlegend) {
                url = url + '&legend=0';
                this.heightOverflow += 10;
            }
            if(this.xdata.background != undefined) {
                url = url + '&theme='+this.xdata.background;
            }
            if(this.xdata.font_color != undefined) {
                url = url + '&font_color='+encodeURIComponent(this.xdata.font_color);
            }
            if(this.xdata.background_color != undefined) {
                url = url + '&background_color='+encodeURIComponent(this.xdata.background_color);
            }
            var global = this.tab;
            if(!global.xdata.autohideheader || this.xdata.showborder) {
                this.heightOverflow = this.heightOverflow / 5;
            }
            url = url + '&width=' + size.width;
            url = url + '&height='+ (this.heightFixed+this.heightOverflow);
            if(this.loader.loadMask == true) { this.imgMask.show(); }
            imgPanel.setSrc(url);
            this.adjustBodyStyle();
        };

        /* panel content should be in an image */
        this.imgItem = new Ext.Img({
            src:   Ext.BLANK_IMAGE_URL,
            listeners: {
                afterrender: function (me) {
                    me.el.on({
                        load: function (evt, ele, opts) {
                            var panel = me.up('panel');
                            var refresh = panel.getTool('refresh') || panel.getTool('broken');
                            refresh.setType('refresh');
                            panel.imgMask.hide();
                            panel.adjustBodyStyle();
                        },
                        error: function (evt, ele, opts) {
                            var panel = me.up('panel');
                            var refresh = panel.getTool('refresh') || panel.getTool('broken');
                            refresh.setType('broken');
                            panel.imgMask.hide();
                        }
                    });
                }
            }
        });
        this.add(this.imgItem);
        this.imgMask = new Ext.LoadMask(this.imgItem, {msg:"Loading..."});

        /* auto load when url is set */
        this.addListener('afterrender', function() {
            if(this.xdata.graph == '') {
                this.gearHandler();
            } else {
                this.refreshHandler();
            }
        });
        this.addListener('resize', function(This, adjWidth, adjHeight, eOpts) {
            var imgPanel = this.items.getAt(0);
            if(!imgPanel || !imgPanel.el) { // not yet initialized
                return;
            }
            var size = imgPanel.getSize();
            if(size.width <= 1) { return; }
            this.heightFixed = size.height;
            this.refreshHandler();
            this.adjustBodyStyle();
        });
        this.gearHandler = this.grafanaGearHandler;
    },
    adjustBodyStyle: function() {
        var panel = this;
        panel.setBodyStyle("background: transparent;");
        if(panel.heightFixed != undefined && panel.heightOverflow) {
            var imgPanel = panel.items.getAt(0);
            imgPanel.el.dom.style.height=(panel.heightFixed+panel.heightOverflow)+"px";
        }
    },
    setGearItems: function() {
        var panel = this;
        if(panel.xdata.showtitle  == undefined) { panel.xdata.showtitle  = true; }
        if(panel.xdata.showlegend == undefined) { panel.xdata.showlegend = true; }
        this.callParent();
        this.addGearItems({
            xtype:          'combobox',
            fieldLabel:     'Graph',
            name:           'graph',
            queryMode:      'remote',
            valueField:     'url',
            displayField:   'text',
            typeAhead:       true,
            minChars:        3,
            pageSize:        10,
            store:           TP.grafanaStore,
            listeners: {
                select: function( combo, records, eOpts ) {
                    panel.xdata.source = 0;
                    panel.updateSource();
                },
                change: function( combo, newValue, oldValue, eOpts ) {
                    panel.updateSource();
                }
            }
        });

        this.addGearItems({
            xtype:          'combobox',
            fieldLabel:     'Source',
            name:           'source',
            queryMode:      'local',
            displayField:   'name',
            valueField:     'source',
            forceSelection: true,
            editable:       false,
            store:          { model: 'TP_Sources', data : [ {name: grafana_default_panelId, source: grafana_default_panelId, image_url: ''} ] }
        });

        this.addGearItems({
            fieldLabel:     'Time Frame',
            xtype:          'textfield',
            name:           'time'
        });
        this.addGearItems({
            fieldLabel: 'Show Border',
            xtype:      'checkbox',
            name:       'showborder'
        });
        this.addGearItems({
            fieldLabel: 'Show Title',
            xtype:      'checkbox',
            name:       'showtitle'
        });
        this.addGearItems({
            fieldLabel: 'Show Legend',
            xtype:      'checkbox',
            name:       'showlegend'
        });
        this.addGearItems({
            xtype:          'combobox',
            fieldLabel:     'Background',
            name:           'background',
            store:        [['light','light theme'],['dark','dark theme']]
        });
        this.addGearItems({
            xtype:          'colorcbo',
            fieldLabel:     'Background Color',
            name:           'background_color'
        });
        this.addGearItems({
            xtype:          'colorcbo',
            fieldLabel:     'Font Color',
            name:           'font_color'
        });
    },
    gearInitCallback: function(panel) {
        TP.grafanaStore.panel = panel;
        TP.grafanaStore.load({
            callback: function() {
                panel.updateSource(true);
            }
        });
    },
    grafanaGearHandler: function() {
        var panel = this;
        TP.panletGearHandler(panel);
        if(panel.gearitem == undefined) {
            panel.refreshHandler();
        }
    }
});
