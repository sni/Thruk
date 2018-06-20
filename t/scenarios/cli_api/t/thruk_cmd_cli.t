use strict;
use warnings;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 108;

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
    waitfor => '0\ Matching\ Service\ Entries',
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
    cmd     => '/usr/bin/env thruk core_scheduling fix',
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
