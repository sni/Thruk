Ext.define('TP.BackendCombo', {
    extend: 'Ext.form.field.ComboBox',

    alias:  'widget.tp_backendcombo',

    fieldLabel: 'Backends / Sites',
    emptyText : 'inherited from dashboard',
    name:       'backends',
    multiSelect: true,
    queryMode:  'local',
    valueField: 'name',
    displayField: 'value',
    editable:   false,
    triggerAction: 'all',
    store:      { fields: ['name', 'value'], data: [] },
    listConfig : {
        getInnerTpl: function(displayField) {
            return '<div class="x-combo-list-item"><img src="' + Ext.BLANK_IMAGE_URL + '" class="chkCombo-default-icon chkCombo" /> {'+displayField+'} <\/div>';
        }
    }
});


Ext.define('TP.ComboBoxSum', {
    extend: 'Ext.form.field.ComboBox',

    alias:  'widget.tp_combobox_sum',

    multiSelect:    true,
    queryMode:      'local',
    editable:       false,
    triggerAction:  'all',
    listConfig : {
        getInnerTpl: function(displayField) {
            return '<div class="x-combo-list-item"><img src="' + Ext.BLANK_IMAGE_URL + '" class="chkCombo-default-icon chkCombo" /> {'+displayField+'} <\/div>';
        }
    },
    listeners: {
        'afterrender': function(This, eOpts) {
            if(!This.columns) { return };
            This.getPicker().addListener('beforerender', function(This, eOpts) {
                This.minWidth = 380;
            });
            This.getPicker().addListener('show', function(This, eOpts) {
                var lis = Ext.DomQuery.select('li', This.getEl().dom);
                for(var nr=0; nr<lis.length; nr++) {
                    var el = Ext.get(lis[nr]);
                    if(nr%2==0) {
                        el.addCls('picker_even');
                    } else {
                        el.addCls('picker_odd');
                    }
                }
            });
        }
    },

    initComponent: function() {
        /* make it possible to set some special display values through
         * sum_values: { '0': 'All' }
         */
        this._getDisplayValue = this.getDisplayValue;
        this.getDisplayValue = function() {
            if(this.sum_values == undefined) {
                return this._getDisplayValue();
            }
            var sum = 0;
            for(var nr=0; nr<this.displayTplData.length; nr++) {
                sum += this.displayTplData[nr].field1;
            }
            if(this.sum_values[''+sum] != undefined) {
                return this.sum_values[''+sum];
            }
            return this._getDisplayValue();
        };
        this.callParent();
    }
});

