var backgrounds = Ext.create('Ext.data.Store', {
    fields: ['path', 'image'],
    proxy: {
        type: 'ajax',
        url:  'panorama.cgi?task=userdata_backgroundimages',
        reader: {
            type: 'json',
            root: 'data'
        }
    },
    autoLoad: false,
    data : []
});
var sounds = Ext.create('Ext.data.Store', {
    fields: ['path', 'name'],
    proxy: {
        type: 'ajax',
        url:  'panorama.cgi?task=userdata_sounds',
        reader: {
            type: 'json',
            root: 'data'
        }
    },
    autoLoad: false,
    data : []
});
var wmsProvider = Ext.create('Ext.data.Store', {
    fields: ['name', 'provider'],
    proxy: {
        type: 'ajax',
        url:  'panorama.cgi?task=wms_provider',
        reader: {
            type: 'json',
            root: 'data'
        }
    },
    autoLoad: false,
    data : thruk_wms_provider
});

TP.getExportTab = function(options) {
    var exportItems = [{
        xtype:      'panel',
        html:       'Save / Load Dashboards',
        style:      'text-align: center;',
        padding:    '0 0 10 0',
        border:      0
    }, {
        xtype:      'fieldcontainer',
        fieldLabel: 'File Save',
        items: [{
            xtype:  'button',
            text:   'Save Active Dashboard',
            iconCls:'save-btn',
            width:   150,
            href:   'panorama.cgi?task=save_dashboard&nr='+options.tab.id
        }, {
            xtype:  'button',
            text:   'Load Dashboard',
            iconCls:'load-btn',
            width:   150,
            margin: '0 0 0 10',
            handler: function() { TP.loadDashboardWindow() }
        }]
    }, {
        xtype:      'fieldcontainer',
        fieldLabel: 'Text Export',
        items: [{
            xtype: 'button',
            text: 'Import Tab(s) from Text',
            iconCls:'text-btn',
            width:   150,
            handler: function() {
                TP.modalWindows.push(Ext.MessageBox.prompt({
                    title:      'Import Tab(s)',
                    id:         'importdialog',
                    multiline:  true,
                    value:      '',
                    width:      600,
                    msg:        'Enter Saved String.<br>This will add the imported tabs next to your current ones.',
                    buttons:    Ext.MessageBox.OKCANCEL,
                    icon:       Ext.MessageBox.INFO,
                    fn:         function(btn, text, window) {
                        if(btn == 'ok') {
                            if(TP.importAllTabs(text)) {
                                if(options.close_handler) { options.close_handler(); }
                                if(TP.dashboardsSettingWindow) {
                                    TP.dashboardsSettingWindow.destroy();
                                }
                            }
                        }
                    }
                }));
            }
        }, {
            xtype: 'button',
            text:  'Export Active Tab as Text',
            iconCls:'text-btn',
            width:   150,
            margin: '0 0 0 10',
            handler: function() {
                var exportText = '# Thruk Panorama Dashboard Export: '+options.tab.title+'\n'+encode64(Ext.JSON.encode(TP.cp.lastdata[options.tab.id])).match(/.{1,65}/g).join("\n")+"\n# End Export";
                TP.modalWindows.push(Ext.MessageBox.show({
                    cls:        'monospaced',
                    title:      'Current Tab Export',
                    multiline:  true,
                    width:      600,
                    msg:        'Copy this string and use it for later import:',
                    value:      exportText,
                    buttons:    Ext.MessageBox.OK,
                    icon:       Ext.MessageBox.INFO,
                    handler: function() {
                        var form = Ext.getCmp('downloadform').getForm();
                        form.standardSubmit = true;
                        form.submit({
                            url:    'panorama.cgi',
                            target: '_blank',
                            params: {text: exportText, task: 'textsave', file: options.tab.title+'.panorama'}
                        });
                    }
                }));
            }
        }, {
            xtype:  'form',
            layout: 'fit',
            id:     'downloadform',
            style: { display: "none" },
            items: []
        }]
    }, {
        xtype:      'fieldcontainer',
        fieldLabel: 'Reset',
        items: [{
            xtype: 'button',
            width:  150,
            text: 'Reset to Default View',
            handler: function() {
                TP.modalWindows.push(Ext.Msg.confirm('Reset to default view?', 'Do you really want to reset all tabs and windows?', function(button) {
                    if (button === 'yes') {
                        if(options.close_handler) { options.close_handler(); }
                        TP.modalWindows.push(Ext.MessageBox.alert('Success', 'Reset Successful!<br>Please wait while page reloads...'));
                        window.location = 'panorama.cgi?clean=1';
                    }
                }));
            }
        }]
    }];
    var exportTab = {
        title : 'Import/Export',
        type  : 'panel',
        listeners: options.listeners,
        items: [{
            xtype : 'panel',
            layout: 'fit',
            border: 0,
            items: [{
                    xtype:           'form',
                    bodyPadding:     2,
                    border:          0,
                    bodyStyle:       'overflow-y: auto;',
                    submitEmptyText: false,
                    defaults:      { anchor: '-12', labelWidth: 130 },
                    items:           exportItems
            }]
        }]
    };
    return(exportTab);
}


