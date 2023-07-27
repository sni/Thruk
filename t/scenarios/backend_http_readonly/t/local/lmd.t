use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 35;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
{
    # enable LMD
    TestUtils::test_command({
        cmd    => "/bin/sed -i etc/thruk/thruk_local.d/lmd.conf -e 's/#use_lmd_core=.*/use_lmd_core=1/g'",
        like   => ['/^$/'],
    });
    # start LMD
    TestUtils::test_command({
        cmd    => '/usr/bin/env omd start lmd',
        like   => ['/starting lmd.*ok/i'],
    });

    # wait till backends are online
    TestUtils::test_command({
        cmd     => '/usr/bin/env thruk -l',
        waitfor => 'backend1.*OK\s+',
    });

    # do some tests
    TestUtils::test_command({
        cmd    => '/usr/bin/env thruk r /hosts/localhost',
        like   => ['/accept_passive_checks/', '/acknowledged/'],
    });
    TestUtils::test_command({
        cmd    => '/usr/bin/env thruk r -m POST /hosts/localhost/cmd/schedule_forced_host_check',
        like   => ['/sending command failed/', '/permission denied - sending commands requires admin permissions/'],
        exit   => 3,
    });

    # stop LMD
    TestUtils::test_command({
        cmd    => '/usr/bin/env omd stop lmd',
        like   => ['/stopping lmd.*ok/i'],
    });
    # disable LMD
    TestUtils::test_command({
        cmd    => "/bin/sed -i etc/thruk/thruk_local.d/lmd.conf -e 's/use_lmd_core=.*/#use_lmd_core=1/g'",
        like   => ['/^$/'],
    });
}
