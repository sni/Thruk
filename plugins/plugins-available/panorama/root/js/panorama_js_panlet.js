Ext.define('TP.Panlet', {
    extend: 'Ext.window.Window',

    x:         0,
    y:         25,
    height:    200,
    width:     400,
    minSettingsWidth:  450,
    minSettingsHeight: 200,
    layout:    'fit',
    constrain: false,
    hideMode:  'visibility',
    autoShow:  false,
    autoRender: true,
    floating:   false,
    style:    { position: 'absolute', zIndex: 52 },
    stateful:  true,
    focusOnToFront: false,
    toFrontOnShow: false,
    initComponent: function() {
        var panel = this;
        if(this.xdata == undefined) {
            this.xdata = {};
        } else {
            this.xdata = TP.clone(this.xdata);
        }
        this.xdata.refresh  = -1;
        this.xdata.cls      = this.$className;
        this.xdata.backends = [];

        var tab     = Ext.getCmp(this.panel_id);
        if(tab == undefined) {
            var err = new Error;
            TP.logError(this.id, "noTabException", err);
            return;
        }
        this.locked = tab.xdata.locked;
        if(readonly) {
            this.locked = true;
        }
        this.redraw     = false;
        this.animations = 0;

        this.semilocked = false;
        if(dashboard_ignore_changes) {
            this.locked     = true;
            this.semilocked = true;
        }

        if(this.locked && !this.semilocked) {
            this.resizable = false;
            this.closable  = false;
            this.draggable = false;
        } else {
            this.resizable = new Ext.Panel({   // make resize snap to grid
                widthIncrement:  TP.snap_x,
                heightIncrement: TP.snap_y
            });
        }


        this.gearHandler = TP.panletGearHandler;
        this.tools = this.extra_tools || [];
        if(!this.locked) {
            if(this.has_search_button != undefined) {
                var This = this;
                this.tools.push({
                    type: 'search',
                    scope: this,
                    tooltip: 'change search filter',
                    handler: function() { TP.filterWindow(this.has_search_button, {setValue: function(v) { This.xdata.filter = v; This.refreshHandler() }, getValue: function() { return This.xdata.filter }}, panel); }
                });
            }
        }
        if(!this.locked) {
            this.tools.push({
                type: 'restore',
                scope: this,
                tooltip: 'clone this panel',
                handler: function() { var This = this; TP.add_panlet_delayed(TP.clone({type:This.xdata.cls, state:TP.clone_panel_config(This)}), -8, -8) }
            });
        }
        this.tools.push(new Ext.panel.Tool({
            type:    'refresh',
            scope:    this,
            tooltip: 'reload content of this panlet',
            handler:  function() { this.manualRefresh() }
        }));
        if(!this.locked) {
            this.tools.push({
                type: 'gear',
                scope: this,
                tooltip: 'settings',
                handler: function() { this.gearHandler() }
            });
        }
        this.shadow_id = this.id + '_shadow';
        this.win_shadow = new Ext.create('Ext.Layer', {
            shadow: 'drop',
            id:      this.shadow_id,
            cls:    'window_drop_shadow'
        });
        this.applyBorderAndBackground();
        this.callParent();
    },
    items:      [],
    html:       '',
    onEsc:      function() { return false; },
    startTimeouts: function() {
        if(!TP.initialized) { return; }
        this.stopTimeouts();
        TP.log('['+this.id+'] startTimeouts');
        var refresh = this.xdata.refresh;
        if(this.xdata.refresh == -1) {
            var tab = Ext.getCmp(this.panel_id);
            refresh = tab.xdata.refresh;
        }
        if(refresh > 0) {
            TP.timeouts['interval_'+this.id+'_refresh'] = window.setInterval(Ext.bind(this.refreshHandler, this, []), refresh * 1000);
        }
    },
    stopTimeouts: function() {
        TP.log('['+this.id+'] stopTimeouts');
        window.clearInterval(TP.timeouts['interval_'+this.id+'_refresh']);
    },
    dd_overriden: false,
    getState: function() {
        if(!this.el) { return; }
        var state = this.callParent(arguments);
        state.title = this.title;
        state.xdata = this.xdata;
        if(one_tab_only) {
            state.pos[1] += 25;
        }
        return state;
    },
    applyState: function(state) {
        this.callParent(arguments);
        if(state) {
            TP.log('['+this.id+'] applyState: '+Ext.JSON.encode(state));
            Ext.apply(this, state);
            this.setRawPosition(state.pos[0], state.pos[1]);
            this.setTitle(state.title);
            this.applyBorderAndBackground();
        }
    },
    /* change size and position animated */
    applyAnimated: function(animated) {
        var win = this;
        win.animations++;
        win.stateful = false;
        var delay = (animated.duration ? animated.duration : 250) + 250;
        window.setTimeout(Ext.bind(function() {
            win.animations--;
            if(win.animations == 0) { win.stateful = true; }
        }, win, []), delay);
        animated.to = {x:win.pos[0], y:win.pos[1], width: win.width, height: win.height};
        win.animate(animated);
    },
    setRawPosition: function(x, y) {
        var panel = this;
        panel.suspendEvents();
        panel.setPosition(x, y);
        if(panel.el && panel.el.dom) {
            panel.setPagePosition(x, y);
        }
        panel.resumeEvents();
        return(panel);
    },
    listeners:  {
        /* make shadow snap to grid */
        move: function( This, x, y, eOpts ) {
            if(This.snap != false && This.animations == 0) {
                var newpos = TP.get_snap(x, y);
                if(newpos[0] != x || newpos[1] != y) {
                    This.setRawPosition( newpos[0], newpos[1] );
                }
            }
            /* hide drop shadow */
            var shadow = Ext.get(This.id + '_shadow');
            if(shadow != undefined) { shadow.hide(); }
        },
        destroy: function( This, eOpts ) {
            TP.log('['+This.id+'] destroy');

            /* remove shadow */
            This.win_shadow.destroy();

            /* stop refreshing */
            This.stopTimeouts();

            if(!This.redraw) {
                /* remove window from panels window ids */
                TP.removeWindowFromPanels(this.id);

                // make sure timer is not started again
                this.xdata.refresh = 0;

                /* clear state information */
                TP.cp.clear(This.id);
            }
        },
        show: function(This, eOpts) {
            // make move show snap shadow
            if(This.dd_overriden == false && This.dd != undefined) {
                This.dd.onDrag = function(evt){
                    // original onDrag function
                    var me = this,
                    comp   = (me.proxy && !me.comp.liveDrag) ? me.proxy : me.comp,
                    offset = me.getOffset(me.constrain || me.constrainDelegate ? 'dragTarget' : null);
                    var x = me.startPosition[0] + offset[0];
                    var y = me.startPosition[1] + offset[1];
                    comp.setPagePosition(x, y);
                    // show shadow
                    var newpos;
                    if(This.snap == false) {
                        newpos = [x,y];
                    } else {
                        newpos = TP.get_snap(x, y);
                    }
                    This.win_shadow.moveTo(newpos[0], newpos[1]);
                    This.win_shadow.setSize(This.getSize());
                    This.win_shadow.show();
                };
                This.dd_overriden = true;
            }
        },
        render: function(This, eOpts) {
            /* make title editable */
            if(this.locked) {
                var head = Ext.get(This.id + '_header_hd');
                head.on("dblclick", function() {
                    Ext.Msg.prompt('Change Title', '', function(btn, text) {
                        if(btn == 'ok') {
                            This.setTitle(text);
                            This.saveState();
                        }
                    }, undefined, undefined, This.title);
                });
            }
            /* make header show on mouseover only */
            var div    = This.getEl();
            var global = Ext.getCmp(This.panel_id);
            div.on("mouseout", function()  { This.hideHeader(global); });
            if(global.xdata.autohideheader === 1 || !this.locked) {
                div.on("mouseover", function() { This.showHeader(global); });
            }
        },
        afterrender: function(This, eOpts) {
            Ext.fly('iconContainer').appendChild(Ext.get(This.id));
            /* start refresh interval */
            TP.log('['+this.id+'] rendered');
            this.startTimeouts();
            this.syncShadowTimeout();
            this.applyBorderAndBackground();
            if(this.xdata.showborder == false) {
                window.setTimeout(function() {
                    This.hideHeader();
                }, 500);
            }
        },
        beforestatesave: function( This, state, eOpts ) {
            if(This.locked) {
                return(false);
            }
            return(true);
        }
    },
    forceSaveState: function() {
        var oldLocked = this.locked;
        this.locked   = false;
        this.saveState();
        this.locked   = oldLocked;
    },
    setFormDefaults: function() {
        /* set initial form values */
        this.xdata['title'] = this.title;
        TP.applyFormValues(this.gearitem.down('form').getForm(), this.xdata);
        delete this.xdata['title'];
        if(this.formUpdatedCallback) {
            this.formUpdatedCallback(this);
        }
    },
    manualRefresh: function() {
        if(this.loader != undefined) { this.loader.loadMask=true; }
        this.refreshHandler();
        if(this.loader != undefined) { this.loader.loadMask=false; }
    },
    refreshHandler: function() {
        TP.defaultSiteRefreshHandler(this);
    },
    getTool: function(name) {
        for(var nr=0; nr<this.tools.length; nr++) {
            if(this.tools[nr].type == name) {
                return(this.tools[nr]);
            }
        }
        return null;
    },
    showHeader: function(global) {
        if(global == undefined) { global = Ext.getCmp(this.panel_id); }
        if(global.xdata.autohideheader === 1 || this.xdata.showborder == false) {
            var style = this.header.getEl().dom.style;
            if(style.width == '' || style.width != this.getEl().dom.style.width) {
                // not yet rendered
                var refresh = this.xdata.refresh;
                this.xdata.refresh = -2;
                this.header.show();
                this.header.hide();
                this.xdata.refresh = refresh;
            }
            style.display  = ''; // using inherit here break ie9: Could not get the display property. Invalid argument.
            style.zIndex   = 20;
            style.opacity  = '0.9';
            if(this.xdata.showborder == false) {
                if(this.getEl().shadow && this.getEl().shadow.el) {
                    this.getEl().shadow.el.removeCls('hidden');
                }
            }
            if(this.autohideHeaderOffset != undefined && !this.gearitem) {
                this.getEl().setStyle('overflow', 'visible');
                this.getHeader().getEl().dom.style.top = this.autohideHeaderOffset+'px';
            }
        }
        if(this.adjustBodyStyle) {
            this.adjustBodyStyle();
        }
    },
    hideHeader: function(global) {
        if(global == undefined) { global = Ext.getCmp(this.panel_id); }
        if((global.xdata.autohideheader === 1 || this.xdata.showborder == false) && this.gearitem == undefined) {
            var style = this.header.getEl().dom.style;
            style.display  = 'none';
            style.opacity  = '';
            style.zIndex   = '';
            if(this.xdata.showborder == false) {
                if(this.getEl().shadow && this.getEl().shadow.el) {
                    this.getEl().shadow.el.addCls('hidden');
                }
            }
        }
        if(this.adjustBodyStyle) {
            this.adjustBodyStyle();
        }
    },
    applyBorderAndBackground: function() {
        var global = Ext.getCmp(this.panel_id);
        if(global.xdata.autohideheader === 1 || (!global.locked && global.xdata.autohideheader === 2)) {
            this.overCls = 'autohideheaderover';
        }
        if(this.xdata.showborder == false && this.gearitem == undefined) {
            this.cls     = 'autohideheader';
            this.bodyCls = 'autohideheader';
            this.shadow  = false;
            if(this.rendered) {
                this.addCls('autohideheader');
                if(this.body) { this.body.addCls('autohideheader'); }
                if(this.getEl().shadow && this.getEl().shadow.el) {
                    this.getEl().shadow.el.addCls('hidden');
                }
                this.getEl().setStyle('background-color', 'transparent');
                if(this.chart && this.chart.getEl()) {
                    this.chart.getEl().setStyle('background-color', 'transparent');
                }
                if(this.autohideHeaderOffset != undefined) {
                    this.getEl().setStyle('overflow', 'visible');
                    this.getHeader().getEl().dom.style.top = this.autohideHeaderOffset+'px';
                }
            }
        } else {
            this.cls     = '';
            this.bodyCls = '';
            this.shadow = 'sides';
            if(this.rendered) {
                this.removeCls('autohideheader');
                this.body.removeCls('autohideheader');
                if(this.getEl().shadow && this.getEl().shadow.el) {
                    this.getEl().shadow.el.removeCls('hidden');
                }
                this.getEl().setStyle('background-color', '');
                if(this.chart && this.chart.getEl()) {
                    this.chart.getEl().setStyle('background-color', '#FFFFFF');
                }
                if(this.autohideHeaderOffset != undefined) {
                    this.getEl().setStyle('overflow', '');
                }
            }
        }
        if(!this.header) { return; }
        var global = Ext.getCmp(this.panel_id);
        if(global.xdata.autohideheader === 1 || this.xdata.showborder == false) {
            this.header.hide();
        }
        if(this.xdata.showborder == true && global.xdata.autohideheader === 0) {
            this.header.show();
        }
        if(this.xdata.showborder == true && global.xdata.autohideheader === 1) {
            var panel = this;
            window.setTimeout(Ext.bind(function() {
                if(panel.header) { panel.header.hide(); }
            }, panel, []), 100);
        }
    },
    /* add item to settings form */
    addGearItems: function(items) {
        var panel = this;
        if(!panel.gearItemsExtra) {
            panel.gearItemsExtra = [];
        }
        if(Ext.isArray(items)) {
            Ext.each(items, function(i) {
                panel.gearItemsExtra.push(i);
            });
        } else {
            panel.gearItemsExtra.push(items);
        }
    },
    /* override to set settings items */
    setGearItems: function() {
    },
    /* schedules shadow refresh */
    syncShadowTimeout: function(delay) {
        var win = this;
        if(delay == undefined) { delay = 100; }
        if(win.xdata.showborder == false) {
            TP.timeouts['timeout_'+win.id+'_remove_shadow'] = window.setTimeout(Ext.bind(function() {
                if(win.getEl().shadow && win.getEl().shadow.el) {
                    win.getEl().shadow.el.addCls('hidden');
                }
            }, win, []), delay);
        }
    },
    /* enable / disable editing of this panlet */
    setLock: function(val) {
        if(this.locked != val) {
            this.redrawPanlet();
        }
    },
    /* destroys and redraws everything */
    redrawPanlet: function() {
        var tab = Ext.getCmp(this.panel_id);
        this.saveState();
        this.redraw = true;
        this.destroy();
        TP.add_panlet({id:this.id, skip_state:true, tb:tab, autoshow:true}, false);
    }
});

