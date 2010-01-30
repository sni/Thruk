use strict;
use warnings;
use Test::More tests => 20;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::showlog' }

my $pages = [
    '/showlog',
    '/thruk/cgi-bin/showlog.cgi',
    '/thruk/cgi-bin/showlog.cgi?archive=1',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Event Log',
        'unlike'  => 'internal server error',
    );
}
