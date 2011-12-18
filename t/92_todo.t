use strict;
use warnings;
use Test::More;
use Data::Dumper;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $cmds = [
  "grep -nr 'TODO' lib/. templates/. plugins/plugins-available/. root/.",
  "grep -nr Dumper lib/ plugins/plugins-available/ | grep STDERR",
];

# find all TODOs
for my $cmd (@{$cmds}) {
  open(my $ph, '-|', $cmd.' 2>&1') or die('cmd '.$cmd.' failed: '.$!);
  while(<$ph>) {
    my $line = $_;
    chomp($line);

    if(   $line =~ m|/dojo/dojo\.js|mx
       or $line =~ m|readme\.txt|mx
       or $line =~ m|Unicode/Encoding\.pm|mx
       or $line =~ m|/excanvas.js|mx
       or $line =~ m|jquery\.mobile\-.*.js|mx
       or $line =~ m|:\d+:\#|mx
    ) {
      next;
    }

    fail($line);
  }
  close($ph);
  ok($? == 0, 'cmd '.$cmd.' exited with: '.$?);
}


done_testing();
