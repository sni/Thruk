use strict;
use warnings;
use Test::More tests => 14;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::summary' }

my $pages = [
# Step 1
    '/summary',
    '/thruk/cgi-bin/summary.cgi',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Alert Summary Report',
        'unlike'  => 'internal server error',
    );
}
