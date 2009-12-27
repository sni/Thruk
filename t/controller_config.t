use strict;
use warnings;
use Test::More tests => 42;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::config' }

ok( request('/config')->is_success, 'Config Request should succeed' );

my $pages = [
    '/nagios/cgi-bin/config.cgi',
    '/nagios/cgi-bin/config.cgi?type=hosts',
    '/nagios/cgi-bin/config.cgi?type=hostdependencies',
    '/nagios/cgi-bin/config.cgi?type=hostescalations',
    '/nagios/cgi-bin/config.cgi?type=hostgroups',
    '/nagios/cgi-bin/config.cgi?type=services',
    '/nagios/cgi-bin/config.cgi?type=servicegroups',
    '/nagios/cgi-bin/config.cgi?type=servicedependencies',
    '/nagios/cgi-bin/config.cgi?type=serviceescalations',
    '/nagios/cgi-bin/config.cgi?type=contacts',
    '/nagios/cgi-bin/config.cgi?type=contactgroups',
    '/nagios/cgi-bin/config.cgi?type=timeperiods',
    '/nagios/cgi-bin/config.cgi?type=commands',
];

for my $url (@{$pages}) {
    my $request = request($url);
    ok( $request->is_success, 'Request '.$url.' should succeed' );
    my $content = $request->content;
    like($content, qr/Configuration/, "Content contains: Configuration");
    unlike($content, qr/internal\ server\ error/mx, "Content contains error");
}
