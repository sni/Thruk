Ext.define('TP.TabBar', {
    extend: 'Ext.tab.Panel',
    plugins: [
        new Ext.ux.TabReorderer({
            itemSelector: '.x-tab-closable', // only make real tabs draggable, not the menus
            animate:       0,                // causes flickering server_time otherwise
            listeners: {
                Drop: function(This, container, dragCmp, idx, eOpts) {
                    tabpan = Ext.getCmp('tabpan');
                    tabpan.saveState();
                }
            }
        })
    ],

    id:             'tabpan',
    bodyCls:        'tabbarbody',
    region:         'center',
    minTabWidth:    80,
    deferredRender: false,
    stateful:       true,
    tabBar:{
        id:        'maintabbar',
        listeners: {
            afterlayout: function(This, eOpts) {
                // move this html element to the body so it can have its own zindex stack and stay in front
                Ext.getBody().appendChild(Ext.get('maintabbar'));
            }
        },
        items:[{ xtype: 'tbfill' },{
            id:       'debug_dom_elements',
            xtype:    'label',
            width:     70,
            html:     'DOM:'+document.getElementsByTagName('*').length,
            style:    'margin-top: 3px',
            hidden:    true,
            listeners: {
                show: function(This, eOpts) {
                    TP.timeouts['interval_global_dom_elements'] = window.setInterval(
                        function() {
                            var elements = Ext.Array.toArray(document.getElementsByTagName('*')).filter(function(v, i, a) { if(v.className && v.className.match && v.className.match("firebug")) {return(false)}; return(true); });
                            Ext.getCmp('debug_dom_elements').el.dom.innerHTML = 'DOM:'+elements.length;
                            /*
                            if(TP.old_dom_elements && TP.old_dom_elements.length != elements.length) {
                                var diff = Ext.Array.difference(elements, TP.old_dom_elements);
                                if(diff.length > 0) {
                                    console.log("found "+diff.length+" new dom elements");
                                    if(diff.length < 20) {
                                        console.log(diff);
                                    }
                                }
                            }
                            TP.old_dom_elements = elements;
                            */
                        },
                        2000
                    );
                }
            }
        }, {
            id:       'debug_tab',
            closable: false,
            minWidth: 38,
            html:     'Debug',
            iconCls:  'debug-tab',
            tooltip:  'Debug Information',
            handler:  function() { thruk_debug_window_handler() },
            margin:   '0 15 0 0',
            listeners: { afterrender: function(This, eOpts) { This.hide(); } }
        }, {
            xtype:    'label',
            text:     server_time.strftime("%H:%M"),
            id:       'server_time',
            tooltip:  'server time',
            style:    'margin-top: 3px',
            width:    35,
            height:   16,
            listeners: {
                afterrender: function(This, eOpts) {
                    This.el.on('dblclick', function() {
                        TP.openLogWindow();
                    });
                }
            }
        }, {
            id:       'bug_report',
            closable:  false,
            minWidth:  28,
            iconCls:  'bug-tab',
            href:     '#',
            html:     'Report',
            tooltip:  'Send Bug Report',
            listeners: { afterrender: function(This, eOpts) { This.hide(); } }
        }, {
            iconCls:  'user-tab',
            closable:  false,
            tooltip:  'user menu',
            arrowCls: 'arrow x-btn-arrow-right x-btn-arrow',
            html:      remote_user+'&nbsp;&nbsp;&nbsp;',
            menu: {
                listeners: {
                    afterrender: function(menu, eOpts) {
                        var tabpan = Ext.getCmp('tabpan');
                        var tab    = tabpan.getActiveTab();
                        tab.disableMapControlsTemp();
                    },
                    beforehide: function(menu, eOpts) {
                        var tabpan = Ext.getCmp('tabpan');
                        var tab    = tabpan.getActiveTab();
                        tab.enableMapControlsTemp();
                    }
                },
                items: [{
                        text: 'About',
                        icon: url_prefix+'plugins/panorama/images/information.png',
                        handler: function() { TP.aboutWindow() }
                    }, {
                        text: 'Settings',
                        icon: url_prefix+'plugins/panorama/images/cog.png',
                        handler: function() { TP.tabSettingsWindow() },
                        hidden: readonly
                    }, {
                        text: 'Dashboard Management',
                        icon: url_prefix+'plugins/panorama/images/new_tab.gif',
                        handler: function() { TP.dashboardsWindow() },
                        hidden: readonly
                    }, '-', {
                        text:   'Save Active Dashboard',
                        icon:    url_prefix+'plugins/panorama/images/disk.png',
                        href:   'panorama.cgi?task=save_dashboard&nr=',
                        listeners: {
                            focus: function(item, e, eOpts) {
                                item.el.dom.firstChild.href = 'panorama.cgi?task=save_dashboard&nr='+Ext.getCmp('tabpan').getActiveTab().id;
                            }
                        }
                    }, {
                        text:   'Load Dashboard',
                        icon:    url_prefix+'plugins/panorama/images/folder_picture.png',
                        handler: function() { TP.loadDashboardWindow() }
                    },
                    /* Exit */
                    '-',
                    {
                        text:   'Logout',
                        icon:   url_prefix+'plugins/panorama/images/door_in.png',
                        handler: function() {
                            window.location = 'login.cgi?logout';
                        },
                        hidden: !cookie_auth
                    },
                    {
                        text:   'Exit Panorama View',
                        icon:   url_prefix+'plugins/panorama/images/exit.png',
                        handler: function() {
                            window.location = '../';
                        }
                    }
                ]
            }
        }, {
            title:    'add new panel and widgets',
            closable: false,
            minWidth: 70,
            id:       'tabbar_addbtn',
            iconCls:  'gear-tab',
            tooltip:  'add panlets',
            arrowCls: 'arrow x-btn-arrow-right x-btn-arrow',
            html:     'add&nbsp;&nbsp;',
            menu:      TP.addPanletsMenu({open: 'left'}),
            hidden:    readonly
        }]
    },
    initComponent: function() {
        this.callParent();

        /* global default setttings */
        this.xdata = {
            rotate_tabs:     0,
            server_time:    true,
            sounds_enabled: false
        }

        /* create new tab */
        var tabhead = this.getTabBar().items.getAt(0);
        tabhead.addListener('click', function(This, eOpts) {
            var tabpan = Ext.getCmp('tabpan');
            var tab    = tabpan.getActiveTab();
            tab.disableMapControlsTemp();
            var menu = Ext.create('Ext.menu.Menu', {
                margin: '0 0 10 0',
                items: [{
                    text:   'New Dashboard',
                    icon:   url_prefix+'plugins/panorama/images/add.png',
                    handler: function() { TP.log('[global] adding new dashboard from menu'); TP.add_pantab('new') }
                }, {
                    text:   'New Geo Map',
                    icon:   url_prefix+'plugins/panorama/images/map.png',
                    handler: function() { TP.log('[global] adding new geo map from menu'); TP.add_pantab('new_geo') }
                }, '-', {
                    text:   'Dashboard Management',
                    icon:   url_prefix+'plugins/panorama/images/new_tab.gif',
                    handler: function() { TP.dashboardsWindow() }
                }, '-', {
                    text: 'My Dashboards',
                    icon: url_prefix+'plugins/panorama/images/user_suit.png',
                    hideOnClick: false,
                    menu: [{
                        text:    'Loading...',
                        icon:    url_prefix+'plugins/panorama/images/loading-icon.gif',
                        disabled: true
                    }]
                }, {
                    text: 'Public Dashboards',
                    icon: url_prefix+'plugins/panorama/images/world.png',
                    hideOnClick: false,
                    menu: [{
                        text:    'Loading...',
                        icon:    url_prefix+'plugins/panorama/images/loading-icon.gif',
                        disabled: true
                    }]
                }],
                listeners: {
                    beforehide: function(menu, eOpts) {
                        tab.enableMapControlsTemp();
                        menu.destroy();
                    }
                }
            }).showBy(This);
            TP.load_dashboard_menu_items(menu.items.get(5).menu, 'panorama.cgi?task=dashboard_list&list=my', TP.add_pantab, false);
            TP.load_dashboard_menu_items(menu.items.get(6).menu, 'panorama.cgi?task=dashboard_list&list=public', TP.add_pantab, false);
        });

        this.addListener('afterrender', function(This, eOpts) {
            var open_tabs = [];
            this.items.each(function(item, idx, length) {
                var stateId = item.getStateId();
                if(stateId) {
                    open_tabs.push(stateId);
                }
            });
            if(open_tabs.length == 0 && default_dashboard && default_dashboard.length > 0) {
                debug("using default view");
                TP.initial_active_tab = default_dashboard[0];
                TP.initial_active_tab = String(TP.initial_active_tab).replace(/^tabpan-tab_/, '');
                TP.initial_active_tab = "tabpan-tab_"+TP.initial_active_tab;
                for(var x = 0; x<default_dashboard.length; x++) {
                    TP.add_pantab(default_dashboard[x], undefined, x == 0 ? false : true);
                }
            } else if(open_tabs.length == 0) {
                TP.add_pantab("tabpan-tab_0");
            }
            TP.startServerTime();
        });
        if(!ExtState[this.id]) {
            TP.initComplete();
        }
    },
    getState: function() {
        var open_tabs = [];
        this.items.each(function(item, idx, length) {
            var stateId = item.getStateId();
            if(stateId && item.rendered) {
                open_tabs.push(stateId);
            }
        });
        if(this.tabs_tr == undefined) {
            this.tabs_tr = {};
        }
        var tabs = Ext.query('.x-tab-closable');
        for(var nr=0; nr<tabs.length; nr++) {
            if(this.tabs_tr[tabs[nr].id] == undefined) {
                this.tabs_tr[tabs[nr].id] = open_tabs[nr];
            }
        }
        var ordered_items = [];
        for(var nr=0; nr<tabs.length; nr++) {
            ordered_items.push(this.tabs_tr[tabs[nr].id]);
        }
        if(open_tabs.length == ordered_items.length) {
            open_tabs = ordered_items;
        }
        var activeTab = this.getActiveTab();
        if(!activeTab) {
            debug("forced setting activeTab");
            activeTab = this.setActiveTab(0);
        }
        activeTab = activeTab.getStateId();
        this.open_tabs = open_tabs;

        return {
            open_tabs:  open_tabs,
            xdata:      this.xdata,
            activeTab:  activeTab
        }
    },
    applyState: function(state) {
        TP.log('['+this.id+'] applyState: '+Ext.JSON.encode(state));
        try {
            TP.initial_create_delay_active   = 0;    // initial delay of placing panlets (will be incremented in pantabs applyState)
            TP.initial_create_delay_inactive = 1000; // placement of inactive panlet starts delayed
            if(state) {
                if(TP.initial_active_tab == undefined && get_hash(1)) {
                    TP.initial_active_tab = "tabpan-tab_"+get_hash(1);
                }
                if(state.activeTab && TP.initial_active_tab == undefined) {
                    TP.initial_active_tab = state.activeTab;
                }
                this.xdata = state.xdata;

                // REMOVE AFTER: 01.01.2017
                if(state.item_ids) {
                    for(var nr=0; nr<state.item_ids.length; nr++) {
                        TP.add_pantab(state.item_ids[nr], undefined, undefined, undefined, undefined, true);
                    };
                }

                if(state.open_tabs) {
                    for(var nr=0; nr<state.open_tabs.length; nr++) {
                        var name = state.open_tabs[nr];
                        TP.add_pantab(state.open_tabs[nr], undefined, undefined, undefined, undefined, true);
                    };
                }

                /* open tab from url */
                if(!Ext.getCmp(TP.initial_active_tab)) {
                    TP.add_pantab(TP.initial_active_tab, undefined, undefined, undefined, undefined, true);
                    state.activeTab = TP.initial_active_tab;
                }

                this.setActiveTab(state.activeTab);
                Ext.apply(this, state);
            }
            TP.timeouts['timeout_'+this.id+'_delayed_start'] = window.setTimeout(Ext.bind(this.startTimeouts, this, []), TP.initial_create_delay_active);
        } catch(err) {
            TP.logError(this.id, "tabbarApplyStateException", err);
            if(confirm("Errors while loading your saved settings:\n\n"+err+"\n\nStart over with a clean view?\nAll panorama view settings will be deleted.")) {
                window.location = 'panorama.cgi?clean=1';
            }
        }
        if(TP.initMask) {
            TP.timeouts['timeout_'+this.id+'_remove_mask'] = window.setTimeout(function() {
                // hide mask
                if(TP.initMask) { TP.initMask.destroy(); delete TP.initMask; }
            } ,TP.initial_create_delay_active + 500);
        }
    },
    items: [{
        title:   '',
        closable: false,
        iconCls: 'new-tab',
        tabConfig: {
            minWidth: 28,
            maxWidth: 28
        },
        tooltip: 'Add Dashboards',
        listeners: {
            beforeactivate: function() { return false; }
        }
    }],

    /* start all timed actions all tabs all panels */
    startTimeouts: function() {
        TP.initComplete();
        this.stopTimeouts();
        TP.log('['+this.id+'] startTimeouts');

        // REMOVE AFTER: 01.01.2017
        delete this.xdata['refresh'];
        delete this.xdata['autohideheader'];
        delete this.xdata['backends'];
        if(TP.reload_required) {
            Ext.Msg.alert("Reload Required", "Internal storage format has changed. Page will reload automatically with the new format...");
            TP.timeouts['timeout_'+this.id+'_window_reload'] = window.setTimeout(function() { TP.cp.saveChanges(false); window.location = 'panorama.cgi'; }, 3000);
            return;
        }

        var activeTab = this.getActiveTab();
        if(!activeTab) {
            activeTab = this.setActiveTab(0);
        }

        TP.startRotatingTabs();
        TP.startServerTime();
        this.items.each(function(tab) {
            if(tab.startTimeouts) {
                tab.startTimeouts();
            }
        });
    },

    /* stop all timed actions all tabs all panels */
    stopTimeouts: function() {
        TP.log('['+this.id+'] stopTimeouts');
        TP.stopRotatingTabs();
        TP.stopServerTime();
        this.items.each(function(tab) {
            if(tab.stopTimeouts) {
                tab.stopTimeouts();
            }
        });
    },

    /* ensure only panlets from the active tab are visible */
    checkPanletVisibility: function(activeTab) {
        this.items.each(function(tab) {
            if(tab.hidePanlets && tab.id != activeTab.id) {
                tab.hidePanlets();
            }
        });
        if(activeTab.map) {
            /* remove chrome workaround */
            Ext.get('tabpan') && Ext.get('tabpan').dom.style.setProperty('z-index', "", "");
        } else {
            /* apply chrome background workaround */
            Ext.get('tabpan') && Ext.get('tabpan').dom.style.setProperty('z-index', "21", "important");
        }
    }
});


