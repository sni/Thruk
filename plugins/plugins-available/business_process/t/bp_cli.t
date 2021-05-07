use warnings;
use strict;
use Test::More;
use URI::Escape;

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

my $bpid = 9990;

TestUtils::test_command({
    cmd  => $BIN.' -a bpd',
    like => ['/OK - \d+ business processes updated in/'],
});

TestUtils::test_command({
    cmd  => $BIN.' bp all --worker=4',
    like => ['/OK - \d+ business processes updated in/'],
});

# create more test bps
for my $x (0..9) {
    TestUtils::test_command({
        cmd  => $BIN.' r -d @t/xt/business_process/data/9999.tbp -D id='.($bpid+$x).' -D name=Test_'.($bpid+$x).' -m POST /thruk/bp',
        like => ['/business process sucessfully created/'],
    });
}
TestUtils::test_command({
    cmd  => $BIN.' bp commit',
    like => ['/OK - wrote \d+ business process/'],
});

TestUtils::test_command({
    cmd  => $BIN.' -a bpd',
    like => ['/OK - \d+ business processes updated in/'],
});

for my $x (0..9) {
    TestUtils::test_command({
        cmd  => $BIN.' r -m DELETE /thruk/bp/'.($bpid+$x),
        like => ['/business process sucessfully removed/'],
    });
}

TestUtils::test_command({
    cmd  => $BIN.' bp commit',
    like => ['/OK - wrote \d+ business process/'],
});

done_testing();
