use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 41;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# testuser gets its roles from contact group
{
    TestUtils::test_command({
        cmd    => '/usr/bin/env thruk cache clean',
        like   => ['/cache cleared/'],
    });
    TestUtils::test_command({
        cmd    => '/usr/bin/env omd reload apache',
        like   => ['/Reloading apache/'],
    });
    sleep(3);
    TestUtils::test_command({
        cmd    => '/usr/bin/env thruk cache dump',
        like   => ['/\{\}/'],
        unlike => ['/testuser/'],
    });
    TestUtils::test_command({
        cmd    => '/usr/bin/env curl -s -u testuser:testuser http://localhost/demo/thruk/r/hosts',
        like   => ['/localhost/'],
        unlike => ['/^\[\]/'],
    });
    TestUtils::test_command({
        cmd    => '/usr/bin/env curl -s -u testuser:testuser -X POST http://localhost/demo/thruk/r/hosts/localhost/cmd/schedule_forced_host_check',
        like   => ['/successfully/'],
        unlike => ['/failed/'],
    });
    TestUtils::test_command({
        cmd    => '/usr/bin/env thruk cache dump',
        like   => ['/global/', '/testgroup/', '/admin/'],
    });
    TestUtils::test_command({
        cmd    => '/usr/bin/env curl -s -u testuser:testuser http://localhost/demo/thruk/r/services/localhost/Disk%20%2F/config',
        like   => ['/example.cfg:/'],
    });
    TestUtils::test_command({
        cmd    => '/usr/bin/env curl -s -u testuser:testuser http://localhost:5000/demo/thruk/r/services/localhost/Disk%20%2F/config',
        like   => ['/example.cfg:/'],
    });
}
