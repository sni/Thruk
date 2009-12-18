use strict;
use warnings;
use Test::More tests => 4;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::history' }

ok( request('/history')->is_success, 'History Request should succeed' );
ok( request('/nagios/cgi-bin/history.cgi')->is_success, 'History Request should succeed' );
