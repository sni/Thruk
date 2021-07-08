use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 9;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# misc rest pages
{
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r /hosts/totals /services/totals',
        like => ['/"critical_and_unhandled"/', '/"down_and_unhandled"/'],
    });
};
