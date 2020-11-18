package Thruk::Controller::panorama;

use strict;
use warnings;
use Data::Dumper qw/Dumper/;
use Cpanel::JSON::XS qw/decode_json encode_json/;
use File::Slurp qw/read_file/;
use File::Copy qw/move copy/;
use Encode qw(decode_utf8 encode_utf8);
use Module::Load qw/load/;
use Carp qw/confess/;
use Thruk::Utils::Panorama qw/ACCESS_NONE ACCESS_READONLY ACCESS_READWRITE ACCESS_OWNER DASHBOARD_FILE_VERSION SOFT_STATE HARD_STATE/;
use Thruk::Utils::Log qw/:all/;

=head1 NAME

Thruk::Controller::panorama - Thruk Controller

=head1 DESCRIPTION

Thruk Controller.

=head1 METHODS

=cut

#use Thruk::Timer qw/timing_breakpoint/;

##########################################################
my @runtime_keys = qw/state stateHist stateDetails
                      currentPage pageSize totalCount
                    /;

##########################################################

=head2 index

=cut
sub index {
    my ( $c ) = @_;

    #&timing_breakpoint('panorama::index');
    return unless Thruk::Action::AddDefaults::add_defaults($c, Thruk::ADD_CACHED_DEFAULTS);

    if(!$c->config->{'panorama_modules_loaded'}) {
        load URI::Escape, qw/uri_unescape/;
        load Scalar::Util, qw/looks_like_number/;
        load Thruk::Utils::PanoramaCpuStats;
        load Thruk::Utils::Avail;
        $c->config->{'panorama_modules_loaded'} = 1;
    }

    # add current dashboard to error details, so if something goes wrong, we can log which dashboard is responsible
    $c->stash->{errorDetails} = '' unless $c->stash->{errorDetails};
    $c->stash->{errorDetails} .= sprintf("Dashboard: %s\n", $c->req->parameters->{'current_tab'}) if $c->req->parameters->{'current_tab'};

    # add some functions
    $c->stash->{'get_static_panorama_files'} = \&Thruk::Utils::Panorama::get_static_panorama_files;

    $c->stash->{title}             = 'Thruk Panorama';
    $c->stash->{'skip_navigation'} = 1;
    $c->stash->{'inject_stats'}    = 0;
    $c->stash->{'no_totals'}       = 1;
    $c->stash->{default_nagvis_base_url} = '';
    $c->stash->{default_nagvis_base_url} = '/'.$ENV{'OMD_SITE'}.'/nagvis' if $ENV{'OMD_SITE'};
    $c->stash->{'panorama_debug'} = $c->config->{'panorama_debug'} // 0;
    $c->stash->{'panorama_debug'} = 1 if $c->req->parameters->{'debug'};

    $c->stash->{'readonly'} = defined $c->config->{'Thruk::Plugin::Panorama'}->{'readonly'} ? $c->config->{'Thruk::Plugin::Panorama'}->{'readonly'} : 0;
    $c->stash->{'readonly'} = 1 if defined $c->req->parameters->{'readonly'};

    $c->stash->{'dashboard_ignore_changes'} = defined $c->config->{'Thruk::Plugin::Panorama'}->{'dashboard_ignore_changes'} ? $c->config->{'Thruk::Plugin::Panorama'}->{'dashboard_ignore_changes'} : 0;
    $c->stash->{'dashboard_ignore_changes'} = 1 if defined $c->req->parameters->{'dashboard_ignore_changes'};

    Thruk::Utils::Panorama::set_is_admin($c);

    $c->stash->{one_tab_only}           = '';
    $c->stash->{'full_reload_interval'} = defined $c->config->{'Thruk::Plugin::Panorama'}->{'full_reload_interval'} ? $c->config->{'Thruk::Plugin::Panorama'}->{'full_reload_interval'} : 10800;
    $c->stash->{'extjs_version'}        = "4.2.2";

    $c->{'panorama_var'} = $c->config->{'var_path'}.'/panorama';
    Thruk::Utils::IO::mkdir_r($c->{'panorama_var'});
    $c->{'panorama_etc'} = $c->config->{'etc_path'}.'/panorama';
    Thruk::Utils::IO::mkdir_r($c->{'panorama_etc'});

    # REMOVE AFTER: 01.01.2021
    for my $oldfile (glob($c->{'panorama_var'}.'/*.tab')) {
        move($oldfile, $c->{'panorama_etc'}) or confess("cannot move dashboard $oldfile to ".$c->{'panorama_etc'}.": ".$!);
    }

    if(defined $c->req->uri->query) {
        if($c->req->uri->query eq 'state') {
            return(_stateprovider($c));
        }
    }

    if(defined $c->req->parameters->{'js'}) {
        return(_js($c));
    }

    if(defined $c->req->parameters->{'task'}) {
        my $task = $c->req->parameters->{'task'};
        if($task eq 'status') {
            return(_task_status($c));
        }
        if($task eq 'availability') {
            return(_task_availability($c));
        }
        elsif($task eq 'dashboard_save_states') {
            return(_task_dashboard_save_states($c));
        }
        elsif($task eq 'dashboard_data') {
            return(_task_dashboard_data($c));
        }
        elsif($task eq 'dashboard_list') {
            return(_task_dashboard_list($c));
        }
        elsif($task eq 'dashboard_update') {
            return(_task_dashboard_update($c));
        }
        elsif($task eq 'dashboard_restore_list') {
            return(_task_dashboard_restore_list($c));
        }
        elsif($task eq 'dashboard_restore_point') {
            return(_task_dashboard_restore_point($c));
        }
        elsif($task eq 'dashboard_restore') {
            return(_task_dashboard_restore($c));
        }
        elsif($task eq 'dashboards_clean') {
            return(_task_dashboards_clean($c));
        }
        elsif($task eq 'stats_core_metrics') {
            return(_task_stats_core_metrics($c));
        }
        elsif($task eq 'stats_check_metrics') {
            return(_task_stats_check_metrics($c));
        }
        elsif($task eq 'server_stats') {
            return(_task_server_stats($c));
        }
        elsif($task eq 'show_logs') {
            return(_task_show_logs($c));
        }
        elsif($task eq 'show_comments') {
            return(_task_show_comments($c));
        }
        elsif($task eq 'site_status') {
            return(_task_site_status($c));
        }
        elsif($task eq 'hosts') {
            return(_task_hosts($c));
        }
        elsif($task eq 'hosttotals') {
            return(_task_hosttotals($c));
        }
        elsif($task eq 'services') {
            return(_task_services($c));
        }
        elsif($task eq 'squares_data') {
            return(_task_squares_data($c));
        }
        elsif($task eq 'servicesminemap') {
            return(_task_servicesminemap($c));
        }
        elsif($task eq 'servicetotals') {
            return(_task_servicetotals($c));
        }
        elsif($task eq 'hosts_pie') {
            return(_task_hosts_pie($c));
        }
        elsif($task eq 'host_list') {
            return(_task_host_list($c));
        }
        elsif($task eq 'host_detail') {
            return(_task_host_detail($c));
        }
        elsif($task eq 'service_list') {
            return(_task_service_list($c));
        }
        elsif($task eq 'service_detail') {
            return(_task_service_detail($c));
        }
        elsif($task eq 'services_pie') {
            return(_task_services_pie($c));
        }
        elsif($task eq 'stats_gearman') {
            return(_task_stats_gearman($c));
        }
        elsif($task eq 'stats_gearman_grid') {
            return(_task_stats_gearman_grid($c));
        }
        elsif($task eq 'pnp_graphs') {
            return(_task_pnp_graphs($c));
        }
        elsif($task eq 'grafana_graphs') {
            return(_task_grafana_graphs($c));
        }
        elsif($task eq 'userdata_backgroundimages') {
            return(_task_userdata_backgroundimages($c));
        }
        elsif($task eq 'userdata_images') {
            return(_task_userdata_images($c));
        }
        elsif($task eq 'userdata_iconsets') {
            return(_task_userdata_iconsets($c));
        }
        elsif($task eq 'userdata_trendiconsets') {
            return(_task_userdata_trendiconsets($c));
        }
        elsif($task eq 'userdata_sounds') {
            return(_task_userdata_sounds($c));
        }
        elsif($task eq 'userdata_shapes') {
            return(_task_userdata_shapes($c));
        }
        elsif($task eq 'redirect_status') {
            return(_task_redirect_status($c));
        }
        elsif($task eq 'textsave') {
            return(_task_textsave($c));
        }
        elsif($task eq 'serveraction') {
            return(_task_serveraction($c));
        }
        elsif($task eq 'timezones') {
            return(_task_timezones($c));
        }
        elsif($task eq 'wms_provider') {
            return(_task_wms_provider($c));
        }
        elsif($task eq 'upload') {
            return(_task_upload($c));
        }
        elsif($task eq 'uploadecho') {
            return(_task_uploadecho($c));
        }
        elsif($task eq 'save_dashboard') {
            return(_task_save_dashboard($c));
        }
        elsif($task eq 'load_dashboard') {
            return(_task_load_dashboard($c));
        }
        elsif($task eq 'search') {
            return(_task_search($c));
        }
    }

    # find images for preloader
    _set_preload_images($c);

    # clean up?
    if($c->req->parameters->{'clean'}) {
        my $data = Thruk::Utils::get_user_data($c);
        delete $data->{'panorama'};
        Thruk::Utils::store_user_data($c, $data);
        return $c->redirect_to("panorama.cgi");
    }

    #&timing_breakpoint('loading _js');
    _js($c, 1);
    #&timing_breakpoint('loading _js done');

    $c->stash->{template} = 'panorama.tt';
    return 1;
}

##########################################################
sub _js {
    my($c, $only_data) = @_;

    # merge open dashboards into state
    my $data = Thruk::Utils::get_user_data($c);
    if($data->{'panorama'} && $data->{'panorama'}->{'tabpan'} && $data->{'panorama'}->{'tabpan'}->{'xdata'}) {
        $data->{'panorama'} = delete $data->{'panorama'}->{'tabpan'}->{'xdata'};
    }
    my $user_data = $data->{'panorama'} || {};
    my $open_tabs = $user_data->{'open_tabs'} || [];
    if(defined $c->req->parameters->{'map'}) {
        my $dashboard = _get_dashboard_by_name($c, $c->req->parameters->{'map'});
        if(!$dashboard) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such dashboard', code => 404 });
            return $c->redirect_to($c->stash->{'url_prefix'});
        }
        $open_tabs = [$dashboard->{'nr'}];
        $c->stash->{one_tab_only} = $dashboard->{'nr'};
        $c->stash->{title}        = $dashboard->{'tab'}->{'xdata'}->{'title'};
    } elsif(defined $c->req->parameters->{'maps'}) {
        $open_tabs = [];
        for my $name (@{Thruk::Utils::list($c->req->parameters->{'maps'})}) {
            my $dashboard = _get_dashboard_by_name($c, $name);
            if($dashboard) {
                push @{$open_tabs}, $dashboard->{'nr'};
            }
        }
        $user_data->{'activeTab'} = scalar @{$open_tabs} > 0 ? $open_tabs->[0] : "";
    } elsif($c->cookie('thruk_panorama_tabs')) {
        $open_tabs = [split(/\s*:\s*/mx, $c->cookie('thruk_panorama_tabs')->value)];
        if($c->cookie('thruk_panorama_active')) {
            $user_data->{'activeTab'} = $c->cookie('thruk_panorama_active')->value;
        }
    }

    if(scalar @{$open_tabs} == 0) {
        $open_tabs = ["0"];
        $user_data->{'activeTab'} = "0";
    }

    # restore last open tabs
    $user_data->{'open_tabs'} = $open_tabs;
    my $extstate = {
        tabbar => $user_data,
    };
    my $shapes = {};
    my $open_tabs_hash = Thruk::Utils::array2hash($open_tabs);
    for my $nr (@{$open_tabs}) {
        _add_initial_dashboard($c, $nr, $extstate, $shapes, $open_tabs_hash);
    }
    $c->stash->{shapes} = $shapes;

    $c->stash->{extstate}          = $extstate;
    $c->stash->{default_dashboard} = [];
    $c->stash->{shapes}            = $shapes;
    if($c->config->{'Thruk::Plugin::Panorama'}->{'default_dashboard'}) {
        my $default_dashboard = $c->config->{'Thruk::Plugin::Panorama'}->{'default_dashboard'};
        if(ref $c->config->{'Thruk::Plugin::Panorama'}->{'default_dashboard'} eq 'ARRAY') {
            $default_dashboard = join(',', @{$default_dashboard});
        }
        my @defaults = split(/\s*,+\s*/mx, $default_dashboard);
        $c->stash->{default_dashboard} = \@defaults;
    }

    my $action_menu_actions = [];
    if($c->config->{'action_menu_actions'}) {
        for my $name (keys %{$c->config->{'action_menu_actions'}}) {
            push @{$action_menu_actions}, $name;
        }
    }
    $c->stash->{action_menu_actions}   = $action_menu_actions;

    my $action_menu_items    = [];
    my $action_menu_items_js = '';
    if($c->config->{'action_menu_items'}) {
        for my $name (sort keys %{$c->config->{'action_menu_items'}}) {
            my $menu = Thruk::Utils::Filter::get_action_menu($c, $name);
            $action_menu_items_js .= delete $menu->{'data'} if $menu->{'type'} eq 'js';
            push @{$action_menu_items}, $menu;
        }
    }
    $c->stash->{action_menu_items}    = $action_menu_items;
    $c->stash->{action_menu_items_js} = $action_menu_items_js;

    $c->stash->{shape_data}         = _task_userdata_shapes($c, 1);
    $c->stash->{iconset_data}       = _task_userdata_iconsets($c, 1);
    $c->stash->{trendiconset_data}  = _task_userdata_trendiconsets($c, 1);
    $c->stash->{wms_provider}       = _get_wms_provider($c);
    $c->stash->{fonts}              = _get_available_fonts($c);

    # default geo map center
    $c->stash->{default_map_zoom} = $c->config->{'Thruk::Plugin::Panorama'}->{'geo_map_default_zoom'} || 5;
    my($lon,$lat) = split(/\s*,\s*/mx, ($c->config->{'Thruk::Plugin::Panorama'}->{'geo_map_default_center'} || '13.74,47.77'));
    $c->stash->{default_map_lon} = $lon;
    $c->stash->{default_map_lat} = $lat;

    $c->stash->{default_maintenance_text} = $c->config->{'Thruk::Plugin::Panorama'}->{'default_maintenance_text'} || '';

    my $default_state_order = $c->config->{'Thruk::Plugin::Panorama'}->{'default_state_order'} // $c->config->{'default_state_order'};
    $c->stash->{default_state_order} = [split(/\s*,\s*/mx, $default_state_order)];

    unless($only_data) {
        $c->res->headers->content_type('text/javascript; charset=UTF-8');
        $c->stash->{template} = 'panorama_js.tt';
    }
    return 1;
}

##########################################################
sub _stateprovider {
    my ( $c ) = @_;

    my $json;
    my $param = $c->req->parameters;
    my $task  = delete $param->{'task'};
    my $value = $param->{'value'};
    my $name  = $param->{'name'};
    if($c->stash->{'readonly'} || $c->stash->{'dashboard_ignore_changes'}) {
        $json = { 'status' => 'failed' };
    }
    elsif(defined $task and $task eq 'update2') {
        $json = { 'status' => 'ok' };
        my $replace = delete $param->{'replace'} || 0;
        my $newids  = [];
        my $newid   = delete $param->{'nr'} || '';
        for my $key (keys %{$param}) {
            next if !$param->{$key};
            next if $key eq 'current_tab';
            my $param_data = $param->{$key};
            if(ref $param_data eq '') {
                $param_data = decode_json($param->{$key});
            }
            if($key eq 'tabbar') {
                my $data = Thruk::Utils::get_user_data($c);
                $data->{'panorama'} = $param_data->{'xdata'};
                Thruk::Utils::store_user_data($c, $data);
            } else {
                # update dashboards
                for my $k2 (keys %{$param_data}) {
                    if($k2 eq 'id') {
                        $newid = $param_data->{$k2};
                    } else {
                        $param_data->{$k2} = $param_data->{$k2};
                        if(ref $param_data->{$k2} eq '') {
                            eval {
                                if($k2 eq 'tab') {
                                    # throws encoding error when having a dashboad with umlaut in title
                                    $param_data->{$k2} = encode_utf8($param_data->{$k2});
                                }
                                $param_data->{$k2} = decode_json($param_data->{$k2});
                            };
                            confess(Dumper("Error in parsing json:", $@, $k2, $param_data)) if $@;
                        }

                    }
                }
                $param_data->{'id'}   = $newid || $key;
                $param_data->{'user'} = $c->stash->{'remote_user'};
                my $extra = {};
                if($c->stash->{'is_admin'} && $param_data->{'tab'}->{'xdata'}->{'owner'}) {
                    $extra->{'user'} = $param_data->{'tab'}->{'xdata'}->{'owner'};
                }
                delete $param_data->{'tab'}->{'xdata'}->{'owner'};
                if(!_save_dashboard($c, $param_data, $extra)) {
                    $json = { 'status' => 'failed' };
                } else {
                    if($newid) {
                        $json->{'newid'} = $param_data->{'id'};
                        push @{$newids}, $param_data->{'id'};
                    }
                }
            }
        }
        if($replace) {
            my $data = Thruk::Utils::get_user_data($c);
            $data->{'panorama'}->{dashboards}->{'tabbar'}->{'open_tabs'} = $newids;
            Thruk::Utils::store_user_data($c, $data);
        }
    } else {
        $json = { 'status' => 'failed' };
    }

    _add_misc_details($c, 1, $json);
    return $c->render(json => $json);
}

