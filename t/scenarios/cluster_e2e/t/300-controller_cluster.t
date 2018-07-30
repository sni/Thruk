use strict;
use warnings;
use Test::More;

BEGIN {
    plan tests => 13;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/extinfo.cgi?type=4&cluster=1',
    'like'    => ['Performance Information', 'Cluster Status', 'accept.png'],
);
