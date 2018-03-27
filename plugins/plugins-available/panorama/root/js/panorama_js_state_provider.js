Object.my_equals = function( x, y ) {
    if ( x === y ) return true;
    // if both x and y are null or undefined and exactly the same

    if ( ! ( x instanceof Object ) || ! ( y instanceof Object ) ) return false;
    // if they are not strictly equal, they both need to be Objects

    if ( x.constructor !== y.constructor ) return false;
    // they must have the exact same prototype chain, the closest we can do is
    // test there constructor.

    for ( var key in x ) {
        if ( ! x.hasOwnProperty( key ) ) continue;
        // other properties were tested using x.constructor === y.constructor

        if ( ! y.hasOwnProperty( key ) ) return false;
        // allows to compare x[ key ] and y[ key ] when set to undefined

        if ( x[ key ] === y[ key ] ) continue;
        // if they have the same strict value or identity then they are equal

        if ( typeof( x[ key ] ) !== "object" ) return false;
        // Numbers, Strings, Functions, Booleans must be strictly equal

        if ( ! Object.my_equals( x[ key ],  y[ key ] ) ) return false;
        // Objects and Arrays must be tested recursively
    }

    for ( var key in y ) {
        if ( y.hasOwnProperty( key ) && ! x.hasOwnProperty( key ) ) return false;
        // allows x[ key ] to be set to undefined
    }
    return true;
}

/* combine settings by tab */
function setStateByTab(state) {
    state = TP.clone(state);
    var data = {};
    for(var key in state) {
        if(key == 'tabpan') { data.tabpan = Ext.JSON.decode(state[key]); }
        if(key.search(/tabpan-tab_\d+$/) != -1) {
            if(data[key] == undefined) { data[key] = {}; }
            data[key].tab = state[key];

            // allow import of old data
            var tmp = Ext.JSON.decode(state[key]);
            if(tmp.window_ids) {
                for(var x = 0; x<tmp.window_ids.length;x++) {
                    var win_id = tmp.window_ids[x];
                    data[key][win_id] = state[win_id];
                    delete state[win_id];
                }
                delete tmp['window_ids'];
                data[key].id  = 'new';
                data[key].tab = Ext.JSON.encode(tmp);
            }

        }
        var matches = key.match(/(tabpan-tab_\d+)_(.*)$/);
        if(matches) {
            var tab_id = matches[1];
            if(data[tab_id] == undefined) { data[tab_id] = {}; }
            data[tab_id][key] = Ext.JSON.decode(state[key]);
        }
    }
    return(data);
}

/* extends state provider by saving states via http */
Ext.state.HttpProvider = function(config){
    Ext.state.HttpProvider.superclass.constructor.call(this);
    this.url       = '';
    this.saveDelay = 500;
    this.isSaving = false;
    this.isSavingCounter = 0;
    Ext.apply(this, config);
    this.state = this.readValues();
};

