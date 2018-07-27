package Thruk::Config;

use strict;
use warnings;
use Carp qw/confess/;
use Cwd ();
use File::Slurp qw/read_file/;
use Data::Dumper qw/Dumper/;
use POSIX ();
use Thruk::Utils::Filter ();
use Thruk::Utils::Broadcast ();

=head1 NAME

Thruk::Config - Generic Access to Thruks Config

=head1 DESCRIPTION

Generic Access to Thruks Config

=cut

###################################################
# load timing class
BEGIN {
    #use Thruk::Timer qw/timing_breakpoint/;
}

######################################

our $VERSION = '2.22';

my $project_root = home('Thruk::Config') or confess('could not determine project_root: '.Dumper(\%INC));
my $branch       = '';
my $gitbranch    = get_git_name($project_root);
my $filebranch   = $branch || 1;
if($branch) {
    $branch = $branch.'~'.$gitbranch if $gitbranch ne '';
} else {
    $branch = $gitbranch if $gitbranch;
}
confess('got no project_root') unless $project_root;
## no critic
$ENV{'THRUK_SRC'} = 'UNKNOWN' unless defined $ENV{'THRUK_SRC'};
## use critic
our %config = ('name'                   => 'Thruk',
              'version'                => $VERSION,
              'branch'                 => $branch,
              'released'               => 'June 29, 2018',
              'compression_format'     => 'gzip',
              'ENCODING'               => 'utf-8',
              'image_path'             => $project_root.'/root/thruk/images',
              'project_root'           => $project_root,
              'home'                   => $project_root,
              'default_view'           => 'TT',
              'View::TT'               => {
                  TEMPLATE_EXTENSION => '.tt',
                  ENCODING           => 'utf-8',
                  INCLUDE_PATH       => $project_root.'/templates',
                  RECURSION          => 1,
                  FILTERS            => {
                                          'duration'            => \&Thruk::Utils::Filter::duration,
                                          'nl2br'               => \&Thruk::Utils::Filter::nl2br,
                                          'strip_command_args'  => \&Thruk::Utils::Filter::strip_command_args,
                                          'escape_html'         => \&Thruk::Utils::Filter::escape_html,
                                          'lc'                  => \&Thruk::Utils::Filter::lc,
                                      },
                  PRE_DEFINE         => {
                                          'sprintf'             => \&Thruk::Utils::Filter::sprintf,
                                          'duration'            => \&Thruk::Utils::Filter::duration,
                                          'name2id'             => \&Thruk::Utils::Filter::name2id,
                                          'as_url_arg'          => \&Thruk::Utils::Filter::as_url_arg,
                                          'uri'                 => \&Thruk::Utils::Filter::uri,
                                          'full_uri'            => \&Thruk::Utils::Filter::full_uri,
                                          'short_uri'           => \&Thruk::Utils::Filter::short_uri,
                                          'uri_with'            => \&Thruk::Utils::Filter::uri_with,
                                          'clean_referer'       => \&Thruk::Utils::Filter::clean_referer,
                                          'escape_html'         => \&Thruk::Utils::Filter::escape_html,
                                          'escape_xml'          => \&Thruk::Utils::Filter::escape_xml,
                                          'escape_js'           => \&Thruk::Utils::Filter::escape_js,
                                          'escape_quotes'       => \&Thruk::Utils::Filter::escape_quotes,
                                          'escape_ampersand'    => \&Thruk::Utils::Filter::escape_ampersand,
                                          'escape_bslash'       => \&Thruk::Utils::Filter::escape_bslash,
                                          'escape_regex'        => \&Thruk::Utils::Filter::escape_regex,
                                          'get_message'         => \&Thruk::Utils::Filter::get_message,
                                          'throw'               => \&Thruk::Utils::Filter::throw,
                                          'contains'            => \&Thruk::Utils::Filter::contains,
                                          'date_format'         => \&Thruk::Utils::Filter::date_format,
                                          'last_check'          => \&Thruk::Utils::Filter::last_check,
                                          'remove_html_comments' => \&Thruk::Utils::Filter::remove_html_comments,
                                          'format_date'         => \&Thruk::Utils::format_date,
                                          'format_cronentry'    => \&Thruk::Utils::format_cronentry,
                                          'format_number'       => \&Thruk::Utils::format_number,
                                          'nl2br'               => \&Thruk::Utils::Filter::nl2br,
                                          'action_icon'         => \&Thruk::Utils::Filter::action_icon,
                                          'logline_icon'        => \&Thruk::Utils::Filter::logline_icon,
                                          'json_encode'         => \&Thruk::Utils::Filter::json_encode,
                                          'encode_json_obj'     => \&Thruk::Utils::Filter::encode_json_obj,
                                          'get_user_token'      => \&Thruk::Utils::Filter::get_user_token,
                                          'uniqnumber'          => \&Thruk::Utils::Filter::uniqnumber,
                                          'replace_macros'      => \&Thruk::Utils::Filter::replace_macros,
                                          'set_time_locale'     => \&Thruk::Utils::Filter::set_time_locale,
                                          'calculate_first_notification_delay_remaining' => \&Thruk::Utils::Filter::calculate_first_notification_delay_remaining,
                                          'has_business_process' => \&Thruk::Utils::Filter::has_business_process,
                                          'set_favicon_counter' => \&Thruk::Utils::Status::set_favicon_counter,
                                          'get_pnp_url'         => \&Thruk::Utils::get_pnp_url,
                                          'get_graph_url'       => \&Thruk::Utils::get_graph_url,
                                          'get_action_url'       => \&Thruk::Utils::get_action_url,
                                          'make_test_mode'      => $ENV{'THRUK_SRC'} eq 'TEST' ? 1 : 0,
                                          'button'              => \&Thruk::Utils::Filter::button,
                                          'fullversion'         => \&Thruk::Utils::Filter::fullversion,
                                          'reduce_number'       => \&Thruk::Utils::reduce_number,
                                          'split_perfdata'      => \&Thruk::Utils::Filter::split_perfdata,
                                          'get_custom_vars'     => \&Thruk::Utils::get_custom_vars,
                                          'validate_json'       => \&Thruk::Utils::Filter::validate_json,
                                          'get_action_menu'     => \&Thruk::Utils::Filter::get_action_menu,
                                          'get_cmd_submit_hash' => \&Thruk::Utils::Filter::get_cmd_submit_hash,
                                          'get_broadcasts'      => \&Thruk::Utils::Broadcast::get_broadcasts,
                                          'command_disabled'    => \&Thruk::Utils::command_disabled,

                                          'version'        => $VERSION,
                                          'branch'         => $branch,
                                          'filebranch'     => $filebranch,
                                          'starttime'      => time(),
                                          'debug_details'  => get_debug_details(),
                                          'omd_site'       => $ENV{'OMD_SITE'} || '',
                                          'stacktrace'     => '',
                                          'backends'       => [],
                                          'backend_detail' => {},
                                          'pi_detail'      => {},
                                          'param_backend'  => '',
                                          'initial_backends' => {},
                                          'refresh_rate'   => '',
                                          'auto_reload_fn' => '',
                                          'page'           => '',
                                          'title'          => '',
                                          'extrabodyclass' => '',
                                          'remote_user'    => '?',
                                          'infoBoxTitle'   => '',
                                          'has_proc_info'  => 0,
                                          'has_expire_acks'=> 0,
                                          'no_auto_reload' => 0,
                                          'die_on_errors'  => 0,        # used in cmd.cgi
                                          'errorMessage'   => 0,        # used in errors
                                          'errorDetails'   => '',       # used in errors
                                          'js'             => [],       # used in _header.tt
                                          'css'            => [],       # used in _header.tt
                                          'extra_header'   => '',       # used in _header.tt
                                          'ssi_header'     => '',       # used in _header.tt
                                          'ssi_footer'     => '',       # used in _header.tt
                                          'original_url'   => '',       # used in _header.tt
                                          'paneprefix'     => 'dfl_',   # used in _status_filter.tt
                                          'sortprefix'     => '',       # used in _status_detail_table.tt / _status_hostdetail_table.tt
                                          'show_form'      => '1',      # used in _status_filter.tt
                                          'show_top_pane'  => 0,        # used in _header.tt on status pages
                                          'body_class'     => '',       # used in _conf_bare.tt on config pages
                                          'thruk_debug'    => 0,
                                          'panorama_debug' => 0,
                                          'all_in_one_css' => 0,
                                          'hide_backends_chooser' => 0,
                                          'show_sitepanel' => 'off',
                                          'sites'          => [],
                                          'backend_chooser'         => 'select',
                                          'enable_shinken_features' => 0,
                                          'disable_backspace'       => 0,
                                          'server_timezone'       => '',
                                          'default_user_timezone' => 'Server Setting',
                                          'play_sounds'    => 0,
                                          'fav_counter'    => 0,
                                          'menu_states'      => {},
                                          'menu_states_json' => "{}",
                                          'cookie_auth'      => 0,
                                          'space'          => ' ',
                                          'debug_info'     => '',
                                          'bodyonload'     => 1,
                                          'has_jquery_ui'  => 0,
                                          'uri_filter'     => {
                                                'bookmark'      => undef,
                                                'referer'       => undef,
                                                'reload_nav'    => undef,
                                                'update.y'      => undef,
                                                'update.x'      => undef,
                                                '_'             => undef,
                                          },
                                          'physical_logo_path' => [],
                                          'all_in_one_javascript' => [
                                              'jquery-1.12.4.min.js',
                                              'thruk-'.$VERSION.'-'.$filebranch.'.js',
                                              'cal/jscal2.js',
                                              'overlib.js',
                                              'jquery-fieldselection.js',
                                              'strftime-min.js',
                                          ],
                                          'all_in_one_css_frames' => [
                                               'thruk_global.css',
                                               'Thruk.css',
                                          ],
                                          'all_in_one_css_noframes' => [
                                              'thruk_global.css',
                                              'thruk_noframes.css',
                                              'Thruk.css',
                                          ],
                                          'all_in_one_css_frames2' => [
                                               'thruk_global.css',
                                               'Thruk2.css',
                                          ],
                                          'all_in_one_css_noframes2' => [
                                              'thruk_global.css',
                                              'thruk_noframes.css',
                                              'Thruk2.css',
                                          ],
                                          'jquery_ui' => '1.12.1',
                                          'all_in_one_javascript_panorama' => [
                                              'javascript/thruk-'.$VERSION.'-'.$filebranch.'.js',
                                              'plugins/panorama/ux/form/MultiSelect.js',
                                              'plugins/panorama/ux/form/ItemSelector.js',
                                              'plugins/panorama/ux/chart/series/KPIGauge.js',
                                              'plugins/panorama/sprintf.js',
                                              'plugins/panorama/bigscreen.js',
                                              'javascript/strftime-min.js',
                                              'plugins/panorama/OpenLayers-2.13.1.js',
                                              'plugins/panorama/geoext2-2.0.2/src/GeoExt/Version.js',
                                              'plugins/panorama/geoext2-2.0.2/src/GeoExt/data/LayerModel.js',
                                              'plugins/panorama/geoext2-2.0.2/src/GeoExt/data/LayerStore.js',
                                              'plugins/panorama/geoext2-2.0.2/src/GeoExt/panel/Map.js',
                                          ],
                                      },
                  PRE_CHOMP          => 0,
                  POST_CHOMP         => 0,
                  TRIM               => 0,
                  COMPILE_EXT        => '.ttc',
                  STAT_TTL           => 604800, # templates do not change in production
                  STRICT             => 0,
                  render_die         => 1,
                  EVAL_PERL          => 1,
              },
              nagios => {
                  service_state_by_number => {
                                    0 => 'OK',
                                    1 => 'WARNING',
                                    2 => 'CRITICAL',
                                    3 => 'UNKNOWN',
                                    4 => 'PENDING',
                                },
                  host_state_by_number => {
                                    0 => 'UP',
                                    1 => 'DOWN',
                                    2 => 'UNREACHABLE',
                                },
              },
);
# set TT strict mode only for authors
$config{'thruk_debug'}  = 0;
$config{'thruk_author'} = 0;
$config{'demo_mode'}   = (-f $project_root."/.demo_mode" || $ENV{'THRUK_DEMO_MODE'}) ? 1 : 0;
if(-f $project_root."/.author" || $ENV{'THRUK_AUTHOR'}) {
    $config{'View::TT'}->{'STRICT'}     = 1;
    $config{'View::TT'}->{'CACHE_SIZE'} = 0 unless($config{'demo_mode'} or $ENV{'THRUK_SRC'} eq 'TEST');
    $config{'View::TT'}->{'STAT_TTL'}   = 5 unless($config{'demo_mode'} or $ENV{'THRUK_SRC'} eq 'TEST');
    $config{'View::TT'}->{'PRE_DEFINE'}->{'thruk_debug'} = 1;
    $config{'thruk_debug'}  = 1;
    $config{'thruk_author'} = 1;
}
$config{'View::TT'}->{'PRE_DEFINE'}->{'released'} = $config{released};

