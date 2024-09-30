use warnings;
use strict;
use File::Temp qw/tempfile/;
use Test::More;
use utf8;

use Thruk::Utils::IO ();

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok("Thruk::Utils::External");

my($res, $c) = ctx_request('/thruk/main.html');
my $cat      = -x '/usr/bin/cat'   ? '/usr/bin/cat'   : '/bin/cat';
my $false    = -x '/usr/bin/false' ? '/usr/bin/false' : '/bin/false';

# perl
my $job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd("hostname"); print $out; return $rc;', background => 1 });
TestUtils::wait_for_job($job);
my($out,$err,$time,$dir,$stash,$rc,$profile,$start,$end,$perl_res) = Thruk::Utils::External::get_result($c, $job);
is($out, `hostname`, "output ok");
is($err, "", "err output empty");
is($rc, 1, "exit code 1");
is($perl_res, 0, "perl result is 0");

my $true = -x '/usr/bin/true' ? '/usr/bin/true' : '/bin/true';
$job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd("'.$true.'"); print $out; return $rc;', background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile,$start,$end,$perl_res) = Thruk::Utils::External::get_result($c, $job);
is($out, "", "output empty");
is($err, "", "err output empty");
is($rc, 1, "exit code 1");
is($perl_res, 0, "perl result is 0");

$job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd(["'.$true.'"]); print $out; return $rc;', background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile,$start,$end,$perl_res) = Thruk::Utils::External::get_result($c, $job);
is($out, "", "output empty");
is($err, "", "err output empty");
is($rc, 1, "exit code 1");
is($perl_res, 0, "perl result is 0");

$job = Thruk::Utils::External::perl($c, { expr => 'print "test"; return(3);', background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile,$start,$end,$perl_res) = Thruk::Utils::External::get_result($c, $job);
is($out, "test", "test output");
is($err, "", "err output empty");
is($rc, 0, "exit code 0");
is($perl_res, 3, "perl result is 3");

$job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd("'.$false.'"); print $out; return $rc;', background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile,$start,$end,$perl_res) = Thruk::Utils::External::get_result($c, $job);
is($out, "", "output empty");
is($err, "", "err output empty");
is($rc, 0, "exit code 0");
is($perl_res, 1, "perl result is 1");

$job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd(["'.$false.'"]); print $out; return $rc;', background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile,$start,$end,$perl_res) = Thruk::Utils::External::get_result($c, $job);
is($out, "", "output empty");
is($err, "", "err output empty");
is($rc, 0, "exit code 0");
is($perl_res, 1, "perl result is 1");

# cmd
$job = Thruk::Utils::External::cmd($c, { cmd => $false, background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile) = Thruk::Utils::External::get_result($c, $job);
is($out, "", "output empty");
is($err, "", "err output empty");
ok($rc != 0, "exit code not 0");

$job = Thruk::Utils::External::cmd($c, { cmd => $true, background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile) = Thruk::Utils::External::get_result($c, $job);
is($out, "", "output empty");
is($err, "", "err output empty");
is($rc, 0, "exit code 0");

$job = Thruk::Utils::External::cmd($c, { cmd => 'hostname', background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile) = Thruk::Utils::External::get_result($c, $job);
is($out, `hostname`, "output ok");
is($err, "", "err output empty");
is($rc, 0, "exit code 0");

my($fh, $tempfile) = tempfile();
$fh->binmode(":encoding(utf-8)");
ok(-e $tempfile, "tempfile created: ".$tempfile);
for(1..10000) {
    print $fh "x" x 999,"\n";
}
print $fh "€öäüß\n";
CORE::close($fh);
is(-s $tempfile, 10000012, "tempfile has 10000012 bytes");

$job = Thruk::Utils::External::cmd($c, { cmd => $cat.' '.$tempfile, background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile) = Thruk::Utils::External::get_result($c, $job);
is(length($out), 10000012, "output ok");
is($err, "", "err output empty");
is($rc, 0, "exit code 0");
Thruk::Utils::External::remove_job_dir($c->config->{'var_path'}."/jobs/".$job);

my($rc2, $out2) = Thruk::Utils::IO::cmd($cat.' '.$tempfile, { no_decode => 1 });
is(length($out2), 10000012, "output ok");
is($rc2, 0, "exit code 0");

($rc, $out) = Thruk::Utils::IO::cmd([$cat, $tempfile], { no_decode => 1 });
is(length($out), 10000012, "output ok");
is($rc, 0, "exit code 0");

$job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd("'.$cat.' \"'.$tempfile.'\""); print $out; return $rc;', background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile,$start,$end,$perl_res) = Thruk::Utils::External::get_result($c, $job);
is(length($out), 10000012, "output ok");
is($err, "", "err output empty");
is($rc, 1, "exit code 1");
is($perl_res, 0, "perl result is 0");
Thruk::Utils::External::remove_job_dir($c->config->{'var_path'}."/jobs/".$job);

$job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd(["'.$cat.'", "'.$tempfile.'"]); print $out; return $rc;', background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile,$start,$end,$perl_res) = Thruk::Utils::External::get_result($c, $job);
is(length($out), 10000012, "output ok");
is($err, "", "err output empty");
is($rc, 1, "exit code 1");
is($perl_res, 0, "perl result is 0");
Thruk::Utils::External::remove_job_dir($c->config->{'var_path'}."/jobs/".$job);

my $logarchive = '/tmp/test.'.$<.'.log';
unlink($logarchive);
$job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd(["'.$cat.'", "'.$tempfile.'"], {no_decode => 1}); print $out; return $rc;', background => 1, log_archive => $logarchive });
TestUtils::wait_for_job($job);
my $jobdir = $c->config->{'var_path'}."/jobs/".$job;
($out,$err,$time,$dir,$stash,$rc,$profile,$start,$end,$perl_res) = Thruk::Utils::External::get_result($c, $job);
is(length($out), 10260038, "output ok") || TestUtils::bail_out_diag("job failed", `ls -la $jobdir`, `ls -la $logarchive`);
is($err, "", "err output empty");
is($rc, 1, "exit code 1");
is($perl_res, 0, "perl result is 0");
Thruk::Utils::External::remove_job_dir($c->config->{'var_path'}."/jobs/".$job);
my @stat = stat($logarchive);
is($stat[7], 10260038, "log size ok");
unlink($logarchive);

unlink($tempfile);

done_testing();
