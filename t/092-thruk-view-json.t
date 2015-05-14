use strict;
use warnings;
use Test::More;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $cmds = [
  "grep -nr 'View::JSON' lib/ plugins/plugins-available/*/lib/ | grep -v Thruk::View::JSON",
];

# find all missed debug outputs
for my $cmd (@{$cmds}) {
  open(my $ph, '-|', $cmd.' 2>&1') or die('cmd '.$cmd.' failed: '.$!);
  ok($ph, 'cmd started');
  while(<$ph>) {
    my $line = $_;
    chomp($line);
    next if $line !~ m/(detach|forward)/mx;
    fail($line);
  }
  close($ph);
}


done_testing();