######################################

=head1 METHODS

=cut

######################################

=head2 get_config

make config available without loading complete dependencies

=cut

sub get_config {
    my @files = @_;
    my @local_files;
    if(scalar @files == 0) {
        for my $path ($ENV{'THRUK_CONFIG'}, '.') {
            next unless defined $path;
            push @files, $path.'/thruk.conf' if -f $path.'/thruk.conf';
            if(-d $path.'/thruk_local.d') {
                my @tmpfiles = sort glob($path.'/thruk_local.d/*');
                for my $tmpfile (@tmpfiles) {
                    my $ext;
                    if($tmpfile =~ m/\.([^.]+)$/mx) { $ext = $1; }
                    if(!$ext) {
                        if($ENV{'THRUK_VERBOSE'} && $ENV{'THRUK_VERBOSE'} >= 1) {
                            print STDERR "skipped config file: ".$tmpfile.", file has no extension, please use either cfg, conf or the hostname\n";
                        }
                        next;
                    }
                    if($ext ne 'conf' && $ext ne 'cfg') {
                        # only read if the extension matches the hostname
                        our $hostname;
                        if(!$hostname) { $hostname = `hostname`; chomp($hostname); }
                        if($tmpfile !~ m/\Q$hostname\E$/mx) {
                            if($ENV{'THRUK_VERBOSE'} && $ENV{'THRUK_VERBOSE'} >= 1) {
                                print STDERR "skipped config file: ".$tmpfile.", file does not end with our hostname '$hostname'\n";
                            }
                            next;
                        }
                    }
                    push @local_files, $tmpfile;
                }
            }
            push @local_files, $path.'/thruk_local.conf' if -f $path.'/thruk_local.conf';
            last if scalar @files > 0;
        }
    }

    my %configs = %{_load_any([@files, { 'thruk_local.conf' => \@local_files}])};
    my %config  = %Thruk::Config::config;
    my $first_backend_from_thruk_locals = 0;
    for my $file (@files, 'thruk_local.conf') {
        for my $key (keys %{$configs{$file}}) {
            if(defined $config{$key} and ref $config{$key} eq 'HASH') {
                if($key eq 'Thruk::Backend') {
                    # merge all backends from thruk_locals
                    if(!$first_backend_from_thruk_locals && $file =~ m|thruk_local\.|mx) {
                        $config{$key}->{'peer'} = [];
                        $first_backend_from_thruk_locals = 1;
                    }
                    for my $peer (@{list($configs{$file}->{$key})}) {
                        $config{$key}->{'peer'} = [ @{list($config{$key}->{'peer'})}, @{list($peer->{'peer'})} ];
                    }
                }
                elsif($key =~ '^Thruk::Plugin::') {
                    if(ref $configs{$file}->{$key} eq 'ARRAY') {
                        my $hash = {};
                        while(my $add = shift @{$configs{$file}->{$key}}) {
                            $hash = { %{$hash}, %{$add} };
                        }
                        $configs{$file}->{$key} = $hash;
                    }
                    if(ref $configs{$file}->{$key} ne 'HASH') { confess("tried to merge into hash: ".Dumper($file, $key, $configs{$file}->{$key})); }
                    $config{$key} = { %{$config{$key}}, %{$configs{$file}->{$key}} };
                } else {
                    if(ref $configs{$file}->{$key} ne 'HASH') { confess("tried to merge into hash: ".Dumper($file, $key, $configs{$file}->{$key})); }
                    $config{$key} = { %{$config{$key}}, %{$configs{$file}->{$key}} };
                }
            } else {
                $config{$key} = $configs{$file}->{$key};
            }
        }
    }

    # merge users and groups
    for my $type (qw/Group User/) {
        if($config{$type}) {
            for my $name (keys %{$config{$type}}) {
                # if its a list of hashes, merge into one hash
                if(ref $config{$type}->{$name} eq 'ARRAY') {
                    my $data = {};
                    for my $d (@{$config{$type}->{$name}}) {
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
                    $config{$type}->{$name} = $data;
                }
            }
        }
    }

    _do_finalize_config(\%config);
    return \%config;
}

######################################

=head2 set_default_config

return config with defaults added

=cut

sub set_default_config {
    my( $config ) = @_;

    #&timing_breakpoint('set_default_config');

    # defaults
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
    my $defaults = {
        'cgi.cfg'                       => 'cgi.cfg',
        bug_email_rcpt                  => 'bugs@thruk.org',
        home_link                       => 'http://www.thruk.org',
        plugin_registry_url             => ['https://api.thruk.org/v1/plugin/list'],
        cluster_nodes                   => '$proto$://$hostname$/$url_prefix$/',
        cluster_heartbeat_interval      => 15,
        cluster_node_stale_timeout      => 120,
        mode_file                       => '0660',
        mode_dir                        => '0770',
        backend_debug                   => 0,
        connection_pool_size            => undef,
        product_prefix                  => 'thruk',
        use_ajax_search                 => 1,
        ajax_search_hosts               => 1,
        ajax_search_hostgroups          => 1,
        ajax_search_services            => 1,
        ajax_search_servicegroups       => 1,
        ajax_search_timeperiods         => 1,
        shown_inline_pnp                => 1,
        use_feature_trends              => 1,
        use_wait_feature                => 1,
        wait_timeout                    => 10,
        use_curl                        => $ENV{'THRUK_CURL'} ? 1 : 0,
        use_frames                      => 1,
        use_strict_host_authorization   => 0,
        make_auth_user_lowercase        => 0,
        make_auth_user_uppercase        => 0,
        csrf_allowed_hosts              => ['127.0.0.1', '::1'],
        can_submit_commands             => 1,
        group_paging_overview           => '*3, 10, 100, all',
        group_paging_grid               => '*5, 10, 50, all',
        group_paging_summary            => '*10, 50, 100, all',
        default_theme                   => 'Thruk2',
        datetime_format                 => '%Y-%m-%d  %H:%M:%S',
        datetime_format_long            => '%a %b %e %H:%M:%S %Z %Y',
        datetime_format_today           => '%H:%M:%S',
        datetime_format_log             => '%B %d, %Y  %H',
        datetime_format_trends          => '%a %b %e %H:%M:%S %Y',
        title_prefix                    => '',
        use_pager                       => 1,
        start_page                      => $config->{'url_prefix'}.'main.html',
        documentation_link              => $config->{'url_prefix'}.'docs/index.html',
        useragentcompat                 => '',
        show_notification_number        => 1,
        strict_passive_mode             => 1,
        hide_passive_icon               => 0,
        show_full_commandline           => 1,
        show_modified_attributes        => 1,
        show_contacts                   => 1,
        show_config_edit_buttons        => 0,
        show_backends_in_table          => 0,
        show_logout_button              => 0,
        commandline_obfuscate_pattern   => [],
        backends_with_obj_config        => {},
        use_feature_statusmap           => 0,
        use_feature_statuswrl           => 0,
        use_feature_histogram           => 0,
        use_feature_configtool          => 0,
        use_feature_recurring_downtime  => 1,
        use_feature_bp                  => 0,
        use_feature_core_scheduling     => 0,
        use_service_description         => 0,
        use_bookmark_titles             => 0,
        use_dynamic_titles              => 1,
        use_new_search                  => 1,
        use_new_command_box             => 1,
        all_problems_link               => $config->{'url_prefix'}."cgi-bin/status.cgi?style=combined&amp;hst_s0_hoststatustypes=4&amp;hst_s0_servicestatustypes=31&amp;hst_s0_hostprops=10&amp;hst_s0_serviceprops=0&amp;svc_s0_hoststatustypes=3&amp;svc_s0_servicestatustypes=28&amp;svc_s0_hostprops=10&amp;svc_s0_serviceprops=10&amp;svc_s0_hostprop=2&amp;svc_s0_hostprop=8&amp;title=All+Unhandled+Problems",
        show_long_plugin_output         => 'popup',
        info_popup_event_type           => 'onclick',
        info_popup_options              => 'STICKY,CLOSECLICK,HAUTO,MOUSEOFF',
        cmd_quick_status                => {
                    default                => 'reschedule next check',
                    reschedule             => 1,
                    downtime               => 1,
                    comment                => 1,
                    acknowledgement        => 1,
                    active_checks          => 1,
                    notifications          => 1,
                    submit_result          => 1,
                    reset_attributes       => 1,
        },
        cmd_defaults                    => {
                    ahas                   => 0,
                    broadcast_notification => 0,
                    force_check            => 0,
                    force_notification     => 0,
                    send_notification      => 1,
                    sticky_ack             => 1,
                    persistent_comments    => 1,
                    persistent_ack         => 0,
                    ptc                    => 0,
                    use_expire             => 0,
        },
        command_disabled                    => {},
        command_enabled                     => {},
        force_sticky_ack                    => 0,
        force_send_notification             => 0,
        force_persistent_ack                => 0,
        force_persistent_comments           => 0,
        downtime_duration                   => 7200,
        expire_ack_duration                 => 86400,
        show_custom_vars                    => [],
        expand_user_macros                  => ['ALL'],
        themes_path                         => './themes',
        priorities                      => {
                    5                       => 'Business Critical',
                    4                       => 'Top Production',
                    3                       => 'Production',
                    2                       => 'Standard',
                    1                       => 'Testing',
                    0                       => 'Development',
        },
        no_external_job_forks               => 0,
        host_action_icon                    => 'action.gif',
        service_action_icon                 => 'action.gif',
        thruk_bin                           => '/usr/bin/thruk',
        thruk_init                          => '/etc/init.d/thruk',
        thruk_shell                         => '/bin/bash -l -c',
        first_day_of_week                   => 0,
        weekdays                        => {
                    '0'                     => 'Sunday',
                    '1'                     => 'Monday',
                    '2'                     => 'Tuesday',
                    '3'                     => 'Wednesday',
                    '4'                     => 'Thursday',
                    '5'                     => 'Friday',
                    '6'                     => 'Saturday',
                    '7'                     => 'Sunday',
                                           },
        'mobile_agent'                  => 'iPhone,Android,IEMobile',
        'show_error_reports'            => 'both',
        'skip_js_errors'                => [ 'cluetip is not a function', 'sprite._defaults is undefined' ],
        'cookie_auth_login_url'             => 'thruk/cgi-bin/login.cgi',
        'cookie_auth_restricted_url'        => 'http://localhost/thruk/cgi-bin/restricted.cgi',
        'cookie_auth_session_timeout'       => 86400,
        'cookie_auth_session_cache_timeout' => 5,
        'cookie_auth_domain'                => '',
        'perf_bar_mode'                     => 'match',
        'sitepanel'                         => 'auto',
        'ssl_verify_hostnames'              => 1,
        'precompile_templates'              => 0,
        'report_use_temp_files'             => 14,
        'report_max_objects'                => 1000,
        'report_include_class2'             => 1,
        'report_update_logcache'            => 1,
        'perf_bar_pnp_popup'                => 1,
        'status_color_background'           => 0,
        'apache_status'                     => {},
        'disable_user_password_change'      => 0,
        'user_password_min_length'          => 5,
        'grafana_default_panelId'           => 1,
        'graph_replace'                     => ['s/[^\w\-]/_/gmx'],
        'logcache_delta_updates'            => 1,
    };
    $defaults->{'thruk_bin'}   = 'script/thruk' if -f 'script/thruk';
    $defaults->{'cookie_path'} = $config->{'url_prefix'};
    my $product_prefix = $config->{'product_prefix'};
    $defaults->{'cookie_path'} =~ s/\/\Q$product_prefix\E\/*$//mx;
    $defaults->{'cookie_path'} = '/'.$product_prefix if $defaults->{'cookie_path'} eq '';
    $defaults->{'cookie_path'} =~ s|/*$||mx; # remove trailing slash, chrome doesn't seem to like them
    $defaults->{'cookie_path'} = $defaults->{'cookie_path'}.'/'; # seems like the above comment is not valid anymore and chrome now requires the trailing slash
    $defaults->{'cookie_path'} = '' if $defaults->{'cookie_path'} eq '/';

    for my $key (keys %{$defaults}) {
        $config->{$key} = exists $config->{$key} ? $config->{$key} : $defaults->{$key};

        # convert lists to scalars if the default is a scalar value
        if(ref $defaults->{$key} eq "" && ref $config->{$key} eq "ARRAY") {
            my $l = scalar (@{$config->{$key}});
            $config->{$key} = $config->{$key}->[$l-1];
        }
    }

    # make a nice path
    for my $key (qw/tmp_path var_path etc_path/) {
        $config->{$key} =~ s/\/$//mx if $config->{$key};
    }

    # merge hashes
    for my $key (qw/cmd_quick_status cmd_defaults/) {
        die(sprintf("%s should be a hash, got %s: %s", $key, ref $config->{$key}, Dumper($config->{$key}))) unless ref $config->{$key} eq 'HASH';
        $config->{$key} = { %{$defaults->{$key}}, %{ $config->{$key}} };
    }

    ## no critic
    $ENV{'THRUK_SRC'} = 'SCRIPTS' unless defined $ENV{'THRUK_SRC'};
    ## use critic
    # external jobs can be disabled by env
    # don't disable for CLI, breaks config reload over http somehow
    if(defined $ENV{'NO_EXTERNAL_JOBS'} or $ENV{'THRUK_SRC'} eq 'SCRIPTS') {
        $config->{'no_external_job_forks'} = 1;
    }

    $config->{'extra_version'}      = '' unless defined $config->{'extra_version'};
    $config->{'extra_version_link'} = '' unless defined $config->{'extra_version_link'};
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

    # set apache status url
    if($ENV{'CONFIG_APACHE_TCP_PORT'}) {
        $config->{'apache_status'}->{'Site'} = 'http://127.0.0.1:'.$ENV{'CONFIG_APACHE_TCP_PORT'}.'/server-status';
    }

    # additional user template paths?
    if(defined $config->{'user_template_path'} and defined $config->{templates_paths}) {
        if(scalar @{$config->{templates_paths}} == 0 || $config->{templates_paths}->[0] ne $config->{'user_template_path'}) {
            unshift @{$config->{templates_paths}}, $config->{'user_template_path'};
        }
    }

    # ensure csrf hosts is a list
    $config->{'csrf_allowed_hosts'} = [split(/\s*,\s*/mx, join(",", @{list($config->{'csrf_allowed_hosts'})}))];

    # make show_custom_vars a list
    $config->{'show_custom_vars'} = array_uniq([split(/\s*,\s*/mx, join(",", @{list($config->{'show_custom_vars'})}))]);

    # make some settings a list
    for my $key (qw/graph_replace commandline_obfuscate_pattern/) {
        $config->{$key} = [@{list($config->{$key})}];
    }

    ## no critic
    $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = $config->{'ssl_verify_hostnames'};
    ## use critic

    #&timing_breakpoint('set_default_config done');
    return;
}

