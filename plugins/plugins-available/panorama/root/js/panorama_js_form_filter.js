Ext.define('TP.formFilter', {
    extend: 'Ext.form.FieldContainer',

    alias:  'widget.tp_filter',

    layout: {
        type: 'table',
        columns: 2
    },
    border: 0,
    items: [{
        xtype:      'textfield',
        name:       'name',
        value:      '',
        width:      0
    }, {
        xtype:     'button',
        text:      'Change Filter',
        icon:      url_prefix+'plugins/panorama/images/image_edit.png',
        handler:   function(This, eOpts) { TP.filterWindow(this.up().ftype, This.up().items.getAt(0), This.up().panel); }
    }],

    initComponent: function() {
        this.callParent();
        this.items.getAt(0).value = this.value;
        this.items.getAt(0).name  = this.name;
        this.addListener('afterrender', function() {
            this.items.getAt(0).inputEl.hide();
        });
        if(!this.panel) {
            throw new Error("TP.formFilter(): no panel!");
        }
    }
});

Ext.define('SearchModel', {
    extend: 'Ext.data.Model',
    fields: [
        {name: 'text', type: 'string'},
        {name: 'value',  type: 'string'}
    ]
});
var searchStore = Ext.create('Ext.data.Store', {
    pageSize: 15,
    model: 'SearchModel',
    remoteSort: true,
    remoteFilter: true,
    listeners: {
        beforeload: function(store, operation, eOpts) {
            var now = new Date();
            store.proxy.extraParams = Ext.Object.merge({format: 'search', hash: 1}, store.proxy.addParams);
            store.proxy.extraParams['backends'] = TP.getActiveBackendsPanel(Ext.getCmp(store.panel.panel_id), store.panel);
            if(!searchStore.search_type) { return false; }
            var type = searchStore.search_type.toLowerCase();
            if(type == 'check period' || type == 'notification period') {
                type = 'timeperiod';
            }
            if(type == 'parent') {
                type = 'host';
            }
            if(  type == 'host'
              || type == 'service'
              || type == 'hostgroup'
              || type == 'servicegroup'
              || type == 'timeperiod'
              || type == 'site'
              || type == 'contactgroup'
              || type == 'eventhandler'
              || type == 'custom variable'
              || type == 'custom value'
            ) {
                store.proxy.extraParams['type'] = type;
                if(type == 'custom value') {
                    store.proxy.extraParams['var'] = searchStore.pre_val;
                }
            } else {
                store.removeAll();
                debug("type: "+type+" not supported");
                store.lastParam  = {};
                store.lastLoaded = now;
                return false;
            }
            // refresh every 120 seconds or if type changed
            var param = {
                type: type,
                page: operation.page,
                query: operation.params ? operation.params.query : ''
            };
            if(store.count() > 0 && Object.my_equals(store.lastParam, param) && store.lastLoaded.getTime() > now.getTime() - 120000) {
                return false;
            }
            store.lastParam  = param;
            store.lastLoaded = now;
            return true;
        }
    },
    proxy: {
        type:   'ajax',
        url:    'status.cgi',
        method: 'POST',
        reader: {
            type: 'json',
            root: 'data'
        }
    }
});
Ext.define('TP.formFilterSelect', {
    extend: 'Ext.panel.Panel',

    alias:  'widget.tp_filter_select',

    border: false,
    width:  500,
    layout: {
        type: 'hbox'
    },
    items:      [{
        name:           'type',
        xtype:          'combobox',
        queryMode:      'local',
        editable:       false,
        triggerAction:  'all',
        forceSelection: true,
        autoSelect:     true,
        width:          140,
        store:          getFilterTypeOptions(),
        tpl: '<ul class="' + Ext.plainListCls + '"><tpl for=".">'
            +'<tpl if="field1 == \'----------------\'">'
            +'<li class="x-boundlist-item item-disabled">'
            +'<tpl else>'
            +'<li class="x-boundlist-item" unselectable="on">'
            +'</tpl>'
            +'{field1}'
            +'</li></tpl></ul>',
        listeners: {
            change: function(This, eOpts) {
                This.up().check_changed(This.getValue());
            }
        }
    }, {
        name:           'val_pre',
        xtype:          'combobox',
        width:          100,
        value:          [],
        tooltip:        'Name of the custom variable. e.x: VAR1 (without the underline)',
        emptyText:      'variable name',
        queryMode:      'remote',
        store:          searchStore,
        triggerAction:  'all',
        pageSize:       true,
        selectOnFocus:  true,
        typeAhead:      true,
        minChars:       0,
        listeners: {
            'expand': function(field, eOpts) {
                if(searchStore.search_type != 'custom variable') {
                    searchStore.search_type = 'custom variable';
                    searchStore.panel       = this.up().panel;
                    searchStore.load();
                }
            },
            'change': function(This, newValue, oldValue, eOpts) {
                if(searchStore.search_type != 'custom variable') {
                    searchStore.search_type = 'custom variable';
                    searchStore.panel       = this.up().panel;
                    searchStore.load();
                }
            },
            'keyup': function() {
                if(searchStore.search_type != 'custom variable') {
                    searchStore.search_type = 'custom variable';
                    searchStore.panel       = this.up().panel;
                    searchStore.load();
                }
            }
        }
    }, {
        name:           'op',
        xtype:          'combobox',
        queryMode:      'local',
        editable:       false,
        triggerAction:  'all',
        forceSelection: true,
        autoSelect:     true,
        width:          50,
        store:          ['~','!~','=','!=','<=','>=']
    }, {
        name:           'value',
        xtype:          'combobox',
        flex:           1,
        queryMode:      'remote',
        store:          searchStore,
        triggerAction:  'all',
        pageSize:       true,
        selectOnFocus:  true,
        typeAhead:      true,
        minChars:       0,
        displayField:   'text',
        valueField:     'value',
        listeners: {
            'expand': function(field, eOpts) {
                var search_type = this.up('panel').items.getAt(0).getValue().toLowerCase();
                searchStore.pre_val = this.up('panel').items.getAt(1).getValue();
                if(search_type == "custom variable") { search_type = "custom value"; }
                if(searchStore.search_type != search_type) {
                    searchStore.search_type = search_type;
                    searchStore.panel       = this.up().panel;
                    searchStore.load();
                }
            },
            'change': function(This, newValue, oldValue, eOpts) {
                var search_type = this.up('panel').items.getAt(0).getValue().toLowerCase();
                searchStore.pre_val = this.up('panel').items.getAt(1).getValue();
                if(search_type == "custom variable") { search_type = "custom value"; }
                if(searchStore.search_type != search_type) {
                    searchStore.search_type = search_type;
                    searchStore.panel       = this.up().panel;
                    searchStore.load();
                }
            },
            'keyup': function() {
                var search_type = this.up('panel').items.getAt(0).getValue().toLowerCase();
                searchStore.pre_val = this.up('panel').items.getAt(1).getValue();
                if(search_type == "custom variable") { search_type = "custom value"; }
                if(searchStore.search_type != search_type) {
                    searchStore.search_type = search_type;
                    searchStore.panel       = this.up().panel;
                    searchStore.load();
                }
            },
            'select': function(combo, records, eOpts) {
                /* if something has been selected from the dropdown, change operator to =, because its most likly not regexp */
                var old = this.up('panel').items.getAt(2).getValue();
                if(old == '~') {
                    this.up('panel').items.getAt(2).setValue('=');
                }
                if(old == '!~') {
                    this.up('panel').items.getAt(2).setValue('!=');
                }
            }
        }
    }, {
        xtype:          'datetimefield',
        name:           'value_date'
    }, {
        xtype:          'displayfield',
        value:          '',
        flex:            1
    }, {
        xtype:      'panel',
        border:     false,
        maxWidth:   14,
        flex:       1,
        margin:     '5 0 0 0',
        html:       '<div align="center" class="clickable"><img src="'+url_prefix+'plugins/panorama/images/remove.png" alt="remove filter" style="vertical-align: top"><\/div>',
        listeners:  {
            afterrender: function(This, eOpts) { This.body.on('click', function() {
                var row = This.up('panel');
                var form = This.up('panel').up('form');
                form.remove(row);
            })}
        }
    }],
    /* check datetime or input field */
    check_changed: function(v) {
        if(!this.items.getAt(1).rendered || !this.items.getAt(3).rendered || !this.items.getAt(4).rendered) {
            return;
        }
        if(v.match("-----")) {
            return;
        }
        v = v.toLowerCase();
        if(v == 'last check' || v == 'next check') {
            this.items.getAt(1).hide();
            this.items.getAt(3).hide();
            this.items.getAt(4).show();
            this.items.getAt(5).show();
        } else {
            this.items.getAt(1).hide();
            this.items.getAt(3).show();
            this.items.getAt(4).hide();
            this.items.getAt(5).hide();
        }
        if(v == 'custom variable') {
            this.items.getAt(1).show();
        }
        var op = this.items.getAt(2).getValue();

        var ops = {
            'search':              ['~','!~','=','!='],
            'check period':        ['~','!~','=','!='],
            'comment':             ['~','!~','=','!='],
            'contact':             ['~','!~','=','!='],
            'current attempt':     ['=','!=','<=','>='],
            'custom variable':     ['~','!~','=','!='],
            'dependency':          ['~','!~','=','!='],
            'downtime duration':   ['=','!=','<=','>='],
            'duration':            ['=','!=','<=','>='],
            'event handler':       ['~','!~','=','!='],
            'execution time':      ['=','!=','<=','>='],
            'host':                ['~','!~','=','!='],
            'hostgroup':           ['~','!~','=','!='],
            'last check':          ['=','!=','<=','>='],
            'latency':             ['=','!=','<=','>='],
            'next check':          ['=','!=','<=','>='],
            'notification period': ['~','!~','=','!='],
            'number of services':  ['=','!=','<=','>='],
            'parent':              ['~','!~','=','!='],
            'plugin output':       ['~','!~','=','!='],
            'service':             ['~','!~','=','!='],
            'servicegroup':        ['~','!~','=','!='],
            '% state change':      ['=','!=','<=','>=']
        };

        TP.updateArrayStore(this.items.getAt(2).store, ops[v], op);
        this.items.getAt(2).setValue(op);
        if(this.items.getAt(2).getValue() == null) {
            this.items.getAt(2).setRawValue(ops[v][0]);
        }
    },

    initComponent: function() {
        this.callParent();
        this.items.getAt(0).setValue(this.val_type  || 'Search');
        this.items.getAt(1).setValue(this.val_pre   || '');
        this.items.getAt(2).setValue(this.val_op    || '~');
        this.items.getAt(3).setValue(this.val_value || '');
        if(this.val_val_d) {
            var d = Date.parse(this.val_val_d);
            this.items.getAt(4).setValue(new Date(d));
        } else {
            this.items.getAt(4).setValue(new Date());
        }

        this.addListener('afterrender', function(This, eOpts) {
            // has to be hidden after renderer, otherwise show does not work
            This.check_changed(This.items.getAt(0).getValue());
        });
        if(!this.panel) {
            throw new Error("TP.formFilterSelect(): no panel!");
        }
    }
});

