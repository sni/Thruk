#!/usr/bin/perl

# create combined javascript/css files
use Thruk;

my $cmds = [
    'cd root/thruk/javascript && cat '.join(' ', @{Thruk->config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_javascript'}}).' > all_in_one-'.$Thruk::VERSION.'.js',
    'cd themes/themes-available/Thruk/stylesheets/ && cat '.join(' ', @{Thruk->config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_css_noframes'}}).' > all_in_one_noframes-'.$Thruk::VERSION.'.css',
    'cd themes/themes-available/Thruk/stylesheets/ && cat '.join(' ', @{Thruk->config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_css_frames'}}).' > all_in_one-'.$Thruk::VERSION.'.css',
];
for my $cmd (@{$cmds}) {
    print `$cmd`;
    exit 1 if $? != 0;
}

exit 0;
