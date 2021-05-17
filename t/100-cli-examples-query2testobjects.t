use warnings;
use strict;
use File::Temp qw/tempdir/;
use Test::More;

BEGIN {
    plan skip_all => 'local tests only'  if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan skip_all => 'backends required' if !-s 'thruk_local.conf';
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan(tests => 5);

###########################################################
TestUtils::test_command({
    cmd     => './examples/query2testobjects "state != -1"',
    like    => [qr(\Qdefine host {\E), qr(\Qdefine command {\E)],
});

exit;
