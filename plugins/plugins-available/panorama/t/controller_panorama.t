use strict;
use warnings;
use Test::More tests => 13;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

    use_ok 'Thruk::Controller::panorama';
};

my $pages = [
    '/thruk/cgi-bin/panorama.cgi',
];


for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Thruk Panorama',
    );
}
