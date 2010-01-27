use strict;
use warnings;
use Test::More tests => 22;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::history' }

my $pages = [
    '/history',
    '/thruk/cgi-bin/history.cgi',
    '/thruk/cgi-bin/history.cgi?host=all',
    '/thruk/cgi-bin/history.cgi?host=unknownhost',
    '/thruk/cgi-bin/history.cgi?host=unknownhost&service=unknownservice',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Alert History',
        'unlike'  => 'internal server error',
    );
}
