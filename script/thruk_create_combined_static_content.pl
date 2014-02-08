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
die('no config') unless $config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_javascript'};
die('no config') unless $Thruk::Config::VERSION;

#################################################
# check if update is required
my $newest = 0;
for my $file (@{$config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_javascript'}}) {
    my @s   = stat('root/thruk/javascript/'.$file);
    $newest = $s[9] if $newest < $s[9];
}
my $js_required = 1;
if(-e 'root/thruk/javascript/all_in_one-'.$Thruk::Config::VERSION.'.js') {
    my @s = stat('root/thruk/javascript/all_in_one-'.$Thruk::Config::VERSION.'.js');
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
if(-e 'themes/themes-available/Thruk/stylesheets/all_in_one_noframes-'.$Thruk::Config::VERSION.'.css') {
    my @s = stat('themes/themes-available/Thruk/stylesheets/all_in_one_noframes-'.$Thruk::Config::VERSION.'.css');
    if($s[9] >= $newest) {
        $css_required = 0;
    }
}

if(!$js_required and !$css_required) {
    exit;
}

#################################################
# required tools available?
unless($ENV{THRUK_SKIP_COMPRESS}) {
    if(!$yuicompr) {
        warn("E: yuicompressor not installed, won't compress javascript and stylesheets!") ;
        $skip_compress = 1;
    }
}

#################################################
my $cmds = [
    'cd root/thruk/javascript && cat '.join(' ', @{$config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_javascript'}}).' > all_in_one-'.$Thruk::Config::VERSION.'.js',
    'cd themes/themes-available/Thruk/stylesheets/ && cat '.join(' ', @{$config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_css_noframes'}}).' > all_in_one_noframes-'.$Thruk::Config::VERSION.'.css',
    'cd themes/themes-available/Thruk/stylesheets/ && cat '.join(' ', @{$config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_css_frames'}}).' > all_in_one-'.$Thruk::Config::VERSION.'.css',
];
push @{$cmds}, 'cd root/thruk/javascript && '.$dos2unix.' all_in_one-'.$Thruk::Config::VERSION.'.js' if $dos2unix;
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
    'themes/themes-available/Thruk/stylesheets/all_in_one_noframes-'.$Thruk::Config::VERSION.'.css',
    'themes/themes-available/Thruk/stylesheets/all_in_one-'.$Thruk::Config::VERSION.'.css',
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
    'root/thruk/javascript/all_in_one-'.$Thruk::Config::VERSION.'.js',
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
