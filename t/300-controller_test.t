use strict;
use warnings;
use Data::Dumper;
use Test::More;
use IO::Scalar;

BEGIN {
    plan skip_all => 'backends required' if(!-s 'thruk_local.conf' and !defined $ENV{'CATALYST_SERVER'});
    plan skip_all => 'local tests only'  if defined $ENV{'CATALYST_SERVER'};
    plan tests => 27;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Controller::test' }

TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/test.cgi',
    'like'    => 'Read what\'s new in Thruk',
);

# test leak detection

my $str;
my $err = tie *STDERR, 'IO::Scalar', \$str;

$ENV{'THRUK_SRC'} = 'TEST_LEAK';
TestUtils::test_page(
    'url'     => '/thruk/cgi-bin/test.cgi?action=leak',
    'like'    => 'Read what\'s new in Thruk',
);
undef $err;
untie *STDERR;

like($str, '/found leaks:/', 'got leak str');
like($str, '/\$ctx->{stash}->{ctx}/', 'got leaks location');

$ENV{'THRUK_SRC'} = 'TEST';