use strict;
use warnings;
use Test::More tests => 20;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::outagespbimp' }

my $pages = [
    '/outagespbimp',
    '/thruk/cgi-bin/outagespbimp.cgi',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Network Outages problem impacts',
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}
