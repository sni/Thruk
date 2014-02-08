package Thruk::Controller::panorama;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use JSON::XS;
use URI::Escape qw/uri_unescape/;
use IO::Socket;
use File::Slurp;
use Thruk::Utils::PanoramaCpuStats;

use parent 'Catalyst::Controller';

=head1 NAME

Thruk::Controller::panorama - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

##########################################################
# enable panorama features if this plugin is loaded
Thruk->config->{'use_feature_panorama'} = 1;

##########################################################
# add new menu item
Thruk::Utils::Menu::insert_item('General', {
                                    'href'  => '/thruk/cgi-bin/panorama.cgi',
                                    'name'  => 'Panorama View',
                                    target  => '_parent'
                         });

##########################################################

=head2 panorama_cgi

page: /thruk/cgi-bin/panorama.cgi

=cut
sub panorama_cgi : Path('/thruk/cgi-bin/panorama.cgi') {
    my ( $self, $c ) = @_;
    return if defined $c->{'canceled'};
    return $c->detach('/panorama/index');
}


##########################################################

=head2 index

=cut
sub index :Path :Args(0) :MyAction('AddCachedDefaults') {
    my ( $self, $c ) = @_;

    $c->stash->{'no_totals'}   = 1;
    $c->stash->{default_nagvis_base_url} = '';
    $c->stash->{default_nagvis_base_url} = '/'.$ENV{'OMD_SITE'}.'/nagvis' if $ENV{'OMD_SITE'};

    $c->stash->{'readonly'} = defined $c->config->{'Thruk::Plugin::Panorama'}->{'readonly'} ? $c->config->{'Thruk::Plugin::Panorama'}->{'readonly'} : 0;
    $c->stash->{'readonly'} = 1 if defined $c->request->parameters->{'readonly'};

    if(defined $c->request->query_keywords) {
        if($c->request->query_keywords eq 'state') {
            return($self->_stateprovider($c));
        }
    }

    if(defined $c->request->parameters->{'js'}) {
        return($self->_js($c));
    }

    if(defined $c->request->parameters->{'task'}) {
        my $task = $c->request->parameters->{'task'};
        if($task eq 'stats_core_metrics') {
            return($self->_task_stats_core_metrics($c));
        }
        elsif($task eq 'stats_check_metrics') {
            return($self->_task_stats_check_metrics($c));
        }
        elsif($task eq 'server_stats') {
            return($self->_task_server_stats($c));
        }
        elsif($task eq 'show_logs') {
            return($self->_task_show_logs($c));
        }
        elsif($task eq 'site_status') {
            return($self->_task_site_status($c));
        }
        elsif($task eq 'hosts') {
            return($self->_task_hosts($c));
        }
        elsif($task eq 'hosttotals') {
            return($self->_task_hosttotals($c));
        }
        elsif($task eq 'services') {
            return($self->_task_services($c));
        }
        elsif($task eq 'servicesminemap') {
            return($self->_task_servicesminemap($c));
        }
        elsif($task eq 'servicetotals') {
            return($self->_task_servicetotals($c));
        }
        elsif($task eq 'hosts_pie') {
            return($self->_task_hosts_pie($c));
        }
        elsif($task eq 'host_list') {
            return($self->_task_host_list($c));
        }
        elsif($task eq 'host_detail') {
            return($self->_task_host_detail($c));
        }
        elsif($task eq 'service_list') {
            return($self->_task_service_list($c));
        }
        elsif($task eq 'service_detail') {
            return($self->_task_service_detail($c));
        }
        elsif($task eq 'services_pie') {
            return($self->_task_services_pie($c));
        }
        elsif($task eq 'stats_gearman') {
            return($self->_task_stats_gearman($c));
        }
        elsif($task eq 'stats_gearman_grid') {
            return($self->_task_stats_gearman_grid($c));
        }
        elsif($task eq 'pnp_graphs') {
            return($self->_task_pnp_graphs($c));
        }
    }

    # find images for preloader
    my $plugin_dir = $c->config->{'plugin_path'} || $c->config->{home}."/plugins";
    my @images = glob($plugin_dir.'/plugins-enabled/panorama/root/images/*');
    $c->stash->{preload_img} = [];
    for my $i (@images) {
        $i =~ s|^.*/||gmx;
        push @{$c->stash->{preload_img}}, $i;
    }

    $self->_js($c, 1) if $c->config->{'thruk_debug'};

    # clean up?
    if($c->request->parameters->{'clean'}) {
        my $data = Thruk::Utils::get_user_data($c);
        delete $data->{'panorama'};
        if($c->config->{'demo_mode'}) {
            eval {
                Thruk::Utils::store_user_data($c, $data);
            };
            Thruk::Utils::Filter::get_message($c);
        } else {
            Thruk::Utils::store_user_data($c, $data);
        }
        return $c->response->redirect("panorama.cgi");
    }

    $c->stash->{template} = 'panorama.tt';
    return 1;
}

##########################################################
sub _js {
    my ( $self, $c, $only_data ) = @_;

    my $stateprovider = $c->config->{'Thruk::Plugin::Panorama'}->{'state_provider'} || 'server';
    if($stateprovider ne 'cookie' and $stateprovider ne 'server') { $stateprovider = 'server'; }
    $c->stash->{stateprovider} = $stateprovider;

    $c->stash->{default_view} = '';
    my $default_file = $c->config->{'Thruk::Plugin::Panorama'}->{'default_view'};
    if($default_file) {
        my $default_view = $default_file;
        if(-e $default_file) {
            $default_view = read_file($default_file);
        }
        chomp($default_view);
        $default_view =~ s/\s//gmx;
        $c->stash->{default_view} = $default_view;
    }

    my $data = Thruk::Utils::get_user_data($c);
    $c->stash->{state} = encode_json($data->{'panorama'}->{'state'} || {});

    unless($only_data) {
        $c->res->content_type('text/javascript; charset=UTF-8');
        $c->stash->{template} = 'panorama_js.tt';
    }
    return 1;
}

