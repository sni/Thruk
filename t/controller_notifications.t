use strict;
use warnings;
use Test::More tests => 4;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::notifications' }

ok( request('/notifications')->is_success, 'Notifications Request should succeed' );
ok( request('/nagios/cgi-bin/notifications.cgi')->is_success, 'Notifications Request should succeed' );
