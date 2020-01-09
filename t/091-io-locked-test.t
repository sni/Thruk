use strict;
use warnings;
use Test::More;
use File::Temp qw/tempfile/;
use File::Slurp qw/read_file/;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

BEGIN {
    use lib('t');
    $ENV{'THRUK_NO_TOUCH_PERM'} = 1;
    $ENV{'TEST_IO_NOWARNINGS'}  = 1;
    require TestUtils;
    import TestUtils;
}

use_ok("Thruk::Utils::IO");

my($fh, $filename) = tempfile();
close($fh);
Thruk::Utils::IO::json_lock_store($filename, { a => 0, b => 0, c => 0 });
ok(-f $filename, "test file exists: $filename");
is(read_file($filename), '{"a":0,"b":0,"c":0}', "test contains test content");

# lock the file but don't do anything, just keep the lock open
my($fh2, $lock_fh) = Thruk::Utils::IO::file_lock($filename, "ex");

$Thruk::Utils::IO::MAX_LOCK_RETRIES = 2;
is($Thruk::Utils::IO::MAX_LOCK_RETRIES, 2, "max retries reduced"); # also prevents perl from complain about: Name "Thruk::Utils::IO::MAX_LOCK_RETRIES" used only once: possible typo

# try to patch the file which is locked
Thruk::Utils::IO::json_lock_patch($filename, { b => 1 });

# now remove the lock
Thruk::Utils::IO::file_unlock($filename, $fh2, $lock_fh);

is(read_file($filename), '{"a":0,"b":1,"c":0}', "test contains test content");

unlink($filename);
ok(!-f $filename, "test file removed");
done_testing();


END {
    unlink($filename) if $filename;
}
