Ext.define('TP.PanletSquares', {
    extend: 'TP.Panlet',

    title: 'Squares',
    height: 400,
    width:  600,
    minSettingsWidth: 600,
    minSettingsHeight: 400,
    bodyStyle: "background: transparent;",
    style:    { position: 'absolute', zIndex: 50, background: 'transparent' },
    autohideHeaderOffset: -17,
    has_search_button: 'service',
    hideSettingsForm: ['url'],
    reloadOnSiteChanges: true,
    initComponent: function() {
        this.callParent();
        var panel                 = this;
        panel.xdata.showborder    = false;
        panel.xdata.source        = 'hosts';
        panel.xdata.groupby       = ['host_name', 'description'];
        panel.xdata.iconPadding   = 2;
        panel.xdata.iconSet       = 'default_64';
        panel.xdata.iconSize      = 'expand';
        panel.xdata.iconWidth     = 0;
        panel.xdata.iconHeight    = 0;
        panel.xdata.popup_button  = ['details'];
        panel.xdata.fadeduration  = "24h";

        panel.dataStore        = {};

        /* data loader */
        panel.loader = {
            autoLoad: false,
            renderer: function(loader, response, active) {
                // using default renderer breaks ie11
            },
            scope:    panel,
            url:      'panorama.cgi?task=squares_data',
            ajaxOptions: { method: 'POST' },
            loading:  false,
            listeners: {
                'beforeload': function(This, options, eOpts) {
                    if(!panel.containerItem || !panel.containerItem.el) {
                        return false;
                    }
                    if(panel.loading) {
                        return false;
                    }
                    panel.loading = true;
                    return true;
                }
            },
            callback: function(This, success, response, options) {
                panel.loading = false;
                var data = TP.getResponse(panel, response);
                if(!data || !data.data) { return };
                TP.log('['+panel.id+'] loaded');
                panel.adjustBodyStyle();
                TP.square_update_callback(panel, data.data);
            }
        };

        /* icon container */
        panel.containerItem = panel.add({
            xtype:     'panel',
            border:     0,
            html:      '<span id="'+panel.id+'-container"></span>'
        });

        /* sets inital value */
        panel.addListener('afterrender', function() {
            panel.createToolTip();
            panel.refreshHandler();
        });
        panel.addListener('resize', function() {
            panel.refreshHandler();
        });
        panel.formUpdatedCallback = function(panel) {
            panel.createToolTip();
        }
    },
    adjustBodyStyle: function() {
        var panel = this;
        panel.containerItem.setBodyStyle("font-family: "+(panel.xdata.fontfamily ? panel.xdata.fontfamily : 'inherit')+";");
        panel.containerItem.setBodyStyle("font-weight: "+(panel.xdata.fontbold ? 'bold' : 'normal')+";");
        panel.containerItem.setBodyStyle("font-style: "+(panel.xdata.fontitalic ? 'italic' : 'normal')+";");
        panel.containerItem.setBodyStyle("color: "+(panel.xdata.fontcolor ? panel.xdata.fontcolor : 'inherit')+";");
        panel.containerItem.setBodyStyle("background: "+(panel.xdata.background ? panel.xdata.background : 'transparent')+";");
    },
    setGearItems: function() {
        this.callParent();
        var panel = this;

        panel.addGearItems({
            fieldLabel:   'Data Source',
            xtype:        'fieldcontainer',
            layout:      { type: 'hbox', align: 'stretch' },
            items:        [{
                xtype:        'combobox',
                name:         'source',
                store:        [['hosts','Hosts'],['services','Services'],['both','Hosts & Services']],
                value:        panel.xdata.source
            }, {
                xtype:        'label',
                text:         'Group By: ',
                margins:      {top: 3, right: 2, bottom: 0, left: 7}
            }, {
                xtype:        'combobox',
                multiSelect:   true,
                name:         'groupby',
                width:        250,
                store:        [['host_name','Hostname'],['description','Servicename']],
                value:        panel.xdata.groupby,
                listConfig : {
                    getInnerTpl: function(displayField) {
                        return '<div class="x-combo-list-item"><img src="' + Ext.BLANK_IMAGE_URL + '" class="chkCombo-default-icon chkCombo" /> {'+displayField+'} <\/div>';
                    }
                }
            }]
        });
        TP.addFormFilter(panel, panel.has_search_button);

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

        panel.addGearItems({
            xtype:        'fieldcontainer',
            fieldLabel:   'Icon Set',
            layout:      { type: 'hbox', align: 'stretch' },
            items:        [{
                xtype:        'combobox',
                name:         'iconSet',
                cls:          'icon',
                store:         TP.iconsetsStore,
                value:        panel.xdata.iconSet,
                emptyText:    'use dashboards default icon set',
                displayField: 'name',
                valueField:   'value',
                width:        200,
                listConfig : {
                    getInnerTpl: function(displayField) {
                        return '<div class="x-combo-list-item"><img src="{sample}" height=16 width=16 style="vertical-align:top; margin-right: 3px;">{name}<\/div>';
                    }
                }
            }, {
                xtype:        'label',
                text:         'Padding: ',
                margins:      {top: 3, right: 2, bottom: 0, left: 7}
            }, {
                xtype:        'numberunit',
                unit:         'px',
                name:         'iconPadding',
                minValue:      0,
                maxValue:      1000,
                step:          1,
                width:         60,
                value:         panel.xdata.iconPadding,
                fieldStyle:   'text-align: right;'
            }]
        });
        panel.addGearItems({
            xtype:        'fieldcontainer',
            fieldLabel:   'Icon Size',
            layout:      { type: 'hbox', align: 'stretch' },
            items:        [{
                xtype:        'combobox',
                name:         'iconSize',
                store:        [['auto','Automatic'],['fixed','Fixed Size'],['expand','Adjust to Panel Size']],
                value:        panel.xdata.iconSize,
                listeners: {
                    change: function(This, val) {
                        if(val == "fixed") {
                            Ext.getCmp('iconWidth').setDisabled(false);
                            Ext.getCmp('iconHeight').setDisabled(false);
                        } else {
                            Ext.getCmp('iconWidth').setDisabled(true);
                            Ext.getCmp('iconHeight').setDisabled(true);
                        }
                    }
                }
            }, {
                xtype:        'label',
                text:         'Size: ',
                margins:      {top: 3, right: 2, bottom: 0, left: 7}
            }, {
                xtype:        'numberunit',
                unit:         'px',
                name:         'iconWidth',
                id:           'iconWidth',
                minValue:      0,
                maxValue:      1000,
                step:          1,
                width:         60,
                value:         panel.xdata.iconWidth,
                disabled:      panel.xdata.iconSize == "fixed" ? false : true,
                fieldStyle:   'text-align: right;'
            }, {
                xtype:        'label',
                text:         '/',
                margins:      {top: 3, right: 2, bottom: 0, left: 2}
            }, {
                xtype:        'numberunit',
                unit:         'px',
                name:         'iconHeight',
                id:           'iconHeight',
                minValue:      0,
                maxValue:      1000,
                step:          1,
                width:         60,
                value:         panel.xdata.iconHeight,
                disabled:      panel.xdata.iconSize == "fixed" ? false : true,
                fieldStyle:   'text-align: right;'
            }]
        });
        panel.addGearItems({
            xtype:        'fieldcontainer',
            fieldLabel:   'Icon Color',
            layout:      { type: 'hbox', align: 'stretch' },
            items:        [{
                xtype:        'label',
                text:         'Fade to black/white for',
                margins:      {top: 3, right: 2, bottom: 0, left: 7}
            }, {
                xtype:        'textfield',
                name:         'fadeduration',
                width:         60,
                value:         panel.xdata.fadeduration,
                fieldStyle:   'text-align: right;'
            }, {
                xtype:        'label',
                text:         Ext.isIE ? '(not supported in IE)' : 'ex.: 3d = 3 days, 24h = 24 hours, 60m = 60 minutes',
                margins:      {top: 3, right: 2, bottom: 0, left: 7}
            }]
        });

        var available_buttons = [["details", "details"]];
        Ext.Array.each(action_menu_actions, function(name, i) {
            available_buttons.push(["s:"+name, name]);
        });
        Ext.Array.each(action_menu_items, function(val, i) {
            var name = val[0];
            available_buttons.push(["m:"+name, name]);
        });
        panel.addGearItems({
            xtype:        'fieldcontainer',
            fieldLabel:   'Popup Button',
            layout:      { type: 'hbox', align: 'stretch' },
            items:        [{
                xtype:        'combobox',
                name:         'popup_button',
                multiSelect:   true,
                width:         300,
                store:         available_buttons,
                value:         panel.xdata.popup_button,
                emptyText:    'add buttons to popup',
                listConfig : {
                    getInnerTpl: function(displayField) {
                        return '<div class="x-combo-list-item"><img src="' + Ext.BLANK_IMAGE_URL + '" class="chkCombo-default-icon chkCombo" /> {'+displayField+'} <\/div>';
                    }
                }
            }]
        });
    },
    createToolTip: function() {
        var panel = this;
        /* add tool tip */
        var popup_fbar_btn = [];
        Ext.Array.each(panel.xdata.popup_button, function(val, i) {
            if(val == "details") {
                popup_fbar_btn.push({
                    type: 'button',
                    text: 'Details',
                    href: 'panorama.cgi',
                    id:   panel.id+'-detailsBtn',
                    icon: url_prefix+'plugins/panorama/images/information.png'
                });
            } else {
                var icon = url_prefix+'plugins/panorama/images/cog.png';
                var name = 'Action';
                var matches = val.match(/s:(.+)$/);
                if(matches) {
                    val  = 'server://'+matches[1];
                    name = matches[1];
                }
                matches = val.match(/m:(.+)$/);
                if(matches) {
                    val  = 'menu://'+matches[1];
                    icon = url_prefix+'plugins/panorama/images/menu-down.gif';
                    name = matches[1];
                }
                popup_fbar_btn.push({
                    type: 'button',
                    text:  name,
                    icon:  icon,
                    handler: function(This) {
                        var btn = This;
                        // create fake panel context to execute the click command from the menu
                        panel.fakePanel = Ext.create('Ext.panel.Panel', {
                            autoShow: false,
                            floating: true,
                            x: 100,
                            y: 100,
                            autoEl:  'a',
                            href:    '#',
                            text:    ' ',
                            renderTo: Ext.getBody(),
                            panel_id: panel.panel_id,
                            xdata: {
                                link: {
                                    link: val
                                },
                                general: {
                                    host: panel.tip.item.host_name,
                                    service: panel.tip.item.description
                                }
                            },
                            listeners: {
                                afterrender: function(This) {
                                    var options = {
                                        alignTo:  btn,
                                        callback: function() {
                                            window.setTimeout(function() {
                                                panel.tip.hide();
                                            }, 500);
                                        }
                                    };
                                    TP.iconClickHandlerExec(This.id, val, This, undefined, undefined, options);
                                }
                            }
                        });
                        panel.fakePanel.show();
                    }
                });
            }
        });
        if(panel.tip) {
            panel.tip.destroy();
            delete panel.tip;
        }
        panel.tip = Ext.create('Ext.tip.ToolTip', {
            renderTo: Ext.getBody(),
            dismissDelay: 120000, // close automatically after 2 minutes
            cls: 'squares_popup',
            minWidth: Ext.Array.max([200, (popup_fbar_btn.length * 110)]),
            buttonAlign: 'left',
            fbar: popup_fbar_btn,
            listeners: {
                beforeshow: function updateTipBody(tip, eOpts) {
                    if(!panel.tip.itemUniq || !panel.dataStore[panel.tip.itemUniq]) { return false; }
                    var item = panel.dataStore[panel.tip.itemUniq].item;
                    panel.tip.item = item;
                    tip.setTitle(item.name);
                    var downtime = '';
                    var details  = TP.square_item_details(item);
                    if(item.downtime) {
                        downtime = '<img src="'+url_prefix+'plugins/panorama/images/btn_downtime.png">';
                    }
                    var acknowledged = '';
                    if(item.acknowledged) {
                        acknowledged = '<img src="'+url_prefix+'plugins/panorama/images/btn_ack.png">';
                    }
                    var state = TP.text_status(item.state, item.isHost);
                    tip.update("Status: <div class='extinfostate "+state.toUpperCase()+"'>"+state+acknowledged+downtime+"<\/div><br>"
                              +"Duration: "+TP.duration(item.duration)
                              +details);
                    var detailsBtn = Ext.getCmp(panel.id+'-detailsBtn')
                    if(detailsBtn) {
                        if(!item.link) {
                            detailsBtn.setHref(TP.square_item_details_link(panel, item));
                        } else {
                            detailsBtn.setHref(item.link);
                        }
                    }
                    return(true);
                },
                beforehide: function(tip, eOpts) {
                    // don't hide if there is still a menu open
                    if(Ext.getCmp('iconActionMenu')) {
                        return(false);
                    }
                    if(panel.fakePanel) {
                        panel.fakePanel.destroy();
                        delete panel.fakePanel;
                    }
                    return(true);
                }
            }
        });
    }
});

