use strict;
use warnings;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###############################################################################
# wait till backend container is fully started
TestUtils::test_page(
    'url'     => '/thruk/r/sites?status=0&columns=count(*)',
    'waitfor' => '"count\(\*\)"\ :\ 1',
);

###############################################################################

done_testing();
