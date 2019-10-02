Ext.define('TP.PanletGridComments', {
    extend: 'TP.PanletGrid',

    title:  'Comments',
    height: 300,
    width:  1000,
    //maximizable: true, // does not work stateful
    hideSettingsForm: ['url'],
    has_search_button: 'service',
    grid_sort:          false,
    initComponent: function() {
        this.callParent();
        this.xdata.url           = 'panorama.cgi?task=show_comments';
        this.xdata.source        = 'both';
        this.xdata.type          = ['ack', 'downtime', 'comment', 'flap'];
        this.xdata.showborder    = true;
        this.reloadOnSiteChanges = true;
    },
    setGearItems: function() {
        var panel = this;
        panel.callParent();
        panel.addGearItems({
            xtype:          'combobox',
            fieldLabel:     'Type',
            name:           'type',
            store:           [['ack','Acknowledgements'], ['downtime','Downtimes'], ['comment','Comments'], ['flap','Flappings']],
            multiSelect:     true,
            editable:        false,
            triggerAction:  'all',
            listConfig : {
                getInnerTpl: function(displayField) {
                    return '<div class="x-combo-list-item"><img src="' + Ext.BLANK_IMAGE_URL + '" class="chkCombo-default-icon chkCombo" /> {'+displayField+'} <\/div>';
                }
            }
        });
        panel.addGearItems({
            xtype:          'combobox',
            fieldLabel:     'Host/Service',
            name:           'source',
            editable:        false,
            triggerAction:  'all',
            store:           [['both','Both'], ['hosts','Hosts'], ['services','Services']]
        });
        TP.addFormFilter(panel, panel.has_search_button);
        panel.addGearItems({
            fieldLabel: 'Include Pattern',
            xtype:      'textfield',
            name:       'pattern',
            emptyText:  'regular search expression (author / comment field)'
        });
        panel.addGearItems({
            fieldLabel: 'Exclude Pattern',
            xtype:      'textfield',
            name:       'exclude',
            emptyText:  'regular search exclude expression (author / comment field)'
        });
        TP.addGearBackgroundOptions(panel);
    }
});
