/* Host Status Icon */
Ext.define('TP.HostStatusIcon', {
    extend: 'TP.IconWidget',

    iconType: 'host',
    iconName: 'Hostname',
    initComponent: function() {
        var panel = this;
        this.callParent();
        this.xdata.general.incl_downtimes = false;
        this.xdata.general.incl_ack       = false;
    },
    getGeneralItems: function() {
        var panel = this;
        return([
            TP.objectSearchItem(panel, 'host', 'Hostname', panel.xdata.general.host),
            {
                fieldLabel: 'Include Downtimes',
                xtype:      'checkbox',
                name:       'incl_downtimes',
                boxLabel:   '(alert during downtimes too)'
            }, {
                fieldLabel: 'Include Acknowledged',
                xtype:      'checkbox',
                name:       'incl_ack',
                boxLabel:   '(alert for acknowledged problems too)'
            }
        ]);
    },
    getName: function() {
        return(this.xdata.general.host);
    },
    getDetails: function() {
        var details = [];
        if(!this.host) {
            return([['Status', 'No status information available']]);
        }
        var statename = TP.text_host_status(this.xdata.state);
        details.push([ 'Current Status', '<div class="extinfostate '+statename.toUpperCase()+'">'+statename.toUpperCase()+'<\/div>'
                                        +' (for ' + TP.render_duration('', '', {data:this.host})+')<br>'
                                        +(this.acknowledged ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_ack.png" style="vertical-align:text-bottom"> acknowledged)':'')
                                        +(this.downtime     ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_downtime.png" style="vertical-align:text-bottom"> in downtime)':'')
                     ]);
        details.push([ 'Status Information', this.host.plugin_output]);
        details.push([ 'Last Check', this.host.last_check ? TP.date_format(this.host.last_check) : 'never']);
        details.push([ 'Next Check', this.host.next_check ? TP.date_format(this.host.next_check) : 'not planned']);
        details.push([ 'Last Notification', (this.host.last_notification == 0 ? 'N/A' : TP.date_format(this.host.last_notification)) + ' (notification '+this.host.current_notification_number+')']);
        if(this.host.pnp_url) {
            var now = new Date();
            var url = this.host.pnp_url+'/image?host='+this.xdata.general.host+'&srv=_HOST_&view=1&source=0&graph_width=300&graph_height=100';
            url    += '&start=' + (Math.round(now.getTime()/1000) - TP.timeframe2seconds('24h'));
            url    += '&end='   + Math.round(now.getTime()/1000);
            details.push([ '*Graph', '<img src="'+url+'" width="100%" border=1 style="max-height: 250px;" onload="TP.iconTip.syncShadow()">']);
        }
        return(details);
    },
    refreshHandler: function(newStatus) {
        this.acknowledged = false;
        this.downtime     = false;
        if(this.host) {
            if(this.host.scheduled_downtime_depth > 0) { this.downtime     = true; }
            if(this.host.acknowledged             > 0) { this.acknowledged = true; }
        }
        this.callParent([newStatus]);
    }
});

/* Hostgroup Status Icon */
Ext.define('TP.HostgroupStatusIcon', {
    extend: 'TP.IconWidget',

    iconType: 'hostgroup',
    iconName: 'Hostgroupname',
    initComponent: function() {
        var panel = this;
        this.callParent();
        this.xdata.general.incl_hst       = true;
        this.xdata.general.incl_svc       = true;
        this.xdata.general.incl_downtimes = false;
        this.xdata.general.incl_ack       = false;
    },

    getGeneralItems: function() {
        var panel = this;
        return([
            TP.objectSearchItem(panel, 'hostgroup', 'Hostgroupname', panel.xdata.general.hostgroup),
            {
                fieldLabel: 'Include Hosts',
                xtype:      'checkbox',
                name:       'incl_hst'
            }, {
                fieldLabel: 'Include Services',
                xtype:      'checkbox',
                name:       'incl_svc'
            }, {
                fieldLabel: 'Include Downtimes',
                xtype:      'checkbox',
                name:       'incl_downtimes',
                boxLabel:   '(alert during downtimes too)'
            }, {
                fieldLabel: 'Include Acknowledged',
                xtype:      'checkbox',
                name:       'incl_ack',
                boxLabel:   '(alert for acknowledged problems too)'
            }
        ]);
    },
    refreshHandler: function(newStatus) {
        // calculate summarized status
        if(this.hostgroup) {
            /* makes no sense if nothing selected but happens after switching classes */
            if(!this.xdata.general.incl_hst && !this.xdata.general.incl_svc) {
                this.xdata.general.incl_svc = true;
                this.xdata.general.incl_hst = true;
            }
            var res = TP.get_group_status({
                group:          this.hostgroup,
                incl_ack:       this.xdata.general.incl_ack,
                incl_downtimes: this.xdata.general.incl_downtimes,
                incl_svc:       this.xdata.general.incl_svc,
                incl_hst:       this.xdata.general.incl_hst
            });
            newStatus         = res.state;
            this.downtime     = res.downtime;
            this.acknowledged = res.acknowledged;
            this.hostProblem  = res.hostProblem;
        }
        this.callParent([newStatus]);
    },
    getName: function() {
        return(this.xdata.general.hostgroup);
    },
    getDetails: function() {
        var panel = this;
        var details = [];
        if(!this.hostgroup) {
            return([['Status', 'No status information available']]);
        }
        var statename = TP.text_status(this.xdata.state, this.hostProblem);
        details.push([ 'Summarized Status', '<div class="extinfostate '+statename.toUpperCase()+'">'+statename.toUpperCase()+'<\/div>'
                                            +(this.acknowledged ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_ack.png" style="vertical-align:text-bottom"> acknowledged)':'')
                                            +(this.downtime     ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_downtime.png" style="vertical-align:text-bottom"> in downtime)':'')
                     ]);
        if(this.xdata.general.incl_hst) {
            details.push([ 'Hosts', TP.get_summarized_hoststatus(this.hostgroup.hosts)]);
        }
        if(this.xdata.general.incl_svc) {
            details.push([ 'Services', TP.get_summarized_servicestatus(this.hostgroup.services)]);
        }
        var link = TP.getIconDetailsLink(panel, true);
        details.push([ 'Details', link, panel]);
        return(details);
    }
});

/* Service Status Icon */
Ext.define('TP.ServiceStatusIcon', {
    extend: 'TP.IconWidget',

    iconType: 'service',
    iconName: 'Servicename',
    initComponent: function() {
        var panel = this;
        this.callParent();
        this.xdata.general.incl_downtimes = false;
        this.xdata.general.incl_ack       = false;
    },

    getGeneralItems: function() {
        var panel = this;
        return([
            TP.objectSearchItem(panel, 'host', 'Hostname', panel.xdata.general.host),
            TP.objectSearchItem(panel, 'service', 'Servicename', panel.xdata.general.service),
            {
                fieldLabel: 'Include Downtimes',
                xtype:      'checkbox',
                name:       'incl_downtimes',
                boxLabel:   '(alert during downtimes too)'
            }, {
                fieldLabel: 'Include Acknowledged',
                xtype:      'checkbox',
                name:       'incl_ack',
                boxLabel:   '(alert for acknowledged problems too)'
            }
        ]);
    },
    getName: function() {
        return(this.xdata.general.host + ' - ' + this.xdata.general.service);
    },
    getDetails: function() {
        var details = [];
        if(!this.service) {
            return([['Status', 'No status information available']]);
        }
        var statename = TP.text_service_status(this.xdata.state);
        details.push([ 'Current Status', '<div class="extinfostate '+statename.toUpperCase()+'">'+statename.toUpperCase()+'<\/div>'
                                            +' (for ' + TP.render_duration('', '', {data:this.service})+')'
                                            +(this.acknowledged ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_ack.png" style="vertical-align:text-bottom"> acknowledged)':'')
                                            +(this.downtime     ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_downtime.png" style="vertical-align:text-bottom"> in downtime)':'')
                     ]);
        details.push([ 'Status Information', this.service.plugin_output]);
        details.push([ 'Last Check', this.service.last_check ? TP.date_format(this.service.last_check) : 'never']);
        details.push([ 'Next Check', this.service.next_check ? TP.date_format(this.service.next_check) : 'not planned']);
        details.push([ 'Last Notification', (this.service.last_notification == 0 ? 'N/A' : TP.date_format(this.service.last_notification)) + ' (notification '+this.service.current_notification_number+')']);
        if(this.service.pnp_url) {
            var now = new Date();
            var url = this.service.pnp_url+'/image?host='+this.xdata.general.host+'&srv='+this.xdata.general.service+'&view=1&source=0&graph_width=300&graph_height=100';
            url    += '&start=' + (Math.round(now.getTime()/1000) - TP.timeframe2seconds('24h'));
            url    += '&end='   + Math.round(now.getTime()/1000);
            details.push([ '*Graph', '<img src="'+url+'" width="100%" border=1 style="max-height: 250px;" onload="TP.iconTip.syncShadow()">']);
        }
        return(details);
    },
    refreshHandler: function(newStatus) {
        this.acknowledged = false;
        this.downtime     = false;
        if(this.service) {
            if(this.service.scheduled_downtime_depth > 0) { this.downtime     = true; }
            if(this.service.acknowledged             > 0) { this.acknowledged = true; }
        }
        this.callParent([newStatus]);
    }
});

/* Servicegroup Status Icon */
Ext.define('TP.ServicegroupStatusIcon', {
    extend: 'TP.IconWidget',

    iconType: 'servicegroup',
    iconName: 'Servicegroupname',
    initComponent: function() {
        var panel = this;
        this.callParent();
        this.xdata.general.incl_downtimes = false;
        this.xdata.general.incl_ack       = false;
    },

    getGeneralItems: function() {
        var panel = this;
        return([
            TP.objectSearchItem(panel, 'servicegroup', 'Servicegroupname', panel.xdata.general.servicegroup),
            {
                fieldLabel: 'Include Downtimes',
                xtype:      'checkbox',
                name:       'incl_downtimes',
                boxLabel:   '(alert during downtimes too)'
            }, {
                fieldLabel: 'Include Acknowledged',
                xtype:      'checkbox',
                name:       'incl_ack',
                boxLabel:   '(alert for acknowledged problems too)'
            }
        ]);
    },
    refreshHandler: function(newStatus) {
        // calculate summarized status
        if(this.servicegroup) {
            var res = TP.get_group_status({
                group:          this.servicegroup,
                incl_ack:       this.xdata.general.incl_ack,
                incl_downtimes: this.xdata.general.incl_downtimes,
                incl_svc:       true,
                incl_hst:       false
            });
            newStatus         = res.state;
            this.downtime     = res.downtime;
            this.acknowledged = res.acknowledged;
            this.hostProblem  = res.hostProblem;
        }
        this.callParent([newStatus]);
    },
    getName: function() {
        return(this.xdata.general.servicegroup);
    },
    getDetails: function() {
        var panel = this;
        var details = [];
        if(!this.servicegroup) {
            return([['Status', 'No status information available']]);
        }
        var statename = TP.text_service_status(this.xdata.state);
        details.push([ 'Summarized Status', '<div class="extinfostate '+statename.toUpperCase()+'">'+statename.toUpperCase()+'<\/div>'
                                            +(this.acknowledged ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_ack.png" style="vertical-align:text-bottom"> acknowledged)':'')
                                            +(this.downtime     ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_downtime.png" style="vertical-align:text-bottom"> in downtime)':'')
                     ]);
        details.push([ 'Services', TP.get_summarized_servicestatus(this.servicegroup.services)]);
        var link = TP.getIconDetailsLink(panel, true);
        details.push([ 'Details', link, panel]);
        return(details);
    }
});

/* Custom Filter Icon */
Ext.define('TP.FilterStatusIcon', {
    extend: 'TP.IconWidget',

    iconType: 'filter',
    initComponent: function() {
        var panel = this;
        this.callParent();
        this.xdata.general.name           = '';
        this.xdata.general.incl_hst       = true;
        this.xdata.general.incl_svc       = true;
        this.xdata.general.incl_downtimes = false;
        this.xdata.general.incl_ack       = false;
    },

    getGeneralItems: function() {
        var panel = this;
        return([{
                fieldLabel: 'Name',
                xtype:      'textfield',
                name:       'name',
                value:      '',
                listeners:  {}
            }, {
                fieldLabel: 'Backends / Sites',
                xtype:      'tp_backendcombo'
            },
            new TP.formFilter({
                fieldLabel: 'Filter',
                name:       'filter',
                ftype:      'service',
                labelWidth: 132,
                panel:      panel
            }), {
                fieldLabel: 'Include Hosts',
                xtype:      'checkbox',
                name:       'incl_hst'
            }, {
                fieldLabel: 'Include Services',
                xtype:      'checkbox',
                name:       'incl_svc'
            }, {
                fieldLabel: 'Include Downtimes',
                xtype:      'checkbox',
                name:       'incl_downtimes',
                boxLabel:   '(alert during downtimes too)'
            }, {
                fieldLabel: 'Include Acknowledged',
                xtype:      'checkbox',
                name:       'incl_ack',
                boxLabel:   '(alert for acknowledged problems too)'
            }
        ]);
    },
    refreshHandler: function(newStatus) {
        // calculate summarized status
        if(this.results) {
            var res = TP.get_group_status({
                group:          this.results,
                incl_ack:       this.xdata.general.incl_ack,
                incl_downtimes: this.xdata.general.incl_downtimes,
                incl_svc:       this.xdata.general.incl_svc,
                incl_hst:       this.xdata.general.incl_hst
            });
            newStatus         = res.state;
            this.downtime     = res.downtime;
            this.acknowledged = res.acknowledged;
            this.hostProblem  = res.hostProblem;
        }
        this.callParent([newStatus]);
    },
    getName: function() {
        return(this.xdata.general.name);
    },
    getDetails: function() {
        var panel = this;
        var details = [];
        if(!this.results) {
            return([['Status', 'No status information available']]);
        }
        var statename;
        if(this.xdata.general.incl_svc == false) {
            statename = TP.text_host_status(this.xdata.state);
        } else {
            statename = TP.text_status(this.xdata.state, this.hostProblem);
        }
        details.push([ 'Summarized Status', '<div class="extinfostate '+statename.toUpperCase()+'">'+statename.toUpperCase()+'<\/div>'
                                            +(this.acknowledged ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_ack.png" style="vertical-align:text-bottom"> acknowledged)':'')
                                            +(this.downtime     ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_downtime.png" style="vertical-align:text-bottom"> in downtime)':'')
                     ]);
        if(this.xdata.general.incl_hst) {
            details.push([ 'Hosts', TP.get_summarized_hoststatus(this.results.hosts)]);
        }
        if(this.xdata.general.incl_svc) {
            details.push([ 'Services', TP.get_summarized_servicestatus(this.results.services)]);
        }
        var link = TP.getIconDetailsLink(panel, true);
        details.push([ 'Details', link, panel]);
        return(details);
    }
});

/* Sitestatus Icon */
Ext.define('TP.SiteStatusIcon', {
    extend: 'TP.IconWidget',

    iconType: 'site',
    iconName: 'Sitename',
    initComponent: function() {
        var panel = this;
        this.callParent();
    },
    getGeneralItems: function() {
        var panel = this;
        return([
            TP.objectSearchItem(panel, 'site', 'Sitename', panel.xdata.general.site)
        ]);
    },
    refreshHandler: function(newStatus) {
        // calculate site status
        if(this.site) {
                 if(this.site.running == 1) { newStatus = 0; }
            else if(this.site.state   == 0) { newStatus = 0; }
            else                            { newStatus = 2; }
        } else if(newStatus == undefined) {
            newStatus = this.state;
        }
        this.callParent([newStatus]);
    },
    getName: function() {
        return(this.xdata.general.site);
    },
    getDetails: function() {
        var details = [];
        if(!this.site) {
            return([['Status', 'No status information available']]);
        }
        var statename = this.xdata.state == 0 ? 'Ok' : 'Down';
        details.push([ 'Status', '<div class="extinfostate '+statename.toUpperCase()+'">'+statename.toUpperCase()+'<\/div>']);
        if(this.xdata.state == 0) {
            details.push([ 'Details', "Operating normal"]);
        } else {
            details.push([ 'Details', this.site.last_error]);
        }
        details.push([ 'Address', this.site.addr]);
        return(details);
    }
});

/* TextLabel Widget */
Ext.define('TP.TextLabelWidget', {
    extend: 'Ext.Component',
    mixins: {
        smallWidget: 'TP.SmallWidget'
    },
    iconType:           'text',
    html:               '',
    hideAppearanceTab:  true,
    initialSettingsTab: 4,
    rotateLabel:        true,
    constructor: function (config) {
        this.mixins.smallWidget.constructor.call(this, config);
        this.callParent();
    },
    initComponent: function() {
        this.callParent();
        var panel = this;
        panel.xdata.label.labeltext = 'Label';
        panel.xdata.label.position  = 'top-left';
        panel.xdata.layout.x        = 0;
        panel.xdata.layout.y        = 0;
    },
    getGeneralItems: function() { return; },
    refreshHandler: function()  { return; }
});

/* Static Image */
var imagesStore = Ext.create('Ext.data.Store', {
    fields: ['path', 'image'],
    proxy: {
        type: 'ajax',
        url:  'panorama.cgi?task=userdata_images',
        reader: {
            type: 'json',
            root: 'data'
        }
    },
    autoLoad: false,
    data : []
});
Ext.define('TP.StaticIcon', {
    extend: 'TP.IconWidget',

    iconType:         'image',
    cls:              'statciconWidget tooltipTarget',
    hideAppearanceTab: true,
    generalLabelWidth: 50,
    hasScale:          true,
    initComponent: function() {
        var panel = this;
        this.callParent();
    },
    getGeneralItems: function() {
        var panel = this;
        imagesStore.load();
        return([{
            xtype:      'combobox',
            name:       'src',
            fieldLabel: 'Image',
            store:       imagesStore,
            queryMode:      'remote',
            triggerAction:  'all',
            pageSize:       true,
            selectOnFocus:  true,
            typeAhead:      true,
            displayField: 'image',
            minChars:      2,
            valueField: 'path',
            listConfig : {
                getInnerTpl: function(displayField) {
                    return '<div class="x-combo-list-item" style="overflow: hidden; white-space: nowrap;"><img src="{path}" height=16 width=16> {image}<\/div>';
                },
                minWidth: 300,
                maxWidth: 800
            },
            matchFieldWidth: false,
            listeners: {
                select: function(combo, records, eOpts) {
                    if(records[0].data['image'] == "&lt;upload new image&gt;") {
                        TP.uploadUserContent('image', 'images/', function(filename) {
                            combo.setValue('../usercontent/images/'+filename);
                        });
                    }
                    return(true);
                },
                change: function() {
                if(TP.iconSettingsWindow.renderUpdate) {
                    TP.iconSettingsWindow.renderUpdate();
                }
            }}
        }, {
            xtype:      'panel',
            html:       'Place images in: '+usercontent_folder+'/images/ <a href="#" onclick="TP.uploadUserContent(\'image\', \'images/\')">(upload)</a>',
            style:      'text-align: center;',
            bodyCls:    'form-hint',
            padding:    '10 0 0 0',
            border:      0
        }]);
    },
    getDetails: function() { return([]); },
    getName: function() { return(""); },
    refreshHandler: function(newStatus) {},
    setRenderItem: function(xdata, forceRecreate) {
        if(xdata == undefined) { xdata = this.xdata; }
        xdata.appearance = { type: 'icon'};
        this.callParent([xdata, forceRecreate]);
    }
});

/* Dashboard Status Icon */
var dashboardStore = Ext.create('Ext.data.Store', {
    fields: ['nr', 'name'],
    proxy: {
        type: 'ajax',
        url:  'panorama.cgi?task=dashboard_list&list=all',
        reader: {
            type: 'json',
            root: 'data'
        }
    },
    autoLoad: false,
    data : []
});
Ext.define('TP.DashboardStatusIcon', {
    extend: 'TP.IconWidget',

    iconType: 'dashboard',
    iconName: 'Dashboard',
    initComponent: function() {
        var panel = this;
        this.xdata.general.hide_downtimes = false;
        this.xdata.general.hide_ack       = false;
        this.callParent();
    },
    getGeneralItems: function() {
        dashboardStore.load();
        var panel = this;
        return([{
                xtype:          'combobox',
                name:           'dashboard',
                fieldLabel:     'Dashboard',
                store:           dashboardStore,
                queryMode:      'remote',
                triggerAction:  'all',
                pageSize:        true,
                selectOnFocus:   true,
                typeAhead:       true,
                displayField:   'name',
                valueField:     'nr',
                listConfig : {
                    minWidth: 300,
                    maxWidth: 800
                },
                matchFieldWidth: false,
                listeners: {
                    change: function(This, newValue, oldValue, eOpts) {
                        /* set icon link automatically */
                        Ext.getCmp('linkForm').getForm().setValues({link: 'dashboard://'+newValue});
                    }
                }
            },{
                fieldLabel: 'Hide Downtimes',
                xtype:      'checkbox',
                name:       'hide_downtimes',
                boxLabel:   '(problems in downtime will be ok if checked)'
            }, {
                fieldLabel: 'Hide Acknowledged',
                xtype:      'checkbox',
                name:       'hide_ack',
                boxLabel:   '(acknowledged problems will be ok if checked)'
        }]);
    },
    getName: function() {
        var tab = Ext.getCmp('tabpan-tab_'+this.xdata.general.dashboard);
        if(tab) {
            return(tab.title);
        }
        return("");
    },
    getDetails: function() {
        var details = [];
        var statename = TP.text_status(this.xdata.state, this.hostProblem);
        details.push([ 'Current Status', '<div class="extinfostate '+statename.toUpperCase()+'">'+statename.toUpperCase()+'<\/div>'
                                        +(this.acknowledged ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_ack.png" style="vertical-align:text-bottom"> acknowledged)':'')
                                        +(this.downtime     ?' (<img src="'+url_prefix+'plugins/panorama/images/btn_downtime.png" style="vertical-align:text-bottom"> in downtime)':'')
                     ]);
        var tab = Ext.getCmp('tabpan-tab_'+this.xdata.general.dashboard);
        if(tab) {
            /* Totals */
            var group = TP.getTabTotals(tab);
            var totals = '';
            if(group.hosts.total > 0) {
                totals += TP.get_summarized_hoststatus(group.hosts);
            }
            if(group.services.total > 0) {
                totals += TP.get_summarized_servicestatus(group.services);
            }
            if(totals != '') {
                details.push([ 'Totals', totals]);
            }

            /* Details */
            var table  = '<\/tr><tr><td colspan=3><table class="TipDetails">';
                table += '<tr><th colspan=3>Details:<\/th><\/tr>';
            var panels = TP.getAllPanel(tab);
            /* sort by type */
            var lastType;
            var skipped = 0;
            var shown   = 0;
            panels = panels.sort(function(a,b) { return(a.iconType > b.iconType) });
            for(var nr=0; nr<panels.length; nr++) {
                var p = panels[nr];
                if(p.iconType && p.xdata && p.iconType != "text" && p.iconType != "image") {
                    if(this.xdata.state <= p.xdata.state         /* show only problems if the map has one */
                       && (this.xdata.state == 0 || p.xdata.state != 4) /* skip pending icons if there is a problem */
                       && (!this.hostProblem || (p.hostProblem || p.iconType == 'host')) /* if the map is a hostproblem, show only hosts */
                       && shown < 10)       /* show only first 10 matches */
                    {
                        var pstatename = TP.text_status(p.xdata.state, p.hostProblem);
                        var type = ucfirst(p.iconType);
                        table += '<tr>';
                        table += '<th class="'+(type != lastType ? 'newType' : '')+'">'+(type != lastType ? type : '')+'<\/th>';
                        table += '<td><a href="'+TP.getIconDetailsLink(p)+'" target="_blank">'+(p.getName ? p.getName() : '')+'</a><\/td>';
                        table += '<td><div class="extinfostate '+pstatename.toUpperCase()+'">'+pstatename+'</div>';
                        table += p.acknowledged ? ' <img src="'+url_prefix+'plugins/panorama/images/btn_ack.png" style="vertical-align:text-bottom">'     : '';
                        table += p.downtime     ? ' <img src="'+url_prefix+'plugins/panorama/images/btn_downtime.png" style="vertical-align:text-bottom">' : '';
                        table += '<\/td>';
                        table += '<\/tr>';
                        lastType = type;
                        shown++;
                    } else {
                        skipped++;
                    }
                }
            }
            if(shown != panels.length) {
                table += '<tr>';
                table += '<th><\/th>';
                table += '<td class="more_hosts" colspan=2>'+(skipped)+' more item'+(skipped > 1 ? 's' : '')+'...<\/td>';
                table += '<\/tr>';
            }
            table += '<\/td><\/tr><\/table>';
            if(shown == 0) {
                details.push(['Details', 'No status icons available on that dashboard']);
            } else {
                details.push(['*Details', table]);
            }
        }
        return(details);
    },
    refreshHandler: function(newStatus, skipUpdate) {
        var This   = this;
        var tab_id = 'tabpan-tab_'+This.xdata.general.dashboard;
        var tab    = Ext.getCmp(tab_id);
        if(!tab) {
            if(skipUpdate) {
                This.callParent([newStatus]);
                return;
            }
            TP.add_pantab(tab_id, undefined, true, function(id, success, response) {
                if(success) {
                    This.refreshHandler(newStatus, skipUpdate);
                } else {
                    // pass unknown state back to the parent
                    This.downtime     = false;
                    This.acknowledged = false;
                    This.hostProblem  = false;
                    This.xdata.state  = 3;
                    newStatus         = 3;
                    skipUpdate        = true;
                    This.refreshHandler(newStatus, skipUpdate);
                }
            });
            return;
        }
        if(tab.rendered) { skipUpdate = true; }
        if(!skipUpdate) {
            TP.updateAllIcons(tab, undefined, undefined, undefined, Ext.bind(This.refreshHandler, This, [newStatus, true]));
            return;
        }
        var res = TP.getTabState(tab_id, !This.xdata.general.hide_ack, !This.xdata.general.hide_downtimes);
        if(res) {
            This.downtime     = res.downtime;
            This.acknowledged = res.acknowledged;
            This.hostProblem  = res.hostProblem;
            This.xdata.state  = res.state;
            newStatus         = res.state;
        }
        This.callParent([newStatus]);
    }
});
