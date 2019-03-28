use strict;
use warnings;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 17;

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
};
