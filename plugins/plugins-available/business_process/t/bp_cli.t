use strict;
use warnings;
use Test::More;
use URI::Escape;
use Data::Dumper;

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

TestUtils::test_command({
    cmd  => $BIN.' -a bpd',
    like => ['/^OK - \d+ business processes updated in/'],
});

done_testing();
