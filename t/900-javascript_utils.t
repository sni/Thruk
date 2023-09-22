use warnings;
use strict;
use Test::More;

use Thruk::Utils::IO ();

use lib('t');
use TestUtils qw/:js/;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};

#################################################
js_init();
js_ok("url_prefix='/'", 'set url prefix');
js_ok("jQuery=false", 'prevent reference error');
my @jsfiles = glob('root/thruk/javascript/thruk-*.js');
ok($jsfiles[0], $jsfiles[0]);
js_eval_ok($jsfiles[0]);

#################################################
# tests from javascript_tests file
my @functions = Thruk::Utils::IO::read('t/data/javascript_tests.js') =~ m/^\s*function\s+(test\w+)/gmx;
ok(scalar @functions > 0, "read ".(scalar @functions)." functions from javascript_test.js");
js_eval_ok('t/data/javascript_tests.js');
for my $f (@functions) {
    js_is("$f()", '1', "$f()");
}

#################################################
# some more functions
js_eval_extracted('templates/login.tt');
@functions = Thruk::Utils::IO::read_as_list('t/data/javascript_tests_login_tt.js') =~ m/^\s*function\s+(test\w+)/gmx;
js_eval_ok('t/data/javascript_tests_login_tt.js');
for my $f (@functions) {
    js_is("$f()", '1', "$f()");
}

#################################################
js_deinit();
done_testing();
