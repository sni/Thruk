use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 4;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::tac' }

ok( request('/tac')->is_success, 'Tac Request should succeed' );
ok( request('/nagios/cgi-bin/tac.cgi')->is_success, 'Tac Request should succeed' );
