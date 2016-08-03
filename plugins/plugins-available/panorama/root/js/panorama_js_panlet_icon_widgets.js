TP.iconAppearanceTypes = [
    {"value":"none",        "name":"Label Only"},
    {"value":"icon",        "name":"Icon"},
    {"value":"connector",   "name":"Line / Arrow / Watermark"},
    {"value":"pie",         "name":"Pie Chart"},
    {"value":"speedometer", "name":"Speedometer"},
    {"value":"shape",       "name":"Shape"},
    {"value":"perfbar",     "name":"Performance Bar"},
    {"value":"trend",       "name":"Trend Icon"}
];

Ext.define('TP.SmallWidget', {
    mixins: {
        iconLabel: 'TP.IconLabel'
    },
    constructor: function(config) {
        var me = this;
        Ext.apply(me, config);

        this.shadow   = false;
        this.stateful = true;
        this.stateId  = this.id;
        this.floating = false;
        this.autoRender = true;
        this.autoShow = false;
        this.style    = { position: 'absolute', 'z-index': 30 };
        if(this.xdata == undefined) {
            this.xdata = {};
        } else {
            this.xdata = TP.clone(this.xdata);
        }
        var tab     = Ext.getCmp(this.panel_id);
        this.locked = tab.xdata.locked;
        if(readonly) {
            this.locked = true;
        }
        this.redrawOnly = false;
        this.animations = 0;

        this.xdata.cls        = this.$className;
        this.xdata.state      = 4;
        this.xdata.general    = {};
        this.xdata.layout     = { rotation:   0 };
        if(this.xdata.appearance == undefined) {
            this.xdata.appearance = { type: 'icon' };
        }
        this.xdata.link     = {};
        this.xdata.label    = { fontfamily:  '',
                                fontsize:     14,
                                fontcolor:   '#000000',
                                position:    'below',
                                orientation: 'horizontal',
                                offsetx:      0,
                                offsety:      0,
                                bgcolor:     '',
                                fontitalic:  '',
                                fontbold:    ''
                            };
        if(this.xdata.general[this.iconType] == undefined) { this.xdata.general[this.iconType] = '' };
        this.autoEl = {
            tag:     'a',
            href:    '',
            target:  '',
            onclick: "return(false);"
        };

        if(!this.locked) {
            this.stateEvents = ['reconfigure', 'afterlayout', 'move'];
            this.draggable   = true;
        }

        this.getState = function() {
            var state      = {
                xdata: TP.clone(this.xdata)
            };
            if(state.xdata.map) {
                delete state.xdata.layout.x;
                delete state.xdata.layout.y;
                delete state.xdata.appearance.connectorfromx;
                delete state.xdata.appearance.connectorfromy;
                delete state.xdata.appearance.connectortox;
                delete state.xdata.appearance.connectortoy;
            }
            return state;
        };
        this.origApplyState = this.applyState;
        this.applyState = function(state) {
            Ext.apply(this.xdata, state.xdata);
            TP.log('['+this.id+'] applyState: '+Ext.JSON.encode(state));
            this.origApplyState(state);
            this.moveToMapLonLat(); /* recalculate x/y from coordinates */
            if(state) {
                this.applyXdata(state.xdata);
            }
        };
    },
    listeners: {
        afterrender: function(This, eOpts) {
            Ext.fly('iconContainer').appendChild(Ext.get(This.id));
            TP.log('['+this.id+'] rendered');
            This.addClickEventhandler(This.el);

            if(!readonly && !This.locked) {
                if((This.xdata.general[This.iconType] == '' && This.firstRun != false && This.iconType != "text") || This.firstRun == true) {
                    This.firstRun = true;
                    TP.timeouts['timeout_' + This.id + '_show_settings'] = window.setTimeout(function() {
                        // show dialog delayed, so the panel has a position already
                        if(This && This.el) {
                            var pos = This.getPosition();
                            This.xdata.layout.x = pos[0];
                            This.xdata.layout.y = pos[1];
                            if(This.iconType != 'text') {
                                TP.iconShowEditDialog(This);
                            }
                        }
                    }, 250);
                }
            }
            This.applyRotation(This.xdata.layout.rotation, This.xdata);
            This.applyZindex(This.xdata.layout.zindex);
            This.applyScale(This.xdata.layout.scale, This.xdata);
            if(!This.locked) {
                This.el.on('mouseover', function(evt,t,a) {
                    if(!This.el.dom.style.outline.match("orange")) {
                        This.el.dom.style.outline = "1px dashed grey";
                        if(This.iconType != "text" && This.labelEl && This.labelEl.el) {
                            This.labelEl.el.dom.style.outline = "1px dashed grey";
                        }
                    }
                });
                This.el.on('mouseout', function(evt,t,a) {
                    if(This.el.dom.style.outline.match("grey")) {
                        This.el.dom.style.outline = "";
                        if(This.labelEl && This.labelEl.el) {
                            This.labelEl.el.dom.style.outline = "";
                        }
                    }
                });
            }
            This.setIconLabel();
        },
        show: function( This, eOpts ) {
            This.addDDListener(This);
            /* update label */
            This.setIconLabel();
            if(This.labelEl) { This.labelEl.show(); }
        },
        hide: function(This, eOpts) {
            if(this.labelEl) { this.labelEl.hide(); }
        },
        destroy: function( This, eOpts ) {
            if(this.redrawOnly) {
                TP.log('['+this.id+'] redrawing icon');
                if(This.labelEl) {
                    /* remove later to avoid flickering during redraw */
                    if(TP.removeLabel == undefined) {
                        TP.removeLabel = {};
                    }
                    TP.removeLabel[This.id] = This.labelEl;
                    This.labelEl = undefined;
                }
            } else {
                TP.log('['+this.id+'] remove icon');
                /* remove window from panels window ids */
                TP.removeWindowFromPanels(this.id);
                /* clear state information */
                TP.cp.clear(this.id);
                if(This.labelEl) { This.labelEl.destroy(); }
            }
            if(This.dragEl1) { This.dragEl1.destroy(); }
            if(This.dragEl2) { This.dragEl2.destroy(); }
        },
        boxready: function( This, width, height, eOpts ) {
            This.addDDListener(This);
            This.setIconLabel();
        },
        move: function(This, x, y, eOpts) {
            var pos = This.getPosition();
            if(x != undefined) { x = Math.floor(x); } else { x = pos[0]; }
            if(y != undefined) { y = Math.floor(y); } else { y = pos[1]; }

            /* snap to roaster when shift key is hold */
            if(TP.isShift) {
                pos = TP.get_snap(x, y);
                if(This.ddShadow) {
                    This.ddShadow.dom.style.display = '';
                    This.ddShadow.dom.style.left    = pos[0]+"px";
                    This.ddShadow.dom.style.top     = pos[1]+"px";
                    x=pos[0];
                    y=pos[1];
                }
            } else {
                if(This.ddShadow) {
                    This.ddShadow.dom.style.display = 'none';
                }
            }

            var noUpdateLonLat = This.noUpdateLonLat;
            TP.reduceDelayEvents(This, function() {
                TP.iconMoveHandler(This, x, y, noUpdateLonLat);
            }, 50, 'timeout_icon_move');
        },
        resize: function(This, width, height, oldWidth, oldHeight, eOpts) {
            /* update label */
            this.setIconLabel();
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
    applyXdata: function(xdata) {
        var panel = this;
        if(xdata == undefined) { xdata = this.xdata; }

        /* restore missing sections */
        Ext.Array.each(['general', 'layout', 'appearance', 'link', 'label'], function(name, idx) {
            if(xdata[name] == undefined) { xdata[name] = {} };
        });
        if(xdata.appearance['type'] == undefined || xdata.appearance['type'] == '') { xdata.appearance['type'] = 'icon' };

        /* restore position */
        xdata.layout.x = Number(xdata.layout.x);
        xdata.layout.y = Number(xdata.layout.y);
        if(xdata.layout.x == null || isNaN(xdata.layout.x)) { xdata.layout.x = 0; }
        if(xdata.layout.y == null || isNaN(xdata.layout.y)) { xdata.layout.y = 0; }
        if(panel.shrinked) {
            this.setRawPosition(xdata.layout.x + panel.shrinked.offsetX, xdata.layout.y + panel.shrinked.offsetY);
        } else {
            this.setRawPosition(xdata.layout.x, xdata.layout.y);
        }
        if(xdata.layout.rotation) {
            this.applyRotation(Number(xdata.layout.rotation), xdata);
        } else {
            this.applyRotation(0, xdata);
        }
        if(xdata.layout.zindex) {
            this.applyZindex(Number(xdata.layout.zindex));
        } else {
            this.applyZindex(0);
        }
        this.applyScale(Number(xdata.layout.scale), xdata);

        /* set label */
        this.setIconLabel(xdata.label);

        /* recalculate state */
        if(TP.initialized) {
            this.refreshHandler();
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

        layout = this.xdata.layout;
        if(layout.rotation) {
            // animations with rotated elements results in wrong position,
            // ex.: rotated shapes return wrong position on getPosition()
            return;
        }
        if(win.shrinked) {
            win.shrinked.x = layout.x;
            win.shrinked.y = layout.y;
            animated.to = {x:layout.x+win.shrinked.offsetX, y:layout.y+win.shrinked.offsetY};
        } else {
            animated.to = {x:layout.x, y:layout.y};
        }
        this.animate(animated);
    },
    /* apply z-index */
    applyZindex: function(value) {
        value = Number(value);
        var This = this;
        This.style['z-index'] = 30+(value+10)*2;
        if(This.el && This.el.dom) {
            This.el.dom.style.zIndex = This.style['z-index'];
        }
        if(This.labelEl && This.labelEl.el && This.labelEl.el.dom) {
            This.labelEl.el.dom.style.zIndex = This.style['z-index']+1;
        }
    },
    /* rotates this thing */
    applyRotation: function(value, xdata) {
        if(value == undefined) { return; }
        value = value*-1;
        var el = this.el;
        if(this.rotateEl) { el = this.rotateEl; }
        if(!el || !el.dom) { return; }
        el.setStyle("-webkit-transform", "rotate("+value+"deg)");
        el.setStyle("-moz-transform", "rotate("+value+"deg)");
        el.setStyle("-o-transform", "rotate("+value+"deg)");
        el.dom.style.msTransform = "rotate("+value+"deg)";
        el.setStyle("-ms-transform", "rotate("+value+"deg)");
    },
    /* apply z-index */
    applyScale: function(value, xdata) {
        if(this.iconFixSize) {
            this.iconFixSize(xdata);
        }
    },
    /* enable / disable editing of this panlet */
    setLock: function(val) {
        var panel = this;
        var tab   = Ext.getCmp(panel.panel_id);
        if(panel.locked != val) {
            panel.saveState();
            TP.redraw_panlet(panel, tab);
        }
    },

    addClickEventhandler: function(el) {
        var This = this;
        var tab  = Ext.getCmp(This.panel_id);

        el.on("click", function(evt) {
            if(!readonly) {
                if(evt.ctrlKey || is_shift_pressed(evt)) {
                    var tab = Ext.getCmp(This.panel_id);
                    if(This.locked) { return; }
                    if(TP.moveIcons == undefined) {
                        TP.moveIcons = [];
                    }
                    if(This.el.dom.style.outline.match("orange")) {
                        /* already selected -> unselect */
                        This.el.dom.style.outline = "";
                        TP.moveIcons = TP.removeFromList(TP.moveIcons, This);
                    } else {
                        if(This.dragEl1) { TP.moveIcons = TP.removeFromList(TP.moveIcons, This.dragEl1); This.dragEl1.el.dom.style.outline = ""; }
                        if(This.dragEl2) { TP.moveIcons = TP.removeFromList(TP.moveIcons, This.dragEl2); This.dragEl2.el.dom.style.outline = ""; }
                        This.el.dom.style.outline = "2px dotted orange";
                        TP.moveIcons.push(This);
                        TP.createIconMoveKeyNav();
                    }
                    if(TP.moveIcons.length == 0) {
                        TP.resetMoveIcons();
                    }
                    return(false);
                }
            }
            if(This.locked) {
                /* make links clickable in text labels */
                if(evt.target.tagName == "A" && !evt.target.className.match('component')) {
                    /* link must be cloned, added to document body, clicked and then be removed */
                    var link = evt.target.cloneNode();
                    document.body.appendChild(link);
                    link.click();
                    link.parentNode.removeChild(link);
                    return(false);
                }
            }
            return(TP.iconClickHandler(This.id));
        });

        /* open edit box on double or right click */
        if(!readonly) {
            el.on("dblclick", function(evt) {
                window.clearTimeout(TP.timeouts['click'+This.id]);
                if(!This.locked) {
                    Ext.getBody().mask("loading settings");
                    window.setTimeout(function() {
                        This.firstRun = false;
                        TP.iconShowEditDialog(This);
                    }, 50);
                }
            });
        }

        /* right click context menu on icon widgets */
        el.on("contextmenu", function(evt) {
            evt.preventDefault();
            TP.resetMoveIcons();
            tab.disableMapControlsTemp();
            TP.suppressIconTip = true;

            var menu_items = [{
                    text:   'Refresh',
                    icon:   url_prefix+'plugins/panorama/images/arrow_refresh.png',
                    handler: function() {
                        TP.updateAllIcons(Ext.getCmp(This.panel_id), This.id, undefined, el)
                        el.mask(el.getSize().width > 50 ? "refreshing" : undefined);
                    },
                    hidden:  This.xdata.state == undefined ? true : false
                }, {
                    text:       'Show Details',
                    icon:       url_prefix+'plugins/panorama/images/application_view_columns.png',
                    href:       'status.cgi',
                    hrefTarget: '_blank',
                    listeners: {
                        afterrender: function(btn, eOpts) { btn.el.dom.children[0].href = TP.getIconDetailsLink(This); }
                    },
                    hidden:  This.xdata.state == undefined ? true : false
                }
            ];
            if(!readonly) {
                menu_items = menu_items.concat([{
                        text:   'Settings',
                        icon:   url_prefix+'plugins/panorama/images/cog.png',
                        handler: function() { This.firstRun = false; TP.iconShowEditDialog(This) },
                        disabled: This.locked
                    }, '-', {
                        text:   'Copy',
                        icon:   url_prefix+'plugins/panorama/images/page_copy.png',
                        handler: function() { TP.clipboard = {type:This.xdata.cls, state:TP.clone_panel_config(This)} }
                    }, {
                        text:   'Paste',
                        icon:   url_prefix+'plugins/panorama/images/page_paste.png',
                        handler: function() { TP.add_panlet_delayed(TP.clone(TP.clipboard), -8, -8) },
                        disabled: (This.locked || TP.clipboard == undefined)
                    }, {
                        text:   'Clone',
                        icon:   url_prefix+'plugins/panorama/images/page_lightning.png',
                        handler: function() { TP.add_panlet_delayed(TP.clone({type:This.xdata.cls, state:TP.clone_panel_config(This)}), -8, -8) },
                        disabled: This.locked
                    }, '-', {
                        text:   'Remove',
                        icon:   url_prefix+'plugins/panorama/images/delete.png',
                        disabled: This.locked,
                        handler: function(me, eOpts) {
                            var menu = me.parentMenu;
                            var i = menu.items.findIndexBy(function(el) { if(el.text == 'Remove') {return true;} });
                            menu.remove(i);
                            menu.add({
                                xtype: 'panel',
                                border: false,
                                bodyStyle: 'background: #F0F0F0;',
                                items: [{
                                    xtype:  'label',
                                    text:   'Remove? ',
                                    style:  'top: 3px; position: relative; color: red; font-weight: bold;'
                                },{
                                    xtype:  'button',
                                    text:   'No',
                                    width:  30,
                                    handler: function() { menu.destroy(); }
                                }, {
                                    xtype: 'button',
                                    text:  'Yes',
                                    width:  30,
                                    handler: function() { This.destroy(); menu.destroy(); }
                                }]
                            });
                            menu.move(menu.items.length, i);
                        }
                    }, {
                        xtype:  'menuseparator',
                        hidden: !This.locked      // only show when locked
                    }, {
                        text:   'Unlock Dashboard',
                        icon:   url_prefix+'plugins/panorama/images/lock_open.png',
                        handler: function() { var tab = Ext.getCmp(This.panel_id); TP.createRestorePoint(tab, "a"); tab.setLock(false); },
                        hidden: !This.locked      // only show when locked
                    }
                ]);
            }

            Ext.create('Ext.menu.Menu', {
                margin: '0 0 10 0',
                items:   menu_items,
                listeners: {
                    beforehide: function(menu, eOpts) {
                        menu.destroy();
                        tab.enableMapControlsTemp();
                        TP.suppressIconTip = false;
                        This.el.dom.style.outline = "";
                        if(This.labelEl && This.labelEl.el) {
                            This.labelEl.el.dom.style.outline = "";
                        }
                    }
                }
            }).showAt(evt.getXY());
            This.el.dom.style.outline = "1px dashed grey";
            if(This.labelEl && This.labelEl.el) {
                This.labelEl.el.dom.style.outline = "1px dashed grey";
            }
        });
    },
    addDDListener: function(el) {
        var panel = this;
        var tab   = Ext.getCmp(panel.panel_id);
        if(el.dd && !el.dd_listener_added) {
            el.dd.addListener('dragstart', function(This, evt) {
                window.clearTimeout(TP.timeouts['click'+panel.id]);
                TP.isShift = is_shift_pressed(evt);
                tab.disableMapControlsTemp();
                /* add ourself to movelist */
                if(TP.moveIcons) {
                    var found = false;
                    Ext.Array.each(TP.moveIcons, function(item) {
                        if(item.id == panel.id) { found = true; return(false); }
                    });
                    if(!found) {
                        panel.el.dom.style.outline = "2px dotted orange";
                        TP.moveIcons.push(panel);
                    }
                    if(panel.dragEl1) { TP.moveIcons = TP.removeFromList(TP.moveIcons, panel.dragEl1); panel.dragEl1.el.dom.style.outline = ""; }
                    if(panel.dragEl2) { TP.moveIcons = TP.removeFromList(TP.moveIcons, panel.dragEl2); panel.dragEl2.el.dom.style.outline = ""; }
                }
                if(!panel.ddShadow) {
                    var size = panel.getSize();
                    panel.ddShadow = Ext.DomHelper.append(document.body, '<div style="border: 1px dashed black; width: '+size.width+'px; height: '+size.height+'px; position: relative; z-index: 10000; top: 0px; ; left: 0px; display: hidden;"><div style="border: 1px dashed white; width:'+(size.width-2)+'px; height:'+(size.height-2)+'px; position: relative; top: 0px; ; left: 0px;" ><\/div><\/div>' , true);
                }
                if(!panel.dragHint) {
                    panel.dragHint = Ext.DomHelper.append(document.body, '<div style="border: 1px solid grey; border-radius: 2px; background: #CCCCCC; position: absolute; z-index: 10000; top: -1px; left: 35%; padding: 3px;">Tip: hold shift key to enable grid snap.<\/div>' , true);
                }
            });
            el.dd.addListener('drag', function(This, evt) {
                TP.isShift = is_shift_pressed(evt);
                if(panel.xdata.appearance.type == "connector") {
                    /* dragging by label does not fire the move event, so fire move manually */
                    panel.fireEvent("move", panel, undefined, undefined);
                }
            });
            el.dd.addListener('dragend', function(This, evt) {
                panel.dragHint.destroy();
                panel.dragHint = undefined;
                tab.enableMapControlsTemp();
                TP.isShift = is_shift_pressed(evt);
                /* prevents opening link after draging */
                if(TP.isShift) {
                    var pos = panel.getPosition();
                    panel.noMoreMoves = true;
                    panel.setRawPosition(TP.get_snap(pos[0], pos[1]));
                    panel.noMoreMoves = false;
                }
                TP.isShift = false;
                if(panel.ddShadow) { panel.ddShadow.dom.style.display = 'none'; }
                window.setTimeout(function() {
                    window.clearTimeout(TP.timeouts['click'+panel.id]);
                    if(panel.ddShadow) {
                        panel.ddShadow.dom.style.display = 'none';
                    }
                }, 100);
                panel.setIconLabel();
                if(panel.dragEl1) { panel.dragEl1.resetDragEl(); }
                if(panel.dragEl2) { panel.dragEl2.resetDragEl(); }
            });
            el.dd_listener_added = true;
        }
    },
    updateMapLonLat: function(forceCenter) {
        var panel = this;
        if(forceCenter && panel.noUpdateLonLat > 0) { return; }
        var tab   = Ext.getCmp(panel.panel_id);
        if(tab.map == undefined || tab.map.map == undefined) { return; }
        var s;
        if(!panel.el) {
            s     = {width: panel.xdata.size, height: panel.xdata.size};
        } else {
            s     = panel.getSize();
        }
        var p = panel.getPosition();
        var lonLat = tab.map.map.getLonLatFromPixel({x: (p[0]+s.width/2), y: (p[1]+s.height/2)-TP.offset_y});
        if(!forceCenter && panel.xdata.appearance.type == "connector") {
            var lonLat1 = tab.map.map.getLonLatFromPixel({x: panel.xdata.appearance.connectorfromx, y: panel.xdata.appearance.connectorfromy-TP.offset_y});
            var lonLat2 = tab.map.map.getLonLatFromPixel({x: panel.xdata.appearance.connectortox,   y: panel.xdata.appearance.connectortoy-TP.offset_y});
            panel.xdata.map = {
                lon:  lonLat.lon,
                lat:  lonLat.lat,
                lon1: lonLat1.lon,
                lat1: lonLat1.lat,
                lon2: lonLat2.lon,
                lat2: lonLat2.lat
            }
        } else {
            /* do not completly overwrite map{}, it might be a connector which looses its endpoints then */
            if(panel.xdata.appearance.type != "connector" || panel.xdata.map == undefined) {
                panel.xdata.map = {};
            }
            panel.xdata.map.lon = lonLat.lon;
            panel.xdata.map.lat = lonLat.lat;
        }
        panel.saveState();
    },
    moveToMapLonLat: function(maxSize, movedOnly) {
        var panel = this;
        var tab   = Ext.getCmp(panel.panel_id);
        if(tab.map == undefined || tab.map.map == undefined) { return; }
        if(panel.xdata.map == undefined)                     { return; }
        panel.noUpdateLonLat++;
        if(panel.xdata.appearance.type == "connector" && !movedOnly) {
            var pixel  = tab.map.map.getPixelFromLonLat({lon: Number(panel.xdata.map.lon),  lat: Number(panel.xdata.map.lat)});
            var pixel1 = tab.map.map.getPixelFromLonLat({lon: Number(panel.xdata.map.lon1), lat: Number(panel.xdata.map.lat1)});
            var pixel2 = tab.map.map.getPixelFromLonLat({lon: Number(panel.xdata.map.lon2), lat: Number(panel.xdata.map.lat2)});
            panel.xdata.layout.x                  = pixel.x;
            panel.xdata.layout.y                  = pixel.y+TP.offset_y;
            panel.xdata.appearance.connectorfromx = pixel1.x;
            panel.xdata.appearance.connectorfromy = pixel1.y+TP.offset_y;
            panel.xdata.appearance.connectortox   = pixel2.x;
            panel.xdata.appearance.connectortoy   = pixel2.y+TP.offset_y;
            if(panel.el) {
                panel.updateRender();
            }
        } else {
            var pixel = tab.map.map.getPixelFromLonLat({lon: Number(panel.xdata.map.lon), lat: Number(panel.xdata.map.lat)});
            var s;
            if(!panel.el) {
                s     = {width: panel.xdata.size, height: panel.xdata.size};
            } else {
                s     = panel.getSize();
            }
            var x     = (pixel.x-s.width/2);
            var y     = (pixel.y-s.height/2)+TP.offset_y;
            panel.xdata.layout.x = x;
            panel.xdata.layout.y = y;
            panel.setRawPosition(x, y);
            if(panel.el && TP.isThisTheActiveTab(panel)) {
                if(panel.xdata.appearance.type == "connector") {
                    if(panel.isHidden()) { panel.show(); }
                } else {
                    if(maxSize != undefined && (x < 0 || y < 0 || x > maxSize.width || y > maxSize.height)) {
                        if(!panel.isHidden()) { panel.hide(); }
                    } else {
                        if(panel.isHidden()) { panel.show(); }
                    }
                }
            } else if(panel.el) {
                panel.hide();
            }
        }
        if(!panel.isHidden() && panel.el) {
            panel.setIconLabel();
        }
        panel.noUpdateLonLat--;
    },
    setRawPosition: function(x, y) {
        var panel = this;
        panel.noUpdateLonLat++
        panel.suspendEvents();
        panel.setPosition(x, y);
        if(panel.el && panel.el.dom) {
            panel.setPagePosition(x, y);
        }
        panel.resumeEvents();
        panel.noUpdateLonLat--;
        panel.setIconLabel();
        return(panel);
    }
});

Ext.define('TP.IconWidget', {
    extend: 'Ext.container.Container',
    mixins: {
        smallWidget: 'TP.SmallWidget'
    },

    cls:      'iconWidget tooltipTarget',
    floating:  true,
    focusOnToFront: false,
    toFrontOnShow: false,
    width:     22,
    height:    22,

    noUpdateLonLat: 0,
    constructor: function (config) {
        this.noUpdateLonLat++;
        this.mixins.smallWidget.constructor.call(this, config);
        this.callParent();
        this.noUpdateLonLat--;
    },
    initComponent: function() {
        var panel = this;
        this.callParent();
        this.addListener('afterrender', function(This, eOpts) {
            this.setRenderItem();
        });
    },
    items: [],
    applyXdata: function(xdata) {
        if(xdata == undefined) { xdata = this.xdata; }
        this.mixins.smallWidget.applyXdata.call(this, xdata);
        if(this.xdata.appearance.type == "connector") {
            this.draggable = false;
        }
        if(xdata.nsize && xdata.size) {
            var size = Math.ceil(Math.sqrt(Math.pow(xdata.nsize[0], 2) + Math.pow(xdata.nsize[1], 2)));
            this.setSize(size, size);
        }
        if(this.lastType != xdata.appearance.type) {
            this.setRenderItem(xdata);
        } else {
            this.updateRender(xdata);
        }
        this.lastType = xdata.appearance.type;
        this.applyZindex(this.xdata.layout.zindex);
    },
    refreshHandler: function(newStatus) {
        var tab   = Ext.getCmp(this.panel_id);
        var panel = this;
        if(TP.iconSettingsWindow && TP.iconSettingsWindow.panel == panel) { return; }
        var oldState = panel.xdata.state;
        if(newStatus != undefined) {
            panel.xdata.state = newStatus;
        }
        this.updateRender();
        if(panel.xdata.state != undefined && oldState != panel.xdata.state) {
            if(panel.locked && panel.el && (oldState != 4 && oldState != undefined)) { // not when initial state was pending
                TP.timeouts['timeout_' + panel.id + '_flicker'] = window.setTimeout(Ext.bind(TP.flickerImg, panel, [panel.el.id]), 200);
                panel.saveIconsStates();
            }
        }
        if(panel.xdata.map) {
            panel.moveToMapLonLat(undefined, false);
        }
        panel.setIconLabel();
    },

    /* save state of icons back to servers runtime file */
    saveIconsStates: function() {
        var tab = Ext.getCmp(this.panel_id);
        tab.saveIconsStates();
    },

    /* rotates this thing */
    applyRotation: function(value, xdata) {
        var panel = this;
        if(xdata == undefined) { xdata = this.xdata; }
        if(value == undefined) { return; }
        if(isNaN(value)) { return; }
        if(xdata.appearance && panel.appearance && panel.appearance.defaultDrawIcon) {
            if(this.surface == undefined) { return; }
            if(this.surface.items.getAt(0) == undefined) { return; }
            this.surface.items.getAt(0).setAttributes({rotate:{degrees: -1*value}}, true);
        } else {
            this.mixins.smallWidget.applyRotation(value);
            this.mixins.smallWidget.applyRotation.call(this, value);
        }
    },
    /* return totals array which can be used in a store */
    getTotals: function(xdata, colors) {
        var panel = this;
        if(xdata == undefined) { xdata = panel.xdata; }
        var totals = [];
        var hosts  = {}, services = {};
        if(panel.hostgroup) {
            if(xdata.general.incl_hst) { hosts    = panel.hostgroup.hosts;    }
            if(xdata.general.incl_svc) { services = panel.hostgroup.services; }
        }
        else if(panel.servicegroup) { services = panel.servicegroup.services; }
        else if(panel.results) {
            if(xdata.general.incl_hst) { hosts    = panel.results.hosts;    }
            if(xdata.general.incl_svc) { services = panel.results.services; }
        }
        else {
            var state = xdata.state;
            if(panel.iconType == 'host') {
                if(state == 0) { totals.push({name: 'up',          value: 1, color: colors['up'] }); }
                if(state == 1) { totals.push({name: 'down',        value: 1, color: colors['down'] }); }
                if(state == 2) { totals.push({name: 'unreachable', value: 1, color: colors['unreachable'] }); }
            } else {
                if(state == 0) { totals.push({name: 'ok',       value: 1, color: colors['ok'] }); }
                if(state == 1) { totals.push({name: 'warning',  value: 1, color: colors['warning'] }); }
                if(state == 2) { totals.push({name: 'critical', value: 1, color: colors['critical'] }); }
                if(state == 3) { totals.push({name: 'unknown',  value: 1, color: colors['unknown'] }); }
            }
            if(state == 4) { totals.push({name: 'pending', value: 1, color: colors['pending'] }); }
        }
        Ext.Array.each(['down', 'unreachable', 'critical', 'unknown', 'warning', 'up', 'ok', 'pending'], function(name, i) {
            if(   hosts[name]) { totals.push({name: name, value:    hosts[name], color: colors[name] }); }
            if(services[name]) { totals.push({name: name, value: services[name], color: colors[name] }); }
        });
        if(totals.length == 0) { totals.push({name: 'none', value: 1, color: colors['pending'] }); }
        return(totals);
    },

    /* update shapes and stuff */
    updateRender: function(xdata) {
        var panel = this;
        window.clearTimeout(TP.timeouts['timeout_' + panel.id + '_updaterender']);
        TP.timeouts['timeout_' + panel.id + '_updaterender'] = window.setTimeout(function() {
            panel.updateRenderDo(xdata);
        }, 100);
    },
    updateRenderDo: function(xdata) {
        var panel = this;
        if(xdata == undefined) { xdata = panel.xdata; }
        /* static icons must be refreshed, even when inactive, because they won't be updated later on */
        if(panel.appearance.updateRenderAlways) { panel.appearance.updateRenderAlways(xdata); }
        /* no need for changes if we are not the active tab */
        if(!TP.isThisTheActiveTab(panel)) { return; }
        if(panel.appearance.updateRenderActive) { panel.appearance.updateRenderActive(xdata); }
    },

    /* set main render item*/
    setRenderItem: function(xdata, forceRecreate) {
        var panel = this;
        if(xdata == undefined) { xdata = panel.xdata; }
        if(panel.itemRendering && !forceRecreate) { return; }
        panel.itemRendering = true;
        panel.removeAll();
        panel.surface  = undefined;
        panel.icon     = undefined;
        panel.chart    = undefined;

        panel.appearance = Ext.create('tp.icon.appearance.'+xdata.appearance['type'], { panel: panel });

        if(panel.dragEl1) { panel.dragEl1.destroy(); }
        if(panel.dragEl2) { panel.dragEl2.destroy(); }

        /* add link (link will only work on labels for connectors) */
        if(xdata.link && xdata.link.link && xdata.appearance.type != "connector") {
            panel.addCls('clickable');
            panel.removeCls('notclickable');
            if(panel.el) { panel.el.dom.href=xdata.link.link; }
            panel.autoEl.href=xdata.link.link;
            if(panel.labelEl && panel.labelEl.el) {
                panel.labelEl.el.dom.href=xdata.link.link;
                panel.labelEl.removeCls('notclickable');
                panel.labelEl.addCls('clickable');
            }
        } else {
            if(panel.el) {
                panel.removeCls('clickable');
                panel.addCls('notclickable');
            }
            if(panel.el) { panel.el.dom.href=''; }
            panel.autoEl.href='';
            if(panel.labelEl && panel.labelEl.el) {
                panel.labelEl.el.dom.href='';
                panel.labelEl.removeCls('clickable');
                panel.labelEl.addCls('notclickable');
            }
        }

        var x       = 0;
        var y       = 0;
        var width   = 16;
        var height  = 16;
        var size;
        var scale   = xdata.layout.scale != undefined ? xdata.layout.scale / 100 : 1;
        if(scale <= 0) { scale = 1; }
        if(xdata.appearance.type == 'connector') {
            width  = xdata.appearance.connectorfromx - xdata.appearance.connectortox;
            height = xdata.appearance.connectorfromy - xdata.appearance.connectortoy;
            if(width  < 0) { width  = width  * -1; }
            if(height < 0) { height = height * -1; }
            width  = width  + 2*(xdata.appearance.connectorarrowlength + xdata.appearance.connectorarrowwidth);
            height = height + 2*(xdata.appearance.connectorarrowlength + xdata.appearance.connectorarrowwidth);
        }
        else if(xdata.nsize && xdata.size) {
            x        = (xdata.size - xdata.nsize[0]) / 2;
            y        = (xdata.size - xdata.nsize[1]) / 2;
            width    = xdata.nsize[0];
            height   = xdata.nsize[1];
            size     = Math.ceil((Math.sqrt(Math.pow(width, 2) + Math.pow(height, 2)))*scale);
            panel.setSize(size, size);
        } else if(panel.xdata.size && panel.xdata.nsize && panel.xdata.nsize[0] > 1) {
            x        = (panel.xdata.size - panel.xdata.nsize[0]) / 2;
            y        = (panel.xdata.size - panel.xdata.nsize[1]) / 2;
            width    = panel.xdata.nsize[0];
            height   = panel.xdata.nsize[1];
            size     = Math.ceil((Math.sqrt(Math.pow(width, 2) + Math.pow(height, 2)))*scale);
            panel.setSize(size, size);
        } else {
            size = Math.ceil(Math.sqrt(Math.pow(width, 2) + Math.pow(height, 2)));
            x    = (size - width)  / 2;
            y    = (size - height) / 2;
        }
        panel.lastScale = scale;

        if(panel.appearance.defaultDrawItem) {
            var drawWidth  = size;
            var drawHeight = size;
            if(xdata.appearance.type == 'connector') {
                drawWidth  = width;
                drawHeight = height;
            }
            /* shrink panel size to icon size if possible (non-edit mode and not rotated) */
            delete panel.shrinked;
            if(panel.appearance.shrinkable && xdata.layout.rotation == 0 && scale == 1 && panel.locked) {
                var offsetX = (size-width)/2;
                var offsetY = (size-height)/2;
                panel.shrinked = { size: size, x: panel.xdata.layout.x, y: panel.xdata.layout.y, offsetX: offsetX, offsetY: offsetY };
                x=0;
                y=0;
                drawWidth  = width;
                drawHeight = height;
                panel.setSize(drawWidth, drawHeight);
                panel.setPosition(panel.xdata.layout.x+offsetX, panel.xdata.layout.y+offsetY);
            }

            var items = [];
            if(panel.appearance.defaultDrawIcon) {
                if(xdata.layout.rotation == undefined) { xdata.layout.rotation = 0; }
                items = [{
                    type:      'image',
                    src:        Ext.BLANK_IMAGE_URL,
                    width:      width,
                    height:     height,
                    x:          x,
                    y:          y,
                    rotation: { degrees: -1*xdata.layout.rotation }
                }];
            }
            panel.add({
                viewBox:   false,
                xtype:    'draw',
                width:     drawWidth,
                height:    drawHeight,
                items:     items,
                style:     'vertical-align:inherit;',
                listeners: {
                    afterrender: function(This, eOpts) {
                        panel.itemRendering = false;
                        panel.surface = panel.items.getAt(0).surface;
                        if(panel.appearance.defaultDrawIcon) {
                            panel.icon = panel.items.getAt(0).surface.items.getAt(0);
                            if(This.el.down('image')) {
                                This.el.down('image').on("load", function (evt, ele, opts) {
                                    panel.iconCheckBorder(xdata);
                                });
                                This.el.down('image').on("error", function (evt, ele, opts) {
                                    panel.iconCheckBorder(xdata, true);
                                });
                            }
                        }
                        panel.updateRender(xdata);
                    }
                }
            });

            if(xdata.appearance.type == 'connector' && !panel.locked) {
                panel.dragEl1 = Ext.create('TP.dragEl', {
                    renderTo:  'iconContainer',
                    panel:      panel,
                    xdata:      xdata,
                    keyX:       "connectorfromx",
                    keyY:       "connectorfromy",
                    offsetX:    -12,
                    offsetY:    -12
                });
                panel.dragEl2 = Ext.create('TP.dragEl', {
                    renderTo:  'iconContainer',
                    panel:      panel,
                    xdata:      xdata,
                    keyX:       "connectortox",
                    keyY:       "connectortoy",
                    offsetX:    -12,
                    offsetY:    -12
                });
            }
        }
        else if(panel.appearance.setRenderItem) {
            panel.appearance.setRenderItem(xdata);
        }
        else {
            panel.itemRendering = false;
        }
    },

    iconFixSize: function(xdata) {
        var panel = this;
        if(!panel.icon)    { return; }
        if(!panel.icon.el) { return; }
        if(TP.imageSizes == undefined) { TP.imageSizes = {} }
        var src = panel.icon.el.dom.href.baseVal || panel.src;
        if(TP.imageSizes[src] == undefined) {
            var naturalSize = TP.getNatural(src);
            if(naturalSize && naturalSize.width > 1 && naturalSize.height > 1) {
                TP.imageSizes[src] = [naturalSize.width, naturalSize.height];
                panel.iconFixSize(xdata);
            }
            return;
        }
        var naturalWidth  = TP.imageSizes[src][0];
        var naturalHeight = TP.imageSizes[src][1];
        if(naturalWidth > 1 && naturalHeight > 1) {
            var size  = Math.ceil(Math.sqrt(Math.pow(naturalWidth, 2) + Math.pow(naturalHeight, 2)));
            var scale = xdata.layout.scale != undefined ? xdata.layout.scale / 100 : 1;
            if(scale <= 0) { scale = 1; }
            size = Math.ceil(size * scale);
            if(panel.shrinked) {
                panel.setSize(naturalWidth, naturalHeight);
                if(panel.items.getAt && panel.items.getAt(0)) {
                    panel.items.getAt(0).setSize(naturalWidth, naturalHeight);
                }
            } else {
                panel.setSize(size, size);
                if(panel.items.getAt && panel.items.getAt(0)) {
                    panel.items.getAt(0).setSize(size, size);
                }
            }
            xdata.size  = size;
            xdata.nsize = [naturalWidth, naturalHeight];
            if(isNaN(scale)) { return; }
            panel.icon.setAttributes({translation:{x:0, y:0}, scale: {x:scale, y:scale}}, true);
            // image size has changed
            if(panel.icon.width != naturalWidth || panel.icon.height != naturalHeight || panel.lastScale != scale) {
                panel.setRenderItem(xdata, true);
                panel.setIconLabel();
            }
        }
    },

    iconCheckBorder: function(xdata, isError) {
        var panel = this;
        var src = panel.src || xdata.general.src;
        if(!panel.el) { return; }
        if(xdata == undefined) { xdata = panel.xdata; }
        if(TP.isThisTheActiveTab(panel) && (isError || src == undefined || src == "" || src.match(/\/panorama\/images\/s\.gif$/))) {
            panel.el.dom.style.border    = "1px dashed black";
            panel.el.dom.style.minWidth  = 20;
            panel.el.dom.style.minHeight = 20;
        } else {
            panel.el.dom.style.border    = "";
            panel.el.dom.style.minWidth  = "";
            panel.el.dom.style.minHeight = "";
            panel.iconFixSize(xdata);
        }
    }
});
