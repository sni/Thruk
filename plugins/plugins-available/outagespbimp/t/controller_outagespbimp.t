use strict;
use warnings;
use Test::More;

use Catalyst::Test 'Thruk';

if(Thruk->config->{'enable_shinken_features'}) {
    plan(tests => 20);
} else {
    plan( skip_all => 'enable_shinken_features disabled by config' ) 
}

use lib('t');
require TestUtils;
import TestUtils;

use_ok 'Thruk::Controller::outagespbimp';

my $pages = [
    '/outagespbimp',
    '/thruk/cgi-bin/outagespbimp.cgi',
];

for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'like'    => 'Network Outages problem impacts',
        'unlike'  => [ 'internal server error', 'HASH', 'ARRAY' ],
    );
}
