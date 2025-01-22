use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 10;

use_ok('Thruk::Utils');
use_ok('Thruk::Utils::Filter');

################################################################################

my $c        = TestUtils::get_c();
$c->db->{'sections_depth'} = 0; # avoid some warnings
my $backends = ["abcd", "1234"];
my $hash     = Thruk::Utils::backends_list_to_hash($c, $backends);
my $expect   = { 'backends' => [ { 'abcd' => undef }, { '1234' => undef } ] };
is_deeply($hash, $expect, "got hash");

my $list     = Thruk::Utils::backends_hash_to_list($c, $hash);
is_deeply($list, $backends, "got same list of backends");

################################################################################

my $res;
$res = Thruk::Utils::Filter::duration(7, 6);
is($res, "7s", "duration is ok");

$res = Thruk::Utils::Filter::duration(107, 6);
is($res, "1m 47s", "duration is ok");

$res = Thruk::Utils::Filter::duration(712, 6);
is($res, "11m 52s", "duration is ok");

$res = Thruk::Utils::Filter::duration(-712, 6);
is($res, "-11m 52s", "duration is ok");

$res = Thruk::Utils::Filter::duration(1.212, 6);
is($res, "1.2s", "duration is ok");

$res = Thruk::Utils::Filter::duration(0.212, 6);
is($res, "212ms", "duration is ok");