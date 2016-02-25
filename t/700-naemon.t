use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'naemon only test' if(!$ENV{'PLACK_TEST_EXTERNALSERVER_URI'} or $ENV{'PLACK_TEST_EXTERNALSERVER_URI'} !~ m/\/naemon$/);
    plan tests => 18;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

#####################################################################
my $pages = [
   { url => '/thruk/', like => [], redirect => 1, location => "/thruk/" },
   { url => '/thruk/cgi-bin/tac.cgi', like => [], redirect => 1, location => "/thruk/cgi-bin/tac.cgi" },
];

for my $url (@{$pages}) {
    my $test = TestUtils::make_test_hash($url, {});
    TestUtils::test_page(%{$test});
}
