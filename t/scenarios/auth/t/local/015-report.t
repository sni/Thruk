use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 13;

###########################################################
# verify that we use the correct thruk binary
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# run example report
{
    local $ENV{'THRUK_CRON'} = 1;
    my $test = {
        cmd  => '/usr/bin/env thruk report 1',
        like => ['/^$/'],
    };
    TestUtils::test_command($test);

    ok(-f 'var/thruk/reports/1.dat', "pdf created");

    $test = {
        cmd  => '/usr/bin/env file var/thruk/reports/1.dat',
        like => ['/PDF/'],
    };
    TestUtils::test_command($test);
}
