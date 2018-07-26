use strict;
use warnings;
use Test::More;
use File::Temp qw/tempfile/;
use File::Slurp qw/read_file/;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
plan skip_all => 'Race condition test. Set $ENV{TEST_RACE} to a true value to run.' unless $ENV{TEST_RACE};

BEGIN {
    use lib('t');
    $ENV{'THRUK_NO_TOUCH_PERM'} = 1;
    require TestUtils;
    import TestUtils;
}

use_ok("Thruk::Utils::IO");

my $max_proc      = 10;
my $test_runs     = 1000;

my($fh, $filename) = tempfile();
close($fh);
Thruk::Utils::IO::json_lock_store($filename, { test => 0 });
ok(-f $filename, "test file exists: $filename");
is(read_file($filename), '{"test":0}', "test contains test content");

ok(1, "starting $max_proc parallel processes with $test_runs writes each.");
for my $x (1..$max_proc) {
    fork() && next;

    # forked processes should not print Test::More results
    Test::More->builder->no_ending(1);

    if($x%2 == 0) {
        for my $nr (1..$test_runs) {
            my $data = Thruk::Utils::IO::json_lock_retrieve($filename);
            if(!$data || ref $data ne 'HASH') {
                die("got no data");
            }
        }
    } else {
        for my $nr (1..$test_runs) {
            my($fh, $lock_fh) = Thruk::Utils::IO::file_lock($filename, "ex");
            my $data = Thruk::Utils::IO::json_retrieve($filename, $fh);
            Thruk::Utils::IO::json_store($filename, $fh, { test => ($data->{'test'}+1) });
            Thruk::Utils::IO::file_unlock($filename, $fh, $lock_fh);
        }
    }
    exit;
}
for(1..$max_proc) { wait; }

my $data = Thruk::Utils::IO::json_lock_retrieve($filename);
is($data->{'test'}, $max_proc * $test_runs * 0.5, 'file containts correct number');

unlink($filename);
ok(!-f $filename, "test file removed");
done_testing();
