use strict;
use warnings;
use Test::More tests => 4;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::statusmap' }

ok( request('/statusmap')->is_success, 'Statusmap Request should succeed' );
ok( request('/nagios/cgi-bin/statusmap.cgi')->is_success, 'Statusmap Request should succeed' );
