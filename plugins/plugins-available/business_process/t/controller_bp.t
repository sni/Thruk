use strict;
use warnings;
use Test::More tests => 12;
use File::Copy qw/copy/;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###########################################################
# test some pages
my $pages = [
    '/thruk/cgi-bin/bp.cgi',
];

for my $url (@{$pages}) {
    my $test = TestUtils::make_test_hash($url, {'like' => 'Business Process'});
    TestUtils::test_page(%{$test});
}
