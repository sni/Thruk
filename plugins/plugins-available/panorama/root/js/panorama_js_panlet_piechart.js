Ext.define('TP.PanletPieChart', {
    extend: 'TP.Panlet',

    title:  'chart',
    width:  200,
    height: 200,
    initComponent: function() {
        var panel = this;
        this.callParent();
        this.xdata.showlabel = true;

        this.pieStore = Ext.create('Ext.data.Store', {
            fields: ['name','value'],
            data:  [{name:' ', value: 100}]
        });

        this.loader = {
            autoLoad: false,
            renderer: 'data',
            scope:    this,
            url:      '',
            ajaxOptions: { method: 'POST' },
            loading:  false,
            listeners: {
                'beforeload': function(This, options, eOpts) {
                    if(this.loading) {
                        return false;
                    }
                    this.loading = true;
                    return true;
                }
            },
            callback: function(This, success, response, options) {
                This.loading = false;
                var data = TP.getResponse(this, response);
                if(data) {
                    TP.log('['+this.id+'] loaded');
                    var fields = [];
                    for(var key in data.columns) {
                        fields.push(data.columns[key].dataIndex);
                    }
                    this.pieStore = Ext.create('Ext.data.Store', {
                        data:  {'items': data.data },
                        fields: fields,
                        proxy: {
                            type: 'memory',
                            reader: {
                                type: 'json',
                                root: 'items'
                            }
                        }
                    });
                    this.chart.series.getAt(0).colorSet = data.colors;
                    this.chart.bindStore(this.pieStore);
                    /* rendering pie charts on inactive tabs leads to setAttribute errors */
                    if(!TP.isThisTheActiveTab(panel)) {
                        return false;
                    }
                    if(this.chart.isVisible()) {
                        try { // this may fail when redrawing for the first time
                            this.chart.redraw();
                        } catch(err) {
                            TP.logError(this.id, "chartRedrawException", err);
                        }
                    }
                    this.chart.setShowLabel();
                }
            }
        };

        this.addListener('beforerender', function() {
            this.refreshHandler();
        });
        this.chart = Ext.create('TP.piechart', {
            store:   this.pieStore,
            panel:   this,
            donut:   false
        });
        this.add(this.chart);

        this.addListener('show', function() {
            this.syncShadowTimeout();
        });
    },
    setGearItems: function() {
        var panel = this;
        this.callParent();
        this.addGearItems({
            fieldLabel: 'Show Border',
            xtype:      'checkbox',
            name:       'showborder'
        });
        this.addGearItems({
            fieldLabel: 'Show Label',
            xtype:      'checkbox',
            name:       'showlabel'
        });
    }
});


Ext.define('TP.piechart', {
    extend: 'Ext.chart.Chart',

    alias:  'widget.tp_piechart',

    animate: true,
    shadow:  true,
    legend:  false,
    insetPadding: 3,
    theme:  'Base:gradients',
    initComponent: function() {
        var pie = this;
        this.series = [{
            type:        'pie',
            field:       'value',
            showInLegend: true,
            colorSet:  [ '#00FF00' ],
            donut:        this.donut != undefined ? this.donut : false,
            label: {
                field: 'name',
                display: 'rotate',
                contrast: true,
                font: '12px Arial',
                renderer: function(v, x, y) {
                    if(!pie.panel || !pie.panel.xdata || !pie.panel.xdata.showlabelVal) {
                        return(v);
                    }
                    var idx       = pie.store.findExact('name', v);
                    var storeItem = pie.store.getAt(idx);
                    var total = 0;
                    storeItem.store.each(function(rec) {
                        total += rec.get('value');
                    });
                    return((pie.panel.xdata.showlabel ? v+' ' : '') + Math.round(storeItem.get('value') / total * 100) + '%');
                }
            }
        }];
        if(this.animate) {
            this.series[0].tips = {
                trackMouse: true,
                width: 140,
                height: 28,
                renderer: function(storeItem, item) {
                    var total = 0;
                    storeItem.store.each(function(rec) {
                        total += rec.get('value');
                    });
                    this.setTitle(storeItem.get('name') + ': ' + storeItem.get('value') + ' (' + Math.round(storeItem.get('value') / total * 100) + '%)');
                }
            };
            this.series[0].highlight = {
                segment: {
                    margin: 20
                }
            };
        } else {
            this.series[0].tips      = false;
            this.series[0].highlight = false;
        }
        this.callParent();

        if(this.animate) {
            this.addListener('render', function(This, eOpts) {
                var div   = This.getEl();
                var panel = This.panel;
                div.on("mouseout", function()  {
                    TP.timeouts['timeout_'+This.id+'_redraw'] = window.setTimeout(Ext.bind(function() {
                        panel.chart.redraw();
                    }, panel, []), 1000);
                });
                div.on("mouseover", function()  {
                    window.clearTimeout(TP.timeouts['timeout_'+This.id+'_redraw']);
                });
            });
            this.addListener('destroy', function(This) {
                window.clearTimeout(TP.timeouts['timeout_'+This.id+'_redraw']);
            });
        }
        this.addListener('resize', function(This) {
            This.setShowLabel();
        });
    },
    setShowLabel: function() {
        var panel = this.panel;
        if(this.getEl()) {
            Ext.each(this.getEl().query('text'), function(el) {
                if(panel.xdata.showlabel == false && panel.xdata.showlabelVal != true) {
                    el.style.fill = 'transparent';
                } else {
                    el.style.fill = '';
                }
            });
        }
    }
});
