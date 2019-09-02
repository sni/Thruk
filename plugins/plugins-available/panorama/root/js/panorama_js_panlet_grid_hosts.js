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
        this.callParent();
        TP.addFormFilter(this, this.has_search_button);
        panel.addGearItems({
            fieldLabel:   'Background',
            xtype:        'fieldcontainer',
            layout:      { type: 'hbox', align: 'stretch' },
            items:        [{
                xtype:        'label',
                text:         'Border: ',
                margins:      {top: 3, right: 2, bottom: 0, left: 0}
            }, {
                xtype:        'checkbox',
                name:         'showborder'
            }, {
                xtype:        'label',
                text:         'Color: ',
                margins:      {top: 3, right: 2, bottom: 0, left: 7}
            }, {
                xtype:        'colorcbo',
                name:         'background',
                value:        '',
                flex:          1
            }]
        });
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
