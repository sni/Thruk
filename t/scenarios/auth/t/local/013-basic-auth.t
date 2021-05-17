use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 22;

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
    cmd  => $curl.' -u omdadmin:omd https://127.0.0.1/demo/thruk/r/',
    like => ['/lists cluster nodes/'],
});

TestUtils::test_command({
    cmd  => $curl.' -u omdadmin:wrong https://127.0.0.1/demo/thruk/r/',
    like => ['/The document has moved/', '/login.cgi/'],
});

TestUtils::test_command({
    cmd  => $curl.' -u omdadmin:omd https://127.0.0.1/demo/thruk/cgi-bin/user.cgi',
    like => ['/Logged in as/'],
});

TestUtils::test_command({
    cmd  => $curl.' -u omdadmin:wrong https://127.0.0.1/demo/thruk/cgi-bin/user.cgi',
    like => ['/The document has moved/', '/login.cgi/'],
});
