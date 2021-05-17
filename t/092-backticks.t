use warnings;
use strict;
use Test::More;

use Thruk::Utils::IO ();

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $cmds = [
  "grep -nr '`' lib/ plugins/plugins-available/*/lib/",
];

# find backticks and advise to use IO module instead
for my $cmd (@{$cmds}) {
  open(my $ph, '-|', $cmd.' 2>&1') or die('cmd '.$cmd.' failed: '.$!);
  ok($ph, 'cmd started');
  my $pod = 0;
  while(my $line = <$ph>) {
    chomp($line);
    $line =~ s/'.*?'//gmx;
    $line =~ s/\#.*$//gmx;
    next if $line =~ m%\QThruk/Utils/IO.pm:\E%mx;
    next if $line =~ m/(CREATE|ALTER|TRUNCATE|OPTIMIZE|DROP|LOCK)\ TABLE/mx;
    next if $line =~ m/LEFT\ JOIN/mx;
    next if $line =~ m/INSERT\ INTO/mx;
    next if $line =~ m/CREATE\ INDEX/mx;
    next if $line =~ m/LOAD\ DATA/mx;
    next if $line =~ m/\$(prefix|key)\.('|")_/mx;
    next if $line =~ m%\Qlib/Monitoring/Availability.pm:\E%mx;
    next if $line =~ m%\Qconf/lib/Monitoring/Config.pm:\E%mx;
    next if $line =~ m%\Q`_log`\E%mx;
    next if $line =~ m%\Q`log`\E%mx;
    next if $line =~ m/Defaults\ to/mx;
    next if $line =~ m/Thruk\/Config.pm/mx;
    next unless $line =~ m/`/gmx;
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
    my $data = Thruk::Utils::IO::read($file);
    if($data !~ m/(wait\(|waitpid\()/mx && $data !~ m/SIG.*CHLD.*IGNORE/mx) {
      fail("file $file uses fork() but misses a wait/waipid or CHLD=ignore");
    }
  }
  close($ph);
}


done_testing();