TP.square_item_details_link = function(panel, item) {
    if(!item.details) {
        return("#");
    }
    var options = {
        backends: TP.getActiveBackendsPanel(Ext.getCmp(panel.panel_id)),
        filter:   panel.xdata.filter,
        task:    'redirect_status'
    };
    var uniqs = item.uniq.split(" - ");
    for(var nr=0; nr<panel.xdata.groupby.length; nr++) {
        if(panel.xdata.groupby[nr] == "host_name") {
            options.host = uniqs[nr];
        }
        if(panel.xdata.groupby[nr] == "description") {
            options.service = uniqs[nr];
        }
    }
    return("panorama.cgi?"+Ext.Object.toQueryString(options));
}

TP.square_item_details = function(item) {
    var details = '';
    var detailCount = 0;
    if(item.details) {
        details = '<br>Details:<br><table>';
        for(var nr=0; nr<item.details.length; nr++) {
            var d = item.details[nr];
            if(item.state != 0 && (d.state == 0 || d.state == 4)) { continue; }
            detailCount++;
            if(detailCount == 11) {
                details += '<tr><td colspan=4>...<\/td><\/tr>'
                break;
            }
            var dState = TP.text_status(d.state, d.isHost);
            var downtime = '';
            if(d.downtime) {
                downtime = '<img src="'+url_prefix+'plugins/panorama/images/btn_downtime.png">';
            }
            var acknowledged = '';
            if(d.acknowledged) {
                acknowledged = '<img src="'+url_prefix+'plugins/panorama/images/btn_ack.png">';
            }
            details += '<tr><td>'+d.host_name+'<\/td>'
                      +'<td>'+d.description+'<\/td>'
                      +'<td><div class="extinfostate '+dState.toUpperCase()+'">'+dState+acknowledged+downtime+'<\/div><\/td>'
                      +'<td>'+TP.duration(d.duration)+'<\/td>'
                      +'<\/tr>';
        }
        details += '<\/table>';
    }
    return(details);
}

