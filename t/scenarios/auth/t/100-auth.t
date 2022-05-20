use warnings;
use strict;
use Test::More;

BEGIN {
    plan tests => 137;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

# omd admin tests
{
    local $ENV{'THRUK_TEST_AUTH'} = 'omdadmin:omd';
    TestUtils::test_page(
        'url'    => '/thruk/main.html',
        'like'   => ['Config Role Link', 'logout'],
        'unlike' => ['Admin Link'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/user.cgi',
        'like'   => ['>User<.*?>omdadmin<', 'authorized_for_admin', 'from cgi.cfg'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/r/thruk/whoami',
        'like'   => ['omdadmin', 'authorized_for_admin'],
    );
    TestUtils::set_test_user_token();
    TestUtils::test_page(
        'url'    => '/thruk/r/services/test/Ping/cmd/schedule_forced_svc_check',
        'post'   => {},
        'like'   => ['Command successfully submitted'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/login.cgi?logout',
        'like'   => ['logout successful'],
        'follow' => 1,
        'code'   => 401,
    );
};

# admin group user tests
{
    local $ENV{'THRUK_TEST_AUTH'} = 'admin:admin';
    TestUtils::test_page(
        'url'    => '/thruk/main.html',
        'like'   => ['Admin Link', 'Config Role Link', 'logout'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/user.cgi',
        'like'   => ['>User<.*?>admin<', 'authorized_for_admin', 'from group: admins'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/r/thruk/whoami',
        'like'   => ['admin', 'authorized_for_admin'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/login.cgi?logout',
        'like'   => ['logout successful'],
        'follow' => 1,
        'code'   => 401,
    );
};

# normal user tests
{
    local $ENV{'THRUK_TEST_AUTH'} = 'test:test';
    TestUtils::test_page(
        'url'    => '/thruk/main.html',
        'like'   => ['logout'],
        'unlike' => ['Admin Link', 'Config Role Link'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/user.cgi',
        'like'   => ['>User<.*?>test<', 'none'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/r/thruk/whoami',
        'like'   => ['test'],
        'unlike' => ['authorized_for_admin'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/login.cgi?logout',
        'like'   => ['logout successful'],
        'follow' => 1,
        'code'   => 401,
    );
};
