use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 8;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# rest requests with remote url
{
    TestUtils::test_command({
        cmd     => "/thruk/script/thruk -k rest https://localhost/demo/thruk/r/",
        like    => ["/login required/"],
        exit    => 3,
    });
};
