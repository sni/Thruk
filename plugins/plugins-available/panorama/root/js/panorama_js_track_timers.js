var timers    = {};
var intervals = {};
var originalSetTimeout    = window.setTimeout;
var originalClearTimeout  = window.clearTimeout;
var originalSetInterval   = window.setInterval;
var originalClearInterval = window.clearInterval;

// override setTimeout with a function that keeps track of all timers
window.setTimeout = function(callback, timeout) {
    var err = new Error;
    var id = originalSetTimeout(function() {
        delete timers[id];
        try {
            if(Ext.isFunction(callback)) {
                callback();
            } else {
                eval(callback);
            }
        } catch(err2) {
            TP.logError("global", "setTimeoutExceptionOrigin", err);
            TP.logError("global", "setTimeoutException", err2);
            throw(err2);
        }
    }, timeout);
    timers[id] = ({id:id,  setAt: new Date(),  timeout: timeout, callback: callback, caller: window.setTimeout.caller});
    return(id);
}

window.clearTimeout = function(id) {
    delete timers[id];
    originalClearTimeout(id);
}

// override setInterval with a function that keeps track of all intervals
window.setInterval = function(callback, timer) {
    var err = new Error;
    var id = originalSetInterval(function() {
        intervals[id]['lastRun'] = new Date();
        try {
            if(Ext.isFunction(callback)) {
                callback();
            } else {
                eval(callback);
            }
        } catch(err2) {
            TP.logError("global", "setIntervalExceptionOrigin", err);
            TP.logError("global", "setIntervalException", err2);
        }
    }, timer);
    intervals[id] = ({id:id,  setAt: new Date(),  interval: timer, callback: callback, lastRun: undefined, caller: window.setInterval.caller});
    return(id);
}

window.clearInterval = function(id) {
    delete intervals[id];
    originalClearInterval(id);
}

/* return timer in a form which can be used by a store */
function getTimerStoreData() {
    var timerData = [];
    for(var key in timers) {
        var id   = timers[key].id;
        var name = undefined;
        if(!timers[key].name) {
            // get according name
            for(var key2 in TP.timeouts) {
                if(TP.timeouts[key2] == id) { name = key2; break; }
            }
            timers[key].name = name;
        }
        timerData.push(timers[key]);
    }
    return(timerData);
}

/* return intervals in a form which can be used by a store */
function getIntervalStoreData() {
    var intervalData = [];
    for(var key in intervals) {
        var id   = intervals[key].id;
        var name = undefined;
        if(!intervals[key].name) {
            // get according name
            for(var key2 in TP.timeouts) {
                if(TP.timeouts[key2] == id) { name = key2; break; }
            }
            intervals[key].name = name;
        }
        intervalData.push(intervals[key]);
    }
    return(intervalData);
}

/* return components in a form which can be used by a store */
function getComponentsStoreData() {
    var componentData = [];
    Ext.ComponentMgr.all.each(function (name, item) {
        componentData.push(item);
    });
    return(componentData);
}

