package Thruk::Config;

use strict;
use warnings;
use utf8;
use Thruk::Utils;
use Config::Any;
use Catalyst::Utils;
use Catalyst::Plugin::Thruk::ConfigLoader;

=head1 NAME

Thruk::Config - Generic Access to Thruks Config

=head1 DESCRIPTION

Generic Access to Thruks Config

=cut

######################################

our $VERSION = '1.63';

my $project_root = Catalyst::Utils::home('Thruk::Config');
my $branch       = '';
my $gitbranch    = Thruk::Utils::get_git_name($project_root);
$branch          = $gitbranch unless $branch ne '';

our %config = ('name'                   => 'Thruk',
              'version'                => $VERSION,
              'branch'                 => $branch,
              'released'               => 'January 12, 2013',
              'compression_format'     => 'gzip',
              'ENCODING'               => 'utf-8',
              'image_path'             => $project_root.'/root/thruk/images',
              'project_root'           => $project_root,
              'home'                   => $project_root,
              'default_view'           => 'TT',
              'View::TT'               => {
                  TEMPLATE_EXTENSION => '.tt',
                  ENCODING           => 'utf8',
                  INCLUDE_PATH       => $project_root.'/templates',
                  RECURSION          => 1,
                  FILTERS            => {
                                          'duration'            => \&Thruk::Utils::Filter::duration,
                                          'nl2br'               => \&Thruk::Utils::Filter::nl2br,
                                          'strip_command_args'  => \&Thruk::Utils::Filter::strip_command_args,
                                          'escape_html'         => \&Thruk::Utils::Filter::escape_html,
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
                                          'escape_bslash'       => \&Thruk::Utils::Filter::escape_bslash,
                                          'get_message'         => \&Thruk::Utils::Filter::get_message,
                                          'throw'               => \&Thruk::Utils::Filter::throw,
                                          'date_format'         => \&Thruk::Utils::Filter::date_format,
                                          'format_date'         => \&Thruk::Utils::format_date,
                                          'format_cronentry'    => \&Thruk::Utils::format_cronentry,
                                          'nl2br'               => \&Thruk::Utils::Filter::nl2br,
                                          'action_icon'         => \&Thruk::Utils::Filter::action_icon,
                                          'logline_icon'        => \&Thruk::Utils::Filter::logline_icon,
                                          'json_encode'         => \&Thruk::Utils::Filter::json_encode,
                                          'encode_json_obj'     => \&Thruk::Utils::Filter::encode_json_obj,
                                          'uniqnumber'          => \&Thruk::Utils::Filter::uniqnumber,
                                          'calculate_first_notification_delay_remaining' => \&Thruk::Utils::Filter::calculate_first_notification_delay_remaining,
                                          'set_favicon_counter' => \&Thruk::Utils::Status::set_favicon_counter,
                                          'get_pnp_url'         => \&Thruk::Utils::get_pnp_url,
                                          'make_test_mode'      => (defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'TEST') ? 1 : 0,
                                          'button'              => \&Thruk::Utils::Filter::button,

                                          'version'        => $VERSION,
                                          'branch'         => $branch,
                                          'starttime'      => time(),
                                          'debug_details'  => Thruk::Utils::get_debug_details(),
                                          'stacktrace'     => '',
                                          'backends'       => [],
                                          'backend_detail' => {},
                                          'pi_detail'      => {},
                                          'param_backend'  => '',
                                          'refresh_rate'   => '',
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
                                          'all_in_one_css' => 0,
                                          'hide_backends_chooser' => 0,
                                          'backend_chooser'       => 'select',
                                          'play_sounds'    => 0,
                                          'fav_counter'    => 0,
                                          'menu_states'      => {},
                                          'menu_states_json' => "{}",
                                          'cookie_auth'      => 0,
                                          'space'          => ' ',
                                          'uri_filter'     => {
                                                'bookmark'      => undef,
                                                'referer'       => undef,
                                                'reload_nav'    => undef,
                                                'update.y'      => undef,
                                                'update.x'      => undef,
                                                '_'             => undef,
                                          },
                                          'all_in_one_javascript' => [
                                              'jquery-1.7.2.min.js',
                                              'thruk-'.$VERSION.'.js',
                                              'cal/jscal2.js',
                                              'overlib.js',
                                              'jquery-fieldselection.js',
                                              'jquery-ui/js/jquery-ui-1.8.16.custom.min.js',
                                          ],
                                          'all_in_one_css_frames' => [
                                               'thruk_global.css',
                                               'Thruk.css'
                                          ],
                                          'all_in_one_css_noframes' => [
                                              'thruk_global.css',
                                              'thruk_noframes.css',
                                              'Thruk.css',
                                          ],
                                      },
                  PRE_CHOMP          => 1,
                  POST_CHOMP         => 1,
                  TRIM               => 1,
                  COMPILE_EXT        => '.ttc',
                  STAT_TTL           => 604800, # template do not change in production
                  STRICT             => 0,
                  render_die         => 1,
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
                                    0 => 'OK',
                                    1 => 'DOWN',
                                    2 => 'UNREACHABLE',
                                },
              },
              'View::GD'               => {
                  gd_image_type      => 'png',
              },
              'View::JSON'               => {
                  expose_stash       => 'json',
                  json_driver        => 'XS',
              },
              'Plugin::Thruk::ConfigLoader' => { file => $project_root.'/thruk.conf' },
              'Plugin::Authentication' => {
                  default_realm => 'Thruk',
                  realms => {
                      Thruk => { credential => { class => 'Thruk'       },
                                 store      => { class => 'FromCGIConf' },
                      }
                  }
              },
              'custom-error-message' => {
                  'error-template'    => 'error.tt',
                  'response-status'   => 500,
              },
              'Plugin::Static::Simple' => {
                  'ignore_extensions' => [ qw/tpl tt tt2/ ],
              },
              'Plugin::Cache'        => {
                  'backend'           => {
                    'class'            => "Catalyst::Plugin::Cache::Backend::Memory",
                  },
              },
              'Plugin::ConfigLoader'  => {
                driver => { General => { '-CComments' => 0  } }
              }
);
# set TT strict mode only for authors
$config{'thruk_debug'} = 0;
if(-f $project_root."/.author") {
    $config{'View::TT'}->{'STRICT'}     = 1;
    $config{'View::TT'}->{'CACHE_SIZE'} = 0;
    $config{'View::TT'}->{'STAT_TTL'}   = 5;
    $config{'View::TT'}->{'PRE_DEFINE'}->{'thruk_debug'} = 1;
    $config{'thruk_debug'} = 1;
}
$config{'View::TT'}->{'PRE_DEFINE'}->{'released'}      = $config{released};
$config{'View::Excel::Template::Plus'}->{'etp_config'} = $config{'View::TT'}; # use same config for View::Excel as in View::TT
$config{'View::PDF::Reuse'}                            = $config{'View::TT'}; # use same config as well

