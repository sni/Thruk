use strict;
use warnings;
use Test::More;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my @dirs = glob("./lib ./plugins/plugins-available/*/lib ./templates ./plugins/plugins-available/*/templates");
for my $dir (@dirs) {
    check_trailing_whitespace($dir.'/');
}
done_testing();


sub check_trailing_whitespace {
    my($dir) = @_;
    my $now = time();
    ok($dir, $dir);
    my $cmd = 'grep -Prni "\s+$" '.$dir;
    open(my $ph, '-|', $cmd.' 2>&1') or die('cmd '.$cmd.' failed: '.$!);
    ok($ph, 'cmd started');
    while(<$ph>) {
        my $line = $_;
        chomp($line);
        fail("trailing whitespace detected in:\n".$line);
    }
    close($ph);
    return;
}
