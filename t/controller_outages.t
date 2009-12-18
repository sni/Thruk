use strict;
use warnings;
use Test::More tests => 4;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::outages' }

ok( request('/outages')->is_success, 'Outages Request should succeed' );
ok( request('/nagios/cgi-bin/outages.cgi')->is_success, 'Outages Request should succeed' );