Ext.extend(Ext.state.HttpProvider, Ext.state.Provider, {
    set: function(name, value) {
        if(typeof value == "undefined" || value === null) {
            this.clear(name);
            return;
        }
        this.setValue(name, value);
        Ext.state.HttpProvider.superclass.set.call(this, name, value);
    },

    clear: function(name) {
        this.clearValue(name);
        Ext.state.HttpProvider.superclass.clear.call(this, name);
    },

    /* read initial states */
    readValues: function() {
        var state = {};
        for (var key in ExtState) {
            if(key!='remove') {
                // new is json already
                try {
                    state[key] = Ext.JSON.decode(ExtState[key]);
                } catch(err) {
                    TP.Msg.msg("fail_message~~decode failed: "+err);
                }
            }
        }

        this.queueChanges();
        return state;
    },

    /* sets value by name */
    setValue: function(name, value) {
        encoded = Ext.JSON.encode(value);
        if(ExtState[name] != undefined && ExtState[name] == encoded) {
            return;
        }
        ExtState[name] = encoded;
        this.queueChanges();
    },

    /* removes value by name */
    clearValue: function(name) {
        delete ExtState[name];
        this.queueChanges();
    },

    /* clear all values */
    clearAll: function() {
        for(var key in ExtState) {
            this.clear(key);
        }
        this.saveChanges();
    },

    /* set state from object */
    loadData: function(data, save) {
        if(save == undefined) { save = true; }
        ExtState = {};
        for(var key in data) {
            this.set(key, data[key]);
            ExtState[key] = Ext.JSON.encode(data[key]);
        }
        if(save) {
            this.saveChanges();
        }
    },

    /* queue save changes */
    queueChanges: function() {
        window.clearTimeout(TP.timeouts['timeout_stateprovider_savedelay']);
        TP.timeouts['timeout_stateprovider_savedelay'] = window.setTimeout(Ext.bind(this.saveChanges, this, []), this.saveDelay);
    },

    /* send changes back to server */
    saveChanges: function(extraParams, callback) {
        var cp = this;
        if(readonly || dashboard_ignore_changes) { return; }
        if(!TP.initialized) { cp.queueChanges(); return; }

        /* seperate state by dashboards */
        var data = setStateByTab(ExtState);
        if(!cp.lastdata) {
            /* set initial data which we can later check against to reduce number of update querys */
            cp.lastdata = data;
            return;
        }
        var params  = {};
        var changed = 0;
        for(var key in data) {
            var encoded1 = Ext.JSON.encode(cp.lastdata[key]);
            var encoded2 = Ext.JSON.encode(data[key]);
            if(cp.lastdata[key] != null && !TP.JSONequals(encoded1, encoded2)) {
                params[key] = encoded2;
                changed++;
            }
        }
        cp.lastdata = data;
        if(changed == 0) { return; }
        params.task   = 'update2';
        if(extraParams) {
            Ext.apply(params, extraParams);
        }
        if(Ext.getCmp('tabpan').getActiveTab()) {
            params.current_tab = Ext.getCmp('tabpan').getActiveTab().id;
        }

        if(!TP.stateSaveImage) {
            TP.stateSaveImage = Ext.create('Ext.Img', {
                src:      url_prefix+'plugins/panorama/images/disk.png',
                autoEl:  'div',
                floating: true,
                shadow:   false,
                title:   'saving...',
                renderTo: Ext.getBody()
            });
        }
        TP.stateSaveImage.showAt(Ext.getBody().getSize().width - 30, 35);
        TP.timeouts['timeout_stateprovider_saveimagedetroy'] = window.setTimeout(function() {
            TP.stateSaveImage.hide();
        }, 1500);

        cp.isSavingCounter++;
        cp.isSaving = true;
        var conn    = new Ext.data.Connection();
        conn.request({
            url:    cp.url,
            params: params,
            success: function(response, opts) {
                cp.isSavingCounter--;
                cp.isSaving = (cp.isSavingCounter == 0);
                TP.log('[global] state provider saved to server');
                TP.timeouts['timeout_stateprovider_saveimagedetroy'] = window.setTimeout(function() {
                    TP.stateSaveImage.hide();
                }, 500);

                /* allow response to contain cookie messages */
                TP.getResponse(undefined, response, false, true);

                /* refresh dashboard manager */
                if(TP.dashboardsSettingGrid && TP.dashboardsSettingGrid.loader) {
                    TP.dashboardsSettingGrid.loader.load();
                }
                if(callback) { callback(refresh, opts); }
            },
            failure: function(response, opts) {
                cp.isSavingCounter--;
                cp.isSaving = (cp.isSavingCounter == 0);
                TP.log('[global] state provider failed to save changes to server');
                TP.Msg.msg("fail_message~~saving changes failed: "+response.status+' - '+response.statusText+'<br>please have a look at the server logfile.');
                if(callback) { callback(refresh, opts); }
            }
        });
    }
});
