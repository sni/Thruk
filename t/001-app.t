use strict;
use warnings;
use Test::More tests => 5;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $request = request('/thruk/side.html');
ok( $request->is_success, 'Request /thruk/side.html should succeed' ) or TestUtils::bail_out_req('request should succeed', $request);

SKIP: {
    skip 'external tests', 1 if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

    ok( request('/')->is_redirect, 'Request / should redirect' );
};

# make sure static content has Last-Modfied header
$request = request('/thruk/themes/Thruk/images/ack.gif');
ok($request->headers('last-modified'), "static content request has last-modified header");
ok($request->headers('content-length'), "static content request has content-length header");

use_ok("Thruk::Config");
use Config;
diag(sprintf("Thruk: %s - Perl: %s - Arch: %s", Thruk::Config::get_thruk_version(), $^V, $Config{'archname'}));
