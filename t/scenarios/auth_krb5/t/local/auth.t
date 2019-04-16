use strict;
use warnings;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 60;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# thruk graph commands
#for my $site (qw/local remote/) {
for my $site (qw/local/) {
  for my $hst (qw/pnp grafana/) {
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk graph --host='.$site.'-'.$hst.' --service=Load',
        like => ['/PNG/'],
    });
  }
}

###########################################################
# test thruks authorization
{
    # these should fail
    TestUtils::test_command({
        cmd  => '/usr/bin/env curl -s "http://omd.test.local/demo/grafana/"',
        like => ['/Unauthorized/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env curl -s -b "thruk_auth=test" "http://omd.test.local/demo/grafana/"',
        like => ['/login.cgi\?expired/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env curl -s -b "thruk_auth=test" "http://omd.test.local/demo/thruk/cgi-bin/tac.cgi"',
        like => ['/login.cgi\?expired/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env curl -s -H "X-Thruk-Auth-Key: wrong" "http://omd.test.local/demo/thruk/cgi-bin/tac.cgi"',
        like => ['/wrong authentication key/'],
    });
};

{
    # these should work
    TestUtils::test_command({
        cmd  => '/usr/bin/env curl -s -b "thruk_auth=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" "http://omd.test.local/demo/thruk/cgi-bin/tac.cgi"',
        like => ['/Logged in as <i>omdadmin<\/i>/', '/Tactical Monitoring Overview/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env curl -s -H "X-Thruk-Auth-Key: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" "http://omd.test.local/demo/thruk/cgi-bin/tac.cgi"',
        like => ['/Logged in as <i>omdadmin<\/i>/', '/Tactical Monitoring Overview/'],
    });
    TestUtils::test_command({
        cmd   => '/bin/bash -c "kinit -f omdadmin"',
        like  => ['/Password for omdadmin/'],
        stdin => 'omd',
    });
    # Grafana might take a bit to start
    TestUtils::test_command({
        cmd     => '/bin/bash -c "curl -s --negotiate -u : \'http://omd.test.local/demo/grafana/\'"',
        waitfor => '"login":"omdadmin"',
    });
    TestUtils::test_command({
        cmd  => '/bin/bash -c "curl -s --negotiate -u : \'http://omd.test.local/demo/grafana/\'"',
        like => ['/<title>Grafana<\/title>/', '/"login":"omdadmin"/'],
    });
    TestUtils::test_command({
        cmd  => '/bin/bash -c "curl -s --negotiate -u : \'http://omd.test.local/demo/thruk/cgi-bin/restricted.cgi\'"',
        like => ['/OK: omdadmin/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env curl -s --negotiate -u : "http://omd.test.local/demo/thruk/cgi-bin/tac.cgi"',
        like => ['/Logged in as <i>omdadmin<\/i>/', '/Tactical Monitoring Overview/'],
    });
};
