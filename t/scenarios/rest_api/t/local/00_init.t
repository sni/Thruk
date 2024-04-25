use warnings;
use strict;
use Test::More;
use utf8;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
plan tests => 15;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

$ENV{'THRUK_TEST_AUTH_KEY'}  = "testkey";
$ENV{'THRUK_TEST_AUTH_USER'} = "omdadmin";

###########################################################
# some tests require non-pending services
TestUtils::test_command({
    cmd     => '/thruk/support/reschedule_all_checks.sh',
    like    => ['/OK/', '/successfully submitted/'],
});
TestUtils::test_command({
    cmd     => '/usr/bin/env thruk -A omdadmin url "status.cgi?host=all&servicestatustypes=1&style=detail"',
    like    => ['/Current Network Status/'],
    waitfor => '0\ Items\ Displayed',
});

###########################################################
