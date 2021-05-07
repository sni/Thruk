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

plan(tests => 6);

use_ok("Thruk::Utils::IO");

###########################################################
`cp t/xt/panorama/data/v1.88.tab test.tab`;
TestUtils::test_command({
    cmd     => './support/convert_old_datafile.pl test.tab',
    like    => [qr(^\s*$)],
});

my $dashboard = Thruk::Utils::IO::json_lock_retrieve("test.tab");
is($dashboard->{'user'}, 'thrukadmin', "old dashboard converted");

unlink("test.tab");

exit;
