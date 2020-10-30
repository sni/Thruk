use strict;
use warnings;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 9;

###########################################################
# verify that we use the correct thruk binary
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# thruk cluster commands
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk user.cgi',
    like => ['/Logged\ in\ as.*\(cli\)/', '/authorized_for_admin/'],
});
###########################################################
