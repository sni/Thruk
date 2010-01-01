use strict;
use warnings;
use Test::More tests => 15;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::history' }

ok( request('/history')->is_success, 'History Request should succeed' );
my $request = request('/nagios/cgi-bin/history.cgi');
ok( $request->is_success, 'History Request should succeed' );
my $content = $request->content;
like($content, qr/Alert History/, "Content contains: Alert History");
unlike($content, qr/internal\ server\ error/mx, "Content contains error");

$request = request('/nagios/cgi-bin/history.cgi?host=all');
ok( $request->is_success, 'History Request should succeed' );
$content = $request->content;
like($content, qr/Alert History/, "Content contains: Alert History");
unlike($content, qr/internal\ server\ error/mx, "Content contains error");

$request = request('/nagios/cgi-bin/history.cgi?host=unknownhost');
ok( $request->is_success, 'History Request should succeed' );
$content = $request->content;
like($content, qr/Host Alert History/, "Content contains: Host Alert History");
unlike($content, qr/internal\ server\ error/mx, "Content contains error");

$request = request('/nagios/cgi-bin/history.cgi?host=unknownhost&service=unknownservice');
ok( $request->is_success, 'History Request should succeed' );
$content = $request->content;
like($content, qr/Service Alert History/, "Content contains: Service Alert History");
unlike($content, qr/internal\ server\ error/mx, "Content contains error");