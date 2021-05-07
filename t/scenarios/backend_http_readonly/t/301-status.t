use warnings;
use strict;
use Cpanel::JSON::XS qw/decode_json/;
use Test::More;

die("*** ERROR: this test is meant to be run with PLACK_TEST_EXTERNALSERVER_URI set") unless defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

BEGIN {
    plan tests => 13;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

TestUtils::test_page(
    url     => '/thruk/cgi-bin/status.cgi',
    like    => ['localhost', 'Http', 'Zombie Procs'],
);
