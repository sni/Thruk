use strict;
use warnings;
use Test::More;

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

my $config = Thruk::Config::get_config();
plan skip_all => 'no livecache configured' if(!$config->{'use_shadow_naemon'} or ($config->{'use_shadow_naemon'} ne 'start_only' and $config->{'use_shadow_naemon'} ne 'auto'));

my $BIN = defined $ENV{'THRUK_BIN'} ? $ENV{'THRUK_BIN'} : './script/thruk';
$BIN    = $BIN.' --local' unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
$BIN    = $BIN.' --remote-url="'.$ENV{'PLACK_TEST_EXTERNALSERVER_URI'}.'"' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

# start cache
TestUtils::test_command({
    cmd     => $BIN.' -a livecachestart',
    like    => ['/OK - livecache started/'],
    exit    => 0,
});

# restart cache
TestUtils::test_command({
    cmd     => $BIN.' -a livecacherestart',
    like    => ['/OK - \d+/\d+ livecache running, \d+\/\d+ online/'],
    exit    => 0,
});

# status cache
TestUtils::test_command({
    cmd     => $BIN.' -a livecachestatus',
    like    => ['/OK - \d+/\d+ livecache running, \d+\/\d+ online/'],
    exit    => 0,
});

# stop cache
TestUtils::test_command({
    cmd     => $BIN.' -a livecachestop',
    like    => ['/STOPPED - 0 livecache running/'],
    exit    => 0,
});

# status cache
TestUtils::test_command({
    cmd     => $BIN.' -a livecachestatus',
    errlike => ['/STOPPED - 0 livecache running/'],
    exit    => 2,
});


done_testing();
