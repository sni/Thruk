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
  "grep -nr 'close\(' lib/ plugins/plugins-available/",
  "grep -nr 'mkdir\(' lib/ plugins/plugins-available/",
  "grep -nr 'chown\(' lib/ plugins/plugins-available/",
  "grep -nr 'chmod\(' lib/ plugins/plugins-available/",
];

# find all close / mkdirs not ensuring permissions
my @fails;
for my $cmd (@{$cmds}) {
  open(my $ph, '-|', $cmd.' 2>&1') or die('cmd '.$cmd.' failed: '.$!);
  ok($ph, 'cmd started');
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

    push @fails, $line;
  }
  close($ph);
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
# some tests for full disks
if(-e '/dev/full') {
    eval {
        Thruk::Utils::IO::json_lock_store('/dev/full', {'a' => 'b' }, undef, undef, '/dev/full');
    };
    my $err = $@;
    like($err, '/cannot write to/', "json_lock_store failed on full filesystem");
    like($err, '/No space left on device/', "json_lock_store failed on full filesystem, no space error message");
}

#########################
# background commands
my $start = time();
($rc, $output) = Thruk::Utils::IO::cmd($c, "sleep 1 >/dev/null 2>&1 &");
my $time = time()- $start;
ok($time < 5, "runtime < 5 (".$time."s)");
is($rc, 0, "exit code is: ".$rc);

#########################
done_testing();
