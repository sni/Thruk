use warnings;
use strict;
use Test::More;

BEGIN {
    plan tests => 214;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

# omdadmin
{
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/login.cgi?logout',
        'like'   => ['logout successful', 'Password'],
        'follow' => 1,
        'code'   => 401,
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/login.cgi',
        'like'   => ['main.html'],
        'post'   => { login => 'omdadmin', password => 'omd' },
        'follow' => 1,
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/user.cgi',
        'like'   => ['Logged in as.*omdadmin', 'authorized_for_admin', 'from cgi.cfg'],
    );

    # report 1
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/reports2.cgi',
        'like'   => ['Reports', 'report scheduled for update'],
        'post'   => { report => '1', action => 'update' },
        'follow' => 1,
    );
    TestUtils::test_page(
        'url'     => '/thruk/cgi-bin/reports2.cgi',
        'like'    => ['Reports'],
        'waitfor' => qr(\Qreports2.cgi?report=1&amp;refreshreport=0&amp;html=1\E),
        'waitmax' => 10,
    );
    TestUtils::test_page(
        'url'            => '/thruk/cgi-bin/reports2.cgi?report=1&refreshreport=0&html=1',
        'like'           => ['Admin Report', 'Host: test', 'Host: localhost'],
        'unlike'         => [],
        'skip_html_lint' => 1,
        'skip_js_check'  => 1,
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/user.cgi',
        'like'   => ['Logged in as.*omdadmin', 'authorized_for_admin', 'from cgi.cfg'],
    );

    # report 2
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/reports2.cgi',
        'like'   => ['Reports', 'report scheduled for update'],
        'post'   => { report => '2', action => 'update' },
        'follow' => 1,
    );
    TestUtils::test_page(
        'url'     => '/thruk/cgi-bin/reports2.cgi',
        'like'    => ['Reports'],
        'waitfor' => qr(\Qreports2.cgi?report=2&amp;refreshreport=0&amp;html=1\E),
    );
    TestUtils::test_page(
        'url'            => '/thruk/cgi-bin/reports2.cgi?report=2&refreshreport=0&html=1',
        'like'           => ['User Report', 'Host: test'],
        'unlike'         => ['Host: localhost'],
        'skip_html_lint' => 1,
        'skip_js_check'  => 1,
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

# test contact
{
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/login.cgi?logout',
        'like'   => ['logout successful', 'Password'],
        'follow' => 1,
        'code'   => 401,
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/login.cgi',
        'like'   => ['main.html'],
        'post'   => { login => 'test_contact', password => 'test' },
        'follow' => 1,
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/user.cgi',
        'like'   => ['Logged in as.*test_contact', 'authorized_for_reports', 'from cgi.cfg'],
    );

    # report 2
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/reports2.cgi',
        'like'   => ['Reports', 'report scheduled for update'],
        'post'   => { report => '2', action => 'update' },
        'follow' => 1,
    );
    TestUtils::test_page(
        'url'     => '/thruk/cgi-bin/reports2.cgi',
        'like'    => ['Reports'],
        'waitfor' => qr(\Qreports2.cgi?report=2&amp;refreshreport=0&amp;html=1\E),
    );
    TestUtils::test_page(
        'url'            => '/thruk/cgi-bin/reports2.cgi?report=2&refreshreport=0&html=1',
        'like'           => ['User Report', 'Host: test'],
        'unlike'         => ['Host: localhost'],
        'skip_html_lint' => 1,
        'skip_js_check'  => 1,
    );
    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/user.cgi',
        'like'   => ['Logged in as.*test_contact', 'authorized_for_reports', 'from cgi.cfg'],
    );

    TestUtils::test_page(
        'url'    => '/thruk/cgi-bin/login.cgi?logout',
        'like'   => ['logout successful'],
        'follow' => 1,
        'code'   => 401,
    );
};
