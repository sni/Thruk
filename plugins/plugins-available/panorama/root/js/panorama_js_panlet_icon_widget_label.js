Ext.define('TP.IconLabel', {
    /* queue label renderer */
    setIconLabel: function(cfg) {
        var panel = this;
        if(!panel.el || !panel.el.dom)  { return; }
        TP.reduceDelayEvents(panel, function() {
            panel.setIconLabelDo(cfg);
        }, 300, panel.id+'setIconLabel');
    },

    /* render label for this widget */
    setIconLabelDo: function(cfg) {
        var panel = this;
        if(!panel.el || !panel.el.dom)  { return; }
        if(cfg == undefined) {
            cfg = panel.xdata.label;
            if(TP.iconSettingsWindow && TP.iconSettingsWindow.panel.id == panel.id) {
                var xdata = TP.get_icon_form_xdata(TP.iconSettingsWindow);
                cfg       = xdata.label;
            }
        }
        if(TP.removeLabel && TP.removeLabel[panel.id]) {
            /* remove later to avoid flickering during redraw */
            window.clearTimeout(TP.timeouts['remove_label_'+panel.id]);
            TP.timeouts['remove_label_'+panel.id] = window.setTimeout(function() {
                TP.removeLabel[panel.id].destroy();
                delete TP.removeLabel[panel.id];
                panel.setIconLabel(cfg);
            }, 100);
        }
        if(cfg == undefined) { return; }

        panel.setIconLabelText(cfg);
        panel.setIconLabelPosition(cfg);
        return;
    },

    setIconLabelText: function(cfg) {
        var panel = this;
        var txt = String(cfg.labeltext);
        if(txt == undefined) { txt = ''; }
        panel.el.dom.title = '';

        /* hide the icon element for label only appearance */
        if(panel.locked && panel.el) {
            if(panel.xdata.appearance.type == "none") {
                panel.el.dom.style.display = "none";
            }
        }

        /* dynamic label? */
        if(txt.match(/\{\{.*?\}\}/)) {
            txt = panel.setIconLabelDynamicText(txt);

            /* update value since it might have changed */
            if(panel.xdata.appearance.type == 'speedometer' && panel.xdata.appearance.speedosource.match(/^avail:(.*)$/)) {
                panel.updateRender(panel.xdata);
            }
        }
        /* no label at all */
        if(!cfg.labeltext) {
            if(panel.labelEl) { panel.labelEl.destroy(); panel.labelEl = undefined; }
            return;
        }
        if(!panel.labelEl) {
            panel.createLabelEl();
        }
        if(!panel.labelEl || !panel.labelEl.el) { return; }
        var el    = panel.labelEl.el.dom;
        var style = el.style;
        style.zIndex = Number(panel.el.dom.style.zIndex)+1; /* keep above icon */
        var oldTxt = panel.labelEl.el.dom.innerHTML;
        if(oldTxt != txt) {
            panel.labelEl.update(txt);
        }
        style.color        = cfg.fontcolor || '#000000';
        style.fontFamily   = cfg.fontfamily || 'inherit';
        style.background   = cfg.bgcolor;
        style.fontWeight   = cfg.fontbold   ? 'bold'   : 'normal';
        style.fontStyle    = cfg.fontitalic ? 'italic' : 'normal';
        style.textAlign    = cfg.fontcenter ? 'center' : 'unset';
        style.paddingLeft  = "3px";
        style.paddingRight = "3px";
        if(cfg.orientation == 'vertical') { panel.labelEl.addCls('vertical');    }
        else                              { panel.labelEl.removeCls('vertical'); }

        return;
    },

    setIconLabelDynamicText: function(txt) {
        var panel = this;
        var allowed_functions = ['strftime', 'sprintf', 'if', 'availability', 'nl2br'];
        if(TP.availabilities == undefined) { TP.availabilities = {}; }
        if(TP.availabilities[panel.id] == undefined) { TP.availabilities[panel.id] = {}; }
        var matches = txt.match(/(\{\{.*?\}\})/g);
        var macros  = TP.getPanelMacros(panel);
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
            var res;
            calc = calc.replace(/availability\(/g, 'availability(panel, ');
            if(macros[calc] != undefined) {
                // direct match, no need for eval
                res = macros[calc];
            } else {
                try {
                    res = TP.evalInContext(calc, macros);
                } catch(err) {
                    TP.logError(panel.id, "labelEvalException", err);
                    panel.el.dom.title = err;
                }
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
        return(txt);
    },

    setIconLabelPosition: function(cfg) {
        var panel = this;
        if(!panel.labelEl || !panel.labelEl.el)     { return; }
        if(!panel.size && panel.iconType != "text") { return; }
        if(cfg == undefined) { cfg = panel.xdata.label; }
        var left          = TP.extract_number_with_unit({ value: panel.el.dom.style.left, unit:'px',  floor: true, defaultValue: 100 });
        var top           = TP.extract_number_with_unit({ value: panel.el.dom.style.top,  unit:'px',  floor: true, defaultValue: 100 });
        var offsetx       = TP.extract_number_with_unit({ value: cfg.offsetx,             unit:' px', floor: true, defaultValue:   0 });
        var offsety       = TP.extract_number_with_unit({ value: cfg.offsety,             unit:' px', floor: true, defaultValue:   0 });
        var fontsize      = TP.extract_number_with_unit({ value: cfg.fontsize,            unit:' px', floor: true, defaultValue:  14 });
        var elWidth       = TP.extract_number_with_unit({ value: panel.width,             unit:'',    floor: true, defaultValue:   0 });
        var elHeight      = TP.extract_number_with_unit({ value: panel.height,            unit:'',    floor: true, defaultValue:   0 });
        var bordersize    = TP.extract_number_with_unit({ value: cfg.bordersize,          unit:' px', floor: true, defaultValue:   0 });

        // avoid flickering when not yet positioned correctly
        if(elWidth == 0 && elHeight == 0 && left == 0 && top == 0) { return; }

        var el    = panel.labelEl.el.dom;
        var style = el.style;

        /* use original reference coordinates for shrinked icons */
        if(panel.shrinked) {
            left     = panel.shrinked.x;
            top      = panel.shrinked.y;
            elWidth  = panel.shrinked.size;
            elHeight = panel.shrinked.size;
        }

        if(cfg.bordercolor && bordersize > 0) {
            style.border = bordersize+"px solid "+cfg.bordercolor;
        } else {
            style.border = "";
        }

        if(cfg.width == undefined || cfg.width == '') {
            style.width    = '';
            style.overflow = '';
        } else {
            style.width    = cfg.width+"px";
            style.overflow = 'hidden';
        }
        if(cfg.height == undefined || cfg.height == '') {
            style.height = '';
        } else {
            style.height = cfg.height+"px";
        }
        if(cfg.roundcorners && cfg.roundcorners != '' && cfg.roundcorners > 0) {
            style.borderRadius = cfg.roundcorners+"px";
        } else {
            style.borderRadius = '';
        }

        style.fontSize = fontsize+'px';
        var size          = panel.labelEl.getSize();
        if(size.width == 0) { return; }

        if(cfg.position == 'above') {
            top = top - offsety - size.height;
            if(cfg.orientation == 'horizontal') {
                left = left + (elWidth / 2) - (size.width / 2) + 2;
            }
            left = left - offsetx;
        }
        else if(cfg.position == 'below') {
            top = top + offsety + elHeight;
            if(cfg.orientation == 'horizontal') {
                left = left + (elWidth / 2) - (size.width / 2) + 2;
            }
            left = left - offsetx;
        }
        else if(cfg.position == 'right') {
            left = left + offsety + elWidth + 2;
            if(cfg.orientation == 'horizontal') {
                top  = top + elHeight/2 - size.height/2;
            }
            top = top - offsetx;
        }
        else if(cfg.position == 'left') {
            left = left - offsety - size.width - 2;
            if(cfg.orientation == 'horizontal') {
                top  = top + elHeight/2 - size.height/2;
            }
            top = top - offsetx;
        }
        else if(cfg.position == 'center') {
            top  = top + offsety + (elHeight/2) - (size.height/2);
            left = left + (elWidth / 2) - (size.width / 2) - offsetx;
        }
        else if(cfg.position == 'top-left') {
            top  = top + offsety;
            left = left + offsetx;
        }
        style.left = left+"px";
        style.top  = top+"px";
        panel.labelEl.oldX = left;
        panel.labelEl.oldY = top;
    },

    /* creates the label element */
    createLabelEl: function() {
        var panel = this;
        if(!TP.isThisTheActiveTab(panel)) { return; } /* no need for a label on inactive tab */
        this.labelEl = Ext.create("Ext.Component", {
            'html':     ' ',
            panel:       panel,
            draggable:  !panel.locked,
            renderTo:  "iconContainer",
            shadow:     false,
            hidden:     (!TP.iconSettingsWindow && panel.xdata.label.display && panel.xdata.label.display == 'mouseover'),
            hideMode:  'visibility',
            cls:        ((panel.xdata.link && panel.xdata.link.link) ? '' : 'not') +'clickable iconlabel tooltipTarget', // defaults to text cursor otherwise
            style:      {
                whiteSpace: 'nowrap',
                left:       '-1000px'    // hide initally before setIconLabelPosition moves it to the correct position
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
                        panel.updateMapLonLat(undefined, "center");
                        // update settings window
                        if(TP.iconSettingsWindow) {
                            Ext.getCmp('layoutForm').getForm().setValues({x:newX, y:newY});
                        }
                        if(!panel.readonly) {
                            panel.xdata.layout.x = newX;
                            panel.xdata.layout.y = newY;
                            if(panel.xdata.appearance.type == "connector" && panel.xdata.appearance.connectorfromx != undefined) {
                                panel.xdata.appearance.connectorfromx += diffX;
                                panel.xdata.appearance.connectorfromy += diffY;
                                panel.xdata.appearance.connectortox   += diffX;
                                panel.xdata.appearance.connectortoy   += diffY;
                            }
                            panel.saveState();
                        }
                        if(panel.dragEl1) { panel.dragEl1.resetDragEl(); }
                        if(panel.dragEl2) { panel.dragEl2.resetDragEl(); }
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
                beforeshow: function( This, eOpts ) {
                    if(!TP.iconSettingsWindow && panel.xdata.label.display && panel.xdata.label.display == "mouseover" && !This.mouseover) {
                        return(false);
                    }
                    return(true);
                },
                show: function( This, eOpts ) {
                    panel.addDDListener(This);
                }
            }
        });
        if(panel.rotateLabel) {
            panel.rotateEl = panel.labelEl.el;
        }
        panel.applyRotation(panel.xdata.layout.rotation);    /* add dbl click and context menu events */
    }
});

function nl2br(text) {
    text = text.replace(/\n/g, "<br>");
    text = text.replace(/\\n/g, "<br>");
    return(text);
}

