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

binmode(STDOUT, ":utf8");
binmode(STDERR, ":utf8");

###################################################
# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages

use parent qw/Catalyst/;
use Catalyst qw/
                Authentication
                Authorization::ThrukRoles
                CustomErrorMessage
                ConfigLoader
                StackTrace
                Static::Simple
                Redirect
                Cache
                Unicode::Encoding
                Compress::Gzip
                Thruk::RemoveNastyCharsFromHttpParam
                /;
our $VERSION = '0.78.2';

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
              'released'               => 'January 19, 2010',
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
                                          'uri_with'       => \&Thruk::Utils::Filter::uri_with,
                                          'html_escape'    => \&Thruk::Utils::Filter::html_escape,
                                          'escape_quotes'  => \&Thruk::Utils::Filter::escape_quotes,
                                          'get_message'    => \&Thruk::Utils::Filter::get_message,
                                          'throw'          => \&Thruk::Utils::Filter::throw,
                                          'date_format'    => \&Thruk::Utils::Filter::date_format,

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
                                          'die_on_errors'  => 0,  # used in cmd.cgi
                                          'errorMessage'   => 0,  # used in errors
                                          'js'             => '', # used in _header.tpl
                                          'extra_header'   => '', # used in _header.tpl
                                          'ssi_header'     => '', # used in _header.tpl
                                          'ssi_footer'     => '', # used in _header.tpl
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
              'Plugin::ConfigLoader'   => { file => $project_root.'/thruk.conf' },
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
}
$config{'View::Excel::Template::Plus'}->{'etp_config'} = $config{'View::TT'}; # use same config for View::Excel as in View::TT
$config{'View::TT'}->{'PRE_DEFINE'}->{'released'}      = $config{released};
__PACKAGE__->config(%config);

###################################################
# get installed plugins
BEGIN {
    my $project_root = __PACKAGE__->config->{home};
    for my $addon (glob($project_root.'/plugins/plugins-enabled/*/')) {
        my $addon_name = $addon;
        $addon_name =~ s/\/$//gmx;
        $addon_name =~ s/^.*\///gmx;

        # does the plugin directory exist?
        if(! -d $project_root.'/root/thruk/plugins/') {
            mkdir($project_root.'/root/thruk/plugins/') or die('cannot create '.$project_root.'/root/thruk/plugins/ : '.$!);
        }

        # lib directory included?
        if(-d $addon.'lib') {
            unshift(@INC, $addon.'lib')
        }

        # template directory included?
        if(-d $addon.'templates') {
            unshift @{__PACKAGE__->config->{templates_paths}}, $addon.'templates'
        }

        # static content included?
        if(-d $addon.'root') {
            my $target_symlink = $project_root.'/root/thruk/plugins/'.$addon_name;
            if(-e $target_symlink) { unlink($target_symlink) or die("cannot unlink: ".$target_symlink." : $!"); }
            symlink($addon.'root', $target_symlink) or die("cannot create ".$target_symlink." : ".$!);
        }
    }
}

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
__PACKAGE__->config->{'View::TT'}->{'PRE_DEFINE'}->{'themes'} = \@themes;

###################################################
# set tmp dir
my $tmp_dir = __PACKAGE__->config->{'tmp_path'} || '/tmp';
$config{'View::TT'}->{'COMPILE_DIR'} = $tmp_dir.'/thruk_ttc_'.$>; # use uid to make tmp dir more uniq
__PACKAGE__->config->{'View::TT'}->{'COMPILE_DIR'} = $tmp_dir.'/thruk_ttc_'.$>; # use uid to make tmp dir more uniq


###################################################
# Start the application
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

###################################################

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
