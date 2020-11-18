package Thruk::Config;

use strict;
use warnings;
use Carp qw/confess/;
use Cwd ();
use File::Slurp qw/read_file/;
use Data::Dumper qw/Dumper/;
use POSIX ();
use Storable ();
use Class::Inspector ();

use Thruk::Base ();
use Thruk::Utils::Log qw/:all/;
use Thruk::Utils::IO ();

=head1 NAME

Thruk::Config - Generic Access to Thruks Config

=head1 DESCRIPTION

Generic Access to Thruks Config

=cut

###################################################
# load timing class
#use Thruk::Timer qw/timing_breakpoint/;

######################################

our $VERSION = '2.38';

our $config;
my $project_root = home() or confess('could not determine project_root: '.Dumper(\%INC));
my $branch       = '2';
my $gitbranch    = get_git_name($project_root);
my $filebranch   = $branch || 1;
if($branch) {
    $branch = $branch.'~'.$gitbranch if $gitbranch ne '';
} else {
    $branch = $gitbranch if $gitbranch;
}
confess('got no project_root') unless $project_root;

my $base_defaults = {
    'name'                                  => 'Thruk',
    'version'                               => $VERSION,
    'branch'                                => $branch,
    'released'                              => 'October 27, 2020',
    'hostname'                              => &hostname(),
    'compression_format'                    => 'gzip',
    'ENCODING'                              => 'utf-8',
    'image_path'                            => $project_root.'/root/thruk/images',
    'project_root'                          => $project_root,
    'home'                                  => $project_root,
    'filebranch'                            => $filebranch,
    'default_view'                          => 'TT',
    'base_templates_dir'                    => $project_root.'/templates',
    'cgi.cfg'                               => 'cgi.cfg',
    'bug_email_rcpt'                        => 'bugs@thruk.org',
    'home_link'                             => 'http://www.thruk.org',
    'plugin_registry_url'                   => ['https://api.thruk.org/v1/plugin/list'],
    'cluster_nodes'                         => ['$proto$://$hostname$/$url_prefix$/'],
    'cluster_heartbeat_interval'            => 15,
    'cluster_node_stale_timeout'            => 120,
    'api_keys_enabled'                      => 1,
    'max_api_keys_per_user'                 => 10,
    'mode_file'                             => '0660',
    'mode_dir'                              => '0770',
    'backend_debug'                         => 0,
    'connection_pool_size'                  => undef,
    'product_prefix'                        => 'thruk',
    'maximum_search_boxes'                  => 9,
    'search_long_plugin_output'             => 1,
    'shown_inline_pnp'                      => 1,
    'use_feature_trends'                    => 1,
    'use_wait_feature'                      => 1,
    'wait_timeout'                          => 10,
    'use_curl'                              => $ENV{'THRUK_CURL'} ? 1 : 0,
    'use_frames'                            => 1,
    'navframesize'                          => 172,
    'use_strict_host_authorization'         => 0,
    'make_auth_user_lowercase'              => 0,
    'make_auth_user_uppercase'              => 0,
    'csrf_allowed_hosts'                    => ['127.0.0.1', '::1'],
    'can_submit_commands'                   => 1,
    'group_paging_overview'                 => '*3, 10, 100, all',
    'group_paging_grid'                     => '*5, 10, 50, all',
    'group_paging_summary'                  => '*10, 50, 100, all',
    'default_theme'                         => 'Thruk2',
    'datetime_format'                           => '%Y-%m-%d  %H:%M:%S',
    'datetime_format_long'                  => '%a %b %e %H:%M:%S %Z %Y',
    'datetime_format_today'                 => '%H:%M:%S',
    'datetime_format_log'                   => '%B %d, %Y  %H',
    'datetime_format_trends'                => '%a %b %e %H:%M:%S %Y',
    'title_prefix'                          => '',
    'use_pager'                             => 1,
    'useragentcompat'                       => '',
    'show_notification_number'              => 1,
    'strict_passive_mode'                   => 1,
    'hide_passive_icon'                     => 0,
    'show_full_commandline'                 => 1,
    'show_modified_attributes'              => 1,
    'show_contacts'                         => 1,
    'show_config_edit_buttons'              => 0,
    'show_backends_in_table'                => 0,
    'show_logout_button'                    => 0,
    'commandline_obfuscate_pattern'         => [],
    'backends_with_obj_config'              => {},
    'use_feature_statusmap'                 => 0,
    'use_feature_statuswrl'                 => 0,
    'use_feature_histogram'                 => 0,
    'use_feature_configtool'                => 0,
    'use_feature_recurring_downtime'        => 1,
    'use_feature_bp'                        => 0,
    'use_feature_core_scheduling'           => 0,
    'use_service_description'               => 0,
    'use_bookmark_titles'                   => 0,
    'use_dynamic_titles'                    => 1,
    'use_new_command_box'                   => 1,
    'show_long_plugin_output'               => 'popup',
    'info_popup_event_type'                 => 'onclick',
    'info_popup_options'                    => 'STICKY,CLOSECLICK,HAUTO,MOUSEOFF',
    'cmd_quick_status'                      => {
                'default'                       => 'reschedule next check',
                'reschedule'                    => 1,
                'downtime'                      => 1,
                'comment'                       => 1,
                'acknowledgement'               => 1,
                'active_checks'                 => 1,
                'notifications'                 => 1,
                'eventhandler'                  => 1,
                'submit_result'                 => 1,
                'reset_attributes'              => 1,
    },
    'cmd_defaults'                          => {
                'ahas'                          => 0,
                'broadcast_notification'        => 0,
                'force_check'                   => 0,
                'force_notification'            => 0,
                'send_notification'             => 1,
                'sticky_ack'                    => 1,
                'persistent_comments'           => 1,
                'persistent_ack'                => 0,
                'ptc'                           => 0,
                'use_expire'                    => 0,
                'childoptions'                  => 0,
                'hostserviceoptions'            => 0,
    },
    'command_disabled'                      => [],
    'command_enabled'                       => [],
    'force_sticky_ack'                      => 0,
    'force_send_notification'               => 0,
    'force_persistent_ack'                  => 0,
    'force_persistent_comments'             => 0,
    'downtime_duration'                     => 7200,
    'expire_ack_duration'                   => 86400,
    'show_custom_vars'                      => [],
    'expand_user_macros'                    => ['ALL'],
    'themes_path'                           => './themes',
    'priorities'                            => {
                '5'                             => 'Business Critical',
                '4'                             => 'Top Production',
                '3'                             => 'Production',
                '2'                             => 'Standard',
                '1'                             => 'Testing',
                '0'                             => 'Development',
    },
    'no_external_job_forks'                 => 0,
    'host_action_icon'                      => 'action.gif',
    'service_action_icon'                   => 'action.gif',
    'thruk_bin'                             => -f 'script/thruk' ? 'script/thruk' : '/usr/bin/thruk',
    'thruk_init'                            => '/etc/init.d/thruk',
    'thruk_shell'                           => '/bin/bash -l -c',
    'first_day_of_week'                     => 0,
    'weekdays'                              => {
                '0'                             => 'Sunday',
                '1'                             => 'Monday',
                '2'                             => 'Tuesday',
                '3'                             => 'Wednesday',
                '4'                             => 'Thursday',
                '5'                             => 'Friday',
                '6'                             => 'Saturday',
                '7'                             => 'Sunday',
    },
    'mobile_agent'                          => 'iPhone,Android,IEMobile',
    'show_error_reports'                    => 'both',
    'skip_js_errors'                        => [ 'cluetip is not a function', 'sprite._defaults is undefined' ],
    'cookie_auth_restricted_url'            => 'http://localhost/thruk/cgi-bin/restricted.cgi',
    'cookie_auth_session_timeout'           => 86400,
    'cookie_auth_session_cache_timeout'     => 5,
    'cookie_auth_domain'                    => '',
    'perf_bar_mode'                         => 'match',
    'sitepanel'                             => 'auto',
    'ssl_verify_hostnames'                  => 1,
    'plugin_templates_paths'                => [],
    'precompile_templates'                  => 0,
    'report_use_temp_files'                 => 14,
    'report_max_objects'                    => 1000,
    'report_include_class2'                 => 1,
    'report_update_logcache'                => 1,
    'perf_bar_pnp_popup'                    => 1,
    'status_color_background'               => 0,
    'apache_status'                         => {},
    'disable_user_password_change'          => 0,
    'user_password_min_length'              => 5,
    'grafana_default_panelId'               => 1,
    'graph_replace'                         => ['s/[^\w\-]/_/gmx'],
    'http_backend_reverse_proxy'            => 1,
    'logcache_delta_updates'                => 0,
    'logcache_clean_duration'               => '2y',
    'logcache_compact_duration'             => '10w',
    'slow_page_log_threshold'               => 15,
    'audit_logs'                            => {
                'login'                         => 1,
                'logout'                        => 1,
                'session'                       => 0,
                'external_command'              => 1,
                'configtool'                    => 1,
    },
    'resource_file'                         => [],
    'default_state_order'                   => 'down, unreachable,'
                                              .'unknown, critical, warning,'
                                              .'acknowledged_down, acknowledged_unreachable,'
                                              .'acknowledged_unknown, acknowledged_critical, acknowledged_warning,'
                                              .'downtime_down, downtime_unreachable,'
                                              .'downtime_unknown, downtime_critical, downtime_warning, downtime_up, downtime_ok,'
                                              .'up, ok, downtime_pending, pending',
    'basic_auth_enabled'                    => 1,
    'auth_oauth'                            => {
                'provider'                      => [],
    },
    'uri_filter'     => {
                'bookmark'                      => undef,
                'referer'                       => undef,
                'reload_nav'                    => undef,
                'update.y'                      => undef,
                'update.x'                      => undef,
                'scrollTo'                      => undef,
                'autoShow'                      => undef,
                '_'                             => undef,
    },
    'physical_logo_path'                    => [],
    'all_in_one_javascript'                 => [
                'vendor/jquery-3.5.1.min.js',
                'javascript/thruk-'.$VERSION.'-'.$filebranch.'.js',
                'vendor/daterangepicker-3.0.5/moment.min.js',
                'vendor/daterangepicker-3.0.5/daterangepicker.js',
                'vendor/overlib-4.21.js',
                'vendor/strftime-min-1.3.js',
                'vendor/bestiejs-1.3.5/platform.js',
    ],
    'all_in_one_css_frames'                 => {
                'Thruk' => [
                    'thruk_global.css',
                    'Thruk.css',
                ],
                'Thruk2' => [
                    'thruk_global.css',
                    'Thruk2.css',
                ],
    },
    'all_in_one_css_noframes'               => {
                'Thruk' => [
                    'thruk_global.css',
                    'thruk_noframes.css',
                    'Thruk.css',
                ],
                'Thruk2' => [
                    'thruk_global.css',
                    'thruk_noframes.css',
                    'Thruk2.css',
                ],
    },
    'jquery_ui'                             => '1.12.1',
    'all_in_one_javascript_panorama'        => [
                'vendor/jquery-3.5.1.min.js',
                'javascript/thruk-'.$VERSION.'-'.$filebranch.'.js',
                'vendor/extjs_ux/form/MultiSelect.js',
                'vendor/extjs_ux/form/ItemSelector.js',
                'vendor/extjs_ux/chart/series/KPIGauge.js',
                'vendor/sprintf-ef8258f.js',
                'vendor/bigscreen-2.0.4.js',
                'vendor/overlib-4.21.js',
                'vendor/strftime-min-1.3.js',
                'vendor/bestiejs-1.3.5/platform.js',
                'vendor/openlayer-2.13.1/OpenLayers-2.13.1.js',
                'vendor/geoext2-2.0.2/src/GeoExt/Version.js',
                'vendor/geoext2-2.0.2/src/GeoExt/data/LayerModel.js',
                'vendor/geoext2-2.0.2/src/GeoExt/data/LayerStore.js',
                'vendor/geoext2-2.0.2/src/GeoExt/panel/Map.js',
    ],
};

