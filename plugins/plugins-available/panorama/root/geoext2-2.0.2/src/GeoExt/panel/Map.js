/*
 * Copyright (c) 2008-2014 The Open Source Geospatial Foundation
 *
 * Published under the BSD license.
 * See https://github.com/geoext/geoext2/blob/master/license.txt for the full
 * text of the license.
 */

/*
 * @requires GeoExt/data/LayerStore.js
 * @include OpenLayers/Map.js
 */

/**
 * Create a panel container for a map. The map contained by this panel
 * will initially be zoomed to either the center and zoom level configured
 * by the `center` and `zoom` configuration options, or the configured
 * `extent`, or - if neither are provided - the extent returned by the
 * map's `getExtent()` method.
 *
 * Example:
 *
 *     var mappanel = Ext.create('GeoExt.panel.Map', {
 *         title: 'A sample Map',
 *         map: {
 *             // ...
 *             // optional, can be either
 *             //   - a valid OpenLayers.Map configuration or
 *             //   - an instance of OpenLayers.Map
 *         },
 *         center: '12.31,51.48',
 *         zoom: 6
 *     });
 *
 * A Map created with code like above is then ready to use as any other panel.
 * To have a fullscreen map application, you could e.g. add it to a viewport:
 *
 * Example:
 *
 *     Ext.create('Ext.container.Viewport', {
 *         layout: 'fit',
 *         items: [
 *             mappanel // our variable from above
 *         ]
 *     });
 *
 * @class GeoExt.panel.Map
 */
