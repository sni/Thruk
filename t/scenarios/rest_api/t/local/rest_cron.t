use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 12;

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
    like => ['/thruk report/', '/downtimetask/', '/bp all/', '/thruk maintenance/', '/cron\.log/'],
});

###########################################################
