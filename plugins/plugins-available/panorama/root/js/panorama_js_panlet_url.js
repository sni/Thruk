Ext.define('TP.PanletUrl', {
    extend: 'TP.Panlet',

    title: 'url panlet',
    height: 220,
    width:  440,
    initComponent: function() {
        var panel = this;
        panel.callParent();
        panel.noChangeUrlParams = true;
        panel.xdata.url      = '';
        panel.xdata.selector = '';
        panel.xdata.keepcss  = true;
        panel.reloadOnSiteChanges = true;

        panel.loader = {
            autoLoad: false,
            renderer: 'data',
            scope:    panel,
            ajaxOptions: { method: 'GET' },
            callback: function(This, success, response, options) {
                This.loading = false;
                window.clearTimeout(TP.timeouts['timeout_' + panel.id + '_refresh']);
                var html;
                if(response.status == 200) {
                    /* should we pick only a part of the page */
                    var el;
                    if(panel.xdata.selector != '') {
                        /* create pseudo window to render html */
                        el    = new Ext.window.Window({html: response.responseText, x: -10000, y: -10000}).show();
                        var q = el.body.select(panel.xdata.selector).elements[0];
                        if(q == undefined) {
                            html = 'ERROR: selector not found';
                        } else {
                            html = q.outerHTML;
                        }
                    } else {
                        html  = response.responseText;
                    }

                    var head = '';
                    /* keep css links */
                    if(panel.xdata.keepcss && panel.xdata.selector != '') {
                        el.body.select('LINK').each(function(el) {
                            if(!el.dom.outerHTML.match(/thruk_noframes\.css/)) {
                                head = head + el.dom.outerHTML;
                            }
                        });
                        head = '<head>' + head + '<\/head>';
                    }
                    html = '<html style="overflow-x:hidden; overflow-y: hidden;">' + head + '<body>' + html + '<\/body><\/html>';
                    if(el != undefined) {
                        el.destroy();
                    }
                } else {
                    html = 'ERROR: request failed with status: ' + response.status;
                    TP.log('['+panel.id+'] '+html);
                    debug(response);
                }

                /* replace iframe content */
                var iframe;
                try {
                    iframe = panel.items.getAt(0).getEl().dom;
                } catch(err) {
                    TP.logError(This.id, "iframeNotFoundException", err);
                }

                if(iframe && (iframe.contentWindow || iframe.contentDocument)) {
                    var ifrm = (iframe.contentWindow) ? iframe.contentWindow : (iframe.contentDocument.document) ? iframe.contentDocument.document : iframe.contentDocument;
                    try {
                        if(ifrm && ifrm.document) {
                            ifrm.document.open();
                            ifrm.document.write(html);
                            ifrm.document.close();
                        } else {
                            panel.setBlankAndRefreshLater(iframe);
                        }
                    } catch(err) {
                        TP.logError(This.id, "iframeOpenException", err);
                        /* first reload after changing from external to internal url does not work*/
                        panel.setBlankAndRefreshLater(iframe);
                    }
                }
            }
        };

        panel.setBlankAndRefreshLater = function(iframe) {
            iframe.src = 'about:blank';
            TP.timeouts['timeout_' + panel.id + '_refresh'] = window.setTimeout(Ext.bind(panel.refreshHandler, panel, []), 1000);
        };

        panel.iframeErrorHandler = function(evt) {
            if(TP.isUnloading) { return; }
            evt = (evt) ? evt : ((window.event) ? event : null);
            var iframe = evt.target;
            var ifrm   = (iframe.contentWindow) ? iframe.contentWindow : (iframe.contentDocument.document) ? iframe.contentDocument.document : iframe.contentDocument;
            TP.log('['+panel.id+'] iframeErrorHandler, error on '+iframe.src);
            ifrm.document.open();
            ifrm.document.write("<style type='text/css'>body {background: white;}<\/style><span style='color: red; font-weight:bold;'>failed to load: " + iframe.src+"<\/span><br>due to javascripts cross domain policy, the exact error cannot be determinced.<br>possible causes:<ul><li>Server does not respond<\/li><li>Trying to access http url from https dashboard.<\/li><\/ul>");
            ifrm.document.close();
        };

        panel.reloads = 0;
        panel.refreshHandler = function() {
            TP.log('['+panel.id+'] refreshHandler("'+panel.xdata.url+'")');
            panel.reloads++;
            /* remove and replace complete iframe object to prevent memory leaks */
            if(panel.reloads > 20) {
                panel.reloads = 0;
                panel.addIframe();
                window.clearTimeout(TP.timeouts['timeout_' + panel.id + '_refresh']);
                TP.timeouts['timeout_' + panel.id + '_refresh'] = window.setTimeout(Ext.bind(panel.refreshHandler, panel, []), 3000);
            }
            var iframeObj = panel.items.getAt(0).getEl();
            if(!TP.isSameOrigin(window.location, TP.getLocationObject(panel.xdata.url))) {
                /* set external url as src */
                var iframeObj = panel.items.getAt(panel.items.length-1).getEl();
                if(iframeObj && iframeObj.dom) {
                    iframeObj.dom.onerror = panel.iframeErrorHandler;
                    iframeObj.dom.src     = Ext.urlAppend(panel.xdata.url, '_dc='+Ext.Date.now())
                    TP.log('['+panel.id+'] refreshHandler: set iframe url '+iframeObj.dom.src);
                }
            } else {
                TP.defaultSiteRefreshHandler(panel);
            }
        };
        panel.manualRefresh = function() {
            TP.log('['+panel.id+'] manualRefresh');
            panel.body.mask('Loading...');
            panel.refreshHandler();
        };

        panel.addIframe = function() {
            if(panel.gearitem) { return; }
            panel.removeAll(true);
            /* url content should be in an iframe */
            panel.add({
                xtype : 'component',
                autoEl : {
                    tag : 'iframe',
                    src : '',
                    style: {
                        border: 0
                    }
                },
                listeners: {
                    load: {
                        element: 'el',
                        fn: function () {
                            TP.log('['+panel.id+'] loaded');
                            window.clearTimeout(TP.timeouts['timeout_' + panel.id + '_refresh']);
                            panel.unmask();
                            panel.body.unmask();
                        }
                    },
                    exception: {
                        element: 'el',
                        fn: function () {
                            panel.unmask();
                            panel.body.unmask();
                        }
                    }
                }
            });
        }
        panel.addIframe();

        /* auto load when url is set */
        panel.addListener('afterrender', function() {
            if(panel.xdata.url == '' || panel.xdata.url == 'about:blank') {
                panel.gearHandler();
            } else {
                panel.refreshHandler();
            }
        });

        /* sometime initial url doesn't work */
        panel.formUpdatedCallback = function(panel) {
            TP.timeouts['timeout_' + panel.id + '_refresh'] = window.setTimeout(Ext.bind(panel.refreshHandler, panel, []), 1000);
        };
    },
    setGearItems: function() {
        var panel = this;
        panel.callParent();
        panel.addGearItems([{
            fieldLabel: 'URL',
            xtype:      'textfield',
            name:       'url',
            emptyText:  'target url, ex.: http://thruk.org/ or relative url',
            listeners: {
                change: function(This, newV, oldV, eOpts) {
                    var pan = This.up('panel');
                    var sel = pan.items.getAt(4);
                    var css = pan.items.getAt(5);
                    if(!TP.isSameOrigin(window.location, TP.getLocationObject(newV))) {
                        sel.emptyText = "css selector only supported for internal urls";
                        sel.setValue("");
                        sel.disable();
                        css.disable();
                    } else {
                        sel.emptyText = " ";
                        sel.enable();
                        css.enable();
                        var old = sel.getValue();
                        sel.setValue("");
                        sel.setValue(old);
                    }
                }
            }
        }, {
            fieldLabel: 'CSS Selector',
            xtype:      'textfield',
            name:       'selector',
            emptyText:  'optional css selector, ex.: DIV#id_of_element'
        }, {
            fieldLabel: 'Keep CSS',
            xtype:      'checkbox',
            name:       'keepcss'
        }]);
    }
});