/* show settings window */
TP.tabSettingsWindow = function(nr, closeAfterEdit) {
    new Ext.LoadMask(Ext.getBody(), {
        msg: 'loading settings...',
        listeners: {
            show: function(mask, eOpts) {
                window.setTimeout(function() {
                    TP.tabSettingsWindowDo(mask, nr, closeAfterEdit);
                }, 100);
            }
        }
    }).show();
}

TP.tabSettingsWindowDo = function(mask, nr, closeAfterEdit) {
    var tabpan = Ext.getCmp('tabpan');
    var tab;
    if(nr != undefined) {
        tab = Ext.getCmp(TP.nr2TabId(nr));
        if(tab == undefined) {
            TP.add_pantab(nr, undefined, true, function() {
                TP.tabSettingsWindow(nr, true);
            });
            return(false);
        }
    } else {
        tab = tabpan.getActiveTab();
    }

    /* stop rotation */
    TP.stopRotatingTabs();

    backgrounds.load();
    sounds.load();
    wmsProvider.load();

    var exportTab = TP.getExportTab({tab: tab, close_handler: function() { tab_win_settings.close() }});

    var usersettingsItems = [{
        xtype:   'panel',
        html:    'These settings apply to all dashboards and are saved with the user account.',
        style:   'text-align: center;',
        padding: '0 0 10 0',
        border:   0
    }, {
        /* rotating tabs */
        xtype:      'tp_slider',
        fieldLabel: 'Rotate Tabs',
        formConf: {
            minValue:   0,
            nameS:      'rotate_tabs',
            nameL:      'rotate_tabs_txt',
            value:      tabpan.xdata['rotate_tabs']
        }
    }, {
        /* show server time */
        xtype:      'checkbox',
        fieldLabel: 'Show Server Time',
        name:       'server_time',
        boxLabel:   '(display server time next to the menu)'
    }, {
        /* sounds enabled */
        xtype:      'checkbox',
        fieldLabel: 'Enable Sounds',
        name:       'sounds_enabled',
        boxLabel:   '(enable sounds if configured for a dashboard)'
    }];
    var usersettingsTab = {
        title : 'User Settings',
        type  : 'panel',
        items: [{
            xtype : 'panel',
            layout: 'fit',
            border: 0,
            items: [{
                    xtype:           'form',
                    id:             'usersettingsForm',
                    bodyPadding:     2,
                    border:          0,
                    bodyStyle:       'overflow-y: auto;',
                    submitEmptyText: false,
                    defaults:      { anchor: '-12', labelWidth: 130 },
                    items:           usersettingsItems
            }]
        }]
    };


    /* Backend Settings Tab */
    var backends = TP.getBackendsArray(initial_backends);
    if(backends.length > 1) {
        var backendsItems = [{
                xtype:   'panel',
                html:    'Filter backends masterset for this dashboard',
                style:   'text-align: center;',
                padding: '0 0 10 0',
                border:   0
            },{
                /* use backends */
                xtype:      'checkbox',
                fieldLabel: 'Select Backends',
                name:       'select_backends',
                listeners: {
                    change: function(This, newValue, oldValue, eOpts) {
                        this.up().items.get(2).setDisabled(!newValue);
                    }
                },
                checked: tab.xdata.select_backends,
                boxLabel:   '(enable to select a subset of backends)'
            }, {
                /* backends */
                fieldLabel: 'Backends / Sites',
                xtype:      'itemselector',
                name:       'backends',
                height:     200,
                disabled:   !tab.xdata.select_backends,
                buttons:   ['add', 'remove'],
                store:     backends,
                value:     tab.xdata.backends
        }];
        var backendsTab = {
            title : 'Backends',
            type  : 'panel',
            items: [{
                xtype : 'panel',
                layout: 'fit',
                border: 0,
                items: [{
                        xtype:          'form',
                        id:             'backendsForm',
                        bodyPadding:     2,
                        border:          0,
                        bodyStyle:      'overflow-y: auto;',
                        submitEmptyText: false,
                        defaults:      { anchor: '-12', labelWidth: 130 },
                        items:           backendsItems
                }]
            }]
        };
    }

    var access = [];
    if(tab.xdata.groups == undefined) { tab.xdata.groups = []; }
    Ext.Array.each(tab.xdata.groups, function(item, idx, len) {
        var group = Ext.Object.getKeys(item)[0];
        var perm  = item[group];
        access.push({ contactgroup: group, permission: perm });
    });
    var permissionsStore = Ext.create('Ext.data.Store', {
        fields: ['contactgroup', 'permission'],
        data: access
    });
    var permissionsItems = [{
        /* show owner */
        xtype:      'textfield',
        fieldLabel: 'Owner',
        name:       'owner',
        disabled:    true
    }, {
        /* permissions */
        xtype:      'fieldcontainer',
        fieldLabel: 'Permissions',
        layout:     'fit',
        items: [{
            xtype:      'gridpanel',
            name:       'permissions',
            id:         'permissionsGrid',
            columns:    [
                    { header: 'Group', flex: 1, dataIndex: 'contactgroup',  align: 'left', tdCls: 'editable', editor: {
                            xtype:            'searchCbo',
                            panel:            {panel_id: tab.id},
                            store:             searchStore,
                            storeExtraParams: { wildcards: 1 },
                            lazyRender:        true,
                            allowBlank:        false
                        }
                    },
                    { header: 'Permissions', width: 140,  dataIndex: 'permission', align: 'left', tdCls: 'editable', editor: {
                            xtype:         'combobox',
                            triggerAction: 'all',
                            selectOnTab:    true,
                            lazyRender:     true,
                            editable:       false,
                            store:        ['read-only', 'read-write']
                        }
                    },
                    { header: '',  width: 30,
                      xtype: 'actioncolumn',
                      items: [{
                            icon: '../plugins/panorama/images/delete.png',
                            handler: TP.removeGridRow,
                            action: 'remove'
                      }],
                      tdCls: 'clickable icon_column'
                    }
            ],
            store: permissionsStore,
            selType:    'rowmodel',
            plugins:     [Ext.create('Ext.grid.plugin.RowEditing', {
                clicksToEdit: 1,
                listeners: {
                    canceledit: function(grid, eOpts) {
                        // remove new elements
                        if(eOpts.record.phantom) { eOpts.store.remove(eOpts.record); }
                    }
                }
            })],
            height: 230,
            width:  300,
            fbar: [{
                type: 'button',
                text: 'Add Contactgroup',
                iconCls: 'user-tab',
                handler: function(btn, eOpts) {
                    var store = btn.up('gridpanel').store;
                    store.add({contactgroup:'*', permission:'read-only'})
                    btn.up('gridpanel').plugins[0].startEdit(store.last(), 0);
                }
            }]
        }]
    }];
    var permissionsTab = {
        title : 'Permissions',
        type  : 'panel',
        items: [{
            xtype : 'panel',
            layout: 'fit',
            border: 0,
            items: [{
                    xtype:          'form',
                    id:             'permissionsForm',
                    bodyPadding:     2,
                    border:          0,
                    bodyStyle:      'overflow-y: auto;',
                    submitEmptyText: false,
                    defaults:      { anchor: '-12', labelWidth: 130 },
                    items:           permissionsItems
            }]
        }]
    };

    function applyBackground(values) {
        if(values == undefined) {
            var d_form  = Ext.getCmp('dashboardForm').getForm();
            if(!d_form.isValid()) { return false; }
            values = d_form.getFieldValues();
            if(values.locked) { return; }
        }
        if(values.map_choose == undefined) {
            if(values.map) {
                values.map_choose = 'geomap';
            }
        }
        if(values.map_choose == 'geomap') {
            if(tab.xdata.map) {
                values.map = tab.xdata.map;
            } else {
                values.map = {};
            }
            Ext.getCmp('background_choose').hide();
            Ext.getCmp('background_offset_choose').hide();
            Ext.getCmp('wms_choose').show();
            Ext.getCmp('mapcenter').show();
            if(values.wms_provider == undefined || values.wms_provider == "") {
                if(wmsProvider.data.length > 0) {
                    values.wms_provider = wmsProvider.getAt(0).data.name;
                    Ext.getCmp('wms_choose').setRawValue(values.wms_provider);
                }
            }
            if(values.mapzoom == undefined || values.mapzoom == "") {
                values.maplon  = default_map_lon;
                values.maplat  = default_map_lat;
                values.mapzoom = default_map_zoom;
                Ext.getCmp('maplon').setRawValue(values.maplon);
                Ext.getCmp('maplat').setRawValue(values.maplat);
                Ext.getCmp('mapzoom').setRawValue(values.mapzoom);
            }
        } else {
            Ext.getCmp('background_choose').show();
            Ext.getCmp('background_offset_choose').show();
            Ext.getCmp('wms_choose').hide();
            Ext.getCmp('mapcenter').hide();
            delete values['map'];
        }
        tab.setBackground(values);
    }

    /* Dashboard Settings Tab */
    var dashboardItems = [{
            xtype:      'checkbox',
            fieldLabel: 'Locked',
            name:       'locked',
            boxLabel:   '(disables dashboard editing)',
            handler:    function(el, checked) { TP.tabSettingsWindowLocked(tab, checked); }
        }, {
            /* tab title */
            xtype:      'textfield',
            name:       'title',
            fieldLabel: 'Title'
        }, {
            /* global refresh rate */
            xtype:      'tp_slider',
            fieldLabel: 'Refresh Rate',
            formConf: {
                minValue:   0,
                nameS:      'refresh',
                nameL:      'refresh_txt',
                value:      tab.xdata['refresh']
            }
        }, {
            fieldLabel:  'Background',
            xtype:       'fieldcontainer',
            defaultType: 'radiofield',
            defaults:   {
                flex: 1,
                listeners: { change: function(This) { applyBackground() } }
            },
            layout:      'hbox',
            items: [{
                    boxLabel:   'Static Image',
                    name:       'map_choose',
                    inputValue: 'static',
                    checked:     tab.xdata.map == undefined ? true : false
                }, {
                    boxLabel:   'Geo Map',
                    name:       'map_choose',
                    inputValue: 'geomap',
                    checked:     tab.xdata.map != undefined ? true : false
            }]
        }, {
            fieldLabel:     'WMS Provider',
            xtype:          'combobox',
            name:           'wms_provider',
            id:             'wms_choose',
            store:           wmsProvider,
            queryMode:      'local',
            triggerAction:  'all',
            displayField:   'name',
            valueField:     'name',
            editable:        false,
            forceSelection:  true,
            hidden:          tab.xdata.map == undefined ? true : false,
            listeners:     { change: function(This) { applyBackground() } }
        }, {
            fieldLabel:  'Map Center',
            xtype:       'fieldcontainer',
            id:          'mapcenter',
            layout:      'hbox',
            defaults:   {
                listeners: { change: function(This) { applyBackground() } }
            },
            items: [
            { xtype: 'label', text:  'Lon/Lat:', style: 'margin-left: 0px; margin-right: 2px;', cls: 'x-form-item-label' },
            {
                xtype:      'textfield',
                name:       'maplon',
                id:         'maplon',
                width:       120,
                value:       tab.xdata.map != undefined ? tab.xdata.map.lon : ''
            }, {
                xtype:      'textfield',
                name:       'maplat',
                id:         'maplat',
                width:       120,
                value:       tab.xdata.map != undefined ? tab.xdata.map.lat : ''
            },
            { xtype: 'label', text:  'Zoom:', style: 'margin-left: 10px; margin-right: 2px; text-align: right;', flex: 1, cls: 'x-form-item-label' },
            {
                xtype:      'textfield',
                name:       'mapzoom',
                id:         'mapzoom',
                width:       40,
                value:       tab.xdata.map != undefined ? tab.xdata.map.zoom : ''
            }]
        }, {
            fieldLabel: ' ',
            labelSeparator: '',
            id:         'background_choose',
            hidden:      tab.xdata.map != undefined ? true : false,
            xtype:      'fieldcontainer',
            layout:     'hbox',
            defaults: {
                listeners: { change: function(This) { applyBackground() } }
            },
            items: [{
                xtype:          'combobox',
                name:           'background',
                store:           backgrounds,
                queryMode:      'remote',
                triggerAction:  'all',
                pageSize:        true,
                selectOnFocus:   true,
                typeAhead:       true,
                displayField:   'image',
                flex:            1,
                valueField:     'path',
                listConfig : {
                    getInnerTpl: function(displayField) {
                        return '<div class="x-combo-list-item" style="overflow: hidden; white-space: nowrap;"><img src="{path}" height=16 width=16> {image}<\/div>';
                    }
                },
                listeners: {
                    select: function(combo, records, eOpts) {
                        if(records[0].data['image'] == "&lt;upload new image&gt;") {
                            TP.uploadUserContent('image', 'backgrounds/', function(filename) {
                                combo.setValue('../usercontent/backgrounds/'+filename);
                            });
                        }
                        return(true);
                    },
                    change: function(This) { applyBackground() }
                }
            },
            { xtype: 'label', text:  'Scale:', style: 'margin-left: 10px; margin-right: 2px;', cls: 'x-form-item-label' },
            {
                xtype:          'numberunit',
                unit:           '%',
                allowDecimals:   true,
                name:           'backgroundscale',
                minValue:        0,
                maxValue:        10000,
                step:            1,
                width:           70,
                value:           100,
                fieldStyle:     'text-align: right;'
            }]
        }, {
            fieldLabel:     ' ',
            labelSeparator: '',
            id:             'background_offset_choose',
            hidden:          tab.xdata.map != undefined ? true : false,
            xtype:          'fieldcontainer',
            layout:         'hbox',
            defaults: {
                listeners: { change: function(This) { applyBackground() } }
            },
            items: [
            { xtype: 'label', text: 'Offset X:', style: 'margin-right: 2px;', cls: 'x-form-item-label' },
            {
                xtype:          'numberunit',
                unit:           'px',
                allowDecimals:   true,
                name:           'backgroundoffset_x',
                minValue:       -10000,
                maxValue:        10000,
                step:            1,
                width:           70,
                value:           0,
                fieldStyle:     'text-align: right;'
            },
            { xtype: 'label', text: 'Y:', style: 'margin-left: 10px; margin-right: 2px;', cls: 'x-form-item-label' },
            {
                xtype:          'numberunit',
                unit:           'px',
                allowDecimals:   true,
                name:           'backgroundoffset_y',
                minValue:       -10000,
                maxValue:        10000,
                step:            1,
                width:           70,
                value:           0,
                fieldStyle:     'text-align: right;'
            }]

        }, {
            fieldLabel:   'Default Icon Set',
            xtype:        'combobox',
            name:         'defaulticonset',
            store:         TP.iconsetsStore,
            value:        'default',
            displayField: 'name',
            valueField:   'value',
            listConfig : {
                getInnerTpl: function(displayField) {
                    return '<div class="x-combo-list-item"><img src="{sample}" height=16 width=16 style="vertical-align:top; margin-right: 3px;">{name}<\/div>';
                }
            }
        }, {
            /* auto hide panlet header */
            xtype:      'checkbox',
            fieldLabel: 'Hide Panlet Header',
            name:       'autohideheader',
            boxLabel:   ' (widget header will be displayed on mouse over)'
        }, {
            fieldLabel:  'State Type',
            xtype:       'fieldcontainer',
            defaultType: 'radiofield',
            layout:      'hbox',
            items: [{
                    boxLabel:   'Soft States',
                    name:       'state_type',
                    inputValue: 'soft',
                    checked:    tab.xdata.state_type == 'soft' ? true : false
                }, {
                    boxLabel:   'Hard States Only',
                    name:       'state_type',
                    inputValue: 'hard',
                    checked:    tab.xdata.state_type == 'hard' ? true : false,
                    padding:    '0 0 0 30',
            }]
        }, {
            xtype:      'panel',
            html:       'Place background images in: '+usercontent_folder+'/backgrounds/ <a href="#" onclick="TP.uploadUserContent(\'image\', \'backgrounds/\')">(upload)</a>',
            style:      'text-align: center;',
            bodyCls:    'form-hint',
            padding:    '10 0 0 0',
            border:      0
        }];
    var dashboardTab = {
        title : 'Dashboard',
        type  : 'panel',
        items: [{
            xtype : 'panel',
            layout: 'fit',
            border: 0,
            items: [{
                    xtype:          'form',
                    id:             'dashboardForm',
                    bodyPadding:     2,
                    border:          0,
                    bodyStyle:      'overflow-y: auto;',
                    submitEmptyText: false,
                    defaults:      { anchor: '-12', labelWidth: 130 },
                    items:           dashboardItems
            }]
        }],
        listeners: {
            afterrender: function() {
                applyBackground(tab.xdata);
            }
        }
    };


    /* Sound Settings Tab */
    var soundItems = [{
        xtype:      'panel',
        html:       'Sounds apply to all icon widgets',
        style:      'text-align: center;',
        padding:    '0 0 10 0',
        border:      0
    }, {
        xtype:      'tp_soundfield',
        fieldLabel: 'Unreachable',
        nameV:      'unreachable_sound',
        nameR:      'unreachable_repeat',
        store:       sounds
    }, {
        xtype:      'tp_soundfield',
        fieldLabel: 'Down',
        nameV:      'down_sound',
        nameR:      'down_repeat',
        store:       sounds
    }, {
        xtype:      'tp_soundfield',
        fieldLabel: 'Critical',
        nameV:      'critical_sound',
        nameR:      'critical_repeat',
        store:       sounds
    }, {
        xtype:      'tp_soundfield',
        fieldLabel: 'Warning',
        nameV:      'warning_sound',
        nameR:      'warning_repeat',
        store:       sounds
    }, {
        xtype:      'tp_soundfield',
        fieldLabel: 'Unknown',
        nameV:      'unknown_sound',
        nameR:      'unknown_repeat',
        store:       sounds
    }, {
        xtype:      'tp_soundfield',
        fieldLabel: 'Recovery',
        nameV:      'recovery_sound',
        store:       sounds
    }, {
        xtype:      'panel',
        html:       'Place sound files in: '+usercontent_folder+'/sounds/',
        style:      'text-align: center;',
        bodyCls:    'form-hint',
        padding:    '10 0 0 0',
        border:      0
    }];
    var soundsTab = {
        title : 'Sounds',
        type  : 'panel',
        items: [{
            xtype : 'panel',
            layout: 'fit',
            border: 0,
            items: [{
                    xtype:          'form',
                    id:             'soundForm',
                    bodyPadding:     2,
                    border:          0,
                    bodyStyle:      'overflow-y: auto;',
                    submitEmptyText: false,
                    defaults:      { anchor: '-12', labelWidth: 70 },
                    items:           soundItems
            }],
            listeners: {
                afterrender: function() {
                    Ext.getCmp('soundForm').getForm().setValues(tab.xdata);
                }
            }
        }]
    };


    /* tab layout for settings window */
    var tabPanel = new Ext.TabPanel({
        activeTab         : 0,
        enableTabScroll   : true,
        items             : [
            dashboardTab,
            backendsTab,
            soundsTab,
            permissionsTab,
            exportTab,
            usersettingsTab
        ]
    });

    /* the actual settings window containing the panel */
    var tab_win_settings = new Ext.window.Window({
        modal:       true,
        width:       550,
        height:      350,
        title:       'Settings',
        layout :     'fit',
        buttonAlign: 'center',
        items:       tabPanel,
        hadMapAlready: tab.xdata.map ? true : false,
        fbar: [{/* cancel button */
                    xtype:  'button',
                    text:   'cancel',
                    handler: function(This) {
                        // restore old values
                        if(!tab_win_settings.hadMapAlready) {
                            delete tab.xdata['map'];
                            delete tab.xdata['wms_provider'];
                        }
                        tab.applyXdata(undefined, false);
                        tab_win_settings.destroy();
                        if(closeAfterEdit) { tab.destroy(); }
                    }
                }, {
                /* save button */
                    xtype : 'button',
                    text:   'save',
                    handler: function() {
                        /* unlock form, otherwise values cannot be retrieved */
                        TP.tabSettingsWindowLocked(tab, false);

                        var win     = this.up('window');
                        var oldautohideheader = tab.xdata.autohideheader;

                        var oldstate = Ext.JSON.encode(tab.getState());
                        var d_form  = Ext.getCmp('dashboardForm').getForm();
                        if(!d_form.isValid()) { return false; }
                        var values = d_form.getFieldValues();
                        var locked = values.locked;
                        if(values['map_choose'] == 'geomap') {
                            tab.xdata.map = {
                                lon:  values.maplon,
                                lat:  values.maplat,
                                zoom: values.mapzoom
                            };
                        } else {
                            delete tab.xdata['map'];
                            delete tab.xdata['wms_provider'];
                            delete values['wms_provider'];
                            if(tab.mapEl) { tab.mapEl.destroy(); tab.mapEl = undefined; }
                            if(tab.map)   { tab.map.destroy();   tab.map   = undefined; }
                            /* remove map coordinates */
                            var panels = TP.getAllPanel(tab);
                            for(var nr=0; nr<panels.length; nr++) {
                                var p = panels[nr];
                                delete p.xdata.map;
                                p.forceSaveState();
                            }
                        }
                        delete values['refresh_txt'];
                        delete values['map_choose'];
                        Ext.apply(tab.xdata, values);

                        var s_form  = Ext.getCmp('soundForm').getForm();
                        if(!s_form.isValid()) { return false; }
                        var values = s_form.getFieldValues();
                        Ext.apply(tab.xdata, values);

                        if(Ext.getCmp('backendsForm')) {
                            var b_form  = Ext.getCmp('backendsForm').getForm();
                            if(!b_form.isValid()) { return false; }
                            var values = b_form.getFieldValues();
                            Ext.apply(tab.xdata, values);
                        }

                        /* dashboard permissions */
                        tab.xdata.groups = [];
                        permissionsStore.each(function(rec) {
                            var row = {};
                            row[rec.data.contactgroup] = rec.data.permission;
                            tab.xdata.groups.push(row);
                        });

                        tab.applyXdata(undefined, false);
                        var newstate = Ext.JSON.encode(tab.getState());
                        tab.forceSaveState();
                        if(oldstate != newstate) {
                            tabpan.startTimeouts();
                        }

                        /* user settings */
                        var oldstate = Ext.JSON.encode(tabpan.getState());
                        var u_form  = Ext.getCmp('usersettingsForm').getForm();
                        if(!u_form.isValid()) { return false; }
                        var values = u_form.getFieldValues();
                        delete values['rotate_tabs_txt'];
                        Ext.apply(tabpan.xdata, values);
                        var newstate = Ext.JSON.encode(tabpan.getState());
                        TP.log('['+tab.id+'] settings changed: '+newstate);
                        /* avoid useless updates */
                        if(oldstate != newstate) {
                            tabpan.saveState();
                            tabpan.startTimeouts();
                        }

                        TP.refreshAllSitePanel(tab);

                        /* border setting may have changed, so redraw all panlets with some small delay */
                        if(oldautohideheader != tab.xdata.autohideheader) {
                            var panels = TP.getAllPanel(tab);
                            var delay  = 30;
                            for(var nr=0; nr<panels.length; nr++) {
                                var p = panels[nr];
                                if(p.redrawPanlet) {
                                    window.setTimeout(Ext.bind(p.redrawPanlet, p, []), delay);
                                    delay = delay + 30;
                                }
                            }
                        }

                        tab_win_settings.destroy();
                        if(closeAfterEdit) {
                            tab.destroy();
                        } else {
                            /* permissions might have changed */
                            tab.setLock(locked);
                            window.setTimeout(function() {
                                TP.renewDashboard(tab);
                            }, 2000);
                        }
                        return true;
                    }
               }
        ]
    });
    tab.xdata['refresh_txt'] = TP.sliderValue2Txt(tab.xdata['refresh']); // refresh text is wrong otherwise on initial settings window
    if(tab.xdata.map) {
        tab.xdata['maplon']  = tab.xdata.map.lon;
        tab.xdata['maplat']  = tab.xdata.map.lat;
        tab.xdata['mapzoom'] = tab.xdata.map.zoom;
    }
    Ext.getCmp('dashboardForm').getForm().setValues(tab.xdata);
    Ext.getCmp('soundForm').getForm().setValues(tab.xdata);
    Ext.getCmp('usersettingsForm').getForm().setValues(tabpan.xdata);
    Ext.getCmp('permissionsForm').getForm().setValues(tab.xdata);
    tab_win_settings.show();
    mask.destroy();
    TP.modalWindows.push(tab_win_settings);
};

