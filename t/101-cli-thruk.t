use strict;
use warnings;
use Test::More;

eval "use Test::Cmd";
plan skip_all => 'Test::Cmd required' if $@;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $BIN = defined $ENV{'THRUK_BIN'} ? $ENV{'THRUK_BIN'} : './script/thruk';

# install crontab
TestUtils::test_command({
    cmd  => $BIN.' -a installcron --local',
    like => ['/^updated cron entries/'],
});

# remove crontab
TestUtils::test_command({
    cmd  => $BIN.' -a uninstallcron --local',
    like => ['/^cron entries removed/'],
});

done_testing();
