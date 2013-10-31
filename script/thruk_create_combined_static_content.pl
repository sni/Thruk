#!/usr/bin/env perl

# create combined javascript/css files
BEGIN {
    $ENV{'THRUK_SRC'} = 'SCRIPTS';
};
use lib 'lib';
use Thruk::Config;

my($dos2unix, $yuicompr);
for my $p (reverse split/:/, $ENV{'PATH'}) {
    $dos2unix = $p.'/dos2unix'       if -x $p.'/dos2unix';
    $dos2unix = $p.'/fromdos'        if -x $p.'/fromdos';
    $yuicompr = $p.'/yui-compressor' if -x $p.'/yui-compressor';
    $yuicompr = $p.'/yuicompressor'  if -x $p.'/yuicompressor';
}

unless($ENV{THRUK_SKIP_COMPRESS}) {
    die("dos2unix is required!")      unless $dos2unix;
    die("yuicompressor is required!") unless $yuicompr;
}

#################################################
# directly use config, otherwise user would be switched when called as root from the Makefile.PL
my $config   = \%Thruk::Config::config;
die('no config') unless $config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_javascript'};
die('no config') unless $Thruk::Config::VERSION;

#################################################
my $cmds = [
    'cd root/thruk/javascript && cat '.join(' ', @{$config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_javascript'}}).' > all_in_one-'.$Thruk::Config::VERSION.'.js',
    'cd root/thruk/javascript && '.$dos2unix.' all_in_one-'.$Thruk::Config::VERSION.'.js',
    'cd themes/themes-available/Thruk/stylesheets/ && cat '.join(' ', @{$config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_css_noframes'}}).' > all_in_one_noframes-'.$Thruk::Config::VERSION.'.css',
    'cd themes/themes-available/Thruk/stylesheets/ && cat '.join(' ', @{$config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_css_frames'}}).' > all_in_one-'.$Thruk::Config::VERSION.'.css',
];
for my $cmd (@{$cmds}) {
    print `$cmd`;
    exit 1 if $? != 0;
}

if($ENV{THRUK_SKIP_COMPRESS}) {
    print STDERR "skipping compression upon request\n";
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
my $files = [
    'root/thruk/javascript/all_in_one-'.$Thruk::Config::VERSION.'.js',
];
for my $file (@{$files}) {
    my $cmd = $yuicompr.' -o compressed.js '.$file.' && mv compressed.js '.$file;
    print `$cmd`;
    if($? != 0) {
        print STDERR "yui-compressor failed, make sure yui-compressor is installed to create compressed files.\n";
        last;
    }
}
unlink('compressed.js');

exit 0;
