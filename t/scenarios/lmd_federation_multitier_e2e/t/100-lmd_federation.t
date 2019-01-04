use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 19;
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
            ],
);

TestUtils::test_command({
    cmd     => './script/thruk selfcheck lmd',
    like => ['/lmd running with pid/',
             '/8\/8 backends online/',
            ],
    exit    => 0,
});
