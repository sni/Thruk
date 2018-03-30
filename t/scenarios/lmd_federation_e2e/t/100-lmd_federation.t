use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 30;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

TestUtils::test_page(
    'url'    => '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail',
    'like'   => [
                '"total":8', '"disabled":0', '"up":8', ,'"down":0',
                ">demo<",  "host=demo&amp;backend=demoid",
                ">demo2<", "host=demo2&amp;backend=omddemo2id",
                ">demo3<", "host=demo3&amp;backend=omddemo3id",
                ">demo4<", "host=demo4&amp;backend=omddemo4id",
                ">demo<",  "host=demo&amp;backend=demoid",
                ">demo2<", "host=demo2&amp;backend=slowdemo2id",
                ">demo3<", "host=demo3&amp;backend=slowdemo3id",
                ">demo4<", "host=demo4&amp;backend=slowdemo4id",
            ],
);
