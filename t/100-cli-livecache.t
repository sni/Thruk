use warnings;
use strict;
use Test::More;

use Thruk::Config 'noautoload';

eval "use Test::Cmd";
plan skip_all => 'Test::Cmd required' if $@;
BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan skip_all => 'local test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $config = Thruk::Config::set_config_env();
plan skip_all => 'no livecache configured' if !$config->{'use_lmd_core'};

my $BIN = defined $ENV{'THRUK_BIN'} ? $ENV{'THRUK_BIN'} : './script/thruk';
$BIN    = $BIN.' --local' unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
$BIN    = $BIN.' --remote-url="'.$ENV{'PLACK_TEST_EXTERNALSERVER_URI'}.'"' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

# stop cache first
TestUtils::test_command({
    cmd     => $BIN.' -a livecachestop',
    like    => ['/STOPPED - 0 lmd running/'],
    exit    => 0,
});

# start cache
TestUtils::test_command({
    cmd     => $BIN.' -a livecachestart',
    like    => ['/OK - lmd started/'],
    exit    => 0,
});

# restart cache
TestUtils::test_command({
    cmd     => $BIN.' -a livecacherestart',
    like    => ['/OK - lmd running with pid/'],
    exit    => 0,
});

# status cache
TestUtils::test_command({
    cmd     => $BIN.' -a livecachestatus',
    like    => ['/OK - lmd running with pid/'],
    exit    => 0,
});

# stop cache
TestUtils::test_command({
    cmd     => $BIN.' -a livecachestop',
    like    => ['/STOPPED - 0 lmd running/'],
    exit    => 0,
});

# status cache
TestUtils::test_command({
    cmd     => $BIN.' -a livecachestatus',
    errlike => ['/STOPPED - 0 lmd running/'],
    exit    => 2,
});


done_testing();
