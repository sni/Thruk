use strict;
use warnings;
use Test::More tests => 4;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::config' }

ok( request('/config')->is_success, 'Config Request should succeed' );
ok( request('/nagios/cgi-bin/config.cgi')->is_success, 'Config Request should succeed' );
