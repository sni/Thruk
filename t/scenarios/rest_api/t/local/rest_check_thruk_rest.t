use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 30;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# check_thruk_rest plugin
{
    TestUtils::test_command({
        cmd     => '/thruk/script/check_thruk_rest',
        errlike => ['/The check_thruk_rest plugin fetches data/'],
        exit    => 3,
    });
    TestUtils::test_command({
        cmd     => '/thruk/script/check_thruk_rest --help',
        errlike => ['/The check_thruk_rest plugin fetches data/'],
        exit    => 3,
    });
    TestUtils::test_command({
        cmd     => "/thruk/script/check_thruk_rest -o '{STATUS} - {up}/{total} hosts are available' -w up:1:10 -c up:1:10 /hosts/totals",
        like    => ['/OK - \d/3 hosts are available/'],
    });
    TestUtils::test_command({
        cmd     => "/thruk/script/check_thruk_rest -o '{STATUS} - {up}/{total} hosts are available' -w up:1:10 -c up:10:20 /hosts/totals",
        like    => ['/CRITICAL - \d/3 hosts are available/'],
        exit    => 2,
    });
    TestUtils::test_command({
        cmd     => "/thruk/script/check_thruk_rest -o '{STATUS} - {up}/{total} hosts are available' -w 1:1 /hosts/totals",
        like    => ['/unknown variable/'],
        exit    => 3,
    });
    TestUtils::test_command({
        cmd     => "/thruk/script/check_thruk_rest -o '{STATUS} - There are {sessions} active sessions.' --warning=sessions:20 --critical=sessions:30:100 --warning=active:10 --critical=active:10:50 '/thruk/sessions?columns=count(*):sessions,max(active):active&active[gte]=10m'",
        like    => ["/CRITICAL - There are 0 active sessions.|'active'=U;10;10:50;; 'sessions'=0;20;30:100;;/"],
        exit    => 2,
    });
    TestUtils::test_command({
        cmd     => "/thruk/script/check_thruk_rest -k https://localhost/demo/thruk/r/",
        like    => ["/login required/"],
        exit    => 3,
    });
};
