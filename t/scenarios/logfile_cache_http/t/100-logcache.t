use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'});
    plan tests => 23;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::notifications' }

# import logs
TestUtils::test_page(
    'url'    => '/thruk/cgi-bin/showlog.cgi',
    'follow' => 1,
    'like'   => [],
);

TestUtils::test_page(
    'url'    => '/thruk/cgi-bin/showlog.cgi',
    'like'   => ["Event Log", "LOG VERSION: 2.0", "Local time is"],
);