######################################
sub _load_any {
    my($files) = @_;
    my $cfg    = load_any({
            files       => $files,
            filter      => \&_fix_syntax,
        },
    );

    return $cfg;
}

##############################################

=head2 get_thruk_version

  get_thruk_version($c, [$config])

return thruk version string

=cut

sub get_thruk_version {
    my($c, $config) = @_;
    $config = $c->config unless $config;
    if($config->{'branch'}) {
        return($config->{'version'}.'-'.$config->{'branch'});
    }
    return($config->{'version'});
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
    my($tag, $hash, $branch);
    my $dir = Cwd::getcwd;
    chdir($project_root.'/../../');

    # directly on git tag?
    $tag = `git describe --tag --exact-match 2>&1`;
    my $rc = $?;
    if($tag && $tag =~ m/\Qno tag exactly matches '\E([^']+)'/mx) { $hash = substr($1,0,7); }
    if($rc != 0) { $tag = ''; }
    if($tag) {
        chdir($dir);
        return '';
    }

    chomp($branch = `git branch --no-color 2>/dev/null`);
    if($branch =~ s/^\*\s+(.*)$//mx) { $branch = $1; }
    if(!$hash) {
        chomp($hash = `git log -1 --no-color --pretty=format:%h 2> /dev/null`);
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
    my $txt  = shift;
    my $c    = shift;
    my $list = {};
    return [] unless defined $txt;

    for my $item (ref $txt eq 'ARRAY' ? @{$txt} : $txt) {
        for my $block (split/\s*,\s*/mx, $item) {
            if($block =~ m/(\d+)\s*\-\s*(\d+)/gmx) {
                for my $nr ($1..$2) {
                    $list->{$nr} = 1;
                }
            } elsif($block =~ m/^(\d+)$/gmx) {
                    $list->{$1} = 1;
            } else {
                $c->log->error("'$block' is not a valid number or range") if defined $c;
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

    # restore user adjusted config
    if($c->stash->{'config_adjustments'}) {
        for my $key (keys %{$c->stash->{'config_adjustments'}}) {
            $c->config->{$key} = $c->stash->{'config_adjustments'}->{$key};
        }
    }
    if($c->stash->{'config_adjustments_extra'}) {
        $Thruk::Backend::Pool::peer_order   = $c->stash->{'config_adjustments_extra'}->{peer_order};
        $Thruk::Backend::Pool::peers        = $c->stash->{'config_adjustments_extra'}->{peers};
        $Thruk::Backend::Pool::pool         = $c->stash->{'config_adjustments_extra'}->{pool};
        $Thruk::Backend::Pool::pool_size    = $c->stash->{'config_adjustments_extra'}->{pool_size};
        $Thruk::Backend::Pool::xs           = $c->stash->{'config_adjustments_extra'}->{xs};
        delete $c->stash->{'config_adjustments_extra'};
    }


    if($Thruk::deprecations_log) {
        if(    $ENV{'THRUK_SRC'} ne 'TEST'
           and $ENV{'THRUK_SRC'} ne 'CLI'
           and $ENV{'THRUK_SRC'} ne 'SCRIPTS'
        ) {
            for my $warning (@{$Thruk::deprecations_log}) {
                $c->log->info($warning);
            }
        }
        undef $Thruk::deprecations_log;
    }

    return;
}

########################################
sub _do_finalize_config {
    my($config) = @_;

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
    my ($uid, $groups) = get_user($var_path);
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

    if(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'CLI') {
        if(defined $uid and $> == 0) {
            switch_user($uid, $groups);
        }
    }

    ###################################################
    # get installed plugins
    $config->{'plugin_path'} = $config->{home}.'/plugins' unless defined $config->{'plugin_path'};
    my $plugin_dir = $config->{'plugin_path'};
    $plugin_dir = $plugin_dir.'/plugins-enabled/*/';

    print STDERR "using plugins: ".$plugin_dir."\n" if $ENV{'THRUK_PLUGIN_DEBUG'};

    for my $addon (glob($plugin_dir)) {

        my $addon_name = $addon;
        $addon_name =~ s/\/+$//gmx;
        $addon_name =~ s/^.*\///gmx;

        # does the plugin directory exist? (only when running as normal user)
        if($> != 0 && ! -d $config->{home}.'/root/thruk/plugins/' && -w $config->{home}.'/root/thruk' ) {
            CORE::mkdir($config->{home}.'/root/thruk/plugins');
        }

        print STDERR "loading plugin: ".$addon_name."\n" if $ENV{'THRUK_PLUGIN_DEBUG'};

        # lib directory included?
        if(-d $addon.'lib') {
            print STDERR " -> lib\n" if $ENV{'THRUK_PLUGIN_DEBUG'};
            unshift(@INC, $addon.'lib');
        }

        # template directory included?
        if(-d $addon.'templates') {
            print STDERR " -> templates\n" if $ENV{'THRUK_PLUGIN_DEBUG'};
            unshift @{$config->{templates_paths}}, $addon.'templates';
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
        print STDERR "theme -> $theme\n" if $ENV{'THRUK_PLUGIN_DEBUG'};
        push @themes, $theme;
    }

    print STDERR "using themes: ".$themes_dir."\n" if $ENV{'THRUK_PLUGIN_DEBUG'};

    $config->{'View::TT'}->{'PRE_DEFINE'}->{'themes'} = \@themes;

    ###################################################
    # use uid to make tmp dir more uniq
    $config->{'tmp_path'} = '/tmp/thruk_'.$> unless defined $config->{'tmp_path'};
    $config->{'tmp_path'} =~ s|/$||mx;
    $config->{'View::TT'}->{'COMPILE_DIR'} = $config->{'tmp_path'}.'/ttc_'.$>;

    $config->{'ssi_path'} = $config->{'ssi_path'} || $config->{etc_path}.'/ssi';

    ###################################################
    # when using lmd, some settings don't make sense
    if($config->{'use_lmd_core'}) {
        $config->{'connection_pool_size'} = 1; # no pool required when using caching
        $config->{'check_local_states'}   = 0; # local state checking not required
    }

    # make this setting available in env
    ## no critic
    $ENV{'THRUK_CURL'} = $config->{'use_curl'} ? 1 : 0;
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
    for my $folder (@{Thruk::Config::list($action_menu_items_folder)}) {
        next unless -d $folder.'/.';
        my @files = glob($folder.'/*.json');
        for my $file (@files) {
            if($file =~ m%([^/]+)\.json$%mx) {
                my $basename = $1;
                $config->{'action_menu_items'}->{$basename} = 'file://'.$file;
            }
        }
    }

    # enable OMD tweaks
    if($ENV{'OMD_ROOT'}) {
        my $site = $ENV{'OMD_SITE'};
        my $root = $ENV{'OMD_ROOT'};
        my($siteport) = (`grep CONFIG_APACHE_TCP_PORT $root/etc/omd/site.conf` =~ m/(\d+)/mx);
        my($ssl)      = (`grep CONFIG_APACHE_MODE     $root/etc/omd/site.conf` =~ m/'(\w+)'/mx);
        my $proto     = $ssl eq 'ssl' ? 'https' : 'http';
        $config->{'omd_local_site_url'} = sprintf("%s://%s:%d/%s", $proto, "127.0.0.1", $siteport, $site);
        # bypass system reverse proxy for restricted cgi for permormance and locking reasons
        if($config->{'cookie_auth_restricted_url'} && $config->{'cookie_auth_restricted_url'} =~ m|^https?://localhost/$site/thruk/cgi-bin/restricted.cgi$|mx) {
            $config->{'cookie_auth_restricted_url'} = $config->{'omd_local_site_url'}.'/thruk/cgi-bin/restricted.cgi';
        }
        $config->{'omd_apache_proto'} = $proto;
    }

    # set default config
    set_default_config($config);

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
    # This is the user we want to be
    my $uid = (stat $from_folder)[4];
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
        @groups = ( $gid );
        while ( my ( $gid, $users ) = ( getgrent )[ 2, -1 ] ) {
            $users =~ /\b$name\b/mx and push @groups, $gid;
        }
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
    my $array = shift;

    my %seen = ();
    my @unique = grep { ! $seen{ $_ }++ } @{$array};

    return \@unique;
}

########################################

=head2 read_config_file

  read_config_file($file)

return parsed config file

=cut

sub read_config_file {
    my($files) = @_;
    $files = list($files);
    my @config_lines;
    for my $f (@{$files}) {
        if($ENV{'THRUK_VERBOSE'} && $ENV{'THRUK_VERBOSE'} >= 2) {
            print STDERR "reading config file: ".$f."\n";
        }
        # since perl 5.23 sysread on utf-8 handles is deprecated, so we need to open the file manually
        open my $fh, '<:encoding(UTF-8)', $f or die "Can't open '$f' for reading: $!";
        my @rows = grep(!/^\s*\#/mxo, <$fh>);
        push @config_lines, @rows;
        CORE::close($fh);
    }
    my $conf = {};
    _parse_rows($files, \@config_lines, $conf);
    return($conf);
}

######################################
sub _parse_rows {
    my($files, $rows, $conf, $until) = @_;
    my $lastline = '';
    while(my $line = shift @{$rows}) {
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
        return if $until && lc($line) eq $until;

        # nested structures
        if(substr($line,0,1) eq '<') {
            # named hashes: <item name>
            if($line =~ m|^<(\w+)\s+([^>]+)>|mxo) {
                my($k,$v) = ($1,$2);
                my $next  = {};
                _parse_rows($files, $rows, $next, '</'.lc($k).'>');
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
                _parse_rows($files, $rows, $next, '</'.lc($k).'>');
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
                confess("unknow config entry: ".$line." in ".join(",", @{$files}));
            }
        }
        if(substr($v,0,1) eq '"') {
            $v =~ s|^"([^"]*)"$|$1|gmxo;
        }
        if(!defined $conf->{$k}) {
            $conf->{$k} = $v;
        } elsif(ref $conf->{$k} eq 'ARRAY') {
            push @{$conf->{$k}}, $v;
        } else {
            $conf->{$k} = [$conf->{$k}, $v];
        }
    }
    return;
}

######################################

=head2 switch_user

  switch_user($uid, $groups)

switch user and groups

=cut

sub switch_user {
    my($uid, $groups) = @_;
    ## no critic
    $) = join(" ", @{$groups});
    # using POSIX::setuid here leads to
    # 'Insecure dependency in eval while running setgid'
    $> = $uid or confess("setuid failed: ".$!);
    ## use critic
    return;
}

######################################
sub _fix_syntax {
    my($config) = @_;
    my @components = (
        map +{
            prefix => $_ eq 'Component' ? '' : $_ . '::',
            values => delete $config->{ lc $_ } || delete $config->{ $_ },
        },
        grep { ref $config->{ lc $_ } || ref $config->{ $_ } } qw( Component Model M View V Controller C Plugin ),
    );

    foreach my $comp ( @components ) {
        my $prefix = $comp->{ prefix };
        foreach my $element ( keys %{ $comp->{ values } } ) {
            $config->{ "$prefix$element" } = $comp->{ values }->{ $element };
        }
    }
    return;
}

########################################

=head2 load_any( $options )

replacement function for Config::Any->load_files

=cut

sub load_any {
    my($options) = @_;
    my $result = {};
    for my $f (@{$options->{'files'}}) {
        my $name  = $f;
        my $files = $f;
        if(ref $f eq 'HASH') {
            my @keys = keys %{$f};
            $name = $keys[0];
            $files = $f->{$name};
        }
        my $config = read_config_file($files);
        &{$options->{'filter'}}($config);
        $result->{$name} = $config;
    }
    return($result);
}

########################################

=head1 AUTHOR

Sven Nierlein, 2009-present, <sven@nierlein.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
