use strict;
use warnings;
use Test::More tests => 10;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

    use_ok 'Thruk::Controller::statusmap';
};

my $pages = [
    '/thruk/cgi-bin/mobile.cgi',
];


for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Mobile Thruk',
        'unlike'  => 'internal server error',
    );
}
