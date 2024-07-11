use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 25;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
my $curl_omdadmin = '/usr/bin/env curl -s -H "X-Thruk-Auth-Key: ff8cde7bc92c261a260a180ef4d35c456853b70d955c3eb1c41098d0d561268b_1" -H "Content-Type: application/json"';
{
    # create service account
    my $test = {
        cmd  => $curl_omdadmin.' -d \'{ "name": "grafana", "role": "Viewer", "isDisabled": false }\' "http://omd.test.local/demo/grafana/api/serviceaccounts"',
        like => ['/"id":/', '/"isDisabled":false/'],
    };
    TestUtils::test_command($test);
    my $id;
    if($test->{'stdout'} =~ m/"id":(\d+)/) {
        $id = $1;
    }
    ok($id, "got id for service account");
    last unless $id;

    # create service account token
    $test = {
        cmd  => $curl_omdadmin.' -d \'{ "name": "grafana" }\' "http://omd.test.local/demo/grafana/api/serviceaccounts/'.$id.'/tokens"',
        like => ['/"key":/', '/"id":/'],
    };
    TestUtils::test_command($test);
    my $token;
    if($test->{'stdout'} =~ m/"key":"([^"]*)"/) {
        $token = $1;
    }
    ok($id, "got token for service bearer token");

    # fetch alerts using the bearer token
    TestUtils::test_command({
        cmd  => '/usr/bin/env curl -s -H "Authorization: Bearer '.$token.'" -H "Content-Type: application/json" "http://omd.test.local/demo/grafana/api/prometheus/grafana/api/v1/alerts"',
        like => ['/success/', '/"data":/'],
    });

    # remove service account
    TestUtils::test_command({
        cmd  => $curl_omdadmin.' -X DELETE "http://omd.test.local/demo/grafana/api/serviceaccounts/'.$id.'"',
        like => ['/Service account deleted/'],
    });
};
