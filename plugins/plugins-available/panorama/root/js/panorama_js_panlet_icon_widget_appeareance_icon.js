TP.iconsetsStore = Ext.create('Ext.data.Store', {
    fields: ['name', 'sample', 'value', 'fileset'],
    proxy: {
        type: 'ajax',
        url:  'panorama.cgi?task=userdata_iconsets&withempty=1',
        reader: {
            type: 'json',
            root: 'data'
        }
    },
    autoLoad: true,
    data : thruk_iconset_data
});

Ext.define('TP.IconWidgetAppearanceIcon', {

    alias:  'tp.icon.appearance.icon',

    constructor: function(config) {
        var me = this;
        Ext.apply(me, config);
    },

    /* always change icon, even on inactive tabs */
    updateRenderAlways: function(xdata) {
        this.iconSetSourceFromState(xdata);
    },

    iconSetSourceFromState: function(xdata) {
        var panel = this.panel;
        if(xdata       == undefined) { xdata = panel.xdata; }
        if(xdata.state == undefined) { xdata.state = panel.xdata.state; }
        if(xdata.state == undefined) { xdata.state = 4; }
        var tab   = Ext.getCmp(panel.panel_id);
        if(!panel.icon) {
            panel.setRenderItem(xdata);
            return;
        }
        var iconsetName = xdata.appearance.iconset;
        if(iconsetName == '' || iconsetName == undefined) {
            if(!tab) { return; }
            iconsetName = tab.xdata.defaulticonset || 'default';
        }

        var newSrc;

        // get iconset from store
        var rec = TP.iconsetsStore.findRecord('value', iconsetName);
        if(rec == null) {
            newSrc = Ext.BLANK_IMAGE_URL;
        }
        else if(panel.iconType == 'image') {
            panel.iconCheckBorder(xdata);
            if(xdata.general.src == undefined || xdata.general.src == "" || xdata.general.src.match(/\/panorama\/images\/s\.gif$/)) {
                newSrc = Ext.BLANK_IMAGE_URL;
            } else {
                newSrc = xdata.general.src;
            }
        }
        else if(panel.iconType == 'host' || panel.hostProblem) {
            if(panel.acknowledged) {
                     if(xdata.state == 1) { newSrc = 'acknowledged_down';        }
                else if(xdata.state == 2) { newSrc = 'acknowledged_unreachable'; }
                else                      { newSrc = 'acknowledged_unknown';     }
            }
            else if(panel.downtime) {
                if(     xdata.state == 0) { newSrc = 'downtime_up';          }
                else if(xdata.state == 1) { newSrc = 'downtime_down';        }
                else if(xdata.state == 2) { newSrc = 'downtime_unreachable'; }
                else if(xdata.state == 4) { newSrc = 'downtime_pending';     }
                else                      { newSrc = 'downtime_unknown';     }
            } else {
                if(     xdata.state == 0) { newSrc = 'up';          }
                else if(xdata.state == 1) { newSrc = 'down';        }
                else if(xdata.state == 2) { newSrc = 'unreachable'; }
                else if(xdata.state == 4) { newSrc = 'pending';     }
                else                      { newSrc = 'unknown';     }
            }
        } else {
            if(panel.acknowledged) {
                     if(xdata.state == 1) { newSrc = 'acknowledged_warning';  }
                else if(xdata.state == 2) { newSrc = 'acknowledged_critical'; }
                else                      { newSrc = 'acknowledged_unknown';  }
            }
            else if(panel.downtime) {
                if(     xdata.state == 0) { newSrc = 'downtime_ok';       }
                else if(xdata.state == 1) { newSrc = 'downtime_warning';  }
                else if(xdata.state == 2) { newSrc = 'downtime_critical'; }
                else if(xdata.state == 4) { newSrc = 'downtime_pending';  }
                else                      { newSrc = 'downtime_unknown';  }
            } else {
                if(     xdata.state == 0) { newSrc = 'ok';       }
                else if(xdata.state == 1) { newSrc = 'warning';  }
                else if(xdata.state == 2) { newSrc = 'critical'; }
                else if(xdata.state == 4) { newSrc = 'pending';  }
                else                      { newSrc = 'unknown';  }
            }
        }
        if(rec != null && rec.data.fileset[newSrc]) {
            newSrc = '../usercontent/images/status/'+iconsetName+'/'+rec.data.fileset[newSrc];
        }
        panel.src = newSrc;
        panel.icon.setAttributes({src: newSrc}).redraw();
        panel.iconFixSize(xdata);
        if(!TP.isThisTheActiveTab(panel)) { panel.hide(); }
    },

    getAppearanceTabItems: function(panel) {
        return([{
            fieldLabel:   'Icon Set',
            id:           'iconset_field',
            xtype:        'combobox',
            name:         'iconset',
            cls:          'icon',
            store:         TP.iconsetsStore,
            value:        '',
            emptyText:    'use dashboards default icon set',
            displayField: 'name',
            valueField:   'value',
            listConfig : {
                getInnerTpl: function(displayField) {
                    return '<div class="x-combo-list-item"><img src="{sample}" height=16 width=16 style="vertical-align:top; margin-right: 3px;">{name}<\/div>';
                }
            },
            listeners: {
                change: function(This) { TP.iconSettingsGlobals.renderUpdate(undefined, true); }
            }
        }, {
            xtype:      'panel',
            cls:        'icon',
            html:       'Place image sets in: '+usercontent_folder+'/images/status/',
            style:      'text-align: center;',
            bodyCls:    'form-hint',
            padding:    '10 0 0 0',
            border:      0
        }]);
    }
});
