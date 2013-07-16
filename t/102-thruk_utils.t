use strict;
use warnings;
use utf8;
use Encode 2.12;
use Test::More tests => 7;

use_ok('Thruk::Utils');

my $test = Thruk::Utils::read_data_file('t/data/userfiles/encoding_ok');
is(ref $test, 'HASH', 'read data file: t/data/userfiles/encoding_ok');
my $encoded = encode("utf-8", $test->{'bookmarks'}->{'Bookmarks'}->[0]->[0], Encode::FB_WARN);
is($encoded, encode_utf8('öäüß'), 'encoded string correctly');


$test = Thruk::Utils::read_data_file('t/data/userfiles/encoding_iso');
is(ref $test, 'HASH', 'read data file: t/data/userfiles/encoding_iso');
$encoded = encode("utf-8", $test->{'bookmarks'}->{'Bookmarks'}->[0]->[0], Encode::FB_WARN);
is($encoded, encode_utf8('ü'), 'encoded string correctly');


$test = Thruk::Utils::read_data_file('t/data/userfiles/encoding_broken');
is(ref $test, 'HASH', 'read data file: t/data/userfiles/encoding_broken');
$encoded = encode("utf-8", $test->{'bookmarks'}->{'Bookmarks'}->[0]->[0], Encode::FB_WARN);
is($encoded, encode_utf8('BP öerpr�'), 'encoded string correctly');