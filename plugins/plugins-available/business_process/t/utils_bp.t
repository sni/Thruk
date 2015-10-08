use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => 'internal test only' if defined $ENV{'PLACK_TEST_EXTERNALSERVER_URI'};
    plan tests => 10;
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

# custom functions
my $functions = Thruk::BP::Utils::_parse_custom_functions('t/xt/business_process/data/test_cust_function.pm');
my $expected_functions = [{
            'args' => [{
                          'args' => 'text that should be echoed',
                          'name' => 'Text',
                          'type' => 'text'
                       }, {
                          'args' => [ 'no', 'yes' ],
                          'type' => 'checkbox',
                          'name' => 'Reverse'
                       }, {
                          'args' => [ 'no', 'yes' ],
                          'name' => 'Uppercase',
                          'type' => 'select'
                       }],
            'file' => 't/xt/business_process/data/test_cust_function.pm',
            'function' => 'echofunction',
            'help' => 'echofunction:

This function just echoes the
provided text sample and optionally
reverses the text.'
}];
is_deeply($functions, $expected_functions, 'parse custom functions 1');