/* creates the panlets settings panel */
Ext.define('TP.PanletGearItem', {
    extend: 'Ext.panel.Panel',

    layout: 'fit',
    border: 0,
    listeners: {
        afterrender: function(This, eOpts) {
            var panel = this.up('window');
            var tab   = Ext.getCmp(panel.panel_id);
            // settings panel is somehow hidden below header
            if(tab.xdata.autohideheader === 1 || panel.xdata.showborder == false) {
                This.body.dom.style.marginTop = '17px';
            } else {
                This.body.dom.style.marginTop = '';
            }
            window.setTimeout(function() {
                panel.header.show();
                panel.showHeader();
            }, 100);
        }
    },
    items: [{
            xtype:           'form',
            bodyPadding:     2,
            border:          0,
            bodyStyle:       'overflow-y: auto;',
            submitEmptyText: false,
            defaults: {
                anchor: '-12'
            },
            items: [{
                fieldLabel: 'Title',
                xtype:      'textfield',
                name:       'title',
                id:         'title_textfield'
            }, {
                xtype:      'tp_slider',
                fieldLabel: 'Refresh Rate',
                formConf: {
                    value:      60,
                    nameS:      'refresh',
                    nameL:      'refresh_txt'
                }
            }, {
                fieldLabel: 'Backends / Sites',
                xtype:      'combobox',
                emptyText : 'inherited from dashboard',
                name:       'backends',
                multiSelect: true,
                queryMode:  'local',
                valueField: 'name',
                displayField: 'value',
                editable:   false,
                triggerAction: 'all',
                store:      { fields: ['name', 'value'], data: [] },
                listConfig : {
                    getInnerTpl: function(displayField) {
                        return '<div class="x-combo-list-item"><img src="' + Ext.BLANK_IMAGE_URL + '" class="chkCombo-default-icon chkCombo" /> {'+displayField+'} <\/div>';
                    }
                }
            }]
    }],
    buttonAlign: 'center',
    fbar: [/* panlet setting cancel button */
           { xtype:  'button',
             text:   'cancel',
             handler: function() { this.up('window').gearHandler() }
           },
           /* panlet setting save button */
           { xtype : 'button',
             text:   'save',
             handler: function() {
                var win      = this.up('window');
                win.stateful = true;
                var form     = win.gearitem.down('form').getForm();
                if(form.isValid()) {
                    win.xdata = TP.storeFormToData(form, win.xdata);
                    TP.log('['+this.id+'] panlet config updated: '+Ext.JSON.encode(win.xdata));
                    win.setTitle(win.xdata.title);
                    win.startTimeouts();
                    win.saveState();
                    if(win.formUpdatedCallback) {
                        win.formUpdatedCallback(win);
                    }
                    win.manualRefresh();
                    win.syncShadowTimeout();
                    win.gearHandler();
                }
             }
           }
    ]
});

