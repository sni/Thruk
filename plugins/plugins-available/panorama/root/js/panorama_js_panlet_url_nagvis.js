Ext.define('TP.PanletNagvis', {
    extend: 'TP.PanletUrl',

    title: 'Nagvis Maps',
    height: 300,
    width:  600,
    hideSettingsForm: ['url', 'backends', 'selector', 'keepcss'],

    initComponent: function() {
        var panel = this;
        panel.callParent();
        panel.xdata.url      = '';
        panel.xdata.selector = '';
        panel.xdata.keepcss  = true;
        panel.xdata.graph    = '';
        panel.xdata.base_url = default_nagvis_base_url;
        panel.reloadOnSiteChanges = false;
        panel.last_url       = '';
        panel.graphs_loaded  = 0;

        panel.loader = {};

        panel.updateGraphsCallback = function(options, success, response) {
            var graph_combo_error_label = TP.getFormField(panel.gearitem.down('form'), 'grapherror');
            if(success) {
                var data  = TP.getResponse(panel, response, true);
                var matches = response.responseText.match(/<a href="[^"]*?mod=Map&act=view&show=[^"]*?".*?>([^<]+)<\/a>/g);
                if(matches && matches.length > 0) {
                    panel.graphs_loaded = 1;
                    var newdata = {};
                    for(var nr=0; nr<matches.length; nr++) {
                        var m = matches[nr];
                        var name = m.match(/>([^<]*)<\/a>/);
                        var link = m.match(/show=([^"]*)"/);
                        newdata[link[1]] = {
                            name: name[1],
                            id:   link[1]
                        };
                    }
                    var graph_combo = TP.getFormField(panel.gearitem.down('form'), 'graph');
                    graph_combo.store.removeAll();
                    for(var key in newdata) {
                        graph_combo.store.loadRawData(newdata[key], true);
                    }
                    graph_combo.setValue(panel.xdata.graph);
                    graph_combo_error_label.unsetActiveError();
                    graph_combo_error_label.setValue('');
                    graph_combo.enable();
                } else {
                    graph_combo_error_label.setActiveError('');
                    graph_combo_error_label.setValue('loading graphs failed, no maps found. Is this a nagvis url?');
                    panel.graphs_loaded = 0;
                }
            }
            if(!success) {
                panel.graphs_loaded = 0;
                graph_combo_error_label.setActiveError('');
                if(response.status == 404) {
                    graph_combo_error_label.setValue('loading graphs failed, no nagvis found under this url: ' + response.status + ' - ' + response.statusText);
                } else if(response.status) {
                    graph_combo_error_label.setValue('loading graphs failed: ' + response.status + ' - ' + response.statusText);
                } else {
                    graph_combo_error_label.setValue('loading graphs failed, possible errors are wrong url or authentication problems.');
                }
            }
        }

        /* available graphs loader */
        panel.updateGraphs = function() {
            var form   = panel.gearitem.down('form').getForm();
            var values = form.getValues();
            panel.xdata.base_url = values.base_url;
            if(!panel.xdata.base_url) { return; }
            if(panel.graphs_loaded)   { return; }
            var graph_combo             = TP.getFormField(panel.gearitem.down('form'), 'graph');
            graph_combo.setRawValue('loading maps...');
            graph_combo.disable();
            var graph_combo_error_label = TP.getFormField(panel.gearitem.down('form'), 'grapherror');
            graph_combo_error_label.unsetActiveError();
            var now    = new Date();
            var url    = panel.xdata.base_url+'/server/core/ajax_handler.php?mod=Multisite&act=getMaps&_ajaxid='+Math.floor(now.getTime()/1000);
            Ext.Ajax.cors                = true;
            Ext.Ajax.withCredentials     = true;
            Ext.Ajax.useDefaultXhrHeader = false;
            try {
                Ext.Ajax.request({
                    url: url,
                    method: 'GET',
                    callback: panel.updateGraphsCallback
                });
            } catch(e) {
                graph_combo_error_label.setActiveError('');
                graph_combo_error_label.setValue('loading graphs failed: ' + e);
            }
        };

        panel.gearInitCallback = function(This) {
            panel.graphs_loaded = 0;
            panel.updateGraphs();
        };

        panel.refreshHandler = function() {
            if(panel.xdata.graph && panel.xdata.base_url) {
                var newUrl = panel.xdata.base_url+'/index.php?mod=Map&act=view&show='+panel.xdata.graph+'&header_menu=0&hover_menu=0&context_menu=0';
                if(panel.xdata.url != newUrl) {
                    panel.xdata.url = newUrl;
                    panel.saveState();
                }
                var iframeObj = panel.items.getAt(0).getEl();
                if(iframeObj && iframeObj.dom && panel.last_url != panel.xdata.url) {
                    iframeObj.dom.src = panel.xdata.url;
                    panel.last_url = panel.xdata.url;
                }
            } else {
                panel.xdata.url = '';
                panel.body.unmask();
            }
        };
        /* manual refresh update nagvis map */
        panel.manualRefresh = function() {
            panel.body.mask('Loading...');
            panel.last_url = '';
            panel.refreshHandler();
        };
    },
    setGearItems: function() {
        var panel = this;
        panel.callParent();
        panel.addGearItems({
            fieldLabel: 'Nagvis Base Url',
            xtype:      'textfield',
            name:       'base_url',
            emptyText:  'nagvis base url, ex.: /nagvis',
            listeners: {
                change: function() {
                    panel.updateGraphs();
                }
            }
        });
        panel.addGearItems({
            xtype:          'combobox',
            fieldLabel:     'Graph',
            name:           'graph',
            queryMode:      'local',
            valueField:     'id',
            displayField:   'name',
            store:           { fields: ['name', 'id'], data: [] },
            emptyText:      'select a map',
            listeners: {
                focus: function() {
                    panel.updateGraphs();
                },
                expand: function() {
                    panel.updateGraphs();
                }
            }
        });
        panel.addGearItems({
            xtype:         'displayfield',
            hideEmptyLabel: false,
            name:          'grapherror',
            activeError:    true,
            value:         ' '
        });
    }
});
