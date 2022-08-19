use warnings;
use strict;
use Test::More;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $cmds = [
  "grep -nr '\$c->'\"{'stash'}\"  lib/ plugins/plugins-available/*/lib/ menu.conf | grep -v 'backwards compatibility'",
  "grep -nr '\$c->'\"{stash}\"    lib/ plugins/plugins-available/*/lib/ menu.conf",
  "grep -nr '\$c->{\"stash\"}'    lib/ plugins/plugins-available/*/lib/ menu.conf",
  "grep -nr '\$c->'\"{'config'}\" lib/ plugins/plugins-available/*/lib/ | grep -v Context.pm",
  "grep -nr '\$c->'\"{config}\"   lib/ plugins/plugins-available/*/lib/",
  "grep -nr '\$c->{\"config\"}'   lib/ plugins/plugins-available/*/lib/",
];

my $filter = $ARGV[0];

# find all missed debug outputs
for my $cmd (@{$cmds}) {
  open(my $ph, '-|', $cmd.' 2>&1') or die('cmd '.$cmd.' failed: '.$!);
  ok($ph, 'cmd started');
  while(<$ph>) {
    my $line = $_;
    chomp($line);
    next if($filter && $line !~ m%$filter%mx);
    fail($line);
  }
  close($ph);
}


done_testing();
