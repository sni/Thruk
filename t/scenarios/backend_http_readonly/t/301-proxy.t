use warnings;
use strict;
use Cpanel::JSON::XS qw/decode_json/;
use Test::More;

die("*** ERROR: this test is meant to be run with PLACK_TEST_EXTERNALSERVER_URI set") unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

BEGIN {
    plan tests => 25;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

TestUtils::test_page(
    url     => '/thruk/cgi-bin/proxy.cgi/backend1/demo/thruk/cgi-bin/user.cgi',
    like    => ['authorized_for_all_hosts', 'authorized_for_read_only', 'Read-Only sessions cannot create API keys', '>User<.*?>omdadmin<'],
    unlike  => ['authorized_for_admin', 'authorized_for_system_commands', 'New API Key'],
);

TestUtils::test_page(
    url     => '/thruk/cgi-bin/proxy.cgi/backend1/demo/thruk/cgi-bin/extinfo.cgi?type=1&host=localhost',
    like    => ['Your account does not have permissions to execute commands'],
);
