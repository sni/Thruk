#!/usr/bin/env perl

# create combined javascript/css files
BEGIN {
    $ENV{'THRUK_SRC'} = 'SCRIPTS';

    # do we want compression at all?
    if(-e 'Makefile') {
        chomp(my $compress = `grep THRUKCOMPRESS Makefile | awk '{print \$3}'`);
        $ENV{THRUK_SKIP_COMPRESS} = 1 if $compress eq 'disabled';
    }
};
use warnings;
use strict;
use lib 'lib';
use lib 'plugins/plugins-available/panorama/lib';
use Thruk::Config;

my($dos2unix, $yuicompr);
for my $p (reverse split/:/, $ENV{'PATH'}) {
    $dos2unix = $p.'/dos2unix'       if -x $p.'/dos2unix';
    $dos2unix = $p.'/fromdos'        if -x $p.'/fromdos';
    $yuicompr = $p.'/yui-compressor' if -x $p.'/yui-compressor';
    $yuicompr = $p.'/yuicompressor'  if -x $p.'/yuicompressor';
}

my $skip_compress = defined $ENV{THRUK_SKIP_COMPRESS} ? $ENV{THRUK_SKIP_COMPRESS} : 0;

#################################################
# directly use config, otherwise user would be switched when called as root from the Makefile.PL
my $config   = \%Thruk::Config::config;
my $branch   = $config->{'View::TT'}->{'PRE_DEFINE'}->{'filebranch'} ;
die('no config') unless $config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_javascript'};
die('no config') unless $Thruk::Config::VERSION;
die('no config') unless $branch;
my $version = $Thruk::Config::VERSION.'-'.$branch;

#################################################
# check if update is required
my $newest = 0;
for my $file (@{$config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_javascript'}}) {
    my @s   = stat('root/thruk/javascript/'.$file);
    $newest = $s[9] if $newest < $s[9];
}
my $js_required = 1;
if(-e 'root/thruk/javascript/all_in_one-'.$version.'.js') {
    my @s = stat('root/thruk/javascript/all_in_one-'.$version.'.js');
    if($s[9] >= $newest) {
        $js_required = 0;
    }
}

$newest = 0;
for my $file (@{$config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_css_frames'}}) {
    my @s   = stat('themes/themes-available/Thruk/stylesheets/'.$file);
    $newest = $s[9] if $newest < $s[9];
}
my $css_required = 1;
if(-e 'themes/themes-available/Thruk/stylesheets/all_in_one_noframes-'.$version.'.css') {
    my @s = stat('themes/themes-available/Thruk/stylesheets/all_in_one_noframes-'.$version.'.css');
    if($s[9] >= $newest) {
        $css_required = 0;
    }
}

my @panorama_files;
$newest = 0;
require Thruk::Utils::Panorama;
for my $file (@{$config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_javascript_panorama'}}, @{Thruk::Utils::Panorama::get_static_panorama_files({plugin_path => 'plugins/'})}) {
    my @s;
    if($file =~ m/^plugins\//mx) {
        my $tmp = $file;
        $tmp =~ s|plugins/panorama/|plugins/plugins-available/panorama/root/|gmx;
        @s = stat($tmp);
        push @panorama_files, $tmp;
        -f $tmp || die($tmp.": ".$!);
    } else {
        @s = stat('root/thruk/'.$file);
        push @panorama_files, 'root/thruk/'.$file;
    }
    $newest = $s[9] if (@s && $newest < $s[9]);
}
my $panorama_required   = 1;
my $all_in_one_panorama = 'plugins/plugins-available/panorama/root/all_in_one-'.$version.'_panorama.js';
if(-e $all_in_one_panorama) {
    my @s = stat($all_in_one_panorama);
    if($s[9] >= $newest) {
        $panorama_required = 0;
    }
}

if(!$js_required and !$css_required and !$skip_compress and !$panorama_required and (!$ARGV[0] or $ARGV[0] ne '-f')) {
    print STDERR "no update necessary\n";
    exit;
}

#################################################
# required tools available?
unless($skip_compress) {
    if(!$yuicompr) {
        warn("E: yuicompressor not installed, won't compress javascript and stylesheets!") ;
        $skip_compress = 1;
    }
}

#################################################
my $cmds = [
    'cd root/thruk/javascript && cat '.join(' ', @{$config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_javascript'}}).' > all_in_one-'.$version.'.js',
    'cd themes/themes-available/Thruk/stylesheets/ && cat '.join(' ', @{$config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_css_noframes'}}).' > all_in_one_noframes-'.$version.'.css',
    'cd themes/themes-available/Thruk/stylesheets/ && cat '.join(' ', @{$config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_css_frames'}}).' > all_in_one-'.$version.'.css',
    'cat '.join(' ', @panorama_files).' > '.$all_in_one_panorama,
];
if($dos2unix) {
    push @{$cmds}, 'cd root/thruk/javascript && '.$dos2unix.' all_in_one-'.$version.'.js';
    push @{$cmds}, $dos2unix.' '.$all_in_one_panorama;
}
for my $cmd (@{$cmds}) {
    print `$cmd`;
    exit 1 if $? != 0;
}

if($skip_compress) {
    print STDERR "skipping compression\n";
    exit;
}

#################################################
# try to minify css
my $files = [
    'themes/themes-available/Thruk/stylesheets/all_in_one_noframes-'.$version.'.css',
    'themes/themes-available/Thruk/stylesheets/all_in_one-'.$version.'.css',
];
for my $file (@{$files}) {
    my $cmd = $yuicompr.' -o compressed.css '.$file.' && mv compressed.css '.$file;
    print `$cmd`;
    if($? != 0) {
        print STDERR "yui-compressor failed, make sure yui-compressor is installed to create compressed files.\n";
        last;
    }
}
unlink('tmp.css');

#################################################
# try to minify js
my $jsfiles = [
    'root/thruk/javascript/all_in_one-'.$version.'.js',
#    $all_in_one_panorama,
];
for my $file (@{$jsfiles}) {
    my $cmd = $yuicompr.' -o compressed.js '.$file.' && mv compressed.js '.$file;
    print `$cmd`;
    if($? != 0) {
        print STDERR "yui-compressor failed, make sure yui-compressor is installed to create compressed files.\n";
        last;
    }
}
unlink('compressed.js');

exit 0;
