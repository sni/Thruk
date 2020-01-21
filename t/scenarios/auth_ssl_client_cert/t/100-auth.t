use strict;
use warnings;
use Test::More;

BEGIN {
    plan tests => 8;

    use lib('t');
    require TestUtils;
    import TestUtils;

    use IO::Socket::SSL;
    IO::Socket::SSL::set_ctx_defaults( SSL_verify_mode => 0 );
    $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = "0";
    #$ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS} = 'Net::SSL';
}

# omd admin tests
{
    local $ENV{'THRUK_TEST_AUTH'} = 'omdadmin:omd';
    TestUtils::test_page(
        'url'    => '/thruk/r/thruk/whoami',
        'like'   => ['omdadmin', 'authorized_for_admin'],
    );
};
