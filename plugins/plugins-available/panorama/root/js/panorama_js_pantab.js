Ext.define('TP.Pantab', {
    extend: 'Ext.panel.Panel',

    tooltip:     (readonly || dashboard_ignore_changes) ? undefined : 'double click to open settings',
    closable:    (readonly || dashboard_ignore_changes) ? false : true,
    bodyCls:     'pantabbody',
    border:      false,
    stateful:    true,
    stateEvents: ['add', 'titlechange'],
    autoRender:  true,
    autoShow:    false,
    locked:      start_unlocked, // lock it by default
    initComponent: function() {
        if(this.xdata == undefined) {
            this.xdata = {};
        } else {
            this.xdata = TP.clone(this.xdata);
        }

        TP.allDashboards[this.id] = this;
        // defaults are set in panorama.pm

        // fetch window ids from ExtState
        this.window_ids = [];
        for(var key in ExtState) {
            var matches = key.match(/^(pantab_\d+)_panlet_(\d+)$/);
            if(matches && matches[1] == this.id) {
                this.window_ids.push(key);
            }
        }

        // contains the currently active backends
        this.activeBackends = undefined;
        this.callParent();
    },
    listeners: {
        beforedestroy: function( This, eOpts ) {
            This.destroying = true;
        },
        destroy: function( This, eOpts ) {
            TP.log('['+This.id+'] destroy');
            This.stopTimeouts();
            if(!This.redraw) {
                This.destroyPanlets();
                TP.cp.clear(This.id);
                delete TP.allDashboards[This.id];
            }
            if(This.bgDragEl) { This.bgDragEl.destroy(); }
            if(This.bgImgEl)  { This.bgImgEl.destroy();  }
            if(This.mapEl)    { This.mapEl.destroy();    }
            if(This.map)      { This.map.destroy();      }
            if(This.maintEl)  { This.maintEl.destroy();  }
            if(This.maintenanceMask) { This.maintenanceMask.destroy(); }
            if(TP.initialized) {
                // remove ?maps= from url
                TP.cleanPanoramUrl();
            }
            if(!This.redraw) {
                TP.reduceDelayEvents(TP, function() {
                    TP.closeAllHiddenDashboards();
                }, 3000, 'timeout_close_hidden_dashboards', true);
            }
            delete This.redraw;
        },
        beforeactivate: function( This, eOpts ) {
            /* must be done before active, otherwise map zoom control flicker */
            TP.suppressIconTip = true;
            if(This.locked) {
                TP.suppressIconTip = false;
                This.disableMapControls();
            }
            This.setBaseHtmlClass(true);
            /* scroll to top, otherwise geomap icons would be at wrong position */
            try {
                document.documentElement.scrollIntoView();
            } catch(e) {
                TP.Msg.msg("fail_message~~scroll failed: "+e);
            }
            This.setUserStyles();
            return(true);
        },
        activate: function(This, eOpts) {
            /* close start page */
            var startPage = Ext.getCmp('pantab_0');
            if(startPage && startPage.id != This.id) {
                try {
                    startPage.destroy();
                } catch(err) {
                    TP.logError(This.id, "startPageCloseException", err);
                }
            }
            // close map controls from previous tab
            if(TP.initial_active_tab && TP.initial_active_tab != This.id) {
                var prevTab = Ext.getCmp(TP.initial_active_tab);
                if(prevTab && prevTab.disableMapControls) {
                    prevTab.disableMapControls();
                }
            }

            /* close tooltip */
            if(TP.iconTip) { TP.iconTip.hide() }

            TP.resetMoveIcons();
            var delay = 0;
            var missingPanlets = 0;
            for(var nr=0; nr<This.window_ids.length; nr++) {
                if(This.destroying) { return; }
                var panlet_nr = This.window_ids[nr];
                var panlet    = Ext.getCmp(panlet_nr);
                if(panlet) { // may not yet exists due to delayed rendering
                    try {    // so allow it to fail
                        if(panlet.rendered == false) {
                            /* delay initial show when its not yet rendered */
                            window.setTimeout(Ext.bind(TP.showPanletById, This, [This, panlet.id]), delay);
                            delay = delay + 25;
                        } else {
                            panlet.show(false);
                        }
                    } catch(err) {
                        TP.logError(panlet.id, "panelActivateException", err);
                    }
                }
                else { missingPanlets++ }
            }
            var tabbar = Ext.getCmp('tabbar');
            if(delay > 0) {
                // make sure we hide all panlets if the user meanwhile changed tab again
                TP.timeouts['timeout_'+this.id+'_check_panel_show'] = window.setTimeout(function() {
                    if(!This.isActiveTab()) {
                        // hide all except the active one
                        tabbar.checkPanletVisibility(tabbar.getActiveTab());
                    }
                }, delay + 100);
            }

            /* disable add button */
            if(Ext.getCmp('tabbar_addbtn')) {
                if(This.xdata.locked) {
                    Ext.getCmp('tabbar_addbtn').setDisabled(true).setIconCls('lock-tab');
                } else {
                    Ext.getCmp('tabbar_addbtn').setDisabled(false).setIconCls('gear-tab');
                }
            }

            // refresh icons
            if(TP.initialized) {
                if(delay > 0) {
                    window.setTimeout(Ext.bind(TP.updateAllIcons, This, [This]), delay + 100);
                } else {
                    TP.updateAllIcons(This);
                }
            }
            if(This.bgDragEl) { This.bgDragEl.show(); }
            if(This.maintEl)  { This.maintEl.show();  }
            if(This.bgImgEl)  { This.bgImgEl.show();  }
            if(This.mapEl)    { This.mapEl.show();    }
            if(This.map)      { This.map.controlsDiv.dom.style.display = ""; }
            This.setBackground(This.xdata);
            if(TP.initialized && missingPanlets > 0) {
                TP.initial_create_delay_active = 0;
                This.createInitialPanlets(0, true);
            }
            This.moveMapIcons(true);
            /* scroll to top, otherwise geomap icons would be at wrong position */
            try {
                document.documentElement.scrollIntoView();
            } catch(e) {
                TP.Msg.msg("fail_message~~scroll failed: "+e);
            }
            /* set id from active tab, otherwise adding new background tabs might become visible (they set autoshow if this id matches) */
            TP.initial_active_tab = This.id;

            if(!This.title) {
                This.applyXdata();
            }
        },
        hide: function(This, eOpts) {
            This.hidePanlets();
            if(This.bgDragEl) { This.bgDragEl.hide(); }
            if(This.maintEl)  { This.maintEl.hide();  }
            if(This.bgImgEl)  { This.bgImgEl.hide();  }
            if(This.mapEl)    { This.mapEl.hide();    }
            if(This.map)      { This.map.controlsDiv.dom.style.display = "none"; }
            if(This.bgDragEl) {
                This.bgDragEl.dom.style.backgroundImage  = "";
                This.bgDragEl.dom.style.backgroundRepeat = "";
            }
        },
        afterrender: function(This, eOpts) {
            var tab = This;
            TP.log('['+tab.id+'] added tab - refresh: '+tab.xdata.refresh);
            if(!tab.title) {
                tab.applyXdata();
            }
            This.el.on("contextmenu", function(evt) {
                This.contextmenu(evt);
            });
            This.el.on("click", This.tabBodyClick);
        },
        beforerender: function(This, eOpts) {
            for(var nr=0; nr<This.window_ids.length; nr++) {
                var panlet = Ext.getCmp(This.window_ids[nr]);
                if(panlet) {
                    panlet.hide();
                }
            }
        },
        resize: function(This, adjWidth, adjHeight, eOpts) {
            This.adjustTabHeaderOffset();
            This.size = This.getSize();
            if(This.map) {
                This.map.setSize(This.size);
                This.moveMapIcons();
                This.saveState();
                This.setZoomControl(); // zoom functionality gets lost when screen resizes
            }
        },
        beforestatesave: function( This, state, eOpts ) {
            if(This.locked) {
                return(false);
            }
            return(true);
        }
    },
    updateHeaderTooltip: function() {
        var tab    = this;
        var tabbar = Ext.getCmp('tabbar');
        if(!tabbar || !tabbar.getTabBar) { return; }
        var tabbarItems = tabbar.getTabBar().items.items;
        var tabhead;
        for(var x = 0; x < tabbarItems.length; x++) {
            if(tabbarItems[x].card && tabbarItems[x].card.id == tab.id) {
                tabhead = tabbarItems[x];
            }
        }

        var text = "double click to open settings (dashboard #"+tab.nr()+")";
        if(readonly || dashboard_ignore_changes) {
            text = "this is dashboard #"+tab.nr();
        }
        if(tabhead == undefined) {
            return;
        } else if(tabhead.rendered == false) {
            tabhead.addListener('afterrender', function(This, eOpts) {
                This.getEl().set({
                    'data-qtip': text
                });
            });
        } else {
            tabhead.getEl().set({
                'data-qtip': text
            });
        }
        return;
    },
    nr: function() {
        var tab = this;
        var nr  = tab.id.replace(/^pantab_/, '');
        return(nr);
    },
    tabBodyClick: function(evt) {
        if(!TP.skipResetMoveIcons) {
            TP.resetMoveIcons();
        }
        TP.skipResetMoveIcons = false;
    },
    setBaseHtmlClass: function(hidescroll) {
        var This = this;
        if(!This.isActiveTab()) { return; }
        var htmlRootEl = Ext.fly(Ext.getBody().dom.parentNode);
        if(This.mapEl) {
            htmlRootEl.addCls('geomap');
            htmlRootEl.removeCls('hidescroll');
        } else {
            htmlRootEl.removeCls('geomap');
            if(hidescroll) {
                TP.setBaseHTMLScroll();
            }
        }
    },
    forceSaveState: function() {
        var oldLocked = this.locked;
        this.locked   = false;
        this.saveState();
        this.locked   = oldLocked;
    },
    getState: function() {
        var state = {
            xdata: TP.clone(this.xdata)
        };
        delete state.xdata.locked;
        delete state.xdata.refresh_txt;
        delete state.xdata.map_choose;
        if(state.xdata.state_order.join(',') == default_state_order.join(',')) {
            delete state.xdata.state_order;
        }
        return state;
    },
    saveIconsStates: function() {
        var tab = this;
        window.clearTimeout(TP.timeouts['timeout_' + tab.id + '_saveIconsStates']);
        TP.timeouts['timeout_' + tab.id + '_saveIconsStates'] = window.setTimeout(function() {
            tab.saveIconsStatesDo();
        }, 500);
    },
    saveIconsStatesDo: function() {
        var tab       = this;
        var panels    = TP.getAllPanel(tab);
        var allStates = {};
        var found     = 0;
        for(var nr=0; nr<panels.length; nr++) {
            var panel = panels[nr];
            var saveData = {};
            if(panel.xdata && panel.xdata.state != undefined) {
                saveData.state = panel.xdata.state;
                found++;
            }
            if(panel.xdata && panel.xdata.stateHist != undefined) {
                saveData.stateHist = panel.xdata.stateHist;
                found++;
            }
            if(panel.downtime || panel.acknowledged || panel.hostProblem) {
                saveData.stateDetails = {
                    downtime     : panel.downtime,
                    acknowledged : panel.acknowledged,
                    hostProblem  : panel.hostProblem
                };
                found++;
            }
            if(found) {
                allStates[panel.id] = saveData;
            }
        }
        if(found) {
            Ext.Ajax.request({
                url:     'panorama.cgi?task=dashboard_save_states',
                method:  'POST',
                params:  {
                    nr:     tab.id,
                    states: Ext.JSON.encode(allStates),
                    current_tab: tab.id
                },
                callback: function(options, success, response) {
                    if(!success) {
                        if(response.status == 0) {
                            TP.Msg.msg("fail_message~~saving dashboard states failed");
                        } else {
                            TP.Msg.msg("fail_message~~saving dashboard states failed: "+response.status+' - '+response.statusText);
                        }
                    } else {
                        TP.getResponse(undefined, response);
                    }
                }
            });
        }
    },
    moveMapIcons: function(movedOnly) {
        if(!this.map) { return; }
        var This = this;
        if(!This.isActiveTab()) { return; }
        var panels = TP.getAllPanel(This);
        for(var nr=0; nr<panels.length; nr++) {
            var panel = panels[nr];
            if(panel.xdata.layout && panel.xdata.layout.lon != undefined) {
                panel.moveToMapLonLat(movedOnly);
            }
        }
    },
    // moves all visible icons
    moveVisibleMapIcons: function() {
        if(!this.map) { return; }
        var This = this;
        if(!This.isActiveTab()) { return; }
        if(!This.visibleIcons) { return; }
        for(var nr=0; nr<This.visibleIcons.length; nr++) {
            var panel = This.visibleIcons[nr];
            panel.moveToMapLonLat();
        }
    },
    isActiveTab: function() {
        var tabbar    = Ext.getCmp('tabbar');
        var activeTab = tabbar.getActiveTab();
        if(activeTab && this.id == activeTab.id) { return(true); }
        return(false);
    },
    applyState: function(state) {
        this.callParent(arguments);
        this.applyXdata();
        if(state) {
            //TP.log('['+this.id+'] applyState: '+Ext.JSON.encode(state));
            /* create panlets */
            Ext.apply(this.xdata, state.xdata);
            this.createInitialPanlets();
        }
    },
    createInitialPanlets: function(retries, autoshow) {
        var tab = this;
        if(autoshow == undefined) { autoshow = false; }
        if(autoshow || (TP.initial_active_tab != undefined && tab.id == TP.initial_active_tab)) {
            autoshow = true;
        }
        if(retries == undefined) { retries=0; }
        if(retries > 1000) {
            var err = new Error;
            TP.logError(tab.id, "tooManyRetriesException", err);
            return;
        }
        // wait for the map in geomaps
        if(tab.rendered && autoshow && tab.xdata.map && (!tab.mapEl || !tab.map)) {
            window.setTimeout(Ext.bind(tab.createInitialPanlets, tab, [retries+1, autoshow]), 50);
            return;
        }

        var zIndexList = [];
        var state      = TP.cp.state;
        for(var nr=0; nr<tab.window_ids.length; nr++) {
            var id = tab.window_ids[nr];
            var zIndex = 0;
            if(state[id] != undefined
               && state[id].xdata
               && state[id].xdata.layout) {
                zIndex = state[id].xdata.layout.zindex || 0;
            }
            zIndex = Number(zIndex) + 100;
            if(zIndex < 0) {
                zIndex = 0;
            }
            if(zIndexList[zIndex] == undefined) { zIndexList[zIndex] = []; }
            zIndexList[zIndex].push(id);
        }
        Ext.Array.each(zIndexList, function(panels, id1) {
            if(panels != undefined) {
                Ext.Array.each(panels, function(panel_id, id2) {
                    // delayed panlet creation
                    var delay    = TP.initial_create_delay_inactive;
                    if(autoshow) {
                        delay    = TP.initial_create_delay_active;
                    }
                    if(!tab.rendered && !autoshow) {
                        TP.add_panlet({id:panel_id, skip_state:true, tb:tab, autoshow:autoshow}, false);
                    } else {
                        TP.timeouts['timeout_' + panel_id + '_render'] = window.setTimeout(Ext.bind(TP.add_panlet, tab, [{id:panel_id, skip_state:true, tb:tab, autoshow:autoshow}, false]), delay);

                        if(autoshow) {
                           TP.initial_create_delay_active   = TP.initial_create_delay_active   + 25;
                        } else {
                           TP.initial_create_delay_inactive = TP.initial_create_delay_inactive + 50;
                        }
                    }
                });
            }
        });

        if(one_tab_only || TP.num_panels == 0) {
            TP.timeouts['timeout_' + tab.id + '_starttimeouts'] = window.setTimeout(function() {
                TP.initComplete();
                tab.startTimeouts();
            }, TP.initial_create_delay_active);
        }
    },
    applyXdata: function(xdata, startTimeouts) {
        var This = this;
        if(xdata == undefined) {
            xdata = This.xdata;
        }
        if(This.readonly) {
            This.locked = true;
        }
        if(!This.xdata.state_order) {
            This.xdata.state_order = default_state_order;
        }
        if(!Ext.isArray(This.xdata.state_order)) {
            This.xdata.state_order = This.xdata.state_order.split(',');
        }

        // convert old binary autohideheader
        if(This.xdata.autohideheader === true)  { This.xdata.autohideheader = 1; }
        if(This.xdata.autohideheader === false) { This.xdata.autohideheader = 0; }

        xdata.locked = This.locked;

        This.applyMaintenance();

        if(This.hidden) { return; }

        This.setLock(xdata.locked);
        This.setTitle(xdata.title);
        if(!xdata.map) {
            if(This.mapEl) { This.mapEl.destroy(); This.mapEl = undefined; }
            if(This.map)   { This.map.destroy();   This.map   = undefined; }
        }
        This.setUserStyles();
        if(xdata.hide_tab_header && This.tab) {
            This.tab.hide();
        }
        This.setBaseHtmlClass();
        This.setBackground(xdata);
        if(startTimeouts != false) {
            if(TP.initialized) {
                This.startTimeouts();
            } else {
                This.setBaseHtmlClass(true);
                TP.timeouts['timeout_' + This.id + '_starttimeouts'] = window.setTimeout(Ext.bind(This.startTimeouts, This, []), 30000);
            }
        }

        var header = This.getDockedItems()[0];
        if(header) { header.hide() }

        if(This.xdata.hide_tab_header && This.tab) {
            This.tab.hide();
        }
        if(one_tab_only) {
            document.title = This.xdata.title;
        }
        This.updateHeaderTooltip();
    },

    hidePanlets: function() {
        var This = this;
        for(var nr=0; nr<This.window_ids.length; nr++) {
            var panlet = Ext.getCmp(This.window_ids[nr]);
            if(panlet) {
                panlet.hide(false);
            }
        }
    },

    destroyPanlets: function() {
        var This = this;
        var window_ids = TP.clone(This.window_ids);
        for(var nr=0; nr<window_ids.length; nr++) {
            var panel = Ext.getCmp(window_ids[nr]);
            if(panel) {
                panel.destroy();
            }
        }
    },

    /* start all timed actions for this tab and its panels */
    startTimeouts: function() {
        var tab = this;
        if(!tab.rendered) { return; }
        tab.stopTimeouts();
        TP.log('['+tab.id+'] startTimeouts');

        /* ensure panels from the active tab are displayed */
        if(!tab.isActiveTab()) {
            return;
        }
        if(tab.window_ids) {
            for(var nr=0; nr<tab.window_ids.length; nr++) {
                var panlet = Ext.getCmp(tab.window_ids[nr]);
                if(panlet) { // may not yet exists due to delayed rendering
                    try {    // so allow it to fail
                        panlet.show(false);
                    } catch(err) {
                        TP.logError(tab.id, "panelStarttimeoutException", err);
                    }
                }
            }
        }

        /* start refresh for all panlets with our refresh rate */
        var panels = TP.getAllPanel(tab);
        if(panels.length > 0) {
            // spread panel reload
            var delay    = 0;
            var interval = 60 / panels.length;
            for(var nr=0; nr<panels.length; nr++) {
                var p = panels[nr];
                if(p.startTimeouts) {
                    window.clearTimeout(TP.timeouts['timeout_' + p.id + '_delayed_start']);
                    TP.timeouts['timeout_' + p.id + '_delayed_start'] = window.setTimeout(Ext.bind(p.startTimeouts, p, []), delay);
                    delay = delay + Math.round(interval*1000);
                }
                if(p.header) {
                    if(tab.xdata.autohideheader === 1) { p.header.hide() }
                }
            }
        }
        if(tab.xdata && tab.xdata.refresh > 0) {
            TP.timeouts['interval_global_icons' + tab.id + '_refresh'] = window.setInterval(function() { TP.updateAllIcons(tab) }, tab.xdata.refresh * 1000);
            TP.updateAllIcons(tab);
        }

        if(TP.dashboardsSettingWindow) {
            TP.dashboardsSettingWindow.body.unmask();
        }
    },

    /* stop all timed actions for this tab and its panels */
    stopTimeouts: function() {
        TP.log('['+this.id+'] stopTimeouts');
        /* start refresh for all panlets with our refresh rate */
        var panels = TP.getAllPanel(this);
        for(var nr=0; nr<panels.length; nr++) {
            if(panels[nr].stopTimeouts) {
                panels[nr].stopTimeouts();
            }
        }

        window.clearInterval(TP.timeouts['interval_global_icons' + this.id + '_refresh']);
    },
    setBackground: function(xdata, retries) {
        var tab = this;
        var background = xdata.background,
            scale      = xdata.backgroundscale,
            offset_x   = xdata.backgroundoffset_x,
            offset_y   = xdata.backgroundoffset_y,
            size_x     = xdata.backgroundsize_x,
            size_y     = xdata.backgroundsize_y,
            bg_color   = xdata.background_color;
        if(retries == undefined) { retries = 0; }
        if(retries >= 10)        { return;      }
        var body = tab.body;
        if(body == undefined)    {
            window.setTimeout(Ext.bind(tab.setBackground, tab, [xdata, retries+1]), 50);
            return;
        }

        if(xdata.map) {
            if(tab.bgImgEl) { tab.bgImgEl.destroy(); tab.bgImgEl = undefined; }
            var size = tab.getSize();
            if(size.width < 5 || size.height < 5) {
                window.setTimeout(Ext.bind(tab.setBackground, tab, [xdata, retries+1]), 50);
                return;
            }

            /* remove chrome workaround */
            Ext.get('tabbar') && Ext.get('tabbar').dom.style.setProperty('z-index', "", "");

            /* get wms provider */
            var wmsData;
            wmsProvider.findBy(function(rec, id) {
                if(rec.data.name == xdata.wms_provider) {
                    wmsData = rec.data.provider;
                }
            });
            if(wmsData == undefined) {
                wmsData = wmsProvider.getAt(0).data.provider;
                TP.log('['+tab.id+'] fallback to default wms provider, "'+xdata.wms_provider+'" does not exist.');
                xdata.wms_provider = wmsProvider.getAt(0).data.name;
            }
            wmsData = anyDecode(wmsData);
            if(tab.mapEl && tab.mapEl.lastWMSProvider != xdata.wms_provider) {
                if(tab.mapEl) { tab.mapEl.destroy(); tab.mapEl = undefined; }
                if(tab.map)   { tab.map.destroy();   tab.map   = undefined; }
            }
            if(!tab.mapEl) {
                tab.mapEl = body.createChild('<div id="'+tab.id+'-osmmap" style="width: 100%; height: 100%;">', body.dom.childNodes[0]);
            }
            if(tab.mapEl.lastWMSProvider != undefined && tab.mapEl.lastWMSProvider == xdata.wms_provider) {
                if(!tab.mapEl.lastCenter || tab.mapEl.lastCenter[0] != xdata.map.lon || tab.mapEl.lastCenter[1] != xdata.map.lat || tab.mapEl.lastCenter[2] != xdata.map.zoom) {
                    tab.map.map.setCenter([tab.xdata.map.lon, tab.xdata.map.lat], tab.xdata.map.zoom);
                    tab.mapEl.lastCenter = [tab.xdata.map.lon, tab.xdata.map.lat, tab.xdata.map.zoom];
                }
                return;
            }
            var attribution = wmsData[2];
            if(attribution == undefined) {
                var url = xdata.wms_provider.replace(/\ .*$/, '');
                attribution =  { "attribution": "&copy; "+url+"<br>Data &copy; OpenStreetMap <a href='http://www.openstreetmap.org/copyright/en' target='_blank'>contributors<a>" };
            }
            tab.mapEl.lastWMSProvider = xdata.wms_provider;
            OpenLayers.ImgPath               = url_prefix +'vendor/openlayer-2.13.1/images/';
            OpenLayers.IMAGE_RELOAD_ATTEMPTS = 5;
            var controlsBody = Ext.getBody();
            var controlsDiv  = controlsBody.createChild('<div style="position: absolute; z-index: 9000; top: 50px; left: 3px; display: none;">');
            var zoomDiv      = controlsDiv.createChild('<div style="position: absolute; z-index: 9000; top: 0; left: 0;">');
            var map   = new OpenLayers.Map('map', { controls: [], theme: url_prefix+'vendor/openlayer-2.13.1/theme/default/style.css' });
            var layer = new OpenLayers.Layer.WMS(xdata.wms_provider, wmsData[0], wmsData[1], attribution);
            map.addLayer(layer);
            map.addControl(new OpenLayers.Control.Navigation());
            var zoomControl = new OpenLayers.Control.PanZoomBar({panIcons: false, zoomWorldIcon: true, div: zoomDiv.dom})
            map.addControl(zoomControl);
            map.addControl(new OpenLayers.Control.Attribution());
            var mapData = {
                renderTo: tab.id+'-osmmap',
                map:      map,
                width:    size.width,
                height:   size.height,
                center:   ''+default_map_lon+','+default_map_lat,
                zoom:     default_map_zoom,
                stateful: true,
                style:    "position: absolute; top: 0px; left: 0px;",
                controlsDiv: controlsDiv,
                listeners: {
                    aftermapmove: function(This, map, eOpts) {
                        if(tab.map == undefined) {
                            /* otherwise not yet set when event fires first time */
                            tab.map = This;
                        }
                        var movedOnly = true;
                        var zoom      = map.getZoom();
                        if(This.map.lastZoomLevel != undefined && zoom != This.map.lastZoomLevel) {
                            movedOnly = false; /* recalculation required */
                        }

                        // if we recently switched from image to geo map or vice versa, we need to update coordinates
                        tab.fixIconsMapPosition(xdata);

                        This.map.lastZoomLevel = zoom;
                        tab.moveMapIcons(movedOnly);
                        tab.saveState();
                    },
                    destroy: function(This){
                        tab.zoomControl = null;
                        tab.zoomControlMap = null;
                        zoomControl.destroy();
                        zoomDiv.destroy();
                        controlsDiv.destroy();
                        tab.lockButton.destroy();
                        tab.lockButton = undefined;
                        tab.keyMap.destroy();
                        tab.keyMap = null;
                    }
                }
            };
            if(tab.xdata && tab.xdata.map && tab.xdata.map.lon != undefined) {
                mapData.zoom   = Number(tab.xdata.map.zoom);
                mapData.center = [Number(tab.xdata.map.lon), Number(tab.xdata.map.lat)];
            }
            tab.mapEl.lastCenter = [mapData.center[0], mapData.center[1], mapData.zoom];
            tab.map = Ext.create('GeoExt.panel.Map', mapData);
            map.events.register("move", map, function() {
                tab.moveVisibleMapIcons();
            });
            // if there are too many icons, hide them before moving the map to reduce lag
            map.events.register("movestart", map, function() {
                var panels = TP.getAllPanel(tab);
                var visible = [];
                for(var nr=0; nr<panels.length; nr++) {
                    var panel = panels[nr];
                    if(!panel.xdata.layout || panel.xdata.layout.lon == undefined || panel.isHidden()) {
                        continue;
                    }
                    visible.push(panel);
                }
                if(visible.length > 30) {
                    for(var nr=0; nr<visible.length; nr++) {
                        var panel = visible[nr];
                        panel.hide();
                    }
                    visible = [];
                }
                tab.visibleIcons = visible;
            });
            map.events.register("moveend", map, function() {
                tab.moveMapIcons();
            });
            map.events.register("zoomend", map, function() {
                tab.moveMapIcons();
            });
            controlsDiv.dom.style.display = "";
            tab.lockButton = controlsDiv.createChild('<div class="lockButton unlocked">', controlsDiv.dom.childNodes[0]);
            tab.lockButton.on("click", function(evt) {
                if(tab.lockButton.hasCls('unlocked')) {
                    tab.disableMapControls();
                } else {
                    tab.enableMapControls();
                }
            });
            /* create our own zoom controls, because they do not work when not using default div from map */
            tab.zoomControl    = zoomControl;
            tab.zoomControlMap = map;
            tab.setZoomControl();
            if(tab.xdata.map == undefined) {
                var data = map.getCenter();
                tab.xdata.map = {
                    lon:    data.lon,
                    lat:    data.lat,
                    zoom:   tab.map.map.getZoom()
                };
                tab.saveState();
            }
            // toggle map navigation on space
            tab.keyMap = new Ext.util.KeyMap({
                target: Ext.getBody(),
                key: Ext.EventObject.SPACE,
                fn: function(key, evt) {
                    if(!tab.map) { return; }
                    if(evt.target.tagName == "INPUT" || evt.target.tagName == "TEXTAREA") { return; }
                    if(tab.lockButton.hasCls('unlocked')) {
                        tab.disableMapControls();
                    } else {
                        tab.enableMapControls();
                    }
                }
            });
        } else {
            if(tab.mapEl) { tab.mapEl.destroy(); tab.mapEl = undefined; }
            if(tab.map)   { tab.map.destroy();   tab.map   = undefined; }
            /* add chrome workaround */
            Ext.get('tabbar') && Ext.get('tabbar').dom.style.setProperty('z-index', "21", "important");
        }
        tab.setBaseHtmlClass();

        if(!tab.bgDragEl) {
            var iconContainer = Ext.fly('iconContainer');
            tab.bgDragEl = iconContainer.createChild('<img>', iconContainer.dom.childNodes[0]);
            tab.bgDragEl.dom.style.position = "fixed";
            tab.bgDragEl.dom.style.width    = "100%";
            tab.bgDragEl.dom.style.height   = "100%";
            tab.bgDragEl.dom.style.top      = TP.offset_y+"px";
            tab.bgDragEl.dom.style.left     = "0px";
            tab.bgDragEl.dom.style.zIndex   = 21;
            tab.bgDragEl.dom.src            = url_prefix+"plugins/panorama/images/s.gif";
            tab.bgDragEl.on("contextmenu", function(evt) {
                tab.contextmenu(evt);
            });
            tab.bgDragEl.on("click", function(evt) {
                tab.tabBodyClick(evt);
            });
            if(!tab.isActiveTab()) {
                tab.bgDragEl.hide();
            }
        }
        tab.disableMapControls();

        if(background != undefined && background != 'none' && !xdata.map) {
            if(!tab.bgImgEl) {
                var iconContainer = Ext.fly('iconContainer');
                tab.bgImgEl  = iconContainer.createChild('<img>', iconContainer.dom.childNodes[0]);
                tab.bgImgEl.on('load',
                                function (evt, ele, opts) {
                                    tab.applyBackgroundSizeAndOffset(xdata, retries, background, scale, offset_x, offset_y, size_x, size_y);
                                },
                                undefined, {
                                    single: true    // remove event handler after first occurence
                                }
                );
            }
            tab.bgImgEl.dom.src            = background;
            tab.bgImgEl.dom.style.position = "absolute";
            tab.applyBackgroundSizeAndOffset(xdata, retries, background, scale, offset_x, offset_y, size_x, size_y);
            if(!tab.isActiveTab()) {
                tab.bgImgEl.hide();
            }
        } else {
            if(tab.bgImgEl) {
                tab.bgImgEl.destroy();
                tab.bgImgEl = undefined;
            }
        }
        if(bg_color != undefined && !xdata.map) {
            tab.el.dom.style.background = bg_color;
        } else {
            tab.el.dom.style.background = '';
        }

        var grid = Ext.getCmp('show_helper_grid');
        if(grid && grid.checked) {
            tab.bgDragEl.dom.style.backgroundImage  = "url("+url_prefix+'plugins/panorama/images/grid_helper.png'+")";
            tab.bgDragEl.dom.style.backgroundRepeat = "repeat";
        } else {
            tab.bgDragEl.dom.style.backgroundImage  = "";
            tab.bgDragEl.dom.style.backgroundRepeat = "";
        }

        // if we recently switched from image to geo map or vice versa, we need to update coordinates
        tab.fixIconsMapPosition(xdata);

        return;
    },
    setZoomControl: function() {
        var tab = this;
        var map = tab.zoomControlMap;
        if(!map || !tab.zoomControl) { return; }
        tab.zoomControl.buttons[0].onclick = function() { map.zoomIn() }
        tab.zoomControl.buttons[1].onclick = function() { map.zoomOut() }
        tab.zoomControl.buttons[2].onclick = function() { map.setCenter([tab.xdata.map.lon, tab.xdata.map.lat], tab.xdata.map.zoom) }
    },
    // set current position to each panel which does not have a lon/lat yet
    fixIconsMapPosition: function(xdata) {
        var tab = this;
        if(xdata == undefined) { xdata = tab.xdata; }
        if(!xdata.map) { return; }
        var panels = TP.getAllPanel(tab);
        for(var nr=0; nr<panels.length; nr++) {
            var panel = panels[nr];
            if(panel.el && panel.xdata.layout != undefined && (panel.xdata.layout.lon == undefined || panel.xdata.layout.lon == "")) {
                panel.updateMapLonLat();
            }
        }
    },
    applyBackgroundSizeAndOffset: function(xdata, retries, background, scale, offset_x, offset_y, size_x, size_y) {
        if(background.match(/s\.gif$/)) { return; }
        var tab = this;
        if(size_x != undefined && size_x > 0 && size_y != undefined && size_y > 0) {
            tab.bgImgEl.dom.style.width  = size_x+"px";
            tab.bgImgEl.dom.style.height = size_y+"px";
        }
        else if(scale == 100) {
            tab.bgImgEl.dom.style.width  = "";
            tab.bgImgEl.dom.style.height = "";
        } else {
            var naturalSize = TP.getNatural(background);
            if(naturalSize.width < 2 || naturalSize.height < 2) {
                window.setTimeout(Ext.bind(tab.setBackground, tab, [xdata, retries+1]), 50);
                return;
            }
            var width  = Number(scale * naturalSize.width  / 100);
            var height = Number(scale * naturalSize.height / 100);
            tab.bgImgEl.dom.style.width  = width+"px";
            tab.bgImgEl.dom.style.height = height+"px";
        }
        tab.bgImgEl.dom.style.top  = (25+offset_y)+"px";
        tab.bgImgEl.dom.style.left = offset_x+"px";
    },
    disableMapControlsTemp: function() {
        if(!this.mapEl) { return; }
        var tab = this;
        if(tab.map == undefined || tab.map.map == undefined) { return; }
        if(tab.map.locked) { return; }
        tab.bgDragEl.dom.style.display="";
    },
    enableMapControlsTemp: function() {
        if(!this.mapEl) { return; }
        var tab = this;
        if(tab.map == undefined || tab.map.map == undefined) { return; }
        if(tab.map.locked) { return; }
        tab.bgDragEl.dom.style.display="none";
    },
    disableMapControls: function() {
        if(!this.mapEl) { return; }
        var tab = this;
        if(tab.map == undefined || tab.map.map == undefined) { return; }
        tab.bgDragEl.dom.style.display="";
        for(var x=1; x<tab.map.controlsDiv.dom.childNodes.length; x++) {
            var ctrl = tab.map.controlsDiv.dom.childNodes[x];
            ctrl.style.display="none";
        }
        if(tab.locked) {
            TP.suppressIconTip = false;
        }
        tab.map.locked = true;
        tab.lockButton.removeCls('unlocked');
        tab.lockButton.addCls('locked');
        var panels = TP.getAllPanel(this);
        for(var nr=0; nr<panels.length; nr++) {
            if(panels[nr].el) {
                panels[nr].el.dom.style.pointerEvents = "";
            }
        }
        tab.map.el.dom.style.display = "";
    },
    enableMapControls: function() {
        if(!this.mapEl) { return; }
        var tab = this;
        if(tab.map == undefined || tab.map.map == undefined) { return; }
        tab.bgDragEl.dom.style.display="none";
        for(var x=1; x<tab.map.controlsDiv.dom.childNodes.length; x++) {
            var ctrl = tab.map.controlsDiv.dom.childNodes[x];
            ctrl.style.display="";
        }
        tab.map.locked = false;
        tab.lockButton.removeCls('locked');
        tab.lockButton.addCls('unlocked');
        TP.suppressIconTip = true;
        var panels = TP.getAllPanel(this);
        for(var nr=0; nr<panels.length; nr++) {
            panels[nr].el.dom.style.pointerEvents = "none";
        }
        tab.map.el.setStyle("position: absolute; top: 0px; left: 0px;");
        tab.map.el.dom.style.zIndex = 1;
    },
    /* enable or disable locking for this tab and all panlet below */
    setLock: function(val) {
        var tab = this;
        var mask;
        var panels = TP.getAllPanel(tab);
        if(tab.locked != val && panels.length > 0) {
            tab.mask = Ext.getBody().mask((val ? "" : "un")+"locking dashboard...");
        }
        var changed = (tab.xdata.locked != val);
        tab.xdata.locked   = val;
        tab.locked         = val;
        TP.suppressIconTip = !val;

        /* disable add button */
        if(Ext.getCmp('tabbar_addbtn')) {
            if(tab.xdata.locked) {
                Ext.getCmp('tabbar_addbtn').setDisabled(true).setIconCls('lock-tab');
            } else {
                Ext.getCmp('tabbar_addbtn').setDisabled(false).setIconCls('gear-tab');
            }
        }

        /* apply to all widgets and panels */
        for(var nr=0; nr<panels.length; nr++) {
            panels[nr].setLock(val);
        }
        if(val && changed) {
            tab.disableMapControls();
        }
        /* schedule update, which also remove the mask from above */
        if(changed) { /* leads to double status update on inital page render */
            TP.updateAllIcons(tab);
        }
    },
    contextmenu: function(evt, hidePasteAndNew, showClose) {
        var tab = this;
        /* right click context menu on tab body */
        evt.preventDefault();
        TP.resetMoveIcons();
        tab.disableMapControlsTemp();
        var pos = [evt.getX(), evt.getY()];
        var nr = tab.nr();

        var menu_items = [];
        if(tab.xdata.locked) { hidePasteAndNew = true; }
        if(!readonly && !tab.readonly && !hidePasteAndNew) {
            menu_items = menu_items.concat([{
                    text:   'New',
                    icon:   url_prefix+'plugins/panorama/images/cog_add.png',
                    hideOnClick: false,
                    menu:    TP.addPanletsMenu({open: 'right'}),
                    disabled: tab.xdata.locked
                }]);
        }


        menu_items = menu_items.concat([{
                text:   'Refresh',
                icon:   url_prefix+'plugins/panorama/images/arrow_refresh.png',
                handler: function() { TP.refreshAllSitePanel(tab) }
            }, {
                text:   'Display',
                icon:   url_prefix+'plugins/panorama/images/picture_empty.png',
                hideOnClick: false,
                menu: [{
                    text:   'Fullscreen',
                    icon:   url_prefix+'plugins/panorama/images/picture_empty.png',
                    handler: function() {
                        var element = Ext.getBody().dom;
                        try {
                            BigScreen.request(element);
                        } catch(err) {
                            TP.logError(tab.id, "bigscreenException", err);
                        }
                    },
                    hidden:  !!BigScreen.element
                }, {
                    text:   'Exit Fullscreen',
                    icon:   url_prefix+'plugins/panorama/images/pictures.png',
                    handler: function() { BigScreen.exit(); },
                    hidden:  !BigScreen.element
                }, {
                    text:       'Open In Tabs Mode',
                    icon:       url_prefix+'plugins/panorama/images/application_put.png',
                    href:       'panorama.cgi?'+Ext.Object.toQueryString({maps: tab.xdata.title}),
                    tooltip:    'open this dashboard with tabs header toolbar.',
                    hidden:     !one_tab_only
                }, {
                    text:       'Direct Link (no tabs mode)',
                    icon:       url_prefix+'plugins/panorama/images/application_put.png',
                    href:       'panorama.cgi?'+Ext.Object.toQueryString({map: tab.xdata.title}),
                    hrefTarget: '_blank',
                    tooltip:    'open this dashboard in a new window without the tabs header toolbar.',
                    hidden:    !!one_tab_only
                }, {
                    text:       'Direct Link (with tabs mode)',
                    icon:       url_prefix+'plugins/panorama/images/application_put.png',
                    href:       'panorama.cgi?'+Ext.Object.toQueryString({maps: tab.xdata.title}),
                    hrefTarget: '_blank',
                    tooltip:    'open this dashboard in a new window keeping the tabs header toolbar.',
                    hidden:    !!one_tab_only
                }, {
                    text:   'Debug Information',
                    icon:   url_prefix+'plugins/panorama/images/information.png',
                    handler: function() { thruk_debug_window_handler() },
                    hidden:  (!thruk_debug_js || thruk_demo_mode)
                }]
            }, {
                text:   'Set Maintenance Mode',
                icon:   url_prefix+'plugins/panorama/images/btn_downtime.png',
                hidden: readonly || tab.readonly || tab.isMaintenance(),
                handler: function() {
                    Ext.Msg.prompt('Put Dashboard into Maintenance Mode', 'Please enter maintenance message:', function(btn, text){
                        if (btn == 'ok'){
                            tab.setMaintenance(text, true);
                        }
                    }, null, true, (default_maintenance_text || 'this dashboard is currently in maintenance mode'));
                }
            }, {
                text:   'Remove Maintenance Mode',
                icon:   url_prefix+'plugins/panorama/images/btn_ack_remove.png',
                hidden: readonly || tab.readonly || !tab.isMaintenance(),
                handler: function() { tab.setMaintenance(null, true); }
            }, '-', {
                text:   'Save Dashboard',
                icon:    url_prefix+'plugins/panorama/images/disk.png',
                href:   'panorama.cgi?task=save_dashboard&nr='+tab.id
            }, {
                text:   'Load Dashboard',
                icon:    url_prefix+'plugins/panorama/images/folder_picture.png',
                handler: function() { TP.loadDashboardWindow() },
                hidden:  !!one_tab_only
        }]);
        if(!readonly && !tab.readonly) {
            menu_items = menu_items.concat([
                {
                    xtype: 'menuseparator',
                    hidden:  hidePasteAndNew
                }, {
                    text:   'Paste',
                    icon:   url_prefix+'plugins/panorama/images/page_paste.png',
                    handler: function() {
                        var tb = Ext.getCmp('tabbar').getActiveTab();
                        if(TP.clipboard.state && TP.clipboard.state.xdata && TP.clipboard.state.xdata.appearance) {
                            // workaround for not existing gradient after copy&paste
                            if(TP.clipboard.state.xdata.appearance.piegradient) {
                                TP.clipboard.state.xdata.appearance.piegradient = Number(TP.clipboard.state.xdata.appearance.piegradient) + 0.001;
                            }
                            if(TP.clipboard.state.xdata.appearance.shapegradient) {
                                TP.clipboard.state.xdata.appearance.shapegradient = Number(TP.clipboard.state.xdata.appearance.shapegradient) + 0.001;
                            }
                        }
                        pos[0] = pos[0] - 8;
                        pos[1] = pos[1] - 8;
                        TP.add_panlet_handler(evt, evt.target, [tb, TP.clone(TP.clipboard), undefined, undefined, pos]);
                    },
                    disabled: (tab.xdata.locked || TP.clipboard == undefined),
                    hidden:  hidePasteAndNew
                }, '-', {
                    text:    'Set Map Center',
                    icon:    url_prefix+'plugins/panorama/images/flag_blue.png',
                    handler:  function() {
                        var data = tab.map.map.getCenter();
                        tab.xdata.map = {
                            lon:    data.lon,
                            lat:    data.lat,
                            zoom:   tab.map.map.getZoom()
                        };
                        tab.saveState();
                        TP.Msg.msg("success_message~~new map center set successfully.");
                    },
                    disabled: tab.xdata.locked,     // disable if locked
                    hidden:   tab.map == undefined  // only show on maps
                }, {
                    text:   'Dashboard Settings',
                    icon:   url_prefix+'plugins/panorama/images/cog.png',
                    handler: function() { TP.tabSettingsWindow() },
                    hidden:  tab.xdata.locked       // only show when not locked
                }, {
                    text:   'Restore',
                    icon:   url_prefix+'plugins/panorama/images/book_previous.png',
                    id:     'manualmenu',
                    menu: [{
                        text:    'Create Restorepoint',
                        icon:    url_prefix+'plugins/panorama/images/disk.png',
                        handler: function() { TP.createRestorePoint(tab, "m") }
                    }, '-', {
                        text:       'Autosave',
                        hideOnClick: false,
                        id:         'autosavemenu',
                        icon:       url_prefix+'plugins/panorama/images/shield.png',
                        menu:        [],
                        listeners: {
                            afterrender: function(item, eOpts) {
                                TP.setRestorePointsMenuItems(tab);
                            }
                        }
                    }, {
                        text:    'Loading...',
                        icon:    url_prefix+'plugins/panorama/images/loading-icon.gif',
                        disabled: true,
                        id:      'restorepointsloading'
                    }],
                    hidden:  tab.xdata.locked       // only show when not locked
                }, {
                    text:   'Close Dashboard',
                    icon:   url_prefix+'plugins/panorama/images/door_in.png',
                    handler: function() { tab.close(); },
                    hidden:  !showClose
                }, {
                    text:   'Unlock Dashboard',
                    icon:   url_prefix+'plugins/panorama/images/lock_open.png',
                    handler: function() { TP.createRestorePoint(tab, "a"); tab.setLock(false); },
                    hidden:  !tab.xdata.locked      // only show when locked
                }, {
                    text:   'Lock Dashboard',
                    icon:   url_prefix+'plugins/panorama/images/lock.png',
                    handler: function() { tab.setLock(true); },
                    hidden:  tab.xdata.locked       // only show when not locked
            }]);
        }

        Ext.create('Ext.menu.Menu', {
            margin: '0 0 10 0',
            items:   menu_items,
            listeners: {
                beforehide: function(menu, eOpts) {
                    menu.destroy();
                    tab.enableMapControlsTemp();
                }
            }
        }).showAt(pos);
    },
    adjustTabHeaderOffset: function() {
        if(!one_tab_only) { return; }
        var tab = this;
        var body = Ext.getBody();
        /* required for showing the background */
        tab.setSize(body.getSize());
        /* required due to missing tabbar */
        var iconContainer = Ext.fly('iconContainer');
        iconContainer.dom.style.top      = "-25px";
        iconContainer.dom.style.position = "absolute";
    },
    scheduleRedrawAllLabels: function() {
        var This = this;
        for(var nr=0; nr<This.window_ids.length; nr++) {
            var panlet = Ext.getCmp(This.window_ids[nr]);
            if(panlet && panlet.setIconLabel) {
                panlet.setIconLabel();
            }
        }
    },
    setUserStyles: function(value) {
        var tab = this;
        if(value == undefined) {
            value = tab.xdata.user_styles;
        }
        if(value == undefined) {
            value = '';
        }
        var style = document.getElementById('user_styles');
        if(!style) {
            style      = document.createElement('style');
            style.type = 'text/css';
            style.id   = 'user_styles';
            document.getElementsByTagName('head')[0].appendChild(style);
        }
        style.innerHTML = value;
    },
    // zoom and pad a geomap so all icon from list are visible
    zoomIntoView: function(list) {
        var tab = this;
        if(!tab || tab.map == undefined || tab.map.map == undefined) { return; }
        if(!list || list.length == 0) { return; }
        var bounds = new OpenLayers.Bounds();
        for(var x = 0; x<list.length; x++) {
            var panel = list[x];
            bounds.extend(panel.getMapBounds());
        }
        tab.map.map.zoomToExtent(bounds);
        if(bounds.getHeight() == 0) {
            tab.map.map.zoomTo(17);
        }
    },

    showLoadMask: function() {
        if(this.window_ids.length  == 0) { return; }
        TP.initial_create_delay_active   = 0;
        TP.initial_create_delay_inactive = 0;
        TP.cur_panels                    = 1;
        TP.num_panels                    = this.window_ids.length;
        TP.initMask = new Ext.LoadMask(Ext.getBody(), {msg:"loading panel "+TP.cur_panels+'/'+TP.num_panels+"..."});
        TP.initMask.show();
    },

    // returns all dashboard ids from dashboard icons
    getAllSubDashboards: function(recursive, dashboards) {
        var tab = this;
        if(dashboards == undefined) { dashboards = {} };
        var panels = TP.getAllPanel(tab);
        for(var nr=0; nr<panels.length; nr++) {
            var p = panels[nr];
            if(p.xdata && p.xdata.general) {
                if(p.xdata.general.dashboard) {
                    var subtab_id = TP.nr2TabId(p.xdata.general.dashboard);
                    if(dashboards[subtab_id]) { continue; }
                    dashboards[subtab_id] = true;
                    if(recursive) {
                        var subtab = Ext.getCmp(subtab_id);
                        if(subtab) {
                            subtab.getAllSubDashboards(true, dashboards);
                        }
                    }
                }
            }
        }
        return(Object.keys(dashboards));
    },

    isMaintenance: function() {
        if(this.maintenance) {
            return true;
        }
        return false;
    },
    setMaintenance: function(text, save) {
        var tab = this;
        if(text) {
            tab.maintenance = text;
            if(save) {
                Ext.Ajax.request({
                    url:     '../r/thruk/panorama/'+tab.nr()+'/maintenance',
                    method:  'POST',
                    params: {
                        text:      text,
                        CSRFtoken: CSRFtoken
                    },
                    callback: TP.defaultHTTPCallback
                });
            }
        } else {
            delete tab.maintenance;
            if(save) {
                Ext.Ajax.request({
                    url:     '../r/thruk/panorama/'+tab.nr()+'/maintenance',
                    method:  'DELETE',
                    params: {
                        CSRFtoken: CSRFtoken
                    },
                    callback: TP.defaultHTTPCallback
                });
            }
        }
        tab.applyMaintenance();
        return;
    },
    applyMaintenance: function() {
        var tab = this;
        var text = tab.maintenance;
        if(text) {
            if(!readonly && !tab.readonly) {
                text += '<center><a href="#" class="show" onclick="Ext.getCmp(\''+tab.id+'\').maintEl.hide(); return false;">show anyway<\/a><\/center>';
            }
            if(!tab.maintEl) {
                var iconContainer = Ext.fly('iconContainer');
                tab.maintEl = iconContainer.createChild('<div>', iconContainer.dom.childNodes[0]);
                tab.maintEl.dom.style.position = "fixed";
                tab.maintEl.dom.style.top      = TP.offset_y+"px";
                tab.maintEl.dom.style.left     = "0px";
                tab.maintEl.dom.style.width    = "100%";
                tab.maintEl.dom.style.height   = "100%";
                tab.maintEl.dom.style.zIndex   = 9001;
                tab.maintenanceMask = new Ext.LoadMask(tab.maintEl, {msg:text, maskCls: 'maintenance', msgCls: 'maintenance'});
                if(tab.isActiveTab()) {
                    tab.maintEl.show();
                    tab.maintenanceMask.show();
                    tab.maintenanceMask.ownerCt.getCache().data.maskEl.el.addCls("maintenance");
                    tab.maintEl.dom.style.display  = "";
                } else {
                    tab.maintEl.hide();
                }
                tab.maintEl.on("contextmenu", function(evt) {
                    tab.contextmenu(evt);
                });
            } else {
                tab.maintenanceMask.msg = text;
                if(tab.isActiveTab()) {
                    tab.maintEl.show();
                    tab.maintenanceMask.show();
                    tab.maintenanceMask.ownerCt.getCache().data.maskEl.el.addCls("maintenance");
                } else {
                    tab.maintEl.hide();
                }
            }
        } else if(tab.maintenanceMask) {
            tab.maintenanceMask.destroy();
            delete tab.maintenanceMask;
            tab.maintEl.destroy();
            delete tab.maintEl;
        }
        return;
    }
});

