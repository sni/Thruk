use strict;
use warnings;
use Test::More tests => 6;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::showlog' }

ok( request('/showlog')->is_success, 'Showlog Request should succeed' );
my $request = request('/nagios/cgi-bin/showlog.cgi');
ok( $request->is_success, 'Showlog Request should succeed' );
my $content = $request->content;
TODO: {
    local $TODO = "needs to be implemented";
    like($content, qr/Current Event Log/, "Content contains: Current Event Log");
};
unlike($content, qr/errorMessage/mx, "Content doesnt contains: errorMessage");