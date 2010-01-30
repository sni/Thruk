use strict;
use warnings;
use Test::More tests => 86;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::config' }

my $pages = [
    '/config',
    '/thruk/cgi-bin/config.cgi',
    '/thruk/cgi-bin/config.cgi?type=hosts',
    '/thruk/cgi-bin/config.cgi?type=hostdependencies',
    '/thruk/cgi-bin/config.cgi?type=hostescalations',
    '/thruk/cgi-bin/config.cgi?type=hostgroups',
    '/thruk/cgi-bin/config.cgi?type=services',
    '/thruk/cgi-bin/config.cgi?type=servicegroups',
    '/thruk/cgi-bin/config.cgi?type=servicedependencies',
    '/thruk/cgi-bin/config.cgi?type=serviceescalations',
    '/thruk/cgi-bin/config.cgi?type=contacts',
    '/thruk/cgi-bin/config.cgi?type=contactgroups',
    '/thruk/cgi-bin/config.cgi?type=timeperiods',
    '/thruk/cgi-bin/config.cgi?type=commands',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Configuration',
        'unlike'  => 'internal server error',
    );
}
