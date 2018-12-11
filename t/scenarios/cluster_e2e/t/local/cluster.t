use strict;
use warnings;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 14;

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
