use strict;
use warnings;
use Test::More tests => 6;

BEGIN { use_ok 'Catalyst::Test', 'Thruk' }
BEGIN { use_ok 'Thruk::Controller::trends' }

ok( request('/trends')->is_success, 'Trends Request should succeed' );
my $request = request('/thruk/cgi-bin/trends.cgi');
ok( $request->is_success, 'Trends Request should succeed' );
my $content = $request->content;
TODO: {
    local $TODO = "needs to be implemented";
    like($content, qr/Host and Service State Trends/, "Content contains: Host and Service State Trends");
};
unlike($content, qr/internal\ server\ error/mx, "Content contains error");
