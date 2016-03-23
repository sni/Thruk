Ext.define('TP.SmallWidget', {
    constructor: function(config) {
        var me = this;
        Ext.apply(me, config);

        this.shadow   = false;
        this.floating = true;
        this.stateful = true;
        this.stateId  = this.id;
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
        this.renderTo   = "bodyview";

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
            TP.log('['+this.id+'] rendered');
            This.addClickEventhandler(This.el);

            if(!readonly && !This.locked) {
                if((This.xdata.general[This.iconType] == '' && This.firstRun != false && This.iconType != "text") || This.firstRun == true) {
                    This.firstRun = true;
                    TP.timeouts['timeout_' + This.id + '_show_settings'] = window.setTimeout(function() {
                        // show dialog delayed, so the panel has a position already
                        var pos = This.getPosition();
                        This.xdata.layout.x = pos[0];
                        This.xdata.layout.y = pos[1];
                        if(This.iconType != 'text') {
                            TP.iconShowEditDialog(This);
                        }
                    }, 50);
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
            /* make sure we don't overlap dashboard settings window */
            TP.checkModalWindows();
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
        var This = this;
        This.effectiveZindex = value;
        var tab = Ext.getCmp(This.panel_id);
        tab.scheduleApplyZindex();
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

    /* render label for this widget */
    setIconLabel: function(cfg, force_perfdata) {
        var panel = this;
        if(cfg       == undefined) { cfg       = this.xdata.label; }
        if(!this.el || !this.el.dom)  { return; }
        if(!this.el.dom.style.zIndex && cfg && cfg.labeltext) {
            var tab  = Ext.getCmp(panel.panel_id);
            tab.scheduleApplyZindex();
            return;
        }
        if(TP.removeLabel && TP.removeLabel[panel.id]) {
            /* remove later to avoid flickering during redraw */
            window.clearTimeout(TP.timeouts['remove_label_'+panel.id]);
            TP.timeouts['remove_label_'+panel.id] = window.setTimeout(function() {
                TP.removeLabel[panel.id].destroy();
                delete TP.removeLabel[panel.id];
                panel.setIconLabel(cfg, force_perfdata);
            }, 100);
        }
        if(cfg == undefined) { return; }
        var txt = String(cfg.labeltext);
        if(txt == undefined) { txt = ''; }
        this.el.dom.title = '';

        /* hide the icon element for label only appearance */
        if(panel.locked && panel.el) {
            if(panel.xdata.appearance.type == "none") {
                panel.el.dom.style.display = "none";
            }
        }

        /* dynamic label? */
        if(force_perfdata || txt.match(/\{\{.*?\}\}/)) {
            var allowed_functions = ['strftime', 'sprintf', 'if', 'availability'];
            if(TP.availabilities == undefined) { TP.availabilities = {}; }
            if(TP.availabilities[panel.id] == undefined) { TP.availabilities[panel.id] = {}; }
            var matches           = txt.match(/(\{\{.*?\}\})/g);
            if(this.servicegroup) { totals = this.servicegroup; }
            if(this.hostgroup)    { totals = this.hostgroup; }
            if(this.results)      { totals = this.results; }
            if(this.host)         { for(var key in this.host)    { window[key] = this.host[key];    } window['performance_data'] = this.host['perf_data']; }
            if(this.service)      { for(var key in this.service) { window[key] = this.service[key]; } window['performance_data'] = this.service['perf_data']; }
            if(window.perf_data) {
                window.perf_data = parse_perf_data(window.perf_data);
                window.perfdata = {};
                for(var x = 0; x < window.perf_data.length; x++) {
                    var d = window.perf_data[x];
                    window.perfdata[d.key] = d;
                }
            } else {
                window.perfdata = {};
            }
            Ext.Array.each(matches, function(item, idx) {
                var calc      = item.replace(/^\{\{/, '').replace(/\}\}$/, '');
                var functions = calc.match(/[\w+_]+\(/g);
                var ok        = true;
                // only run a few allow functions
                Ext.Array.each(functions, function(f, idx) {
                    f = f.replace(/\($/, '');
                    if(!Ext.Array.contains(allowed_functions, f)) {
                        debug("function "+f+" is not allowed");
                        ok = false;
                    }
                });
                if(!ok) { return; }
                var res = '';
                calc = calc.replace(/availability\(/g, 'availability(panel, ');
                try {
                    res = eval(calc);
                } catch(err) {
                    TP.logError(panel.id, "labelEvalException", err);
                    panel.el.dom.title = err;
                }
                if(res == undefined) { res = ''; }
                // replace not yet resolved availabilities
                if(calc.match(/availability\(/)) {
                    if(TP.lastAvailError) {
                        TP.lastAvailError = TP.lastAvailError.replace(/'/g, '');
                        TP.lastAvailError = TP.lastAvailError.replace(/ at .*?\/Thruk/g, ' at Thruk');
                        res = "<span class='avail_result_error' title='"+TP.lastAvailError+"'>error<\/span>";
                    }
                    else if(res.match(/\-1/)) {
                        res = res.replace(/\-1[\.0]*/g, '...');
                        res = "<span class='avail_result_not_ready' title='not yet ready'>"+res+"<\/span>";
                    }
                }
                txt = txt.replace(item, res);
            });
            /* remove inactive availabilities */
            var remove_older = (Math.floor(new Date().getTime()/1000)) - 120;
            for(var key in TP.availabilities[panel.id]) {
                if(TP.availabilities[panel.id][key]['active'] < remove_older) {
                    delete TP.availabilities[panel.id][key];
                }
            }
            /* update value since it might have changed */
            if(panel.xdata.appearance.type == 'speedometer' && panel.xdata.appearance.speedosource.match(/^avail:(.*)$/)) {
                panel.updateRender(panel.xdata);
            }
        }
        /* no label at all */
        if(!cfg.labeltext) {
            if(this.labelEl) { this.labelEl.destroy(); this.labelEl = undefined; }
            return;
        }
        if(!this.labelEl) {
            var panel = this;
            if(!TP.isThisTheActiveTab(panel)) { return; } /* no need for a label on inactive tab */
            this.labelEl = Ext.create('Ext.Component', {
                'html':     ' ',
                panel:       panel,
                draggable:  !panel.locked,
                shadow:     false,
                renderTo:  "bodyview",
                cls:        ((panel.xdata.link && panel.xdata.link.link) ? '' : 'not') +'clickable iconlabel tooltipTarget', // defaults to text cursor otherwise
                style:      {
                    whiteSpace: 'nowrap'
                },
                autoEl: {
                    tag:     'a',
                    href:    panel.xdata.link ? panel.xdata.link.link : '',
                    target:  '',
                    onclick: "return(false);"
                },
                listeners: {
                    /* move parent element according to our drag / drop */
                    move: function(This, x, y, eOpts) {
                        var diffX = 0, diffY = 0;
                        if(x != undefined && This.oldX != undefined) { diffX = x - This.oldX; }
                        if(y != undefined && This.oldY != undefined) { diffY = y - This.oldY; }
                        if(x != undefined) { This.oldX = x; }
                        if(y != undefined) { This.oldY = y; }
                        if(diffX != 0 || diffY != 0) {
                            var pos = panel.getPosition();
                            var newX = pos[0]+diffX;
                            var newY = pos[1]+diffY;
                            panel.setRawPosition(newX, newY);
                            // update settings window
                            if(TP.iconSettingsWindow) {
                                TP.iconSettingsWindow.items.getAt(0).items.getAt(1).down('form').getForm().setValues({x:newX, y:newY});
                            } else if(panel.iconType == "text" && !panel.readonly) {
                                panel.xdata.layout.x = newX;
                                panel.xdata.layout.y = newY;
                                panel.saveState();
                            }
                        }
                    },
                    boxready: function( This, width, height, eOpts ) {
                        panel.addDDListener(This);
                    },
                    afterrender: function(This, eOpts) {
                        panel.addClickEventhandler(This.el);
                        panel.addDDListener(This);
                        if(!panel.locked) {
                            This.el.on('mouseover', function(evt,t,a) {
                                if(!panel.el) { return; }
                                if(!panel.el.dom.style.outline.match("orange") && !This.el.dom.style.outline.match("orange")) {
                                    This.el.dom.style.outline = "1px dashed grey";
                                    if(panel.iconType != "text") {
                                        panel.el.dom.style.outline = "1px dashed grey";
                                    }
                                }
                            });
                            This.el.on('mouseout', function(evt,t,a) {
                                if(This.el.dom.style.outline.match("grey")) {
                                    This.el.dom.style.outline = "";
                                }
                                if(panel.el && panel.el.dom && panel.el.dom.style.outline.match("grey")) {
                                    panel.el.dom.style.outline = "";
                                }
                            });
                        }
                    },
                    show: function( This, eOpts ) {
                        panel.addDDListener(This);
                        /* make sure we don't overlap dashboard settings window */
                        TP.checkModalWindows();
                    }
                }
            });
            if(panel.rotateLabel) {
                panel.rotateEl = panel.labelEl.el;
            }
            panel.applyRotation(panel.xdata.layout.rotation);
        }
        var el = this.labelEl.el.dom;
        el.style.zIndex       = Number(this.el.dom.style.zIndex)+1; /* keep above icon */
        this.labelEl.update(txt);
        el.style.color        = cfg.fontcolor;
        el.style.fontFamily   = cfg.fontfamily;
        el.style.background   = cfg.bgcolor;
        el.style.fontWeight   = cfg.fontbold   ? 'bold'   : 'normal';
        el.style.fontStyle    = cfg.fontitalic ? 'italic' : 'normal';
        el.style.paddingLeft  = "3px";
        el.style.paddingRight = "3px";
        if(cfg.orientation == 'vertical') { this.labelEl.addCls('vertical');    }
        else                              { this.labelEl.removeCls('vertical'); }

        var left          = TP.extract_number_with_unit({ value: this.el.dom.style.left, unit:'px',  floor: true, defaultValue: 100 });
        var top           = TP.extract_number_with_unit({ value: this.el.dom.style.top,  unit:'px',  floor: true, defaultValue: 100 });
        var offsetx       = TP.extract_number_with_unit({ value: cfg.offsetx,            unit:' px', floor: true, defaultValue:   0 });
        var offsety       = TP.extract_number_with_unit({ value: cfg.offsety,            unit:' px', floor: true, defaultValue:   0 });
        var fontsize      = TP.extract_number_with_unit({ value: cfg.fontsize,           unit:' px', floor: true, defaultValue:  14 });
        var elWidth       = TP.extract_number_with_unit({ value: this.width,             unit:'',    floor: true, defaultValue:   0 });
        var elHeight      = TP.extract_number_with_unit({ value: this.height,            unit:'',    floor: true, defaultValue:   0 });
        var bordersize    = TP.extract_number_with_unit({ value: cfg.bordersize,         unit:' px', floor: true, defaultValue:   0 });

        if(cfg.bordercolor && bordersize > 0) {
            el.style.border = bordersize+"px solid "+cfg.bordercolor;
        } else {
            el.style.border = "";
        }

        if(cfg.width == undefined || cfg.width == '') {
            el.style.width = '';
        } else {
            el.style.width = cfg.width+"px";
        }
        if(cfg.height == undefined || cfg.height == '') {
            el.style.height = '';
        } else {
            el.style.height = cfg.height+"px";
        }

        el.style.fontSize = fontsize+'px';
        var size          = this.labelEl.getSize();
        if(size.width == 0) { return; }

        if(cfg.position == 'above') {
            top = top - offsety - size.height;
            if(cfg.orientation == 'horizontal') {
                left = left + (elWidth / 2) - (size.width / 2) + 2;
            }
            left = left - offsetx;
        }
        if(cfg.position == 'below') {
            top = top + offsety + elHeight;
            if(cfg.orientation == 'horizontal') {
                left = left + (elWidth / 2) - (size.width / 2) + 2;
            }
            left = left - offsetx;
        }
        if(cfg.position == 'right') {
            left = left + offsety + elWidth + 2;
            if(cfg.orientation == 'horizontal') {
                top  = top + elHeight/2 - size.height/2;
            }
            top = top - offsetx;
        }
        if(cfg.position == 'left') {
            left = left - offsety - size.width - 2;
            if(cfg.orientation == 'horizontal') {
                top  = top + elHeight/2 - size.height/2;
            }
            top = top - offsetx;
        }
        if(cfg.position == 'center') {
            top  = top + offsety + (elHeight/2) - (size.height/2);
            left = left + (elWidth / 2) - (size.width / 2) - offsetx;
        }
        if(cfg.position == 'top-left') {
            top  = top + offsety;
            left = left + offsetx;
        }
        el.style.left = left+"px";
        el.style.top  = top+"px";
        this.labelEl.oldX = left;
        this.labelEl.oldY = top;
    },

    /* add dbl click and context menu events */
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
                    tab.body.mask("loading settings");
                    window.setTimeout(function() {
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
                        handler: function() { TP.iconShowEditDialog(This) },
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
                    }
                }
            }).showBy(This);
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
                    panel.ddShadow = Ext.DomHelper.insertFirst(document.body, '<div style="border: 1px dashed black; width: '+size.width+'px; height: '+size.height+'px; position: relative; z-index: 99999; top: 0px; ; left: 0px; display: hidden;"><div style="border: 1px dashed white; width:'+(size.width-2)+'px; height:'+(size.height-2)+'px; position: relative; top: 0px; ; left: 0px;" ><\/div><\/div>' , true);
                }
                if(!panel.dragHint) {
                    panel.dragHint = Ext.DomHelper.insertFirst(document.body, '<div style="border: 1px solid grey; border-radius: 2px; background: #CCCCCC; position: absolute; z-index: 99999; top: -1px; left: 35%; padding: 3px;">Tip: hold shift key to enable grid snap.<\/div>' , true);
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
        var tab   = Ext.getCmp(this.panel_id);
        tab.scheduleApplyZindex();
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

        /* update zIndex order if no mask is present only */
        var masks = Ext.Element.select('.x-mask');
        if(masks.elements.length > 0) { return }
        if(panel.labelEl) { try { panel.labelEl.toFront(); } catch(err) {} }
        TP.checkModalWindows();
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
            size     = xdata.size;
            size     = Math.ceil((Math.sqrt(Math.pow(width, 2) + Math.pow(height, 2)))*scale);
            panel.setSize(size, size);
        } else if(panel.xdata.size && panel.xdata.nsize && panel.xdata.nsize[0] > 1) {
            x        = (panel.xdata.size - panel.xdata.nsize[0]) / 2;
            y        = (panel.xdata.size - panel.xdata.nsize[1]) / 2;
            width    = panel.xdata.nsize[0];
            height   = panel.xdata.nsize[1];
            size     = panel.xdata.size;
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
                    panel:      panel,
                    xdata:      xdata,
                    keyX:       "connectorfromx",
                    keyY:       "connectorfromy",
                    offsetX:    -12,
                    offsetY:    -12
                });
                panel.dragEl2 = Ext.create('TP.dragEl', {
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
                    resize: function(This, eOpts) {
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
        var factor = xdata.appearance.speedofactor == '' ? Number(1) : Number(xdata.appearance.speedofactor);
        if(isNaN(factor)) { factor = 1; }

        if(state == undefined) { state = panel.xdata.state; }
        if(xdata.appearance.speedosource == undefined) { xdata.appearance.speedosource = 'problems'; }
        var matchesP = xdata.appearance.speedosource.match(/^perfdata:(.*)$/);
        var matchesA = xdata.appearance.speedosource.match(/^avail:(.*)$/);
        if(matchesP && matchesP[1]) {
            window.perfdata = {};
            panel.setIconLabel(undefined, true);
            if(perfdata[matchesP[1]]) {
                var p = perfdata[matchesP[1]];
                value = p.val;
                var r = TP.getPerfDataMinMax(p, '?');
                max   = r.max * factor;
                min   = r.min * factor;
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
            xdata.appearance.speedoaxis_min = min;
            xdata.appearance.speedoaxis_max = max;
            panel.setRenderItem(xdata);
            return;
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

        var colorSet = [];
        if(panel.chart.surface.existingGradients == undefined) { panel.chart.surface.existingGradients = {} }
        Ext.Array.each([color_fg, colors['bg']], function(color,i) {
            if(forceColor) { color = forceColor; }
            if(xdata.appearance.speedogradient != 0) {
                var gradient = TP.createGradient(color, xdata.appearance.speedogradient);
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
        if(panel.chart.series.getAt(0).setValue) {
            if(value == 0) { value = 0.0001; } // doesn't draw anything otherwise
            panel.chart.series.getAt(0).setValue(value);
        }
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
        else if(panel.iconType == 'host') {
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
            panel.setSize(size, size);
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
            }
            this.setIconLabel();
        }
    },
    iconCheckBorder: function(xdata, isError) {
        var panel = this;
        var src = panel.src || xdata.general.src;
        if(!panel.el) { return; }
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

/* Host Status Icon */
Ext.define('TP.HostStatusIcon', {
    extend: 'TP.IconWidget',

    iconType: 'host',
    iconName: 'Hostname',
    initComponent: function() {
        var panel = this;
        this.callParent();
        this.xdata.general.incl_downtimes = false;
        this.xdata.general.incl_ack       = false;
    },
    getGeneralItems: function() {
        var panel = this;
        return([
            TP.objectSearchItem(panel, 'host', 'Hostname', panel.xdata.general.host),
            {
                fieldLabel: 'Include Downtimes',
                xtype:      'checkbox',
                name:       'incl_downtimes',
                boxLabel:   '(alert during downtimes too)'
            }, {
                fieldLabel: 'Include Acknowledged',
                xtype:      'checkbox',
                name:       'incl_ack',
                boxLabel:   '(alert for acknowledged problems too)'
            }
        ]);
    },
    getName: function() {
        return(this.xdata.general.host);
    },
    getDetails: function() {
        var details = [];
        if(!this.host) {
            return([['Status', 'No status information available']]);
        }
        var statename = TP.text_host_status(this.xdata.state);
        details.push([ 'Current Status', '<div class="extinfostate '+statename.toUpperCase()+'">'+statename.toUpperCase()+'<\/div>'
                                        +' (for ' + TP.render_duration('', '', {data:this.host})+')<br>'
                                        +(this.acknowledged ?' (<img src='+url_prefix+'plugins/panorama/images/btn_ack.png" style="vertical-align:text-bottom"> acknowledged)':'')
                                        +(this.downtime     ?' (<img src='+url_prefix+'plugins/panorama/images/btn_downtime.png" style="vertical-align:text-bottom"> in downtime)':'')
                     ]);
        details.push([ 'Status Information', this.host.plugin_output]);
        details.push([ 'Last Check', this.host.last_check ? TP.date_format(this.host.last_check) : 'never']);
        details.push([ 'Next Check', this.host.next_check ? TP.date_format(this.host.next_check) : 'not planned']);
        details.push([ 'Last Notification', (this.host.last_notification == 0 ? 'N/A' : TP.date_format(this.host.last_notification)) + ' (notification '+this.host.current_notification_number+')']);
        if(this.host.pnp_url) {
            var now = new Date();
            var url = this.host.pnp_url+'/image?host='+this.xdata.general.host+'&srv=_HOST_&view=1&source=0&graph_width=300&graph_height=100';
            url    += '&start=' + (Math.round(now.getTime()/1000) - TP.timeframe2seconds('24h'));
            url    += '&end='   + Math.round(now.getTime()/1000);
            details.push([ '<img src="'+url+'" width="100%" border=1 style="max-height: 250px;" onload="TP.iconTip.syncShadow()">']);
        }
        return(details);
    },
    refreshHandler: function(newStatus) {
        this.acknowledged = false;
        this.downtime     = false;
        if(this.host) {
            if(this.host.scheduled_downtime_depth > 0) { this.downtime     = true; }
            if(this.host.acknowledged             > 0) { this.acknowledged = true; }
        }
        this.callParent([newStatus]);
    }
});

/* get summarized table for hosts */
TP.get_summarized_hoststatus = function(item) {
    var table = '<table class="ministatus"><tr>';
    table += '<th>Up<\/th><th>Down<\/th><th>Unreachable<\/th><th>Pending<\/th><\/tr><tr>';
    table += '<td class='+(item.up          ? 'UP'          : 'miniEmpty')+'>'+item.up+'<\/td>';
    table += '<td class='+(item.down        ? 'DOWN'        : 'miniEmpty')+'>'+item.down+'<\/td>';
    table += '<td class='+(item.unreachable ? 'UNREACHABLE' : 'miniEmpty')+'>'+item.unreachable+'<\/td>';
    table += '<td class='+(item.pending     ? 'PENDING'     : 'miniEmpty')+'>'+item.pending+'<\/td>';
    table += '<\/tr><\/table>';
    return(table);
}

/* get summarized table for services */
TP.get_summarized_servicestatus = function(item) {
    var table = '<table class="ministatus"><tr>';
    table += '<th>Ok<\/th><th>Warning<\/th><th>Unknown<\/th><th>Critical<\/th><th>Pending<\/th><\/tr><tr>';
    table += '<td class='+(item.ok       ? 'OK'       : 'miniEmpty')+'>'+item.ok+'<\/td>';
    table += '<td class='+(item.warning  ? 'WARNING'  : 'miniEmpty')+'>'+item.warning+'<\/td>';
    table += '<td class='+(item.unknown  ? 'UNKNOWN'  : 'miniEmpty')+'>'+item.unknown+'<\/td>';
    table += '<td class='+(item.critical ? 'CRITICAL' : 'miniEmpty')+'>'+item.critical+'<\/td>';
    table += '<td class='+(item.pending  ? 'PENDING'  : 'miniEmpty')+'>'+item.pending+'<\/td>';
    table += '<\/tr><\/table>';
    return(table);
}

/* returns group status */
TP.get_group_status = function(options) {
    var group          = options.group,
        incl_svc       = options.incl_svc,
        incl_hst       = options.incl_hst;
        incl_ack       = options.incl_ack;
        incl_downtimes = options.incl_downtimes;
    var s;
    var acknowledged = false;
    var downtime     = false;
    if(group.hosts    == undefined) { group.hosts    = {} }
    if(group.services == undefined) { group.services = {} }
         if(incl_svc && group.services.unknown > 0)                              { s = 3; }
    else if(incl_svc && incl_ack && group.services.ack_unknown > 0)              { s = 3; }
    else if(incl_svc && incl_downtimes && group.services.downtimes_unknown > 0)  { s = 3; }
    else if(incl_hst && group.hosts.unreachable > 0)                             { s = 2; }
    else if(incl_hst && group.hosts.down        > 0)                             { s = 2; }
    else if(incl_ack && group.hosts.ack_unreachable > 0)                         { s = 2; }
    else if(incl_ack && group.hosts.ack_down        > 0)                         { s = 2; }
    else if(incl_hst && incl_downtimes && group.hosts.downtime_down        > 0)  { s = 2; }
    else if(incl_hst && incl_downtimes && group.hosts.downtime_unreachable > 0)  { s = 2; }
    else if(incl_svc && group.services.critical > 0)                             { s = 2; }
    else if(incl_svc && incl_ack && group.services.ack_critical > 0)             { s = 2; }
    else if(incl_svc && incl_downtimes && group.services.downtimes_critical > 0) { s = 2; }
    else if(incl_svc && group.services.warning > 0)                              { s = 1; }
    else if(incl_svc && incl_ack && group.services.ack_warning > 0)              { s = 1; }
    else if(incl_svc && incl_downtimes && group.services.downtimes_warning > 0)  { s = 1; }
    else                                                                         { s = 0; }
    if(s == 0) {
        var a = 0;
             if(incl_svc && group.services.ack_unknown       > 0) { a = 3; acknowledged = true; }
        else if(incl_hst && group.hosts.ack_unreachable      > 0) { a = 2; acknowledged = true; }
        else if(incl_hst && group.hosts.ack_down             > 0) { a = 2; acknowledged = true; }
        else if(incl_svc && group.services.ack_critical      > 0) { a = 2; acknowledged = true; }
        else if(incl_svc && group.services.ack_warning       > 0) { a = 1; acknowledged = true; }

        var d = 0;
             if(incl_svc && group.services.downtimes_unknown > 0) { d = 3; downtime     = true; }
        else if(incl_hst && group.hosts.downtime_unreachable > 0) { d = 2; downtime     = true; }
        else if(incl_hst && group.hosts.downtime_down        > 0) { d = 2; downtime     = true; }
        else if(incl_svc && group.services.downtime_critical > 0) { d = 2; downtime     = true; }
        else if(incl_svc && group.services.downtime_warning  > 0) { d = 1; downtime     = true; }
        s = Ext.Array.max([a,s,d]);
    }
    return({state: s, downtime: downtime, acknowledged: acknowledged});
}


/* Hostgroup Status Icon */
Ext.define('TP.HostgroupStatusIcon', {
    extend: 'TP.IconWidget',

    iconType: 'hostgroup',
    iconName: 'Hostgroupname',
    initComponent: function() {
        var panel = this;
        this.callParent();
        this.xdata.general.incl_hst       = true;
        this.xdata.general.incl_svc       = true;
        this.xdata.general.incl_downtimes = false;
        this.xdata.general.incl_ack       = false;
    },

    getGeneralItems: function() {
        var panel = this;
        return([
            TP.objectSearchItem(panel, 'hostgroup', 'Hostgroupname', panel.xdata.general.hostgroup),
            {
                fieldLabel: 'Include Hosts',
                xtype:      'checkbox',
                name:       'incl_hst'
            }, {
                fieldLabel: 'Include Services',
                xtype:      'checkbox',
                name:       'incl_svc'
            }, {
                fieldLabel: 'Include Downtimes',
                xtype:      'checkbox',
                name:       'incl_downtimes',
                boxLabel:   '(alert during downtimes too)'
            }, {
                fieldLabel: 'Include Acknowledged',
                xtype:      'checkbox',
                name:       'incl_ack',
                boxLabel:   '(alert for acknowledged problems too)'
            }
        ]);
    },
    refreshHandler: function(newStatus) {
        // calculate summarized status
        if(this.hostgroup) {
            /* makes no sense if nothing selected but happens after switching classes */
            if(!this.xdata.general.incl_hst && !this.xdata.general.incl_svc) {
                this.xdata.general.incl_svc = true;
                this.xdata.general.incl_hst = true;
            }
            var res = TP.get_group_status({
                group:          this.hostgroup,
                incl_ack:       this.xdata.general.incl_ack,
                incl_downtimes: this.xdata.general.incl_downtimes,
                incl_svc:       this.xdata.general.incl_svc,
                incl_hst:       this.xdata.general.incl_hst
            });
            newStatus         = res.state;
            this.downtime     = res.downtime;
            this.acknowledged = res.acknowledged;
        }
        this.callParent([newStatus]);
    },
    getName: function() {
        return(this.xdata.general.hostgroup);
    },
    getDetails: function() {
        var panel = this;
        var details = [];
        if(!this.hostgroup) {
            return([['Status', 'No status information available']]);
        }
        var statename = TP.text_service_status(this.xdata.state);
        details.push([ 'Summarized Status', '<div class="extinfostate '+statename.toUpperCase()+'">'+statename.toUpperCase()+'<\/div>'
                                            +(this.acknowledged ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_ack.png" style="vertical-align:text-bottom"> acknowledged)':'')
                                            +(this.downtime     ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_downtime.png" style="vertical-align:text-bottom"> in downtime)':'')
                     ]);
        if(this.xdata.general.incl_hst) {
            details.push([ 'Hosts', TP.get_summarized_hoststatus(this.hostgroup.hosts)]);
        }
        if(this.xdata.general.incl_svc) {
            details.push([ 'Services', TP.get_summarized_servicestatus(this.hostgroup.services)]);
        }
        var link = TP.getIconDetailsLink(panel, true);
        details.push([ 'Details', link, panel]);
        return(details);
    }
});

/* Service Status Icon */
Ext.define('TP.ServiceStatusIcon', {
    extend: 'TP.IconWidget',

    iconType: 'service',
    iconName: 'Servicename',
    initComponent: function() {
        var panel = this;
        this.callParent();
        this.xdata.general.incl_downtimes = false;
        this.xdata.general.incl_ack       = false;
    },

    getGeneralItems: function() {
        var panel = this;
        return([
            TP.objectSearchItem(panel, 'host', 'Hostname', panel.xdata.general.host),
            TP.objectSearchItem(panel, 'service', 'Servicename', panel.xdata.general.service),
            {
                fieldLabel: 'Include Downtimes',
                xtype:      'checkbox',
                name:       'incl_downtimes',
                boxLabel:   '(alert during downtimes too)'
            }, {
                fieldLabel: 'Include Acknowledged',
                xtype:      'checkbox',
                name:       'incl_ack',
                boxLabel:   '(alert for acknowledged problems too)'
            }
        ]);
    },
    getName: function() {
        return(this.xdata.general.host + ' - ' + this.xdata.general.service);
    },
    getDetails: function() {
        var details = [];
        if(!this.service) {
            return([['Status', 'No status information available']]);
        }
        var statename = TP.text_service_status(this.xdata.state);
        details.push([ 'Current Status', '<div class="extinfostate '+statename.toUpperCase()+'">'+statename.toUpperCase()+'<\/div>'
                                            +' (for ' + TP.render_duration('', '', {data:this.service})+')'
                                            +(this.acknowledged ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_ack.png" style="vertical-align:text-bottom"> acknowledged)':'')
                                            +(this.downtime     ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_downtime.png" style="vertical-align:text-bottom"> in downtime)':'')
                     ]);
        details.push([ 'Status Information', this.service.plugin_output]);
        details.push([ 'Last Check', this.service.last_check ? TP.date_format(this.service.last_check) : 'never']);
        details.push([ 'Next Check', this.service.next_check ? TP.date_format(this.service.next_check) : 'not planned']);
        details.push([ 'Last Notification', (this.service.last_notification == 0 ? 'N/A' : TP.date_format(this.service.last_notification)) + ' (notification '+this.service.current_notification_number+')']);
        if(this.service.pnp_url) {
            var now = new Date();
            var url = this.service.pnp_url+'/image?host='+this.xdata.general.host+'&srv='+this.xdata.general.service+'&view=1&source=0&graph_width=300&graph_height=100';
            url    += '&start=' + (Math.round(now.getTime()/1000) - TP.timeframe2seconds('24h'));
            url    += '&end='   + Math.round(now.getTime()/1000);
            details.push([ '<img src="'+url+'" width="100%" border=1 style="max-height: 250px;" onload="TP.iconTip.syncShadow()">']);
        }
        return(details);
    },
    refreshHandler: function(newStatus) {
        this.acknowledged = false;
        this.downtime     = false;
        if(this.service) {
            if(this.service.scheduled_downtime_depth > 0) { this.downtime     = true; }
            if(this.service.acknowledged             > 0) { this.acknowledged = true; }
        }
        this.callParent([newStatus]);
    }
});

/* Servicegroup Status Icon */
Ext.define('TP.ServicegroupStatusIcon', {
    extend: 'TP.IconWidget',

    iconType: 'servicegroup',
    iconName: 'Servicegroupname',
    initComponent: function() {
        var panel = this;
        this.callParent();
        this.xdata.general.incl_downtimes = false;
        this.xdata.general.incl_ack       = false;
    },

    getGeneralItems: function() {
        var panel = this;
        return([
            TP.objectSearchItem(panel, 'servicegroup', 'Servicegroupname', panel.xdata.general.servicegroup),
            {
                fieldLabel: 'Include Downtimes',
                xtype:      'checkbox',
                name:       'incl_downtimes',
                boxLabel:   '(alert during downtimes too)'
            }, {
                fieldLabel: 'Include Acknowledged',
                xtype:      'checkbox',
                name:       'incl_ack',
                boxLabel:   '(alert for acknowledged problems too)'
            }
        ]);
    },
    refreshHandler: function(newStatus) {
        // calculate summarized status
        if(this.servicegroup) {
            var res = TP.get_group_status({
                group:          this.servicegroup,
                incl_ack:       this.xdata.general.incl_ack,
                incl_downtimes: this.xdata.general.incl_downtimes,
                incl_svc:       true,
                incl_hst:       false
            });
            newStatus         = res.state;
            this.downtime     = res.downtime;
            this.acknowledged = res.acknowledged;
        }
        this.callParent([newStatus]);
    },
    getName: function() {
        return(this.xdata.general.servicegroup);
    },
    getDetails: function() {
        var panel = this;
        var details = [];
        if(!this.servicegroup) {
            return([['Status', 'No status information available']]);
        }
        var statename = TP.text_service_status(this.xdata.state);
        details.push([ 'Summarized Status', '<div class="extinfostate '+statename.toUpperCase()+'">'+statename.toUpperCase()+'<\/div>'
                                            +(this.acknowledged ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_ack.png" style="vertical-align:text-bottom"> acknowledged)':'')
                                            +(this.downtime     ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_downtime.png" style="vertical-align:text-bottom"> in downtime)':'')
                     ]);
        details.push([ 'Services', TP.get_summarized_servicestatus(this.servicegroup.services)]);
        var link = TP.getIconDetailsLink(panel, true);
        details.push([ 'Details', link, panel]);
        return(details);
    }
});

/* Custom Filter Icon */
Ext.define('TP.FilterStatusIcon', {
    extend: 'TP.IconWidget',

    iconType: 'filtered',
    initComponent: function() {
        var panel = this;
        this.callParent();
        this.xdata.general.name           = '';
        this.xdata.general.incl_hst       = true;
        this.xdata.general.incl_svc       = true;
        this.xdata.general.incl_downtimes = false;
        this.xdata.general.incl_ack       = false;
    },

    getGeneralItems: function() {
        var panel = this;
        return([{
                fieldLabel: 'Name',
                xtype:      'textfield',
                name:       'name',
                value:      ''
            }, {
                fieldLabel: 'Backends / Sites',
                xtype:      'tp_backendcombo'
            },
            new TP.formFilter({
                fieldLabel: 'Filter',
                name:       'filter',
                ftype:      'service',
                labelWidth: 132,
                panel:      panel
            }), {
                fieldLabel: 'Include Hosts',
                xtype:      'checkbox',
                name:       'incl_hst'
            }, {
                fieldLabel: 'Include Services',
                xtype:      'checkbox',
                name:       'incl_svc'
            }, {
                fieldLabel: 'Include Downtimes',
                xtype:      'checkbox',
                name:       'incl_downtimes',
                boxLabel:   '(alert during downtimes too)'
            }, {
                fieldLabel: 'Include Acknowledged',
                xtype:      'checkbox',
                name:       'incl_ack',
                boxLabel:   '(alert for acknowledged problems too)'
            }
        ]);
    },
    refreshHandler: function(newStatus) {
        // calculate summarized status
        if(this.results) {
            var res = TP.get_group_status({
                group:          this.results,
                incl_ack:       this.xdata.general.incl_ack,
                incl_downtimes: this.xdata.general.incl_downtimes,
                incl_svc:       this.xdata.general.incl_svc,
                incl_hst:       this.xdata.general.incl_hst
            });
            newStatus         = res.state;
            this.downtime     = res.downtime;
            this.acknowledged = res.acknowledged;
        }
        this.callParent([newStatus]);
    },
    getName: function() {
        return(this.xdata.general.name);
    },
    getDetails: function() {
        var panel = this;
        var details = [];
        if(!this.results) {
            return([['Status', 'No status information available']]);
        }
        var statename;
        if(this.xdata.general.incl_svc == false) {
            statename = TP.text_host_status(this.xdata.state);
        } else {
            statename = TP.text_service_status(this.xdata.state);
        }
        details.push([ 'Summarized Status', '<div class="extinfostate '+statename.toUpperCase()+'">'+statename.toUpperCase()+'<\/div>'
                                            +(this.acknowledged ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_ack.png" style="vertical-align:text-bottom"> acknowledged)':'')
                                            +(this.downtime     ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_downtime.png" style="vertical-align:text-bottom"> in downtime)':'')
                     ]);
        if(this.xdata.general.incl_hst) {
            details.push([ 'Hosts', TP.get_summarized_hoststatus(this.results.hosts)]);
        }
        if(this.xdata.general.incl_svc) {
            details.push([ 'Services', TP.get_summarized_servicestatus(this.results.services)]);
        }
        var link = TP.getIconDetailsLink(panel, true);
        details.push([ 'Details', link, panel]);
        return(details);
    }
});

/* Sitestatus Icon */
Ext.define('TP.SiteStatusIcon', {
    extend: 'TP.IconWidget',

    iconType: 'site',
    iconName: 'Sitename',
    initComponent: function() {
        var panel = this;
        this.callParent();
    },
    getGeneralItems: function() {
        var panel = this;
        return([
            TP.objectSearchItem(panel, 'site', 'Sitename', panel.xdata.general.site)
        ]);
    },
    refreshHandler: function(newStatus) {
        // calculate site status
        if(this.site) {
                 if(this.site.running == 1) { newStatus = 0; }
            else if(this.site.state   == 0) { newStatus = 0; }
            else                            { newStatus = 2; }
        } else if(newStatus == undefined) {
            newStatus = this.state;
        }
        this.callParent([newStatus]);
    },
    getName: function() {
        return(this.xdata.general.site);
    },
    getDetails: function() {
        var details = [];
        if(!this.site) {
            return([['Status', 'No status information available']]);
        }
        var statename = this.xdata.state == 0 ? 'Ok' : 'Down';
        details.push([ 'Status', '<div class="extinfostate '+statename.toUpperCase()+'">'+statename.toUpperCase()+'<\/div>']);
        if(this.xdata.state == 0) {
            details.push([ 'Details', "Operating normal"]);
        } else {
            details.push([ 'Details', this.site.last_error]);
        }
        details.push([ 'Address', this.site.addr]);
        return(details);
    }
});

/* TextLabel Widget */
Ext.define('TP.TextLabelWidget', {
    extend: 'Ext.Component',
    mixins: {
        smallWidget: 'TP.SmallWidget'
    },
    iconType:           'text',
    html:               '',
    hideAppearanceTab:  true,
    initialSettingsTab: 4,
    rotateLabel:        true,
    constructor: function (config) {
        this.mixins.smallWidget.constructor.call(this, config);
        this.callParent();
    },
    initComponent: function() {
        this.callParent();
        var panel = this;
        panel.xdata.label.labeltext = 'Label';
        panel.xdata.label.position  = 'top-left';
        panel.xdata.layout.x        = 0;
        panel.xdata.layout.y        = 0;
    },
    getGeneralItems: function() { return; },
    refreshHandler: function()  { return; }
});

/* Static Image */
var imagesStore = Ext.create('Ext.data.Store', {
    fields: ['path', 'image'],
    proxy: {
        type: 'ajax',
        url:  'panorama.cgi?task=userdata_images',
        reader: {
            type: 'json',
            root: 'data'
        }
    },
    autoLoad: false,
    data : []
});
Ext.define('TP.StaticIcon', {
    extend: 'TP.IconWidget',

    iconType:         'image',
    cls:              'statciconWidget',
    hideAppearanceTab: true,
    generalLabelWidth: 50,
    hasScale:          true,
    initComponent: function() {
        var panel = this;
        this.callParent();
    },
    getGeneralItems: function() {
        var panel = this;
        imagesStore.load();
        return([{
            xtype:      'combobox',
            name:       'src',
            fieldLabel: 'Image',
            store:       imagesStore,
            queryMode:      'remote',
            triggerAction:  'all',
            pageSize:       true,
            selectOnFocus:  true,
            typeAhead:      true,
            displayField: 'image',
            valueField: 'path',
            listConfig : {
                getInnerTpl: function(displayField) {
                    return '<div class="x-combo-list-item" style="overflow: hidden; white-space: nowrap;"><img src="{path}" height=16 width=16> {image}<\/div>';
                },
                minWidth: 300,
                maxWidth: 800
            },
            matchFieldWidth: false,
            listeners: {
                select: function(combo, records, eOpts) {
                    if(records[0].data['image'] == "&lt;upload new image&gt;") {
                        TP.uploadUserContent('image', 'images/', function(filename) {
                            combo.setValue('../usercontent/images/'+filename);
                        });
                    }
                    return(true);
                },
                change: function() {
                TP.iconSettingsWindow.renderUpdate();
            }}
        }, {
            xtype:      'panel',
            html:       'Place images in: '+usercontent_folder+'/images/ <a href="#" onclick="TP.uploadUserContent(\'image\', \'images/\')">(upload)</a>',
            style:      'text-align: center;',
            bodyCls:    'form-hint',
            padding:    '10 0 0 0',
            border:      0
        }]);
    },
    refreshHandler: function(newStatus) {},
    setRenderItem: function(xdata, forceRecreate) {
        if(xdata == undefined) { xdata = this.xdata; }
        xdata.appearance = { type: 'icon'};
        this.callParent([xdata, forceRecreate]);
    }
});

TP.resetMoveIcons = function() {
    Ext.Array.each(TP.moveIcons, function(item) {
        item.el.dom.style.outline = "";
        if(item.labelEl) {
            item.labelEl.el.dom.style.outline = "";
        }
    });
    TP.moveIcons = undefined;
    if(TP.keynav) {
        TP.keynav.destroy();
        TP.keynav = undefined;
    }
    if(TP.lassoEl) {
        TP.lassoEl.destroy();
        TP.lassoEl = undefined;
    }
}

TP.createIconMoveKeyNav = function() {
    if(TP.keynav) { return; }
    TP.keynav = Ext.create('Ext.util.KeyNav', Ext.getBody(), {
        'left':  function(evt){ if(TP.moveIcons && TP.moveIcons[0]) { var pos = TP.moveIcons[0].getPosition(); TP.moveIcons[0].setPosition(pos[0]-1, pos[1]); }},
        'right': function(evt){ if(TP.moveIcons && TP.moveIcons[0]) { var pos = TP.moveIcons[0].getPosition(); TP.moveIcons[0].setPosition(pos[0]+1, pos[1]); }},
        'up':    function(evt){ if(TP.moveIcons && TP.moveIcons[0]) { var pos = TP.moveIcons[0].getPosition(); TP.moveIcons[0].setPosition(pos[0], pos[1]-1); }},
        'down':  function(evt){ if(TP.moveIcons && TP.moveIcons[0]) { var pos = TP.moveIcons[0].getPosition(); TP.moveIcons[0].setPosition(pos[0], pos[1]+1); }},
        'esc':   function(evt){ TP.resetMoveIcons(); },
        ignoreInputFields: true
    });
}


/* delay link opening to allow double click menu */
TP.iconClickHandler = function(id) {
    if(Ext.getCmp(id).passClick) { return true; }
    window.clearTimeout(TP.timeouts['click'+id]);
    TP.timeouts['click'+id] = window.setTimeout(function() {
        TP.iconClickHandlerDo(id);
    }, 200);
    return false;
}
/* actually open the clicked link */
TP.iconClickHandlerDo = function(id) {
    var panel = Ext.getCmp(id);
    if(!panel || !panel.xdata || !panel.xdata.link || !panel.xdata.link.link) {
        return(false);
    }
    var link    = panel.xdata.link.link;
    var newTab  = panel.xdata.link.newtab;
    if(!panel.locked) {
        TP.Msg.msg("info_message~~icon links are disabled in edit mode, would have openend:<br><b>"+link+"</b>"+(newTab?'<br>(in a new tab)':''));
        return(false);
    }
    var target = "";
    if(newTab) {
        target = '_blank';
    }
    return(TP.iconClickHandlerExec(id, link, panel, target));
}

/* open link or special action for given link */
TP.iconClickHandlerExec = function(id, link, panel, target) {
    var special = link.match(/dashboard:\/\/(.+)$/);
    var action  = link.match(/server:\/\/(.+)$/);
    var menu    = link.match(/menu:\/\/(.+)$/);
    if(special && special[1]) {
        link = undefined;
        if(special[1].match(/^\d+$/)) {
            // is that tab already open?
            var tabpan = Ext.getCmp('tabpan');
            var tab_id = "tabpan-tab_"+special[1];
            var tab    = Ext.getCmp(tab_id);
            if(tab) {
                tabpan.setActiveTab(tab);
            } else {
                var replace;
                if(!target) {
                    replace = tabpan.getActiveTab().id;
                }
                TP.add_pantab(tab_id, replace);
            }
        }
        else if(special[1] == 'show_details') {
            link = TP.getIconDetailsLink(panel);
        }
        else if(special[1] == 'refresh') {
            var el = panel.getEl();
            TP.updateAllIcons(Ext.getCmp(panel.panel_id), panel.id, undefined, el)
            el.mask(el.getSize().width > 50 ? "refreshing" : undefined);
        } else {
            TP.Msg.msg("fail_message~~unrecognized link: "+special[1]);
        }
    }
    if(action && action[1]) {
        var panel_id = panel.panel_id.replace(/^tabpan\-tab_/, '');
        var params = {
            host:      panel.xdata.general.host,
            service:   panel.xdata.general.service,
            link:      link,
            dashboard: panel_id,
            icon:      id,
            token:     user_token
        };
        Ext.Ajax.request({
            url:    url_prefix+'cgi-bin/panorama.cgi?task=serveraction',
            params:  params,
            method: 'POST',
            callback: function(options, success, response) {
                if(!success) {
                    if(response.status == 0) {
                        TP.Msg.msg("fail_message~~server action failed");
                    } else {
                        TP.Msg.msg("fail_message~~server action failed: "+response.status+' - '+response.statusText);
                    }
                } else {
                    var data = TP.getResponse(undefined, response);
                    if(data.rc == 0) {
                        if(data.msg != "") {
                            TP.Msg.msg("success_message~~"+data.msg);
                        }
                    } else {
                        TP.Msg.msg("fail_message~~"+data.msg);
                    }
                }
            }
        });
        return(false);
    }
    if(menu && menu[1]) {
        var tmp = menu[1].split(/\//);
        var menuName = tmp.shift();
        var menuArgs = tmp;
        var menuRaw;
        Ext.Array.each(action_menu_items, function(val, i) {
            var name    = val[0];
            if(name == menuName) {
                menuRaw = val[1];
                return(false);
            }
        });
        if(!menuRaw) {
            TP.Msg.msg("fail_message~~no such menu: "+menu[1]);
            return(false);
        }
        var menuData  = Ext.JSON.decode(menuRaw);
        var menuItems = [];
        Ext.Array.each(menuData['menu'], function(i, x) {
            if(Ext.isString(i)) {
                menuItems.push(i);
            } else {
                menuItems.push({
                    text:    i.label,
                    icon:    replace_macros(i.icon),
                    handler: function(This, evt) {
                        if(i.target) {
                            target = i.target;
                        }
                        return(TP.iconClickHandlerExec(id, i.action, panel, target));
                    }
                });
            }
        });
        TP.suppressIconTip = true;
        Ext.create('Ext.menu.Menu', {
            items: menuItems,
            listeners: {
                beforehide: function(This) {
                    TP.suppressIconTip = false;
                    This.destroy();
                }
            }
        }).showBy(panel);
        return(false);
    }
    if(link) {
        if(!link.match(/\$/)) {
            // no macros, no problems
            TP.iconClickHandlerClickLink(panel, link, target);
        } else {
            var tab = Ext.getCmp(panel.panel_id);
            Ext.Ajax.request({
                url:    url_prefix+'cgi-bin/status.cgi?replacemacros=1',
                params:  {
                    host:    panel.xdata.general.host,
                    service: panel.xdata.general.service,
                    backend: TP.getActiveBackendsPanel(tab, panel),
                    data:    link,
                    token:   user_token
                },
                method: 'POST',
                callback: function(options, success, response) {
                    if(!success) {
                        if(response.status == 0) {
                            TP.Msg.msg("fail_message~~could not replace macros");
                        } else {
                            TP.Msg.msg("fail_message~~could not replace macros: "+response.status+' - '+response.statusText);
                        }
                    } else {
                        var data = TP.getResponse(undefined, response);
                        if(data.rc != 0) {
                            TP.Msg.msg("fail_message~~could not replace macros: "+data.data);
                        } else {
                            TP.iconClickHandlerClickLink(panel, data.data, target);
                        }
                    }
                }
            });

        }
    }
    return(true);
};

TP.iconClickHandlerClickLink = function(panel, link, target) {
    var oldOnClick=panel.el.dom.onclick;
    panel.el.dom.onclick="";
    panel.el.dom.href=link;
    panel.passClick = true;
    if(target) {
        panel.el.dom.target = target;
    }
    panel.el.dom.click();
    window.setTimeout(function() {
        panel.el.dom.href=panel.xdata.link.link;
        panel.el.dom.onclick=oldOnClick;
        panel.passClick = false;
    }, 300);
}

/* return link representing the data for this icon */
TP.getIconDetailsLink = function(panel, relativeUrl) {
    if(!panel.xdata || !panel.xdata.general) {
        return('#');
    }
    var cfg = panel.xdata.general;
    var options = {
        backends: TP.getActiveBackendsPanel(Ext.getCmp(panel.panel_id))
    };
    var base = "status.cgi";
    if(cfg.hostgroup) {
        options.hostgroup = cfg.hostgroup;
    }
    else if(cfg.service) {
        options.host    = cfg.host;
        options.service = cfg.service;
        options.type    = 2;
        base            = "extinfo.cgi";
    }
    else if(cfg.servicegroup) {
        options.servicegroup = cfg.servicegroup;
    }
    else if(cfg.host) {
        options.host = cfg.host;
    }
    else if(cfg.filter) {
        options.filter = cfg.filter;
        options.task   = 'redirect_status';
        base           = 'panorama.cgi';
    } else {
        return('#');
    }
    if(panel.xdata.general.backends && panel.xdata.general.backends.length > 0) {
        options.backends = panel.xdata.general.backends;
    } else {
        var tab = Ext.getCmp(panel.panel_id);
        options.backends = tab.xdata.backends;
    }
    if(relativeUrl) {
        return(base+"?"+Ext.Object.toQueryString(options));
    }
    if(use_frames) {
        return(url_prefix+"#cgi-bin/"+base+"?"+Ext.Object.toQueryString(options));
    } else {
        return(base+"?"+Ext.Object.toQueryString(options));
    }
}

/* get gradient for color */
TP.createGradient = function(color, num, color2, percent) {
    if(num == undefined) { num = 0.2; }
    color  = Ext.draw.Color.fromString(color);
    if(color == undefined) { color = Ext.draw.Color.fromString('#DDDDDD'); }
    color2 = color2 ? Ext.draw.Color.fromString(color2) : color;
    var start;
    var end;
    if(num > 0) {
        start = color2.getLighter(Number(num)).toString();
        end   = color.toString();
    } else if (num < 0) {
        start = color.toString();
        end   = color2.getDarker(Number(-num)).toString();
    }
    var colorname1 = color.toString().replace(/^#/, '');
    var colorname2 = color2.toString().replace(/^#/, '');
    var g = {
        id: 'fill'+colorname1+colorname2+num,
        angle: 45,
        stops: {
              0: { color: start }
        }
    };
    if(percent != undefined) {
        if(percent > 10 && percent < 90) {
            g.stops[percent-10] = { color: start };
            g.stops[percent+10] = { color: end };
        } else {
            g.stops[percent] = { color: end };
        }
        g.stops[100] = { color: end };
        g.id         = 'fill'+colorname1+colorname2+num+percent;
    } else {
        g.stops[100] = { color: end };
    }
    return(g);
}

/* extract min/max */
TP.getPerfDataMinMax = function(p, maxDefault) {
    var r = { warn: undefined, crit: undefined, min: 0, max: maxDefault };
    if(p.max)           { r.max = p.max; }
    else if(p.crit_max) { r.max = p.crit_max; }
    else if(p.warn_max) { r.max = p.warn_max; }
    if(p.unit == '%')   { r.max = 100; }

    if(p.min)           { r.min = p.min; }
    return(r);
}

/* return natural size cross browser compatible */
TP.getNatural = function(src) {
    if(TP.imageSizes == undefined) { TP.imageSizes = {} }
    if(TP.imageSizes[src] != undefined) {
        return {width: TP.imageSizes[src][0], height: TP.imageSizes[src][1]};
    }
    img = new Image();
    img.src = src;
    if(img.width > 0 && img.height > 0) {
        TP.imageSizes[src] = [img.width, img.height];
    }
    return {width: img.width, height: img.height};
}

/* calculates availability used in labels */
function availability(panel, opts) {
    TP.lastAvailError = undefined;
    if(panel.iconType == 'hostgroup' || panel.iconType == 'filtered') {
        if(panel.xdata.general.incl_hst) { opts['incl_hst'] = 1; }
        if(panel.xdata.general.incl_svc) { opts['incl_svc'] = 1; }
    }
    var opts_enc = Ext.JSON.encode(opts);
    if(TP.availabilities[panel.id] == undefined) { TP.availabilities[panel.id] = {}; }
    var refresh = false;
    var now     = Math.floor(new Date().getTime()/1000);
    if(TP.availabilities[panel.id][opts_enc] == undefined) {
        refresh = true;
        TP.availabilities[panel.id][opts_enc] = {
            opts:         opts,
            last_refresh: TP.iconSettingsWindow == undefined ? now : 0,
            last:        -1
        };
    }
    /* refresh every 30seconds max */
    else if(TP.availabilities[panel.id][opts_enc]['last_refresh'] < now - (thruk_debug_js ? 5 : 30)) {
        refresh = true;
    }
    TP.availabilities[panel.id][opts_enc]['active'] = now;
    if(refresh) {
        if(TP.iconSettingsWindow != undefined) {
            if(!Ext.isNumeric(TP.availabilities[panel.id][opts_enc]['last'])) {
                TP.lastAvailError = TP.availabilities[panel.id][opts_enc]['last'];
            }
            return(TP.availabilities[panel.id][opts_enc]['last']);
        }
        TP.availabilities[panel.id][opts_enc]['last_refresh'] = now;
        TP.updateAllLabelAvailability(Ext.getCmp(panel.panel_id));
    }
    if(!Ext.isNumeric(TP.availabilities[panel.id][opts_enc]['last'])) {
        TP.lastAvailError = TP.availabilities[panel.id][opts_enc]['last'];
    }
    return(TP.availabilities[panel.id][opts_enc]['last']);
}


TP.iconMoveHandler = function(icon, x, y, noUpdateLonLat) {
    window.clearTimeout(TP.timeouts['timeout_icon_move']);

    var deltaX = x - icon.xdata.layout.x;
    var deltaY = y - icon.xdata.layout.y;
    if(isNaN(deltaX) || isNaN(deltaY)) { return; }

    /* update settings window */
    if(TP.iconSettingsWindow) {
        /* layout tab */
        TP.iconSettingsWindow.items.getAt(0).items.getAt(1).down('form').getForm().setValues({x:x, y:y});
        /* appearance tab */
        TP.skipRender = true;
        TP.iconSettingsWindow.items.getAt(0).items.getAt(2).down('form').getForm().setValues({
            connectorfromx: icon.xdata.appearance.connectorfromx + deltaX,
            connectorfromy: icon.xdata.appearance.connectorfromy + deltaY,
            connectortox:   icon.xdata.appearance.connectortox   + deltaX,
            connectortoy:   icon.xdata.appearance.connectortoy   + deltaY
        });
        if(icon.dragEl1) { icon.dragEl1.suspendEvents(); icon.dragEl1.setPosition(icon.xdata.appearance.connectorfromx + deltaX, icon.xdata.appearance.connectorfromy + deltaY); icon.dragEl1.resumeEvents(); }
        if(icon.dragEl2) { icon.dragEl2.suspendEvents(); icon.dragEl2.setPosition(icon.xdata.appearance.connectortox   + deltaX, icon.xdata.appearance.connectortoy   + deltaY); icon.dragEl2.resumeEvents(); }
        TP.skipRender = false;
    }
    /* update label */
    if(icon.setIconLabel) {
        icon.setIconLabel();
    }

    /* moving with closed settings window */
    if(icon.stateful) {
        if(icon.setIconLabel) {
            icon.xdata.layout.x = Math.floor(x);
            icon.xdata.layout.y = Math.floor(y);

            if(icon.xdata.appearance.type == "connector" && icon.xdata.appearance.connectorfromx != undefined) {
                icon.xdata.appearance.connectorfromx += deltaX;
                icon.xdata.appearance.connectorfromy += deltaY;
                icon.xdata.appearance.connectortox   += deltaX;
                icon.xdata.appearance.connectortoy   += deltaY;
            }
        }

        /* move aligned items too */
        TP.moveAlignedIcons(deltaX, deltaY, icon.id);
    }

    if(!noUpdateLonLat) {
        icon.updateMapLonLat();
    }
}

TP.moveAlignedIcons = function(deltaX, deltaY, skip_id) {
    if(!TP.moveIcons) { return; }
    Ext.Array.each(TP.moveIcons, function(item) {
        if(item.id != skip_id) {
            deltaX = Number(deltaX);
            deltaY = Number(deltaY);
            if(item.setIconLabel) {
                item.suspendEvents();
                item.xdata.layout.x = Number(item.xdata.layout.x) + deltaX;
                item.xdata.layout.y = Number(item.xdata.layout.y) + deltaY;
                item.setPosition(item.xdata.layout.x, item.xdata.layout.y);
                if(item.xdata.appearance.type == "connector") {
                    item.xdata.appearance.connectorfromx = Number(item.xdata.appearance.connectorfromx) + deltaX;
                    item.xdata.appearance.connectorfromy = Number(item.xdata.appearance.connectorfromy) + deltaY;
                    item.xdata.appearance.connectortox   = Number(item.xdata.appearance.connectortox)   + deltaX;
                    item.xdata.appearance.connectortoy   = Number(item.xdata.appearance.connectortoy)   + deltaY;
                }
                item.setIconLabel();
                item.resumeEvents();
                item.saveState();
            } else {
                item.moveDragEl(deltaX, deltaY);
            }
        }
    });
}

/* convert list of points to svg path */
TP.pointsToPath = function(points) {
    var l = points.length;
    if(l == 0) {return("");}
    var path = "M";
    for(var x = 0; x < l; x++) {
        var p = points[x];
        path += " "+p[0]+","+p[1];
    }
    path += " Z";
    return(path);
}

/* create gradient and return color by state */
TP.getShapeColor = function(type, panel, xdata, forceColor) {
    var state = xdata.state, fillcolor, r, color1, color2;
    var p     = {};
    var perc  = 100;
    if(state == undefined) { state = panel.xdata.state; }
    if(xdata.appearance[type+"source"] == undefined) { xdata.appearance[type+"source"] = 'fixed'; }
    if(forceColor != undefined) { fillcolor = forceColor; }
    else if(state == 0)         { fillcolor = xdata.appearance[type+"color_ok"]; }
    else if(state == 1)         { fillcolor = xdata.appearance[type+"color_warning"]; }
    else if(state == 2)         { fillcolor = xdata.appearance[type+"color_critical"]; }
    else if(state == 3)         { fillcolor = xdata.appearance[type+"color_unknown"]; }
    else if(state == 4)         { fillcolor = "#777777"; }
    if(!fillcolor)              { fillcolor = '#333333'; }

    var matches = xdata.appearance[type+"source"].match(/^perfdata:(.*)$/);
    if(matches && matches[1]) {
        window.perfdata = {};
        panel.setIconLabel(undefined, true);
        if(perfdata[matches[1]]) {
            p      = perfdata[matches[1]];
            r      = TP.getPerfDataMinMax(p, 100);
            color1 = xdata.appearance[type+"color_ok"];
            color2 = xdata.appearance[type+"color_ok"];
            /* inside critical range: V c w o w c  */
            if(p.crit_min != "" && p.val < p.crit_min) {
                color1 = xdata.appearance[type+"color_critical"];
                color2 = xdata.appearance[type+"color_critical"];
                perc   = 100;
            }
            /* above critical threshold: o w c V */
            else if(p.crit_max != "" && p.val > p.crit_max) {
                color1 = xdata.appearance[type+"color_critical"];
                color2 = xdata.appearance[type+"color_critical"];
                perc   = 100;
            }
            /* inside warning range low: c V w o w c */
            else if(p.warn_min != "" && p.val < p.warn_min && p.val > p.crit_min) {
                color1 = xdata.appearance[type+"color_warning"];
                color2 = xdata.appearance[type+"color_critical"];
                perc = Math.floor(((p.warn_min - p.val) / (p.warn_min - p.crit_min))*100);
            }
            /* inside warning range high: c w o w V c */
            else if(p.warn_min != "" && p.val > p.warn_max && p.val < p.crit_max) {
                color1 = xdata.appearance[type+"color_warning"];
                color2 = xdata.appearance[type+"color_critical"];
                perc = Math.floor(((p.val - p.warn_max) / (p.crit_max - p.warn_max))*100);
            }
            /* above warning threshold: o w V c */
            else if(p.warn_max != "" && p.val > p.warn_max) {
                color1 = xdata.appearance[type+"color_warning"];
                color2 = xdata.appearance[type+"color_critical"];
                perc   = Math.floor(((p.val - p.warn_max) / (r.max - p.warn_max))*100);
            }
            /* below warning threshold: o V w c */
            else if(p.warn_max != "" && p.val < p.warn_max) {
                color1 = xdata.appearance[type+"color_ok"];
                color2 = xdata.appearance[type+"color_warning"];
                perc   = Math.floor(((p.val - r.min) / (p.warn_max - r.min))*100);
            }
        }
    }

    if(xdata.appearance[type+"gradient"] != 0) {
        /* dynamic gradient */
        if(panel.surface.existingGradients == undefined) { panel.surface.existingGradients = {}; }
        if(xdata.appearance[type+"source"] != 'fixed' &&  color1 != undefined && color2 != undefined) {
            var gradient = TP.createGradient(color1, xdata.appearance[type+"gradient"], color2, perc);
            if(panel.surface.existingGradients[gradient.id] == undefined) {
                panel.surface.addGradient(gradient);
                panel.surface.existingGradients[gradient.id] = true;
            }
            return({color: "url(#"+gradient.id+")", value: p.val, perfdata: p, range: r});
        } else {
            /* fixed gradient from state color */
            var gradient = TP.createGradient(fillcolor, xdata.appearance[type+"gradient"]);
            if(panel.surface.existingGradients[gradient.id] == undefined) {
                panel.surface.addGradient(gradient);
                panel.surface.existingGradients[gradient.id] = true;
            }
            return({color: "url(#"+gradient.id+")", value: p.val, perfdata: p, range: r});
        }
    }
    /* fixed state color */
    return({color: fillcolor, value: p.val, perfdata: p, range: r});
}
