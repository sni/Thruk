use warnings;
use strict;
use File::Temp qw/tempfile/;
use Test::More;

use Thruk::Utils::IO ();

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $filter = $ARGV[0];

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $c = TestUtils::get_c();

use_ok("Thruk::Utils::IO");

my $srcfolders = "lib/ plugins/plugins-available/*/lib";
my $cmds = [
  "grep -nr  'close\(' $srcfolders",            "better use Thruk::Utils::IO::close",
  "grep -nr  'mkdir\(' $srcfolders",            "better use Thruk::Utils::IO::mkdir",
  "grep -nr  'chown\(' $srcfolders",            "better use Thruk::Utils::IO::ensure_permissions",
  "grep -nr  'chmod\(' $srcfolders",            "better use Thruk::Utils::IO::ensure_permissions",
  "grep -Enr 'sleep\\([0-9]+\\.' $srcfolders",  "better use Time::HiRes::sleep directly",
  "grep -nr  'File::Slurp' t/ $srcfolders",     "better use Thruk::Utils::IO::read",
];
my $iocmd = "grep -Enr -- '(\\-s|\\-f|\\-d|unlink\\(|stat\\(|opendir\\(|open\\(|move\\(|glob\\() ' $srcfolders";

# find all close / mkdirs not ensuring permissions
my @fails;
while(scalar @{$cmds} > 0) {
  my $cmd  = shift @{$cmds};
  my $desc = shift @{$cmds};
  ok(1, $cmd);
  my($rc, $out) = Thruk::Utils::IO::cmd($cmd);
  ok($rc == 0, "rc: $rc");
  for my $line (split m/\n/mx, $out) {
    chomp($line);
    $line =~ s|//|/|gmx;

    next if($filter && $line !~ m%$filter%mx);
    next unless $line =~ m/\.pm:\d+/mx;
    next if $line =~ m|STDERR|mx;
    next if $line =~ m|STDOUT|mx;
    next if $line =~ m|POSIX::close|mx;
    next if $line =~ m|Thruk/Utils/IO\.pm:|mx;
    next if $line =~ m|Thruk/Utils/IO/LocalFS\.pm:|mx;
    next if $line =~ m|Thruk::Utils::IO::close|mx;
    next if $line =~ m|Thruk::Utils::IO::mkdir|mx;
    next if $line =~ m|CORE::|mx;
    next if $line =~ m|lib/Monitoring/Availability|mx;
    next if $line =~ m|lib/Monitoring/Livestatus|mx;
    next if $line =~ m|\Qmake sure the core can read it\E|mx;
    next if $line =~ m|secretfile|mx;
    next if $line =~ m|_close|mx;
    next if $line =~ m|\->close|mx;
    next if $line =~ m|Time::HiRes|mx;

    fail($desc." in\n".$line);
  }
}

{
    ok(1, $iocmd);
    my($rc, $out) = Thruk::Utils::IO::cmd($iocmd);
    ok($rc == 0, "rc: $rc");
    for my $line (split m/\n/mx, $out) {
        chomp($line);
        $line =~ s|//|/|gmx;
        next if $line =~ m|:\s*\#|mx;
        next if $line =~ m|/tmp/|mx;
        next if $line =~ m|tmp_path|mx;
        next if $line =~ m|/local/|mx;
        next if $line =~ m|pidfile|mx;
        next if $line =~ m|logcache|mx;
        next if $line =~ m|thruk_local.conf|mx;
        next if $line =~ m|thruk.conf|mx;
        next if $line =~ m|thruk_local.d|mx;
        next if $line =~ m|\$addon|mx;
        next if $line =~ m|/version|mx;
        next if $line =~ m|usercontent|mx;
        next if $line =~ m|/root/|mx;
        next if $line =~ m|project_root|mx;
        next if $line =~ m|script/|mx;
        next if $line =~ m|scriptfolder|mx;
        next if $line =~ m|plugin_enabled_dir|mx;
        next if $line =~ m|/plugins-available/|mx;
        next if $line =~ m|spool folder|mx;
        next if $line =~ m|route_file|mx;
        next if $line =~ m|_info|mx;
        next if $line =~ m|\Qlib/Monitoring/Config\E|mx;
        next if $line =~ m|\Qlib/Thruk/Utils/LMD\E|mx;
        next if $line =~ m|\Qlib/Thruk/Utils/IO/LocalFS.pm\E|mx;

        fail("direct file access in\n".$line);
    }
}

my($rc, $output) = Thruk::Utils::IO::cmd('ls -la');
is($rc, 0, "ls returned with rc: 0");
like($output, '/thruk.conf/', "ls returned something");

($rc, $output) = Thruk::Utils::IO::cmd(['ls', '-l', '-a']);
is($rc, 0, "ls returned with rc: 0");
like($output, '/thruk.conf/', "ls array args returned something");

