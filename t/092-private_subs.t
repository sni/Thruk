use warnings;
use strict;
use Test::More;

use Thruk::Utils::IO ();

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

my $filter = $ARGV[0];

################################################################################
my @files = Thruk::Utils::IO::all_perl_files("./script", "./lib", glob("./plugins/plugins-available/*/lib"));
my @filtered;
for my $file (@files) {
    next if($filter && $file !~ m%$filter%mx);
    push @filtered, $file;

}
plan( tests => scalar @filtered);
for my $file (@filtered) {
    check_private_subs($file);
}

################################################################################
sub check_private_subs {
    my($file) = @_;
    my $now = time();

    ok($file, $file);
    my $content = Thruk::Utils::IO::read($file);
    $content =~ s/^=head.*?^=cut//smgx;
    my $nr = 0;
    for my $line (split/\n/mx, $content) {
        $nr++;
        chomp($line);
        my $test = $line;
        $test =~ s/"[^"]*?"//gmx;
        $test =~ s/'[^']*?'//gmx;
        $test =~ s/\#.*//gmx;
        $test =~ s/Devel::Cycle::_//gmx;
        next if $test =~ m/::_skip_backends/mx;
        if($test =~ m/::_/mx) {
            fail("private sub used in ".$file.":$nr ".$line);
        }
    }
    return;
}
