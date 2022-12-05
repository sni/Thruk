use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 85;

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
    `/usr/bin/printf "export THRUK_TEST_NO_LOG=.\n" >> .thruk`; # do not errors for the next requests
    TestUtils::test_command({
        cmd  => '/usr/bin/env omd reload apache',
        like => ['/Reloading dedicated Apache/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env curl -s -H "X-Thruk-Auth-Key: wrong" "http://omd.test.local/demo/thruk/cgi-bin/tac.cgi"',
        like => ['/wrong authentication key/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env curl -s -b "thruk_auth=test" "http://omd.test.local/demo/thruk/r/thruk/whoami"',
        like => ['/login.cgi\?expired/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env curl -s -H "X-Thruk-Auth-Key: wrong" "http://omd.test.local/demo/thruk/r/thruk/whoami"',
        like => ['/wrong authentication key/'],
    });
    `>.thruk`; # clear skipping log
    TestUtils::test_command({
        cmd  => '/usr/bin/env omd reload apache',
        like => ['/Reloading dedicated Apache/'],
    });
};

{
    # these should work
    TestUtils::test_command({
        cmd  => '/usr/bin/env curl -s -b "thruk_auth=bec648c310a161e8610bd62d66c4d9eeb2caff68ee5a3a98910d29e0389013cd_1" "http://omd.test.local/demo/thruk/cgi-bin/tac.cgi"',
        like => ['/>User<.*?>omdadmin</', '/Tactical Monitoring Overview/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env curl -s -H "X-Thruk-Auth-Key: ff8cde7bc92c261a260a180ef4d35c456853b70d955c3eb1c41098d0d561268b_1" "http://omd.test.local/demo/thruk/cgi-bin/tac.cgi"',
        like => ['/>User<.*?>omdadmin</', '/Tactical Monitoring Overview/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env curl -s -H "X-Thruk-Auth-Key: ff8cde7bc92c261a260a180ef4d35c456853b70d955c3eb1c41098d0d561268b_1" "http://omd.test.local/demo/thruk/r/thruk/whoami"',
        like => ['/has_thruk_profile/'],
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
        like => ['/>User<.*?>omdadmin</', '/Tactical Monitoring Overview/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env curl -s --negotiate -u : "http://omd.test.local/demo/thruk/r/thruk/whoami"',
        like => ['/"id" : "omdadmin"/'],
    });
};