Ext.define('TP.formFilterPanel', {
    extend: 'Ext.form.Panel',

    initComponent: function() {
        this.callParent();
        if(!this.panel) {
            throw new Error("TP.formFilterPanel(): no panel!");
        }
    },

    submitEmptyText: false,
    bodyPadding:     3,
    padding:        '0 0 15 0', // leave some space for scrollbars
    bodyStyle:      'border-width: 0 1px 0 0;',
    defaults: {
        labelWidth: 135,
        style: 'margin-top: 5px'
    },
    items: [{
            xtype:      'panel',
            border:     false,
            width:      '100%',
            height:     6,
            style:      'margin-top: 0px',
            html:       '<div align="right" class="clickable"><img src="'+url_prefix+'plugins/panorama/images/remove.png" alt="remove filter" style="vertical-align: top"><\/div>',
            listeners:  {
                afterrender: function(This, eOpts) { This.body.on('click', function() {
                    var win = This.up('form').up('window');
                    win.remove(This.up('panel'));
                    if(win.items.length == 2) { win.setWidth(600); }
                    win.center();
                })}
            }
        }, {
            fieldLabel: 'Host Status Types',
            name:       'hoststatustypes',
            xtype:      'tp_combobox_sum',
            width:      485,
            value:      [1,2,4,8],
            sum_values: {'15': 'All', '12': 'All Problems' },
            store:      [[2,'Up'], [4,'Down'], [8,'Unreachable'], [1,'Pending']]
        }, {
            fieldLabel: 'Host Properties',
            name:       'hostprops',
            xtype:      'tp_combobox_sum',
            width:      485,
            columns:    true,
            value:      [],
            sum_values: {'0': 'Any' },
            store:      [[1,'In Scheduled Downtime'], [2,'Not In Scheduled Downtime'],
                         [4,'Has Been Acknowledged'], [8,'Has Not Been Acknowledged'],
                         [16,'Checks Disabled'], [32,'Checks Enabled'],
                         [64,'Event Handler Disabled'], [128,'Event Handler Enabled'],
                         [256,'Flap Detection Disabled'], [512,'Flap Detection Enabled'],
                         [1024,'Is Flapping'], [2048,'Is Not Flapping'],
                         [4096,'Notifications Disabled'], [8192,'Notifications Enabled'],
                         [16384,'Passive Checks Disabled'], [32768,'Passive Checks Enabled'],
                         [65536,'Passive Checks'], [131072,'Active Checks'],
                         [262144,'In Hard State'], [524288,'In Soft State'],
                         [1048576,'In Check Period'], [2097152,'Outside Check Period'],
                         [4194304,'In Notification Period'], [8388608,'Outside Notification Period'],
                         [16777216,'Has Modified Attributes'], [33554432,'No Modified Attributes']]
        }, {
            fieldLabel: 'Service Status Types',
            name:       'servicestatustypes',
            xtype:      'tp_combobox_sum',
            width:      485,
            value:      [1,2,4,8,16],
            sum_values: {'31': 'All', '28': 'All Problems' },
            store:      [[2,'Ok'],[4,'Warning'],[8,'Unknown'],[16,'Critical'],[1,'Pending']]
        }, {
            fieldLabel: 'Service Properties',
            name:       'serviceprops',
            xtype:      'tp_combobox_sum',
            width:      485,
            columns:    true,
            value:      [],
            sum_values: {'0': 'Any' },
            store:      [[1,'In Scheduled Downtime'], [2,'Not In Scheduled Downtime'],
                         [4,'Has Been Acknowledged'], [8,'Has Not Been Acknowledged'],
                         [16,'Active Checks Disabled'], [32,'Active Checks Enabled'],
                         [64,'Event Handler Disabled'], [128,'Event Handler Enabled'],
                         [512,'Flap Detection Disabled'], [256,'Flap Detection Enabled'],
                         [1024,'Is Flapping'], [2048,'Is Not Flapping'],
                         [4096,'Notifications Disabled'], [8192,'Notifications Enabled'],
                         [16384,'Passive Checks Disabled'], [32768,'Passive Checks Enabled'],
                         [65536,'Passive Checks'], [131072,'Active Checks'],
                         [262144,'In Hard State'], [524288,'In Soft State'],
                         [1048576,'In Check Period'], [2097152,'Outside Check Period'],
                         [4194304,'In Notification Period'], [8388608,'Outside Notification Period'],
                         [16777216,'Has Modified Attributes'], [33554432,'No Modified Attributes']]
        }, {
            xtype:      'panel',
            border:     false,
            html:       '<div align="center"><div class="clickable" style="width: 40px;"><img src="'+url_prefix+'plugins/panorama/images/down.png" alt="add new and filter" style="vertical-align: middle"> and<\/div><\/div>',
            listeners:  {
                afterrender: function(This, eOpts) { Ext.get(This.body.dom.firstChild.firstChild).on('click', function() {
                    var form = This.up('form');
                    form.insert(form.items.length-1, {xtype: 'tp_filter_select', panel: This.up('panel').panel});
                })}
            }
    }]
});

