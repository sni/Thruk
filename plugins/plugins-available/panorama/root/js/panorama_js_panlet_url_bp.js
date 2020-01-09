Ext.define('TP.PanletBP', {
    extend: 'TP.PanletUrl',

    title: '',
    height: 300,
    width:  600,
    hideSettingsForm: ['url', 'backends', 'selector', 'keepcss'],

    initComponent: function() {
        var panel = this;
        panel.extra_tools = [{
            type: 'prev',
            tooltip: 'switch to home business process',
            handler: function() { panel.current_bp = undefined; panel.manualRefresh(); },
            hidden: true
        }];
        panel.callParent();
        panel.xdata.url           = '';
        panel.xdata.selector      = '';
        panel.xdata.keepcss       = true;
        panel.xdata.graph         = '';
        panel.reloadOnSiteChanges = false;
        panel.last_url            = '';
        panel.xdata.showborder    = true;
        panel.current_bp          = null;

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
            // title is set automatically
            Ext.getCmp("title_textfield").hide();
            panel.current_bp = undefined;
        };

        panel.addListener('resize', function(This, adjWidth, adjHeight, eOpts) {
            panel.manualRefresh();
        });

        panel.refreshHandler = function() {
            if(panel.gearitem) { return; }
            if(panel.xdata.graph) {
                var bp_id  = panel.current_bp ? panel.current_bp : panel.xdata.graph;
                var newUrl = 'bp.cgi?action=details&bp='+bp_id+'&no_menu=1&iframed=1&readonly=1&minimal=1&nav=0&_='+Ext.Date.now();
                if(panel.xdata.background != undefined && panel.xdata.background != "") {
                    newUrl = newUrl + '&htmlCls=transparent';
                }
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
                var iframeObj = panel.iframe.getEl();
                if(iframeObj && iframeObj.dom && panel.last_url != panel.xdata.url) {
                    iframeObj.dom.src = panel.xdata.url;
                    iframeObj.dom.loadingCallback = function(args) {
                        if(args["link"] && !args["link"].match(/\#/)) {
                            panel.mask("Loading...");
                            // manual click, reset refresh timer
                            panel.startTimeouts();
                        }
                    }
                    iframeObj.dom.loadedCallback = function(args) {
                        if(args["bp_name"]) {
                            panel.setTitle(args["bp_name"]);
                        }
                        if(args["bp_id"]) {
                            panel.current_bp = args["bp_id"];
                        }
                        if(panel.current_bp != panel.xdata.graph) {
                            panel.tools[0].show();
                        } else {
                            panel.tools[0].hide();
                        }
                    }
                    panel.last_url = panel.xdata.url;
                }
            } else {
                panel.xdata.url = '';
            }
        };
        /* manual refresh update business process */
        panel.manualRefresh = function() {
            if(panel.gearitem) { return; }
            panel.last_url = '';
            var bp_id  = panel.current_bp ? panel.current_bp : panel.xdata.graph;
            var newUrl = 'bp.cgi?action=details&bp='+bp_id+'&no_menu=1&iframed=1&readonly=1&minimal=1&nav=0&update=1';
            if(panel.xdata.background != undefined && panel.xdata.background != "") {
                newUrl = newUrl + '&htmlCls=transparent';
            }
            if(!panel.xdata.graph) {
                newUrl = 'about:blank';
            }
            var iframeObj = panel.iframe.getEl();
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
            xtype:          'colorcbo',
            fieldLabel:     'Background',
            name:           'background',
            mouseover:     function(color) { panel.applyBorderAndBackground(color); },
            mouseout:      function(color) { panel.applyBorderAndBackground(); }
        });
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
    }
});