TP.tabSettingsWindowLocked = function(tab, val) {
    /* apply to dashboard tab */
    var dashboardForm = Ext.getCmp('dashboardForm');
    if(dashboardForm) {
        dashboardForm.items.each(function(item, idx, len) {
            if(item.name != 'locked') {
                item.setDisabled(val);
            }
            if(tab.readonly == 1) {
                item.setDisabled(true);
            }
        });
    }
    /* apply to sounds tab */
    var soundForm = Ext.getCmp('soundForm');
    if(soundForm) {
        soundForm.items.each(function(item, idx, len) {
            item.setDisabled(val);
            if(tab.readonly == 1) {
                item.setDisabled(true);
            }
        });
    }
    /* change backends tab */
    var backendsForm = Ext.getCmp('backendsForm');
    if(backendsForm) {
        var b_form   = backendsForm.getForm();
        var b_values = b_form.getFieldValues();
        if(b_values['select_backends'] == undefined) {
            b_values['select_backends'] = tab.xdata.select_backends;
        }
        backendsForm.items.each(function(item, idx, len) {
            item.setDisabled(val);
            if(item.name == "backends" && !b_values['select_backends']) {
                item.setDisabled(true);
            }
        });
    }
    /* apply to permissions tab */
    var permissionsForm = Ext.getCmp('permissionsForm');
    if(permissionsForm) {
        permissionsForm.items.each(function(item, idx, len) {
            item.setDisabled(val);
            Ext.getCmp('permissionsGrid').setDisabled(val);
            if(tab.readonly == 1) {
                item.setDisabled(true);
                Ext.getCmp('permissionsGrid').setDisabled(true);
            }
        });
    }
};