##########################################################
sub _stateprovider {
    my ( $self, $c ) = @_;

    my $task  = $c->request->parameters->{'task'};
    my $value = $c->request->parameters->{'value'};
    my $name  = $c->request->parameters->{'name'};

    if($c->stash->{'readonly'}) {
        $c->stash->{'json'} = {
            'status' => 'failed'
        };
    }
    elsif(defined $task and ($task eq 'set' or $task eq 'update')) {
        my $data = Thruk::Utils::get_user_data($c);
        if($task eq 'update') {
            $c->log->debug("panorama: update users data");
            $data->{'panorama'}->{'state'} = $c->request->parameters;
            delete $data->{'panorama'}->{'state'}->{'task'};
        } else {
            if($value eq 'null') {
                $c->log->debug("panorama: removed ".$name);
                delete $data->{'panorama'}->{'state'}->{$name};
            } else {
                $c->log->debug("panorama: set ".$name." to ".$self->_nice_ext_value($value));
                $data->{'panorama'}->{'state'}->{$name} = $value;
            }
        }
        if($c->config->{'demo_mode'}) {
            eval {
                Thruk::Utils::store_user_data($c, $data);
            };
            Thruk::Utils::Filter::get_message($c);
        } else {
            Thruk::Utils::store_user_data($c, $data);
        }

        $c->stash->{'json'} = {
            'status' => 'ok'
        };
    } else {
        $c->stash->{'json'} = {
            'status' => 'failed'
        };
    }

    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _nice_ext_value {
    my($self, $orig) = @_;
    my $value = uri_unescape($orig);
    $value =~ s/^o://gmx;
    my @val   = split/\^/mx, $value;
    my $o = {};
    for my $v (@val) {
        my($key, $val) = split(/=/mx, $v, 2);
        $val =~ s/^n%3A//gmx;
        $val =~ s/^b%3A0/false/gmx;
        $val =~ s/^b%3A1/true/gmx;
        if($val =~ m/^a%3A/mx) {
            $val =~ s/^a%3A//mx;
            $val =~ s/s%253A//gmx;
            $val = [ split(m/n%253A|%5E/mx, $val) ];
            @{$val} = grep {!/^$/mx} @{$val};
        }
        elsif($val =~ m/^o%3A/mx) {
            $val =~ s/^o%3A//mx;
            $val = [ split(m/n%253A|%3D|%5E/mx, $val) ];
            @{$val} = grep {!/^$/mx} @{$val};
            $val = {@{$val}};
        } else {
            $val =~ s/^s%3A//mx;
        }
        $o->{$key} = $val;
    }
    $Data::Dumper::Sortkeys = 1;
    $value = Dumper($o);
    $value =~ s/^\$VAR1\ =//gmx;
    $value =~ s/\n/ /gmx;
    $value =~ s/\s+/ /gmx;
    return $value;
}

##########################################################
sub _task_stats_core_metrics {
    my($self, $c) = @_;

    my $data = $c->{'db'}->get_extra_perf_stats(  filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'status' ) ] );
    my $json = {
        columns => [
            { 'header' => 'Type',  dataIndex => 'type',  flex  => 1 },
            { 'header' => 'Total', dataIndex => 'total', align => 'right', xtype => 'numbercolumn', format => '0,000' },
            { 'header' => 'Rate',  dataIndex => 'rate',  align => 'right', xtype => 'numbercolumn', format => '0.00/s' },
        ],
        data    => [
            { type => 'Servicechecks',       total => $data->{'service_checks'}, rate => $data->{'service_checks_rate'} },
            { type => 'Hostchecks',          total => $data->{'host_checks'},    rate => $data->{'host_checks_rate'} },
            { type => 'Connections',         total => $data->{'connections'},    rate => $data->{'connections_rate'} },
            { type => 'Requests',            total => $data->{'requests'},       rate => $data->{'requests_rate'} },
            { type => 'NEB Callbacks',       total => $data->{'neb_callbacks'},  rate => $data->{'neb_callbacks_rate'} },
            { type => 'Cached Log Messages', total => $data->{'cached_log_messages'}, rate => '' },
        ]
    };

    $c->stash->{'json'} = $json;
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_stats_check_metrics {
    my($self, $c) = @_;

    my $data = $c->{'db'}->get_performance_stats( services_filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ) ], hosts_filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ) ] );

    my $json = {
        columns => [
            { 'header' => 'Type',  dataIndex => 'type', flex  => 1 },
            { 'header' => 'Min',   dataIndex => 'min', width => 60, align => 'right', xtype => 'numbercolumn', format => '0.00s' },
            { 'header' => 'Max',   dataIndex => 'max', width => 60, align => 'right', xtype => 'numbercolumn', format => '0.00s' },
            { 'header' => 'Avg',   dataIndex => 'avg', width => 60, align => 'right', xtype => 'numbercolumn', format => '0.00s' },
        ],
        data    => [
            { type => 'Service Check Execution Time', min => $data->{'services_execution_time_min'}, max => $data->{'services_execution_time_max'}, avg => $data->{'services_execution_time_avg'} },
            { type => 'Service Check Latency',        min => $data->{'services_latency_min'},        max => $data->{'services_latency_max'},        avg => $data->{'services_latency_avg'} },
            { type => 'Host Check Execution Time',    min => $data->{'hosts_execution_time_min'},    max => $data->{'hosts_execution_time_max'},    avg => $data->{'hosts_execution_time_avg'} },
            { type => 'Host Check Latency',           min => $data->{'hosts_latency_min'},           max => $data->{'hosts_latency_max'},           avg => $data->{'hosts_latency_avg'} },
        ]
    };

    $c->stash->{'json'} = $json;
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_server_stats {
    my($self, $c) = @_;

    my $show_load   = $c->request->parameters->{'load'}   || 'true';
    my $show_cpu    = $c->request->parameters->{'cpu'}    || 'true';
    my $show_memory = $c->request->parameters->{'memory'} || 'true';

    my $json = {
        columns => [
            { 'header' => 'Cat',    dataIndex => 'cat',   hidden => JSON::XS::true },
            { 'header' => 'Type',   dataIndex => 'type',  width => 60, align => 'right' },
            { 'header' => 'Value',  dataIndex => 'value', width => 65, align => 'right', renderer => 'TP.render_systat_value' },
            { 'header' => 'Graph',  dataIndex => 'graph', flex  => 1,                    renderer => 'TP.render_systat_graph' },
            { 'header' => 'Warn',   dataIndex => 'warn',  hidden => JSON::XS::true },
            { 'header' => 'Crit',   dataIndex => 'crit',  hidden => JSON::XS::true },
            { 'header' => 'Max',    dataIndex => 'max',   hidden => JSON::XS::true },
        ],
        data  => [],
        group => 'cat',
    };
    $c->stash->{'json'} = $json;
    return $c->forward('Thruk::View::JSON') unless -e '/proc'; # all beyond is linux only

    my($cpu, $cpucount);
    if($show_load eq 'true' or $show_cpu eq 'true') {
        my $lastcpu = $c->cache->get('panorama_sys_cpu');
        my $pcs  = Thruk::Utils::PanoramaCpuStats->new({sleep => 3, init => $lastcpu->{'init'}});
           $cpu  = $pcs->get();
           $cpucount = (scalar keys %{$cpu}) - 1;
        # don't save more often than 5 seconds to keep a better reference
        if(!defined $lastcpu->{'time'} or $lastcpu->{'time'} +5 < time()) {
            $c->cache->set('panorama_sys_cpu', { init => $pcs->{'init'}, time => time() });
        }
        $cpu     = $cpu->{'cpu'};
    }

    if($show_load eq 'true') {
        my @load = split(/\s+/mx,(read_file('/proc/loadavg')));
        push @{$json->{'data'}},
            { cat => 'Load',    type => 'load 1',   value => $load[0],            'warn' => $cpucount*2.5, crit => $cpucount*5.0, max => $cpucount*3, graph => '' },
            { cat => 'Load',    type => 'load 5',   value => $load[1],            'warn' => $cpucount*2.0, crit => $cpucount*3.0, max => $cpucount*3, graph => '' },
            { cat => 'Load',    type => 'load 15',  value => $load[2],            'warn' => $cpucount*1.5, crit => $cpucount*2,   max => $cpucount*3, graph => '' };
    }
    if($show_cpu eq 'true') {
        push @{$json->{'data'}},
            { cat => 'CPU',     type => 'User',     value => $cpu->{'user'},      'warn' => 70, crit => 90, max => 100, graph => '' },
            { cat => 'CPU',     type => 'Nice',     value => $cpu->{'nice'},      'warn' => 70, crit => 90, max => 100, graph => '' },
            { cat => 'CPU',     type => 'System',   value => $cpu->{'system'},    'warn' => 70, crit => 90, max => 100, graph => '' },
            { cat => 'CPU',     type => 'Wait IO',  value => $cpu->{'iowait'},    'warn' => 70, crit => 90, max => 100, graph => '' };
    }
    if($show_memory eq 'true') {
        # gather system statistics
        my $mem = {};
        for my $line (split/\n/mx,(read_file('/proc/meminfo'))) {
            my($name,$val,$unit) = split(/\s+/mx,$line,3);
            next unless defined $unit;
            $name =~ s/:$//gmx;
            $mem->{$name} = int($val / 1024);
        }
        push @{$json->{'data'}},
            { cat => 'Memory',  type => 'total',    value => $mem->{'MemTotal'},  graph => '', warn => $mem->{'MemTotal'}, crit => $mem->{'MemTotal'}, max => $mem->{'MemTotal'} },
            { cat => 'Memory',  type => 'free',     value => $mem->{'MemFree'},   'warn' => $mem->{'MemTotal'}*0.7, crit => $mem->{'MemTotal'}*0.8, max => $mem->{'MemTotal'}, graph => '' },
            { cat => 'Memory',  type => 'used',     value => $mem->{'MemTotal'}-$mem->{'MemFree'}-$mem->{'Buffers'}-$mem->{'Cached'}, 'warn' => $mem->{'MemTotal'}*0.7, crit => $mem->{'MemTotal'}*0.8, max => $mem->{'MemTotal'}, graph => '' },
            { cat => 'Memory',  type => 'buffers',  value => $mem->{'Buffers'},   'warn' => $mem->{'MemTotal'}*0.8, crit => $mem->{'MemTotal'}*0.9, max => $mem->{'MemTotal'}, graph => '' },
            { cat => 'Memory',  type => 'cached',   value => $mem->{'Cached'},    'warn' => $mem->{'MemTotal'}*0.8, crit => $mem->{'MemTotal'}*0.9, max => $mem->{'MemTotal'}, graph => '' };
    }

    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_stats_gearman {
    my($self, $c) = @_;
    $c->stash->{'json'} = $self->_get_gearman_stats($c);
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_stats_gearman_grid {
    my($self, $c) = @_;

    my $data = $self->_get_gearman_stats($c);

    my $json = {
        columns => [
            { 'header' => 'Queue',   dataIndex => 'name', flex  => 1, renderer => 'TP.render_gearman_queue' },
            { 'header' => 'Worker',  dataIndex => 'worker',  width => 60, align => 'right', xtype => 'numbercolumn', format => '0,000' },
            { 'header' => 'Running', dataIndex => 'running', width => 60, align => 'right', xtype => 'numbercolumn', format => '0,000' },
            { 'header' => 'Waiting', dataIndex => 'waiting', width => 60, align => 'right', xtype => 'numbercolumn', format => '0,000' },
        ],
        data    => []
    };
    for my $queue (sort keys %{$data}) {
        # hide empty queues
        next if($data->{$queue}->{'worker'} == 0 and $data->{$queue}->{'running'} == 0 and $data->{$queue}->{'waiting'} == 0);
        push @{$json->{'data'}}, {
            name    => $queue,
            worker  => $data->{$queue}->{'worker'},
            running => $data->{$queue}->{'running'},
            waiting => $data->{$queue}->{'waiting'},
        };
    }

    $c->stash->{'json'} = $json;
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_show_logs {
    my($self, $c) = @_;

    my $filter;
    my $end   = time();
    my $start = $end - Thruk::Utils::Status::convert_time_amount($c->{'request'}->{'parameters'}->{'time'} || '15m');
    push @{$filter}, { time => { '>=' => $start }};
    push @{$filter}, { time => { '<=' => $end }};

    # additional filters set?
    my $pattern         = $c->{'request'}->{'parameters'}->{'pattern'};
    my $exclude_pattern = $c->{'request'}->{'parameters'}->{'exclude'};
    if(defined $pattern and $pattern !~ m/^\s*$/mx) {
        push @{$filter}, { message => { '~~' => $pattern }};
    }
    if(defined $exclude_pattern and $exclude_pattern !~ m/^\s*$/mx) {
        push @{$filter}, { message => { '!~~' => $exclude_pattern }};
    }
    my $total_filter = Thruk::Utils::combine_filter('-and', $filter);

    return if $c->{'db'}->renew_logcache($c);
    my $data = $c->{'db'}->get_logs(filter => [$total_filter, Thruk::Utils::Auth::get_auth_filter($c, 'log')], sort => {'DESC' => 'time'});

    my $json = {
        columns => [
            { 'header' => '',        dataIndex => 'icon', width => 30, tdCls => 'icon_column', renderer => 'TP.render_icon_log' },
            { 'header' => 'Time',    dataIndex => 'time', width => 60, renderer => 'TP.render_date' },
            { 'header' => 'Message', dataIndex => 'message', flex => 1 },
        ],
        data    => []
    };
    for my $row (@{$data}) {
        push @{$json->{'data'}}, {
            icon    => Thruk::Utils::Filter::logline_icon($row),
            time    => $row->{'time'},
            message => substr($row->{'message'},13),
        };
    }

    $c->stash->{'json'} = $json;
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_site_status {
    my($self, $c) = @_;

    Thruk::Action::AddDefaults::set_processinfo($c);

    my $json = {
        columns => [
            { 'header' => 'Id',               dataIndex => 'id',                      width => 45, hidden => JSON::XS::true },
            { 'header' => '',                 dataIndex => 'icon',                    width => 30, tdCls => 'icon_column', renderer => 'TP.render_icon_site' },
            { 'header' => 'Site',             dataIndex => 'site',                    width => 60, flex => 1 },
            { 'header' => 'Version',          dataIndex => 'version',                 width => 50, renderer => 'TP.add_title' },
            { 'header' => 'Runtime',          dataIndex => 'runtime',                 width => 85 },
            { 'header' => 'Notifications',    dataIndex => 'enable_notifications',    width => 65, hidden => JSON::XS::true, align => 'center', renderer => 'TP.render_enabled_switch' },
            { 'header' => 'Svc Checks',       dataIndex => 'execute_service_checks',  width => 65, hidden => JSON::XS::true, align => 'center', renderer => 'TP.render_enabled_switch' },
            { 'header' => 'Hst Checks',       dataIndex => 'execute_host_checks',     width => 65, hidden => JSON::XS::true, align => 'center', renderer => 'TP.render_enabled_switch' },
            { 'header' => 'Eventhandlers',    dataIndex => 'enable_event_handlers',   width => 65, hidden => JSON::XS::true, align => 'center', renderer => 'TP.render_enabled_switch' },
            { 'header' => 'Performance Data', dataIndex => 'process_performance_data',width => 65, hidden => JSON::XS::true, align => 'center', renderer => 'TP.render_enabled_switch' },
        ],
        data    => []
    };

    for my $key (@{$c->stash->{'backends'}}) {
        my $b = $c->stash->{'backend_detail'}->{$key};
        my $d = {};
        $d = $c->stash->{'pi_detail'}->{$key} if ref $c->stash->{'pi_detail'} eq 'HASH';
        my $icon            = 'exclamation.png';
        if($b->{'running'} && $d->{'program_start'}) { $icon = 'accept.png'; }
        elsif($b->{'disabled'} == 2) { $icon = 'sport_golf.png'; }
        my $runtime = "";
        my $program_version = $b->{'last_error'};
        if($b->{'running'} && $d->{'program_start'}) {
            $runtime = Thruk::Utils::Filter::duration(time() - $d->{'program_start'});
            $program_version = $d->{'program_version'};
        }
        my $row = {
            id      => $key,
            icon    => $icon,
            site    => $b->{'name'},
            version => $program_version,
            runtime => $runtime,
        };
        for my $attr (qw/enable_notifications execute_host_checks execute_service_checks enable_event_handlers process_performance_data/) {
            $row->{$attr} = $d->{$attr};
        }
        push @{$json->{'data'}}, $row;
    }

    $c->stash->{'json'} = $json;
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_hosts {
    my($self, $c) = @_;

    my( $hostfilter, $servicefilter, $groupfilter ) = $self->_do_filter($c);
    return if $c->stash->{'has_error'};

    $c->{'request'}->{'parameters'}->{'entries'} = $c->{'request'}->{'parameters'}->{'pageSize'};
    $c->{'request'}->{'parameters'}->{'page'}    = $c->{'request'}->{'parameters'}->{'currentPage'};

    my $data = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ], pager => 1);

    my $json = {
        columns => [
            { 'header' => 'Hostname',               width => 120, dataIndex => 'name',                                 renderer => 'TP.render_clickable_host' },
            { 'header' => 'Icons',                  width => 75,  dataIndex => 'icons',             align => 'right',  renderer => 'TP.render_host_icons' },
            { 'header' => 'Status',                 width => 80,  dataIndex => 'state',             align => 'center', renderer => 'TP.render_host_status' },
            { 'header' => 'Last Check',             width => 80,  dataIndex => 'last_check',        align => 'center', renderer => 'TP.render_last_check' },
            { 'header' => 'Duration',               width => 100, dataIndex => 'last_state_change', align => 'center', renderer => 'TP.render_duration' },
            { 'header' => 'Attempt',                width => 60,  dataIndex => 'current_attempt',   align => 'center', renderer => 'TP.render_attempt' },
            { 'header' => 'Site',                   width => 60,  dataIndex => 'peer_name',         align => 'center', },
            { 'header' => 'Status Information',     flex  => 1,   dataIndex => 'plugin_output',                        renderer => 'TP.render_plugin_output' },
            { 'header' => 'Performance',            width => 80,  dataIndex => 'perf_data',                            renderer => 'TP.render_perfbar' },

            { 'header' => 'Parents',                  dataIndex => 'parents',                     hidden => JSON::XS::true, renderer => 'TP.render_clickable_host_list' },
            { 'header' => 'Current Attempt',          dataIndex => 'current_attempt',             hidden => JSON::XS::true },
            { 'header' => 'Max Check Attempts',       dataIndex => 'max_check_attempts',          hidden => JSON::XS::true },
            { 'header' => 'Last State Change',        dataIndex => 'last_state_change',           hidden => JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Check Type',               dataIndex => 'check_type',                  hidden => JSON::XS::true, renderer => 'TP.render_check_type' },
            { 'header' => 'Site ID',                  dataIndex => 'peer_key',                    hidden => JSON::XS::true },
            { 'header' => 'Has Been Checked',         dataIndex => 'has_been_checked',            hidden => JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Active Checks Enabled',    dataIndex => 'active_checks_enabled',       hidden => JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Accept Passive Checks',    dataIndex => 'accept_passive_checks',       hidden => JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Next Check',               dataIndex => 'next_check',                  hidden => JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Notification Number',      dataIndex => 'current_notification_number', hidden => JSON::XS::true },
            { 'header' => 'First Notification Delay', dataIndex => 'first_notification_delay',    hidden => JSON::XS::true },
            { 'header' => 'Notifications Enabled',    dataIndex => 'notifications_enabled',       hidden => JSON::XS::true, renderer => 'TP.render_enabled_switch' },
            { 'header' => 'Is Flapping',              dataIndex => 'is_flapping',                 hidden => JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Acknowledged',             dataIndex => 'acknowledged',                hidden => JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Comments',                 dataIndex => 'comments',                    hidden => JSON::XS::true, hideable => JSON::XS::false },
            { 'header' => 'Scheduled Downtime Depth', dataIndex => 'scheduled_downtime_depth',    hidden => JSON::XS::true },
            { 'header' => 'Action Url',               dataIndex => 'action_url_expanded',         hidden => JSON::XS::true, renderer => 'TP.render_action_url' },
            { 'header' => 'Notes url',                dataIndex => 'notes_url_expanded',          hidden => JSON::XS::true, renderer => 'TP.render_notes_url' },
            { 'header' => 'Icon Image',               dataIndex => 'icon_image_expanded',         hidden => JSON::XS::true, renderer => 'TP.render_icon_url' },
            { 'header' => 'Icon Image Alt',           dataIndex => 'icon_image_alt',              hidden => JSON::XS::true, hideable => JSON::XS::false },
            { 'header' => 'Custom Variable Names',    dataIndex => 'custom_variable_names',       hidden => JSON::XS::true, hideable => JSON::XS::false },
            { 'header' => 'Custom Variable Values',   dataIndex => 'custom_variable_values',      hidden => JSON::XS::true, hideable => JSON::XS::false },
            { 'header' => 'Long Plugin Output',       dataIndex => 'long_plugin_output',          hidden => JSON::XS::true, renderer => 'TP.render_long_pluginoutput' },

            { 'header' => 'Last Time Up',          dataIndex => 'last_time_up',          hidden => JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Last Time Unreachable', dataIndex => 'last_time_unreachable', hidden => JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Last Time Down',        dataIndex => 'last_time_down',        hidden => JSON::XS::true, renderer => 'TP.render_date' },
        ],
        data        => $data,
        data        => $c->stash->{'data'},
        totalCount  => $c->stash->{'pager'}->{'total_entries'},
        currentPage => $c->stash->{'pager'}->{'current_page'},
        paging      => JSON::XS::true,
        pi_detail   => $c->stash->{pi_detail},
    };

    if($c->stash->{'escape_html_tags'} or $c->stash->{'show_long_plugin_output'} eq 'inline') {
        for my $h ( @{$c->stash->{'data'}}) {
            _escape($h)      if $c->stash->{'escape_html_tags'};
            _long_plugin($h) if $c->stash->{'show_long_plugin_output'} eq 'inline';
        }
    }

    $c->stash->{'json'} = $json;
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_services {
    my($self, $c) = @_;

    my( $hostfilter, $servicefilter, $groupfilter ) = $self->_do_filter($c);
    return if $c->stash->{'has_error'};

    $c->{'request'}->{'parameters'}->{'entries'} = $c->{'request'}->{'parameters'}->{'pageSize'};
    $c->{'request'}->{'parameters'}->{'page'}    = $c->{'request'}->{'parameters'}->{'currentPage'};

    $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter], pager => 1);

    my $json = {
        columns => [
            { 'header' => 'Hostname',               width => 120, dataIndex => 'host_display_name',                    renderer => 'TP.render_service_host' },
            { 'header' => 'Host',                                 dataIndex => 'host_name',         hidden => JSON::XS::true },
            { 'header' => 'Host Icons',             width => 75,  dataIndex => 'icons',             align => 'right',  renderer => 'TP.render_host_service_icons' },
            { 'header' => 'Service',                width => 120, dataIndex => 'display_name',                         renderer => 'TP.render_clickable_service' },
            { 'header' => 'Description',                          dataIndex => 'description',       hidden => JSON::XS::true },
            { 'header' => 'Icons',                  width => 75,  dataIndex => 'icons',             align => 'right',  renderer => 'TP.render_service_icons' },
            { 'header' => 'Status',                 width => 70,  dataIndex => 'state',             align => 'center', renderer => 'TP.render_service_status' },
            { 'header' => 'Last Check',             width => 80,  dataIndex => 'last_check',        align => 'center', renderer => 'TP.render_last_check' },
            { 'header' => 'Duration',               width => 100, dataIndex => 'last_state_change', align => 'center', renderer => 'TP.render_duration' },
            { 'header' => 'Attempt',                width => 60,  dataIndex => 'current_attempt',   align => 'center', renderer => 'TP.render_attempt' },
            { 'header' => 'Site',                   width => 60,  dataIndex => 'peer_name',         align => 'center', },
            { 'header' => 'Status Information',     flex  => 1,   dataIndex => 'plugin_output',                        renderer => 'TP.render_plugin_output' },
            { 'header' => 'Performance',            width => 80,  dataIndex => 'perf_data',                            renderer => 'TP.render_perfbar' },

            { 'header' => 'Current Attempt',          dataIndex => 'current_attempt',             hidden => JSON::XS::true },
            { 'header' => 'Max Check Attempts',       dataIndex => 'max_check_attempts',          hidden => JSON::XS::true },
            { 'header' => 'Last State Change',        dataIndex => 'last_state_change',           hidden => JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Check Type',               dataIndex => 'check_type',                  hidden => JSON::XS::true, renderer => 'TP.render_check_type' },
            { 'header' => 'Site ID',                  dataIndex => 'peer_key',                    hidden => JSON::XS::true },
            { 'header' => 'Has Been Checked',         dataIndex => 'has_been_checked',            hidden => JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Active Checks Enabled',    dataIndex => 'active_checks_enabled',       hidden => JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Accept Passive Checks',    dataIndex => 'accept_passive_checks',       hidden => JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Next Check',               dataIndex => 'next_check',                  hidden => JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Notification Number',      dataIndex => 'current_notification_number', hidden => JSON::XS::true },
            { 'header' => 'First Notification Delay', dataIndex => 'first_notification_delay',    hidden => JSON::XS::true },
            { 'header' => 'Notifications Enabled',    dataIndex => 'notifications_enabled',       hidden => JSON::XS::true, renderer => 'TP.render_enabled_switch' },
            { 'header' => 'Is Flapping',              dataIndex => 'is_flapping',                 hidden => JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Acknowledged',             dataIndex => 'acknowledged',                hidden => JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Comments',                 dataIndex => 'comments',                    hidden => JSON::XS::true, hideable => JSON::XS::false },
            { 'header' => 'Scheduled Downtime Depth', dataIndex => 'scheduled_downtime_depth',    hidden => JSON::XS::true },
            { 'header' => 'Action Url',               dataIndex => 'action_url_expanded',         hidden => JSON::XS::true, renderer => 'TP.render_action_url' },
            { 'header' => 'Notes url',                dataIndex => 'notes_url_expanded',          hidden => JSON::XS::true, renderer => 'TP.render_notes_url' },
            { 'header' => 'Icon Image',               dataIndex => 'icon_image_expanded',         hidden => JSON::XS::true, renderer => 'TP.render_icon_url' },
            { 'header' => 'Icon Image Alt',           dataIndex => 'icon_image_alt',              hidden => JSON::XS::true, hideable => JSON::XS::false },
            { 'header' => 'Custom Variable Names',    dataIndex => 'custom_variable_names',       hidden => JSON::XS::true, hideable => JSON::XS::false },
            { 'header' => 'Custom Variable Values',   dataIndex => 'custom_variable_values',      hidden => JSON::XS::true, hideable => JSON::XS::false },
            { 'header' => 'Long Plugin Output',       dataIndex => 'long_plugin_output',          hidden => JSON::XS::true, renderer => 'TP.render_long_pluginoutput' },

            { 'header' => 'Host Parents',                   dataIndex => 'host_parents',                  hidden => JSON::XS::true, renderer => 'TP.render_clickable_host_list' },
            { 'header' => 'Host Status',                    dataIndex => 'host_state',                    hidden => JSON::XS::true, renderer => 'TP.render_host_status' },
            { 'header' => 'Host Notifications Enabled',     dataIndex => 'host_notifications_enabled',    hidden => JSON::XS::true, renderer => 'TP.render_enabled_switch' },
            { 'header' => 'Host Check Type',                dataIndex => 'host_check_type',               hidden => JSON::XS::true, renderer => 'TP.render_check_type' },
            { 'header' => 'Host Active Checks Enabled',     dataIndex => 'host_active_checks_enabled',    hidden => JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Host Accept Passive Checks',     dataIndex => 'host_accept_passive_checks',    hidden => JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Host Is Flapping',               dataIndex => 'host_is_flapping',              hidden => JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Host Acknowledged',              dataIndex => 'host_acknowledged',             hidden => JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Host Comments',                  dataIndex => 'host_comments',                 hidden => JSON::XS::true, hideable => JSON::XS::false },
            { 'header' => 'Host Scheduled Downtime Depth',  dataIndex => 'host_scheduled_downtime_depth', hidden => JSON::XS::true },
            { 'header' => 'Host Action Url',                dataIndex => 'host_action_url_expanded',      hidden => JSON::XS::true, renderer => 'TP.render_action_url' },
            { 'header' => 'Host Notes Url',                 dataIndex => 'host_notes_url_expanded',       hidden => JSON::XS::true, renderer => 'TP.render_notes_url' },
            { 'header' => 'Host Icon Image',                dataIndex => 'host_icon_image_expanded',      hidden => JSON::XS::true, renderer => 'TP.render_icon_url' },
            { 'header' => 'Host Icon Image Alt',            dataIndex => 'host_icon_image_alt',           hidden => JSON::XS::true, hideable => JSON::XS::false },
            { 'header' => 'Host Custom Variable Names',     dataIndex => 'host_custom_variable_names',    hidden => JSON::XS::true, hideable => JSON::XS::false },
            { 'header' => 'Host Custom Variable Values',    dataIndex => 'host_custom_variable_values',   hidden => JSON::XS::true, hideable => JSON::XS::false },

            { 'header' => 'Last Time Ok',       dataIndex => 'last_time_ok',       hidden => JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Last Time Warning',  dataIndex => 'last_time_warning',  hidden => JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Last Time Unknown',  dataIndex => 'last_time_unknown',  hidden => JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Last Time Critical', dataIndex => 'last_time_critical', hidden => JSON::XS::true, renderer => 'TP.render_date' },
        ],
        data        => $c->stash->{'data'},
        totalCount  => $c->stash->{'pager'}->{'total_entries'},
        currentPage => $c->stash->{'pager'}->{'current_page'},
        paging      => JSON::XS::true,
        pi_detail   => $c->stash->{pi_detail},
    };

    if($c->stash->{'escape_html_tags'} or $c->stash->{'show_long_plugin_output'} eq 'inline') {
        for my $s ( @{$c->stash->{'data'}}) {
            _escape($s)      if $c->stash->{'escape_html_tags'};
            _long_plugin($s) if $c->stash->{'show_long_plugin_output'} eq 'inline';
        }
    }

    $c->stash->{'json'} = $json;
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_hosttotals {
    my($self, $c) = @_;

    my( $hostfilter, $servicefilter, $groupfilter ) = $self->_do_filter($c);
    return if $c->stash->{'has_error'};
    Thruk::Utils::Status::fill_totals_box( $c, $hostfilter, undef, 1);

    my $s = $c->stash->{'host_stats'};
    my $json = {
        columns => [
            { 'header' => '#',     width => 40, dataIndex => 'count', align => 'right', renderer => 'TP.render_statuscount' },
            { 'header' => 'State', flex  => 1,  dataIndex => 'state' },
        ],
        data      => [],
        pi_detail => $c->stash->{pi_detail},
    };

    for my $state (qw/up down unreachable pending/) {
        push @{$json->{'data'}}, {
            state => ucfirst $state,
            count => $s->{$state},
        };
    }

    $c->stash->{'json'} = $json;
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_servicetotals {
    my($self, $c) = @_;

    my( $hostfilter, $servicefilter, $groupfilter ) = $self->_do_filter($c);
    return if $c->stash->{'has_error'};
    Thruk::Utils::Status::fill_totals_box( $c, undef, $servicefilter, 1 );

    my $s = $c->stash->{'service_stats'};
    my $json = {
        columns => [
            { 'header' => '#',     width => 40, dataIndex => 'count', align => 'right', renderer => 'TP.render_statuscount' },
            { 'header' => 'State', flex  => 1,  dataIndex => 'state' },
        ],
        data      => [],
        pi_detail => $c->stash->{pi_detail},
    };

    for my $state (qw/ok warning unknown critical pending/) {
        push @{$json->{'data'}}, {
            state => ucfirst $state,
            count => $s->{$state},
        };
    }

    $c->stash->{'json'} = $json;
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_hosts_pie {
    my($self, $c) = @_;

    my( $hostfilter, $servicefilter, $groupfilter ) = $self->_do_filter($c);
    return if $c->stash->{'has_error'};

    my $data = $c->{'db'}->get_host_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter]);

    my $json = {
        columns => [
            { 'header' => 'Name',      dataIndex => 'name' },
            { 'header' => 'Data',      dataIndex => 'data' },
        ],
        colors    => [ ],
        data      => [],
        pi_detail => $c->stash->{pi_detail},
    };
    my $colors = {
        up          => '#00FF33',
        down        => '#FF5B33',
        unreachable => '#FF7A59',
        pending     => '#ACACAC',
    };

    for my $state (qw/up down unreachable pending/) {
        next if $data->{$state} == 0;
        push @{$json->{'data'}}, {
            name    => ucfirst $state,
            data    => $data->{$state},
        };
        push @{$json->{'colors'}}, $colors->{$state};
    }

    $c->stash->{'json'} = $json;
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_services_pie {
    my($self, $c) = @_;

    my( $hostfilter, $servicefilter, $groupfilter ) = $self->_do_filter($c);
    return if $c->stash->{'has_error'};

    my $data = $c->{'db'}->get_service_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter]);

    my $json = {
        columns => [
            { 'header' => 'Name',      dataIndex => 'name' },
            { 'header' => 'Data',      dataIndex => 'data' },
        ],
        colors    => [],
        data      => [],
        pi_detail => $c->stash->{pi_detail},
    };
    my $colors = {
        ok       => '#00FF33',
        warning  => '#FFDE00',
        unknown  => '#FF9E00',
        critical => '#FF5B33',
        pending  => '#ACACAC',
    };

    for my $state (qw/ok warning unknown critical pending/) {
        next if $data->{$state} == 0;
        push @{$json->{'data'}}, {
            name    => ucfirst $state,
            data    => $data->{$state},
        };
        push @{$json->{'colors'}}, $colors->{$state};
    }

    $c->stash->{'json'} = $json;
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_servicesminemap {
    my($self, $c) = @_;

    my( $hostfilter, $servicefilter, $groupfilter ) = $self->_do_filter($c);
    return if $c->stash->{'has_error'};

    my($uniq_services, $hosts, $matrix) = Thruk::Utils::Status::get_service_matrix($c, $hostfilter, $servicefilter);

    # automatically adjust service column hight
    my $longest_description = 0;
    for my $svc (sort keys %{$uniq_services}) {
        my $l = length($svc);
        $longest_description = $l if $l > $longest_description;
    }
    my $height = 15 + int($longest_description * 5.70);
    $height    =  40 if $height <  40;
    $height    = 300 if $height > 300;

    my $service2index = {};
    my $json = {
        columns => [
            { 'header' => '<div class="minemap_first_col" style="top: '.($height/2-10).'px;">Hostname</div>', width => 120, height => $height, dataIndex => 'host_display_name' },
        ],
        data        => [],
        pi_detail   => $c->stash->{pi_detail},
    };

    my $x=0;
    for my $svc (sort keys %{$uniq_services}) {
        my $index = 'col'.$x;
        $service2index->{$svc} = $index;
        push @{$json->{'columns'}}, {
                    'header'    => '<div class="vertical" style="top: '.($height/2-10).'px;">'.$svc.'</div>',
                    'headerIE'  => '<div class="vertical" style="top: 8px; width: '.($height-20).'px;">'.$svc.'</div>',
                    'width'     => 20,
                    'height'    => $height,
                    'dataIndex' => $index,
                    'align'     => 'center',
                    'tdCls'     => 'mine_map_cell'
        };
        $x++;
    }
    for my $name (sort keys %{$hosts}) {
        my $hst  = $hosts->{$name};
        my $data;
        if ($hst->{'host_action_url_expanded'}) {
            $data = { 'host_display_name' => $hst->{'host_display_name'} . '&nbsp;<a target="_blank" href="'.$hst->{'host_action_url_expanded'}.'"><img src="'.$c->stash->{'url_prefix'}.'themes/'.$c->stash->{'theme'}.'/images/action.gif" border="0" width="20" height="20" alt="Perform Extra Host Actions" title="Perform Extra Host Actions" style="vertical-align: text-bottom;"></a>' };
        } else {
            $data = { 'host_display_name' => $hst->{'host_display_name'} };
        }

        for my $svc (keys %{$uniq_services}) {
            my $service = $matrix->{$name}->{$svc};
            next unless defined $service->{state};
            my $cls     = 'mine_map_state'.$service->{state};
            $cls        = 'mine_map_state4' if $service->{has_been_checked} == 0;
            my $text    = '&nbsp;';
            if($service->{'scheduled_downtime_depth'}) { $text = '<img src="'.$c->stash->{'url_prefix'}.'themes/'.$c->stash->{'theme'}.'/images/downtime.gif" alt="downtime" height="15" width="15">' }
            if($service->{'acknowledged'})             { $text = '<img src="'.$c->stash->{'url_prefix'}.'themes/'.$c->stash->{'theme'}.'/images/ack.gif" alt="acknowledged" height="15" width="15">' }
            $data->{$service2index->{$svc}} = '<div class="clickable '.$cls.'" '.$self->_generate_service_popup($c, $service).'>'.$text.'</div>';
        }
        push @{$json->{'data'}}, $data;
    }

    $c->stash->{'json'} = $json;
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_pnp_graphs {
    my($self, $c) = @_;

    my $graphs = [];
    my $data = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts')]);
    for my $hst (@{$data}) {
        my $url = Thruk::Utils::get_pnp_url($c, $hst, 1);
        if($url ne '') {
            push @{$graphs}, {
                text => $hst->{'name'}.';_HOST_',
                url  => $url.'/image?host='.$hst->{'name'}.'&srv=_HOST_',
            };
        }
    }

    $data = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services')]);
    for my $svc (@{$data}) {
        my $url = Thruk::Utils::get_pnp_url($c, $svc, 1);
        if($url ne '') {
            push @{$graphs}, {
                text => $svc->{'host_name'}.';'.$svc->{'description'},
                url  => $url.'/image?host='.$svc->{'host_name'}.'&srv='.$svc->{'description'},
            };
        }
    }
    $graphs = Thruk::Backend::Manager::_sort({}, $graphs, 'text');

    $c->stash->{'json'} = { data => $graphs };
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_host_list {
    my($self, $c) = @_;

    my $hosts = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts')]);
    my $data = [];
    for my $hst (@{$hosts}) {
        push @{$data}, { name => $hst->{'name'} };
    }

    $data = Thruk::Backend::Manager::_sort({}, $data, 'name');
    $c->stash->{'json'} = { data => $data };
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_host_detail {
    my($self, $c) = @_;

    my $host        = $c->request->parameters->{'host'}    || '';
    $c->stash->{'json'} = {};
    my $hosts     = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), { name => $host }]);
    my $downtimes = $c->{'db'}->get_downtimes(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'host_name' => $host }, { 'service_description' => '' } ],
        sort => { 'DESC' => 'id' }
    );
    if(defined $hosts and scalar @{$hosts} > 0) {
        if($c->stash->{'escape_html_tags'}) {
            _escape($hosts->[0]);
        }
        $c->stash->{'json'} = { data => $hosts->[0], downtimes => $downtimes };
    }
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_service_list {
    my($self, $c) = @_;

    my $host     = $c->request->parameters->{'host'} || '';
    my $services = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), { host_name => $host }]);
    my $data = [];
    for my $svc (@{$services}) {
        push @{$data}, { description => $svc->{'description'} };
    }

    $data = Thruk::Backend::Manager::_sort({}, $data, 'description');
    $c->stash->{'json'} = { data => $data };
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _task_service_detail {
    my($self, $c) = @_;

    my $host        = $c->request->parameters->{'host'}    || '';
    my $description = $c->request->parameters->{'service'} || '';
    $c->stash->{'json'} = {};
    my $services  = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), { host_name => $host, description => $description }]);
    my $downtimes = $c->{'db'}->get_downtimes(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'host_name' => $host }, { 'service_description' => $description } ],
        sort => { 'DESC' => 'id' }
    );
    if(defined $services and scalar @{$services} > 0) {
        if($c->stash->{'escape_html_tags'}) {
            _escape($services->[0]);
        }
        $c->stash->{'json'} = { data => $services->[0], downtimes => $downtimes };
    }
    return $c->forward('Thruk::View::JSON');
}

