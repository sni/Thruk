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
my $VAR = (defined $ENV{'CATALYST_SERVER'} or ! -d './var') ? '/var/lib/thruk' : './var';
$BIN    = $BIN." --local ";

my $oldextsrv = $ENV{'CATALYST_SERVER'};
delete $ENV{'CATALYST_SERVER'};

my ($uid, $groups) = Thruk::Utils::get_user($VAR);
ok($uid > 0, 'got a uid: '.$uid);
if(defined $uid and $> == 0) {
    Thruk::Utils::switch_user($uid, $groups);
}

my($host,$service) = TestUtils::get_test_service();

# list backends
TestUtils::test_command({
    cmd  => $BIN.' -l',
    like => ['/\s+\*\s*\w{5}\s*\w+/',
             '/Def\s+Key\s+Name/'
            ],
});

# create recurring downtime
my $pages = [
    { url => '/thruk/cgi-bin/extinfo.cgi?type=6&recurring=save&host='.$host.'&duration=5&send_type_1=day&send_hour_1=5&send_minute_1=0', 'redirect' => 1, location => 'extinfo.cgi', like => 'This item has moved' },
];
for my $test (@{$pages}) {
    $test->{'unlike'} = [ 'internal server error', 'HASH', 'ARRAY' ] unless defined $test->{'unlike'};
    $test->{'like'}   = [ 'Reports' ]                                unless defined $test->{'like'};
    TestUtils::test_page(%{$test});
}
TestUtils::test_command({
    cmd  => '/usr/bin/crontab -l | grep "THIS PART IS WRITTEN BY THRUK" | wc -l',
    like => ['/^1$/' ],
});

# update crontab
TestUtils::test_command({
    cmd  => $BIN.' reports.cgi?action=updatecron',
    like => ['/^OK - updated crontab$/'],
});
TestUtils::test_command({
    cmd  => '/usr/bin/crontab -l | grep "THIS PART IS WRITTEN BY THRUK" | wc -l',
    like => ['/^1$/' ],
});

# remove recurring downtime
$pages = [
    { url => '/thruk/cgi-bin/extinfo.cgi?type=6&recurring=remove&host='.$host, 'redirect' => 1, location => 'extinfo.cgi', like => 'This item has moved' },
];
for my $test (@{$pages}) {
    $test->{'unlike'} = [ 'internal server error', 'HASH', 'ARRAY' ] unless defined $test->{'unlike'};
    $test->{'like'}   = [ 'Reports' ]                                unless defined $test->{'like'};
    TestUtils::test_page(%{$test});
}


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
    cmd  => '/usr/bin/crontab -l | grep "THIS PART IS WRITTEN BY THRUK" | wc -l',
    like => ['/^0$/' ],
});

# restore env
defined $oldextsrv ? $ENV{'CATALYST_SERVER'} = $oldextsrv : delete $ENV{'CATALYST_SERVER'};
done_testing();
