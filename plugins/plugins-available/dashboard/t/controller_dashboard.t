use strict;
use warnings;
use Test::More tests => 106;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan skip_all => 'local test only'   if defined $ENV{'CATALYST_SERVER'};

    # enable plugin
    `cd plugins/plugins-enabled && ln -s ../plugins-available/dashboard .`;

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

# restore default
`cd plugins/plugins-enabled && rm -f dashboard`;
unlink('root/thruk/plugins/dashboard');
