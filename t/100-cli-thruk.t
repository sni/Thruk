use strict;
use warnings;
use Test::More;

eval "use Test::Cmd";
plan skip_all => 'Test::Cmd required' if $@;
BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $BIN = defined $ENV{'THRUK_BIN'} ? $ENV{'THRUK_BIN'} : './script/thruk';
$BIN    = $BIN.' --local' unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
$BIN    = $BIN.' --remote-url="'.$ENV{'PLACK_TEST_EXTERNALSERVER_URI'}.'"' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

my $cronuser = '';
$cronuser = ' -u '.$ENV{'THRUK_USER'} if defined $ENV{'THRUK_USER'};

# get test host
my $host = TestUtils::get_test_host_cli($BIN);

# show help
TestUtils::test_command({
    cmd     => $BIN.' -h',
    errlike => ['/EXAMPLES/',
                '/Usage: thruk/'
               ],
    exit    => 3,
});

# url export
TestUtils::test_command({
    cmd     => $BIN.' tac.cgi',
    like => ['/Tactical Monitoring Overview/',
             '/Network Outages/',
             '/Monitoring Features/',
             '/(javascript\/overlib\.js|all_in_one-[\d\-\.]+\.js)/',
            ],
});

# url export, all-inclusive
TestUtils::test_command({
    cmd     => $BIN.' --all-inclusive tac.cgi',
    like => ['/Tactical Monitoring Overview/',
             '/Network Outages/',
             '/Monitoring Features/',
             '/data:image/',
             '/jquery\.org\/license/',
             '/\.peerDOWN/',
            ],
});

# list backends
my $test = {
    cmd  => $BIN.' -l',
    like => ['/\s+\*\s*\w{5}\s*[^\s]+/',
             '/Def\s+Key\s+Name/'
            ],
};
TestUtils::test_command($test);

if($test->{'exit'} == 0) {
    my @out = split/\n/mx, $test->{'stdout'};
    @out = grep(!/^(-|Def)/, @out);
    my @backends;
    my @names;
    for my $line (@out) {
        $line =~ s/^\ \*\s+//mx;
        $line =~ s/^\s+//gmx;
        my $data = [split(/\s+/mx, $line)];
        push @backends, $data->[0];
        push @names, $data->[1];
    }
    if(scalar @backends > 1) {
        # test commands with multiple backends
        local $ENV{'THRUK_NO_COMMANDS'} = 1;
        TestUtils::test_command({
            cmd  => $BIN.' "cmd.cgi?cmd_mod=2&cmd_typ=11" -b '.$backends[0].' -b '.$backends[1],
            errlike => ['/\['.$backends[0].','.$backends[1].'\]/', '/TESTMODE:/', '/DISABLE_NOTIFICATIONS/' ],
            like => ['/Command request successfully submitted to the Backend for processing/'],
        });
        TestUtils::test_command({
            cmd  => $BIN.' "cmd.cgi?cmd_mod=2&cmd_typ=96&host='.$host.'&start_time=now" -b '.$backends[0],
            errlike => ['/\['.$names[0].'\]/', '/TESTMODE:/', '/'.$host.'/' ],
            like => ['/Command request successfully submitted to the Backend for processing/'],
        });
    }
}

# clearcache
TestUtils::test_command({
    cmd  => $BIN.' -a clearcache',
    like => ['/^cache cleared$/'],
});

# dumpcache
TestUtils::test_command({
    cmd  => $BIN.' -a dumpcache',
    like => ['/^\$VAR1/'],
});

# 2 commands
TestUtils::test_command({
    cmd  => $BIN.' -a clearcache,dumpcache',
    like => ['/^cache cleared\$VAR1/'],
});

# create recurring downtime
TestUtils::test_command({
    cmd  => $BIN.' "/thruk/cgi-bin/extinfo.cgi?type=6&recurring=save&target=host&host='.$host.'&duration=5&send_type_1=day&send_hour_1=5&send_minute_1=0&nr=999"',
    like => ['/^OK - recurring downtime saved$/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/crontab -l '.$cronuser.' | grep "THIS PART IS WRITTEN BY THRUK" | wc -l',
    like => ['/^\s*1$/' ],
});

# update crontab
TestUtils::test_command({
    cmd  => $BIN.' "reports2.cgi?action=updatecron"',
    like => ['/^OK - updated crontab$/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/crontab -l '.$cronuser.' | grep "THIS PART IS WRITTEN BY THRUK" | wc -l',
    like => ['/^\s*1$/' ],
});

# remove recurring downtime
TestUtils::test_command({
    cmd  => $BIN.' "/thruk/cgi-bin/extinfo.cgi?type=6&recurring=remove&target=host&host='.$host.'&nr=999"',
    like => ['/^OK - recurring downtime removed$/'],
});

# Excel export
TestUtils::test_command({
    cmd  => '/bin/sh -c \''.$BIN.' -A thrukadmin -a "url=status.cgi?view_mode=xls&host='.$host.'" > /tmp/services.xls\'',
});
TestUtils::test_command({
    cmd  => '/usr/bin/file /tmp/services.xls',
    like => ['/(Microsoft Office|CDF V2|CDFV2 Microsoft Excel|Composite Document File V2)/' ],
});
unlink('/tmp/allservices.xls');

# remove crontab
TestUtils::test_command({
    cmd  => $BIN.' -a uninstallcron',
    like => ['/^cron entries removed/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/crontab -l '.$cronuser.' | grep "THIS PART IS WRITTEN BY THRUK" | wc -l',
    like => ['/^\s*0$/' ],
});

# precompile
TestUtils::test_command({
    cmd  => $BIN.' -a compile',
    like => ['/^\d{3} templates precompiled/'],
});

# logcache
TestUtils::test_command({
    cmd     => $BIN.' -a logcacheupdate',
    like    => ['/(^$|OK - imported \d+ log items from \d+ site|FAILED - logcache is not enabled)/'],
    errlike => ['/(^$|FAILED - logcache is not enabled)/'],
    exit    => undef,
});

# test command
TestUtils::test_command({
    cmd     => $BIN.' -a command "'.$host.'"',
    like    => ['/Expanded Command:/'],
});

# self check
TestUtils::test_command({
    cmd  => $BIN.' -a selfcheck',
    like => ['/Filesystem:/', '/is writable/', '/Logfiles:/', '/no errors/', '/Recurring Downtimes:/', '/Reports:/', '/no errors in \d+ reports/'],
    exit => undef,
});

# panorama cleanup
TestUtils::test_command({
    cmd  => $BIN.' -a clean_dashboards',
    like => ['/OK - cleaned up 0 old dashboards/'],
});

done_testing();
