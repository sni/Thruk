use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 18;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# rest error pages
{
    local $ENV{'THRUK_TEST_AUTH_KEY'}  = "testkey";
    TestUtils::test_page(
        url  => 'http://localhost/demo/thruk/r/thruk/whoami',
        like => ['secret key requires'],
        code => 400,
    );
    local $ENV{'THRUK_TEST_AUTH_USER'}  = "omdadmin";
    TestUtils::test_page(
        url  => 'http://localhost/demo/thruk/r/thruk/whoami',
        like => ['"id" : "omdadmin"'],
    );
};
