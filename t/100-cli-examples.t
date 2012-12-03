use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'local tests only'  if defined $ENV{'CATALYST_SERVER'};
    plan skip_all => 'backends required' if !-s 'thruk_local.conf';
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

###########################################################
my @files;
if(scalar @ARGV == 0) {
    plan(tests => 8);
    @files = glob('examples/*');
} else {
    @files = @ARGV;
}

###########################################################
# some
my $args = {
    'examples/objectcache2csv'  => 't/data/naglint/basic/in.cfg hostgroup',
};

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
    my $cmd = sprintf("%s%s", $file, defined $args->{$file} ? ' '.$args->{$file} : '');
    ok($cmd, "testing : ".$cmd);
    TestUtils::test_command({
        cmd     => $cmd,
    });
    return;
}
