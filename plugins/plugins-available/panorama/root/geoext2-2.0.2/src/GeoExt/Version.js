/*
 * Copyright (c) 2008-2014 The Open Source Geospatial Foundation
 *
 * Published under the BSD license.
 * See https://github.com/geoext/geoext2/blob/master/license.txt for the full
 * text of the license.
 */
(function() {
    var major = 2,
        minor = 0,
        patch = 2,
        label = '',
        environment = [],
        v = '';

    // Concatenate GeoExt version.
    v = 'v' + major + '.' + minor + '.' + patch + (label ? '.' + label : '');

    // Grab versions of libraries in the environment
    if ( Ext.versions.extjs.version ) {
        environment.push('ExtJS: ' + Ext.versions.extjs.version);
    }
    if ( window.OpenLayers ) {
        environment.push('OpenLayers: ' + OpenLayers.VERSION_NUMBER);
    }
    environment.push('GeoExt: ' + v);

    /**
     * A singleton class holding the properties #version with the current
     * GeoExt version and #environment with a string about the surrounding
     * libraries ExtJS and OpenLayers.
     */
    Ext.define('GeoExt.Version', {
        singleton: true,

        /**
         * The version number of GeoExt.
         *
         * @property {String} version
         */
        version: v,

        /**
         * Lists the versions of the currently loaded libraries and contains the
         * versions of `ExtJS`, `OpenLayers` and `GeoExt`.
         *
         * @property {String} environment
         */
        environment: (environment.join(', '))
    }, function() {
        /**
         * The GeoExt root object.
         *
         * @class GeoExt
         * @singleton
         */
        /**
         * @inheritdoc GeoExt.Version#version
         * @member GeoExt
         * @property version
         */
        GeoExt.version = GeoExt.Version.version;
    });
})();
