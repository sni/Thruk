use strict;
use warnings;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 13;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

TestUtils::test_command({
    cmd    => '/usr/bin/env thruk -l',
    like   => ['/tier1a/', '/tier3a/'],
});

TestUtils::test_command({
    cmd    => '/usr/bin/env thruk -b tier3a logcache update ',
    like   => ['/OK\ \-\ imported/'],
});