/* called when user clicks on the gear icon in panlet header */
TP.panletGearHandler = function(panel) {
    if(panel == undefined) { panel = this; }
    if(panel.locked) { return; }
    var tab = Ext.getCmp(panel.panel_id);
    if(panel.gearitem == undefined) {
        // show settings
        panel.add(Ext.create('TP.PanletGearItem', {}));
        panel.gearitem = panel.items.getAt(panel.items.length-1);
        if(!panel.gearItemsExtra) {
            panel.setGearItems();
        }
        if(panel.gearItemsExtra) {
            panel.gearitem.down('form').add(panel.gearItemsExtra);
        }
        if(panel.hideSettingsForm) {
            TP.hideFormElements(panel.gearitem.down('form').getForm(), panel.hideSettingsForm);
        }

        /* set initial form values */
        panel.setFormDefaults();
        panel.stateful = false;
        // hide main content if already rendered
        if(panel.items.getAt(0) != panel.gearitem) {
            panel.items.getAt(0).hide();
        }

        // add current available backends
        var backendItem = TP.getFormField(panel.gearitem.down('form'), 'backends');
        TP.updateArrayStoreKV(backendItem.store, TP.getAvailableBackendsTab(tab));
        if(backendItem.store.count() <= 1) { backendItem.hide(); }

        panel.gearitem.down('form').getForm().reset();
        if(panel.has_search_button != undefined) {
            // make filter show the same value as the main filter button
            var form = panel.gearitem.down('form').getForm();
            form.setValues({filter: panel.xdata.filter});
        }
        if(panel.gearInitCallback) {
            panel.gearInitCallback(panel);
        }
        panel.origSize = panel.getSize();
        if(panel.origSize.width < panel.minSettingsWidth || panel.origSize.height < panel.minSettingsHeight) {
            panel.setSize(Ext.Array.max([panel.minSettingsWidth, panel.origSize.width]),
                         Ext.Array.max([panel.minSettingsHeight, panel.origSize.height])
                        );
        }
        panel.applyBorderAndBackground();
        panel.addCls('gearopen');
        panel.showHeader(tab);
        // move to front
        panel.el.dom.style.zIndex = 1000;
    } else {
        // hide settings
        panel.remove(panel.gearitem);
        panel.gearitem.destroy();
        delete panel.gearItemsExtra;
        panel.removeCls('gearopen');
        panel.removeCls('autohideheaderover');
        delete panel.gearitem;
        if(panel.origSize != undefined) {
            panel.setSize(panel.origSize);
            delete panel.origSize;
        }
        panel.stateful = true;
        panel.applyBorderAndBackground();
        if(panel.items.getAt(0)) {
            panel.items.getAt(0).show();
        }
        panel.hideHeader(tab);
        panel.syncShadowTimeout();
        // move back
        panel.el.dom.style.zIndex = panel.style.zIndex || 50;
    }
}
