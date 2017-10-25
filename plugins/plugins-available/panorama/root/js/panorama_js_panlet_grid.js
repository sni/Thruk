Ext.define('TP.GridLoader', {
    extend: 'Ext.ComponentLoader',

    autoLoad: false,
    renderer: 'data',
    url:      '',
    ajaxOptions: { method: 'POST' },
    loading:  false,
    listeners: {
        'beforeload': function(This, options, eOpts) {
            var panel = This.target;
            if(panel.loading) {
                return false;
            }
            panel.loading = true;
            return true;
        },
        'load': function(This, response, options, eOpts) {
            var panel = This.target;
            if(panel && panel.body) {
                panel.unmask();
            }
        }
    },
    callback: function(This, success, response, options) {
        var panel     = This.target;
        panel.loading = false;
        var data = TP.getResponse(panel, response);
        if(!data) { return; }

        TP.log('['+panel.id+'] loaded');

        /* column state is not recognized, so set it here */
        if(panel.xdata && panel.xdata.gridstate) {
            TP.applyColumns(data.columns, panel.xdata.gridstate);
        } else {
            TP.applyColumns(data.columns, panel.initialState);
        }

        var newcolumns = Ext.JSON.encode(data.columns);
        var fields     = TP.extractDataFields(panel, data);

        var columnsChanged = false;
        if(panel.gridcolumns == undefined || panel.gridcolumns != newcolumns) {
            panel.gridcolumns = newcolumns;
            columnsChanged = true;
        }

        // replace data only if columns haven't changed (does not work in IE11, panel will be blank afterwards)
        if(!Ext.isIE && !columnsChanged && panel.gridStore) {
            panel.gridStore.loadData(data.data);
            if(panel.pagingToolbar) {
                panel.pagingToolbar.onLoad();
            }
            return;
        }

        if(panel.xdata == undefined) { panel.xdata = { pageSize: 20 }; }
        var gridStore = Ext.create('Ext.data.Store', {
            data:  {'items': data.data },
            fields: fields,
            pageSize: panel.xdata.pageSize,
            proxy: {
                type: 'memory',
                reader: {
                    type: 'json',
                    root: 'items'
                }
            },
            groupField: panel.xdata.groupField != undefined ? panel.xdata.groupField : data.group
        });

        if(This.reconfigure) {
            if(panel.grid && (!panel.grid.headerCt || !panel.grid.headerCt.up('[store]') || !panel.grid.headerCt.up('[store]').store)) {
                /* make sure store still exists, may have been closed meanwhile */
                return;
            }
            /* panel.reconfigure throws internal error sometimes */
            try {
                panel.reconfigure(gridStore, data.columns);
            } catch(err) {
                //TP.logError(panel.id, "panelReconfigureException", err);
            }
            return;
        }

        var pagingToolbar   = new TP.PagingToolbar({panel: panel});
        var groupingFeature = Ext.create('Ext.grid.feature.Grouping',{
            groupHeaderTpl: '{name}'
        });
        var grid = Ext.create('Ext.grid.Panel', {
            store:        gridStore,
            features:    [groupingFeature],
            id:           panel.id + '_gridpanel',
            cls:          panel.$className.replace('.', '_'),
            stateful:     true,
            stateEvents: ['reconfigure', 'afterlayout', 'columnmove', 'columnresize', 'sortchange', 'groupchange'],
            sortableColumns:    panel.grid_sort,
            enableColumnResize: panel.grid_columns,
            enableColumnHide:   panel.grid_columns,
            enableColumnMove:   panel.grid_columns,
            listeners: {
                beforestatesave: function(This, state, eOpts) {
                    /* only save filled grids state */
                    if(This.columns.length == 0 || TP.initialized == false) {
                        return false;
                    }
                    panel.xdata.gridstate = state;
                    if(panel.grid.store.groupers.length == 1) {
                        panel.xdata.groupField = panel.grid.store.groupers.get(0).property;
                    } else {
                        panel.xdata.groupField = undefined;
                    }

                    // save columns width explitcitly
                    for(var x=0; x<panel.grid.columns.length; x++) {
                        if(!panel.grid.columns[x].isHidden()) {
                            var width = panel.grid.columns[x].getWidth();
                            // width is 1 if not yet completly rendered and we don't want to store that
                            // width is 0 if the settings window is open
                            if(width > 1) {
                                state.columns[x].width = width;
                            }
                            state.columns[x].hidden = false;
                        } else {
                            state.columns[x].hidden = true;
                        }
                    }

                    panel.saveState();
                    return false;
                },
                resize: function(This, adjWidth, adjHeight, eOpts) {
                    This.adjustPageSize();
                },
                beforeselect: function(This, record, index, eOpts) {
                    /* prevent selections */
                    return false;
                }
            },
            adjustPageSize: function() {
                var panletBody  = Ext.get(panel.id + '_gridpanel-body');
                if(panletBody) {
                    var bodySize    = panletBody.getSize();
                    if(bodySize.height > 2) {
                        panel.xdata.pageSize = Math.floor(bodySize.height / 22);
                        if(panel.xdata.pageSize <= 0) { panel.xdata.pageSize = 1; }
                    }
                }
                if(panel.refreshHandler) {
                    panel.refreshHandler();
                }
            },
            columns: data.columns,
            dockedItems: [pagingToolbar]
        });
        if(panel.grid) {
            panel.remove(panel.grid);
        }
        panel.grid          = grid;
        panel.gridStore     = gridStore;
        panel.pagingToolbar = pagingToolbar;
        panel.add(panel.grid);

        TP.setPagingToolbarVisibility(panel, pagingToolbar, data);

        if(panel.xdata.gridstate != undefined) {
            /* applyState throws internal error but state gets applied anyway */
            try {
                grid.applyState(panel.xdata.gridstate);
            } catch(err) {
                //TP.logError(panel.id, "gridApplyStateException", err);
            }
        }
        else if(panel.initialState != undefined) {
            /* applyState throws internal error but state gets applied anyway */
            try {
                grid.applyState(this.initialState);
            } catch(err) {
                //TP.logError(panel.id, "gridApplyStateException", err);
            }
        }

        panel.loading = false;
        return;
    }
});


