use strict;
use warnings;
use Test::More tests => 687;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my @themes = TestUtils::get_themes();

# check if all themes have at least all images from the Classic theme
my @images = glob("./root/thruk/themes/Classic/images/*.{png,jpg,gif}");
for my $theme (@themes) {
    for my $img (@images) {
        $img =~ s/.*\///gmx;
        ok(-f "./root/thruk/themes/$theme/images/$img", "$img available in $theme");
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
            'unlike'  => 'internal server error',
        );
    }
}

