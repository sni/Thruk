use strict;
use warnings;
use Test::More tests => 1;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use Catalyst::Test 'Thruk';

SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

    ok( request('/')->is_redirect, 'Request should redirect' );
};
