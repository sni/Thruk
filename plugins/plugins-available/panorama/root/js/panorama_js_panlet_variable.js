// Textinput / Variable Widget
/* TODO:
 *   - set variables from urls and dashboard link parameters
 *   - add option when to reload store: initial / regular
 *   - other var combos do not update automatically if one changes
 */
TP.VariableWidgetAll = '* ALL *';
Ext.define('TP.VariableWidget', {
    extend: 'TP.IconWidget',
    iconType:           'variable',
    html:               '',
    hideAppearanceTab:  true,
    hideLinkTab:        true,
    hidePermissionsTab: true,
    hideSourceTab:      true,
    hideScale:          true,
    hideFilterType:     true,
    hideRotate:         true,
    geoMapStatic:       true,
    labelBehindPanel:   true,
    initComponent: function() {
        this.callParent();
        var panel = this;
        panel.xdata.label.labeltext = '{{ucfirst(name)}}:';
        panel.xdata.label.position  = 'left';
        panel.xdata.layout.size_x   = '100';
        panel.xdata.layout.size_y   = '20';
        panel.xdata.general.name    = 'var1';
        panel.xdata.general.type    = 'select';
        panel.xdata.general.source  = 'query';
    },
    getGeneralItems: function() {
        var panel = this;
        updateFormVisibility = function() {
            if(!TP.iconSettingsWindow) { return; }
            var xdata = TP.get_icon_form_xdata(TP.iconSettingsWindow);
            var type   = xdata.general.type;
            var source = xdata.general.source;
            var form   = Ext.getCmp("generalForm");
            form.items.each(function(item, idx) {
                if(item.hasCls("all") || item.hasCls("type_"+type) || item.hasCls("source_"+source)) {
                    item.show();
                } else {
                    item.hide();
                }
            });
        }
        var renderChange = function() {
            if(!TP.iconSettingsWindow) { return; }
            var xdata = TP.get_icon_form_xdata(TP.iconSettingsWindow);
            panel.setRenderItem(xdata);
        };
        var previewChange = function() {
            TP.reduceDelayEvents(panel, previewChangeDo, 300, panel.id+'previewChange');
        };
        var previewChangeDo = function() {
            if(!TP.iconSettingsWindow) { return; }
            var xdata = TP.get_icon_form_xdata(TP.iconSettingsWindow);
            var preview = Ext.getCmp("varsPreview");
            preview.store.xdata = xdata;
            preview.setValue("refreshing...");
            preview.store.load(function(records, operation, success) {
                if(!success) {
                    if(preview.store.proxy.lastError) {
                        preview.setValue("ERROR: "+preview.store.proxy.lastError);
                    } else {
                        preview.setValue("ERROR: "+operation.error.status+" "+operation.error.statusText);
                    }
                    return;
                }
                var data = [];
                for(var x = 0; x < records.length; x++) {
                    if(x > 10) {
                        data.push("...");
                        x = records.length + 1;
                        break;
                    }
                    var disabled = records[x].get("disabled");
                    if(!disabled) {
                        data.push(records[x].get("name"));
                    }
                }
                preview.setValue(data.join(", "));
            });
        };
        var previewChangeListeners = {
            change: function(This, newValue, oldValue, eOpts) {
                previewChange();
            }
        };
        return([
            {
                fieldLabel: 'Name',
                cls:        'all',
                name:       'name',
                vtype:      'alphanum', // allow only letters and numbers
                xtype:      'textfield'
            },
            {
                fieldLabel: 'Type',
                cls:        'all',
                name:       'type',
                editable:    false,
                xtype:      'combobox',
                store:    [["textfield", "Textfield"],
                           ["select", "DropDown"]],
                listeners: {
                    change: function(This, newValue, oldValue, eOpts) {
                        renderChange();
                        updateFormVisibility();
                    }
                }
            },
            {
                fieldLabel: 'Source',
                cls:        'type_select',
                name:       'source',
                xtype:      'combobox',
                editable:    false,
                allowBlank:  false,
                store:    [["query", "Rest Query"],
                           ["static_list", "Static List"]],
                listeners: {
                    change: function(This, newValue, oldValue, eOpts) {
                        renderChange();
                        updateFormVisibility();
                    }
                }
            },
// Rest Url Options
            {
                fieldLabel: 'Rest Url',
                xtype:      'fieldcontainer',
                cls:        'source_query',
                layout:    { type: 'hbox', align: 'stretch' },
                items:      [{
                    name:           'rest_url',
                    flex:            1,
                    xtype:          'combobox',
                    matchFieldWidth: false,
                    triggerAction:  'all',
                    selectOnFocus:   true,
                    selectOnTab:     true,
                    typeAhead:       true,
                    valueField:     'url',
                    displayField:   'url',
                    id:             'rest_url_form',
                    emptyText:      'rest url, ex.: /hosts',
                    listeners:       previewChangeListeners,
                    pageSize:        12,
                    listConfig: {
                        minWidth: 240,
                        maxWidth: 600
                    },
                    store:{
                        model:   'RestUrlModel',
                        pageSize: 12,
                        proxy: {
                            type: 'ajax',
                            url:  '../r/index?columns=url&protocol=get&url[!~]=<&meta=1',
                            reader: {
                                type: 'json',
                                root: 'data'
                            }
                        }
                    }
                },
                {
                    xtype:         'label',
                    text:          'Column:',
                    margins:       {top: 3, right: 2, bottom: 0, left: 12}
                },
                {
                    name:          'column',
                    xtype:         'combobox',
                    matchFieldWidth: false,
                    triggerAction:  'all',
                    selectOnFocus:   true,
                    selectOnTab:     true,
                    typeAhead:       true,
                    listConfig: {
                        minWidth: 240,
                        maxWidth: 600
                    },
                    store:          [],
                    listeners: {
                        focus: function(combo, evt, eOpts) {
                            combo.reloadStoreData();
                        },
                        expand: function(combo, eOpts) {
                            combo.reloadStoreData();
                        },
                        change: function(This, newValue, oldValue, eOpts) {
                            previewChange();
                        }
                    },
                    lastUrl: "",
                    reloadStoreData: function() {
                        var combo = this;
                        var url = '../r'+Ext.getCmp("rest_url_form").getValue()+"?limit=1";
                        if(combo.lastUrl === url) { return; }
                        combo.lastUrl = url;
                        Ext.Ajax.request({
                            url: url,
                            success: function(response, opts) {
                                var data = TP.getResponse(undefined, response);
                                var keys = [];
                                if(data.length > 0) {
                                    for(var key in data[0]) {
                                        keys.push(key);
                                    }
                                }
                                TP.updateArrayStore(combo.store, keys);
                                combo.expand();
                            }
                        });
                    }
                }]
            },
            {
                fieldLabel: 'Query',
                cls:        'source_query',
                name:       'query',
                xtype:      'textfield',
                emptyText:  'filter, ex.: name !~ ^test',
                listeners: previewChangeListeners
            },
            {
                fieldLabel: 'Regexp',
                cls:        'source_query',
                name:       'regex',
                xtype:      'textfield',
                emptyText:  'apply regular expression to result, ex.: ^([a-z])\\.',
                listeners: previewChangeListeners
            },

// Static List Options
            {
                fieldLabel: 'Options',
                xtype:      'fieldcontainer',
                cls:        'source_static_list',
                layout:    { type: 'hbox', align: 'stretch' },
                items:      [{
                    xtype:         'label',
                    text:          'Separator:',
                    margins:       {top: 4, right: 2, bottom: 0, left: 0}
                }, {
                    name:         'separator',
                    xtype:        'combobox',
                    allowBlank:    false,
                    value:        ',',
                    store:    [[",", "comma ,"],
                               [";", "semicolon ;"],
                               ["\t", "tab"]],
                    listeners: previewChangeListeners
                }]
            },
            {
                fieldLabel: 'Input',
                cls:        'source_static_list',
                name:       'input',
                xtype:      'textarea',
                emptyText:  'comma separated list, ex.: a,b,c',
                listeners:   previewChangeListeners
            },

// Drop Down Options
            {
                fieldLabel: 'Options',
                xtype:      'fieldcontainer',
                cls:        'type_select',
                layout:    { type: 'hbox', align: 'stretch' },
                items:      [{
                    xtype:         'label',
                    text:          'Multiselect:',
                    forId:         'multiselect',
                    margins:       {top: 3, right: 2, bottom: 0, left: 0}
                }, {
                    name:         'multiselect',
                    inputId:      'multiselect',
                    xtype:        'checkbox'
                },
                {
                    xtype:         'label',
                    text:          'Add All Option:',
                    forId:         'add_all_option',
                    margins:       {top: 3, right: 2, bottom: 0, left: 12}
                }, {
                    name:         'add_all_option',
                    inputId:      'add_all_option',
                    xtype:        'checkbox',
                    listeners: previewChangeListeners
                },
                {
                    xtype:         'label',
                    text:          'Case:',
                    margins:       {top: 3, right: 2, bottom: 0, left: 12}
                }, {
                    name:         'casetransform',
                    width:         90,
                    xtype:        'combobox',
                    store:    [["uc", "upper case"],
                               ["lc", "lower case"]],
                    listeners: previewChangeListeners
                }]
            },

// Preview
            {
                fieldLabel: 'Preview',
                cls:        'type_select',
                xtype:      'displayfield',
                id:         'varsPreview',
                name:       'preview',
                value:      '',
                store:       Ext.create('TP.data.VarsStore', { panel:  panel }),
            }
        ]);
    },
    iconSettingsInitCallback: function() {
        updateFormVisibility();
    },
    refreshHandler: function()  { return; },
    setRenderItem: function(xdata) {
        var panel = this;
// TODO: check why called multiple times on load
        if(!xdata) { xdata = panel.xdata; }
        panel.removeAll();

        var changeListener = function(This, newValue, oldValue, eOpts) {
            if(Ext.isArray(newValue) && newValue.length > 1) {
                var foundAll = 0;
                for(var x = 0; x < newValue.length; x++) {
                    if(newValue[x] == TP.VariableWidgetAll) {
                        foundAll = x+1;
                        x = newValue.length + 1;
                    }
                }
                if(foundAll == 1) {
                    // found at first position: means _all_ was selected before and not something specific was choosen -> remove _all_
                    newValue.shift();
                    This.setValue(newValue);
                    return;
                }
                else if(foundAll > 1) {
                    // found anywhere else: means _all_ was selected as last pick -> clear selection and select only _all_
                    newValue = [TP.VariableWidgetAll];
                    This.setValue(newValue);
                    return;
                }
            }
            panel.tab.setVar(This.name, newValue);
// TODO: label won't refresh immediatly
            TP.refreshAllSitePanel(panel.tab);
            TP.updateAllIcons(panel.tab);
            panel.tab.saveIconsStates();
        };

        if(xdata.general.type == "select") {
            var listConfig = {
                minWidth:  240,
                maxWidth:  600,
                maxHeight: 800
            };
            if(xdata.general.multiselect) {
                listConfig["getInnerTpl"] = function(displayField) {
                    return '<div class="x-boundlist-item x-combo-list-item"><img src="' + Ext.BLANK_IMAGE_URL + '" class="chkCombo-default-icon chkCombo" /> {'+displayField+'} <\/div>';
                };
            }
            panel.formField = panel.add({
                xtype:          'searchpickercbo',
                name:            xdata.general.name,
                value:           panel.tab.getVars(xdata.general.name),
                id:              panel.id+'.var.'+xdata.general.name,
                width:           xdata.layout.size_x,
                height:          xdata.layout.size_y,
                matchFieldWidth: false,
                triggerAction:  'all',
                editable:        false,
                pageSize:        20,
                remoteFilter:    true,
                queryMode:      'remote',
                multiSelect:     xdata.general.multiselect,
                cls:             xdata.general.multiselect ? 'multiselect' : '',
                listConfig:      listConfig,
                displayField:   'name',
                store: Ext.create('TP.data.VarsStore', {
                    pageSize: 20,
                    panel:    panel,
                    xdata:    xdata
                }),
                listeners: {
                    change: changeListener,
                    expand: function(combo) {
                        panel.comboExtraFilter = ""; // reset filter
                        window.setTimeout(function() {
                            if(combo.picker.searchtoolbar) {
                                combo.picker.searchtoolbar.items.getAt(0).focus();
                            }
                        }, 300);
                    },
                },
                plugins: [{
                    ptype: 'comboitemsdisableable'
                }]
            });
        } else {
            panel.formField = el.add({
                xtype: 'textfield',
                name:  xdata.general.name,
                value: panel.tab.getVars(xdata.general.name),
                id:    panel.id+'.var.'+xdata.general.name,
                width:  xdata.layout.size_x,
                height: xdata.layout.size_y,
                listeners: {
                    change: changeListener
                }
            });
        }
        if(panel.el) { panel.size = panel.getSize(); }
    },
    // called when resized in settings
    applyScale: function(value, xdata) {
        var panel = this;
        if(xdata.layout.size_x != panel.xdata.layout.size_x || xdata.layout.size_y != panel.xdata.layout.size_y) {
            panel.setRenderItem(xdata);
        }
    },
    applyXdata: function(xdata) {
        var panel = this;
        this.callParent([xdata]);
        if(!xdata) {
            xdata = panel.xdata;
        }
        var val = panel.tab.getVars(xdata.general.name);
        panel.tab.setVar(xdata.general.name, val);
    },
    getMacros: function(xdata) {
        var panel = this;
        if(!xdata) {
            xdata = panel.xdata;
            if(TP.iconSettingsWindow && TP.iconSettingsWindow.panel.id == panel.id) {
                xdata = TP.get_icon_form_xdata(TP.iconSettingsWindow);
            }
        }
        return({
            name: xdata.general.name
        });
    }
});

