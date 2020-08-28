use strict;
use warnings;
use Test::More;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

plan tests => 19;

TestUtils::test_command({
    cmd     => "./script/check_thruk_rest t/data/check_thruk_rest/nested.json",
    like    => ['/timestamp/', '/longitude/'],
    exit    => 0,
});

TestUtils::test_command({
    cmd     => "./script/check_thruk_rest t/data/check_thruk_rest/nested.json -o '{list.0.key} {list.1} {list.2} {message} {iss_position.latitude}'",
    like    => [qr/^\Qvalue 1 5 success -32.7396\E\|/],
    exit    => 0,
});

TestUtils::test_command({
    cmd     => "./script/check_thruk_rest t/data/check_thruk_rest/nested.json -w list.1:0.5 -o '{STATUS}'",
    like    => [qr/^\QWARNING\E\|/],
    exit    => 1,
});

TestUtils::test_command({
    cmd     => "./script/check_thruk_rest t/data/check_thruk_rest/nested.json -o '{STATUS}' --perffilter='^t'",
    like    => [qr/timestamp/],
    unlike  => [qr/list/, qr/iss/],
    exit    => 0,
});
