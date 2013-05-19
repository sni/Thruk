use strict;
use warnings;
use Test::More;
use Data::Dumper;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $cmds = [
  "grep -rc 'use Moose' lib/. plugins/plugins-available/*/lib/. | grep -v :0",
  "grep -Erc 'use base.*Catalyst::' lib/. plugins/plugins-available/*/lib/. | grep -v :0 | grep -v 'Thruk/View' | grep -v 'Catalyst/View' | grep -v 'Catalyst/Plugin'",
  "grep -Erc 'use parent.*Catalyst::' lib/. plugins/plugins-available/*/lib/. | grep -v :0",
];

# find all TODOs
for my $cmd (@{$cmds}) {
  open(my $ph, '-|', $cmd.' 2>&1') or die('cmd '.$cmd.' failed: '.$!);
  while(<$ph>) {
    my $line = $_;
    chomp($line);
    $line =~ s/:\d+$//gmx;
    $line =~ s|/./|/|gmx;
    `grep make_immutable $line`;
    if($? != 0) {
        next if $line eq 'lib/Thruk.pm';
        next if $line eq 'lib/Monitoring/Livestatus/Class/Base/Table.pm';
        fail($line);
    }
  }
  close($ph);
  ok($? == 0, 'cmd '.$cmd.' exited with: '.$?);
}


done_testing();
