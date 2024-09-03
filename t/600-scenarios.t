use warnings;
use strict;
use Cwd qw/cwd/;
use Test::More;
use Time::HiRes qw/gettimeofday tv_interval/;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
    plan skip_all => 'skipped by THRUK_SKIP_DOCKER' if $ENV{'THRUK_SKIP_DOCKER'};
    plan skip_all => 'docker required' unless TestUtils::has_util('docker');
}

my $filter;
if($0 =~ m/scenario\-(.*)\.t$/mx) {
    $filter = 't/scenarios/'.$1;
}

use_ok("Thruk::Utils");
use_ok("Thruk::Utils::IO");
use_ok("Thruk::Utils::Log");
use_ok("Thruk::Config");

my $verbose   = $ENV{'HARNESS_IS_VERBOSE'} ? 1 : undef;
my $pwd       = cwd();
my $make      = $ENV{'MAKE'} || 'make';
my $scenarios = [map($_ =~ s/\/\.$//gmx && $_, split/\n/mx, `ls -1d t/scenarios/*/.`)];
my $config    = Thruk::Config::get_config();

for my $dir (@{$scenarios}) {
    next if $filter && $filter ne $dir;
    next if $dir =~ m/\/_/mx;
    chdir($dir);
    _run($dir, "clean");
    chdir($pwd);
}

for my $dir (@{$scenarios}) {
    if($filter) {
        # test specific scenario
        next if $filter ne $dir;
        if($dir =~ /e2e$/mx && !$ENV{'THRUK_TEST_E2E'}) {
            diag('E2E tests skiped, set THRUK_TEST_E2E env to run them');
            next;
        }
        chdir($dir);
        my $archive = [];
        for my $step (qw/prepare wait_start test_verbose clean/) {
            my($rc,$out) = _run($dir, $step, $archive);
            if($rc != 0) {
                BAIL_OUT("step $step failed") if $ENV{'THRUK_TEST_BAIL_OUT'};
                _run($dir, "clean", $archive);
                last;
            }
        }
        chdir($pwd);
    }
    else {
        # simply test if we have a specific test case for all required scenarios
        next if $dir =~ /backend_(icinga|nagios4|shinken)/mx;
        next if $dir =~ /citest/mx;
        my $dirname = $dir;
        $dirname =~ s%^.*/%%gmx;
        my $filename = 't/610-scenario-'.$dirname.'.t';
        if(-e $filename) {
            ok(1, "test case for $dirname exists");
        } elsif($dirname =~ m/^pentest_/mx) {
            ok(1, "no test case for pentests required");
        } elsif($dirname =~ m/^_/mx) {
            ok(1, "no test case for common folder required");
        } else {
            fail("missing test case file: ".$filename);
        }
    }
}

# make simple normal final request since the tests kill existing lmd childs and upcoming
# tests will fail if there is a startup message on stderr
if($config->{'use_lmd'}) {
    local $ENV{'TEST_ERROR'} = "";
    TestUtils::test_page(
        url     => '/thruk/cgi-bin/extinfo.cgi?type=0',
        waitfor => 'Process\s+Commands',
        like    => [ 'Process Information', 'Program Start Time' ],
    );
}

done_testing();

sub _run {
    my($dir, $step, $archive) = @_;

    my $t0 = [gettimeofday];
    ok(1, "$dir: running make $step");
    my($rc, $out) = Thruk::Utils::IO::cmd([$make, $step], {
        print_prefix  => ($verbose ? '## ' : undef),
        output_prefix => Thruk::Utils::Log::time_prefix(),
    });
    is($rc, 0, sprintf("step %s complete, rc=%d duration=%.1fsec", $step, $rc, tv_interval ($t0)));
    if($out =~ m/^(FROM.*version:.*)$/mx) {
        diag($1);
    }
    push @{$archive}, [$step, $rc, $out];
    # already printed in verbose mode
    if(!$verbose && $rc != 0) {
        for my $a (@{$archive}) {
            my $chr = $a->[1] == 0 ? '*' : '!';
            diag("");
            diag("");
            diag(($chr x 3).sprintf(" make %-12s ", $a->[0]).($chr x 58));
            diag("step: ".$a->[0]);
            diag("rc:   ".$a->[1]);
            diag($a->[2]);
            diag($chr x 78);
            diag("");
        }
    };
    return($rc, $out);
}
