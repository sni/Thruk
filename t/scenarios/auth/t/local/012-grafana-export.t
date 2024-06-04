use warnings;
use strict;
use Cpanel::JSON::XS qw/decode_json/;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 53;

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

# wait till histou/influx is ready
TestUtils::test_command({
    cmd     => $curl.' "http://127.0.0.1/demo/histou/index.php?host=test&service=Ping&annotations=true&callback=jQuery36108434547110946526_1676536465838"',
    waitfor => 'test\ Ping\ check_ping\ pl',
    maxwait => 120, # grafana might need some time to get ready
});

# fails directly after first start, so do it twice
for (1..2) {
    TestUtils::test_command({
        cmd  => $curl.' "https://127.0.0.1/demo/thruk/cgi-bin/extinfo.cgi?type=grafana&host=test&service=Ping&width=200&height=200" -o tmp/grafana.png',
        like => ['/^$/'],
    });
}

TestUtils::test_command({
    cmd  => '/usr/bin/env file tmp/grafana.png',
    like => ['/tmp/grafana.png: PNG image data, 200 x 200, 8-bit\/color RGB, non-interlaced/'],
});

TestUtils::test_command({
    cmd  => '/bin/bash -c "thruk graph --host=test --service=Ping --width=200 --height=200 --format=png > tmp/grafana.png"',
    like => ['/^$/'],
});

TestUtils::test_command({
    cmd  => '/usr/bin/env file tmp/grafana.png',
    like => ['/tmp/grafana.png: PNG image data, 200 x 200, 8-bit\/color RGB, non-interlaced/'],
});

TestUtils::test_command({
    cmd  => '/bin/bash -c "thruk graph --host=test --service=Ping --width=200 --height=200 --format=base64 -o tmp/grafana.base64"',
    like => ['/graph written to/'],
});

TestUtils::test_command({
    cmd  => '/bin/bash -c "base64 -d tmp/grafana.base64 > tmp/grafana.png"',
    like => ['/^$/'],
});

TestUtils::test_command({
    cmd  => '/usr/bin/env file tmp/grafana.png',
    like => ['/tmp/grafana.png: PNG image data, 200 x 200, 8-bit\/color RGB, non-interlaced/'],
});