# set TT strict mode only for authors
$base_defaults->{'thruk_author'} = 0;
$base_defaults->{'demo_mode'}   = (-f $project_root."/.demo_mode" || $ENV{'THRUK_DEMO_MODE'}) ? 1 : 0;
if(-f $project_root."/.author" || $ENV{'THRUK_AUTHOR'}) {
    $base_defaults->{'thruk_author'} = 1;
}
$config = set_config_env();

######################################

=head1 METHODS

=head2 get_default_stash

    return default stash

=cut
sub get_default_stash {
    my($c, $pre) = @_;
    my $stash = {
        'total_backend_waited'      => 0,
        'total_render_waited'       => 0,
        'inject_stats'              => 1,
        'user_profiling'            => 0,
        'real_page'                 => '',
        'make_test_mode'            => Thruk::Base->mode eq 'TEST' ? 1 : 0,
        'version'                   => $VERSION,
        'branch'                    => $branch,
        'filebranch'                => $filebranch,
        'starttime'                 => time(),
        'omd_site'                  => $ENV{'OMD_SITE'} || '',
        'stacktrace'                => '',
        'backends'                  => [],
        'backend_detail'            => {},
        'pi_detail'                 => {},
        'param_backend'             => '',
        'initial_backends'          => {},
        'refresh_rate'              => 0,
        'auto_reload_fn'            => '',
        'page'                      => '',
        'title'                     => '',
        'extrahtmlclass'            => '',
        'extrabodyclass'            => '',
        'remote_user'               => '?',
        'infoBoxTitle'              => '',
        'has_proc_info'             => 0,
        'has_expire_acks'           => 0,
        'no_auto_reload'            => 0,
        'die_on_errors'             => 0,        # used in cmd.cgi
        'errorMessage'              => 0,        # used in errors
        'errorDetails'              => '',       # used in errors
        'js'                        => [],       # used in _header.tt
        'css'                       => [],       # used in _header.tt
        'extra_header'              => '',       # used in _header.tt
        'ssi_header'                => '',       # used in _header.tt
        'ssi_footer'                => '',       # used in _header.tt
        'original_url'              => '',       # used in _header.tt
        'paneprefix'                => 'dfl_',   # used in _status_filter.tt
        'sortprefix'                => '',       # used in _status_detail_table.tt / _status_hostdetail_table.tt
        'show_form'                 => '1',      # used in _status_filter.tt
        'show_top_pane'             => 0,        # used in _header.tt on status pages
        'body_class'                => '',       # used in _conf_bare.tt on config pages
        'thruk_verbose'             => $ENV{'THRUK_VERBOSE'} // 0,
        'all_in_one_css'            => 0,
        'hide_backends_chooser'     => 0,
        'show_sitepanel'            => 'off',
        'sites'                     => [],
        'backend_chooser'           => 'select',
        'enable_shinken_features'   => 0,
        'disable_backspace'         => 0,
        'server_timezone'           => '',
        'default_user_timezone'     => 'Server Setting',
        'play_sounds'               => 0,
        'menu_states'               => {},
        'cookie_auth'               => 0,
        'space'                     => ' ',
        'debug_info'                => '',
        'bodyonload'                => 1,
        'show_home_button'          => "",
        'has_jquery_ui'             => 0,
        'physical_logo_path'        => [],
        'fav_counter'               => 0,
    };
    $stash = {%{$pre}, %{$stash}};
    return($stash);
}

