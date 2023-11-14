use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 27;

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
    TestUtils::test_command({
        cmd     => "/usr/bin/env thruk r '/logs'",
        like    => ['/class/', '/starting/'],
    });
    TestUtils::test_command({
        cmd     => "/usr/bin/env thruk r '/logs?limit=1&plugin_output[ne]='",
    });
    TestUtils::test_command({
        cmd     => "/usr/bin/env thruk r '/logs?limit=1&contact_name[ne]='",
    });
};
