use strict;
use warnings;
use Test::More;

plan skip_all => 'internal test only'      if defined $ENV{'CATALYST_SERVER'};
plan skip_all => 'yui-compressor required' unless -x '/usr/bin/yui-compressor';
plan skip_all => 'csstidy required'        unless -x '/usr/bin/csstidy';

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my @themes = TestUtils::get_themes();

# check if all themes have at least all images from the Classic theme
my @images = glob("./themes/themes-available/Classic/images/*.{png,jpg,gif}");
for my $theme (@themes) {
    for my $img (@images) {
        $img =~ s/.*\///gmx;
        ok(-f "./themes/themes-available/$theme/images/$img", "$img available in $theme");
    }
}

my $pages = [
    '/thruk/main.html',
    '/thruk/side.html',
    '/thruk/cgi-bin/status.cgi',
];

for my $theme (@themes) {
    for my $url (@{$pages}) {
        TestUtils::test_page(
            'url'     => $url."?theme=".$theme,
        );
    }
}


# creating cached js
my $rc1 = system('cd root/thruk/javascript && cat '.join(' ', @{Thruk->config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_javascript'}}).' > /tmp/all_in_one.js');
is($rc1, 0, 'creating tmp js file');

my $rc2 = system('yui-compressor -o /tmp/all_in_one.js2 /tmp/all_in_one.js && mv /tmp/all_in_one.js2 /tmp/all_in_one.js');
is($rc2, 0, 'compressed tmp js file');

is(`diff -bu /tmp/all_in_one.js root/thruk/javascript/all_in_one-$Thruk::VERSION.js`, '', 'all_in_one.js differs');
is(unlink('/tmp/all_in_one.js'), 1, 'remove tmp file');


# creating cached noframed css
my $rc3 = system('cd themes/themes-available/Thruk/stylesheets/ && cat '.join(' ', @{Thruk->config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_css_noframes'}}).' > /tmp/all_in_one_noframes.css');
is($rc3, 0, 'creating tmp css noframes file');

my $rc4 = system('csstidy /tmp/all_in_one_noframes.css --silent=true --optimise_shorthands=2 --template=highest > /tmp/all_in_one_noframes.css2 && mv /tmp/all_in_one_noframes.css2 /tmp/all_in_one_noframes.css');
is($rc4, 0, 'compressed tmp css noframes file');

is(`diff -bu /tmp/all_in_one_noframes.css themes/themes-available/Thruk/stylesheets/all_in_one_noframes-$Thruk::VERSION.css`, '', 'all_in_one_noframes.css differs');
is(unlink('/tmp/all_in_one_noframes.css'), 1, 'remove tmp file');


# creating cached css
my $rc5 = system('cd themes/themes-available/Thruk/stylesheets/ && cat '.join(' ', @{Thruk->config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_css_frames'}}).' > /tmp/all_in_one.css');
is($rc5, 0, 'creating tmp css file');

my $rc6 = system('csstidy /tmp/all_in_one.css --silent=true --optimise_shorthands=2 --template=highest > /tmp/all_in_one.css2 && mv /tmp/all_in_one.css2 /tmp/all_in_one.css');
is($rc6, 0, 'compressed tmp css file');

is(`diff -bu /tmp/all_in_one.css themes/themes-available/Thruk/stylesheets/all_in_one-$Thruk::VERSION.css`, '', 'all_in_one.css differs');
is(unlink('/tmp/all_in_one.css'), 1, 'remove tmp file');

done_testing();