######################################

=head2 set_config_env

return basic config hash and sets environment

=cut
sub set_config_env {
    my @files = @_;

    my $configs = _load_config_files(\@files);
    my $conf    = Storable::dclone($base_defaults);

    ###################################################
    # merge files into defaults, use backends from base config unless specified in local configs
    my $base_backends;
    for my $cfg (@{$configs}) {
        my $file = $cfg->[0];
        merge_sub_config($conf, $cfg->[1]);
        if($file =~ m/\Qthruk.conf\E$/mx) {
            $base_backends = delete $conf->{'Thruk::Backend'};
            $conf->{'Thruk::Backend'} = {};
        }
    }
    $conf->{'Thruk::Backend'} = $base_backends unless($conf->{'Thruk::Backend'} && scalar keys %{$conf->{'Thruk::Backend'}} > 0);

    ## no critic
    if($conf->{'thruk_verbose'}) {
        if(!$ENV{'THRUK_VERBOSE'} || $ENV{'THRUK_VERBOSE'} < $conf->{'thruk_verbose'}) {
            $ENV{'THRUK_VERBOSE'} = $conf->{'thruk_verbose'};
        }
    }
    ## use critic

    $conf = set_default_config($conf);
    $config = $conf;
    return($conf);
}

######################################

=head2 set_default_config

return basic config hash and sets environment, but does not read config again

