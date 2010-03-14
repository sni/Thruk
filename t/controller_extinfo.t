use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 75;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::extinfo' }

my $hostgroup      = TestUtils::get_test_hostgroup();
my $servicegroup   = TestUtils::get_test_servicegroup();
my($host,$service) = TestUtils::get_test_service();

my $pages = [
    '/extinfo',
    '/thruk/cgi-bin/extinfo.cgi',
    '/thruk/cgi-bin/extinfo.cgi?type=0',
    '/thruk/cgi-bin/extinfo.cgi?type=1&host='.$host,
    '/thruk/cgi-bin/extinfo.cgi?type=2&host='.$host.'&service='.$service,
    '/thruk/cgi-bin/extinfo.cgi?type=3',
    '/thruk/cgi-bin/extinfo.cgi?type=4',
    '/thruk/cgi-bin/extinfo.cgi?type=5&hostgroup='.$hostgroup,
    '/thruk/cgi-bin/extinfo.cgi?type=6',
    '/thruk/cgi-bin/extinfo.cgi?type=7',
    '/thruk/cgi-bin/extinfo.cgi?type=8&servicegroup='.$servicegroup,
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'unlike'  => 'internal server error',
    );
}
