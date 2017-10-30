use strict;
use warnings;
use Test::More;
use Cwd qw/cwd/;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
    plan skip_all => 'docker required' unless TestUtils::has_util('docker');
    plan skip_all => 'docker-compose required' unless TestUtils::has_util('docker-compose');
}

my $pwd  = cwd();
my $make = $ENV{'MAKE'} || 'make';
for my $dir (split/\n/mx, `ls -1d t/scenarios/*/.`) {
    $dir =~ s/\/\.$//gmx;
    if($dir =~ /e2e/mx && !$ENV{'THRUK_TEST_E2E'}) {
        diag('E2E tests skiped, set THRUK_TEST_E2E env to run them');
        next;
    }
    chdir($dir);
    for my $step (qw/clean update prepare test clean/) {
        ok(1, "$dir: running make $step");
        my $out = `$make $step 2>&1`;
        my $rc = $?;
        is($rc, 0, "rc was $rc") or diag($out);
    }
    chdir($pwd);
}

done_testing();
