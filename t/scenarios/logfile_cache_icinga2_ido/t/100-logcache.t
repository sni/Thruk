use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s ($ENV{'THRUK_CONFIG'} || '.').'/thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
    $ENV{'THRUK_TEST_CMD_NO_LOG'} = 1;
}
BEGIN { use_ok 'Thruk::Controller::notifications' }

###########################################################
# import logs
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/showlog.cgi',
    'follow'  => 1,
    'like'    => [],
);
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/showlog.cgi',
    'like'    => [],
    'waitfor' => 'SERVICE\ ALERT',
);

TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/showlog.cgi',
    'like'    => ["Event Log", "SERVICE ALERT:", "Matching Log Entries Displayed"],
);

###########################################################
# import tests require non-pending hosts
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/cmd.cgi',
    'post'    => { cmd_mod => 2, cmd_typ => 96, host => 'host-host1', start_time => 'now' , force_check => 1 },
    'like'    => ['Your command request was successfully submitted'],
);
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/status.cgi?host=host-host1&style=hostdetail&hoststatustypes=1',
    'like'    => ['Current Network Status', 'Host Status Details'],
    'waitfor' => '0\ Matching\ Host\ Entries',
);

# cannot determine fixed number of tests, number depends on wether initial import redirects or not,
# which depends on machine load and speed (initial import redirects after 10 seconds)
done_testing();
