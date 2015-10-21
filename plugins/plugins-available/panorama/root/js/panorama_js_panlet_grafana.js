Ext.define('TP_Sources', {
    extend: 'Ext.data.Model',
    fields: [
        {name: 'image_url', type: 'string'},
        {name: 'name',      type: 'string'},
        {name: 'source',    type: 'number'},
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
                store.proxy.extraParams['backends'] = TP.getActiveBackendsPanel(Ext.getCmp(store.panel.panel_id), store.panel);
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
    initComponent: function() {
        this.callParent();
        var panel             = this;
        this.xdata.url        = '';
        this.xdata.graph      = '';
        this.xdata.source     = 2;
        this.xdata.time       = '1h';
        this.xdata.showborder = true;
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
                Ext.Ajax.withCredentials     = true;
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
                                for(var k=0; i<row.panels.length; i++) {
                                    var p = row.panels[k];
                                    sources.push({
                                        name:    p.title,
                                        source:  p.id
                                    });
                                }
                            }
                        }
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
            var size     = imgPanel.getSize();
            if(size.width == 0) { return; }
            var url      = this.xdata.graph + '&source='+this.xdata.source;
            var now      = new Date();
            url = url + '&from='  + (Math.round(now.getTime()/1000) - TP.timeframe2seconds(this.xdata.time));
            url = url + '&to='    + Math.round(now.getTime()/1000);
            url = url + '&width=' + size.width;
            url = url + '&height='+ size.height;
            if(this.loader.loadMask == true) { this.imgMask.show(); }
            imgPanel.setSrc(url);
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
            this.refreshHandler();
        });
    },
    setGearItems: function() {
        var panel = this;
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
            store:          { model: 'TP_Sources', data : [ {name: '2', source: 2, image_url: ''} ] }
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
    },
    gearInitCallback: function(panel) {
        TP.grafanaStore.panel = panel;
        TP.grafanaStore.load();
        panel.updateSource(true);
    }
});
