use strict;
use warnings;
use Test::More;
use File::Slurp qw/read_file/;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $cmds = [
  "grep -nr '`' lib/ plugins/plugins-available/*/lib/",
];

# find backticks and advise to use IO module instead
for my $cmd (@{$cmds}) {
  open(my $ph, '-|', $cmd.' 2>&1') or die('cmd '.$cmd.' failed: '.$!);
  ok($ph, 'cmd started');
  while(<$ph>) {
    my $line = $_;
    chomp($line);
    next if $line =~ m/Thruk\/Utils\/IO\.pm:/mx;
    next if $line =~ m/\.pm:\d+:\s*\#/mx;
    next if $line =~ m/(CREATE|ALTER|TRUNCATE|OPTIMIZE|DROP|LOCK)\ TABLE/mx;
    next if $line =~ m/LEFT\ JOIN/mx;
    next if $line =~ m/INSERT\ INTO/mx;
    next if $line =~ m/SELECT\ /mx;
    next if $line =~ m/UPDATE\ /mx;
    next if $line =~ m/DELETE\ FROM/mx;
    next if $line =~ m/CREATE\ INDEX/mx;
    next if $line =~ m/\$prefix\.('|")_/mx;
    next if $line =~ m/Thruk\/BP\/Utils\.pm:\d+:\s*\$str\ =/mx;
    next if $line =~ m/lib\/Monitoring\/Availability\.pm/mx;
    next if $line =~ m/lib\/Monitoring\/Config\.pm/mx;
    fail($line);
  }
  close($ph);
}

###############################################################################
# look for fork() and make sure either a wait() / waitpid() or $SIG{CHLD} = 'IGNORE' is in that file
$cmds = [
  "grep -rnc 'fork()' lib/ plugins/plugins-available/*/lib t/ script/ | grep -v :0",
];

# find backticks and advise to use IO module instead
for my $cmd (@{$cmds}) {
  open(my $ph, '-|', $cmd.' 2>&1') or die('cmd '.$cmd.' failed: '.$!);
  ok($ph, 'cmd started');
  while(<$ph>) {
    my $line = $_;
    $line =~ m/^(.*):/mx;
    my $file = $1;
    my $data = read_file($file);
    if($data !~ m/(wait\(|waitpid\()/mx && $data !~ m/SIG.*CHLD.*IGNORE/mx) {
      fail("file $file uses fork() but misses a wait/waipid or CHLD=ignore");
    }
  }
  close($ph);
}


done_testing();
