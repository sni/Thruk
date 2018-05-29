use strict;
use warnings;
use Test::More;
use POSIX qw/mktime/;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my @dirs = glob("./lib/ ./templates/ ./root/ ./script ./plugins/plugins-available/ t/");
for my $dir (@dirs) {
    check_remove_afters($dir.'/');
}
done_testing();


sub check_remove_afters {
    my($dir) = @_;
    my $now = time();
    ok($dir, $dir);
    my $cmd = 'grep -rni "REMOVE AFTER:" '.$dir;
    open(my $ph, '-|', $cmd.' 2>&1') or die('cmd '.$cmd.' failed: '.$!);
    ok($ph, 'cmd started');
    while(<$ph>) {
        my $line = $_;
        chomp($line);
        next if $line =~ m/088\-remove_after\.t/;
        if($line =~ m/REMOVE\s*AFTER:\s*([\d]+)\.([\d]+)\.([\d]+)/mxi) {
            my($day,$month,$year) = ($1,$2,$3);
            my $ts = POSIX::mktime(0, 0, 0, $day, ($month-1), ($year-1900));
            if(!$ts || $ts < 0 || $ts < $now) {
                fail($line.' -> '.(scalar localtime($ts)));
            } else {
                ok($line, $line.' -> '.(scalar localtime($ts)));
            }
        } else {
            fail($line);
        }
    }
    close($ph);
    return;
}
