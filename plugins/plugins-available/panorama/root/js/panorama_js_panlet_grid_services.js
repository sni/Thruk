Ext.define('TP.PanletGridServices', {
    extend: 'TP.PanletGrid',

    title:  'Services',
    width:  900,
    height: 200,
    //maximizable: true, // does not work stateful
    has_search_button: 'service',
    grid_sort:          false,
    hideSettingsForm: ['url'],
    reloadOnSiteChanges: true,
    autohideHeaderOffset: -17,
    initComponent: function() {
        this.callParent();
        this.xdata.url = 'panorama.cgi?task=services';
        this.xdata.showborder = true;
    },
    setGearItems: function() {
        var panel = this;
        this.callParent();
        TP.addFormFilter(this, this.has_search_button);
        this.addGearItems({
            fieldLabel: 'Show Border',
            xtype:      'checkbox',
            name:       'showborder'
        });
    }
});

Ext.define('TP.PanletGridServiceTotals', {
    extend: 'TP.PanletGrid',

    title:  'Service Totals',
    width:  200,
    height: 200,
    has_search_button: 'service',
    hideSettingsForm: ['url'],
    reloadOnSiteChanges: true,
    initComponent: function() {
        this.callParent();
        this.xdata.url = 'panorama.cgi?task=servicetotals';
    },
    setGearItems: function() {
        var panel = this;
        this.callParent();
        TP.addFormFilter(this, this.has_search_button);
    }
});

Ext.define('TP.PanletGridServiceMineMap', {
    extend: 'TP.PanletGrid',

    title:  'Mine Map',
    width:  600,
    height: 300,
    has_search_button: 'service',
    grid_sort:    false,
    grid_columns: false,
    hideSettingsForm: ['url'],
    reloadOnSiteChanges: true,
    initComponent: function() {
        this.callParent();
        this.xdata.showborder = true;
        delete this.initialState;
        var state = TP.cp.get(this.id);
        if(state && state.xdata && state.xdata.gridstate) {
            delete state.xdata.gridstate;
        }
        this.xdata.url = 'panorama.cgi?task=servicesminemap';
    },
    setGearItems: function() {
        var panel = this;
        this.callParent();
        TP.addFormFilter(this, this.has_search_button);
        this.addGearItems({
            fieldLabel: 'Show Border',
            xtype:      'checkbox',
            name:       'showborder'
        });
    }
});
