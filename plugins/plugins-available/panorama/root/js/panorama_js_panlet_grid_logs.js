Ext.define('TP.PanletGridLogs', {
    extend: 'TP.PanletGrid',

    title:  'Logfiles',
    height: 200,
    width:  800,
    //maximizable: true, // does not work stateful
    hideSettingsForm: ['url'],
    initComponent: function() {
        this.callParent();
        this.xdata.url      = 'panorama.cgi?task=show_logs';
        this.xdata.pattern  = '';
        this.xdata.exclude  = '';
        this.xdata.time     = '15m';
        this.reloadOnSiteChanges = true;

        this.formUpdatedCallback = function() {
            this.loader.baseParams = {
                time:    this.xdata.time,
                exclude: this.xdata.exclude,
                pattern: this.xdata.pattern
            };
        };
    },
    setGearItems: function() {
        var panel = this;
        panel.callParent();
        panel.addGearItems({
            fieldLabel: 'Time',
            xtype:      'textfield',
            name:       'time'
        });
        panel.addGearItems({
            fieldLabel: 'Include Pattern',
            xtype:      'textfield',
            name:       'pattern',
            emptyText:  'regular search expression'
        });
        panel.addGearItems({
            fieldLabel: 'Exclude Pattern',
            xtype:      'textfield',
            name:       'exclude',
            emptyText:  'regular search exclude expression'
        });
    }
});
