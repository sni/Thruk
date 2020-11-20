use strict;
use warnings;
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
# test thruk logcache example
{
    TestUtils::test_command({
        cmd     => "/usr/bin/env thruk logcache import -q -y",
        like    => [qr(\QOK - imported\E)],
    });
    TestUtils::test_command({
        cmd     => "/thruk/examples/get_logs var/log/naemon.log",
        like    => ['/^$/'],
    });
    TestUtils::test_command({
        cmd     => "/thruk/examples/get_logs var/log/naemon.log -n",
        like    => ['/^$/'],
    });
};
