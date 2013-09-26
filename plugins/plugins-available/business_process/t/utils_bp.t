use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'CATALYST_SERVER'};
    plan tests => 9;
}

BEGIN {
    use lib('t');
    require TestUtils;
    import TestUtils;
}

use_ok('Thruk::BP::Utils');

is_deeply(Thruk::BP::Utils::clean_function_args(), [], "args 1");
is_deeply(Thruk::BP::Utils::clean_function_args("'host', 'svc'"), ["host", "svc"], "args 2");
is_deeply(Thruk::BP::Utils::clean_function_args('"host", "svc"'), ["host", "svc"], "args 3");
is_deeply(Thruk::BP::Utils::clean_function_args('"host", \'svc\''), ["host", "svc"], "args 4");
is_deeply(Thruk::BP::Utils::clean_function_args('"host"'), ["host"], "args 5");
is_deeply(Thruk::BP::Utils::clean_function_args('1, 2'), [1, 2], "args 6");
is_deeply(Thruk::BP::Utils::clean_function_args('1'), [1], "args 7");
is_deeply(Thruk::BP::Utils::clean_function_args('"1a", 5, "a2a"'), ['1a', 5, 'a2a'], "args 8");
