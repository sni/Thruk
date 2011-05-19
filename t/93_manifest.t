use strict;
use warnings;
use Test::More;
use Data::Dumper;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

# first do a make distcheck
open(my $ph, '-|', 'make distcheck 2>&1') or die('make failed: '.$!);
while(<$ph>) {
    my $line = $_;
    chomp($line);

    if(   $line =~ m/\/bin\/perl/ 
       or $line =~ m/: Entering directory/
       or $line =~ m/: Leaving directory/
    ) {
      pass($line);
      next;
    }

    if($line =~ m/No such file: (.*)$/) {
        if( -l $1) {
          pass("$1 is a symlink");
        } else {
          fail("$1 does not exist!");
        }
        next;
    }

    fail($line);
}
close($ph);
ok($? == 0, 'make exited with: '.$?);

# read our manifest file
my $manifest = {};
open(my $fh, '<', 'MANIFEST') or die('open MANIFEST failed: '.$!);
while(<$fh>) {
    my $line = $_;
    chomp($line);
    next if $line =~ m/^#/;
    $manifest->{$line} = 1;
}
close($fh);
ok(scalar keys %{$manifest} >  0, 'read entrys from MANIFEST: '.(scalar keys %{$manifest}));

# verify that all symlinks are in our manifest file
open($ph, '-|', 'bash -c "find {templates/,root/,plugins/} -type l" 2>&1') or die('find failed: '.$!);
while(<$ph>) {
    my $line = $_;
    chomp($line);
    my $dst = readlink($line);
    if($dst =~ m/^\//) {
        if(defined $manifest->{$line}) {
            fail("$line is in the MANIFEST but should not: $dst");
        } else {
            pass("$line is NOT in the MANIFEST");
        }
    } else {
        if(defined $manifest->{$line}) {
            pass("$line is in the MANIFEST");
        } else {
            fail("$line is NOT in the MANIFEST");
        }
    }
}
close($ph);


done_testing();