/* show debug window */
thruk_debug_window_handler = function() {

    Ext.define('TimerModel', {
        extend: 'Ext.data.Model',
        fields: [
            { name: 'id',       type: 'int'    },
            { name: 'name',     type: 'string' },
            { name: 'setAt',    type: 'date'   },
            { name: 'timeout',  type: 'int'    },
            { name: 'callback', type: 'string' },
            { name: 'caller',   type: 'string' }
        ]
    });
    var timerStore = Ext.create('Ext.data.Store', {
        model: 'TimerModel',
        data:   getTimerStoreData(),
        listeners: {
            datachanged: function(store, eOpts) {
                var label = Ext.getCmp('timerNr');
                if(label) { label.update(store.count()+" Timer"); }
            }
        }
    });
    var timersTab = {
        title : 'Timers',
        type  : 'panel',
        layout: 'fit',
        items: [{
            xtype : 'panel',
            layout: 'fit',
            border: 0,
            items: [{
                xtype:   'grid',
                store:   timerStore,
                columns: [
                    { text: 'Id',       dataIndex: 'id',       width:  60 },
                    { text: 'Name',     dataIndex: 'name',     width: 170, renderer: TP.add_title    },
                    { text: 'Created',  dataIndex: 'setAt',    width:  60, renderer: TP.render_real_date },
                    { text: 'Timeout',  dataIndex: 'timeout',  width:  60 },
                    { text: 'Callback', dataIndex: 'callback', flex: 1,    renderer: TP.add_title    },
                    { text: 'Caller',   dataIndex: 'caller',   flex: 1,    renderer: TP.add_title    }
                ]
            }],
            dockedItems: [{
                xtype: 'toolbar',
                dock: 'bottom',
                items: [{
                    xtype:  'button',
                    icon:   url_prefix+'plugins/panorama/images/arrow_refresh.png',
                    text:   'Refresh',
                    handler: function(This) { This.up('panel').items.getAt(0).store.loadRawData(getTimerStoreData(), false) }
                }, {
                    xtype:    'checkbox',
                    boxLabel: 'Automatically Refresh',
                    handler:  function(This) {
                        if(This.checked) {
                            TP.timeouts['debug_timer_refresh'] = window.setInterval(function() {
                                This.up('panel').items.getAt(0).store.loadRawData(getTimerStoreData(), false);
                            }, 300);
                        } else {
                            window.clearInterval(TP.timeouts['debug_timer_refresh']);
                        }
                    },
                    margins: '5 0 5 0'
                }, {
                    xtype: 'tbfill'
                }, {
                    xtype:  'label',
                    id:     'timerNr',
                    text:    timerStore.count()+' Timer'
                }]
            }]
        }]
    };

    Ext.define('IntervalModel', {
        extend: 'Ext.data.Model',
        fields: [
            { name: 'id',       type: 'int'    },
            { name: 'name',     type: 'string' },
            { name: 'setAt',    type: 'date'   },
            { name: 'lastRun',  type: 'date'   },
            { name: 'interval', type: 'int'    },
            { name: 'callback', type: 'string' },
            { name: 'caller',   type: 'string' }
        ]
    });
    var intervalStore = Ext.create('Ext.data.Store', {
        model: 'IntervalModel',
        data:   getIntervalStoreData(),
        listeners: {
            datachanged: function(store, eOpts) {
                var label = Ext.getCmp('intervalNr');
                if(label) { label.update(store.count()+" Intervals"); }
            }
        }
    });
    var intervalsTab = {
        title : 'Intervals',
        type  : 'panel',
        layout: 'fit',
        items: [{
            xtype : 'panel',
            layout: 'fit',
            border: 0,
            items: [{
                xtype:   'grid',
                store:   intervalStore,
                columns: [
                    { text: 'Id',       dataIndex: 'id',       width:  60 },
                    { text: 'Name',     dataIndex: 'name',     width: 170, renderer: TP.add_title    },
                    { text: 'Created',  dataIndex: 'setAt',    width:  60, renderer: TP.render_real_date },
                    { text: 'Last Run', dataIndex: 'lastRun',  width:  60, renderer: TP.render_real_date },
                    { text: 'Interval', dataIndex: 'interval', width:  60 },
                    { text: 'Callback', dataIndex: 'callback', flex: 1,    renderer: TP.add_title    },
                    { text: 'Caller',   dataIndex: 'caller',   flex: 1,    renderer: TP.add_title    }
                ]
            }],
            dockedItems: [{
                xtype: 'toolbar',
                dock: 'bottom',
                items: [{
                    xtype:  'button',
                    icon:   url_prefix+'plugins/panorama/images/arrow_refresh.png',
                    text:   'Refresh',
                    handler: function(This) { This.up('panel').items.getAt(0).store.loadRawData(getIntervalStoreData(), false) }
                }, {
                    xtype:    'checkbox',
                    boxLabel: 'Automatically Refresh',
                    handler:  function(This) {
                        if(This.checked) {
                            TP.timeouts['debug_interval_refresh'] = window.setInterval(function() {
                                This.up('panel').items.getAt(0).store.loadRawData(getIntervalStoreData(), false);
                            }, 300);
                        } else {
                            window.clearInterval(TP.timeouts['debug_interval_refresh']);
                        }
                    },
                    margins: '5 0 5 0'
                }, {
                    xtype: 'tbfill'
                }, {
                    xtype:  'label',
                    id:     'intervalNr',
                    text:    intervalStore.count()+' Intervals'
                }]
            }]
        }]
    };


    Ext.define('ComponentsModel', {
        extend: 'Ext.data.Model',
        fields: [
            { name: 'id',         type: 'string' },
            { name: 'name',       type: 'string' },
            { name: 'xtype',      type: 'string' },
            { name: '$className', type: 'string' },
            { name: 'rendered',   type: 'bool'   }
        ]
    });
    var componentsStore = Ext.create('Ext.data.Store', {
        model: 'ComponentsModel',
        data:   getComponentsStoreData(),
        listeners: {
            datachanged: function(store, eOpts) {
                var label = Ext.getCmp('componentNr');
                if(label) { label.update(store.count()+" Components"); }
            }
        }
    });
    var componentsTab = {
        title : 'Components',
        type  : 'panel',
        layout: 'fit',
        items: [{
            xtype : 'panel',
            layout: 'fit',
            border: 0,
            items: [{
                xtype:   'grid',
                store:   componentsStore,
                columns: [
                    { text: 'Id',       dataIndex: 'id',         width: 200, renderer: TP.add_title    },
                    { text: 'Name',     dataIndex: 'name',       width: 200, renderer: TP.add_title    },
                    { text: 'Type',     dataIndex: 'xtype',      width: 100 },
                    { text: 'Class',    dataIndex: '$className', width: 150 },
                    { text: 'Rendered', dataIndex: 'rendered',   width:  60 }
                ]
            }],
            dockedItems: [{
                xtype: 'toolbar',
                dock: 'bottom',
                items: [{
                    xtype:  'button',
                    icon:   url_prefix+'plugins/panorama/images/arrow_refresh.png',
                    text:   'Refresh',
                    handler: function(This) { This.up('panel').items.getAt(0).store.loadRawData(getComponentsStoreData(), false) }
                }, {
                    xtype:    'checkbox',
                    boxLabel: 'Automatically Refresh',
                    handler:  function(This) {
                        if(This.checked) {
                            TP.timeouts['debug_component_refresh'] = window.setInterval(function() {
                                This.up('panel').items.getAt(0).store.loadRawData(getComponentsStoreData(), false);
                            }, 1000);
                        } else {
                            window.clearInterval(TP.timeouts['debug_component_refresh']);
                        }
                    },
                    margins: '5 0 5 0'
                }, {
                    xtype: 'tbfill'
                }, {
                    xtype:  'label',
                    id:     'componentNr',
                    text:    componentsStore.count()+' Components'
                }]
            }]
        }]
    };


    /* tab layout for settings window */
    var tabPanel = new Ext.TabPanel({
        activeTab         : 0,
        enableTabScroll   : true,
        items             : [
            intervalsTab,
            timersTab,
            componentsTab,
            TP.getLogTab()
        ]
    });

    /* the actual settings window containing the panel */
    var debug_win = new Ext.window.Window({
        autoShow:    true,
        modal:       true,
        width:       1000,
        height:      350,
        title:       'Debug Information',
        layout :     'fit',
        buttonAlign: 'center',
        items:       tabPanel,
        fbar: [{/* close button */
                    xtype:  'button',
                    text:   'OK',
                    handler: function(This) {
                        debug_win.destroy();
                    }
        }],
        listeners: {
            destroy: function(This, eOpts) {
                window.clearInterval(TP.timeouts['debug_interval_refresh']);
                window.clearInterval(TP.timeouts['debug_timer_refresh']);
                window.clearInterval(TP.timeouts['debug_component_refresh']);
                window.clearInterval(TP.timeouts['debug_log_refresh']);
            }
        }
    });
};
