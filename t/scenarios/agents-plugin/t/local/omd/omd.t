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
plan tests => 143;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# initialize object configs
TestUtils::test_command({ cmd => '/usr/bin/env thruk r -d "" /config/check', like => ['/Running\ configuration\ check/'] });

###########################################################
# create example host
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi', like => ['Agents', 'Items Displayed'], waitfor => 'Items Displayed', follow => 1 );
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi', like => ['Agents', 'Items Displayed'] );
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi?action=new', like => ['Add Agent', 'Save Changes'] );
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi?action=scan',
        post => {
            'type'     => 'snclient',
            'ip'       => '127.0.0.1',
            'hostname' => 'host-http',
            'backend'  => 'http',
        },
        like => ['"ok" : 1'],
);
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi?action=edit&hostname=host-http&backend=http', like => ['agent inventory', 'agent version', 'net eth0'] );
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi?action=save',
        post => {
            'type'            => 'snclient',
            'ip'              => '127.0.0.1',
            'hostname'        => 'host-http',
            'backend'         => 'http',
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

TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi', like => ['host-http'] );
# force reschedule
TestUtils::test_page( url     => '/thruk/r/services/host-http/agent%20inventory/cmd/schedule_forced_svc_check',
        post    => { start_time => 'now' },
        like    => ['Command successfully submitted'],
);
TestUtils::test_page( url     => '/thruk/cgi-bin/extinfo.cgi?type=2&host=host-http&service=agent+inventory',
        like    => ['Service.*agent inventory.*on'],
        waitfor => 'inventory unchanged|could re-apply defaults',
);

TestUtils::test_page( url => '/thruk/cgi-bin/status.cgi', like => ['agent inventory', 'agent version', 'net eth0'] );

# cleanup again
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi?action=remove',
        post => {
            'hostname'        => 'host-http',
            'backend'         => 'http',
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
TestUtils::test_page( url => '/thruk/cgi-bin/agents.cgi', unlike => ['host-http'] );

###########################################################
