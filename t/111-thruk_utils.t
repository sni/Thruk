use warnings;
use strict;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 3;

use_ok('Thruk::Utils');

################################################################################

my $c        = TestUtils::get_c();
$c->db->{'sections_depth'} = 0; # avoid some warnings
my $backends = ["abcd", "1234"];
my $hash     = Thruk::Utils::backends_list_to_hash($c, $backends);
my $expect   = { 'backends' => [ { 'abcd' => undef }, { '1234' => undef } ] };
is_deeply($hash, $expect, "got hash");

my $list     = Thruk::Utils::backends_hash_to_list($c, $hash);
is_deeply($list, $backends, "got same list of backends");