use strict;
use warnings;
use Test::More tests => 9;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

BEGIN { use_ok 'Thruk::Controller::statusmap' }

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
