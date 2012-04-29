use strict;
use warnings;
use Test::More;

plan skip_all => 'internal test only' if defined $ENV{'CATALYST_SERVER'};

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


# creating cached css/ js
my $rc1 = system('cd root/thruk/javascript && cat '.join(' ', @{Thruk->config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_javascript'}}).' > /tmp/all_in_one.js');
is($rc1, 0, 'creating tmp js file');
is(`diff -bu /tmp/all_in_one.js root/thruk/javascript/all_in_one-$Thruk::VERSION.js`, '', 'all_in_one.js differs');
is(unlink('/tmp/all_in_one.js'), 1, 'remove tmp file');

my $rc2 = system('cd themes/themes-available/Thruk/stylesheets/ && cat '.join(' ', @{Thruk->config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_css_noframes'}}).' > /tmp/all_in_one_noframes.css');
is($rc2, 0, 'creating tmp css noframes file');
is(`diff -bu /tmp/all_in_one_noframes.css themes/themes-available/Thruk/stylesheets/all_in_one_noframes-$Thruk::VERSION.css`, '', 'all_in_one_noframes.css differs');
is(unlink('/tmp/all_in_one_noframes.css'), 1, 'remove tmp file');

my $rc3 = system('cd themes/themes-available/Thruk/stylesheets/ && cat '.join(' ', @{Thruk->config->{'View::TT'}->{'PRE_DEFINE'}->{'all_in_one_css_frames'}}).' > /tmp/all_in_one.css');
is($rc3, 0, 'creating tmp css file');
is(`diff -bu /tmp/all_in_one.css themes/themes-available/Thruk/stylesheets/all_in_one-$Thruk::VERSION.css`, '', 'all_in_one.css differs');
is(unlink('/tmp/all_in_one.css'), 1, 'remove tmp file');

done_testing();
