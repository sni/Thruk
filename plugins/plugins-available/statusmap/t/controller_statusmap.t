use strict;
use warnings;
use Test::More tests => 124;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

BEGIN { use_ok 'Thruk::Controller::statusmap' }

my($host,$service) = TestUtils::get_test_service();

my $pages = [
    '/statusmap',
    '/thruk/cgi-bin/statusmap.cgi',
    '/thruk/cgi-bin/statusmap.cgi?type=circle&groupby=parent&host='.$host,
    '/thruk/cgi-bin/statusmap.cgi?type=table&groupby=parent&host='.$host,
    '/thruk/cgi-bin/statusmap.cgi?type=hyper&groupby=parent&host='.$host,

    '/thruk/cgi-bin/statusmap.cgi?type=circle&groupby=address&host='.$host,
    '/thruk/cgi-bin/statusmap.cgi?type=table&groupby=address&host='.$host,
    '/thruk/cgi-bin/statusmap.cgi?type=hyper&groupby=address&host='.$host,

    '/thruk/cgi-bin/statusmap.cgi?type=circle&groupby=domain&host='.$host,
    '/thruk/cgi-bin/statusmap.cgi?type=table&groupby=domain&host='.$host,
    '/thruk/cgi-bin/statusmap.cgi?type=hyper&groupby=domain&host='.$host,

    '/thruk/cgi-bin/statusmap.cgi?type=circle&groupby=hostgroup&host='.$host,
    '/thruk/cgi-bin/statusmap.cgi?type=table&groupby=hostgroup&host='.$host,
    '/thruk/cgi-bin/statusmap.cgi?type=hyper&groupby=hostgroup&host='.$host,

    '/thruk/cgi-bin/statusmap.cgi?type=table&groupby=servicegroup&hidetop=',
    '/thruk/cgi-bin/statusmap.cgi?type=circle&groupby=servicegroup&host='.$host,
    '/thruk/cgi-bin/statusmap.cgi?type=hyper&groupby=servicegroup&host='.$host,

# bugs
];


for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Network Map For All Hosts',
        'unlike'  => 'internal server error',
    );
}
