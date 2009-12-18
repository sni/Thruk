use strict;
use warnings;
use Test::More tests => 6;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::outages' }

ok( request('/outages')->is_success, 'Outages Request should succeed' );
my $request = request('/nagios/cgi-bin/outages.cgi');
ok( $request->is_success, 'Outages Request should succeed' );
my $content = $request->content;
like($content, qr/Network Outages/, "Content contains: Network Outages");
unlike($content, qr/errorMessage/mx, "Content doesnt contains: errorMessage");