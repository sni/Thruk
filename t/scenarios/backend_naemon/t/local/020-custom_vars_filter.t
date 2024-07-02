use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 27;

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
TestUtils::test_page(
    url  => '/thruk/cgi-bin/status.cgi?style=hostdetail&dfl_s0_type=custom variable&dfl_s0_val_pre=TEST&dfl_s0_op=%3D&dfl_s0_value=test var hst',
    like => ['host=test'],
);

TestUtils::test_page(
    url  => '/thruk/cgi-bin/status.cgi?style=hostdetail&dfl_s0_type=custom variable&dfl_s0_val_pre=_IMPACT&dfl_s0_op=%3D&dfl_s0_value=dbl underscore hst',
    like => ['host=test'],
);

###########################################################
