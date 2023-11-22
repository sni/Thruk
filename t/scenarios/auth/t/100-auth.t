use warnings;
use strict;
use Test::More;

BEGIN {
    plan tests => 308;

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

    # verify check_command visibility: should see obfuscated command
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/extinfo.cgi?type=2&host=test&service=Http',
        'like'   => ['Service Http on.*test', '-a \*\*\* -u'],
        'unlike'   => ['test:test'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/status.cgi?style=detail&view_mode=json',
        'like'   => ['"Http"', '"check_http', '-a \*\*\* -u', 'customvartest123'],
        'unlike'   => ['test:test'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/status.cgi?style=combined&view_mode=json',
        'like'   => ['"Http"', '"check_http', '-a \*\*\* -u', 'customvartest123'],
        'unlike'   => ['test:test'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/r/services',
        'like'   => ['"Http"', '"check_http', '-a \*\*\* -u', 'customvartest123'],
        'unlike'   => ['test:test'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/r/services/test/Http/commandline',
        'like'   => ['"check_http', '-a \*\*\* -u', '/demo/omd/index.html'],
        'unlike' => ['test:test'],
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


# conf info user tests
{
    local $ENV{'THRUK_TEST_AUTH'} = 'confinfo:confinfo';
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/user.cgi',
        'like'   => ['>User<.*?>confinfo<', 'authorized_for_configuration_information'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/r/thruk/whoami',
        'like'   => ['confinfo', 'authorized_for_configuration_information'],
    );

    # verify check_command visibility: should see obfuscated command
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/extinfo.cgi?type=2&host=test&service=Http',
        'like'   => ['Service Http on.*test', '-a \*\*\* -u'],
        'unlike' => ['test:test'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/status.cgi?style=detail&view_mode=json',
        'like'   => ['"Http"', '"check_http', '-a \*\*\* -u', 'customvartest123'],
        'unlike' => ['test:test'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/status.cgi?style=combined&view_mode=json',
        'like'   => ['"Http"', '"check_http', '-a \*\*\* -u', 'customvartest123'],
        'unlike' => ['test:test'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/r/services',
        'like'   => ['"Http"', '"check_http', '-a \*\*\* -u', 'customvartest123'],
        'unlike' => ['test:test'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/r/services?columns=custom_variable_values,check_command',
        'like'   => ['custom_variable_values', 'check_command', 'customvartest123', '/demo/omd/index.html'],
        'unlike' => ['test:test'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/r/services/test/Http/commandline',
        'like'   => ['"check_http', '-a \*\*\* -u', '/demo/omd/index.html'],
        'unlike' => ['test:test'],
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

    # verify check_command visibility: must not see command at all
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/extinfo.cgi?type=2&host=test&service=Http',
        'like'   => ['Service Http on.*test'],
        'unlike' => ['test:test', 'plugins\/check_http', 'customvartest123'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/status.cgi?style=detail&view_mode=json',
        'like'   => ['"Http"', '"check_http'],
        'unlike' => ['test:test', '/demo/omd/index.html', 'customvartest123'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/status.cgi?style=combined&view_mode=json',
        'like'   => ['"Http"', '"check_http'],
        'unlike' => ['test:test', '/demo/omd/index.html', 'customvartest123'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/r/services',
        'like'   => ['"Http"', '"check_http'],
        'unlike' => ['test:test', '/demo/omd/index.html', 'customvartest123'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/r/services?columns=custom_variable_values,check_command',
        'like'   => ['custom_variable_values', 'check_command'],
        'unlike' => ['test:test', '/demo/omd/index.html', 'customvartest123'],
    );
    TestUtils::test_page(
        'url'    => '/thruk/r/services/test/Http/commandline',
        'like'   => ['not authorized'],
        'unlike' => ['test:test', '/demo/omd/index.html'],
        'code'   => 403,
    );

    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/login.cgi?logout',
        'like'   => ['logout successful'],
        'follow' => 1,
        'code'   => 401,
    );
};
