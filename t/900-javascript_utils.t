use strict;
use warnings;
use Test::More;
use Data::Dumper;

plan skip_all => 'Author test. Set $ENV{TEST_AUTHOR} to a true value to run.' unless $ENV{TEST_AUTHOR};
eval "use Test::JavaScript";
plan skip_all => 'Test::JavaScript required' if $@;

#################################################
# create minimal window object
js_ok("
var window = {
  navigator: {userAgent:'test'},
  document:  {
    createElement:function(){
        return({
            getElementsByTagName:function(){ return([])},
            appendChild:function(){},
            setAttribute:function(){}
        });
    },
    createDocumentFragment:function(){return({})},
    createComment:function(){},
    getElementById:function(){},
    documentElement:{
        insertBefore:function(){},
        removeChild:function(){}
    }
  }
}
thruk_debug_js = 1;
", 'set window object') or BAIL_OUT("$0: failed to create window object");
my @jsfiles = glob('root/thruk/javascript/jquery-*.js');
ok($jsfiles[0], $jsfiles[0]);
js_eval_ok($jsfiles[0]) or BAIL_OUT("$0: failed to load jQuery");
js_ok("jQuery = window.jQuery", 'set jQuery into global space') or BAIL_OUT("$0: failed to globalize jQuery");
js_ok("jQuery.noConflict()", 'set jQuery noConflict') or BAIL_OUT("$0: failed to so noConflict");

#################################################
js_ok("url_prefix='/'", 'set url prefix');
@jsfiles = glob('root/thruk/javascript/thruk-*.js');
ok($jsfiles[0], $jsfiles[0]);
js_eval_ok($jsfiles[0]);

js_eval_ok('t/data/javascript_tests.js');
js_is("test1()", '1', 'test1()');
js_is("test2()", '1', 'test2()');

done_testing();
