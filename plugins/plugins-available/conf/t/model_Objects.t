use strict;
use warnings;
use Test::More;
use Data::Dumper;

$Data::Dumper::Sortkeys = 1;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

BEGIN { use_ok 'Thruk::Model::Objects' }

use Catalyst::Test 'Thruk';

done_testing();
