Ext.define('TP.PanletGridHosts', {
    extend: 'TP.PanletGrid',

    title:  'Hosts',
    height: 200,
    width:  800,
    //maximizable: true, // does not work stateful
    has_search_button: 'host',
    grid_sort:          false,
    hideSettingsForm: ['url'],
    reloadOnSiteChanges: true,
    initComponent: function() {
        this.callParent();
        this.xdata.url = 'panorama.cgi?task=hosts';
        TP.addFormFilter(this, this.has_search_button);
    },
    setGearItems: function() {
        var panel = this;
        this.callParent();
        TP.addFormFilter(this, this.has_search_button);
    }
});

Ext.define('TP.PanletGridHostTotals', {
    extend: 'TP.PanletGrid',

    title:  'Hosts Totals',
    height: 200,
    width:  200,
    has_search_button: 'host',
    hideSettingsForm: ['url'],
    reloadOnSiteChanges: true,
    initComponent: function() {
        this.callParent();
        this.xdata.url = 'panorama.cgi?task=hosttotals';
        TP.addFormFilter(this, this.has_search_button);
    },
    setGearItems: function() {
        var panel = this;
        this.callParent();
        TP.addFormFilter(this, this.has_search_button);
    }
});
