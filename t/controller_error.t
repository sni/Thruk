use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 17;

BEGIN { use_ok 'Catalyst::Test', 'Thruk' }
BEGIN { use_ok 'Thruk::Controller::error' }

$ENV{'TEST_ERROR'} = 1;
ok( request('/error')->is_error, 'Request should fail' );
for(1..14) {
  ok( request('/error/'.$_)->is_error, 'Request should fail' );
}
delete $ENV{'TEST_ERROR'};