=cut
sub set_default_config {
    my($config) = @_;

    ###################################################
    # normalize lists / scalars and set defaults
    for my $key (keys %{$base_defaults}) {
        $config->{$key} = $base_defaults->{$key} unless exists $config->{$key};

        # convert lists to scalars if the default is a scalar value
        if(ref $base_defaults->{$key} eq "" && ref $config->{$key} eq "ARRAY") {
            my $l = scalar (@{$config->{$key}});
            $config->{$key} = $config->{$key}->[$l-1];
        }

        # convert scalars to lists if the default is a list
        if(ref $base_defaults->{$key} eq "ARRAY" && ref $config->{$key} ne "ARRAY") {
            $config->{$key} = [$config->{$key}];
        }
    }

    # ensure comma separated lists
    for my $key (qw/csrf_allowed_hosts show_custom_vars/) {
        $config->{$key} = _comma_separated_list($config->{$key});
    }

    ###################################################
    # set var dir
    $config->{'var_path'} = $config->{'home'}.'/var' unless defined $config->{'var_path'};
    $config->{'var_path'} =~ s|/$||mx;

    if(!defined $config->{'etc_path'}) {
        if($ENV{'THRUK_CONFIG'}) {
            $config->{'etc_path'} = $ENV{'THRUK_CONFIG'};
        } else {
            $config->{'etc_path'} = $config->{'home'};
        }
    }
    $config->{'etc_path'} =~ s|/$||mx;

    ###################################################
    # switch user when running as root
    my $var_path = $config->{'var_path'} or die("no var path!");
    if($> != 0 && !-d ($var_path.'/.')) { CORE::mkdir($var_path); }
    die("'".$var_path."/.' does not exist, make sure it exists and has proper user/groups/permissions") unless -d ($var_path.'/.');
    my($uid, $groups) = get_user($var_path);
    ## no critic
    $ENV{'THRUK_USER_ID'}  = $config->{'thruk_user'}  || $uid;
    $ENV{'THRUK_GROUP_ID'} = $config->{'thruk_group'} || $groups->[0];

    if($ENV{'THRUK_USER_ID'} !~ m/^\d+$/mx) {
        $ENV{'THRUK_USER_ID'}  = (getpwnam($ENV{'THRUK_USER_ID'}))[2]  || die("cannot convert '".$ENV{'THRUK_USER_ID'}."' into numerical uid. Does this user really exist?");
    }
    if($ENV{'THRUK_GROUP_ID'} !~ m/^\d+$/mx) {
        $ENV{'THRUK_GROUP_ID'} = (getgrnam($ENV{'THRUK_GROUP_ID'}))[2] || die("cannot convert '".$ENV{'THRUK_GROUP_ID'}."' into numerical uid. Does this group really exist?");
    }

    $ENV{'THRUK_GROUPS'}   = join(';', @{$groups});
    ## use critic

    if(Thruk::Base->mode eq 'CLI') {
        if(defined $uid and $> == 0) {
            switch_user($uid, $groups);
            _fatal("re-exec with uid $uid did not work");
        }
    }

    # must only be done once
    unless($config->{'url_prefix_fixed'}) {
        $config->{'url_prefix'} = exists $config->{'url_prefix'} ? $config->{'url_prefix'} : '';
        $config->{'url_prefix'} =~ s|/+$||mx;
        $config->{'url_prefix'} =~ s|^/+||mx;
        $config->{'product_prefix'} = $config->{'product_prefix'} || 'thruk';
        $config->{'product_prefix'} =~ s|^/+||mx;
        $config->{'product_prefix'} =~ s|/+$||mx;
        $config->{'url_prefix'} = '/'.$config->{'url_prefix'}.'/'.$config->{'product_prefix'}.'/';
        $config->{'url_prefix'} =~ s|/+|/|gmx;
        $config->{'url_prefix_fixed'} = 1;
    }

    $config->{'start_page'}            = $config->{'url_prefix'}.'main.html' unless defined $config->{'start_page'};
    $config->{'documentation_link'}    = $config->{'url_prefix'}.'docs/index.html' unless defined $config->{'documentation_link'};
    $config->{'all_problems_link'}     = $config->{'url_prefix'}.'cgi-bin/status.cgi?style=combined&hst_s0_hoststatustypes=4&hst_s0_servicestatustypes=31&hst_s0_hostprops=10&hst_s0_serviceprops=0&svc_s0_hoststatustypes=3&svc_s0_servicestatustypes=28&svc_s0_hostprops=10&svc_s0_serviceprops=10&svc_s0_hostprop=2&svc_s0_hostprop=8&title=All+Unhandled+Problems' unless defined $config->{'all_problems_link'};
    $config->{'cookie_auth_login_url'} = $config->{'url_prefix'}.'cgi-bin/login.cgi' unless defined $config->{'cookie_auth_login_url'};

    $config->{'cookie_path'} = $config->{'cookie_path'} // $config->{'url_prefix'};
    my $product_prefix       = $config->{'product_prefix'};
    $config->{'cookie_path'} =~ s/\/\Q$product_prefix\E\/*$//mx;
    $config->{'cookie_path'} = '/'.$product_prefix if $config->{'cookie_path'} eq '';
    $config->{'cookie_path'} =~ s|/*$||mx; # remove trailing slash, chrome doesn't seem to like them
    $config->{'cookie_path'} = $config->{'cookie_path'}.'/'; # seems like the above comment is not valid anymore and chrome now requires the trailing slash

    if(defined $ENV{'OMD_ROOT'} and -s $ENV{'OMD_ROOT'}."/version") {
        my $omdlink = readlink($ENV{'OMD_ROOT'}."/version");
        $omdlink    =~ s/.*?\///gmx;
        $omdlink    =~ s/^(\d+)\.(\d+).(\d{4})(\d{2})(\d{2})/$1.$2~$3-$4-$5/gmx; # nicer snapshots
        $config->{'extra_version'}      = 'OMD '.$omdlink;
        $config->{'extra_version_link'} = 'http://www.omdistro.org';
    }
    elsif($config->{'project_root'} && -s $config->{'project_root'}.'/naemon-version') {
        $config->{'extra_version'}      = read_file($config->{'project_root'}.'/naemon-version');
        $config->{'extra_version_link'} = 'http://www.naemon.org';
        chomp($config->{'extra_version'});
    }
    $config->{'extra_version'}      = '' unless defined $config->{'extra_version'};
    $config->{'extra_version_link'} = '' unless defined $config->{'extra_version_link'};

    # external jobs can be disabled by env
    # don't disable for CLI, breaks config reload over http somehow
    if(defined $ENV{'NO_EXTERNAL_JOBS'} || Thruk::Base->mode eq 'SCRIPTS') {
        $config->{'no_external_job_forks'} = 1;
    }

    ###################################################
    # get installed plugins
    $config->{'plugin_path'} = $config->{home}.'/plugins' unless defined $config->{'plugin_path'};
    my $plugin_dir = $config->{'plugin_path'};
    $plugin_dir = $plugin_dir.'/plugins-enabled/*/';

    _debug2("using plugins: ".$plugin_dir);

    for my $addon (glob($plugin_dir)) {

        my $addon_name = $addon;
        $addon_name =~ s/\/+$//gmx;
        $addon_name =~ s/^.*\///gmx;

        # does the plugin directory exist? (only when running as normal user)
        if($> != 0 && ! -d $config->{home}.'/root/thruk/plugins/' && -w $config->{home}.'/root/thruk' ) {
            CORE::mkdir($config->{home}.'/root/thruk/plugins');
        }

        _trace("loading plugin: ".$addon_name);

        # lib directory included?
        if(-d $addon.'lib') {
            _trace(" -> lib");
            unshift(@INC, $addon.'lib');
        }

        # template directory included?
        if(-d $addon.'templates') {
            _trace(" -> templates");
            push @{$config->{plugin_templates_paths}}, $addon.'templates';
        }
    }

    ###################################################
    # get installed / enabled themes
    my $themes_dir = $config->{'themes_path'} || $config->{home}."/themes";
    $themes_dir = $themes_dir.'/themes-enabled/*/';

    my @themes;
    for my $theme (sort glob($themes_dir)) {
        $theme =~ s/\/$//gmx;
        $theme =~ s/^.*\///gmx;
        _trace("theme -> ".$theme);
        push @themes, $theme;
    }

    _debug2("using themes: ".$themes_dir);

    $config->{'themes'} = \@themes;

    ###################################################
    # use uid to make tmp dir more uniq
    $config->{'tmp_path'} = '/tmp/thruk_'.$> unless defined $config->{'tmp_path'};
    $config->{'tmp_path'} =~ s|/$||mx;

    $config->{'ssi_path'} = $config->{'ssi_path'} || $config->{etc_path}.'/ssi';

    ###################################################
    # make a nice path
    for my $key (qw/tmp_path var_path etc_path ssi_path/) {
        $config->{$key} =~ s/\/$//mx if $config->{$key};
    }

    ###################################################
    # when using lmd, some settings don't make sense
    if($config->{'use_lmd_core'}) {
        $config->{'connection_pool_size'} = 1; # no pool required when using caching
        $config->{'check_local_states'}   = 0; # local state checking not required
    }

    # make this setting available in env
    ## no critic
    $ENV{'THRUK_CURL'} = $ENV{'THRUK_CURL'} || $config->{'use_curl'} || 0;
    ## use critic

    if($config->{'action_menu_apply'}) {
        for my $menu (keys %{$config->{'action_menu_apply'}}) {
            for my $pattern (ref $config->{'action_menu_apply'}->{$menu} eq 'ARRAY' ? @{$config->{'action_menu_apply'}->{$menu}} : ($config->{'action_menu_apply'}->{$menu})) {
                if($pattern !~ m/;/mx) {
                    $pattern .= '.*;$';
                }
            }
        }
    }

    ###################################################
    # expand expand_user_macros
    my $new_expand_user_macros = [];
    if(defined $config->{'expand_user_macros'}) {
        for my $item (ref $config->{'expand_user_macros'} eq 'ARRAY' ? @{$config->{'expand_user_macros'}} : ($config->{'expand_user_macros'})) {
            next unless $item;
            if($item =~ m/^USER([\d\-]+$)/mx) {
                my $list = expand_numeric_list($1);
                for my $nr (@{$list}) {
                    push @{$new_expand_user_macros}, 'USER'.$nr;
                }
            } else {
                push @{$new_expand_user_macros}, $item;
            }
        }
        $config->{'expand_user_macros'} = $new_expand_user_macros;
    }

    # expand action_menu_items_folder
    my $action_menu_items_folder = $config->{'action_menu_items_folder'} || $config->{etc_path}."/action_menus";
    for my $folder (@{list($action_menu_items_folder)}) {
        next unless -d $folder.'/.';
        my @files = glob($folder.'/*');
        for my $file (@files) {
            if($file =~ m%([^/]+)\.(json|js)$%mx) {
                my $basename = $1;
                $config->{'action_menu_items'}->{$basename} = 'file://'.$file;
            }
        }
    }

    # normalize oauth provider
    if(ref $config->{'auth_oauth'}->{'provider'} eq 'HASH') { $config->{'auth_oauth'}->{'provider'} = [$config->{'auth_oauth'}->{'provider'}]}
    for my $p (@{$config->{'auth_oauth'}->{'provider'}}) {
        # named provider
        if(scalar keys %{$p} == 1) {
            my $name = (keys %{$p})[0];
            $p = $p->{$name};
            $p->{'id'} = $name;
        } else {
            $p->{'id'} = "oauth";
        }
    }

    # enable OMD tweaks
    if($ENV{'OMD_ROOT'}) {
        my $site = $ENV{'OMD_SITE'};
        my $root = $ENV{'OMD_ROOT'};
        my $site_config = _parse_omd_site_config($root."/etc/omd/site.conf");
        my $siteport    = $site_config->{'CONFIG_APACHE_TCP_PORT'};
        my $ssl         = $site_config->{'CONFIG_APACHE_MODE'};
        my $proto     = $ssl eq 'ssl' ? 'https' : 'http';
        $config->{'omd_local_site_url'} = sprintf("%s://%s:%d/%s", $proto, "127.0.0.1", $siteport, $site);
        # bypass system reverse proxy for restricted cgi for permormance and locking reasons
        if($config->{'cookie_auth_restricted_url'} && $config->{'cookie_auth_restricted_url'} =~ m|^https?://localhost/$site/thruk/cgi\-bin/restricted\.cgi$|mx) {
            $config->{'cookie_auth_restricted_url'} = $config->{'omd_local_site_url'}.'/thruk/cgi-bin/restricted.cgi';
        }
        if(scalar keys %{$config->{'apache_status'}} == 0) {
            $config->{'apache_status'} = {
                'Site'   => $proto.'://127.0.0.1:'.$siteport.'/server-status',
                'System' => $proto.'://127.0.0.1/server-status',
            };
        }
        $config->{'omd_apache_proto'} = $proto;
    }

    return $config;
}

