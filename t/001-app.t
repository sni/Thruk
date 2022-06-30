use warnings;
use strict;
use Config;
use Test::More tests => 5;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $request = request('/thruk/main.html');
ok( $request->is_success, 'Request /thruk/main.html should succeed' ) or TestUtils::bail_out_req('request should succeed', $request);

SKIP: {
    skip 'external tests', 1 if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};

    ok( request('/')->is_redirect, 'Request / should redirect' );
};

# make sure static content has Last-Modfied header
$request = request('/thruk/themes/Thruk/images/logo_thruk.png');
ok($request->headers('last-modified'), "static content request has last-modified header");
ok($request->headers('content-length'), "static content request has content-length header");

use_ok("Thruk::Config");

diag(sprintf("Thruk: %s - Perl: %s - Arch: %s", Thruk::Config::get_thruk_version(), $^V, $Config{'archname'}));
