use strict;
use warnings;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::extinfo' }

ok( request('/extinfo')->is_success, 'Request should succeed' );