my $false = -x '/usr/bin/false' ? '/usr/bin/false' : '/bin/false';
($rc, $output) = Thruk::Utils::IO::cmd([$false]);
ok($rc != 0, $false." returned with anything but 0");
like($output, '/^$/', "false returned nothing");

($rc, $output) = Thruk::Utils::IO::cmd($false);
ok($rc != 0, $false." returned with anything but 0");
like($output, '/^$/', "false returned nothing");

my($tfh, $tmpfilename) = tempfile();
$rc = Thruk::Utils::IO::json_lock_store($tmpfilename, {'a' => 'b' });
is($rc, 1, "json_lock_store succeeded on tmpfile");
my $content = Thruk::Utils::IO::read($tmpfilename);
like($content, '/{"a":"b"}/', 'file contains json');
unlink($tmpfilename);

#########################
# lock store with orphaned lock
{
    local $ENV{'TEST_IO_NOWARNINGS'}  = 1;
    ($tfh, $tmpfilename) = tempfile();
    Thruk::Utils::IO::write($tmpfilename.'.lock', '');
    $rc = Thruk::Utils::IO::json_lock_store($tmpfilename, {'a' => 'b' });
    is($rc, 1, "json_lock_store succeeded on tmpfile with orphaned lock file");
    unlink($tmpfilename);
};

#########################
# some tests for full disks
if(-e '/dev/full') {
    eval {
        Thruk::Utils::IO::json_store('/dev/full', {'a' => 'b' }, { tmpfile => '/dev/full' });
    };
    my $err = $@;
    like($err, '/cannot write to/', "json_store failed on full filesystem");
    like($err, '/No space left on device/', "json_store failed on full filesystem, no space error message");
}

#########################
# background commands
my $start = time();
($rc, $output) = Thruk::Utils::IO::cmd("sleep 1 >/dev/null 2>&1 &");
my $time = time()- $start;
ok($time < 5, "runtime < 5 (".$time."s)");
is($rc, 0, "exit code is: ".$rc);

#########################
# merge hashes
{
    my $a = {
        'k1' => { 'sk1' => 'v1' },
        'k2' => { 'sk3' => 'v3', 'sk4' => 'v4' },
        'k4' => [1,2,3],
        'k5' => 'xyz'
    };
    my $b = {
        'k1' => { 'sk2' => 'v2'},
        'k3' => { 'sk5' => 'v5'},
        'k4' => [5,6,7],
        'k5' => undef,
        'k6' => { 'a' => undef },
    };
    my $expect = {
        'k1' => { 'sk1' => 'v1', 'sk2' => 'v2' },
        'k2' => { 'sk3' => 'v3', 'sk4' => 'v4' },
        'k3' => { 'sk5' => 'v5' },
        'k4' => [5,6,7],
        'k6' => {},
    };
    my $c = Thruk::Utils::IO::merge_deep($a, $b);
    is_deeply($c, $expect, "merge hashes worked");
};

#########################
# merge hashes with arrays
{
    my $a = {
        'k1' => [[1,2,3], {4 => 5, 6 => 7}, "c", "d"],
        'k2' => "a",
        'k3' => [1,2,3],
    };
    my $b = {
        'k1' => [{ 1 => "a" }, { 1 => "b" }],
        'k2' => "b",
        'k3' => { 1 => undef },
    };
    my $expect = {
        'k1' => [[1,"a", 3], {1 => "b", 4 => 5, 6 => 7}, "c", "d"],
        'k2' => "b",
        'k3' => [1,3],
    };
    my $c = Thruk::Utils::IO::merge_deep($a, $b);
    is_deeply($c, $expect, "merge hashes with arrays worked");
};

#########################
# backwards compatible IO::cmd
my $hostname = `hostname`;
my(undef, $hostname2) = Thruk::Utils::IO::cmd($c, "hostname");
is($hostname2, $hostname, "leading Context");

(undef, $hostname2) = Thruk::Utils::IO::cmd($c, ["hostname"]);
is($hostname2, $hostname, "leading Context and array");

(undef, $hostname2) = Thruk::Utils::IO::cmd(["hostname"], undef, undef, undef, undef, 10);
is($hostname2, $hostname, "timeout");

(undef, $hostname2) = Thruk::Utils::IO::cmd($c, ["hostname"], undef, undef, undef, undef, 10);
is($hostname2, $hostname, "context and timeout");

(undef, $hostname2) = Thruk::Utils::IO::cmd($c, ["hostname"], undef, undef, undef, undef, 10, 1);
is($hostname2, $hostname, "context and timeout, signals");

(undef, $hostname2) = Thruk::Utils::IO::cmd(["hostname"], undef, undef, undef, undef, 10, 1);
is($hostname2, $hostname, "timeout, signals");

#########################
done_testing();
