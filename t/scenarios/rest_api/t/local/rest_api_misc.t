use warnings;
use strict;
use Test::More;
use utf8;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
plan tests => 20;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

$ENV{'THRUK_TEST_AUTH_KEY'}  = "testkey";
$ENV{'THRUK_TEST_AUTH_USER'} = "omdadmin";

###########################################################
# rest api text transformation
{
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/hosts/localhost?columns=name,calc(rta, "+", 1) as rta_plus&headers=wrapped_json\'',
        like => ['/rta_plus/', '/localhost/', '/"ms"/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/hosts/localhost?columns=name,unit(calc(rta, "*", 1000), "s") as rta_seconds&headers=wrapped_json\'',
        like => ['/rta_seconds/', '/localhost/', '/"s"/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/hosts/localhost?columns=substr(name,0,3)\'',
        like => ['/"loc"/'],
    });
};
