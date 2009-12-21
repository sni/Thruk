use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 6;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::tac' }

ok( request('/tac')->is_success, 'Tac Request should succeed' );
my $request = request('/nagios/cgi-bin/tac.cgi');
ok( $request->is_success, 'Tac Request should succeed' );
my $content = $request->content;
like($content, qr/Network\s+Outages/mx, "Content contains: Network Outages");
unlike($content, qr/internal\ server\ error/mx, "Content contains error");
