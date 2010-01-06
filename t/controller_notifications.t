use strict;
use warnings;
use Test::More tests => 6;

BEGIN { use_ok 'Catalyst::Test', 'Thruk' }
BEGIN { use_ok 'Thruk::Controller::notifications' }

ok( request('/notifications')->is_success, 'Notifications Request should succeed' );
my $request = request('/thruk/cgi-bin/notifications.cgi');
ok( $request->is_success, 'Notifications Request should succeed' );
my $content = $request->content;
TODO: {
    local $TODO = "needs to be implemented";
    like($content, qr/Contact Notifications/, "Content contains: Contact Notifications");
};
unlike($content, qr/internal\ server\ error/mx, "Content contains error");