######################################
sub _load_config_files {
    my($files) = @_;

    # read/load config files
    my @local_files;
    my @base_files;
    if(scalar @{$files} == 0) {
        for my $path ($ENV{'THRUK_CONFIG'}, '.') {
            next unless defined $path;
            push @base_files, $path.'/thruk.conf' if -f $path.'/thruk.conf';
            if(-d $path.'/thruk_local.d') {
                my @tmpfiles = sort glob($path.'/thruk_local.d/*');
                for my $tmpfile (@tmpfiles) {
                    my $ext;
                    if($tmpfile =~ m/\.([^.]+)$/mx) { $ext = $1; }
                    if(!$ext) {
                        _debug2("skipped config file: ".$tmpfile.", file has no extension, please use either cfg, conf or the hostname");
                        next;
                    }
                    if($ext ne 'conf' && $ext ne 'cfg') {
                        # only read if the extension matches the hostname
                        my $hostname = &hostname;
                        if($tmpfile !~ m/\Q$hostname\E$/mx) {
                            _debug2("skipped config file: ".$tmpfile.", file does not end with our hostname '$hostname'");
                            next;
                        }
                    }
                    push @local_files, $tmpfile;
                }
            }
            push @local_files, $path.'/thruk_local.conf' if -f $path.'/thruk_local.conf';
            last if scalar @base_files > 0;
        }
    }

    my $cfg = [];
    for my $f (@{$files}, @base_files) {
        push @{$cfg}, [$f, _fixup_config(read_config_file($f))];
    }
    push @{$cfg}, ['thruk_local.conf', _fixup_config(read_config_file(\@local_files))];

    return $cfg;
}

######################################

=head2 get_base_config

return base config

=cut
sub get_base_config {
    return($base_defaults);
}

######################################

=head2 get_toolkit_config

return template toolkit config

=cut
sub get_toolkit_config {
    require Thruk::Utils::Filter;
    require Thruk::Utils::Broadcast;

    my $view_tt_settings = {
        'TEMPLATE_EXTENSION'                    => '.tt',
        'ENCODING'                              => 'utf-8',
        'INCLUDE_PATH'                          => $project_root.'/templates', # will be overwritten during render
        'COMPILE_DIR'                           => $config->{'tmp_path'}.'/ttc_'.$>,
        'RECURSION'                             => 1,
        'PRE_CHOMP'                             => 0,
        'POST_CHOMP'                            => 0,
        'TRIM'                                  => 0,
        'COMPILE_EXT'                           => '.ttc',
        'STAT_TTL'                              => 604800, # templates do not change in production
        'STRICT'                                => 0,
        'EVAL_PERL'                             => 1,
        'FILTERS'                               => {
                    'duration'                      => \&Thruk::Utils::Filter::duration,
                    'nl2br'                         => \&Thruk::Utils::Filter::nl2br,
                    'strip_command_args'            => \&Thruk::Utils::Filter::strip_command_args,
                    'escape_html'                   => \&Thruk::Utils::Filter::escape_html,
                    'lc'                            => \&Thruk::Utils::Filter::lc,
        },
        'PRE_DEFINE'                            => {
                    # subs from Thruk::Utils::Filter will be added automatically
                    'dump'                          => \&Thruk::Utils::Filter::debug,
                    'get_broadcasts'                => \&Thruk::Utils::Broadcast::get_broadcasts,
                    'command_disabled'              => \&Thruk::Utils::command_disabled,
                    'proxifiy_url'                  => \&Thruk::Utils::proxifiy_url,
                    'get_remote_thruk_url'          => \&Thruk::Utils::get_remote_thruk_url,
                    'basename'                      => \&Thruk::Utils::basename,
                    'debug_details'                 =>   get_debug_details(),
                    'format_date'                   => \&Thruk::Utils::format_date,
                    'format_cronentry'              => \&Thruk::Utils::format_cronentry,
                    'format_number'                 => \&Thruk::Utils::format_number,
                    'set_favicon_counter'           => \&Thruk::Utils::Status::set_favicon_counter,
                    'get_pnp_url'                   => \&Thruk::Utils::get_pnp_url,
                    'get_graph_url'                 => \&Thruk::Utils::get_graph_url,
                    'get_action_url'                => \&Thruk::Utils::get_action_url,
                    'reduce_number'                 => \&Thruk::Utils::reduce_number,
                    'get_custom_vars'               => \&Thruk::Utils::get_custom_vars,
        },
    };

    # export filter functions
    for my $s (@{Class::Inspector->functions('Thruk::Utils::Filter')}) {
        $view_tt_settings->{'PRE_DEFINE'}->{$s} = \&{'Thruk::Utils::Filter::'.$s};
    }

    return($view_tt_settings);
}

