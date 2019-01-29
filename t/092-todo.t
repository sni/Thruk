use strict;
use warnings;
use Test::More;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $cmds = [
  "grep -nr 'TODO' lib/. templates/. plugins/plugins-available/. root/. t/",
];

# find all TODOs
for my $cmd (@{$cmds}) {
  open(my $ph, '-|', $cmd.' 2>&1') or die('cmd '.$cmd.' failed: '.$!);
  ok($ph, 'cmd started');
  while(<$ph>) {
    my $line = $_;
    chomp($line);

    # skip those
    if(   $line =~ m|/vendor/|mx
       or $line =~ m|/cache/|mx
       or $line =~ m|/panorama_js_box_reorder.js|mx
       or $line =~ m|/092\-todo\.t|mx
    ) {
      next;
    }

    # let them really fail
    fail($line);
  }
  close($ph);
}


done_testing();
