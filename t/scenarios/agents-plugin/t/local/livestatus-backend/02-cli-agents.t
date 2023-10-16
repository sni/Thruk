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
plan tests => 65;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
TestUtils::test_command({ cmd => '/usr/bin/env thruk agents -I host-ls --ip=127.0.0.1', like => ['/agent inventory/', '/new\ \->\ on\ |\ agent\ version/'] });
TestUtils::test_command({ cmd => '/usr/bin/env thruk agents -I host-ls', like => ['/no\ new\ checks\ found\ for\ host\ host-ls/'] });
TestUtils::test_command({ cmd => '/usr/bin/env thruk agents -S host-ls', like => ['/agent inventory/'], errlike => ['/host\ host-ls\ has\ not\ yet\ been\ activated/'] });
TestUtils::test_command({ cmd => '/usr/bin/env thruk agents -R', like => ['/Reloading\ naemon\ configuration/'] });
TestUtils::test_command({ cmd => '/usr/bin/env thruk agents -I host-ls', like => ['/no\ new\ checks\ found\ for\ host\ host-ls/'] });
TestUtils::test_page( url => '/thruk/cgi-bin/status.cgi', like => ['agent inventory', 'agent version', 'net eth0'] );
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi', like => ['host-ls'] );

###########################################################
# clean up again
TestUtils::test_command({ cmd => '/usr/bin/env thruk agents -yD host-ls', like => ['/host\ host-ls\ removed\ successsfully/'] });
TestUtils::test_command({ cmd => '/usr/bin/env thruk agents -R', like => ['/Reloading\ naemon\ configuration/'] });
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi', unlike => ['host-ls'] );

###########################################################