##############################################

=head2 get_git_name

  get_git_name()

return git branch name

=cut

sub get_git_name {
    my $project_root = $INC{'Thruk/Config.pm'};
    $project_root =~ s/\/Config\.pm$//gmx;
    return '' unless -d $project_root.'/../../.git';
    my($hash);
    my $dir = Cwd::getcwd;
    chdir($project_root.'/../../');

    # directly on git tag?
    my($rc, $tag) = Thruk::Utils::IO::cmd("git describe --tag --exact-match 2>&1");
    if($tag && $tag =~ m/\Qno tag exactly matches '\E([^']+)'/mx) { $hash = substr($1,0,7); }
    if($rc != 0) { $tag = ''; }
    if($tag) {
        chdir($dir);
        return '';
    }

    my $branch = Thruk::Utils::IO::cmd("git branch --no-color 2>/dev/null");
    if($branch =~ s/^\*\s+(.*)$//mx) { $branch = $1; }
    if(!$hash) {
        $hash = Thruk::Utils::IO::cmd("git log -1 --no-color --pretty=format:%h 2> /dev/null");
    }
    chdir($dir);
    if($branch eq 'master') {
        return $hash;
    }
    return $branch.'.'.$hash;
}

########################################

=head2 get_debug_details

  get_debug_details()

return details useful for debuging

=cut

sub get_debug_details {
    my $uname = join(" ", POSIX::uname());
    my $release = "";
    for my $f (qw|/etc/redhat-release /etc/issue|) {
        if(-e $f) {
            $release = read_file($f);
            last;
        }
    }
    $release =~ s/^\s*//gmx;
    $release =~ s/\\\w//gmx;
    $release =~ s/\s*$//gmx;
    my $details =<<"EOT";
uname:      $uname
release:    $release
EOT
    return $details;
}

######################################

=head2 home

  home()

return home folder

=cut
sub home {
    my($class) = @_;
    $class = 'Thruk::Config' unless $class;
    (my $file = "$class.pm") =~ s{::}{/}gmx;
    if(my $inc_entry = $INC{$file}) {
        $inc_entry = Cwd::abs_path($inc_entry);
        $inc_entry =~ s/\Q\/$file\E$//mx;
        $inc_entry =~ s/\/b?lib//gmx;
        if($inc_entry =~ m#/omd/versions/[^/]*/share/thruk#mx && $ENV{'OMD_ROOT'}) {
            return $ENV{'OMD_ROOT'}.'/share/thruk';
        }
        return $inc_entry;
    }

    # we found nothing
    return 0;
}

########################################

=head2 expand_numeric_list

  expand_numeric_list($txt, $c)

return expanded list.
ex.: converts '3,7-9,15' -> [3,7,8,9,15]

=cut

sub expand_numeric_list {
    my($txt, $c) = @_;
    my $list = {};
    return [] unless defined $txt;

    for my $item (@{list($txt)}) {
        for my $block (split/\s*,\s*/mx, $item) {
            if($block =~ m/(\d+)\s*\-\s*(\d+)/gmx) {
                for my $nr ($1..$2) {
                    $list->{$nr} = 1;
                }
            } elsif($block =~ m/^(\d+)$/gmx) {
                    $list->{$1} = 1;
            } else {
                _error("'$block' is not a valid number or range") if defined $c;
            }
        }
    }

    my @arr = sort keys %{$list};
    return \@arr;
}

########################################

=head2 array2hash

  array2hash($data, [ $key, [ $key2 ]])

create a hash by key

=cut
sub array2hash {
    my $data = shift;
    my $key  = shift;
    my $key2 = shift;

    return {} unless defined $data;
    confess("not an array") unless ref $data eq 'ARRAY';

    my %hash;
    if(defined $key2) {
        for my $d (@{$data}) {
            $hash{$d->{$key}}->{$d->{$key2}} = $d;
        }
    } elsif(defined $key) {
        %hash = map { $_->{$key} => $_ } @{$data};
    } else {
        %hash = map { $_ => $_ } @{$data};
    }

    return \%hash;
}

########################################

=head2 finalize

    restore used specific settings from global hash

=cut

sub finalize {
    my($c) = @_;

    Thruk::Action::AddDefaults::restore_user_backends($c);

    if($Thruk::deprecations_log) {
        if(Thruk::Base->mode ne 'TEST' && Thruk::Base->mode ne 'CLI') {
            for my $warning (@{$Thruk::deprecations_log}) {
                _info($warning);
            }
        }
        undef $Thruk::deprecations_log;
    }

    return;
}

######################################

=head2 get_user

  get_user($from_folder)

return user and groups thruk runs with

=cut
sub get_user {
    # Discover which user we want to be
    my($from_folder) = @_;
    confess($from_folder." ".$!) unless -d $from_folder;
    my @stat = stat $from_folder;
    # This is the user we want to be
    my $uid = $stat[4];
    # This is the current user
    my $cuid = (getpwuid($<))[2];
    # For now just initialize the array
    my @groups = ( );

    # If we are the user we want to be we use getgroups
    # Which is fast and non intrusive against ldap/nis
    if($cuid eq $uid) {
        # Get the grous from getgroups
        my @gids = POSIX::getgroups;
        foreach my $egid (@gids) {
            # Add zero to convert egid to an int like it is in the old function
            push @groups, $egid  + 0;
        }
    }
    # Otherwise we fall back on getgrent which will loop all groups in an intrusive way
    else {
        my($name,$gid) = (getpwuid($uid))[0, 3];
        if($name) {
            @groups = ( $gid );
            while ( my ( $gid, $users ) = ( getgrent )[ 2, -1 ] ) {
                $users =~ /\b$name\b/mx and push @groups, $gid;
            }
        }
    }
    # make sure we have at least one group id
    if(scalar @groups == 0) {
        push @groups, $stat[5];
    }
    return($uid, \@groups);
}

