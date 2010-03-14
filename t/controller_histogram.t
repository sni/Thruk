use strict;
use warnings;
use Test::More tests => 16;


BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::histogram' }

my $pages = [
# Step 1
    '/histogram',
    '/thruk/cgi-bin/histogram.cgi',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Host and Service Alert Histogram',
        'unlike'  => 'internal server error',
    );
}
