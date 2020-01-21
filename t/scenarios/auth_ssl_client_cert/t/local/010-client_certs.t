use strict;
use warnings;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 13;

###########################################################
# verify that we use the correct thruk binary
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# check some curl requests
my $curl = '/usr/bin/env curl -ks';
TestUtils::test_command({
    cmd  => $curl.' -L --cert etc/certs/client.pem --key etc/certs/client-key.pem https://127.0.0.1/demo/thruk/r/thruk/whoami',
    like => ['/test@localhost/', '/secret_key/'],
});


TestUtils::test_command({
    cmd  => $curl.' -L https://127.0.0.1/demo/thruk/r/thruk/whoami',
    like => ['/no or invalid credentials used/'],
});

