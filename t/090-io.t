use strict;
use warnings;
use Test::More;
use Data::Dumper;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

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

done_testing();
