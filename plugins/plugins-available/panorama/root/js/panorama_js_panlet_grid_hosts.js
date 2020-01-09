Ext.define('TP.PanletGridHosts', {
    extend: 'TP.PanletGrid',

    title:  'Hosts',
    width:  800,
    height: 200,
    //maximizable: true, // does not work stateful
    has_search_button: 'host',
    grid_sort:          false,
    hideSettingsForm: ['url'],
    reloadOnSiteChanges: true,
    autohideHeaderOffset: -17,
    cls: 'statusdata',
    initComponent: function() {
        this.callParent();
        this.xdata.url = 'panorama.cgi?task=hosts';
        this.xdata.showborder = true;
    },
    setGearItems: function() {
        var panel = this;
        panel.callParent();
        TP.addFormFilter(panel, panel.has_search_button);
        TP.addGearBackgroundOptions(panel);
    }
});

Ext.define('TP.PanletGridHostTotals', {
    extend: 'TP.PanletGrid',

    title:  'Hosts Totals',
    width:  200,
    height: 200,
    has_search_button: 'host',
    hideSettingsForm: ['url'],
    reloadOnSiteChanges: true,
    initComponent: function() {
        this.callParent();
        this.xdata.url = 'panorama.cgi?task=hosttotals';
    },
    setGearItems: function() {
        var panel = this;
        this.callParent();
        TP.addFormFilter(this, this.has_search_button);
    }
});
