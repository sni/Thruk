use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan tests => 124;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

    use_ok 'Thruk::Controller::mobile';
};

my($host,$service) = TestUtils::get_test_service();

my $pages = [
    '/thruk/cgi-bin/mobile.cgi',
    '/thruk/cgi-bin/mobile.cgi#problems',
    '/thruk/cgi-bin/mobile.cgi#options',
    '/thruk/cgi-bin/mobile.cgi#hosts',
    '/thruk/cgi-bin/mobile.cgi#hosts_list?hoststatustypes=2',
    '/thruk/cgi-bin/mobile.cgi#host?host='.$host,
    '/thruk/cgi-bin/mobile.cgi#services',
    '/thruk/cgi-bin/mobile.cgi#service?host='.$host.'&service='.$service,
    '/thruk/cgi-bin/mobile.cgi#alerts',
    '/thruk/cgi-bin/mobile.cgi#notifications',
];


for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Mobile Thruk',
    );
}
