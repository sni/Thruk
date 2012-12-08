use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 2;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use Catalyst::Test 'Thruk';

my $request = request('/thruk/side.html');
ok( $request->is_success, 'Request /thruk/side.html should succeed' ) or TestUtils::bail_out_req('request should succeed', $request);

SKIP: {
    skip 'external tests', 1 if defined $ENV{'CATALYST_SERVER'};

    ok( request('/')->is_redirect, 'Request / should redirect' );
};
