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
        if(key == 'tabbar') { data.tabbar = anyDecode(state[key]); }

        // dashboard main data
        if(key.search(/pantab_\d+$/) != -1) {
            if(data[key] == undefined) { data[key] = {}; }
            data[key].tab = state[key];

            // allow import of old data
            var tmp = anyDecode(state[key]);
            if(tmp.window_ids) {
                for(var x = 0; x<tmp.window_ids.length;x++) {
                    var win_id = tmp.window_ids[x];
                    data[key][win_id] = state[win_id];
                    delete state[win_id];
                }
                // remove keys not required to be saved
                delete tmp['window_ids'];
                data[key].id  = 'new';
                data[key].tab = Ext.JSON.encode(tmp);
            }
        }

        // panels data
        var matches = key.match(/(pantab_\d+)_(.*)$/);
        if(matches) {
            var tab_id = matches[1];
            if(data[tab_id] == undefined) { data[tab_id] = {}; }
            data[tab_id][key] = anyDecode(state[key]);
        }
    }
    return(data);
}

/* extends state provider by saving states via http */
Ext.state.HttpProvider = function(config){
    Ext.state.HttpProvider.superclass.constructor.call(this);
    this.url             = '';
    this.saveDelay       = 500;
    this.isSaving        = false;
    this.isSavingCounter = 0;
    this.state           = {};
    Ext.apply(this, config);
};

Ext.extend(Ext.state.HttpProvider, Ext.state.Provider, {
    /* retrieve value by name with optional fallback value */
    get: function(name, defaultValue) {
        var val = this.state[name];
        if(val == undefined) {
            return(defaultValue);
        }
        return(TP.clone(val));
    },

    /* set value by name */
    set: function(name, value, save) {
        if(typeof value == "undefined" || value === null) {
            this.clear(name);
            return;
        }
        this.state[name] = TP.clone(value); // clone to preserve value from being changed by reference
        Ext.state.HttpProvider.superclass.set.call(this, name, value);
        if(save == undefined || save) {
            this.queueChanges();
        }
    },

    /* removes value by name */
    clear: function(name) {
        delete this.state[name];
        this.queueChanges();
        Ext.state.HttpProvider.superclass.clear.call(this, name);
    },

    /* set state from object */
    loadData: function(data) {
        var cp = this;
        cp.state = {};
        for(var key in data) {
            cp.set(key, data[key], false);
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
        var data = setStateByTab(cp.state);
        if(!cp.lastdata) {
            /* set initial data which we can later check against to reduce number of update querys */
            cp.lastdata = data;
            return;
        }

        var params  = {};
        var changed = 0;
        for(var key in data) {
            if(cp.lastdata[key] != null && !TP.JSONequals(cp.lastdata[key], data[key])) {
                params[key] = Ext.JSON.encode(data[key]);
                changed++;
            }
        }
        cp.lastdata = data;
        if(changed == 0) { return; }
        params.task   = 'update2';
        if(extraParams) {
            Ext.apply(params, extraParams);
        }
        if(Ext.getCmp('tabbar').getActiveTab()) {
            params.current_tab = Ext.getCmp('tabbar').getActiveTab().id;
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
                cp.isSaving = (cp.isSavingCounter > 0);
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
                if(callback) { callback(response, opts); }
            },
            failure: function(response, opts) {
                cp.isSavingCounter--;
                cp.isSaving = (cp.isSavingCounter > 0);
                TP.log('[global] state provider failed to save changes to server');
                TP.Msg.msg("fail_message~~saving changes failed: "+response.status+' - '+response.statusText+'<br>please have a look at the server logfile.');
                if(callback) { callback(response, opts); }
            }
        });
    }
});

function anyDecode(data) {
    if(Ext.isString(data) && data.length > 1 && (data.substring(0,1) == "{" || data.substring(0,1) == "[")) {
        return(Ext.JSON.decode(data));
    }
    return(data);
}
