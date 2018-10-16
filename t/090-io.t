use strict;
use warnings;
use Test::More;
use File::Temp qw/tempfile/;
use File::Slurp qw/read_file/;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

my $c = TestUtils::get_c();

use_ok("Thruk::Utils::IO");

my $cmds = [
  "grep -nr 'close\(' lib/ plugins/plugins-available/",           "better use Thruk::Utils::IO::close",
  "grep -nr 'mkdir\(' lib/ plugins/plugins-available/",           "better use Thruk::Utils::IO::mkdir",
  "grep -nr 'chown\(' lib/ plugins/plugins-available/",           "better use Thruk::Utils::IO::ensure_permissions",
  "grep -nr 'chmod\(' lib/ plugins/plugins-available/",           "better use Thruk::Utils::IO::ensure_permissions",
  "grep -Pnr 'sleep\\(\\d+\\.' lib/ plugins/plugins-available/",  "better use Time::HiRes::sleep directly",
];

# find all close / mkdirs not ensuring permissions
my @fails;
while(scalar @{$cmds} > 0) {
  my $cmd  = shift @{$cmds};
  my $desc = shift @{$cmds};
  open(my $ph, '-|', $cmd.' 2>&1') or die('cmd '.$cmd.' failed: '.$!);
  ok($ph, 'cmd '.$cmd.' started');
  while(<$ph>) {
    my $line = $_;
    chomp($line);
    $line =~ s|//|/|gmx;

    next unless $line =~ m/\.pm:\d+/mx;
    next if $line =~ m|STDERR|mx;
    next if $line =~ m|STDOUT|mx;
    next if $line =~ m|POSIX::close|mx;
    next if $line =~ m|Thruk/Utils/IO\.pm:|mx;
    next if $line =~ m|Thruk::Utils::IO::close|mx;
    next if $line =~ m|Thruk::Utils::IO::mkdir|mx;
    next if $line =~ m|CORE::|mx;
    next if $line =~ m|lib/Monitoring/Availability|mx;
    next if $line =~ m|lib/Monitoring/Livestatus|mx;
    next if $line =~ m|\Qmake sure the core can read it\E|mx;
    next if $line =~ m|secretfile|mx;
    next if $line =~ m|_close|mx;
    next if $line =~ m|Time::HiRes|mx;

    push @fails, $desc." in\n".$line;
  }
  close($ph);
  ok($? == 0, "exit code is: ".$?." (cmd: ".$cmd.")");
}

for my $fail (sort @fails) {
    fail($fail);
}

my($rc, $output) = Thruk::Utils::IO::cmd(undef, 'ls -la');
is($rc, 0, "ls returned with rc: 0");
like($output, '/thruk.conf/', "ls returned something");

($rc, $output) = Thruk::Utils::IO::cmd(undef, ['ls', '-l', '-a']);
is($rc, 0, "ls returned with rc: 0");
like($output, '/thruk.conf/', "ls array args returned something");

my $false = -x '/usr/bin/false' ? '/usr/bin/false' : '/bin/false';
($rc, $output) = Thruk::Utils::IO::cmd(undef, [$false]);
ok($rc != 0, $false." returned with anything but 0");
like($output, '/^$/', "false returned nothing");

($rc, $output) = Thruk::Utils::IO::cmd(undef, $false);
ok($rc != 0, $false." returned with anything but 0");
like($output, '/^$/', "false returned nothing");

my($tfh, $tmpfilename) = tempfile();
$rc = Thruk::Utils::IO::json_lock_store($tmpfilename, {'a' => 'b' });
is($rc, 1, "json_lock_store succeeded on tmpfile");
my $content = read_file($tmpfilename);
like($content, '/{"a":"b"}/', 'file contains json');
unlink($tmpfilename);

#########################
# lock store with orphaned lock
($tfh, $tmpfilename) = tempfile();
Thruk::Utils::IO::write($tmpfilename.'.lock', '');
$rc = Thruk::Utils::IO::json_lock_store($tmpfilename, {'a' => 'b' });
is($rc, 1, "json_lock_store succeeded on tmpfile with orphaned lock file");
unlink($tmpfilename);

#########################
# some tests for full disks
if(-e '/dev/full') {
    eval {
        Thruk::Utils::IO::json_store('/dev/full', {'a' => 'b' }, undef, undef, '/dev/full');
    };
    my $err = $@;
    like($err, '/cannot write to/', "json_store failed on full filesystem");
    like($err, '/No space left on device/', "json_store failed on full filesystem, no space error message");
}

#########################
# background commands
my $start = time();
($rc, $output) = Thruk::Utils::IO::cmd($c, "sleep 1 >/dev/null 2>&1 &");
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
done_testing();
