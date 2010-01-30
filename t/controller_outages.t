use strict;
use warnings;
use Test::More tests => 14;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::outages' }

my $pages = [
    '/outages',
    '/thruk/cgi-bin/outages.cgi',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Network Outages',
        'unlike'  => 'internal server error',
    );
}