########################################

=head2 list

  list($ref)

return list of ref unless it is already a list

=cut

sub list {
    my($d) = @_;
    return [] unless defined $d;
    return $d if ref $d eq 'ARRAY';
    return([$d]);
}

######################################

=head2 array_uniq

  array_uniq($array)

return uniq elements of array

=cut

sub array_uniq {
    my($array) = @_;

    my %seen = ();
    my @unique = grep { ! $seen{ $_ }++ } @{$array};

    return \@unique;
}

########################################
# splits lists of comma separated values into list
sub _comma_separated_list {
    my($val) = @_;
    $val = [split(/\s*,\s*/mx, join(",", @{list($val)}))];
    return(array_uniq($val));
}

########################################

=head2 read_config_file

  read_config_file($file)

return parsed config file

=cut

sub read_config_file {
    my($files) = @_;
    $files = list($files);
    my $conf = {};
    for my $f (@{$files}) {
        _debug2("reading config file: ".$f);
        # since perl 5.23 sysread on utf-8 handles is deprecated, so we need to open the file manually
        open my $fh, '<:encoding(UTF-8)', $f or die "Can't open '$f' for reading: $!";
        my @rows = <$fh>;
        CORE::close($fh);
        _parse_rows($f, \@rows, $conf);
    }
    return($conf);
}

######################################
sub _parse_rows {
    my($file, $rows, $conf, $cur_line, $until, $until_source) = @_;
    my $lastline = '';
    $cur_line = 0 unless defined $cur_line;
    while(my $line = shift @{$rows}) {
        $cur_line++;
        $line =~ s|(?<!\\)\#.*$||gmxo;
        $line =~ s|^\s+||gmxo;
        $line =~ s|\s+$||gmxo;
        $line =~ s|\\\#|#|gmxo;

        # concatenate by trailing backslash
        if(substr($line, -1, 1) eq '\\' && $line =~ m/^\s*(.*)\s*\\$/mxo) {
            $lastline = $lastline.$1;
            next;
        }
        if($lastline) {
            $line     = $lastline.$line;
            $lastline = '';
        }
        next unless $line;
        return($cur_line) if $until && lc($line) eq $until;

        # nested structures
        if(substr($line,0,1) eq '<') {
            if(substr($line,1,1) eq '/') {
                die(sprintf("unexpected closing block found: '%s' in: %s:%d", $line, $file, $cur_line));
            }
            # named hashes: <item name>
            if($line =~ m|^<(\w+)\s+([^>]+)>|mxo) {
                my($k,$v) = ($1,$2);
                my $next  = {};
                $cur_line = _parse_rows($file, $rows, $next, $cur_line, '</'.lc($k).'>', $file.':'.$cur_line);
                if(!defined $conf->{$k}->{$v}) {
                    $conf->{$k}->{$v} = $next;
                } elsif(ref $conf->{$k}->{$v} eq 'ARRAY') {
                    push @{$conf->{$k}->{$v}}, $next;
                } else {
                    $conf->{$k}->{$v} = [$conf->{$k}->{$v}, $next];
                }
                next;
            }
            # direct hashes: <name>
            if($line =~ m|^<([^>]+)>|mxo) {
                my $k = $1;
                my $next  = {};
                if($k eq 'peer') {
                    $next->{'_FILE'} = $file;
                    $next->{'_LINE'} = $cur_line;
                }
                $cur_line = _parse_rows($file, $rows, $next, $cur_line, '</'.lc($k).'>', $file.':'.$cur_line);
                if(!defined $conf->{$k}) {
                    $conf->{$k} = $next;
                } elsif(ref $conf->{$k} eq 'ARRAY') {
                    push @{$conf->{$k}}, $next;
                } else {
                    # merge top level hashes
                    if(!$until && ref($conf->{$k}) eq 'HASH' && ref($next) eq 'HASH') {
                        $conf->{$k} = { %{$conf->{$k}}, %{$next} };
                    } else {
                        $conf->{$k} = [$conf->{$k}, $next];
                    }
                }
                next;
            }
        }

        # simple key / value pairs
        my($k,$v) = split(/\s*=\s*/mxo, $line, 2);
        if(!defined $v) {
            # try split by space
            ($k,$v) = split(/\s+/mxo, $line, 2);
            if(!defined $v) {
                die("unknow config entry: ".$line." in ".$file.":".$cur_line);
            }
        }
        if(substr($v,0,1) eq '"') {
            $v =~ s|^"(.*)"$|$1|gmxo;
        }
        elsif(substr($v,0,1) eq "'") {
            $v =~ s|^'(.*)'$|$1|gmxo;
        }
        if(!defined $conf->{$k}) {
            $conf->{$k} = $v;
        } elsif(ref $conf->{$k} eq 'ARRAY') {
            push @{$conf->{$k}}, $v;
        } else {
            $conf->{$k} = [$conf->{$k}, $v];
        }
    }
    if($until) {
        my $block = $until;
        $block =~ s/>$//gmx;
        $block =~ s/<\///gmx;
        die(sprintf("unclosed '<%s>' block, started in: %s", $block, $until_source));
    }
    return($cur_line);
}

######################################

=head2 switch_user

  switch_user($uid, $groups)

switch user and groups

=cut

sub switch_user {
    my($uid, $groups) = @_;
    if(scalar @{$groups} > 0) {
        POSIX::setgid($groups->[0]) || confess("setgid failed: ".$!);
        ## no critic
        $) = join(" ", @{$groups});
        $( = $groups->[0];
        ## use critic
    }
    my @cmd = _get_orig_cmd_line();
    _debug("switching to uid: $uid") if $ENV{'THRUK_VERBOSE'};
    POSIX::setuid($uid) || confess("setuid failed: ".$!);
    _debug("re-exec: ".'"'.join('" "', @cmd).'"');
    # clean perl5lib
    if($ENV{'PERL5LIB'}) {
        my @clean;
        for my $lib (split(/:/mx, $ENV{'PERL5LIB'})) {
            next unless -x $lib.'/.';
            next unless -r $lib.'/.';
            push @clean, $lib;
        }
        ## no critic
        $ENV{'PERL5LIB'} = join(':', @clean);
        ## use critic
    }
    exec(@cmd) || confess("exec (".'"'.join('" "', @cmd).'"'.") failed: ".$!);
}

