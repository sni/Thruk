Ext.define('TP.GridLoader', {
    extend: 'Ext.ComponentLoader',

    autoLoad: false,
    renderer: 'data',
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
        },
        'load': function(This, response, options, eOpts) {
            if(This.target && This.target.body) {
                This.target.unmask();
            }
        }
    },
    callback: function(This, success, response, options) {
        var panel    = this;
        This.loading = false;
        var data = TP.getResponse(this, response);
        if(data) {
            TP.log('['+panel.id+'] loaded');
            if(!this.grid) {this.grid = this.target };
            var b = Ext.get(this.grid.id+"-body");
            var body;
            if(b) { body = b.dom.firstChild }
            if(data.paging) {
                if(this.pagingToolbar) {
                    this.pagingToolbar.show();
                    if(this.pagingToolbar.items.getAt(9)) {
                        this.pagingToolbar.items.getAt(9).hide();  // hide seperator
                        this.pagingToolbar.items.getAt(10).hide(); // hide refresh
                    }
                    this.pagingToolbar.updateData(data);
                }
                if(body) {
                    try {
                        body.style.overflow  = 'inherit';
                        body.style.overflowY = 'hidden';
                    } catch(err) {
                        /* breaks in IE 8 sometimes */
                        TP.log("thruk: setting style failed")
                        TP.logError(panel.id, "bodyStyleException", err);
                    }
                }
            } else {
                if(this.pagingToolbar) {
                    this.pagingToolbar.hide();
                }
                if(body) {
                    try {
                        body.style.overflowY = 'inherit';
                        body.style.overflow  = 'auto';
                    } catch(err) {
                        /* breaks in IE 8 sometimes */
                        TP.log("thruk: setting style failed")
                        TP.logError(panel.id, "bodyStyleException", err);
                    }
                }
            }
            var fields = [];
            var newcolumns = Ext.JSON.encode(data.columns);
            for(var key in data.columns) {
                if(data.columns[key].dataIndex) {
                    fields.push(data.columns[key].dataIndex);
                }
                for(var key2 in data.columns[key]) {
                    /* this is usually a function, so eval it */
                    if(key2 == 'renderer') {
                        eval('data.columns[key][key2]=' + data.columns[key][key2]);
                    }
                    if(Ext.isIE && key2 == 'headerIE') {
                        data.columns[key]['header'] = data.columns[key]['headerIE'];
                    }
                    if(key2 == 'items') {
                        for(var x=0; x<data.columns[key][key2].length; x++) {
                            if(data.columns[key][key2][x].handler) {
                                eval('data.columns[key][key2][x]["handler"]=' + data.columns[key][key2][x].handler);
                            }
                        }
                    }
                }
            }
            if(this.xdata == undefined) { this.xdata = { pageSize: 20 }; }
            this.gridStore = Ext.create('Ext.data.Store', {
                data:  {'items': data.data },
                fields: fields,
                pageSize: this.xdata.pageSize,
                proxy: {
                    type: 'memory',
                    reader: {
                        type: 'json',
                        root: 'items'
                    }
                },
                groupField: this.xdata.groupField != undefined ? this.xdata.groupField : data.group
            });
            var columns;
            if(panel.xdata && panel.xdata.gridstate && panel.xdata.gridstate.columns) {
                columns = panel.xdata.gridstate.columns;
            }
            var changed = false;
            /* may fail if grid is already closed */
            try {
                if(!panel.grid.headerCt.up('[store]') || !panel.grid.headerCt.up('[store]').store) {
                    /* make sure store still exists, may have been closed meanwhile */
                    return;
                }
                if(this.gridcolumns == undefined || this.gridcolumns != newcolumns) {
                    this.gridcolumns = newcolumns;
                    /* width is not recognized, so set it here */
                    if(this.initialState) {
                        for(var x = 0; x < data.columns.length; x++) {
                            if(this.initialState.columns && this.initialState.columns[x] && this.initialState.columns[x].width) {
                                data.columns[x].width = this.initialState.columns[x].width;
                            }
                        }
                    }
                    this.grid.reconfigure(this.gridStore, data.columns);
                    changed = true;
                } else {
                    this.grid.reconfigure(this.gridStore);
                }
            } catch(err) {
                TP.log("reconfigure failed");
                TP.logError(panel.id, "gridReconfigureException", err);
                return;
            }
            if(this.initialState != undefined) {
                /* applyState throws internal error but state gets applied anyway */
                try {
                    this.grid.applyState(this.initialState);
                } catch(err) {
                    //TP.logError(panel.id, "gridApplyStateException", err);
                }
            }
            if(this.xdata.gridstate != undefined) {
                this.grid.applyState(this.xdata.gridstate);
            }
            if(this.pagingToolbar) {
                this.pagingToolbar.onLoad();
                if(data.paging && this.pagingToolbar.getPageData().pageCount == 1) {
                    this.pagingToolbar.hide();
                }
            }
            if(changed && columns) {
                for(var x=0; x<columns.length; x++) {
                    if(columns[x].hidden != undefined) {
                        // toggle header once to workaround a display glitch
                        this.grid.columns[x].setVisible(columns[x].hidden);
                        this.grid.columns[x].setVisible(!columns[x].hidden);
                    }
                    if(columns[x].width != undefined) {
                        this.grid.columns[x].setWidth(columns[x].width);
                    }
                }
            }
        }
    }
});


