use strict;
use warnings;
use Test::More tests => 1;
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

################################################################################
# check if we have all subs in Provider/Base.pm
my @files = glob("lib/Thruk/Backend/Provider/*.pm");
my @bsubs = get_subs("lib/Thruk/Backend/Provider/Base.pm");
for my $file ( @files ) {
    next if $file =~ m/\/Base\.pm$/;
    my @fsubs = get_subs($file);
    is_deeply(\@fsubs, \@bsubs, "Base.pm contains all subs from $file");
}

################################################################################
# get_subs
sub get_subs {
    my $file = shift;
    my @subs;
    open(my $fh, '<', $file) or die("cannot open file $file: $!");
    while(<$fh>) {
        if($_ =~ /^\s*sub\s+([\w\d_\_]+)/mx) {
            next if $1 =~ m/^_/mx; # skip private subs
            push @subs, $1;
        }
    }
    close($fh);
    return sort @subs;
}
