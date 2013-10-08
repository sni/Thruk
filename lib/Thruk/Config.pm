package Thruk::Config;

use strict;
use warnings;
use utf8;
use Config::Any;
use Catalyst::Utils;
use Catalyst::Plugin::Thruk::ConfigLoader;

=head1 NAME

Thruk::Config - Generic Access to Thruks Config

=head1 DESCRIPTION

Generic Access to Thruks Config

=cut

######################################

our $VERSION = '1.76';

my $project_root = Catalyst::Utils::home('Thruk::Config');
my $branch       = '';
my $gitbranch    = get_git_name($project_root);
$branch          = $gitbranch unless $branch ne '';

our %config = ('name'                   => 'Thruk',
              'version'                => $VERSION,
              'branch'                 => $branch,
              'released'               => 'September 03, 2013',
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
                                          'remove_html_comments' => \&Thruk::Utils::Filter::remove_html_comments,
                                          'format_date'         => \&Thruk::Utils::format_date,
                                          'format_cronentry'    => \&Thruk::Utils::format_cronentry,
                                          'format_number'       => \&Thruk::Utils::format_number,
                                          'nl2br'               => \&Thruk::Utils::Filter::nl2br,
                                          'action_icon'         => \&Thruk::Utils::Filter::action_icon,
                                          'logline_icon'        => \&Thruk::Utils::Filter::logline_icon,
                                          'json_encode'         => \&Thruk::Utils::Filter::json_encode,
                                          'encode_json_obj'     => \&Thruk::Utils::Filter::encode_json_obj,
                                          'uniqnumber'          => \&Thruk::Utils::Filter::uniqnumber,
                                          'calculate_first_notification_delay_remaining' => \&Thruk::Utils::Filter::calculate_first_notification_delay_remaining,
                                          'has_business_process' => \&Thruk::Utils::Filter::has_business_process,
                                          'set_favicon_counter' => \&Thruk::Utils::Status::set_favicon_counter,
                                          'get_pnp_url'         => \&Thruk::Utils::get_pnp_url,
                                          'get_graph_url'       => \&Thruk::Utils::get_graph_url,
                                          'get_action_url'       => \&Thruk::Utils::get_action_url,
                                          'make_test_mode'      => (defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'TEST') ? 1 : 0,
                                          'button'              => \&Thruk::Utils::Filter::button,
                                          'fullversion'         => \&Thruk::Utils::Filter::fullversion,
                                          'reduce_number'       => \&Thruk::Utils::reduce_number,

                                          'version'        => $VERSION,
                                          'branch'         => $branch,
                                          'starttime'      => time(),
                                          'debug_details'  => get_debug_details(),
                                          'stacktrace'     => '',
                                          'backends'       => [],
                                          'backend_detail' => {},
                                          'pi_detail'      => {},
                                          'param_backend'  => '',
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
                                          'all_in_one_css' => 0,
                                          'hide_backends_chooser' => 0,
                                          'backend_chooser'       => 'select',
                                          'play_sounds'    => 0,
                                          'fav_counter'    => 0,
                                          'menu_states'      => {},
                                          'menu_states_json' => "{}",
                                          'cookie_auth'      => 0,
                                          'space'          => ' ',
                                          'debug_info'     => '',
                                          'has_jquery_ui'  => 0,
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
                                              'strftime-min.js',
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
                                          'jquery_ui' => '1.10.3',
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
              'Plugin::ConfigLoader'  => {
                driver => { General => { '-CComments' => 0  } }
              }
);
# set TT strict mode only for authors
$config{'thruk_debug'} = 0;
$config{'demo_mode'}   = -f $project_root."/.demo_mode" ? 1 : 0;
if(-f $project_root."/.author") {
    $config{'View::TT'}->{'STRICT'}     = 1;
    $config{'View::TT'}->{'CACHE_SIZE'} = 0 unless $config{'demo_mode'};
    $config{'View::TT'}->{'STAT_TTL'}   = 5 unless $config{'demo_mode'};
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

##############################################

=head2 get_git_name

  get_git_name()

return git branch name

=cut

sub get_git_name {
    my $project_root = $INC{'Thruk/Config.pm'};
    $project_root =~ s/\/Config\.pm$//gmx;
    if(-d $project_root.'/../../.git') {
        # directly on git tag?
        my $tag = `cd $project_root && git describe --tag --exact-match 2>/dev/null`;
        return '' if $tag;

        my $branch = `cd $project_root && git branch --no-color 2> /dev/null | grep ^\*`;
        chomp($branch);
        $branch =~ s/^\*\s+//gmx;
        my $hash = `cd $project_root && git log -1 --no-color --pretty=format:%h 2> /dev/null`;
        chomp($hash);
        if($branch eq 'master') {
            return $hash;
        }
        return $branch.'.'.$hash;
    }
    return '';
}

########################################

=head2 get_debug_details

  get_debug_details()

return details useful for debuging

=cut

sub get_debug_details {
    chomp(my $uname = `uname -a`);
    my $release = "";
    for my $f (qw|/etc/redhat-release /etc/issue|) {
        if(-e $f) {
            $release = `cat $f`;
            last;
        }
    }
    $release =~ s/^\s*//gmx;
    $release =~ s/\\\w//gmx;
    $release =~ s/\s*$//gmx;
    my $details =<<EOT;
uname:      $uname
release:    $release
EOT
    return $details;
}

######################################

=head1 AUTHOR

Sven Nierlein, 2012, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