Ext.onReady(function() {
    if(readonly) { return; }
    /* lasso for element selection */
    Ext.getBody().on("mouseup", function(evt) {
        if(TP.lassoEl) {
            TP.lassoEl.destroy();
            TP.lassoEl = undefined;
            Ext.getBody().removeListener("mousemove", TP.lassoDragHandler);
            TP.createIconMoveKeyNav();
            TP.skipResetMoveIcons = true;
            window.setTimeout(function() { TP.skipResetMoveIcons = false; }, 50);
        }
    });
    Ext.getBody().on("dragstart", function(evt) {
        evt.preventDefault();
        var tabbar = Ext.getCmp('tabbar');
        var tab    = tabbar.getActiveTab();
        if(tab.locked)            { return(false); };
        if(TP.iconSettingsWindow) { return(false); };
        var pos = evt.getXY();
        if(TP.lassoEl) { TP.lassoEl.destroy(); }
        TP.lassoEl = Ext.create('Ext.Component', {
            'html':     ' ',
            autoRender: true,
            autoShow:   true,
            shadow:     false,
            style: {
                position: 'absolute',
                border: '1px black dashed',
                top:     pos[1]+'px',
                left:    pos[0]+'px',
                width:   '1px',
                height:  '1px'
            }
        });
        TP.lassoEl.startPosition = pos;
        Ext.getBody().on("mousemove", TP.lassoDragHandler);
        return(false);
    });
});

