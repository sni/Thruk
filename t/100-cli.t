use strict;
use warnings;
use Test::More;
use Data::Dumper;

eval "use Test::Cmd";
plan skip_all => 'Test::Cmd required' if $@;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $BIN = defined $ENV{'CATALYST_SERVER'} ? '/usr/bin/thruk' : './script/thruk';

my $oldextsrv = $ENV{'CATALYST_SERVER'};
delete $ENV{'CATALYST_SERVER'};

my $cronuser = '';
if($BIN eq '/usr/bin/thruk') {
    my $user  = TestUtils::get_user();
    $cronuser = ' -l '.$user;
}

# list backends
TestUtils::test_command({
    cmd  => $BIN.' -l',
    like => ['/\s+\*\s*\w{5}\s*\w+/',
             '/Def\s+Key\s+Name/'
            ],
});

# update crontab
TestUtils::test_command({
    cmd  => $BIN.' reports.cgi?action=updatecron',
    like => ['/^OK - updated crontab$/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/crontab -l '.$cronuser.' | grep "THIS PART IS WRITTEN BY THRUK" | wc -l',
    like => ['/^1$/' ],
});


# Excel export
TestUtils::test_command({
    cmd  => '/bin/sh -c \''.$BIN.' -A thrukadmin -a "url=status.cgi?view_mode=xls&host=all" > /tmp/allservices.xls\'',
});
TestUtils::test_command({
    cmd  => '/usr/bin/file /tmp/allservices.xls',
    like => ['/(Microsoft Office|CDF V2|Composite Document File V2) Document/',
            ],
});
unlink('/tmp/allservices.xls');

# remove crontab
TestUtils::test_command({
    cmd  => $BIN.' -a uninstallcron',
    like => ['/^cron entries removed/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/crontab -l '.$cronuser.' | grep "THIS PART IS WRITTEN BY THRUK" | wc -l',
    like => ['/^0$/' ],
});

# restore env
defined $oldextsrv ? $ENV{'CATALYST_SERVER'} = $oldextsrv : delete $ENV{'CATALYST_SERVER'};
done_testing();
