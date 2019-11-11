use strict;
use warnings;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 54;

###########################################################
# verify that we use the correct thruk binary
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# thruk cluster commands
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk r /thruk/cluster',
    like => ['/"node_url"/', '/"last_error" : "",/', '/"response_time" : 0./'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk r -m POST /thruk/cluster/heartbeat',
    like => ['/heartbeat send/'],
});

###########################################################
TestUtils::test_command({ cmd  => '/bin/mv .thruk .thruk.off' });
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk cluster status',
    like => ['/OK/', '/nodes online/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk cluster ping',
    like => ['/heartbeat send/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk cluster restart',
    like => ['/all cluster nodes restarted/'],
});

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
    cmd    => '/usr/bin/env thruk cluster unmaint',
    like   => ['/OK\ \-\ removed\ maintenance\ mode/'],
});
TestUtils::test_command({
    cmd    => '/usr/bin/env thruk cluster status',
    like   => ['/OK/', '/nodes online/'],
    unlike => ['/MAINT/'],
});
TestUtils::test_command({ cmd  => '/bin/mv .thruk.off .thruk' });
###########################################################
