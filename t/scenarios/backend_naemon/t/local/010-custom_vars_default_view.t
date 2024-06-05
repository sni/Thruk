use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 35;

$ENV{'THRUK_TEST_AUTH'}               = 'omdadmin:omd';
$ENV{'PLACK_TEST_EXTERNALSERVER_URI'} = 'http://127.0.0.1/demo';

use_ok("Thruk::Utils::IO");

###########################################################
# verify that we use the correct thruk binary
TestUtils::test_command({
    cmd  => '/bin/bash -c "type thruk"',
    like => ['/\/thruk\/script\/thruk/'],
}) or BAIL_OUT("wrong thruk path");

###########################################################
# thruk roles
TestUtils::test_command({
    cmd  => '/usr/bin/env thruk user.cgi',
    like => ['/>User<.*?>\(cli\)</', '/authorized_for_admin/'],
});

###########################################################
# create example config and reload apache
my $rc = Thruk::Utils::IO::write("etc/thruk/thruk_local.d/custom_var.conf", '
show_custom_vars = _TEST
show_custom_vars = __IMPACT
default_service_columns = host_name,description,state,last_check,cust__IMPACT:ImpactAlias,cust_TEST:TestAlias
');
ok($rc, 'etc/thruk/thruk_local.d/custom_var.conf');
TestUtils::test_command({
    cmd  => '/usr/bin/env omd reload apache',
    like => ['/Reloading apache.*OK/'],
});
sleep(3);

###########################################################
TestUtils::test_page(
    url  => '/thruk/cgi-bin/status.cgi?host=test',
    like => ['ImpactAlias', 'TestAlias', 'dbl underscore hst', 'dbl underscore svc', 'test var hst', 'test var svc'],
);

###########################################################
# cleanup test config
unlink("etc/thruk/thruk_local.d/custom_var.conf");
TestUtils::test_command({
    cmd  => '/usr/bin/env omd reload apache',
    like => ['/Reloading apache.*OK/'],
});
sleep(3);
