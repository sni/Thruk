use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 36;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::Root' }

my $redirects = [
    '/',
];
my $pages = [
    '/thruk',
    '/thruk/',
    '/thruk/docs/index.html',
    '/thruk/index.html',
    '/thruk/main.html',
    '/thruk/side.html',
];

for my $url (@{$redirects}) {
    TestUtils::test_page(
        'url'      => $url,
        'redirect' => 1,
    );
}

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'unlike'  => 'internal server error',
    );
}
