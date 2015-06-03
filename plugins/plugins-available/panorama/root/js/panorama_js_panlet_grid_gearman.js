Ext.define('TP.PanletGridGearmanMetrics', {
    extend: 'TP.PanletGrid',

    title:  'Mod-Gearman Metrics',
    height: 200,
    width:  360,
    hideSettingsForm: ['url', 'backends'],
    initComponent: function() {
        this.callParent();
        this.xdata.server = 'localhost:4730';
        this.xdata.url    = 'panorama.cgi?task=stats_gearman_grid';
    },
    setGearItems: function() {
        var panel = this;
        this.callParent();
        this.addGearItems({
            fieldLabel: 'Gearman Daemon',
            xtype:      'textfield',
            name:       'server'
        });
    }
});

Ext.define('GearmanTop', {
    extend: 'Ext.data.Model',
    fields: [{ name:'name' },
             { name:'worker',   type:'int' },
             { name:'running',  type:'int' },
             { name:'waiting',  type:'int' },
             { name:'nr',       type:'int' },
             { name:'date',     type:'date'}
            ]
});

Ext.define('TP.PanletChartGearman', {
    extend: 'TP.PanletChart',

    title:  'Gearman Queues',
    width:  640,
    height: 260,
    hideSettingsForm: ['url', 'backends'],
    initComponent: function() {
        var panel = this;
        this.callParent();

        this.store = new Ext.data.Store({
                model: 'GearmanTop',
                data: []
        });

        this.xdata.queue  = 'service';
        this.xdata.server = 'localhost:4730';
        this.xdata.url    = 'panorama.cgi?task=stats_gearman';
        this.formUpdatedCallback = function() {
            if(this.setTitle) {
                this.setTitle('Mod-Gearman ' + ucfirst(this.xdata.queue) + ' Queue');
            }
            if(this.lastqueue != this.xdata.queue) {
                this.lastqueue = this.xdata.queue;
                this.fill_store();
                this.refreshHandler();
            }
        };
        this.getData = function(data) {
            /* fill queue store, but only when not selected currently */
            if(panel.gearitem) {
                var queue_store = TP.getFormField(panel.gearitem.down('form'), 'queue').store;
                queue_store.removeAll();
                for(var key in data) {
                    var name = ucfirst(key);
                    if(name == 'Check_results') {
                        name = 'Check Results';
                    } else{
                        name = name.replace(/_/, ' ');
                    }
                    queue_store.loadRawData({name:name, value:key}, true);
                }
                queue_store.sort('name');
            }
            return data[this.xdata.queue];
        };
        this.updated_callback = function(panel) {
            var chart = this.chart;
            if(!this.store || !this.store.max || !this.store.max('date')) {
                return;
            }
            var tabpan = Ext.getCmp('tabpan');
            var refresh = this.xdata.refresh;
            if(refresh == -1 ) { refresh = tabpan.xdata.refresh; }
            if(refresh == 0)   { refresh = 60; }
            var minutes_to_show = Math.ceil(refresh * this.xdata.nr_dots / 60 * 1.5);
            /* dynamically adjust minimum/maximum and ticks */
            var max     = this.store.max('date').getTime() / 1000;
            var axis = chart.axes.getAt(1);
            var min = max - minutes_to_show * 60;
            if(minutes_to_show > 30) {
                axis.majorTickSteps = (minutes_to_show / 10)-1;
                axis.minorTickSteps = 9;
                min = min - min%600 + 600;
            }
            else if(minutes_to_show > 10) {
                axis.majorTickSteps = (minutes_to_show / 5)-1;
                axis.minorTickSteps = 4;
                min = min - min%300 + 300;
            }
            else if(minutes_to_show < 10) {
                axis.majorTickSteps = minutes_to_show-1;
                axis.minorTickSteps = 5;
                min = min - min%60 + 60;
            }
            var mindate = min*1000;
            var first   = this.store.data.first();
            while(first != undefined && first.get('date').getTime() < mindate) {
                this.store.remove(first);
                first = this.store.data.first();
            }
            axis.minimum = mindate;
            axis.maximum = mindate + minutes_to_show * 60000;
        }

        /* add graph */
        this.chart = new Ext.chart.Chart({
            style:  'background:#fff',
            store:  this.store,
            shadow: true,
            theme:  'Category1',
            legend: {
                position: 'right'
            },
            listeners: {
                'beforerefresh': function(This, eOpts) {
                    // refreshing breaks if chart is not visible
                    return(!This.isHidden());
                }
            },
            axes: [{
                type:           'tp_numeric',
                minimum:         0,
                position:       'left',
                fields:         ['worker', 'running', 'waiting'],
                majorTickSteps: 4,
                minorTickSteps: 1,
                decimals:       1,
                grid: {
                    odd: {
                        opacity:        0.7,
                        fill:           '#ddd',
                        stroke:         '#bbb',
                        'stroke-width': 0.5
                    }
                }
            }, {
                type: 'tp_time',
                position: 'bottom',
                fields: ['date'],
                label: {
                    renderer: function(val){
                        val = val - val%60000; // round to 1 minute
                        var d = new Date(val);
                        return(Ext.Date.format(d, "H:i"));
                    }
                }
            }],
            series: [{
                type: 'line',
                axis: 'left',
                xField: 'date',
                yField: 'worker',
                showMarkers: false,
                style: {
                    'stroke-width': 2
                }
            }, {
                type: 'line',
                axis: 'left',
                xField: 'date',
                yField: 'waiting',
                showMarkers: false,
                style: {
                    'stroke-width': 2
                }
            }, {
                type: 'line',
                axis: 'left',
                xField: 'date',
                yField: 'running',
                showMarkers: false,
                style: {
                    'stroke-width': 2
                }
            }]
        });
        this.add(this.chart);
    },
    setGearItems: function() {
        var panel = this;
        this.callParent();
        this.addGearItems({
            fieldLabel: 'Gearman Daemon',
            xtype:      'textfield',
            name:       'server'
        });
        this.addGearItems({
            fieldLabel:   'Gearman Queue',
            xtype:        'combobox',
            name:         'queue',
            valueField:   'value',
            displayField: 'name',
            queryMode:    'local',
            store:        { fields: ['name', 'value'], data: [] },
            listeners: {
                afterrender: function() {
                    panel.refreshHandler();
                }
            }
        });
    },
    fill_store: function() {
        var now = new Date();
        this.store.suspendEvents();
        this.chart.hide();
        this.store.removeAll();
        for(var i=this.xdata.nr_dots;i>=0;i--) {
            var v = now.getTime() - i * 1000 * this.xdata.refresh;
            v = v - v%60000;
            var d = new Date(v);
            this.store.loadRawData({
                name:'', worker:0, running:0, waiting:0, nr:i, date:d
            }, true);
        }
        this.chart.show();
        this.store.resumeEvents();
    }
});
