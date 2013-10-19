use strict;
use warnings;
use Test::More;
use File::Temp qw/tempdir/;

BEGIN {
    plan skip_all => 'local tests only'  if defined $ENV{'CATALYST_SERVER'};
    plan skip_all => 'backends required' if !-s 'thruk_local.conf';
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

$ENV{'TERM'} = 'xterm' unless defined $ENV{'TERM'};

###########################################################
my(@files, $tmpdir);
if(scalar @ARGV == 0) {
    plan(tests => 26);
    @files = glob('examples/*');
    $tmpdir = tempdir( CLEANUP => 1 );
    mkdir($tmpdir);
    ok(-d $tmpdir, $tmpdir.' created');
    `cp -rp t/data/remove_duplicates/* $tmpdir/`;
} else {
    @files = @ARGV;
}

###########################################################
# some examples will need arguments
my $args = {
    'examples/objectcache2csv'   => 't/data/naglint/basic/in.cfg hostgroup',
    'examples/contacts2csv'      => 't/data/naglint/basic/in.cfg',
    'examples/remove_duplicates' => '-ay '.$tmpdir.'/core.cfg',
};

###########################################################
for my $file (@files) {
    check_example($file);
}

###########################################################
if(!scalar @ARGV > 0) {
    TestUtils::test_command({
        cmd  => '/usr/bin/diff -ru t/data/remove_duplicates/expect.cfg '.$tmpdir.'/test.cfg',
        like => ['/^$/'],
    });
    `rm -rf $tmpdir` if $tmpdir;
    ok(!-d $tmpdir, $tmpdir.' removed');
} else {
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
