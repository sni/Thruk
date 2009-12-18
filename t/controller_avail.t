use strict;
use warnings;
use Test::More tests => 4;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::avail' }

ok( request('/avail')->is_success, 'Avail Request should succeed' );
ok( request('/nagios/cgi-bin/avail.cgi')->is_success, 'Avail Request should succeed' );
