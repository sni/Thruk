use strict;
use warnings;
use Test::More;
use Data::Dumper;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $cmds = [
  "grep -nr 'TODO' lib/. templates/. plugins/plugins-available/. root/.",
];

# find all TODOs
for my $cmd (@{$cmds}) {
  open(my $ph, '-|', $cmd.' 2>&1') or die('cmd '.$cmd.' failed: '.$!);
  ok($ph, 'cmd started');
  while(<$ph>) {
    my $line = $_;
    chomp($line);

    # skip those
    if(   $line =~ m|/dojo/dojo\.js|mx
       or $line =~ m|readme\.txt|mx
       or $line =~ m|/excanvas.js|mx
       or $line =~ m|jquery\.mobile\-.*.js|mx
       or $line =~ m|extjs\-.*\.js|mx
       or $line =~ m|extjs\-.*\.css|mx
       or $line =~ m|/javascript/jstree/|mx
       or $line =~ m|/conf/root/jstree/|mx
       or $line =~ m|jquery\.flot\.|mx
       or $line =~ m|root/./tests/|mx
       or $line =~ m|/geoext2|mx
    ) {
      next;
    }

    # let them really fail
    fail($line);
  }
  close($ph);
}


done_testing();
