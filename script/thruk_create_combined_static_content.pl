#!/usr/bin/perl

# create combined javascript/css files
BEGIN {
    $ENV{'THRUK_SRC'} = 'SCRIPTS';
};
use lib 'lib';
use Thruk::Config;

my $dos2unix = "/usr/bin/dos2unix";
$dos2unix    = "/usr/bin/fromdos"        if -x "/usr/bin/fromdos";
$dos2unix    = "/opt/local/bin/dos2unix" if -x "/opt/local/bin/dos2unix";
my $config   = Thruk::Config::get_config();

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

#################################################
# try to minify css
my $files = [
    'themes/themes-available/Thruk/stylesheets/all_in_one_noframes-'.$Thruk::Config::VERSION.'.css',
    'themes/themes-available/Thruk/stylesheets/all_in_one-'.$Thruk::Config::VERSION.'.css',
];
for my $file (@{$files}) {
    my $cmd = 'yui-compressor -o compressed.css '.$file.' && mv compressed.css '.$file;
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
    my $cmd = 'yui-compressor -o compressed.js '.$file.' && mv compressed.js '.$file;
    print `$cmd`;
    if($? != 0) {
        print STDERR "yui-compressor failed, make sure yui-compressor is installed to create compressed files.\n";
        last;
    }
}
unlink('compressed.js');

exit 0;
