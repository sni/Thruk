Ext.define('TP.IconWidgetAppearancePerfBar', {

    alias:  'tp.icon.appearance.perfbar',

    constructor: function(config) {
        var me = this;
        Ext.apply(me, config);
    },

    /* update render item on active tab only */
    updateRenderActive: function(xdata) {
        this.perfbarRender(xdata);
    },

    setRenderItem: function(xdata) {
        var panel = this.panel;
        panel.add({
            xtype:       'panel',
            listeners: {
                afterrender: function(This, eOpts) {
                    panel.itemRendering = false;
                    panel.chart = This;
                    panel.updateRender(xdata);
                },
                resize: function(This, width, height, oldWidth, oldHeight, eOpts) {
                    panel.updateRender(xdata);
                }
            }
        });
    },

    /* renders performance bar */
    perfbarRender: function(xdata, forceColor) {
        var panel = this.panel;
        if(xdata == undefined) { xdata = panel.xdata; }
        if(xdata.appearance.type != 'perfbar') { return }
        panel.setSize(75, 20);
        if(!panel.items.getAt(0)) {
            panel.setRenderItem(xdata);
            return;
        }
        var data;
        if(panel.service) {
            data = panel.service;
        }
        else if(panel.host) {
            data = panel.host;
        }
        if(data) {
            var r =  perf_table(false, data.state, data.plugin_output, data.perf_data, data.check_command, "", !!panel.host, true);
            if(r == false) { r= ""; }
            panel.items.getAt(0).update(r);
        } else {
            if(TP.iconSettingsWindow) {
                xdata = TP.get_icon_form_xdata(TP.iconSettingsWindow);
            }
            var tab = Ext.getCmp(panel.panel_id);
            TP.updateAllIcons(tab, panel.id, xdata);
            panel.items.getAt(0).update("<div class='perf_bar_bg notclickable' style='width:75px;'>");
        }
    }
});