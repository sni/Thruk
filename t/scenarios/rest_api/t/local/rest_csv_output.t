use warnings;
use strict;
use Test::More;
use utf8;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
plan tests => 28;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

$ENV{'THRUK_TEST_AUTH_KEY'}  = "testkey";
$ENV{'THRUK_TEST_AUTH_USER'} = "omdadmin";

###########################################################
# test rest csv output
{
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r -d "plugin_output=öäüß€" /services/localhost/Ping/cmd/process_service_check_result',
        like => ['/Command successfully submitted/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r /csv/services?columns=host_name,description,plugin_output',
        like => ['/localhost;Http/', '/öäüß€/'],
    });
    TestUtils::test_page(
        url  => 'http://localhost/demo/thruk/r/csv/services?columns=host_name,description,plugin_output',
        like => ['localhost;Http', 'öäüß€'],
    );
    # empty csv report
    TestUtils::test_page(
        url  => 'http://localhost/demo/thruk/r/csv/hosts?name=doesnotexist&columns=name&headers=0',
        like => ['^$'],
    );
};
