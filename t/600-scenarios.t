use strict;
use warnings;
use Test::More;
use Cwd qw/cwd/;
use Time::HiRes qw/gettimeofday tv_interval/;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
    plan skip_all => 'docker required' unless TestUtils::has_util('docker');
    plan skip_all => 'docker-compose required' unless TestUtils::has_util('docker-compose');
}

use_ok("Thruk::Utils::IO");

my $verbose = $ENV{'HARNESS_IS_VERBOSE'} ? 1 : undef;
my $pwd  = cwd();
my $make = $ENV{'MAKE'} || 'make';
my $scenarios = [map($_ =~ s/\/\.$//gmx && $_, split/\n/mx, `ls -1d t/scenarios/*/.`)];

for my $dir (@{$scenarios}) {
    chdir($dir);
    _run($dir, "clean");
    chdir($pwd);
}

for my $dir (@{$scenarios}) {
    next if $dir =~ /nagios4/mx;
    if($dir =~ /e2e$/mx && !$ENV{'THRUK_TEST_E2E'}) {
        diag('E2E tests skiped, set THRUK_TEST_E2E env to run them');
        next;
    }
    chdir($dir);
    for my $step (qw/update prepare wait_start test_verbose clean/) {
        _run($dir, $step);
    }
    chdir($pwd);
}

done_testing();

sub _run {
    my($dir, $step) = @_;

    my $t0 = [gettimeofday];
    ok(1, "$dir: running make $step");
    my($rc, $out) = Thruk::Utils::IO::cmd(undef, [$make, $step], undef, ($verbose ? '## ' : undef));
    is($rc, 0, sprintf("step %s complete, rc=%d duration=%.1fsec", $step, $rc, tv_interval ($t0)));
    # already printed in verbose mode
    if(!$verbose && $rc != 0) {
        diag("*** make output ***************-");
        diag($out);
        diag("********************************");
    };
    if($step eq "prepare" && $rc != 0) {
        diag(`docker ps`);
        BAIL_OUT("$step failed");
    }
}
