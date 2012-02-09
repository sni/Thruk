use strict;
use warnings;
use Data::Dumper;
use Test::More tests => 217;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::error' }

my $pages = [];
for(0..23) {
    push @{$pages}, '/error/'.$_;
}

$ENV{'TEST_ERROR'} = 1;
for my $url (@{$pages}) {
    TestUtils::test_page(
        'url'     => $url,
        'fail'    => 1,
        'unlike'  => [ 'HASH', 'ARRAY' ],
    );
}
delete $ENV{'TEST_ERROR'};
