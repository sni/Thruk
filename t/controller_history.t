use strict;
use warnings;
use Test::More tests => 6;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::history' }

ok( request('/history')->is_success, 'History Request should succeed' );
my $request = request('/nagios/cgi-bin/history.cgi');
ok( $request->is_success, 'History Request should succeed' );
my $content = $request->content;
TODO: {
    local $TODO = "needs to be implemented";
    like($content, qr/Alert History/, "Content contains: Alert History");
};
unlike($content, qr/errorMessage/mx, "Content doesnt contains: errorMessage");