Ext.define('TP.PanletGrid', {
    extend: 'TP.Panlet',

    title:  'grid',
    width:   640,
    height:  260,
    initComponent: function() {
        var panel = this;
        this.callParent();
        this.xdata.pageSize    = 5;
        this.xdata.currentPage = 1;
        this.xdata.totalCount  = 1;

        this.loader         = Ext.create('TP.GridLoader', { scope: this });
        var groupingFeature = Ext.create('Ext.grid.feature.Grouping',{
            groupHeaderTpl: '{name}'
        });
        this.pagingToolbar  = new TP.PagingToolbar({panel: this});

        if(this.grid_sort == undefined) {
            this.grid_sort = true;
        }
        if(this.grid_columns == undefined) {
            this.grid_columns = true;
        }
        /* do not change the columns in readonly mode */
        if(panel.locked) {
            this.grid_sort    = false;
            this.grid_columns = false;
        }

        this.grid = Ext.create('Ext.grid.Panel', {
            store:        this.gridStore,
            features:    [groupingFeature],
            id:           this.id + '_gridpanel',
            cls:          this.$className.replace('.', '_'),
            stateful:     true,
            stateEvents: ['reconfigure', 'afterlayout', 'columnmove', 'columnresize', 'sortchange', 'groupchange'],
            sortableColumns:    this.grid_sort,
            enableColumnResize: this.grid_columns,
            enableColumnHide:   this.grid_columns,
            enableColumnMove:   this.grid_columns,
            listeners: {
                beforestatesave: function(This, state, eOpts) {
                    /* only save filled grids state */
                    if(This.columns.length == 0 || TP.initialized == false) {
                        return false;
                    }
                    var panlet = This.up('panel');
                    panlet.xdata.gridstate = state;
                    if(panlet.grid.store.groupers.length == 1) {
                        panlet.xdata.groupField = panlet.grid.store.groupers.get(0).property;
                    } else {
                        panlet.xdata.groupField = undefined;
                    }

                    // save columns width explitcitly
                    for(var x=0; x<panlet.grid.columns.length; x++) {
                        if(!panlet.grid.columns[x].isHidden()) {
                            var width = panlet.grid.columns[x].getWidth();
                            // width is 1 if not yet completly rendered and we don't want to store that
                            // width is 0 if the settings window is open
                            if(width > 1) {
                                state.columns[x].width = width;
                            }
                        }
                    }

                    panlet.saveState();
                    return false;
                },
                resize: function(This, adjWidth, adjHeight, eOpts) {
                    this.adjustPageSize();
                },
                beforeselect: function(This, record, index, eOpts) {
                    /* prevent selections */
                    return false;
                }
            },
            adjustPageSize: function() {
                var panlet      = this.up('panel');
                var panletBody  = Ext.get(panlet.id + '_gridpanel-body');
                if(panletBody) {
                    var bodySize    = panletBody.getSize();
                    if(bodySize.height > 2) {
                        panlet.xdata.pageSize = Math.floor(bodySize.height / 25.5);
                        if(panlet.xdata.pageSize <= 0) { panlet.xdata.pageSize = 1; }
                    }
                }
                panlet.refreshHandler();
            },
            columns: [],
            dockedItems: [this.pagingToolbar]
        });
        var state = TP.cp.get(this.id);
        if(state && state.xdata && state.xdata.gridstate) {
            this.initialState = Ext.JSON.decode(Ext.JSON.encode(state.xdata.gridstate));
        }

        this.add(this.grid);

        this.addListener('afterrender', function() {
            this.grid.adjustPageSize();
        });
    },
    setGearItems: function() {
        var panel = this;
        this.callParent();
        this.addGearItems({
            fieldLabel: 'URL',
            xtype:      'textfield',
            name:       'url'
        });
    }
});
