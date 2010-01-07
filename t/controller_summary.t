use strict;
use warnings;
use Test::More tests => 6;

BEGIN { use_ok 'Catalyst::Test', 'Thruk' }
BEGIN { use_ok 'Thruk::Controller::summary' }

ok( request('/summary')->is_success, 'Summary Request should succeed' );
my $request = request('/thruk/cgi-bin/summary.cgi');
ok( $request->is_success, 'Summary Request should succeed' );
my $content = $request->content;
TODO: {
    local $TODO = "needs to be implemented";
    like($content, qr/Alert Summary Report/, "Content contains: Alert Summary Report");
};
unlike($content, qr/internal\ server\ error/mx, "Content contains error");
