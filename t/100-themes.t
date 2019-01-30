use strict;
use warnings;
use Test::More;

plan skip_all => 'internal test only'      if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

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
        next if $url =~ m/status.cgi/mx and !-s 'thruk_local.conf';
        TestUtils::test_page(
            'url'     => $url."?theme=".$theme,
        );
    }
}

done_testing();
