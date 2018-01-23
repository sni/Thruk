use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 22;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

TestUtils::test_page(
    'url'    => '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail',
    'like'   => [
                '"total":4', '"disabled":0', '"up":4', ,'"down":0',
                ">demo<",  "host=demo&amp;backend=demoid",
                ">demo2<", "host=demo2&amp;backend=demo2id",
                ">demo3<", "host=demo3&amp;backend=demo3id",
                ">demo4<", "host=demo4&amp;backend=demo4id",
            ],
);
