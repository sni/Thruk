use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 33;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

TestUtils::test_page(
    'url'    => '/thruk/cgi-bin/status.cgi?hostgroup=all&style=hostdetail',
    'like'   => [
                '"total":7', '"disabled":0', '"up":7', ,'"down":0',
                ">demo<",  "host=demo&amp;backend=demodirectlivestatusid",
                ">demo2<", "host=demo2&amp;backend=demo2id",
                ">demo3<", "host=demo3&amp;backend=demo3id",
                ">demo4<", "host=demo4&amp;backend=demo4id",
                ">demo5<", "host=demo5&amp;backend=demo5id",
                ">demo6<", "host=demo6&amp;backend=demo6id",
                ">demo7<", "host=demo7&amp;backend=demo7id",
            ],
);

TestUtils::test_command({
    cmd     => './script/thruk selfcheck lmd',
    like => ['/lmd running with pid/',
             '/7\/7 backends online/',
            ],
    exit    => 0,
});