TP.load_dashboard_menu_items = function(menu, url, handler, all) {
    Ext.Ajax.request({
        url:      url,
        method:  'POST',
        callback: function(options, success, response) {
            if(!success) {
                if(response.status == 0) {
                    TP.Msg.msg("fail_message~~adding new dashboard failed");
                } else {
                    TP.Msg.msg("fail_message~~adding new dashboard failed: "+response.status+' - '+response.statusText);
                }
            } else {
                var data = TP.getResponse(undefined, response);
                data = data.data;
                menu.removeAll();
                var found = 0;
                for(var x=0; x<data.length; x++) {
                    if(all || (!Ext.getCmp(data[x].id)) || !Ext.getCmp(data[x].id).rendered) {
                        found++;
                        menu.add({text:    data[x].name,
                                  val:     data[x].id,
                                  icon:   url_prefix+'plugins/panorama/images/table_go.png',
                                  handler: function() { TP.log('[global] adding dashboard from menu: '+this.val); handler(this.val); }
                                }
                        );
                    }
                }
                if(found == 0) {
                    menu.add({text: 'none', disabled: true});
                }
            }
        }
    });
}

TP.getLogTab = function() {
    var formatLogEntry = function(entry) {
        var date = Ext.Date.format(entry[0], "Y-m-d H:i:s.u");
        return('['+date+'] '+entry[1]+"\n");
    }

    var logTab = {
        title : 'Log',
        type  : 'panel',
        layout: 'fit',
        items: [{
            xtype:  'form',
            layout: 'fit',
            id:     'logform',
            items: [{
                xtype:   'textarea',
                value:   'loading...',
                id:      'logtextarea',
                disabled: true,
                listeners: {
                    afterrender: function(This, eOpts) {
                        window.setTimeout(function() {
                            Ext.getCmp('logrefresh').handler();
                        }, 200);
                    }
                }
            }]
        }],
        dockedItems: [{
            xtype: 'toolbar',
            dock: 'bottom',
            items: [{
                text:   'Refresh',
                xtype:  'button',
                iconCls:'refresh-btn',
                id:     'logrefresh',
                handler: function(This) {
                    var logtextarea = Ext.getCmp('logtextarea');
                    var filter      = Ext.getCmp('logfilter').getValue();
                    if(logtextarea.lastLength != TP.logHistory.length || logtextarea.lastFilter != filter) {
                        var input = Ext.get('logtextarea-inputEl');
                        var oldScroll = input.dom.scrollTop;
                        input.dom.scrollTop = 100000000;
                        var scrollDown = false;
                        if(oldScroll != 0 && oldScroll == input.dom.scrollTop) { scrollDown = true; } /* scroll down if we were on bottom before */
                        if(logtextarea.lastLength == undefined) { scrollDown = true; } /* scroll down if this is the first refresh */
                        logtextarea.lastLength = TP.logHistory.length;
                        logtextarea.lastFilter = filter;
                        var text = "";
                        var pattern;
                        if(filter) { pattern = new RegExp(filter, 'i') }
                        for(var i = 0; i < TP.logHistory.length; i++) {
                            if(!pattern || TP.logHistory[i][1].match(pattern)) {
                                text += formatLogEntry(TP.logHistory[i]);
                            }
                        }
                        logtextarea.setValue(text);
                        logtextarea.setDisabled(false);
                        if(scrollDown) {
                            input.dom.scrollTop = 100000000;
                        } else {
                            input.dom.scrollTop = oldScroll;
                        }
                    }
                }
            }, {
                xtype:    'checkbox',
                boxLabel: 'Automatically Refresh',
                handler:  function(This) {
                    if(This.checked) {
                        TP.timeouts['debug_log_refresh'] = window.setInterval(function() {
                            Ext.getCmp('logrefresh').handler();
                        }, 500);
                    } else {
                        window.clearInterval(TP.timeouts['debug_log_refresh']);
                    }
                },
                margins: '5 0 5 0'
            }, {
                text:   'Save',
                xtype:  'button',
                iconCls:'save-btn',
                handler: function(This) {
                    var text = "";
                    for(var i = 0, len = TP.logHistory.length; i < len; i++) {
                        text += formatLogEntry(TP.logHistory[i]);
                    }
                    var form = Ext.getCmp('logform').getForm();
                    form.standardSubmit = true;
                    form.submit({
                        url:    'panorama.cgi',
                        target: '_blank',
                        params: {text: text, task: 'textsave'}
                    });
                }
            }, {
                    xtype: 'tbfill'
            }, {
                    xtype:     'textfield',
                    emptyText: 'enter search term',
                    id:        'logfilter',
                    listeners: {
                        keyup:  function(This, evt, eOpts) { Ext.getCmp('logrefresh').handler(); },
                        change: function(This, evt, eOpts) { Ext.getCmp('logrefresh').handler(); }
                    },
                    fieldBodyCls: 'x-form-clear-trigger'
            }, {
                xtype:   'button',
                text:    ' ',
                width:    19,
                border:   1,
                style:    'padding: 0 0 5px;',
                cls:     'x-form-clear-trigger',
                handler: function(This) {
                   Ext.getCmp('logfilter').reset();
                },
                listeners: {
                    afterrender: function(This) {
                        window.setTimeout(function() {
                            var style = This.getEl().dom.style;
                            var left  = Number(String(style.left).replace(/px$/, ''));
                            style.top    = '4px';
                            style.border = '0';
                            style.left   = left-3+'px';
                        } , 100);
                    }
                }
            }, {
                    xtype: 'tbfill'
            }, {
                text:   'Clear',
                iconCls:'clear-btn',
                xtype:  'button',
                handler: function(This) {
                    TP.logHistory = [];
                    Ext.getCmp('logrefresh').handler();
                }
            }]
        }]
    };
    return(logTab);
}
TP.openLogWindow = function() {
    /* tab layout for log window */
    var tabPanel = new Ext.TabPanel({
        activeTab         : 0,
        enableTabScroll   : true,
        items             : [ TP.getLogTab() ]
    });

    /* show the window containing the debug messages */
    var debug_win = new Ext.window.Window({
        autoShow:    true,
        modal:       true,
        width:       1000,
        height:      350,
        title:       'Debug Information',
        layout :     'fit',
        buttonAlign: 'center',
        items:       tabPanel,
        fbar: [{/* close button */
                    xtype:  'button',
                    text:   'OK',
                    handler: function(This) {
                        debug_win.destroy();
                    }
        }],
        listeners: {
            destroy: function(This, eOpts) {
                window.clearInterval(TP.timeouts['debug_log_refresh']);
                window.clearInterval(TP.timeouts['debug_log_keep_top']);
            }
        }
    });
}
