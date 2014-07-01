use strict;
use warnings;
use Test::More;
use Data::Dumper;

eval "use Test::Cmd";
plan skip_all => 'Test::Cmd required' if $@;
BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan skip_all => 'local test only' if defined $ENV{'CATALYST_SERVER'};
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $config = Thruk::Config::get_config();
plan skip_all => 'no livecache configured' if(!$config->{'use_shadow_naemon'} or ($config->{'use_shadow_naemon'} ne 'start_only' and $config->{'use_shadow_naemon'} ne 'auto'));

my $BIN = defined $ENV{'THRUK_BIN'} ? $ENV{'THRUK_BIN'} : './script/thruk';
$BIN    = $BIN.' --local' unless defined $ENV{'CATALYST_SERVER'};
$BIN    = $BIN.' --remote-url="'.$ENV{'CATALYST_SERVER'}.'"' if defined $ENV{'CATALYST_SERVER'};

# start cache
TestUtils::test_command({
    cmd     => $BIN.' -a livecachestart',
    like    => ['/OK - \d+/\d+ livecache running, \d+\/\d+ online/'],
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
