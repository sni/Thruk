use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s ($ENV{'THRUK_CONFIG'} || '.').'/thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::notifications' }

# import logs
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/showlog.cgi?logcache_update=1',
    'like'    => [],
    'follow'  => 1,
    'waitfor' => 'LOG\ VERSION',
);
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/showlog.cgi',
    'follow'  => 1,
    'like'    => [],
);
TestUtils::test_page(
    'url'    => '/thruk/cgi-bin/showlog.cgi',
    'like'   => ["Event Log", "LOG VERSION: 2.0", "Local time is"],
);

# cannot determine fixed number of tests, number depends on wether initial import redirects or not,
# which depends on machine load and speed (initial import redirects after 10 seconds)
done_testing();
