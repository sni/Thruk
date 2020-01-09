use strict;
use warnings;
use Test::More;
use Cpanel::JSON::XS qw/decode_json/;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 23;

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
# fetch grafana image
my $curl = '/usr/bin/env curl -ks --header "X-Thruk-Auth-Key: '.$data->{'private_key'}.'"';
# wait till grafana is ready
TestUtils::test_command({
    cmd     => $curl.' "https://127.0.0.1/demo/grafana/"',
    waitfor => '"login":"\(api\)"',
});
TestUtils::test_command({
    cmd  => $curl.' "https://127.0.0.1/demo/thruk/cgi-bin/extinfo.cgi?type=grafana&host=test&service=Ping&width=200&height=200" -o tmp/grafana.png',
    like => ['/^$/'],
});

TestUtils::test_command({
    cmd  => '/usr/bin/env file tmp/grafana.png',
    like => ['/tmp/grafana.png: PNG image data, 200 x 200, 8-bit\/color RGBA, non-interlaced/'],
});
