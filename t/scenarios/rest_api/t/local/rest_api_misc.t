use warnings;
use strict;
use Test::More;
use utf8;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
plan tests => 57;

###########################################################
# test thruks script path
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

$ENV{'THRUK_TEST_AUTH_KEY'}  = "testkey";
$ENV{'THRUK_TEST_AUTH_USER'} = "omdadmin";

###########################################################
# rest api text transformation
{
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/hosts/localhost?columns=name,calc(rta, "+", 1) as rta_plus&headers=wrapped_json\'',
        like => ['/rta_plus/', '/localhost/', '/"ms"/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/hosts/localhost?columns=name,unit(calc(rta, "*", 1000), "s") as rta_seconds&headers=wrapped_json\'',
        like => ['/rta_seconds/', '/localhost/', '/"s"/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/hosts/localhost?columns=substr(name,0,3)\'',
        like => ['/"loc"/'],
    });
};

###########################################################
# mixed stats and transformation
{
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/hosts/localhost?columns=avg(unit(calc(last_check,/,1000), "ms")) as testcheck&headers=wrapped_json\'',
        like => ['/"ms"/', '/"testcheck"/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/csv/services?columns=avg(calc(state, "*", 100)):avgState,host_name\'',
        like => ['/0;Test/', '/0;localhost/' ],
    });
};

###########################################################
# disaggregation function
{
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/hosts?columns=to_rows(services) as service&headers=wrapped_json\'',
        like => ['/"Users"/', '/"service"/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/hosts?columns=name,to_rows(services) as svc&headers=wrapped_json\'',
        like => ['/"Users"/', '/"svc"/'],
    });
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/hosts?columns=name,upper(to_rows(services)) as svc&headers=wrapped_json\'',
        like => ['/"USERS"/', '/"svc"/'],
    });
};

###########################################################
# aggregation function
{
    # count services by hostname
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/csv/services?columns=count(*):num,host_name&sort=-count(*)\'',
        like => ['/8;localhost/'],
    });
    # count services by hostname and state
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/csv/services?columns=host_name,state,count(*):num&sort=-count(*)\'',
        like => ['/localhost;0;/'],
    });
    # count services by part of hostname and state
    TestUtils::test_command({
        cmd  => '/usr/bin/env thruk r \'/csv/services?columns=count(*):num,upper(substr(host_name, 0, 2)),state\'',
        like => ['/;LO;0/'],
    });
}

###########################################################
