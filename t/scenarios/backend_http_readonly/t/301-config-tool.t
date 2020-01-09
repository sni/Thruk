use strict;
use warnings;
use Test::More;
use Cpanel::JSON::XS qw/decode_json/;

die("*** ERROR: this test is meant to be run with PLACK_TEST_EXTERNALSERVER_URI set") unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

BEGIN {
    plan tests => 11;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

TestUtils::test_page(
    url     => '/thruk/cgi-bin/conf.cgi',
    like    => ['No object configuration enabled'],
);