TP.square_update_callback = function(panel, data, retries) {
    if(!panel.el || !panel.el.dom) { return; }
    if(!panel.containerItem || !panel.containerItem.body.el || !panel.containerItem.body.el.dom) { return; }
    var tab   = Ext.getCmp(panel.panel_id);
    var iconsetName = panel.xdata.iconSet;
    if(iconsetName == '' || iconsetName == undefined) {
        if(!tab) { return; }
        iconsetName = tab.xdata.defaulticonset || 'default';
    }
    var rec    = TP.iconsetsStore.findRecord('value', iconsetName);
    var imgSrc = Ext.BLANK_IMAGE_URL;
    var leftStart  = 3;
    var topStart   = 3;
    var padding    = panel.xdata.iconPadding;
    var iconWidth  = 0;
    var iconHeight = 0;
    if(panel.xdata.iconSize == 'fixed') {
        iconWidth  = panel.xdata.iconWidth;
        iconHeight = panel.xdata.iconHeight;
    }
    if(panel.xdata.iconSize == 'expand') {
        // see how big the icons can be to fill the complete panel
        if(data.length == 0) { return; }
        var size = panel.getSize();
        size.width  += -14; // 8px border + 2*3px padding
        size.height += -14; // same

        var edgeLength = TP.getMaxSquareEdgeLength(size.width, size.height, data.length);

        iconWidth  = edgeLength - padding;
        iconHeight = edgeLength - padding;
    }

    // reset all update flags
    for(var key in panel.dataStore) {
        panel.dataStore[key].updated = false;
    }

    var left = leftStart;
    var top  = topStart;
    var size = panel.getSize();
    panel.containerItem.body.el.dom.style.position = 'relative';

    var rec = TP.iconsetsStore.findRecord('value', iconsetName);
    if(!iconWidth || !iconHeight) {
        if(rec != null) {
            var imgSrc = '../usercontent/images/status/'+iconsetName+'/'+rec.data.fileset["ok"];
            var naturalSize = TP.getNatural(imgSrc);
            iconWidth  = naturalSize.width;
            iconHeight = naturalSize.height;
            if(iconWidth <= 0 || iconHeight <= 0) {
                if(retries == undefined) { retries = 0; }
                retries++;
                if(retries <= 5) {
                    window.setTimeout(function() {
                        TP.square_update_callback(panel, data, retries);
                    }, 1000*retries);
                }
                return;
            }
        }
    }

    for(var nr=0; nr<data.length; nr++) {
        var item   = data[nr];
        var newSrc = "ok";
        if(item.isHost) {
            newSrc = TP.hostState2Src(item.state, item.acknowledged, item.downtime);
        } else {
            newSrc = TP.serviceState2Src(item.state, item.acknowledged, item.downtime);
        }
        var imgSrc = ''
        if(rec != null && rec.data.fileset[newSrc]) {
            imgSrc = '../usercontent/images/status/'+iconsetName+'/'+rec.data.fileset[newSrc];
        }
        if(!panel.dataStore[item.uniq]) {
            var el = panel.containerItem.body.createChild({tag:   'img',
                                                  src:    imgSrc,
                                                  'class': 'clickable',
                                                  style: {top:       top+'px',
                                                          left:      left+'px',
                                                          position: 'absolute'}
                                                });
            el.on("click", function(This) {
                panel.tip.itemUniq = This.target.dataName;
                panel.tip.showBy(This.target);
            });
            el.on("mouseover", function(This) {
                var dataName = This.target.dataName;
                var el = panel.dataStore[dataName];
                if(el.label) { return; }
                TP.square_set_icon_label(panel, el, dataName, el.item.name);
                el.label.on("mouseout", function() {
                    el.label.destroy();
                    delete el.label;
                });
            });
            panel.dataStore[item.uniq] = el;
        }
        // update position and source
        var oldSrc = panel.dataStore[item.uniq].el.dom.src;
        panel.dataStore[item.uniq].updated             = true;
        panel.dataStore[item.uniq].el.dom.src          = imgSrc;
        panel.dataStore[item.uniq].el.dom.style.left   = left+"px";
        panel.dataStore[item.uniq].el.dom.style.top    = top+"px";
        panel.dataStore[item.uniq].el.dom.style.width  = iconWidth+"px";
        panel.dataStore[item.uniq].el.dom.style.height = iconHeight+"px";
        panel.dataStore[item.uniq].el.dom.style.top    = top+"px";
        panel.dataStore[item.uniq].el.dom.dataName     = item.uniq;

        // apply black/white filter based on state duration
        panel.dataStore[item.uniq].keepLabel = true;
        if(panel.xdata.fadeduration != "") {
            var durationHours = TP.timeframe2seconds(panel.xdata.fadeduration);
            var el = panel.dataStore[item.uniq].el;
            if(item.duration < durationHours) {
                var durationFilter = Ext.Array.min([100, Math.round(item.duration / (durationHours/100))]);
                el.dom.style.filter = "grayscale("+durationFilter+"%)";
                TP.square_set_icon_label(panel, el, item.uniq, item.name);
                el.label.dom.style.opacity = 1-durationFilter/100;
                el.label.on("mouseover", function(This) {
                    This.target.opacityOrig = This.target.style.opacity;
                    This.target.style.opacity = 1;
                });
                el.label.on("mouseout", function(This) {
                    This.target.style.opacity = This.target.opacityOrig;
                });
            } else {
                el.dom.style.filter = "grayscale(100%)";
                panel.dataStore[item.uniq].keepLabel = false;
            }
        }

        if(panel.dataStore[item.uniq].el.dom.src != oldSrc) {
            TP.flickerImg(panel.dataStore[item.uniq].el.id);
        }

        panel.dataStore[item.uniq].left = left;
        panel.dataStore[item.uniq].top  = top;

        left += iconWidth + padding;
        if(left + iconWidth > size.width - 10 ) {
            left = leftStart;
            top += iconHeight + padding;
        }
        panel.dataStore[item.uniq].item = item;
    }
    // remove all old icons
    for(var key in panel.dataStore) {
        if(!panel.dataStore[key].keepLabel && panel.dataStore[key].el.label) {
            panel.dataStore[key].el.label.destroy();
            delete panel.dataStore[key].el.label;
        }
        if(!panel.dataStore[key].updated) {
            if(panel.dataStore[key].el.label) {
                panel.dataStore[key].el.label.destroy();
            }
            panel.dataStore[key].destroy();
            delete panel.dataStore[key];
        }
    }
}