/* handles dragging a lasso around icon elements to move them together */
TP.lassoDragHandler = function(evt) {
    evt.preventDefault();
    var mouse = evt.getXY();
    TP.reduceDelayEvents(TP.lassoEl, function() {
        TP.lassoDragHandlerDo(mouse);
    }, 50, 'timeout_icon_lasso');
}

TP.lassoDragHandlerDo = function(mouse) {
    /* set new lasso size */
    window.clearTimeout(TP.timeouts['timeout_icon_lasso']);
    if(!TP.lassoEl) { return; }
    var start = TP.lassoEl.startPosition;
    var x = mouse[0]-start[0];
    var y = mouse[1]-start[1];
    if(x < 0 && y < 0) {
        TP.lassoEl.setPosition(mouse[0], mouse[1]);
        x = -x;
        y = -y;
    }
    else if(x < 0) {
        TP.lassoEl.setPosition(mouse[0], start[1]);
        x = -x;
    }
    else if(y < 0) {
        TP.lassoEl.setPosition(start[0], mouse[1]);
        y = -y;
    }
    TP.lassoEl.setSize(x, y);

    TP.reduceDelayEvents(TP.lassoEl, function() {
        TP.lassoMarkIcons(x, y);
    }, 50, 'timeout_icon_mark_update');
}