// http://www.sencha.com/forum/showthread.php?22661-new-version-DateTime-Field/page83
Ext.define('Ext.ux.form.field.DateTime', {
    extend:'Ext.form.FieldContainer',
    mixins: {
        field: 'Ext.form.field.Field'
    },
    alias: 'widget.datetimefield',
    layout: 'fit',
    timePosition:'right', // valid values:'below', 'right'
    dateCfg:{},
    timeCfg:{},
    allowBlank: true,

    initComponent: function() {
        var me = this;
        me.buildField();
        me.callParent();
        this.dateField = this.down('datefield');
        this.timeField = this.down('timefield');
        me.initField();
    },

    buildField: function() {
        var l;
        var d = {};
        if (this.timePosition == 'below') {
            l = {type: 'anchor'};
            d = {anchor: '100%'};
        } else
            l = {type: 'hbox', align: 'middle'};
        this.items = {
            xtype: 'container',
            layout: l,
            defaults: d,
            items: [Ext.apply({
                xtype:      'datefield',
                format:     'Y-m-d',
                width:       this.timePosition != 'below' ? 100 : undefined,
                allowBlank:  this.allowBlank,
                listeners: {
                    specialkey: this.onSpecialKey,
                    scope: this
                },
                isFormField: false // prevent submission
            }, this.dateCfg), Ext.apply({
                xtype:        'timefield',
                format:       'H:i',
                submitFormat: 'H:i:s',
                margin:        this.timePosition != 'below' ? '0 0 0 3' : 0,
                width:         this.timePosition != 'below' ? 80 : undefined,
                allowBlank:    this.allowBlank,
                listeners: {
                    specialkey: this.onSpecialKey,
                    scope: this
                },
                isFormField: false // prevent submission
            }, this.timeCfg)]
        };
    },

    focus: function() {
        this.callParent();
        this.dateField.focus(false, 100);
    },

    // Handle tab events
    onSpecialKey:function(cmp, evt) {
        var key = evt.getKey();
        if (key === evt.TAB) {
            if (cmp == this.dateField) {
                // fire event in container if we are getting out of focus from datefield
                if (evt.shiftKey) {
                    this.fireEvent('specialkey', this, evt);
                }
            }
            if (cmp == this.timeField) {
                if (!evt.shiftKey) {
                    this.fireEvent('specialkey', this, evt);
                }
            }
        } else if (this.inEditor) {
            this.fireEvent('specialkey', this, evt);
        }
    },

    getValue: function() {
        var value, date = this.dateField.getSubmitValue(), time = this.timeField.getSubmitValue();
        if (date) {
            if (time) {
                var format = this.getFormat();
                value = Ext.Date.parse(date + ' ' + time, format);
            } else {
                value = this.dateField.getValue();
            }
        }
        return value
    },

    setValue: function(value) {
        this.dateField.setValue(value);
        this.timeField.setValue(value);
    },

    getSubmitData: function() {
        var value = this.getValue();
        var format = this.getFormat();
        var v = {};
        v[this.name] = value ? Ext.Date.format(value, format) : null;
        return v;
    },

    getFormat: function() {
        return (this.dateField.submitFormat || this.dateField.format) + " " + (this.timeField.submitFormat || this.timeField.format)
    },

    getErrors: function() {
        return this.dateField.getErrors().concat(this.timeField.getErrors());
    },

    validate: function() {
        if (this.disabled)
            return true;
        else {
            var isDateValid = this.dateField.validate();
            var isTimeValid = this.timeField.validate();
            return isDateValid && isTimeValid;
        }
    },

    reset: function() {
        this.mixins.field.reset();
        this.dateField.reset();
        this.timeField.reset();
    }
});


Ext.define('TP.PagingToolbar', {
    extend:'Ext.toolbar.Paging',

    dock:       'bottom',
    displayInfo: true,
    getPageData: function() {
        var data   = {
            total:          parseInt(this.panel.xdata.totalCount),
            currentPage:    parseInt(this.panel.xdata.currentPage),
            pageCount:      Math.ceil(this.panel.xdata.totalCount / this.panel.xdata.pageSize),
            fromRecord:     ((this.panel.xdata.currentPage - 1) * this.panel.xdata.pageSize),
            toRecord:       Math.min(this.panel.xdata.currentPage * this.panel.xdata.pageSize, this.panel.xdata.totalCount)
        };
        return(data);
    },
    updateInfo : function(){
        var me = this,
            displayItem = me.child('#displayItem'),
            pageData = me.getPageData(),
            count, msg;
        if (displayItem) {
            msg = Ext.String.format(
                me.displayMsg,
                (pageData.fromRecord+1),
                pageData.toRecord,
                pageData.total
            );
            displayItem.setText(msg);
            me.doComponentLayout();
        }
    },
    onLoad : function(){
        var me = this,
            pageData,
            currPage,
            pageCount,
            afterText;

        if (!me.rendered) {
            return;
        }

        pageData  = me.getPageData();
        currPage  = pageData.currentPage;
        pageCount = pageData.pageCount;
        afterText = Ext.String.format(me.afterPageText, isNaN(pageCount) ? 1 : pageCount);
        me.child('#afterTextItem').setText(afterText);
        me.child('#inputItem').setValue(currPage);
        me.child('#first').setDisabled(currPage === 1);
        me.child('#prev').setDisabled(currPage === 1);
        me.child('#next').setDisabled(currPage === pageCount);
        me.child('#last').setDisabled(currPage === pageCount);
        me.child('#refresh').enable();
        me.updateInfo();
        me.fireEvent('change', me, pageData);
    },
    updateData: function(data) {
        this.panel.xdata.totalCount  = parseInt(data.totalCount);
        this.panel.xdata.currentPage = parseInt(data.currentPage);
    },
    moveNext: function() {
        this.panel.xdata.currentPage++;
        this.panel.refreshHandler();
    },
    moveLast: function() {
        var pageData = this.getPageData();
        this.panel.xdata.currentPage = pageData.pageCount;
        this.panel.refreshHandler();
    },
    moveFirst: function() {
        this.panel.xdata.currentPage = 1;
        this.panel.refreshHandler();
    },
    movePrevious: function() {
        this.panel.xdata.currentPage--;
        this.panel.refreshHandler();
    }
});