TP.filterWindow = function(ftype, base_el, panel) {
    if(!panel) {
        throw new Error("TP.formFilterSelect(): no panel!");
    }
    var win = new Ext.window.Window({
        title:      'Filter',
        layout:     'hbox',
        maximizable: true,
        width:       600,
        minHeight:   200,
        autoScroll:  true,
        modal:       true,
        items:       [],
        buttonAlign: 'center',
        bodyStyle:   'background: white;',
        fbar: [{ xtype:  'button', text: 'cancel', handler: function() { this.up('window').destroy() } },
               { xtype:  'button',
                 text:    'save',
                 handler: function(This) {
                    var filter = [];
                    win.items.each(function(item, idx, length) {
                        if(item.getForm) {
                            var form                = item.getForm();
                            var vals                = form.getFieldValues();
                            vals.hostprops          = TP.arraySum(vals.hostprops);
                            vals.serviceprops       = TP.arraySum(vals.serviceprops);
                            vals.hoststatustypes    = TP.arraySum(vals.hoststatustypes);
                            vals.servicestatustypes = TP.arraySum(vals.servicestatustypes);
                            filter.push(vals);
                        }
                    });
                    base_el.setValue(Ext.JSON.encode(filter));
                    this.up('window').destroy();
                 }
               }
        ],
        listeners: {
            afterrender: function(This, eOpts) {
                /* autoScroll overwrites this otherwise */
                this.body.dom.style.overflowY = 'hidden';
            }
        },
        checkServiceFormVisibility: function() {
            if(ftype == 'host') {
                win.items.each(function(item, idx, length) {
                    if(item.getForm) {
                        var fields = item.getForm().getFields();
                        fields.getAt(2).hide();
                        fields.getAt(3).hide();
                    }
                });
            }
        }
    });

    /* add values */
    var val = base_el.getValue();
    if(val) {
        val = Ext.JSON.decode(val);
        if(!Ext.isArray(val)) {
            /* convert old searches */
            val = [val];
        }
        Ext.Array.each(val, function(f, i) {
            var form = Ext.create("TP.formFilterPanel", {panel: panel});
            var values = {
                hoststatustypes:    TP.dec2bin(f.hoststatustypes),
                hostprops:          TP.dec2bin(f.hostprops),
                servicestatustypes: TP.dec2bin(f.servicestatustypes),
                serviceprops:       TP.dec2bin(f.serviceprops)
            };
            if(Ext.isArray(f.type)) {
                for(var nr=0; nr<f.type.length; nr++) {
                    form.insert(form.items.length-1, {
                        xtype:     'tp_filter_select',
                        panel:      panel,
                        val_op:     f.op[nr],
                        val_type:   f.type[nr],
                        val_pre:    f.val_pre[nr],
                        val_value:  f.value[nr],
                        val_val_d:  f.value_date[nr]
                    });
                }
            } else {
                form.insert(form.items.length-1, {
                    xtype:     'tp_filter_select',
                    panel:      panel,
                    val_op:     f.op,
                    val_type:   f.type,
                    val_pre:    f.val_pre,
                    val_value:  f.value,
                    val_val_d:  f.value_date
                });
            }
            form.getForm().setValues(values);
            win.add(form);
        });
    } else {
        /* add one empty filter */
        var form = Ext.create("TP.formFilterPanel", {panel: panel});
        form.insert(form.items.length-1, {xtype: 'tp_filter_select', panel: panel});
        win.add(form);
    }

    /* hide service specific fields for hosts */
    win.checkServiceFormVisibility();

    /* add or button */
    win.add({
        xtype:      'panel',
        border:     false,
        html:       '<div align="center" class="clickable" style="width: 25px; margin-top: 60px;"><img src="'+url_prefix+'plugins/panorama/images/right.png" alt="add new or filter" style="vertical-align: middle"><br>or<\/div>',
        listeners:  {
            afterrender: function(This, eOpts) {
                Ext.get(This.body.dom.firstChild).on('click', function() {
                    var newform = Ext.create("TP.formFilterPanel", {panel: panel});
                    newform.insert(newform.items.length-1, {xtype: 'tp_filter_select', panel: panel});
                    win.insert(win.items.length-1, newform);

                    win.checkServiceFormVisibility();

                    // scroll right to view the new filter
                    win.body.dom.scrollLeft=10000000000;

                    // adjust size if possible
                    if(win.items.length  > 2) { win.setWidth(1070); }
                    if(win.items.length == 2) { win.setWidth(600);  }
                    win.center();

                    // highlight the new filter
                    var newid = win.items.getAt(win.items.length-2).body.id;
                    Ext.get(newid).highlight();
                });
            }
        }
    });

    // at least two filter fit on the screen
    if(win.items.length > 2) {
        win.setWidth(1070);
        win.center();
    }

    /* show the window */
    win.show();
}