TP.lassoMarkIcons = function(x, y) {
    /* check marked elements */
    window.clearTimeout(TP.timeouts['timeout_icon_mark_update']);
    if(!TP.lassoEl) { return; }
    var lassoPos = TP.lassoEl.getPosition();
    var tabbar = Ext.getCmp('tabbar');
    var tab    = tabbar.getActiveTab();
    var panels = TP.getAllPanel(tab);
    TP.moveIcons = [];
    var elements = [];
    for(var nr=0; nr<panels.length; nr++) {
        var panel = panels[nr];
        if(panel.xdata.layout) { // only icons
            if(panel.xdata.appearance.type == "connector") {
                if(panel.dragEl1) { elements.push(panel.dragEl1); }
                if(panel.dragEl2) { elements.push(panel.dragEl2); }
            } else {
                elements.push(panel);
            }
        }
    }

    /* now check those elements */
    for(var nr=0; nr<elements.length; nr++) {
        var panel = elements[nr];
        var center = panel.getPosition();
        var size   = panel.getSize();
        center[0]  = center[0] + size.width/2;
        center[1]  = center[1] + size.height/2;
        if(center[0] > lassoPos[0] && center[1] > lassoPos[1] && center[0] < lassoPos[0] + x && center[1] < lassoPos[1] + y) {
            if(panel.iconType == "text") {
                panel.labelEl.el.dom.style.outline = "2px dotted orange";
            } else {
                panel.el.dom.style.outline = "2px dotted orange";
            }
            TP.moveIcons.push(panel);
        } else {
            panel.el.dom.style.outline = "";
        }
    }
}

