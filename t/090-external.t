use strict;
use warnings;
use Test::More;
use File::Temp qw/tempfile/;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok("Thruk::Utils::External");

my($res, $c) = ctx_request('/thruk/side.html');
my $cat      = -x '/usr/bin/cat'   ? '/usr/bin/cat'   : '/bin/cat';
my $false    = -x '/usr/bin/false' ? '/usr/bin/false' : '/bin/false';

# perl
my $job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd($c, "hostname"); print $out; return $rc;', background => 1 });
TestUtils::wait_for_job($job);
my($out,$err,$time,$dir,$stash,$rc,$profile,$start,$end,$perl_res) = Thruk::Utils::External::get_result($c, $job);
is($out, `hostname`, "output ok");
is($err, "", "err output empty");
is($rc, 1, "exit code 1");
is($perl_res, 0, "perl result is 0");

my $true = -x '/usr/bin/true' ? '/usr/bin/true' : '/bin/true';
$job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd($c, "'.$true.'"); print $out; return $rc;', background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile,$start,$end,$perl_res) = Thruk::Utils::External::get_result($c, $job);
is($out, "", "output empty");
is($err, "", "err output empty");
is($rc, 1, "exit code 1");
is($perl_res, 0, "perl result is 0");

$job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd($c, ["'.$true.'"]); print $out; return $rc;', background => 1 });
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

$job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd($c, "'.$false.'"); print $out; return $rc;', background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile,$start,$end,$perl_res) = Thruk::Utils::External::get_result($c, $job);
is($out, "", "output empty");
is($err, "", "err output empty");
is($rc, 0, "exit code 0");
is($perl_res, 1, "perl result is 1");

$job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd($c, ["'.$false.'"]); print $out; return $rc;', background => 1 });
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
ok(-e $tempfile, "tempfile created: ".$tempfile);
for(1..10000) {
    print $fh "x" x 999,"\n";
}
CORE::close($fh);
is(-s $tempfile, 10000000, "tempfile has 10000000 bytes");

$job = Thruk::Utils::External::cmd($c, { cmd => $cat.' '.$tempfile, background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile) = Thruk::Utils::External::get_result($c, $job);
is(length($out), 10000000, "output ok");
is($err, "", "err output empty");
is($rc, 0, "exit code 0");
Thruk::Utils::External::remove_job_dir($c->config->{'var_path'}."/jobs/".$job);

($rc, $out) = Thruk::Utils::IO::cmd($c, $cat.' '.$tempfile);
is(length($out), 10000000, "output ok");
is($rc, 0, "exit code 0");

($rc, $out) = Thruk::Utils::IO::cmd($c, [$cat, $tempfile]);
is(length($out), 10000000, "output ok");
is($rc, 0, "exit code 0");

$job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd($c, "'.$cat.' \"'.$tempfile.'\""); print $out; return $rc;', background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile,$start,$end,$perl_res) = Thruk::Utils::External::get_result($c, $job);
is(length($out), 10000000, "output ok");
is($err, "", "err output empty");
is($rc, 1, "exit code 1");
is($perl_res, 0, "perl result is 0");
Thruk::Utils::External::remove_job_dir($c->config->{'var_path'}."/jobs/".$job);

$job = Thruk::Utils::External::perl($c, { expr => 'my($rc, $out) = Thruk::Utils::IO::cmd($c, ["'.$cat.'", "'.$tempfile.'"]); print $out; return $rc;', background => 1 });
TestUtils::wait_for_job($job);
($out,$err,$time,$dir,$stash,$rc,$profile,$start,$end,$perl_res) = Thruk::Utils::External::get_result($c, $job);
is(length($out), 10000000, "output ok");
is($err, "", "err output empty");
is($rc, 1, "exit code 1");
is($perl_res, 0, "perl result is 0");
Thruk::Utils::External::remove_job_dir($c->config->{'var_path'}."/jobs/".$job);

unlink($tempfile);

done_testing();
