use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use Catalyst::Test 'Thruk';

ok( request('/')->is_redirect, 'Request should redirect' );