/* restore dashboard to given timestamp */
TP.restoreDashboard = function(tab, timestamp, mode) {
    Ext.Msg.confirm('Reset to previous save point?', 'Do you really want to replace the current dashboard with the previous save version?', function(button) {
        if (button === 'yes') {
            Ext.Ajax.request({
                url:      'panorama.cgi?task=dashboard_restore&nr='+tab+'&timestamp='+timestamp+"&mode="+mode,
                method:  'POST',
                callback: function(options, success, response) {
                    if(!success) {
                        if(response.status == 0) {
                            TP.Msg.msg("fail_message~~restoring dashboard failed");
                        } else {
                            TP.Msg.msg("fail_message~~restoring dashboard failed: "+response.status+' - '+response.statusText);
                        }
                    } else {
                        TP.getResponse(undefined, response);
                        TP.Msg.msg("success_message~~restoring dashboard successful to "+strftime("%a %b %e %Y, %H:%M:%S", timestamp));
                    }
                }
            });
        }
    });
}


/* create restore point for dashboard */
TP.createRestorePoint = function(tab, mode) {
    Ext.Ajax.request({
        url:      'panorama.cgi?task=dashboard_restore_point&nr='+tab.id+"&mode="+mode,
        method:  'POST',
        callback: function(options, success, response) {
            if(!success) {
                if(response.status == 0) {
                    TP.Msg.msg("fail_message~~creating restore point failed");
                } else {
                    TP.Msg.msg("fail_message~~creating restore point failed: "+response.status+' - '+response.statusText);
                }
            } else {
                TP.getResponse(undefined, response);
                if(mode == "m") {
                    TP.Msg.msg("success_message~~created restore point successfully");
                }
            }
        }
    });
}