Ext.define('RestUrlModel', {
    extend: 'Ext.data.Model',
    fields: ['url']
});

Ext.define('TP.data.VarsStore', {
    extend: 'Ext.data.Store',
    alias : 'tp_vars_store',

    model: 'Ext.ux.NameValueMode', // sets name / value model
    pageSize:       10,
    remoteSort:     true,
    remoteFilter:   true,
    displayField:  'name',
    listeners: {
        beforeload: function(store, operation, eOpts) {
            var xdata = store.xdata;
            var panel = store.panel;

            // local data
            if(xdata.general.source == "static_list") {
                var splitter = new RegExp("\s*["+xdata.general.separator+"\n\]+\s*")
                var data = String(xdata.general.input).split(splitter);
                store.setProxy({
                    type:   'memory',
                    data:    {data: data, total: data.length },
                    reader: {
                        type: 'tp_json_vars',
                        panel: panel,
                        xdata: xdata
                    }
                });
                return(true);
            }

            // remote data
            store.setProxy({
                type:   'tp_ajax_save_errors',
                method: 'POST',
                reader: {
                    type: 'tp_json_vars',
                    panel: panel,
                    xdata: xdata,
                }
            });
            var query = panel.tab.replaceVars(xdata.general.query);
            if(panel.comboExtraFilter) {
                if(query != "") { query += " and "; }
                panel.comboExtraFilter = panel.comboExtraFilter.replace('"', '');
                query += xdata.general.column+' ~~ "'+panel.comboExtraFilter+'"';
            }
            store.proxy.url = '../r'+xdata.general.rest_url;
            store.proxy.extraParams = {
                backends:   TP.getActiveBackendsPanel(panel.tab, panel),
                q:          query,
                columns:    xdata.general.column,
                transform:  xdata.general.regex,
                meta:       1
            };
            return(true);
        }
    }
});

