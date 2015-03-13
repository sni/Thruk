use strict;
use warnings;
use Test::More;
use Data::Dumper;
use File::Slurp qw/read_file/;
use File::Temp qw/tempfile/;

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
  },
  addEventListener: function() {}
};
var document = window.document;
thruk_debug_js = 1;
", 'set window object') or BAIL_OUT("$0: failed to create window object");

#################################################
js_ok("url_prefix='/'", 'set url prefix');
my @jsfiles = glob('root/thruk/javascript/thruk-*.js');
ok($jsfiles[0], $jsfiles[0]);
js_eval_ok($jsfiles[0]);

#################################################
# tests from javascript_tests file
my @functions = read_file('t/data/javascript_tests.js') =~ m/^\s*function\s+(test\d+)/gmx;
js_eval_ok('t/data/javascript_tests.js');
for my $f (@functions) {
    js_is("$f()", '1', "$f()");
}

#################################################
# some more functions
js_ok("var top = { location: '' };", "defined top fake object");
js_ok("var location = '';"         , "defined location fake object");
js_ok("window.location = '';"      , "defined window.location fake object");
_eval_extracted_js('templates/login.tt');
@functions = read_file('t/data/javascript_tests_login_tt.js') =~ m/^\s*function\s+(test\d+)/gmx;
js_eval_ok('t/data/javascript_tests_login_tt.js');
for my $f (@functions) {
    js_is("$f()", '1', "$f()");
}

#################################################
done_testing();


#################################################
# SUBS
#################################################
sub _eval_extracted_js {
    my($file) = @_;
    ok(1, "extracting from ".$file);
    my $cont = read_file($file);
    my @codes = $cont =~ m/<script[^>]*text\/javascript.*?>(.*?)<\/script>/gsmxi;
    my $jscode = join("\n", @codes);
    $jscode =~ s/\[\%\s*product_prefix\s*\%\]/thruk/gmx;
    my($fh, $filename) = tempfile();
    print $fh $jscode;
    close($fh);
    js_eval_ok($filename);
    unlink($filename);
    return;
}

#################################################
