use warnings;
use strict;
use Test::More;

plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use Thruk::Base ();
use Thruk::Utils::IO ();

my @themes = TestUtils::get_themes();

# check if all themes have at least all images from the Light theme
my @images = glob("./themes/themes-available/Light/images/*.{png,jpg,gif}");
ok(scalar @images > 5, 'Light theme has some images');
for my $theme (@themes) {
    for my $img (@images) {
        $img =~ s/.*\///gmx;
        ok(-f "./themes/themes-available/$theme/images/$img", "$img available in $theme");
    }
}

my $pages = [
    '/thruk/main.html',
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

# check if the Dark theme has all color defintions from the base file
my $colors = getColors("themes/base.css");
ok(scalar keys %{$colors} > 5, 'got some colors from the base.css');
for my $theme (@themes) {
    next if $theme eq 'Light';

    my $themeColors = getColors("./themes/themes-available/".$theme."/src/".$theme.".css");
    for my $col (sort keys %{$colors}) {
        ok(exists $themeColors->{$col}, "color $col exists in $theme");
    }
}

done_testing();


###########################################################
sub getColors {
    my($file) = @_;
    my $src    = Thruk::Utils::IO::read($file);
    my @colors = ($src =~ m/^\s+\-\-([\S\-]+):\s+/gmx);
    return(Thruk::Base::array2hash(\@colors));
}
