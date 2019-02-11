use strict;
use warnings;
use Test::More;

BEGIN {
    plan tests => 105;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

# omd admin tests
{
    local $ENV{'THRUK_TEST_AUTH'} = 'omdadmin:omd';
    TestUtils::test_page(
        'url'    => '/thruk/side.html',
        'like'   => ['Config Role Link', 'logout'],
        'unlike' => ['Admin Link'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/user.cgi',
        'like'   => ['Logged in as.*omdadmin', 'authorized_for_admin', 'from cgi.cfg'],
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
        'url'    => '/thruk/side.html',
        'like'   => ['Admin Link', 'Config Role Link', 'logout'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/user.cgi',
        'like'   => ['Logged in as.*admin', 'authorized_for_admin', 'from group: admins'],
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
        'url'    => '/thruk/side.html',
        'like'   => ['logout'],
        'unlike' => ['Admin Link', 'Config Role Link'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/user.cgi',
        'like'   => ['Logged in as.*test', 'none'],
        'unlike' => ['authorized_for_admin'],
    );

    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/login.cgi?logout',
        'like'   => ['logout successful'],
        'follow' => 1,
        'code'   => 401,
    );
};
