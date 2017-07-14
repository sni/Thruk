use strict;
use warnings;
use Test::More;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok("Thruk::Utils::External");

my($res, $c) = ctx_request('/thruk/side.html');

# perl
my $job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd($c, "hostname"); print $out; return $rc;', background => 1 });
TestUtils::wait_for_job($job);
my($out,$err,$time,$dir,$stash,$rc,$profile) = Thruk::Utils::External::get_result($c, $job);
is($out, `hostname`, "output ok");
is($rc, 0, "exit code 0");

my $true = -x '/usr/bin/true' ? '/usr/bin/true' : '/bin/true';
$job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd($c, "'.$true.'"); print $out; return $rc;', background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile) = Thruk::Utils::External::get_result($c, $job);
is($out, "", "output empty");
is($rc, 0, "exit code 0");

$job = Thruk::Utils::External::perl($c, { expr => 'print "test"; return(3);', background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile) = Thruk::Utils::External::get_result($c, $job);
is($out, "test", "test output");
is($rc, 3, "exit code 3");

my $false = -x '/usr/bin/false' ? '/usr/bin/false' : '/bin/false';
$job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd($c, '.$false.'); print $out; return $rc;', background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile) = Thruk::Utils::External::get_result($c, $job);
is($out, "", "output empty");
ok($rc != 0, "exit code not 0");

# cmd
$job = Thruk::Utils::External::cmd($c, { cmd => $false, background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile) = Thruk::Utils::External::get_result($c, $job);
is($out, "", "output empty");
ok($rc != 0, "exit code not 0");

$job = Thruk::Utils::External::cmd($c, { cmd => $true, background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile) = Thruk::Utils::External::get_result($c, $job);
is($out, "", "output empty");
is($rc, 0, "exit code 0");

$job = Thruk::Utils::External::cmd($c, { cmd => 'hostname', background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile) = Thruk::Utils::External::get_result($c, $job);
is($out, `hostname`, "output ok");
is($rc, 0, "exit code 0");

done_testing();
