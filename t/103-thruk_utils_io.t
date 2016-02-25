use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw/tempfile/;

plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
plan tests => 5;

use_ok('Thruk::Utils::IO');

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
