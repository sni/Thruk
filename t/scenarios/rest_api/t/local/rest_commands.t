use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 33;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# rest error pages
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk r -d "comment_data=test" -d "triggered_by=test" /hosts/localhost/cmd/schedule_host_downtime',
    like => ['/demo: 400: Couldn\'t parse ulong argument trigger_id/', '/COMMAND/', '/sending command failed/', '/"code" : 400/'],
    exit => 3,
});

###########################################################
# enable lmd and try again
TestUtils::test_command({
    cmd  => '/usr/bin/env sed -i etc/thruk/thruk_local.d/lmd.conf -e s/\#use_lmd_core=.*/use_lmd_core=1/g',
    like => ['/^$/'],
});

TestUtils::test_command({
    cmd  => '/usr/bin/env thruk r -d "comment_data=test" -d "triggered_by=test" /hosts/localhost/cmd/schedule_host_downtime',
    like => ['/400: Couldn\'t parse ulong argument trigger_id/', '/COMMAND/', '/sending command failed/', '/"code" : 400/'],
    exit => 3,
});

TestUtils::test_command({
    cmd  => '/usr/bin/env sed -i etc/thruk/thruk_local.d/lmd.conf -e s/^.*use_lmd_core=.*/#use_lmd_core=1/g',
    like => ['/^$/'],
});

###########################################################
# rest downtime duration
{
    my $test = {
        cmd  => '/usr/bin/env thruk r -d "comment_data=test" -d "end_time=+1m" /hosts/localhost/cmd/schedule_host_downtime',
        like => ['/COMMAND/', '/Command successfully submitted/', '/SCHEDULE_HOST_DOWNTIME/'],
    };
    TestUtils::test_command($test);
    my($t1, $t2) = ($test->{'stdout'} =~ m/SCHEDULE_HOST_DOWNTIME;localhost;(\d+);(\d+);/gmx);
    if(!$t1) {
        fail("cannot parse timestamps from stdout: ".$test->{'stdout'});
    } else {
        my $duration = $t2 - $t1;
        ok($duration == 60, "downtime duration should be 60s but is ".$duration."s");
    }
}