TP.uploadUserContent = function(type, location, onSuccess) {
    TP.modalWindows.push(Ext.create('Ext.window.Window', {
        title: 'Usercontent Upload',
        height: 100,
        width:  300,
        layout: 'anchor',
        items: [{
            xtype:  'form',
            border:  false,
            layout: 'anchor',
            anchor: '100% 100%',
            bodyPadding: 5,
            items: [{
                xtype:      'filefield',
                anchor:     '90% 100%',
                name:        type,
                allowBlank:  false,
                buttonText: 'Select '+type+'...'
            }]
        }],
        buttons: [{
            text: 'Cancel',
            handler: function() {
                this.up('window').destroy();
            }
        }, {
            text: 'Upload',
            handler: function() {
                var win  = this.up('window');
                var form = win.down('form').getForm();
                if(form.isValid()){
                    form.submit({
                        url: 'panorama.cgi',
                        params: {
                            task:    'upload',
                            type:     type,
                            location: location
                        },
                        waitMsg: 'Uploading your '+type+'...',
                        success: function(form, action) {
                            TP.Msg.msg("success_message~~uploaded "+type+" successfully.");
                            win.destroy();
                            backgrounds.load();
                            if(onSuccess) { onSuccess(action.result.filename); }
                        },
                        failure: function(form, action) {
                            TP.Msg.msg("fail_message~~uploading "+type+" failed. "+action.result.msg);
                            win.destroy();
                        }
                    });
                }
            }
        }]
    }).show());
};

