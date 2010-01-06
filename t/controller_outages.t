use strict;
use warnings;
use Test::More tests => 6;

BEGIN { use_ok 'Catalyst::Test', 'Thruk' }
BEGIN { use_ok 'Thruk::Controller::outages' }

ok( request('/outages')->is_success, 'Outages Request should succeed' );
my $request = request('/thruk/cgi-bin/outages.cgi');
ok( $request->is_success, 'Outages Request should succeed' );
my $content = $request->content;
like($content, qr/Network Outages/, "Content contains: Network Outages");
unlike($content, qr/internal\ server\ error/mx, "Content contains error");
