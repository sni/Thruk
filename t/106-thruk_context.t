use strict;
use warnings;
use Test::More;

BEGIN {
    plan tests => 6;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok('Thruk::Context');

{
    my $pathinfo = Thruk::Context::translate_request_path("/thruk/cgi-bin/tac.cgi", {product_prefix => 'thruk'});
    is($pathinfo, "/thruk/cgi-bin/tac.cgi", "pathinfo for /thruk/cgi-bin/tac.cgi");
};

{
    my $pathinfo = Thruk::Context::translate_request_path("/naemon/cgi-bin/tac.cgi", {product_prefix => 'naemon'});
    is($pathinfo, "/thruk/cgi-bin/tac.cgi", "pathinfo for /thruk/cgi-bin/tac.cgi with naemon product");
};

{
    local $ENV{'OMD_SITE'} = "test";
    my $pathinfo = Thruk::Context::translate_request_path("/test/thruk/cgi-bin/tac.cgi", {product_prefix => 'thruk'});
    is($pathinfo, "/thruk/cgi-bin/tac.cgi", "pathinfo for /thruk/cgi-bin/tac.cgi with omd site");
};

{
    local $ENV{'OMD_SITE'} = "thruk";
    my $pathinfo = Thruk::Context::translate_request_path("/thruk/thruk/cgi-bin/tac.cgi", {product_prefix => 'thruk'});
    is($pathinfo, "/thruk/cgi-bin/tac.cgi", "pathinfo for /thruk/cgi-bin/tac.cgi with omd site named thruk");
};

{
    local $ENV{'OMD_SITE'} = "thruk";
    my $pathinfo = Thruk::Context::translate_request_path("/thruk/cgi-bin/tac.cgi", {product_prefix => 'thruk'});
    is($pathinfo, "/thruk/cgi-bin/tac.cgi", "pathinfo for /thruk/cgi-bin/tac.cgi with omd site named thruk");
};