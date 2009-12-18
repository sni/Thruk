use strict;
use warnings;
use Test::More tests => 8;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::Root' }

my $redirects = [
    '/',
    '/nagios',
    '/nagios/',
];
my $pages = [
    '/nagios/index.html',
    '/nagios/main.html',
    '/nagios/side.html',
];

for my $url (@{$redirects}) {
    ok( request($url)->is_redirect, 'Request '.$url.' should redirect' );
}
for my $url (@{$pages}) {
    ok( request($url)->is_success, 'Request '.$url.' should succeed' );
}
