use strict;
use warnings;
use Test::More tests => 81;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

BEGIN { use_ok 'Thruk::Controller::dashboard' }

my($host,$service) = TestUtils::get_test_service();
my $hostgroup      = TestUtils::get_test_hostgroup();
my $servicegroup   = TestUtils::get_test_servicegroup();

my $pages = [
    '/thruk/cgi-bin/dashboard.cgi',
    '/thruk/cgi-bin/dashboard.cgi?hostgroup=all',
    '/thruk/cgi-bin/dashboard.cgi?hostgroup='.$hostgroup,
    '/thruk/cgi-bin/dashboard.cgi?host=all',
    '/thruk/cgi-bin/dashboard.cgi?host='.$host,
    '/thruk/cgi-bin/dashboard.cgi?servicegroup='.$servicegroup,
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => [ 'Dashboard', 'statusTitle' ],
    );
}


# redirects
my $redirects = {
    '/thruk/cgi-bin/dashboard.cgi?style=hostdetail' => 'status\.cgi\?style=hostdetail',
    '/thruk/cgi-bin/status.cgi?style=dashboard'     => 'dashboard\.cgi\?style=dashboard',
};
for my $url (keys %{$redirects}) {
    TestUtils::test_page(
        'url'      => $url,
        'location' => $redirects->{$url},
        'redirect' => 1,
    );
}
