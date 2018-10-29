TP.suppressIconTipForce = true;
TP.suppressIconTip      = false;
Ext.onReady(function() {
    TP.iconTip = Ext.create('Ext.tip.ToolTip', {
        title:    'Details:',
        itemId:   'iconTip',
        target:    Ext.getBody(),
        delegate: 'A.tooltipTarget', // the cell class in which the tooltip has to be triggered
        dismissDelay:    0,
        width:         500,
        manageHeight: false,
        maxWidth:      500,
        hideDelay:     300,
        closable:     true,
        showDelay:     500,
        //closable:  true, hideDelay: 6000000, // enable for easier css debuging
        style:    'background: #E5E5E5',
        bodyStyle:'background: #E5E5E5',
        shadow:   'drop',
        html:      '',
        listeners: {
            move: function(This, x, y, eOpts) {
                var position = "automatic";
                if(TP.iconTipTarget && TP.iconTipTarget.xdata.popup && TP.iconTipTarget.xdata.popup.popup_position != "" && TP.iconTipTarget.xdata.popup.popup_position != "automatic") {
                    position =  TP.iconTipTarget.xdata.popup.popup_position;
                }
                if(position == "relative position") {
                    This.suspendEvents(false);
                    TP.iconTip.setFixedOffsetPosition(TP.iconTipTarget, TP.iconTipTarget.xdata.popup.popup_x, TP.iconTipTarget.xdata.popup.popup_y);
                    This.resumeEvents(false);
                }
                if(position == "absolute position") {
                    This.suspendEvents(false);
                    TP.iconTip.setFixedPosition(TP.iconTipTarget.xdata.popup.popup_x, TP.iconTipTarget.xdata.popup.popup_y);
                    This.resumeEvents(false);
                }
                if(TP.iconSettingsWindow && TP.iconTip.isVisible()) {
                    This.suspendEvents(false);
                    TP.iconTip.alignToSettingsWindow();
                    This.resumeEvents(false);
                }
            },
            beforeshow: function(This, eOpts) {
                if(!TP.iconTipTarget)       { return(false); }
                if(TP.suppressIconTipForce) { return(false); }
                TP.suppressIconTipForce = true;
                if(TP.suppressIconTip) {
                    This.hide();
                    return false;
                }
                if(!TP.iconSettingsWindow && TP.iconTipTarget.xdata.popup && TP.iconTipTarget.xdata.popup.type == "off") {
                    This.hide();
                    return false;
                }
                var tabpan = Ext.getCmp('tabpan');
                var tab = tabpan.getActiveTab();
                if(!tab || !tab.locked && !TP.iconSettingsWindow) {
                    return(false);
                }
                if(!TP.iconSettingsWindow) {
                    // check if the mouse is still over the icon after the showDelay
                    if(!TP.iconTipTarget || !TP.iconTipTarget.el) {
                        return(false);
                    }
                    var pos = TP.iconTipTarget.getPosition();
                    var size = TP.iconTipTarget.getSize();
                    if(   cursorX < pos[0] || cursorX > pos[0]+size.width
                       || cursorY < pos[1] || cursorY > pos[1]+size.height) {
                        if(TP.iconTip) {
                            TP.iconTip.last_id = "";
                        }
                        return(false);
                    }
                }
                return true;
            },
            show: function(This) {
                if(TP.iconTip.detailsTarget) { TP.iconTip.detailsTarget.doLayout(); }
                var size = This.getSize();
                if(size.width <= 1 || size.height <= 1) { size = {width: 500, height: 150} }

                var position = "automatic";
                if(TP.iconTipTarget && TP.iconTipTarget.xdata.popup && TP.iconTipTarget.xdata.popup.popup_position != "" && TP.iconTipTarget.xdata.popup.popup_position != "automatic") {
                    position = TP.iconTipTarget.xdata.popup.popup_position;
                }
                if(position == "relative position") {
                    TP.iconTip.setFixedOffsetPosition(TP.iconTipTarget, TP.iconTipTarget.xdata.popup.popup_x, TP.iconTipTarget.xdata.popup.popup_y);
                }
                else if(position == "absolute position") {
                    TP.iconTip.setFixedPosition(TP.iconTipTarget.xdata.popup.popup_x, TP.iconTipTarget.xdata.popup.popup_y);
                }
                else if(!TP.iconSettingsWindow) {
                    var showAtPos = TP.getNextToPanelPos(TP.iconTip.panel, size.width, size.height);
                    var pos = This.getPosition();
                    if(pos[0] != showAtPos[0] || pos[1] != showAtPos[1]) {
                        TP.suppressIconTipForce = false;
                        This.showAt(showAtPos);
                    }
                }

                This.el.on('mouseover', function() {
                    window.clearTimeout(This.hideTimer);
                    delete This.hideTimer;
                });
                This.el.on('mouseout', function() {
                    if(TP.iconSettingsWindow) { return; }
                    This.delayHide();
                });
                if(TP.iconSettingsWindow && position == "automatic") {
                    this.alignToSettingsWindow();
                }
                This.hidden = false;
            },
            beforehide: function(This) {
                if(TP.iconSettingsWindow
                   && TP.iconSettingsWindow.items.getAt(0)
                   && TP.iconSettingsWindow.items.getAt(0).getActiveTab().title == "Popup"
                ) { return(false); }
                This.hidden = true;
            },
            destroy: function(This) { delete TP.iconTip; delete TP.iconTipTarget; }
        },
        alignToSettingsWindow: function() {
            var position = "automatic";
            var xdata = {};
            if(TP.iconSettingsWindow) {
                xdata = TP.get_icon_form_xdata(TP.iconSettingsWindow);
            }
            else if(TP.iconTipTarget) {
                xdata = TP.iconTipTarget.xdata;
            }
            if(xdata.popup && xdata.popup.popup_position != "" && xdata.popup.popup_position != "automatic") {
                position = xdata.popup.popup_position;
            }
            if(position == "relative position") {
                TP.iconTip.setFixedOffsetPosition(TP.iconSettingsWindow.panel || TP.iconTipTarget, xdata.popup.popup_x, xdata.popup.popup_y);
            }
            else if(position == "absolute position") {
                TP.iconTip.setFixedPosition(xdata.popup.popup_x, xdata.popup.popup_y);
            }
            else if(TP.iconSettingsWindow) {
                var size = TP.iconSettingsWindow.getSize();
                var pos  = TP.iconSettingsWindow.getPosition();
                TP.suppressIconTipForce = false;
                this.showAt([pos[0] + size.width + 10, pos[1]]);
            }
        },
        setFixedOffsetPosition: function(panel, x, y) {
            if(!panel || !panel.getPosition) { return; }
            var pos  = panel.getPosition();
            TP.suppressIconTipForce = false;
            this.showAt([pos[0]+x, pos[1]+y]);
        },
        setFixedPosition: function(x, y) {
            TP.suppressIconTipForce = false;
            this.showAt([x, y]);
        }
    });

    TP.tipRenderer = function (evt, el, eOpts, force) {
        if(evt.target.tagName == "rect") { delete TP.iconTipTarget; return; } /* skip canvas elements and only popup on actual paths */
        var img = Ext.getCmp(el.id);
        if(!img || !img.el || !img.el.dom) { delete TP.iconTipTarget; return; }
        try {
            if(img.panel) { img = img.panel; el = img.el.dom }
        } catch(e) { delete TP.iconTipTarget; return;} // errors with img.el not defined sometimes

        var xdata = img.xdata;
        if(TP.iconSettingsWindow) {
            xdata = TP.get_icon_form_xdata(TP.iconSettingsWindow);
            img   = TP.iconSettingsWindow.panel;
            TP.iconTipTarget = TP.iconSettingsWindow.panel;
        }

        /* activate label mouseover */
        if(img.labelEl && xdata.label.display && xdata.label.display == 'mouseover') {
            img.labelEl.mouseover = true;
            img.labelEl.show();
            delete img.labelEl.mouseover;
            TP.mouseoverLabel = img.labelEl;
        }

        var tabpan = Ext.getCmp('tabpan');
        var tab = tabpan.getActiveTab();
        if(tab && !tab.locked && !TP.iconSettingsWindow) { delete TP.iconTipTarget; return; }

        if(!force && TP.suppressIconTip) { delete TP.iconTipTarget; return; }
        evt.stopEvent();
        TP.iconTipTarget = img;

        if(!force && ( TP.iconTip.last_id && TP.iconTip.last_id == el.id)) { TP.suppressIconTipForce = false; return; }
        TP.iconTip.panel   = img;
        /* hide when in edit mode */
        if(!force && !img.locked) { return; }
        TP.iconTip.last_id = el.id;
        if(!img.getName) { delete TP.iconTipTarget; return; }
        if(img.iconType == 'filter' || img.iconType == 'image') {
            TP.iconTip.setTitle(img.getName());
        } else {
            TP.iconTip.setTitle(ucfirst(img.iconType)+': '+img.getName());
        }
        var link;
        var d = img.getDetails();
        /* custom popup details */
        if(xdata.popup && xdata.popup.type == "custom") {
            /* convert current details into hash */
            var dHash = {};
            for(var x=0; x<d.length; x++) {
                dHash[d[x][0]] = d[x];
            }
            d = [];
            var content = xdata.popup.content.split(/\n/);
            var curBlock = [];
            for(var x=0; x<content.length; x++) {
                var line = content[x];
                var m = line.match(/^\{\{\s*(.*)\s*\}\}\s*$/);
                if(m && m[1]) {
                    m[1] = m[1].replace(/^\s+/, '');
                    m[1] = m[1].replace(/\s+$/, '');
                    if(dHash[m[1]]) {
                        if(curBlock[0] != undefined) { d.push(curBlock); curBlock = []; }
                        d.push(dHash[m[1]]);
                        continue;
                    }
                    if(dHash['*'+m[1]]) {
                        if(curBlock[0] != undefined) { d.push(curBlock); curBlock = []; }
                        /* make it possible to show a title for sections which use colspan usually */
                        d.push([m[1], dHash['*'+m[1]][1]]);
                        continue;
                    }
                    if(m[1].match(/^\*/)) {
                        /* search for existing items without a leading asterix to hide sections which are not with a colspan by default */
                        var key = m[1].replace(/^\*/, '');
                        if(dHash[key]) {
                            if(curBlock[0] != undefined) { d.push(curBlock); curBlock = []; }
                            d.push([m[1], dHash[key][1]]);
                            continue;
                        }
                    }
                }
                m = line.match(/^(.*):$/);
                if(m && m[1]) {
                    if(curBlock[0] != undefined) { d.push(curBlock); curBlock = []; }
                    curBlock[0] = m[1];
                    curBlock[1] = '';
                    continue;
                }
                if(curBlock[0] != undefined) {
                    curBlock[1] += img.setIconLabelDynamicText(line);
                    curBlock[1] += '<br>';
                    continue;
                }
                if(curBlock[0] != undefined) { d.push(curBlock); curBlock = []; }
                curBlock[0] = '';
                curBlock[1] = img.setIconLabelDynamicText(line)+'<br>';
            }
            if(curBlock[0] != undefined) { d.push(curBlock); curBlock = []; }
        }

        TP.iconTip.panel = undefined;
        if(d.length == 0) {
            delete TP.iconTipTarget;
            TP.iconTip.hide();
            return;
        }
        var details = '<table class="iconDetails">';
        for(var x=0; x<d.length; x++) {
            if(d[x].length == 2 && d[x][0] == '')        { d[x] = [d[x][1]]; }
            if(d[x].length == 2 && d[x][0].match(/^\*/)) { d[x] = [d[x][1]]; }
            if(d[x].length == 1) {
                details += '<tr>';
                details += '<td colspan=2>'+d[x][0]+'<\/td>';
                details += '<\/tr>';
            }
            else if(d[x][0] == "Details" && d[x].length == 3) {
                TP.iconTip.panel = d[x][2];
                link             = d[x][1];
                details += '<tr>';
                details += '<td colspan=2 id="tipdetails"><\/td>';
                details += '<\/tr>';
            } else {
                details += '<tr>';
                details += '<th>'+d[x][0]+'<\/th>';
                details += '<td>'+d[x][1]+'<\/td>';
                details += '<\/tr>';
            }
        }
        details += '<\/table>';
        TP.iconTip.update(details);
        var size;
        if(TP.iconTip.el) { size = TP.iconTip.getSize(); }
        if(size == undefined || size.width <= 1 || size.height <= 1) { size = {width: 500, height: 150} }
        TP.suppressIconTipForce = false;
        if(xdata.popup && xdata.popup.popup_position == "relative position") {
            TP.iconTip.setFixedOffsetPosition(img, xdata.popup.popup_x, xdata.popup.popup_y);
        }
        else if(xdata.popup && xdata.popup.popup_position == "absolute position") {
            TP.iconTip.setFixedPosition(xdata.popup.popup_x, xdata.popup.popup_y);
        }
        else if(!TP.iconSettingsWindow) {
            var showAtPos = TP.getNextToPanelPos(img, size.width, size.height);
            TP.iconTip.showAt(showAtPos);
        } else {
            TP.iconTip.alignToSettingsWindow();
        }
        img.el.dom.onmouseout = function() {
            TP.iconTip.delayHide();
        };
        if(link && TP.iconTip.panel) {
            var style = 'detail';
            if(!(TP.iconTip.panel.iconType == 'servicegroup' || TP.iconTip.panel.xdata.general.incl_svc) || TP.iconTip.panel.iconType == 'host') {
                style = 'hostdetail';
            }
            link = link+'&style='+style+'&view_mode=json';
            if(!document.getElementById('tipdetails')) {
                // will result in js error if renderTo target does not (yet) exist
                return;
            }
            if(TP.iconTip.detailsTarget) { TP.iconTip.detailsTarget.destroy(); }
            TP.iconTip.detailsTarget = Ext.create('Ext.panel.Panel', {
                renderTo: 'tipdetails',
                html:     ' ',
                border:     0,
                minHeight: 40,
                width:     480
            });
            TP.iconTip.detailsTarget.body.mask("loading");
            if(link == TP.iconTip.lastUrl && TP.iconTip.lastData) {
                TP.renderTipDetails(TP.iconTip.lastData);
                TP.iconTip.detailsTarget.body.unmask();
            } else if(link == TP.iconTip.lastUrl) {
                // just wait till its rendered...
            } else {
                TP.iconTip.lastData = undefined;
                TP.iconTip.lastUrl  = link;
                Ext.Ajax.request({
                    url:     link,
                    method: 'POST',
                    callback: function(options, success, response) {
                        if(!success) {
                            TP.iconTip.lastUrl = undefined;
                            if(response.status == 0) {
                                TP.Msg.msg("fail_message~~fetching details failed");
                            } else {
                                TP.Msg.msg("fail_message~~fetching details failed: "+response.status+' - '+response.statusText);
                            }
                        } else {
                            var data = TP.getResponse(undefined, response);
                            TP.iconTip.lastData = data;
                            TP.renderTipDetails(TP.iconTip.lastData);
                        }
                        TP.iconTip.detailsTarget.body.unmask();
                    }
                });
            }
        }
    };

    Ext.getBody().on('mouseover', function(evt,t,a) {
        /* cancel previous hide timer */
        window.clearTimeout(TP.iconTip.hideTimer);
        delete TP.iconTip.hideTimer;

        cursorX = evt.pageX;
        cursorY = evt.pageY;

        TP.tipRenderer(evt,t,a);
    }, null, {delegate:'A.tooltipTarget'});

    Ext.getBody().on('mouseout', function(evt,t,a) {
        if(TP.mouseoverLabel && !TP.iconSettingsWindow) {
            TP.mouseoverLabel.hide();
            delete TP.mouseoverLabel;
        }
    }, null, {delegate:'A.tooltipTarget'});
});

