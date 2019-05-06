use strict;
use warnings;
use Test::More;
use Cpanel::JSON::XS qw/decode_json/;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 26;

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
    cmd  => $curl.' https://127.0.0.1/demo/thruk/r/thruk/api_keys',
    like => ['/last_from/', '/hashed_key/', '/'.$data->{'hashed_key'}.'/'],
});

TestUtils::test_command({
    cmd  => $curl.' --data "comment_data=testDowntime" https://127.0.0.1/demo/thruk/r/sites/ALL/hosts/test/cmd/schedule_host_downtime',
    like => ['/Command successfully submitted/', '/SCHEDULE_HOST_DOWNTIME/'],
});