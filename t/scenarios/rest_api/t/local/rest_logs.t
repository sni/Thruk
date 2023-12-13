use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 16;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# /logs rest calls
{
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/logs?limit=5&q=***host_name = "localhost"***\'',
        like => ['/EXTERNAL COMMAND/'],
    });
};

{
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/logs?limit=5&q=***host_name = "localhost" AND time > -24h***\'',
        like => ['/EXTERNAL COMMAND/'],
    });
};

{
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/logs?limit=5&q=***host_name != "" AND time > -24h***\'',
        like => ['/EXTERNAL COMMAND/'],
    });
};
