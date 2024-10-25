use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 7;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

TestUtils::test_command({
    cmd    => '/usr/bin/env thruk nc runtime tier2a',
    errlike   => ['/tier2a updated runtime sucessfully: OK/'],
});