Ext.define('TP.PanletGrid', {
    extend: 'TP.Panlet',

    title:  'grid',
    width:   640,
    height:  260,
    initComponent: function() {
        var panel = this;
        panel.callParent();
        panel.xdata.pageSize    = 5;
        panel.xdata.currentPage = 1;
        panel.xdata.totalCount  = 1;

        panel.loader        = Ext.create('TP.GridLoader', { scope: panel });

        if(panel.grid_sort == undefined) {
            panel.grid_sort = true;
        }
        if(panel.grid_columns == undefined) {
            panel.grid_columns = true;
        }
        /* do not change the columns in readonly mode */
        if(panel.locked) {
            panel.grid_sort    = false;
            panel.grid_columns = false;
        }

        var state = TP.cp.get(panel.id);
        if(state && state.xdata && state.xdata.gridstate) {
            panel.initialState = Ext.JSON.decode(Ext.JSON.encode(state.xdata.gridstate));
        }

        panel.addListener('afterrender', function() {
            panel.refreshHandler();
        });
    },
    setGearItems: function() {
        var panel = this;
        panel.callParent();
        panel.addGearItems({
            fieldLabel: 'URL',
            xtype:      'textfield',
            name:       'url'
        });
    }
});

TP.extractDataFields = function(panel, data) {
    var fields = [];
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
    return(fields);
};

TP.setPagingToolbarVisibility = function(panel, pagingToolbar, data) {
    var b = Ext.get(panel.grid.id+"-body");
    var body;
    if(b) { body = b.dom.firstChild }
    if(data.paging) {
        if(pagingToolbar) {
            pagingToolbar.show();
            if(pagingToolbar.items.getAt(9)) {
                pagingToolbar.items.getAt(9).hide();  // hide seperator
                pagingToolbar.items.getAt(10).hide(); // hide refresh
            }
            pagingToolbar.updateData(data);
            pagingToolbar.onLoad();
            if(pagingToolbar.getPageData().pageCount == 1) {
                pagingToolbar.hide();
            }
        }
        if(body) {
            try {
                body.style.overflow  = 'inherit';
                body.style.overflowY = 'hidden';
            } catch(err) {
                // breaks in IE 8 sometimes
                TP.log("thruk: setting style failed")
                TP.logError(panel.id, "bodyStyleException", err);
            }
        }
    } else {
        if(pagingToolbar) {
            pagingToolbar.hide();
        }
        if(body) {
            try {
                body.style.overflowY = 'inherit';
                body.style.overflow  = 'auto';
            } catch(err) {
                // breaks in IE 8 sometimes
                TP.log("thruk: setting style failed")
                TP.logError(panel.id, "bodyStyleException", err);
            }
        }
    }
};

TP.applyColumns = function(columns, state) {
    if(!state || !state.columns) {
        return;
    }
    for(var x = 0; x < columns.length; x++) {
        if(state.columns[x] && state.columns[x].width) {
            columns[x].width = state.columns[x].width;
        }
        if(state.columns[x] && state.columns[x].hidden != undefined) {
            columns[x].hidden = state.columns[x].hidden;
        }
    }
    return;
};
