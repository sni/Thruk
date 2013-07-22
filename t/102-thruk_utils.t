use strict;
use warnings;
use utf8;
use Encode 2.12;
use Test::More;

# from: http://perldoc.perl.org/perl5101delta.html
# Within UTF8-encoded Perl source files (i.e. where use utf8 is in effect), double-quoted literal strings could be corrupted where a \xNN , \0NNN or \N{} is followed by a literal character with ordinal value greater than 255 [RT #59908].
plan skip_all => 'breaks with perl older than 5.10.1, got '.$] if $] < 5.010001;
plan tests => 7;

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
