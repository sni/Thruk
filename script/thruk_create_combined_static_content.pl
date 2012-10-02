#!/usr/bin/perl

# create combined javascript/css files
BEGIN {
    $ENV{'THRUK_SRC'} = 'SCRIPTS';
};
use lib 'lib';
use Thruk::Config;

my $dos2unix = "/usr/bin/dos2unix";
$dos2unix    = "/usr/bin/fromdos" if -x "/usr/bin/fromdos";
my $config   = Thruk::Config::get_config();

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

exit 0;
