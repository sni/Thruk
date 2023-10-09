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
plan tests => 138;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# create example host
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi', like => ['Agents', 'Items Displayed'] );
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi?action=new', like => ['Add Agent', 'Save Changes'] );
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi?action=scan',
        post => {
            'type'     => 'snclient',
            'ip'       => '127.0.0.1',
            'hostname' => 'host-ls',
            'backend'  => 'demo',
        },
        like => ['"ok" : 1'],
);
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi?action=edit&hostname=host-ls&backend=demo', like => ['agent inventory', 'agent version', 'net eth0'] );
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi?action=save',
        post => {
            'type'            => 'snclient',
            'ip'              => '127.0.0.1',
            'hostname'        => 'host-ls',
            'backend'         => 'demo',
            'check.version'   => 'on',
            'check.inventory' => 'on',
            'check.cpu'       => 'on',
            'check.memory'    => 'on',
            'check.net.eth0'  => 'on',
            'check.disk./'    => 'on',
        },
        redirect => 1,
        location => "/thruk/cgi-bin/agents.cgi"
);
TestUtils::test_page( url => '/thruk/cgi-bin/conf.cgi',
        post => {
            'reload' => 'yes',
            'apply'  => 'yes',
            'sub'    => 'objects',
        },
        like => ['Reloading naemon configuration'],
);

TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi', like => ['host-ls'] );
TestUtils::test_command({ cmd => '/usr/bin/env thruk agents check inventory host-ls', like => ['/inventory\ unchanged/', '/unwanted\ checks/'] });
TestUtils::test_page( url => '/thruk/cgi-bin/status.cgi', like => ['agent inventory', 'agent version', 'net eth0'] );

# cleanup again
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi?action=remove',
        post => {
            'hostname'        => 'host-ls',
            'backend'         => 'demo',
        },
        redirect => 1,
        location => "/thruk/cgi-bin/agents.cgi"
);

TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi', like => ['Activate Changes'] );
TestUtils::test_page( url => '/thruk/cgi-bin/conf.cgi',
        post => {
            'reload' => 'yes',
            'apply'  => 'yes',
            'sub'    => 'objects',
        },
        like => ['Reloading naemon configuration'],
);
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi', unlike => ['host-ls'] );

###########################################################
