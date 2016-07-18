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
        this.setRawPosition(xdata.layout.x, xdata.layout.y);
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
        animated.to = {x:layout.x, y:layout.y};
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
        if(newStatus != undefined && oldState != newStatus) {
            panel.xdata.state = newStatus;
            if(panel.el && (oldState != 4 && oldState != undefined)) { // not when initial state was pending
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
        if(xdata.appearance.type == 'icon')        { panel.iconSetSourceFromState(xdata); }
        /* no need for changes if we are not the active tab */
        if(!TP.isThisTheActiveTab(panel)) { return; }
        if(xdata.appearance.type == 'shape')       { panel.shapeRender(xdata);            }
        if(xdata.appearance.type == 'pie')         { panel.pieRender(xdata);              }
        if(xdata.appearance.type == 'speedometer') { panel.speedoRender(xdata);           }
        if(xdata.appearance.type == 'connector')   { panel.connectorRender(xdata);        }
        if(xdata.appearance.type == 'perfbar')     { panel.perfbarRender(xdata);          }
    },

    /* rotates this thing */
    applyRotation: function(value, xdata) {
        if(xdata == undefined) { xdata = this.xdata; }
        if(value == undefined) { return; }
        if(isNaN(value)) { return; }
        if(xdata.appearance && xdata.appearance.type == "icon") {
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

        if(xdata.appearance.type == 'icon' || xdata.appearance.type == 'shape' || xdata.appearance.type == 'connector') {
            var drawWidth  = size;
            var drawHeight = size;
            if(xdata.appearance.type == 'connector') {
                drawWidth  = width;
                drawHeight = height;
            }
            /* shrink panel size to icon size if possible (non-edit mode and not rotated) */
            delete panel.shrinked;
            if(xdata.appearance.type == 'icon' && xdata.layout.rotation == 0 && scale == 1 && panel.locked) {
                panel.shrinked = { size: size, x: panel.xdata.layout.x, y: panel.xdata.layout.y };
                x=0;
                y=0;
                drawWidth  = width;
                drawHeight = height;
                panel.setSize(drawWidth, drawHeight);
                panel.setPosition(panel.xdata.layout.x+((size-width)/2), panel.xdata.layout.y+((size-height)/2));
            }

            var items = [];
            if(xdata.appearance.type == 'icon') {
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
                        if(xdata.appearance.type == 'icon') {
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
        else if(xdata.appearance.type == 'pie') {
            var pieStore = Ext.create('Ext.data.Store', {
                fields: ['name','value'],
                data:  []
            });
            panel.add({
                xtype:  'tp_piechart',
                store:   pieStore,
                panel:   panel,
                animate: false,
                shadow:  false, // xdata.appearance.pieshadow, // not working atm
                donut:   xdata.appearance.piedonut,
                listeners: {
                    afterrender: function(This, eOpts) {
                        panel.itemRendering = false;
                        panel.chart = This;
                        panel.updateRender(xdata);
                    }
                }
            });
        }
        else if(xdata.appearance.type == 'speedometer') {
            panel.add({
                xtype:       'tp_speedochart',
                store:        [0],
                panel:        panel,
                insetPadding: xdata.appearance.speedomargin > 0 ? xdata.appearance.speedomargin + 20 : 10,
                shadow:       xdata.appearance.speedoshadow,
                donut:        xdata.appearance.speedodonut,
                needle:       xdata.appearance.speedoneedle,
                axis_margin:  xdata.appearance.speedomargin == 0 ? 0.1 : xdata.appearance.speedomargin,
                axis_steps:   xdata.appearance.speedosteps,
                axis_min:     xdata.appearance.speedoaxis_min ? xdata.appearance.speedoaxis_min : 0,
                axis_max:     xdata.appearance.speedoaxis_max ? xdata.appearance.speedoaxis_max : 0,
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
        }
        else if(xdata.appearance.type == 'perfbar') {
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
        }
        else {
            panel.itemRendering = false;
        }
    },

    /* renders speedometer chart */
    speedoRender: function(xdata, forceColor) {
        var panel = this;
        if(xdata == undefined) { xdata = panel.xdata; }
        if(xdata.appearance.type != 'speedometer') { return }
        if(!panel.chart) {
            panel.setRenderItem(xdata);
            return;
        }
        var extraSpace = 0;
        if(!panel.items.getAt || !panel.items.getAt(0)) { return; }
        panel.items.getAt(0).setSize(xdata.appearance.speedowidth, xdata.appearance.speedowidth/1.8);
        panel.setSize(xdata.appearance.speedowidth, xdata.appearance.speedowidth/1.8);
        var colors = {
            pending:  xdata.appearance.speedocolor_pending  ? xdata.appearance.speedocolor_pending  : '#ACACAC',
            ok:       xdata.appearance.speedocolor_ok       ? xdata.appearance.speedocolor_ok       : '#00FF33',
            warning:  xdata.appearance.speedocolor_warning  ? xdata.appearance.speedocolor_warning  : '#FFDE00',
            unknown:  xdata.appearance.speedocolor_unknown  ? xdata.appearance.speedocolor_unknown  : '#FF9E00',
            critical: xdata.appearance.speedocolor_critical ? xdata.appearance.speedocolor_critical : '#FF5B33',
            bg:       xdata.appearance.speedocolor_bg       ? xdata.appearance.speedocolor_bg       : '#DDDDDD'
        };

        // which source to use
        var state  = xdata.state, value = 0, min = 0, max = 100;
        var warn_min, warn_max, crit_min, crit_max;
        var factor = xdata.appearance.speedofactor == '' ? Number(1) : Number(xdata.appearance.speedofactor);
        if(isNaN(factor)) { factor = 1; }

        if(state == undefined) { state = panel.xdata.state; }
        if(xdata.appearance.speedosource == undefined) { xdata.appearance.speedosource = 'problems'; }
        var matchesP = xdata.appearance.speedosource.match(/^perfdata:(.*)$/);
        var matchesA = xdata.appearance.speedosource.match(/^avail:(.*)$/);
        if(matchesP && matchesP[1]) {
            var macros  = TP.getPanelMacros(panel);
            if(macros.perfdata[matchesP[1]]) {
                var p = macros.perfdata[matchesP[1]];
                value = p.val;
                var r = TP.getPerfDataMinMax(p, '?');
                if(Ext.isNumeric(r.max)) {
                    max   = r.max * factor;
                }
                min   = r.min * factor;
                if(Ext.isNumeric(p.warn_min)) { warn_min = p.warn_min * factor; }
                if(Ext.isNumeric(p.warn_max)) { warn_max = p.warn_max * factor; }
                if(Ext.isNumeric(p.crit_min)) { crit_min = p.crit_min * factor; }
                if(Ext.isNumeric(p.crit_max)) { crit_max = p.crit_max * factor; }
            }
        }
        else if(matchesA && matchesA[1]) {
            if(TP.availabilities && TP.availabilities[panel.id] && TP.availabilities[panel.id][matchesA[1]] && TP.availabilities[panel.id][matchesA[1]].last != undefined) {
                value = Number(TP.availabilities[panel.id][matchesA[1]].last);
                max   = 100;
                min   = 0;
            }
        }
        else if(xdata.appearance.speedosource == 'problems' || xdata.appearance.speedosource == 'problems_warn') {
            var totals = this.getTotals(xdata, colors);
            max = 0;
            Ext.Array.each(totals, function(t,i) {
                max += t.value;
                if(t.name == 'critical' || t.name == 'unknown' || t.name == 'down' || t.name == 'unreachable') {
                    value += t.value;
                }
                if(xdata.appearance.speedosource == 'problems_warn' && t.name == 'warning') {
                    value += t.value;
                }
            });
        }
        // override min / max by option
        if(xdata.appearance.speedomin != undefined && xdata.appearance.speedomin != '') { min = Number(xdata.appearance.speedomin); }
        if(xdata.appearance.speedomax != undefined && xdata.appearance.speedomax != '') { max = Number(xdata.appearance.speedomax); }

        if(panel.chart.axes.getAt(0).minimum != min || panel.chart.axes.getAt(0).maximum != max) {
            if(!isNaN(min) && !isNaN(max)) {
                xdata.appearance.speedoaxis_min = min;
                xdata.appearance.speedoaxis_max = max;
                panel.setRenderItem(xdata);
                return;
            }
        }

        value *= factor;

        /* inverted value? */
        if(xdata.appearance.speedoinvert) {
            value = max - value;
        }
        if(value > max) { value = max; } // value cannot exceed speedo
        if(value < min) { value = min; } // value cannot exceed speedo
        var color_fg = colors['unknown'];
        if(state == 0) { color_fg = colors['ok'];       }
        if(state == 1) { color_fg = colors['warning'];  }
        if(state == 2) { color_fg = colors['critical']; }
        if(state == 3) { color_fg = colors['unknown'];  }
        if(state == 4) { color_fg = colors['pending'];  }

        /* translate host state */
        if(panel.iconType == 'host') {
            if(state == 1) { color_fg = colors['critical']; }
            if(state == 2) { color_fg = colors['warning'];  }
        }

        if(panel.chart.surface.existingGradients == undefined) { panel.chart.surface.existingGradients = {} }

        /* warning / critical thresholds */
        panel.chart.series.getAt(0).ranges = [];
        panel.chart.series.getAt(0).lines  = [];
        if(xdata.appearance.speedo_thresholds == 'undefined') { xdata.appearance.speedo_thresholds = 'line'; }
        if(value == 0) { value = 0.0001; } // doesn't draw anything otherwise
        var color_bg = panel.speedoGetColor(colors, 0, forceColor, 'bg');
        if(!!xdata.appearance.speedoneedle) {
            if(xdata.appearance.speedo_thresholds == 'hide') {
                color_bg = panel.speedoGetColor(color_fg, xdata.appearance.speedogradient, forceColor)
            }
            else if(xdata.appearance.speedo_thresholds == 'filled') {
                color_bg = panel.speedoGetColor(colors, xdata.appearance.speedogradient, forceColor, 'ok')
            }
        }
        panel.chart.series.getAt(0).ranges.push({
            from:  min,
            to:    max,
            color: color_bg
        });
        if(warn_max != undefined) {
            if(xdata.appearance.speedo_thresholds == 'fill') {
                if(warn_min == undefined) {
                    warn_min = warn_max;
                    if(crit_min != undefined) {
                        warn_max = crit_min;
                    }
                    else if(crit_max != undefined) {
                        warn_max = crit_max;
                    }
                    else {
                        warn_max = max;
                    }
                }
                panel.chart.series.getAt(0).ranges.push({
                    from:  warn_min,
                    to:    warn_max,
                    color: panel.speedoGetColor(colors, xdata.appearance.speedogradient, forceColor, 'warning')
                });
            }
            else if(xdata.appearance.speedo_thresholds == 'line') {
                panel.chart.series.getAt(0).lines.push({
                    value: warn_max,
                    color: panel.speedoGetColor(colors, 0, forceColor, 'warning')
                });
                if(warn_min != undefined && warn_min != warn_max) {
                    panel.chart.series.getAt(0).lines.push({
                        value: warn_min,
                        color: panel.speedoGetColor(colors, 0, forceColor, 'warning')
                    });
                }
            }
        }
        if(crit_max != undefined) {
            if(xdata.appearance.speedo_thresholds == 'fill') {
                if(crit_min == undefined) { crit_min = crit_max; crit_max = max; }
                panel.chart.series.getAt(0).ranges.push({
                    from:  crit_min,
                    to:    crit_max,
                    color: panel.speedoGetColor(colors, xdata.appearance.speedogradient, forceColor, 'critical')
                });
            }
            else if(xdata.appearance.speedo_thresholds == 'line') {
                panel.chart.series.getAt(0).lines.push({
                    value: crit_max,
                    color: panel.speedoGetColor(colors, 0, forceColor, 'critical')
                });
                if(crit_min != undefined && crit_min != crit_max) {
                    panel.chart.series.getAt(0).lines.push({
                        value: crit_min,
                        color: panel.speedoGetColor(colors, 0, forceColor, 'critical')
                    });
                }
            }
        }

        if(!xdata.appearance.speedoneedle) {
            panel.chart.series.getAt(0).ranges.push({
                from:  0,
                to:    value,
                color: panel.speedoGetColor(color_fg, xdata.appearance.speedogradient, forceColor)
            });
        }
        panel.chart.series.getAt(0).value = value;
        if(panel.chart.series.getAt(0).setValue)   { panel.chart.series.getAt(0).setValue(value); }
        if(panel.chart.series.getAt(0).drawSeries) { panel.chart.series.getAt(0).drawSeries();    }
    },

    speedoGetColor: function(colors, gradient_val, forceColor, type) {
        var panel = this;
        var color;
        if(type != undefined) {
            color = colors[type];
            if(forceColor && forceColor.scope.name == "speedocolor_"+type) { color = forceColor.color; }
        } else {
            color = colors;
            if(forceColor) { color = forceColor.color; }
        }
        if(gradient_val != 0) {
            var gradient = TP.createGradient(color, gradient_val);
            if(panel.chart.surface.existingGradients[gradient.id] == undefined) {
                panel.chart.surface.existingGradients[gradient.id] = true;
                panel.chart.surface.addGradient(gradient);
            }
            return('url(#'+gradient.id+')');
        }
        return(color);
    },

    /* renders pie chart */
    pieRender: function(xdata, forceColor) {
        var panel = this;
        if(xdata == undefined) { xdata = panel.xdata; }
        if(xdata.appearance.type != 'pie') { return }
        if(!panel.chart) {
            panel.setRenderItem(xdata);
            return;
        }
        if(panel.itemRendering) { return; }
        if(xdata.appearance.pielocked) { xdata.appearance.pieheight = xdata.appearance.piewidth; }
        if(!panel.items.getAt || !panel.items.getAt(0)) { return; }
        panel.items.getAt(0).setSize(xdata.appearance.piewidth, xdata.appearance.pieheight);
        panel.setSize(xdata.appearance.piewidth, xdata.appearance.pieheight);
        var colors = {
            up:          xdata.appearance.piecolor_up          ? xdata.appearance.piecolor_up          : '#00FF33',
            down:        xdata.appearance.piecolor_down        ? xdata.appearance.piecolor_down        : '#FF5B33',
            unreachable: xdata.appearance.piecolor_unreachable ? xdata.appearance.piecolor_unreachable : '#FF7A59',
            pending:     xdata.appearance.piecolor_pending     ? xdata.appearance.piecolor_pending     : '#ACACAC',
            ok:          xdata.appearance.piecolor_ok          ? xdata.appearance.piecolor_ok          : '#00FF33',
            warning:     xdata.appearance.piecolor_warning     ? xdata.appearance.piecolor_warning     : '#FFDE00',
            unknown:     xdata.appearance.piecolor_unknown     ? xdata.appearance.piecolor_unknown     : '#FF9E00',
            critical:    xdata.appearance.piecolor_critical    ? xdata.appearance.piecolor_critical    : '#FF5B33'
        };
        var totals   = this.getTotals(xdata, colors);
        var colorSet = [];
        if(panel.chart.surface.existingGradients == undefined) { panel.chart.surface.existingGradients = {} }
        Ext.Array.each(totals, function(t,i) {
            var color = t.color;
            if(forceColor) { color = forceColor; }
            if(xdata.appearance.piegradient != 0) {
                var gradient = TP.createGradient(color, xdata.appearance.piegradient);
                if(panel.chart.surface.existingGradients[gradient.id] == undefined) {
                    panel.chart.surface.existingGradients[gradient.id] = true;
                    panel.chart.surface.addGradient(gradient);
                }
                colorSet.push('url(#'+gradient.id+')');
            } else {
                colorSet.push(color);
            }
        });
        panel.chart.series.getAt(0).colorSet = colorSet;
        var pieStore = Ext.create('Ext.data.Store', {
            fields: ['name','value'],
            data:  []
        });
        TP.updateArrayStoreHash(pieStore, totals);
        panel.chart.bindStore(pieStore);
        panel.chart.panel.xdata.showlabel    = !!xdata.appearance.pielabel;
        panel.chart.panel.xdata.showlabelVal = !!xdata.appearance.pielabelval;
        panel.chart.setShowLabel();
    },

    /* renders shape */
    shapeRender: function(xdata, forceColor, panel) {
        if(panel == undefined) { panel = this; }
        if(xdata == undefined) { xdata = panel.xdata; }
        if(xdata.appearance.type != 'shape') { return }

        if(xdata.appearance.shapename == undefined) { return; }
        if(!panel.surface) {
            panel.setRenderItem(xdata);
            return;
        }
        if(!panel.surface.el) { return };
        var shapeData;
        TP.shapesStore.findBy(function(rec, id) {
            if(rec.data.name == xdata.appearance.shapename) {
                shapeData = rec.data.data;
            }
        });
        if(shapeData == undefined) {
            if(initial_shapes[xdata.appearance.shapename]) {
                shapeData = initial_shapes[xdata.appearance.shapename];
            } else {
                TP.Msg.msg("fail_message~~loading shape '"+xdata.appearance.shapename+"' failed: no such shape");
                return;
            }
        }

        shapeData = shapeData.replace(/,\s*$/, ''); // remove trailing commas
        shapeData += ",fill:'"+(TP.getShapeColor("shape", panel, xdata, forceColor).color)+"'";
        var spriteData;
        try {
            eval("spriteData = {"+shapeData+"};");
        }
        catch(err) {
            TP.logError(panel.id, "labelSpriteEvalException", err);
            TP.Msg.msg("fail_message~~loading shape '"+xdata.appearance.shapename+"' failed: "+err);
            return;
        }
        panel.surface.removeAll();
        sprite = panel.surface.add(spriteData);
        var box = sprite.getBBox();
        var xScale = xdata.appearance.shapewidth/box.width;
        var yScale = xdata.appearance.shapeheight/box.height;
        if(xdata.appearance.shapelocked) { yScale = xScale; }
        if(isNaN(xScale) || isNaN(yScale) || isNaN(box.x)) { return; }
        sprite.setAttributes({scale:{x:xScale,y:yScale}}, true);
        box = sprite.getBBox();
        sprite.setAttributes({translate:{x:-box.x,y:-box.y}}, true);
        panel.setSize(Math.ceil(box.width), Math.ceil(box.height));
        if(panel.items.getAt && panel.items.getAt(0)) {
            panel.items.getAt(0).setSize(Math.ceil(box.width), Math.ceil(box.height));
        }
        sprite.show(true);
    },
    /* renders connector */
    connectorRender: function(xdata, forceColor, panel) {
        if(panel == undefined) { panel = this; }
        if(xdata == undefined) { xdata = panel.xdata; }
        if(xdata.appearance.type != 'connector') { return }

        if(!panel.surface) {
            panel.setRenderItem(xdata);
            return;
        }

        var fromX     = xdata.appearance.connectorfromx;
        var fromY     = xdata.appearance.connectorfromy;
        var toX       = xdata.appearance.connectortox;
        var toY       = xdata.appearance.connectortoy;
        var arrowtype = xdata.appearance.connectorarrowtype;
        if(isNaN(fromX)) { return; }

        if(!panel.surface.el) { return };

        if(fromX > toX) {
            fromX = xdata.appearance.connectortox;
            fromY = xdata.appearance.connectortoy;
            toX   = xdata.appearance.connectorfromx;
            toY   = xdata.appearance.connectorfromy;
            if(     arrowtype == "right") { arrowtype = "left"; }
            else if(arrowtype == "left")  { arrowtype = "right"; }
        }
        var connectorarrowwidth = xdata.appearance.connectorarrowwidth;

        /* variable arrow sizes */
        var shapeColor = TP.getShapeColor("connector", panel, xdata, forceColor);
        var connectorwidth = xdata.appearance.connectorwidth;
        if(xdata.appearance.connectorvariable) {
            var percent = 100;
            var state   = xdata.state != undefined ? xdata.state : panel.xdata.state;
            if(shapeColor.value != undefined) {
                var min   = shapeColor.range.min;
                var max   = shapeColor.range.max;
                if(xdata.appearance.connectormin != undefined) { min = xdata.appearance.connectormin; }
                if(xdata.appearance.connectormax != undefined) { max = xdata.appearance.connectormax; }
                if(min == undefined) { min = 0; }
                percent = ((shapeColor.value-min) / (max-min)) * 100;
                if(percent > 100) { percent = 100 }
            }
            else if(state == 0) { percent =   0; }
            else if(state == 1) { percent =  50; }
            else if(state == 2) { percent = 100; }
            else if(state == 3) { percent =  50; }
            else if(state == 4) { percent =   0; }
            connectorwidth = connectorwidth * (percent/100);
            if(connectorwidth < 1)    { connectorwidth = 1; }
            if(isNaN(connectorwidth)) { connectorwidth = 1; }
        }

        /* calculate distance, draw horizontal arrow with that length and rotate it later. save a lot of work to rotate by ourselves */
        var distance  = Math.ceil(Math.sqrt(Math.pow(toX-fromX, 2)
                                          + Math.pow(toY-fromY, 2)));
        if(isNaN(distance) || distance == 0) {
            return;
        }
        var start = [ 0, 0 ];
        var end   = [ distance, 0 ];

        /* get angle between points */
        var angle = Math.atan((toY-fromY)/(toX-fromX))*180/Math.PI;

        var points = [[start[0],start[1]]];
        /* top half of left arrow */
        if(arrowtype == "both" || arrowtype == "left") {
            points.push(
                [(start[0]+xdata.appearance.connectorarrowlength), (start[1]-connectorwidth/2-connectorarrowwidth)],
                [(start[0]+xdata.appearance.connectorarrowlength-xdata.appearance.connectorarrowinset), (start[1]-connectorwidth/2)]
            );
        } else {
            points.push(
                [start[0], (start[1]-connectorwidth/2)]
            );
        }

        /* right arrow */
        if(arrowtype == "both" || arrowtype == "right") {
            points.push(
                [end[0]-xdata.appearance.connectorarrowlength+xdata.appearance.connectorarrowinset, (end[1]-connectorwidth/2)],
                [end[0]-xdata.appearance.connectorarrowlength, (end[1]-connectorwidth/2-connectorarrowwidth)],
                [end[0], end[1]],
                [end[0]-xdata.appearance.connectorarrowlength, (end[1]+connectorwidth/2+connectorarrowwidth)],
                [end[0]-xdata.appearance.connectorarrowlength+xdata.appearance.connectorarrowinset, (end[1]+connectorwidth/2)]
            );
        } else {
            points.push(
                [end[0], (end[1]-connectorwidth/2)],
                [end[0], (end[1]+connectorwidth/2)]
            );
        }

        /* bottom half of left arrow */
        if(arrowtype == "both" || arrowtype == "left") {
            points.push(
                [(start[0]+xdata.appearance.connectorarrowlength-xdata.appearance.connectorarrowinset), (start[1]+connectorwidth/2)],
                [(start[0]+xdata.appearance.connectorarrowlength), (start[1]+connectorwidth/2+connectorarrowwidth)]
            );
        } else {
            points.push(
                [start[0], (start[1]+connectorwidth/2)]
            );
        }

        panel.surface.removeAll();
        sprite = panel.surface.add({
            type: "path",
            path: TP.pointsToPath(points),
            fill: shapeColor.color
        });
        sprite.setAttributes({rotate:{degrees: angle, x:0, y:0}}, true);
        var box = sprite.getBBox();
        sprite.setAttributes({translate:{x:-box.x,y:-box.y+(arrowtype == "none" ? connectorarrowwidth : 0)}}, true);
        var newHeight = Math.ceil(Ext.Array.max([connectorarrowwidth+connectorwidth, box.height]));
        panel.setSize(Math.ceil(box.width), newHeight);
        panel.surface.setSize(Math.ceil(box.width), newHeight);
        panel.surface.el.dom.parentNode.style.width  = Math.ceil(box.width)+"px";
        panel.surface.el.dom.parentNode.style.height = newHeight+"px";
        sprite.show(true);
        /* adjust position: first point in path is the rotated start point, so we can get our current offset from there */
        xdata.layout.x = Math.ceil(fromX-box.path[0][1]+box.x);
        xdata.layout.y = Math.ceil(fromY-box.path[0][2]+box.y);
        panel.setRawPosition(xdata.layout.x, xdata.layout.y);
        panel.updateMapLonLat(true);

        /* adjust drag elements position */
        Ext.Array.each([panel.dragEl1, panel.dragEl2], function(dragEl) {
            if(dragEl != undefined) {
                dragEl.suspendEvents();
                dragEl.setPosition(xdata.appearance[dragEl.keyX]+dragEl.offsetX, xdata.appearance[dragEl.keyY]+dragEl.offsetY);
                dragEl.resumeEvents();
                try { dragEl.toFront(); } catch(err) {}
            }
        });

        /* enable popups only over the actual arrow */
        if(!TP.suppressIconTip) {
            sprite.on('mouseover', function(el, evt, eOpts) {
                TP.suppressIconTip = false;
            });
            sprite.on('mouseout', function(el, evt, eOpts) {
                TP.suppressIconTip = true;
            });
            panel.el.on('mouseover', function(evt, el, eOpts) {
                if(evt.target.tagName != "rect") { return; }
                TP.suppressIconTip = true;
            });
            panel.el.on('mouseout', function(evt, el, eOpts) {
                if(evt.target.tagName != "rect") { return; }
                TP.suppressIconTip = false;
            });
            if(panel.labelEl && panel.labelEl.el) {
                panel.labelEl.el.on('mouseover', function(evt, el, eOpts) {
                    TP.suppressIconTip = false;
                });
                panel.labelEl.el.on('mouseout', function(evt, el, eOpts) {
                    TP.suppressIconTip = true;
                });
            }
        }
    },
    /* renders performance bar */
    perfbarRender: function(xdata, forceColor) {
        var panel = this;
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
    },
    iconSetSourceFromState: function(xdata) {
        var panel = this;
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
            } else {
                panel.setSize(size, size);
            }
            if(panel.items.getAt && panel.items.getAt(0)) {
                panel.items.getAt(0).setSize(size, size);
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