Ext.define('GeoExt.panel.Map', {
    extend: 'Ext.panel.Panel',
    requires: [
        'GeoExt.data.LayerStore'
    ],
    alias: 'widget.gx_mappanel',
    alternateClassName: 'GeoExt.MapPanel',

    statics: {
        /**
         * The first map panel found via an the Ext.ComponentQuery.query
         * manager.
         *
         * Convenience function for guessing the map panel of an application.
         * This can reliably be used for all applications that just have one map
         * panel in the viewport.
         *
         * @return {GeoExt.panel.Map}
         * @static
         */
        guess : function() {
            var candidates = Ext.ComponentQuery.query("gx_mappanel");
            return ((candidates && candidates.length > 0)
                ? candidates[0]
                : null);
        }
    },

    /**
     * A location for the initial map center.  If an array is provided, the
     * first two items should represent x & y coordinates. If a string is
     * provided, it should consist of a x & y coordinate seperated by a
     * comma.
     *
     * @cfg {OpenLayers.LonLat/Number[]/String} center
     */
    center: null,

    /**
     * An initial zoom level for the map.
     *
     * @cfg {Number} zoom
     */
    zoom: null,

    /**
     * An initial extent for the map (used if center and zoom are not
     * provided.  If an array, the first four items should be minx, miny,
     * maxx, maxy.
     *
     * @cfg {OpenLayers.Bounds/Number[]} extent
     */
    extent: null,

    /**
     * Set this to true if you want pretty strings in the MapPanel's state
     * keys. More specifically, layer.name instead of layer.id will be used
     * in the state keys if this option is set to true. But in that case
     * you have to make sure you don't have two layers with the same name.
     * Defaults to false.
     *
     * @cfg {Boolean} prettyStateKeys
     */
    /**
     * Whether we want the state key to be pretty. See
     * {@link #cfg-prettyStateKeys the config option prettyStateKeys} for
     * details.
     *
     * @property {Boolean} prettyStateKeys
     */
    prettyStateKeys: false,

    /**
     * A configured map or a configuration object for the map constructor.
     * A configured map will be available after construction through the
     * {@link GeoExt.panel.Map#property-map} property.
     *
     * @cfg {OpenLayers.Map/Object} map
     */
    /**
     * A map or map configuration.
     *
     * @property {OpenLayers.Map/Object} map
     */
    map: null,

    /**
     * In order for child items to be correctly sized and positioned,
     * typically a layout manager must be specified through the layout
     * configuration option.
     *
     * @cfg {OpenLayers.Map/Object} layout
     */
    /**
     * A layout or layout configuration.
     *
     * @property {OpenLayers.Map/Object} layout
     */
    layout: 'fit',

    /**
     * The layers provided here will be added to this Map's
     * {@link #property-map}.
     *
     * @cfg {GeoExt.data.LayerStore/OpenLayers.Layer[]} layers
     */
    /**
     * A store containing {@link GeoExt.data.LayerModel gx_layer-model}
     * instances.
     *
     * @property {GeoExt.data.LayerStore} layers
     */
    layers: null,

    /**
     * Array of state events.
     *
     * @property {String[]} stateEvents
     * @private
     */
    stateEvents: [
        "aftermapmove",
        "afterlayervisibilitychange",
        "afterlayeropacitychange",
        "afterlayerorderchange",
        "afterlayernamechange",
        "afterlayeradd",
        "afterlayerremove"
    ],

    /**
     * Whether we already rendered an OpenLayers.Map in this panel. Will be
     * updated in #onResize, after the first rendering happened.
     *
     * @property {Boolean} mapRendered
     * @private
     */
    mapRendered: false,

    /**
     * Initializes the map panel. Creates an OpenLayers map if
     * none was provided in the config options passed to the
     * constructor.
     *
     * @private
     */
    initComponent: function(){
        if(!(this.map instanceof OpenLayers.Map)) {
            this.map = new OpenLayers.Map(
                Ext.applyIf(this.map || {}, {
                    allOverlays: true,
                    fallThrough: true
                })
            );
        }

        var layers  = this.layers;
        if(!layers || layers instanceof Array) {
            this.layers = Ext.create('GeoExt.data.LayerStore', {
                layers: layers,
                map: this.map.layers.length > 0 ? this.map : null
            });
        }

        if (Ext.isString(this.center)) {
            this.center = OpenLayers.LonLat.fromString(this.center);
        } else if(Ext.isArray(this.center)) {
            this.center = new OpenLayers.LonLat(this.center[0], this.center[1]);
        }
        if (Ext.isString(this.extent)) {
            this.extent = OpenLayers.Bounds.fromString(this.extent);
        } else if(Ext.isArray(this.extent)) {
            this.extent = OpenLayers.Bounds.fromArray(this.extent);
        }

        this.callParent(arguments);

        // The map is renderer and its size is updated when we receive
        // "resize" events.
        this.on('resize', this.onResize, this);

        //TODO This should be handled by a LayoutManager
        this.on("afterlayout", function() {
            //TODO remove function check when we require OpenLayers > 2.11
            if (typeof this.map.getViewport === "function") {
                this.items.each(function(cmp) {
                    if (typeof cmp.addToMapPanel === "function") {
                        cmp.getEl().appendTo(this.body);
                    }
                }, this);
            }
        }, this);

        /**
         * Fires after the map is moved.
         *
         * @event aftermapmove
         */
        /**
         * Fires after a layer changed visibility.
         *
         * @event afterlayervisibilitychange
         */
        /**
         * Fires after a layer changed opacity.
         *
         * @event afterlayeropacitychange
         */
        /**
         * Fires after a layer order changed.
         *
         * @event afterlayerorderchange
         */
        /**
         * Fires after a layer name changed.
         *
         * @event afterlayernamechange
         */
        /**
         * Fires after a layer added to the map.
         *
         * @event afterlayeradd
         */
        /**
         * Fires after a layer removed from the map.
         *
         * @event afterlayerremove
         */

        // bind various listeners to the corresponding OpenLayers.Map-events
        this.map.events.on({
            "moveend": this.onMoveend,
            "changelayer": this.onChangelayer,
            "addlayer": this.onAddlayer,
            "removelayer": this.onRemovelayer,
            scope: this
        });
    },

    /**
     * The "moveend" listener bound to the
     * {@link GeoExt.panel.Map#property-map}.
     *
     * @param {Object} e
     * @private
     */
    onMoveend: function(e) {
        this.fireEvent("aftermapmove", this, this.map, e);
    },

    /**
     * The "changelayer" listener bound to the
     * {@link GeoExt.panel.Map#property-map}.
     *
     * @param {Object} e
     * @private
     */
    onChangelayer: function(e) {
        var map = this.map;
        if (e.property) {
            if (e.property === "visibility") {
                this.fireEvent("afterlayervisibilitychange", this, map, e);
            } else if (e.property === "order") {
                this.fireEvent("afterlayerorderchange", this, map, e);
            } else if (e.property === "nathis") {
                this.fireEvent("afterlayernathischange", this, map, e);
            } else if (e.property === "opacity") {
                this.fireEvent("afterlayeropacitychange", this, map, e);
            }
        }
    },

    /**
     * The "addlayer" listener bound to the
     * {@link GeoExt.panel.Map#property-map}.
     *
     * @param {Object} e
     * @private
     */
    onAddlayer: function() {
        this.fireEvent("afterlayeradd");
    },

    /**
     * The "removelayer" listener bound to the
     * {@link GeoExt.panel.Map#property-map}.
     *
     * @param {Object} e
     * @private
     */
    onRemovelayer: function() {
        this.fireEvent("afterlayerremove");
    },

    /**
     * Private method called after the panel has been rendered or after it
     * has been laid out by its parent's layout.
     *
     * @private
     */
    onResize: function() {
        var map = this.map;
        if(!this.mapRendered && this.body.dom !== map.div) {
            // the map has not been rendered yet
            map.render(this.body.dom);
            this.mapRendered = true;

            this.layers.bind(map);

            if (map.layers.length > 0) {
                this.setInitialExtent();
            } else {
                this.layers.on("add", this.setInitialExtent, this,
                               {single: true});
            }
        } else {
            map.updateSize();
        }
    },

    /**
     * Set the initial extent of this panel's map.
     *
     * @private
     */
    setInitialExtent: function() {
        var map = this.map;
        if (!map.getCenter()) {
            if (this.center || this.zoom ) {
                // center and/or zoom?
                map.setCenter(this.center, this.zoom);
            } else if (this.extent instanceof OpenLayers.Bounds) {
                // extent
                map.zoomToExtent(this.extent, true);
            }else {
                map.zoomToMaxExtent();
            }
        }
    },

    /**
     * Returns a state of the Map as keyed Object. Depending on the point in
     * time this method is being called, the following keys will be available:
     *
     * * `x`
     * * `y`
     * * `zoom`
     *
     * And for all layers present in the map the object will contain the
     * following keys
     *
     * * `visibility_<XXX>`
     * * `opacity_<XXX>`
     *
     * The &lt;XXX&gt; suffix is either the title or id of the layer record, it
     * can be influenced by setting #prettyStateKeys to `true` or `false`.
     *
     * @return {Object}
     * @private
     */
    getState: function() {
        var me = this,
            map = me.map,
            state = me.callParent(arguments) || {},
            layer;

        // Ext delays the call to getState when a state event
        // occurs, so the MapPanel may have been destroyed
        // between the time the event occurred and the time
        // getState is called
        if(!map) {
            return;
        }

        // record location and zoom level
        var center = map.getCenter();
        // map may not be centered yet, because it may still have zero
        // dimensions or no layers
        center && Ext.applyIf(state, {
            "x": center.lon,
            "y": center.lat,
            "zoom": map.getZoom()
        });

        me.layers.each(function(modelInstance) {
            layer = modelInstance.getLayer();
            layerId = this.prettyStateKeys
                   ? modelInstance.get('title')
                   : modelInstance.get('id');
            state = me.addPropertyToState(state, "visibility_" + layerId,
                layer.getVisibility());
            state = me.addPropertyToState(state, "opacity_" + layerId,
                (layer.opacity === null) ? 1 : layer.opacity);
        }, me);

        return state;
    },

    /**
     * Apply the state provided as an argument.
     *
     * @param {Object} state The state to apply.
     * @private
     */
    applyState: function(state) {
        var me = this;
            map = me.map;
        // if we get strings for state.x, state.y or state.zoom
        // OpenLayers will take care of converting them to the
        // appropriate types so we don't bother with that
        me.center = new OpenLayers.LonLat(state.x, state.y);
        me.zoom = state.zoom;

        // TODO refactor with me.layers.each
        // set layer visibility and opacity
        var i, l, layer, layerId, visibility, opacity;
        var layers = map.layers;
        for(i=0, l=layers.length; i<l; i++) {
            layer = layers[i];
            layerId = me.prettyStateKeys ? layer.name : layer.id;
            visibility = state["visibility_" + layerId];
            if(visibility !== undefined) {
                // convert to boolean
                visibility = (/^true$/i).test(visibility);
                if(layer.isBaseLayer) {
                    if(visibility) {
                        map.setBaseLayer(layer);
                    }
                } else {
                    layer.setVisibility(visibility);
                }
            }
            opacity = state["opacity_" + layerId];
            if(opacity !== undefined) {
                layer.setOpacity(opacity);
            }
        }
    },

    /**
     * Check if an added item has to take separate actions
     * to be added to the map.
     * See e.g. the GeoExt.slider.Zoom or GeoExt.slider.LayerOpacity
     *
     * @private
     */
    onBeforeAdd: function(item) {
        if(Ext.isFunction(item.addToMapPanel)) {
            item.addToMapPanel(this);
        }
        this.callParent(arguments);
    },

    /**
     * Private method called during the destroy sequence.
     *
     * @private
     */
    beforeDestroy: function() {
        if(this.map && this.map.events) {
            this.map.events.un({
                "moveend": this.onMoveend,
                "changelayer": this.onChangelayer,
                scope: this
            });
        }
        // if the map panel was passed a map instance, this map instance
        // is under the user's responsibility
        if(!this.initialConfig.map ||
           !(this.initialConfig.map instanceof OpenLayers.Map)) {
            // we created the map, we destroy it
            if(this.map && this.map.destroy) {
                this.map.destroy();
            }
        }
        delete this.map;
        this.callParent(arguments);
    }
});