######################################

=head1 METHODS

=cut

######################################

=head2 get_config

make config available without loading complete catalyst

=cut

sub get_config {
    my @files = @_;
    if(scalar @files == 0) {
        for my $path ('.', $ENV{'CATALYST_CONFIG'}, $ENV{'THRUK_CONFIG'}) {
            next unless defined $path;
            push @files, $path.'/thruk.conf'       if -f $path.'/thruk.conf';
            push @files, $path.'/thruk_local.conf' if -f $path.'/thruk_local.conf';
        }
    }

    my %configs = %{_load_any(\@files)};
    my %config  = %Thruk::Config::config;
    for my $file (@files) {
        for my $key (keys %{$configs{$file}}) {
            if(defined $config{$key} and ref $config{$key} eq 'HASH') {
                $config{$key} = { %{$config{$key}}, %{$configs{$file}->{$key}} };
            } else {
                $config{$key} = $configs{$file}->{$key};
            }
        }
    }

    Catalyst::Plugin::Thruk::ConfigLoader::_do_finalize_config(\%config);
    return \%config;
}

######################################

=head2 set_default_config

return config with defaults added

=cut

sub set_default_config {
    my( $config ) = @_;

    # defaults
    $config->{'url_prefix'} = exists $config->{'url_prefix'} ? $config->{'url_prefix'} : '/';
    my $defaults = {
        'cgi.cfg'                       => 'cgi.cfg',
        bug_email_rcpt                  => 'bugs@thruk.org',
        home_link                       => 'http://www.thruk.org',
        mode_file                       => '0660',
        mode_dir                        => '0770',
        backend_debug                   => 0,
        connection_pool_size            => 0,
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
        use_frames                      => 1,
        use_strict_host_authorization   => 0,
        make_auth_user_lowercase        => 0,
        make_auth_user_uppercase        => 0,
        can_submit_commands             => 1,
        group_paging_overview           => '*3, 10, 100, all',
        group_paging_grid               => '*5, 10, 50, all',
        group_paging_summary            => '*10, 50, 100, all',
        default_theme                   => 'Thruk',
        datetime_format                 => '%Y-%m-%d  %H:%M:%S',
        datetime_format_long            => '%a %b %e %H:%M:%S %Z %Y',
        datetime_format_today           => '%H:%M:%S',
        datetime_format_log             => '%B %d, %Y  %H',
        datetime_format_trends          => '%a %b %e %H:%M:%S %Y',
        title_prefix                    => '',
        use_pager                       => 1,
        start_page                      => $config->{'url_prefix'}.'thruk/main.html',
        documentation_link              => $config->{'url_prefix'}.'thruk/docs/index.html',
        show_notification_number        => 1,
        strict_passive_mode             => 1,
        show_full_commandline           => 1,
        show_modified_attributes        => 1,
        show_config_edit_buttons        => 0,
        show_backends_in_table          => 0,
        backends_with_obj_config        => {},
        use_feature_statusmap           => 0,
        use_feature_statuswrl           => 0,
        use_feature_histogram           => 0,
        use_feature_configtool          => 0,
        use_new_search                  => 1,
        use_new_command_box             => 1,
        all_problems_link               => $config->{'url_prefix'}."thruk/cgi-bin/status.cgi?style=combined&amp;hst_s0_hoststatustypes=4&amp;hst_s0_servicestatustypes=31&amp;hst_s0_hostprops=10&amp;hst_s0_serviceprops=0&amp;svc_s0_hoststatustypes=3&amp;svc_s0_servicestatustypes=28&amp;svc_s0_hostprops=10&amp;svc_s0_serviceprops=10&amp;svc_s0_hostprop=2&amp;svc_s0_hostprop=8&amp;title=All+Unhandled+Problems",
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
        downtime_duration                   => 7200,
        expire_ack_duration                 => 86400,
        show_custom_vars                    => [],
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
        cookie_path                         => $config->{'url_prefix'}.'thruk',
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
                    '6'                     => 'Saterday',
                    '7'                     => 'Sunday',
                                           },
        'mobile_agent'                  => 'iPhone,Android,IEMobile',
        'show_error_reports'            => 1,
        'skip_js_errors'                => [ 'cluetip is not a function' ],
        'cookie_auth_login_url'             => 'thruk/cgi-bin/login.cgi',
        'cookie_auth_restricted_url'        => 'http://localhost/thruk/cgi-bin/restricted.cgi',
        'cookie_auth_session_timeout'       => 86400,
        'cookie_auth_session_cache_timeout' => 5,
        'perf_bar_mode'                     => 'match',
        'sitepanel'                         => 'auto',
        'ssl_verify_hostnames'              => 1,
        'use_curl'                          => 0,
    };
    $defaults->{'thruk_bin'} = 'script/thruk' if -f 'script/thruk';
    for my $key (keys %{$defaults}) {
        $config->{$key} = exists $config->{$key} ? $config->{$key} : $defaults->{$key};
    }

    # make a nice path
    for my $key (qw/tmp_path var_path/) {
        $config->{$key} =~ s/\/$//mx;
    }

    # merge hashes
    for my $key (qw/cmd_quick_status cmd_defaults/) {
        $config->{$key} = { %{$defaults->{$key}}, %{ $config->{$key}} };
    }
    # command disabled should be a hash
    if(ref $config->{'command_disabled'} ne 'HASH') {
        $config->{'command_disabled'} = Thruk::Utils::array2hash(Thruk::Utils::expand_numeric_list($config->{'command_disabled'}));
    }

    $ENV{'THRUK_SRC'} = 'SCRIPTS' unless defined $ENV{'THRUK_SRC'};
    # external jobs can be disabled by env
    if(defined $ENV{'NO_EXTERNAL_JOBS'}
       or $ENV{'THRUK_SRC'} eq 'SCRIPTS'
       or $ENV{'THRUK_SRC'} eq 'CLI')
    {
        $config->{'no_external_job_forks'} = 1;
    }

    $config->{'omd_version'} = "";
    if(defined $ENV{'OMD_ROOT'} and -s $ENV{'OMD_ROOT'}."/version") {
        my $omdlink = readlink($ENV{'OMD_ROOT'}."/version");
        $omdlink    =~ s/.*?\///gmx;
        $omdlink    =~ s/^(\d+)\.(\d+).(\d{4})(\d{2})(\d{2})/$1.$2~$3-$4-$5/gmx; # nicer snapshots
        $config->{'omd_version'} = $omdlink;
    }

    # additional user template paths?
    if(defined $config->{'user_template_path'}) {
        if(scalar @{$config->{templates_paths}} == 0 || $config->{templates_paths}->[0] ne $config->{'user_template_path'}) {
            unshift @{$config->{templates_paths}}, $config->{'user_template_path'};
        }
    }

    $ENV{'PERL_LWP_SSL_VERIFY_HOSTNAME'} = $config->{'ssl_verify_hostnames'};

    return;
}

######################################
sub _load_any {
    my ($files) = @_;
    my $cfg   = Config::Any->load_files({
            files       => $files,
            filter      => \&Catalyst::Plugin::ConfigLoader::_fix_syntax,
            use_ext     => 1,
            driver_args => $Thruk::Config::config{'Plugin::ConfigLoader'}->{'driver'},
        }
    );

    # map the array of hashrefs to a simple hash
    my %configs = map { %$_ } @$cfg;

    return \%configs;
}

######################################

=head1 AUTHOR

Sven Nierlein, 2012, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
