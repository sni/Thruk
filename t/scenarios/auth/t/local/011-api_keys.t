use warnings;
use strict;
use Cpanel::JSON::XS qw/decode_json/;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 87;

use_ok('Thruk::Utils::IO');

###########################################################
# verify that we use the correct thruk binary
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# create api key
my $test = {
    cmd  => '/usr/bin/env thruk r -m POST /thruk/api_keys',
    like => ['/private_key/', '/hashed_key/', '/\.SHA\-256/'],
};
TestUtils::test_command($test);
my $data = decode_json($test->{'stdout'});
isnt($data->{'private_key'}, undef, "created api key");

###########################################################
# check some curl requests
my $curl = '/usr/bin/env curl -ks --header "X-Thruk-Auth-Key: '.$data->{'private_key'}.'"';
TestUtils::test_command({
    cmd  => $curl.' https://127.0.0.1/demo/thruk/r/',
    like => ['/lists cluster nodes/'],
});

TestUtils::test_command({
    cmd  => $curl.' https://127.0.0.1/demo/thruk/r/thruk/whoami',
    like => ['/"auth_src" : "api_key",/', '/"id" : "\(api\)",/'],
});

TestUtils::test_command({
    cmd  => $curl.' https://127.0.0.1/demo/thruk/r/thruk/api_keys',
    like => ['/last_from/', '/hashed_key/', '/'.$data->{'hashed_key'}.'/'],
});

TestUtils::test_command({
    cmd  => $curl.' --data "comment_data=testDowntime" https://127.0.0.1/demo/thruk/r/sites/ALL/hosts/test/cmd/schedule_host_downtime',
    like => ['/Command successfully submitted/', '/SCHEDULE_HOST_DOWNTIME/'],
});

###########################################################
# create superuser api key
$test = {
    cmd  => '/usr/bin/env thruk r -d superuser=1 -m POST /thruk/api_keys',
    like => ['/private_key/', '/hashed_key/', '/\.SHA\-256/'],
};
TestUtils::test_command($test);
$data = decode_json($test->{'stdout'});
isnt($data->{'private_key'}, undef, "created superuser api key");

###########################################################
# check some curl requests
$curl = '/usr/bin/env curl -ks --header "X-Thruk-Auth-Key: '.$data->{'private_key'}.'"';
TestUtils::test_command({
    cmd  => $curl.' https://127.0.0.1/demo/thruk/r/',
    like => ['/lists cluster nodes/'],
});

TestUtils::test_command({
    cmd  => $curl.' --header "X-Thruk-Auth-User: testuser" https://127.0.0.1/demo/thruk/r/thruk/whoami',
    like => ['/"auth_src" : "api_key",/', '/"id" : "testuser",/'],
});

TestUtils::test_command({
    cmd  => $curl.' https://127.0.0.1/demo/thruk/r/thruk/api_keys',
    like => ['/last_from/', '/hashed_key/', '/'.$data->{'hashed_key'}.'/'],
});

TestUtils::test_command({
    cmd  => $curl.' --data "comment_data=testDowntime" https://127.0.0.1/demo/thruk/r/sites/ALL/hosts/test/cmd/schedule_host_downtime',
    like => ['/Command successfully submitted/', '/SCHEDULE_HOST_DOWNTIME/'],
});

###########################################################
$test = {
    cmd  => '/usr/bin/env thruk apikey info '.$data->{'private_key'},
    like => ['/comment/', '/digest/', '/\.SHA\-256/', '/super user/'],
};
TestUtils::test_command($test);

$test = {
    cmd  => '/usr/bin/env thruk apikey info '.$data->{'file'},
    like => ['/comment/', '/digest/', '/\.SHA\-256/', '/super user/'],
};
TestUtils::test_command($test);

###########################################################
$test = {
    cmd  => '/usr/bin/env thruk apikey create -u test -r authorized_for_read_only --comment="test key"',
    like => ['/test key/', '/digest/', '/\.SHA\-256/', '/user.*test/', '/super user.*no/', '/role restriction.*authorized_for_read_only/' ],
};
TestUtils::test_command($test);

###########################################################
# test old md5 api keys (files have been migrated, but private key not)
{
    my $md5key = "d8e8fca2dc0f896fd7cb4cb0031ba249";
    my $curl   = '/usr/bin/env curl -ks --header "X-Thruk-Auth-Key: '.$md5key.'"';

    Thruk::Utils::IO::write("./var/thruk/api_keys/7eff66561fc5e3d39c13f675c02e762310479f4df951f0f9caa4769749fa7232.SHA-256", '{
    "comment" : "testing md5 key",
    "created" : '.time().',
    "user" : "md5user"
    }');

    TestUtils::test_command({
        cmd  => $curl.' https://127.0.0.1/demo/thruk/r/thruk/whoami',
        like => ['/"auth_src" : "api_key",/', '/"id" : "md5user",/'],
    });
};

###########################################################