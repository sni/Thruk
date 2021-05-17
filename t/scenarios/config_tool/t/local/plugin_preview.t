use warnings;
use strict;
use Test::More;

plan tests => 24;

BEGIN {
    $ENV{'THRUK_TEST_CONF_NO_LOG'} = 1;
    $ENV{'THRUK_AUTHOR'} = 1;
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###########################################################
# verify that we use the correct thruk binary
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# initialize object config
my $curl = '/usr/bin/env curl -s -u omdadmin:omd';
TestUtils::test_command({
    cmd    => $curl.' http://localhost/demo/thruk/cgi-bin/conf.cgi?sub=objects',
    like   => [ '/Config Tool/', '/obj_retention\..*\.dat/' ],
});

###########################################################
# get command details
TestUtils::test_command({
    cmd    => $curl.' -d action=json -d command=check-host-alive -d type=commanddetails -X POST http://localhost/demo/thruk/cgi-bin/conf.cgi',
    like   => [ '/cmd_line/', '/check_icmp/' ],
});

###########################################################
# get plugin help
TestUtils::test_command({
    cmd    => $curl.' -d action=json -d plugin=check-host-alive -d type=pluginhelp -X POST http://localhost/demo/thruk/cgi-bin/conf.cgi',
    like   => ['/specify a target/', '/number of alive hosts required for success/' ],
});

###########################################################
# get command preview
TestUtils::test_command({
    cmd    => $curl.' -d action=json -d command=check_ping -d args="1000,20%!2000,30%" -d host=localhost -d service=Ping -d type=pluginpreview -X POST http://localhost/demo/thruk/cgi-bin/conf.cgi',
    like   => ['/PING OK - Packet loss/', '/rta=/' ],
});
