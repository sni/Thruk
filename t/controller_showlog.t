use strict;
use warnings;
use Test::More tests => 4;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::showlog' }

ok( request('/showlog')->is_success, 'Showlog Request should succeed' );
ok( request('/nagios/cgi-bin/showlog.cgi')->is_success, 'Showlog Request should succeed' );