TP.setRestorePointsMenuItems = function(tab) {
    Ext.Ajax.request({
        url:      'panorama.cgi?task=dashboard_restore_list&nr='+tab.id,
        method:  'POST',
        callback: function(options, success, response) {
            if(!success) {
                if(response.status == 0) {
                    TP.Msg.msg("fail_message~~fetching dashboard restore points failed");
                } else {
                    TP.Msg.msg("fail_message~~fetching dashboard restore points failed: "+response.status+' - '+response.statusText);
                }
            } else {
                var data = TP.getResponse(undefined, response);
                if(!data || !data.data) { return }
                data = data.data;
                var autosavemenu  = Ext.getCmp("autosavemenu");
                if(autosavemenu == undefined || autosavemenu.menu == undefined) { return; } /* menu has been closed already */
                var manualmenu    = Ext.getCmp("manualmenu").menu;
                var restorepointsloading = Ext.getCmp("restorepointsloading");
                if(restorepointsloading) {
                    restorepointsloading.destroy();
                }
                var found = 0;
                for(var x=0; x<data.a.length; x++) {
                    found++;
                    autosavemenu.menu.add({text:    strftime("%a %b %e %Y, %H:%M:%S", data.a[x].num),
                              val:     data.a[x].num,
                              style:  'text-align: right;',
                              icon:   url_prefix+'plugins/panorama/images/clock_go.png',
                              handler: function() { TP.log('[global] restoring dashboard to: '+this.val); TP.restoreDashboard(tab.id, this.val, "a"); }
                            }
                    );
                }
                if(found == 0) {
                    autosavemenu.menu.add({text: 'none', disabled: true});
                }
                for(var x=0; x<data.m.length; x++) {
                    manualmenu.add({text:    strftime("%a %b %e %Y, %H:%M:%S", data.m[x].num),
                              val:     data.m[x].num,
                              style:  'text-align: right;',
                              icon:   url_prefix+'plugins/panorama/images/clock_go.png',
                              handler: function() { TP.log('[global] restoring dashboard to: '+this.val); TP.restoreDashboard(tab.id, this.val, "m"); }
                            }
                    );
                }
            }
        }
    })
}
