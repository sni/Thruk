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
    plan(tests => 16);
    @files = glob('examples/*');
} else {
    @files = @ARGV;
}

###########################################################
# some examples will need arguments
my $args = {
    'examples/objectcache2csv'   => 't/data/naglint/basic/in.cfg hostgroup',
    'examples/contacts2csv'      => 't/data/naglint/basic/in.cfg',
};

###########################################################
for my $file (@files) {
    next if $file eq 'examples/remove_duplicates'; # there is an extra test for this
    check_example($file);
}

###########################################################
if(scalar @ARGV > 0) {
    done_testing();
}
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
