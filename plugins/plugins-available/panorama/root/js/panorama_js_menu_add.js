TP.addPanletsMenu = function(options) {
    var menu = {
        listeners: {
            afterrender: function(menu, eOpts) {
                var tabpan = Ext.getCmp('tabpan');
                var tab    = tabpan.getActiveTab();
                if(tab) {
                    tab.disableMapControlsTemp();
                }
            },
            beforehide: function(menu, eOpts) {
                var tabpan = Ext.getCmp('tabpan');
                var tab    = tabpan.getActiveTab();
                if(tab) {
                    tab.enableMapControlsTemp();
                }
            }
        },
        items: [{
                text:    'Icons & Widgets',
                icon:   options.open == 'left' ? url_prefix+'plugins/panorama/images/menu-parent.gif' : url_prefix+'plugins/panorama/images/chart_pie.png',
                cls:    options.open == 'left' ? 'hideRightArrow' : '',
                hideOnClick: false,
                menu:    [{
                        text:   'Line / Arrow / Watermark',
                        icon:   url_prefix+'plugins/panorama/images/link_go.png',
                        handler: function() { TP.add_panlet_delayed({type:'TP.ServiceStatusIcon', conf: { xdata: { appearance: { type: 'connector' }}}}, -8, -8) }
                    }, '-', {
                        text:   'Host Status',
                        icon:   url_prefix+'plugins/panorama/images/server.png',
                        handler: function() { TP.add_panlet_delayed({type:'TP.HostStatusIcon'}, -8, -8) }
                    }, {
                        text:   'Hostgroup Status',
                        icon:   url_prefix+'plugins/panorama/images/server_link.png',
                        handler: function() { TP.add_panlet_delayed({type:'TP.HostgroupStatusIcon'}, -8, -8) }
                    }, '-' ,{
                        text:   'Service Status',
                        icon:   url_prefix+'plugins/panorama/images/computer.png',
                        handler: function() { TP.add_panlet_delayed({type:'TP.ServiceStatusIcon'}, -8, -8) }
                    }, {
                        text:   'Servicegroup Status',
                        icon:   url_prefix+'plugins/panorama/images/computer_link.png',
                        handler: function() { TP.add_panlet_delayed({type:'TP.ServicegroupStatusIcon'}, -8, -8) }
                    }, '-', {
                        text:   'Custom Filter',
                        icon:   url_prefix+'plugins/panorama/images/page_find.png',
                        handler: function() { TP.add_panlet_delayed({type:'TP.FilterStatusIcon'}, -8, -8) }
                    }, '-', {
                        text:   'Site Status',
                        icon:   url_prefix+'plugins/panorama/images/accept.png',
                        handler: function() { TP.add_panlet_delayed({type:'TP.SiteStatusIcon'}, -8, -8) }
                    }, {
                        text:   'Dashboard Status',
                        icon:   url_prefix+'plugins/panorama/images/map.png',
                        handler: function() { TP.add_panlet_delayed({type:'TP.DashboardStatusIcon'}, -8, -8) }
                    }, '-', {
                        text:   'Text Label',
                        icon:   url_prefix+'plugins/panorama/images/text_align_left.png',
                        handler: function() { TP.add_panlet_delayed({type:'TP.TextLabelWidget'}, -8, -8) }
                    }, {
                        text:   'Static Image',
                        icon:   url_prefix+'plugins/panorama/images/picture.png',
                        handler: function() { TP.add_panlet_delayed({type:'TP.StaticIcon'}, -8, -8) }
                    }
                ]
            },
            /* Server */
            '-', {
                text:   'Site Status',
                icon:   url_prefix+'plugins/panorama/images/server.png',
                handler: function() { TP.add_panlet({type:'TP.PanletGridServer'}) }
            }, {
                text:   'Server Status',
                icon:   url_prefix+'plugins/panorama/images/bricks.png',
                handler: function() { TP.add_panlet({type:'TP.PanletGridServerStats'}) }
            }, {
                text:   'Core Performance Metrics',
                icon:   url_prefix+'plugins/panorama/images/table_lightning.png',
                handler: function() { TP.add_panlet({type:'TP.PanletGridCoreMetrics'}) }
            }, {
                text:   'Host / Service Performance',
                icon:   url_prefix+'plugins/panorama/images/table_gear.png',
                handler: function() { TP.add_panlet({type:'TP.PanletGridCheckMetrics'}) }
            },
            /* Hosts */
            '-', {
                text:   'Hosts',
                icon:   url_prefix+'plugins/panorama/images/server.png',
                handler: function() { TP.add_panlet({type:'TP.PanletGridHosts'}) }
            }, {
                text:   'Hosts Totals',
                icon:   url_prefix+'plugins/panorama/images/application_view_columns.png',
                handler: function() { TP.add_panlet({type:'TP.PanletGridHostTotals'}) }
            }, {
                text:   'Hosts Graph',
                icon:   url_prefix+'plugins/panorama/images/chart_pie.png',
                handler: function() { TP.add_panlet({type:'TP.PanletPieChartHosts'}) }
            },
            /* Services */
            '-', {
                text:   'Services',
                icon:   url_prefix+'plugins/panorama/images/computer.png',
                handler: function() { TP.add_panlet({type:'TP.PanletGridServices'}) }
            }, {
                text:   'Services Totals',
                icon:   url_prefix+'plugins/panorama/images/application_view_columns.png',
                handler: function() { TP.add_panlet({type:'TP.PanletGridServiceTotals'}) }
            }, {
                text:   'Services Graph',
                icon:   url_prefix+'plugins/panorama/images/chart_pie.png',
                handler: function() { TP.add_panlet({type:'TP.PanletPieChartServices'}) }
            }, {
                text:   'Mine Map',
                icon:   url_prefix+'plugins/panorama/images/minemap.png',
                handler: function() { TP.add_panlet({type:'TP.PanletGridServiceMineMap'}) }
            }, {
                text:   'Squares',
                icon:   url_prefix+'plugins/panorama/images/minemap.png',
                handler: function() { TP.add_panlet({type:'TP.PanletSquares'}) }
            },
            /* Misc */
            '-', {
                text:   'Miscellaneous',
                icon:   options.open == 'left' ? url_prefix+'plugins/panorama/images/menu-parent.gif' : url_prefix+'plugins/panorama/images/wrench.png',
                cls:    options.open == 'left' ? 'hideRightArrow' : '',
                hideOnClick: false,
                menu:   [{
                    text:   'Logfile',
                    icon:   url_prefix+'plugins/panorama/images/text_align_left.png',
                    handler: function() { TP.add_panlet({type:'TP.PanletGridLogs'}) }
                }, {
                    text:   'Grafana Graph',
                    icon:   url_prefix+'plugins/panorama/images/chart_curve.png',
                    handler: function() { TP.add_panlet({type:'TP.PanletGrafana'}) }
                }, {
                    text:   'PNP Graph',
                    icon:   url_prefix+'plugins/panorama/images/chart_curve.png',
                    handler: function() { TP.add_panlet({type:'TP.PanletPNP'}) }
                }, {
                    text:   'Nagvis Map',
                    icon:   url_prefix+'plugins/panorama/images/world.png',
                    handler: function() { TP.add_panlet({type:'TP.PanletNagvis'}) }
                }, {
                    text:   'World Clock',
                    icon:   url_prefix+'plugins/panorama/images/clock.png',
                    handler: function() { TP.add_panlet({type:'TP.PanletClock'}) }
                }, {
                    text:    'Generic Url Panlet',
                    icon:    url_prefix+'plugins/panorama/images/html_add.png',
                    handler: function() { TP.add_panlet({type:'TP.PanletUrl'}) }
                }]
            },
            {
                text:   'Business Process Map',
                icon:   url_prefix+'plugins/panorama/images/chart_organisation.png',
                handler: function() { TP.add_panlet({type:'TP.PanletBP'}) },
                hidden: !use_feature_bp
            },
            /* Mod-Gearman */
            {
                text:   'Mod-Gearman',
                icon:   options.open == 'left' ? url_prefix+'plugins/panorama/images/menu-parent.gif' : url_prefix+'plugins/panorama/images/modgearman.png',
                cls:    options.open == 'left' ? 'hideRightArrow' : '',
                hideOnClick: false,
                menu:   [{
                    text:   'Mod-Gearman Metrics',
                    icon:   url_prefix+'plugins/panorama/images/modgearman.png',
                    handler: function() { TP.add_panlet({type:'TP.PanletGridGearmanMetrics'}) }
                }, {
                    text:   'Mod-Gearman Charts',
                    icon:   url_prefix+'plugins/panorama/images/modgearman.png',
                    handler: function() { TP.add_panlet({type:'TP.PanletChartGearman'}) }
                }]
            }
        ]
    }
    return(menu);
}
