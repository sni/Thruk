use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 40;

###########################################################
# verify that we use the correct thruk binary
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# check x-forwarded-* header with curl requests
my $curl = '/usr/bin/env curl -ks';

TestUtils::test_command({
    cmd  => $curl.' -H "X-Forwarded-Port: 1234" https://127.0.0.1/demo/thruk/cgi-bin/login.cgi | grep "full_uri"',
    like => [qr%\Qhttp://127.0.0.1:1234/demo/thruk/cgi-bin/login.cgi\E%],
});

TestUtils::test_command({
    cmd  => $curl.' -H "X-Forwarded-Port: 1234" -H "X-Forwarded-Proto: https" https://127.0.0.1/demo/thruk/cgi-bin/login.cgi | grep "full_uri"',
    like => [qr%\Qhttps://127.0.0.1:1234/demo/thruk/cgi-bin/login.cgi\E%],
});

TestUtils::test_command({
    cmd  => $curl.' -H "X-Forwarded-Port: 443" -H "X-Forwarded-Proto: https" https://127.0.0.1/demo/thruk/cgi-bin/login.cgi | grep "full_uri"',
    like => [qr%\Qhttps://127.0.0.1/demo/thruk/cgi-bin/login.cgi\E%],
});

TestUtils::test_command({
    cmd  => $curl.' -H "X-Forwarded-Port: 1234" -H "X-Forwarded-Proto: http" https://127.0.0.1/demo/thruk/cgi-bin/login.cgi | grep "full_uri"',
    like => [qr%\Qhttp://127.0.0.1:1234/demo/thruk/cgi-bin/login.cgi\E%],
});

TestUtils::test_command({
    cmd  => $curl.' -H "X-Forwarded-Port: 80" -H "X-Forwarded-Proto: http" https://127.0.0.1/demo/thruk/cgi-bin/login.cgi | grep "full_uri"',
    like => [qr%\Qhttp://127.0.0.1/demo/thruk/cgi-bin/login.cgi\E%],
});

TestUtils::test_command({
    cmd  => $curl.' -H "X-Forwarded-Proto: http" https://127.0.0.1/demo/thruk/cgi-bin/login.cgi | grep "full_uri"',
    like => [qr%\Qhttp://127.0.0.1/demo/thruk/cgi-bin/login.cgi\E%],
});

TestUtils::test_command({
    cmd  => $curl.' -H "X-Forwarded-Proto: https" https://127.0.0.1/demo/thruk/cgi-bin/login.cgi | grep "full_uri"',
    like => [qr%\Qhttps://127.0.0.1/demo/thruk/cgi-bin/login.cgi\E%],
});

TestUtils::test_command({
    cmd  => $curl.' -H "X-Forwarded-Host: vhost.com" https://127.0.0.1/demo/thruk/cgi-bin/login.cgi | grep "full_uri"',
    like => [qr%\Qhttps://vhost.com/demo/thruk/cgi-bin/login.cgi\E%],
});

# invalid hostname
TestUtils::test_command({
    cmd  => $curl.' -H "X-Forwarded-Host: vhost.com/evil" https://127.0.0.1/demo/thruk/cgi-bin/login.cgi | grep "full_uri"',
    like => [qr%\Qhttps://127.0.0.1/demo/thruk/cgi-bin/login.cgi\E%],
});