use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 26;

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
    like => ['/thruk maintenance/', '/cron\.log/'],
});

###########################################################
# remove cron entries
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk cron uninstall',
    like => ['/cron entries removed/'],
});

###########################################################
# cron should not contain thruk entries
TestUtils::test_command({
    cmd  => '/usr/bin/env crontab -l | grep thruk | grep -v ^PATH | grep -v ^#',
    like => ['/^$/'],
    exit => 1,
});

###########################################################
# restore cron entries
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk cron install',
    like => ['/updated cron entries/'],
});

###########################################################
# check cron entries
TestUtils::test_command({
    cmd  => '/usr/bin/env crontab -l | grep thruk',
    like => ['/thruk maintenance/', '/cron\.log/'],
});

###########################################################