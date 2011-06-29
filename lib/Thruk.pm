package Thruk;

use 5.008000;
use strict;
use warnings;

use utf8;
use Carp;
use Catalyst::Log::Log4perl;
use Thruk::Backend::Manager;
use Thruk::Utils;
use Thruk::Utils::Auth;
use Thruk::Utils::Filter;
use Thruk::Utils::Menu;
use Catalyst::Runtime '5.70';

binmode(STDOUT, ":encoding(UTF-8)");
binmode(STDERR, ":encoding(UTF-8)");

###################################################
# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages

use parent qw/Catalyst/;
use Catalyst qw/
                Thruk::ConfigLoader
                Unicode::Encoding
                Compress
                Authentication
                Authorization::ThrukRoles
                CustomErrorMessage
                StackTrace
                Static::Simple
                Redirect
                Cache
                Thruk::RemoveNastyCharsFromHttpParam
                /;
our $VERSION = '1.0.7';

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
my %config = ('name'                   => 'Thruk',
              'version'                => $VERSION,
              'released'               => 'June 29, 2011',
              compression_format       => 'gzip',
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
                                      },
                  PRE_DEFINE         => {
                                          'sprintf'        => \&Thruk::Utils::Filter::sprintf,
                                          'duration'       => \&Thruk::Utils::Filter::duration,
                                          'name2id'        => \&Thruk::Utils::Filter::name2id,
                                          'uri'            => \&Thruk::Utils::Filter::uri,
                                          'full_uri'       => \&Thruk::Utils::Filter::full_uri,
                                          'short_uri'      => \&Thruk::Utils::Filter::short_uri,
                                          'uri_with'       => \&Thruk::Utils::Filter::uri_with,
                                          'html_escape'    => \&Thruk::Utils::Filter::html_escape,
                                          'xml_escape'     => \&Thruk::Utils::Filter::xml_escape,
                                          'escape_quotes'  => \&Thruk::Utils::Filter::escape_quotes,
                                          'get_message'    => \&Thruk::Utils::Filter::get_message,
                                          'throw'          => \&Thruk::Utils::Filter::throw,
                                          'date_format'    => \&Thruk::Utils::Filter::date_format,
                                          'format_date'    => \&Thruk::Utils::format_date,

                                          'version'        => $VERSION,
                                          'backends'       => [],
                                          'param_backend'  => '',
                                          'refresh_rate'   => '',
                                          'page'           => '',
                                          'title'          => '',
                                          'remote_user'    => '?',
                                          'infoBoxTitle'   => '',
                                          'has_proc_info'  => 0,
                                          'no_auto_reload' => 0,
                                          'die_on_errors'  => 0,        # used in cmd.cgi
                                          'errorMessage'   => 0,        # used in errors
                                          'js'             => '',       # used in _header.tt
                                          'extra_header'   => '',       # used in _header.tt
                                          'ssi_header'     => '',       # used in _header.tt
                                          'ssi_footer'     => '',       # used in _header.tt
                                          'paneprefix'     => 'dfl_',   # used in _status_filter.tt
                                          'sortprefix'     => '',       # used in _status_detail_table.tt / _status_hostdetail_table.tt
                                          'show_form'      => '1',      # used in _status_filter.tt
                                          'author'         => 0,
                                          'all_in_one_css' => 0,
                                          'hide_backends_chooser' => 0,
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
    $config{'View::TT'}->{'STAT_TTL'}   = 3600;
    $config{'View::TT'}->{'PRE_DEFINE'}->{'author'} = 1;
}
$config{'View::Excel::Template::Plus'}->{'etp_config'} = $config{'View::TT'}; # use same config for View::Excel as in View::TT
$config{'View::TT'}->{'PRE_DEFINE'}->{'released'}      = $config{released};

###################################################
# set installed themes
my $themes_dir = $project_root."/root/thruk/themes/";
my @themes;
opendir(my $dh, $themes_dir) or die "can't opendir '$themes_dir': $!";
for my $entry (readdir($dh)) {
    next unless -d $themes_dir."/".$entry;
    next if $entry =~ m/^\./mx; # hide hidden dirs
    next if $entry eq 'images';
    push @themes, $entry;
}
@themes = sort @themes;
closedir $dh;
$config{'View::TT'}->{'PRE_DEFINE'}->{'themes'} = \@themes;

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
# set timezone
my $timezone = __PACKAGE__->config->{'use_timezone'};
if(defined $timezone) {
    $ENV{'TZ'} = $timezone;
}

###################################################
# set installed themes
my $ssi_dir = __PACKAGE__->config->{'ssi_path'} || $project_root."/ssi/";
my %ssi;
opendir( $dh, $ssi_dir) or die "can't opendir '$ssi_dir': $!";
for my $entry (readdir($dh)) {
    next if $entry eq '.' or $entry eq '..';
    next if $entry !~ /\.ssi$/mx;
    $ssi{$entry} = { name => $entry }
}
closedir $dh;
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
    die("\n\n*****\nfailed to load cgi config\n*****\n\n");
}


###################################################
# Logging
if(defined __PACKAGE__->config->{'log4perl_conf'} and ! -s __PACKAGE__->config->{'log4perl_conf'} ) {
    die("\n\n*****\nfailed to load log4perl config: ".__PACKAGE__->config->{'log4perl_conf'}.": ".$!."\n*****\n\n");
}
my $log4perl_conf = __PACKAGE__->config->{'log4perl_conf'} || $project_root.'/log4perl.conf';
if(-s $log4perl_conf) {
    __PACKAGE__->log(Catalyst::Log::Log4perl->new($log4perl_conf));
}
elsif(!__PACKAGE__->debug) {
    # check if logdir exists
    if(!-d $project_root.'/logs') { mkdir($project_root.'/logs') or die("failed to create logs directory: $!"); }
    __PACKAGE__->log->levels( 'info', 'warn', 'error', 'fatal' );
}


###################################################
# GD installed?
# set to true unless there is a way to load trends.pm safely without GD
__PACKAGE__->config->{'has_gd'} = 0;
eval {
    require("GD.pm");
    __PACKAGE__->config->{'has_gd'} = 1;
};
if($@) {
    __PACKAGE__->log->error("cannot load GD.pm: did you forget to install libgd, libxpm or GD.pm?\n".$@);
    croak('cannot start');
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


=head1 NAME

Thruk - Catalyst based monitoring web interface

=head1 SYNOPSIS

    script/thruk_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<Thruk::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Sven Nierlein, 2010, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
