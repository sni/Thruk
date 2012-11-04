use strict;
use warnings;
use Test::More tests => 17;
use File::Temp qw/ tempfile /;

my $BIN = './script/naglint';
if(defined $ENV{'THRUK_BIN'}) {
    $BIN = $ENV{'THRUK_BIN'};
    $BIN =~ s/thruk$/naglint/mx;
}

ok(-f $BIN, "naglint exists: $BIN") or BAIL_OUT("no binary found");

my($fh, $filename) = tempfile(TEMPLATE => 'tempXXXXX', SUFFIX => '.cfg');
ok((defined $filename and $filename ne ''), "created testfile: ".$filename);

###########################################################
# do some tests from t/data/naglint
my $tests_dir = "t/data/naglint";
opendir(my $dh, $tests_dir) or die "can't opendir '$tests_dir': $!";
for my $dir (readdir($dh)) {
    next if $dir eq '.' or $dir eq '..';

    my $infile  = $tests_dir.'/'.$dir."/in.cfg";
    my $outfile = $tests_dir.'/'.$dir."/out.cfg";
    ok(-f $infile,  'input file ('.$infile.') exists');
    ok(-f $outfile, 'ouput file ('.$outfile.') exists');

    my $cmd = "$BIN $infile > $filename 2>&1";
    ok($cmd, 'cmd: '.$cmd);
    `$cmd`;
    is($?, 0, 'naglint returned: '.$?);

    my $diff_cmd = "/usr/bin/diff -u $outfile $filename";
    ok($cmd, 'cmd: '.$cmd);
    my $diff = `$diff_cmd`;
    is($?, 0, 'diff returned: '.$?);
    is($diff, '', 'diff should be empty');
}
closedir $dh;

###########################################################
# cleanup
ok(unlink($filename), "unlinked test file");
