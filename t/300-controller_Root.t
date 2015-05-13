use strict;
use warnings;
use Data::Dumper;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 85;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::Root' }

my $redirects = [
    '/',
    '/thruk',
];
my $pages = [
    '/thruk/',
    '/thruk/docs/index.html',
    '/thruk/index.html',
    '/thruk/main.html',
    '/thruk/side.html',
    '/thruk/startup.html',
];

SKIP: {
    skip 'external tests', 16 if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

    for my $url (@{$redirects}) {
        TestUtils::test_page(
            'url'      => $url,
            'redirect' => 1,
        );
    }
};

for my $url (@{$pages}) {
    SKIP: {
        skip 'external tests', 13 if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'} and $url eq '/thruk/';

        TestUtils::test_page(
            'url'      => $url,
        );
    };
}