/* render tip details */
TP.renderTipDetails = function(data) {
    if(data == undefined) { return; }
    if(TP.iconTip == undefined) { return; }
    if(TP.iconTip.panel == undefined) { return; }
    var panel      = TP.iconTip.panel;
    var details    = '';
    var num_shown  = 0;
    if(panel.xdata.general.incl_hst || panel.iconType == 'host') {
        details += '<table class="TipDetails">';
        details += '<tr>';
        details += '<th>Hosts:<\/th>';
        details += '<\/tr>';
        var skipped = 0;
        var uniq_hosts   = {};
        var host_details         = [];
        var host_details_skipped = [];
        for(var x=0; x<data.length;x++) {
            var d = data[x];
            var prefix = '';
            if(d['host_name']) {
                prefix = 'host_';
            }
            if(uniq_hosts[d[prefix+'name']]) { continue; }
            if(host_details_skipped.length > 5) { skipped++; continue; }
            uniq_hosts[d[prefix+'name']] = true;
            delete d['action_url_expanded'];
            delete d['notes_url_expanded'];
            var icons = TP.render_host_icons({}, {}, {}, {}, {}, {}, {}, d);
            var statename = TP.render_host_status(d[prefix+'state'], {}, {data:d});
            detail  = '<tr>';
            detail += '<td class="host"><table class="icons"><tr><td>'+d[prefix+'name']+'<\/td><td class="icons">'+icons+'<\/td><\/tr><\/table><\/td>';
            detail += '<td class="state"><div class="extinfostate '+statename.toUpperCase()+'">'+statename.toUpperCase()+'<\/div><\/td>';
            detail += '<td class="plugin_output">'+d[prefix+'plugin_output']+'<\/td>';
            detail += '<\/tr>';
            if(data.length > 10 && (num_shown >= 5 || (panel.xdata.state != 0 && d[prefix+'state'] == 0))) {
                skipped++;
                host_details_skipped.push(detail);
                continue;
            }
            host_details.push(detail);
            num_shown++;
        }
        details += host_details.join("");
        if(skipped == 1) {
            details += host_details_skipped.join("");
            skipped = 0;
        }
        if(skipped > 0) {
            var link = TP.getIconDetailsLink(panel);
            details += '<tr>';
            details += '<td class="more_hosts" colspan=3><a href="'+link+'" target="_blank">'+(skipped)+' more host'+(skipped > 1 ? 's' : '')+'...</a><\/td>';
            details += '<\/tr>';
        }
        details += '<\/table>';
    }
    if(panel.xdata.general.incl_svc || panel.iconType == 'servicegroup') {
        details += '<table class="TipDetails">';
        details += '<tr>';
        details += '<th>Services:<\/th>';
        details += '<\/tr>';
        var last_host = "";
        skipped = 0;
        for(var x=0; x<data.length;x++) {
            var d = data[x];
            if(data.length > 10 && (num_shown >= 10 || (panel.xdata.state != 0 && d['state'] == 0))) { skipped++; continue; }
            delete d['action_url_expanded'];
            delete d['notes_url_expanded'];
            var icons = TP.render_service_icons({}, {}, {}, {}, {}, {}, {}, d);
            var statename = TP.render_service_status(d['state'], {}, {data:d});
            details += '<tr>';
            if(last_host != d['host_name']) {
                details += '<td class="host svchost">'+d['host_name']+'<\/td>';
            } else {
                details += '<td class="emptyhost"><\/td>';
            }
            details += '<td class="descr"><table class="icons"><tr><td>'+d['description']+'<\/td><td class="icons">'+icons+'<\/td><\/tr><\/table><\/td>';
            details += '<td class="state"><div class="extinfostate '+statename.toUpperCase()+'">'+statename.toUpperCase()+'<\/div><\/td>';
            details += '<td class="plugin_output">'+d['plugin_output']+'<\/td>';
            details += '<\/tr>';
            last_host = d['host_name'];
            num_shown++;
        }
        if(skipped > 0) {
            var link = TP.getIconDetailsLink(panel);
            details += '<tr>';
            details += '<td class="more_services" colspan=4><a href="'+link+'" target="_blank">'+(skipped)+' more service'+(skipped > 1 ? 's' : '')+'...</a><\/td>';
            details += '<\/tr>';
        }
        details += '<\/table>';
    }
    TP.iconTip.detailsTarget.update(details);
    // make sure new size fits viewport
    TP.iconTip.detailsTarget.doLayout();
    TP.suppressIconTipForce = false;
    if(panel.xdata.popup && panel.xdata.popup.popup_position == "relative position") {
        TP.iconTip.setFixedOffsetPosition(img, panel.xdata.popup.popup_x, panel.xdata.popup.popup_y);
    }
    else if(panel.xdata.popup && panel.xdata.popup.popup_position == "absolute position") {
        TP.iconTip.setFixedPosition(panel.xdata.popup.popup_x, panel.xdata.popup.popup_y);
    }
    else if(!TP.iconSettingsWindow) {
        var size      = TP.iconTip.getSize();
        if(size.width <= 1 || size.height <= 1) { size = {width: 500, height: 150} }
        var showAtPos = TP.getNextToPanelPos(panel, size.width, size.height);
        TP.iconTip.showAt(showAtPos);
    } else {
        TP.iconTip.alignToSettingsWindow();
    }
    TP.iconTip.syncShadow();
    return;
}

// save cursor position
var cursorX;
var cursorY;
document.onmousemove = function(e){
    cursorX = e.pageX;
    cursorY = e.pageY;
}
