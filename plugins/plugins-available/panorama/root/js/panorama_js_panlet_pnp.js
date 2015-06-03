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
        {name: 'text', type: 'string'},
        {name: 'url',  type: 'string'}
    ]
});

TP.graphStore = Ext.create('Ext.data.Store', {
    pageSize:     10,
    model:       'TP_GraphModell',
    remoteSort:   true,
    remoteFilter: true,
    proxy: {
        type:   'ajax',
        url:    'panorama.cgi?task=pnp_graphs',
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

Ext.define('TP.PanletPNP', {
    extend: 'TP.Panlet',

    title: 'PNPGraph',
    height: 240,
    width:  420,
    hideSettingsForm: ['backends'],
    initComponent: function() {
        this.callParent();
        var panel             = this;
        this.xdata.url        = '';
        this.xdata.graph      = '';
        this.xdata.source     = 0;
        this.xdata.time       = '1h';
        this.xdata.showborder = true;
        this.lastGraph        = '';
        this.adjusting        = 0;

        this.size_adjustment_x = 97;
        this.size_adjustment_y = 50;

        /* update source selector */
        this.updateSource = function(force) {
            var form   = this.down('form').getForm();
            var values = form.getValues();
            if(!values.graph) { return; }
            if(force || (values.graph != this.lastGraph && values.graph.indexOf('host=') != -1)) {
                this.lastGraph = values.graph;
                var url = values.graph.replace(/\/image\?/, '/json?');
                Ext.Ajax.cors                = true;
                Ext.Ajax.withCredentials     = true;
                Ext.Ajax.useDefaultXhrHeader = false;
                Ext.Ajax.request({
                    url:     url,
                    method: 'POST',
                    callback: function(options, success, response) {
                        var data = [];
                        var tmp  = TP.getResponse(panel, response);
                        if(tmp) {
                            for(var nr=0; nr<tmp.length; nr++) {
                                var row = tmp[nr];
                                var match = row.image_url.match(/\&source=(\d+)\&/);
                                data[match[1]] = {
                                    name:    tmp[nr].ds_name,
                                    source:  match[1]
                                };
                            }
                        }
                        var source_combo = TP.getFormField(panel.gearitem.down('form'), 'source');
                        source_combo.store.removeAll();
                        for(var nr=0; nr<data.length; nr++) {
                            source_combo.store.loadRawData(data[nr], true);
                        }
                        source_combo.setValue(panel.xdata.source);
                    }
                });
            }
        };
        this.loader = {};

        /* update graph source */
        this.refreshHandler = function() {
            if(this.xdata.graph == '') {
                return;
            }
            var imgPanel = this.items.getAt(0);
            if(!imgPanel || !imgPanel.el) { // not yet initialized
                return;
            }
            var size     = imgPanel.getSize();
            var url      = this.xdata.graph + '&view=1&source='+this.xdata.source;
            var now      = new Date();
            url = url + '&start=' + (Math.round(now.getTime()/1000) - TP.timeframe2seconds(this.xdata.time));
            url = url + '&end='   + Math.round(now.getTime()/1000);
            if(size.height > 1 && (size.height - this.size_adjustment_y) < 81) {
                url = url + '&graph_width=' + size.width;
                url = url + '&graph_height='+ size.height;
            } else {
                url = url + '&graph_width=' +(size.width  - this.size_adjustment_x);
                url = url + '&graph_height='+(size.height - this.size_adjustment_y);
            }
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
                            panel.adjustImgSize();
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
            var size = This.getSize();
            // not on initial resizing
            if(size.width != adjWidth || size.height != adjHeight) {
                this.size_adjustment_x += adjWidth;
                this.size_adjustment_y += adjHeight;
            }
            this.refreshHandler();
        });

        /* adjust size of image */
        this.adjustImgSize = function() {
            var imgPanel = this.items.getAt(0);
            if(!imgPanel || !imgPanel.el) { // not yet initialized
                return;
            }
            var size = imgPanel.getSize();
            var naturalWidth  = imgPanel.getEl().dom.naturalWidth;
            var naturalHeight = imgPanel.getEl().dom.naturalHeight;
            if(naturalWidth && naturalWidth > 81 && size.height - this.size_adjustment_y > 81) {
                var oldX = this.size_adjustment_x;
                var oldY = this.size_adjustment_y;
                this.size_adjustment_x += (naturalWidth  - size.width);
                this.size_adjustment_y += (naturalHeight - size.height);
                if(oldX != this.size_adjustment_x || oldY != this.size_adjustment_y) {
                    panel.adjusting++;
                    if(panel.adjusting < 5) {
                        window.setTimeout(function() {
                            panel.refreshHandler();
                        }, 100);
                    }
                } else {
                    panel.adjusting = 0;
                }
            }
        }
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
            store:           TP.graphStore,
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
            store:          { model: 'TP_Sources', data : [ {name: '0', source: 0, image_url: ''} ] }
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
        TP.graphStore.panel = panel;
        TP.graphStore.load();
        panel.updateSource(true);
    }
});