##########################################################
sub _get_gearman_stats {
    my($self, $c) = @_;

    my $data = {};
    my $host = 'localhost';
    my $port = 4730;

    if(defined $c->request->parameters->{'server'}) {
        ($host,$port) = split(/:/mx, $c->request->parameters->{'server'}, 2);
    }

    my $handle = IO::Socket::INET->new(
        Proto    => "tcp",
        PeerAddr => $host,
        PeerPort => $port,
    )
    or do {
        $c->log->warn("can't connect to port $port on $host: $!") unless(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'TEST');
        return $data;
    };
    $handle->autoflush(1);

    print $handle "status\n";

    while ( defined( my $line = <$handle> ) ) {
        chomp($line);
        my($name,$total,$running,$worker) = split(/\t/mx, $line);
        next if $name eq 'dummy';
        if(defined $worker) {
            my $stat = {
                'name'      => $name,
                'worker'    => int($worker),
                'running'   => int($running),
                'waiting'   => int($total - $running),
            };
            $data->{$name} = $stat;
        }
        last if $line eq '.';
    }
    CORE::close($handle);

    return $data;
}

##########################################################
# convert json filter to perl object and do filtering
sub _do_filter {
    my($self, $c) = @_;

    if(defined $c->request->parameters->{'filter'} and $c->request->parameters->{'filter'} ne '') {
        my $filter;
        eval {
            $filter = decode_json($c->request->parameters->{'filter'});
        };
        if($@) {
            $c->log->warn('filter failed: '.$@);
            return;
        }

        my $pre = 'dfl_s0_';
        for my $key (qw/hostprops hoststatustypes serviceprops servicestatustypes/) {
            $c->request->parameters->{$pre.$key} = $filter->{$key};
        }
        for my $type (qw/op type value value_date val_pre/) {
            if(ref $filter->{$type} ne 'ARRAY') { $filter->{$type} = [$filter->{$type}]; }
        }

        for my $type (qw/op type value val_pre/) {
            my $x = 0;
            for my $val (@{$filter->{$type}}) {
                $c->request->parameters->{$pre.$type} = [] unless defined $c->request->parameters->{$pre.$type};
                if($type eq 'value') {
                    if(!defined $val) { $val = ''; }
                    if($filter->{'type'}->[$x] eq 'last check' or $filter->{'type'}->[$x] eq 'next check') {
                        $val = $filter->{'value_date'}->[$x];
                        $val =~ s/T/ /gmx;
                    }
                }
                elsif($type eq 'type') {
                    $val = lc($val || '')
                }
                elsif($type eq 'val_pre') {
                    if(!defined $val) { $val = ''; }
                }

                push @{$c->request->parameters->{$pre.$type}}, $val;
                $x++;
            }
        }
    }
    my @f = Thruk::Utils::Status::do_filter($c);
    return @f;
}