Ext.define('TP.data.proxy.AjaxSaveErrors', {
    extend: 'Ext.data.proxy.Ajax',
    alias : 'proxy.tp_ajax_save_errors',

    processResponse: function(success, operation, request, response, callback, scope) {
        if(!success) {
            var error = response.status+" "+response.statusText;
            try {
                var res = Ext.JSON.decode(response.responseText);
                if(res && res.description) {
                    error = res.description;
                    error = error.replace(/\s+at\s+[\w\\\/\.]+\.pm\s+line\s+\d+\./, "");
                }
            } catch(e) {}
            this.lastError = error;
        }
        return this.callParent([success, operation, request, response, callback, scope]);
    }
});

Ext.define('TP.data.reader.JsonVariables', {
    extend: 'Ext.data.reader.Json',
    alias : 'reader.tp_json_vars',
    root: 'data',
    adjustResultData: function(raw) {
        var reader = this;
        var result = [];
        var regex;
        if(reader.xdata.general.regex) {
            regex = new RegExp(reader.xdata.general.regex, "i");
        }
        var filter;
        if(reader.panel.comboExtraFilter && reader.panel.comboExtraFilter != "") {
            filter = new RegExp(reader.panel.comboExtraFilter, "i");
        }
        var data  = raw.data;
        var total = raw.total || data.length;
        var uniq  = {};
        var col = reader.xdata.general.column;
        for(var x = 0; x < data.length; x++) {
            var val;
            if(Ext.isObject(data[x])) {
                val = data[x][col];
            } else {
                val = data[x];
            }
            if(filter  && !filter.test(val))  { continue; }
            if(regex) {
                var matches = regex.exec(val);
                if(matches && matches[1]) {
                    val = matches[1];
                }
            }
            if(reader.xdata.general.casetransform != "") {
                if(     reader.xdata.general.casetransform == "uc") { val = val.toUpperCase(); }
                else if(reader.xdata.general.casetransform == "lc") { val = val.toLowerCase(); }
            }
            val = Ext.String.htmlEncode(val);
            if(uniq[val]) { continue; }
            uniq[val] = true;
            result.push({name: val, value: val});
        }

        // sort by name
        result = Ext.Array.sort(result, function(a, b) { return(a['name'].localeCompare(b['name'])) });

        if(reader.xdata.general.add_all_option) {
            result.unshift({name: "<hr>", value: "", disabled: true});
            result.unshift({name: TP.VariableWidgetAll, value: "__ALL__"});
        }

        var current = reader.panel.items.getAt(0).getValue();
        if(!Ext.isArray(current)) { current = [current]; }
        for(var x = 0; x < current.length; x++) {
            if(current[x] != "" && current[x] != TP.VariableWidgetAll && !uniq[current[x]]) {
                var hidden = false;
                if(filter  && !filter.test(val))  { hidden = true; }
                result.push({name: current[x], value: current[x], hidden: hidden});
                total++;
            }
        }
        return({
            data: result,
            total: total
        });
    },
    readRecords: function(raw) {
        var data = this.adjustResultData(raw);
        return this.callParent([data]);
    }
});