TP.Msg = function() {
    var msgCt;

    function createBox(cls, title, s){
        return '<div class="msg x-tab-default '+cls+'"><a class="x-tab-close-btn" title="" href="#"><\/a><h3>' + title + '<\/h3><p>' + s + '<\/p><\/div>';
    }
    return {
        msg : function(s, close_timeout, container, title, onCloseCB) {
            if(TP.unloading) { return; }
            if(!msgCt){
                msgCt = Ext.DomHelper.insertFirst(document.body, {id:'msg-div', 'class': "popup-msg"}, true);
            }
            // show demo mode errors as warnings and only once
            if(s.match(/disabled in demo mode/)) {
                s = s.replace(/^fail_message/, 'info_message');
                if(TP.demo_warnings_shown == undefined) { TP.demo_warnings_shown = 0;}
                TP.demo_warnings_shown++;
                if(TP.demo_warnings_shown > 1) {
                    return;
                }
            }
            var p = s.split('~~', 2);
            if(title == undefined) {
                title = 'Success';
                if(p[0] == 'fail_message') {
                    title = 'Error';
                }
                if(p[0] == 'info_message') {
                    title = 'Information';
                }
            }
            TP.log('msg: '+title+' - '+p[1]);
            var m = Ext.DomHelper.append((container || msgCt), createBox(p[0], title, p[1]), true);
            var btn = new Ext.Element(m.dom.firstChild);
            btn.on("click", function() {
                if(onCloseCB) { onCloseCB(); }
                m.ghost("t", { remove: true});
            });
            m.show();
            m.hide();
            m.slideIn('t');
            if(p[0] == 'fail_message' || p[0] == 'info_message') {
                debug(title + ': ' + p[1]);
                var err = new Error;
                TP.logError("global", "fail_message", err);
                delay = 30000;
            } else {
                delay = 5000;
            }
            if(close_timeout != undefined) {
                if(close_timeout == 0) {
                    return(m);
                }
                delay = close_timeout * 1000;
            }
            TP.timeouts['timeout_global_msg_ghost'] = window.setTimeout( function() { if(m && m.dom) { m.ghost("t", { remove: true}) }}, delay );
            return(m);
        }
    };
}();


Ext.define('TP.SoundField', {
    extend:'Ext.form.FieldContainer',

    alias:  'widget.tp_soundfield',

    layout:    { type: 'hbox', align: 'stretch', defaultMargins: {top: 0, right: 0, bottom: 0, left: 5} },
    items:    [{
        xtype:        'combobox',
        queryMode:    'local',
        displayField: 'name',
        valueField:   'path',
        flex:          1,
        typeAhead:     true,
        name:         'sound'
    }, {
        xtype:        'label',
        text:         'repeat:',
        cls:          'x-form-item-label'
    }, {
        xtype:        'numberfield',
        value:        0,
        maxValue:     9999,
        minValue:     0,
        width:        65,
        allowDecimals: false,
        valueToRaw:   function(value) { if(value == 0) { return('forever') }; return(String(value)); },
        rawToValue:   function(value) { if(value == 'forever') { return(Number(0)) }; return(Number(value)); },
        getErrors:    function(value) { if(value != 'forever' && !Ext.isNumeric(value)) { return([value + " is not a valid number"]); } return([]); },
        name:         'repeat'
    }, {
        xtype:       'button',
        text:        'Test',
        icon:        url_prefix+'plugins/panorama/images/sound.png',
        handler:      function(btn, evt) {
            var wav = btn.up().items.getAt(0).getValue();
            if(wav != "") {
                btn.disable();
                TP.playWave(wav, function() { btn.enable() });
            }
        }
    }],
    initComponent: function() {
        this.callParent();
        this.items.getAt(0).name  = this.nameV;
        this.items.getAt(0).store = this.store;
        if(this.nameR == undefined) {
            this.items.getAt(1).style = 'visibility: hidden;';
            this.items.getAt(2).style = 'visibility: hidden;';
            this.items.getAt(2).name = '';
        } else {
            this.items.getAt(2).name = this.nameR;
        }
    }
});

