Ext.define('TP.TabBarSearch', {
    extend:     'Ext.form.field.Text',
    alias:      'widget.tp_tabbarsearch',

    emptyText:  'search',
    fieldStyle: 'background: #f0f0f0;',
    height:      20,
    padding:     '0 10 0 0',
    enableKeyEvents: true,
    listeners: {
        focus:  function(This, e, eOpts) { This.onChanged(); },
        keyup:  function(This, e, eOpts) { This.onChanged(); },
        change: function(This, e, eOpts) { This.onChanged(); }
    },
    onChanged: function() {
        var This = this;
        This.menu = Ext.menu.Manager.get(This.menu);
        This.menu.ownerButton = This;
        var val  = Ext.String.trim(This.getValue());
        if(val.length < 2) { // must have at least 2 characters
            This.menu.hide();
            return;
        }
        if(!This.menu.isVisible()) {
            This.menu.showBy(This);
        }
        TP.delayEvents(This, function() {
            This.updateMenu();
        }, 300);
    },
    updateMenu: function() {
        var This = this;
        var menu = This.menu;
        var val  = This.getValue();
        if(This.lastSearch == val) { return; }
        if(val == "") {
            This.menu.hide();
            return;
        }
        This.lastSearch = val;
        menu.removeAll();
        menu.plain = false;
        menu.add({
            text:    'Loading...',
            icon:    url_prefix+'plugins/panorama/images/loading-icon.gif',
            disabled: true
        });
        Ext.Ajax.request({
            url:      "panorama.cgi",
            method:  'POST',
            params: { task: "search", value: val },
            callback: function(options, success, response) {
                if(!success) {
                    if(response.status == 0) {
                        TP.Msg.msg("fail_message~~search failed");
                    } else {
                        TP.Msg.msg("fail_message~~search failed: "+response.status+' - '+response.statusText);
                    }
                    return;
                }
                var data = TP.getResponse(undefined, response);
                menu.removeAll();
                menu.plain = true;
                if(data && data.data) {
                    data = data.data;
                    for(var x = 0; x<data.length; x++) {
                        if(x == 20) {
                            menu.add({
                                text: "<span class='searchhint'>showing first 20 of "+data.length+" results...<\/span>",
                                disabled: true
                            });
                            break;
                        }
                        This.menuAddFoundEntry(menu, data[x]);
                    }
                    // no matches at all?
                    if(menu.items.length == 0) {
                        menu.add({
                            text:    'nothing found',
                            disabled: true
                        });
                    }
                }
            }
        });
    },
    menu: {
        focusOnToFront: false,
        showSeparator: false,
        items: [{
            text:    'Loading...',
            icon:    url_prefix+'plugins/panorama/images/loading-icon.gif',
            disabled: true
        }]
    },
    menuHandler: function(item, e) {
        var highlight = function(el) {
            // highlight this icon
            var icon = Ext.getCmp(el.highlight);
            if(!icon)    { return; }
            if(!icon.el) { return; }
            icon.el.dom.style.boxShadow = "0 0 25px 25px #0083ee";
            TP.flickerImg(icon.el.id, function() {
                icon.el.dom.style.boxShadow = "";
            });
        }
        var highlightAll = function() {
            for(var x = 0; x<item.highlight.length; x++) {
                var el = item.highlight[x];
                if(el.highlight) {
                    highlight(el);
                }
            }
        };
        var tab = Ext.getCmp(item.data.id);
        if(tab && tab.rendered) {
            var tabpan = Ext.getCmp('tabpan');
            tabpan.setActiveTab(tab);
            // delay highlight a bit
            window.setTimeout(highlightAll, 500);
        } else {
            TP.add_pantab(item.data.id, undefined, undefined, function() {
                // delay highlight a bit
                window.setTimeout(highlightAll, 2000);
            });
        }
    },
    menuAddFoundEntry: function(menu, data) {
        var This  = this;

        var label    = "<span class='searchname'>"+data.name+"<\/span>";
        var hints    = {}
        var subitems = [];

        var detailedHints = {};
        for(var x = 0; x<data.matches.length; x++) {
            var match = data.matches[x];

            // trim the pre match text
            var pre = match.pre;
            if(pre.length > 12) {
                pre = "..."+pre.substr(-12);
            }
            // trim the actual match if its too long
            var text = match.match;
            if(text.length > 25) {
                var t1 = text.substr(-12);
                var t2 = text.substr(0, 12);
                text = t1+"..."+t2;
            }
            // trim the post match text
            var post = match.post;
            if(post.length > 12) {
                post = post.substr(0, 12)+"...";
            }
            var sublabel = "<span class='searchhint type'>"+match.type+":<\/span>"
                          +"<span class='searchhint'>"+pre+"<b>"+text+"<\/b>"+post+"<\/span>";
            subitems.push({
                text:      sublabel,
                handler:   This.menuHandler,
                data:      data,
                highlight: [match]
            });

            if(hints[match.type]) {
                hints[match.type]++;
            } else {
                hints[match.type] = 1;
            }
            detailedHints[sublabel] = 1;
        }
        var hintslabel = [];
        for(var key in hints) {
            var nr = hints[key];
            if(nr == 1) {
                hintslabel.push(" "+hints[key]+" "+key);
            } else {
                hintslabel.push(" "+hints[key]+" "+key+"s");
            }
        }
        if(Object.keys(detailedHints).length == 1) {
            var keys = Object.keys(detailedHints);
            label += "<span class='searchhints'>("+keys[0]+")<\/span>";
        } else {
            label += "<span class='searchhints'>(matches in "+hintslabel.join(', ')+")<\/span>";
        }

        subitems = Ext.Array.sort(subitems, function(a, b) { return(a['text'].localeCompare(b['text'])) });
        var submenu = Ext.create('Ext.menu.Menu', {
            plain: true,
            items: subitems
        });

        menu.add({
            text:      label,
            cls:       'searchresult',
            data:      data,
            highlight: data.matches,
            handler:   This.menuHandler,
            menu:      submenu
        });
    }
});
