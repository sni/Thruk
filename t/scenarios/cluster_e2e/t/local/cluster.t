use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 88;

###########################################################
# verify that we use the correct thruk binary
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# check cron entries
TestUtils::test_command({
    cmd  => '/usr/bin/env crontab -l | grep thruk',
    like => ['/heartbeat/', '/downtimetask/', '/bp all/', '/thruk maintenance/', '/cron\.log/'],
});

###########################################################
# thruk cluster commands
TestUtils::test_command({ cmd  => '/bin/mv .thruk .thruk.off' });
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk r -m POST /thruk/cluster/heartbeat',
    like => ['/heartbeat send/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk r /thruk/cluster',
    like => ['/"node_url"/', '/"last_error" : "",/', '/"response_time" : 0./'],
});

###########################################################
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk cluster status',
    like => ['/OK/', '/nodes online/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk cluster ping',
    like => ['/heartbeat send/'],
});

###########################################################
# maint mode
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk cluster maint',
    like => ['/OK/', '/set\ into\ maintenance\ mode/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk cluster status',
    like => ['/OK/', '/nodes online/', '/MAINT/'],
});
TestUtils::test_command({
    cmd     => '/usr/bin/env omd stop',
    like    => ['/Stopping.*OK/'],
    errlike => ['/.*/'],
});
TestUtils::test_command({
    cmd    => '/usr/bin/env omd umount',
    like   => ['/Cleaning\ up\ temp\ filesystem/'],
});
TestUtils::test_command({
    cmd    => '/usr/bin/env omd start',
    like   => ['/Preparing\ tmp\ directory/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/env curl -s "http://localhost/demo/thruk/cgi-bin/remote.cgi?lb_ping"',
    like => ['/MAINTENANCE/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk cluster ping',
    like => ['/heartbeat send/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk cluster status',
    like => ['/OK/', '/nodes online/', '/MAINT/'],
});
TestUtils::test_command({
    cmd    => '/usr/bin/env thruk cluster unmaint',
    like   => ['/OK\ \-\ removed\ maintenance\ mode/'],
});
TestUtils::test_command({
    cmd    => '/usr/bin/env thruk cluster status',
    like   => ['/OK/', '/nodes online/'],
    unlike => ['/MAINT/'],
});

###########################################################
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk cluster restart',
    like => ['/all cluster nodes restarted/'],
});
TestUtils::test_command({ cmd  => '/bin/mv .thruk.off .thruk' });
###########################################################