Ext.define('Ext.ux.ColorPickerCombo', {
    extend:     'Ext.form.field.Trigger',
    alias:      'widget.colorcbo',
    triggerTip: 'Please select a color.',
    onTriggerClick: function() {
        var me = this;
        if(me.picker) {
            me.picker.destroy();
            me.picker = undefined;
            return;
        }
        me.picker = Ext.create('Ext.picker.Color', {
            pickerField: this,
            ownerCt:     this,
            renderTo:    document.body,
            floating:    true,
            focusOnShow: true,
            style:     { backgroundColor: "#fff" } ,
            initComponent: function() {
                if(this.pickerField.colors) { this.colors = this.pickerField.colors; }
                if(this.pickerField.colorGradient) {
                    var start = Ext.draw.Color.fromString(this.pickerField.colorGradient.start);
                    var stop  = Ext.draw.Color.fromString(this.pickerField.colorGradient.stop);
                    if(!start || !stop) { return; }
                    this.colors = [];
                    start = start.getLighter(0.20);
                    stop  = stop.getLighter(0.20);
                    for(var x=0; x<5; x++) {
                        this.colors.push(start.toString().replace(/^\#/, '').toUpperCase());
                        var rgbStart = start.getRGB();
                        var rgbStop  = stop.getRGB();
                        var r = (rgbStart[0] - rgbStop[0]) / 7,
                            g = (rgbStart[1] - rgbStop[1]) / 7,
                            b = (rgbStart[2] - rgbStop[2]) / 7;
                        for(var y=0; y<7; y++) {
                            var color = 'rgb('+Math.floor(rgbStart[0] - r*y)+','+Math.floor(rgbStart[1] - g*y)+','+Math.floor(rgbStart[2] - b*y)+')';
                            this.colors.push(Ext.draw.Color.fromString(color).toString().replace(/^\#/, '').toUpperCase());
                        }
                        start = start.getDarker(0.10);
                        stop  = stop.getDarker(0.10);
                    }
                }
                // add two rows of additional colors
                var additionalColors = TP.getAllUsedColors();
                for(var x=0; x<15; x++) {
                    if(additionalColors[x]) {
                        this.colors.push(additionalColors[x].replace('#'));
                    } else {
                        this.colors.push("DDDDDD");
                    }
                }
                this.height = 127;
                this.maxHeight = 127;
                // add transparent
                this.colors.push("000001"); // must be 6 chars long, otherwise color picker chokes
                this.callParent();
            },
            listeners: {
                scope:this,
                select: function(field, value, opts){
                    if(value == "000001") {
                        me.setValue("transparent");
                    } else {
                        me.setValue('#' + value);
                    }
                    me.inputEl.setStyle({backgroundColor:value});
                    me.picker.destroy();
                    me.picker = undefined;
                },
                afterrender: function(field,opts){
                    field.getEl().monitorMouseLeave(2500, field.hide, field);
                    Ext.Array.each(field.el.dom.getElementsByTagName('A'), function(item, index) {
                        item.color = Ext.draw.Color.fromString(item.firstChild.style.backgroundColor).toString();
                        if(item.color == "#000001") {
                            item.color = "transparent";
                        }
                        item.onmouseover=function() { if(me.mouseover) { me.mouseover(item.color); }},
                        item.onmouseout=function()  { if(me.mouseout)  { me.mouseout(); } }
                        // replace transparent background color
                        if(item.color == "transparent") {
                            item.firstChild.style.background = "url("+url_prefix+"plugins/panorama/images/transparent_picker.png)";
                        }
                    });
                }
            }
        });
        me.picker.alignTo(me.inputEl, 'tl-bl?');
        me.picker.show(me.inputEl);
    }
});

Ext.define('Ext.ux.FontPickerCombo', {
    extend:     'Ext.form.field.ComboBox',
    alias:      'widget.fontcbo',
    triggerTip: 'Please select a font.',
    queryMode:  'local',
    store:       available_fonts,
    listConfig : {
        getInnerTpl: function(displayField) {
            return '<div class="x-combo-list-item" style="font-family:{'+displayField+'}">{'+displayField+'}<\/div>';
        }
    }
});

Ext.define('Ext.ux.NumberFieldUnit', {
    extend:        'Ext.form.field.Number',
    alias:         'widget.numberunit',
    value:          0,
    valueToRaw:     function(value) { return(TP.extract_number_with_unit({ value: value, unit: this.unit, defaultValue: 0 })+' '+this.unit); },
    rawToValue:     function(value) { return(TP.extract_number_with_unit({ value: value, unit: this.unit, defaultValue: 0 })); },
    getErrors:      function(value) { if(!Ext.isNumeric(String(value).replace(' '+this.unit, ''))) { return([value + " is not a valid number"]); } return([]); },
    getSubmitValue: function()      { var value = Number(this.rawToValue(this.callParent())); return(value); }
});

Ext.define('Ext.ux.SearchModel', {
    extend: 'Ext.data.Model',
    fields: [
        {name: 'text', type: 'string'},
        {name: 'value',  type: 'string'}
    ]
});

Ext.define('Ext.ux.SearchStore', {
    extend: 'Ext.data.Store',

    pageSize: 15,
    model: 'Ext.ux.SearchModel',
    remoteSort: true,
    remoteFilter: true,
    listeners: {
        beforeload: function(store, operation, eOpts) {
            var now = new Date();
            store.proxy.extraParams = Ext.Object.merge({format: 'search', hash: 1}, store.proxy.addParams);
            store.proxy.extraParams['backends'] = TP.getActiveBackendsPanel(store.panel.tab, store.panel);
            if(!store.search_type) { return false; }
            var type = store.search_type.toLowerCase();
            if(type == 'check period' || type == 'notification period') {
                type = 'timeperiod';
            }
            if(type == 'parent') {
                type = 'host';
            }
            if(type == 'action menu') {
                type = 'custom value';
                store.pre_val = "THRUK_ACTION_MENU";
            }
            if(  type == 'host'
              || type == 'service'
              || type == 'hostgroup'
              || type == 'servicegroup'
              || type == 'timeperiod'
              || type == 'site'
              || type == 'contactgroup'
              || type == 'eventhandler'
              || type == 'command'
              || type == 'custom variable'
              || type == 'custom value'
            ) {
                store.proxy.extraParams['type'] = type;
                delete store.proxy.extraParams['var'];
                if(type == 'custom value') {
                    store.proxy.extraParams['var'] = store.pre_val;
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
                type:    type,
                page:    operation.page,
                query:   operation.params ? operation.params.query : '',
                pre_val: store.pre_val
            };
            if(store.count() > 0 && Object.my_equals(store.lastParam, param) && store.lastLoaded.getTime() > now.getTime() - 120000) {
                return false;
            }
            store.lastParam  = param;
            store.lastLoaded = now;
            return true;
        },
        load: function(store, operation, eOpts) {
            if(store.curCombo) {
                store.curCombo.expand();
            }
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

Ext.define('Ext.ux.SearchCombobox', {
    extend:        'Ext.form.field.ComboBox',
    alias:         'widget.searchCbo',

    triggerAction:  'all',
    selectOnFocus:  true,
    selectOnTab:    true,
    typeAhead:      true,
    minChars:       0,
    pageSize:       15,
    initComponent: function() {
        var me = this;
        me.valueField   = 'value';
        me.displayField = 'text';
        me.queryMode    = 'remote';
        me.store        = Ext.create('Ext.ux.SearchStore');
        me.callParent();

        var setStoreParams = function() {
            me.store.curCombo = me;
            me.store.panel    = me.panel || me.up().panel || me.up('panel');
            var type          = me.search_type || me.name;
            var doReload      = false;
            if(type == "value") {
                // get type from type selector
                var index = me.up().items.findIndex("name", "type");
                if(index >= 0) {
                    var typeInput = me.up().items.getAt(index);
                    type = typeInput.getValue().toLowerCase()
                }
                if(type == "custom variable") { type = "custom value"; }

                index = me.up().items.findIndex("name", "val_pre");
                if(index >= 0) {
                    var pre_val = me.up().items.getAt(index).getValue();
                    if(me.store.pre_val != pre_val) {
                        me.store.pre_val = pre_val;
                        doReload = true;
                    }
                }
            }
            var proxy         = me.store.getProxy();
            proxy.addParams   = Ext.Object.merge({}, me.storeExtraParams);
            if(me.storeExtraParams) {
                proxy.addParams = Ext.Object.merge({}, me.storeExtraParams);
            }
            if(type == 'service') {
                proxy.addParams.host = this.up('form').getForm().getFieldValues().host;
                if(me.store.lastHost != proxy.addParams.host) {
                    me.store.lastHost = proxy.addParams.host;
                }
            }
            if(me.store.search_type != type) {
                me.store.search_type = type;
                doReload = true;
            }
            if(doReload) {
                me.store.load();
            }
        };
        me.addListener('focus', setStoreParams);
        me.addListener('expand', setStoreParams);

        // try to find a matching record for this value
        // if picker gets closed by clicking somewhere in the page, the current value simply
        // will be set and not expanded.
        me.addListener('collapse',  function() {
            var val = me.getValue();
            var num = me.store.find("text", val);
            if(num != -1) {
                val = me.store.getAt(num).get("value");
            }
            me.setRawValue(val);
        });

        me.addListener('select',  function(combo, records, eOpts) {
            // if something has been selected from the dropdown, change operator to =, because its most likly not regexp
            var type = me.search_type || me.name;
            if(type != "value") { return; }
            var index = me.up().items.findIndex("name", "op");
            if(index >= 0) {
                var opField = me.up().items.getAt(index);
                var old = opField.getValue();
                if(old == '~') {
                    opField.setValue('=');
                }
                if(old == '!~') {
                    opField.setValue('!=');
                }
            }
        });
    }
});

Ext.define('TP.speedochart', {
    extend: 'Ext.chart.Chart',

    alias:  'widget.tp_speedochart',

    legend:  false,
    initComponent: function() {
        var me = this;
        this.series = [{
            type:        'kpigauge',
            field:       'value',
            showInLegend: true,
            ranges:       []
        }];
        this.series[0].donut  = this.donut  ? this.donut : false;
        this.series[0].needle = !!this.needle;
        this.axes[0].margin   = this.axis_margin != undefined ? this.axis_margin : -10;
        this.axes[0].steps    = this.axis_steps  != undefined ? this.axis_steps  :  10;
        this.axes[0].minimum  = this.axis_min    != undefined ? this.axis_min    :   0;
        this.axes[0].maximum  = this.axis_max    != undefined ? this.axis_max    : 100;
        this.axes[0].label    = {
            renderer: function(v) {
                var axe = me.axes.getAt(0);
                if(axe.i == undefined) {
                    axe.i = 0;
                }
                var round = 0;
                var range = axe.maximum - axe.minimum;
                if(axe.steps > 0) {
                    var singleStep = range / axe.steps;
                    if(singleStep < 1)    { round = 1; }
                    if(singleStep < 0.1)  { round = 2; }
                    if(singleStep < 0.01) { round = 3; }
                }
                if(round > 0) {
                    v = Ext.util.Format.round((axe.i / axe.steps * range)+axe.minimum, round);
                    axe.i++;
                    if(axe.i > axe.steps) { axe.i = 0; }
                    return(v);
                }
                return(v);
            }
        };
        this.callParent();
    },
    axes: [{
        type:     'gauge',
        position: 'gauge',
        minimum:   0,
        maximum: 100,
        steps:    10,
        margin:   10
    }],
    series: []
});

Ext.define('TP.dragEl', {
    extend: 'Ext.Component',

    alias:  'widget.tp_drager',

    'html':     ' ',
    draggable:  true,
    autoRender: true,
    autoShow:   true,
    shadow:     false,
    floating:   true,
    width:      24,
    height:     24,
    cls:       "clickable",
    x:          0,
    y:          0,
    listeners: {
        afterrender: function(This, eOpts) {
            if(!This.panel.locked) {
                This.el.on('mouseover', function(evt,t,a) {
                    if(!This.el.dom.style.outline.match("orange")) {
                        This.el.dom.style.outline = "1px dashed grey";
                    }
                });
                This.el.on('mouseout', function(evt,t,a) {
                    if(This.el.dom.style.outline.match("grey")) {
                        This.el.dom.style.outline = "";
                    }
                });
            }
            This.addDDListener();
        },
        boxready: function(This, width, height, eOpts) {
            This.addDDListener();
        },
        show: function( This, eOpts ) {
            This.addDDListener();
        },
        move: function(This, x, y, eOpts) {
            if(This.noMoreMoves) { return; }
            if(x == undefined) { x = This.xdata.appearance[This.keyX]; }
            if(y == undefined) { y = This.xdata.appearance[This.keyY]; }

            /* breaks connectors: items are moved to 0/0 when unlocking in single window mode */
            if(x == 0 && y == 0) { return; }

            /* snap to roaster when shift key is hold */
            if(TP.isShift) {
                var pos = TP.get_snap(x, y);
                if(This.ddShadow) {
                    This.ddShadow.dom.style.display = '';
                    This.ddShadow.dom.style.left    = pos[0]+"px";
                    This.ddShadow.dom.style.top     = pos[1]+"px";
                }
                x=pos[0];
                y=pos[1];
            } else {
                if(This.ddShadow) {
                    This.ddShadow.dom.style.display = 'none';
                }
            }

            TP.reduceDelayEvents(This, function() {
                var origX = This.xdata.appearance[This.keyX];
                var origY = This.xdata.appearance[This.keyY];
                This.xdata.appearance[This.keyX] = x-This.offsetX;
                This.xdata.appearance[This.keyY] = y-This.offsetY;
                This.panel.updateMapLonLat(undefined, This.keyX);
                if(TP.iconSettingsWindow) {
                    var values = {};
                    values[This.keyX] = This.xdata.appearance[This.keyX];
                    values[This.keyY] = This.xdata.appearance[This.keyY];
                    Ext.getCmp('appearanceForm').getForm().setValues(values);
                } else {
                    /* move aligned items too */
                    var deltaX = This.xdata.appearance[This.keyX] - origX;
                    var deltaY = This.xdata.appearance[This.keyY] - origY;
                    TP.moveAlignedIcons(deltaX, deltaY, This.id);
                }
                This.panel.updateRender(This.xdata);
            }, 100, 'timeout_panel_move_delay');
        }
    },
    moveDragEl: function(deltaX, deltaY) {
        var This = this;
        This.xdata.appearance[This.keyX] = Number(This.xdata.appearance[This.keyX]);
        This.xdata.appearance[This.keyY] = Number(This.xdata.appearance[This.keyY]);
        This.xdata.appearance[This.keyX] += deltaX;
        This.xdata.appearance[This.keyY] += deltaY;
        This.setPosition(This.xdata.appearance[This.keyX]+This.offsetX, This.xdata.appearance[This.keyY]+This.offsetY);
    },
    resetDragEl: function() {
        var This = this;
        This.suspendEvents();
        This.setPosition(This.xdata.appearance[This.keyX]+This.offsetX, This.xdata.appearance[This.keyY]+This.offsetY);
        This.resumeEvents();
    },
    addDDListener: function(retries) {
        var panel = this;
        if(retries == undefined) { retries = 0; }
        if(panel.ddAdded) {return;}
        if(!panel.el || !panel.dd) {
            if(retries == 1) { panel.initDraggable(); }
            if(retries > 10) { return; }
            /* add dd listener later */
            window.setTimeout(Ext.bind(panel.addDDListener, panel, [retries+1]), 1000);
            return;
        }
        var tab   = panel.panel.tab;
        panel.dd.addListener('dragstart', function(This, evt) {
            TP.isShift = is_shift_pressed(evt);
            if(!panel.ddShadow) {
                var size = panel.getSize();
                panel.ddShadow = Ext.DomHelper.append(document.body, '<div style="border: 1px dashed black; width: '+size.width+'px; height: '+size.height+'px; position: relative; z-index: 10000; top: 0px; ; left: 0px; display: hidden;"><div style="border: 1px dashed white; width:'+(size.width-2)+'px; height:'+(size.height-2)+'px; position: relative; top: 0px; ; left: 0px;" ><\/div><\/div>' , true);
            }
            if(!panel.dragHint) {
                panel.dragHint = Ext.DomHelper.append(document.body, '<div style="border: 1px solid grey; border-radius: 2px; background: #CCCCCC; position: absolute; z-index: 10000; top: -1px; left: 35%; padding: 3px;">Tip: hold shift key to enable grid snap.<\/div>' , true);
            }
            tab.disableMapControlsTemp();
        });
        panel.dd.addListener('drag', function(This, evt) {
            TP.isShift = is_shift_pressed(evt);
            if(TP.iconSettingsWindow && TP.iconSettingsGlobals.renderUpdate) { TP.iconSettingsGlobals.renderUpdate(); }
        });
        panel.dd.addListener('dragend', function(This, evt) {
            if(TP.iconSettingsWindow && TP.iconSettingsGlobals.renderUpdate) { TP.iconSettingsGlobals.renderUpdate(); }
            tab.enableMapControlsTemp();
            if(panel.dragHint) {
                panel.dragHint.destroy();
                panel.dragHint = undefined;
            }
            TP.isShift = is_shift_pressed(evt);
            if(TP.isShift) {
                var pos = panel.getPosition();
                panel.noMoreMoves = true;
                panel.setPosition(TP.get_snap(pos[0], pos[1]));
                panel.noMoreMoves = false;
            }
            TP.isShift = false;
            if(panel.ddShadow) { panel.ddShadow.dom.style.display = 'none'; }
            window.setTimeout(function() {
                if(panel.ddShadow) {
                    panel.ddShadow.dom.style.display = 'none';
                }
            }, 100);
        });
        panel.ddAdded = true;
    }
});

Ext.define('TP.ActionMenuButton', {
    extend: 'Ext.button.Button',

    alias:  'widget.tp_action_menu_button',

    action_link:        '',    // contains the action link like ex.: menu://
    panel:              null,  // reference to panel
    host:               '',    // hostname used for macros
    service:            '',    // service description used for macros
    target:             '',    // target used for links
    afterClickCallback: null,  // callback called after click is done

    handler: function(btn, evt) {
        // create fake panel context to execute the click command from the menu
        openActionUrlWithFakePanel(btn, btn.panel, btn.action_link, btn.host, btn.service, btn.target, btn.afterClickCallback);
    }
});

function openActionUrlWithFakePanel(alignTo, panel, action_link, host, service, target, callback) {
    var fakePanel = Ext.create('Ext.panel.Panel', {
        autoShow: false,
        floating: true,
        x: 100,
        y: 100,
        autoEl:  'a',
        href:    '#',
        text:    ' ',
        renderTo: Ext.getBody(),
        listeners: {
            afterrender: function(This) {
                This.panel    = panel;
                This.tab      = panel.tab;
                This.xdata = {
                    link: {
                        link: action_link
                    },
                    general: {
                        host: host,
                        service: service
                    }
                };
                var options = {
                    alignTo:  alignTo,
                    callback: function() {
                        if(callback) {
                            callback();
                        }
                        window.setTimeout(function() {
                            This.destroy();
                        }, 1000);
                    }
                };
                TP.iconClickHandlerExec(This.id, action_link, This, target, undefined, options);
            }
        }
    });
    fakePanel.show();
    return;
}
