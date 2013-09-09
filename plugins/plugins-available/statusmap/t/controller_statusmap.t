use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan tests => 136;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

    use_ok 'Thruk::Controller::statusmap';
};

my($host,$service) = TestUtils::get_test_service();

my $pages = [
    '/thruk/cgi-bin/statusmap.cgi',
    '/thruk/cgi-bin/statusmap.cgi?type=circle&groupby=parent&host='.$host,
    '/thruk/cgi-bin/statusmap.cgi?type=table&groupby=parent&host='.$host,

    '/thruk/cgi-bin/statusmap.cgi?type=circle&groupby=address&host='.$host,
    '/thruk/cgi-bin/statusmap.cgi?type=table&groupby=address&host='.$host,

    '/thruk/cgi-bin/statusmap.cgi?type=circle&groupby=domain&host='.$host,
    '/thruk/cgi-bin/statusmap.cgi?type=table&groupby=domain&host='.$host,

    '/thruk/cgi-bin/statusmap.cgi?type=circle&groupby=hostgroup&host='.$host,
    '/thruk/cgi-bin/statusmap.cgi?type=table&groupby=hostgroup&host='.$host,

    '/thruk/cgi-bin/statusmap.cgi?type=table&groupby=servicegroup&hidetop=',
    '/thruk/cgi-bin/statusmap.cgi?type=circle&groupby=servicegroup&host='.$host,
];


for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Network Map',
    );
}
