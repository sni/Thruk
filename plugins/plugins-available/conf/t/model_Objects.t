use strict;
use warnings;
use Test::More;
use Data::Dumper;

plan skip_all => 'internal test only' if defined $ENV{'CATALYST_SERVER'};

$Data::Dumper::Sortkeys = 1;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok 'Thruk::Model::Objects';

use Catalyst::Test 'Thruk';

done_testing();
