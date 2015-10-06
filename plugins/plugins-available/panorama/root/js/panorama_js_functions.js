/* send debug output to firebug console */
var debug = function(str) {}
if(thruk_debug_js != undefined && thruk_debug_js) {
    if(typeof window.console === "object" && window.console.debug) {
        /* overwrite debug function, so caller information is not replaced */
        debug = window.console.debug.bind(console);
    }
}

/* uppercase first char */
function ucfirst(str) {
    var firstLetter = str.slice(0,1);
    return firstLetter.toUpperCase() + str.substring(1);
}

/* global Thruk Panorama Object */
var TP = {
    snap_x:       20,
    snap_y:       20,
    offset_y:     one_tab_only ? 0 : 25,
    initialized:  false,
    timeouts:     {},
    num_panels:   0,
    cur_panels:   1,
    logHistory:   [],
    modalWindows: [],

    get_snap: function (x, y) {
        newx = Math.round(x/TP.snap_x) * TP.snap_x;
        newy = Math.round(y/TP.snap_y) * TP.snap_y + 5;
        if(newx < 0) { newx = 0; }
        if(newy < 0) { newy = 0; }
        if(newy < TP.offset_y) { newy = TP.offset_y; }
        return([newx, newy]);
    },

    add_pantab: function(id, replace_id, hidden, callback, extraConf) {
        var tabpan = Ext.getCmp('tabpan');

        if(TP.dashboardsSettingWindow) {
            TP.dashboardsSettingWindow.body.mask('loading...');
        }
        TP.checkModalWindows();

        if(one_tab_only) {
            if(replace_id && id != replace_id) {
                tabpan.getActiveTab().body.mask("loading");
            }
        }

        if(id == undefined) {
            TP.initialized = true;
            id = 'new_or_empty';
        }

        TP.log('[global] add_pantab: id:'+id+(replace_id ? ', replace_id: '+replace_id : ''));

        /* get tab data from server */
        var newDashboard = false;
        if(id && (id == "new" || id == "new_or_empty")) {
            newDashboard = true;
        }
        if(id && TP.cp.state[id] == undefined) {
            /* fetch state info and add new tab as callback */
            Ext.Ajax.request({
                url: 'panorama.cgi?task=dashboard_data',
                method: 'POST',
                params: { nr: id },
                async: false,
                callback: function(options, success, response) {
                    if(id != 'new') {
                        id = TP.nr2TabId(id);
                    }
                    if(!success) {
                        if(response.status == 0) {
                            TP.Msg.msg("fail_message~~adding new dashboard failed");
                        } else {
                            TP.Msg.msg("fail_message~~adding new dashboard failed: "+response.status+' - '+response.statusText);
                        }
                        tabpan.saveState();
                    } else {
                        var data = TP.getResponse(undefined, response);
                        data = data.data;
                        TP.log('['+id+'] dashboard_data: '+Ext.JSON.encode(data));
                        if(data.newid) { id = data.newid; delete data.newid; }
                        if(extraConf) {
                            var tmp = Ext.JSON.decode(data[id]);
                            Ext.apply(tmp.xdata, extraConf);
                            data[id] = Ext.JSON.encode(tmp);
                        }
                        for(var key in data) {
                            TP.cp.set(key, Ext.JSON.decode(data[key]));
                        }
                        if(TP.cp.state[id]) {
                            if(!hidden) {
                                TP.initial_active_tab = id; // set inital tab, so panlets will be shown
                            }
                            TP.add_pantab(id, replace_id, hidden);
                            if(TP.dashboardsSettingWindow && TP.dashboardsSettingGrid && TP.dashboardsSettingGrid.getView) {
                                TP.dashboardsSettingGrid.getView().refresh();
                            }
                            TP.checkModalWindows();
                        } else {
                            TP.Msg.msg("fail_message~~adding new dashboard failed, no such dashboard");
                            tabpan.saveState();
                        }
                    }

                    /* disable lock for new dashboard */
                    if(newDashboard) {
                        Ext.getCmp(id).locked = false;
                        Ext.getCmp(id).setLock(false);
                    }

                    if(callback) { callback(id); }
                }
            });
            return;
        }

        var size = tabpan.items.length;

        /* add new tab panel */
        if(hidden) {
            tabpan.add(new TP.Pantab({id: id}));
        } else {
            tabpan.add(new TP.Pantab({id: id})).show();
        }

        /* move new-tab button at the end */
        if(!one_tab_only) {
            tabpan.getTabBar().move(size-1, size);

            /* make tab title editable */
            if(!readonly && !dashboard_ignore_changes) {
                var tabhead = tabpan.getTabBar().items.getAt(size-1);
                if(tabhead.rendered == false) {
                    tabhead.addListener('afterrender', function(This, eOpts) {
                        TP.addTabBarMouseEvents(This.getEl(), id);
                    });
                } else {
                    TP.addTabBarMouseEvents(tabhead.getEl(), id);
                }
            }
        }

        /* replace existing tab with current one */
        if(replace_id) {
            if(one_tab_only) {
                if(id != replace_id) {
                    Ext.getCmp(replace_id).destroy();
                    if(history.replaceState) {
                        var tab    = tabpan.getActiveTab();
                        var newloc = new String(window.document.location);
                        newloc     = newloc.replace(/\?map=.*$/g, '');
                        newloc     = newloc + "?map="+tab.xdata.title;
                        history.replaceState({}, "", newloc);
                    }
                }
            } else {
                var replace_nr;
                var tabState = tabpan.getState();
                for(var x=0; x<tabState.open_tabs.length; x++) {
                    if(tabState.open_tabs[x] == replace_id) {
                        replace_nr = x+1;
                    }
                }
                if(replace_nr != undefined) {
                    tabpan.getTabBar().move(size-1, replace_nr);
                    if(id != replace_id) {
                        Ext.getCmp(replace_id).destroy();
                    }
                }
            }
            var tab = tabpan.getActiveTab();
            tab.adjustTabHeaderOffset();
        }

        /* save tabs state */
        Ext.getCmp('tabpan').saveState();

        /* any callbacks? */
        if(callback) { callback(id); }

        /* return false to prevent newtab button being activated */
        return false;
    },

    /* clone config from given panel which can be used to create a clone */
    clone_panel_config: function(panel) {
        var config = TP.clone(panel.getState());
        delete config.id;
        return(config);
    },

    /* add given panlet */
    add_panlet: function(config, smartPlacement) {
        if(readonly && TP.initialized) {
            return false;
        }
        if(config == undefined) {
            throw new Error("TP.add_panlet(): no config! (caller: " + (TP.add_panlet.caller ? TP.add_panlet.caller : 'unknown') + ")");
        }
        if(config.conf == undefined) {
            config.conf = {};
        }
        var pan = Ext.getCmp('tabpan');
        var tb;
        if(config.tb) {
            tb                   = config.tb;
            config.conf.autoShow = config.autoshow;
        } else {
            config.conf.autoShow = true;
            tb  = pan.getActiveTab();
            if(!tb) {
                tb = pan.setActiveTab(0);
            }
        }
        if(!tb) {
            throw new Error("TP.add_panlet(): no active tab! (caller: " + (TP.add_panlet.caller ? TP.add_panlet.caller : 'unknown') + ")");
        }

        /* do not add panlets twice */
        var testPanlet = Ext.getCmp(config.id);
        if(testPanlet) {
            if(config.conf.autoShow) {
                testPanlet.hide();
                testPanlet.show();
            }
            return;
        }

        config.conf.id = TP.getNextId(tb.id+"_panlet", config.id);
        var state = TP.cp.state;
        if(state[config.conf.id] != undefined
           && state[config.conf.id].xdata != undefined
           && state[config.conf.id].xdata.cls != undefined) {
            config.type = state[config.conf.id].xdata.cls;
        }
        if(config.type == undefined) {
            debug(config);
            var err  = new Error("no type!");
            var text = "";
            try {
                delete config['tb'];
                text = Ext.JSON.encode(config);
            } catch(err) {
                text = ""+err;
            }
            TP.logError("global", "noTypeException", err);
            TP.log("[global] "+text);
            throw err;
        }
        // fake state (probably cloned)
        if(config.state) {
            TP.cp.set(config.conf.id, config.state);
        }
        config.conf.panel_id = tb.id;
        TP.log('['+tb.id+'] add_panlet - type: '+config.type+', '+Ext.JSON.encode(config.conf));
        var win = Ext.create(config.type, config.conf);
        if(smartPlacement == undefined || smartPlacement == true) {
            pan.setActiveTab(tb); /* otherwise panel won't be rendered and panel size is 0 */
            if(config.conf.pos) {
                win.setRawPosition(config.conf.pos[0], config.conf.pos[1]);
            } else {
                TP.fitWindowPlacement(tb, win);
            }
        }
        if(!config.skip_state) {
            tb.window_ids.push(win.id);
            tb.saveState();
            win.firstRun = false;
        }
        // update initial panlet counter
        var tmp = Ext.dom.Query.select('.x-mask-loading DIV');
        if(tmp.length > 0) {
            tmp[0].innerHTML = "loading panel "+TP.cur_panels+'/'+TP.num_panels+"...";
            TP.cur_panels++;
        }
        return win;
    },

    /* choose position handler */
    add_panlet_handler: function(evt, element, args) {
        var tb = args[0], config = args[1], offsetX = args[2], offsetY = args[3], pos = args[4];
        tb.getEl().un('click', TP.add_panlet_handler, this, args); // remove event handler again
        tb.enableMapControlsTemp();
        if(config.conf == undefined) { config.conf = {}; }
        if(pos != undefined) {
            config.conf.pos = pos;
        } else {
            config.conf.pos = [evt.getX()+offsetX, evt.getY()+offsetY];
        }
        tb.getEl().dom.style.cursor = '';
        var panel = TP.add_panlet(config);
        panel.firstRun = true;
        if(panel.iconType) {
            TP.updateAllIcons(tb, panel.id);
        } else {
            panel.refreshHandler();
        }
        /* ensure the panel gets where it should be */
        window.setTimeout(function() {
            panel.setPosition(config.conf.pos[0], config.conf.pos[1]);
        }, 200);
    },

    /* add panel, but let the user choose position */
    add_panlet_delayed: function(config, offsetX, offsetY) {
        var tb;
        var pan = Ext.getCmp('tabpan');
        if(config.tb) {
            tb = config.tb;
        } else {
            tb = pan.getActiveTab();
            if(!tb) {
                tb = pan.setActiveTab(0);
            }
        }
        if(!tb) {
            throw new Error("TP.add_panlet(): no active tab! (caller: " + (TP.add_panlet.caller ? TP.add_panlet.caller : 'unknown') + ")");
        }
        tb.getEl().dom.style.cursor = 'crosshair';
        tb.getEl().on('click', TP.add_panlet_handler, tb, [tb, config, offsetX, offsetY]);
        window.setTimeout(function() {
            tb.disableMapControlsTemp();
        }, 100);
    },

    redraw_panlet: function(panel, tab) {
        window.clearTimeout(TP.timeouts['timeout_' + panel.id + '_redraw']);
        TP.timeouts['timeout_' + panel.id + '_redraw'] = window.setTimeout(function() {
            var firstRun = panel.firstRun;
            panel.redrawOnly = true;
            panel.destroy();
            panel = TP.add_panlet({id:panel.id, skip_state:true, tb:tab, autoshow:true}, false);
            panel.hide(); // workaround for not removed labels on text elements
            panel.show();
            panel.firstRun = firstRun;
            TP.updateAllIcons(Ext.getCmp(panel.panel_id));
        }, 50);
    },

    /* return next unused id */
    getNextId: function(prefix, id) {
        if(id != undefined) {
            return id;
        }
        var nr = 1;
        while(Ext.getCmp(prefix + "_" + nr) != undefined) {
            nr++;
        }
        return(prefix + "_" + nr);
    },

    /* remove item from an array */
    removeFromList: function(list, item) {
        var newlist = [];
        for(var key in list) {
            if(list[key] != item) {
                newlist.push(list[key]);
            }
        }
        return(newlist);
    },

    /* show about window */
    aboutWindow: function() {
        var win = new Ext.window.Window({
            autoShow:   true,
            modal:      true,
            title:      'About Thruks Panorama',
            buttonAlign: 'center',
            items: [{
                html: 'Thruk Panorama Dashboard<br><br>'
                     +'Copyright 2009-present Sven Nierlein, sven@consol.de<br>'
                     +'License: GPL v3<br>'
                     +'Version: '+thruk_version+(thruk_extra_version ? '<font size="-3">('+thruk_extra_version+')<\/font>' : '')
            }],
            fbar: [{
                text:'OK',
                handler: function() { this.up('window').destroy() }
            }]
        });
        TP.modalWindows.push(win);
    },

    /* get box coordinates for given object */
    getBox: function(obj) {
        var pos  = obj.getPosition();
        var size = obj.getSize();
        var box = {
            tl: { x:pos[0], y:pos[1] },
            tr: { x:pos[0]+size.width, y:pos[1] },
            bl: { x:pos[0], y:pos[1]+size.height },
            br: { x:pos[0]+size.width, y:pos[1]+size.height }
        };
        return box;
    },

    /* smart placement for new windows */
    fitWindowPlacement: function(tab, win) {
        var box     = TP.getBox(win);
        var tabsize = tab.getSize();

        /* get list of boxes */
        var boxes = [];
        if(tab.window_ids) {
            for(var nr=0; nr<tab.window_ids.length; nr++) {
                var id = tab.window_ids[nr];
                var w  = Ext.getCmp(id);
                if(id != win.id) {
                    boxes.push(TP.getBox(w));
                }
            };
        }

        /* get first place which fits */
        var x = 0;
        var y = TP.offset_y;
        while(TP.boxesOverlap(x, y, box, boxes)) {
            x = x + TP.snap_x;
            if(x+box.tr.x > tabsize.width) {
                x = 0;
                y = y + TP.snap_y;
            }
            if(y+box.bl.y > tabsize.height) {
                /* nothing matched, just placed at 0,0 */
                x = 0;
                y = TP.offset_y;
                break;
            }
        }
        win.setRawPosition(x, y);
    },
    /* returns true if any box ovelap */
    boxesOverlap: function(x, y, box, boxes) {
        var tmp_box = {
            tl: { x:x, y:y },
            tr: { x:x+(box.tr.x-box.tl.x), y:y },
            bl: { x:x, y:y+(box.br.y-box.tr.y) },
            br: { x:x+(box.tr.x-box.tl.x), y:y+(box.br.y-box.tr.y) }
        };

        for(var nr=0; nr<boxes.length; nr++) {
            var b = boxes[nr];
            /* check if these boxes overlap */
            if(TP.boxOverlap(tmp_box, b)) { return true; }
            if(TP.boxOverlap(b, tmp_box)) { return true; }
        }
        return false;
    },
    /* returns true if both boxes ovelap */
    boxOverlap: function(b1, b2) {
        if(b1.tl.x >= b2.tl.x && b1.tl.x < b2.tr.x && b1.tl.y >= b2.tl.y && b1.tl.y <  b2.bl.y) { return true; }
        if(b1.tr.x >  b2.tl.x && b1.tr.x < b2.tr.x && b1.tr.y >= b2.tl.y && b1.tr.y <  b2.bl.y) { return true; }
        if(b1.bl.x >= b2.tl.x && b1.bl.x < b2.tr.x && b1.bl.y >  b2.tl.y && b1.bl.y <= b2.bl.y) { return true; }
        if(b1.br.x >  b2.tl.x && b1.br.x < b2.tr.x && b1.br.y >  b2.tl.y && b1.br.y <= b2.bl.y) { return true; }
        return false;
    },
    /* hide element in given form */
    hideFormElements: function(form, list) {
        form.getFields().each(function(f, i) {
            for(var nr=0; nr<list.length; nr++) {
                if(f.name == list[nr]) { f.hide() }
            }
        });
    },
    /* refresh all site specific panlets */
    refreshAllSitePanel: function(tab) {
        var panels = TP.getAllPanel(tab);
        for(var nr=0; nr<panels.length; nr++) {
            var p = panels[nr];
            if(p.reloadOnSiteChanges != undefined && p.reloadOnSiteChanges == true && p.isVisible()) {
                p.refreshHandler();
            }
        }
        // refresh icons
        TP.updateAllIcons(tab);
    },
    refreshAllPanel: function(tab) {
        var panels = TP.getAllPanel(tab);
        for(var nr=0; nr<panels.length; nr++) {
            panels[nr].refreshHandler();
        }
    },
    /* return all panlets */
    getAllPanel: function(tab) {
        var panels = [];
        if(tab == undefined) {
            throw new Error("TP.getAllPanel(): no tab! (caller: " + (TP.getAllPanel.caller ? TP.getAllPanel.caller : 'unknown') + ")");
            var tabpan = Ext.getCmp('tabpan');
            tab = tabpan.getActiveTab();
            if(!tab) {
                tab = tabpan.setActiveTab(0);
            }
        }
        if(tab.window_ids) {
            for(var nr=0; nr<tab.window_ids.length; nr++) {
                var id = tab.window_ids[nr];
                var p  = Ext.getCmp(id);
                if(p) { // can be undefined unless already rendered
                    panels.push(p);
                }
            }
        }
        return panels;
    },
    /* set form values from data hash */
    applyFormValues: function(form, data) {
        var fields = form.getFields();
        TP.setRefreshText(data, 'refresh', 'refresh_txt');
        fields.each(function(f) {
            var v = data[f.getName()];
            if(f.xtype == 'combobox' && f.multiSelect == true) {
                f.originalValue = v;
                f.value = v;
                f.setValue(v);
            }
            else if(f.inputType == 'checkbox') {
                f.setValue(v);
                f.originalValue = v;
            } else {
                f.originalValue = [ v ];
                f.setValue(v);
                f.value = v;
            }
        });

        /* checkbox groups are different */
        var items = form.getFields().items;
        for(var i=0; i<items.length; i++) {
            var f = items[i];
            if(f.xtype == 'checkboxgroup') {
                f.removeAll();
                for(var key in initial_backends) {
                    var checked = false;
                    if(Ext.Array.contains(data.backends, key)) { checked = true; }
                    f.add({ boxLabel: initial_backends[key].name, name: 'backends', inputValue: key, checked: checked });
                }
            }
        };

        delete data['refresh_txt'];
        return true;
    },
    /* store form result in data hash  */
    storeFormToData: function(form, data) {
        var values = form.getFieldValues();
        /* save values to xdata store */
        for(var key in values) {
            data[key] = values[key];
        };
        /* checkboxgroups are different */
        var items = form.getFields().items;
        for(var i=0; i<items.length; i++) {
            var f = items[i];
            if(f.xtype == 'checkboxgroup') {
                var result = {};
                var checked = f.getChecked();
                for(var nr=0; nr<checked.length; nr++) {
                    c = checked[nr];
                    if(result[c.name] == undefined) {
                        result[c.name] = [];
                    }
                    result[c.name].push(c.inputValue);
                }
                for(var key in result) {
                    data[key] = result[key];
                }
            }
        }
        return data;
    },
    /* clone an object */
    clone: function(o) {
        return(Ext.JSON.decode(Ext.JSON.encode(o)));
    },
    /* convert backends into array usable by data store */
    getBackendsArray: function(backends, filter) {
        var filterLookup;
        if(filter != undefined) {
            filterLookup = {};
            for(var x = 0; x < filter.length; x++) {
                filterLookup[filter[x]] = 1;
            }
        }
        var data = [];
        for(var key in backends) {
            if(filterLookup == undefined || filterLookup[key]) {
                data.push([key, backends[key].name]);
            }
        }
        return data;
    },

    /* return backends used in panlets backend store */
    getAvailableBackendsTab: function(tab) {
        var backends = [];
        if(tab.xdata.select_backends) {
            // hide backends which are disabled
            backends = TP.getBackendsArray(initial_backends, tab.xdata.backends);
        } else {
            backends = TP.getBackendsArray(initial_backends);
        }
        return backends;
    },

    /* default refresh handler */
    defaultSiteRefreshHandler: function(panel) {
        TP.log('['+panel.id+'] defaultSiteRefreshHandler');
        if(panel.loader.loading) {
            TP.log('['+panel.id+'] is already loading, skipped');
            return;
        }
        if(panel.xdata.url == '') {
            TP.log('['+panel.id+'] no url, skipped');
            return;
        }
        if(panel.xdata.refresh == -2) { // -2 means temporarily disabled
            TP.log('['+panel.id+'] temporarily disabled, skipped');
            return;
        }
        var url = panel.xdata.url;
        var baseParams = {};
        if(panel.noChangeUrlParams == undefined || !panel.noChangeUrlParams) {
            if(panel.loader.baseParams == undefined) {
                panel.loader.baseParams = {};
            }
            baseParams = Ext.merge(panel.loader.baseParams, panel.xdata);
            delete baseParams['gridstate']; // not needed
            // add backend settings
            var tab = Ext.getCmp(panel.panel_id);
            baseParams['backends'] = TP.getActiveBackendsPanel(tab, panel);

            // update proc info?
            baseParams['update_proc'] = TP.setUpdateProcInfo();
        }
        TP.log('['+panel.id+'] loading '+url);
        panel.loader.load({url:url, baseParams: baseParams});
    },

    /* only request proc update information every 30 seconds */
    setUpdateProcInfo: function() {
        var d   = new Date();
        var now = Math.floor(d.getTime()/1000);
        if(TP.last_update_proc == undefined || TP.last_update_proc < now - 30) {
            TP.last_update_proc = now;
            return("1");
        }
        return("0");
    },

    /* convert time frame into seconds */
    timeframe2seconds: function(timedef) {
        if(Ext.isNumeric(String(timedef))) { timedef = timedef + 's'; }
        if(!timedef || !timedef.match)     { return 3600; }

        var res  = timedef.match(/^(\d+)(\w{1})/);
        if(res && res.length == 1) {
            return 3600;
        }
        var nr    = res[1];
        var unit  = res[2];
        if(unit == 's') { return nr; }          // seconds
        if(unit == 'm') { return nr * 60; }     // minutes
        if(unit == 'h') { return nr * 3600; }   // hours
        if(unit == 'd') { return nr * 86400; }  // days
        if(unit == 'w') { return nr * 604800; } // weeks
        return 3600;
    },
    /* import tabs from string */
    importAllTabs: function(data) {
        // strip off comments
        data = data.replace(/\s*\#.*/g, '').replace(/\n/g, '');
        var decoded;
        try {
            decoded = TP.cp.decodeValue(decode64(data));
        }
        catch(err) {
            TP.logError("global", "importAllTabsException", err);
            TP.modalWindows.push(Ext.MessageBox.alert('Failed', 'Import Failed!\nThis seems to be an invalid dashboard export.'));
            return(false);
        }
        if(decoded == null) {
            try {
                decoded = Ext.JSON.decode(decode64(data));
            }
            catch(err) {
                TP.logError("global", "jsonDecodeException", err);
                TP.modalWindows.push(Ext.MessageBox.alert('Failed', 'Import Failed!\nThis seems to be an invalid dashboard export.'));
                return(false);
            }
        }
        if(decoded == undefined || decoded == '') {
            TP.modalWindows.push(Ext.MessageBox.alert('Failed', 'Import Failed!\nThis seems to be an invalid dashboard export.'));
            return(false);
        }
        if(decoded == '') { decoded = {}; }

        /* stop everything */
        var tabpan = Ext.getCmp('tabpan');

        if(decoded.tabpan) {
            /* old export with all tabs*/
            // verify complete import of all tabs export still works
            // REMOVE AFTER: 01.01.2016
            TP.cp.saveChanges(false);
            TP.modalWindows.push(Ext.Msg.confirm(
                'Confirm Import',
                'This is a complete import which will replace your current view with the exported one.<br>Your current open dashboards will be closed and can be added again afterwards.',
                function(button) {
                    if(button === 'yes') {
                        tabpan.stopTimeouts();
                        TP.cp.loadData(decoded, false);
                        TP.cp.saveChanges(false, {replace: 1});
                        TP.modalWindows.push(Ext.MessageBox.alert('Success', 'Import Successful!<br>Please wait while page reloads...'));
                        TP.initialized = false; // prevents onUnload saving over our imported tabs
                        TP.timeouts['timeout_window_reload'] = window.setTimeout("window.location.reload()", 1000);
                    }
                }
            ));
        } else {
            /* new single tab export */
            var param = {
                task:  'update2',
                nr:    'new',
                'tabpan-tab_1': Ext.JSON.encode(decoded)
            }
            var conn = new Ext.data.Connection();
            conn.request({
                url:    'panorama.cgi?state',
                params:  param,
                async:   true,
                success: function(response, opts) {
                    /* allow response to contain cookie messages */
                    var resp = TP.getResponse(undefined, response, false);
                    if(resp.newid) {
                        TP.initial_active_tab = resp.newid;
                        TP.add_pantab(resp.newid);
                    } else {
                        TP.modalWindows.push(Ext.MessageBox.alert('Failed', 'Import Failed!\nThis seems to be an invalid dashboard export.'));
                        return(false);
                    }
                }
            });
        }
        return(true);
    },
    /* eval response data */
    getResponse: function(panlet, response, no_json, no_ts) {
        var refresh = {setType: Ext.emptyFn };
        if(panlet != undefined && panlet.getTool) {
            refresh = panlet.getTool('refresh') || panlet.getTool('broken');
        }
        if(response.status == 200) {
            var data;
            if(no_json) {
                return(response.responseText);
            }
            try {
                data = eval("("+response.responseText+")");
            } catch(err) {
                if(refresh.setType) { refresh.setType('broken') }
                TP.logError(panlet ? panlet.id : '??', "responseEvalException", err);
                return data;
            }
            if(refresh.setType) { refresh.setType('refresh') }
            /* extract pi details */
            if(data && data.pi_detail != undefined) {
                for(var key in data.pi_detail) {
                    if(data.pi_detail[key] && data.pi_detail[key]['state'] != undefined) {
                        initial_backends[key].state         = 0;
                        initial_backends[key].program_start = 0;
                        try {
                            initial_backends[key].state         = data.pi_detail[key]['state'];
                            initial_backends[key].program_start = data.pi_detail[key]['program_start'];
                        } catch(err) {
                            TP.logError(panlet ? panlet.id : '??', "initialBackendsException", err);
                        }
                    }
                }
            }
            var tab = Ext.getCmp('tabpan').getActiveTab();
            if(data && data.dashboard_ts != undefined && data.dashboard_ts[tab.id] != undefined && data.dashboard_ts[tab.id] != tab.ts) {
                var old = tab.ts ? tab.ts : '';
                tab.ts = data.dashboard_ts[tab.id];
                if((no_ts == undefined || no_ts == false) && old < tab.ts) {
                    TP.log('['+tab.id+'] tab timestamp has changed - old: '+old+', new: '+data.dashboard_ts[tab.id]);
                    TP.renewDashboard(tab);
                }
            }
            /* contains a message? */
            var msg = Ext.util.Cookies.get('thruk_message');
            if(msg) {
                TP.Msg.msg(msg);
                // clear message
                Ext.util.Cookies.clear('thruk_message', cookie_path);
            }
            if(data && data.errors) {
                for(var nr=0; nr<data.errors.length; nr++) {
                    TP.Msg.msg("fail_message~~"+data.errors[nr].message);
                }
            }
            return data;
        }
        if(response.status == 0) {
            // ok too
            return false;
        }
        debug("ERROR: " + response.status + ' (' + response.request.options.url + ')');
        debug(response);
        if(refresh.setType) { refresh.setType('broken') }
        return false;
    },
    /* sets text for refresh slider */
    setRefreshText: function(data, slider, text) {
        data[text] = TP.sliderValue2Txt(data[slider]);
    },
    /* convert value to human text */
    sliderValue2Txt: function(v) {
        if(v == -1) { return 'default'; }
        if(v ==  0) { return 'off'; }
        return v+'s';
    },
    /* start tab rotation interval */
    startRotatingTabs: function() {
        var tabpan = Ext.getCmp('tabpan');
        this.stopRotatingTabs();
        if(tabpan.xdata.rotate_tabs > 0) {
            debug("starting tab rotation every " + tabpan.xdata.rotate_tabs + "seconds");
            TP.timeouts['interval_global_rotate_tabs'] = window.setInterval(TP.rotateTabs, tabpan.xdata.rotate_tabs * 1000);
        }
    },
    /* start server time */
    startServerTime: function() {
        var tabpan = Ext.getCmp('tabpan');
        this.stopServerTime();
        var label = Ext.getCmp('server_time');
        if(!tabpan.xdata.server_time) {
            label.hide();
            return;
        }
        label.show();
        TP.timeouts['interval_global_servertime'] = window.setInterval(TP.updateServerTime, 1000);
    },
    stopServerTime: function() {
        var tabpan = Ext.getCmp('tabpan');
        window.clearInterval(TP.timeouts['interval_global_servertime']);
    },
    /* update server time */
    updateServerTime: function() {
        var label  = Ext.getCmp('server_time');
        var client = new Date();
        var time   = Math.floor((client.getTime() - delta_time) / 1000);
        var date   = TP.date_format(time, 'H:i');
        label.update(date);
    },
    /* stop tab rotation interval */
    stopRotatingTabs: function() {
        var tabpan = Ext.getCmp('tabpan');
        window.clearInterval(TP.timeouts['interval_global_rotate_tabs']);
    },
    /* rotate tabs once */
    rotateTabs: function() {
        var tabpan = Ext.getCmp('tabpan');
        var state  = tabpan.getState();
        var at     = state.activeTab;
        // find next tab
        var found = false;
        var next  = undefined;
        tabpan.items.each(function(tab) {
            if(found == true) {
                next = tab.id;
                return false;
            }
            if(tab.id == at) {
                found = true;
            }
        });
        if(next == undefined || !tabpan.setActiveTab(next)) {
            tabpan.setActiveTab(1);
        }
    },
    addTabBarMouseEvents: function(el, tabId) {
        el.on("dblclick", function(evt, el, o) {
            TP.tabSettingsWindow();
        });
        el.on("contextmenu", function(evt, el, o) {
            var tab = Ext.getCmp(tabId);
            tab.contextmenu(evt, true);
        });
    },
    /* sum list elements */
    arraySum: function(list) {
        var l=list.length, i=0, n=0;
        while(i<l) { n += list[i++]} ;
        return n;
    },
    addFormFilter: function(panel, type) {
        panel.obj_filter = new TP.formFilter({
            fieldLabel:     'Filter',
            name:           'filter',
            ftype:          type,
            panel:          panel
        });
        panel.addGearItems(panel.obj_filter);
    },
    /* convert number to binary list */
    dec2bin: function(dec) {
        var potencies = new Array();
        var binary = [];
        for (var i = 0; i > -1; i++) {
            var potency = Math.pow(2, i);
            if (potency > dec) { break; }
            potencies[i] = potency;
        }

        potencies.reverse();

        for (var j = 0; j < potencies.length; j++) {
            var position = potencies[j];
            var zeroOne = parseInt(dec / position);
            if(zeroOne) {
                binary.push(position);
            }
            dec -= potencies[j] * zeroOne;
        }
        return binary;
    },
    /* update an array store with new data */
    updateArrayStore: function(store, data) {
        if(!store) { return; }
        store.suspendEvents(false);
        store.removeAll();
        var num = data.length-1;
        for(var x=0;x<num;x++) {
            store.loadRawData([[data[x]]], true);
        }
        store.resumeEvents();
        // add last one to trigger some events
        if(data.length > 0) {
            store.loadRawData([[data[x]]], true);
        }
    },
    /* update an array store with new data with key/value */
    updateArrayStoreKV: function(store, data) {
        if(!store) { return; }
        store.suspendEvents(false);
        store.removeAll();
        var num = data.length-1;
        for(var x=0;x<num;x++) {
            store.loadRawData({name:data[x][0], value:data[x][1]}, true);
        }
        store.resumeEvents();
        // add last one to trigger some events
        if(data.length > 0) {
            store.loadRawData({name:data[x][0], value:data[x][1]}, true);
        }
    },
    /* update an array store with new data from hash */
    updateArrayStoreHash: function(store, data) {
        if(!store) { return; }
        store.suspendEvents(false);
        store.removeAll();
        var num = data.length-1;
        for(var x=0;x<num;x++) {
            store.loadRawData({name:data[x]['name'], value:data[x]['value']}, true);
        }
        store.resumeEvents();
        // add last one to trigger some events
        if(data.length > 0) {
            store.loadRawData({name:data[x]['name'], value:data[x]['value']}, true);
        }
    },
    /* return location object for url */
    getLocationObject: function(url) {
        var a  = document.createElement('a');
        a.href = url;
        return(a);
    },
    /* compare same origin policy */
    isSameOrigin: function(l1, l2) {
        if(l1.protocol != l2.protocol) {
            return false;
        }
        if(l1.host != l2.host) {
            return false;
        }
        return true;
    },
    /* called on body unload */
    unload: function() {
        TP.isUnloading = true;
        try {
            // try saving state
            TP.cp.saveChanges(false);
        }
        catch(evt) {}
    },
    deleteDowntime: function(id, panelId, type) {
        var panel = Ext.getCmp(panelId);
        var fields = [{
            fieldLabel: '',
            xtype:      'displayfield',
            value:      'no options needed',
            name:       'display',
            width:      240
        }, {
            xtype: 'hidden', name: 'down_id', value: id
        }];
        var menuCfg = TP.ext_menu_command('Remove', (type == 'host' ? 78 : 79), fields);
        var menu = new Ext.menu.Menu(menuCfg);
        panel.add(menu);
        menu.show();
    },
    objectSearchItem: function(panel, type, name, value) {
        return({
            name:           type,
            fieldLabel:     name,
            panel:          panel,
            xtype:          'searchCbo',
            store:          searchStore,
            value:          value
        });
    },
    removeWindowFromPanels: function(win_id) {
        /* remove panel reference */
        var panel = Ext.getCmp(win_id);
        var tab   = Ext.getCmp(panel.panel_id);
        if(tab.window_ids) {
            tab.window_ids = TP.removeFromList(tab.window_ids, win_id);
            tab.saveState();
        }
    },
    updateAllIcons: function(tab, id, xdata, reschedule) {
        if(id != undefined) {
            TP.updateAllIconsDo(tab, id, xdata, reschedule);
        } else {
            /* avoid duplicate updates */
            window.clearTimeout(TP.timeouts['timeout_global_icon_update'+tab.id]);
            TP.timeouts['timeout_global_icon_update'+tab.id] = window.setTimeout(function() {
                TP.updateAllIconsDo(tab);
            }, 300);
        }
    },
    updateAllIconsDo: function(tab, id, xdata, reschedule) {
        if(!TP.iconUpdateRunning) { TP.iconUpdateRunning = {}; }
        if(TP.iconUpdateRunning[tab.id]) { return; }

        var statusReq = TP.getStatusReq(tab, id, xdata);
        if(statusReq == undefined) {
            if(tab && tab.body && tab.mask) { tab.body.unmask(); tab.mask = undefined; }
            return;
        }
        var req = statusReq.req,
            ref = statusReq.ref;

        TP.log('['+tab.id+'] updateAllIconsDo');
        var params = {
            types:       Ext.JSON.encode(req),
            backends:    TP.getActiveBackendsPanel(tab),
            update_proc: TP.setUpdateProcInfo(),
            reschedule:  reschedule ? 1 : ''
        };
        TP.iconUpdateRunning[tab.id] = true;
        Ext.Ajax.request({
            url: 'panorama.cgi?task=status',
            method: 'POST',
            params: params,
            callback: function(options, success, response) {
                TP.iconUpdateRunning[tab.id] = false;
                if(reschedule) { reschedule.unmask(); }
                if(tab && tab.body && tab.mask) { tab.body.unmask(); tab.mask = undefined; }
                if(!success) {
                    if(TP.refresh_errors == undefined) { TP.refresh_errors = 0; }
                    TP.refresh_errors++;
                    /* ignore first error, maybe caused by a reload */
                    if(TP.refresh_errors > 1) {
                        if(response.status == 0) {
                            TP.Msg.msg("fail_message~~refreshing status failed");
                        } else {
                            TP.Msg.msg("fail_message~~refreshing status failed: "+response.status+' - '+response.statusText+'<br>please have a look at the server logfile.');
                        }
                    }
                } else {
                    TP.refresh_errors = 0;
                    if(TP.iconTip) { TP.iconTip.lastUrl = undefined; }
                    var data = TP.getResponse(undefined, response);
                    if(!data || !data.data) { return; }
                    data = data.data;
                    /* update custom filter */
                    if(data.filter) {
                        for(var key in data.filter) {
                            for(var x=0; x<ref.filter[key].length; x++) {
                                ref.filter[key][x].results = data.filter[key];
                                ref.filter[key][x].refreshHandler();
                            }
                            delete ref.filter[key];
                        }
                    }
                    /* update hosts */
                    if(data.hosts) {
                        for(var x=0; x<data.hosts.length; x++) {
                            var name  = data.hosts[x]['name'];
                            var state = data.hosts[x]['state'];
                            if(ref.hosts[name]) { // may be empty if we get the same host twice in a result
                                if(data.hosts[x]['has_been_checked'] == 0) { state = 4; }
                                for(var y=0; y<ref.hosts[name].length; y++) {
                                    ref.hosts[name][y].host = data.hosts[x];
                                    ref.hosts[name][y].refreshHandler(state);
                                }
                                delete ref.hosts[name];
                            }
                        }
                    }
                    /* update hostgroups */
                    if(data.hostgroups) {
                        for(var x=0; x<data.hostgroups.length; x++) {
                            var name  = data.hostgroups[x]['name'];
                            var state = data.hostgroups[x]['state'];
                            if(ref.hostgroups[name]) { // may be empty if we get the same hostgroup twice in a result
                                for(var y=0; y<ref.hostgroups[name].length; y++) {
                                    ref.hostgroups[name][y].hostgroup = data.hostgroups[x];
                                    ref.hostgroups[name][y].refreshHandler();
                                }
                                delete ref.hostgroups[name];
                            }
                        }
                    }
                    /* update servicegroups */
                    if(data.servicegroups) {
                        for(var x=0; x<data.servicegroups.length; x++) {
                            var name  = data.servicegroups[x]['name'];
                            var state = data.servicegroups[x]['state'];
                            if(ref.servicegroups[name]) { // may be empty if we get the same servicegroup twice in a result
                                for(var y=0; y<ref.servicegroups[name].length; y++) {
                                    ref.servicegroups[name][y].servicegroup = data.servicegroups[x];
                                    ref.servicegroups[name][y].refreshHandler();
                                }
                                delete ref.servicegroups[name];
                            }
                        }
                    }
                    /* update services */
                    if(data.services) {
                        for(var x=0; x<data.services.length; x++) {
                            var hst   = data.services[x]['host_name'];
                            var svc   = data.services[x]['description'];
                            var state = data.services[x]['state'];
                            if(data.services[x]['has_been_checked'] == 0) { state = 4; }
                            if(ref.services[hst] && ref.services[hst][svc]) { // may be empty if we get the same service twice in a result
                                for(var y=0; y<ref.services[hst][svc].length; y++) {
                                    ref.services[hst][svc][y].service = data.services[x];
                                    ref.services[hst][svc][y].refreshHandler(state);
                                }
                                delete ref.services[hst][svc];
                            }
                        }
                    }
                    /* update sites */
                    if(data.backends) {
                        for(var key in data.backends) {
                            var name = data.backends[key].name;
                            if(ref.sites[name]) {
                                for(var x=0; x<ref.sites[name].length; x++) {
                                    ref.sites[name][x].site = data.backends[key];
                                    ref.sites[name][x].refreshHandler();
                                }
                            }
                            delete ref.sites[name];
                        }
                    }

                    /* mark remaining as unknown */
                    var keys = ['hosts', 'hostgroups', 'servicegroups', 'sites', 'filter'];
                    for(var x=0; x<keys.length; x++) {
                        var name = keys[x];
                        for(var key in ref[name]) {
                            for(var y=0; y<ref[name][key].length; y++) {
                                delete ref[name][key][y]['hostgroup'];
                                delete ref[name][key][y]['host'];
                                delete ref[name][key][y]['servicegroup'];
                                delete ref[name][key][y]['site'];
                                delete ref[name][key][y]['data'];
                                ref[name][key][y].refreshHandler(3);
                                delete ref[name][key][y][name];
                            }
                        }
                    }
                    // mark unknown services
                    for(var key in ref.services) {
                        for(var key2 in ref.services[key]) {
                            for(var y=0; y<ref.services[key][key2].length; y++) {
                                ref.services[key][key2][y].refreshHandler(3);
                                delete ref.services[key][key2][y]['service'];
                            }
                        }
                    }
                }
                TP.checkSoundAlerts(tab);
                tab.scheduleApplyZindex();
            }
        });
    },

    /* do delayed availability update */
    updateAllLabelAvailability: function(tab, id, xdata) {
        if(id != undefined) {
            TP.updateAllLabelAvailabilityDo(tab, id, xdata);
        } else {
            /* avoid duplicate updates */
            window.clearTimeout(TP.timeouts['timeout_global_avail_update'+tab.id]);
            TP.timeouts['timeout_global_avail_update'+tab.id] = window.setTimeout(function() {
                TP.updateAllLabelAvailabilityDo(tab);
            }, 300);
        }
    },

    /* do the availability update */
    updateAllLabelAvailabilityDo: function(tab, id, xdata) {
        if(!TP.availabilityUpdateRunning) { TP.availabilityUpdateRunning = {}; }
        if(TP.availabilityUpdateRunning[tab.id]) { return; }
        var statusReq = TP.getStatusReq(tab, id, xdata);
        if(statusReq == undefined) { return; }
        var req = statusReq.req,
            ref = statusReq.ref;

        var params = {
            types:       Ext.JSON.encode(req),
            backends:    TP.getActiveBackendsPanel(tab),
            update_proc: TP.setUpdateProcInfo(),
            avail:       Ext.JSON.encode(TP.availabilities)
        };
        TP.log('['+tab.id+'] updateAllLabelAvailability');
        TP.availabilityUpdateRunning[tab.id] = true;
        Ext.Ajax.request({
            url: 'panorama.cgi?task=availability',
            method: 'POST',
            params: params,
            callback: function(options, success, response) {
                if(success) {
                    var data = TP.getResponse(undefined, response);
                    if(!data || !data.data) { return; }
                    data = data.data;
                    var now = Math.floor(new Date().getTime()/1000);
                    for(var key in data) {
                        for(var key2 in data[key]) {
                            TP.availabilities[key][key2]['last']         = data[key][key2];
                            TP.availabilities[key][key2]['last_refresh'] = now;
                        }
                        var panel = Ext.getCmp(key);
                        panel.setIconLabel();
                    }
                }
                TP.availabilityUpdateRunning[tab.id] = false;
                TP.log('['+tab.id+'] updateAllLabelAvailability done');
            }
        });
    },

    /* get request parameters for status requests */
    getStatusReq: function(tab, id, xdata) {
        var panels   = TP.getAllPanel(tab);
        var req      = { filter: {}, hosts: {}, hostgroups: {}, services: {}, servicegroups: {}};
        var ref      = { filter: {}, hosts: {}, hostgroups: {}, services: {}, servicegroups: {}, sites: {}};
        var count  = 0;
        for(var nr=0; nr<panels.length; nr++) {
            var p = panels[nr];
            if(id && p.id != id) { continue; }
            if(id && xdata) { p.oldXdata = p.xdata; p.xdata = xdata; }
            if(p.xdata && p.xdata.general) {
                /* custom filter */
                if(p.xdata.general.filter) {
                    var filter = Ext.JSON.encode([p.xdata.general.incl_hst, p.xdata.general.incl_svc, p.xdata.general.filter, p.xdata.general.backends]);
                    if(ref.filter[filter] == undefined) { ref.filter[filter] = []; }
                    if(req.filter[filter] == undefined) { req.filter[filter] = []; }
                    req.filter[filter].push(p.id);
                    ref.filter[filter].push(p);
                    count++;
                }

                /* update services */
                else if(p.xdata.general.service && p.xdata.general.host) {
                    if(req.services[p.xdata.general.host] == undefined) {
                        req.services[p.xdata.general.host] = {};
                        ref.services[p.xdata.general.host] = {};
                    }
                    if(ref.services[p.xdata.general.host][p.xdata.general.service] == undefined) {
                        ref.services[p.xdata.general.host][p.xdata.general.service] = [];
                    }
                    if(req.services[p.xdata.general.host][p.xdata.general.service] == undefined) {
                        req.services[p.xdata.general.host][p.xdata.general.service] = [];
                    }
                    req.services[p.xdata.general.host][p.xdata.general.service].push(p.id);
                    ref.services[p.xdata.general.host][p.xdata.general.service].push(p);
                    count++;
                }
                /* update hosts */
                else if(p.xdata.general.host) {
                    if(ref.hosts[p.xdata.general.host] == undefined) { ref.hosts[p.xdata.general.host] = []; }
                    if(req.hosts[p.xdata.general.host] == undefined) { req.hosts[p.xdata.general.host] = []; }
                    req.hosts[p.xdata.general.host].push(p.id);
                    ref.hosts[p.xdata.general.host].push(p);
                    count++;
                }
                /* update hostgroups */
                else if(p.xdata.general.hostgroup) {
                    if(ref.hostgroups[p.xdata.general.hostgroup] == undefined) { ref.hostgroups[p.xdata.general.hostgroup] = []; }
                    if(req.hostgroups[p.xdata.general.hostgroup] == undefined) { req.hostgroups[p.xdata.general.hostgroup] = []; }
                    req.hostgroups[p.xdata.general.hostgroup].push(p.id);
                    ref.hostgroups[p.xdata.general.hostgroup].push(p);
                    count++;
                }
                /* update servicegroups */
                else if(p.xdata.general.servicegroup) {
                    if(ref.servicegroups[p.xdata.general.servicegroup] == undefined) { ref.servicegroups[p.xdata.general.servicegroup] = []; }
                    if(req.servicegroups[p.xdata.general.servicegroup] == undefined) { req.servicegroups[p.xdata.general.servicegroup] = []; }
                    req.servicegroups[p.xdata.general.servicegroup].push(p.id);
                    ref.servicegroups[p.xdata.general.servicegroup].push(p);
                    count++;
                }
                /* update sites */
                else if(p.xdata.general.site) {
                    if(ref.sites[p.xdata.general.site] == undefined) { ref.sites[p.xdata.general.site] = []; }
                    ref.sites[p.xdata.general.site].push(p);
                    count++;
                }
            }
            if(id && p.oldXdata) { p.xdata = p.oldXdata; delete p.oldXdata; }
        };
        var tabpan = Ext.getCmp('tabpan');
        if(count == 0 && tab != tabpan.getActiveTab()) { return; }
        return({req: req, ref: ref });
    },

    /* let this element flicker and make it a little bit bigger */
    flickerImg: function(dom_id) {
        var el     = Ext.get(dom_id);
        el.animate({ to: { opacity: 0   } })
          .animate({ to: { opacity: 100 } })
          .animate({ to: { opacity: 0   } })
          .animate({ to: { opacity: 100 } })
          .animate({ to: { opacity: 0   } })
          .animate({ to: { opacity: 100 } })
          .animate({ to: { opacity: 0   } })
          .animate({ to: { opacity: 100 } })
          .animate({ to: { opacity: 0   } })
          .animate({ to: { opacity: 100 } })
    },

    /* toggle or set a dashboard option */
    toggleDashboardOption: function(nr, field, value) {
        if(value == undefined) { value = 'toggle'; }
        Ext.Ajax.request({
            url: 'panorama.cgi?task=dashboard_update',
            method: 'POST',
            params: { nr: nr, action: 'update', field: field, value: value },
            async: false,
            callback: function(options, success, response) {
                if(!success) {
                    if(response.status == 0) {
                        TP.Msg.msg("fail_message~~adding dashboard failed");
                    } else {
                        TP.Msg.msg("fail_message~~adding dashboard failed: "+response.status+' - '+response.statusText);
                    }
                } else {
                    if(TP.dashboardsSettingWindow && TP.dashboardsSettingGrid && TP.dashboardsSettingGrid.loader) {
                        TP.dashboardsSettingGrid.loader.load();
                    }
                    TP.reconfigureDashboard(nr);
                }
            }
        });
        return false;
    },

    /* fetch dashboard data from server and reapply settings */
    reconfigureDashboard: function(nr) {
        /* update dashboard managment view */
        if(TP.dashboardsSettingWindow && TP.dashboardsSettingGrid && TP.dashboardsSettingGrid.getView) {
            TP.dashboardsSettingGrid.getView().refresh();
        }
        TP.checkModalWindows();

        var tab = Ext.getCmp(nr);
        if(tab == undefined) { return; }

        Ext.Ajax.request({
            url: 'panorama.cgi?task=dashboard_data',
            method: 'POST',
            params: { nr: nr },
            async: false,
            callback: function(options, success, response) {
                if(!success) {
                    if(response.status == 0) {
                        TP.Msg.msg("fail_message~~adding dashboard failed");
                    } else {
                        TP.Msg.msg("fail_message~~adding dashboard failed: "+response.status+' - '+response.statusText);
                    }
                } else {
                    var data = TP.getResponse(undefined, response);
                    data = data.data;
                    for(var key in data) {
                        TP.cp.set(key, Ext.JSON.decode(data[key]));
                    }
                    if(TP.cp.state[nr]) {
                        tab.applyXdata(TP.cp.state[nr].xdata);
                    } else {
                        TP.Msg.msg("fail_message~~adding dashboard failed, no such dashboard");
                    }
                }
            }
        });
    },

    /* run action for dashboards */
    dashboardActionHandler: function(grid, rowIndex, colIndex, item, evt, record, row, confirmed) {
        var action = item.action;
        var nr     = record.data.nr;
        if(action == 'remove') {
            if(confirmed == undefined || confirmed == 0) {
                TP.modalWindows.push(Ext.Msg.confirm('Really Remove?', 'Do you really want to remove this dashboard with all its windows?', function(button) {
                    if(button === 'yes') {
                        TP.dashboardActionHandler(grid, rowIndex, colIndex, item, evt, record, row, 1);
                    }
                }));
                return false;
            }
            Ext.Ajax.request({
                url: 'panorama.cgi?task=dashboard_update',
                method: 'POST',
                params: { nr: nr, action: action },
                async: false,
                callback: function(options, success, response) {
                    if(!success) {
                        if(response.status == 0) {
                            TP.Msg.msg("fail_message~~removing dashboard failed");
                        } else {
                            TP.Msg.msg("fail_message~~removing dashboard failed: "+response.status+' - '+response.statusText);
                        }
                    } else {
                        if(TP.dashboardsSettingWindow && TP.dashboardsSettingGrid && TP.dashboardsSettingGrid.loader) {
                            TP.dashboardsSettingGrid.loader.load();
                        }
                        var tab = Ext.getCmp(TP.nr2TabId(nr));
                        if(tab) { tab.close(); }
                    }
                }
            });
        }
        if(action == 'edit') {
            TP.tabSettingsWindow(nr);
        }
        return false;
    },

    /* returns list of currently active backends for given panel */
    getActiveBackendsPanel: function(tab, panel) {
        var backends;
        if(panel && panel.xdata && panel.xdata.backends && panel.xdata.backends.length > 0) {
            backends = panel.xdata.backends;
        }
        else if(tab.xdata.select_backends) {
            backends = tab.xdata.backends;
        } else {
            var available = TP.getAvailableBackendsTab(tab);
            backends      = [];
            for(var x=0; x<available.length; x++) {
                backends.push(available[x][0]);
            }
        }
        if((!panel || panel.filterBackends == undefined || panel.filterBackends != false) && tab.activeBackends != undefined) {
            var newBackends = [];
            for(var x=0; x<backends.length; x++) {
                var key = backends[x];
                if(tab.activeBackends[key] != false) {
                    newBackends.push(key);
                }
            }
            backends = newBackends;
        }
        if(backends.length == 0) { return(''); }
        return backends;
    },

    /* returns form field by name */
    getFormField: function(form, name) {
        var item = form.items.findBy(function(item, key) {
            if(item.name == name) { return true; }
            return false;
        });
        return item;
    },

    /* play a wave file*/
    playWave: function(url, endedCallback) {
        var el = Ext.DomHelper.insertFirst(document.body, '<audio src="'+url+'" />' , true);
        el.dom.play();
        el.dom.addEventListener('ended', function() {
            if(endedCallback) {
                endedCallback();
            }
        });
    },
    /* put a new alert onto the queue */
    checkSoundAlerts: function(tab) {
        var order = ['unreachable', 'down', 'critical', 'warning', 'unknown', 'recovery'];
        var tab_id = tab.id;

        /* check if any sound is enabled */
        var enabled = 0;
        for(var x=0; x<order.length; x++) {
            if(tab.xdata[order[x]+'_sound'] != "") { enabled++; }
        }
        if(enabled == 0) { return; }

        if(TP.alertTotals == undefined) { TP.alertTotals = {}; }
        var totals = {recovery: 0, warning: 0, critical: 0, unknown: 0, down: 0, unreachable: 0};

        var panels = TP.getAllPanel(tab);
        for(var nr=0; nr<panels.length; nr++) {
            var p = panels[nr];
            if(p.iconType && p.xdata) {
                var alertState = p.xdata.state;
                if(p.acknowledged || p.downtime) { alertState = 0; }
                if(p.iconType == 'host') {
                    if(alertState == 0) { totals.recovery++    }
                    if(alertState == 1) { totals.down++        }
                    if(alertState == 2) { totals.unreachable++ }
                } else {
                    if(alertState == 0) { totals.recovery++    }
                    if(alertState == 1) { totals.warning++     }
                    if(alertState == 2) { totals.critical++    }
                    if(alertState == 3) { totals.unknown++     }
                }
            }
        }

        /* inital display does not alert */
        if(TP.alertTotals[tab_id] == undefined) {
            TP.alertTotals[tab_id] = totals;
            return;
        }

        if(TP.alertNumbers         == undefined) { TP.alertNumbers         = {}; }
        if(TP.alertNumbers[tab_id] == undefined) { TP.alertNumbers[tab_id] = {recovery: 0, warning: 0, critical: 0, unknown: 0, down: 0, unreachable: 0}; }

        for(var x=0; x<order.length; x++) {
            var name = order[x];
            /* sounds enabled and there are alerts */
            if(tab.xdata[name+'_sound'] != "" && totals[name] > 0) {
                /* repeat enabled or new alerts */
                if(   totals[name] > TP.alertTotals[tab_id][name]
                   || tab.xdata[name+'_repeat'] == 0
                   || tab.xdata[name+'_repeat'] > TP.alertNumbers[tab_id][name])
                {
                    var tabpan = Ext.getCmp('tabpan');
                    if(tabpan.xdata.sounds_enabled) {
                        TP.playWave(tab.xdata[name+'_sound']);
                        TP.alertNumbers[tab_id][name]++;
                    }
                }
                break;
            } else {
                TP.alertNumbers[tab_id].name = 0;
            }
        }
    },
    /* renew dashboards on the fly, delayed */
    renewDashboard: function(tab) {
        if(tab.renewInProgress) { return; }
        window.clearTimeout(TP.timeouts['timeout_global_renewdashboard'+tab.id]);
        TP.timeouts['timeout_global_renewdashboard'+tab.id] = window.setTimeout(function() {
            TP.renewDashboardDo(tab);
        }, 200);
    },

    /* renew dashboards on the fly */
    renewDashboardDo: function(tab) {
        TP.log('['+tab.id+'] renewDashboardDo');
        var duration = 1000;
        tab.renewInProgress = true;
        Ext.Ajax.request({
            url: 'panorama.cgi?task=dashboard_data',
            method: 'POST',
            params: { nr: tab.id },
            callback: function(options, success, response) {
                if(success) {
                    var data = TP.getResponse(undefined, response);
                    data = data.data;
                    var old_window_ids = TP.clone(tab.window_ids);
                    for(var key in data) {
                        var cfg = Ext.JSON.decode(data[key]);
                        var p   = Ext.getCmp(key);
                        if(p && key.search(/tabpan-tab_\d+$/) != -1) {
                            /* changes in our dashboard itself */
                            Ext.apply(p, cfg);
                            delete cfg['readonly'];
                            delete cfg['user'];
                            delete cfg['ts'];
                            delete cfg['public'];
                            p.applyXdata();
                            TP.cp.set(key, cfg);
                        }

                        /* panel class changed */
                        if(p && cfg.xdata.cls != p.xdata.cls) {
                            TP.cp.set(p.id, cfg);
                            TP.redraw_panlet(p, tab);
                            continue;
                        }

                        /* panel does not yet exist */
                        if(ExtState[key] == undefined) {
                            TP.cp.set(key, cfg);
                            TP.add_panlet({id:key, tb:tab, autoshow:true, conf: { firstRun:false }}, false);
                            tab.saveState();
                        }
                        else if(p && !TP.JSONequals(ExtState[key], data[key])) {
                            /* position and size changes can be applied by animation */
                            Ext.apply(p, cfg);
                            TP.cp.set(key, cfg);
                            if(p.applyAnimated) {
                                p.applyAnimated({duration:duration});
                            }
                            if(p.applyXdata) {
                                window.setTimeout(Ext.bind(p.applyXdata, p, [cfg.xdata]), duration+100);
                            }
                        }
                    }
                    /* remove no longer existing panlets */
                    for(var x=0; x<old_window_ids.length; x++) {
                        var id = old_window_ids[x];
                        if(data[id] == undefined) {
                            Ext.getCmp(id).destroy();
                        }
                    }
                    /* update stateproviders last data to prevent useless updates */
                    TP.cp.lastdata = setStateByTab(ExtState);
                    if(tab.mapEl) { tab.mapEl.destroy(); tab.mapEl = undefined; }
                    if(tab.map)   { tab.map.destroy();   tab.map   = undefined; }
                    tab.renewInProgress = false;
                } else {
                    tab.renewInProgress = false;
                }
            }
        });
    },
    /* convert string number into real number: { value: '14px', unit: 'px', floor: true, defaultValue: 10 } */
    extract_number_with_unit: function(options) {
        var val = String(options.value);
        var nr  = Number(val.replace(options.unit, ''));
        if(!Ext.isNumber(nr)) { nr = options.defaultValue; }
        if(options.floor)     { nr = Math.floor(nr);  }
        return(nr);
    },
    show_shape_preview: function(item, panel, list) {
        var name = item.getAttribute('name');
        if(item.innerHTML != "") { return; }
        item.id = 'tmpid'+TP.tmpid++;
        var tmppanel = Ext.create('Ext.draw.Component', {
            renderTo: item.id,
            width:    16,
            height:   16,
            viewBox:  false,
            shadow:   false,
            items:    [],
            xdata: {
                state: 0,
                appearance: { type: 'shape', shapename: name, shapeheight: 16, shapewidth: 16 },
                layout: { rotation: 0 }
            }
        }).show(true);
        tmppanel.setFloatParent(item.el);
        panel.shapeRender(tmppanel.xdata, panel.xdata.appearance.color_ok, tmppanel);
        list.push(tmppanel);
    },
    fullReload: function() {
        TP.log('[global] full reload');
        reloadPage();
    },
    log: function(str) {
        //debug(str); /* makes too much noise */
        TP.logHistory.push([new Date(), str]);
        /* limit history to last 50k entries */
        while(TP.logHistory.length > 50000) {
            TP.logHistory.shift();
        }
    },
    logError: function(prefix, name, err) {
        if(name == "labelEvalException") { return; }
        try {
            var str = '['+prefix+'] '+name+':';
            debug(str);
            debug(err);
            TP.log(str);
            var out = err.stack.trim().split("\n");
            for(var x=0; x<out.length; x++) {
                str = '['+prefix+'] '+out[x];
                debug(str);
                TP.log(str);
            }
        } catch(er) {}
    },
    JSONequals: function(str1, str2) {
        if(!str1) {
            return(false);
        }
        if(str2 != str1) {
            if(str1.length != str2.length) {
                return(false);
            }
            var dec1 = Ext.JSON.decode(str1);
            var dec2 = Ext.JSON.decode(str2);
            for(var key2 in dec1) {
                var obj1 = dec1[key2]; if(Ext.isString(dec1[key2]) && dec1[key2].match(/^\{/)) { obj1 = Ext.JSON.decode(dec1[key2]); }
                var obj2 = dec2[key2]; if(Ext.isString(dec2[key2]) && dec2[key2].match(/^\{/)) { obj2 = Ext.JSON.decode(dec2[key2]); }
                if(!Object.my_equals(obj1, obj2)) {
                    return(false);
                }
            }
        }
        return(true);
    },
    /* remove row from gridpanel */
    removeGridRow: function(grid, rowIndex, colIndex) {
        grid.getStore().removeAt(rowIndex);
    },
    /* convert number to tab id */
    nr2TabId: function(nr) {
        nr = String(nr).replace(/^tabpan-tab_/, '');
        nr = "tabpan-tab_"+nr;
        return(nr);
    },
    /* make sure our modal windows are still in front */
    checkModalWindows: function() {
        if(TP.modalWindows.length == 0) { return; }
        var newModelWindows = [];
        var zIndex;
        var length = TP.modalWindows.length;
        var first  = true;
        for(var x=length-1; x>=0; x--) {
            var win = TP.modalWindows[x];
            if(win && win.el && !win.isHidden()) {
                if(first) {
                    try { win.toFront(); } catch(err) {}
                    var masks = Ext.Element.select('.x-mask');
                    if(masks.elements.length > 0) {
                        zIndex = Number(masks.elements[0].style.zIndex);
                    } else {
                        zIndex = Number(win.el.dom.style.zIndex);
                    }
                    first  = false;
                } else {
                    win.el.dom.style.zIndex = zIndex - length + x;
                }
                newModelWindows.unshift(win);
            }
        }
        TP.modalWindows = newModelWindows;
    },
    reduceDelayEvents: function(scope, callback, delay, timeoutName) {
        var now = (new Date()).getTime();
        if(!scope) {
            /* probably out of scope already, run it a last time */
            callback();
            return;
        }
        if(!scope.lastEventRun)              { scope.lastEventRun = {}; }
        if(!scope.lastEventRun[timeoutName]) { scope.lastEventRun[timeoutName] = 0; }
        window.clearTimeout(TP.timeouts[timeoutName]);
        if(now > scope.lastEventRun[timeoutName] + delay) {
            scope.lastEventRun[timeoutName] = now;
            callback();
        } else {
            TP.timeouts[timeoutName] = window.setTimeout(function() {
                if(scope) {
                    var now = (new Date()).getTime();
                    scope.lastEventRun[timeoutName] = now;
                    callback();
                }
            }, delay);
        }
    },
    isThisTheActiveTab: function(panel) {
        var tabpan    = Ext.getCmp('tabpan');
        var activeTab = tabpan.getActiveTab();
        if(activeTab && panel.panel_id != activeTab.id) { return(false); }
        return(true);
    }
}
TP.log('[global] starting');
TP.log('[global] '+thruk_version);
if(thruk_extra_version) { TP.log('[global] '+thruk_extra_version); }
TP.log('[global] '+window.location);
TP.log('[global] '+navigator.userAgent);

/* returns formated time string */
function strftime(format, unix_timestamp) {
    var date = new Date(unix_timestamp*1000);
    return(date.strftime(format));
}
