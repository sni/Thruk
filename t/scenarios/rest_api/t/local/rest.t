use strict;
use warnings;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 40;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# test thruks config tool
{
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r -m PATCH -d \'{ "use" : ["generic-service","srv-perf"] }\' /services/localhost/Ping/config',
        like => ['/changed 1 objects successfully./'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r /config/diff',
        like => ['/generic-service,srv-perf/', '/example.cfg/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r -m POST /config/revert',
        like => ['/successfully reverted stashed changes/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r /hosts/totals /services/totals',
        like => ['/"critical_and_unhandled"/', '/"down_and_unhandled"/'],
    });
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
        like    => ['/OK - \d/2 hosts are available/'],
    });
    TestUtils::test_command({
        cmd     => "/thruk/script/check_thruk_rest -o '{STATUS} - {up}/{total} hosts are available' -w up:1:10 -c up:10:20 /hosts/totals",
        like    => ['/CRITICAL - \d/2 hosts are available/'],
        exit    => 2,
    });
    TestUtils::test_command({
        cmd     => "/thruk/script/check_thruk_rest -o '{STATUS} - {up}/{total} hosts are available' -w 1:1 /hosts/totals",
        like    => ['/unknown variable/'],
        exit    => 3,
    });
};
