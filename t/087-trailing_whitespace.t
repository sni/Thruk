use strict;
use warnings;
use Test::More;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

open(my $ph, '-|', 'bash -c "find ./lib ./plugins/plugins-available/*/lib ./templates ./plugins/plugins-available/*/templates t/*.t t/*/*/*.t -type f" 2>&1') or die('find failed: '.$!);
while(<$ph>) {
    my $line = $_;
    chomp($line);
    check_trailing_whitespace($line);
}
done_testing();


sub check_trailing_whitespace {
    my($file) = @_;
    my $now = time();
    ok($file, $file);
    my $cmd = 'perl -ne \'chomp; print "line ",$.,": ",$_,"\n" if $_ =~ m/\s+$/mx\' '.$file;
    open(my $ph, '-|', $cmd.' 2>&1') or die('cmd '.$cmd.' failed: '.$!);
    ok($ph, 'cmd started');
    while(<$ph>) {
        my $line = $_;
        chomp($line);
        fail("trailing whitespace in ".$file." ".$line);
    }
    close($ph);
    return;
}
