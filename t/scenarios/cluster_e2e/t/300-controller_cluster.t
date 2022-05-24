use warnings;
use strict;
use Test::More;

BEGIN {
    plan tests => 53;

    use lib('t');
    require TestUtils;
    import TestUtils;
}

TestUtils::set_test_user_token();

# since the cluster is round-robin, this should trigger an update on each node
for my $x (1..3) {
    TestUtils::test_page(
        'url'     => '/thruk/r/thruk/cluster/heartbeat',
        'post'    => {},
        'waitfor' => 'heartbeat\ send',
    );
}

# since the cluster is round-robin, this should trigger an update on each node
for my $x (1..3) {
    TestUtils::test_page(
        'url'     => '/thruk/r/thruk/cluster/heartbeat',
        'post'    => {},
        'like'    => ['heartbeat send'],
    );
}

TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/extinfo.cgi?type=4&cluster=1',
    'like'    => ['Performance Information', 'Cluster Status', '<i[^>]+"ok"[^>]*>'],
);

TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/proxy.cgi/e0364/demo/thruk/cgi-bin/tac.cgi',
    'like'    => ['Tactical Monitoring Overview'],
);
