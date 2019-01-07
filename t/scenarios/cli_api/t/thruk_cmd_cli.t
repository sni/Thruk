use strict;
use warnings;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 139;

###########################################################
# verify that we use the correct thruk binary
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# thruk lmd
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk lmd stop',
    like => ['/STOPPED - 0 lmd running/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk lmd start',
    like => ['/OK - lmd started/'],
});
TestUtils::test_command({
    cmd     => '/usr/bin/env thruk lmd start',
    errlike => ['/FAILED - lmd already running with pid/'],
    exit    => 1,
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk lmd status',
    like => ['/OK - lmd running with pid/'],
});

###########################################################
# thruk -l
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk -l',
    like => ['/OK/', '/demo/', '/\/omd\/sites\/demo\/tmp\/run\/live/'],
});

###########################################################
# thruk bp
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk bp commit',
    like => ['/OK - wrote 1 business process/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk bp all',
    like => ['/OK - 1 business processes updated in/'],
});

###########################################################
# some tests require non-pending services
TestUtils::test_command({
    cmd     => '/test/t/reschedule_all.sh',
    like    => ['/OK/', '/cmd: COMMAND/', '/SCHEDULE_FORCED_HOST_CHECK/', '/SCHEDULE_FORCED_SVC_CHECK/'],
});
TestUtils::test_command({
    cmd     => '/usr/bin/env thruk -A omdadmin url "status.cgi?host=all&servicestatustypes=1&style=detail"',
    like    => ['/Current Network Status/'],
    waitfor => '(0|1)\ Matching\ Service\ Entries',
});

###########################################################
# logging on rest api
TestUtils::test_command({
    cmd     => '/usr/bin/env thruk r -d "" /hosts/localhost/cmd/schedule_forced_host_check',
    like    => ['/successfully submitted/', '/COMMAND/', '/SCHEDULE_FORCED_HOST_CHECK/'],
    unlike  => ['/cmd:/'],
});
TestUtils::test_command({
    cmd     => '/usr/bin/env thruk r --local -d "" /hosts/localhost/cmd/schedule_forced_host_check',
    like    => ['/successfully submitted/', '/COMMAND/', '/SCHEDULE_FORCED_HOST_CHECK/'],
    unlike  => ['/cmd:/'],
});

###########################################################
# errors on external commands
TestUtils::test_command({
    cmd     => '/usr/bin/env thruk r -d "comment_data=test" -d "triggered_by=test" /hosts/localhost/cmd/schedule_host_downtime',
    like    => ['/"error"/', '/parse ulong argument trigger_id/', '/No digits found in ulong/', '/COMMAND/', '/SCHEDULE_HOST_DOWNTIME/'],
    unlike  => ['/successfully submitted/'],
    exit    => 1,
});

###########################################################
# thruk plugin
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk plugin list',
    like => ['/E\s+business_process/', '/E\s+conf/', '/E\s+reports2/', '/E\s+panorama/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk plugin enable core_scheduling',
    like => ['/enabled plugin core_scheduling/'],
});

###########################################################
# thruk selfcheck
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk selfcheck',
    like => ['/^OK - /', '/lmd running with/', '/is writable/', '/no errors in 1 reports/', '/no errors in 1 downtimes/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk selfcheck lmd',
    like => ['/^OK - /', '/lmd running with/'],
});

###########################################################
# thruk cron
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk cron uninstall',
    like => ['/^cron entries removed$/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk cron install',
    like => ['/^updated cron entries$/'],
});

###########################################################
# thruk find
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk find host localhost',
    like => ['/host found in the filesystem:/',
             '/referenced in service \'Ping\'/',
             '/host referenced in dashboard/',
             '/referenced in report/',
             '/host listed in recurring downtime/',
             '/referenced in business process node \'Host Node\' host/',
            ],
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk find service localhost Ping',
    like => ['/service found in the filesystem:/', '/service listed in recurring downtime/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk find hostgroup none',
    like => ['/cannot find any reference for hostgroup \'none\'/'],
});

###########################################################
# thruk core_scheduling
TestUtils::test_command({
    cmd     => '/usr/bin/env thruk --local core_scheduling fix',
    like    => ['/hosts and services rebalanced successfully/'],
    errlike => ['/.*/'], # may print executed commands to stderr
});
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk plugin disable core_scheduling',
    like => ['/disabled plugin core_scheduling/'],
});

###########################################################
# thruk hosts
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk hosts list',
    like => ['/localhost/', '/Test BP/'],
});

###########################################################
# thruk cmd.cgi
TestUtils::test_command({
    cmd  => "/usr/bin/env thruk 'cmd.cgi?cmd_mod=2&cmd_typ=96&host=localhost&start_time=now'",
    like => ['/Command request successfully submitted/'],
});
TestUtils::test_command({
    cmd  => "/usr/bin/env thruk 'cmd.cgi?cmd_mod=2&cmd_typ=96&host=localhost&start_time=now' --local",
    like => ['/Command request successfully submitted/'],
    errlike => ['/SCHEDULE_HOST_CHECK/'],
});

###########################################################
