/*
 * Copyright (c) 2008-2014 The Open Source Geospatial Foundation
 *
 * Published under the BSD license.
 * See https://github.com/geoext/geoext2/blob/master/license.txt for the full
 * text of the license.
 */

/*
 * @requires GeoExt/data/LayerModel.js
 */

/**
 * A store that synchronizes a layers array of an OpenLayers.Map with a
 * layer store holding {@link GeoExt.data.LayerModel} instances.
 *
 * @class GeoExt.data.LayerStore
 */
Ext.define('GeoExt.data.LayerStore', {
    requires: ['GeoExt.data.LayerModel'],
    extend: 'Ext.data.Store',
    model: 'GeoExt.data.LayerModel',

    statics: {
        /**
         * Direction: Map to store
         *
         * @static
         * @property {Number}
         */
        MAP_TO_STORE: 1,
        /**
         * Direction: Store to map
         *
         * @static
         * @property {Number}
         */
        STORE_TO_MAP: 2
    },

    /**
     * Fires when the store is bound to a map.
     *
     * @event bind
     * @param {GeoExt.data.LayerStore} store
     * @param {OpenLayers.Map} map
     */

    /**
     * Map that this store will be in sync with. If not provided, the
     * store will not be bound to a map.
     *
     * @cfg {OpenLayers.Map/GeoExt.panel.Map/Object} map
     */

    /**
     * Map that the store is synchronized with, if any.
     *
     * @property {OpenLayers.Map/Object} map
     */
    map: null,

    /**
     * Layers that will be added to the store (and the map, depending on the
     * value of the `initDir` option.
     *
     * @cfg {OpenLayers.Layer/Array} layers
     */

    /**
     *
     * Bitfields specifying the direction to use for the initial sync between
     * the map and the store, if set to 0 then no initial sync is done.
     * Defaults to #MAP_TO_STORE | #STORE_TO_MAP.
     *
     * @cfg {Number} initDir
     */

    /**
     * @param {Object} config Creation parameters.
     * @private
     */
    constructor: function(config) {
        var me = this;

        config = Ext.apply({}, config);

        // "map" option
        var map = (GeoExt.MapPanel && config.map instanceof GeoExt.MapPanel) ?
            config.map.map : config.map;
        delete config.map;

        // "layers" option - is an alias to "data" option
        if(config.layers) {
            config.data = config.layers;
        }
        delete config.layers;

        // "initDir" option
        var options = {initDir: config.initDir};
        delete config.initDir;

        me.callParent([config]);

        if(map) {
            this.bind(map, options);
        }
    },

    /**
     * Bind this store to a map instance, once bound the store
     * is synchronized with the map and vice-versa.
     *
     * @param {OpenLayers.Map} map The map instance.
     * @param {Object} options
     */
    bind: function(map, options) {
        var me = this;

        if(me.map) {
            // already bound
            return;
        }
        me.map = map;
        options = Ext.apply({}, options);

        var initDir = options.initDir;
        if(options.initDir == undefined) {
            initDir = GeoExt.data.LayerStore.MAP_TO_STORE |
                GeoExt.data.LayerStore.STORE_TO_MAP;
        }

        // create a snapshot of the map's layers
        var layers = map.layers.slice(0);

        if(initDir & GeoExt.data.LayerStore.STORE_TO_MAP) {
            me.each(function(record) {
                me.map.addLayer(record.getLayer());
            }, me);
        }
        if(initDir & GeoExt.data.LayerStore.MAP_TO_STORE) {
            me.loadRawData(layers, true);
        }

        map.events.on({
            "changelayer": me.onChangeLayer,
            "addlayer": me.onAddLayer,
            "removelayer": me.onRemoveLayer,
            scope: me
        });
        me.on({
            "load": me.onLoad,
            "clear": me.onClear,
            "add": me.onAdd,
            "remove": me.onRemove,
            "update": me.onStoreUpdate,
            scope: me
        });
        me.data.on({
            "replace" : me.onReplace,
            scope: me
        });
        me.fireEvent("bind", me, map);
    },

    /**
     * Unbind this store from the map it is currently bound.
     */
    unbind: function() {
        var me = this;

        if(me.map) {
            me.map.events.un({
                "changelayer": me.onChangeLayer,
                "addlayer": me.onAddLayer,
                "removelayer": me.onRemoveLayer,
                scope: me
            });
            me.un("load", me.onLoad, me);
            me.un("clear", me.onClear, me);
            me.un("add", me.onAdd, me);
            me.un("remove", me.onRemove, me);
            me.un("update", me.onStoreUpdate, me);

            me.data.un("replace", me.onReplace, me);

            me.map = null;
        }
    },

    /**
     * Handler for layer changes.  When layer order changes, this moves the
     * appropriate record within the store.
     *
     * @param {Object} evt
     * @private
     */
    onChangeLayer: function(evt) {
        var layer = evt.layer;
        var recordIndex = this.findBy(function(rec, id) {
            return rec.getLayer() === layer;
        });
        if(recordIndex > -1) {
            var record = this.getAt(recordIndex);
            if(evt.property === "order") {
                if(!this._adding && !this._removing) {
                    var layerIndex = this.map.getLayerIndex(layer);
                    if(layerIndex !== recordIndex) {
                        this._removing = true;
                        this.remove(record);
                        delete this._removing;
                        this._adding = true;
                        this.insert(layerIndex, [record]);
                        delete this._adding;
                    }
                }
            } else if(evt.property === "name") {
                record.set("title", layer.name);
            } else {
                this.fireEvent("update", this, record, Ext.data.Record.EDIT);
            }
        }
    },

    /**
     * Handler for a map's addlayer event.
     *
     * @param {Object} evt
     * @private
     */
    onAddLayer: function(evt) {
        var me = this;
        if(!me._adding) {
            me._adding = true;
            var result  = me.proxy.reader.read(evt.layer);
            me.add(result.records);
            delete me._adding;
        }
    },

    /**
     * Handler for a map's removelayer event.
     *
     * @param {Object} evt
     * @private
     */
    onRemoveLayer: function(evt){
        //TODO replace the check for undloadDestroy with a listener for the
        // map's beforedestroy event, doing unbind(). This can be done as soon
        // as http://trac.openlayers.org/ticket/2136 is fixed.
        if(this.map.unloadDestroy) {
            if(!this._removing) {
                var layer = evt.layer,
                    rec = this.getByLayer(layer);
                if (rec) {
                    this._removing = true;
                    this.remove(this.getByLayer(layer));
                    delete this._removing;
                }
            }
        } else {
            this.unbind();
        }
    },

    /**
     * Handler for a store's load event.
     *
     * @param {Ext.data.Store} store
     * @param {Ext.data.Model[]} records
     * @param {Boolean} successful
     * @private
     */
    onLoad: function(store, records, successful) {
        if (successful) {
            if (!Ext.isArray(records)) {
                records = [records];
            }
            if(!this._addRecords) {
                this._removing = true;
                for (var i = this.map.layers.length - 1; i >= 0; i--) {
                    this.map.removeLayer(this.map.layers[i]);
                }
                delete this._removing;
            }
            var len = records.length;
            if (len > 0) {
                var layers = new Array(len);
                for (var j = 0; j < len; j++) {
                    layers[j] = records[j].getLayer();
                }
                this._adding = true;
                this.map.addLayers(layers);
                delete this._adding;
            }
        }
        delete this._addRecords;
    },

    /**
     * Handler for a store's clear event.
     *
     * @param {Ext.data.Store} store
     * @private
     */
    onClear: function(store) {
        this._removing = true;
        for (var i = this.map.layers.length - 1; i >= 0; i--) {
            this.map.removeLayer(this.map.layers[i]);
        }
        delete this._removing;
    },

    /**
     * Handler for a store's add event.
     *
     * @param {Ext.data.Store} store
     * @param {Ext.data.Model[]} records
     * @param {Number} index
     * @private
     */
    onAdd: function(store, records, index) {
        if(!this._adding) {
            this._adding = true;
            var layer;
            for(var i=records.length-1; i>=0; --i) {
                layer = records[i].getLayer();
                this.map.addLayer(layer);
                if(index !== this.map.layers.length-1) {
                    this.map.setLayerIndex(layer, index);
                }
            }
            delete this._adding;
        }
    },

    /**
     * Handler for a store's remove event.
     *
     * @param {Ext.data.Store} store
     * @param {Ext.data.Model} record
     * @param {Number} index
     * @private
     */
    onRemove: function(store, record, index){
        if(!this._removing) {
            var layer = record.getLayer();
            if (this.map.getLayer(layer.id) != null) {
                this._removing = true;
                this.removeMapLayer(record);
                delete this._removing;
            }
        }
    },

    /**
     * Handler for a store's update event.
     *
     * @param {Ext.data.Store} store
     * @param {Ext.data.Model} record
     * @param {Number} operation
     */
    onStoreUpdate: function(store, record, operation) {
        if(operation === Ext.data.Record.EDIT) {
            if (record.modified && record.modified.title) {
                var layer = record.getLayer();
                var title = record.get("title");
                if(title !== layer.name) {
                    layer.setName(title);
                }
            }
        }
    },

    /**
     * Removes a record's layer from the bound map.
     *
     * @param {Ext.data.Record} record
     * @private
     */
    removeMapLayer: function(record){
        this.map.removeLayer(record.getLayer());
    },

    /**
     * Handler for a store's data collections' replace event.
     *
     * @param {String} key
     * @param {Ext.data.Model} oldRecord In this case, a record that has
     *     been replaced.
     * @param {Ext.data.Model} newRecord In this case, a record that is
     *     replacing oldRecord.
     * @private
     */
    onReplace: function(key, oldRecord, newRecord){
        this.removeMapLayer(oldRecord);
    },

    /**
     * Get the record for the specified layer.
     *
     * @param {OpenLayers.Layer} layer
     * @returns {Ext.data.Model} or undefined if not found
     */
    getByLayer: function(layer) {
        var index = this.findBy(function(r) {
            return r.getLayer() === layer;
        });
        if(index > -1) {
            return this.getAt(index);
        }
    },

    /**
     * Unbinds listeners by calling #unbind prior to being destroyed.
     *
     * @private
     */
    destroy: function() {
        this.unbind();
        this.callParent();
    },

    /**
     * Overload loadRecords to set a flag if `addRecords` is `true`
     * in the load options. Ext JS does not pass the load options to
     * "load" callbacks, so this is how we provide that information
     * to `onLoad`.
     *
     * @private
     */
    loadRecords: function(records, options) {
        if(options && options.addRecords) {
            this._addRecords = true;
        }
        this.callParent(arguments);
    },

    /**
     * @inheritdoc
     *
     * The event firing behaviour of Ext.4.1 is reestablished here. See also:
     * [This discussion on the Sencha forum](http://www.sencha.com/forum/
     * showthread.php?253596-beforeload-is-not-fired-by-loadRawData)
     *
     * In version 4.2.1 this method reads
     *
     *     //...
     *     loadRawData : function(data, append) {
     *         var me      = this,
     *             result  = me.proxy.reader.read(data),
     *             records = result.records;
     *
     *         if (result.success) {
     *             me.totalCount = result.total;
     *             me.loadRecords(records, append ? me.addRecordsOptions : undefined);
     *         }
     *     },
     *     // ...
     *
     * While the previous version 4.1.3 has also
     * the line `me.fireEvent('load', me, records, true);`:
     *
     *     // ...
     *     if (result.success) {
     *         me.totalCount = result.total;
     *         me.loadRecords(records, append ? me.addRecordsOptions : undefined);
     *         me.fireEvent('load', me, records, true);
     *     }
     *     // ...
     *
     * Our overwritten method has the code from 4.1.3, so that the #load-event
     * is being fired.
     *
     * See also the source code of [version 4.1.3](http://docs-origin.sencha.
     * com/extjs/4.1.3/source/Store.html#Ext-data-Store-method-loadRawData) and
     * of [version 4.2.1](http://docs-origin.sencha.com/extjs/4.2.1/source/
     * Store.html#Ext-data-Store-method-loadRawData).
     */
    loadRawData : function(data, append) {
        var me      = this,
            result  = me.proxy.reader.read(data),
            records = result.records;

        if (result.success) {
            me.totalCount = result.total;
            me.loadRecords(records, append ? me.addRecordsOptions : undefined);
            me.fireEvent('load', me, records, true);
        }
    }
});
