use strict;
use warnings;
use Test::More;

plan tests => 13;

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}
BEGIN { use_ok 'Thruk::Utils::CLI::Rest' }

################################################################################
my $test_result = [{data => {
        "text1"  => "text1",
        "int1"   => 5,
        "float1" => 3.7,
        "total"  => 1,
    }}, {data =>  {
        "text2"  => "text2",
        "int2"   => 2,
        "float2" => 1.7,
        "total"  => 2,
    }}
];

################################################################################
$test_result = Thruk::Utils::CLI::Rest::_calculate_totals($test_result);

################################################################################
# simple text
is(Thruk::Utils::CLI::Rest::_replace_output('text1', $test_result), "text1");
is(Thruk::Utils::CLI::Rest::_replace_output('text2', $test_result), "text2");

# numbers
is(Thruk::Utils::CLI::Rest::_replace_output('int1', $test_result), "5");
is(Thruk::Utils::CLI::Rest::_replace_output('int1%d', $test_result), "5");
is(Thruk::Utils::CLI::Rest::_replace_output('float1%0.2f', $test_result), "3.70");

# totals
is(Thruk::Utils::CLI::Rest::_replace_output('1:total', $test_result), "1");
is(Thruk::Utils::CLI::Rest::_replace_output('2:total', $test_result), "2");
is(Thruk::Utils::CLI::Rest::_replace_output('total', $test_result), "3");

# arimethic
is(Thruk::Utils::CLI::Rest::_replace_output('1:total + 2:total', $test_result), "3");
is(Thruk::Utils::CLI::Rest::_replace_output('2:total - 1:total', $test_result), "1");
is(Thruk::Utils::CLI::Rest::_replace_output('1:total / 2:total%0.2f', $test_result), "0.50");
is(Thruk::Utils::CLI::Rest::_replace_output('total / 3', $test_result), "1");

################################################################################
