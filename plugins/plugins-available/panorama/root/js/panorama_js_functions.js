/* send debug output to firebug console */
var debug = function(str) {}
if(typeof thruk_debug_js !== 'undefined' && thruk_debug_js != undefined && thruk_debug_js) {
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
    allDashboards: {},

    /* called once the initialization */
    initComplete: function() {
        if(TP.initMask) { TP.initMask.destroy(); delete TP.initMask; }
        if(TP.initialized) { return; }
        TP.log('[global] init complete');
        TP.initialized = true;

        var tabbar = Ext.getCmp("tabbar");
        var activeTab = tabbar.getActiveTab();
        if(!activeTab) {
            tabbar.setActiveTab(0);
        }
        if(!one_tab_only) {
            tabbar.startTimeouts();
        }

        TP.cp.queueChanges();

        /* preload images */
        window.setTimeout(preloader, 2000);
    },

    // check if init has completed
    increaseLoadedPanels: function() {
        if(TP.cur_panels > TP.num_panels) {
            return;
        }
        // update initial panlet counter
        var tmp = Ext.dom.Query.select('.x-mask-loading DIV');
        if(tmp.length > 0) {
            TP.cur_panels++;
            if(TP.cur_panels > TP.num_panels) {
                TP.initComplete();
            } else {
                tmp[0].innerHTML = "loading panel "+TP.cur_panels+'/'+TP.num_panels+"...";
            }
        }
    },

    get_snap: function (x, y) {
        var newx = Math.round(x/TP.snap_x) * TP.snap_x;
        var newy = Math.round(y/TP.snap_y) * TP.snap_y + 5;
        if(newx < 0) { newx = 0; }
        if(newy < 0) { newy = 0; }
        if(newy < TP.offset_y) { newy = TP.offset_y; }
        return([newx, newy]);
    },

    /*
    add_pantab(options):
        id                  the id to open, or 'new'
        replace_id          replace given dashboard
        hidden              dashboard will be invisible and kept in background
        callback            run callback after dashboard finished loading function(tab_id, success, response)
        extraConf           merge config into dashboard data
        skipAutoShow        do not put dashboard in front
    */
    add_pantab: function(opt) {
        if(!Ext.isObject(opt)) { opt = { id: opt }; }
        var id = opt.id;
        if(id && id != "new" && id != "new_geo" && id != "new_or_empty") {
            id = TP.nr2TabId(id);
        }
        var tabbar = Ext.getCmp('tabbar');

        if(id == undefined) {
            id = 'new_or_empty';
        }
        if(id == 'new_geo') {
            id = 'new';
            opt.extraConf = {map: {}};
        }

        /* if previously added as hidden tab, destroy it and add it normal */
        var tab = Ext.getCmp(id);
        if(tab && tab.rendered) {
            if(!opt.hidden) {
                // simply activate tab
                tabbar.setActiveTab(tab);
            }
            return;
        }


        if(!opt.hidden) {
            if(TP.dashboardsSettingWindow) {
                TP.dashboardsSettingWindow.body.mask('loading...');
            }
            if(one_tab_only) {
                if(opt.replace_id && id != opt.replace_id) {
                    tabbar.getActiveTab().addMask("loading");
                }
            }
        }

        TP.log('[global] add_pantab: id:'+id+(opt.replace_id ? ', replace_id: '+opt.replace_id : ''));

        /* get tab data from server */
        if(id && (id == "new" || id == "new_or_empty")) {
            opt.newDashboard = true;
        }
        if(id && TP.cp.get(id) == undefined) {
            if(!TP.initialized) {
                // all initial tabs should have a state, if not, do not open that tab
                return;
            }
            opt.id = id;
            if(opt.hidden) {
                TP.add_pantab_delayed_hidden(id, opt.callback);
                return;
            }
            return(TP.add_pantab_load(opt));
        }

        /* add new tab panel */
        if(opt.hidden) {
            if(tab) {
                // recreate as hidden tab
                tab.redraw = true;
                tab.destroy();
            }
            tab = Ext.create("TP.Pantab", {id: id, hidden: true});
        } else {
            if(TP.initial_active_tab == undefined || one_tab_only) {
                TP.initial_active_tab = id; // set inital tab, so panlets will be shown
            }

            if(tab) {
                tabbar.add(tab);
            } else {
                tab = tabbar.add(new TP.Pantab({id: id}));
            }
            if(!opt.skipAutoShow) {
                tab.showLoadMask();
                tab.show();
                tabbar.setActiveTab(tab);
                if(tab.tab) {
                    if(tab.xdata.hide_tab_header) {
                        tab.tab.hide();
                    } else {
                        tab.tab.show();
                    }
                }
            }

            var tabPos, bar;
            if(tabbar.getTabBar) {
                bar = tabbar.getTabBar();
                for(var x=0; x<bar.items.items.length; x++) {
                    if(bar.items.items[x].card && bar.items.items[x].card.id == id) {
                        tabPos = x;
                        break;
                    }
                }
            }

            /* move new-tab button at the end */
            if(!one_tab_only) {
                /* switch added tab with "new tab" */
                bar.move(tabPos-1, tabPos);

                /* make tab title editable */
                if(!readonly && !dashboard_ignore_changes) {
                    var tabhead = tabbar.getTabBar().items.getAt(tabPos-1);
                    if(tabhead == undefined) {
                        // do nothing
                    } else if(tabhead.rendered == false) {
                        tabhead.addListener('afterrender', function(This, eOpts) {
                            TP.addTabBarMouseEvents(This.getEl(), id);
                        });
                    } else {
                        TP.addTabBarMouseEvents(tabhead.getEl(), id);
                    }
                }
            }

            /* replace existing tab with current one */
            if(opt.replace_id) {
                if(one_tab_only) {
                    if(id != opt.replace_id) {
                        Ext.getCmp(opt.replace_id).destroy();
                        if(history.replaceState) {
                            var tab    = tabbar.getActiveTab();
                            var newloc = new String(window.document.location);
                            newloc     = newloc.replace(/\?map=.*$/g, '');
                            newloc     = newloc + "?map="+tab.xdata.title;
                            history.replaceState({}, "", newloc);
                        }
                    }
                } else {
                    var replace_nr;
                    for(var x=0; x<tabbar.open_tabs.length; x++) {
                        if(tabbar.open_tabs[x] == opt.replace_id) {
                            replace_nr = x+1;
                        }
                    }
                    if(replace_nr != undefined) {
                        bar.move(tabPos-1, replace_nr);
                        if(id != opt.replace_id) {
                            Ext.getCmp(opt.replace_id).destroy();
                        }
                    }
                }
                var tab = tabbar.getActiveTab();
                tab.adjustTabHeaderOffset();
            }

            if(TP.initialized) {
                // remove ?maps= from url
                TP.cleanPanoramUrl();
            }
        }

        /* disable lock for new dashboard */
        if(opt.newDashboard) {
            tab.locked = false;
            tab.setLock(false);
            opt.newDashboard = false;
        }

        /* any callbacks? */
        if(opt.callback) { opt.callback(id, true); }

        /* return false to prevent newtab button being activated */
        return false;
    },

    add_pantab_load: function(opt, callback) {
        /* fetch state info and add new tab(s) as callback */
        var alreadyopen = [];
        for(var key in TP.allDashboards) {
            var key_id = String(key).replace(/^pantab_/, "");
            alreadyopen.push(key_id);
        }
        Ext.Ajax.request({
            url: 'panorama.cgi?task=dashboard_data',
            method: 'POST',
            params: {
                nr:        opt.id,
                hidden:    opt.hidden,
                recursive: alreadyopen
            },
            callback: function(options, success, response) {
                if(!success) {
                    if(!opt.hidden) {
                        if(response.status == 0) {
                            TP.Msg.msg("fail_message~~adding new dashboard failed");
                        } else {
                            TP.Msg.msg("fail_message~~adding new dashboard failed: "+response.status+' - '+response.statusText);
                        }
                    }
                    var tabbar = Ext.getCmp('tabbar');
                    tabbar.saveState();
                    if(callback) { callback(opt.id, success, response); }
                    return;
                }

                var data = TP.getResponse(undefined, response);
                data = data.data;
                if(data && data.newid) {
                    opt.id = data.newid;
                    delete data.newid;
                    opt.newDashboard = true;
                }
                if(opt.extraConf) {
                    var tmp = anyDecode(data[opt.id]);
                    Ext.apply(tmp.xdata, opt.extraConf);
                    data[opt.id] = Ext.JSON.encode(tmp);
                }
                for(var key in data) {
                    TP.cp.set(key, anyDecode(data[key]));
                }

                if(Ext.isArray(opt.id)) {
                    if(callback) { callback(opt.id, success, response); }
                    return;
                }

                if(TP.cp.state[opt.id]) {
                    if(TP.dashboardsSettingWindow && TP.dashboardsSettingGrid && TP.dashboardsSettingGrid.getView) {
                        TP.dashboardsSettingGrid.getView().refresh();
                    }
                } else {
                    if(!opt.hidden) {
                        TP.Msg.msg("fail_message~~adding new dashboard failed, no such dashboard");
                    }
                    var tabbar = Ext.getCmp('tabbar');
                    tabbar.saveState();
                    return;
                }

                if(!opt.hidden) {
                    TP.initial_active_tab = TP.nr2TabId(opt.id); // set inital tab, so panlets will be shown
                }

                TP.add_pantab(opt);
                if(callback) { callback(opt.id, success, response); }

                // add additionall hidden dashboards required from icons
                for(var key in data) {
                    var matches = key.match(/^pantab_.*/);
                    if(matches && !matches[0].match(/^pantab_.*_panlet_\d+/) &&  matches[0] != opt.id && !Ext.getCmp(matches[0])) {
                        TP.add_pantab({ id: matches[0], hidden: true });
                    }
                }
            }
        });
        return;
    },

    // adds multiple (hidden) dashboards in bulk mode
    add_pantab_bulk_hidden: function(ids, callbacks) {
        TP.add_pantab_load({ id: ids, hidden: true }, function() {
            for(var x=0; x<ids.length; x++) {
                var id = ids[x];
                if(TP.cp.state[id]) {
                    TP.add_pantab({ id: id, hidden: true, callback: callbacks[x] });
                } else {
                    if(callbacks[x]) {
                        callbacks[x](id, false);
                    }
                }
            }
        });
    },

    // collect dashboard ids to open in bulk
    add_pantab_delayed_hidden: function(id, callback) {
        if(!TP.load_bulk_ids)       { TP.load_bulk_ids = []; }
        if(!TP.load_bulk_callbacks) { TP.load_bulk_callbacks = []; }

        // do not add it twice
        for(var x=0; x<TP.load_bulk_ids.length; x++) {
            if(TP.load_bulk_ids[x] == id) {
                return;
            }
        }

        TP.load_bulk_ids.push(id);
        TP.load_bulk_callbacks.push(callback);

        window.clearTimeout(TP.timeouts['timeout_bulk_load']);
        TP.timeouts['timeout_bulk_load'] = window.setTimeout(function() {
            var ids       = TP.load_bulk_ids
            var callbacks = TP.load_bulk_callbacks;
            TP.load_bulk_ids       = [];
            TP.load_bulk_callbacks = [];
            TP.add_pantab_bulk_hidden(ids, callbacks);
        }, 3000);
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
        var pan = Ext.getCmp('tabbar');
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
            var text = "";
            try {
                delete config['tb'];
                text = Ext.JSON.encode(config);
            } catch(err) {
                text = ""+err;
            }
            var err  = new Error("no type in "+text);
            TP.logError("global", "noTypeException", err);
            throw err;
        }
        // fake state (probably cloned)
        if(config.state) {
            TP.cp.set(config.conf.id, config.state);
        }
        TP.log('['+tb.id+'] add_panlet - type: '+config.type+', '+Ext.JSON.encode(config.conf));
        config.conf.tab = tb;

        // does this widget class exist?
        if(!Ext.ClassManager.get(config.type)) {
            TP.Msg.msg("fail_message~~cannot create panel of type: "+config.type+". Thruk version conflict?");
            return;
        }

        try {
            var win = Ext.create(config.type, config.conf);
        } catch(err) {
            TP.logError("global", "panelCreateException", err);
            throw err;
        }
        if(config.conf.autoShow) { win.show(); }
        if((smartPlacement == undefined || smartPlacement == true) && !(config.conf.pos)) {
            pan.setActiveTab(tb); /* otherwise panel won't be rendered and panel size is 0 */
            TP.fitWindowPlacement(tb, win);
        }
        if(!config.skip_state) {
            tb.window_ids.push(win.id);
            tb.saveState();
            win.firstRun = false;
        }
        return win;
    },

    /* choose position handler */
    add_panlet_handler: function(evt, element, args) {
        var tb = args[0], config = args[1], offsetX = args[2], offsetY = args[3], pos = args[4], el = args[5];
        if(el == undefined) { el = tb.getEl(); }
        el.un('click', TP.add_panlet_handler, this, args); // remove event handler again
        tb.enableMapControlsTemp();
        if(config.conf == undefined) { config.conf = {}; }
        if(pos != undefined) {
            config.conf.pos = pos;
        } else {
            config.conf.pos = [evt.getX()+offsetX, evt.getY()+offsetY];
        }
        el.dom.style.cursor = '';
        el.dom.style.zIndex = el.oldZindex;
        delete el.oldZindex;
        config.autoshow = true;
        var panel = TP.add_panlet(config);
        panel.firstRun = true;
        if(panel.iconType) {
            TP.updateAllIcons(tb, panel.id);
        } else {
            panel.refreshHandler();
            panel.setPosition(config.conf.pos[0], config.conf.pos[1]);
        }
    },

    /* add panel, but let the user choose position */
    add_panlet_delayed: function(config, offsetX, offsetY) {
        var tb;
        var pan = Ext.getCmp('tabbar');
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
        var el = tb.getEl();
        if(tb.bgDragEl) {
            el = tb.bgDragEl;
        }
        el.dom.style.cursor = 'crosshair';
        el.oldZindex = el.dom.style.zIndex;
        el.dom.style.zIndex = 100000;
        el.on('click', TP.add_panlet_handler, tb, [tb, config, offsetX, offsetY, undefined, el]);
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
            TP.updateAllIcons(panel.tab);
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
        new Ext.window.Window({
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
            throw new Error("TP.getAllPanel(): no tab!");
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
                    var c = checked[nr];
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
        /* sort by name */
        data = Ext.Array.sort(data, function(a,b) { return(a[1].toLowerCase() > b[1].toLowerCase()) });
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
            var tab = panel.tab;
            baseParams['backends'] = TP.getActiveBackendsPanel(tab, panel);

            // update proc info?
            baseParams['update_proc'] = TP.setUpdateProcInfo();
            baseParams['current_tab'] = panel.tab.id;
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
        if(!res || res.length <= 2) {
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
        /* strip off comments */
        data = data.replace(/\s*\#.*/g, '').replace(/[\n\r]/g, '');
        var decoded;
        try {
            decoded = TP.cp.decodeValue(decode64(data));
        }
        catch(err) {
            TP.logError("global", "importAllTabsException", err);
            Ext.MessageBox.alert('Failed', 'Import Failed!\nThis seems to be an invalid dashboard export.');
            return(false);
        }
        if(decoded == null) {
            try {
                decoded = Ext.JSON.decode(decode64(data));
            }
            catch(err) {
                TP.logError("global", "jsonDecodeException", err);
                Ext.MessageBox.alert('Failed', 'Import Failed!\nThis seems to be an invalid dashboard export.');
                return(false);
            }
        }
        if(decoded == undefined || decoded == '') {
            Ext.MessageBox.alert('Failed', 'Import Failed!\nThis seems to be an invalid dashboard export.');
            return(false);
        }
        if(decoded == '') { decoded = {}; }

        /* stop everything */
        var tabbar = Ext.getCmp('tabbar');

        if(decoded.tabbar) {
            /* old export with all tabs*/
            TP.cp.saveChanges(undefined, function() {
                Ext.Msg.confirm(
                    'Confirm Import',
                    'This is a complete import which will replace your current view with the exported one.<br>Your current open dashboards will be closed and can be added again afterwards.',
                    function(button) {
                        if(button === 'yes') {
                            tabbar.stopTimeouts();
                            TP.cp.loadData(decoded);
                            TP.cp.saveChanges({replace: 1}, function() {
                                Ext.MessageBox.alert('Success', 'Import Successful!<br>Please wait while page reloads...');
                                TP.initialized = false; // prevents onUnload saving over our imported tabs
                                TP.timeouts['timeout_window_reload'] = window.setTimeout(function() { window.location.reload(); }, 1000);
                            });
                        }
                    }
                );
            });
        } else {
            /* new single tab export */
            var param = {
                task:    'update2',
                nr:      'new',
                pantab_1: Ext.JSON.encode(decoded)
            };
            var conn = new Ext.data.Connection();
            conn.request({
                url:    'panorama.cgi?state',
                params:  param,
                success: function(response, opts) {
                    /* allow response to contain cookie messages */
                    var resp = TP.getResponse(undefined, response, false);
                    if(resp.newid) {
                        TP.initial_active_tab = TP.nr2TabId(resp.newid);
                        TP.add_pantab({ id: resp.newid });
                    } else {
                        Ext.MessageBox.alert('Failed', 'Import Failed!\nThis seems to be an invalid dashboard export.');
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
                if(refresh.setType) { refresh.setType('broken'); }
                TP.logError(panlet ? panlet.id : '??', "responseEvalException", err);
                return data;
            }
            if(refresh.setType) { refresh.setType('refresh'); }
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

            if(data && data.broadcasts) {
                TP.showBroadcasts(data.broadcasts);
            }

            if(data && !TP.already_reloading) {
                if(data.server_version != undefined && thruk_version != data.server_version) {
                    TP.already_reloading = true;
                    TP.Msg.msg("info_message~~Server version has changed: "+thruk_version+" -> "+data.server_version+"<br>Panorama dashboard will be reloaded...");
                    window.setTimeout(TP.fullReload, 5000);
                }
                else if(data.server_extra_version != undefined && thruk_extra_version != data.server_extra_version) {
                    TP.already_reloading = true;
                    TP.Msg.msg("info_message~~Server version has changed: "+thruk_version+"~"+thruk_extra_version+" -> "+data.server_version+"~"+data.server_extra_version+"<br>Panorama dashboard will be reloaded...");
                    window.setTimeout(TP.fullReload, 5000);
                }
            }

            if(data && data.dashboard_ts != undefined && !TP.cp.isSaving) {
                for(var key in data.dashboard_ts) {
                    var tab_id = TP.nr2TabId(key);
                    var tab = Ext.getCmp(tab_id);
                    if(!tab) {
                        // dashboard has been closed already
                        return;
                    }
                    if(data.dashboard_ts[key] != tab.ts) {
                        var old = tab.ts ? tab.ts : '';
                        tab.ts = data.dashboard_ts[key];
                        if((no_ts == undefined || no_ts == false) && old < tab.ts) {
                            TP.log('['+tab.id+'] tab timestamp has changed - old: '+old+', new: '+data.dashboard_ts[key]);
                            if(tab.rendered) {
                                TP.renewDashboard(tab);
                            } else {
                                TP.add_pantab({ id: tab.id, hidden: true });
                            }
                        }
                    }
                }
            }

            // response contains maintenance modes
            if(data && data.maintenance != undefined) {
                for(var key in data.maintenance) {
                    var tab_id = TP.nr2TabId(key);
                    var tab = Ext.getCmp(tab_id);
                    if(tab) {
                        tab.setMaintenance(data.maintenance[key], false);
                    }
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
        if(refresh.setType) { refresh.setType('broken'); }
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
        var tabbar = Ext.getCmp('tabbar');
        this.stopRotatingTabs();
        if(tabbar.xdata.rotate_tabs > 0) {
            debug("starting tab rotation every " + tabbar.xdata.rotate_tabs + "seconds");
            TP.timeouts['interval_global_rotate_tabs'] = window.setInterval(TP.rotateTabs, tabbar.xdata.rotate_tabs * 1000);
        }
    },
    /* start server time */
    startServerTime: function() {
        var tabbar = Ext.getCmp('tabbar');
        this.stopServerTime();
        var label = Ext.getCmp('server_time');
        if(!tabbar.xdata.server_time) {
            label.hide();
            return;
        }
        label.show();
        TP.timeouts['interval_global_servertime'] = window.setInterval(TP.updateServerTime, 1000);
    },
    stopServerTime: function() {
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
    /* returns current server time in unix seconds */
    serverTime: function() {
        var client = new Date();
        var time   = Math.floor((client.getTime() - delta_time) / 1000);
        return(time);
    },
    /* stop tab rotation interval */
    stopRotatingTabs: function() {
        window.clearInterval(TP.timeouts['interval_global_rotate_tabs']);
    },
    /* rotate tabs once */
    rotateTabs: function() {
        var tabbar = Ext.getCmp('tabbar');
        var at     = tabbar.getActiveTab();
        // find next tab
        var found = false;
        var next  = undefined;
        tabbar.items.each(function(tab) {
            if(found == true) {
                next = tab.id;
                return false;
            }
            if(tab.id == at.id) {
                found = true;
            }
        });
        if(next == undefined || !tabbar.setActiveTab(next)) {
            tabbar.setActiveTab(1);
        }
    },
    addTabBarMouseEvents: function(el, tabId) {
        el.on("dblclick", function(evt, el, o) {
            TP.tabSettingsWindow();
        });
        el.on("contextmenu", function(evt, el, o) {
            var tab = Ext.getCmp(tabId);
            tab.contextmenu(evt, true, true);
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
    addGearBackgroundOptions: function(panel) {
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
    },
    /* convert number to binary list */
    dec2bin: function(dec) {
        var potencies = new Array();
        var binary = [];
        for (var i = 0; i < 100; i++) {
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
        cookieSave("thruk_screen", JSON.stringify(getScreenData()));
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
            value:          value
        });
    },
    removeWindowFromPanels: function(win_id) {
        /* remove panel reference */
        var panel = Ext.getCmp(win_id);
        var tab   = panel.tab;
        if(tab && tab.window_ids) {
            tab.window_ids = TP.removeFromList(tab.window_ids, win_id);
            tab.saveState();
        }
    },
    updateAllIcons: function(tab, id, xdata, reschedule, callback) {
        if(id != undefined) {
            TP.updateAllIconsDo(tab, id, xdata, reschedule, callback);
        } else {
            /* avoid duplicate updates */
            window.clearTimeout(TP.timeouts['timeout_global_icon_update'+tab.id]);
            TP.timeouts['timeout_global_icon_update'+tab.id] = window.setTimeout(function() {
                TP.updateAllIconsDo(tab, undefined, undefined, undefined, callback);
            }, 300);
        }
    },
    updateAllIconsDo: function(tab, id, xdata, reschedule, callback) {
        if(!TP.iconUpdateRunning) { TP.iconUpdateRunning = {}; }
        if(TP.iconUpdateRunning[tab.id]) { return; }

        // background tabs are refreshed separately
        if(!tab.rendered) { return; }

        // background tab, do not refresh unnecessarily unless focus was gone a few moments ago (3min), but refresh at least every 3 hours
        if(document.visibilityState && document.visibilityState != 'visible' && thrukState.lastPageFocus < ((new Date).getTime() - 180000)) {
            //} && thrukState.lastPageLoaded > ((new Date).getTime() - (3*3600*1000))) {
            return;
        }

        /* Delay update if not all icons are rendered yet.
         * Those icons would be missing from getStatusReq()
         */
        if(id == undefined && tab.window_ids.length > 0 && TP.getAllPanel(tab).length < tab.window_ids.length) {
            TP.updateAllIcons(tab, id, xdata, reschedule, callback);
            return;
        }

        var panels = TP.getAllPanel(tab);
        if(panels.length < 50 || id != undefined) {
            return(TP.updateAllIconsBulkDo(tab, id, xdata, reschedule, callback));
        }

        // fetch 20 icons at a time, otherwise we might get timeouts from the backends
        var bucket  = {}
        var items   = 0;
        var items_per_bucket = 20;
        for(var nr=0; nr<panels.length; nr++) {
            items++;
            bucket[panels[nr].id] = true;
            if(items >= items_per_bucket) {
                if(nr == panels.length-1) {
                    // run the last bulk with callback and update sub dashboards
                    TP.updateAllIconsBulkDo(tab, bucket, xdata, reschedule, callback, true);
                } else {
                    TP.updateAllIconsBulkDo(tab, bucket, xdata, reschedule);
                }
                bucket = [];
                items  = 0;
            }
        }
        if(items > 0) {
            // run the last bulk with callback and update sub dashboards
            TP.updateAllIconsBulkDo(tab, bucket, xdata, reschedule, callback, true);
        }
    },

    updateAllIconsBulkDo: function(tab, ids, xdata, reschedule, callback, withSubDashboards) {
        var statusReq = TP.getStatusReq(tab, ids, xdata);
        if(statusReq == undefined) {
            if(tab) { tab.removeMask(); }
            if(callback) { callback(); }
            return;
        }
        var id;
        if(ids && !Ext.isArray(ids)) {
            id = ids;
        }

        var req = statusReq.req,
            ref = statusReq.ref;

        TP.log('['+tab.id+'] updateAllIconsDo'+(id ? ' (id: '+id+')' : ''));
        var params = {
            types:       Ext.JSON.encode(req),
            backends:    TP.getActiveBackendsPanel(tab),
            update_proc: TP.setUpdateProcInfo(),
            current_tab: tab.id,
            reschedule:  reschedule ? 1 : '',
            state_type:  tab.xdata.state_type,
            CSRFtoken:   CSRFtoken
        };
        TP.iconUpdateRunning[tab.id] = true;
        if(!id) {
            tab.last_full_refresh = (new Date()).getTime();
        }
        var subReqs = {};
        if(!id || withSubDashboards) {
            // add dashboard icons status request
            params.sub = {};
            var subtabs = tab.getAllSubDashboards(true);
            for(var x=0; x<subtabs.length; x++) {
                var subtab_id = TP.nr2TabId(subtabs[x]);
                var subtab    = Ext.getCmp(subtab_id);
                if(!subtab) {
                    TP.add_pantab({ id: subtab_id, hidden: true, callback: function(subtab_id) {
                        var subtab = Ext.getCmp(subtab_id);
                        if(!subtab) {
                            TP.log('['+subtab_id+'] failed to load dashboard');
                        }
                    }});
                }
                if(subtab && !subtab.rendered) {
                    var subreq = TP.getStatusReq(subtab);
                    if(subreq) {
                        TP.iconUpdateRunning[subtab.id] = true;
                        params.sub[subtab.id] = {
                            types:       subreq.req,
                            backends:    TP.getActiveBackendsPanel(subtab),
                            current_tab: subtab.id,
                            state_type:  subtab.xdata.state_type
                        };
                        subReqs[subtab.id] = { tab: subtab, ref: subreq.ref };
                    }
                }
            }
            params.sub = Ext.JSON.encode(params.sub);
        }

        Ext.Ajax.request({
            url: 'panorama.cgi?task=status',
            method: 'POST',
            params: params,
            callback: function(options, success, response) {
                tab = Ext.getCmp(tab.id);
                TP.iconUpdateRunning[tab.id] = false;
                if(reschedule) { reschedule.unmask(); }
                if(tab) { tab.removeMask(); }
                if(!success) {
                    if(TP.refresh_errors == undefined) { TP.refresh_errors = 0; }
                    TP.refresh_errors++;
                    /* ignore first errors, maybe caused by a reload */
                    if(TP.refresh_errors > 2) {
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
                    if(!data || !data.data) {
                        if(callback) { callback(); }
                        return;
                    }
                    // first insert sub dashboards if there are some
                    for(var key in subReqs) {
                        TP.insertStatusResponseData(subReqs[key].tab, data.data.sub[key], subReqs[key].ref);
                        TP.iconUpdateRunning[key] = false;
                    }
                    // then calculate own status
                    if(!tab.renewInProgress) {
                        TP.insertStatusResponseData(tab, data.data, ref);
                    }
                }

                if(!tab.renewInProgress) {
                    TP.checkSoundAlerts(tab);
                }

                /* run callback */
                if(callback) { callback(); }
            }
        });
    },

    insertStatusResponseData: function(tab, data, ref) {
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
                    if(data.hosts[x]['state_type'] == 0 && tab.xdata.state_type == "hard") { state = 0; }
                    for(var y=0; y<ref.hosts[name].length; y++) {
                        /* update host object but keep trend values */
                        if(ref.hosts[name][y].host) {
                            var lastTrend = ref.hosts[name][y].host.trend;
                            if(lastTrend) { data.hosts[x].trend = lastTrend; }
                        }

                        delete ref.hosts[name][y]['no_data'];
                        ref.hosts[name][y].host = data.hosts[x];
                        ref.hosts[name][y].lastState = state;
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
                if(ref.hostgroups[name]) { // may be empty if we get the same hostgroup twice in a result
                    for(var y=0; y<ref.hostgroups[name].length; y++) {
                        delete ref.hostgroups[name][y]['no_data'];
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
                if(ref.servicegroups[name]) { // may be empty if we get the same servicegroup twice in a result
                    for(var y=0; y<ref.servicegroups[name].length; y++) {
                        delete ref.servicegroups[name][y]['no_data'];
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
                if(data.services[x]['state_type'] == 0 && tab.xdata.state_type == "hard") { state = 0; }
                if(ref.services[hst] && ref.services[hst][svc]) { // may be empty if we get the same service twice in a result
                    for(var y=0; y<ref.services[hst][svc].length; y++) {
                        /* update service object but keep trend values */
                        if(ref.services[hst][svc][y].service) {
                            var lastTrend = ref.services[hst][svc][y].service.trend;
                            if(lastTrend) { data.services[x].trend = lastTrend; }
                        }

                        delete ref.services[hst][svc][y]['no_data'];
                        ref.services[hst][svc][y].service = data.services[x];
                        ref.services[hst][svc][y].lastState = state;
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
                        delete ref.sites[name][x]['no_data'];
                        ref.sites[name][x].site = data.backends[key];
                        ref.sites[name][x].refreshHandler();
                    }
                }
                delete ref.sites[name];
            }
        }

        /* update all dashboard/map icons */
        for(var key in ref.dashboards) {
            for(var x=0; x<ref.dashboards[key].length; x++) {
                var p = ref.dashboards[key][x];
                p.refreshHandler(undefined, true);
            }
            delete ref.dashboards[key];
        }

        /* mark remaining as unknown */
        var keys = ['hosts', 'hostgroups', 'servicegroups', 'sites', 'filter'];
        for(var x=0; x<keys.length; x++) {
            var name = keys[x];
            for(var key in ref[name]) {
                for(var y=0; y<ref[name][key].length; y++) {
                    ref[name][key][y]['no_data'] = true;
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
        /* mark unknown services */
        for(var key in ref.services) {
            for(var key2 in ref.services[key]) {
                for(var y=0; y<ref.services[key][key2].length; y++) {
                    ref.services[key][key2][y]['no_data'] = true;
                    ref.services[key][key2][y].refreshHandler(3);
                    delete ref.services[key][key2][y]['service'];
                }
            }
        }
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
        var req = statusReq.req;

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
    getStatusReq: function(tab, ids, xdata) {
        var panels = TP.getAllPanel(tab);
        var req    = { filter: {}, hosts: {}, hostgroups: {}, services: {}, servicegroups: {}, has_long_plugin_output: false };
        var ref    = { filter: {}, hosts: {}, hostgroups: {}, services: {}, servicegroups: {}, sites: {}, dashboards: {} };

        var count  = 0;
        if(ids && typeof(ids) == "string") {
            var id = ids;
            ids = {};
            ids[id] = true;
        }
        for(var nr=0; nr<panels.length; nr++) {
            var p = panels[nr];
            if(ids && !ids[p.id]) { continue; }
            if(ids && xdata) { p.oldXdata = p.xdata; p.xdata = xdata; }
            if(p.xdata && p.xdata.general) {
                /* custom filter */
                if(p.xdata.general.filter) {
                    var backends = TP.getActiveBackendsPanel(tab, p);
                    var filter = Ext.JSON.encode([p.xdata.general.incl_hst, p.xdata.general.incl_svc, p.xdata.general.filter, backends]);
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
                    if(p.xdata.label && p.xdata.label.labeltext && p.xdata.label.labeltext.match("long_plugin_output")) {
                        req.has_long_plugin_output = true;
                    }
                    req.services[p.xdata.general.host][p.xdata.general.service].push(p.id);
                    ref.services[p.xdata.general.host][p.xdata.general.service].push(p);
                    count++;
                }
                /* update hosts */
                else if(p.xdata.general.host) {
                    if(ref.hosts[p.xdata.general.host] == undefined) { ref.hosts[p.xdata.general.host] = []; }
                    if(req.hosts[p.xdata.general.host] == undefined) { req.hosts[p.xdata.general.host] = []; }
                    if(p.xdata.label && p.xdata.label.labeltext && p.xdata.label.labeltext.match("long_plugin_output")) {
                        req.has_long_plugin_output = true;
                    }
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
                /* update dashboards */
                else if(p.xdata.general.dashboard) {
                    var tab_id = TP.nr2TabId(p.xdata.general.dashboard);
                    if(ref.dashboards[tab_id] == undefined) { ref.dashboards[tab_id] = []; }
                    ref.dashboards[tab_id].push(p);
                    count++;
                }
            }
            if(ids && p.oldXdata) { p.xdata = p.oldXdata; delete p.oldXdata; }
        };
        var tabbar = Ext.getCmp('tabbar');
        if(count == 0 && tab != tabbar.getActiveTab()) { return; }
        return({req: req, ref: ref });
    },

    /* let this element flicker and make it a little bit bigger */
    flickerImg: function(dom_id, callback) {
        var el     = Ext.get(dom_id);
        if(!el) { return; }

        el.animate({ to: { opacity: 0   } })
          .animate({ to: { opacity: 100 } })
          .animate({ to: { opacity: 0   } })
          .animate({ to: { opacity: 100 } })
          .animate({ to: { opacity: 0   } })
          .animate({ to: { opacity: 100 } })
          .animate({ to: { opacity: 0   } })
          .animate({ to: { opacity: 100 } })
          .animate({ to: { opacity: 0   } })
          .animate({ to: { opacity: 100 },
                     callback: function() { if(callback) callback(); }
                   });
    },

    /* toggle or set a dashboard option */
    toggleDashboardOption: function(nr, field, value) {
        if(value == undefined) { value = 'toggle'; }
        Ext.Ajax.request({
            url: 'panorama.cgi?task=dashboard_update',
            method: 'POST',
            params: { nr: nr, action: 'update', field: field, value: value },
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
        /* update dashboard management view */
        if(TP.dashboardsSettingWindow && TP.dashboardsSettingGrid && TP.dashboardsSettingGrid.getView) {
            TP.dashboardsSettingGrid.getView().refresh();
        }

        var tab = Ext.getCmp(nr);
        if(tab == undefined) { return; }

        Ext.Ajax.request({
            url: 'panorama.cgi?task=dashboard_data',
            method: 'POST',
            params: { nr: nr },
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
                        TP.cp.set(key, anyDecode(data[key]));
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
                Ext.Msg.confirm('Really Remove?', 'Do you really want to remove this dashboard with all its windows?', function(button) {
                    if(button === 'yes') {
                        TP.dashboardActionHandler(grid, rowIndex, colIndex, item, evt, record, row, 1);
                    }
                });
                return false;
            }
            Ext.Ajax.request({
                url: 'panorama.cgi?task=dashboard_update',
                method: 'POST',
                params: { nr: nr, action: action },
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
            return false;
        }
        else if(action == 'edit') {
            TP.tabSettingsWindow(nr);
        }
        return false;
    },

    /* returns list of currently active backends for given panel */
    getActiveBackendsPanel: function(tab, panel) {
        var backends;
        if(panel && panel.xdata && panel.xdata.backends && panel.xdata.backends.length > 0 && (panel.xdata.backends.length != 1 || panel.xdata.backends[0] != "")) {
            backends = panel.xdata.backends;
        }
        else if(panel && panel.xdata && panel.xdata.general && panel.xdata.general.backends && panel.xdata.general.backends.length > 0 && (panel.xdata.general.backends.length != 1 || panel.xdata.general.backends[0] != "")) {
            backends = panel.xdata.general.backends;
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
        if(url == null || url == "null") { return; }
        console.log("playing sound: "+url);
        var el = Ext.DomHelper.insertFirst(document.body, '<audio src="'+url+'" />' , true);
        el.dom.addEventListener('ended', function() {
            if(endedCallback) {
                endedCallback();
            }
        });
        el.dom.addEventListener('error', function(a,b,c,d) {
            TP.Msg.msg("fail_message~~failed to play sound file.");
            if(endedCallback) {
                endedCallback();
            }
        });
        el.dom.play();
    },
    /* put a new alert onto the queue */
    checkSoundAlerts: function(tab) {
        var order = ['unreachable', 'down', 'critical', 'warning', 'unknown', 'recovery'];
        var tab_id = tab.id;
        if(tab_id == 0) { return; }

        /* check if any sound is enabled */
        var enabled = 0;
        for(var x=0; x<order.length; x++) {
            if(tab.xdata[order[x]+'_sound'] != "") { enabled++; }
        }
        if(enabled == 0) { return; }

        // see if this dashboard is only loaded to recalculate its status
        if(tab.hidden) { return; }

        if(TP.alertTotals == undefined) { TP.alertTotals = {}; }
        var totals = {recovery: 0, warning: 0, critical: 0, unknown: 0, down: 0, unreachable: 0};

        var panels = TP.getAllPanel(tab);
        for(var nr=0; nr<panels.length; nr++) {
            var p = panels[nr];
            if(p.iconType && p.xdata) {
                var alertState = p.xdata.state;
                if(p.acknowledged || p.downtime) { alertState = 0; }
                if(p.iconType == 'host' || p.hostProblem) {
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

        if(TP.alertNumbers         == undefined) { TP.alertNumbers         = {}; }
        if(TP.alertNumbers[tab_id] == undefined) { TP.alertNumbers[tab_id] = {recovery: 0, warning: 0, critical: 0, unknown: 0, down: 0, unreachable: 0}; }

        /* inital display does not alert */
        if(TP.alertTotals[tab_id] == undefined) {
            TP.alertTotals[tab_id] = totals;
            TP.alertNumbers[tab_id]["recovery"] = 1; // do not send initial recovery alerts
            return;
        }

        for(var x=0; x<order.length; x++) {
            var name = order[x];
            /* sounds enabled and there are alerts */
            if(tab.xdata[name+'_sound'] != "" && totals[name] > 0) {
                /* repeat enabled or new alerts */
                if(tab.xdata[name+'_repeat'] == undefined) { tab.xdata[name+'_repeat'] = 1; } // don't repeat if not set, ex.: recoveries
                if(   totals[name] > TP.alertTotals[tab_id][name]
                   || tab.xdata[name+'_repeat'] == 0 // forever
                   || tab.xdata[name+'_repeat'] > TP.alertNumbers[tab_id][name])
                {
                    var tabbar = Ext.getCmp('tabbar');
                    if(tabbar.xdata.sounds_enabled) {
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
    /* calculate state for tab */
    getTabState: function(tab_id, incl_ack, incl_downtimes) {
        var tab = Ext.getCmp(tab_id);
        if(!tab) {
            return;
        }
        var group = TP.getTabTotals(tab);
        var res = TP.get_group_status({ group: group, incl_svc: true, incl_hst: true, incl_ack: incl_ack, incl_downtimes: incl_downtimes, order: tab.xdata.state_order});
        if(tab.isMaintenance()) {
            res.downtime = true;
        }
        return(res);
    },
    getTabTotals: function(tab) {
        /* convert icon states into a hash used by hostgroup icons so we can use that state calculation later */
        var group = { services: {      total: 0,
                                          ok: 0,          warning: 0,          critical: 0,          unknown: 0,       pending: 0,
                                    plain_ok: 0,    plain_warning: 0,    plain_critical: 0,    plain_unknown: 0, plain_pending: 0,
                                                      ack_warning: 0,      ack_critical: 0,      ack_unknown: 0,
                                 downtime_ok: 0, downtime_warning: 0, downtime_critical: 0, downtime_unknown: 0
                                },
                      hosts:    {      total: 0,
                                          up: 0,          down: 0,          unreachable: 0,       pending: 0,
                                    plain_up: 0,    plain_down: 0,    plain_unreachable: 0, plain_pending: 0,
                                                      ack_down: 0,      ack_unreachable: 0,
                                 downtime_up: 0, downtime_down: 0, downtime_unreachable: 0
                                }
        };

        var panels = TP.getAllPanel(tab);
        if(tab.window_ids.length != panels.length) {
            tab.createInitialPanlets(0, false);
        }
        for(var nr=0; nr<panels.length; nr++) {
            var p = panels[nr];
            if(p.iconType && p.xdata && p.iconType != "text" && p.iconType != "image") {
                if(p.iconType == 'host' || p.hostProblem) {
                    group.hosts.total++;
                         if(p.xdata.state == 0) { group.hosts.up++; }
                    else if(p.xdata.state == 1) { group.hosts.down++; }
                    else if(p.xdata.state == 2) { group.hosts.unreachable++; }
                    else if(p.xdata.state == 3) { group.services.unknown++; } /* there is no unknown host state but the icon might be unknown for missing hosts */
                    else if(p.xdata.state == 4) { group.hosts.pending++; }
                    if(p.acknowledged) {
                            if(p.xdata.state == 1) { group.hosts.ack_down++; }
                       else if(p.xdata.state == 2) { group.hosts.ack_unreachable++; }
                    }
                    if(p.downtime) {
                            if(p.xdata.state == 0) { group.hosts.downtime_up++; }
                       else if(p.xdata.state == 1) { group.hosts.downtime_down++; }
                       else if(p.xdata.state == 2) { group.hosts.downtime_unreachable++; }
                    }
                    if(!p.acknowledged && !p.downtime) {
                            if(p.xdata.state == 0) { group.hosts.plain_up++; }
                       else if(p.xdata.state == 1) { group.hosts.plain_down++; }
                       else if(p.xdata.state == 2) { group.hosts.plain_unreachable++; }
                       else if(p.xdata.state == 3) { group.services.plain_unknown++; } /* same as above, count missing hosts as unknown */
                       else if(p.xdata.state == 4) { group.hosts.plain_pending++; }
                    }
                } else {
                    group.services.total++;
                         if(p.xdata.state == 0) { group.services.ok++; }
                    else if(p.xdata.state == 1) { group.services.warning++; }
                    else if(p.xdata.state == 2) { group.services.critical++; }
                    else if(p.xdata.state == 3) { group.services.unknown++; }
                    else if(p.xdata.state == 4) { group.services.pending++; }
                    if(p.acknowledged) {
                            if(p.xdata.state == 1) { group.services.ack_warning++; }
                       else if(p.xdata.state == 2) { group.services.ack_critical++; }
                       else if(p.xdata.state == 3) { group.services.ack_unknown++; }
                    }
                    if(p.downtime) {
                            if(p.xdata.state == 0) { group.services.downtime_ok++; }
                       else if(p.xdata.state == 1) { group.services.downtime_warning++; }
                       else if(p.xdata.state == 2) { group.services.downtime_critical++; }
                       else if(p.xdata.state == 3) { group.services.downtime_unknown++; }
                    }
                    if(!p.acknowledged && !p.downtime) {
                            if(p.xdata.state == 0) { group.services.plain_ok++; }
                       else if(p.xdata.state == 1) { group.services.plain_warning++; }
                       else if(p.xdata.state == 2) { group.services.plain_critical++; }
                       else if(p.xdata.state == 3) { group.services.plain_unknown++; }
                       else if(p.xdata.state == 4) { group.services.plain_pending++; }
                    }
                }
            }
        }
        return(group);
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
    renewDashboardDo: function(tab, callback) {
        // reschedule if state provider is saving right now, this might result in race conditions
        if(TP.cp.isSaving) {
            return TP.renewDashboard(tab);
        }
        TP.log('['+tab.id+'] renewDashboardDo');
        var duration = 1000;
        tab.addMask("updating dashboard");
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
                    var panlet_added_ids = {};

                    /* make sure tab itself is updated first */
                    var mapChanged = false;
                    for(var key in data) {
                        var cfg = anyDecode(data[key]);
                        var p   = Ext.getCmp(key);
                        if(p && key.match(/^pantab_/) && !key.match(/^pantab_.*_panlet_\d+/)) {
                            if((p.xdata.map && !cfg.xdata.map) || (!p.xdata.map && cfg.xdata.map)) { mapChanged = true; }
                            /* changes in our dashboard itself */
                            Ext.apply(p, cfg);
                            p.applyXdata();
                            p.forceSaveState();
                        }
                    }

                    if(mapChanged) {
                        tab.destroyPanlets();
                    }

                    for(var key in data) {
                        var cfg = anyDecode(data[key]);
                        var p   = Ext.getCmp(key);

                        if((key.match(/pantab_/) && !key.match(/pantab_.*_panlet_\d+/)) || key == "tabbar") {
                            /* tab has been updated already */
                            continue;
                        }

                        /* panel class changed */
                        if(p && (cfg.xdata.cls != p.xdata.cls || mapChanged)) {
                            TP.cp.set(p.id, cfg);
                            TP.redraw_panlet(p, tab);
                            continue;
                        }

                        /* panel does not yet exist */
                        if(TP.cp.get(key) == undefined) {
                            TP.cp.set(key, cfg);
                            TP.add_panlet({id:key, tb:tab, autoshow:true, conf: { firstRun:false }}, false);
                            tab.saveState();
                            panlet_added_ids[key] = true;
                        }
                        else if(p && !TP.JSONequals(TP.cp.get(key), data[key])) {
                            /* position and size changes can be applied by animation */
                            Ext.apply(p, cfg);
                            TP.cp.set(key, cfg);
                            if(p.applyAnimated && p.rendered) {
                                p.applyAnimated({duration:duration});
                                if(p.applyXdata) {
                                    window.setTimeout(Ext.bind(p.applyXdata, p, [cfg.xdata]), duration+100);
                                }
                            } else {
                                if(p.applyXdata) {
                                    p.applyXdata(cfg.xdata);
                                }
                            }
                        }
                    }
                    /* remove no longer existing panlets */
                    for(var x=0; x<old_window_ids.length; x++) {
                        var id = old_window_ids[x];
                        if(data[id] == undefined) {
                            var p = Ext.getCmp(id);
                            // remove unless this is ex. an host/service extinfo detail panel openened by the user
                            if(p && !p.userOpened) {
                                p.destroy();
                            }
                        }
                    }
                    /* update stateproviders last data to prevent useless updates */
                    TP.cp.lastdata = setStateByTab(TP.cp.state);
                    tab.renewInProgress = false;

                    if(panlet_added_ids.length > 0) {
                        TP.updateAllIcons(tab, panlet_added_ids);
                    }
                } else {
                    tab.renewInProgress = false;
                }
                if(callback) {
                    callback(success);
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
        panel.appearance.shapeRender(tmppanel.xdata, panel.xdata.appearance.color_ok, tmppanel);
        list.push(tmppanel);
    },
    fullReload: function() {
        TP.log('[global] full reload');
        // save current dashboards to a cookie, otherwise we would display something else after the reload
        Ext.getCmp('tabbar').getState();
        reloadPage(50, false, true, url_prefix+'cgi-bin/extinfo.cgi?type=0', 300);
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
    JSONequals: function(any1, any2) {
        if(!any1) {
            return(false);
        }
        if(any2 != any1) {
            if(any1.length != any2.length) {
                return(false);
            }
            var dec1 = anyDecode(any1);
            var dec2 = anyDecode(any2);
            var keys = {};
            Ext.Array.forEach(Ext.Object.getKeys(dec1).concat(Ext.Object.getKeys(dec2)), function(n, i) {
                keys[n] = true;
            });
            for(var key2 in keys) {
                var obj1 = anyDecode(dec1[key2]);
                var obj2 = anyDecode(dec2[key2]);
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
        nr = String(nr).replace(/^pantab_/, '');
        nr = "pantab_"+nr;
        return(nr);
    },
    reduceDelayEvents: function(scope, callback, delay, timeoutName, skipInitialRun) {
        var now = (new Date()).getTime();
        if(!scope) {
            /* probably out of scope already, run it a last time */
            callback();
            return;
        }
        if(!scope.lastEventRun)              { scope.lastEventRun = {}; }
        if(!scope.lastEventRun[timeoutName]) { scope.lastEventRun[timeoutName] = 0; }
        window.clearTimeout(TP.timeouts[timeoutName]);
        if(now > scope.lastEventRun[timeoutName] + delay && !skipInitialRun) {
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
    /* calls function delayed and removes duplicate calls till then */
    delayEvents: function(scope, callback, delay, timeoutName) {
        if(!scope) {
            /* out of scope already, nothing to do */
            return;
        }
        window.clearTimeout(TP.timeouts[timeoutName]);
        TP.timeouts[timeoutName] = window.setTimeout(function() {
            if(scope) {
                callback();
            }
        }, delay);
    },
    /* return true if there are any masks visible */
    masksVisible: function() {
        var masks = Ext.Element.select('.x-mask');
        if(masks.elements.length > 0) {
            for(var nr=0; nr<masks.elements.length; nr++) {
                if(masks.elements[nr].style.display != "none") {
                    return(true);
                }
            }
        }
        return(false);
    },
    median: function(values) {
        values.sort( function(a,b) {return a - b;} );
        var half = Math.floor(values.length/2);
        if(values.length % 2)
            return values[half];
        else
            return (values[half-1] + values[half]) / 2.0;
    },
    getAllUsedColors: function() {
        var colors = {};
        var tabbar = Ext.getCmp('tabbar');
        var tab    = tabbar.getActiveTab();
        if(!tab) { return; }
        for(var nr=0; nr<tab.window_ids.length; nr++) {
            var panel = Ext.getCmp(tab.window_ids[nr]);
            if(panel) {
                TP.getAllColorsInStructure(panel.xdata, colors);
            }
        }
        if(TP.iconSettingsWindow && TP.iconSettingsWindow.panel) {
            var xdata = TP.get_icon_form_xdata(TP.iconSettingsWindow);
            TP.getAllColorsInStructure(xdata, colors);
        }
        return(Ext.Object.getKeys(colors).sort());
    },
    getAllColorsInStructure: function(val, colors) {
        if(Ext.isArray(val)) {
            for(var x; x < val.length; x++) {
                TP.getAllColorsInStructure(val[x], colors);
            }
        }
        else if(Ext.isObject(val)) {
            for(var key in val) {
                TP.getAllColorsInStructure(val[key], colors);
            }
        }
        else if(Ext.isString(val) && val.length == 7 && val.match(/^#/)) {
            var color = val.replace(/^#/, '');
            colors[color] = 1;
        }
    },
    showBroadcasts: function(broadcasts) {
        if(!broadcasts) { return; }
        if(!TP.broadcasts) { TP.broadcasts = {}; }
        if(!TP.broadcastCt) {
            TP.broadcastCt = Ext.DomHelper.insertFirst(document.body, {id:'broadcast-div', 'class': "popup-msg"}, true);
        }
        var broadcast_list = {};
        for(var x = 0; x < broadcasts.length; x++) {
            var b   = broadcasts[x];
            var id  = "broadcast_"+b.basefile.replace(/[^0-9a-z]/g, "");
            var text = replace_macros(replace_macros(b.text, b.frontmatter), b.macros);
            if(b.annotation) {
                text = '<img src="'+url_prefix+'themes/'+theme+'/images/'+b.annotation+'.png" border="0" alt="warning" title="'+b.annotation+'" width="16" height="16" style="vertical-align: text-bottom; margin-right: 5px;">'+text;
            }
            if(TP.broadcasts[id]) {
                broadcast_list[id] = TP.broadcasts[id];
                // update text for existing broadcasts
                Ext.get(id+"_content").update(text);
                continue;
            }
            // create missing broadcasts
            var msg = TP.Msg.msg("info_message~~<div id="+id+"_content>"+text+"</div>", 0, TP.broadcastCt, "Announcement", function() {
                Ext.Ajax.request({
                    url: 'broadcast.cgi',
                    method: 'POST',
                    params: {
                        action:   'dismiss',
                        panorama:  1,
                        CSRFtoken: CSRFtoken
                    }
                });
                delete TP.broadcasts[id];
            });
            broadcast_list[id] = msg.id;
        }
        // remove exceeding broadcasts
        for(var key in TP.broadcasts) {
            if(!broadcast_list[key]) {
                Ext.get(TP.broadcasts[key]).destroy();
            }
        }

        TP.broadcasts = broadcast_list;
    },
    cleanPanoramUrl: function() {
        var newUrl = window.location.href;
        if (history.replaceState) {
            newUrl = newUrl.replace(/\?.*$/g, '');
            try {
                history.replaceState({}, "", newUrl);
            } catch(err) { debug(err) }
        }
    },
    saveOpenTabsToCookie: function(tab, open_tabs) {
        var activeTab = tab.getActiveTab();
        if(!activeTab) {
            return;
        }
        cookieSave('thruk_panorama_active', activeTab.getStateId() ? activeTab.getStateId().replace(/^pantab_/, '') : 0);
        var numbers = [];
        for(var nr=0; nr<open_tabs.length; nr++) {
            var num = open_tabs[nr].replace(/^pantab_/, '');
            if(num != "0") {
                numbers.push(num);
            }
        }
        cookieSave('thruk_panorama_tabs', numbers.join(':'));
    },
    setBaseHTMLScroll: function() {
        window.clearTimeout(TP.timeouts['timeout_base_scroll']);
        var htmlRootEl = Ext.fly(Ext.getBody().dom.parentNode);
        htmlRootEl.removeCls('hidescroll');
        if(htmlRootEl.hasCls('geomap')) {
            return;
        }
        TP.timeouts['timeout_base_scroll'] = window.setTimeout(function() {
            var htmlRootEl = Ext.fly(Ext.getBody().dom.parentNode);
            if(htmlRootEl.hasCls('geomap')) { return; }
            htmlRootEl.addCls('hidescroll');
        }, 3000);
    },
    getPosFromLonLat: function(options) {
        var map    = options.map,
            lon    = options.lon,
            lat    = options.lat,
            center = options.center,
            size   = options.size,
            nsize  = options.nsize;
        var pixel = map.getPixelFromLonLat({lon: lon, lat: lat});

        // calculate center position of icon
        var x = (pixel.x-size.width/2);
        var y = (pixel.y-size.height/2)+TP.offset_y;

        if(center && center != "centered") {
            var c = center.split("-");
            if(c.length == 2) {
                var widthOffset = size.width;
                var heightOffset = size.height;
                if(nsize) {
                    widthOffset  = nsize[0];
                    heightOffset = nsize[1];
                }

                if(c[0] == "bottom") {
                    y = y - heightOffset/2;
                }
                else if(c[0] == "top") {
                    y = y + heightOffset/2;
                }

                if(c[1] == "left") {
                    x = x + widthOffset/2;
                }
                else if(c[1] == "right") {
                    x = x - widthOffset/2;
                }
            }
        }
        return({x:Math.floor(x), y:Math.floor(y)});
    },
    getRefPixel: function(options) {
        var x      = options.x,
            y      = options.y,
            center = options.center,
            size   = options.size,
            nsize  = options.nsize;

        x = x+(size.width/2);
        y = y+(size.height/2)-TP.offset_y;

        if(center && center != "centered") {
            var c = center.split("-");
            if(c.length == 2) {
                var widthOffset = size.width;
                var heightOffset = size.height;
                if(nsize) {
                    widthOffset  = nsize[0];
                    heightOffset = nsize[1];
                }

                if(c[0] == "bottom") {
                    y = y + heightOffset/2;
                }
                else if(c[0] == "top") {
                    y = y - heightOffset/2;
                }

                if(c[1] == "left") {
                    x = x - widthOffset/2;
                }
                else if(c[1] == "right") {
                    x = x + widthOffset/2;
                }
            }
        }
        return({x:Math.floor(x), y:Math.floor(y)});
    },
    showPanletById: function(tab, id) {
        var panlet = Ext.getCmp(id);
        if(!tab.destroying && panlet && panlet.show) {
            panlet.show();
        }
    },
    // remove all hidden dashboards which are no longer in use
    closeAllHiddenDashboards: function() {
        if(!TP.initialized) { return; }

        // collect all required dashboards
        var required = {};
        for(var key in TP.allDashboards) {
            var pantab = TP.allDashboards[key];
            if(!pantab.destroying) {
                var panels = TP.getAllPanel(pantab);
                for(var y=0; y<panels.length; y++) {
                    var p = panels[y];
                    if(p.xdata.cls == 'TP.DashboardStatusIcon' && p.xdata.general.dashboard) {
                        required[TP.nr2TabId(p.xdata.general.dashboard)] = true;
                    }
                }
            }
        }

        // close all not rendered (hidden) dashboards
        for(var key in TP.allDashboards) {
            if(!required[key] && !TP.allDashboards[key].rendered) {
                TP.allDashboards[key].destroy();
            }
        }
        return;
    },
    defaultHTTPCallback: function(options, success, response) {
        if(!success) {
            if(response.status == 0) {
                TP.Msg.msg("fail_message~~request failed");
            } else {
                TP.Msg.msg("fail_message~~request failed: "+response.status+' - '+response.statusText);
            }
            return;
        }
        TP.getResponse(undefined, response);
        return;
    },
    create_host_object_from_service: function(o) {
        var host = {};
        for(var key in o) {
            var m = key.match(/^host_(.*)$/);
            if(m && m[1]) {
                host[m[1]] = o[key];
            }
        }
        return(host);
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