##########################################################
sub _nice_ext_value {
    my($orig) = @_;
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
sub _task_status {
    my($c, $data_only, $params) = @_;

    $params = $c->req->parameters unless defined $params;

    # make status group filter faster
    $c->stash->{'cache_groups_filter'} = {} unless defined $c->stash->{'cache_groups_filter'};

    my $types        = {};
    my $tab_backends = $params->{'backends'};
    if($params->{'types'}) {
        if(ref $params->{'types'}) {
            $types = $params->{'types'};
        } else {
            $types = decode_json($params->{'types'});
        }
    }

    my $hostfilter    = Thruk::Utils::combine_filter('-or', [map {{name => $_}} keys %{$types->{'hosts'}}]);
    my $servicefilter = [];
    for my $host (keys %{$types->{'services'}}) {
        for my $svc (keys %{$types->{'services'}->{$host}}) {
            push @{$servicefilter}, { '-and' => { host_name => $host, description => $svc}};
        }
    }
    $servicefilter = Thruk::Utils::combine_filter('-or', $servicefilter);

    my $state_type = SOFT_STATE;
    if(defined $params->{'state_type'} && $params->{'state_type'} eq 'hard') {
        $state_type = HARD_STATE;
    }

    if($params->{'reschedule'}) {
        Thruk::Action::AddDefaults::set_enabled_backends($c, $tab_backends);
        # works only for a single host or service
        $c->stash->{'now'}                   = time();
        $c->req->parameters->{'cmd_mod'}     = 2;
        $c->req->parameters->{'force_check'} = 0;
        $c->req->parameters->{'start_time'}  = time();
        $c->req->parameters->{'json'}        = 1;
        $c->req->parameters->{'service'}     = '';
        if(scalar keys %{$types->{'hosts'}} == 1) {
            my $hosts  = $c->{'db'}->get_hosts(filter  => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ],
                                               columns => [qw/name/]);
            if(scalar @{$hosts} == 1) {
                $c->req->parameters->{'cmd_typ'} = 96;
                $c->req->parameters->{'host'}    = $hosts->[0]->{'name'};
                $c->req->parameters->{'backend'} = [$hosts->[0]->{'peer_key'}];
            } else {
                Thruk::Utils::set_message($c, 'fail_message', 'Found '.(scalar @{$hosts}).' hosts. Cannot send reschedule command.');
            }
        }
        elsif(scalar keys %{$types->{'services'}} == 1) {
            my $services = $c->{'db'}->get_services(filter  => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter ],
                                                    columns => [qw/host_name description/]);
            if(scalar @{$services} == 1) {
                $c->req->parameters->{'cmd_typ'} = 7;
                $c->req->parameters->{'host'}    = $services->[0]->{'host_name'};
                $c->req->parameters->{'service'} = $services->[0]->{'description'};
                $c->req->parameters->{'backend'} = [$services->[0]->{'peer_key'}];
            } else {
                Thruk::Utils::set_message($c, 'fail_message', 'Found '.(scalar @{$services}).' services. Cannot send reschedule command.');
            }
        }
        $c->stash->{'use_csrf'} = 0;
        if($params->{'cmd_typ'}) {
            require Thruk::Controller::cmd;
            if(Thruk::Controller::cmd::do_send_command($c)) {
                Thruk::Utils::set_message( $c, 'success_message', 'Commands successfully submitted' );
                Thruk::Controller::cmd::redirect_or_success($c, -2, 1);
            }
        }
    }

    my $data = {};
    if(scalar keys %{$types->{'filter'}} > 0) {
        for my $f (keys %{$types->{'filter'}}) {
            my($incl_hst, $incl_svc, $filter, $backends) = @{decode_json($f)};
            next if $c->stash->{'has_error'};
            delete $c->req->parameters->{'backend'};
            delete $c->req->parameters->{'backends'};
            if($backends && scalar @{$backends} > 0 && (scalar @{$backends} != 1 || $backends->[0] ne '')) {
                Thruk::Action::AddDefaults::set_enabled_backends($c, $backends);
            } else {
                Thruk::Action::AddDefaults::set_enabled_backends($c, $tab_backends);
            }
            $c->req->parameters->{'filter'} = $filter;
            my( $hfilter, $sfilter, $hostgroupfilter, $servicegroupfilter, $has_service_filter ) = _do_filter($c);
            $data->{'filter'}->{$f} = _summarize_query($c, $incl_hst, $incl_svc, $hfilter, $sfilter, $state_type, $has_service_filter);
        }
        Thruk::Action::AddDefaults::set_enabled_backends($c, $tab_backends);
    }
    if(scalar keys %{$types->{'hostgroups'}} > 0) {
        $data->{'hostgroups'} = [values %{_summarize_hostgroup_query($c, $types->{'hostgroups'}, $state_type)}];
    }
    if(scalar keys %{$types->{'servicegroups'}} > 0) {
        $data->{'servicegroups'} = [values %{_summarize_servicegroup_query($c, $types->{'servicegroups'}, $state_type)}];
    }
    if(scalar keys %{$types->{'hosts'}} > 0) {
        my $columns = [qw/name alias state state_type has_been_checked scheduled_downtime_depth acknowledged last_state_change last_check plugin_output
                          last_notification current_notification_number perf_data next_check action_url_expanded notes_url_expanded
                         /];
        push @{$columns}, "long_plugin_output" if $types->{'has_long_plugin_output'};
        $data->{'hosts'} = $c->{'db'}->get_hosts(filter  => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ],
                                                 columns => $columns,
                                                );
        if($c->config->{'shown_inline_pnp'}) {
            for my $hst (@{$data->{'hosts'}}) {
                $hst->{'pnp_url'} = Thruk::Utils::get_pnp_url($c, $hst);
            }
        }
    }
    if(scalar keys %{$types->{'services'}} > 0) {
        my $columns = [qw/host_name host_alias description state state_type has_been_checked scheduled_downtime_depth acknowledged last_state_change last_check
                          plugin_output last_notification current_notification_number perf_data next_check action_url_expanded notes_url_expanded
                         /];
        push @{$columns}, "long_plugin_output" if $types->{'has_long_plugin_output'};
        $data->{'services'} = $c->{'db'}->get_services(filter  => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter ],
                                                       columns => $columns,
                                                      );
        if($c->config->{'shown_inline_pnp'}) {
            for my $svc (@{$data->{'services'}}) {
                $svc->{'pnp_url'} = Thruk::Utils::get_pnp_url($c, $svc);
            }
        }
    }

    return $data if $data_only;

    # add status data for sub dashboards
    if($params->{'sub'}) {
        my $sub = decode_json($params->{'sub'});
        $data->{'sub'} = {};
        for my $key (keys %{$sub}) {
            $data->{'sub'}->{$key} = _task_status($c, 1, $sub->{$key});
        }
    }

    $data->{backends} = $c->stash->{'backend_detail'};

    my $json = { data => $data };

    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_redirect_status {
    my($c) = @_;
    my $types = {};
    if($c->req->parameters->{'filter'}) {
        my($hfilter, $sfilter, $hostgroupfilter, $servicegroupfilter, $has_service_filter) = _do_filter($c);
        $c->req->parameters->{'filter'} = '';
        $c->req->parameters->{'task'}   = '';
        my $url = Thruk::Utils::Filter::uri_with($c, $c->req->parameters);
        $url    =~ s/^panorama.cgi/status.cgi/gmx;
        $url    =~ s/\&amp;filter=.*?\&amp;/&amp;/gmx;
        $url    =~ s/\&amp;task=.*?\&amp;/&amp;/gmx;
        $url    =~ s/\&amp;/&/gmx;
        if($has_service_filter) {
            $url =~ s/style=hostdetail/style=detail/gmx;
        }
        return $c->redirect_to($url);
    }
    return $c->redirect_to("status.cgi");
}

##########################################################
sub _task_textsave {
    my($c) = @_;
    my $file = $c->req->parameters->{'file'} || "log.txt";
    $c->res->headers->header('Content-Disposition', 'attachment; filename="'.$file.'"');
    $c->res->headers->content_type('application/octet-stream');
    $c->stash->{text}     = $c->req->parameters->{'text'};
    $c->stash->{template} = 'passthrough.tt';
    return;
}

##########################################################
sub _task_serveraction {
    my($c) = @_;
    my($rc, $msg);
    # if there is a dashboard in our parameters, make sure we have proper permissions
    if($c->req->parameters->{'dashboard'} && Thruk::Utils::Panorama::is_authorized_for_dashboard($c, $c->req->parameters->{'dashboard'}) == ACCESS_NONE) {
        ($rc, $msg) = (1, 'no permission for this dashboard');
    } else {
        ($rc, $msg) = Thruk::Utils::Status::serveraction($c);
    }
    my $json = { 'rc' => $rc, 'msg' => $msg };
    _add_misc_details($c, 1, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_upload {
    my($c) = @_;

    $c->stash->{'template'} = 'passthrough.tt';

    my $type     = $c->req->parameters->{'type'};
    my $location = $c->req->parameters->{'location'};
    if(!$type || !$location || !$c->req->uploads->{$type}) {
        # must be text/html result, otherwise extjs form result handler dies
        $c->stash->{text} = Thruk::Utils::Filter::json_encode({ 'msg' => 'missing properties in fileupload.', success => Cpanel::JSON::XS::false });
        return;
    }
    $location =~ s|/$||gmx;

    if($c->config->{'demo_mode'}) {
        # must be text/html result, otherwise extjs form result handler dies
        $c->stash->{text} = Thruk::Utils::Filter::json_encode({ 'msg' => 'fileupload is disabled in demo mode.', success => Cpanel::JSON::XS::false });
        return;
    }

    my $upload = $c->req->uploads->{$type};
    my $folder = $c->stash->{'usercontent_folder'}.'/'.$location;

    if(!-w $folder.'/.') {
        # must be text/html result, otherwise extjs form result handler dies
        $c->stash->{text} = Thruk::Utils::Filter::json_encode({ 'msg' => 'Fileupload must use existing and writable folder.', success => Cpanel::JSON::XS::false });
        return;
    }

    if($upload->{'size'} > (50*1024*1024)) { # not more than 50MB
        # must be text/html result, otherwise extjs form result handler dies
        $c->stash->{text} = Thruk::Utils::Filter::json_encode({ 'msg' => 'Fileupload exceeds the allowed filesize of 50MB.', success => Cpanel::JSON::XS::false });
        return;
    }

    my $filename = $upload->{'filename'};
    $filename =~ s|^/||gmx;
    if($filename !~ m/^[a-z0-9_\- ]+\.(jpeg|jpg|gif|png|svg)$/mxi) {
        # must be text/html result, otherwise extjs form result handler dies
        $c->stash->{text} = Thruk::Utils::Filter::json_encode({ 'msg' => 'Fileupload contains invalid characters (a-z0-9_- ) in filename.', success => Cpanel::JSON::XS::false });
        return;
    }

    my $newlocation = $folder.'/'.$filename;
    if(-s $newlocation && !_check_media_permissions($c, $newlocation)) {
        # must be text/html result, otherwise extjs form result handler dies
        $c->stash->{text} = Thruk::Utils::Filter::json_encode({ 'msg' => 'Only administrator/panorama_view_media_manager roles may overwrite existing files.', success => Cpanel::JSON::XS::false });
        return;
    }

    eval {
        move($upload->{'tempname'}, $newlocation);
    };
    if($@) {
        # must be text/html result, otherwise extjs form result handler dies
        $c->stash->{text} = Thruk::Utils::Filter::json_encode({ 'msg' => $@, success => Cpanel::JSON::XS::false });
        return;
    }

    # must be text/html result, otherwise extjs form result handler dies
    $c->stash->{text} = Thruk::Utils::Filter::json_encode({ 'msg' => 'Upload successfull', success => Cpanel::JSON::XS::true, filename => $filename });
    return;
}

##########################################################
sub _task_uploadecho {
    my($c) = @_;

    $c->stash->{'template'} = 'passthrough.tt';

    if(!$c->req->uploads->{'file'}) {
        # must be text/html result, otherwise extjs form result handler dies
        $c->stash->{text} = Thruk::Utils::Filter::json_encode({ 'msg' => 'missing file in fileupload.', success => Cpanel::JSON::XS::false });
        return;
    }

    my $upload = $c->req->uploads->{'file'};
    if($upload->{'size'} > (50*1024*1024)) { # not more than 50MB
        # must be text/html result, otherwise extjs form result handler dies
        $c->stash->{text} = Thruk::Utils::Filter::json_encode({ 'msg' => 'Fileupload exceeds the allowed filesize of 50MB.', success => Cpanel::JSON::XS::false });
        return;
    }

    my $content = read_file($upload->{'tempname'});
    unlink($upload->{'tempname'});

    # must be text/html result, otherwise extjs form result handler dies
    $c->stash->{text} = Thruk::Utils::Filter::json_encode({ 'msg' => 'Upload successfull', success => Cpanel::JSON::XS::true, content => $content });
    return;
}

##########################################################
sub _task_save_dashboard {
    my($c) = @_;

    my $nr   = $c->req->parameters->{'nr'} || die('no number supplied');
    $nr      =~ s/^pantab_//gmx;
    my $d = Thruk::Utils::Panorama::load_dashboard($c, $nr);
    return unless Thruk::Utils::Panorama::is_authorized_for_dashboard($c, $nr, $d) >= ACCESS_READONLY;

    my $data = {
        usercontent => {},
        version     => Thruk::Utils::Filter::fullversion($c),
    };
    for my $key (keys %{$d}) {
        if($key =~ m/^(tab|panlet)/mx) {
            $data->{$key} = $d->{$key};
        }
    }
    # add image data
    require MIME::Base64;
    my $images = {};
    for my $id (sort keys %{$d}) {
        my $p = $d->{$id};
        next unless ref $p eq 'HASH';
        # dashboard background
        if($p->{'xdata'}->{'background'}) {
            my $file = $p->{'xdata'}->{'background'};
            if($file =~ s|^../usercontent/||mx && $file !~ m|\.\.|mx) {
                next if $file eq 'backgrounds/europa.png';
                next if $file eq 'backgrounds/world.png';
                next if $file eq 'backgrounds/world.svg';
                next if $file eq 'backgrounds/europa.svg';
                next if $file eq 'backgrounds/germany.svg';
                $images->{$file} = $c->stash->{'usercontent_folder'}.'/'.$file;
            }
        }
        # type image
        if($p->{'xdata'}->{'appearance'} && $p->{'xdata'}->{'appearance'}->{'type'} && $p->{'xdata'}->{'appearance'}->{'type'} eq 'icon') {
            my $file = $p->{'xdata'}->{'general'}->{'src'};
            if($file && $file =~ s|^../usercontent/||mx && $file !~ m|\.\.|mx) {
                $images->{$file} = $c->stash->{'usercontent_folder'}.'/'.$file;
            }
        }
        # type icon - iconset
        if($p->{'xdata'}->{'appearance'} && $p->{'xdata'}->{'appearance'}->{'iconset'}) {
            my $file = $p->{'xdata'}->{'appearance'}->{'iconset'};
            if($file && $file !~ m|/|mx && $file !~ m|\.\.|mx) {
                next if $file eq 'default'; # skip our default sets
                next if $file eq 'default_64';
                next if $file eq 'tfl';
                next if $file eq 'emoji';
                next if $file eq 'emoji_64';
                my @files = glob($c->stash->{'usercontent_folder'}.'/images/status/'.$file.'/*');
                my $usercontent_folder = $c->stash->{'usercontent_folder'}.'/';
                for my $f (@files) {
                    my $short = $f;
                    $short =~ s|^$usercontent_folder||mx;
                    $images->{$short} = $f;
                }
            }
        }
    }
    for my $image (sort keys %{$images}) {
        my $file = $images->{$image};
        next unless -r $file;
        $data->{'usercontent'}->{$image} = MIME::Base64::encode_base64("".read_file($file));
    }
    $c->stash->{'template'} = 'passthrough.tt';
    my $text = "";
    $text   .= "# Thruk Panorama Dashboard Export: ".$d->{'tab'}->{'xdata'}->{'title'}."\n";
    $text   .= Thruk::Utils::Filter::json_encode($data);
    $text   .= "\n# End Export\n";
    $c->stash->{text} = $text;
    $c->res->headers->header( 'Content-Disposition', 'attachment; filename="'.$d->{'tab'}->{'xdata'}->{'title'}.'.dashboard"' );
    return;
}

##########################################################
sub _task_load_dashboard {
    my($c) = @_;

    $c->stash->{'template'} = 'passthrough.tt';

    if(!$c->req->uploads->{'file'}) {
        # must be text/html result, otherwise extjs form result handler dies
        $c->stash->{text} = Thruk::Utils::Filter::json_encode({ 'msg' => 'missing file in fileupload.', success => Cpanel::JSON::XS::false });
        return;
    }

    my $upload = $c->req->uploads->{'file'};
    if($upload->{'size'} > (50*1024*1024)) { # not more than 50MB
        # must be text/html result, otherwise extjs form result handler dies
        $c->stash->{text} = Thruk::Utils::Filter::json_encode({ 'msg' => 'File exceeds the allowed filesize of 50MB.', success => Cpanel::JSON::XS::false });
        return;
    }

    my $content = read_file($upload->{'tempname'});
    unlink($upload->{'tempname'});

    $content =~ s/^\#.*$//gmx;
    my $data;
    eval {
        $data = decode_json($content);
    };
    if($@) {
        # must be text/html result, otherwise extjs form result handler dies
        $c->stash->{text} = Thruk::Utils::Filter::json_encode({ 'msg' => 'This is not a valid dashboard', success => Cpanel::JSON::XS::false });
        return;
    }

    delete $data->{'version'};

    if($data->{'usercontent'}) {
        require MIME::Base64;
        my $usercontent_folder = $c->stash->{'usercontent_folder'}.'/';
        for my $file (sort keys %{$data->{'usercontent'}}) {
            my $size = -s $usercontent_folder.$file;
            next if $c->config->{'demo_mode'};
            next if $size && !_check_media_permissions($c, $usercontent_folder.$file); # overwrite only if user is allowed to
            my $content = MIME::Base64::decode_base64($data->{'usercontent'}->{$file});
            next if($size && length($content) == $size);
            my $dir     = $file;
            $dir        =~ s|/[^/]+$||mx;
            eval {
                Thruk::Utils::IO::mkdir_r($usercontent_folder.$dir);
                Thruk::Utils::IO::write($usercontent_folder.$file,$content);
            };
            if($@) {
                _error('Usercontent upload for '.$file.' failed: '.$@);
                $c->stash->{text} = Thruk::Utils::Filter::json_encode({ 'msg' => 'Usercontent upload for '.$file.' failed.', success => Cpanel::JSON::XS::false });
                return;
            }
        }
        delete $data->{'usercontent'};
    }
    $data->{'id'}   = 'new';
    $data->{'user'} = $c->stash->{'remote_user'};
    $data = _save_dashboard($c, $data);
    my $newid = $data->{'id'};

    # must be text/html result, otherwise extjs form result handler dies
    $c->stash->{text} = Thruk::Utils::Filter::json_encode({ 'msg' => 'Import successfull', success => Cpanel::JSON::XS::true, newid => $newid });
    return;
}

##########################################################
sub _task_search {
    my($c) = @_;

    my $query = $c->req->parameters->{'value'} || '';
    $query =~ s/^\s+//gmx;
    $query =~ s/\s+$//gmx;
    $query =~ s/\s+/.*/gmx;
    my $json = { 'rc' => 0, 'data' => [] };
    _add_misc_details($c, undef, $json);
    return $c->render(json => $json) unless $query;

    my $dashboards = Thruk::Utils::Panorama::get_dashboard_list($c, 'all', 1);

    # search names and aliases
    my $search = {
        'host'         => $c->{'db'}->get_hosts( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hosts' ), { '-or' => [ { name => { '~~' => $query } }, { alias => { '~~' => $query } } ] } ], columns => [qw/name alias/]),
        'hostgroup'    => $c->{'db'}->get_hostgroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'hostgroups' ), { '-or' => [ { name => { '~~' => $query } }, { alias => { '~~' => $query } } ] } ], columns => [qw/name alias/]),
        'service'      => $c->{'db'}->get_services( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'services' ), { '-or' => [ { description => { '~~' => $query } }, { display_name => { '~~' => $query } } ] } ], columns => [qw/description display_name/]),
        'servicegroup' => $c->{'db'}->get_hostgroups( filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'servicegroups' ), { '-or' => [ { name => { '~~' => $query } }, { alias => { '~~' => $query } } ] } ], columns => [qw/name alias/]),
    };

    # normalize services
    for my $o (@{$search->{"service"}}) {
        $o->{'name'}  = delete $o->{'description'};
        $o->{'alias'} = delete $o->{'display_name'};
    }

    my $data  = {};
    for my $d (@{$dashboards}) {
        my $found = _search_match($data, $d, $d->{'tab'}->{'xdata'}->{'title'}, $query, "title")
                 || _search_match($data, $d, $d->{'tab'}->{'xdata'}->{'description'}, $query, "description");

        for my $icon_id (sort keys %{$d}) {
            my $icon = $d->{$icon_id};
            next unless ref $icon eq 'HASH';
            next unless $icon->{'xdata'};

            for my $type (sort keys %{$search}) {
                if($icon->{'xdata'}->{'general'}->{$type}) {
                    for my $o (@{$search->{$type}}) {
                        my $found = _search_match($data, $d, $icon->{'xdata'}->{'general'}->{$type}, $query, $type, $o);
                        if($found) {
                            $found->{'highlight'} = $icon_id;
                            $found->{'object'}    = $o;
                        }
                    }
                }
                if(!$found) {
                    my $found = _search_match($data, $d, $icon->{'xdata'}->{'general'}->{$type}, $query, $type);
                    if($found) {
                        $found->{'highlight'} = $icon_id;
                    }
                }
            }

            my $found = _search_match($data, $d, $icon->{'xdata'}->{'label'}->{'labeltext'}, $query, "iconlabel")
                     || _search_match($data, $d, $icon->{'xdata'}->{'general'}->{'text'}, $query, "icontext");
            if($found) {
                $found->{'highlight'} = $icon_id;
            }
        }
    }

    # sort by dashboard name
    $json->{'data'} = [sort { $a->{'name'} cmp $b->{'name'} } values(%{$data})];

    return $c->render(json => $json);
}

