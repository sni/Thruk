use strict;
use warnings;
use Test::More tests => 6;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::avail' }

ok( request('/avail')->is_success, 'Avail Request should succeed' );
my $request = request('/nagios/cgi-bin/avail.cgi');
ok( $request->is_success, 'Avail Request should succeed' );
my $content = $request->content;
TODO: {
    local $TODO = "needs to be implemented";
    like($content, qr/Availability Report/, "Content contains: Availability Report");
};
unlike($content, qr/errorMessage/mx, "Content doesnt contains: errorMessage");