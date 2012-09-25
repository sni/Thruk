use strict;
use warnings;
use Test::More;
use URI::Escape;
use Data::Dumper;

eval "use Test::Cmd";
plan skip_all => 'Test::Cmd required' if $@;
plan skip_all => 'backends required' if(!-f 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $BIN = defined $ENV{'THRUK_BIN'} ? $ENV{'THRUK_BIN'} : './script/thruk';
$BIN    = $BIN.' --local' unless defined $ENV{'CATALYST_SERVER'};
$BIN    = $BIN.' --remote-url="'.$ENV{'CATALYST_SERVER'}.'"' if defined $ENV{'CATALYST_SERVER'};

# get test host
my $test = { cmd  => $BIN.' -a listhosts' };
TestUtils::test_command($test);
my $host = (split(/\n/mx, $test->{'stdout'}))[0];
isnt($host, undef, 'got test hosts') or BAIL_OUT("need test host:\n".Dumper($test));

my $comment = 'test downtime '.int(rand(1000000));
my $test_downtime = [{
    'type'          => 6,
    'host'          => $host,
    'comment'       => $comment,
    'send_type_1'   => 'day',
    'send_day_1'    => 1,
    'week_day_1'    => '*',
    'send_hour_1'   => '*',
    'send_minute_1' => '*',
    'duration'      => 2,
    'fixed'         => 1,
    'flex_range'    => 720,
    'childoptions'  => 0,
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

    # wait 90 seconds for a downtime
    my $now   = time();
    my $found = 0;
    while($now > time() - 90) {
        my $test = { cmd  => $BIN.' "extinfo.cgi?type=1&host='.$host.'"'};
        TestUtils::test_command($test);
        if($test->{'stdout'} =~ m/\(cron\)<\/td>\s+<td\s+class='\w+'>$comment/gs) {
            ok(1, "downtime occured after ".(time()-$now)." seconds");
            $found = 1;
            last;
        }
    }
    fail("downtime did not occur in time") unless $found;
}

# remove downtime
TestUtils::test_command({
    cmd  => $BIN.' "extinfo.cgi?type=6&recurring=remove&host='.$host.'"',
    like => ['/^OK - recurring downtime removed$/'],
});

done_testing();
