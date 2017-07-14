Ext.define('TP.PanletBP', {
    extend: 'TP.PanletUrl',

    title: 'Business Process',
    height: 300,
    width:  600,
    hideSettingsForm: ['url', 'backends', 'selector', 'keepcss'],

    initComponent: function() {
        var panel = this;
        panel.callParent();
        panel.xdata.url           = '';
        panel.xdata.selector      = '';
        panel.xdata.keepcss       = true;
        panel.xdata.graph         = '';
        panel.reloadOnSiteChanges = false;
        panel.last_url            = '';
        panel.xdata.showborder    = true;

        panel.loader = {};

        /* available graphs loader */
        panel.updateGraphs = function() {
            var url    = 'bp.cgi?view_mode=json&no_drafts=1';
            Ext.Ajax.request({
                url: url,
                method: 'POST',
                callback: function(options, success, response) {
                    var data  = TP.getResponse(panel, response);
                    if(data) {
                        var newdata = {};
                        for(var key in data) {
                            var row = data[key];
                            newdata[row['id']] = {
                                name: row['name'],
                                id:   row['id']
                            };
                        }
                        var graph_combo = TP.getFormField(panel.gearitem.down('form'), 'graph');
                        graph_combo.store.removeAll();
                        for(var key in newdata) {
                            graph_combo.store.loadRawData(newdata[key], true);
                        }
                        graph_combo.setValue(panel.xdata.graph);
                    }
                }
            });
        };

        panel.gearInitCallback = function(This) {
            panel.updateGraphs();
        };

        panel.addListener('resize', function(This, adjWidth, adjHeight, eOpts) {
            panel.manualRefresh();
        });

        panel.refreshHandler = function() {
            if(panel.xdata.graph) {
                var refresh = panel.xdata.refresh;
                if(refresh == -1 || refresh == undefined) {
                    var tab = Ext.getCmp('tabpan');
                    refresh = tab.xdata.refresh;
                }
                var newUrl = 'bp.cgi?action=details&bp='+panel.xdata.graph+'&no_menu=1&readonly=1&iframed=1&minimal=1&nav=0&refresh='+refresh;
                if(!panel.xdata.graph) {
                    newUrl = 'about:blank';
                }
                if(panel.xdata.url != newUrl) {
                    panel.xdata.url = newUrl;
                    /* skip on background tabs, will crash because getState calls getSize which fails unless rendered */
                    if(panel.el && panel.el.dom) {
                        panel.saveState();
                    }
                }
                var iframeObj = panel.items.getAt(0).getEl();
                if(iframeObj && iframeObj.dom && panel.last_url != panel.xdata.url) {
                    iframeObj.dom.src = panel.xdata.url;
                    panel.last_url = panel.xdata.url;
                }
            } else {
                panel.xdata.url = '';
            }
        };
        /* manual refresh update business process */
        panel.manualRefresh = function() {
            panel.last_url = '';
            var newUrl = 'bp.cgi?action=details&bp='+panel.xdata.graph+'&no_menu=1&iframed=1&readonly=1&minimal=1&nav=0&update=1';
            if(!panel.xdata.graph) {
                newUrl = 'about:blank';
            }
            var iframeObj = panel.items.getAt(0).getEl();
            if(iframeObj && iframeObj.dom) {
                if(newUrl != "about:blank") {
                    panel.body.mask('Loading...');
                }
                iframeObj.dom.src = newUrl;
            }
            panel.xdata.url = newUrl;
            panel.saveState();
        };
    },
    setGearItems: function() {
        var panel = this;
        this.callParent();
        this.addGearItems({
            xtype:          'combobox',
            fieldLabel:     'Graph',
            name:           'graph',
            queryMode:      'local',
            valueField:     'id',
            displayField:   'name',
            store:           { fields: ['name', 'id'], data: [] },
            emptyText:      'select business process to display'
        });
        this.addGearItems({
            fieldLabel: 'Show Border',
            xtype:      'checkbox',
            name:       'showborder'
        });
    }
});
