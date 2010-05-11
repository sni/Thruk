package Thruk;

use 5.008000;
use strict;
use warnings;

use Carp;
use Catalyst::Log::Log4perl;
use Thruk::Utils;
use Thruk::Utils::Livestatus;
use Catalyst::Runtime '5.70';

###################################################
# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages

use parent qw/Catalyst/;
use Catalyst qw/
                Unicode::Encoding
                Authentication
                Authorization::ThrukRoles
                CustomErrorMessage
                ConfigLoader
                StackTrace
                Static::Simple
                Redirect
                Compress::Gzip
                /;
our $VERSION = '0.60';

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
__PACKAGE__->config('name'                   => 'Thruk',
                    'version'                => $VERSION,
                    'released'               => 'May 06, 2010',
                    'encoding'               => 'UTF-8',
                    'image_path'             => $project_root.'/root/thruk/images',
                    'project_root'           => $project_root,
                    'default_view'           => 'TT',
                    'View::TT'               => {
                        TEMPLATE_EXTENSION => '.tt',
                        ENCODING           => 'utf8',
                        INCLUDE_PATH       => $project_root.'/templates',
                        FILTERS            => {
                                                'duration'     => \&Thruk::Utils::filter_duration,
                                                'nl2br'        => \&Thruk::Utils::filter_nl2br,
                                            },
                        PRE_DEFINE         => {
                                                'sprintf'      => \&Thruk::Utils::filter_sprintf,
                                                'duration'     => \&Thruk::Utils::filter_duration,
                                                'name2id'      => \&Thruk::Utils::name2id,
                                                'uri'          => \&Thruk::Utils::uri,
                                                'uri_with'     => \&Thruk::Utils::uri_with,
                                                'html_escape'  => \&Thruk::Utils::_html_escape,
                                                'get_message'  => \&Thruk::Utils::get_message,
                                                'throw'        => \&Thruk::Utils::throw,
                                            },
                        PRE_CHOMP          => 1,
                        POST_CHOMP         => 1,
                        TRIM               => 1,
                        CACHE_SIZE         => 0,
                        COMPILE_EXT        => '.ttc',
                        COMPILE_DIR        => '/tmp/ttc',
                        STAT_TTL           => 60,
                        STRICT             => 0,
#                        DEBUG              => 'all',
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
                    'static' => {
                        'ignore_extensions' => [ qw/tpl tt tt2/ ],
                    },
);

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
# set installed themes
my $ssi_dir = $project_root."/ssi/";
my %ssi;
opendir( $dh, $ssi_dir) or die "can't opendir '$ssi_dir': $!";
for my $entry (readdir($dh)) {
    next if $entry eq '.' or $entry eq '..';
    next if $entry !~ /\.ssi$/mx;
    $ssi{$entry} = { name => $entry }
}
closedir $dh;
__PACKAGE__->config->{'ssi_includes'} = \%ssi;


###################################################
# Start the application
__PACKAGE__->setup();


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
#
# check if logdir exists
if(!-d $project_root.'/logs') { mkdir($project_root.'/logs') or die("failed to create logs directory: $!"); }

if(-s "log4perl.conf") {
    __PACKAGE__->log(Catalyst::Log::Log4perl->new("log4perl.conf"));
}
elsif(!__PACKAGE__->debug) {
    __PACKAGE__->log->levels( 'info', 'warn', 'error', 'fatal' );
}


###################################################
# GD installed?
# set to true unless there is a way to load trends.pm safely without GD
__PACKAGE__->config->{'has_gd'} = 0;
eval {
    require GD;
    __PACKAGE__->config->{'has_gd'} = 1;
};
if($@) {
    __PACKAGE__->log->error("cannot load GD.pm: did you forget to install libgd, libxpm or GD.pm?\n".$@);
    croak('cannot start');
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

Sven Nierlein, 2009, <nierlein@cpan.org>

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
