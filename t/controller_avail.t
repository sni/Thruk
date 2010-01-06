use strict;
use warnings;
use Test::More tests => 6;

BEGIN { use_ok 'Catalyst::Test', 'Thruk' }
BEGIN { use_ok 'Thruk::Controller::avail' }

ok( request('/avail')->is_success, 'Avail Request should succeed' );
my $request = request('/thruk/cgi-bin/avail.cgi');
ok( $request->is_success, 'Avail Request should succeed' );
my $content = $request->content;
like($content, qr/Availability Report/, "Content contains: Availability Report");
unlike($content, qr/internal\ server\ error/mx, "Content contains error");