/* calculate maximum square edge length for given rectangle */
TP.getMaxSquareEdgeLength = function(x, y, nr) {
    var sx, sy;
    var px = Math.ceil(Math.sqrt(nr * x / y));
    if(Math.floor(px * y / x) * px < nr) { //does not fit, y / ( x / px ) = px * y / x
        sx = y / Math.ceil(px * y / x);
    } else {
        sx = x / px;
    }

    var py = Math.ceil(Math.sqrt(nr * y / x));
    if(Math.floor(py * x / y) * py < nr) { //does not fit
        sy = x / Math.ceil(x * py /y);
    } else {
        sy = y / py;
    }
    return(Math.floor(Ext.Array.max([sx, sy])));
}

TP.square_set_icon_label = function(panel, icon, uniq, text) {
    var top    = icon.dom.style.top.replace("px", "");
    var left   = icon.dom.style.left.replace("px", "");;
    var width  = icon.dom.style.width.replace("px", "");
    var height = icon.dom.style.width.replace("px", "");;
    var fontsize = 8;
    var el;
    if(icon.label) {
        el = icon.label;
    } else {
        el = panel.containerItem.body.createChild({
                                               tag:    'div',
                                              'class': 'clickable',
                                               style: {
                                                    fontSize:   fontsize+'px',
                                                    wordWrap:  'break-word',
                                                    textAlign: 'center',
                                                    overflow:  'hidden',
                                                    position: 'absolute'
                                                }
        });
        icon.label = el;

        el.on("click", function(l) {
            panel.tip.itemUniq = uniq;
            panel.tip.showBy(l.target);
        });
    }
    el.dom.style.width  = width+"px";
    el.dom.style.height = height+"px";
    el.dom.style.top    = top+"px";
    el.dom.style.left   = left+"px";
    el.dom.innerText    = text;

    // set maximum font-size
    while(el.dom.scrollHeight <= height && el.dom.scrollWidth <= width && fontsize < 100) {
        fontsize++;
        el.dom.style.fontSize = fontsize+"px";
    }
    fontsize = fontsize - 1;
    el.dom.style.fontSize = fontsize+"px";

    return;
}