##########################################################
sub _search_match {
    my($result, $dashboard, $field, $query, $type, $names) = @_;
    return unless defined $field;

    # strip html and tags
    $field =~ s/\{\{.*?\}\}//gmx;
    $field =~ s/<.*?>//gmx;

    my($matched, $pre,$match,$post) = (0, '', '', '');
    if($names) {
        return if $names->{'name'} ne $field;
        $field   = $names->{'name'} eq $names->{'alias'} ? $names->{'name'} : $names->{'name'}.' - '.$names->{'alias'};
        $match   = $query;
        $matched = 1;
    }
    ## no critic
    if($field =~ m#(.*)($query)(.*)#si) {
        ($pre,$match,$post) = ($1,$2,$3);
        $matched = 1;
    }
    ## use critic

    return unless $matched;
    my $found = {
        type  => $type,
        match => $match,
        pre   => $pre,
        post  => $post,
        value => $field,
    };
    $result->{$dashboard->{id}} = {
        id      => $dashboard->{id},
        name    => $dashboard->{'tab'}->{'xdata'}->{'title'},
        matches => [],
    } unless $result->{$dashboard->{id}};
    push @{$result->{$dashboard->{id}}->{'matches'}}, $found;
    return($found);
}

##########################################################
sub _task_wms_provider {
    my($c) = @_;

    my $provider = _get_wms_provider($c);
    my $json = { 'rc' => 0, 'data' => $provider };
    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _get_wms_provider {
    my($c) = @_;
    my $provider = [];
    my $list     = $c->config->{'Thruk::Plugin::Panorama'}->{'wms_provider'};
    if(ref $list eq "") { $list = [$list] }
    for my $entry (@{$list}) {
        next unless $entry;
        my($name, $data) = split(/\s*=\s*/mx, $entry, 2);
        $name =~ s/^\s*//gmx;
        $name =~ s/\s*$//gmx;
        $data =~ s/^\s*//gmx;
        $data =~ s/\s*$//gmx;
        next unless $data;
        eval {
            my $test = Cpanel::JSON::XS::decode_json($data);
        };
        if($@) {
            print STDERR "error in wms provider: ".$@;
            print STDERR $entry,"\n";
            die("error in wms provider: ".$@."\nat entry: ".$entry."\n");
        }
        push @{$provider}, { name => $name, provider => $data };
    }
    return($provider);
}


##########################################################
sub _task_timezones {
    my($c) = @_;

    my $query = $c->req->parameters->{'query'} || '';
    my $data  = [];
    for my $tz (@{Thruk::Utils::get_timezone_data($c)}) {
        next if($query && $tz->{'text'} !~ m/$query/mxi);
        push @{$data}, $tz;
    }

    my $json = { 'rc' => 0, 'data' => $data };
    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}


##########################################################
sub _task_availability {
    my($c) = @_;

    # make status group filter faster
    $c->stash->{'cache_groups_filter'} = {};

    if($c->req->parameters->{'force'}) {
        return(avail_update($c));
    }

    $c->stats->profile(begin => "_task_avail");
    if($c->req->parameters->{'force'}) {
        avail_update($c);
    } else {
        Thruk::Utils::External::perl($c, { expr       => 'Thruk::Controller::panorama::avail_update($c)',
                                           message    => 'availability is being calculated',
                                           background => 1,
                                        });
    }
    my $res = avail_update($c, 1);
    $c->stats->profile(end => "_task_avail");
    return($res);
}

##########################################################

=head2 avail_update

  avail_update($c, [$cached_only])

returns calculated availability data in json format

=cut
sub avail_update {
    my($c, $cached_only) = @_;

    $c->stats->profile(begin => "avail_update");
    my $in    = {};
    my $types = {};

    my $tab_backends = $c->req->parameters->{'backends'};
    return $c->render(json => {status => 'ok', msg => 'nothing to do'}) if(!defined $c->req->parameters->{'avail'} || $c->req->parameters->{'avail'} eq 'null');
    if($c->req->parameters->{'avail'}) { $in    = decode_json($c->req->parameters->{'avail'}); }
    if($c->req->parameters->{'types'}) { $types = decode_json($c->req->parameters->{'types'}); }
    my $cache = Thruk::Utils::Cache->new($c->config->{'var_path'}.'/availability.cache');

    # cache hit?
    my @cache_prefix;
    if($c->check_user_roles('authorized_for_all_hosts') && $c->check_user_roles('authorized_for_all_services')) {
        my $tmp_cache = $cache->get('global');
        if(!defined $tmp_cache) {
            $cache->set('global', {});
        }
        @cache_prefix = ('global');
    } else {
        my $tmp_cache = $cache->get('users');
        if(!defined $tmp_cache->{$c->stash->{'remote_user'}}) {
            $tmp_cache->{$c->stash->{'remote_user'}} = {};
            $cache->set('users', $c->stash->{'remote_user'}, {});
        }
        @cache_prefix = ('users', $c->stash->{'remote_user'});
    }

    my $data = {};
    my $now  = time();
    Thruk::Action::AddDefaults::set_enabled_backends($c, $tab_backends);
    if(scalar keys %{$types->{'filter'}} > 0) {
        for my $f (keys %{$types->{'filter'}}) {
            # check if this filter is used in availabilities at all
            my $found = 0;
            for my $panel (@{$types->{'filter'}->{$f}}) {
                if($in->{$panel}) { $found = 1; last; }
            }
            next unless $found;

            Thruk::Utils::Avail::reset_req_parameters($c);
            my $filtername = "$f"; # results in *** glibc detected *** perl: double free or corruption (!prev): 0x0e482c38 *** otherwise
            my($incl_hst, $incl_svc, $filter, $backends) = @{decode_json($f)};
            delete $c->req->parameters->{'backend'};
            delete $c->req->parameters->{'backends'};
            if((ref $backends eq "" and $backends) || (ref $backends eq 'ARRAY' && scalar @{$backends} > 0)) {
                Thruk::Action::AddDefaults::set_enabled_backends($c, $backends);
            } else {
                Thruk::Action::AddDefaults::set_enabled_backends($c, $tab_backends);
            }
            $c->req->parameters->{'filter'} = $filter;
            my( $hfilter, $sfilter, $groupfilter ) = _do_filter($c);
            next if $c->stash->{'has_error'};
            for my $panel (@{$types->{'filter'}->{$f}}) {
                for my $key (keys %{$in->{$panel}}) {
                    my $opts   = $in->{$panel}->{$key}->{opts};
                    Thruk::Utils::Avail::reset_req_parameters($c);
                    if($opts->{'incl_hst'} || (!$opts->{'incl_hst'} && !$opts->{'incl_svc'})) {
                        if($hfilter) {
                            $c->req->parameters->{h_filter} = $hfilter;
                        } else {
                            $c->req->parameters->{host}     = 'all';
                        }
                    }
                    if($opts->{'incl_svc'} || (!$opts->{'incl_hst'} && !$opts->{'incl_svc'})) {
                        if($sfilter) {
                            $c->req->parameters->{s_filter} = $sfilter;
                        } else {
                            $c->req->parameters->{service}  = 'all';
                        }
                    }
                    my $cached = $cache->get(@cache_prefix, 'filter', $filtername, $key);
                    $cache->set(@cache_prefix, 'filter', $filtername, $key, {val => -1, time => $now}) if(!$cached && !$cached_only);
                    $data->{$panel}->{$key} = _avail_calc($c, $cached_only, $now, $cached, $opts, undef, undef, 1);
                    $cache->set(@cache_prefix, 'filter', $filtername, $key, {val => $data->{$panel}->{$key}, time => $now}) if !$cached_only;
                }
            }
        }
        Thruk::Action::AddDefaults::set_enabled_backends($c, $tab_backends);
    }
    if(scalar keys %{$types->{'hostgroups'}} > 0) {
        for my $group (keys %{$types->{'hostgroups'}}) {
            Thruk::Utils::Avail::reset_req_parameters($c);
            $c->req->parameters->{hostgroup} = $group;
            for my $panel (@{$types->{'hostgroups'}->{$group}}) {
                for my $key (keys %{$in->{$panel}}) {
                    my $opts   = $in->{$panel}->{$key}->{opts};
                    my $cached = $cache->get(@cache_prefix, 'hostgroups', $group, $key);
                    $cache->set(@cache_prefix, 'hostgroups', $group, $key, {val => -1, time => $now}) if(!$cached && !$cached_only);
                    if($opts->{'incl_svc'} || (!$opts->{'incl_hst'} && !$opts->{'incl_svc'})) {
                        $c->req->parameters->{include_host_services} = 1;
                    }
                    $data->{$panel}->{$key} = _avail_calc($c, $cached_only, $now, $cached, $opts);
                    $cache->set(@cache_prefix, 'hostgroups', $group, $key, {val => $data->{$panel}->{$key}, time => $now}) if !$cached_only;
                }
            }
        }
    }
    if(scalar keys %{$types->{'servicegroups'}} > 0) {
        for my $group (keys %{$types->{'servicegroups'}}) {
            Thruk::Utils::Avail::reset_req_parameters($c);
            $c->req->parameters->{servicegroup} = $group;
            for my $panel (@{$types->{'servicegroups'}->{$group}}) {
                for my $key (keys %{$in->{$panel}}) {
                    my $cached = $cache->get(@cache_prefix, 'servicegroups', $group, $key);
                    $cache->set(@cache_prefix, 'servicegroups', $group, $key, {val => -1, time => $now}) if(!$cached && !$cached_only);
                    $data->{$panel}->{$key} = _avail_calc($c, $cached_only, $now, $cached, $in->{$panel}->{$key}->{opts});
                    $cache->set(@cache_prefix, 'servicegroups', $group, $key, {val => $data->{$panel}->{$key}, time => $now}) if !$cached_only;
                }
            }
        }
    }
    if(scalar keys %{$types->{'hosts'}} > 0) {
        for my $host (keys %{$types->{'hosts'}}) {
            Thruk::Utils::Avail::reset_req_parameters($c);
            $c->req->parameters->{host} = $host;
            $c->req->parameters->{include_host_services} = 0;
            for my $panel (@{$types->{'hosts'}->{$host}}) {
                for my $key (keys %{$in->{$panel}}) {
                    my $cached = $cache->get(@cache_prefix, 'hosts', $host, $key);
                    $cache->set(@cache_prefix, 'hosts', $host, $key, {val => -1, time => $now}) if(!$cached && !$cached_only);
                    $data->{$panel}->{$key} = _avail_calc($c, $cached_only, $now, $cached, $in->{$panel}->{$key}->{opts}, $host);
                    $cache->set(@cache_prefix, 'hosts', $host, $key, {val => $data->{$panel}->{$key}, time => $now}) if !$cached_only;
                }
            }
        }
    }
    if(scalar keys %{$types->{'services'}} > 0) {
        for my $host (keys %{$types->{'services'}}) {
            for my $service (keys %{$types->{'services'}->{$host}}) {
                Thruk::Utils::Avail::reset_req_parameters($c);
                $c->req->parameters->{host}    = $host;
                $c->req->parameters->{service} = $service;
                for my $panel (@{$types->{'services'}->{$host}->{$service}}) {
                    for my $key (keys %{$in->{$panel}}) {
                        my $cached = $cache->get(@cache_prefix, 'services', $host, $service, $key);
                        $cache->set(@cache_prefix, 'services', $host, $service, $key, {val => -1, time => $now}) if(!$cached && !$cached_only);
                        $data->{$panel}->{$key} = _avail_calc($c, $cached_only, $now, $cached, $in->{$panel}->{$key}->{opts}, $host, $service);
                        $cache->set(@cache_prefix, 'services', $host, $service, $key, {val => $data->{$panel}->{$key}, time => $now}) if !$cached_only;
                    }
                }
            }
        }
    }

    # clean up cache
    $c->stats->profile(begin => "_avail_clean_cache");
    my $cached = $cache->get();
    _avail_clean_cache($cached, $now - 86400);
    $cache->set($cached);
    $c->stats->profile(end => "_avail_clean_cache");

    my $json = { data => $data };

    $c->stats->profile(end => "avail_update");
    return $c->render(json => $json);
}

##########################################################
sub _avail_clean_cache {
    my($data, $expire) = @_;
    for my $key (keys %{$data}) {
        if(ref $data->{$key} eq 'HASH') {
            if(exists $data->{$key}->{'time'}) {
                if($data->{$key}->{'time'} < $expire) {
                    delete $data->{$key};
                }
            } else {
                _avail_clean_cache($data->{$key}, $expire);
            }
            if(scalar keys %{$data->{$key}} == 0) {
                delete $data->{$key};
            }
        }
    }
    return;
}

##########################################################
sub _avail_calc {
    my($c, $cached_only, $now, $cached, $opts, $host, $service, $filter) = @_;
    my $duration = Thruk::Utils::expand_duration($opts->{'d'});
    my $unavailable_states = {'down' => 1, 'unreachable' => 1, 'critical' => 1, 'unknown' => 1};
    my $cache_retrieve_factor = $c->config->{'Thruk::Plugin::Panorama'}->{'cache_retrieve_factor'} || 0.0025; # ~ once a day for yearly values, every ~ 3.5 minutes for daily averages

    # cache hit?
    if($cached && !$c->req->parameters->{'force'}) {
        my $refresh = 0;
        if($now > $cached->{'time'} + $duration * $cache_retrieve_factor) {
            $refresh = 1;
        }
        # retry unknown values every 2 minutes
        elsif(!looks_like_number($cached->{'val'}) || $cached->{'val'} == -1) {
            if($now > $cached->{'time'} + 120) {
                $refresh = 1;
            }
        }
        if(!$refresh) {
            return($cached->{'val'});
        }
    }
    if($cached_only) {
        if(defined $cached->{'val'}) {
            if($now > $cached->{'time'} + $duration * $cache_retrieve_factor*5 && $now > $cached->{'time'} + 180) {
                # better return unknown for really old cached values
                return(-1);
            }
            return($cached->{'val'});
        }
        return(-1);
    }

    $cached->{'time'} = $now;

    $c->req->parameters->{t2}            = time();
    $c->req->parameters->{t1}            = $c->req->parameters->{t2} - $duration;
    $c->req->parameters->{rpttimeperiod} = $opts->{'tm'};
    if($opts->{'h'}) {
        $unavailable_states->{'down'}        = 0;
        $unavailable_states->{'unreachable'} = 0;
        for my $chr (split//mx, lc $opts->{'h'}) {
            if($chr eq 'd') { $unavailable_states->{'down'}        = 1; }
            if($chr eq 'u') { $unavailable_states->{'unreachable'} = 1; }
        }
    }
    if($opts->{'s'}) {
        $unavailable_states->{'warning'}  = 0;
        $unavailable_states->{'critical'} = 0;
        $unavailable_states->{'unknown'}  = 0;
        for my $chr (split//mx, lc $opts->{'s'}) {
            if($chr eq 'w') { $unavailable_states->{'warning'}  = 1; }
            if($chr eq 'c') { $unavailable_states->{'critical'} = 1; }
            if($chr eq 'u') { $unavailable_states->{'unknown'}  = 1; }
        }
    }
    # set downtimes as unavailable too
    if(defined $opts->{'downtime'} && !$opts->{'downtime'}) {
        for my $key (keys %{$unavailable_states}) {
            $unavailable_states->{$key."_downtime"} = 1;
        }
    }
    if(!$filter) {
        eval {
            Thruk::Utils::Avail::calculate_availability($c)
        };
        if($@) {
            _error("calculating availability failed for filter:");
            _error(Dumper($c->req->parameters));
            _error($@);
            return(($ENV{'THRUK_JOB_ID'} ? '('.$ENV{'THRUK_JOB_ID'}.') ' : '').$@);
        }
    }
    if($host) {
        my $totals = Thruk::Utils::Avail::get_availability_percents($c->stash->{avail_data},
                                                                    $unavailable_states,
                                                                    $host,
                                                                    $service,
                                                                   );
        return("found no data for service: ".$host." - ".$service) if($service && $totals->{'total'}->{'percent'} == -1);
        return("found no data for host: ".$host) if (!defined $totals->{'total'}->{'percent'} || $totals->{'total'}->{'percent'} == -1);
        return($totals->{'total'}->{'percent'});
    } else {
        my($num, $total) = (0,0);
        # if nothing is enabled, use all
        if(!$opts->{'incl_hst'} && !$opts->{'incl_svc'}) {
            $opts->{'incl_hst'} = 1;
            $opts->{'incl_svc'} = 1;
        }
        if($opts->{'incl_hst'}) {
            my $s_filter = delete $c->req->parameters->{s_filter};
            if($filter) {
                delete $c->stash->{avail_data}->{'hosts'};
                eval {
                    Thruk::Utils::Avail::calculate_availability($c)
                };
                if($@) {
                    _error("calculating availability failed for host filter:");
                    _error(Dumper($c->req->parameters));
                    _error($@);
                    return(($ENV{'THRUK_JOB_ID'} ? '('.$ENV{'THRUK_JOB_ID'}.') ' : '').$@);
                }
            }
            if($c->stash->{avail_data}->{'hosts'}) {
                for my $host (keys %{$c->stash->{avail_data}->{'hosts'}}) {
                    my $totals = Thruk::Utils::Avail::get_availability_percents($c->stash->{avail_data},
                                                                                $unavailable_states,
                                                                                $host,
                                                                               );
                    if($totals->{'total'}->{'percent'} != -1) {
                        $total += $totals->{'total'}->{'percent'};
                        $num++;
                    }
                }
            }
            $c->req->parameters->{s_filter} = $s_filter;
        }
        if($opts->{'incl_svc'}) {
            delete $c->req->parameters->{h_filter};
            if($filter) {
                delete $c->stash->{avail_data}->{'services'};
                eval {
                    Thruk::Utils::Avail::calculate_availability($c)
                };
                if($@) {
                    _error("calculating availability failed for service filter:");
                    _error(Dumper($c->req->parameters));
                    _error($@);
                    return(($ENV{'THRUK_JOB_ID'} ? '('.$ENV{'THRUK_JOB_ID'}.') ' : '').$@);
                }
            }
            if($c->stash->{avail_data}->{'services'}) {
                for my $host (keys %{$c->stash->{avail_data}->{'services'}}) {
                    for my $service (keys %{$c->stash->{avail_data}->{'services'}->{$host}}) {
                        my $totals = Thruk::Utils::Avail::get_availability_percents($c->stash->{avail_data},
                                                                                    $unavailable_states,
                                                                                    $host,
                                                                                    $service,
                                                                                   );
                        if($totals->{'total'}->{'percent'} != -1) {
                            $total += $totals->{'total'}->{'percent'};
                            $num++;
                        }
                    }
                }
            }
        }
        if($num > 0) {
            return($total/$num);
        }
    }
    return("found no data");
}

##########################################################
sub _task_stats_core_metrics {
    my($c) = @_;

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
        ],
    };

    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_stats_check_metrics {
    my($c) = @_;

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
        ],
    };

    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_server_stats {
    my($c) = @_;

    my $show_load   = $c->req->parameters->{'load'}   || 'true';
    my $show_cpu    = $c->req->parameters->{'cpu'}    || 'true';
    my $show_memory = $c->req->parameters->{'memory'} || 'true';

    my $json = {
        columns => [
            { 'header' => 'Cat',    dataIndex => 'cat',   hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Type',   dataIndex => 'type',  width => 60, align => 'right' },
            { 'header' => 'Value',  dataIndex => 'value', width => 65, align => 'right', renderer => 'TP.render_systat_value' },
            { 'header' => 'Graph',  dataIndex => 'graph', flex  => 1,                    renderer => 'TP.render_systat_graph' },
            { 'header' => 'Warn',   dataIndex => 'warn',  hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Crit',   dataIndex => 'crit',  hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Max',    dataIndex => 'max',   hidden => Cpanel::JSON::XS::true },
        ],
        data  => [],
        group => 'cat',
    };
    return $c->render(json => $json) unless -e '/proc'; # all beyond is linux only

    my($cpu, $cpucount);
    if($show_load eq 'true' or $show_cpu eq 'true') {
        my $lastcpu = $c->cache->get('panorama_sys_cpu');
        my $pcs  = Thruk::Utils::PanoramaCpuStats->new({sleep => 3, init => $lastcpu->{'init'}});
           $cpu  = $pcs->get();
           $cpucount = (scalar keys %{$cpu}) - 1;
        # don't save more often than 5 seconds to keep a better reference
        if(!defined $lastcpu->{'time'} || $lastcpu->{'time'} +5 < time()) {
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
        $mem->{'Buffers'} = 0; # can be empty on some machines
        push @{$json->{'data'}},
            { cat => 'Memory',  type => 'total',    value => $mem->{'MemTotal'},  graph => '', warn => $mem->{'MemTotal'}, crit => $mem->{'MemTotal'}, max => $mem->{'MemTotal'} },
            { cat => 'Memory',  type => 'free',     value => $mem->{'MemFree'},   'warn' => $mem->{'MemTotal'}*0.7, crit => $mem->{'MemTotal'}*0.8, max => $mem->{'MemTotal'}, graph => '' },
            { cat => 'Memory',  type => 'used',     value => $mem->{'MemTotal'}-$mem->{'MemFree'}-$mem->{'Buffers'}-$mem->{'Cached'}, 'warn' => $mem->{'MemTotal'}*0.7, crit => $mem->{'MemTotal'}*0.8, max => $mem->{'MemTotal'}, graph => '' },
            { cat => 'Memory',  type => 'buffers',  value => $mem->{'Buffers'},   'warn' => $mem->{'MemTotal'}*0.8, crit => $mem->{'MemTotal'}*0.9, max => $mem->{'MemTotal'}, graph => '' },
            { cat => 'Memory',  type => 'cached',   value => $mem->{'Cached'},    'warn' => $mem->{'MemTotal'}*0.8, crit => $mem->{'MemTotal'}*0.9, max => $mem->{'MemTotal'}, graph => '' };
    }

    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_stats_gearman {
    my($c) = @_;
    my $json = _get_gearman_stats($c);
    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_stats_gearman_grid {
    my($c) = @_;

    my $data = _get_gearman_stats($c);

    my $json = {
        columns => [
            { 'header' => 'Queue',   dataIndex => 'name', flex  => 1, renderer => 'TP.render_gearman_queue' },
            { 'header' => 'Worker',  dataIndex => 'worker',  width => 60, align => 'right', xtype => 'numbercolumn', format => '0,000' },
            { 'header' => 'Running', dataIndex => 'running', width => 60, align => 'right', xtype => 'numbercolumn', format => '0,000' },
            { 'header' => 'Waiting', dataIndex => 'waiting', width => 60, align => 'right', xtype => 'numbercolumn', format => '0,000' },
        ],
        data    => [],
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

    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_show_logs {
    my($c) = @_;

    my $filter;
    my $end   = time();
    my $start = $end - Thruk::Utils::expand_duration($c->req->parameters->{'time'} || '15m');
    push @{$filter}, { time => { '>=' => $start }};
    push @{$filter}, { time => { '<=' => $end }};

    # additional filters set?
    my $pattern         = $c->req->parameters->{'pattern'};
    my $exclude_pattern = $c->req->parameters->{'exclude'};
    if(defined $pattern and $pattern !~ m/^\s*$/mx) {
        push @{$filter}, { message => { '~~' => Thruk::Utils::clean_regex($pattern) }};
    }
    if(defined $exclude_pattern and $exclude_pattern !~ m/^\s*$/mx) {
        push @{$filter}, { message => { '!~~' => Thruk::Utils::clean_regex($exclude_pattern) }};
    }
    my $total_filter = Thruk::Utils::combine_filter('-and', $filter);
    $c->{'db'}->renew_logcache($c);
    my $data = $c->{'db'}->get_logs(filter => [$total_filter, Thruk::Utils::Auth::get_auth_filter($c, 'log')], sort => {'DESC' => 'time'});

    my $json = {
        columns => [
            { 'header' => 'Icon',    dataIndex => 'icon', width => 30, tdCls => 'icon_column', renderer => 'TP.render_icon_log' },
            { 'header' => 'Time',    dataIndex => 'time', width => 60, renderer => 'TP.render_date' },
            { 'header' => 'Message', dataIndex => 'message', flex => 1 },
        ],
        data    => [],
    };
    for my $row (@{$data}) {
        push @{$json->{'data'}}, {
            icon    => Thruk::Utils::Filter::logline_icon($row),
            time    => $row->{'time'},
            message => substr($row->{'message'},13),
        };
    }

    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_site_status {
    my($c) = @_;

    if(!$c->stash->{'pi_detail'} || scalar keys %{$c->stash->{'pi_detail'}} == 0) {
        my $cached_data = $c->cache->get->{'global'} || {};
        Thruk::Action::AddDefaults::set_processinfo($c, undef, undef, $cached_data, 1);
    }

    my $backend_filter;
    if($c->req->parameters->{'backends'}) {
        $backend_filter = {};
        for my $b (ref $c->req->parameters->{'backends'} eq 'ARRAY' ? @{$c->req->parameters->{'backends'}} : $c->req->parameters->{'backends'}) {
            $backend_filter->{$b} = 1;
        }
    }

    my $json = {
        columns => [
            { 'header' => 'Id',               dataIndex => 'id',                      width => 45, hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Icon',             dataIndex => 'icon',                    width => 30, tdCls => 'icon_column', renderer => 'TP.render_icon_site' },
            { 'header' => 'Category',         dataIndex => 'category',                width => 60, hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Section',          dataIndex => 'section',                 width => 60, hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Site',             dataIndex => 'site',                    width => 60, flex => 1 },
            { 'header' => 'Version',          dataIndex => 'version',                 width => 50, renderer => 'TP.add_title' },
            { 'header' => 'Runtime',          dataIndex => 'runtime',                 width => 85 },
            { 'header' => 'Notifications',    dataIndex => 'enable_notifications',    width => 65, hidden => Cpanel::JSON::XS::true, align => 'center', renderer => 'TP.render_enabled_switch' },
            { 'header' => 'Svc Checks',       dataIndex => 'execute_service_checks',  width => 65, hidden => Cpanel::JSON::XS::true, align => 'center', renderer => 'TP.render_enabled_switch' },
            { 'header' => 'Hst Checks',       dataIndex => 'execute_host_checks',     width => 65, hidden => Cpanel::JSON::XS::true, align => 'center', renderer => 'TP.render_enabled_switch' },
            { 'header' => 'Eventhandlers',    dataIndex => 'enable_event_handlers',   width => 65, hidden => Cpanel::JSON::XS::true, align => 'center', renderer => 'TP.render_enabled_switch' },
            { 'header' => 'Performance Data', dataIndex => 'process_performance_data',width => 65, hidden => Cpanel::JSON::XS::true, align => 'center', renderer => 'TP.render_enabled_switch' },
        ],
        data    => [],
    };

    for my $key (@{$c->stash->{'backends'}}) {
        next if($backend_filter && !defined $backend_filter->{$key});
        my $b    = $c->stash->{'backend_detail'}->{$key};
        my $d    = {};
        $d       = $c->stash->{'pi_detail'}->{$key} if ref $c->stash->{'pi_detail'} eq 'HASH';
        my $icon = 'exclamation.png';
        if($b->{'running'} && $d->{'program_start'}) { $icon = 'accept.png'; }
        my $runtime = "";
        my $program_version = $b->{'last_error'};
        if($b->{'running'} && $d->{'program_start'}) {
            $runtime = Thruk::Utils::Filter::duration(time() - $d->{'program_start'});
            $program_version = $d->{'program_version'};
        }
        my $row = {
            id       => $key,
            icon     => $icon,
            site     => $b->{'name'},
            version  => $program_version,
            runtime  => $runtime,
            section  => $b->{'section'},
            category => $b->{'section'}, # keep for backwards compatibility
        };
        for my $attr (qw/enable_notifications execute_host_checks execute_service_checks
                      enable_event_handlers process_performance_data/) {
            $row->{$attr} = $d->{$attr};
        }
        push @{$json->{'data'}}, $row;
    }

    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_hosts {
    my($c) = @_;

    my( $hostfilter, $servicefilter, $groupfilter ) = _do_filter($c);
    return if $c->stash->{'has_error'};

    $c->req->parameters->{'entries'} = $c->req->parameters->{'pageSize'};
    $c->req->parameters->{'page'}    = $c->req->parameters->{'currentPage'};

    my $data = $c->{'db'}->get_hosts(filter        => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ],
                                     pager         => 1,
                                     extra_columns => [qw/long_plugin_output/],
                                     sort          => _append_sort($c->req->parameters->{'sort'}, { ASC => [ 'name' ] }),
                                    );

    my $json = {
        columns => [
            { 'header' => 'Hostname',               width => 120, dataIndex => 'name',                                 renderer => 'TP.render_clickable_host' },
            { 'header' => 'Icons',                  width => 75,  dataIndex => 'icons',             align => 'right',  renderer => 'TP.render_host_icons' },
            { 'header' => 'Status',                 width => 80,  dataIndex => 'state',             align => 'center', renderer => 'TP.render_host_status' },
            { 'header' => 'Last Check',             width => 80,  dataIndex => 'last_check',        align => 'center', renderer => 'TP.render_last_check' },
            { 'header' => 'Duration',               width => 100, dataIndex => 'last_state_change', align => 'center', renderer => 'TP.render_duration' },
            { 'header' => 'Attempt',                width => 60,  dataIndex => 'current_attempt',   align => 'center', renderer => 'TP.render_attempt' },
            { 'header' => 'Site',                   width => 60,  dataIndex => 'peer_name',         align => 'center', renderer => 'TP.render_peer_name' },
            { 'header' => 'Status Information',     flex  => 1,   dataIndex => 'plugin_output',                        renderer => 'TP.render_plugin_output' },
            { 'header' => 'Performance',            width => 80,  dataIndex => 'perf_data',                            renderer => 'TP.render_perfbar' },

            { 'header' => 'Parents',                  dataIndex => 'parents',                     hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_clickable_host_list' },
            { 'header' => 'Current Attempt',          dataIndex => 'current_attempt',             hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Max Check Attempts',       dataIndex => 'max_check_attempts',          hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Last State Change',        dataIndex => 'last_state_change',           hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Check Type',               dataIndex => 'check_type',                  hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_check_type' },
            { 'header' => 'Site ID',                  dataIndex => 'peer_key',                    hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Has Been Checked',         dataIndex => 'has_been_checked',            hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Active Checks Enabled',    dataIndex => 'active_checks_enabled',       hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Accept Passive Checks',    dataIndex => 'accept_passive_checks',       hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Next Check',               dataIndex => 'next_check',                  hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Notification Number',      dataIndex => 'current_notification_number', hidden => Cpanel::JSON::XS::true },
            { 'header' => 'First Notification Delay', dataIndex => 'first_notification_delay',    hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Notifications Enabled',    dataIndex => 'notifications_enabled',       hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_enabled_switch' },
            { 'header' => 'Is Flapping',              dataIndex => 'is_flapping',                 hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Acknowledged',             dataIndex => 'acknowledged',                hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Comments',                 dataIndex => 'comments',                    hidden => Cpanel::JSON::XS::true, hideable => Cpanel::JSON::XS::false },
            { 'header' => 'Scheduled Downtime Depth', dataIndex => 'scheduled_downtime_depth',    hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Action Url',               dataIndex => 'action_url_expanded',         hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_action_url' },
            { 'header' => 'Notes url',                dataIndex => 'notes_url_expanded',          hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_notes_url' },
            { 'header' => 'Notes',                    dataIndex => 'notes',                       hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Icon Image',               dataIndex => 'icon_image_expanded',         hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_icon_url' },
            { 'header' => 'Icon Image Alt',           dataIndex => 'icon_image_alt',              hidden => Cpanel::JSON::XS::true, hideable => Cpanel::JSON::XS::false },
            { 'header' => 'Custom Variable Names',    dataIndex => 'custom_variable_names',       hidden => Cpanel::JSON::XS::true, hideable => Cpanel::JSON::XS::false },
            { 'header' => 'Custom Variable Values',   dataIndex => 'custom_variable_values',      hidden => Cpanel::JSON::XS::true, hideable => Cpanel::JSON::XS::false },
            { 'header' => 'Long Plugin Output',       dataIndex => 'long_plugin_output',          hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_long_pluginoutput' },

            { 'header' => 'Last Time Up',          dataIndex => 'last_time_up',          hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Last Time Unreachable', dataIndex => 'last_time_unreachable', hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Last Time Down',        dataIndex => 'last_time_down',        hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_date' },
        ],
        data        => $c->stash->{'data'},
        totalCount  => $c->stash->{'pager'}->{'total_entries'},
        currentPage => $c->stash->{'pager'}->{'current_page'},
        paging      => Cpanel::JSON::XS::true,
    };

    if($c->config->{'show_custom_vars'}) {
        for my $var (@{$c->config->{'show_custom_vars'}}) {
            if($var !~ m/\*/mx) { # does not work with wildcards
                $var =~ s/^_//gmx;
                push @{$json->{'columns'}},
                { 'header' => $var, dataIndex => $var, hidden => Cpanel::JSON::XS::true };
            }
        }
        for my $h ( @{$c->stash->{'data'}}) {
            my $cust = Thruk::Utils::get_custom_vars($c, $h);
            for my $var (@{$c->config->{'show_custom_vars'}}) {
                if($var !~ m/\*/mx) { # does not work with wildcards
                    $var =~ s/^_//gmx;
                    $h->{$var} = $cust->{$var} // '';
                }
            }
            $h->{'THRUK_ACTION_MENU'} = $cust->{'THRUK_ACTION_MENU'} // '';
        }
    }
    if(!$c->check_user_roles("authorized_for_configuration_information")) {
        # remove custom macro colums which could contain confidential informations
        for my $h ( @{$c->stash->{'data'}}) {
            delete $h->{'custom_variable_names'};
            delete $h->{'custom_variable_values'};
        }
    }

    if($c->stash->{'escape_html_tags'} or $c->stash->{'show_long_plugin_output'} eq 'inline') {
        for my $h ( @{$c->stash->{'data'}}) {
            _escape($h)      if $c->stash->{'escape_html_tags'};
            _long_plugin($h) if $c->stash->{'show_long_plugin_output'} eq 'inline';
        }
    }

    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_services {
    my($c) = @_;

    my( $hostfilter, $servicefilter, $groupfilter ) = _do_filter($c);
    return if $c->stash->{'has_error'};

    $c->req->parameters->{'entries'} = $c->req->parameters->{'pageSize'};
    $c->req->parameters->{'page'}    = $c->req->parameters->{'currentPage'};

    $c->{'db'}->get_services(filter        => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter],
                             pager         => 1,
                             extra_columns => [qw/long_plugin_output/],
                             sort          => _append_sort($c->req->parameters->{'sort'}, { ASC => [ 'host_name',   'description' ] }),
                            );

    my $json = {
        columns => [
            { 'header' => 'Hostname',               width => 120, dataIndex => 'host_display_name',                    renderer => 'TP.render_service_host' },
            { 'header' => 'Host',                                 dataIndex => 'host_name',         hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Host Icons',             width => 75,  dataIndex => 'icons',             align => 'right',  renderer => 'TP.render_host_service_icons' },
            { 'header' => 'Service',                width => 120, dataIndex => 'display_name',                         renderer => 'TP.render_clickable_service' },
            { 'header' => 'Description',                          dataIndex => 'description',       hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Icons',                  width => 75,  dataIndex => 'icons',             align => 'right',  renderer => 'TP.render_service_icons' },
            { 'header' => 'Status',                 width => 70,  dataIndex => 'state',             align => 'center', renderer => 'TP.render_service_status' },
            { 'header' => 'Last Check',             width => 80,  dataIndex => 'last_check',        align => 'center', renderer => 'TP.render_last_check' },
            { 'header' => 'Duration',               width => 100, dataIndex => 'last_state_change', align => 'center', renderer => 'TP.render_duration' },
            { 'header' => 'Attempt',                width => 60,  dataIndex => 'current_attempt',   align => 'center', renderer => 'TP.render_attempt' },
            { 'header' => 'Site',                   width => 60,  dataIndex => 'peer_name',         align => 'center', renderer => 'TP.render_peer_name' },
            { 'header' => 'Status Information',     flex  => 1,   dataIndex => 'plugin_output',                        renderer => 'TP.render_plugin_output' },
            { 'header' => 'Performance',            width => 80,  dataIndex => 'perf_data',                            renderer => 'TP.render_perfbar' },

            { 'header' => 'Current Attempt',          dataIndex => 'current_attempt',             hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Max Check Attempts',       dataIndex => 'max_check_attempts',          hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Last State Change',        dataIndex => 'last_state_change',           hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Check Type',               dataIndex => 'check_type',                  hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_check_type' },
            { 'header' => 'Site ID',                  dataIndex => 'peer_key',                    hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Has Been Checked',         dataIndex => 'has_been_checked',            hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Active Checks Enabled',    dataIndex => 'active_checks_enabled',       hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Accept Passive Checks',    dataIndex => 'accept_passive_checks',       hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Next Check',               dataIndex => 'next_check',                  hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Notification Number',      dataIndex => 'current_notification_number', hidden => Cpanel::JSON::XS::true },
            { 'header' => 'First Notification Delay', dataIndex => 'first_notification_delay',    hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Notifications Enabled',    dataIndex => 'notifications_enabled',       hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_enabled_switch' },
            { 'header' => 'Is Flapping',              dataIndex => 'is_flapping',                 hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Acknowledged',             dataIndex => 'acknowledged',                hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Comments',                 dataIndex => 'comments',                    hidden => Cpanel::JSON::XS::true, hideable => Cpanel::JSON::XS::false },
            { 'header' => 'Scheduled Downtime Depth', dataIndex => 'scheduled_downtime_depth',    hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Action Url',               dataIndex => 'action_url_expanded',         hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_action_url' },
            { 'header' => 'Notes url',                dataIndex => 'notes_url_expanded',          hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_notes_url' },
            { 'header' => 'Icon Image',               dataIndex => 'icon_image_expanded',         hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_icon_url' },
            { 'header' => 'Icon Image Alt',           dataIndex => 'icon_image_alt',              hidden => Cpanel::JSON::XS::true, hideable => Cpanel::JSON::XS::false },
            { 'header' => 'Custom Variable Names',    dataIndex => 'custom_variable_names',       hidden => Cpanel::JSON::XS::true, hideable => Cpanel::JSON::XS::false },
            { 'header' => 'Custom Variable Values',   dataIndex => 'custom_variable_values',      hidden => Cpanel::JSON::XS::true, hideable => Cpanel::JSON::XS::false },
            { 'header' => 'Long Plugin Output',       dataIndex => 'long_plugin_output',          hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_long_pluginoutput' },

            { 'header' => 'Host Parents',                   dataIndex => 'host_parents',                  hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_clickable_host_list' },
            { 'header' => 'Host Status',                    dataIndex => 'host_state',                    hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_host_status' },
            { 'header' => 'Host Notifications Enabled',     dataIndex => 'host_notifications_enabled',    hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_enabled_switch' },
            { 'header' => 'Host Check Type',                dataIndex => 'host_check_type',               hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_check_type' },
            { 'header' => 'Host Active Checks Enabled',     dataIndex => 'host_active_checks_enabled',    hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Host Accept Passive Checks',     dataIndex => 'host_accept_passive_checks',    hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Host Is Flapping',               dataIndex => 'host_is_flapping',              hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Host Acknowledged',              dataIndex => 'host_acknowledged',             hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_yes_no' },
            { 'header' => 'Host Comments',                  dataIndex => 'host_comments',                 hidden => Cpanel::JSON::XS::true, hideable => Cpanel::JSON::XS::false },
            { 'header' => 'Host Scheduled Downtime Depth',  dataIndex => 'host_scheduled_downtime_depth', hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Host Action Url',                dataIndex => 'host_action_url_expanded',      hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_action_url' },
            { 'header' => 'Host Notes Url',                 dataIndex => 'host_notes_url_expanded',       hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_notes_url' },
            { 'header' => 'Host Notes',                     dataIndex => 'host_notes',                    hidden => Cpanel::JSON::XS::true },
            { 'header' => 'Host Icon Image',                dataIndex => 'host_icon_image_expanded',      hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_icon_url' },
            { 'header' => 'Host Icon Image Alt',            dataIndex => 'host_icon_image_alt',           hidden => Cpanel::JSON::XS::true, hideable => Cpanel::JSON::XS::false },
            { 'header' => 'Host Custom Variable Names',     dataIndex => 'host_custom_variable_names',    hidden => Cpanel::JSON::XS::true, hideable => Cpanel::JSON::XS::false },
            { 'header' => 'Host Custom Variable Values',    dataIndex => 'host_custom_variable_values',   hidden => Cpanel::JSON::XS::true, hideable => Cpanel::JSON::XS::false },

            { 'header' => 'Last Time Ok',       dataIndex => 'last_time_ok',       hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Last Time Warning',  dataIndex => 'last_time_warning',  hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Last Time Unknown',  dataIndex => 'last_time_unknown',  hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_date' },
            { 'header' => 'Last Time Critical', dataIndex => 'last_time_critical', hidden => Cpanel::JSON::XS::true, renderer => 'TP.render_date' },
        ],
        data        => $c->stash->{'data'},
        totalCount  => $c->stash->{'pager'}->{'total_entries'},
        currentPage => $c->stash->{'pager'}->{'current_page'},
        paging      => Cpanel::JSON::XS::true,
    };

    if($c->config->{'show_custom_vars'}) {
        for my $var (@{$c->config->{'show_custom_vars'}}) {
            if($var !~ m/\*/mx) { # does not work with wildcards
                $var =~ s/^_//gmx;
                push @{$json->{'columns'}},
                { 'header' => $var, dataIndex => $var, hidden => Cpanel::JSON::XS::true };
            }
        }
    }
    for my $s ( @{$c->stash->{'data'}}) {
        my $cust = Thruk::Utils::get_custom_vars($c, $s, undef, 1);
        for my $var (@{$c->config->{'show_custom_vars'}}) {
            if($var !~ m/\*/mx) { # does not work with wildcards
                $var =~ s/^_//gmx;
                $s->{$var} = $cust->{$var} // $cust->{'HOST'.$var} // '';
            }
        }
        $s->{'THRUK_ACTION_MENU'}     = $cust->{'THRUK_ACTION_MENU'} // '';
        $s->{'HOSTTHRUK_ACTION_MENU'} = $cust->{'HOSTTHRUK_ACTION_MENU'} // '';
    }
    if(!$c->check_user_roles("authorized_for_configuration_information")) {
        # remove custom macro colums which could contain confidential informations
        for my $s ( @{$c->stash->{'data'}}) {
            delete $s->{'host_custom_variable_names'};
            delete $s->{'host_custom_variable_values'};
            delete $s->{'custom_variable_names'};
            delete $s->{'custom_variable_values'};
        }
    }

    if($c->stash->{'escape_html_tags'} or $c->stash->{'show_long_plugin_output'} eq 'inline') {
        for my $s ( @{$c->stash->{'data'}}) {
            _escape($s)      if $c->stash->{'escape_html_tags'};
            _long_plugin($s) if $c->stash->{'show_long_plugin_output'} eq 'inline';
        }
    }

    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_squares_data {
    my($c) = @_;

    my $source = $c->req->parameters->{'source'} || 'hosts';
    my( $hostfilter, $servicefilter, $groupfilter ) = _do_filter($c);
    return if $c->stash->{'has_error'};

    my $now        = time();
    my $data       = [];
    if($source eq 'services' || $source eq 'both') {
        my $services = $c->{'db'}->get_services(
                                    filter  => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter],
                                    columns => [qw/host_name description state acknowledged scheduled_downtime_depth has_been_checked last_state_change/],
                                    sort    => { ASC => [ 'host_name',   'description' ] },
                                );
        for my $svc (@{$services}) {
            push @{$data}, { uniq         => $svc->{'host_name'}.';'.$svc->{'description'},
                             name         => $svc->{'host_name'}.' - '.$svc->{'description'},
                             host_name    => $svc->{'host_name'},
                             description  => $svc->{'description'},
                             state        => $svc->{'has_been_checked'} == 0 ? 4 : $svc->{'state'},
                             downtime     => $svc->{'scheduled_downtime_depth'},
                             acknowledged => $svc->{'acknowledged'},
                             link         => 'extinfo.cgi?type=2&host='.$svc->{'host_name'}."&service=".$svc->{'description'},
                             duration     => $now - $svc->{'last_state_change'},
                             isHost       => 0,
                           };
        }
    }

    if($source eq 'hosts' || $source eq 'both') {
        my $hosts = $c->{'db'}->get_hosts(
                                    filter  => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter],
                                    columns => [qw/name state acknowledged scheduled_downtime_depth has_been_checked last_state_change/],
                                    sort    => { ASC => [ 'name' ] },
                                );
        for my $hst (@{$hosts}) {
            push @{$data}, { uniq         => $hst->{'name'},
                             name         => $hst->{'name'},
                             host_name    => $hst->{'name'},
                             description  => '',
                             state        => $hst->{'state'},
                             downtime     => $hst->{'scheduled_downtime_depth'},
                             acknowledged => $hst->{'acknowledged'},
                             link         => 'extinfo.cgi?type=1&host='.$hst->{'name'},
                             duration     => $now - $hst->{'last_state_change'},
                             isHost       => 1,
                            };
        }
    }

    # need to sort by host/service again
    if($source eq 'both') {
        $data = Thruk::Backend::Manager::sort_result({}, $data, 'uniq');
    }

    # apply group by
    if($c->req->parameters->{'groupby'}) {
        my $groupby = Thruk::Utils::list($c->req->parameters->{'groupby'});
        if(scalar @{$groupby} == 2 && $groupby->[0] eq 'host_name' && $groupby->[1] eq 'description') {
            # nothing todo
        }
        elsif(scalar @{$groupby} == 1 && $groupby->[0] eq 'host_name' && $source eq 'hosts') {
            # nothing todo
        } else {
            my $grouped_data = {};
            for my $d (@{$data}) {
                my $uniq = [];
                for my $key (@{$groupby}) {
                    push @{$uniq}, $d->{$key};
                }
                $uniq = join(" - ", @{$uniq});
                my $details = {
                    'host_name'    => $d->{'host_name'},
                    'description'  => $d->{'description'},
                    'state'        => $d->{'state'},
                    'duration'     => $d->{'duration'},
                    'acknowledged' => $d->{'acknowledged'},
                    'downtime'     => $d->{'downtime'},
                    'isHost'       => $d->{'isHost'},
                };
                if(!$grouped_data->{$uniq}) {
                    $grouped_data->{$uniq} = $d;
                    $grouped_data->{$uniq}->{'uniq'}    = $uniq;
                    $grouped_data->{$uniq}->{'name'}    = $uniq;
                    $grouped_data->{$uniq}->{'details'} = [$details];
                    delete $grouped_data->{$uniq}->{'link'};
                } else {
                    my $comb = $grouped_data->{$uniq};
                    if($d->{'state'} > 0 && $d->{'state'} != 4) {
                        my $worse = 0;
                        if(!$d->{'acknowledged'} && $comb->{'acknowledged'}) {
                            $worse = 1;
                        }
                        elsif(!$d->{'downtime'} && $comb->{'downtime'}) {
                            $worse = 1;
                        }
                        elsif($d->{'isHost'} && !$comb->{'isHost'}) {
                            $worse = 1;
                        }
                        elsif($comb->{'isHost'} && $comb->{'state'} != 0) {
                            # host state beats every service
                        }
                        elsif($d->{'state'} > $comb->{'state'}) {
                            $worse = 1;
                        }
                        if($worse) {
                            $comb->{'state'}        = $d->{'state'};
                            $comb->{'isHost'}       = $d->{'isHost'};
                            $comb->{'downtime'}     = $d->{'downtime'};
                            $comb->{'acknowledged'} = $d->{'acknowledged'};
                            $comb->{'duration'}     = $d->{'duration'};
                        }
                    }
                    if($comb->{'duration'} > $d->{'duration'} && $comb->{'state'} == $d->{'state'} && $comb->{'isHost'} == $d->{'isHost'}) {
                        $comb->{'duration'} = $d->{'duration'};
                    }
                    push @{$grouped_data->{$uniq}->{'details'}}, $details;
                }
            }
            $data = [];
            for my $key (sort keys %{$grouped_data}) {
                push @{$data}, $grouped_data->{$key};
            }
        }
    }

    my $json = {
        data => $data,
    };

    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_hosttotals {
    my($c) = @_;

    my( $hostfilter, $servicefilter, $groupfilter ) = _do_filter($c);
    return if $c->stash->{'has_error'};
    Thruk::Utils::Status::fill_totals_box( $c, $hostfilter, undef, 1);

    my $s = $c->stash->{'host_stats'};
    my $json = {
        columns => [
            { 'header' => '#',     width => 40, dataIndex => 'count', align => 'right', renderer => 'TP.render_statuscount' },
            { 'header' => 'State', flex  => 1,  dataIndex => 'state' },
        ],
        data      => [],
    };

    for my $state (qw/up down unreachable pending/) {
        push @{$json->{'data'}}, {
            state => ucfirst $state,
            count => $s->{$state},
        };
    }

    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_servicetotals {
    my($c) = @_;

    my( $hostfilter, $servicefilter, $groupfilter ) = _do_filter($c);
    return if $c->stash->{'has_error'};
    Thruk::Utils::Status::fill_totals_box( $c, undef, $servicefilter, 1 );

    my $s = $c->stash->{'service_stats'};
    my $json = {
        columns => [
            { 'header' => '#',     width => 40, dataIndex => 'count', align => 'right', renderer => 'TP.render_statuscount' },
            { 'header' => 'State', flex  => 1,  dataIndex => 'state' },
        ],
        data      => [],
    };

    for my $state (qw/ok warning unknown critical pending/) {
        push @{$json->{'data'}}, {
            state => ucfirst $state,
            count => $s->{$state},
        };
    }

    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_hosts_pie {
    my($c) = @_;

    my( $hostfilter, $servicefilter, $groupfilter ) = _do_filter($c);
    return if $c->stash->{'has_error'};

    my $data = $c->{'db'}->get_host_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter]);

    my $json = {
        columns => [
            { 'header' => 'Name',      dataIndex => 'name' },
            { 'header' => 'Data',      dataIndex => 'value' },
        ],
        colors    => [ ],
        data      => [],
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
            value   => $data->{$state},
        };
        push @{$json->{'colors'}}, $colors->{$state};
    }

    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_services_pie {
    my($c) = @_;

    my( $hostfilter, $servicefilter, $groupfilter ) = _do_filter($c);
    return if $c->stash->{'has_error'};

    my $data = $c->{'db'}->get_service_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter]);

    my $json = {
        columns => [
            { 'header' => 'Name',      dataIndex => 'name' },
            { 'header' => 'Data',      dataIndex => 'value' },
        ],
        colors    => [],
        data      => [],
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
            value   => $data->{$state},
        };
        push @{$json->{'colors'}}, $colors->{$state};
    }

    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_servicesminemap {
    my($c) = @_;

    my( $hostfilter, $servicefilter, $groupfilter ) = _do_filter($c);
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
            { 'header'       => '<div class="minemap_first_col" style="top: '.($height/2-10).'px;">Hostname</div>',
              'headerIE'     => '<div class="minemap_first_col" style="top: '.($height-25).'px;">Hostname</div>',
              'headerChrome' => '<div class="minemap_first_col" style="bottom: 0px;">Hostname</div>',
              'width'        => 120,
              'height'       => $height,
              'dataIndex'    => 'host_display_name',
            },
        ],
        data        => [],
    };

    my $x=0;
    for my $svc (sort keys %{$uniq_services}) {
        my $index = 'col'.$x;
        $service2index->{$svc} = $index;
        push @{$json->{'columns'}}, {
                    'header'       => '<div class="vertical" style="top: '.($height/2-10).'px;">'.$svc.'</div>',
                    'headerIE'     => '<div class="vertical" style="top: 8px; width: '.($height-25).'px; right: '.($height/2-16).'px;">'.$svc.'</div>',
                    'headerChrome' => '<div class="vertical" style="top: '.($height-20).'px;">'.$svc.'</div>',
                    'width'        => 20,
                    'height'       => $height,
                    'dataIndex'    => $index,
                    'align'        => 'center',
                    'tdCls'        => 'mine_map_cell',
        };
        $x++;
    }
    for my $name (sort keys %{$hosts}) {
        my $hst  = $hosts->{$name};
        my $data;
        if ($hst->{'host_action_url_expanded'}) {
            $data = { 'host_display_name' => $hst->{'host_display_name'} . "&nbsp;<a target='_blank' href='".$hst->{'host_action_url_expanded'}."' style='position: relative;'><img src='".$c->stash->{'url_prefix'}.'themes/'.$c->stash->{'theme'}.'/images/'.$c->stash->{'host_action_icon'}."' border=0 width=20 height=20 alt='Perform Extra Host Actions' title='Perform Extra Host Actions' style='vertical-align: text-bottom; position: absolute; top: -2px;'></a>" };
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
            $data->{$service2index->{$svc}} = '<div class="clickable '.$cls.'" '._generate_service_popup($c, $service).'>'.$text.'</div>';
        }
        push @{$json->{'data'}}, $data;
    }

    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_show_comments {
    my($c) = @_;

    my($hostfilter, $servicefilter, undef, undef, $has_service_filter) = _do_filter($c);
    return if $c->stash->{'has_error'};

    my $source = $c->req->parameters->{'source'} || 'both';

    my $generalfilter;
    if($source eq 'hosts') {
        push @{$generalfilter},  { service_description => { '=' => '' }};
    }
    elsif($source eq 'services') {
        push @{$generalfilter},  { service_description => { '!=' => '' }};
    }

    if($hostfilter && ($source eq 'hosts' || $source eq 'both')) {
        my $hosts = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ], columns => [qw/name/]);
        my $host_comments_filter = [{ host_name => ''}]; # add useless filter, so the -or will not match on empty hostlists
        for my $hst (@{$hosts}) {
            push @{$host_comments_filter}, { host_name => $hst->{'name'}};
        }
        push @{$generalfilter},  Thruk::Utils::combine_filter( '-or', $host_comments_filter );
    }

    if($servicefilter && ($source eq 'services' || $source eq 'both')) {
        my $services = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter ], columns => [qw/host_name description/]);
        my $svc_comments_filter = [{ host_name => ''}]; # add useless filter, so the -or will not match on empty servicelists
        for my $svc (@{$services}) {
            push @{$svc_comments_filter}, [{ host_name => $svc->{'host_name'}}, { service_description => $svc->{'service_description'}}];
        }
        push @{$generalfilter}, Thruk::Utils::combine_filter( '-or', $svc_comments_filter );
    }

    my $types = Thruk::Utils::list($c->req->parameters->{'type'});
    my $commentfilter = [];
    my $typesfilter   = [];
    my $add_downtimes = 0;
    my $add_comments  = 0;
    for my $t (@{$types}) {
        if(   $t eq 'comment')  { $add_comments  = 1; push @{$typesfilter}, { entry_type => 1 }; }
        elsif($t eq 'flap')     { $add_comments  = 1; push @{$typesfilter}, { entry_type => 3 }; }
        elsif($t eq 'ack')      { $add_comments  = 1; push @{$typesfilter}, { entry_type => 4 }; }
        elsif($t eq 'downtime') { $add_downtimes = 1; }
    }
    push @{$commentfilter}, Thruk::Utils::combine_filter( '-or', $typesfilter );

    my $data = [];
    if($add_comments) {
        $data = $c->{'db'}->get_comments(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'comments'), $generalfilter, $commentfilter ]);
        # move some fields to match downtimes
        for my $d (@{$data}) {
            $d->{'start_time'} = $d->{'entry_time'};
            $d->{'end_time'}   = -1;
        }
    }

    if($add_downtimes) {
        my $downtimes = $c->{'db'}->get_downtimes(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'downtimes'), $generalfilter ]);
        for my $d (@{$downtimes}) {
            $d->{'entry_type'} = 2;
        }
        push @{$data}, @{$downtimes};
    }

    my $include = $c->req->parameters->{'pattern'};
    if($include) {
        my $filtered = [];
        for my $d (@{$data}) {
            ## no critic
            if($d->{'author'} =~ m/$include/ || $d->{'comment'} =~ m/$include/) {
                push @{$filtered}, $d;
            }
            ## use critic
        }
        $data = $filtered;
    }

    my $exclude = $c->req->parameters->{'exclude'};
    if($exclude) {
        my $filtered = [];
        for my $d (@{$data}) {
            ## no critic
            if($d->{'author'} !~ m/$exclude/ && $d->{'comment'} !~ m/$exclude/) {
                push @{$filtered}, $d;
            }
            ## use critic
        }
        $data = $filtered;
    }

    $c->req->parameters->{'entries'} = $c->req->parameters->{'pageSize'};
    $c->req->parameters->{'page'}    = $c->req->parameters->{'currentPage'};
    $data = [sort { $a->{'host_name'} cmp $b->{'host_name'} || $a->{'service_description'} cmp $b->{'service_description'} } @{$data}];
    Thruk::Backend::Manager::page_data($c, $data);
    my $json = {
        columns => [
            { 'header' => 'Hostname',               width => 120, dataIndex => 'host_name',           renderer => 'TP.render_service_host' },
            { 'header' => 'Service',                width => 120, dataIndex => 'service_description', renderer => 'TP.render_clickable_service' },
            { 'header' => 'Type',                   width => 120, dataIndex => 'entry_type',          renderer => 'TP.render_entry_type'    },
            { 'header' => 'Start Time',             width => 120, dataIndex => 'start_time',          align => 'right', renderer => 'TP.render_date' },
            { 'header' => 'End Time',               width => 120, dataIndex => 'end_time',            align => 'right', renderer => 'TP.render_date' },
            { 'header' => 'Entry Time',             width => 120, dataIndex => 'entry_time',          hidden => Cpanel::JSON::XS::true, align => 'right', renderer => 'TP.render_date' },
            { 'header' => 'Author',                 width => 100, dataIndex => 'author',              },
            { 'header' => 'Comment',                flex  => 1,   dataIndex => 'comment',             },
            { 'header' => 'ID',                                   dataIndex => 'id',                  hidden => Cpanel::JSON::XS::true },
        ],
        data        => $c->stash->{'data'},
        totalCount  => $c->stash->{'pager'}->{'total_entries'},
        currentPage => $c->stash->{'pager'}->{'current_page'},
        paging      => Cpanel::JSON::XS::true,
    };

    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_pnp_graphs {
    my($c) = @_;

    $c->req->parameters->{'entries'} = $c->req->parameters->{'limit'} || 15;
    $c->req->parameters->{'page'}    = $c->req->parameters->{'page'}  || 1;
    my $search = $c->req->parameters->{'query'};
    my $graphs = [];
    my $data = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts')]);
    for my $hst (@{$data}) {
        my $text = $hst->{'name'}.';_HOST_';
        next if($search and $text !~ m/$search/mxi);
        my $url = Thruk::Utils::get_pnp_url($c, $hst, 1);
        if($url ne '') {
            push @{$graphs}, {
                text => $text,
                url  => $url.'/image?host='.$hst->{'name'}.'&srv=_HOST_',
            };
        }
    }

    $data = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services')]);
    for my $svc (@{$data}) {
        my $text = $svc->{'host_name'}.';'.$svc->{'description'};
        next if($search and $text !~ m/$search/mxi);
        my $url = Thruk::Utils::get_pnp_url($c, $svc, 1);
        if($url ne '') {
            push @{$graphs}, {
                text => $text,
                url  => $url.'/image?host='.$svc->{'host_name'}.'&srv='.$svc->{'description'},
            };
        }
    }
    $graphs = Thruk::Backend::Manager::sort_result({}, $graphs, 'text');
    Thruk::Backend::Manager::page_data($c, $graphs);

    my $json = {
        data        => $c->stash->{'data'},
        total       => $c->stash->{'pager'}->{'total_entries'},
        currentPage => $c->stash->{'pager'}->{'current_page'},
        paging      => Cpanel::JSON::XS::true,
    };

    return $c->render(json => $json);
}

##########################################################
sub _task_grafana_graphs {
    my($c) = @_;

    $c->req->parameters->{'entries'} = $c->req->parameters->{'limit'} || 15;
    $c->req->parameters->{'page'}    = $c->req->parameters->{'page'}  || 1;
    my $search  = $c->req->parameters->{'query'};
    my $search2 = $c->req->parameters->{'query2'}; # current selected graph should always be returned, otherwise text/alias replacement does not work on paging
    my $graphs = [];
    my $current;
    my $data = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts')]);
    for my $hst (@{$data}) {
        my $url = Thruk::Utils::get_histou_url($c, $hst, 1);
        if($url ne '') {
            my $text   = $hst->{'name'}.';';
            my $exturl = 'extinfo.cgi?type=grafana&host='.$hst->{'name'};
            if($search2 && $exturl eq $search2) {
                $current = {
                    text       => $text,
                    url        => $exturl,
                    source_url => $url,
                };
            }
            next if($search && $text !~ m/$search/mxi && $exturl ne $search);
            push @{$graphs}, {
                text       => $text,
                url        => $exturl,
                source_url => $url,
            };
        }
    }

    $data = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services')]);
    for my $svc (@{$data}) {
        my $url = Thruk::Utils::get_histou_url($c, $svc, 1);
        if($url ne '') {
            my $text   = $svc->{'host_name'}.';'.$svc->{'description'};
            my $exturl = 'extinfo.cgi?type=grafana&host='.$svc->{'host_name'}.'&service='.$svc->{'description'};
            if($search2 && $exturl eq $search2) {
                $current = {
                    text       => $text,
                    url        => $exturl,
                    source_url => $url,
                };
            }
            next if($search && $text !~ m/$search/mxi && $exturl ne $search);
            push @{$graphs}, {
                text       => $text,
                url        => $exturl,
                source_url => $url,
            };
        }
    }
    $graphs = Thruk::Backend::Manager::sort_result({}, $graphs, 'text');
    Thruk::Backend::Manager::page_data($c, $graphs);

    # make sure current graph is always part of the result
    push @{$c->stash->{'data'}}, $current if $current;

    my $json = {
        data        => $c->stash->{'data'},
        total       => $c->stash->{'pager'}->{'total_entries'},
        currentPage => $c->stash->{'pager'}->{'current_page'},
        paging      => Cpanel::JSON::XS::true,
    };

    return $c->render(json => $json);
}

##########################################################
sub _task_userdata_backgroundimages {
    my($c) = @_;
    my $folder = $c->stash->{'usercontent_folder'}.'/backgrounds/';
    my $query  = $c->req->parameters->{'query'};
    my $images = [];
    my $files = Thruk::Utils::find_files($folder, '\.(png|gif|jpg|jpeg|svg)$') || [];
    for my $img (@{$files}) {
        my $path = $img;
        $path    =~ s/^\Q$folder\E//gmx;
        next if $query and $path !~ m/\Q$query\E/mx;
        my $name = $path;
        $name    =~ s/^.*\///gmx;
        push @{$images}, {
            path  => '../usercontent/backgrounds/'.$path,
            image => $path,
        };
    }
    $c->req->parameters->{'entries'} = $c->req->parameters->{'limit'} || 15;
    $c->req->parameters->{'page'}    = $c->req->parameters->{'page'}  || 1;
    $images = Thruk::Backend::Manager::sort_result({}, $images, 'path');
    if(!$query) {
        unshift @{$images}, { path => $c->stash->{'url_prefix'}.'plugins/panorama/images/s2.gif', image => '&lt;upload new image&gt;'};
        unshift @{$images}, { path => $c->stash->{'url_prefix'}.'plugins/panorama/images/s.gif',  image => 'none'};
    }
    Thruk::Backend::Manager::page_data($c, $images);
    my $json = {
        data        => $c->stash->{'data'},
        total       => $c->stash->{'pager'}->{'total_entries'},
        currentPage => $c->stash->{'pager'}->{'current_page'},
        paging      => Cpanel::JSON::XS::true,
    };
    return $c->render(json => $json);
}

##########################################################
sub _task_userdata_images {
    my($c) = @_;
    my $folder = $c->stash->{'usercontent_folder'}.'/images/';
    my $query  = $c->req->parameters->{'query'};
    my $images = [];
    my $files = Thruk::Utils::find_files($folder, '\.(png|gif|jpg|jpeg|svg)$') || [];
    for my $img (@{$files}) {
        my $path = $img;
        $path    =~ s/^\Q$folder\E//gmx;
        next if $query and $path !~ m/\Q$query\E/mx;
        my $name = $path;
        $name    =~ s/^.*\///gmx;
        push @{$images}, {
            path  => '../usercontent/images/'.$path,
            image => $path,
        };
    }
    $c->req->parameters->{'entries'} = $c->req->parameters->{'limit'} || 15;
    $c->req->parameters->{'page'}    = $c->req->parameters->{'page'}  || 1;
    $images = Thruk::Backend::Manager::sort_result({}, $images, 'path');
    if(!$query) {
        unshift @{$images}, { path => $c->stash->{'url_prefix'}.'plugins/panorama/images/s2.gif', image => '&lt;upload new image&gt;'};
    }
    Thruk::Backend::Manager::page_data($c, $images);
    my $json = {
        data        => $c->stash->{'data'},
        total       => $c->stash->{'pager'}->{'total_entries'},
        currentPage => $c->stash->{'pager'}->{'current_page'},
        paging      => Cpanel::JSON::XS::true,
    };
    return $c->render(json => $json);
}

##########################################################
sub _task_userdata_iconsets {
    my($c, $return_only) = @_;
    my $folder  = $c->stash->{'usercontent_folder'}.'/images/status';
    my $folders = [];
    for my $f (glob("$folder/*/.")) {
        my $name = $f;
        $name    =~ s/^\Q$folder\E//gmx;
        $name    =~ s/^\///gmx;
        $name    =~ s/\/\.$//gmx;
        my $fileset = {};
        for my $pic (glob("$folder/$name/*.gif $folder/$name/*.jpg $folder/$name/*.png $folder/$name/*.svg")) {
            $pic =~ s|\Q$folder/$name/\E||gmx;
            my $type = $pic;
            $type =~ s/\.(png|gif|jpg|svg)$//gmx;
            $fileset->{$type} = $pic;
        }
        $fileset->{'ok'} = '' unless $fileset->{'ok'};
        push @{$folders}, { name => $name, 'sample' => "../usercontent/images/status/".$name."/".$fileset->{'ok'}, value => $name, fileset => $fileset };
    }
    $folders = Thruk::Backend::Manager::sort_result({}, $folders, 'name');
    if($c->req->parameters->{'withempty'}) {
        unshift @{$folders}, { name => 'use dashboards default iconset', 'sample' => $c->stash->{'url_prefix'}.'plugins/panorama/images/s.gif', value => '' };
    }
    return $folders if $return_only;
    my $json = { data => $folders };
    return $c->render(json => $json);
}

##########################################################
sub _task_userdata_trendiconsets {
    my($c, $return_only) = @_;
    my $folder  = $c->stash->{'usercontent_folder'}.'/images/trend';
    my $folders = [];
    for my $f (glob("$folder/*/.")) {
        my $name = $f;
        $name    =~ s/^\Q$folder\E//gmx;
        $name    =~ s/^\///gmx;
        $name    =~ s/\/\.$//gmx;
        my $fileset = {};
        for my $pic (glob("$folder/$name/*.gif $folder/$name/*.jpg $folder/$name/*.png  $folder/$name/*.svg")) {
            $pic =~ s|\Q$folder/$name/\E||gmx;
            my $type = $pic;
            $type =~ s/\.(png|gif|jpg|svg)$//gmx;
            $fileset->{$type} = $pic;
        }
        $fileset->{'good'} = '' unless $fileset->{'good'};
        push @{$folders}, { name => $name, 'sample' => "../usercontent/images/trend/".$name."/".$fileset->{'good'}, value => $name, fileset => $fileset };
    }
    $folders = Thruk::Backend::Manager::sort_result({}, $folders, 'name');
    return $folders if $return_only;
    my $json = { data => $folders };
    return $c->render(json => $json);
}

##########################################################
sub _task_userdata_sounds {
    my($c) = @_;
    my $folder = $c->stash->{'usercontent_folder'}.'/sounds/';
    my $sounds = [];
    for my $file (glob("$folder/*.ogg $folder/*/*.ogg $folder/*.mp3 $folder/*/*.mp3")) {
        my $path = $file;
        $path    =~ s/^\Q$folder\E//gmx;
        my $name = $path;
        $name    =~ s/^.*\///gmx;
        push @{$sounds}, {
            path  => '../usercontent/sounds'.$path,
            name  => $name,
        };
    }
    $sounds = Thruk::Backend::Manager::sort_result({}, $sounds, 'name');
    unshift @{$sounds}, { path => '', name => 'none'};
    my $json = { data => $sounds };
    return $c->render(json => $json);
}

##########################################################
sub _task_userdata_shapes {
    my($c, $return_only) = @_;
    my $folder = $c->stash->{'usercontent_folder'}.'/shapes/';
    my $shapes = [];
    for my $file (glob("$folder/*.js $folder/*/*.js $folder/*.shape $folder/*/*.shape")) {
        my $name = $file;
        $name    =~ s/^\Q$folder\E//gmx;
        $name    =~ s/^.*\///gmx;
        $name    =~ s/\.js$//gmx;
        $name    =~ s/\.shape$//gmx;
        push @{$shapes}, {
            name  => $name,
            data  => scalar read_file($file),
        };
    }
    $shapes = Thruk::Backend::Manager::sort_result({}, $shapes, 'name');
    return $shapes if $return_only;
    my $json = { data => $shapes };
    return $c->render(json => $json);
}

##########################################################
sub _task_host_list {
    my($c) = @_;

    my $hosts = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts')], columns => [qw/name/]);
    my $data = [];
    for my $hst (@{$hosts}) {
        push @{$data}, { name => $hst->{'name'} };
    }

    $data = Thruk::Backend::Manager::sort_result({}, $data, 'name');
    my $json = { data => $data };
    return $c->render(json => $json);
}

##########################################################
sub _task_host_detail {
    my($c) = @_;

    my $host        = $c->req->parameters->{'host'}    || '';
    my $json      = {};
    my $hosts     = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), { name => $host }], extra_columns => [qw/long_plugin_output/]);
    my $downtimes = $c->{'db'}->get_downtimes(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'host_name' => $host }, { 'service_description' => '' } ],
        sort => { 'DESC' => 'id' },
    );
    if(defined $hosts and scalar @{$hosts} > 0) {
        if($c->stash->{'escape_html_tags'}) {
            _escape($hosts->[0]);
        }
        my $cust_vars = Thruk::Utils::get_custom_vars($c, $hosts->[0]);
        $json = { data => $hosts->[0], downtimes => $downtimes, action_menu => $cust_vars->{'THRUK_ACTION_MENU'} };
    }
    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_service_list {
    my($c) = @_;

    my $host     = $c->req->parameters->{'host'} || '';
    my $services = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), { host_name => $host }], columns => [qw/description/]);
    my $data = [];
    for my $svc (@{$services}) {
        push @{$data}, { description => $svc->{'description'} };
    }

    $data = Thruk::Backend::Manager::sort_result({}, $data, 'description');
    my $json = { data => $data };
    return $c->render(json => $json);
}

##########################################################
sub _task_service_detail {
    my($c) = @_;

    my $host        = $c->req->parameters->{'host'}    || '';
    my $description = $c->req->parameters->{'service'} || '';
    my $json        = {};
    my $services    = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), { host_name => $host, description => $description }], extra_columns => [qw/long_plugin_output/]);
    my $downtimes = $c->{'db'}->get_downtimes(
        filter => [ Thruk::Utils::Auth::get_auth_filter( $c, 'downtimes' ), { 'host_name' => $host }, { 'service_description' => $description } ],
        sort => { 'DESC' => 'id' },
    );
    if(defined $services and scalar @{$services} > 0) {
        if($c->stash->{'escape_html_tags'}) {
            _escape($services->[0]);
        }
        my $cust_vars = Thruk::Utils::get_custom_vars($c, $services->[0]);
        $json = { data => $services->[0], downtimes => $downtimes, action_menu => $cust_vars->{'THRUK_ACTION_MENU'} };
    }
    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_dashboard_save_states {
    my($c) = @_;
    my $nr   = $c->req->parameters->{'nr'} || die('no number supplied');
    $nr      =~ s/^pantab_//gmx;

    my $dashboard = Thruk::Utils::Panorama::load_dashboard($c, $nr, 1);
    my $runtime   = _extract_runtime_data($dashboard);
    my $states;
    eval {
        $states = decode_json($c->req->parameters->{'states'});
    };
    if($@) {
        _warn('_task_dashboard_save_states failed: '.$@);
        return;
    }
    for my $id (keys %{$runtime}, keys %{$states}) {
        for my $key (@runtime_keys) {
            $runtime->{$id}->{$key} = $states->{$id}->{$key} if defined $states->{$id}->{$key};
        }
    }
    my $runtime_file = Thruk::Utils::Panorama::get_runtime_file($c, $nr);
    Thruk::Utils::write_data_file($runtime_file, $runtime, 1);
    Thruk::Utils::IO::touch($runtime_file); # update timestamp because thats what we use for last_used

    my $json = { 'status' => 'ok' };
    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_dashboard_data {
    my($c) = @_;
    my $nr = $c->req->parameters->{'nr'} || die('no number supplied');
    $nr = Thruk::Utils::array_uniq(Thruk::Utils::list($nr));

    my $open_tabs_hash = Thruk::Utils::array2hash(Thruk::Utils::list($c->req->parameters->{'recursive'}));
    if(scalar @{$nr} > 1) {
        my $json;
        my $data = {};
        for my $n (@{$nr}) {
            _add_initial_dashboard($c, $n, $data, undef, $open_tabs_hash);
        }
        return $c->render(json => { data => $data });
    }
    $nr = $nr->[0];

    my $dashboard;
    my $new_override = 0;
    if($nr eq 'new_or_empty' || $nr eq 'first_or_new') {
        # avoid too many empty dashboards, so return the first existing empty dashboard for this user
        my $dashboards = Thruk::Utils::Panorama::get_dashboard_list($c, 'my');
        for my $d (@{$dashboards}) {
            if($nr eq 'first_or_new' || $d->{'objects'} == 0) {
                $nr = $d->{'nr'};
                $new_override = 1;
                last;
            }
        }
        $nr = 'new' if $nr eq 'first_or_new';
        $nr = 'new' if $nr eq 'new_or_empty';
    }

    if($nr eq 'new') {
        return if $c->stash->{'readonly'};
        $dashboard = {
            tab     => {
                xdata => _get_default_tab_xdata($c),
            },
            id      => 'new',
        };
        $dashboard = _save_dashboard($c, $dashboard);
    } else {
        $dashboard = Thruk::Utils::Panorama::load_dashboard($c, $nr);
    }
    my $json;
    if(!$dashboard) {
        if(!$c->req->parameters->{'hidden'}) {
            Thruk::Utils::set_message( $c, { style => 'fail_message', msg => 'no such dashboard' });
        }
        $c->res->code(404);
        $json = { 'status' => 'failed' };
    } else {
        my $data = {};
        _merge_dashboard_into_hash($c, $dashboard, $data);
        _add_recursive_dashboards($c, $dashboard, $data, undef, $open_tabs_hash);
        if($nr eq 'new' || $new_override) {
            $data->{'newid'} = $dashboard->{'id'};
        }
        $json = { data => $data };
    }
    return $c->render(json => $json);
}

##########################################################
sub _get_dashboard_by_name {
    my($c, $name) = @_;
    return unless $name;

    for my $file (glob($c->{'panorama_etc'}.'/*.tab')) {
        if($file =~ s/^.*\/(\d+)\.tab$//mx) {
            my $d = Thruk::Utils::Panorama::load_dashboard($c, $1, 1);
            if($d) {
                if(  ($d->{'tab'}->{'xdata'}->{'title'} && $d->{'tab'}->{'xdata'}->{'title'} eq $name)
                   || $d->{'nr'} eq $name) {
                    return($d);
                }
            }
        }
    }
    return;
}

##########################################################
sub _task_dashboard_list {
    my($c) = @_;

    my $type       = $c->req->parameters->{'list'} || 'my';
    my $dashboards = Thruk::Utils::Panorama::get_dashboard_list($c, $type);

    my $columns = [
        { 'header' => 'Id',                        dataIndex => 'id',                              hidden => Cpanel::JSON::XS::true },
        { 'header' => 'Nr',          width => 60,  dataIndex => 'nr', align => 'left' },
        { 'header' => '',            width => 20,  dataIndex => 'visible',      align => 'left', tdCls => 'icon_column', renderer => 'TP.render_dashboard_toggle_visible' },
        { 'header' => 'Name',        width => 130, dataIndex => 'name',         align => 'left', editor => {}, tdCls => 'editable'   },
        { 'header' => 'Description', flex  => 1,   dataIndex => 'description',  align => 'left', editor => {}, tdCls => 'editable'   },
        { 'header' => 'Owner',        width => 130, dataIndex => 'user',        align => 'center',
                                        editor => $c->stash->{'is_admin'} ? {} : undef,
                                        hidden => $type eq 'my' ? Cpanel::JSON::XS::true : Cpanel::JSON::XS::false,
                                        tdCls => $c->stash->{'is_admin'} ? 'editable' : '',
        },
        { 'header' => 'Read-Write Permissions',  width => 135, dataIndex => 'perm_rw',    align => 'left' },
        { 'header' => 'Read-Only Permissions',   width => 135, dataIndex => 'perm_ro',    align => 'left' },
        { 'header' => 'Direct Link',        width =>  65, dataIndex => 'link',         align => 'center', renderer => 'TP.render_directlink' },
        { 'header' => 'Objects',     width => 55,  dataIndex => 'objects',      align => 'center' },
        { 'header' => 'Last Time Used',     width => 130,  dataIndex => 'last_used',   align => 'center', renderer => 'TP.render_date_only' },
        { 'header' => 'Readonly',    width => 60,  dataIndex => 'readonly',     align => 'center', renderer => 'TP.render_yes_no' },
        { 'header' => 'Actions',     width => 60,
                    xtype => 'actioncolumn',
                    items => [{
                        icon => '../plugins/panorama/images/edit.png',
                        handler => 'TP.dashboardActionHandler',
                        action  => 'edit',
                    }, {
                        icon => '../plugins/panorama/images/delete.png',
                        handler => 'TP.dashboardActionHandler',
                        action  => 'remove',
                    }],
                    tdCls => 'clickable icon_column',
        },
    ];

    my $search = $c->req->parameters->{'query'};
    if($search) {
        my $filtered = [];
        for my $d (@{$dashboards}) {
            next unless $d->{'name'} =~ m/$search/mxi;
            push @{$filtered}, $d;
        }
        $dashboards = $filtered;
    }

    # add last_used data
    for my $d (@{$dashboards}) {
        $d->{'last_used'} = 0;
        for my $file (glob($c->config->{'var_path'}.'/panorama/'.$d->{'nr'}.'.tab.*runtime')) {
            my @stat = stat($file);
            $d->{'last_used'} = $stat[9] if $d->{'last_used'} < $stat[9];
        }
    }

    $c->req->parameters->{'entries'} = $c->req->parameters->{'limit'} // 'all';
    $c->req->parameters->{'page'}    = $c->req->parameters->{'page'}  || 1;
    Thruk::Backend::Manager::page_data($c, $dashboards);
    my $json = {
        columns     => $columns,
        data        => $c->stash->{'data'},
        total       => $c->stash->{'pager'}->{'total_entries'},
        currentPage => $c->stash->{'pager'}->{'current_page'},
        paging      => Cpanel::JSON::XS::true,
    };

    _add_misc_details($c, 1, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_dashboard_update {
    my($c) = @_;

    my $json   = { 'status' => 'failed' };
    my $nr     = $c->req->parameters->{'nr'};
    my $action = $c->req->parameters->{'action'};
    my $dashboard = Thruk::Utils::Panorama::load_dashboard($c, $nr, 1);
    if($action && $dashboard && !$dashboard->{'readonly'}) {
        $json = { 'status' => 'ok' };
        if($action eq 'remove') {
            Thruk::Utils::Panorama::delete_dashboard($c, $nr, $dashboard);
        }
        if($action eq 'update') {
            my $extra_settings = {};
            my $field = $c->req->parameters->{'field'};
            my $value = $c->req->parameters->{'value'};
            if($field eq 'description') {
                $extra_settings->{$field} = $value;
            }
            elsif($field eq 'name') {
                $dashboard->{'tab'}->{'xdata'}->{'title'} = $value;
            }
            elsif($field eq 'user' and $c->stash->{'is_admin'}) {
                $extra_settings->{$field} = $value;
            }
            _save_dashboard($c, $dashboard, $extra_settings);
        }
    }
    _add_misc_details($c, 1, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_dashboard_restore_list {
    my($c) = @_;

    my $nr         = $c->req->parameters->{'nr'};
    my $dashboard  = Thruk::Utils::Panorama::load_dashboard($c, $nr, 1);
    my $permission = Thruk::Utils::Panorama::is_authorized_for_dashboard($c, $nr, $dashboard);
    my $json;
    if($permission >= ACCESS_READWRITE && !$dashboard->{'scripted'}) {
        my $list = {
            a => [],
            m => [],
        };
        $nr       =~ s/^pantab_//gmx;
        my @files = reverse sort glob($c->{'panorama_var'}.'/'.$nr.'.tab.*');
        for my $file (@files) {
            next if $file =~ m/\.runtime$/mx;
            if($file =~ m/\.(\d+)\.(\w)$/mx) {
                my $date = $1;
                my $mode = $2;
                push(@{$list->{$mode}}, { num => $date });
            } else {
                die("wrong file name format in $file");
            }
        }
        $json = { data => $list };
    }
    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_dashboard_restore_point {
    my($c) = @_;

    my $nr         = $c->req->parameters->{'nr'};
       $nr         =~ s/^pantab_//gmx;
    my $mode       = $c->req->parameters->{'mode'} || 'm';
    my $dashboard  = Thruk::Utils::Panorama::load_dashboard($c, $nr, 1);
    my $permission = Thruk::Utils::Panorama::is_authorized_for_dashboard($c, $nr, $dashboard);
    my $etc_file   = $c->{'panorama_etc'}.'/'.$nr.'.tab';
    my $var_file   = $c->{'panorama_var'}.'/'.$nr.'.tab';
    if($permission >= ACCESS_READWRITE && !$dashboard->{'scripted'}) {
        if(!$mode || $mode eq 'm') {
            Thruk::Utils::backup_data_file($etc_file, $var_file, 'm', 5, 0, 1);
        } else {
            Thruk::Utils::backup_data_file($etc_file, $var_file, 'a', 5, 600, 1);
        }
    }

    my $json = { msg => "ok" };
    _add_misc_details($c, undef, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_dashboard_restore {
    my($c) = @_;

    my $nr         = $c->req->parameters->{'nr'};
    my $mode       = $c->req->parameters->{'mode'};
       $nr         =~ s/^pantab_//gmx;
    my $timestamp  = $c->req->parameters->{'timestamp'};
    my $dashboard  = Thruk::Utils::Panorama::load_dashboard($c, $nr, 1);
    my $permission = Thruk::Utils::Panorama::is_authorized_for_dashboard($c, $nr, $dashboard);
    if($permission >= ACCESS_READWRITE && !$dashboard->{'scripted'}) {
        die("no such dashboard") unless -e $c->{'panorama_etc'}.'/'.$nr.'.tab';
        die("no such restore point") unless -e $c->{'panorama_var'}.'/'.$nr.'.tab.'.$timestamp.".".$mode;
        unlink($c->{'panorama_etc'}.'/'.$nr.'.tab');
        copy($c->{'panorama_var'}.'/'.$nr.'.tab.'.$timestamp.".".$mode, $c->{'panorama_etc'}.'/'.$nr.'.tab');
    }
    my $json = {};
    _add_misc_details($c, 1, $json);
    return $c->render(json => $json);
}

##########################################################
sub _task_dashboards_clean {
    my($c) = @_;

    die("no admin permissions") unless $c->stash->{'is_admin'};
    my $json = { num => Thruk::Utils::Panorama::clean_old_dashboards($c) };
    _add_misc_details($c, 1, $json);
    return $c->render(json => $json);
}

##########################################################
sub _get_gearman_stats {
    my($c) = @_;

    my $data = {};
    my $host = 'localhost';
    my $port = 4730;

    if(defined $c->req->parameters->{'server'}) {
        ($host,$port) = split(/:/mx, $c->req->parameters->{'server'}, 2);
    }

    load IO::Socket;
    my $handle = IO::Socket::INET->new(
        Proto    => "tcp",
        PeerAddr => $host,
        PeerPort => $port,
    )
    or do {
        _warn("can't connect to port $port on $host: $!") unless(Thruk->mode eq 'TEST');
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
    my($c) = @_;

    # reset existing filter
    Thruk::Utils::Status::reset_filter($c);

    if(!defined $c->req->parameters->{'filter'} || $c->req->parameters->{'filter'} eq '') {
        my @f = Thruk::Utils::Status::do_filter($c);
        return @f;
    }

    my $filter;
    eval {
        $filter = decode_json($c->req->parameters->{'filter'});
    };
    if($@) {
        _warn('filter failed: '.$@);
        return;
    }

    if(ref $filter eq 'HASH') {
        $filter = [$filter];
    }

    my $nr = 0;
    for my $f (@{$filter}) {
        my $pre = 'dfl_s'.$nr.'_';
        for my $key (qw/hostprops hoststatustypes serviceprops servicestatustypes/) {
            $c->req->parameters->{$pre.$key} = $f->{$key};
        }
        for my $type (qw/op type value value_date val_pre/) {
            if(ref $f->{$type} ne 'ARRAY') { $f->{$type} = [$f->{$type}]; }
        }

        for my $type (qw/op type value val_pre/) {
            my $x = 0;
            for my $val (@{$f->{$type}}) {
                $c->req->parameters->{$pre.$type} = [] unless defined $c->req->parameters->{$pre.$type};
                if($type eq 'value') {
                    if(!defined $val) { $val = ''; }
                    if($f->{'type'}->[$x] eq 'last check' or $f->{'type'}->[$x] eq 'next check') {
                        $val = $f->{'value_date'}->[$x];
                        $val =~ s/T/ /gmx;
                    }
                }
                elsif($type eq 'type') {
                    $val = lc($val || '');
                }
                elsif($type eq 'val_pre') {
                    if(!defined $val) { $val = ''; }
                }

                push @{$c->req->parameters->{$pre.$type}}, $val;
                $x++;
            }
        }
        $nr++;
    }

    my @f = Thruk::Utils::Status::do_filter($c);
    return @f;
}

##########################################################
sub _generate_service_popup {
    my ($c, $service) = @_;
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
sub _summarize_hostgroup_query {
    my($c, $type_groups, $state_type) = @_;

    my $filter = Thruk::Utils::combine_filter('-or', [map {{ name => { '=' => $_ }}} keys %{$type_groups}]);
    my $details = $c->{'db'}->get_hostgroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hostgroups'), $filter ], columns => [qw/name alias/]);
    $details = Thruk::Utils::array2hash($details, 'name');

    $filter = Thruk::Utils::combine_filter('-or', [map {{ groups => { '>=' => $_ }}} keys %{$type_groups}]);
    my $hosts = $c->{'db'}->get_hosts(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $filter ], columns => [qw/name groups state state_type last_state_change acknowledged scheduled_downtime_depth has_been_checked/]);
    my $hostgroups = {};
    for my $hst (@{$hosts}) {
        for my $grp (@{$hst->{'groups'}}) {
            next unless defined $type_groups->{$grp};
            if(!defined $hostgroups->{$grp}) {
                $hostgroups->{$grp} = { services => { ok => 0, warning => 0, critical => 0, unknown => 0, pending => 0,
                                                      plain_ok => 0, plain_warning => 0, plain_critical => 0, plain_unknown => 0, plain_pending => 0,
                                                      ack_warning => 0, ack_critical => 0, ack_unknown => 0,
                                                      downtime_ok => 0, downtime_warning => 0, downtime_critical => 0, downtime_unknown => 0,
                                                    },
                                        hosts    => { up => 0, down => 0, unreachable => 0, pending => 0,
                                                      plain_up => 0, plain_down => 0, plain_unreachable => 0, plain_pending => 0,
                                                      ack_down => 0, ack_unreachable => 0,
                                                      downtime_up => 0, downtime_down => 0, downtime_unreachable => 0,
                                                    },
                                        name     => $grp,
                                        alias    => $details->{$grp}->{'alias'} // '',
                                      };
            }
            if($state_type == HARD_STATE && $hst->{'state_type'} != HARD_STATE) {
                $hostgroups->{$grp}->{'hosts'}->{'up'}++;
                if($hst->{'scheduled_downtime_depth'}) {
                    $hostgroups->{$grp}->{'hosts'}->{'downtime_up'}++;
                } else {
                    $hostgroups->{$grp}->{'hosts'}->{'plain_up'}++;
                }
                next;
            }
            if($hst->{'has_been_checked'} == 0) { $hostgroups->{$grp}->{'hosts'}->{'pending'}++;     }
            elsif($hst->{'state'} == 0)         { $hostgroups->{$grp}->{'hosts'}->{'up'}++;          }
            elsif($hst->{'state'} == 1)         { $hostgroups->{$grp}->{'hosts'}->{'down'}++;        }
            elsif($hst->{'state'} == 2)         { $hostgroups->{$grp}->{'hosts'}->{'unreachable'}++; }
            if($hst->{'acknowledged'}) {
                   if($hst->{'state'} == 1)         { $hostgroups->{$grp}->{'hosts'}->{'ack_down'}++;        }
                elsif($hst->{'state'} == 2)         { $hostgroups->{$grp}->{'hosts'}->{'ack_unreachable'}++; }
            }
            if($hst->{'scheduled_downtime_depth'}) {
                   if($hst->{'state'} == 0)         { $hostgroups->{$grp}->{'hosts'}->{'downtime_up'}++;          }
                elsif($hst->{'state'} == 1)         { $hostgroups->{$grp}->{'hosts'}->{'downtime_down'}++;        }
                elsif($hst->{'state'} == 2)         { $hostgroups->{$grp}->{'hosts'}->{'downtime_unreachable'}++; }
            }
            if(!$hst->{'acknowledged'} && !$hst->{'scheduled_downtime_depth'}) {
                if($hst->{'has_been_checked'} == 0) { $hostgroups->{$grp}->{'hosts'}->{'plain_pending'}++;     }
                elsif($hst->{'state'} == 0)         { $hostgroups->{$grp}->{'hosts'}->{'plain_up'}++;          }
                elsif($hst->{'state'} == 1)         { $hostgroups->{$grp}->{'hosts'}->{'plain_down'}++;        }
                elsif($hst->{'state'} == 2)         { $hostgroups->{$grp}->{'hosts'}->{'plain_unreachable'}++; }
            }
        }
    }
    $filter      = Thruk::Utils::combine_filter('-or', [map {{ host_groups => { '>=' => $_ }}} keys %{$type_groups}]);
    my $services = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $filter ], columns => [qw/host_name description host_groups state state_type last_state_change acknowledged scheduled_downtime_depth has_been_checked/]);
    for my $svc (@{$services}) {
        for my $grp (@{$svc->{'host_groups'}}) {
            next unless defined $type_groups->{$grp};
            if($state_type == HARD_STATE && $svc->{'state_type'} != HARD_STATE) {
                $hostgroups->{$grp}->{'services'}->{'ok'}++;
                if($svc->{'scheduled_downtime_depth'}) {
                   $hostgroups->{$grp}->{'services'}->{'downtime_ok'}++;
                } else {
                    $hostgroups->{$grp}->{'services'}->{'plain_ok'}++;
                }
                next;
            }
            if($svc->{'has_been_checked'} == 0) { $hostgroups->{$grp}->{'services'}->{'pending'}++;  }
            elsif($svc->{'state'} == 0)         { $hostgroups->{$grp}->{'services'}->{'ok'}++;       }
            elsif($svc->{'state'} == 1)         { $hostgroups->{$grp}->{'services'}->{'warning'}++;  }
            elsif($svc->{'state'} == 2)         { $hostgroups->{$grp}->{'services'}->{'critical'}++; }
            elsif($svc->{'state'} == 3)         { $hostgroups->{$grp}->{'services'}->{'unknown'}++;  }
            if($svc->{'acknowledged'}) {
                   if($svc->{'state'} == 1)         { $hostgroups->{$grp}->{'services'}->{'ack_warning'}++;  }
                elsif($svc->{'state'} == 2)         { $hostgroups->{$grp}->{'services'}->{'ack_critical'}++; }
                elsif($svc->{'state'} == 3)         { $hostgroups->{$grp}->{'services'}->{'ack_unknown'}++;  }
            }
            if($svc->{'scheduled_downtime_depth'}) {
                   if($svc->{'state'} == 0)         { $hostgroups->{$grp}->{'services'}->{'downtime_ok'}++;       }
                elsif($svc->{'state'} == 1)         { $hostgroups->{$grp}->{'services'}->{'downtime_warning'}++;  }
                elsif($svc->{'state'} == 2)         { $hostgroups->{$grp}->{'services'}->{'downtime_critical'}++; }
                elsif($svc->{'state'} == 3)         { $hostgroups->{$grp}->{'services'}->{'downtime_unknown'}++;  }
            }
            if(!$svc->{'acknowledged'} && !$svc->{'scheduled_downtime_depth'}) {
                if($svc->{'has_been_checked'} == 0) { $hostgroups->{$grp}->{'services'}->{'plain_pending'}++;  }
                elsif($svc->{'state'} == 0)         { $hostgroups->{$grp}->{'services'}->{'plain_ok'}++;       }
                elsif($svc->{'state'} == 1)         { $hostgroups->{$grp}->{'services'}->{'plain_warning'}++;  }
                elsif($svc->{'state'} == 2)         { $hostgroups->{$grp}->{'services'}->{'plain_critical'}++; }
                elsif($svc->{'state'} == 3)         { $hostgroups->{$grp}->{'services'}->{'plain_unknown'}++;  }
            }
        }
    }
    return($hostgroups);
}

##########################################################
sub _summarize_servicegroup_query {
    my($c, $type_groups, $state_type) = @_;

    my $filter = Thruk::Utils::combine_filter('-or', [map {{ name => { '=' => $_ }}} keys %{$type_groups}]);
    my $details = $c->{'db'}->get_servicegroups(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'servicegroups'), $filter ], columns => [qw/name alias/]);
    $details = Thruk::Utils::array2hash($details, 'name');

    $filter = Thruk::Utils::combine_filter('-or', [map {{ groups => { '>=' => $_ }}} keys %{$type_groups}]);
    my $services = $c->{'db'}->get_services(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $filter ], columns => [qw/host_name description groups state state_type last_state_change acknowledged scheduled_downtime_depth has_been_checked/]);
    my $servicegroups = {};
    for my $svc (@{$services}) {
        for my $grp (@{$svc->{'groups'}}) {
            next unless defined $type_groups->{$grp};
            if(!defined $servicegroups->{$grp}) {
                $servicegroups->{$grp} = { services => { ok => 0, warning => 0, critical => 0, unknown => 0, pending => 0,
                                                         plain_ok => 0, plain_warning => 0, plain_critical => 0, plain_unknown => 0, plain_pending => 0,
                                                         ack_warning => 0, ack_critical => 0, ack_unknown => 0,
                                                         downtime_ok => 0, downtime_warning => 0, downtime_critical => 0, downtime_unknown => 0,
                                                       },
                                           name     => $grp,
                                           alias    => $details->{$grp}->{'alias'} // '',
                                         };
            }
            if($state_type == HARD_STATE && $svc->{'state_type'} != HARD_STATE) {
                $servicegroups->{$grp}->{'services'}->{'ok'}++;
                if($svc->{'scheduled_downtime_depth'}) {
                    $servicegroups->{$grp}->{'services'}->{'downtime_ok'}++;
                } else {
                    $servicegroups->{$grp}->{'services'}->{'plain_ok'}++;
                }
                next;
            }
            if($svc->{'has_been_checked'} == 0) { $servicegroups->{$grp}->{'services'}->{'pending'}++;  }
            elsif($svc->{'state'} == 0)         { $servicegroups->{$grp}->{'services'}->{'ok'}++;       }
            elsif($svc->{'state'} == 1)         { $servicegroups->{$grp}->{'services'}->{'warning'}++;  }
            elsif($svc->{'state'} == 2)         { $servicegroups->{$grp}->{'services'}->{'critical'}++; }
            elsif($svc->{'state'} == 3)         { $servicegroups->{$grp}->{'services'}->{'unknown'}++;  }
            if($svc->{'acknowledged'}) {
                   if($svc->{'state'} == 1)         { $servicegroups->{$grp}->{'services'}->{'ack_warning'}++;    }
                elsif($svc->{'state'} == 2)         { $servicegroups->{$grp}->{'services'}->{'ack_critical'}++;   }
                elsif($svc->{'state'} == 3)         { $servicegroups->{$grp}->{'services'}->{'ack_unknown'}++;    }
            }
            if($svc->{'scheduled_downtime_depth'}) {
                   if($svc->{'state'} == 0)         { $servicegroups->{$grp}->{'services'}->{'downtime_ok'}++;        }
                elsif($svc->{'state'} == 1)         { $servicegroups->{$grp}->{'services'}->{'downtime_warning'}++;   }
                elsif($svc->{'state'} == 2)         { $servicegroups->{$grp}->{'services'}->{'downtime_critical'}++;  }
                elsif($svc->{'state'} == 3)         { $servicegroups->{$grp}->{'services'}->{'downtime_unknown'}++;   }
            }
            if(!$svc->{'acknowledged'} && !$svc->{'scheduled_downtime_depth'}) {
                if($svc->{'has_been_checked'} == 0) { $servicegroups->{$grp}->{'services'}->{'plain_pending'}++;  }
                elsif($svc->{'state'} == 0)         { $servicegroups->{$grp}->{'services'}->{'plain_ok'}++;       }
                elsif($svc->{'state'} == 1)         { $servicegroups->{$grp}->{'services'}->{'plain_warning'}++;  }
                elsif($svc->{'state'} == 2)         { $servicegroups->{$grp}->{'services'}->{'plain_critical'}++; }
                elsif($svc->{'state'} == 3)         { $servicegroups->{$grp}->{'services'}->{'plain_unknown'}++;  }
            }
        }
    }
    return($servicegroups);
}

##########################################################
sub _summarize_query {
    my($c, $incl_hst, $incl_svc, $hostfilter, $servicefilter, $state_type, $has_service_filter) = @_;
    my $sum   = { services => { ok => 0, warning => 0, critical => 0, unknown => 0, pending => 0,
                                plain_ok => 0, plain_warning => 0, plain_critical => 0, plain_unknown => 0, plain_pending => 0,
                                ack_warning => 0, ack_critical => 0, ack_unknown => 0,
                                downtime_ok => 0, downtime_warning => 0, downtime_critical => 0, downtime_unknown => 0,
                              },
                  hosts    => { up => 0, down => 0, unreachable => 0, pending => 0,
                                plain_up => 0, plain_down => 0, plain_unreachable => 0, plain_pending => 0,
                                ack_down => 0, ack_unreachable => 0,
                                downtime_up => 0, downtime_down => 0, downtime_unreachable => 0,
                              },
                };
    if($incl_hst) {
        my $host_sum;
        if(!$has_service_filter) {
            $host_sum = $c->{'db'}->get_host_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'hosts'), $hostfilter ]);
        } else {
            $host_sum = $c->{'db'}->get_host_stats_by_servicequery(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter ]);
        }
        for my $k (qw/up down unreachable pending/) {
            $sum->{'hosts'}->{$k} = $host_sum->{$k};
            $sum->{'hosts'}->{'plain_'.$k} = $host_sum->{'plain_'.$k};
            if($k ne 'up' and $k ne 'pending') {
                $sum->{'hosts'}->{'ack_'.$k} = $host_sum->{$k.'_and_ack'};
            }
            if($k ne 'pending') {
                $sum->{'hosts'}->{'downtime_'.$k} = $host_sum->{$k.'_and_scheduled'};
            }
        }
    }
    if($incl_svc) {
        my $service_sum = $c->{'db'}->get_service_stats(filter => [ Thruk::Utils::Auth::get_auth_filter($c, 'services'), $servicefilter ]);
        for my $k (qw/ok warning critical unknown pending/) {
            $sum->{'services'}->{$k} = $service_sum->{$k};
            $sum->{'services'}->{'plain_'.$k} = $service_sum->{'plain_'.$k};
            if($k ne 'ok' and $k ne 'pending') {
                $sum->{'services'}->{'ack_'.$k} = $service_sum->{$k.'_and_ack'};
            }
            if($k ne 'pending') {
                $sum->{'services'}->{'downtime_'.$k} = $service_sum->{$k.'_and_scheduled'};
            }
        }
    }
    return($sum);
}

##########################################################
sub _save_dashboard {
    my($c, $dashboard, $extra_settings) = @_;

    my $nr   = delete $dashboard->{'id'};
    $nr      =~ s/^pantab_//gmx;
    my $file = $c->{'panorama_etc'}.'/'.$nr.'.tab';

    my $existing = $nr eq 'new' ? $dashboard : Thruk::Utils::Panorama::load_dashboard($c, $nr, 1);
    return unless Thruk::Utils::Panorama::is_authorized_for_dashboard($c, $nr, $existing) >= ACCESS_READWRITE;

    # do not overwrite scripted dashboards
    return if $nr eq "0"; # may be non-numeric too
    return if $dashboard->{'scripted'};
    return if -x $file;

    if($nr eq 'new') {
        # find next free number
        $nr = $c->config->{'Thruk::Plugin::Panorama'}->{'new_files_start_at'} || 1;
        $file = $c->{'panorama_etc'}.'/'.$nr.'.tab';
        while(-e $file) {
            $nr++;
            $file = $c->{'panorama_etc'}.'/'.$nr.'.tab';
        }
    }

    # preserve some settings
    if($existing) {
        $dashboard->{'user'} = $existing->{'user'} || $c->stash->{'remote_user'};
    }

    if($extra_settings) {
        for my $key (keys %{$extra_settings}) {
            $dashboard->{$key} = $extra_settings->{$key};
        }
    }

    delete $dashboard->{'version'}; # leftover from imported dashboard
    delete $dashboard->{'nr'};
    delete $dashboard->{'id'};
    delete $dashboard->{'file'};
    delete $dashboard->{'locked'};
    delete $dashboard->{'tab'}->{'xdata'}->{'owner'};
    delete $dashboard->{'tab'}->{'xdata'}->{''};
    delete $dashboard->{'tab'}->{'readonly'};
    delete $dashboard->{'tab'}->{'user'};
    delete $dashboard->{'tab'}->{'ts'};
    delete $dashboard->{'tab'}->{'public'};
    delete $dashboard->{'tab'}->{'scripted'};

    # set file version
    $dashboard->{'file_version'} = DASHBOARD_FILE_VERSION;

    if($dashboard->{'tab'}->{'xdata'}->{'backends'}) {
        $dashboard->{'tab'}->{'xdata'}->{'backends'} = Thruk::Utils::backends_list_to_hash($c, $dashboard->{'tab'}->{'xdata'}->{'backends'});
    }

    for my $key (sort keys %{$dashboard}) {
        my $newkey = $key;
        $newkey =~ s/^.*_(panlet_\d+)$/$1/gmx;
        $dashboard->{$newkey} = delete $dashboard->{$key};
    }

    # save runtime data in extra file
    my $runtime      = _extract_runtime_data($dashboard);
    my $runtime_file = Thruk::Utils::Panorama::get_runtime_file($c, $nr);

    Thruk::Utils::write_data_file($file, $dashboard, 1);
    Thruk::Utils::write_data_file($runtime_file, $runtime, 1);
    Thruk::Utils::IO::touch($runtime_file); # update timestamp because thats what we use for last_used
    Thruk::Utils::backup_data_file($c->{'panorama_etc'}.'/'.$nr.'.tab', $c->{'panorama_var'}.'/'.$nr.'.tab', 'a', 5, 600);
    $dashboard->{'nr'} = $nr;
    $dashboard->{'id'} = 'pantab_'.$nr;
    $dashboard->{'ts'} = [stat($file)]->[9];
    return $dashboard;
}

##########################################################
sub _merge_dashboard_into_hash {
    my($c, $dashboard, $data) = @_;
    return $data unless $dashboard;

    my $id = $dashboard->{'id'};
    for my $key (keys %{$dashboard}) {
        if($key =~ m/^panlet_\d+$/mx) {
            $data->{$id.'_'.$key} = $dashboard->{$key};
        }
        elsif($key eq 'tab') {
            # add some values to the tab
            for my $k (qw/user public readonly ts scripted maintenance/) {
                $dashboard->{'tab'}->{$k} = $dashboard->{$k} if defined $dashboard->{$k};
            }
            $data->{$id} = $dashboard->{'tab'};

            # touch runtime file, since thats what we use to reflect last_used date
            my $runtime_file = Thruk::Utils::Panorama::get_runtime_file($c, $dashboard->{'nr'});
            Thruk::Utils::IO::touch($runtime_file);
        }
    }
    return $data;
}

##########################################################
sub _add_initial_dashboard {
    my($c, $nr, $data, $shapes, $open_tabs) = @_;

    my $dashboard = Thruk::Utils::Panorama::load_dashboard($c, $nr);
    if(!$dashboard && $data->{'tabbar'}->{'open_tabs'}) {
        # remove orphaned or removed dashboards
        @{$data->{'tabbar'}->{'open_tabs'}} = grep !/^\Q$nr\E$/mx, @{$data->{'tabbar'}->{'open_tabs'}};
        return;
    }
    _merge_dashboard_into_hash($c, $dashboard, $data);
    _add_recursive_dashboards($c, $dashboard, $data, $shapes, $open_tabs);
    return;
}

##########################################################
sub _add_recursive_dashboards {
    my($c, $dashboard, $data, $shapes, $open_tabs) = @_;
    my $add_hidden = {};
    # add shapes data
    for my $key (keys %{$dashboard}) {
        if(ref $dashboard->{$key} eq 'HASH' && $dashboard->{$key}->{'xdata'} && $dashboard->{$key}->{'xdata'}->{'appearance'}) {
            my $shape = $dashboard->{$key}->{'xdata'}->{'appearance'}->{'shapename'};
            if(defined $shapes && $shape && !exists $shapes->{$shape}) {
                if(-e $c->stash->{'usercontent_folder'}.'/shapes/'.$shape.'.js') {
                    $shapes->{$shape} = scalar read_file($c->stash->{'usercontent_folder'}.'/shapes/'.$shape.'.js');
                } else {
                    $shapes->{$shape} = undef;
                }
            }
            if($dashboard->{$key}->{'xdata'}->{'cls'} eq 'TP.DashboardStatusIcon') {
                my $sub = $dashboard->{$key}->{'xdata'}->{'general'}->{'dashboard'};
                if(!defined $open_tabs->{$sub}) {
                    $open_tabs->{$sub} = 1;
                    $add_hidden->{$sub} = 1;
                }
            }
        }
    }
    # add hidden dashboards recursivly
    for my $key (sort keys %{$add_hidden}) {
        _add_initial_dashboard($c, $key, $data, $shapes, $open_tabs);
    }
    return;
}

##########################################################
sub _get_default_tab_xdata {
    my($c) = @_;
    return({
        title           => $c->req->parameters->{'title'} || 'Dashboard',
        refresh         => $c->config->{'refresh_rate'} || 60,
        select_backends => 0,
        backends        => [],
        background      => 'none',
        autohideheader  => 1,
        defaulticonset  => 'default',
        groups          => [],
    });
}

##########################################################
sub _add_json_dashboard_timestamps {
    my($c, $json, $tab) = @_;
    if(!defined $tab && $c->cookie('thruk_panorama_active')) {
        $tab = $c->cookie('thruk_panorama_active')->value;
    }
    if($tab) {
        my $nr = $tab;
        $json->{'dashboard_ts'} = {};
        $nr =~ s/^pantab_//gmx;
        my $file  = $c->{'panorama_etc'}.'/'.$nr.'.tab';
        if($nr == 0 && !-s $file) {
            $file = $c->config->{'plugin_path'}.'/plugins-enabled/panorama/0.tab';
        }
        my @stat = stat($file);
        if(-x $file) {
            my $dashboard = Thruk::Utils::Panorama::load_dashboard($c, $nr);
            if($dashboard->{'ts'}) {
                $json->{'dashboard_ts'}->{$tab} = $dashboard->{'ts'};
            } else {
                $json->{'dashboard_ts'}->{$tab} = $stat[9] if defined $stat[9];
            }
        } else {
            $json->{'dashboard_ts'}->{$tab} = $stat[9] if defined $stat[9];
        }
        my $maintfile  = Thruk::Utils::Panorama::get_maint_file($c, $nr);
        if(-e $maintfile) {
            my $maintenance = Thruk::Utils::IO::json_lock_retrieve($maintfile);
            $json->{'maintenance'}->{$tab} = $maintenance->{'maintenance'};
        } else {
            $json->{'maintenance'}->{$tab} = "";
        }
    }
    return;
}

##########################################################
sub _add_json_pi_detail {
    my($c, $json) = @_;
    $json->{'pi_detail'} = $c->stash->{pi_detail};
    return;
}

##########################################################
sub _add_misc_details {
    my($c, $always, $json) = @_;
    if($always || $c->req->parameters->{'update_proc'}) {
        $c->stats->profile(begin => "_add_misc_details");
        _add_json_dashboard_timestamps($c, $json, $c->req->parameters->{'current_tab'});
        _add_json_pi_detail($c, $json);
        $json->{'server_version'}       = $c->config->{'version'};
        $json->{'server_version'}      .= '~'.$c->config->{'branch'} if $c->config->{'branch'};
        $json->{'server_extra_version'} = $c->config->{'extra_version'};
        $json->{'broadcasts'}           = Thruk::Utils::Broadcast::get_broadcasts($c, undef, undef, 1);
        $c->stats->profile(end => "_add_misc_details");
    }
    elsif($c->req->parameters->{'current_tab'}) {
        _add_json_dashboard_timestamps($c, $json, $c->req->parameters->{'current_tab'});
    }
    return;
}

##########################################################
sub _set_preload_images {
    my($c) = @_;
    my $plugin_dir = $c->config->{'plugin_path'} || $c->config->{home}."/plugins";
    my @images = glob($plugin_dir.'/plugins-enabled/panorama/root/images/*');
    $c->stash->{preload_img} = [];
    for my $i (@images) {
        $i =~ s|^.*/||gmx;
        push @{$c->stash->{preload_img}}, $i;
    }
    return;
}

##########################################################
sub _extract_runtime_data {
    my($dashboard) = @_;
    my $runtime = {};
    for my $tab (keys %{$dashboard}) {
        next unless ref $dashboard->{$tab} eq 'HASH';
        delete $dashboard->{$tab}->{""};
        for my $key (@runtime_keys) {
            if(defined $dashboard->{$tab}->{'xdata'} && defined $dashboard->{$tab}->{'xdata'}->{$key}) {
                $runtime->{$tab}->{$key} = delete $dashboard->{$tab}->{'xdata'}->{$key};
            }
        }
    }
    return($runtime);
}

##########################################################
sub _get_available_fonts {
    my($c) = @_;
    my $fonts = [ 'Arial', 'Comic Sans MS', 'Georgia', 'Helvetica', 'Lucida Console',
                  'Lucida Grande', 'Tahoma', 'Times', 'Times New Roman', 'Trebuchet MS',
                  'Verdana', 'caption', 'cursive', 'fantasy', 'icon', 'menu',
                  'message-box', 'monospace', 'sans-serif', 'serif', 'small-caption',
    ];
    if($c->config->{'Thruk::Plugin::Panorama'}->{'extra_fonts'}) {
        for my $font (@{Thruk::Utils::list($c->config->{'Thruk::Plugin::Panorama'}->{'extra_fonts'})}) {
            my @extra = split/\s*,\s*/mx, $font;
            push @{$fonts}, @extra;
        }
        @{$fonts} = sort(@{$fonts});
    }
    unshift @{$fonts}, 'inherit';
    return($fonts);
}

##########################################################
sub _check_media_permissions {
    my($c, $file) = @_;
    return 1 if $c->stash->{'is_admin'};
    return 1 if $c->check_user_roles('panorama_view_media_manager');

    my $folder = $c->stash->{'usercontent_folder'}.'/';
    $file = Thruk::Utils::IO::realpath($file);

    # user is allowed to change the image if he has write access to all dashboards using this image
    my $dashboards = Thruk::Utils::Panorama::get_dashboard_list($c, 'all', 1);
    for my $d (@{$dashboards}) {
        # we are looking for dashboards without access which use this image,so skip the dashboard we have full access to
        next if Thruk::Utils::Panorama::is_authorized_for_dashboard($c, $d->{'nr'}, $d) >= ACCESS_READWRITE;
        if($d->{'tab'}->{'xdata'}->{'background'}) {
            return if Thruk::Utils::IO::realpath($folder.$d->{'tab'}->{'xdata'}->{'background'}) eq $file;
        }
        for my $key (sort keys %{$d}) {
            if(ref($d->{$key}) eq 'HASH' && $d->{$key}->{'xdata'} && $d->{$key}->{'xdata'}->{'general'} && $d->{$key}->{'xdata'}->{'general'}->{'src'}) {
                return if Thruk::Utils::IO::realpath($folder.$d->{$key}->{'xdata'}->{'general'}->{'src'}) eq $file;
            }
        }
    }

    return 1;
}

##########################################################
sub _append_sort {
    my($param, $default) = @_;
    if(!$param || ref $param ne 'ARRAY') {
        return($default);
    }

    my $others = $default->{'ASC'} || $default->{'DESC'};
    return({
        $param->[1] => [ $param->[0], @{$others} ],
    });
}

##########################################################

1;
