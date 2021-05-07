use warnings;
use strict;
use Cpanel::JSON::XS qw/decode_json/;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 42;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# create api key for testuser2 and use that to send a command
{
    my $test = {
        cmd    => '/usr/bin/env thruk r -d "username=testuser2" /thruk/api_keys',
        like   => ['/private_key/'],
    };
    TestUtils::test_command($test);
    my $data = decode_json($test->{'stdout'});
    isnt($data->{'private_key'}, undef, "created api key");

    TestUtils::test_command({
        cmd    => '/usr/bin/env curl -s -H "X-Thruk-Auth-Key: '.$data->{'private_key'}.'" http://localhost/demo/thruk/r/thruk/whoami',
        like   => ['/testuser2/', '/testgroup2/'],
    });

    TestUtils::test_command({
        cmd    => '/usr/bin/env thruk cache clean',
        like   => ['/cache cleared/'],
    });
    TestUtils::test_command({
        cmd    => '/usr/bin/env omd reload apache',
        like   => ['/Reloading dedicated Apache/'],
    });
    TestUtils::test_command({
        cmd    => '/usr/bin/env thruk cache dump',
        like   => ['/\{\}/'],
        unlike => ['/testuser2/'],
    });
    TestUtils::test_command({
        cmd    => '/usr/bin/env curl -s -H "X-Thruk-Auth-Key: '.$data->{'private_key'}.'" -X POST http://localhost/demo/thruk/r/hosts/localhost/cmd/schedule_forced_host_check',
        like   => ['/successfully/'],
        unlike => ['/failed/'],
    });
    TestUtils::test_command({
        cmd    => '/usr/bin/env curl -s -H "X-Thruk-Auth-Key: '.$data->{'private_key'}.'" http://localhost/demo/thruk/r/hosts',
        like   => ['/localhost/'],
        unlike => ['/^\[\]/'],
    });
    TestUtils::test_command({
        cmd    => '/usr/bin/env thruk cache dump',
        like   => ['/global/', '/testgroup2/'],
    });
    unlink($data->{'file'});
}
