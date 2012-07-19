package Thruk;

=head1 NAME

Thruk - Catalyst based monitoring web interface

=head1 DESCRIPTION

Catalyst based monitoring web interface for Nagios, Icinga and Shinken

=cut

use 5.008000;
use strict;
use warnings;

use utf8;
use Carp;
use GD;
use POSIX qw(tzset);
use Log::Log4perl::Catalyst;
use Digest::MD5 qw(md5_hex);
use File::Slurp qw(read_file);
use Thruk::Backend::Manager;
use Thruk::Utils;
use Thruk::Utils::Auth;
use Thruk::Utils::Filter;
use Thruk::Utils::IO;
use Thruk::Utils::Menu;
use Thruk::Utils::Avail;
use Thruk::Utils::External;
use Catalyst::Runtime '5.70';

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

###################################################
# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#         StackTrace

use parent qw/Catalyst/;
use Catalyst qw/
                Thruk::ConfigLoader
                Unicode::Encoding
                Compress
                Authentication
                Authorization::ThrukRoles
                CustomErrorMessage
                Static::Simple
                Redirect
                Cache
                Thruk::RemoveNastyCharsFromHttpParam
                /;
our $VERSION = '1.35';

###################################################
# Configure the application.
#
# Note that settings in thruk.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with a external configuration file acting as an override for
# local deployment.
my $project_root = __PACKAGE__->config->{home};
my $branch       = '';
$branch          = Thruk::Utils::get_git_name($project_root) unless $branch ne '';
my %config = ('name'                   => 'Thruk',
              'version'                => $VERSION,
              'released'               => 'June 21, 2012',
              'compression_format'     => 'gzip',
              'ENCODING'               => 'utf-8',
              'image_path'             => $project_root.'/root/thruk/images',
              'project_root'           => $project_root,
              'min_livestatus_version' => '1.1.3',
              'default_view'           => 'TT',
              'View::TT'               => {
                  TEMPLATE_EXTENSION => '.tt',
                  ENCODING           => 'utf8',
                  INCLUDE_PATH       => $project_root.'/templates',
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
                                          'calculate_first_notification_delay_remaining' => \&Thruk::Utils::Filter::calculate_first_notification_delay_remaining,

                                          'version'        => $VERSION,
                                          'branch'         => $branch,
                                          'debug_details'  => Thruk::Utils::get_debug_details(),
                                          'backends'       => [],
                                          'param_backend'  => '',
                                          'refresh_rate'   => '',
                                          'page'           => '',
                                          'title'          => '',
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
                                          'thruk_debug'    => 0,
                                          'all_in_one_css' => 0,
                                          'hide_backends_chooser' => 0,
                                          'backend_chooser'       => 'select',
                                          'play_sounds'    => 0,
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
                  STAT_TTL           => 3600,
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
              'static'               => {
                  'ignore_extensions' => [ qw/tpl tt tt2/ ],
              },
              'Plugin::Cache'        => {
                  'backend'           => {
                    'class'            => "Catalyst::Plugin::Cache::Backend::Memory",
                  },
              },
);
# set TT strict mode only for authors
if(-f $project_root."/.author") {
    $config{'View::TT'}->{'STRICT'}     = 1;
    $config{'View::TT'}->{'CACHE_SIZE'} = 0;
    $config{'View::TT'}->{'STAT_TTL'}   = 5;
    $config{'View::TT'}->{'PRE_DEFINE'}->{'thruk_debug'} = 1;
}
$config{'View::TT'}->{'PRE_DEFINE'}->{'released'}      = $config{released};
$config{'View::Excel::Template::Plus'}->{'etp_config'} = $config{'View::TT'}; # use same config for View::Excel as in View::TT
$config{'View::PDF::Reuse'}                            = $config{'View::TT'}; # use same config as well

###################################################
# set some defaults
__PACKAGE__->config->{'cgi.cfg'}  = exists __PACKAGE__->config->{'cgi.cfg'}  ? __PACKAGE__->config->{'cgi.cfg'}  : 'cgi.cfg';

###################################################
# load config loader
__PACKAGE__->config(%config);

###################################################
# Start the application and make __PACKAGE__->config
# accessible
# override config in Catalyst::Plugin::Thruk::ConfigLoader
__PACKAGE__->setup();

###################################################
# save user/group id
my $var_path = __PACKAGE__->config->{'var_path'} or die("no var path!");
die("'".$var_path."/.' does not exist, make sure it exists and has proper user/groups/permissions") unless -d $var_path.'/.';
my ($uid, $groups) = Thruk::Utils::get_user($var_path);
$ENV{'THRUK_USER_ID'}  = $uid;
$ENV{'THRUK_GROUP_ID'} = $groups->[0];
$ENV{'THRUK_GROUPS'}   = join(',', @{$groups});

###################################################
# save pid
Thruk::Utils::IO::mkdir(__PACKAGE__->config->{'tmp_path'});
my $pidfile  = __PACKAGE__->config->{'tmp_path'}.'/thruk.pid';
sub _remove_pid {
    if(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'FastCGI') {
        unlink($pidfile);
    }
    return;
}
if(defined $ENV{'THRUK_SRC'} and $ENV{'THRUK_SRC'} eq 'FastCGI') {
    open(my $fh, '>', $pidfile) || warn("cannot write $pidfile: $!");
    print $fh $$."\n";
    Thruk::Utils::IO::close($fh, $pidfile);
    $SIG{INT}  = sub { _remove_pid();  exit; };
    $SIG{TERM} = sub { _remove_pid(); exit; };
}
END {
    _remove_pid();
};

###################################################
# create secret file
if(!defined $ENV{'THRUK_SRC'} or $ENV{'THRUK_SRC'} ne 'SCRIPTS') {
    my $secretfile = $var_path.'/secret.key';
    unless(-s $secretfile) {
        my $digest = md5_hex(rand(1000).time());
        chomp($digest);
        open(my $fh, ">$secretfile") or warn("cannot write to $secretfile: $!");
        if(defined $fh) {
            print $fh $digest;
            Thruk::Utils::IO::close($fh, $secretfile);
        }
        __PACKAGE__->config->{'secret_key'} = $digest;
    } else {
        my $secret_key = read_file($secretfile);
        chomp($secret_key);
        __PACKAGE__->config->{'secret_key'} = $secret_key;
    }
}

###################################################
# set timezone
my $timezone = __PACKAGE__->config->{'use_timezone'};
if(defined $timezone) {
    $ENV{'TZ'} = $timezone;
    POSIX::tzset();
}

###################################################
# set installed server side includes
my $ssi_dir = __PACKAGE__->config->{'ssi_path'} || $project_root."/ssi/";
my (%ssi, $dh);
if(!-e $ssi_dir) {
    warn("cannot access ssi_path $ssi_dir: $!");
} else {
    opendir( $dh, $ssi_dir) or die "can't opendir '$ssi_dir': $!";
    for my $entry (readdir($dh)) {
        next if $entry eq '.' or $entry eq '..';
        next if $entry !~ /\.ssi$/mx;
        $ssi{$entry} = { name => $entry }
    }
    closedir $dh;
}
__PACKAGE__->config->{'ssi_includes'} = \%ssi;
__PACKAGE__->config->{'ssi_path'}     = $ssi_dir;

###################################################
# load and parse cgi.cfg into $c->config
if(exists __PACKAGE__->config->{'cgi_cfg'}) {
    warn("cgi_cfg option is deprecated and has been renamed to cgi.cfg!");
    __PACKAGE__->config->{'cgi.cfg'} = __PACKAGE__->config->{'cgi_cfg'};
    delete __PACKAGE__->config->{'cgi_cfg'};
}
unless(Thruk::Utils::read_cgi_cfg(undef, __PACKAGE__->config, __PACKAGE__->log)) {
    die("\n\n*****\nfailed to load cgi config: ".__PACKAGE__->config->{'cgi.cfg'}."\n*****\n\n");
}


###################################################
# Logging
my $log4perl_conf;
if(!defined $ENV{'THRUK_SRC'} or ($ENV{'THRUK_SRC'} ne 'CLI' and $ENV{'THRUK_SRC'} ne 'SCRIPTS')) {
    if(defined __PACKAGE__->config->{'log4perl_conf'} and ! -s __PACKAGE__->config->{'log4perl_conf'} ) {
        die("\n\n*****\nfailed to load log4perl config: ".__PACKAGE__->config->{'log4perl_conf'}.": ".$!."\n*****\n\n");
    }
    $log4perl_conf = __PACKAGE__->config->{'log4perl_conf'} || $project_root.'/log4perl.conf';
}
if(defined $log4perl_conf and -s $log4perl_conf) {
    __PACKAGE__->log(Log::Log4perl::Catalyst->new($log4perl_conf));
}
elsif(!__PACKAGE__->debug) {
    __PACKAGE__->log->levels( 'info', 'warn', 'error', 'fatal' );
}

###################################################
# additional user template paths?
if(defined __PACKAGE__->config->{'user_template_path'}) {
    unshift @{__PACKAGE__->config->{templates_paths}}, __PACKAGE__->config->{'user_template_path'};
}

###################################################
__PACKAGE__->config->{'omd_version'} = "";
if(defined $ENV{'OMD_ROOT'} and -s $ENV{'OMD_ROOT'}."/version") {
    my $omdlink = readlink($ENV{'OMD_ROOT'}."/version");
    $omdlink    =~ s/.*?\///gmx;
    __PACKAGE__->config->{'omd_version'} = $omdlink;
}

###################################################

=head1 METHODS

=head2 check_user_roles_wrapper

  check_user_roles_wrapper()

wrapper to avoid undef values in TT

=cut
sub check_user_roles_wrapper {
    my $self = shift;
    if($self->check_user_roles(@_)) {
        return 1;
    }
    return 0;
}

=head1 SEE ALSO

L<Thruk::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Sven Nierlein, 2010-2012, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
