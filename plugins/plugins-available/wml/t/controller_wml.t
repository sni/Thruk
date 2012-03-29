use strict;
use warnings;
use Test::More tests => 34;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

    use_ok 'Thruk::Controller::wml';
};

my $pages = [
    '/thruk/cgi-bin/statuswml.cgi',
    '/thruk/cgi-bin/statuswml.cgi?style=uprobs',
    '/thruk/cgi-bin/statuswml.cgi?style=aprobs',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'            => $url,
        'like'           => [ 'WML Thruk' ],
        'unlike'         => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}

