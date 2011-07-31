use strict;
use warnings;
use Test::More tests => 69;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

BEGIN { use_ok 'Thruk::Controller::minemap' }

my($host,$service) = TestUtils::get_test_service();
my $hostgroup      = TestUtils::get_test_hostgroup();
my $servicegroup   = TestUtils::get_test_servicegroup();

my $pages = [
    '/thruk/cgi-bin/minemap.cgi',
    '/thruk/cgi-bin/minemap.cgi?hostgroup=all',
    '/thruk/cgi-bin/minemap.cgi?hostgroup='.$hostgroup,
    '/thruk/cgi-bin/minemap.cgi?host=all',
    '/thruk/cgi-bin/minemap.cgi?host='.$host,
    '/thruk/cgi-bin/minemap.cgi?servicegroup='.$servicegroup,
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => [ 'Mine Map', 'statusTitle' ],
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}
