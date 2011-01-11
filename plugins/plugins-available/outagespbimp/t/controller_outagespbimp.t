use strict;
use warnings;
use Test::More tests => 20;

use Catalyst::Test 'Thruk';

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
};

use_ok 'Thruk::Controller::outagespbimp';

my $side = TestUtils::test_page(
    'url' => '/thruk/side.html',
);

SKIP: {
    skip("plugin not enabled", 13) unless $side->{'content'} =~ m/Root\ problems/mx;
    my $pages = [
        '/outagespbimp',
        '/thruk/cgi-bin/outagespbimp.cgi',
    ];

    for my $url (@{$pages}) {
        TestUtils::test_page(
            'url'     => $url,
            'like'    => 'Problems and impacts',
            'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
        );
    }
}