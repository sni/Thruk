use strict;
use warnings;
use Test::More tests => 4;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::status' }

ok( request('/status')->is_success, 'Status Request should succeed' );
ok( request('/nagios/cgi-bin/status.cgi')->is_success, 'Status Request should succeed' );
