use warnings;
use strict;
use Encode qw/encode_utf8/;
use File::Temp qw/tempfile/;
use Test::More;
use utf8;

use Thruk::Utils::Encode ();

plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
plan tests => 14;

use_ok('Thruk::Utils::IO');
use_ok('Thruk::Config');

my $testdata = { data => [
    'string',
    12345,
    { nested => ['list'] },
    '€',
]};
my($fh, $file) = tempfile();
unlink($file);
close($fh);

ok(!-f $file, "file does not exist yet: ".$file);
Thruk::Utils::IO::json_lock_store($file, $testdata);
ok(-f $file, "file does not exist now: ".$file);

my $readdata = Thruk::Utils::IO::json_lock_retrieve($file);
is_deeply($testdata, $readdata, 'data is the same');

ok(unlink($file), 'remove tempfile');

my $hostname = `hostname`;
my(undef, $hostname2) = Thruk::Utils::IO::cmd("hostname");
is($hostname2, $hostname, "hostnames are equal");

my $hostname3 = Thruk::Utils::IO::cmd("hostname");
is($hostname3, $hostname, "hostnames are equal");

################################################################################
# write utf8
my $teststr = 'öäüß';
my $rc = Thruk::Utils::IO::write($file, $teststr);
is($rc, 1, "write succeeded");

my $str = Thruk::Utils::IO::read($file);
is($str, $teststr, "read string matched");
ok(unlink($file), 'remove tempfile');

################################################################################
# write decoded utf8
$teststr = Thruk::Utils::Encode::decode_any($teststr);
$rc = Thruk::Utils::IO::write($file, $teststr);
is($rc, 1, "write succeeded");

$str = Thruk::Utils::IO::read($file);
is($str, $teststr, "read string matched");

ok(unlink($file), 'remove tempfile');
