use strict;
use warnings;
use Test::More tests => 42;

BEGIN { use_ok 'Catalyst::Test', 'Thruk' }
BEGIN { use_ok 'Thruk::Controller::config' }

ok( request('/config')->is_success, 'Config Request should succeed' );

my $pages = [
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
    my $request = request($url);
    ok( $request->is_success, 'Request '.$url.' should succeed' );
    my $content = $request->content;
    like($content, qr/Configuration/, "Content contains: Configuration");
    unlike($content, qr/internal\ server\ error/mx, "Content contains error");
}
