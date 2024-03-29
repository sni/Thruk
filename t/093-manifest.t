use warnings;
use strict;
use ExtUtils::Manifest;
use Test::More;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
my($e_m_v) = ($ExtUtils::Manifest::VERSION =~ m/^(\d+\.\d+)/mx);
plan skip_all => 'ExtUtils::Manifest > 1.51 required, this is '.$ExtUtils::Manifest::VERSION unless $e_m_v > 1.51;



# first do a make distcheck
SKIP: {
    # https://github.com/Perl-Toolchain-Gang/ExtUtils-Manifest/issues/5
    skip "distcheck is broken with ExtUtils::Manifest >= 1.66", 1 if $e_m_v >= 1.66;
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
};

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

# read our manifest.skip file
my $manifest_skip = {};
open($fh, '<', 'MANIFEST.SKIP') or die('open MANIFEST.SKIP failed: '.$!);
while(<$fh>) {
    my $line = $_;
    chomp($line);
    next if $line =~ m/^#/;
    $manifest_skip->{$line} = 1;
}
close($fh);
ok(scalar keys %{$manifest_skip} >  0, 'read entrys from MANIFEST.SKIP: '.(scalar keys %{$manifest_skip}));


# verify that all symlinks are in our manifest file
open(my $ph, '-|', 'bash -c "find {templates/,root/,plugins/,themes/} -type l" 2>&1') or die('find failed: '.$!);
while(<$ph>) {
    my $line = $_;
    chomp($line);
    $line =~ s|//|/|gmx;
    my $dst = readlink($line);
    if($dst =~ m|/root$|) {
        if(defined $manifest->{$line}) {
            fail("$line is in the MANIFEST but should not: $dst");
        } else {
            pass("$line is NOT in the MANIFEST");
        }
    } else {
        if(defined $manifest->{$line}) {
            if(_match_skip($line)) {
                fail("$line is in the MANIFEST but matches MANIFEST.SKIP too");
                next;
            }
            pass("$line is in the MANIFEST");
        } else {
            next if _match_skip($line);
            fail("$line is NOT in the MANIFEST");
        }
    }
}
close($ph);

done_testing();

sub _match_skip {
    my($line) = @_;
    for my $p (sort keys %{$manifest_skip}) {
        ## no critics
        if($line =~ m|$p|) {
            return(1);
        }
        ## use critics
    }
    return;
}