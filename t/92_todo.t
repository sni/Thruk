use strict;
use warnings;
use Test::More;
use Data::Dumper;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

# find all TODOs
open(my $ph, '-|', ' grep -r "TODO" lib/. templates/. plugins/plugins-available/. root/. 2>&1') or die('grep failed: '.$!);
while(<$ph>) {
    my $line = $_;
    chomp($line);

    if(   $line =~ m|/dojo/dojo\.js|mx
       or $line =~ m|readme\.txt|mx
       or $line =~ m|Unicode/Encoding\.pm|mx
    ) {
      next;
    }

    fail($line);
}
close($ph);
ok($? == 0, 'grep exited with: '.$?);

done_testing();