TP.loadDashboardWindow = function() {
    TP.modalWindows.push(Ext.create('Ext.window.Window', {
        title: 'Load Dashboard From File',
        height: 100,
        width:  300,
        layout: 'anchor',
        items: [{
            xtype:  'form',
            border:  false,
            layout: 'anchor',
            anchor: '100% 100%',
            bodyPadding: 5,
            items: [{
                xtype:      'filefield',
                anchor:     '90% 100%',
                name:        'file',
                allowBlank:  false,
                buttonText: 'Select Dashboard File...'
            }]
        }],
        buttons: [{
            text: 'Cancel',
            handler: function() {
                this.up('window').destroy();
            }
        }, {
            text: 'Import',
            handler: function() {
                var win  = this.up('window');
                var form = win.down('form').getForm();
                if(form.isValid()){
                    form.submit({
                        url: 'panorama.cgi',
                        params: { task: 'load_dashboard' },
                        waitMsg: 'Loading Dashboard...',
                        success: function(form, action) {
                            /* refresh icon sets, there might be new ones now */
                            TP.iconsetsStore.load({callback: function() {
                                TP.add_pantab(action.result.newid);
                                TP.Msg.msg("success_message~~dashboard loaded successfully.");
                            }});
                            win.destroy();
                        },
                        failure: function(form, action) {
                            TP.Msg.msg("fail_message~~loading dashboard failed. "+action.result.msg);
                            win.destroy();
                        }
                    });
                }
            }
        }]
    }).show());
}