########################################

=head2 read_cgi_cfg

  read_cgi_cfg($app, $config);

parse the cgi.cfg and returns config hash

=cut
sub read_cgi_cfg {
    my($app, $config) = @_;
    $config = $app->config unless defined $config;

    # read only if its changed
    my $file = $config->{'cgi.cfg'};
    if(!defined $file || $file eq '') {
        $app->{'cgi_cfg'} = 'undef';
        $app->log->debug("no cgi.cfg found");
        return;
    }
    elsif( -r $file ) {
        # perfect, file exists and is readable
    }
    elsif(-r $config->{'project_root'}.'/'.$file) {
        $file = $config->{'project_root'}.'/'.$file;
    }
    else {
        $app->log->error("cgi.cfg not readable: ".$!);
        return;
    }

    # (dev,ino,mode,nlink,uid,gid,rdev,size,atime,mtime,ctime,blksize,blocks)
    my @cgi_cfg_stat = stat($file);

    my $last_stat = $app->{'cgi_cfg_stat'};
    if(!defined $last_stat
       || $last_stat->[1] != $cgi_cfg_stat[1] # inode changed
       || $last_stat->[9] != $cgi_cfg_stat[9] # modify time changed
      ) {
        _debug("cgi.cfg has changed, updating...") if defined $last_stat;
        _debug2("reading $file");
        $app->{'cgi_cfg_stat'}      = \@cgi_cfg_stat;
        $app->{'cgi.cfg_effective'} = $file;
        $app->{'cgi_cfg'}           = read_config_file($file);
    }
    return($app->{'cgi_cfg'});
}

########################################

=head2 merge_cgi_cfg

  merge_cgi_cfg($config)

merge entries from cgi.cfg into $c->config

=cut
sub merge_cgi_cfg {
    my($c) = @_;
    my $cfg = read_cgi_cfg($c->app);
    for my $key (sort keys %{$cfg}) {
        $c->config->{$key} = $cfg->{$key};
    }
    return;
}

########################################
# parses omd sites key/value config file
sub _parse_omd_site_config {
    my($file) = @_;
    my $site_config = {};
    for my $line (read_file($file)) {
        if($line =~ m/^(CONFIG_.*?)='([^']*)'$/mx) {
            $site_config->{$1} = $2;
        }
    }
    return($site_config);
}

########################################

=head2 merge_sub_config

  merge_sub_config($base_config, $sub_config)

merge entries from $sub_config into $base_config.

base config will not be cloned are therefore changed.

=cut
sub merge_sub_config {
    my($base, $add) = @_;
    my $config = $base;

    for my $key (keys %{$add}) {
        if($key =~ '^Thruk::Plugin::' && !defined $config->{$key}) {
            $config->{$key} = {};
        }
        if(defined $config->{$key} and ref $config->{$key} eq 'HASH') {
            if($key eq 'Thruk::Backend') {
                # merge all backends
                for my $peer (@{list($add->{$key})}) {
                    $config->{$key}->{'peer'} = [ @{list($config->{$key}->{'peer'})}, @{list($peer->{'peer'})} ];
                }
            }
            elsif($key =~ '^Thruk::Plugin::') {
                if(ref $add->{$key} eq 'ARRAY') {
                    my $hash = {};
                    while(my $add = shift @{$add->{$key}}) {
                        $hash = { %{$hash}, %{$add} };
                    }
                    $add->{$key} = $hash;
                }
                if(ref $add->{$key} ne 'HASH') { confess("tried to merge into hash: ".Dumper({key => $key, from_file => $add->{$key}, base => $config->{$key}})); }
                $config->{$key} = { %{$config->{$key}}, %{$add->{$key}} };
            } else {
                if(ref $add->{$key} ne 'HASH') { confess("tried to merge into hash: ".Dumper({key => $key, from_file => $add->{$key}, base => $config->{$key}})); }
                $config->{$key} = { %{$config->{$key}}, %{$add->{$key}} };
            }
        } else {
            $config->{$key} = $add->{$key};
        }
    }

    return;
}

########################################
# move Component one level up and merge Users/Groups
sub _fixup_config {
    my($config) = @_;
    for my $key (sort keys %{$config->{'Component'}}) {
        $config->{$key} = delete $config->{'Component'}->{$key};
    }
    delete $config->{'Component'};

    for my $type (qw/Group User/) {
        if($config->{$type}) {
            for my $name (keys %{$config->{$type}}) {
                # if its a list of hashes, merge into one hash
                if(ref $config->{$type}->{$name} eq 'ARRAY') {
                    my $data = {};
                    for my $d (@{$config->{$type}->{$name}}) {
                        for my $key (keys %{$d}) {
                            if(!defined $data->{$key}) {
                                $data->{$key} = $d->{$key};
                            }
                            else {
                                if(ref $data->{$key} eq 'ARRAY') {
                                    push @{$data->{$key}}, $d->{$key};
                                } else {
                                    $data->{$key} = [$data->{$key}, $d->{$key}];
                                }
                            }
                        }
                    }
                    $config->{$type}->{$name} = $data;
                }
                for my $key (sort keys %{$config->{$type}->{$name}->{'Component'}}) {
                    $config->{$type}->{$name}->{$key} = delete $config->{$type}->{$name}->{'Component'}->{$key};
                }
                delete $config->{$type}->{$name}->{'Component'};
            }
        }
    }

    return($config);
}

########################################
sub _get_orig_cmd_line {
    # cannot use @ARGV here, because that gets consumed by GetOpt
    local $/ = undef;
    my @cmd;
    open(my $cmd, '<', '/proc/self/cmdline') or die("cannot open /proc/self/cmdline: $!");
    my $cmd_started = 0;
    my @argv = split(/\0+/mx, <$cmd>);
    for my $e (@argv) {
        if($e eq $0) {
            $cmd_started = 1;
        }
        if($cmd_started) {
            push @cmd, $e;
        }
    }
    CORE::close $cmd;
    return($^X, @cmd);
}

##############################################

=head2 hostname

  hostname()

return system hostname

=cut

sub hostname {
    our $hostname;
    return($hostname) if $hostname;
    chomp($hostname = Thruk::Utils::IO::cmd("hostname"));
    return($hostname);
}

##############################################

=head2 get_thruk_version

  get_thruk_version()

return full thruk version string, ex.: 2.38-2~feature_branch.45a4ceb

=cut

sub get_thruk_version {
    if($branch) {
        return($VERSION.'-'.$branch);
    }
    return($VERSION);
}

########################################

=head2 version

  version()

return version string, ex.: 2.38-2

=cut
sub version {
    return(sprintf("%s-%s", $VERSION, $filebranch));
}

########################################

1;
