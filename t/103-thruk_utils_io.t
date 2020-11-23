use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw/tempfile/;

plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
plan tests => 8;

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