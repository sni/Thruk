use strict;
use warnings;
use Data::Dumper;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-f 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan tests => 184;
}

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
    '/thruk/cgi-bin/extinfo.cgi',
    '/thruk/cgi-bin/extinfo.cgi?type=0',
    '/thruk/cgi-bin/extinfo.cgi?type=1&host='.$host,
    '/thruk/cgi-bin/extinfo.cgi?type=2&host='.$host.'&service='.$service,
    '/thruk/cgi-bin/extinfo.cgi?type=3',
    '/thruk/cgi-bin/extinfo.cgi?type=4',
    '/thruk/cgi-bin/extinfo.cgi?type=5&hostgroup='.$hostgroup,
    '/thruk/cgi-bin/extinfo.cgi?type=6',
    '/thruk/cgi-bin/extinfo.cgi?type=6&recurring',
    '/thruk/cgi-bin/extinfo.cgi?type=6&recurring=add_host',
    '/thruk/cgi-bin/extinfo.cgi?type=6&recurring=edit&host='.$host,
    '/thruk/cgi-bin/extinfo.cgi?type=6&recurring=edit&host='.$host.'&service='.$service,
    { url => '/thruk/cgi-bin/extinfo.cgi?type=6&recurring=save&old_host=&host='.$host.'&comment=automatic+downtime&send_type_1=month&send_day_1=1&week_day_1=&send_hour_1=0&send_minute_1=0&duration=120&childoptions=0', 'redirect' => 1, location => 'extinfo.cgi', like => 'This item has moved' },
    { url => '/thruk/cgi-bin/extinfo.cgi?type=6&recurring=remove&host='.$host, 'redirect' => 1, location => 'extinfo.cgi', like => 'This item has moved' },
    '/thruk/cgi-bin/extinfo.cgi?type=7',
    '/thruk/cgi-bin/extinfo.cgi?type=8&servicegroup='.$servicegroup,
];

for my $url (@{$pages}) {
    if(ref $url eq 'HASH') {
        TestUtils::test_page( %{$url} );
    } else {
        TestUtils::test_page( 'url' => $url );
    }
}
