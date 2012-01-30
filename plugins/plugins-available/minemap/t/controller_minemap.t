use strict;
use warnings;
use Test::More tests => 93;

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


# redirects
my $redirects = {
    '/thruk/cgi-bin/minemap.cgi?style=hostdetail' => 'status\.cgi\?style=hostdetail',
    '/thruk/cgi-bin/status.cgi?style=minemap'     => 'minemap\.cgi\?style=minemap',
};
for my $url (keys %{$redirects}) {
    TestUtils::test_page(
        'url'      => $url,
        'location' => $redirects->{$url},
        'redirect' => 1,
    );
}
