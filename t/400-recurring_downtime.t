use strict;
use warnings;
use Test::More;
use URI::Escape;
use Data::Dumper;

eval "use Test::Cmd";
plan skip_all => 'Test::Cmd required' if $@;
plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
`ps -fu root | grep cron >/dev/null 2>&1`;
plan skip_all => 'crond required' if $? != 0;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $BIN = defined $ENV{'THRUK_BIN'} ? $ENV{'THRUK_BIN'} : './script/thruk';
$BIN    = $BIN.' --local' unless defined $ENV{'CATALYST_SERVER'};
$BIN    = $BIN.' --remote-url="'.$ENV{'CATALYST_SERVER'}.'"' if defined $ENV{'CATALYST_SERVER'};

# get test host
my $host = TestUtils::get_test_host_cli($BIN);

my $rand    = int(rand(1000000));
my $comment = 'test downtime '.$rand;
my $test_downtime = [{
    'type'          => 6,
    'target'        => 'host',
    'host'          => $host,
    'comment'       => $comment,
    'send_type_1'   => 'cust',
    'send_day_1'    => 1,
    'week_day_1'    => '0',
    'send_hour_1'   => '0',
    'send_minute_1' => '0',
    'send_cust_1'   => '* * * * *',
    'duration'      => 2,
    'fixed'         => 1,
    'flex_range'    => 720,
    'childoptions'  => 0,
    'nr'            => $rand,
    'verbose'       => 1,
}];

for my $downtime (@{$test_downtime}) {
    # create downtime
    my $args = [];
    for my $key (keys %{$downtime}) {
        push @{$args}, $key.'='.$downtime->{$key};
    }
    TestUtils::test_command({
        cmd  => $BIN.' "extinfo.cgi?recurring=save&'.join('&', @{$args}).'"',
        like => ['/^OK - recurring downtime saved$/'],
    });

    my $host = $downtime->{'host'};
    my $user = defined $ENV{THRUK_USER} ? ' -u '.$ENV{THRUK_USER} : '';
    my $grephost = $host;
    $grephost =~ s/["'\/\s;]+/_/gmx;
    my $cronentry = `crontab -l $user | grep downtimetask | grep '$grephost'`;
    chomp($cronentry);
    like($cronentry, '/downtimetask=/', "got cron entry: ".$cronentry) or BAIL_OUT("$0: got no cron entry");

    my($logfile) = ($cronentry =~ m/>>(.*?cron\.log)/mx);
    like($logfile, '/cron\.log$/', "got cron log: ".$logfile);
    `>$logfile`;

    # wait 150 seconds for a downtime
    my $now   = time();
    my $found = 0;
    while($now > time() - 150) {
        my $test = { cmd  => $BIN.' "extinfo.cgi?type=1&host='.$host.'"'};
        TestUtils::test_command($test);
        if($test->{'stdout'} =~ m/\(cron\)<\/td>\s+<td[^>]*>$comment/gs) {
            ok(1, "downtime occured after ".(time()-$now)." seconds");
            $found = 1;
            last;
        }
    }
    if(!$found) {
        fail("downtime did not occur in time");
        for my $cmd ("cat $logfile",
                     "crontab -l",
                     "ps -efl",
                     "$BIN 'extinfo.cgi?type=6'",
                     "$BIN 'showlog.cgi?pattern=EXTERNAL+COMMAND&start=yesterday&end=now'",
                    ) {
            diag("cmd: $cmd");
            diag(`$cmd`);
        }
    }
}

# remove downtime
TestUtils::test_command({
    cmd  => $BIN.' "extinfo.cgi?type=6&recurring=remove&target=host&nr='.$rand.'&host='.$host.'"',
    like => ['/^OK - recurring downtime removed$/'],
});

done_testing();
