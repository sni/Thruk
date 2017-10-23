/* show dashboard management window */
Ext.define('TP.DashboardManagementWindow', {
    extend:      'Ext.window.Window',
    autoShow:     true,
    modal:        true,
    width:        800,
    resizable:    false,
    title:       'Dashboard Management',
    closeAction: 'destroy',
    cls:         'dashboardmanagementwindow',
    initComponent: function() {
        var win   = this;
        win.xdata = {};
        win.callParent();
        win.startLoading = false;

        var listeners = {
            activate: function(This, eOpts) {
                var panel = This.up('panel').up('panel');
                // update grid content
                if(This.loader && win.startLoading) {
                    This.loader.grid  = This;
                    This.loader.xdata = panel.xdata;
                    This.loader.load();
                }
                TP.dashboardsSettingGrid = This;
                // reset filter
                if(TP.dashboardsSettingWindow) {
                    var filterEl = Ext.getCmp('dashboardManagementFilterEl');
                    var resetEl  = Ext.getCmp('dashboardManagementResetBtn');
                    if(   (TP.dashboardsSettingGrid.tabConfig && TP.dashboardsSettingGrid.tabConfig.title.match(/Import/))
                       || (TP.dashboardsSettingGrid.title && TP.dashboardsSettingGrid.title.match(/Import/))
                       ) {
                        filterEl.hide();
                        resetEl.hide();
                    } else {
                        filterEl.show();
                        resetEl.show();
                        filterEl.setValue('');
                    }
                }
            },
            beforeselect: function(This, record, index, eOpts) {
                /* prevent selections */
                return false;
            },
            edit: function(editor, el) {
                if(el.value != el.originalValue) {
                    TP.toggleDashboardOption(el.record.data.id, el.field, el.value);
                    el.record.commit();
                }
            },
            destroy: function(This, eOpts) {
                delete TP.dashboardsSettingWindow;
                return true;
            },
            close: function(This, eOpts) {
                This.destroy();
                return true;
            },
            afterrender: function(This) {
                win.startLoading = true;
            },
            reconfigure: function(This) {
                win.unmask();
            }
        }
        /* My Dasboards */
        win.grid_my = Ext.create('Ext.grid.Panel', {
            tabConfig: {
                title:   'My',
                tooltip: 'My Dashboards'
            },
            columns:     [],
            listeners:   listeners,
            loader:      Ext.create('TP.GridLoader', {
                url:        'panorama.cgi?task=dashboard_list&list=my',
                loadMask:    true,
                reconfigure: true
            }),
            plugins: readonly ? [] : [Ext.create('Ext.grid.plugin.CellEditing', { clicksToEdit: 1 })]
        });
        win.items.get(0).add(win.grid_my);

        /* Shared Dasboards */
        win.grid_public = Ext.create('Ext.grid.Panel', {
            tabConfig: {
                title:   'Shared',
                tooltip: 'Shared Dashboards'
            },
            columns:     [],
            listeners:   listeners,
            loader:      Ext.create('TP.GridLoader', {
                url:        'panorama.cgi?task=dashboard_list&list=public',
                loadMask:    true,
                reconfigure: true
            }),
            plugins: readonly ? [] : [Ext.create('Ext.grid.plugin.CellEditing', { clicksToEdit: 1 })]
        });
        win.items.get(0).add(win.grid_public);

        /* All Dasboards, Admins only */
        if(thruk_is_admin) {
            win.grid_all = Ext.create('Ext.grid.Panel', {
                tabConfig: {
                    title:   'All',
                    tooltip: 'All Dashboards'
                },
                columns:     [],
                listeners:   listeners,
                loader:      Ext.create('TP.GridLoader', {
                    url:        'panorama.cgi?task=dashboard_list&list=all',
                    loadMask:    true,
                    reconfigure: true
                }),
                plugins: readonly ? [] : [Ext.create('Ext.grid.plugin.CellEditing', { clicksToEdit: 1 })],
                bbar:[{
                    xtype:   'button',
                    text:    'Cleanup Dashboards',
                    iconCls: 'clear-btn',
                    handler: function(This) {
                        This.setIconCls("wait-btn");
                        This.mask("loading");
                        Ext.Ajax.request({
                            url:      'panorama.cgi?task=dashboards_clean',
                            method:  'POST',
                            callback: function(options, success, response) {
                                This.unmask();
                                This.setIconCls("clear-btn");
                                if(!success) {
                                    if(response.status == 0) {
                                        TP.Msg.msg("fail_message~~cleaning dashboards failed");
                                    } else {
                                        TP.Msg.msg("fail_message~~cleaning dashboards failed: "+response.status+' - '+response.statusText);
                                    }
                                } else {
                                    var data = TP.getResponse(undefined, response);
                                    if(data.num > 0) {
                                        TP.Msg.msg("success_message~~cleaned "+data.num+" dashboards successful");
                                        This.up('panel').loader.load();
                                    } else {
                                        TP.Msg.msg("success_message~~all dashboards are cleaned already");
                                    }
                                }
                            }
                        });
                    }
                }]
            });
            win.items.get(0).add(win.grid_all);
        }

        /* import / export */
        var tabpan = Ext.getCmp('tabpan');
        var tab    = tabpan.getActiveTab();
        if(!tab) {
            debug("forced setting activeTab");
            tab = tabpan.setActiveTab(0);
        }
        win.exportTab = TP.getExportTab({listeners: listeners, tab: tab});
        win.items.get(0).add(win.exportTab);

        win.items.get(0).setActiveTab(0);
    },
    items: [{
        xtype:        'tabpanel',
        height:        380,
        items:         [],
        tabBar:        {
            items: [{
                xtype: 'tbfill'
            }, {
                xtype:        'textfield',
                emptyText:    'filter dashboards',
                width:         120,
                closable:      false,
                id:           'dashboardManagementFilterEl',
                fieldStyle:   'border-bottom: 1px solid #EAEAEA;',
                fieldBodyCls: 'x-form-clear-trigger',
                listeners: {
                    change: function(This) {
                        var clearBtn  = Ext.getCmp('dashboardManagementResetBtn');
                        var activeTab = This.up('window').items.getAt(0).getActiveTab();
                        var store     = activeTab.store;
                        if(This.value != undefined && This.value != '') {
                            clearBtn.enable();
                            var val   = This.value.toLowerCase();
                            store.filterBy(function(rec, id) {
                                var found = false;
                                for(var key in rec.data) {
                                    if(String(rec.data[key]).toLowerCase().match(val)) { found=true; }
                                }
                                return found;
                            });
                        } else {
                            clearBtn.disable();
                            store.clearFilter();
                        }
                    }
                }
            }, {
                xtype:   'button',
                text:    ' ',
                width:    19,
                border:   1,
                style:    'padding: 0 0 5px;',
                cls:     'x-form-clear-trigger',
                id:      'dashboardManagementResetBtn',
                disabled: true,
                handler: function(This) {
                   var searchField = Ext.getCmp('dashboardManagementFilterEl');
                    searchField.reset();
                },
                listeners: {
                    afterrender: function(This) {
                        window.setTimeout(function() {
                            var style = This.getEl().dom.style;
                            var left  = Number(String(style.left).replace(/px$/, ''));
                            style.top          = '-1px';
                            style.borderBottom = '1px solid #EAEAEA';
                            style.borderTop    = '1px solid #B5B8C8';
                            style.borderRight  = '1px solid #B5B8C8';
                            style.borderLeft   = '0';
                            style.left         = left-2+'px';
                        } , 100);
                    }
                }
            }]
        }
    }]
});

TP.dashboardsWindow = function() {
    var win = Ext.create('TP.DashboardManagementWindow', {});
    TP.dashboardsSettingWindow = win;

    // somehow new tabbar elements occur when opening window again, so we just remove them
    var toDelete = TP.dashboardsSettingWindow.items.getAt(0).tabBar.items.getCount() - 7;
    if(toDelete > 0) {
        for(var x = toDelete-1; x >= 0; x--) {
            TP.dashboardsSettingWindow.items.getAt(0).tabBar.items.getAt(7+x).destroy();
            TP.dashboardsSettingWindow.items.getAt(0).tabBar.items.removeAt(7+x);
        }
        TP.dashboardsSettingWindow.items.getAt(0).tabBar.doLayout();
    }
}
