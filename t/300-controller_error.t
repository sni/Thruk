use warnings;
use strict;
use Test::More;

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 183;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
use_ok 'Thruk::Controller::error';

$ENV{'TEST_ERROR'} = 1;
for(0..25) {
    my $nr = $_;
    my $test = {
        'url'     => '/thruk/cgi-bin/error.cgi?error='.$nr,
        'fail'    => 1,
        'unlike'  => [],
    };
    TestUtils::test_page(%{$test});
}

delete $ENV{'TEST_ERROR'};
