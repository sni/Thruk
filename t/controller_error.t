use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 3;

BEGIN { use_ok 'Catalyst::Test', 'Thruk' }
BEGIN { use_ok 'Thruk::Controller::error' }

ok( request('/error')->is_redirect, 'Request should redirect' );
