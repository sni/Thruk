Ext.define('TP.PanletGridServer', {
    extend: 'TP.PanletGrid',

    title:  'Site Status',
    height: 200,
    width:  260,
    filterBackends: false,
    hideSettingsForm: ['url', 'backends'],
    initComponent: function() {
        this.callParent();
        this.xdata.url = 'panorama.cgi?task=site_status';
        this.reloadOnSiteChanges = true;
    }
});

/* toggle backends */
TP.toggleBackend = function(icon, panel_id, backend) {
    var panel = Ext.getCmp(panel_id);
    var tab = Ext.getCmp(panel.panel_id);
    if(tab.activeBackends == undefined || tab.activeBackends[backend] == undefined) {
        if(tab.activeBackends == undefined) { tab.activeBackends = {} }
        tab.activeBackends[backend] = false;
        icon.style.backgroundImage  = 'url(../plugins/panorama/images/sport_golf.png)';
    } else {
        icon.style.backgroundImage = 'url(../plugins/panorama/images/accept.png)';
        delete tab.activeBackends[backend];
    }

    // check if backends left, otherwise unset activeBackends list
    var count = 0;
    var available = TP.getAvailableBackendsTab(tab);
    for(var x = 0; x<available.length; x++) {
        var key = available[x][0];
        if(tab.activeBackends[key] != undefined) {
            count++;
        }
    }
    if(count == 0) {
        tab.activeBackends = undefined;
    }

    window.clearTimeout(TP.timeouts['timeout_'+tab.id+'_refresh_all_site_panel']);
    TP.timeouts['timeout_'+tab.id+'_refresh_all_site_panel'] = window.setTimeout(function() {
        TP.refreshAllSitePanel(tab);
    }, 500);
}


Ext.define('TP.PanletGridServerStats', {
    extend: 'TP.PanletGrid',

    title:  'Server Status',
    height: 420,
    width:  200,
    hideSettingsForm: ['url', 'backends'],
    initComponent: function() {
        this.callParent();
        this.xdata.url    = 'panorama.cgi?task=server_stats';
        this.xdata.cpu    = true;
        this.xdata.load   = true;
        this.xdata.memory = true;
    },
    setGearItems: function() {
        var panel = this;
        this.callParent();
        this.addGearItems([{
            fieldLabel: 'CPU',
            xtype:      'checkbox',
            name:       'cpu'
        }, {
            fieldLabel: 'Load',
            xtype:      'checkbox',
            name:       'load'
        }, {
            fieldLabel: 'Memory',
            xtype:      'checkbox',
            name:       'memory'
        }]);
    }
});
