use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 258;
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
    };
    if($nr == 13) {
        $test->{'unlike'} = [];
    }
    TestUtils::test_page(%{$test});
}

delete $ENV{'TEST_ERROR'};
