use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 15;

BEGIN { use_ok 'Catalyst::Test', 'Thruk' }
BEGIN { use_ok 'Thruk::Controller::Root' }

my $redirects = [
    '/',
];
my $pages = [
    '/thruk',
    '/thruk/',
    '/thruk/docs/index.html',
    '/thruk/index.html',
    '/thruk/main.html',
    '/thruk/side.html',
];

for my $url (@{$redirects}) {
    ok( request($url)->is_redirect, 'Request '.$url.' should redirect' );
}
for my $url (@{$pages}) {
    my $request = request($url);
    ok( $request->is_success, 'Request '.$url.' should succeed' ) or diag(Dumper($request));
    my $content = $request->content;
    unlike($content, qr/internal\ server\ error/mx, "Content contains error");
}
