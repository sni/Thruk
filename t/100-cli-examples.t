use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'local tests only'  if defined $ENV{'CATALYST_SERVER'};
    plan skip_all => 'backends required' if !-f 'thruk_local.conf';
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###########################################################
my @files;
if(scalar @ARGV == 0) {
    plan(tests => 4);
    @files = glob('examples/*');
} else {
    @files = @ARGV;
}

###########################################################
for my $file (@files) {
    check_example($file);
}

###########################################################
done_testing() if scalar @ARGV > 0;
exit;


###########################################################
# SUBS
###########################################################
sub check_example {
    my($file) = @_;
    ok($file, "testing : $file");
    TestUtils::test_command({
        cmd     => $file,
        #like    => ['/^$/'],
        #errlike => ['/^/'],
    });
    return;
}
