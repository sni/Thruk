use strict;
use warnings;
use Test::More;
use Data::Dumper;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

BEGIN { use_ok 'Thruk::Controller::statusmap' }

# check if all used images are preloaded
my $page = TestUtils::test_page('url' => '/thruk/cgi-bin/mobile.cgi');

my %preloaded;
if($page->{'content'} =~ m/preloadImages:\s+\[([\s\w\'\/,\-\.]*)/mxi) {
    for my $preload (split/,\s*\n/mx, $1) {
        chomp($preload);
        $preload =~ s/'//gmx;
        $preload =~ s/^\s*//gmx;
        $preload =~ s/\n*//gmx;
        $preloaded{$preload} = 1;
    }
} else {
    BAIL_OUT("did not find any pre loaded images at all");
}

my @matches = $page->{'content'} =~ m/<img[^>]+(src|href)=['|"](.+?)['|"]/gmxi;
my $x=0;
for my $match (@matches) {
    $x++;
    next if $x%2==1;
    is(defined $preloaded{$match}, 1, "$match is preloaded");
}

done_testing();
