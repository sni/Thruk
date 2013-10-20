use strict;
use warnings;
use Test::More;
use File::Temp qw/tempdir/;

BEGIN {
    plan skip_all => 'local tests only'  if defined $ENV{'CATALYST_SERVER'};
    plan skip_all => 'backends required' if !-s 'thruk_local.conf';
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan(tests => 10);

###########################################################
my $tmpdir = tempdir( CLEANUP => 1 );
mkdir($tmpdir);
ok(-d $tmpdir, $tmpdir.' created');
`cp -rp t/data/remove_duplicates/* $tmpdir/`;

check_example("examples/remove_duplicates -ay $tmpdir/core.cfg");

TestUtils::test_command({
    cmd  => '/usr/bin/diff -ru t/data/remove_duplicates/expect.cfg '.$tmpdir.'/test.cfg',
    like => ['/^$/'],
});
`rm -rf $tmpdir` if $tmpdir;
ok(!-d $tmpdir, $tmpdir.' removed');

exit;


###########################################################
# SUBS
###########################################################
sub check_example {
    my($file) = @_;
    ok($file, "testing : ".$file);
    TestUtils::test_command({
        cmd     => $file,
    });
    return;
}
