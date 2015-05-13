use strict;
use warnings;
use Data::Dumper;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan tests => 86;
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
    skip 'external tests', 16 if defined $ENV{'CATALYST_SERVER'};

    for my $url (@{$redirects}) {
        TestUtils::test_page(
            'url'      => $url,
            'redirect' => 1,
        );
    }
};

for my $url (@{$pages}) {
    SKIP: {
        skip 'external tests', 13 if defined $ENV{'CATALYST_SERVER'} and $url eq '/thruk/';

        TestUtils::test_page(
            'url'          => $url,
            'content_type' => $url =~ m/startup/ ? 'text/html' : undef,
        );
    };
}