##########################################################
sub _generate_service_popup {
    my ($self, $c, $service) = @_;
    return ' title="'.Thruk::Utils::Filter::escape_quotes($service->{'plugin_output'}).'" onclick="TP.add_panlet({type:\'TP.PanletService\', conf: { xdata: { host: \''.Thruk::Utils::Filter::escape_bslash($service->{'host_name'}).'\', service: \''.Thruk::Utils::Filter::escape_bslash($service->{'description'}).'\', }}})"';
}

##########################################################
sub _escape {
    my($o) = @_;
    $o->{'plugin_output'}      = Thruk::Utils::Filter::escape_quotes(Thruk::Utils::Filter::escape_html($o->{'plugin_output'}));
    $o->{'long_plugin_output'} = Thruk::Utils::Filter::escape_quotes(Thruk::Utils::Filter::escape_html($o->{'long_plugin_output'}));
    return $o;
}

##########################################################
sub _long_plugin {
    my($o) = @_;
    if($o->{'long_plugin_output'}) {
        $o->{'plugin_output'}      = $o->{'plugin_output'}.'<br>'.$o->{'long_plugin_output'};
        $o->{'long_plugin_output'} = '';
    }
    return $o;
}

##########################################################

=head1 AUTHOR

Sven Nierlein, 2009-2014, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
