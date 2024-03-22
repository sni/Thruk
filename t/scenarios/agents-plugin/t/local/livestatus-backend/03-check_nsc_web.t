use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

$ENV{'THRUK_TEST_AUTH'}               = 'omdadmin:omd';
$ENV{'PLACK_TEST_EXTERNALSERVER_URI'} = 'http://127.0.0.1/demo';
plan tests => 31;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
for my $cmd ('./lib/monitoring-plugins/check_nsc_web', '/usr/bin/snclient run check_nsc_web', './bin/mod_gearman_worker testcmd -- ../check_nsc_web') {
    TestUtils::test_command({ cmd => '/usr/bin/env '.$cmd.' -k -p test -u https://127.0.0.1:8443', like => ['/OK - REST API reachable/'] });
    TestUtils::test_command({ cmd => '/usr/bin/env '.$cmd.' -k -p test -u https://127.0.0.1:8443 check_snclient_version', like => ['/SNClient/', '/Build:/'] });
}

###########################################################
