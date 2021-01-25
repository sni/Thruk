use strict;
use warnings;
use Test::More tests => 4;

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
            my $func = $1;
            next if $func =~ m/^_/mx; # skip private subs
            next if $func eq 'propagate_session_file'; # not required
            next if $func eq 'rpc';                    # only available on http
            next if $func eq 'request';                # only available on http
            next if $func eq 'rest_request';           # only available on http
            next if $func eq 'check_global_lock';      # only available on mysql
            push @subs, $func;
        }
    }
    close($fh);
    return sort @subs;
}
