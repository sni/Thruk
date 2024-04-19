use warnings;
use strict;
use Test::More;

BEGIN {
    plan tests => 17;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

###########################################################
my($host,$service) = TestUtils::get_test_service();

###########################################################
# force reschedule so we get some performance data
TestUtils::test_page(
    url     => '/thruk/r/hosts/'.$host.'/cmd/schedule_forced_host_check',
    post    => { start_time => 'now' },
    like    => ['Command successfully submitted'],
);
TestUtils::test_page(
    url     => '/thruk/r/services/'.$host.'/'.$service.'/cmd/schedule_forced_svc_check',
    post    => { start_time => 'now' },
    like    => ['Command successfully submitted'],
);

###########################################################
