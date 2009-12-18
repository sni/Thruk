use strict;
use warnings;
use Test::More tests => 4;

BEGIN { use_ok 'Catalyst::Test', 'Nagios::Web' }
BEGIN { use_ok 'Nagios::Web::Controller::histogram' }

ok( request('/histogram')->is_success, 'Histogram Request should succeed' );
ok( request('/nagios/cgi-bin/histogram.cgi')->is_success, 'Histogram Request should succeed' );
